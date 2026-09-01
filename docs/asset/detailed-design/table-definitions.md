# テーブル定義書（物理・詳細設計）

| 項目 | 内容 |
|---|---|
| 文書ID | DD-01 |
| 版数 | V1.0（ドラフト） |
| 作成日 | 2026-08-31 |
| 対象 | Booking × Salesforce Experience Cloud 連携（詳細設計フェーズ・テーブル定義） |

## 1. 文書の位置づけと雛形対応

- 本書は詳細設計四文書の一つ（DD-01）。基本設計 BD-07『ERD』（erd.md）の論理モデルを物理層へ落としたテーブル定義書である。論理モデル＝BD-07、用語・命名＝RD-06『用語集』（用語ID TERM-xx・物理名候補）を正とし、本書は物理層（PostgreSQL 実型・NULL 許否・デフォルト・PK/FK・インデックス・削除制約）のみを扱う。DDL（CREATE TABLE 文）は本書から生成する（Prisma migration 運用）。
- 雛形（交付物雛形集 5.1 テーブル定義書）の 7 項目への対応：テーブル物理名/論理名＝各 §2 テーブル見出し／カラム物理名/論理名・型・桁数・NULL 許否・デフォルト・PK/FK・制約＝各カラム一覧表／インデックス＝§2 のインデックス一覧／パーティション＝§3。
- 事実源（実測）：`booking-backend/prisma/schema.prisma`（2026-08-31 読取・13 モデル全フィールド）。Salesforce 側オブジェクトは BD-07 §3 の計画項目（🔵 契約凍結済み（2026-09-01）・未作成）であり、**本書の SF 側記載はすべて設計値（P0-2 契約・未作成）** である。
- 状態表記：✅＝既存実装（schema.prisma 実測）｜🔵＝P0 計画（未実装）。本書の Booking 側 13 テーブルは ✅、§2.15 の integration_commands は 🔵（P0-2 計画・第 14 モデル）、Salesforce 側 2 オブジェクトは 🔵 設計値。

## 2. Booking 側テーブル定義（✅ 実測・schema.prisma 基準）

### 2.0 型マッピング規約（Prisma 型 → PostgreSQL 実型）

schema.prisma の型を PostgreSQL 実型へ落とす規約。**`@db.` ネイティブ型注記がある場合はそれを優先し、注記がない型は Prisma 既定の PostgreSQL 型**を採用する（下記はすべて schema.prisma 実測の対応）。

| Prisma 型 | PostgreSQL 実型 | 根拠（schema.prisma 実測） |
|---|---|---|
| `String` + `@db.Uuid` | `UUID` | id・FK 列ほか |
| `String` + `@db.VarChar(n)` | `VARCHAR(n)` | 文字列の大半（桁数は注記値） |
| `String` + `@db.Text` | `TEXT` | remarks・userAgent 等 |
| `String` + `@db.Inet` | `INET` | ip_address（users / user_sessions / appointments） |
| `String`（注記なし） | `TEXT` | Appointment.notes / userAgent・ServiceCategory.description・Service.description（下表のとおり。Prisma 既定は text） |
| `Int` | `INTEGER` | 数値項目全般 |
| `Boolean` | `BOOLEAN` | フラグ項目全般 |
| `DateTime` + `@db.Date` | `DATE` | 日付のみ項目（appointmentDate 等） |
| `DateTime`（注記なし） | `TIMESTAMP(3)` | 日時項目（UTC 保持・タイムゾーンなし） |
| `Float` | `DOUBLE PRECISION` | Service.price・AppointmentStatistic.averageLeadTimeHours（Prisma Float の既定） |
| `Json`（`@db.JsonB` 注記あり） | `JSONB` | deviceInfo・metadata・context |
| Prisma enum | 同名の PostgreSQL enum 型 | UserType／UserStatus／AppointmentStatus／NotificationType／NotificationStatus／SettingType／SettingCategory（Prisma migrate が生成） |

注記：
- パーティションは**採用しない**（デモ規模・RD-02 測定規模の前提。全テーブルでパーティションなし）。
- 論理削除フラグ（deletedAt 等）は 13 テーブルのいずれにも存在しない（BD-07 §4.4 と一致）。削除は原則物理削除。
- Prisma enum `AppointmentAction` はモデルから参照されない（BD-08 CD-11 実測）ため、PostgreSQL の enum 型としては生成されない（migration の生成対象外）。

### 2.1 users（ユーザー）

