# 🚀 Claude Auto Project Template

**プロエンジニア品質の完全自動化プロジェクトセットアップ**

一つのコマンドで、Claude AI統合済みの新しいプロジェクトを自動作成します。

## ✨ 特徴

- 🤖 **Claude AI統合**: PRコメントで`@claude`を呼び出すだけで自動コード生成
- 🔄 **完全自動化**: GitHub リポジトリ作成からPR作成まで全自動
- 🛡️ **エンタープライズ品質**: 堅牢なエラーハンドリングとリトライ機能
- 📊 **100%テスト済み**: 包括的テストスイートで品質保証
- 🌸 **curl | bash 安全対応**: プロフェッショナルグレードの安全性

## 🚀 使い方

### 方法1: ワンコマンドセットアップ

```bash
curl -s https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh | bash
```

### 方法2: ローカルコマンド

```bash
# このリポジトリをクローン
git clone https://github.com/simeji03/claude_auto_project_template.git
cd claude_auto_project_template

# newappコマンドを実行
./newapp
```

## 📋 前提条件

- ✅ GitHub CLI (`gh`) がインストール済み
- ✅ GitHub CLI が認証済み (`gh auth login`)
- ✅ 環境変数 `ANTHROPIC_API_KEY` が設定済み
- ✅ Git がインストール済み

## 🔧 セットアップ

1. **GitHub CLI認証**
   ```bash
   gh auth login
   ```

2. **Anthropic API Key設定**
   ```bash
   echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **プロジェクト作成**
   ```bash
   curl -s https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh | bash
   ```

## 🎯 自動実行される処理

1. **前提条件チェック** - 必要なツールとAPIキーの確認
2. **プロジェクト名入力** - 英数字・ハイフン・アンダースコア対応
3. **ローカルプロジェクト作成** - `~/Projects/[project-name]`
4. **GitHub リポジトリ作成** - プライベートリポジトリとして作成
5. **GitHub Secrets設定** - `ANTHROPIC_API_KEY`の自動設定
6. **初期コミット & プッシュ** - README とワークフローファイル
7. **フィーチャーブランチ作成** - `feat/initial-development`
8. **プルリクエスト作成** - 開発準備完了状態
9. **Claude自動起動** - `@claude scaffold a simple auto-reply app`

## 🤖 Claude使用方法

プロジェクト作成後、PRコメントで以下のように呼び出します：

```
@claude scaffold a simple auto-reply application with the following features:

## Requirements
- Simple and clean architecture
- Auto-reply functionality
- Modern UI/UX
- Proper error handling
- Documentation
- Tests

Please create a complete, production-ready application. Thanks!
```

## 🧪 テスト

包括的テストスイートが含まれています：

```bash
./test_auto_setup.sh
```

**テスト項目:**
- ✅ スクリプト存在確認
- ✅ 必要コマンド確認
- ✅ GitHub CLI認証確認
- ✅ API Key確認
- ✅ プロジェクト名検証
- ✅ curl | bash 検出
- ✅ ログ機能
- ✅ リトライメカニズム
- ✅ GitHub操作（ドライラン）
- ✅ セキュリティチェック

## 🏗️ プロジェクト構造

```
your-project/
├── README.md                    # プロジェクト説明
├── .github/
│   └── workflows/
│       └── claude.yml          # Claude Code Action設定
└── [あなたのコード]             # Claudeが生成するファイル群
```

## 🔒 セキュリティ

- 🛡️ 入力値検証（プロジェクト名、APIキー）
- 🔐 GitHub Secrets自動設定
- 🚫 ハードコードされた認証情報なし
- ✅ プロフェッショナルグレードのエラーハンドリング

## 📊 品質保証

- **テスト通過率**: 100%
- **エラーハンドリング**: 包括的
- **リトライ機能**: 堅牢
- **ログ機能**: 詳細
- **コード品質**: エンタープライズレベル

## 🚨 トラブルシューティング

### GitHub CLI認証エラー
```bash
gh auth login --scopes repo,workflow
```

### API Key未設定エラー
```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc
source ~/.zshrc
```

### プロジェクト名エラー
- 英数字・ハイフン・アンダースコアのみ使用
- 3-39文字の長さ
- ハイフン・アンダースコアで始まったり終わったりしない

## 🎉 成功例

```bash
$ curl -s https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh | bash
🚀 Starting Claude Auto Project Setup v2.0.0
新しいプロジェクト名を入力してください: my-awesome-app
✅ SUCCESS: All prerequisites verified
✅ SUCCESS: No conflicts found for project: my-awesome-app
✅ SUCCESS: Local project setup completed
✅ SUCCESS: GitHub repository created: username/my-awesome-app
✅ SUCCESS: GitHub secrets configured
✅ SUCCESS: Code pushed to main branch
✅ SUCCESS: Pull request created: https://github.com/username/my-awesome-app/pull/1
✅ SUCCESS: Claude triggered successfully!
🎉 SUCCESS: my-awesome-app is ready!

📍 Project Location: /Users/username/Projects/my-awesome-app
🔗 GitHub Repository: https://github.com/username/my-awesome-app
📋 Pull Request: https://github.com/username/my-awesome-app/pulls

🤖 Claude is now generating your application!
   Check the PR comments for progress updates.
```

## 📝 ライセンス

MIT License

---

**Made with ❤️ by Professional Engineers**