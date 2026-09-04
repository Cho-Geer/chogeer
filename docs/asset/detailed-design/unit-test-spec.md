# 単体テスト仕様書（詳細設計）

| 項目 | 内容 |
|---|---|
| 文書ID | DD-04 |
| 版数 | V1.2（2026-09-04・D-1 TC-07〜28 実施結果回写〔S-4/T-2 11/11・S-5/T-3 8/8・T-4 Jest 270/270〕＋§4 旧計画名改称。前版 V1.1＝ドラフト・2026-09-03 C-2 修订） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（詳細設計フェーズ・単体テスト） |

## 1. 文書の位置づけと構成

- 本書は詳細設計四文書の一つ（DD-04）。既存テスト資産の実測概況（§2）と、P0 連携スライスのテスト設計値（§3 Apex／§4 Booking Jest）を記載する。雛形（交付物雛形集 5.4 単体テスト仕様書）の 6 項目（テストケース ID／対象モジュール・メソッド／観点／入力・前提条件／期待結果／実施結果）を §3・§4 のテストケース表に展開し、対応機能 ID・出典を記した備考列（第 7 列）を付す。テストケースの実施結果欄は実測値で記す（P0-3 完了時点で TC-01〜28 全件実施済み：TC-01〜06＝2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS／TC-07〜11/14＝2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS／TC-12/13/15/16＝2026-09-03・S-5/T-3・8/8 PASS／TC-17〜28＝2026-09-04・T-4・Booking 側 Jest 270/270）。
- 状態表記：✅＝既存実装・実測／🔵＝P0 計画（未実装）。**§3・§4 のテストケースは設計値として本章に展開し、実施結果欄に実測値を記す**（P0-3 完了時点で全件実施済み：§3 SF 側投影系 TC-01〜06＝2026-09-02・S-3/T-1・15/15・Apex コマンド系 TC-07〜11/14＝2026-09-03・S-4/T-2・11/11・Site 系 TC-12/13/15/16＝2026-09-03・S-5/T-3・8/8・§4 Booking 側統合経路 TC-17〜28＝2026-09-04・T-4・Jest 270/270）。既存テストの実測数値（describe 数・it 数）は `booking-backend/src` 配下の 14 個の `*.spec.ts` を grep 計数した（2026-08-31・実測）。
- 対応機能 ID（F-xx）・ルール ID（RULE-xx）・検証アンカー（MV-xx）は既存文書の引用のみ使用し、新規の対応関係は製造しない。テストケース ID は TC-xx を本書で新規に採番する（唯一の新規 ID 空間）。

## 2. 既存テスト実測概況（§A・✅ 実測）

### 2.1 テスト資産一覧（14 spec ファイル）

`booking-backend/src` 配下の 14 個の `*.spec.ts`（実測・grep 計数）。テスト説明文は実装言語（中国語／英語）のまま実測値として記録し、日本語への改訳は本件の対象外とする。

