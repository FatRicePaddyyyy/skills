#!/usr/bin/env bash
# 各バッチの結果JSONを結合し、並列分析用にチャンクへ分割して保存する。
#
# Input:  /tmp/reviews_*.json
# Output: /tmp/all_reviews.json, /tmp/review_chunk_N.json, /tmp/num_chunks.txt
set -euo pipefail

MAX_CHUNKS=8
MIN_PRS_PER_CHUNK=10

shopt -s nullglob
files=(/tmp/reviews_*.json)
if (( ${#files[@]} == 0 )); then
  echo '[]' > /tmp/all_reviews.json
  echo 1 > /tmp/num_chunks.txt
  echo '[]' > /tmp/review_chunk_0.json
  echo "PRs with comments: 0, total comments: 0"
  echo "チャンク数: 1"
  exit 0
fi

jq -s 'add | sort_by(.pr_number) | reverse' "${files[@]}" > /tmp/all_reviews.json

total_prs=$(jq 'length' /tmp/all_reviews.json)
total_comments=$(jq '[.[].comments | length] | add // 0' /tmp/all_reviews.json)
echo "PRs with comments: ${total_prs}, total comments: ${total_comments}"

if (( total_prs == 0 )); then
  num_chunks=1
else
  num_chunks=$(( total_prs / MIN_PRS_PER_CHUNK ))
  if (( num_chunks < 1 )); then num_chunks=1; fi
  if (( num_chunks > MAX_CHUNKS )); then num_chunks=$MAX_CHUNKS; fi
fi

chunk_size=$(( total_prs / num_chunks + 1 ))
echo "チャンク数: ${num_chunks}"

for (( chunk_idx = 0; chunk_idx < num_chunks; chunk_idx++ )); do
  start=$(( chunk_idx * chunk_size ))
  end=$(( start + chunk_size ))
  path="/tmp/review_chunk_${chunk_idx}.json"
  jq ".[${start}:${end}]" /tmp/all_reviews.json > "$path"
  n_prs=$(jq 'length' "$path")
  if (( n_prs == 0 )); then
    rm -f "$path"
    continue
  fi
  n_comments=$(jq '[.[].comments | length] | add // 0' "$path")
  echo "  chunk_${chunk_idx}: ${n_prs} PRs, ${n_comments} comments → ${path}"
done

echo "$num_chunks" > /tmp/num_chunks.txt