- 論理名：ユーザー（TERM-05/06）｜説明：顧客（CUSTOMER）と管理者（ADMIN）のアカウント。電話番号がログイン認証情報

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | ユーザーID | UUID | NOT NULL | gen_random_uuid() | ○ | | | @default(uuid()) |
| 2 | name | 氏名 | VARCHAR(100) | NOT NULL | — | | | | |
| 3 | phone | 電話番号 | VARCHAR(20) | NOT NULL | — | | ○ | | @unique |
| 4 | phone_hash | 電話番号ハッシュ | VARCHAR(64) | NOT NULL | — | | ○ | | @unique・@map("phone_hash") |
| 5 | email | メールアドレス | VARCHAR(255) | NULL 可 | — | | ○ | | @unique |
| 6 | wechat | WeChat ID | VARCHAR(100) | NULL 可 | — | | | | |
| 7 | remarks | 備考 | TEXT | NULL 可 | — | | | | |
| 8 | is_verified | 検証済フラグ | BOOLEAN | NOT NULL | false | | | | |
| 9 | user_type | ユーザー種別 | enum "UserType" | NOT NULL | CUSTOMER | | | | CD-01 |
| 10 | status | ユーザー状態 | enum "UserStatus" | NOT NULL | ACTIVE | | | | CD-02 |
| 11 | last_login_at | 最終ログイン日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 12 | login_count | ログイン回数 | INTEGER | NOT NULL | 0 | | | | |
| 13 | ip_address | IP アドレス | INET | NULL 可 | — | | | | |
| 14 | user_agent | ユーザーエージェント | TEXT | NULL 可 | — | | | | |
| 15 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 16 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス（schema.prisma 実測）：`@@index([phone_hash])`・`@@index([status])`・`@@index([created_at])`。加えて UK（phone・phone_hash・email）に一意インデックス。

リレーション・削除制約：子は UserSession／Appointment／Notification／AppointmentHistory／ActivityLog／BlockedTimeSlot／SystemLog。**明示 onDelete: Cascade は UserSession.user のみ**（親削除時にセッション連鎖削除）。その他の子リレーション（Appointment.user・Notification.user・AppointmentHistory.user・ActivityLog.user・BlockedTimeSlot.user・SystemLog.user）は onDelete 指定なし＝DB 既定挙動。**実 DB 削除挙動は 2026-09-01 pg_constraint 実測済み（§2.14・§5 未決 3 クローズ記録参照）**。

### 2.2 user_sessions（ユーザーセッション）

- 論理名：ユーザーセッション（用語集 TERM 対応なし・BD-07 §2.1）｜説明：JWT セッションの記録。状態変更時のセッション取消（RULE-17）の対象

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | セッションID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | user_id | ユーザーID | UUID | NOT NULL | — | | | → users.id | onDelete: Cascade（明示） |
| 3 | session_token | セッショントークン | VARCHAR(255) | NOT NULL | — | | ○ | | @unique |
| 4 | refresh_token | リフレッシュトークン | VARCHAR(255) | NULL 可 | — | | ○ | | @unique |
| 5 | expires_at | 有効期限 | TIMESTAMP(3) | NOT NULL | — | | | | |
| 6 | refresh_expires_at | リフレッシュ有効期限 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 7 | ip_address | IP アドレス | INET | NULL 可 | — | | | | |
| 8 | user_agent | ユーザーエージェント | TEXT | NULL 可 | — | | | | |
| 9 | device_info | デバイス情報 | JSONB | NULL 可 | — | | | | |
| 10 | is_active | 有効フラグ | BOOLEAN | NOT NULL | true | | | | |
| 11 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：`@@index([user_id])`・`@@index([session_token])`・`@@index([expires_at])`。UK（session_token・refresh_token）に一意インデックス。

削除制約：親 User 削除時に Cascade（§2.1 と重複記載）。

### 2.3 time_slots（予約枠）

- 論理名：予約枠（TERM-02）｜説明：予約可能な日時単位。実効容量は 1（RULE-06 の現行ハードコード値）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 予約枠ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | slot_time | 枠時刻 | VARCHAR(8) | NOT NULL | — | | ○ | | @unique・HH:mm:ss 形式 |
| 3 | duration_minutes | 所要分数 | INTEGER | NOT NULL | 30 | | | | |
| 4 | is_active | 稼働フラグ | BOOLEAN | NOT NULL | true | | | | |
| 5 | display_order | 表示順 | INTEGER | NULL 可 | — | | | | |
| 6 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 7 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス：`@@unique([slot_time])`・`@@index([is_active])`・`@@index([display_order])`。

