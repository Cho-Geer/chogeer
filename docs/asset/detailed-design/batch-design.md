# バッチ設計書（詳細設計）

| 項目 | 内容 |
|---|---|
| 文書ID | DD-03 |
| 版数 | V1.0（ドラフト） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（詳細設計フェーズ・バッチ設計） |

## 1. 文書の位置づけと雛形対応

- 本書は詳細設計四文書の一つ（DD-03）。本システム（Booking System）に存在する周期処理（バッチ）をジョブ単位で定義する。対象は retention モジュールの 1 ジョブのみ（✅ 既存実装・稼働中）。Salesforce 側の非同期処理（Queueable）はバッチではなく非同期ジョブとして区別して §5 に記載する。
- 雛形（交付物雛形集 5.3 バッチ設計書）の 8 項目＝§3 のジョブ定義表：ジョブ ID/名称／起動契機・スケジュール／処理フロー／対象データ・件数／処理時間見積／リラン・冪等性／異常時通知／依存ジョブ。
- 事実源（実測）：`booking-backend/src/modules/retention/retention.scheduler.ts`・`retention.service.ts`（2026-08-31 読取）。要件・ルールの引用元：REQ-032（保持）・REQ-033（投影は対象外）・RULE-15（30 日保持）・BIZ-16・NFR-11（周期実行・月次目視確認）・NFR-14（目的外保持防止）・CF-07（保持・削除の共通機能）。
- 状態表記：✅＝既存実装（コード実測）｜🔵＝P0 計画（未実装）｜⚪＝P1。

## 2. バッチ一覧

| ジョブ ID | 名称 | 起動契機 | 状態 |
|---|---|---|---|
| retention-delete-expired | 予約期限切れデータ削除 | 日次スケジュール（毎日 02:30・既定） | ✅ 既存実装 |

本システムのバッチは上記 1 件のみである。連携スライス（P0-3/P0-4）で追加する周期処理は存在しない（§5 の対象外参照）。

## 3. ジョブ定義：retention-delete-expired（✅ 実測）

### 3.1 ジョブ ID・名称

| 項目 | 内容 |
|---|---|
| ジョブ ID | `retention-delete-expired`（本設計書の管理 ID） |
| 名称 | 予約期限切れデータ削除（30 日保持・ハードデリート） |
| 実装上の登録名 | SchedulerRegistry の cron ジョブ名 `retentionCleanupJob`（実測・`retention.scheduler.ts`）。管理 ID と実装登録名が異なる点に留意 |
| 対応要件・ルール | REQ-032・RULE-15・BIZ-16・NFR-11・NFR-14（CF-07 の実装） |

### 3.2 起動契機・スケジュール

| 項目 | 内容（実測） |
|---|---|
| 契機 | 日次タイマー。`ScheduleModule` の `onModuleInit` で `CronJob` を `SchedulerRegistry` に登録し自動起動（`retention.scheduler.ts` 実測。**@Cron デコレータではなく `cron` パッケージの `CronJob` クラスを使用**） |
| cron 式 | 既定 `0 30 2 * * *`＝**毎日 02:30**（JST ではないサーバローカル時刻。`RETENTION_CRON` 環境変数で変更可・実測） |
| 有効スイッチ | `RETENTION_ENABLED`（既定 `true`。`'0'/'false'/'off'/'no'` 以外は有効と判定・実測）。無効時はジョブ自体がスキップ（ログ出力のみ） |
| 手動実行 | dry-run／実行は手動スクリプト経由（NFR-11 の月次目視確認の入力） |

### 3.3 処理フロー（実測）

```
開始
 ├─ RETENTION_ENABLED 判定（無効ならスキップ・ログ出力）
 ├─ 対象抽出条件の組立（buildWhere・cancelledAt/completedAt 基準）
 ├─ matchedAppointments = count（対象件数の事前計数）
 └─ 繰返し処理（runExecute）
     ├─ findMany（対象から id のみ・updatedAt 昇順・id 昇順・take=バッチ件数）
     ├─ 0 件なら終了
     ├─ deleteMany（id IN バッチ内 id）
     ├─ 削除件数を累計
     └─ バッチ間スリープ（既定 200ms・0 ならスキップ）→ 繰返し
 └─ 実行サマリ（mode・cutoff・days・batchSize・matched・deleted・durationMs）を
     アプリログ（NestJS Logger）へ出力
```

