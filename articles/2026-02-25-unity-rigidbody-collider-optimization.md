---
title: "Unity！「Rigidbody × Collider 最適化」で当たり判定を究極に高めるテクニック"
emoji: "🙆"
type: "tech"
topics: ["csharp","unity","rigidbody","collider","当たり判定"]
published: true
---

Unityの物理演算を駆使するうえで、**RigidbodyとColliderをいかに最適化するか**は当たり判定の正確さやパフォーマンスに直結します。開発初期は気にならなくても、シーンが大規模化するにつれて衝突判定の不具合やパフォーマンス低下が表面化するケースは珍しくありません。本記事では、**リアルな衝突演出を目指すエンジニアが知っておきたい設計の基本**と、トラブルシューティングのヒントをまとめます。シミュレーションゲームやアクションゲームにおいても役立つポイントを網羅しながら、最適化への道筋を見つけていきましょう。

#### [](#unity%E5%88%9D%E5%BF%83%E8%80%85%E3%81%A7%E3%82%82%E6%9C%80%E7%9F%AD5%E6%97%A5%E3%81%A73d-fps%E3%81%8C%E5%AE%8C%E6%88%90%EF%BC%81%E4%BB%8A%E3%81%99%E3%81%90%E5%A7%8B%E3%82%81%E3%82%8B%E5%85%A5%E9%96%80%E3%83%81%E3%83%A5%E3%83%BC%E3%83%88%E3%83%AA%E3%82%A2%E3%83%AB%E3%81%AF%E3%81%93%E3%81%A1%E3%82%89)Unity初心者でも最短5日で3D FPSが完成！今すぐ始める入門チュートリアルはこちら

