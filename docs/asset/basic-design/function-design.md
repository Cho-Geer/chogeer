# 機能設計書（基本設計）

| 項目 | 内容 |
|---|---|
| 文書ID | BD-03 |
| 版数 | V1.0（ドラフト・雛形準拠） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（基本設計フェーズ・機能設計） |

## 1. 文書の位置づけと雛形対応

- 本書は基本設計八文書の一つ（BD-03）。BD-02『機能一覧』（function-list.md）のうち **Salesforce 連携機能の P0 計画分（F-20〜F-26）** と、§5 のうち連携に直接関連する権限系機能（F-32・F-30/F-31 の確認系）を、雛形（交付物雛形集 4.3 機能設計書）の 9 節骨格に従って逐機能に展開する。
- 雛形 9 節＝各機能章の 9 小節：1.機能概要／2.処理フロー／3.入力項目・出力項目／4.処理詳細／5.例外処理・エラー処理／6.排他制御・トランザクション境界／7.更新対象エンティティ／8.制約・前提条件／9.未決事項。
- 業務ルールは RULE-ID の引用のみとし、本文の複製は行わない（雛形記載要点）。I/F の詳細は BD-09（interface-design.md・IF-01/IF-02）、画面項目は BD-05（screen-items.md）、データモデルは BD-07（erd.md）、構成と認証境界は BD-01（system-architecture.md）を参照する。
- 状態表記：✅ 既存実装｜🔵 P0 計画（未実装）｜⚪ P1。**本書の対象機能は特記（F-22）のない限りすべて 🔵 計画・未着手であり、記載値は設計値（未実装）である。**

## 2. 対象範囲（既存機能の取扱い）

本書は連携スライスの新規機能のみを展開する。Booking の既存機能（F-01〜F-15・画面 S-01〜S-05・13 モデル）は**本書では展開しない**。既存機能の仕様は次を正とする。

| 既存機能の情報源 | 用途 |
|---|---|
| RD-01『要件一覧』（REQ-001〜REQ-015）＋ `booking-backend/docs/api-contract.md`（端点実測） | 既存 Booking 機能の仕様照会 |
| BD-02（function-list.md §2・§3） | 既存機能の一覧と対応要件 |
| BD-04（screens.md）・BD-05（screen-items.md） | 既存画面の構成と項目 |
| BD-07（erd.md） | 既存データモデル |

なお既存機能のうち連携に接続する変化点は 1 点のみである：正本変更トランザクションへの version 採番と `syncStatus` 管理の追加（P0-2 migration・RULE-08）。これは F-20 の処理詳細（§3.4）に含めて記載する。

## 3. F-20：予約投影（🔵 P0-3 計画・未着手）

### 3.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | 予約正本（TERM-08）の変更（作成・変更・キャンセル全て＝顧客自身の標準取消を含む）を Salesforce 側投影 `Booking__c`（TERM-09）へ冪等に反映する |
| 対応要件ID | REQ-018（主）・REQ-019（PII 除外）・REQ-024（バージョンゲート）・REQ-029（A2）・REQ-033（投影レコード保持） |
| 対応業務 | BIZ-12 |
| 使用角色 | システム（Booking API → Apex）。人物は直接操作しない |

### 3.2 処理フロー

業務フローは RD-04 図 5、時序は `interview-portfolio-business-sequence.md` §2 の F3 段を参照。I/F レベルの詳細は BD-09 IF-01。Booking 側の処理順序：正本変更トランザクション確定 → 投影ペイロード生成（ホワイトリスト・RULE-11） → OAuth JWT Bearer で投影 REST 呼出 → 応答判定 → `syncStatus=SYNCED`／`ERROR` 更新。

### 3.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | 正本変更イベント（Appointment の作成・変更・取消の実行結果） | BD-07 §2.2 |
| 出力（I/F） | 投影ペイロード 9 項目（外部ID・予約番号・日付・時間枠・サービス名・状態・version・eventId・correlationId） | BD-09 §3.3 |
| 出力（状態） | `Appointment.syncStatus`（PENDING→SYNCED／ERROR） | BD-07 §2.2・CD-06 |

### 3.4 処理詳細

