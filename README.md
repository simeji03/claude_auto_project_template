# Claude Auto Project Template

## 使い方

1. このリポジトリを clone
2. ターミナルで以下を実行

```bash
bash scripts/init.sh <新しいプロジェクト名>
```

3. GitHubでPRを作成
4. PRコメントに @claude create a simple app と入力
5. Claudeが自動でコード生成！

---

## ✅ 2️⃣ GitHubにリポジトリを作ろう

1️⃣ GitHubにログイン
2️⃣ 「New repository」をクリック
3️⃣ 名前：`claude_auto_project_template`
4️⃣ **Initialize this repository with a README** はチェックしない！
5️⃣ 「Create repository」をクリック
6️⃣ 作ったフォルダをGitHubに紐づけ👇

```bash
git init
git remote add origin https://github.com/＜あなたのGitHubユーザー名＞/claude_auto_project_template.git
git add .
git commit -m "initial commit"
git push -u origin main
```