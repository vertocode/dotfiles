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
| `jdescribe "<msg>"` | `jj describe -m "<msg>"` | Set the description of the current change (`@`) |
| `jdescribe "<msg>" <rev>` | `jj describe <rev> -m "<msg>"` | Set description of a specific revision |
| `jnewmain "<msg>" <bookmark>` | `jj git fetch && jj new main -m "<msg>" && jj bookmark create <bookmark>` | Start a new change from main |
| `jnewcurrent "<msg>" <bookmark>` | `jj git fetch && jj new @ -m "<msg>" && jj bookmark create <bookmark>` | Start a new change on top of current |
| `jcommit` | `jj new @ -m "$1"` | Commit current change and start a new empty one |
| `jdiff` | shows diff vs origin for current bookmark | Review local changes vs remote |
| `jpush` | `jj git push --all --deleted` | Push all bookmarks and delete remote ones that were deleted locally |
| `jtrack <bookmark>` | `jj bookmark track <bookmark> --remote=origin` | Track a remote bookmark |
| `juntrack <bookmark>` | `jj bookmark untrack <bookmark>` | Untrack a remote bookmark |
| `jfetch` | `jj git fetch --all-remotes` | Fetch from all remotes |
| `jdelete <bookmark>` | `jj bookmark delete <bookmark>` | Delete a local bookmark |
| `jsquash` | `jj squash` | Squash current change into parent |
| `jrebase` | rebase entire local stack onto `main@origin` | Rebase all mutable local commits onto latest main |
| `jclone <url>` | `jj git clone --colocate <url>` | Clone a repo with jj+git colocated |
| `jinit` | `jj git init --colocate` | Init jj in an existing git repo |

### Typical jj workflows

- **Start work from main:** `source ~/.zshrc && jnewmain "feat: description" my-bookmark-name`
- **Amend current change:** `source ~/.zshrc && jdescribe "updated message"`
- **Push changes:** `source ~/.zshrc && jpush`
- **Check diff vs remote:** `source ~/.zshrc && jdiff`
- **Rebase onto latest main:** `source ~/.zshrc && jrebase`

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

### If a needed jj command is missing from ~/.zshrc

Ask the user if they want to add it before proceeding. Do not run raw `jj` commands that are not aliased without confirming first.

### git aliases (repos without `.jj`)

| Alias | Purpose |
|-------|---------|
| `commit "<msg>"` | `git add . && git commit -m "<msg>"` |
| `amend` | `git add . && git commit --amend --no-edit` |
| `pull` | Fetch and merge `origin/main` |
| `push` | Push current branch to origin |
| `fpush` | Force-push with lease |
| `new "<branch>"` | Checkout main, reset hard, create new branch |

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
- If there is no visual demo, replace the table with a brief explanation of the observable change.
- Do NOT append any "Generated with Claude Code" footer.

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
