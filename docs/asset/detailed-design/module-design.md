# モジュール設計書（詳細設計）

| 項目 | 内容 |
|---|---|
| 文書ID | DD-02 |
| 版数 | V1.0（ドラフト） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（詳細設計フェーズ・モジュール設計） |

## 1. 文書の位置づけと対象範囲

- 本書は詳細設計四文書の一つ（DD-02）。基本設計 BD-03『機能設計書』（F-20〜F-26）と BD-01『システム構成図』（モジュール構成・認証境界 A1〜A4）を受け、**P0 で新規追加するモジュールを実装級（クラス・メソッド・呼び出し関係）に展開**する。既存モジュール（✅）は機能設計との重複を避けるため一覧＋コード正本の引用に留め、本文では展開しない（BD-03 §2 と同一口径）。
- 雛形（交付物雛形集 5.2 モジュール設計書）の 7 項目＋命名・職責＝各モジュール節の構成：モジュール/クラス名・命名と職責／メソッド名・引数・戻り値／処理概要／呼び出し関係／例外処理／使用 SQL（Prisma クエリ要点または SOQL）／対応機能 ID。
- 状態表記：✅＝既存実装（コード実測）｜🔵＝P0 計画（未実装・設計値）。**本書の P0 新規モジュールはすべて 🔵 設計値（未実装）** であり、実装は P0-3／P0-4 を予定する。
- クラス名の規約：BD-03・BD-01・RD-06（TERM）等の既存文書に既出の名前のみを正式名として使用する。既出でない名前は「計画名（設計値・本書限りの管理名）」と明記し、正式確定は P0-3 とする。Integration Guard のクラス名は TERM-23 のとおり「P0-3 で確定」。
- 対応機能 ID：BD-02 の F-20〜F-26・F-32 を引用する（新規の機能 ID は製造しない）。

## 2. Booking 側 P0 新規モジュール（🔵 設計値・未実装）

### 2.1 Integration Guard（A3 サービス認証）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | **クラス名は P0-3 で確定**（TERM-23 のとおり）。本書では「Integration Guard」と表記。配置は `src/common/guards/`（既存ガード群と同じ） |
| 命名と職責 | サービス間認証（A3）の検証。secret の鍵バージョン・audience・scope=`booking.integration.command`・時刻偏差を検証し、統合端点への呼出が「正しいシステムからの呼出」であることを担保する（REQ-029・BD-01 §4 A3） |
| メソッド名・引数・戻り値 | `canActivate(context: ExecutionContext): Promise<boolean>`（NestJS CanActivate 規約）。内部ヘルパー：`verifySignature(header: string, payload: unknown): Promise<boolean>`・`verifyClaims(payload: JwtPayload): boolean`（設計値） |
| 処理概要 | 1) Authorization ヘッダの Bearer token を取得。2) secret の鍵バージョン照合。3) 署名検証（secret は環境変数／secret 管理・P0-3 で確定）。4) audience が自環境の想定値と一致。5) scope に `booking.integration.command` を含む。6) 時刻偏差（例：±数分・具体値は P0-3）以内。すべて合格で true、不合格で 401/403 を返す |
| 呼び出し関係 | 呼出元：統合端点（BookingCommandsController §2.2）のルートにガードとして登録。呼出先：なし（設定値のみ参照）。既存の `JwtAuthGuard`（APP_GUARD）とは独立したガードであり、**JWT ガードを迂回した匿名端点としてではなく独立ガードで保護する**（CF-01 の制約・BD-10 §3.2） |
| 例外処理 | 検証 NG 時に `AuthenticationException`（401）／`AuthorizationException`（403）を throw（実在クラス・`src/common/exceptions/business.exceptions.ts`）。業務状態遷移・コマンド状態は一切変更しない（RULE-14 注記・MV-11）。CSRF ミドルウェアとの干渉は BD-11 未決事項 3 として確認対象 |
| 使用 SQL | なし（SQL・Prisma クエリを使用しない） |
| 対応機能 ID | F-25（IF-02 の A3 認証・NFR-04） |