1. 正本変更トランザクション内で正本更新＋`version+1`＋`syncStatus=PENDING` を行う（RULE-08）。version は単調増加とする。version／syncStatus が未導入の既存機能には本ルールは非適用（P0-2 migration 前の現行挙動は変更しない）。
2. ペイロードは投影ホワイトリスト（予約 ID・番号・日付・時間枠・サービス・状態・version・同期管理項目）のみから生成し、PII 5 項目を含めない（RULE-11・REQ-019）。例外の項目追加は P0-2 契約の凍結変更を要する。
3. eventId・correlationId を採番し、ペイロードへ設定する（採番方針は BD-11 CF-05）。
4. Salesforce 側は External ID 定位の Upsert・バージョンゲート（RULE-01）・eventId 冪等（RULE-04）を適用する（Apex 側の設計は本書の範囲外とせず、BD-09 §3.8・RD-04 図 5 に定義した分岐に従う）。
5. 投影レコード（`Booking__c`）は正本クリーンアップの対象外とし、削除済み予約への遅延コマンドは 404/409 でフォールバックする（REQ-033・G7 決定）。

### 3.5 例外処理・エラー処理

| 分岐 | 処理 | メッセージ方針 |
|---|---|---|
| 旧バージョン・同バージョン別イベント | SF 側が拒否。Booking 側は `syncStatus=ERROR` 記録・**再送しない**（単調増加のため以後も拒否） | 画面出力なし。運用者は `syncStatus`・`LastError` で確認 |
| 401/403（認証系） | 業務状態遷移なし・`syncStatus=ERROR` 記録・認証設定修復後に同一 eventId で手動 Retry | 画面出力なし（システム間） |
| 503・timeout | `syncStatus=ERROR` 記録・手動 Retry（P0 は投影側自動リトライを持たない） | 画面出力なし |
| PII 混入（開発時欠陥） | ペイロード生成関数がホワイトリストのみ許可する実装とし、混入を構造的に不可能にする（設計値・未実装） | MV-04 併せて確認（NFR-08 検証方法） |

### 3.6 排他制御・トランザクション境界

- トランザクション境界：正本更新（version+1・syncStatus=PENDING）までを 1 トランザクションとし、I/F 呼出はその後に分離する（I/F 失敗時は正本の整合を損なわない）。
- 排他：単一環境では同時正本変更の競合頻度は極めて低いが、version 単調増加（RULE-08）＋SF 側バージョンゲート（RULE-01）が楽観的排他を担う。既存予約作成の直列化リトライ（P2034）は同一時間枠の在庫競合対策であり、連携の version ゲートはその代替ではなく層の異なる補完である。
- Salesforce 側は External ID の `FOR UPDATE` ロック後に判定する（sequence 文書 F3 段・並行初回投影は MV-06 で検証）。

### 3.7 更新対象エンティティ

| システム | エンティティ | 操作 | 参照 |
|---|---|---|---|
| Booking | `Appointment` | update（version+1・syncStatus） | BD-07 §2.2 |
| Salesforce | `Booking__c` | insert／update（canonical 項目・LastEventId__c・CurrentVersion__c・SyncStatus__c・CorrelationId__c・LastError__c） | BD-07 §3 |

### 3.8 制約・前提条件

- P0-2 契約凍結（External ID 確定〔uuid `id`・2026-09-01 拍板済み〕・ホワイトリスト凍結〔**2026-09-01 凍結済・RULE-11**〕・権限マトリクス凍結〔2026-09-01 凍結済・F-32〕）が前提。未凍結のまま実装しない。
- P0-3 で HTTP クライアントと OAuth 依存を Booking に新規導入する（現状ゼロ・RD-07 §6 前提条件 2）。
- データ量はデモ規模（数十件）。Outbox/Worker 等の信頼性配信は行わない（REQ-037・P1 保留）。

### 3.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】External ID＝uuid `id`（TERM-14・appointmentNumber 案不採用。DD-01 §5 未決 1 と同日クローズ） | 決定済み（2026-09-01） |
| 2 | 投影呼出失敗時の同期呼出ブロック有無（正本応答を待たせるか非同期化するか） | P0-3 実装設計時 |

## 4. F-21：管理者入口遷移（🔵 P0-4 計画・未着手）

### 4.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | Booking 管理コンソールに「Salesforce 管理ワークベンチ」入口ボタンを表示（条件付き）し、Site ログインページへ遷移させる（遷移＝SSO ではない） |
| 対応要件ID | REQ-017（前提 REQ-026） |
| 対応業務 | BIZ-10 |
| 使用角色 | 管理者（ADMIN） |

### 4.2 処理フロー

RD-04 図 4（MAPCHK4 判定）を参照。ログイン済み管理コンソール描画時（S-04）に、サーバ側データ（role・静的マッピング active）でボタンの有効/無効を判定し、押下で固定 Site URL（`/02/login`）へ遷移する。