リレーション・削除制約：子は Appointment（必須参照・onDelete 指定なし）／BlockedTimeSlot（任意参照・onDelete 指定なし）。明示 Cascade なし。実 DB 削除挙動は 2026-09-01 pg_constraint 実測済み（§2.14・§5 未決 3 クローズ記録参照）。

### 2.4 appointments（予約＝正本）

- 論理名：予約（正本・TERM-08）｜説明：予約状態の唯一の権威あるデータ。顧客情報のスナップショット項目を持つ。🔒 5 項目は投影ホワイトリスト外（TERM-29・RULE-11）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 予約ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | appointment_number | 予約番号 | VARCHAR(20) | NOT NULL | — | | ○ | | @unique・AP-yyyymmdd-0001 形式（TERM-15） |
| 3 | user_id | ユーザーID | UUID | NULL 可 | — | | | → users.id | onDelete 指定なし |
| 4 | appointment_date | 予約日 | DATE | NOT NULL | — | | | | |
| 5 | time_slot_id | 予約枠ID | UUID | NOT NULL | — | | | → time_slots.id | onDelete 指定なし（必須参照） |
| 6 | service_id | サービスID | UUID | NULL 可 | — | | | → services.id | onDelete 指定なし（任意参照） |
| 7 | status | 予約状態 | enum "AppointmentStatus" | NOT NULL | PENDING | | | | CD-03 |
| 8 | customer_name | 顧客氏名 🔒 | VARCHAR(100) | NOT NULL | — | | | | PII（TERM-29） |
| 9 | customer_phone | 顧客電話番号 🔒 | VARCHAR(20) | NOT NULL | — | | | | PII。スキーマのコメントは暗号化保存を示唆するが、既存の読取調査では平文保存・応答層のみマスクと報告（BD-07 §2.2 現状要点） |
| 10 | customer_email | 顧客メール 🔒 | VARCHAR(255) | NULL 可 | — | | | | PII |
| 11 | customer_wechat | 顧客WeChat 🔒 | VARCHAR(100) | NULL 可 | — | | | | PII |
| 12 | notes | 備考 🔒 | TEXT | NULL 可 | — | | | | PII。@db 注記なし String → text |
| 13 | ip_address | IP アドレス | INET | NULL 可 | — | | | | |
| 14 | user_agent | ユーザーエージェント | TEXT | NULL 可 | — | | | | @db 注記なし String → text |
| 15 | confirmation_sent | 確認メール送信済 | BOOLEAN | NOT NULL | false | | | | |
| 16 | reminder_sent | リマインダー送信済 | BOOLEAN | NOT NULL | false | | | | |
| 17 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 18 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |
| 19 | confirmed_at | 確定日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 20 | cancelled_at | 取消日時 | TIMESTAMP(3) | NULL 可 | — | | | | retention 判定基準（DD-03 §3 参照） |
| 21 | completed_at | 完了日時 | TIMESTAMP(3) | NULL 可 | — | | | | retention 判定基準 |

インデックス：`@@index([user_id])`・`@@index([appointment_date])`・`@@index([time_slot_id])`・`@@index([time_slot_id, appointment_date])`・`@@index([status])`・`@@index([appointment_number])`。UK（appointment_number）に一意インデックス。

リレーション・削除制約：子は AppointmentHistory（onDelete: Cascade 明示）／Notification（onDelete: Cascade 明示）。親参照（user・timeSlot・service）はいずれも onDelete 指定なし。`DELETE /v1/bookings/:id`（F-08 ハード削除）が親参照に与える実 DB 削除挙動は 2026-09-01 pg_constraint 実測済み（SET NULL／RESTRICT 詳細は §2.14・§5 未決 3 クローズ記録参照。F-08・retention は子テーブル明示 Cascade のため安全）。

P0-2 計画増分（🔵 設計値・未実装）：`version`（INTEGER NOT NULL DEFAULT 0 確定・2026-09-01 拍板・TERM-10）と `syncStatus`（VARCHAR(16) NOT NULL DEFAULT 'PENDING'・2026-09-01 拍板・enum 案不採用。根拠：NFR-13 P1 無破壊変更・CD-06 文字列定位・SF 側 SyncStatus__c テキスト镜像・TERM-16）の 2 カラムを追加予定。**現行スキーマには存在しない**（schema.prisma 実測・BD-07 §2.2・NFR-13）。型・制約は 2026-09-01 拍板で確定済み。migration 実施は CHK-01 B-1 で別管理。

### 2.5 appointment_history（予約履歴）