### 2.2 BookingCommandsController（統合端点受付）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | `BookingCommandsController`（計画名・設計値。本書限りの管理名であり、既存文書には未出。正式確定は P0-3）。ルーティング `POST /v1/integrations/salesforce/booking-commands`（BD-09 §4.2） |
| 命名と職責 | 統合端点の HTTP 受付層。Integration Guard 通過後、リクエストボディの入力検証（DTO 検証）を行い、業務処理を BookingsIntegrationService（§2.3）へ委譲する。HTTP 層の関心事（ステータス・envelope）のみを担う |
| メソッド名・引数・戻り値 | `receiveCommand(@Body() dto: BookingCommandRequestDto): Promise<ApiResponseDto<BookingCommandResultDto>>`（設計値）。DTO 項目は IF-02 §4.3 の 6 項目：`commandType`（CANCEL_BOOKING 固定）・`commandId`・`bookingExternalId`・`expectedVersion`・`requestedBySalesforceUserId`・`correlationId` |
| 処理概要 | 1) Integration Guard で A3 検証（§2.1）。2) DTO 検証（commandType=CANCEL_BOOKING 以外は ValidationException・RULE-13）。3) BookingsIntegrationService.executeCancelCommand() を呼出。4) 応答を `ApiResponseDto` envelope（code/message/data/requestId/timestamp・api-contract.md 実測）で返す。200 時は `canonicalVersion`＋`resultCode`、409 時は `currentVersion`＋`correlationId` |
| 呼び出し関係 | 呼出元：BookingCommandQueueable（SF 側・Named Credential）。呼出先：BookingsIntegrationService。ガード：Integration Guard |
| 例外処理 | throw は Service 層の例外を伝播。400＝`ValidationException`・404＝`ResourceNotFoundException`（削除済み予約宛・REQ-033）・409＝`ResourceConflictException`／`BusinessRuleException`・401/403＝ガード層。`ApiResponseDto` 変換は既存のグローバル ExceptionFilter（`src/common/filters/global-exception.filter.ts` 実測）に委ね、HTTP 状態区分は BD-09 §4.8 の区分（409/503/401/403）と整合させる（CF-03） |
| 使用 SQL | なし（Service 層へ委譲） |
| 対応機能 ID | F-25 |

