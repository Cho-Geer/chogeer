# 共通機能設計（基本設計）

| 項目 | 内容 |
|---|---|
| 文書ID | BD-11 |
| 版数 | V1.1（ドラフト・雛形準拠・2026-09-03 C-2 修订：A3 静的 Bearer Token 化） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（基本設計フェーズ・共通機能設計） |

## 1. 文書の位置づけと雛形対応

- 本書は基本設計八文書の一つ（BD-11）。Booking API の横断処理（認証・エラー・ログ・採番等）と連携で新たに必要になる横断規約を、雛形（交付物雛形集 4.12 共通機能設計）の 5 項目＋対応非機能要件ID で定義する。
- 雛形 5 項目＝各 CF の記載構成：共通機能ID・名称／提供方式／呼び出し規約／制約・禁止事項／対応非機能要件ID。
- 事実源は `booking-backend/src/` の実測（2026-08-31 読取：`src/common/guards/`・`src/modules/retention/`・`src/common/prisma/`）と chogeer の既存 Apex パターン（`force-app/main/default/classes/ShowcaseIntegrationRest.cls`・`ShowcaseContactSyncService.cls` 実測）である。🔵 は P0-2/P0-3/P0-4 計画（未実装）を示す。
- 機能設計（BD-03）は本書を引用して差分のみを記載する方針とする（雛形記載要点）。

## 2. 共通機能一覧

| 共通機能ID | 名称 | 提供方式 | 対応 NFR-ID | 状態 |
|---|---|---|---|---|
| CF-01 | 認証・認可 | フレームワーク機能（NestJS Guard・APP_GUARD グローバル登録） | NFR-04・NFR-05 | ✅（連携側拡張は 🔵） |
| CF-02 | トークン無効化 | ミドルウェア層の KVS（Redis ブラックリスト） | NFR-04 | ✅ |
| CF-03 | エラーレスポンス | フレームワーク機能（NestJS ExceptionFilter）＋SF 側標準 envelope パターン流用 | NFR-05・NFR-09 | ✅（Booking）／✅（連携・実装済 2026-09-02/09-03） |
| CF-04 | ログ出力 | フレームワーク機能（NestJS Logger）＋DB モデル（`ActivityLog`／`SystemLog`） | NFR-07 | ✅ |
| CF-05 | 採番（eventId・correlationId・commandId） | 共通生成ユーティリティ（連携モジュール内） | NFR-07 | ✅ 実装済（UUID v4・2026-09-02 確定〔CHK-02 C-8〕・IF-01/IF-02 実装に反映） |
| CF-06 | 日付・タイムゾーン処理 | フロント JST ユーティリティ（実装済）＋バックエンド UTC 規約 | NFR-07（間接・監査時刻整合） | ✅ 実態どおり（規約化は 🔵） |
| CF-07 | 保持・削除 | 共通モジュール（retention：CronJob＋Prisma deleteMany） | NFR-11・NFR-14 | ✅ |

## 3. 各共通機能の規約

### 3.1 CF-01：認証・認可（✅）

- 提供方式：`JwtAuthGuard`（APP_GUARD でグローバル・`skipJwtAuth` デコレータで個別解除・実測）＋`RolesGuard`／`AdminGuard`（`src/common/guards/` 実測）＋CSRF ミドルウェア（`CSRF_ENABLED=true` の場合のみ登録・実測）。
- 呼び出し規約：コントローラはガードを明示呼出せず、デコレータ（ロール指定・skip 指定）で宣言する。ロール判定は JWT 載荷の値でなく DB の現在値を毎回参照する（実測・降格/昇格検知あり）。
- 制約・禁止事項：**ガードを迂回した匿名端点の新設を禁止**（連携の Integration Guard も JWT ガードの迂回ではなく独立ガードとして実装する・BD-01 §4 A3。A3 の認証方式は C-2 修订 2026-09-03＝静的 Bearer Token 定数時間比較に変更・ガード独立性は維持）。フロント側の権限判定をセキュリティ境界とみなすことを禁止（REQ-014）。
- 対応 NFR：NFR-04（認証）・NFR-05（認可・最終裁定）。