- 論理名：予約履歴（BD-07 §2.1）｜説明：予約状態変更の履歴管理用モデル。実装上の書込み経路なし（BD-07 §4.2・REQ-031 備考）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 履歴ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | appointment_id | 予約ID | UUID | NOT NULL | — | | | → appointments.id | onDelete: Cascade（明示） |
| 3 | action | 操作種別 | VARCHAR(50) | NOT NULL | — | | | | 文字列保存（enum 参照なし・CD-11） |
| 4 | previous_status | 変更前状態 | VARCHAR(20) | NULL 可 | — | | | | |
| 5 | new_status | 変更後状態 | VARCHAR(20) | NULL 可 | — | | | | |
| 6 | changed_by | 変更者 | UUID | NULL 可 | — | | | → users.id | onDelete 指定なし（任意参照） |
| 7 | change_reason | 変更理由 | TEXT | NULL 可 | — | | | | |
| 8 | metadata | メタデータ | JSONB | NULL 可 | — | | | | |
| 9 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：`@@index([appointment_id])`・`@@index([created_at])`。

### 2.6 system_settings（システム設定）

- 論理名：システム設定（BD-07 §2.1）｜説明：設定キー・バリューの保存。対応端点（`/v1/system/*`）は SystemModule 未インポートのため現状不可用（BD-01 §5 注記）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 設定ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | setting_key | 設定キー | VARCHAR(100) | NOT NULL | — | | ○ | | @unique |
| 3 | setting_value | 設定値 | TEXT | NULL 可 | — | | | | |
| 4 | setting_type | 設定型別 | enum "SettingType" | NOT NULL | STRING | | | | CD-09 |
| 5 | description | 説明 | TEXT | NULL 可 | — | | | | |
| 6 | is_public | 公開フラグ | BOOLEAN | NOT NULL | false | | | | |
| 7 | category | 設定分類 | enum "SettingCategory" | NOT NULL | GENERAL | | | | CD-10 |
| 8 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 9 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス：UK（setting_key）のみ。リレーションなし。

### 2.7 blocked_time_slots（予約枠停止）

- 論理名：予約枠停止（BD-07 §2.1）｜説明：枠の停止記録。モデルは在るが端点未実装（既知課題・REQ-012/F-13 備考）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 停止ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | blocked_date | 停止日 | DATE | NOT NULL | — | | | | |
| 3 | time_slot_id | 予約枠ID | UUID | NULL 可 | — | | | → time_slots.id | onDelete 指定なし（任意参照） |
| 4 | reason | 理由 | TEXT | NULL 可 | — | | | | |
| 5 | blocked_by | 停止実施者 | UUID | NULL 可 | — | | | → users.id | onDelete 指定なし（任意参照） |
| 6 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 7 | expires_at | 失効日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 8 | is_active | 有効フラグ | BOOLEAN | NOT NULL | true | | | | |

インデックス：`@@index([blocked_date])`・`@@index([is_active])`。

### 2.8 notifications（通知）

- 論理名：通知（用語集 TERM 対応なし・BD-07 §2.1）｜説明：サイト内通知（F-09）。WebSocket 配信の対象

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 通知ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | user_id | ユーザーID | UUID | NOT NULL | — | | | → users.id | onDelete: Cascade（明示） |
| 3 | appointment_id | 予約ID | UUID | NULL 可 | — | | | → appointments.id | onDelete: Cascade（明示） |
| 4 | type | 通知種別 | enum "NotificationType" | NOT NULL | — | | | | CD-04 |
| 5 | title | タイトル | VARCHAR(200) | NOT NULL | — | | | | |
| 6 | content | 本文 | TEXT | NOT NULL | — | | | | |
| 7 | is_read | 既読フラグ | BOOLEAN | NOT NULL | false | | | | |
| 8 | status | 通知状態 | enum "NotificationStatus" | NOT NULL | PENDING | | | | CD-05 |
| 9 | scheduled_for | 送信予定日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 10 | sent_at | 送信日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 11 | read_at | 既読日時 | TIMESTAMP(3) | NULL 可 | — | | | | |
| 12 | metadata | メタデータ | JSONB | NULL 可 | — | | | | |
| 13 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：`@@index([user_id])`・`@@index([appointment_id])`・`@@index([status])`・`@@index([created_at])`。

### 2.9 activity_logs（アクティビティログ）

