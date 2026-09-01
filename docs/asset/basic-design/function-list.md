# 機能一覧（基本設計）

| 項目 | 内容 |
|---|---|
| 文書ID | BD-02 |
| 版数 | V2.0（ドラフト・日本語化・雛形準拠） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（基本設計フェーズ・機能一覧） |

## 1. 文書の位置づけと雛形対応

- 本書は P0-2 基本設計四文書の一つ（BD-02）。要件（RD-01 REQ-xx）を機能（F-xx）へ分解した目録であり、機能設計書・画面一覧（BD-04）・ERD（BD-07）への索引となる。
- 雛形（交付物雛形集 4.2 機能一覧）の 8 項目＝本書主表の 8 列：機能ID／機能名・概要／対応要件ID／対応業務ID／担当ロール／新規・改修・共通／優先度／備考。
- 対応要件ID・対応業務ID・優先度の記入根拠は RD-01『要件一覧』付録「要件 × 機能対応表」と RD-03『業務一覧』であり、既存の対応関係のみを引用する（新規の対応関係は製造しない）。
- 端点は `booking-backend/docs/api-contract.md` 実測（2026-08-31 読取）に基づき備考列に記載。画面記号 S-xx は BD-04、データモデルは BD-07 を参照。
- 状態図例：✅ 既存実装済み｜🔵 P0 計画（未実装）｜⚪ P1。システム構成は BD-01（system-architecture.md）。

## 2. Booking 顧客機能（✅ 既存）

| 機能ID | 機能名・概要 | 対応要件ID | 対応業務ID | 担当ロール | 新規・改修・共通 | 優先度 | 備考 |
|---|---|---|---|---|---|---|---|
| F-01 | 電話番号認証コードログイン：6 桁 SMS 認証コードでログインし、access/refresh/csrf を HttpOnly Cookie で発行する | REQ-002 | BIZ-02 | 顧客・管理者 | 既存流用（共通認証） | Must | 端点 `POST /v1/auth/login`、`POST /v1/auth/send-verification-code`、`GET /v1/auth/profile`。画面 S-01 |
| F-02 | ユーザー登録：電話番号＋認証コード＋氏名／メールで顧客アカウントを登録（電話番号重複チェック付き） | REQ-001 | BIZ-01 | 顧客 | 既存流用 | Must | 端点 `POST /v1/auth/register`、`GET /v1/auth/check-phone`。画面 S-02 |
| F-03 | トークン更新・ログアウト・検証：401 時の自動更新、ログアウト時にトークンを Redis ブラックリストへ登録、トークン有効性検証 | REQ-003 | BIZ-02 | 顧客・管理者 | 既存流用（共通認証） | Must | 端点 `POST /v1/auth/refresh`、`POST /v1/auth/logout`、`GET /v1/auth/verify` |
| F-04 | サービスカタログ照会：稼働中サービスの一覧を閲覧 | REQ-004 | BIZ-03 | 顧客 | 既存流用 | Must | 端点 `GET /v1/services`。画面 S-03 |
| F-05 | 予約可能時間枠照会：指定日の空き時間枠を照会（時間枠容量は現状固定値 1） | REQ-005 | BIZ-03 | 顧客 | 既存流用 | Must | 端点 `GET /v1/time-slots/available-slots`。容量 1 は RULE-06 の現行実装値。画面 S-03 |
| F-06 | 予約作成：サービス・時間枠を検証し予約（status=PENDING）を作成 | REQ-006 | BIZ-03 | 顧客 | 既存流用 | Must | 端点 `POST /v1/bookings`。競合時は直列化＋限定回数リトライ（P2034）。画面 S-03 |
| F-07 | 本人予約照会：自分の予約リスト・詳細を照会（非管理者はバックエンド側で本人レコードに絞り込み） | REQ-007 | BIZ-05 | 顧客 | 既存流用 | Must | 端点 `GET /v1/bookings/all`、`GET /v1/bookings/:id`。画面 S-03 |
| F-08 | 予約変更・キャンセル・削除：状態遷移検証（RULE-05・RULE-07）のうえ変更・取消を実施。取消確認メールは非同期送信。ハード削除あり | REQ-008 | BIZ-04 | 顧客 | 既存流用 | Must | 端点 `PATCH /v1/bookings/:id`、`PATCH /v1/bookings/:id/cancel`、`DELETE /v1/bookings/:id`（ハード削除・HTTP 204）。画面 S-03 |
| F-09 | 通知：サイト内通知一覧・既読化・未読数＋WebSocket による通知配信 | REQ-009 | BIZ-06 | 顧客 | 既存流用 | Could | 端点 `GET /v1/notifications` ほか＋WebSocket。検証はデモ環境での手動確認。画面 S-03 |

