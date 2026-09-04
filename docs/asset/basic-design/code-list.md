# コード一覧／コード設計（基本設計）

| 項目 | 内容 |
|---|---|
| 文書ID | BD-08 |
| 版数 | V1.0（ドラフト・雛形準拠） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（基本設計フェーズ・コード設計） |

## 1. 文書の位置づけと雛形対応

- 本書は基本設計八文書の一つ（BD-08）。コード値（区分値・状態値）の値域と意味を管理し、画面（BD-05）・機能（BD-03）・I/F（BD-09）から参照される。
- 値域の事実源は `booking-backend/prisma/schema.prisma` の enum 定義実測（2026-08-31 読取）と BD-07『ERD』§3 の Salesforce 側計画項目である。本書で新しいコード値を製造していない。
- 雛形（交付物雛形集 4.9 コード一覧）の 8 項目＝本書主表の 8 列：コードID／コード名・物理名／値域と各値の意味／桁数・型（論理）／分類／管理方法／変更頻度／影響範囲。物理型・桁数の厳密定義は詳細設計（テーブル定義書）に属するため、本書では論理水準のみ記載する。

## 2. コード一覧

| コードID | コード名・物理名 | 値域と各値の意味 | 桁数・型（論理） | 分類 | 管理方法 | 変更頻度 | 影響範囲 |
|---|---|---|---|---|---|---|---|
| CD-01 | ユーザー種別・`UserType` | CUSTOMER＝顧客（一般ユーザー・TERM-05）；ADMIN＝管理者（TERM-06） | 半角英字 8 桁程度・enum 文字列 | 業務コード | ハードコード（Prisma enum・現状マスタなし） | 低（P0 追加なし） | S-01〜S-05（ロール判定）・A1 認証（jwt-auth.guard の DB 参照）・NFR-05 認可・静的マッピング（RULE-12） |
| CD-02 | ユーザー状態・`UserStatus` | ACTIVE＝有効；INACTIVE＝無効（ログイン不可）；BLOCKED＝ブロック（ログイン不可） | 半角英字 7〜8 桁程度・enum 文字列 | 業務コード | ハードコード（Prisma enum・現状マスタなし） | 低 | S-04 ユーザー管理・S-05 提示・セッション取消（RULE-17）・JwtAuthGuard の `status !== 'ACTIVE'` 判定（実測） |
| CD-03 | 予約状態・`AppointmentStatus` | PENDING＝受付済（未確定）；CONFIRMED＝確定；CANCELLED＝取消済（**終状態**）；COMPLETED＝完了（**終状態**） | 半角英字 7〜10 桁程度・enum 文字列 | 業務コード | ハードコード（Prisma enum・現状マスタなし） | 低（値追加時は I/F 契約変更を伴う） | S-03・S-04・S-11（S-11-05）・IF-01（§3.6 変換表）・IF-02（409 判定）・RULE-05・RULE-07・RULE-15・retention 対象判定・BD-07 |
| CD-04 | 通知種別・`NotificationType` | SMS＝SMS 通知；EMAIL＝メール通知；WECHAT＝WeChat 通知；PUSH＝プッシュ通知 | 半角英字 3〜6 桁程度・enum 文字列 | 業務コード | ハードコード（Prisma enum・現状マスタなし） | 低 | F-09 通知モジュール・WebSocket 配信・S-03 通知表示 |
| CD-05 | 通知状態・`NotificationStatus` | PENDING＝送信待ち；SENT＝送信済；FAILED＝送信失敗；CANCELLED＝取消済（送信取消） | 半角英字 6〜9 桁程度・enum 文字列 | 業務コード | ハードコード（Prisma enum・現状マスタなし） | 低 | F-09 通知送信・再送判定・S-03 通知表示 |
| CD-06 | 同期状態・`syncStatus` ✅ 実装済（2026-09-02・booking-backend 71c88c8） | PENDING＝投影待ち（正本変更トランザクション内で設定）；SYNCED＝投影済；ERROR＝投影エラー（手動 Retry 対象） | 半角英字 6〜7 桁程度・文字列（TERM-16） | システム内部コード | ハードコード（migration 追加済・現状マスタなし） | 低 | F-20（投影）・IF-01（§3.8 異常時処理）・BD-07 §2.2（計画増分）・運用確認（BIZ-15 手順） |
| CD-07 | 投影状態・`Booking__c.Status__c` ✅ 実装済（オブジェクト作成 2026-09-02・S-1） | CD-03 と同一の canonical 値：PENDING／CONFIRMED／CANCELLED（終状態）／COMPLETED（終状態）。変換ロジックなし・値の一致を I/F 契約とする（BD-09 §3.6） | 半角英字 7〜10 桁程度・Salesforce テキスト | 業務コード（投影複製値） | ハードコード（Booking 側 CD-03 と同一値域・SF 側 **非制限 Picklist** 確定（【決定済 2026-09-01】・restricted なし。値追加は I/F 契約変更に伴う）） | 低（CD-03 と同期して管理） | S-11（S-11-05）・F-23・IF-01・バージョンゲート表示（F-26） |
| CD-08 | コマンド状態・`Booking_Command__c.Status__c` ✅ 実装済（オブジェクト作成 2026-09-02・S-2） | QUEUED＝受付済（実行待ち）；RUNNING＝実行中；SUCCEEDED＝成功（**終状態**・明示 200 受信時のみ）；CONFLICT＝業務競合（**終状態**・409 受信時のみ・リトライしない）；FAILED＝失敗（**終状態**・リトライ上限超過） | 半角英字 6〜9 桁程度・Salesforce テキスト（TERM-35・固定遷移 QUEUED→RUNNING→終状態） | システム内部コード | ハードコード（SF 側 **制限 Picklist** 確定（【決定済 2026-09-01】・restricted あり・SF 内部コードのみ書込）） | 低（プロトコル規約） | F-24（受付・QUEUED）・F-25（実行・終状態書込 RULE-14）・S-11-07（ポーリング表示）・IF-02（§4.8）・BIZ-15 手動 Retry |
| CD-09 | 設定型別・`SettingType` | STRING＝文字列；NUMBER＝数値；BOOLEAN＝真偽値；JSON＝JSON 構造 | 半角英字 4〜6 桁程度・enum 文字列 | システム内部コード | ハードコード（Prisma enum・現状マスタなし） | 低 | `SystemSetting` モデルのみ。対応端点（`/v1/system/*`）は `SystemModule` 未インポートのため現状不可用（BD-01 §5 注記・UI 影響なし） |
| CD-10 | 設定分類・`SettingCategory` | GENERAL＝一般；SECURITY＝セキュリティ；BUSINESS＝業務；SYSTEM＝システム | 半角英字 6〜9 桁程度・enum 文字列 | システム内部コード | ハードコード（Prisma enum・現状マスタなし） | 低 | `SystemSetting` モデルのみ（CD-09 同様・現状 UI 影響なし） |
| CD-11 | 予約操作・`AppointmentAction` | CREATE＝作成；UPDATE＝変更；CONFIRM＝確定；CANCEL＝取消；COMPLETE＝完了 | 半角英字 6〜8 桁程度・enum 定義 | システム内部コード | ハードコード（**enum 定義は存在するが参照先なし**：`AppointmentHistory.action` は VarChar(50) の文字列保存・実測） | 低 | `AppointmentHistory`（書込み経路なし・BD-07 §4.2）。連携監査では使用しない（REQ-031 備考と一致） |
| CD-12 | コマンド結果コード・`Booking_Command__c.ResultCode__c` ✅ 実装済（オブジェクト作成 2026-09-02・S-2） | SUCCESS＝200（SUCCEEDED＋結果書戻し）；CONFLICT＝409（終状態・リトライせず）；VALIDATION_ERROR＝400（終状態不写・エラー記録）；NOT_FOUND＝404（同上・削除予約宛含む）；AUTH_ERROR＝401/403（同上）；TRANSIENT_ERROR＝503/429/timeout（AttemptCount+1→上限内リトライ）；SYSTEM_ERROR＝500/その他（兜底・エラー記録） | 半角英字大文字スネーク 6〜16 桁程度・Salesforce テキスト（既存 envelope code と同規約・粗碼） | システム内部コード | ハードコード（7 値封闭集・【決定済 2026-09-01】・一分支一码。詳細情報は LastError__c／ResponseBodyRedacted__c に分離） | 低（プロトコル規約） | F-25（Queueable 状態機構・RULE-09/14）・IF-02・BIZ-15 手動 Retry・DD-02 §3.2・DD-04 TC-07〜11 |