- 論理名：アクティビティログ（BD-07 §2.1）｜説明：利用者操作の記録（CF-04）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | ログID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | user_id | ユーザーID | UUID | NULL 可 | — | | | → users.id | onDelete 指定なし（任意参照） |
| 3 | action | 操作内容 | VARCHAR(100) | NOT NULL | — | | | | |
| 4 | resource_type | リソース種別 | VARCHAR(50) | NULL 可 | — | | | | |
| 5 | resource_id | リソースID | UUID | NULL 可 | — | | | | |
| 6 | ip_address | IP アドレス | VARCHAR(45) | NULL 可 | — | | | | |
| 7 | user_agent | ユーザーエージェント | TEXT | NULL 可 | — | | | | |
| 8 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：`@@index([user_id])`・`@@index([created_at])`・`@@index([resource_type, resource_id])`。

### 2.10 system_logs（システムログ）

- 論理名：システムログ（BD-07 §2.1）｜説明：システム動作の記録（CF-04）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | ログID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | level | ログレベル | VARCHAR(20) | NOT NULL | — | | | | |
| 3 | message | メッセージ | TEXT | NOT NULL | — | | | | |
| 4 | context | コンテキスト | JSONB | NULL 可 | — | | | | |
| 5 | user_id | ユーザーID | UUID | NULL 可 | — | | | → users.id | onDelete 指定なし（任意参照） |
| 6 | ip_address | IP アドレス | VARCHAR(45) | NULL 可 | — | | | | |
| 7 | user_agent | ユーザーエージェント | TEXT | NULL 可 | — | | | | |
| 8 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：`@@index([level])`・`@@index([created_at])`・`@@index([user_id])`。

### 2.11 appointment_statistics（予約統計）

- 論理名：予約統計（BD-07 §2.1）｜説明：日次統計（F-10 の統計サマリとは別の集計テーブル）

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 統計ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | stat_date | 統計日 | DATE | NOT NULL | — | | ○ | | @unique |
| 3 | total_appointments | 予約総数 | INTEGER | NOT NULL | 0 | | | | |
| 4 | confirmed_appointments | 確定数 | INTEGER | NOT NULL | 0 | | | | |
| 5 | cancelled_appointments | 取消数 | INTEGER | NOT NULL | 0 | | | | |
| 6 | completed_appointments | 完了数 | INTEGER | NOT NULL | 0 | | | | |
| 7 | new_users | 新規ユーザー数 | INTEGER | NOT NULL | 0 | | | | |
| 8 | returning_users | リピータ数 | INTEGER | NOT NULL | 0 | | | | |
| 9 | peak_hour | ピーク時間帯 | VARCHAR(5) | NULL 可 | — | | | | |
| 10 | no_show_count | 無断キャンセル数 | INTEGER | NOT NULL | 0 | | | | |
| 11 | average_lead_time_hours | 平均リードタイム | DOUBLE PRECISION | NULL 可 | — | | | | Float → double precision |
| 12 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 13 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス：UK（stat_date）＋`@@index([stat_date])`。リレーションなし。

### 2.12 service_categories（サービスカテゴリ）

- 論理名：サービスカテゴリ（TERM-04）｜説明：サービスの分類マスタ

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | カテゴリID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | name | カテゴリ名 | VARCHAR(50) | NOT NULL | — | | ○ | | @unique |
| 3 | description | 説明 | TEXT | NULL 可 | — | | | | @db 注記なし String → text |
| 4 | icon_url | アイコンURL | VARCHAR(255) | NULL 可 | — | | | | |
| 5 | is_active | 稼働フラグ | BOOLEAN | NOT NULL | true | | | | |
| 6 | display_order | 表示順 | INTEGER | NULL 可 | — | | | | |
| 7 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 8 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス：`@@index([is_active])`・`@@index([display_order])`。UK（name）に一意インデックス。子は Service（任意参照・onDelete 指定なし）。

### 2.13 services（サービス）

- 論理名：サービス（TERM-03）｜説明：予約対象の提供メニュー

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | サービスID | UUID | NOT NULL | gen_random_uuid() | ○ | | | |
| 2 | name | サービス名 | VARCHAR(100) | NOT NULL | — | | | | |
| 3 | description | 説明 | TEXT | NULL 可 | — | | | | @db 注記なし String → text |
| 4 | duration_minutes | 所要分数 | INTEGER | NOT NULL | 30 | | | | |
| 5 | price | 価格 | DOUBLE PRECISION | NULL 可 | — | | | | Prisma Float → double precision |
| 6 | image_url | 画像URL | VARCHAR(255) | NOT NULL | — | | | | |
| 7 | category_id | カテゴリID | UUID | NULL 可 | — | | | → service_categories.id | onDelete 指定なし（任意参照） |
| 8 | is_active | 稼働フラグ | BOOLEAN | NOT NULL | true | | | | |
| 9 | display_order | 表示順 | INTEGER | NULL 可 | — | | | | |
| 10 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |
| 11 | updated_at | 更新日時 | TIMESTAMP(3) | NOT NULL | @updatedAt | | | | |

