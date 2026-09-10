# 毎朝8時のスクリーンタイム確認通知

このドキュメントは毎朝8時に送る「先日のスクリーンタイムを確認しましょう」通知の実装([lib/services/daily_notification_service.dart](../lib/services/daily_notification_service.dart))の仕様書です。
**コードが正**であり、このドキュメントはそれを読み解くための資料です。実装を変更したら、このドキュメントも合わせて更新してください。

## 目次

- [設計方針](#設計方針)
- [文面](#文面)
- [仕組み](#仕組み)
- [動作確認用ボタン](#動作確認用ボタン)
- [既知の制約](#既知の制約)

---

## 設計方針

方式は**端末ローカル通知のみ**([flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications))。
サーバー主導のプッシュ通知(FCM)にすると、Firebaseプロジェクトの作成・`google-services.json`の配置・
デバイストークンを保存するテーブル・`pg_cron`による定期実行など、このアプリにまだ無い基盤が新たに必要になる。
ローカル通知は端末側で毎日繰り返しスケジュールするだけで済み、追加のバックエンドが要らない。

スクリーンタイム機能自体がAndroid専用([screen_time_ai_commentary.md](screen_time_ai_commentary.md)参照、
iOSは`ScreenTimeUnavailableReason.unsupportedPlatform`)なため、この通知も**Android専用**とする。
`DailyNotificationService`は`Platform.isAndroid`以外ではすべてのメソッドが何もせずに返る。

## 文面

| 宛先 | タイトル | 本文 |
|---|---|---|
| 子ども | 先日のスクリーンタイム | 先日のスクリーンタイムを確認しましょう。 |
| 保護者(子ども1人) | 〈子どもの名前〉のスクリーンタイム | 〈子どもの名前〉の先日のスクリーンタイムを確認してみましょう。 |
| 保護者(子ども2人以上) | 〈名前1〉、〈名前2〉のスクリーンタイム | 〈名前1〉、〈名前2〉の先日のスクリーンタイムを確認してみましょう。 |

同じグループに子どもが複数いる場合も通知は**1件にまとめ**、名前を「、」で連結する。
保護者かつ同じグループに子どもが1人もいない場合は知らせる相手がいないため、通知そのものを出さない。

文面の組み立ては`dailyScreenTimeNotificationContent({required isChild, required childNames})`が担う純粋関数で、
プラグインに一切触れないため`test/services/daily_notification_content_test.dart`でロジックのみを検証している。

## 仕組み

- `main()`で`DailyNotificationService.instance.init()`を一度だけ呼び、タイムゾーンデータの読み込み(`Asia/Tokyo`固定。
  日本語圏専用アプリなので端末のタイムゾーンを取得するパッケージは追加していない)とプラグインの初期化だけを行う。
- ログイン成功のたびに[lib/screens/auth_gate.dart](../lib/screens/auth_gate.dart)の`_ProfileLoader._loadAndHydrate()`が
  `DailyNotificationService.instance.syncForSession(isChild:, childNames:)`を呼ぶ。このメソッドは
  1. 既存のスケジュールを`cancelAll()`で消す(表示名変更・ロール切替・子どもの増減で古い文面が残らないように)
  2. 通知権限を要求する(Android 13+)
  3. 次に来る午前8:00を`zonedSchedule` + `matchDateTimeComponents: DateTimeComponents.time`で毎日繰り返しスケジュールする

  という流れを行う。`AuthGate`はすでにロールと同じグループの子ども一覧を取得済みなので、追加のDBクエリは発生しない。
  全体を`try/catch`で囲んでおり、通知のスケジュールに失敗してもログイン処理自体は止めない。
- [lib/services/auth_service.dart](../lib/services/auth_service.dart)の`signOut()`は、Supabaseのサインアウト前に
  `DailyNotificationService.instance.cancelAll()`を呼ぶ。同じ端末で別のユーザーがログインしたときに、
  前のユーザー向けの文面が届き続けないようにするため。
- 通知をタップしたときの挙動は特別なディープリンクを実装していない。アプリを起動するだけで
  `'/'` → `AuthGate` → `MainShell`(ホームタブ = スクリーンタイムカード)が開くので、それをそのまま利用している。

## 動作確認用ボタン

8時を待たずに確認できるよう、アカウント情報画面([lib/screens/account_info_screen.dart](../lib/screens/account_info_screen.dart))に
「通知テスト送信」ボタンを置いている。押すと現在ログイン中のロールと同グループの子ども一覧から
`DailyNotificationService.instance.showNow(...)`を呼び、毎朝のスケジュールとは別の通知IDで即時発火する
(スケジュール済みの通知を上書き・キャンセルしない)。開発確認用の機能であり、リリースビルドから隠す対応は行っていない。

## 既知の制約

- **端末ローカル通知**なので、その端末で一度ログインして初めてスケジュールされる。アプリを未インストール/未ログインの
  端末には届かない。
- サーバー側から文面や配信タイミングを後から変更することはできない。将来サーバー主導の配信にするなら、
  FCM + デバイストークンを保存するテーブル + `pg_cron`が必要になる。
- 子どもの表示名を変えた場合、その保護者が次にアプリを開いてログインし直したタイミングで再スケジュールされ、
  新しい名前が通知文面に反映される。
- `AndroidScheduleMode.inexactAllowWhileIdle`を使っているため、Doze(省電力)の影響で午前8:00ちょうどではなく
  数分〜数十分ずれて届くことがある。厳密な時刻精度は求めていない。