注（共通機能の対応）：REQ-014（アクセス制御：フロント三層＋JwtAuthGuard・AdminGuard・RolesGuard による最終裁定）は、RD-01 対応表のとおり F-01〜F-13 に共通するガード・アクセス制御として対応する（単独の F 番号は持たない）。

## 3. Booking 管理者機能（✅ 既存）

| 機能ID | 機能名・概要 | 対応要件ID | 対応業務ID | 担当ロール | 新規・改修・共通 | 優先度 | 備考 |
|---|---|---|---|---|---|---|---|
| F-10 | 管理コンソール（予約管理タブ）：全量リスト・日次別・統計サマリによる予約管理 | REQ-010 | BIZ-07 | 管理者 | 既存流用 | Must | 端点 `GET /v1/bookings/all`、`GET /v1/bookings/by-date`、`GET /v1/bookings/stats/summary`。画面 S-04 |
| F-11 | サービス管理タブ：サービス CRUD と稼働・停止 | REQ-011 | BIZ-08 | 管理者 | 既存流用 | Must | 端点 `GET /v1/services/all`、`POST /v1/services/admin`、`PATCH /v1/services/admin/:id(/status)`。画面 S-04 |
| F-12 | ユーザー管理タブ：ユーザー作成・照会・統計、状態変更（セッション取消）、ロール変更（セッション維持＝現行仕様・既知課題）、削除 | REQ-013 | BIZ-09 | 管理者 | 既存流用 | Must | 端点 `POST /v1/users`、`GET /v1/users*`、`PUT /v1/users/:id/status`、`PUT /v1/users/:id`、`DELETE /v1/users/:id`。セッション挙動の差は RULE-17。画面 S-04 |
| F-13 | 時間枠管理：時間枠 CRUD と稼働・停止 | REQ-012 | BIZ-08 | 管理者 | 既存流用 | Must | 端点 `POST /v1/time-slots` ほか。`BlockedTimeSlot` モデルは在るが端点未実装（既知課題・RD-01 REQ-012 備考と一致）。画面 S-04 |
| F-14 | アカウント状態提示：無効化・降格ユーザーを提示ページへ誘導（`?reason=ROLE_CHANGED_FROM_ADMIN`） | REQ-015 | BIZ-09 | 顧客・管理者（無効化・降格されたユーザー） | 既存流用 | Should | フロントエンドガードと連動。画面 S-05 |
| F-15 | ファイルアップロード：単一・複数ファイル、アバター画像 | —（本スライス対象外） | —（対象業務なし） | 顧客・管理者 | 既存流用 | — | 端点 `POST /v1/upload/*`（`src/common/file-upload/` に実装）。予約 × EC 連携スライスの対象外のため要件化対象外（RD-01 §1 対象範囲の注記と一致・RD-03 の業務にも含まれない） |

注：REQ-032（30 日保持・ハードデリート）に対応する retention モジュールは**既存実装・稼働中**だが、機能一覧外の運用機能として扱う（RD-01 対応表の口径）。BIZ-16・RULE-15・NFR-11 を参照。

管理者アクセス制御三層（✅ 実測・詳細は BD-04 §3.3）：Next.js middleware（**Cookie 存在性のみ**・ロール判定なし）→ `AuthGuard`＋`routePermissions`（クライアントルート権限・`/bookings` は customer のみ）→ `AdminPage` コンポーネント内ロール検知（非 admin は storage クリアのうえ S-05 へリダイレクト）。バックエンド `AdminGuard`／`RolesGuard` が最終裁定する。

注：`api-contract.md` 記載の `/v1/system/*` 端点群（設定・レポート）は `SystemModule` 未インポートのため現状不可用であり、本表に列挙しない（契約文書から誤って復元しないこと）。`GET /v1/health`、`GET /v1/upload/stats` は運用補助端点のため単独立項しない。

## 4. Salesforce 連携機能（🔵 P0 計画・F-22 のログイン部分のみ検証済み）