インデックス：`@@index([is_active])`・`@@index([category_id])`・`@@index([display_order])`。子は Appointment（任意参照・onDelete 指定なし）。

### 2.14 FK の削除制約まとめ（明示 Cascade 4 本・実測）

schema.prisma に明示指定のある `onDelete: Cascade` は次表の 4 本のみ（BD-07 §4.1 と同一実測）。

| 親 | 子 | 削除動作 | 出典（schema.prisma） |
|---|---|---|---|
| User | UserSession | 連鎖削除 | `UserSession.user` の onDelete: Cascade |
| Appointment | AppointmentHistory | 連鎖削除 | `AppointmentHistory.appointment` の onDelete: Cascade |
| User | Notification | 連鎖削除 | `Notification.user` の onDelete: Cascade |
| Appointment | Notification | 連鎖削除 | `Notification.appointment` の onDelete: Cascade |

上記以外の FK（Appointment.user／timeSlot／service、AppointmentHistory.user、BlockedTimeSlot.timeSlot／user、ActivityLog.user、SystemLog.user、Service.category）は onDelete 指定なし＝DB 既定挙動。実 DB における削除時の実際の挙動は 2026-09-01 pg_constraint の読取専用照会で実測済みであり、migration SQL（20250921050720_init 11 本・20250930144512_test_migration 2 本）と schema.prisma の両方と一致することを確認した：指定なし → SET NULL 8 本（appointments.user_id・appointments.service_id・appointment_history.changed_by・blocked_time_slots.time_slot_id／blocked_time_slots.blocked_by・activity_logs.user_id・system_logs.user_id・services.category_id＝任意参照 8 本）＋指定なし → RESTRICT 1 本（appointments.time_slot_id＝必須参照）＋明示 Cascade 4 本（上表）。残課題 2 点：① time-slots 削除時の P2003 を 409 業務エラーへ変換（P0-3 改善候補）、② users 削除時の監査リンク切れ（SET NULL）へのガード（P1 検討）。詳細は §5 未決 3 クローズ記録参照。

### 2.15 integration_commands（コマンド冪等結果・🔵 設計値・P0-2 契約・未実装）

- 論理名：コマンド冪等結果｜説明：統合コマンドの初回受理結果（200 のみ）を保存する冪等キーテーブル。**現行 schema.prisma には存在しない第 14 モデル（計画）**。決定経緯：DD-02 §5 未決 1【決定済 2026-09-01】・応答キャッシュ（Redis）案は否決

| No. | カラム物理名 | 論理名 | 型・桁数（PostgreSQL） | NULL 許否 | デフォルト | PK | UK | FK | 制約・備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | id | 冪等記録ID | UUID | NOT NULL | gen_random_uuid() | ○ | | | @default(uuid()) |
| 2 | command_id | コマンドID | VARCHAR | NOT NULL | — | | ○ | | 冪等キー・TERM-12 |
| 3 | command_type | コマンド種別 | VARCHAR(32) | NOT NULL | — | | | | CANCEL_BOOKING のみ・RULE-13 |
| 4 | appointment_id | 予約ID | UUID | NULL 可 | — | | | → appointments.id | onDelete 指定なし（SET NULL 予定・Prisma 既定）・**任意参照：予約削除後も冪等記録を存続させるため**（handoff §3.2 契約動作に整合） |
| 5 | http_status | HTTP状態 | INTEGER | NOT NULL | — | | | | 保存値は 200 のみ |
| 6 | result_code | 結果コード | VARCHAR(32) | NOT NULL | — | | | | CD-12（SUCCESS） |
| 7 | canonical_version | 正本バージョン | INTEGER | NOT NULL | — | | | | 受理時の version・TERM-10 |
| 8 | correlation_id | 相関ID | VARCHAR(64) | NULL 可 | — | | | | TERM-17 |
| 9 | created_at | 作成日時 | TIMESTAMP(3) | NOT NULL | now() | | | | |

インデックス：UK（command_id）＋`@@index([appointment_id])`（任意）。

注記：
- ①保存対象は **200 成功結果のみ**（409 は決定論的に再現・503/timeout は DB 未触・404 の監査は SF 側 Booking_Command__c が担う＝両側職責対称・handoff §一）
- ②書込みは RULE-08 正本更新と**同一トランザクション**（BD-03 §8.6・crash 窗口で冪等性を保証）
- ③cleanup は P0 不要（デモ規模）、P1 で retention ジョブへの接続を検討（DD-03 関連）
- ④型・制約の最終値は migration 時に確定（CHK-01 B-3・正式モデル名は P0-3 確定フロー・IDR-01 登録済み）