### 4.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | 現在ユーザーの role（DB 値）・静的マッピング active フラグ | BD-07 §2.1・TERM-26 |
| 出力 | 入口ボタンの表示状態（有効/無効/非表示）と Site URL への遷移 | BD-04 §2.1 S-04（入口ボタンは 🔵 P0-4 計画） |

### 4.4 処理詳細

- ボタンは `role=ADMIN` かつ静的マッピング active の場合のみ有効表示とし、それ以外は無効または非表示（RULE-16）。
- 操作者の特定は Booking サーバ側の静的マッピングのみで行い、ブラウザ申告 ID は採用しない（RULE-12）。
- 遷移は固定 URL へのブラウザナビゲーションであり、認証情報（PW/JWT/Cookie）を引き渡さない（RULE-18）。

### 4.5 例外処理・エラー処理

- 非 ADMIN・マッピング不存在/inactive：ボタン無効表示（エラーメッセージは出さず操作不能とする方針・設計値）。メッセージID を付ける場合は BD-05 の MSG-xx 体系に従う。
- Site 側ログイン失敗：Site ログイン画面で差戻し（S-10 の画面仕様・BD-05 §S-10）。

### 4.6 排他制御・トランザクション境界

読取系判定のみでトランザクション・排他の対象外（書込なし）。

### 4.7 更新対象エンティティ

なし（照会のみ）。

### 4.8 制約・前提条件

- 静的マッピングは事前登録 active 1 件のみ（P0）。動的 provisioning は P1（REQ-038）。
- 遷移先は固定 Site URL。Named Credential 目標 URL（G3）とは別の、ブラウザ向け Site URL を使用する。

### 4.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | ボタン無効時の非表示/無効表示の選択 | P0-4 実装時 |
| 2 | 静的マッピングテーブルの実装方式（Prisma モデル vs 設定ファイル） | P0-3 実装設計時 |

## 5. F-22：Site 独立ログイン（既存・ログイン部分 ✅ 検証済・閲覧範囲限定検証は未実施）

### 5.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | 外部ユーザー（TERM-07）が `/02/login` から Experience Site に独立ログインする（SSO ではない二次ログイン）。Booking の PW/JWT/Cookie は Salesforce に送信しない（RULE-18） |
| 対応要件ID | REQ-016 |
| 対応業務 | BIZ-11 |
| 使用角色 | 管理者（外部ユーザーとして） |

### 5.2 処理フロー

RD-04 図 4（PG4→CRED4）・`interview-portfolio-business-sequence.md` §2 の F2 段を参照。Site ログインページで外部ユーザー認証情報によるログイン → 成功後は制限付きサイトページ（S-11）へ。

### 5.3 入力項目・出力項目

Salesforce 標準のログイン画面仕様に依存し、Booking 側に I/F・画面項目は存在しない。S-10 の画面情報は BD-05 §S-10（実態ベース記載）を参照。

### 5.4 処理詳細

- Salesforce Network 設定（Live・SelfReg=false・メンバー管理）に依存する標準機能であり、Booking 側に独自処理はない（F-30 確認対象）。
- LoginHistory に外部ユーザー種別（Chatter Communities External User）の記録が残る（MV-03 検証済の硬い証跡）。
- 判定基準の後半「権限付与済みページのみ閲覧可能」は MV-07（準備＝P0-2・実行＝P0-4〔F-23 完了時〕・PPT-01 †4 窓表現）で実施予定であり、現時点では検証済みではない。

### 5.5 例外処理・エラー処理

認証失敗時は Site ログイン画面で差戻し（Salesforce 標準動作）。Booking 側の例外処理は発生しない。

### 5.6 排他制御・トランザクション境界

Salesforce 標準セッション管理に依存。Booking のログイン状態と完全に独立し、相互のログアウトは影響しない（RULE-18）。排他制御の設計対象外。

### 5.7 更新対象エンティティ

Booking 側なし。Salesforce 側は LoginHistory（標準オブジェクト）への自動記録のみ。

### 5.8 制約・前提条件

- Site 本体（P0-1 完了）と外部ユーザー 1 名の事前設定が前提。
- 本機能は「検証済（ログイン部分のみ）」であり、権限範囲の検証は未完了。F-23（MV-07）の完了をもって REQ-016 の受け入れ条件後半が充足する。

### 5.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 「権限付与済みページのみ閲覧可能」の検証（MV-07） | P0-2〜（F-23 完了時） |

## 6. F-23：投影リスト表示（🔵 P0-4 計画・未着手）

