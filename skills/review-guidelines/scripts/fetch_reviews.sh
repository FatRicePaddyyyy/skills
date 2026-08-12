#!/usr/bin/env bash
# 1バッチ分のPRレビューコメントをGitHub APIから取得する。
#
# Usage:
#   fetch_reviews.sh <start> <end> <output_path> [owner/repo]
set -euo pipefail

if (( $# < 3 )); then
  echo "Usage: fetch_reviews.sh <start> <end> <output_path> [owner/repo]" >&2
  exit 1
fi

start=$1
end=$2
output=$3
REPO=${4:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
MIN_COMMENT_LENGTH=15

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
idx=0

while IFS= read -r pr; do
  num=$(jq -r '.number' <<<"$pr")
  title=$(jq -r '.title' <<<"$pr")

  inline=$(gh api "repos/${REPO}/pulls/${num}/comments" --paginate 2>/dev/null || echo '[]')
  reviews=$(gh api "repos/${REPO}/pulls/${num}/reviews" 2>/dev/null || echo '[]')
  # paginate が複数ページを連結すると壊れる場合があるため配列化を試みる
  inline=$(jq -c 'if type == "array" then . else [] end' <<<"$inline" 2>/dev/null || echo '[]')
  reviews=$(jq -c 'if type == "array" then . else [] end' <<<"$reviews" 2>/dev/null || echo '[]')

  comments=$(jq -n \
    --argjson inline "$inline" \
    --argjson reviews "$reviews" \
    --argjson min "$MIN_COMMENT_LENGTH" '
    def ok:
      ((.user.login // "") | tostring | contains("[bot]") | not)
      and (((.body // "") | gsub("^\\s+|\\s+$";"")) | length) >= $min;
    ($inline | map(select(ok) | {
      author: .user.login,
      body: (.body | gsub("^\\s+|\\s+$";"")),
      path: (.path // ""),
      type: "inline"
    }))
    +
    ($reviews | map(select(ok) | {
      author: .user.login,
      body: (.body | gsub("^\\s+|\\s+$";"")),
      path: "",
      type: "review_body",
      state: (.state // "")
    }))
  ')

  if [[ $(jq 'length' <<<"$comments") -gt 0 ]]; then
    jq -n \
      --argjson num "$num" \
      --arg title "$title" \
      --argjson comments "$comments" \
      '{pr_number: $num, pr_title: $title, comments: $comments}' \
      > "${tmpdir}/${idx}.json"
    idx=$((idx + 1))
  fi
done < <(jq -c ".[${start}:${end}][]" /tmp/target_prs.json)

if (( idx > 0 )); then
  jq -s '.' "$tmpdir"/*.json > "$output"
else
  echo '[]' > "$output"
fi

echo "[${start}-${end}] Saved ${idx} PRs with comments → ${output} (repo=${REPO})"
