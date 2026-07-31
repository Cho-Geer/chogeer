# Salesforce プラットフォーム & インテグレーション ショーケース

このリポジトリは、`Senior Salesforce Platform / Integration Engineer` 職位を想定して厳選した Salesforce DX のポートフォリオプロジェクトです。

プラットフォーム、インテグレーション、UI、そして Experience Cloud スタイルの認証フローについて、代表的な実装を少数だけ厳選して提示することを目的としています。レビュー担当者が実験成果物の巨大なアーカイブを掘り起こすことなく、技術的なシグナルを迅速に理解できるように設計されています。

このリポジトリは、あらゆる実験的・学習的な成果物を見せるのではなく、代表的な Salesforce プラットフォームとインテグレーションのパターンを示すものとして、意図的に厳選されています。

## このリポジトリで示していること

- Apex、Visualforce、Aura を用いた Experience Cloud スタイルの認証フロー
- `@RestResource`、`with sharing`、`Security.stripInaccessible` による安全な Apex REST 設計
- HTTP Callout と Named Credential ベースのエンドポイント設計による外部連携
- Platform Event 駆動の処理と Apex トリガのテスト
- Apex コントローラーをバックエンドとする Lightning Web Components による一覧・作成フロー
- 主なショーケース実装をカバーする Apex ユニットテスト

## カバーしている Salesforce のスキル

- Apex コントローラーとサービスクラス
- Apex ユニットテスト
- Visualforce
- Aura Components
- Lightning Web Components
- Experience Cloud スタイルの認証およびセルフ登録フロー
- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- HTTP Callout
- Named Credential ベースのインテグレーション設定
- Platform Events
- トリガベースのイベント処理
- レビュアーフレンドリーなリポジトリのキュレーションとアーキテクチャ説明

## 代表的な実装

### 1. Experience Cloud / 認証フロー

代表的な Apex ファイル:

- `force-app/main/default/classes/CommunitiesLoginController.cls`
- `force-app/main/default/classes/CommunitiesSelfRegController.cls`
- `force-app/main/default/classes/ForgotPasswordController.cls`
- `force-app/main/default/classes/ChangePasswordController.cls`
- `force-app/main/default/classes/MyProfilePageController.cls`
- `force-app/main/default/classes/LightningLoginFormController.cls`
- `force-app/main/default/classes/LightningSelfRegisterController.cls`
- `force-app/main/default/classes/LightningForgotPasswordController.cls`
- `force-app/main/default/classes/SiteLoginController.cls`
- `force-app/main/default/classes/SiteRegisterController.cls`

代表的なテストファイル:

- `force-app/main/default/classes/CommunitiesLoginControllerTest.cls`
- `force-app/main/default/classes/CommunitiesSelfRegControllerTest.cls`
- `force-app/main/default/classes/ForgotPasswordControllerTest.cls`
- `force-app/main/default/classes/ChangePasswordControllerTest.cls`
- `force-app/main/default/classes/MyProfilePageControllerTest.cls`
- `force-app/main/default/classes/LightningLoginFormControllerTest.cls`
- `force-app/main/default/classes/LightningSelfRegisterControllerTest.cls`
- `force-app/main/default/classes/LightningForgotPasswordControllerTest.cls`
- `force-app/main/default/classes/SiteLoginControllerTest.cls`
- `force-app/main/default/classes/SiteRegisterControllerTest.cls`

代表的な Visualforce ページ:

- `force-app/main/default/pages/CommunitiesLogin.page`
- `force-app/main/default/pages/CommunitiesSelfReg.page`
- `force-app/main/default/pages/ForgotPassword.page`
- `force-app/main/default/pages/ChangePassword.page`
- `force-app/main/default/pages/MyProfilePage.page`
- `force-app/main/default/pages/SiteLogin.page`
- `force-app/main/default/pages/SiteRegister.page`

代表的な Aura ファイル:

- `force-app/main/default/aura/loginForm/loginForm.cmp`
- `force-app/main/default/aura/selfRegister/selfRegister.cmp`
- `force-app/main/default/aura/forgotPassword/forgotPassword.cmp`

これらの例は次のことを示しています:

- ログインおよびセルフ登録フローのハンドリング
- パスワードリセットとプロフィール管理フロー
- Visualforce、Aura、Apex をまたぐ UI とコントローラーの連携
- 面接で説明しやすい Experience Cloud 志向のエントリーポイント

### 2. 安全な REST エンドポイント

代表的なファイル:

- `force-app/main/default/classes/ShowcaseContactRestResource.cls`
- `force-app/main/default/classes/ShowcaseContactRestResourceTest.cls`

この例は次のことを示しています:

- `@RestResource`
- `with sharing`
- `Security.stripInaccessible`
- リクエストバリデーションとレスポンス整形
- レビュアーフレンドリーな安全なデータ公開パターン

### 3. 外部連携 / HTTP Callout

代表的なファイル:

- `force-app/main/default/classes/ShowcaseContactSyncService.cls`
- `force-app/main/default/classes/ShowcaseContactSyncServiceTest.cls`

この例は次のことを示しています:

- 外部への HTTP Callout
- Named Credential ベースのエンドポイント設定
- 型付けされたリクエスト/レスポンスのラッパー
- モックベースの Callout テスト
- インテグレーション志向の Apex サービス設計

### 4. Platform Event とトリガベースの処理

代表的なファイル:

- `force-app/main/default/triggers/OrderEventTrigger.trigger`
- `force-app/main/default/classes/OrderEventTriggerTest.cls`
- `force-app/main/default/objects/Order_Event__e/Order_Event__e.object-meta.xml`

この例は次のことを示しています:

- Platform Event の定義
- トリガベースのイベント処理
- イベント駆動の後続自動化
- `EventBus.publish` によるテスト

### 5. LWC + Apex の連携

代表的なファイル:

- `force-app/main/default/classes/ShowcaseContactController.cls`
- `force-app/main/default/classes/ShowcaseContactControllerTest.cls`
- `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`
- `force-app/main/default/lwc/showcaseContactCreate/showcaseContactCreate.js`

この例は次のことを示しています:

- Apex をバックエンドとする連絡先の一覧取得
- Apex をバックエンドとする連絡先の作成
- LWC と Apex のクライアント/サーバー連携
- ポートフォリオレビューや面接で簡単に説明できるシンプルな UI パターン

### 6. 補助資料として残している追加のプラットフォームサンプル

代表的なファイル:

- `force-app/main/default/classes/ApexSecurityRest.cls`
- `force-app/main/default/classes/ApexSecurityRestTest.cls`
- `force-app/main/default/classes/Account_batchable.cls`
- `force-app/main/default/classes/Test_account_batchable.cls`
- `force-app/main/default/flows/New_Contact.flow-meta.xml`
- `force-app/main/default/flows/Cloud_new_process.flow-meta.xml`

これらのファイルは補助資料として有用ですが、本リポジトリの主なレビューパスではありません。

## リポジトリ構成

主たるレビュー対象:

- `force-app/main/default/classes/`
- `force-app/main/default/pages/`
- `force-app/main/default/aura/`
- `force-app/main/default/lwc/`
- `force-app/main/default/triggers/`
- `force-app/main/default/objects/`

補助的なプロジェクトファイル:

- `sfdx-project.json`
- `package.json`
- `jest.config.js`
- `playwright.config.js`

## アーキテクチャノート

このリポジトリは、シンプルなポートフォリオ原則に従っています:

- レビュー対象を小さく保つ
- リポジトリのテーマを明確にする
- プラットフォームとインテグレーションの代表的なパターンを示す
- 既存の Experience Cloud の最良の例を保持する
- 過去のあらゆるサンプルを寄せ集めた"捨て場"にしない

実際のところ、本リポジトリの中核となるストーリーは次のとおりです:

1. `chogeer` 内にすでに存在する Experience Cloud / 認証フロー
2. 幅を広げるために厳選して追加された、プラットフォームとインテグレーションの一連のサンプル
3. 採用チームがシグナルを迅速に理解できるように設計された、意図的なレビュー順

## このリポジトリのレビュー方法

推奨されるレビュー順:

1. `force-app/main/default/classes/CommunitiesLoginController.cls`
2. `force-app/main/default/classes/CommunitiesSelfRegController.cls`
3. `force-app/main/default/classes/MyProfilePageController.cls`
4. `force-app/main/default/pages/CommunitiesLogin.page`
5. `force-app/main/default/aura/loginForm/loginForm.cmp`
6. `force-app/main/default/classes/ShowcaseContactRestResource.cls`
7. `force-app/main/default/classes/ShowcaseContactSyncService.cls`
8. `force-app/main/default/triggers/OrderEventTrigger.trigger`
9. `force-app/main/default/classes/ShowcaseContactController.cls`
10. `force-app/main/default/lwc/showcaseContactList/showcaseContactList.js`

## ローカル開発

依存パッケージをインストールします:

```bash
npm install
```

Salesforce Org への認証:

```bash
sf org login web --alias <your-org-alias>
```

ソースのデプロイ:

```bash
sf project deploy start --target-org <your-org-alias>
```

Apex テストの実行:

```bash
sf apex run test --target-org <your-org-alias> --test-level RunLocalTests
```

LWC ユニットテストの実行:

```bash
npm run test:unit
```

Playwright E2E テストの実行:

```bash
npm run test:e2e
```

Named Credential に関する注意:

- 外部 Callout の例では、`CustomerProfileService` という Named Credential が必要です。

## 注記

- このリポジトリは、すべての Salesforce 実験を網羅したアーカイブではなく、厳選されたショーケースとして位置付けられています。
- レガシーや練習目的の追加ファイルも一部リポジトリ内に残っていますが、上記のセクションが意図されたレビューパスを定義します。
- Salesforce 以外の、より広範なフルスタックの証跡としては、別の予約システムのリポジトリ群がより有力な参照ポイントです。

## 作者

Zixi Tao

## 想定役割

Senior Salesforce Platform / Integration Engineer

---

## 🇬🇧 English | 🇨🇳 中文

- [English version](./README.en.md)
- [中文版本](./README.zh.md)