### 2.3 BookingsIntegrationService（コマンド業務判定・正本更新）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | `BookingsIntegrationService`（計画名・設計値。本書限りの管理名・正式確定は P0-3）。配置は `src/modules/integrations/`（新規モジュール・P0-3 で AppModule へインポート） |
| 命名と職責 | 統合コマンドの業務判定と正本更新の中核。BD-03 §8.4 の検証順序（2〜7）を実装し、同一トランザクションで正本を CANCELLED に更新する（REQ-022・RULE-02/03/05/07/12） |
| メソッド名・引数・戻り値 | `executeCancelCommand(dto: BookingCommandRequestDto): Promise<BookingCommandResult>`（設計値）。戻り値：`BookingCommandResult`＝`{ httpStatus, canonicalVersion?, resultCode?, currentVersion? }`（IF-02 §4.3 応答に対応） |
| 処理概要 | 1) **commandId 冪等判定**：同一 commandId の既処理があれば初回保存済み結果をそのまま返す（RULE-03・業務判定より先行）。冪等結果の保存先＝**integration_commands テーブル（第 14 モデル・DD-01 §2.15）【決定済 2026-09-01】**。RULE-08 正本更新と同一トランザクションで create（応答キャッシュ案は否決）。2) 静的マッピング検証：`requestedBySalesforceUserId` → Booking ユーザーが存在し、現在 ADMIN かつ ACTIVE（RULE-12）。3) 予約定位：`bookingExternalId` で正本を特定。不存在は 404。4) 状態遷移検証：PENDING/CONFIRMED のみ受理（RULE-05/07）。5) バージョンゲート：`expectedVersion != 正本現在 version` は 409＋currentVersion（RULE-02）。6) 全検証合格時、**同一トランザクションで**正本 status=CANCELLED・`version+1`・`syncStatus=PENDING`・`cancelledAt=now()` を更新（RULE-08）。7) 200＋canonicalVersion＋resultCode を返す |
| 呼び出し関係 | 呼出元：BookingCommandsController。呼出先：PrismaService（`src/common/prisma/prisma.service.ts` 実測）。呼出しを受けた正本変更は投影送信サービス（§2.4・IF-01）の契機となる（RULE-08・トランザクション後の分離呼出） |
| 例外処理 | 検証 NG を throw：404＝`ResourceNotFoundException`・409＝`ResourceConflictException`（バージョン不整合）／`BusinessRuleException`（状態遷移 NG）・403＝`AuthorizationException`（マッピング不存在/inactive・非 ADMIN/ACTIVE・RULE-12）。**エラー区分の 409/503 分類は RULE-09 のとおり**：409＝リトライせず CONFLICT、503/429/timeout＝一時的障害（SF 側でリトライ）。DB 例外はロールバック（検証〜正本更新の同一トランザクション・途中失敗は全てロールバック・BD-03 §8.6） |
| 使用 SQL | Prisma クエリ要点（設計値）：正本取得 `appointment.findUnique({ where: { id } })`（External ID は uuid `id` に決定済・2026-09-01 拍板。定位は `findUnique({ where: { id } })` で確定・BD-09 §5 未決 1 は同日クローズ）／静的マッピング取得 `salesforceUserLink.findFirst({ where: { salesforceUserId, active: true } })`（P1 の SalesforceUserLink＝動的 provisioning とは別物。P0 では静的マッピング設定テーブルを想定・命名は P0-3 で確定。実装方式は Prisma モデル vs 設定ファイルの未決・BD-03 §4.9）／正本更新 `appointment.update({ where: { id }, data: { status: 'CANCELLED', version: { increment: 1 }, syncStatus: 'PENDING', cancelledAt: new Date() } })`。**排他の考え方**：コマンド経路では P2034 直列化リトライを導入せず、version ゲート（RULE-02）が楽観的排他を担う（BD-03 §8.6 の「層の異なる補完」に整合。P2034 は既存の予約作成フロー＝在庫競合対策として残る）／冪等判定・記録：`integrationCommand.findUnique({ where: { commandId } })`／同一トランザクション内 `integrationCommand.create({ commandId, httpStatus: 200, resultCode, canonicalVersion, ... })`（DD-01 §2.15・【決定済 2026-09-01】） |
| 対応機能 ID | F-25（REQ-022/023/024/026/027・RULE-02/03/05/07/12） |

### 2.4 投影送信サービス（IF-01 呼出）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | 投影送信サービス（計画名は P0-3 で確定。本書では機能名で表記）。配置は `src/modules/integrations/`（§2.3 と同一モジュール内のサービス） |
| 命名と職責 | 予約正本の変更（作成・変更・キャンセル全て＝顧客自身の標準取消を含む）を、IF-01 で Salesforce 側 `Booking__c` へ冪等投影する（F-20・REQ-018）。ペイロード生成は投影ホワイトリスト（RULE-11・契約凍結）のみに限定し、PII 5 項目を構造的に含めない（REQ-019・BD-03 §3.5） |
| メソッド名・引数・戻り値 | `projectBooking(appointmentId: string): Promise<ProjectionResult>`（設計値）。内部ヘルパー：`buildPayload(appointment): ProjectionPayload`（ホワイトリスト 9 項目・BD-09 §3.3）・`sendProjection(payload): Promise<HttpResponse>`（OAuth JWT Bearer 呼出・A2）・`updateSyncStatus(appointmentId, status)`。戻り値：`ProjectionResult`＝`{ eventId, acceptedVersion?, syncStatus }` |
| 処理概要 | 1) 正本変更トランザクション確定後に呼出（トランザクション内で version+1・syncStatus=PENDING 済・RULE-08）。2) eventId・correlationId を採番（CF-05・UUID・設計値）。3) ホワイトリストのみからペイロード生成。4) OAuth 2.0 JWT Bearer（Connected App・A2・TERM-20）で `POST /services/apexrest/integrations/bookings/projection` を呼出。5) 応答判定：受理（初回・より新しい version）→ `syncStatus=SYNCED` 更新。拒否・認証系・一時的障害 → `syncStatus=ERROR` 記録（BD-09 §3.8）。6) 手動 Retry（同一 eventId）は BIZ-15 手順に依拠（Retry UI は P1 保留） |
| 呼び出し関係 | 呼出元：既存の正本変更処理（bookings モジュールの作成/変更/取消・F-06〜F-08）と BookingsIntegrationService（§2.3・コマンド取消）のトランザクション確定後。呼出先：Apex REST（BookingProjectionRest・§3.1）。OAuth クライアント依存は P0-3 で新規導入（現状 package.json に HTTP クライアント・OAuth 依存なし＝実測） |
| 例外処理 | 呼出失敗（ネットワーク・503・timeout・401/403）を throw せず `syncStatus=ERROR` として記録し、正本の整合は損なわない（IF-01 呼出はトランザクション外・BD-03 §3.6）。旧バージョン拒否は恒久的（単調増加のため再送不可）なため ERROR 記録＋原因分析の対象（BD-09 §3.8）。PII 混入はペイロード生成関数のホワイトリスト制限により構造的に防止（設計値） |
| 使用 SQL | Prisma クエリ要点（設計値）：投影対象読取 `appointment.findUnique({ where: { id }, include: { timeSlot: true, service: true } })`／syncStatus 更新 `appointment.update({ data: { syncStatus: 'SYNCED' | 'ERROR' } })` |
| 対応機能 ID | F-20（REQ-018/019/024/029/033・IF-01） |

