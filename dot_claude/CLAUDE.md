# Global Claude Instructions

## Version control

Check for a `.jj` folder in the repo root before choosing a workflow:

- **If `.jj` exists** — the repo uses Jujutsu (colocated with git). Use the `jj` aliases from `~/.zshrc`. Never use raw `git commit`, `git push`, or `git checkout`.
- **If `.jj` does not exist** — use the standard `git` aliases from `~/.zshrc` (`commit`, `push`, `pull`, `new`, etc.).

Always run `source ~/.zshrc` before using any alias.

### jj aliases (repos with `.jj`)

### Key aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `jlog` | `jj log` | View commit graph |
| `jbranch [base]` | `jj log -r "::@ ~ ::<base>@origin"` | Show commits unique to current branch vs base (defaults to `main`) |
| `jedit <bookmark>` | `jj edit <bookmark>` | Switch `@` to an existing bookmark/revision |
| `jdescribe "<msg>"` | `jj describe -m "<msg>"` | Set the description of the current change (`@`) |
| `jdescribe "<msg>" <rev>` | `jj describe <rev> -m "<msg>"` | Set description of a specific revision |
| `jnewmain "<msg>" <bookmark>` | `jj git fetch && jj new main -m "<msg>" && jj bookmark create <bookmark>` | Start a new change from main |
| `jnewcurrent "<msg>" <bookmark>` | `jj git fetch && jj new @ -m "<msg>" && jj bookmark create <bookmark>` | Start a new change on top of current |
| `jnewfrom <from> "<msg>" <bookmark>` | `jj git fetch && jj new <from> -m "<msg>" && jj bookmark create <bookmark>` | Start a new change from a specific branch |
| `jcommit "<msg>"` | finds current bookmark, creates a new child commit, advances the bookmark to it | Commit current change and advance the bookmark |
| `jdiff` | shows diff vs origin for current bookmark | Review local changes vs remote |
| `jrestore [file]` | restores file (or whole bookmark) to its remote state | Hard-reset to remote; pass a path to restore just that file |
| `jpush` | auto-detects bookmark on `@`, runs `jj git push --bookmark <that>` | Push only the current branch |
| `jpushall` | `jj git push --all --deleted` | Push all bookmarks and delete remote ones removed locally |
| `jtrack <bookmark>` | `jj bookmark track <bookmark> --remote=origin` | Track a remote bookmark |
| `juntrack <bookmark>` | `jj bookmark untrack <bookmark>` | Untrack a remote bookmark |
| `jfetch` | `jj git fetch --all-remotes` | Fetch from all remotes |
| `jdelete <bookmark>` | `jj bookmark delete <bookmark>` | Delete a local bookmark |
| `jsquash` | `jj squash` | Squash current change into parent |
| `jrebase` | rebase entire local stack onto `main@origin` | Rebase all mutable local commits onto latest main |
| `jrebaseparent [branch]` | rebase stack onto parent branch (auto-detected or explicit) | Rebase onto a parent feature branch instead of main |
| `jclone <url>` | `jj git clone --colocate <url>` | Clone a repo with jj+git colocated |
| `jinit` | `jj git init --colocate` | Init jj in an existing git repo |

### Typical jj workflows

- **Start work from main:** `source ~/.zshrc && jfetch && jnewmain "feat: description" my-bookmark-name`
- **Start work from current:** `source ~/.zshrc && jfetch && jnewcurrent "feat: description" my-bookmark-name`
- **Amend current change:** `source ~/.zshrc && jdescribe "updated message"`
- **Push changes:** `source ~/.zshrc && jpush`
- **Check diff vs remote:** `source ~/.zshrc && jdiff`
- **Rebase onto latest main:** `source ~/.zshrc && jrebase`

> **Always run `jfetch` before `jnewmain` or `jnewcurrent`** — even though the aliases call `jj git fetch` internally, `jfetch` fetches all remotes (`--all-remotes`) and ensures the local view is fully up to date before branching, preventing conflicts from stale base commits.

### Resolving rebase conflicts

When `jrebase` leaves a commit marked `(conflict)` in `jlog`:

1. **Create a resolution commit on top of the conflicted one:**
   ```sh
   jj new <conflicted-change-id>
   ```
   `@` is now a clean working copy. jj embeds conflict markers directly in file content.