| 機能ID | 機能名・概要 | 対応要件ID | 対応業務ID | 担当ロール | 新規・改修・共通 | 優先度 | 備考 |
|---|---|---|---|---|---|---|---|
| F-20 | 予約投影：予約正本（TERM-08）の変更（作成・変更・キャンセル全て＝顧客自身の標準取消を含む）を Booking__c（TERM-09）へ冪等投影。External ID 定位＋version ゲート＋eventId 再送時は初回結果を返す。投影ホワイトリストに顧客 PII を含まない | REQ-018（主）・REQ-019/024/029/033 | BIZ-12 | システム（Booking API → Apex） | 新規（P0-3 計画） | Must | 検証アンカー MV-04・MV-05・MV-06。ホワイトリストは RULE-11（契約凍結・PII 5 項目除外）。遅延コマンドへの 404/409 フォールバックは REQ-033（G7 決定） |
| F-21 | 管理者入口遷移：Booking 管理コンソールに「Salesforce 管理ワークベンチ」ボタンを表示（ADMIN＋静的マッピング active のときのみ有効）し、Site ログインページへ遷移（遷移＝SSO ではない） | REQ-017（前提 REQ-026） | BIZ-10 | 管理者 | 新規（P0-4 計画） | Must | 検証アンカー MV-02。表示条件は RULE-16。現状はボタンなし |
| F-22 | Site 独立ログイン：外部ユーザーが `/02/login` から Experience Site に独立ログイン（Booking の PW/JWT/Cookie は送信しない・RULE-18） | REQ-016 | BIZ-11 | 管理者（外部ユーザーとして・TERM-07） | 既存（P0-1 構築済み・ログイン部分 ✅ 検証済み） | Must | 検証アンカー MV-03（ログイン部分）。判定基準の後半「権限付与済みページのみ閲覧可能」は MV-07（準備＝P0-2・実行＝P0-4〔F-23 完了時〕・PPT-01 †4 窓表現）で実施 |
| F-23 | 投影リスト表示：Site 内 LWC で自 Account の予約投影を閲覧（行級限定・読取専用） | REQ-020（＋REQ-030） | BIZ-13 | 管理者（外部ユーザーとして） | 新規（P0-4 計画） | Must | 検証アンカー MV-07。行級範囲は RULE-13（OWD Private＋Sharing Set＋CRUD/FLS）。現サイトはサンプルテンプレート |
| F-24 | キャンセルコマンド受理：Site から CANCEL_BOOKING を送信し、Booking_Command__c（TERM-11）を生成して commandId／QUEUED を即時返却。状態はポーリングで取得 | REQ-021（＋REQ-030） | BIZ-14 | 管理者（送信）＋システム（受付） | 新規（P0-3/P0-4 計画） | Must | 検証アンカー MV-07/08。唯一の逆方向コマンド種別 |
| F-25 | コマンドバックグラウンド実行：Queueable が Named Credential で Booking 統合端点を呼出。Booking 側は Integration Guard・静的マッピング・ADMIN/ACTIVE・状態・expectedVersion を検証し、同一トランザクションで正本を CANCELLED に更新。409＝業務競合（リトライしない）・429/503/timeout＝一時的障害（限定回数リトライ）。FAILED／ERROR は同一 commandId で手動 Retry 可能 | REQ-022（主）・REQ-023・REQ-024・REQ-026・REQ-027・REQ-028・REQ-029・REQ-031 | BIZ-14・BIZ-15 | システム | 新規（P0-3 計画） | Must | 検証アンカー MV-08/09/10/11。エラー区分は RULE-09・手動 Retry は RULE-10（原 commandId・Retry UI は P1 保留）。監査フィールド（CorrelationId・AttemptCount・HttpStatus・NextAttemptAt・LastError）は REQ-031 |
| F-26 | 結果書き戻し：コマンド成功後、バージョンゲート付きで canonical result を Booking__c に書き戻す（incomingVersion が現行より高い場合のみ更新） | REQ-025（＋REQ-024） | BIZ-14 | システム | 新規（P0-3 計画） | Must | 検証アンカー MV-08。終状態の書込みは明示 200/409 のみ（RULE-14） |

Booking 側の新規追加キャリア（P0-3 計画）：統合端点 `POST /v1/integrations/salesforce/booking-commands`、HTTP クライアントと OAuth 依存の新規導入（現状 `package.json` に HTTP クライアント依存なし＝実測）、静的操作者マッピング（TERM-26・`salesforceUserId ↔ bookingUserId` の事前登録 active 1 件）、同期状態フィールド（`version`／`syncStatus` の migration・現行 13 モデルに該当フィールドなし＝BD-07 実測、確定済（2026-09-01・CHK-01 B-1））。