[https://zenn.dev/ryuryu\_game/books/fd28de9d8e963a/viewer/0570af](https://zenn.dev/ryuryu_game/books/fd28de9d8e963a/viewer/0570af)

#### [](#unity%E3%81%AE%E5%BD%93%E3%81%9F%E3%82%8A%E5%88%A4%E5%AE%9A%E3%81%AE%E8%A8%AD%E5%AE%9A%E6%96%B9%E6%B3%95%E3%81%AF%E3%81%93%E3%81%A1%E3%82%89)Unityの当たり判定の設定方法はこちら

[https://youtu.be/2M1\_uv5bRMA?si=18vO2uCKxrVGoFgq](https://youtu.be/2M1_uv5bRMA?si=18vO2uCKxrVGoFgq)

# [](#%E3%81%AA%E3%81%9Crigidbody%E3%81%A8collider%E3%81%AE%E6%9C%80%E9%81%A9%E5%8C%96%E3%81%8C%E9%87%8D%E8%A6%81%E3%81%AA%E3%81%AE%E3%81%8B)なぜRigidbodyとColliderの最適化が重要なのか

## [](#%E5%A4%A7%E8%A6%8F%E6%A8%A1%E3%82%B7%E3%83%BC%E3%83%B3%E3%81%A7%E3%81%AE%E8%B2%A0%E8%8D%B7%E3%82%92%E6%8A%91%E3%81%88%E3%82%8B)大規模シーンでの負荷を抑える

多数のオブジェクトを配置すると、物理演算の負荷が加速度的に増大します。とくにRigidbodyは物理エンジンによる計算処理が必須であり、**不要なRigidbodyを無闇に配置している**と、FPS（フレームレート）低下を招きやすいです。以下のリンクでも、FPS最適化に関連した具体例が紹介されています。  
[https://qiita.com/Nakatomo/items/ace31ac9de2e0bdb87bf](https://qiita.com/Nakatomo/items/ace31ac9de2e0bdb87bf)

## [](#%E5%BD%93%E3%81%9F%E3%82%8A%E5%88%A4%E5%AE%9A%E3%81%AE%E7%B2%BE%E5%BA%A6%E3%82%92%E5%90%91%E4%B8%8A%E3%81%95%E3%81%9B%E3%82%8B)当たり判定の精度を向上させる

衝突の発生タイミングや検知が曖昧だと、ゲームプレイに不快感を与える可能性があります。Colliderの形状選択やRigidbody設定を最適化することで、「すり抜け」や「タイミングがズレる」問題を大幅に減らせます。特にプレイヤーキャラクターのHit感が重要なアクションゲームでは、**最適化こそが演出力アップの鍵**となります。

## [](#%E3%83%87%E3%83%90%E3%83%83%E3%82%B0%E3%82%92%E5%AE%B9%E6%98%93%E3%81%AB%E3%81%99%E3%82%8B)デバッグを容易にする

多くのColliderやRigidbodyが入り乱れた状態では、トラブルシュートも困難になります。**どのオブジェクトが衝突を管理しているか**が不透明になり、バグ修正の工数が増大しがちです。最適化にあたっては、ColliderとRigidbodyの役割分担を明確にし、レイヤーやタグの整理を行うとデバッグ効率が飛躍的に向上します。

# [](#rigidbody%E6%9C%80%E9%81%A9%E5%8C%96%E3%81%AE%E5%9F%BA%E6%9C%AC)Rigidbody最適化の基本

## [](#1.-rigidbody%E3%81%AE%E6%95%B0%E3%82%92%E5%BF%85%E8%A6%81%E6%9C%80%E5%B0%8F%E9%99%90%E3%81%AB%E3%81%99%E3%82%8B)1\. Rigidbodyの数を必要最小限にする

Rigidbodyは物理演算コストの大部分を占めるため、**静止しているオブジェクトはRigidbodyを持たせない**のがセオリーです。特に背景や足場などは、静的Collider（Rigidbodyなし）にしておくとパフォーマンス改善が見込めます。こちらの資料でも、RigidbodyやColliderの扱いに関する最適化テクニックがまとめられています。  
[https://qiita.com/yoship1639/items/7339a6201b44a24fbdfe](https://qiita.com/yoship1639/items/7339a6201b44a24fbdfe)

-   オブジェクトをなるべく動かさず、`isKinematic`を活用する
-   動きが不要なパーツをバラバラにしない（1つの大きなメッシュColliderに集約する場合も検討）

## [](#2.-collision-detection%E3%82%92%E9%81%A9%E5%88%87%E3%81%AB%E9%81%B8%E3%81%B6)2\. Collision Detectionを適切に選ぶ

Rigidbodyの**Collision Detection**には、Discrete / Continuous / Continuous Dynamic など複数のモードがあります。高速移動するオブジェクトほどContinuous系を選ぶべきですが、その分計算負荷が増えます。無闇にContinuousを多用せず、**必要なオブジェクトだけ使う**ことが重要です。  
移動が速すぎるオブジェクトがColliderをすり抜ける問題に関しては、以下のリンク先でより詳しく解説されています。  
[https://www.popii33.com/unity\_collider\_make-ones-way-through-quickly/](https://www.popii33.com/unity_collider_make-ones-way-through-quickly/)

## [](#3.-sleep%E7%8A%B6%E6%85%8B%E3%82%92%E6%B4%BB%E7%94%A8%E3%81%99%E3%82%8B)3\. Sleep状態を活用する

一定時間動きがないRigidbodyオブジェクトは物理演算を停止できる“Sleep状態”に移行可能です。これにより、演算量を削減してパフォーマンスを向上できます。

-   オブジェクトが動かない状況で無駄にRigidbody計算しない
-   Sleepからの復帰タイミングは衝突や外部影響を受けたとき

# [](#collider%E6%9C%80%E9%81%A9%E5%8C%96%E3%81%AE%E5%9F%BA%E6%9C%AC)Collider最適化の基本

## [](#1.-%E5%BD%A2%E7%8A%B6%E9%81%B8%E6%8A%9E%EF%BC%9Amesh-collider-vs-primitive-collider)1\. 形状選択：Mesh Collider vs Primitive Collider

見た目どおりの形状で当たり判定を取るためにMesh Colliderを使いたくなりますが、複雑なメッシュだと計算コストが嵩みがちです。できるかぎり**Sphere / Box / Capsule / Cylinder**などのPrimitive Colliderで代替できないかを検討しましょう。

-   シューティングゲームなどではSphereColliderを多用し、余計な多角形判定を回避
-   背景や地形はMesh Collider、キャラやギミックはBoxやCapsule、といった住み分け

## [](#2.-%E8%A4%87%E5%90%88collider%E3%81%A7%E7%AF%84%E5%9B%B2%E3%82%92%E7%B4%B0%E5%88%86%E5%8C%96)2\. 複合Colliderで範囲を細分化

一つのMesh Colliderよりも、複数のPrimitive Colliderを組み合わせたほうが負荷が下がるケースがあります。たとえば、車の形をBoxCollider数個で再現する手法などが典型例です。**これにより衝突計算が簡略化される**ので、FPS向上に寄与する場合があります。

## [](#3.-%E3%83%AC%E3%82%A4%E3%83%A4%E3%83%BC%E5%88%86%E3%81%91%E3%81%A8%E3%82%BF%E3%82%B0%E7%AE%A1%E7%90%86)3\. レイヤー分けとタグ管理

Colliderをレイヤーで管理すると、不要な衝突判定を省略できます。

-   Physics設定で「このレイヤー同士は衝突させない」を指定し、余計な干渉をカット
-   衝突イベントの中でタグ判定を行う際、可能な限りレイヤーと組み合わせると効率的

衝突イベントが発火しない問題や複数Colliderが重なるトラブルについて、以下の資料でも分かりやすく言及されています。  
[https://zenn.dev/ryuryu\_game/articles/aef8913baa738b](https://zenn.dev/ryuryu_game/articles/aef8913baa738b)

# [](#%E3%82%88%E3%81%8F%E3%81%82%E3%82%8B%E3%83%88%E3%83%A9%E3%83%96%E3%83%AB%E3%81%A8%E5%AF%BE%E5%87%A6%E6%B3%95)よくあるトラブルと対処法

## [](#%E8%A1%9D%E7%AA%81%E5%88%A4%E5%AE%9A%E3%81%8C%E3%81%99%E3%82%8A%E6%8A%9C%E3%81%91%E3%82%8B)衝突判定がすり抜ける

-   **速度が高すぎる場合**: RigidbodyのCollision DetectionをContinuousに変更し、移動単位を適切に抑える
-   **フレーム単位のズレ**: Update vs FixedUpdateのタイミングを誤ると衝突検出が漏れる可能性がある

## [](#%E5%BD%93%E3%81%9F%E3%82%8A%E5%88%A4%E5%AE%9A%E3%81%8C%E7%99%BA%E7%81%AB%E3%81%97%E3%81%AA%E3%81%84)当たり判定が発火しない

-   **Tag/Layersの設定ミス**: 意図した衝突対象が同じレイヤーに属していない、あるいは`OnCollisionEnter`/`OnTriggerEnter`の対象外になっている
-   **isTriggerの設定**: TriggerとそうでないColliderの組み合わせに注意

## [](#collider%E5%90%8C%E5%A3%AB%E3%81%8C%E9%87%8D%E3%81%AA%E3%81%A3%E3%81%A6%E3%81%97%E3%81%BE%E3%81%86)Collider同士が重なってしまう

-   **初期配置の重なり**: GameObject配置時にColliderの位置や大きさが適切に設定されていない
-   **物理演算の干渉**: アニメーションや外部スクリプトで無理矢理動かしている

# [](#%E3%82%B7%E3%83%9F%E3%83%A5%E3%83%AC%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E3%82%B2%E3%83%BC%E3%83%A0%E3%82%84%E3%82%A2%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%E3%82%B2%E3%83%BC%E3%83%A0%E3%81%A7%E3%81%AE%E5%BF%9C%E7%94%A8%E4%BE%8B)シミュレーションゲームやアクションゲームでの応用例

## [](#%E3%82%B7%E3%83%9F%E3%83%A5%E3%83%AC%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E3%82%B2%E3%83%BC%E3%83%A0%EF%BC%9A%E5%A4%A7%E9%87%8F%E3%82%AA%E3%83%96%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%81%AE%E8%A1%9D%E7%AA%81%E7%AE%A1%E7%90%86)シミュレーションゲーム：大量オブジェクトの衝突管理

-   マップ内の建築物やユニットは**極力Rigidbodyを持たせず**、静的Colliderにする
-   動きがあるオブジェクトだけにRigidbodyを付けるが、その数を最適化する
-   大量のパーティクル演出が重なる場合は、パーティクル数を絞り、Colliderとの同期を最小限にする
-   大規模シーンでのパーティクル最適化例は下記記事も参考

[https://qiita.com/Nakatomo/items/ace31ac9de2e0bdb87bf](https://qiita.com/Nakatomo/items/ace31ac9de2e0bdb87bf)

## [](#%E3%82%A2%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%E3%82%B2%E3%83%BC%E3%83%A0%EF%BC%9A%E3%83%AA%E3%82%A2%E3%83%AB%E3%81%AA%E8%A1%9D%E7%AA%81%E3%81%A8%E8%BB%BD%E5%BF%AB%E3%81%AA%E6%93%8D%E4%BD%9C%E6%84%9F)アクションゲーム：リアルな衝突と軽快な操作感

-   プレイヤーキャラのRigidbodyはContinuousに設定し、壁や床はDiscreteで十分なケースが多い
-   攻撃判定はPrimitive Colliderで管理し、斬撃やエフェクト部分はTriggerで当たり判定を取る
-   敵キャラ同士はLayersを分け、余計な衝突を省きながらプレイヤーとのみ当たるよう制御

# [](#%E3%83%88%E3%83%A9%E3%83%96%E3%83%AB%E3%82%B7%E3%83%A5%E3%83%BC%E3%83%88%E3%81%AB%E5%82%99%E3%81%88%E3%82%8B%E3%83%81%E3%82%A7%E3%83%83%E3%82%AF%E3%83%AA%E3%82%B9%E3%83%88)トラブルシュートに備えるチェックリスト

-   **レイヤー設定が適切か？**
    -   衝突不要な組み合わせをPhysicsの設定でオフにしているか
-   **RigidBodyのSleep/Active状態を把握しているか？**
    -   動かないオブジェクトはSleep状態にできる設計になっているか
-   **コリジョン検出モード(Collision Detection Mode)の見直しは済んでいるか？**
    -   速度の遅いオブジェクトでもContinuousにしていないか
-   **Mesh Colliderを多用しすぎていないか？**
    -   プリミティブ形状に置き換えできないかを常に検討

# [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

**Rigidbody × Colliderの最適化**は、Unity物理演算の土台を強固にするうえで欠かせない工程です。最適化が行き届くことで、当たり判定の精度が高まり、エンジンに過度な負担をかけることなく、リアルで快適なゲーム体験を提供できます。

!

-   不要なRigidbodyを削減し、物理演算コストを抑える
-   形状選択やレイヤー管理で衝突判定を効率化
-   Collision Detectionを正しく設定し、すり抜けやズレを防ぐ

これらを徹底すれば、衝突の再現性が高くなり、開発後期に起きがちな「当たり判定が安定しない」トラブルを最小限に抑えられます。

さらに詳しい最適化手法やトラブルシュート例は、以下のリンクも参照してください。

[https://www.popii33.com/unity\_collider\_make-ones-way-through-quickly/](https://www.popii33.com/unity_collider_make-ones-way-through-quickly/)

アクションゲーム、シミュレーションゲームを問わず、衝突判定の最適化は作品のクオリティと動作安定性を大きく左右します。**あなたのUnityプロジェクトでも、まずはColliderの形状やRigidBody数の棚卸しを行い、Physics設定を見直してみてください**。  
次の一手として、プロファイラーを活用した負荷計測や、部分的なデモシーンでの実験を通して、理想的な当たり判定とパフォーマンスの両立を探ってみるとよいでしょう。

最後までお読みいただき、ありがとうございました。最適化を行うことで、Unityエンジニアにとって悩みの種である衝突判定の不具合を減らし、開発全体をスムーズに進められます。**今こそRigidbody×Collider設定を見直し、究極の当たり判定を目指しましょう！**

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
