---
name: create-pr
description: Create a GitHub pull request with the user's required body structure (Description, Jira Task, Demo, How can QA test). Use whenever opening or drafting a PR with gh pr create. Always --draft unless told ready, always --base main and --head <bookmark>, never a "Generated with Claude Code" footer.
---

# Pull Request creation

Always use `gh pr create` with `--base main` (or the correct target branch). Always pass `--draft` unless the user explicitly says the PR is ready for review. Always use `--head <bookmark-name>` since repos use jj colocated with git and `gh` cannot detect the current branch automatically.

Every PR body **must** follow this structure:

```
## Description

<short 1–3 sentence summary of what the PR does and why — keep it minimal>

## Jira Task

https://company.atlassian.net/browse/<TICKET-ID>

## Demo

Before | After
-- | --
<before state> | <after state>

## How can QA test

1. <step one>
2. <step two>
...
```

- If there is no Jira ticket, omit that section.
- If there is no visual demo, omit the Demo section entirely. Do not replace it with a paragraph of explanation — the Description already covers that.
- Do NOT append any "Generated with Claude Code" footer.

## Tone and length

Keep PR descriptions short and friendly — match length to code complexity, not formality. Write the way you'd brief a teammate in Slack.

- For small changes (a single field added, a small bug fix, a config tweak): the **Description** is one or two sentences. No paragraphs of context, no "out of scope" notes, no rationale sections.
- For larger or genuinely complex changes (architectural refactors, multi-system features): more detail is fine, but still cut anything a reviewer can see in the diff.
- The diff is the source of truth. The description just orients the reader — it should be skimmable in ~10 seconds.

## QA steps

Keep the **How can QA test** list short and concrete. 2–4 numbered steps for a small change; only go longer when the feature really has multiple flows worth verifying. Each step should be one action the tester can actually do (open a page, click a button, check a network request) — not a paragraph.