## 5. Salesforce 側既存・共通機能

| 機能ID | 機能名・概要 | 対応要件ID | 対応業務ID | 担当ロール | 新規・改修・共通 | 優先度 | 備考 |
|---|---|---|---|---|---|---|---|
| F-30 | Site アクセス・メンバー管理：Network Live・メンバー 4 件・SelfReg=false の維持確認 | REQ-034（不実施事項の確認対象） | BIZ-11 | 管理者（外部ユーザー） | 既存（P0-1） | Won't（REQ-034 は本件で実施しない・F-30 はその確認対象） | 自己登録がないことの確認が受け入れ条件（REQ-034） |
| F-31 | 外部ユーザーライフサイクル（静的部分）：事前設定 1 名の外部ユーザーで運用 | REQ-038（動的部分は P1 保留） | BIZ-09・BIZ-10 | 管理者 | 既存（静的 1 名）＋⚪ P1（動的部分） | Won't（動的部分は P1） | `sfAccessStatus` 状態遷移は設計目標（未実装）。P1 計画名は `SalesforceUserLink`（TERM-26） |
| F-32 | オブジェクト権限マトリクス：Booking__c／Booking_Command__c の外部ユーザー最小 CRUD/FLS・Sharing Set 行級・External OWD=Private | REQ-030 | BIZ-13・BIZ-14 | システム（権限設定） | 新規（P0-2 契約凍結） | Must | 権限マトリクスは P0-2 で凍結。`Admin_Note__c` は SF ローカル（P1 表示項目） |
| F-33 | 信頼性配信・対合・告警：Outbox/Worker・DLQ・周期対合・指標告警 | REQ-037（本件では対応しない） | BIZ-12・BIZ-15 | システム | ⚪ P1（本件スコープ外） | Won't | P0 は「直接呼出＋有限リトライ＋手動 Retry」。本番級の信頼性配信ではないことを明示。注：REQ-033（G7 決定）の対合側は P1 相当であり、P0 では周期対合を実施しない（RD-01 付録の REQ-033→F-20/F-33 関連と対応） |

## 6. 対象外（本件で明示的に実施しない事項）

RD-07『システム化範囲』§4・RD-01 REQ-034〜REQ-038 と同一口径。以下は本スライスでは実施しない。

| No. | 対象外事項 | 先送り先 |
|---|---|---|
| 1 | SSO／JIT／自己登録／自動ライセンスプール（REQ-034・F-30 で不実施を確認） | 対応しない（必要時に別案件） |
| 2 | Salesforce 内部ユーザー／System Administrator による連携（REQ-035） | 対応しない（外部ライセンス・最小権限の原則） |
| 3 | 全項目自由双方向同期・改期・添付ファイル連携（REQ-036）。コマンド種別は CANCEL_BOOKING のみ | 対応しない（P1 の Admin_Note__c 表示のみ） |
| 4 | Outbox／Worker／DLQ／周期対合・指標告警（REQ-037・F-33） | P1（保留） |
| 5 | 動的 provisioning／deprovisioning（SalesforceUserLink・Contact/User 生成・提権降権・`sfAccessStatus` 状態遷移）（REQ-038・F-31 動的部分） | P1（保留） |
| 6 | Trigger／Batch／Email Service 等の技術要素追加（Flow／標準 REST による代替も評価のうえ否決済み） | 対応しない |
| 7 | Exactly-once 配信・分散トランザクション・生産級高可用性・リアルタイム零遅延 | 対応しない（冪等＝version＋commandId による実質重複排除のみ） |
| 8 | SF 側からの改期・予約作成（改期が必要な場合は管理者が Booking 管理画面＝BIZ-04 で手動対応） | 対応しない |
| 9 | ロール変更時の全デバイスセッション取消（RULE-17 の既知課題・現行仕様はセッション維持） | P1（強化項目） |
| 10 | F-15（ファイルアップロード）：実装は存在するが本スライス（予約 × EC 連携）の対象外のため要件化対象外 | 対応しない（RD-01 §1 対象範囲の注記） |

## 7. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】F-20/F-25 の External ID＝uuid `id`（TERM-14。DD-01 §5 未決 1 と同日クローズ） | 決定済み（2026-09-01） |
| 2 | F-25 の手動 Retry UI（現行は手順ベースの手動対応） | P1（保留・REQ-028） |