**コミット単位**：`deleteMany` 1 回を 1 バッチ（既定 500 件）とし、バッチ間 200ms のスリープで負荷を平準化する（実測）。途中失敗時は当該バッチの未完了分が残り、リランで回収される（§3.6）。

注記（実測の正直な記載）：処理フロー末尾の「記録」は **アプリログ（NestJS Logger）へのサマリ出力**であり、`ActivityLog` テーブルへの書込みは retention モジュールに存在しない（`retention.service.ts`・`retention.scheduler.ts` 実測・BD-10 §5.1 の「実行サマリをアプリログへ出力」と一致）。連携監査用の `ActivityLog` 書込みは 2026-09-01 拍板で P1 強化項と決定（P0 はアプリログ出力のみ）。

### 3.4 対象データ・件数

| 項目 | 内容（実測口径） |
|---|---|
| 対象テーブル | `appointments`（BD-07 §2.2・DD-01 §2.4）。`Appointment` モデル |
| 対象条件 | OR 2 系統（`retention.service.ts` の `buildWhere` 実測）：<br>① `status = CANCELLED` かつ（`cancelled_at < cutoff` または `cancelled_at IS NULL AND updated_at < cutoff`）<br>② `status = COMPLETED` かつ（`completed_at < cutoff` または `completed_at IS NULL AND updated_at < cutoff`） |
| 保持期限 | `RETENTION_DAYS`（既定 **30 日**・`getRetentionDays()` 実測。非正値は既定 30 へフォールバック）。cutoff = 現在日時 − 30 日 |
| バッチ件数 | `RETENTION_BATCH_SIZE`（既定 **500 件**・`getBatchSize()` 実測）。バッチ間スリープ `RETENTION_BATCH_SLEEP_MS`（既定 **200ms**） |
| 連鎖削除 | 削除対象予約に Cascade で紐づく `appointment_history`・`notifications` も連鎖削除（明示 onDelete: Cascade・DD-01 §2.14） |
| 投影レコード | **`Booking__c`（Salesforce 側投影）はクリーンアップ対象外**（REQ-033・RULE-15 の G7 決定事項）。削除済み予約への遅延コマンドは 404/409 でフォールバック（🔵 設計値） |
| 件数（デモ規模） | 対象は 0〜数件（RD-07 §3・RD-03 BIZ-16 のデモ見込み）。総量数十件のうち期限経過分のみ |

### 3.5 処理時間見積

| 項目 | 内容 |
|---|---|
| 見積方針 | **実測は未実施**（正直な記載）。デモ規模（対象 0〜数件・バッチ 500 件）では全処理が数秒以内で完了する見込み |
| 計算根拠 | デモ規模では 1 バッチ未満（500 件に達しない）のため、findMany＋deleteMany＋サマリ出力のみ。バッチ間スリープは 1 回未満で発生しない |
| ウィンドウ | 02:30 の日次実行が 1 回のみ。夜間ウィンドウの制約は存在しない（単一構成・デモ・NFR-10） |
| 注意 | 対象が 500 件を超える場合のみバッチ分割と 200ms スリープが発生するが、デモ規模では発生しない |

### 3.6 リラン・冪等性（必須記載）

- **リラン安全**：`deleteMany` は現在の条件（CANCELLED/COMPLETED・期限経過）を満たすレコードのみを削除する。**既に削除済みのレコードは再選択されない**ため、同一ジョブの再実行は追加の副作用を生まない（冪等）。
- 部分失敗時のリラン：バッチ単位の失敗で未削除分が残った場合も、次回実行（翌日 02:30 または手動実行）が残存対象のみを処理する。重複削除・二重副作用は発生しない。
- 手動実行時の注意：`matchedAppointments`（事前計数）は実行時のスナップショットであり、実行直前に他処理が削除した場合は実削除件数と差異が出るが、これは正常挙動（冪等性を損なわない）。
- **dry-run モード実装済**：`RETENTION_DRY_RUN=true`（既定 false・`isDryRunEnabled()` 実測）で対象件数のみ計数し削除しない（`runDry()` 実測）。本番前確認・月次目視確認の入力として利用する（NFR-11）。

