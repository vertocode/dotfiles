# Global Claude Instructions

## Version control

Check for a `.jj` folder in the repo root before choosing a workflow:

- **If `.jj` exists** — the repo uses Jujutsu (colocated with git). Use the `jj` aliases from `~/.zshrc`. Never use raw `git commit`, `git push`, or `git checkout`. For the full alias table, commit/push/rebase workflows, conflict resolution, and remote-tracking troubleshooting, use the **`jj-workflow`** skill.
- **If `.jj` does not exist** — use the standard `git` aliases from `~/.zshrc`.

Always run `source ~/.zshrc` before using any alias.

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

## Skills for specific workflows

These detailed workflows live in skills and load on demand — invoke them when relevant instead of keeping the detail always in context:

- **`jj-workflow`** — jj (Jujutsu) aliases, commit/push/rebase, conflict resolution, remote bookmark / "stale info" / non-fast-forward troubleshooting.
- **`start-ticket`** — entry point when starting a new ticket/branch. Decides WHERE work runs (current repo / specific folder / duplicate for parallel) then routes to `work-in-folder` or `parallel-branch-setup`. Use whenever starting work on a branch or Jira ticket and the location is not already decided.
- **`work-in-folder`** — set up the branch bookmark in place (current repo or a named folder), no duplication.
- **`parallel-branch-setup`** — duplicate the repo folder before working on a branch/ticket so sessions stay isolated and branches run in parallel. Used for the "duplicate for parallel" path.
- **`create-pr`** — the required PR body structure (Description, Jira Task, Demo, How can QA test), tone, and QA steps. Use whenever opening a PR.
- **`dotfiles-chezmoi`** — edit chezmoi-managed dotfiles (`.zshrc`, `~/.claude/CLAUDE.md`, etc.) via the source path, then apply and commit. Use whenever editing an alias or any managed dotfile.

## Custom scripts (Rust CLIs in ~/scripts/)

| Alias | Purpose |
|-------|---------|
| `repo-clean` | Removes common web dev artifacts from cwd (node_modules, .next, dist, build, .cache, .turbo, coverage, etc.) |
| `repo-open <folder>` | Finds a folder by exact name under ~/Documents/ and cd into it |
| `portcheck` | Lists all TCP/UDP ports currently listening on the system |

@RTK.md