### 6.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | Site 内 LWC で自 Account に紐づく予約投影（`Booking__c`）を読取専用で一覧表示する（行級限定） |
| 対応要件ID | REQ-020（＋REQ-030） |
| 対応業務 | BIZ-13 |
| 使用角色 | 管理者（外部ユーザー・静的マッピング active の運用前提） |

### 6.2 処理フロー

RD-04 図 4（SHARE4→VIEW4）を参照。ログイン済み外部ユーザーが S-11 を開く → Apex コントローラ（with sharing・TERM-25）が行級範囲（OWD Private＋Sharing Set）で自 Account の投影のみ照会 → LWC が一覧表示。取消操作は F-24（§7）へ分岐。

### 6.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | 自 Account の投影レコード（表示 8 項目＋取消可否判定用の状態・version） | BD-05 S-11 項目定義（S-11-nn） |
| 出力 | 一覧表示（読取専用）・状態ポーリング結果 | 同上 |

### 6.4 処理詳細

- 照会は with sharing＋CRUD/FLS 最小権限の Apex コントローラ経由のみとし、LWC からの直接 SOQL は行わない（RULE-13・REQ-030）。
- 行級範囲は External OWD=Private＋Sharing Set（Account 隔離）により担保される（TERM-32）。
- 表示する状態値は canonical 値（BD-08 CD-03・CD-07 同一値）。読取専用であり、`Booking__c` を LWC から更新しない。
- 状態ポーリング（コマンド実行後の結果確認）は F-24 の応答（commandId）を用いて `Booking_Command__c` の状態を参照する。

### 6.5 例外処理・エラー処理

| 分岐 | 処理 | メッセージ方針（設計値・未実装） |
|---|---|---|
| 他 Account レコード直指定 | 行級範囲により取得不能（MV-07 で確認） | 標準の権限不足挙動 |
| 投影 0 件 | 空一覧を表示 | MSG-01 相当（BD-05 §3.1） |
| データ取得エラー | エラー表示・再試行操作 | MSG-02 相当 |

### 6.6 排他制御・トランザクション境界

読取系のみ。書込は発生しないため排他制御の対象外（コマンド送信時の排他は F-24/F-25）。

### 6.7 更新対象エンティティ

なし（照会のみ）。

### 6.8 制約・前提条件

- 権限マトリクス（F-32）が P0-2 で凍結済みであること。
- 現サイトはサンプルテンプレートであり、P0-4 で独自 LWC に置換する（BD-04 §2.2）。

### 6.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | LWC バンドル名 | P0-4 着手時（BD-04 §5 と同源） |
| 2 | 取消可否判定の表示条件（CANCELLED/COMPLETED は取消ボタン無効化） | P0-4 実装時 |

## 7. F-24：キャンセルコマンド受理（🔵 P0-3/P0-4 計画・未着手）

### 7.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | Site から CANCEL_BOOKING を送信させ、`Booking_Command__c`（TERM-11）を生成して commandId／QUEUED を即時返却する（唯一の逆方向コマンド） |
| 対応要件ID | REQ-021（＋REQ-030） |
| 対応業務 | BIZ-14 |
| 使用角色 | 管理者（送信）＋システム（受付） |

### 7.2 処理フロー

RD-04 図 6（BTN6→PERM6→MAKE6→RESP6）を参照。取消ボタン押下 → 権限・行級判定（RULE-13） → `Booking_Command__c` 生成（commandId・expectedVersion・要求者）＋Queueable エンキュー → commandId／QUEUED を即時返却 → Site は状態ポーリングへ移行。

### 7.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | 取消対象の投影（BookingExternalId__c・CurrentVersion__c）・要求者（Salesforce ユーザーID） | BD-07 §3 |
| 出力 | `Booking_Command__c` レコード・即時応答（commandId／QUEUED） | BD-09 §4.3 |

### 7.4 処理詳細

1. コマンド種別は CANCEL_BOOKING のみ受理（RULE-13）。
2. コマンド生成トランザクション内で Queueable を `System.enqueueJob` する（BD-01 §2 注記）。
3. `expectedVersion` には送信時点の投影 `CurrentVersion__c` を設定する。
4. 要求者の特定はブラウザ申告 ID ではなくサーバ側の静的マッピング検証に委ねる（実行時検証は F-25・RULE-12）。

### 7.5 例外処理・エラー処理

| 分岐 | 処理 | メッセージ方針（設計値・未実装） |
|---|---|---|
| 権限・行級判定の拒否 | コマンド生成前に終了（レコード残さない） | MSG-03 相当（権限不足） |
| 取消不可状態の事前抑制 | CANCELLED/COMPLETED の投影では取消ボタンを無効化（二重防止・最終判定は Booking 側 409） | ボタン非活性＋MSG-04 相当 |
| 受付失敗（SF 側障害） | エラー表示・再操作 | MSG-02 相当 |