2. **Edit the files** to resolve the markers. jj conflict markers look like:
   ```
   <<<<<<< conflict 1 of N
   +++++++ <destination side description>
     ... destination version ...
   %%%%%%% diff from: <base> to: <our revision>
     ... diff-style of our changes ...
   >>>>>>> conflict 1 of N ends
   ```
   Replace the entire marker block (including surrounding lines that belong to the conflict) with the resolved code.

3. **Squash the resolution into the conflicted parent:**
   ```sh
   jj squash
   ```

4. **Check if the bookmark needs moving.** After squash, run `jj log`. If you see the same change ID split into two divergent versions — e.g. `xyz/0` (clean) and `xyz/2` (conflict) — and the bookmark is on the conflicted one, move it:
   ```sh
   jj bookmark set <bookmark-name> -r <change-id>/0 --allow-backwards
   ```
   If the bookmark is already on the clean commit, skip this step.

5. **Push:**
   ```sh
   jpush
   ```

Also: if `jj squash` fails with a git index lock error, delete the stale lock first:
```sh
rm -f <repo-root>/.git/index.lock
```

### jj remote tracking and bookmark conflicts

#### "Stale info" error from `jpush`

Happens when jj's internal remote bookmark tracking is out of sync with the actual remote (common in duplicated repos where the fetch refspec was not set up). Fix sequence:

```sh
git config --add remote.origin.fetch '+refs/heads/TICKET-*:refs/remotes/origin/TICKET-*'
git fetch origin
jj git import
```

After `jj git import`, jj's view of `@origin` will match the real remote. Then `jpush` works if the local bookmark is a descendant of `@origin` (fast-forward).

#### Conflicted bookmark (`??` in `jlog`)

Shows as `BOOKMARK-NAME??` in `jlog`. Means jj sees the bookmark pointing to two different commits (usually one local, one from the remote import). Verify with:

```sh
jj bookmark list <bookmark-name>
```

Resolve by explicitly setting it to your local revision:

```sh
jj bookmark set <bookmark-name> -r <your-change-id>
```

Then `jpush` fast-forwards cleanly — **but only if your revision is a descendant of `@origin`**.

#### When `jpush` is blocked (non-fast-forward / divergent histories)

If the local bookmark is not a descendant of the remote tip, `jpush` refuses. This happens when:
- The remote was force-pushed to a different history while you were working
- Squashing commits changed the git hash of an already-pushed commit

**Option A — Rebase onto remote tip (keeps history linear, may produce conflicts):**

```sh
jj git fetch
jj git import
jj rebase -r @ -d '<bookmark-name>@origin'
# resolve any conflicts (see "Resolving rebase conflicts" above)
jpush
```

Note: if both sides modified the same file, the rebase may only produce a trivial format/style diff. In that case the extra commit is fine to push as a fast-forward.

**Option B — Create a clean squash commit via `git commit-tree` and force-push:**

Useful when you want to replace N remote commits with one squashed commit (e.g. reviewer asks to squash):

```sh
# 1. Get the tree of the commit that has the correct final content
TREE=$(git rev-parse <revision-with-correct-tree>^{tree})
# 2. Point it at the desired parent on the remote
PARENT=<desired-parent-git-hash>
# 3. Create the squash commit (does not touch working copy or HEAD)
NEW=$(git commit-tree $TREE -p $PARENT -m "fix: message")
echo $NEW   # verify the hash
git log --oneline $NEW | head -4   # verify ancestry
# 4. Force-push (user must run this; Claude's permissions block force push)
git push origin $NEW:refs/heads/<branch> \
  --force-with-lease=refs/heads/<branch>:<current-remote-hash>
```

After the force-push succeeds, run `jj git fetch && jj git import` to resync jj.

#### Checking the true remote state (bypasses stale tracking refs)

`git fetch` and `jj git fetch` may not update tracking refs if the refspec is wrong. Always verify the real remote with:

```sh
git ls-remote origin <branch-name>
```

### If a needed jj command is missing from ~/.zshrc

Ask the user if they want to add it before proceeding. Do not run raw `jj` commands that are not aliased without confirming first.

### Keeping the alias table in sync

Whenever a jj alias is added or changed in `~/.zshrc` (or discovered in `~/.zshrc` but absent from this table), **always update the Key aliases table above** in the same chezmoi edit session. This applies to jj aliases specifically; for git or other aliases, only sync when the user asks.

### git aliases (repos without `.jj`)