## 3. Salesforce 側 P0 新規モジュール（🔵 設計値・未実装）

### 3.1 BookingProjectionRest（投影受入口・TERM-24）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | `BookingProjectionRest`（既出・TERM-24・BD-01 §6）。`@RestResource(urlMapping='/integrations/bookings/projection')`・`global with sharing class`（設計値）。URL：`POST /services/apexrest/integrations/bookings/projection` |
| 命名と職責 | Booking からの投影を受ける Apex REST 入口。External ID 定位の Upsert・バージョンゲート（RULE-01）・eventId 冪等（RULE-04）を適用し、`Booking__c` canonical 項目を更新する。**Booking__c の唯一の書込入口**（BD-07 §3 境界制約） |
| メソッド名・引数・戻り値 | `@HttpPost global static String receiveProjection(ProjectionRequest request)`（設計値）。`ProjectionRequest`＝IF-01 §3.3 の 9 項目（BookingExternalId・AppointmentNumber・AppointmentDate・TimeSlot・ServiceName・Status・version・eventId・correlationId）。戻り値は標準 envelope（success/statusCode/message/data/errors/requestId/timestamp・ShowcaseIntegrationRest.cls の `ApiResponse` 実測を流用） |
| 処理概要 | 1) 入力検証（必須 9 項目・`validateRequest` パターン流用）。2) 外部ID で `Booking__c` を `FOR UPDATE` ロック取得（並行初回投影・MV-06）。3) **eventId 冪等判定（RULE-04）を version ゲート（RULE-01）に先行して実施する**：`LastEventId__c` と同一の eventId 再送（同 version・同一 eventId を含む）は初回受理結果をそのまま返し、レコードを更新しない（TC-02 と整合）。4) バージョンゲート：`incomingVersion <= CurrentVersion__c` は拒否応答（RULE-01・等号含む・初回 insert は比較対象外）。5) 全項目をホワイトリスト対応項目のみから Upsert（insert/update）。6) `eventId`・受理後 `CurrentVersion__c` を応答 |
| 呼び出し関係 | 呼出元：Booking 投影送信サービス（§2.4・A2 OAuth JWT Bearer）。呼出先：`Booking__c`（SOQL/DML）。レスポンス header 設定・入力検証・例外ハンドリングは `ShowcaseIntegrationRest.cls` の実測パターンを流用 |
| 例外処理 | `ValidationException`（400）／`ConcurrencyException` 相当（旧 version 拒否・409 系の競合応答）／`DataAccessException`（500）／予期せぬ例外（500）を、ShowcaseIntegrationRest の `handleXxxException` パターンで標準 envelope へ変換（設計値）。**PII は応答に含めない** |
| 使用 SQL | SOQL 要点（設計値）：`SELECT Id, CurrentVersion__c, LastEventId__c, SyncStatus__c, CorrelationId__c, LastError__c FROM Booking__c WHERE BookingExternalId__c = :extId FOR UPDATE`＋`WITH SECURITY_ENFORCED`（ShowcaseIntegrationRest の `queryUsersByIds` 実測パターン流用）。Upsert は `Database.upsert(records, Booking__c.BookingExternalId__c, false)`（部分成功許容） |
| 対応機能 ID | F-20（IF-01 受入側） |

