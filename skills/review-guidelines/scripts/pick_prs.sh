#!/usr/bin/env bash
# 前回の実行記録を参照し、未処理の新規PRのみを /tmp/target_prs.json に書き出す。
#
# Input:
#   /tmp/merged_prs.json
#   docs/review-guidelines/*/pr_ids.json
# Output:
#   /tmp/target_prs.json
# Exit 2: 新規PRゼロ
set -euo pipefail

DOCS_DIR="docs/review-guidelines"
SEEN_FILE=$(mktemp)
trap 'rm -f "$SEEN_FILE"' EXIT
echo '[]' > "$SEEN_FILE"

shopt -s nullglob
run_records=("$DOCS_DIR"/*/pr_ids.json)
run_count=${#run_records[@]}

if (( run_count > 0 )); then
  for path in "${run_records[@]}"; do
    jq -s 'add | unique' "$SEEN_FILE" "$path" > "${SEEN_FILE}.next"
    mv "${SEEN_FILE}.next" "$SEEN_FILE"
  done
  latest="${run_records[$((run_count - 1))]}"
  seen_count=$(jq 'length' "$SEEN_FILE")
  echo "前回までの実行数: ${run_count} 回"
  echo "最新実行記録:     ${latest}"
  echo "処理済みPR総数:   ${seen_count} 件"
else
  echo "前回の実行記録なし → 全マージ済みPRを処理します"
fi

jq --slurpfile seen "$SEEN_FILE" '
  ($seen[0] // []) as $ids
  | map(select(.number as $n | ($ids | index($n) | not)))
' /tmp/merged_prs.json > /tmp/target_prs.json

all_count=$(jq 'length' /tmp/merged_prs.json)
target_count=$(jq 'length' /tmp/target_prs.json)
echo "全マージ済みPR: ${all_count} 件"
echo "今回処理対象:   ${target_count} 件（新規）"

if (( target_count == 0 )); then
  echo "新しいPRはありません。スキップします。"
  exit 2
fi
