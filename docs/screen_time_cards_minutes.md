# 議事録: スクリーンタイム/AI講評カードのホーム統合

- **日時**: 2026-09-07
- **対象ブランチ**: `feature/screen-time-ai-commentary` → `main`
- **議題**: `feature/screen-time-ai-commentary` で実装済みのスクリーンタイム表示・ドパガキ指数・AI講評を、`main` の `HomeBody` にあるプレースホルダーカード3枚と差し替えて統合する

このドキュメントは、統合作業を進める前に確認・合意した方針と、その理由の記録です。実装の詳細な仕様は [db_schema.md](db_schema.md) を参照してください。

---

## 前提の共有

`feature/screen-time-ai-commentary`(コミット `5304773`)は、`main` にログイン/Supabase連携/クエスト/ギフト機能が入る**前**の状態(`dde8937`)から分岐していた。そのため単純な `merge`/`rebase` はできず、`lib/main.dart` や `lib/models/child_profile.dart` など複数ファイルで衝突する状態だった。

一方 `main` の [home_body.dart](../lib/screens/home_body.dart) には、統合対象のちょうど3枚のプレースホルダーカード(`_DopamineIndexCard` / `_ScreenTimePlaceholderCard` / `_AiCommentCard`)が既に置かれており、差し替え先が明確だった。

## 決定事項

| # | 論点 | 決定 | 理由 |
|---|---|---|---|
| 1 | mainへの取り込み方法 | `feature` ブランチ上で `git merge main` → 衝突解消 → `main` へPR | rebaseは全コミットが1つで衝突量が変わらない上に履歴が失われる。直接mainで作業すると他ブランチへの影響やレビュー可能性が失われるため、通常のPRフローを採用 |
| 2 | UIスタイル | `main` の `GlassCard` + ネオンシアン `#33F7FF` + `FuturisticBackground` に統一 | `main` のホーム画面は既にこの意匠で作り込まれており、feature側のフラットな Material `Card` のままだと同じ画面内で2つのデザイン言語が混在してしまう |
| 3 | データ取得元 | `MockScreenTimeService` / `MockAiCommentaryService` を維持 | Supabase実装(`screen_time_daily`/`screen_time_apps`/`ai_reviews`)は別タスクとして切り出し、今回は「カードの統合」にスコープを絞る |
| 4 | 表記ゆれ | 「ドバガキ」→「ドパガキ」に統一 | `main` のUI文言・[0005_screen_time_and_ai.sql](../supabase/migrations/0005_screen_time_and_ai.sql) の `dopagaki_score` 列名と一致させるため |

## 衝突ファイルの解消方針

| ファイル | 採用した側 | 理由 |
|---|---|---|
| `lib/main.dart` | main | dotenv読み込み・`Supabase.initialize`・ルーティングを失えない |
| `lib/models/child_profile.dart` | main | feature側は `{id, name}` のみの簡易版。main側は `groupCode`/`questItems`/`giftItems`/`points`/`avatarBytes` を持つ本実装 |
| `pubspec.yaml` / `pubspec.lock` | main | `supabase_flutter`/`flutter_dotenv`/`image_picker` を含む。feature側に追加依存は無く失うものがない |
| `test/widget_test.dart` | main | ログイン画面のテストに置き換え、スクリーンタイム側のテストは `test/screens/home_body_test.dart` として新設 |

## アーキテクチャ上の変更

feature側は `AppState extends ChangeNotifier` + `AppScope extends InheritedNotifier` で状態を配布していたが、main は `ChildRegistry`/`AppSession` のような **ChangeNotifierシングルトン + `addListener`/`setState`** の流儀で統一されている([lib/widgets/account_bar.dart](../lib/widgets/account_bar.dart) 参照)。

これに合わせ、`AppState` を廃止して `ScreenTimeRegistry`([lib/services/screen_time_registry.dart](../lib/services/screen_time_registry.dart))をシングルトンとして新設した。

- 子ども一覧・選択の保持は行わない。`ChildRegistry.instance`/`AppSession.instance` にそのまま委譲する
- `ScreenTimeService`/`AiCommentaryService`/`DopagakiCalculator` のインターフェースは無変更(Supabase実装への差し替え口をそのまま残すため)
- `ChildProfile` に `id` フィールドが無いため、キャッシュキーは `'${groupCode}/${name}'` の合成文字列にした
- サインアウト時のキャッシュ破棄は `SessionBridge.clear()` に `ScreenTimeRegistry.instance.clear()` を追加して対応

## 置き換えたカードの対応表

| main のプレースホルダー | 差し替え後 |
|---|---|
| `_DopamineIndexCard` | `DopagakiIndexCard`([lib/widgets/dopagaki_index_card.dart](../lib/widgets/dopagaki_index_card.dart)) |
| `_ScreenTimePlaceholderCard` | `ScreenTimeCard`(新規切り出し、[lib/widgets/screen_time_card.dart](../lib/widgets/screen_time_card.dart)) |
| `_AiCommentCard` | `AiCommentaryCard`([lib/widgets/ai_commentary_card.dart](../lib/widgets/ai_commentary_card.dart)) |

`ScreenTimeCard` は feature側で `parent_home_screen.dart` にインライン記述されていた「グラフ+アプリ別内訳」をウィジェットとして切り出したもの。他2枚と命名規則(`XxxCard`)を揃えている。

## 積み残し(次のタスク)

- `SupabaseScreenTimeService` の実装(`screen_time_daily`/`screen_time_apps` を読む)。`ScreenTimeService` インターフェースはそのまま使える
- `ai_reviews` テーブルと `AiCommentary` モデルのギャップ解消: DBは `dopagaki_score` + `comment`(単一text) + `model` を持つが、モデル側は `summary` + `adviceList: List<String>` + `generatedAt`。永続化するならどちらかを寄せる必要がある
- `AppUsage.color`/`isDistracting` はDBに対応列が無い(`app_id`/`app_label`のみ)。クライアント側のアプリカタログでのマッピング方針を決める
- `ai_reviews`/`activity_suggestions` の書き込みは service role キー(サーバー/Edge Functions)の責務。AI講評生成をどこで実行するか(Edge Function化)は未着手