### 3.2 CF-02：トークン無効化（✅）

- 提供方式：Redis ブラックリスト（トークン SHA-256 ハッシュを `blacklist:{hash}` キーで保存・`jwt-auth.guard.ts` 実測）。
- 呼び出し規約：ログアウト・ユーザー無効化・リフレッシュ失効の各処理がブラックリストへ登録し、ガード検証時に照合する。ユーザー状態変更時は全セッション取消（RULE-17・S-05 誘導と連動）。
- 制約・禁止事項：ロール変更時に既存セッションを取消さない現行仕様の無自覚な変更を禁止（P1 強化課題として別途管理・RULE-17）。ブラックリストの直接操作（正規 API 以外からの無効化）を禁止。
- 対応 NFR：NFR-04。

### 3.3 CF-03：エラーレスポンス（✅ Booking／✅ 連携・実装済）

- 提供方式：Booking 側は NestJS ExceptionFilter による統一 envelope（`ApiResponseDto`：code／message／data／requestId／timestamp・`api-contract.md` 実測）。SF 側は既存パターン `ShowcaseIntegrationRest.cls` の標準 envelope（success／statusCode／message／data／errors／requestId／timestamp・実測）を流用済み（BookingProjectionRest／BookingCommandQueueable・2026-09-02/09-03）。
- 呼び出し規約：Booking 側はコントローラから例外を throw し filter で統一変換する。連携の HTTP 状態区分（409＝業務競合・503/429/timeout＝一時的障害・401/403＝認証系）は BD-09 IF-02 §4.8 の区分に従い、Queueable／呼出側が同じ区分を共有する。
- 制約・禁止事項：エラー応答に PII・スタックトレース・secret を含めることを禁止。区分（409/503/401/403）を応答ごとに場当たり的に変えることを禁止（IF 契約との整合）。
- 対応 NFR：NFR-05（権限拒否 403 の統一挙動）・NFR-09（区分化によるテスト可能性）。

### 3.4 CF-04：ログ出力（✅）

- 提供方式：NestJS Logger（モジュール単位）＋DB モデル `ActivityLog`（利用者操作）／`SystemLog`（システム動作・level／message／context）（BD-07 §2.1 実測）。
- 呼び出し規約：利用者起点の操作は `ActivityLog` へ、周期ジョブ・システム判断は `SystemLog`／アプリログへ出力する。retention は実行サマリ（件数・所要時間）をログ出力する（実測）。連携トレースは `CorrelationId`（CF-05）をキーに横断追跡する（🔵）。
- 制約・禁止事項：**PII（氏名・電話・メール・WeChat・備考）をログへ平文出力することを禁止**（既知の既存盲点＝`bookings.service.ts:243` の電話番号出力は 2026-09-01 に是正済み（P0-2 契約内・マスキング適用）・BD-07 §5／BD-10 §3.6 に既録）。ログの無差別大量出力を禁止。
- 対応 NFR：NFR-07。

### 3.5 CF-05：採番（eventId・correlationId・commandId）（✅ 実装済・UUID v4）

- 提供方式：連携モジュール内の共通生成ユーティリティ（実装済・UUID v4・2026-09-02 確定〔CHK-02 C-8・§4 未決 1〕）。既存の先例パターンとして SF 側 `generateRequestId()`（`'REQ-' + 時刻 + 乱数`・`ShowcaseIntegrationRest.cls` 実測）がある。
- 呼び出し規約（設計値）：`eventId`／`correlationId` は Booking 側で UUID を生成し投影ペイロードへ設定（BD-09 §3.3）。`commandId` は Salesforce 側（Apex）で生成し `Booking_Command__c.CommandId__c` へ設定（TERM-12）。採番は両系統とも一意性のみ保証し、順序性を持たせない（順序制御は version ゲートの担当）。
- 制約・禁止事項：commandId の再発行（手動 Retry は原 commandId を使う＝RULE-10）・eventId の使い回し（別 version の変更に同一 eventId を使わない）を禁止。採番形式の変更は I/F 契約変更（BD-09 §5）を伴う。
- 対応 NFR：NFR-07（CorrelationId による監査トレース）。具体形式は UUID v4 に確定済み（2026-09-02・CHK-02 C-8・§4 未決 1）。

