---
name: pr-review
description: Opinionated PR / diff review against a fixed checklist — type assertions, unnecessary blocks, simplification opportunities, security issues, performance issues. Use whenever the user asks to review a PR, review a diff, or review changes. Reports one finding per line, severity-tagged, no praise.
---

# PR review

Review the target changes against the checklist below. Report only real, actionable findings — no praise, no restating what the code does.

## 1. Get the diff

In order of preference:

```sh
gh pr diff <number>          # explicit PR
gh pr diff                   # current branch's PR
```

If there is no PR yet, review the working changes instead:
- `.jj` repo → `jdiff` (or `jj diff`)
- git repo → `git diff main...HEAD` (committed) and `git diff` (uncommitted)

Read the full diff. For any changed symbol whose surrounding context matters, open the file — don't review hunks blind.

## 2. Checklist

Check every changed file for all five:

1. **Type assertions** — flag every `as`, `as any`, `as unknown`, non-null `!`, `@ts-ignore`/`@ts-expect-error`, or unsafe cast. Each one hides a real type. Propose the typed alternative (narrowing, generics, a guard, fixing the source type) or justify why it's unavoidable.
2. **Unnecessary blocks** — dead code, unreachable branches, redundant `else` after return, needless wrapping (`{}` / IIFE / one-call helper), commented-out code, no-op guards, duplicated logic that already exists elsewhere.
3. **Improvements / simplification** — clearer name, earlier return, reuse an existing util instead of reimplementing, collapse nested conditionals, remove a temp variable, idiomatic API the project already uses. Only suggest changes that are clearly better, not stylistic preference.
4. **Security** — injection (SQL/command/template), unvalidated input, secrets or tokens in code, missing authz/authn checks, unsafe deserialization, path traversal, SSRF, weak crypto, leaking data in logs/errors, dependency with a known issue.
5. **Performance** — N+1 queries, work inside a loop that belongs outside, missing `await` parallelism (sequential awaits that could be `Promise.all`), unbounded fetch/allocation, re-render / re-compute that isn't memoized, O(n²) where O(n) is easy, blocking the event loop.

## 3. Output format

One line per finding:

```
path:line: <emoji> <severity>: <problem>. <fix>.
```

Severity + emoji: 🔴 critical · 🟠 high · 🟡 medium · 🔵 low.

Group nothing, pad nothing. Order by severity, highest first. If a category has zero findings, say so in one line (e.g. `Security: none found.`) rather than inventing weak ones.

End with a one-line verdict: whether the diff is safe to merge, or the blocking items that must be fixed first.
