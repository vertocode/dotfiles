---
name: work-in-folder
description: Set up a branch/ticket bookmark inside an existing repo folder — the current working directory or a folder the user names — WITHOUT duplicating the repo. Use when the user wants to work on a ticket in place (current repo or a specific folder), not in a parallel duplicate. Usually invoked by the start-ticket dispatcher.
---

# Work in folder (in-place, no duplication)

Set up the branch directly in an existing repo folder. No copy is made. Use this for the "current repo" and "specific folder" paths from `start-ticket`.

## Steps

1. **Resolve the target folder.**
   - Current repo → the current working directory.
   - Specific folder → the path the user named. `cd` there first. Confirm it exists and is a repo (has `.git`, and `.jj` if jj-managed).

2. **Confirm it is safe to work in place.** This folder is the real repo, not a copy — uncommitted changes and the active bookmark belong to the user. Run `jlog` / `jst` (or `git status`) and check the tree is clean or that the user is fine continuing on top of current state. If dirty and unexpected, ask before proceeding.

3. **Set up the bookmark** (format `TICKET-ID/description`):
   - **New branch:** `source ~/.zshrc && jfetch && jnewmain "feat: description" PROJECT-123/implement-feature`
   - **Existing branch:** `source ~/.zshrc && jfetch && jedit PROJECT-123/implement-feature` (confirm the alias exists in `~/.zshrc`; ask if not found)

4. **Confirm placement.** Run `jlog` to verify `@` is on the correct bookmark before starting work.

## Notes

- No refspec fix needed — an in-place clone already tracks its branches (unlike a fresh duplicate; that fix lives in `parallel-branch-setup`).
- **Never** `rm -rf` this folder on completion — it is the user's working repo, not a throwaway duplicate. Just push/finish the branch normally.
- For jj alias details and push/rebase troubleshooting, see the `jj-workflow` skill.