| Alias | Purpose |
|-------|---------|
| `commit "<msg>"` | `git add . && git commit -m "<msg>"` |
| `amend` | `git add . && git commit --amend --no-edit` |
| `pull` | Fetch and merge `origin/main` |
| `push` | Push current branch to origin |
| `fpush` | Force-push with lease |
| `new "<branch>"` | Checkout main, reset hard, create new branch |

## Commit message format

Always use conventional commits: `type: short description` on a single line.

- **Types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `perf`
- **Description:** one brief line — a high-level summary, not an exhaustive list of changes
- **Examples:** `feat: add user auth`, `fix: null check in parser`, `chore: update deps`

No body, no bullet points, no multi-line messages unless the user explicitly asks for more detail.

## Branch naming convention

Always name branches in the format `JIRA-100/cool-feature` — Jira ticket ID, a slash, then a short kebab-case description of the work.

If the user asks to create a branch but hasn't provided the Jira ticket ID or a description, ask for both before proceeding.

## Parallel branch workflow (repo duplication)

When the user asks to work on a repo in a specific branch or ticket, **always** duplicate the repo folder first so each Claude session is fully isolated and multiple branches can run in parallel without interference.

### Steps

1. **Identify** the source repo path and branch name (format: `TICKET-ID/description`).

2. **Derive the new folder name** by appending the branch to the repo name, replacing `/` with `-`:
   - Source repo: `project-x`, branch: `PROJECT-123/implement-feature`
   - New folder: `project-x-PROJECT-123-implement-feature`

3. **Duplicate the repo** into the same parent directory:
   ```sh
   cp -r /path/to/project-x /path/to/project-x-PROJECT-123-implement-feature
   ```

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

### Notes

- If the user has not provided the Jira ticket ID or branch description, ask before duplicating.
- Run `jlog` after switching to confirm `@` is on the correct bookmark before starting any work.
- The duplicated folder is the working directory for the entire session.
- **When the user says the ticket is finished**, delete the duplicated folder:
  ```sh
  rm -rf /path/to/project-x-PROJECT-123-implement-feature
  ```

## Custom scripts (Rust CLIs in ~/scripts/)

| Alias | Purpose |
|-------|---------|
| `repo-clean` | Removes common web dev artifacts from cwd (node_modules, .next, dist, build, .cache, .turbo, coverage, etc.) |
| `repo-open <folder>` | Finds a folder by exact name under ~/Documents/ and cd into it |
| `portcheck` | Lists all TCP/UDP ports currently listening on the system |

## Pull Request format

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

### Tone and length

Keep PR descriptions short and friendly — match length to code complexity, not formality. Write the way you'd brief a teammate in Slack.

- For small changes (a single field added, a small bug fix, a config tweak): the **Description** is one or two sentences. No paragraphs of context, no "out of scope" notes, no rationale sections.
- For larger or genuinely complex changes (architectural refactors, multi-system features): more detail is fine, but still cut anything a reviewer can see in the diff.
- The diff is the source of truth. The description just orients the reader — it should be skimmable in ~10 seconds.

### QA steps

Keep the **How can QA test** list short and concrete. 2–4 numbered steps for a small change; only go longer when the feature really has multiple flows worth verifying. Each step should be one action the tester can actually do (open a page, click a button, check a network request) — not a paragraph.

## Dotfiles management with chezmoi

All dotfiles (`.zshrc`, `CLAUDE.md`, etc.) are managed with chezmoi. When the user asks to edit an alias, add a new one, or modify any dotfile:

### Workflow

1. **Edit** the source via the chezmoi source path (since `chezmoi edit` requires an interactive terminal not available to Claude):
   - Find source path: `chezmoi source-path <file>`
   - Edit the file at that source path using the Edit tool
2. **Apply** the changes to the home directory:
   ```sh
   chezmoi apply <file>
   ```
3. **Commit** the changes inside the chezmoi repo:
   ```sh
   chezmoi cd && git add . && git commit -m "<describe what changed>"
   ```
4. **Ask the user** whether to push before doing so — always review the diff for sensitive data first:
   ```sh
   git diff HEAD~1
   ```
   Never push automatically. Never commit tokens, passwords, API keys, or personal data.

### What counts as a chezmoi-managed file

Any file where `chezmoi source-path <file>` returns a path (e.g. `~/.zshrc`, `~/.claude/CLAUDE.md`). If the command errors, the file is not managed — add it first with `chezmoi add <file>`.