### 3.2 BookingCommandQueueable（コマンドバックグラウンド実行・TERM-22）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | `BookingCommandQueueable`（既出・TERM-22・BD-01 §6）。`global class BookingCommandQueueable implements Queueable`（設計値） |
| 命名と職責 | コマンドのバックグラウンド実行。Named Credential（`Booking_Integration_API`・TERM-21 計画名）で Booking 統合端点を呼出し、応答に応じて `Booking_Command__c` の状態・監査フィールドを更新する。**Queueable は正本 canonical 状態を直接書かない**（BD-07 §3 境界制約） |
| メソッド名・引数・戻り値 | `global void execute(QueueableContext context)`（Queueable 規約）。コンストラクタで `Booking_Command__c.Id`・`commandId`・`bookingExternalId`・`expectedVersion`・`requestedBySalesforceUserId`・`correlationId` を受け取る（設計値）。内部ヘルパー：`sendCommand(): HttpResponse`・`handleResponse(HttpResponse)`・`recordAttempt(...)` |
| 処理概要 | 1) コマンド実行開始：`Status__c=RUNNING` 更新。2) Named Credential で `POST /v1/integrations/salesforce/booking-commands` を呼出（IF-02・6 項目ペイロード）。**HttpRequest タイムアウト 10 秒**（`ShowcaseContactSyncService.cls` の `setTimeout(10000)` 実測を踏襲・BD-09 §4.2）。3) 応答区分（RULE-09/14）：200→`SUCCEEDED`＋結果書き戻し（§3.1 経由・F-26）／409→`CONFLICT`（リトライせず）／401/403→終状態を書込まずエラー記録のみ／503/429/timeout→`AttemptCount__c+1`・`NextAttemptAt__c`・`LastError__c` 記録し、上限内で同一 commandId 再実行（上限到達で `FAILED`）。4) `HttpStatus__c`・`ResultCode__c`・`ResultVersion__c` を記録（REQ-031）・ResultCode__c 値域＝CD-12（7 値封闭集・【決定済 2026-09-01】） |
| 呼び出し関係 | 呼出元：BookingSiteController（§3.3）が `System.enqueueJob(new BookingCommandQueueable(...))`（コマンド生成トランザクション内・BD-03 §7.4）。呼出先：Booking 統合端点（Named Credential）。結果書き戻し時は投影入口（§3.1）を再利用（F-26・専用直書込経路を作らない） |
| 例外処理 | Callout 例外（`CalloutFailureException` 流用・ShowcaseContactSyncService 実測）・タイムアウトを捕捉し、終状態判定（RULE-14：明示 200/409 のみ）に従って状態・監査フィールドを更新。Queueable 内で捕捉するため例外は上流へ伝播しない。再 throw する場合は `AsyncApexJobs` に失敗記録が残る点に留意（設計値） |
| 使用 SQL | SOQL/DML 要点（設計値）：コマンド取得 `SELECT Id, CommandId__c, Status__c, AttemptCount__c, ... FROM Booking_Command__c WHERE Id = :id`／更新 `update cmd`（Status__c・AttemptCount__c・HttpStatus__c・NextAttemptAt__c・ResultCode__c・ResultVersion__c・LastError__c・CorrelationId__c） |
| 対応機能 ID | F-25（REQ-022/023/027/028/029/031・IF-02） |