### 7.6 排他制御・トランザクション境界

- コマンド生成（insert）＋エンキューを 1 トランザクションとする。
- 重複押下対策：ボタン連打による同一投影への複数コマンド生成は Booking 側の冪等・409 判定（RULE-03/07）で収斂する（commandId は押下ごとに新規発行のため、最終的に 1 件のみ CANCELLED 化・残りは 409 CONFLICT）。表示抑制（§7.5）は予防線であり権威ではない。

### 7.7 更新対象エンティティ

Salesforce：`Booking_Command__c`（insert・Status__c=QUEUED）。Booking：この時点では変更なし。

### 7.8 制約・前提条件

- 受付応答は 2 秒以内（NFR-03）。バックグラウンド実行の完了時間は目標値なし（非同期）。
- Booking 側受入エンドポイント（F-25）が未実装の間、本機能は単独で検証できない。

### 7.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | ポーリング間隔・最大継続時間の設計値 | P0-4 実装時 |
| 2 | 【決定済 2026-09-01】`resultCode` 値域＝CD-12（7 値封闭集・BD-09 §5 未決 4 と同日クローズ） | 決定済み（2026-09-01） |

## 8. F-25：コマンドバックグラウンド実行（🔵 P0-3 計画・未着手）

### 8.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | Queueable が Named Credential で Booking 統合端点を呼出し、Booking が Integration Guard・静的マッピング・ADMIN/ACTIVE・状態・expectedVersion を検証したうえで、同一トランザクションで正本を CANCELLED に更新する。409/503 の区分処理と手動 Retry を含む |
| 対応要件ID | REQ-022（主）・REQ-023・REQ-024・REQ-026・REQ-027・REQ-028・REQ-029・REQ-031 |
| 対応業務 | BIZ-14・BIZ-15 |
| 使用角色 | システム（Queueable ⇔ Booking 統合端点）。手動 Retry の判断は管理者 |

### 8.2 処理フロー

RD-04 図 6（QEU6→IGUARD6→IDEN6→BIZCHK6→CANUPD6→TERM6→RWRITE6）と `interview-portfolio-business-sequence.md` §2 F4 段・§3 異常時序を参照。I/F レベルの詳細は BD-09 IF-02。

### 8.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | `Booking_Command__c`（commandId・BookingExternalId__c・CommandType__c・ExpectedVersion__c・要求者・CorrelationId__c） | BD-07 §3 |
| 出力 | Booking 応答（200＋canonicalVersion＋resultCode／409＋currentVersion）・コマンド終状態・（成功時）結果書き戻し | BD-09 §4.3 |

### 8.4 処理詳細

Booking 側の検証順序（すべてサーバ側で実施・RULE-02/03/05/07/12 の引用）：

1. Integration Guard：secret の鍵バージョン・audience・scope・時刻偏差の検証（A3・TERM-23）。NG は 401/403。
2. commandId 重複判定：同一 commandId の再到達は初回保存済み結果をそのまま返す（RULE-03・業務判定より先行）。
3. 静的マッピング検証：`requestedBySalesforceUserId` に対応する Booking ユーザーが存在し active、かつ現在 ADMIN かつ ACTIVE であること。NG は拒否（RULE-12）。
4. 予約定位：`bookingExternalId` で正本を特定。不存在は 404（削除済み予約宛・REQ-033）。
5. 状態遷移検証：取消は PENDING/CONFIRMED のみ。CANCELLED 宛新 commandId・COMPLETED 宛は 409（RULE-05/07）。
6. バージョンゲート：`expectedVersion != 正本現在 version` は 409＋currentVersion＋correlationId（RULE-02）。
7. 全検証合格：同一トランザクションで正本 status=CANCELLED・version+1・応答 200＋canonicalVersion＋resultCode。
8. Queueable は明示 200/409 のみ終状態（SUCCEEDED/CONFLICT）を書込み、成功時はバージョンゲート付き結果書き戻し（F-26）を実行する（RULE-14）。

### 8.5 例外処理・エラー処理

| 分類 | 条件 | 処理 | 記録（REQ-031） |
|---|---|---|---|
| 認証系 | 401/403 | 終状態を書込まずエラー記録のみ・業務状態遷移なし | HttpStatus・LastError |
| 業務競合 | 409（検証 5〜6 の NG） | **リトライせず** CONFLICT 確定・人間が判断（BIZ-15） | HttpStatus・LastError・CorrelationId |
| 一時的障害 | 503/429/timeout | attemptCount+1・同一 commandId で限定回数自動リトライ・上限到達で FAILED | AttemptCount・NextAttemptAt・LastError |
| 手動 Retry | FAILED 確定後 | 原 commandId で再実行（新規 commandId を発行しない・Retry UI は P1 保留） | AttemptCount 更新 |