| No. | ファイル（src 相対） | 対象モジュール | describe 数 | it/test 数 | 観点カバレッジ（実測） |
|---|---|---|---|---|---|
| 1 | `common/exceptions/business.exceptions.spec.ts` | 業務例外 19 クラス | 20 | 21 | 各例外の errorCode・HTTP 状態・カスタム状態コード・詳細情報（正常構築中心） |
| 2 | `common/utils/config.util.spec.ts` | 設定ユーティリティ | 1 | 3 | 真偽値パース（truthy／falsy／フォールバック） |
| 3 | `common/utils/masking.util.spec.ts` | マスクユーティリティ | 3 | 12 | 電話番号（11 桁・他桁・短い・null・空・非数字）／メール（短い・無効・中・長） |
| 4 | `modules/auth/auth.controller.spec.ts` | AuthController | 1 | 1 | ログアウト時の Cookie 不在→bearer フォールバック |
| 5 | `modules/auth/auth.service.spec.ts` | AuthService | 7 | 16 | ログイン（成功/検証コード誤り/ユーザー不存在/無効）・JWT_EXPIRES_IN 解析（文字列/数値）・登録（成功/電話番号重複/メール重複）・コード送信・ログアウト・プロフィール |
| 6 | `modules/bookings/bookings.controller.spec.ts` | BookingsController | 7 | 12 | 作成（userId 補完）・一覧（非管理者は本人のみ）・詳細（不存在）・更新（不存在）・取消（不存在）・管理者削除・統計 |
| 7 | `modules/bookings/bookings.service.spec.ts` | BookingsService | 6 | 17 | 作成（P2034 リトライ・時間枠不存在/停止/満杯・ユーザー競合・DB 一意制約）・照会（不存在）・更新（不存在）・統計 |
| 8 | `modules/email/email.service.spec.ts` | EmailService | 4 | 5 | 確認メール（成功/失敗）・取消メール・更新メール・備考なし |
| 9 | `modules/retention/retention.service.spec.ts` | RetentionService | 9 | 24 | 保持日数（既定/設定/不正/負/0）・バッチ件数・スリープ・有効スイッチ・dry-run・削除（一致/0 件/大量バッチ分割/モード選択） |
| 10 | `modules/services/services.service.spec.ts` | ServicesService | 6 | 10 | 一覧（稼働中/ページ/フィルタ）・作成・更新・状態切替（無効時予約解除）・不存在 |
| 11 | `modules/time-slots/time-slots.service.spec.ts` | TimeSlotsService | 8 | 15 | 作成（衝突）・一覧/詳細・更新（衝突）・削除（不存在）・空き判定（予約済）・初期化（重複なし） |
| 12 | `modules/users/users.controller.spec.ts` | UsersController | 9 | 12 | 作成（成功/失敗）・一覧（0 件）・詳細（不存在）・更新・削除・プロフィール・DTO 検証・統計 |
| 13 | `modules/users/users.logic.spec.ts` | ユーザー業務ロジック | 7 | 11 | 作成（電話番号重複）・詳細/更新/削除（不存在・DB 失敗）・一覧・統計 |
| 14 | `modules/users/users.service.spec.ts` | UsersService | 7 | 15 | 作成（電話番号重複/DB/メール重複）・照会・更新・削除（不存在）・一覧（安定ソート・フィルタ）・統計 |

計：describe 95・it/test 174（grep 計数・実測）。実行結果（パス/失敗）は本フェーズでは計測していない（実行環境での確認はテスト実行フェーズの対象）。

### 2.2 観点別ギャップ分析（実測に基づく指摘・捏造しない）

- **auth.controller.spec.ts（it 1）**：コントローラ層が著しく薄い。ログイン・登録・プロフィール等の正常系応答、異常系（検証コード誤り・DB 例外の伝播）が未カバー。Cookie 有無の分岐も 1 件のみ。
- **email.service.spec.ts（it 5）**：正常送信・送信失敗・備考なしに限定。本文の境界（空・長文・特殊文字）・null 引数・宛先欠落が未カバー。
- **config.util.spec.ts（it 3）**：真偽値の境界（`'1'`/`'0'`・大文字小文字・前後空白・数値 0/1）が薄い。
- **masking.util.spec.ts（it 12）**：比較的厚いが、11 桁中国携帯番号を前提としており、日本のデモ規模の電話番号桁（固定電話・国番号・区切り記号）は対象外（既存実装の前提に合わせた実測値であり、本スライスの課題ではない）。
- **サービス層全般**：null・undefined・空文字の境界値は retention（負/0/不正）と users に一部あるが、bookings の入力境界（0 件・limit 最大・最大件数+1）や不正引数は薄い。
- **retention.service.spec.ts（it 24）**：境界値・異常系が最も厚く、DD-03 のリラン・冪等性（0 件・大量バッチ）の裏付けとして参照できる。
- テスト説明文が実装言語（中国語主体・一部英語）のままである点は既存資産の実態であり、日本語化は今後の改善余地として記録する。

## 3. P0 Apex テスト設計（§B・✅ 実施済 2026-09-02/09-03）

対象：Salesforce 側の `BookingProjectionRest`／`BookingCommandQueueable`／`BookingSiteController`（DD-02 §3）。検証観点は experience-site-interview-mvp-focus.md の「P0：必須完成」No.6（Apex テスト：初回投影・重複投影・旧バージョン・合法取消・409・Callout Mock の一時的失敗）と MV アンカーに準拠する。カバレッジ目標は NFR-09（Apex テストカバレッジ 75% 以上・`sf apex run tests`）。