## 3. パーティション方針

全テーブルとも**パーティションなし**。対象データ量はデモ規模（RD-07 §3：予約数十件・投影数十件以下・コマンド 0〜数件）であり、パーティションの要件・効果とも存在しない。生産展開時は RD-02 §3 のとおり指標の再設定と再設計を要する。

## 4. Salesforce 側オブジェクト（🔵 設計値・P0-2 契約・未作成）

Salesforce 側の 2 オブジェクトは SF プラットフォームが DDL を管理するため、テーブル定義書としての DDL は存在しない。ここでは BD-07 §3 の計画項目（項目一覧・物理名候補）を設計値として記録する。**全項目とも「設計値（P0-2 契約・未作成）」であり、実オブジェクトは未作成**。型は Salesforce 標準データ型の計画値。

### 4.1 Booking__c（予約投影・TERM-09）

- 状態：🔵 契約凍結済み（2026-09-01）・未作成。External OWD=Private＋Sharing Set（Account 隔離・TERM-32）前提。

| No. | 項目物理名 | 論理名 | 型（計画値） | 備考（設計値） |
|---|---|---|---|---|
| 1 | BookingExternalId__c | 外部ID | テキスト（External ID・一意） | External ID＝**uuid id**（TERM-14・【決定済 2026-09-01】）。両方を同時に External ID にはしない制約は維持 |
| 2 | AppointmentNumber__c | 予約番号 | テキスト | TERM-15 |
| 3 | AppointmentDate__c | 予約日 | 日付 | 予約日（Date・タイムゾーンなし） |
| 4 | TimeSlot__c | 時間枠 | テキスト | HH:mm:ss |
| 5 | ServiceName__c | サービス名 | テキスト | サービス未指定予約では空を許容 |
| 6 | Status__c | 予約状態 | テキスト（**非制限 Picklist**・【決定済 2026-09-01】） | canonical 値＝CD-03 の 4 値を透過（変換なし）。制限しない根拠：計画的な契約変更（値追加）を投影 DML の実行時故障に拡大させないため（CD-07 行参照） |
| 7 | CurrentVersion__c | 現在バージョン | 数値（整数） | TERM-10・バージョンゲート用 |
| 8 | LastEventId__c | イベントID | テキスト | TERM-18・冪等判定用 |
| 9 | SyncStatus__c | 同期状態 | テキスト | TERM-16 |
| 10 | CorrelationId__c | 相関ID | テキスト | TERM-17 |
| 11 | LastError__c | 最終エラー | テキスト | REQ-031 監査 |
| 12 | Account__c | 管理元Account | 参照（lookup・Account） | Sharing Set のキー |
| 13 | Admin_Note__c | 管理者メモ | 長いテキストエリア | SF ローカル・唯一の SF 側編集対象（P1 表示項目・REQ-036） |

制約（設計値・BD-07 §3 境界制約）：canonical 項目の書込入口は投影 REST（BookingProjectionRest）のみ。PII 5 項目（氏名・電話・メール・WeChat・備考）は Booking__c に一切出現しない（RULE-11）。External ID の二択は同時に両方を使わない。

### 4.2 Booking_Command__c（予約キャンセルコマンド・TERM-11）

- 状態：🔵 契約凍結済み（2026-09-01）・未作成。External OWD=Private＋Sharing Set（Account 隔離）前提。