メッセージ方針：409 CONFLICT・FAILED は SF 側レコード上の状態・LastError で表現し、Site 利用者にはポーリング結果の状態表示（CANCELLED／失敗旨）を行う（BD-05 S-11・MSG-05 相当）。401/403 は利用者に表示しない。

### 8.6 排他制御・トランザクション境界

- Booking 側トランザクション境界：検証 3〜7 と正本更新を同一トランザクションとし、途中失敗は全てロールバックする。
- 排他：正本の楽観的排他は version ゲート（検証 6）が担う。同時コマンド到達時は先着 1 件のみ合法となり、後着は 409（currentVersion 更新後）となる。タイムアウト後重複は冪等（検証 2）で吸収する。
- P0 の直接呼出＋有限リトライは本番級の信頼性配信ではない（REQ-037・P1 の Outbox/Worker は対象外）。

### 8.7 更新対象エンティティ

| システム | エンティティ | 操作 |
|---|---|---|
| Booking | `Appointment` | update（status=CANCELLED・version+1・syncStatus=PENDING） |
| Salesforce | `Booking_Command__c` | update（Status__c=RUNNING→SUCCEEDED/CONFLICT/FAILED・AttemptCount__c・HttpStatus__c・NextAttemptAt__c・ResultCode__c・ResultVersion__c・LastError__c） |

### 8.8 制約・前提条件

- 静的マッピング（active 1 件）・Integration Guard 設定（secret・鍵バージョン管理）の事前構築が前提（いずれも P0-3・未実装）。
- Queueable は正本 canonical 状態を直接書かない（BD-07 §3 境界制約）。
- リトライ上限・間隔はパラメータ化対象（RULE-09/10・具体値は P0-3 実装時）。

### 8.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | Integration Guard の secret 鍵バージョン管理方式（ローテーション手順を含む） | P0-3 実装設計時 |
| 2 | リトライ上限回数・間隔・NextAttemptAt の具体値 | P0-3 実装時 |
| 3 | 【決定済 2026-09-01】404 の resultCode 区分＝CD-12 NOT_FOUND（HttpStatus 区分・非終態扱いは BD-09 §5 補記のとおり）。REQ-033 の決定記録は 2026-09-01 に成文済み（CHK-01 C-3 [x]・p0-2/interview-portfolio-req033-decision-record.md 参照） | 決定済み（2026-09-01） |

## 9. F-26：結果書き戻し（🔵 P0-3 計画・未着手）

### 9.1 機能概要

| 項目 | 内容 |
|---|---|
| 目的 | コマンド成功後、バージョンゲート付きで canonical result（正本 CANCELLED の結果）を `Booking__c` に書き戻す（incomingVersion が現行より高い場合のみ更新） |
| 対応要件ID | REQ-025（＋REQ-024） |
| 対応業務 | BIZ-14 |
| 使用角色 | システム（Queueable → 投影サービス） |

### 9.2 処理フロー

RD-04 図 6（RWRITE6）を参照。F-25 の SUCCEEDED 確定後に、Queueable が投影書き戻し（IF-01 と同一の投影経路・RULE-01 のバージョンゲート）を呼び出す。

### 9.3 入力項目・出力項目

| 区分 | 内容 | 参照 |
|---|---|---|
| 入力 | コマンド実行結果（canonicalVersion・resultCode） | BD-09 §4.3 |
| 出力 | `Booking__c` の canonical 項目更新（Status__c=CANCELLED・CurrentVersion__c 等） | BD-07 §3 |

### 9.4 処理詳細

- 書き戻しは `incomingVersion`（正本の新 version）が `Booking__c.CurrentVersion__c` より高い場合のみ `Booking__c` を更新する（REQ-025）。
- 終状態（SUCCEEDED/CONFLICT）の書込みは Booking から明示 200/409 を受信した場合のみに限定される（RULE-14）。
- 書き戻し経路は通常の投影入口（TERM-24）を再利用し、専用の直書込経路を作らない（投影専用書込の原則・BD-07 §3）。

### 9.5 例外処理・エラー処理

- 書き戻し失敗（ネットワーク・認証）：コマンド自体は SUCCEEDED のまま、`Booking__c` の `LastError`・`SyncStatus__c` に記録し手動 Retry（再投影）で整合回復する。
- バージョンゲート拒否（到着時点で既に新しい投影が存在）：上書きしない（正しい挙動・記録のみ）。