### 3.6 CF-06：日付・タイムゾーン処理（✅ 実態どおり・規約化は 🔵）

- **実態（実測の正直な記載）**：
  - フロントエンド：`booking-frontend/src/utils/timeUtils.ts` が **JST（Asia/Tokyo・`+09:00` 固定）** による予約期限判定ユーティリティを持つ（実測）。
  - バックエンド：`bookings.service.ts:841` が `toISOString().slice(0,10)`（**UTC 基準**）で予約番号の日付部を生成（実測）。`TZ` 環境変数・compose の TZ 設定は実測では見つからなかった。
  - DB：Prisma は日付を UTC で扱う。スキーマの日付項目は `@db.Date`（実測）。
  - Salesforce：標準挙動として DateTime は UTC 保存・表示はユーザーのタイムゾーン、日付項目は Date 型（BD-07 §3 の `AppointmentDate__c` は Date）。
- 呼び出し規約（🔵 規約化の設計値）：連携 I/F で扱う予約日付は **Date（日付のみ・タイムゾーンを持たない）** として授受し、時刻は時間枠の `HH:mm:ss` 文字列で表現する（BD-09 §3.3・IF 契約）。タイムスタンプ系（createdAt 等）は UTC で保持する。
- 制約・禁止事項：I/F ペイロードへローカルタイムゾーン付きの日時文字列を含めることを禁止（日付の解釈ずれ防止）。バックエンドの UTC 日付部生成と JST 表示の境界挙動（深夜予約の番号日付ずれ）は**既知の未確認点**として記録し、推定の動作断定を行わない（詳細設計・実装時に確認）。
- 対応 NFR：NFR-07（間接：監査・追跡の時刻整合に寄与）。

### 3.7 CF-07：保持・削除（✅）

- 提供方式：retention モジュール（`src/modules/retention/`・実測）：`RetentionScheduler`（cron 既定 `0 30 2 * * *`＝毎日 02:30）＋`RetentionService`（30 日経過の CANCELLED/COMPLETED を `deleteMany` で物理削除・バッチ 500 件・スリープ 200ms・dry-run・有効スイッチあり）。
- 呼び出し規約：周期実行は cron による自動起動。手動実行はスクリプト経由（NFR-11 の月次目視確認の入力）とする。削除対象の判定条件・基準時刻（cancelledAt/completedAt、null 時 updatedAt）はサービス実装に一元化し、他モジュールから直接 delete を書かせない。
- 制約・禁止事項：投影レコード（`Booking__c`）をクリーンアップ対象に含めることを禁止（G7・REQ-033・🔵）。保持日数 30 の無断変更を禁止（RULE-15 のパラメータ化対象・変更は RULE・本書の同時更新を要する）。
- 対応 NFR：NFR-11・NFR-14（個人情報の目的外保持防止）。

## 4. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-02】採番形式＝**UUID v4**（小文字・ハイフン付き 36 文字）。eventId・correlationId＝Booking 側生成（Node `crypto.randomUUID`／Prisma `uuid()`）・commandId＝Salesforce 側生成（Apex・S-5 実装時）。BD-09 §3.3/§4.3 の型列へ反映済み（CHK-02 C-8） | 決定済み（2026-09-02） |
| 2 | CF-06 のバックエンド UTC 日付部生成と JST 表示の境界挙動の確認（深夜予約） | 詳細設計・実装時（本書 §3.6 未確認点） |
| 3 | 【決定済 2026-09-02】干渉なし・免除構成の追加不要（CSRF middleware の Bearer 豁免が適用・`csrf.middleware.ts:32-36` 実測）。B-2 実装時に JwtAuthGuard の @Public 放行を確認（CHK-02 C-9） | 決定済み（2026-09-02） |
