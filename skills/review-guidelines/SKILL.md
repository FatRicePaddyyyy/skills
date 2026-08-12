---
name: review-guidelines
description: >-
  対象リポジトリの全PRレビューコメントを収集・分析し、docs/review-guidelines/ に
  ガイドラインを生成・保存する。2回目以降は新規PRのみ差分処理する。
  Use when generating review guidelines from PR comments, mining past reviews,
  or building a repo-specific review checklist.
---

対象リポジトリの全マージ済みPRのレビューコメントを収集し、ガイドラインを生成します。
**2回目以降は前回処理済みのPRをスキップし、新規PRのみ処理します。**

補助スクリプトはすべてこのスキル直下の `scripts/` にあります（bash + `jq` + `gh`。Python 不要）。
実行前に `SKILL_ROOT`（この `SKILL.md` があるディレクトリ）を特定してください。

## Step 0: タイムスタンプとリポジトリを決定

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "実行タイムスタンプ: $TIMESTAMP"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
REPO_URL=$(gh repo view --json url -q .url)
REPO_NAME=$(gh repo view --json name -q .name)
echo "対象リポジトリ: $REPO ($REPO_URL)"
```

以降のステップでは `$TIMESTAMP` / `$REPO` / `$REPO_URL` / `$REPO_NAME` を使い続けてください。

## Step 1: 全マージ済みPRのリストを取得

```bash
gh pr list --state all --limit 1000 --json number,title,state \
  | jq '[.[] | select(.state == "MERGED")]' > /tmp/merged_prs.json
echo "Merged PRs: $(jq 'length' /tmp/merged_prs.json)"
```

## Step 2: 前回処理済みPRを除外し、今回の処理対象を決定

`scripts/pick_prs.sh` が `docs/review-guidelines/*/pr_ids.json` を参照し、
未処理のPRだけを `/tmp/target_prs.json` に書き出します。

```bash
bash "$SKILL_ROOT/scripts/pick_prs.sh"
```

**終了コード 2 の場合は新規PRがゼロ**です。その場合はここで終了してください。

## Step 3: 対象PRのレビューコメントを並列バッチ取得

`target_prs.json` の件数に応じてバッチ数を決めます（65件ずつ、最大10並列）。
`fetch_reviews.sh` には検出済みの `$REPO` を渡します。

```bash
TOTAL=$(jq 'length' /tmp/target_prs.json)
echo "処理対象PR数: $TOTAL"

i=0
while [ $i -lt $TOTAL ]; do
    end=$((i + 65))
    bash "$SKILL_ROOT/scripts/fetch_reviews.sh" $i $end /tmp/reviews_${i}_${end}.json "$REPO" &
    i=$end
done
wait
echo "全バッチ完了"
```

## Step 4: バッチ結果を結合・チャンク分割

`scripts/split_chunks.sh` で結合し、PR数に応じた数のチャンクへ分割します。
チャンク数は `/tmp/num_chunks.txt` に書き出されます。

```bash
bash "$SKILL_ROOT/scripts/split_chunks.sh"

NUM_CHUNKS=$(cat /tmp/num_chunks.txt)
echo "分析チャンク数: $NUM_CHUNKS"
```

## Step 5: 各チャンクをパターン分析

`/tmp/review_chunk_0.json` 〜 `/tmp/review_chunk_$(($NUM_CHUNKS - 1)).json` を読み込み、
以下のカテゴリでパターンを抽出してください。チャンクは並列に処理してよいです。

リポジトリの主言語・ドメインに合わせてカテゴリ名は調整して構いません
（例: TypeScript プロジェクトなら「コーディング規約」の中で TS 固有の指摘をまとめる）。

**抽出カテゴリ（初期セット）:**
- アーキテクチャ設計
- コーディング規約
- エラーハンドリング
- データベース・トランザクション
- API設計
- セキュリティ
- テスト
- ログ・可観測性
- コード品質・保守性

コメントに該当が無いカテゴリは省略して構いません。上記に収まらないドメイン固有の指摘は、
新しいカテゴリを追加してまとめてください。

**各パターンの形式:**
- **タイトル:** 短い名前（日本語）
- **ルール:** 何をすべきか・すべきでないかの明確な記述（日本語）
- **理由:** そのルールが重要な理由（日本語）
- **良い例 / 悪い例:** 実際のコードスニペット（あれば）。言語はリポジトリに合わせる
- **参考PRとコメント:** `[PR #NNN: タイトル](URL) — @author: "コメント抜粋"`

チャンク間で重複するパターンは統合し、参照PRを全て残してください。

分析結果を以下のスキーマで `/tmp/guidelines_by_category.json` に保存してください:

```json
[
  {
    "category_name": "アーキテクチャ設計",
    "guidelines": [
      {
        "title": "ガイドライン名",
        "rule": "ルール文（日本語）",
        "rationale": "理由（日本語）",
        "do_example": "良い例（省略可）",
        "dont_example": "悪い例（省略可）",
        "example_language": "ts",
        "references": [
          {
            "pr_number": 123,
            "pr_title": "PRタイトル",
            "comment_excerpt": "コメント抜粋",
            "author": "username"
          }
        ]
      }
    ]
  }
]
```

`example_language` はコードフェンス用の言語タグ（`ts` / `py` / `go` / `rb` など）。
例が無い場合は省略して構いません。

## Step 6: ガイドラインMDを生成

`scripts/render_md.sh` にタイムスタンプを渡して `/tmp/guidelines_$TIMESTAMP.md` に出力します。
リポジトリ表示名とURLは環境変数で渡します。

```bash
REPO_URL="$REPO_URL" REPO_NAME="$REPO_NAME" bash "$SKILL_ROOT/scripts/render_md.sh" $TIMESTAMP
```

## Step 7: 実行記録を保存

`scripts/save_out.sh` が以下の2ファイルを `docs/review-guidelines/$TIMESTAMP/` に保存します：

- `review-guidelines.md` — 今回生成したガイドライン
- `pr_ids.json` — 今回処理したPRのIDリスト（次回実行時のスキップ判定に使用）

```bash
bash "$SKILL_ROOT/scripts/save_out.sh" $TIMESTAMP
```

保存後、`docs/review-guidelines/$TIMESTAMP/` の内容を確認してください。

## 注意事項

- 依存: `bash` / `jq` / `gh`（Python は不要）
- ボット（dependabot 等）のコメントはスキップ。ただし Copilot の技術的な指摘は含める
- 15文字未満の短いコメントはスキップ
- 各ガイドラインに必ず1件以上のPR参照を含める
- ガイドライン本文は日本語で統一（コメント原文が英語でも可）
- 特定企業・特定プロダクト前提のルールを勝手に追加しない。根拠は収集したレビューコメントのみ
- `docs/review-guidelines/` ディレクトリの構造:
  ```
  docs/review-guidelines/
  ├── 20260611_153042/
  │   ├── review-guidelines.md   # 生成されたガイドライン
  │   └── pr_ids.json            # 処理済みPR IDリスト
  ├── 20260701_090000/
  │   ├── review-guidelines.md
  │   └── pr_ids.json
  └── ...
  ```