## 3. 管理方針の補足

- **全コードとも現状マスタなし**（ハードコード enum 定義・SF 側 picklist）。マスタ管理への移行は行わない方針であり、値の変更は改修（発版・SF 側は picklist 変更）を伴う。
- マスタ化候補の既存記録の引用：時間枠の実効容量値（現状ハードコード値 1）は RULE-06 の「パラメータ化要否＝要（容量値。P1 でマスタ化候補）」に既に明記されており、本書はこれを引用するのみである。コード値そのもの（CD-03 等）のマスタ化候補は存在しない。
- **終状態の扱い**：CD-03 の CANCELLED／COMPLETED、CD-08 の SUCCEEDED／CONFLICT／FAILED は終状態であり、RD-05（RULE-05・RULE-14）のとおり遷移不可・限定経路でのみ書込む。CD-02 と CD-03 の取消（CANCELLED）は意味が異なる（ユーザー状態の取消 vs 予約状態の取消）ため混同しない。
- **外部システム消費値の変更管理**：CD-03／CD-07／CD-08 は I/F（BD-09）で先方に渡る値であるため、追加・変更時は BD-09 のコード変換節と本書を同時に更新し、Salesforce 側の取り込み前に I/F 契約を確定させる（雛形記載要点の適用）。
- コード値の廃止は行わず、履歴データの解釈可能性を保持する方針（レコードの物理削除方針・BD-07 §4.4 と整合）。

## 4. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】CD-07＝非制限 Picklist・CD-08＝制限 Picklist・ResultCode＝CD-12 新設（上表参照） | 決定済み（2026-09-01） |
| 2 | CD-06（`syncStatus`）の migration 実施【決定済/実施済 2026-09-02・71c88c8】（現行 13 モデルには存在しない） | P0-2 契約凍結後 |
| 3 | 【決定済 2026-09-01】IF-02 応答の `resultCode` 値域＝CD-12（7 値封闭集。预告の新コードID は CD-12 として上表へ追記済み・BD-09 §5 未決 4 と同日クローズ） | 決定済み（2026-09-01） |