| テストケース ID | 対象モジュール・メソッド | 観点 | 入力・前提条件 | 期待結果 | 実施結果 | 備考（対応機能 ID・出典） |
|---|---|---|---|---|---|---|
| TC-01 | BookingProjectionRest.receiveProjection | 正常（初回投影成功） | 新規予約の投影ペイロード 9 項目（incomingVersion=1・eventId=新規 UUID・External ID 未存在） | `Booking__c` が 1 件 insert され、Status__c・CurrentVersion__c がペイロードと一致。受理応答（eventId・受理後 CurrentVersion__c）を返す | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-04） |
| TC-02 | BookingProjectionRest.receiveProjection | 冪等（同一 eventId 再送） | TC-01 実行後、同一 eventId・同一 version のペイロードを再送 | レコードが増えず更新もされず、初回受理結果をそのまま返す（LastEventId__c 判定・RULE-04） | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-05・RULE-04） |
| TC-03 | BookingProjectionRest.receiveProjection | 異常（旧 version 拒否） | CurrentVersion__c=5 の既存投影へ incomingVersion=4 を送信 | 拒否応答（競合）を返し、Booking__c は更新されない（incomingVersion <= CurrentVersion・RULE-01） | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-05・RULE-01・REQ-024） |
| TC-04 | BookingProjectionRest.receiveProjection | 境界（同 version・別 eventId は拒否・RULE-01 は等号含む） | CurrentVersion__c=5・LastEventId__c=旧 に対し、incomingVersion=5・別 eventId を送信 | 拒否応答（競合）を返し、Booking__c は更新されない | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-05・RULE-01/04） |
| TC-05 | BookingProjectionRest.receiveProjection | 並行（並行初回投影） | 同一 External ID へ 2 スレッドで初回投影を同時送信（FOR UPDATE ロック前提） | `Booking__c` は 1 件のみ生成。競合側はロック待ち後にバージョンゲートで判定（重複 insert なし） | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-06・BD-03 §3.6）・Apex 単一スレッド制約につき順次シミュレーション |
| TC-06 | BookingProjectionRest.receiveProjection | 異常（PII 非含有） | ペイロード・Booking__c の全項目を検証（氏名・電話・メール・WeChat・備考の 5 項目） | 投影ペイロード・Booking__c のいずれにも PII 5 項目が出現しない（ホワイトリスト・RULE-11・NFR-08） | ✅ 実施済（2026-09-02・S-3/T-1・BookingProjectionRestTest 15/15 PASS） | F-20（MV-04・REQ-019・NFR-09） |
| TC-07 | BookingCommandQueueable.execute | 正常（合法取消成功） | HttpCalloutMock が Booking から 200＋canonicalVersion＋resultCode を返す前提（正常取消シミュレーション） | `Booking_Command__c.Status__c=SUCCEEDED`・HttpStatus__c=200・ResultVersion__c 記録。バージョンゲート付き結果書き戻し（Booking__c.Status__c=CANCELLED） | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25/F-26（MV-08・RULE-14・REQ-025） |
| TC-08 | BookingCommandQueueable.execute | 異常（409 業務競合） | HttpCalloutMock が 409＋currentVersion＋correlationId を返す前提（業務競合シミュレーション：旧 expectedVersion 等） | `Status__c=CONFLICT`（終状態）・リトライしない・副作用なし。HttpStatus__c・LastError__c・CorrelationId__c 記録 | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25（MV-09・RULE-02/09/14） |
| TC-09 | BookingCommandQueueable.execute | 異常（503 一時障害・成功回復） | HttpCalloutMock が前 2 回 503・第 3 回 200 を返す前提（Callout Mock・MV-10） | AttemptCount__c が 2 回目まで +1 され、3 回目成功で SUCCEEDED。NextAttemptAt__c・LastError__c 記録 | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25（MV-10・RULE-09） |
| TC-10 | BookingCommandQueueable.execute | 異常（継続失敗→FAILED） | HttpCalloutMock が上限回数まで 503 を返し続ける前提 | 上限到達で `Status__c=FAILED`（AttemptCount__c・NextAttemptAt__c・LastError__c 記録）。手動 Retry（原 commandId）前提（RULE-10） | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25（MV-10・RULE-10・REQ-028） |
| TC-11 | BookingCommandQueueable.execute | 異常（認証 NG 401/403） | HttpCalloutMock が 401/403（誤 token／欠落 token・C-2 修订 2026-09-03）を返す前提 | 業務状態遷移・コマンド終状態（SUCCEEDED/CONFLICT/FAILED）を書込まず、エラー記録のみ（RULE-14 注記・REQ-029） | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25（MV-11・RULE-09 注記・REQ-029） |
| TC-12 | BookingSiteController.getProjections | 異常（行級限定・越権拒否） | 外部ユーザー A が他 Account の Booking__c ID を直指定で照会（External OWD=Private＋Sharing Set 前提） | 行級範囲により取得不能（空／権限不足挙動）。他 Account の投影は表示されない | ✅ 実施済（2026-09-03・S-5/T-3・8/8 PASS） | F-23（MV-07・RULE-13・REQ-030） |
| TC-13 | BookingSiteController.submitCancel | 境界（取消不可状態の事前抑制） | CANCELLED／COMPLETED の投影に対して取消送信を試行 | 送信前に抑制（ボタン無効・MSG-04 相当）。Booking_Command__c は生成されない（最終判定は Booking 側 409・F-25） | ✅ 実施済（2026-09-03・S-5/T-3・8/8 PASS） | F-24（BD-03 §7.5・RULE-07） |
| TC-14 | BookingCommandQueueable.execute | 境界（受入端点の入力境界） | リクエスト境界：expectedVersion 同値（正本一致）・`expectedVersion` null・`bookingExternalId` 空・`commandType` 不正値・`requestedBySalesforceUserId` null を各 1 件 | 同値は受理 200。null／空／不正は **400（ValidationException・判定制確定 2026-09-02・CHK-02 C-11：必須 6 項目＋commandType 完全一致＋expectedVersion 型検証のみ）** で返し、正本・コマンド状態を変えない（P0 では Mock 応答の境界として検証） | ✅ 実施済（2026-09-03・S-4/T-2・C-2 修订後 11/11 PASS） | F-25（BD-09 §4.3・RULE-02/12/13） |
| TC-15 | BookingSiteController.getProjections | 境界（投影 0 件） | 自 Account に投影レコードが存在しない状態 | 空一覧を返す（MSG-01 相当・異常にしない） | ✅ 実施済（2026-09-03・S-5/T-3・8/8 PASS） | F-23（BD-03 §6.5） |
| TC-16 | BookingSiteController.getCommandStatus | 正常（状態遷移表示） | コマンド生成後、QUEUED→RUNNING→SUCCEEDED の順にポーリング | 各状態が正しく返り、最終的に SUCCEEDED（/CONFLICT/FAILED）が表示される | ✅ 実施済（2026-09-03・S-5/T-3・8/8 PASS） | F-24（BD-03 §7・S-11-07） |