### 9.6 排他制御・トランザクション境界

バージョンゲート（RULE-01）が排他の本体。書き戻しはコマンド実行トランザクション外の独立呼出であり、Booking 側正本トランザクションには含まれない。

### 9.7 更新対象エンティティ

Salesforce：`Booking__c`（update・canonical 項目・CurrentVersion__c・LastEventId__c）。Booking：変更なし（F-25 で既に更新済み）。

### 9.8 制約・前提条件

F-25 の成功応答（明示 200）が前提。200 以外（409・認証系・timeout）では書き戻しを実行しない。

### 9.9 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 書き戻し失敗時の検知手段（P0 は手動確認・周期照合なし） | P1 検討（REQ-037） |

## 10. 連携関連の権限・確認系機能（BD-02 §5 からの引用展開）

### 10.1 F-32：オブジェクト権限マトリクス（【凍結済 2026-09-01】）

- 概要：`Booking__c`／`Booking_Command__c` に対する外部ユーザーの最小 CRUD/FLS・Sharing Set 行級・External OWD=Private を凍結する（REQ-030・対応業務 BIZ-13/BIZ-14）。
- 導出根拠：「数値は CHK-01 C-4 方針（外部ユーザー＝投影 Read＋コマンド Create のみ）・DD-02 §3.3 SOQL 実測・DD-01 §4.1/§4.2 項目一覧・BD-07 §3 書込入口制約・REQ-036 から導出（2026-09-01 凍結）」。
- 適用対象：本マトリクスの適用対象は Site 操作ユーザー（F-23/F-24 経路・Sharing Set 行級）であり、IF-01 §3.2 の統合ユーザー（integration principal・JWT Bearer）には適用しない。統合ユーザー用の権限セットは投影 REST が LastEventId__c／CorrelationId__c／LastError__c を参照するため本表とは別体系となり、**P0-3 で確定済み（2026-09-02・CHK-02 C-7）**：Salesforce Integration license＋Minimum Access - API Only Integrations＋SalesforceAPIIntegrationPsl＋PS `Booking_Integration_User`（Booking__c Read/Create/Edit＋13 項目 FLS＋`BookingProjectionRest` class access＋ユーザー権限「Apex REST サービス」）。

**表 1：Booking__c・外部ユーザー権限（13 項目）**——オブジェクト権限＝**Read のみ**（Create/Update/Delete 不付与）。行級＝OWD Private＋Sharing Set（Account__c キー・自 Account のみ）。

| # | 項目物理名 | Read | Create | Edit | Delete | 根拠 |
|---|---|---|---|---|---|---|
| 1 | BookingExternalId__c | ○ | × | × | × | LWC 行定位（S-11-10・getProjections SELECT 実測） |
| 2 | AppointmentNumber__c | ○ | × | × | × | S-11-05 表示 |
| 3 | AppointmentDate__c | ○ | × | × | × | S-11-05 表示 |
| 4 | TimeSlot__c | ○ | × | × | × | S-11-05 表示 |
| 5 | ServiceName__c | ○ | × | × | × | S-11-05 表示 |
| 6 | Status__c | ○ | × | × | × | 表示・取消可否判定 |
| 7 | CurrentVersion__c | ○ | × | × | × | expectedVersion 送信値（S-11-10） |
| 8 | LastEventId__c | × | × | × | × | 内部同期管理・UI 参照なし |
| 9 | SyncStatus__c | ○ | × | × | × | getProjections SELECT 実測（DD-02 §3.3） |
| 10 | CorrelationId__c | × | × | × | × | 内部監査 |
| 11 | LastError__c | × | × | × | × | 内部監査 |
| 12 | Account__c | ○ | × | × | × | Sharing Set 行級キー・WHERE フィルタ（WITH SECURITY_ENFORCED 対象） |
| 13 | Admin_Note__c | × | × | × | × | 管理者メモ・外部秘匿（REQ-036：SF 側編集は管理者のみ） |

表後注記：全項目 C/U/D 不付与＝Booking__c の唯一の書込入口は投影 REST（BD-07 §3 境界制約）。Read 付与集合＝getProjections の SELECT 実測 9 項目＋Account__c の最小権限。

**表 2：Booking_Command__c・外部ユーザー権限（16 項目）**——オブジェクト権限＝**Create・Read**（Update/Delete 不付与）。OWD Private＝自己生成コマンドのみ可視（生成者＝実行ユーザー）→ getCommandStatus ポーリング成立。Queueable による状態・監査項目の更新は Apex（system context・CRUD/FLS 非強制）で実施するため権限付与不要。

