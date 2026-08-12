# PRレビューガイドライン

## このドキュメントについて

このドキュメントは、example-api リポジトリの全マージ済み PR（120件）のレビューコメント（480件）を分析し、
実際にレビューで指摘・議論された内容をガイドラインとして体系化したものです。
各ガイドラインには根拠となった実際のPRとコメントへの参照を記載しています。

最終更新: 2026-06-11（PR #3〜#180 のレビューコメントを分析）

## 活用方法

- **PR作成時:** チェックリストとして活用し、よくある指摘を事前に自己レビューする
- **コードレビュー時:** レビューコメントの根拠として参照する
- **オンボーディング:** このリポジトリ固有のコーディング規約・設計方針を把握する

## 目次

1. エラーハンドリング (1件)
2. API設計 (1件)
3. テスト (1件)
...

## 1. エラーハンドリング

### ドメインエラーとインフラエラーを混同しない

**ルール:** バリデーション失敗や「見つからない」などのドメインエラーは、DB接続断・タイムアウトなどのインフラエラーと別の型／コードで返す。呼び出し側がリトライ可否を判断できるようにする。

**理由:** 同じ `Error` にまとめると、一時障害と仕様上の失敗を区別できず、リトライやユーザー向けメッセージが誤る。

**悪い例:**
```ts
async function getUser(id: string): Promise<User> {
  const row = await db.query("SELECT * FROM users WHERE id = $1", [id]);
  if (!row) throw new Error("failed"); // NG: 原因が分からない
  return row;
}
```

**良い例:**
```ts
async function getUser(id: string): Promise<User> {
  const row = await db.query("SELECT * FROM users WHERE id = $1", [id]);
  if (!row) throw new NotFoundError(`user ${id}`);
  return row;
}
```

**参考PRとコメント:**
- [PR #104: ユーザー取得 API のエラー整理](https://github.com/example-org/example-api/pull/104) — @carol: "NotFound と DB 障害を同じ Error にしないでください。呼び出し側でリトライ判断できません。"

---

## 2. API設計

### 破壊的変更はバージョンか互換レイヤで吸収する

**ルール:** 既存クライアントが依存するレスポンスフィールドの削除・型変更は、メジャーバージョンアップか互換フィールドの並行提供なしにマージしない。

**理由:** サイレントな破壊的変更は本番クライアントを壊し、ロールバックコストが高い。

**参考PRとコメント:**
- [PR #91: 注文レスポンスから legacyStatus を削除](https://github.com/example-org/example-api/pull/91) — @dave: "legacyStatus を消すなら v2 にするか、少なくとも1リリースは両方返してください。"

---

## 3. テスト

### 時刻依存のロジックは時計を注入する

**ルール:** `Date.now()` やシステム時刻に直接依存するビジネスロジックは、テスト可能な時計（`Clock` / `now` 関数）を引数または依存として受け取る。

**理由:** 実時刻に依存するとフレークしやすく、境界条件（月末・タイムゾーン）を再現できない。

**悪い例:**
```ts
function isExpired(expiresAt: Date): boolean {
  return expiresAt.getTime() < Date.now(); // NG: テストで固定できない
}
```

**良い例:**
```ts
function isExpired(expiresAt: Date, now: () => number = Date.now): boolean {
  return expiresAt.getTime() < now();
}
```

**参考PRとコメント:**
- [PR #115: セッション期限チェックの追加](https://github.com/example-org/example-api/pull/115) — @erin: "Date.now 直書きはやめて、now を渡せるようにしてください。期限境界のテストが書けません。"

---