## 4. P0 新規エンドポイントのテスト設計（§C・✅ 実施済 2026-09-04）

対象：Booking 側の統合経路（Integration Guard・IntegrationCommandsController・IntegrationCommandsService・投影送信サービス＝DD-02 §2）。Jest（NestJS Testing）によるテスト設計値。既存 spec（§2）と同一のテスト基盤を想定する。

| テストケース ID | 対象モジュール・メソッド | 観点 | 入力・前提条件 | 期待結果 | 実施結果 | 備考（対応機能 ID・出典） |
|---|---|---|---|---|---|---|
| TC-17 | Integration Guard.canActivate | 正常（A3 検証通過） | env `INTEGRATION_TOKEN` と一致する正しい Bearer token（`Authorization: Bearer <token>`・C-2 修订 2026-09-03） | `true` を返しリクエストが通過する | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（REQ-029・NFR-04・MV-11） |
| TC-18 | Integration Guard.canActivate | 異常（認証 NG） | 誤 token（env `INTEGRATION_TOKEN` と不一致）／欠落 token（ヘッダなし・Bearer 形式不正）の各 token（C-2 修订 2026-09-03） | 401/403 を返し、予約・コマンド状態が一切変化しない（業務状態不変） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270・403 は 401 と同一分岐のため代表 1 件で網羅） | F-25（REQ-029・MV-11） |
| TC-19 | IntegrationCommandsController.receiveCommand | 境界（DTO 検証） | `commandType` が CANCEL_BOOKING 以外／必須 6 項目の null・空文字・欠落 | 400（ValidationException）を返し、業務処理を実行しない | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（BD-09 §4.3・RULE-13） |
| TC-20 | IntegrationCommandsService.executeCancelCommand | 冪等（commandId 再送） | 同一 commandId の既処理結果が保存済みの状態で同一 commandId を再送 | 初回保存済み結果（HTTP 状態・canonicalVersion・resultCode）をそのまま返し、取消・通知の副作用を再実行しない（RULE-03・タイムアウト後重複含む） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（MV-08・RULE-03・REQ-023） |
| TC-21 | IntegrationCommandsService.executeCancelCommand | 異常（静的マッピング NG） | `requestedBySalesforceUserId` に対応するマッピング不存在／inactive、または Booking ユーザーが非 ADMIN／非 ACTIVE | 403（AuthorizationException）を返し、正本を更新しない（RULE-12） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（RULE-12・REQ-026） |
| TC-22 | IntegrationCommandsService.executeCancelCommand | 異常（予約定位 404） | `bookingExternalId` が既存予約に一致しない（削除済み予約宛を含む） | 404（ResourceNotFoundException）を返し、曖昧な成功としない（REQ-033・G7） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（REQ-033・RULE-15） |
| TC-23 | IntegrationCommandsService.executeCancelCommand | 異常（状態遷移 NG） | COMPLETED 宛取消・CANCELLED 宛の新 commandId 取消 | 409（BusinessRuleException）を返し、正本を更新しない（RULE-05/07） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（MV-09・RULE-05/07） |
| TC-24 | IntegrationCommandsService.executeCancelCommand | 境界（バージョンゲート） | expectedVersion 同値（正本一致）→受理／expectedVersion が正本より 1 低い→409／expectedVersion 0 件（初回・正本 version=1 想定） | 同値は 200、不一致は 409＋currentVersion＋correlationId（RULE-02）。**0 件も不一致として 409（決定済 2026-09-02・CHK-02 C-10・特殊扱いなし）** | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（RULE-02・REQ-024） |
| TC-25 | IntegrationCommandsService.executeCancelCommand | 正常（正本更新トランザクション） | 全検証合格（PENDING・expectedVersion 一致・マッピング active） | 同一トランザクションで status=CANCELLED・`version+1`・`syncStatus=PENDING`・`cancelledAt` 設定（RULE-08）。応答 200＋canonicalVersion＋resultCode | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（RULE-08・BD-03 §8.6） |
| TC-26 | IntegrationCommandsService.executeCancelCommand | 異常（DB 例外ロールバック） | 正本更新時に DB エラー（接続断等）を注入 | 例外を throw し、検証〜正本更新のトランザクション全体がロールバック（正本不変・整合保持） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-25（BD-03 §8.6） |
| TC-27 | 投影送信サービス.projectBooking | 正常（投影成功） | 正本変更確定後の Appointment に対し、ホワイトリスト 9 項目ペイロードを生成して IF-01 呼出（Mock で受理応答） | 応答受理後 `syncStatus=SYNCED` に更新。ペイロードに PII 5 項目が含まれない（構造的排除） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270） | F-20（REQ-018/019・RULE-11・IF-01） |
| TC-28 | 投影送信サービス.projectBooking | 異常（投影失敗） | IF-01 呼出が 503／timeout／401/403 を返す（Mock） | `syncStatus=ERROR` を記録し、正本の整合を損なわない。手動 Retry（同一 eventId）前提（BIZ-15） | ✅ 実施済（2026-09-04・T-4・Booking 側 Jest 270/270・403 は 401 と同一分岐のため代表 1 件で網羅） | F-20（BD-09 §3.8・REQ-029） |