| # | 項目物理名 | Read | Create | Edit | Delete | 根拠 |
|---|---|---|---|---|---|---|
| 1 | CommandId__c | ○ | ○ | × | × | 採番設定・ポーリング定位キー（TERM-12） |
| 2 | BookingExternalId__c | × | ○ | × | × | insert 時設定 |
| 3 | CommandType__c | × | ○ | × | × | CANCEL_BOOKING（RULE-13） |
| 4 | ExpectedVersion__c | × | ○ | × | × | 送信時 CurrentVersion__c 設定 |
| 5 | RequestedBySalesforceUserId__c | × | ○ | × | × | 要求者設定 |
| 6 | RequestedByBookingUserId__c | × | × | × | × | Booking 側解決値（SF insert では設定しない・DD-01 §4.2） |
| 7 | Status__c | ○ | ○ | × | × | QUEUED 初期値設定＋ポーリング表示（S-11-07） |
| 8 | AttemptCount__c | × | × | × | × | Queueable 管理（Apex） |
| 9 | NextAttemptAt__c | × | × | × | × | 同上 |
| 10 | HttpStatus__c | × | × | × | × | 同上 |
| 11 | ResultCode__c | × | × | × | × | 同上（CD-12） |
| 12 | ResultVersion__c | × | × | × | × | 同上 |
| 13 | CurrentVersion__c | × | × | × | × | 409 応答値（Queueable 記録） |
| 14 | CorrelationId__c | × | × | × | × | Queueable 記録（TERM-17） |
| 15 | LastError__c | × | × | × | × | 同上 |
| 16 | ResponseBodyRedacted__c | × | × | × | × | 同上（PII 非含有） |

表後注記：Create 付与集合＝submitCancel の insert 設定項目（DD-02 §3.3 処理概要 2 実測）。Read 付与＝ポーリング経路の最小集合（Id＋CommandId__c＋Status__c）。

- 処理詳細（設計値）：外部ユーザーへの付与は「自 Account の投影・コマンドの参照（Read）＋コマンドの作成（Create）」に限定し、投影の Create/Update/Delete・コマンドの Update/Delete は付与しない方針。Apex は with sharing。FLS は LWC／Apex の双方で参照項目を最小化。項目別権限値は上表のとおり確定済み（2026-09-01 凍結）。
- 例外処理：越権アクセス（他 Account のレコード ID 直指定）は行級範囲で取得不能（MV-07 で確認）。
- 排他・トランザクション：対象外（設定）。
- 更新対象エンティティ：なし（Salesforce 設定変更）。
- 制約・前提：凍結後の変更は契約変更手順（BD-09 §3.3・RULE-11 の凍結管理に準ずる）。
- 未決事項：【決定済 2026-09-01】項目別 CRUD/FLS の最終値（上表のとおり凍結）。

### 10.2 F-30／F-31：確認系・静的運用（既存・P0-1）

- F-30（Site アクセス・メンバー管理）：Network Live・メンバー 4 件・SelfReg=false の維持確認であり、機能設計上の新規展開対象外（REQ-034 の不実施確認対象）。
- F-31（外部ユーザーライフサイクル・静的部分）：事前設定 1 名の静的運用のみ。動的部分（SalesforceUserLink・sfAccessStatus 遷移）は P1 設計目標（未実装）であり本書では展開しない（REQ-038・P1 保留）。

## 11. 対象外とする機能（本書で展開しない根拠）

| 機能ID | 機能名 | 対象外の根拠 |
|---|---|---|
| F-01〜F-14 | Booking 既存機能 | §2 のとおり RD-01・api-contract が正。本書未展開 |
| F-15 | ファイルアップロード | 本スライス対象外（RD-01 §1 注記・BD-02 §6 No.10） |
| F-33 | 信頼性配信・対合・告警 | P1・本件スコープ外（REQ-037・BD-02 §6 No.4） |
| F-31 動的部分 | 動的 provisioning | P1 保留（REQ-038） |

## 12. 未決事項（全体横断）

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】External ID＝uuid `id`（TERM-14・F-20/F-25 共通。DD-01 §5 未決 1 と同日クローズ） | 決定済み（2026-09-01） |
| 2 | 静的マッピングの実装方式（§4.9 と同源） | P0-3 実装設計時 |
| 3 | 各機能のメッセージ文面の確定（MSG-xx は BD-05 §3.1 に設計値として定義） | P0-4 実装時 |
