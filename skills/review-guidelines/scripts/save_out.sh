#!/usr/bin/env bash
# 実行結果を docs/review-guidelines/<timestamp>/ に保存する。
#
# Usage:
#   save_out.sh <timestamp>
#
# Input:
#   /tmp/all_reviews.json
#   /tmp/guidelines_<timestamp>.md
# Output:
#   docs/review-guidelines/<timestamp>/review-guidelines.md
#   docs/review-guidelines/<timestamp>/pr_ids.json
set -euo pipefail

if (( $# < 1 )); then
  echo "Usage: save_out.sh <timestamp>" >&2
  exit 1
fi

timestamp=$1
out_dir="docs/review-guidelines/${timestamp}"
mkdir -p "$out_dir"

jq '[.[].pr_number] | unique | sort' /tmp/all_reviews.json > "${out_dir}/pr_ids.json"
pr_count=$(jq 'length' "${out_dir}/pr_ids.json")
echo "PR IDリスト保存: ${out_dir}/pr_ids.json (${pr_count} 件)"

md_src="/tmp/guidelines_${timestamp}.md"
if [[ -f "$md_src" ]]; then
  cp "$md_src" "${out_dir}/review-guidelines.md"
  echo "ガイドラインMD保存: ${out_dir}/review-guidelines.md"
else
  echo "警告: ${md_src} が見つかりません。MDのコピーをスキップします。"
fi

echo ""
echo "実行記録保存先: ${out_dir}/"