## 5. 境界値要件の総括（§B・§C 横断）

雛形 5.4 の記載要点（境界値は 0・最大値・最大値+1・空・null が欠陥高発区）に基づく総括。

| 境界項目 | テストケース | 確認内容 |
|---|---|---|
| version 同値 | TC-04（別 eventId）・TC-24（expectedVersion 同値） | 同 version の取り扱い（投影は別イベント拒否／コマンドは一致受理） |
| 旧 version・同値+1 差 | TC-03・TC-24 | 旧 version 拒否（投影）・+1 差 409（コマンド） |
| 0 件 | TC-15（投影 0 件）・TC-24（version 0 件） | 空一覧表示・初回 version の扱い |
| null／空文字 | TC-14（expectedVersion null・外部ID 空・要求者 null）・TC-19（DTO null/空/欠落） | 受入端点の入力境界・業務状態不変 |
| 並行 | TC-05（並行初回投影）・TC-20（冪等） | 並行・再送時の重複排除 |
| 最大件数+1 | —（デモ規模のため最大件数境界は対象外・RD-02） | バッチ等の上限境界は retention（既存 spec・バッチ 500 件）に帰属 |

## 6. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-02】TC-24 の「version 0 件」＝特殊扱いなし・不一致として 409＋currentVersion（単純整数一致維持・CHK-02 C-10） | 決定済み（2026-09-02） |
| 2 | 【決定済 2026-09-02】TC-14 の 400 判定＝必須 6 項目＋commandType 完全一致＋expectedVersion 型検証のみ（UUID 形式検証なし・CHK-02 C-11） | 決定済み（2026-09-02） |
| 3 | 既存テスト実行結果（パス/失敗）の取得と、既存テストの日本語化要否 | テスト実行フェーズ／P1 検討 |