### 3.3 BookingSiteController（Site 用コントローラ・TERM-25）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | `BookingSiteController`（既出・TERM-25・BD-01 §6）。`global with sharing class`（設計値）。LWC の AuraEnabled メソッドを提供 |
| 命名と職責 | Site の LWC から参照・コマンド送信を受ける Apex コントローラ。with sharing＋CRUD/FLS 最小権限で自 Account の投影を照会し、取消コマンドを生成する（F-23・F-24・RULE-13）。LWC からの直接 SOQL は行わない |
| メソッド名・引数・戻り値 | `@AuraEnabled(cacheable=true) public static List<Booking__c> getProjections()`（自 Account の投影一覧・設計値）／`@AuraEnabled public static CommandResponse submitCancel(String bookingExternalId, Integer expectedVersion)`（コマンド生成・commandId/QUEUED 即時返却・設計値）／`@AuraEnabled(cacheable=true) public static CommandStatus getCommandStatus(String commandId)`（ポーリング・設計値） |
| 処理概要 | 1) `getProjections`：外部ユーザーの `AccountId`（User から取得）で `Booking__c` を絞り込み（行級範囲は OWD Private＋Sharing Set・NFR-06）。2) `submitCancel`：CANCELLED/COMPLETED の投影は事前抑制（ボタン無効・最終判定は Booking 側 409）のうえ、`Booking_Command__c` を insert（CommandId__c 採番・ExpectedVersion__c＝送信時 CurrentVersion__c・Status__c=QUEUED・要求者）し、同一トランザクションで Queueable をエンキュー。commandId／QUEUED を返す（NFR-03・2 秒以内）。3) `getCommandStatus`：`Booking_Command__c.Status__c` を返す |
| 呼び出し関係 | 呼出元：Site LWC（§3.4）。呼出先：`Booking_Command__c`（insert/update）・BookingCommandQueueable（エンキュー）・`Booking__c`（照会）。要求者の特定はブラウザ申告 ID ではなく静的マッピング検証に委ねる（実行時検証は F-25・RULE-12） |
| 例外処理 | 権限・行級判定の拒否：コマンド生成前に終了（レコード残さず・MSG-03 相当）。取得 0 件：空一覧（MSG-01 相当）。データ取得エラー：`AuraHandledException` 等で LWC へエラー表示（MSG-02 相当・設計値）。メッセージ文面の最終値は P0-4（BD-03 未決事項 3） |
| 使用 SQL | SOQL 要点（設計値）：`SELECT Id, BookingExternalId__c, AppointmentNumber__c, AppointmentDate__c, TimeSlot__c, ServiceName__c, Status__c, CurrentVersion__c, SyncStatus__c FROM Booking__c WHERE Account__c = :accountId WITH SECURITY_ENFORCED`／`SELECT Id, Status__c FROM Booking_Command__c WHERE CommandId__c = :commandId` |
| 対応機能 ID | F-23（照会）・F-24（コマンド受付） |

### 3.4 Site LWC（予約リスト・取消・状態ポーリング・TERM-33）

| 項目 | 内容 |
|---|---|
| モジュール/クラス名 | LWC バンドル（**バンドル名は P0-4 着手時に確定**・BD-03 §6.9 未決事項 1）。構成：予約リスト表示コンポーネント＋取消ボタン＋コマンド状態ポーリング（設計値） |
| 命名と職責 | 外部ユーザー向けの読取専用予約投影一覧と、取消コマンド送信・結果確認の UI。JS controller（`.js`）は BookingSiteController（§3.3）の AuraEnabled メソッドを `@wire`／`import` で呼出し、直接の DML を行わない |
| メソッド名・引数・戻り値 | JS controller 要点（設計値）：`getProjections()`（`@wire` で投影一覧取得）／`handleCancel(event)`（対象の BookingExternalId__c・CurrentVersion__c を渡し submitCancel 呼出）／`pollStatus(commandId)`（getCommandStatus をポーリング。間隔・最大継続時間は P0-4 で確定・BD-03 §7.9） |
| 処理概要 | 1) ロード時に自 Account の投影一覧を表示（読取専用）。2) 取消可能状態（PENDING/CONFIRMED）のみ取消ボタンを有効化（CANCELLED/COMPLETED は無効・BD-03 §6.9 未決事項 2）。3) 押下で commandId を受領し、状態ポーリングで QUEUED→RUNNING→SUCCEEDED/CONFLICT/FAILED を表示。4) ポーリング終了後、最新の投影を再取得（結果書き戻しの反映・F-26） |
| 呼び出し関係 | 呼出元：Site 制限ページ（S-11・現サンプルテンプレートを P0-4 で置換）。呼出先：BookingSiteController（§3.3） |
| 例外処理 | 権限不足・取得エラーはコントローラの例外を標準エラー表示へ（MSG-01〜03 相当・設計値）。取消失敗（409 等）はポーリング結果の状態表示（MSG-05 相当・BD-03 §8.5） |
| 使用 SQL | なし（JS 層は SOQL を直接実行しない） |
| 対応機能 ID | F-23・F-24 |

