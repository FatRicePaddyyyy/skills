# PRレビューガイドライン

## このドキュメントについて

このドキュメントは、{{repo_name}} リポジトリの全マージ済み PR（{{merged_pr_count}}件）のレビューコメント（{{total_comment_count}}件）を分析し、
実際にレビューで指摘・議論された内容をガイドラインとして体系化したものです。
各ガイドラインには根拠となった実際のPRとコメントへの参照を記載しています。

最終更新: {{date}}（PR #{{min_pr_number}}〜#{{max_pr_number}} のレビューコメントを分析）

## 活用方法

- **PR作成時:** チェックリストとして活用し、よくある指摘を事前に自己レビューする
- **コードレビュー時:** レビューコメントの根拠として参照する
- **オンボーディング:** このリポジトリ固有のコーディング規約・設計方針を把握する

## 目次

{{toc}}

## {{section_number}}. {{category_name}}

### {{guideline_title}}

**ルール:** {{rule}}

**理由:** {{rationale}}

**悪い例:**
```{{example_language}}
{{dont_example}}
```

**良い例:**
```{{example_language}}
{{do_example}}
```

**参考PRとコメント:**
- [PR #{{pr_number}}: {{pr_title}}]({{repo_url}}/pull/{{pr_number}}) — @{{author}}: "{{comment_excerpt}}"

---

## まとめ

以上のガイドラインは、実際のPRレビューコメントから帰納的に導出したものです。
新たなパターンが確認された場合は、このドキュメントを更新してください。
