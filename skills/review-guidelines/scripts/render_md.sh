#!/usr/bin/env bash
# /tmp/guidelines_by_category.json からガイドライン MD を生成する。
#
# Usage:
#   REPO_URL=... REPO_NAME=... render_md.sh [timestamp]
#
# Output: /tmp/guidelines_<timestamp>.md または /tmp/guidelines.md
set -euo pipefail

INPUT_PATH="/tmp/guidelines_by_category.json"
timestamp=${1:-}
if [[ -n "$timestamp" ]]; then
  OUTPUT_PATH="/tmp/guidelines_${timestamp}.md"
else
  OUTPUT_PATH="/tmp/guidelines.md"
fi

if [[ -z "${REPO_URL:-}" || -z "${REPO_NAME:-}" ]]; then
  meta=$(gh repo view --json url,name)
  REPO_URL=${REPO_URL:-$(jq -r '.url' <<<"$meta" | sed 's:/*$::')}
  REPO_NAME=${REPO_NAME:-$(jq -r '.name' <<<"$meta")}
fi

jq -r --arg repo_name "$REPO_NAME" --arg repo_url "$REPO_URL" '
def fence(lang; code):
  ["```" + (lang // ""), code, "```"];

def excerpt:
  (. // "") | gsub("\n"; " ") | .[0:200];

def guideline_lines($repo_url):
  . as $g
  | ["### \($g.title)", ""]
  + (if ($g.rule // "") != "" then ["**ルール:** \($g.rule)", ""] else [] end)
  + (if ($g.rationale // "") != "" then ["**理由:** \($g.rationale)", ""] else [] end)
  + (if ($g.dont_example // "") != "" then
      ["**悪い例:**"] + fence($g.example_language; $g.dont_example) + [""]
    else [] end)
  + (if ($g.do_example // "") != "" then
      ["**良い例:**"] + fence($g.example_language; $g.do_example) + [""]
    else [] end)
  + (if (($g.references // []) | length) > 0 then
      ["**参考PRとコメント:**"]
      + [
          .references[]
          | "- [PR #\(.pr_number): \(.pr_title)](\($repo_url)/pull/\(.pr_number)) — @\(.author): \"\(.comment_excerpt | excerpt)\""
        ]
      + [""]
    else [] end)
  + ["---", ""];

def category_lines($i; $repo_url):
  . as $cat
  | ["## \($i). \($cat.category_name)", ""]
  + ([ $cat.guidelines[] | guideline_lines($repo_url) ] | add);

[
  "# PRレビューガイドライン",
  "",
  "## このドキュメントについて",
  "",
  "このドキュメントは、\($repo_name) リポジトリの全マージ済み PR のレビューコメントを分析し、",
  "実際にレビューで指摘・議論された内容をガイドラインとして体系化したものです。",
  "各ガイドラインには根拠となった実際のPRとコメントへの参照を記載しています。",
  "",
  "## 活用方法",
  "",
  "- **PR作成時:** チェックリストとして活用し、よくある指摘を事前に自己レビューする",
  "- **コードレビュー時:** レビューコメントの根拠として参照する",
  "- **オンボーディング:** このリポジトリ固有のコーディング規約・設計方針を把握する",
  "",
  "## 目次",
  ""
]
+ [ range(0; length) as $i | "\($i+1). \(.[$i].category_name) (\(.[$i].guidelines | length)件)" ]
+ [""]
+ ([ range(0; length) as $i | (.[$i] | category_lines($i+1; $repo_url)) ] | add // [])
+ [
  "## まとめ",
  "",
  "以上のガイドラインは、実際のPRレビューコメントから帰納的に導出したものです。",
  "新たなパターンが確認された場合は、このドキュメントを更新してください。",
  ""
]
| join("\n")
' "$INPUT_PATH" > "$OUTPUT_PATH"

chars=$(wc -c < "$OUTPUT_PATH" | tr -d ' ')
lines=$(wc -l < "$OUTPUT_PATH" | tr -d ' ')
echo "Written: ${OUTPUT_PATH} (${chars} chars, ${lines} lines)"
echo "Repo: ${REPO_NAME} (${REPO_URL})"