### 3.7 異常時通知

- **通知機構は未整備**（正直な記載）：失敗時は `RetentionScheduler.handleDailyRetention` が例外を捕捉し、エラーログ（`Retention cleanup failed`＋スタック）を出力するのみ（実測）。メール・Webhook 等の自動通知・自動告警は存在しない（REQ-037 の告警は P1 保留・RD-03 BIZ-16 は月次目視確認で担保）。
- デモ運用では月 1 回の削除ログ／件数の目視確認（NFR-11）と、ジョブ未実行の確認（削除対象が残っている・`updated_at` が古い予約の存在チェック等）を開発者本人が行う。

### 3.8 依存ジョブ

- **なし**。前置・後続ジョブは存在しない。日次実行が独立して完結する（retention 実行と他ジョブの順序依存なし）。

## 4. 設定パラメータ一覧（実測）

| 環境変数 | 既定値 | 説明 | 出典 |
|---|---|---|---|
| `RETENTION_CRON` | `0 30 2 * * *` | cron 式（毎日 02:30） | retention.scheduler.ts |
| `RETENTION_ENABLED` | `true` | 有効スイッチ | retention.service.ts |
| `RETENTION_DAYS` | `30` | 保持日数（RULE-15 のパラメータ化対象） | 同上 |
| `RETENTION_BATCH_SIZE` | `500` | 1 バッチの削除件数 | 同上 |
| `RETENTION_BATCH_SLEEP_MS` | `200` | バッチ間スリープ | 同上 |
| `RETENTION_DRY_RUN` | `false` | dry-run モード（対象計数のみ） | 同上 |

## 5. バッチ一覧と対象外（非同期ジョブ・P1 計画との区別）

| 種別 | 対象 | 取扱い |
|---|---|---|
| バッチ（日次周期） | retention-delete-expired（§3） | 本システムのバッチは本件のみ |
| 非同期ジョブ（Apex Queueable） | `BookingCommandQueueable`（TERM-22） | **バッチではない**。コマンド受理時に `System.enqueueJob` で起動する非同期ジョブであり、日次周期実行を持たない（BD-01 §2 注記・DD-02 §3.2）。P0-3 計画（🔵 未実装） |
| Outbox／Worker | 正本変更と連携イベントの同トランザクション記録・確実配信 | **P1 将来項**（REQ-037・F-33・TERM-34）。P0 では直接呼出＋有限リトライ＋手動 Retry のため、Worker ジョブは存在しない |
| 周期対合・指標告警 | 投影/コマンドの乖離確認・異常検知 | **P1 将来項**（REQ-037・F-33・BD-02 §5 注記）。P0 では実施しない |
| Salesforce 側 Batch クラス | `Account_batchable` 等（既存 showcase 資産） | **本連携のバッチ対象外**。F-33（信頼性配信・対合・告警）は P1・本件スコープ外（RD-07 §4・BD-02 §6）であり、既存 Batch 資産を連携に追加利用しない（「Trigger／Batch／Email Service 等の技術要素追加は行わない」＝RD-07 §4 No.6） |
| キャッシュ／統計集計 | — | 予約統計（AppointmentStatistic）等の集計ジョブは存在しない（統計はリクエスト時集計・api-contract.md 実測） |

非機能要件との承接：本ジョブは NFR-11（周期実行・月次目視確認）・NFR-14（個人情報の目的外保持防止）・RULE-15（30 日保持）・REQ-033（投影レコードは対象外）を実装側で充足する。性能は NFR-01〜03 の対象外（周期バッチはオンライン性能目標の対象外とし、バッチ負荷は 200ms スリープで平準化）。

## 6. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】P1 強化項（P0 はアプリログ出力のみ継続・実測変更なし） | 決定済み（2026-09-01・P1） |
| 2 | 異常時通知（自動告警）の導入 | P1（REQ-037・告警は P1 保留） |
| 3 | 保持日数 30 のパラメータ変更時のルール（RULE-15 のパラメータ化対象）と本書の同時更新手順 | 変更発生時 |
