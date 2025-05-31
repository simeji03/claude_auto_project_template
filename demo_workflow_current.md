# 🎯 現在の修正指示ワークフロー（デモ）

## 📱 現在実装済みの修正指示方法

### Method 1: GitHub PR経由（メイン）

#### Step 1: プロジェクト作成 → Cursor自動起動
```bash
$ ./auto_setup.sh
# プロジェクト名: demo-app
# 選択: 1 (リアルタイム監視)
# → Cursorが自動起動
# → GitHub PR作成: https://github.com/username/demo-app/pull/1
```

#### Step 2: 初回Claude指示
GitHub PR画面で以下をコメント：
```
@claude この React アプリに以下の機能を追加してください：

- ユーザー登録フォーム
- ログイン機能
- ダッシュボード画面
- レスポンシブデザイン

Tailwind CSSとTypeScriptを使用してください。
```

#### Step 3: Claude作業開始 → 自動同期
```
[監視中] 🔄 チェック中 ... [5/60]
[監視中] ✨ 新しい変更を検出しました！
[監視中] 📥 変更をローカルに同期中...
[監視中] 📦 依存関係を自動インストール中...
[監視中] 🎯 Cursorでプロジェクトを開いています...
[監視中] 🎉 同期完了！
```

#### Step 4: Cursor上でコード確認 → 追加修正指示
- Cursorでコード内容確認
- GitHub PR画面に戻る
- 追加の修正指示をコメント：

```
@claude 追加で以下を修正してください：

- ログインフォームのバリデーションを強化
- エラーメッセージを日本語化
- ローディング状態の表示を追加

src/components/LoginForm.tsx のこの部分を重点的にお願いします。
```

### Method 2: Cursor内でファイル編集 → PR反映

#### Option A: コメントで指示
```typescript
// TODO: @claude この関数のパフォーマンスを改善してください
// 現在のO(n²)をO(n log n)にしたいです
function sortUsers(users: User[]): User[] {
  // 現在の実装...
}
```

#### Option B: 直接編集してコミット
1. Cursorでファイル編集
2. Git commit & push
3. PRが自動更新
4. Claudeが変更を認識して対応

## 🔍 現在の制限事項

### できること ✅
- GitHub PR経由での詳細指示
- Cursorでのコード確認・手動編集
- リアルタイム同期・自動依存関係インストール
- 通知受信

### できないこと（改善余地）❌
- **Cursor内から直接Claudeに指示**
- Cursor内でのClaude会話UI
- ファイル内コメントの自動Claude認識
- Cursor拡張機能との統合

## 💡 理想的なワークフロー（未実装）

```
Cursor内で Cmd+K → "Claude: この関数を最適化して"
↓
直接Claudeが応答・修正
↓
リアルタイムでファイル更新
```

## 📊 現在の実用性評価

| 機能 | 実装状況 | 使いやすさ |
|------|----------|------------|
| GitHub PR指示 | ✅ 完全実装 | ⭐⭐⭐⭐ |
| 自動同期 | ✅ 完全実装 | ⭐⭐⭐⭐⭐ |
| Cursor自動起動 | ✅ 完全実装 | ⭐⭐⭐⭐⭐ |
| Cursor内直接指示 | ❌ 未実装 | - |

## 🎯 結論

**現在の方法でも十分実用的**だが、Cursor内直接指示があればより理想的。