## 4. 既存モジュール一覧（✅ 実測・コード正本を正とする・本文では展開しない）

BD-03 §2 と同一口径で、既存モジュールは次表の一覧とコード正本の引用に留める。詳細は api-contract.md・RD-01・BD-02・BD-04 を参照。

| モジュール | 主要クラス（実測） | 対応機能 ID | 備考 |
|---|---|---|---|
| auth | `AuthController`・`AuthService` | F-01〜F-03 | 電話番号＋認証コードログイン・JWT Cookie 発行・Redis ブラックリスト（CF-01/02） |
| bookings | `BookingsController`・`BookingsService` | F-06〜F-08・F-10 | 予約 CRUD・取消・照会・統計。競合時は P2034 直列化リトライ。**連携の正本変更フック（F-20）は P0-3 で追記予定**（現状 version/syncStatus なし・実測） |
| services | `ServicesController`・`ServicesService` | F-04・F-11 | サービスカタログ・管理 |
| time-slots | `TimeSlotsController`・`TimeSlotsService` | F-05・F-13 | 空き照会・枠管理。**BlockedTimeSlot モデルは在るが端点未実装**（既知課題・REQ-012/F-13 備考） |
| users | `UsersController`・`UsersService` | F-12・F-14 | ユーザー管理。ロール変更はセッション維持（RULE-17 既知課題） |
| email | `EmailService` | F-08（取消確認メール） | 非同期送信 |
| retention | `RetentionScheduler`・`RetentionService` | REQ-032（機能一覧外・運用機能） | 30 日ハードデリート・cron 毎日 02:30。詳細は DD-03 |
| prisma（共通） | `PrismaService` | 全機能共通 | `src/common/prisma/` |
| 共通ガード | `JwtAuthGuard`（APP_GUARD）・`RolesGuard`・`PermissionsGuard`・`AdminGuard` | F-01〜F-13 共通（REQ-014） | `src/common/guards/` 実測。CF-01 |
| system | —（`SystemModule` 未インポート） | — | `/v1/system/*` は現状呼出不可（BD-01 §5 注記）。コード一覧 CD-09/10 参照 |

注記：上表のうち連携に接続する既存側の変化点は、bookings モジュールの正本変更トランザクションへの version 採番・syncStatus 管理の追加のみ（F-20・RULE-08・P0-2 migration）。既存機能の仕様は RD-01・api-contract.md が正（BD-03 §2）。

## 5. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】integration_commands（第 14 モデル・暫定名・正式名は P0-3 確定フロー・IDR-01 登録済み）に確定。RULE-08 同一トランザクション書込み・応答キャッシュ否決・P0-2 凍結ウィンドウへ前倒し（migration は CHK-01 B-3）。詳細は DD-01 §2.15 | 決定済み（2026-09-01） |
| 2 | Integration Guard のクラス名・secret 鍵バージョン管理方式（ローテーション手順含む） | P0-3 実装設計時（TERM-23・BD-03 §8.9） |
| 3 | 静的マッピングの実装方式（Prisma モデル vs 設定ファイル） | P0-3 実装設計時（BD-03 §4.9・TERM-26） |
| 4 | 投影送信サービスのクラス名・投影呼出失敗時の同期ブロック有無 | P0-3 実装設計時（BD-03 §3.9 未決事項 2） |
| 5 | LWC バンドル名・ポーリング間隔・取消可否表示条件 | P0-4 着手時（BD-03 §6.9・§7.9） |
| 6 | リトライ上限回数・間隔・NextAttemptAt の具体値 | P0-3 実装時（RULE-09/10・BD-09 §5 未決事項 2） |
