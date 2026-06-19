---
name: parallel-branch-setup
description: Duplicate a repo folder before working on a branch/ticket so each Claude session is fully isolated and multiple branches run in parallel. Use for the "duplicate for parallel" path — usually routed here by the start-ticket dispatcher. Branch format JIRA-100/cool-feature; ask for ticket ID + description if missing.
---

# Parallel branch workflow (repo duplication)

Use this when the chosen location mode is **duplicate for parallel** (see the `start-ticket` dispatcher). Duplicate the repo folder first so this Claude session is fully isolated and multiple branches run in parallel without interference. For in-place work (current repo or a named folder, no copy), use `work-in-folder` instead.

## Steps

1. **Identify** the source repo path and branch name (format: `TICKET-ID/description`).

2. **Derive the new folder name** from the branch name, replacing `/` with `-`:
   - Source repo: `project-x`, branch: `PROJECT-123/implement-feature`
   - New folder: `PROJECT-123-implement-feature`

3. **Duplicate the repo** into the same parent directory with `rsync` (not `cp -r`):
   ```sh
   rsync -a /path/to/project-x/ /path/to/PROJECT-123-implement-feature/
   ```
   `cp -r` exits 1 on broken symlinks under `node_modules` (e.g. `.bin/sanity`); `rsync -a` copies symlinks as-is. Note the trailing slashes.

4. **Set up the bookmark** inside the duplicated folder (`cd` there first):
   - **New branch:** `source ~/.zshrc && jfetch && jnewmain "feat: description" PROJECT-123/implement-feature`
   - **Existing branch:** `source ~/.zshrc && jfetch && jedit PROJECT-123/implement-feature` (confirm alias exists first — check `~/.zshrc`; ask user if not found)

5. **Fix the git fetch refspec** so `jj git fetch` tracks the feature branch (not just `main`). In a duplicated repo the refspec only fetches `main` by default, which causes `jpush` to fail with "stale info" whenever the remote moves:
   ```sh
   git config --add remote.origin.fetch '+refs/heads/PROJECT-*:refs/remotes/origin/PROJECT-*'
   git fetch origin
   jj git import
   ```
   Adjust the glob (`PROJECT-*`) to match the ticket prefix in use (e.g. `MARTECH-*`, `POST-*`).

6. **All work happens inside the duplicated folder.** Never modify the original source repo.

## Notes

- If the user has not provided the Jira ticket ID or branch description, ask before duplicating.
- Run `jlog` after switching to confirm `@` is on the correct bookmark before starting any work.
- The duplicated folder is the working directory for the entire session.
- **spanx-storefront:** after `jnewmain` rebases onto latest main, regenerate the gitignored route types or `tsc` throws phantom TS2307 errors: `cd apps/storefront && bunx react-router typegen`.
- **When the user says the ticket is finished**, delete the duplicated folder:
  ```sh
  rm -rf /path/to/PROJECT-123-implement-feature
  ```

See the `jj-workflow` skill for jj alias details and push/rebase troubleshooting.
