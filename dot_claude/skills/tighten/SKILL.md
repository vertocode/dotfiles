---
name: tighten
description: Critically review recently changed code and remove waste — unnecessary tests, comments, defensive guards, fallback branches, and type assertions. Keep only what's required and idiomatic for the project. Run on the current working diff after a feature/fix is implemented, before opening or finalizing a PR. Triggers on phrases like "tighten the changes", "review for waste", "trim the diff", "remove unnecessary code/tests/comments".
---

# Tighten

You are doing a critical second-pass review of the **changes the user just made**, not the whole codebase. The goal is to remove anything that doesn't earn its place: speculative defensiveness, tautological tests, narrating comments, and type assertions.

Be ruthless. Most cleanup feedback is "this is fine, don't change it" — but every line you do change should be one a reviewer would call out.

## 1. Identify the diff

Detect the VCS in use and read the unstaged + new changes:
- If `.jj` exists in the repo root → use `jj diff -r @` (and `jj diff -r @ --summary` for the file list).
- Else → use `git diff` and `git status --short`; include staged and unstaged.

If the diff is empty, ask the user which range to review (e.g. last commit, vs. a base branch). Don't review the whole repo.

## 2. Read each changed file end-to-end

Before flagging anything, read the full final version of every changed file. Skimming the diff alone misses context (e.g. a helper looks fine in the diff but duplicates an existing utility one folder over).

## 3. Apply the checklist

For each addition, ask the question and act:

**Defensive code that can't fail.**
- Guards for impossible states (e.g. checking a value is non-null right after a function that always returns non-null; SSR guards inside code that's already gated upstream; `try/catch` around code that can't throw).
- Fallbacks for inputs that never arrive in that shape (e.g. parsing a known-format ID and falling back to the raw value "just in case").
- Validation at internal boundaries. Validate at system boundaries (user input, external APIs); trust your own code.
- → **Remove.** If the impossible state ever happens, fail loudly rather than silently coping.

**Comments.**
- WHAT comments that restate the code (`// loop over items` above `for (const item of items)`).
- Comments duplicated across the file or duplicating an adjacent docblock.
- TODOs without a ticket, "added for X" notes, "do not remove" pleas.
- → **Remove.** Keep a comment only if it explains a non-obvious WHY (a workaround, a constraint, a footgun for the next reader).

**Type assertions.**
- `value as Type`, `as unknown as Type`, `<Type>value` casts, `!` non-null assertions.
- → **Replace.** Use a runtime type guard (`typeof x === 'object'`, `Array.isArray`, schema parse), a type annotation on a variable, or `satisfies`. If the only option is a cast, document why in one line.

**Tests.**
- A test that asserts the framework/language behaves correctly (e.g. `expect(typeof x).toBe('string')` right after `expect(x).toBe('foo')`).
- Multiple tests that exercise the same code path with trivially different inputs — collapse with `it.each`/parametrization.
- Tests for code that was deleted in the same change.
- Tests for behaviour the production code can't produce (testing branches that fallbacks reach but real callers never hit).
- Snapshot tests where the assertion has no semantic check.
- → **Drop or consolidate.** Every test should describe a regression worth catching.

**Code blocks.**
- Helpers used only once and only locally — inline them.
- Abstractions added "in case we need it later" with no second caller — inline them.
- Re-exports/barrels that exist only for the new code's convenience — drop them.
- Imports for symbols that ended up unused after edits.
- → **Inline or delete.** Three duplicate lines beat one premature abstraction.

**Project idioms.**
- Before keeping a defensive pattern, grep for the same situation elsewhere in the codebase. If the rest of the project doesn't guard, don't guard here.
- Mirror existing naming, error-handling, logging, and test-style conventions found in neighbouring files.
- → **Conform.** Consistency reduces review friction more than any individual cleanup.

## 4. Verify before acting

A change is only safe if you can confirm the project's own validation passes after it. Detect and run, in this order, whatever the project actually uses:
1. Type check (e.g. `tsc --noEmit`, `mypy`, `go vet`).
2. Linter (e.g. `eslint`, `oxlint`, `ruff`, `golangci-lint`).
3. Formatter (e.g. `prettier`, `oxfmt`, `biome`, `gofmt`, `ruff format`). Run the *write* mode, not just *check* — CI typically diffs the working tree after formatting, so unformatted code lands as a failure. Skip only if no format script exists.
4. The specific test files you touched (full suite is overkill at this stage).

Detect commands from `package.json` scripts, `Makefile`, `justfile`, language convention, or the project's CLAUDE.md / README. If you can't find them, ask the user which to run.

## 5. Report

After applying changes, give the user a short summary: what you removed, what you kept and why (briefly), and the validation results. Match the brevity of a Slack message — don't restate the diff.

## What this skill is NOT

- Not a full code review (security, architecture, naming bikeshed) — those need separate passes.
- Not a rewrite — preserve the user's intent and shape; only remove waste.
- Not project-aware out of the box — always read the surrounding code first.
- Not a substitute for the user's judgment — when a kept comment or guard is debatable, leave it and flag it in the report rather than removing silently.