| No. | 項目物理名 | 論理名 | 型（計画値） | 備考（設計値） |
|---|---|---|---|---|
| 1 | CommandId__c | コマンドID | テキスト（External ID・一意） | TERM-12・冪等キー |
| 2 | BookingExternalId__c | 外部ID | テキスト | 取消対象予約の定位（TERM-14） |
| 3 | CommandType__c | コマンド種別 | テキスト | CANCEL_BOOKING のみ（RULE-13） |
| 4 | ExpectedVersion__c | 期待バージョン | 数値（整数） | TERM-10・409 判定入力 |
| 5 | RequestedBySalesforceUserId__c | 要求者（SFユーザーID） | テキスト | 静的マッピング検証用（RULE-12） |
| 6 | RequestedByBookingUserId__c | 要求者（BookingユーザーID） | テキスト | 静的マッピング結果 |
| 7 | Status__c | コマンド状態 | テキスト（**制限 Picklist**・【決定済 2026-09-01】） | QUEUED/RUNNING/SUCCEEDED/CONFLICT/FAILED（TERM-35・CD-08）。SF 内部状態機構のみが書込むため restricted で防呆（zero-cost） |
| 8 | AttemptCount__c | 試行回数 | 数値（整数） | REQ-031 監査 |
| 9 | NextAttemptAt__c | 次回試行日時 | 日時 | REQ-031 監査 |
| 10 | HttpStatus__c | HTTP状態 | 数値（整数） | REQ-031 監査 |
| 11 | ResultCode__c | 結果コード | テキスト | 値域＝**CD-12（7 値封闭集）**・【決定済 2026-09-01・BD-09 §5 未決 4 と同日クローズ】・SUCCESS／CONFLICT／VALIDATION_ERROR／NOT_FOUND／AUTH_ERROR／TRANSIENT_ERROR／SYSTEM_ERROR。粗碼で機械判定（リトライ/状態機構）、詳細情報は LastError__c／ResponseBodyRedacted__c |
| 12 | ResultVersion__c | 結果バージョン | 数値（整数） | TERM-10 |
| 13 | CurrentVersion__c | 現在バージョン | 数値（整数） | 409 応答時の現在値 |
| 14 | CorrelationId__c | 相関ID | テキスト | TERM-17 |
| 15 | LastError__c | 最終エラー | テキスト | REQ-031 監査 |
| 16 | ResponseBodyRedacted__c | 応答ボディ（秘匿） | テキスト | 応答記録（PII 非含有） |

## 5. 未決事項

| No. | 未決事項 | 決定期限 |
|---|---|---|
| 1 | 【決定済 2026-09-01】uuid `id` に決定（TERM-14）。BD-07 §6・BD-09 §5・RD-01 §4・RD-06・BD-01・BD-02・BD-03 の同源項も同日クローズ済み | 決定済み（2026-09-01） |
| 2 | 【決定済 2026-09-01】version＝INTEGER NOT NULL DEFAULT 0・syncStatus＝VARCHAR(16) NOT NULL DEFAULT 'PENDING'（enum 案不採用）。migration 実施は CHK-01 B-1 | 決定済み（2026-09-01） |
| 3 | 【クローズ 2026-09-01・実測確認済】下記 §5.1 クローズ記録参照（BD-07 未決事項 3 と同源・同日クローズ） | 決定済み（2026-09-01） |
| 4 | 【決定済 2026-09-01】CD-07＝非制限 Picklist・CD-08＝制限 Picklist・ResultCode__c 値域＝CD-12（7 値）。BD-08 §4 未決 1・未決 3・BD-09 §5 未決 4・BD-03 §7.9/§8.9 の同源項も同日クローズ | 決定済み（2026-09-01） |

### 5.1 未決事項 3 クローズ記録（2026-09-01 実測）

**3. onDelete 指定なし FK の実 DB 削除挙動の確認 → 【クローズ・2026-09-01 実測確認済】**

確認方法：開発環境 PostgreSQL（本番相当の単一構成）の pg_constraint を読取専用照会（2026-09-01）。全 13 FK の削除挙動を実測し、migration SQL（20250921050720_init 11 本・20250930144512_test_migration 2 本）と schema.prisma の両方と一致することを確認した。

確認結果：
- 明示 onDelete: Cascade 4 本（user_sessions.user_id／appointment_history.appointment_id／notifications.user_id／notifications.appointment_id）
- 指定なし → SET NULL 8 本（Prisma 既定・任意参照）：appointments.user_id・appointments.service_id・appointment_history.changed_by・blocked_time_slots.time_slot_id／blocked_time_slots.blocked_by・activity_logs.user_id・system_logs.user_id・services.category_id
- 指定なし → RESTRICT 1 本（Prisma 既定・必須参照）：appointments.time_slot_id

影響評価：管理 UI には users・time-slots の削除ボタンが存在しない（フロントエンド実測：/users の DELETE 呼出なし・deleteTimeSlot は thunk まで定義済みだが画面から未接続）。よって SET NULL／RESTRICT が発火する経路は API 直叩きのみであり、P0 デモ運用への実害はない。F-08 ハード削除・retention バッチ削除は子テーブル明示 Cascade のため安全。

残課題（別途管理）：① time-slots 削除時の P2003 を 409 業務エラーへ変換（現状 500 吸収・time-slots.service.ts remove）→ P0-3 改善候補。② users 削除時の監査リンク切れ（SET NULL 5 本）へのガード → P1 検討。

結論：本未決事項はクローズ。migration レビューでの再確認は不要とする（P0-2 migration は列追加のみで FK 変更なし。適用後に pg_constraint を 1 回再照会すればなお良し）。
