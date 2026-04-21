#!/bin/bash
# update-zenn-metrics.sh - Zenn公開APIからfollower/like数を取得しmetrics.jsonを更新
#
# 依存: curl, python3 のみ (playwrightに依存しない軽量版)
# 出力: data/metrics.json
#   {
#     "followers": 37,
#     "likes": 349,
#     "articles_count": 36,
#     "monthly_increase": 0,
#     "last_updated": "2026-04-21",
#     "history": [{"date": "2026-04-21", "followers": 37, "likes": 349}]
#   }

set -uo pipefail

USERNAME="ryuryu_game"
METRICS_FILE="$(dirname "$0")/../data/metrics.json"
TODAY=$(date '+%Y-%m-%d')

RESPONSE=$(curl -sf "https://zenn.dev/api/users/${USERNAME}" 2>/dev/null)
if [[ -z "$RESPONSE" ]]; then
  echo "ERROR: Zenn API 取得失敗" >&2
  exit 1
fi

CURRENT_FOLLOWERS=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user',{}).get('follower_count',0))")
CURRENT_LIKES=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user',{}).get('total_liked_count',0))")
CURRENT_ARTICLES=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user',{}).get('articles_count',0))")

if [[ -f "$METRICS_FILE" ]]; then
  EXISTING=$(cat "$METRICS_FILE")
else
  EXISTING='{}'
fi
if [[ -z "${EXISTING// }" ]] || ! echo "$EXISTING" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  EXISTING='{}'
fi

DATE_30_DAYS_AGO=$(date -v-30d '+%Y-%m-%d' 2>/dev/null || date -d '30 days ago' '+%Y-%m-%d')

export EXISTING CURRENT_FOLLOWERS CURRENT_LIKES CURRENT_ARTICLES TODAY DATE_30_DAYS_AGO

python3 << 'PYEOF' > "$METRICS_FILE"
import os, json
existing = json.loads(os.environ.get("EXISTING") or "{}")
history = existing.get("history", [])
today = os.environ["TODAY"]
date_30d = os.environ["DATE_30_DAYS_AGO"]
f = int(os.environ["CURRENT_FOLLOWERS"])
l = int(os.environ["CURRENT_LIKES"])
a = int(os.environ["CURRENT_ARTICLES"])

snap = None
for h in sorted(history, key=lambda x: x.get("date","")):
    if h.get("date","") <= date_30d:
        snap = h

monthly_increase = max(0, f - snap.get("followers", f)) if snap else 0

updated = False
for h in history:
    if h.get("date") == today:
        h.update({"followers": f, "likes": l, "articles": a})
        updated = True
        break
if not updated:
    history.append({"date": today, "followers": f, "likes": l, "articles": a})
history = sorted(history, key=lambda x: x.get("date",""))[-90:]

print(json.dumps({
    "followers": f,
    "likes": l,
    "articles_count": a,
    "monthly_increase": monthly_increase,
    "last_updated": today,
    "history": history,
}, ensure_ascii=False, indent=2))
PYEOF

echo "Updated: followers=${CURRENT_FOLLOWERS}, likes=${CURRENT_LIKES}, articles=${CURRENT_ARTICLES}"
