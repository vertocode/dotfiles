---
name: jj-workflow
description: Jujutsu (jj) version control workflows for repos with a .jj folder — aliases, committing, pushing, rebasing, resolving rebase conflicts, and fixing remote bookmark tracking / non-fast-forward / "stale info" errors. Use when running jj commands or hitting any jj, bookmark, or jj push error. Always run `source ~/.zshrc` before using any alias.
---

# jj (Jujutsu) workflows

Use these `jj` aliases from `~/.zshrc`. **Never use raw `git commit`, `git push`, or `git checkout`** in a `.jj` repo. Always run `source ~/.zshrc` before using any alias.

## Key aliases

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
| `jtrackall [target]` | tracks every untracked remote bookmark with a commit you authored vs `target@origin` (defaults to `main`) | Bulk-track your remote feature branches so `jrebase` + `jpushall` can update them all |
| `juntrack <bookmark>` | `jj bookmark untrack <bookmark>` | Untrack a remote bookmark |
| `jfetch` | `jj git fetch --all-remotes` | Fetch from all remotes |
| `jdelete <bookmark>` | `jj bookmark delete <bookmark>` | Delete a local bookmark |
| `jsquash` | `jj squash` | Squash current change into parent |
| `jrebase` | rebase entire local stack onto `main@origin` | Rebase all mutable local commits onto latest main |
| `jrebaseparent [branch]` | rebase stack onto parent branch (auto-detected or explicit) | Rebase onto a parent feature branch instead of main |
| `jclone <url>` | `jj git clone --colocate <url>` | Clone a repo with jj+git colocated |
| `jinit` | `jj git init --colocate` | Init jj in an existing git repo |

## Typical workflows

- **Start work from main:** `source ~/.zshrc && jfetch && jnewmain "feat: description" my-bookmark-name`
- **Start work from current:** `source ~/.zshrc && jfetch && jnewcurrent "feat: description" my-bookmark-name`
- **Amend current change:** `source ~/.zshrc && jdescribe "updated message"`
- **Push changes:** `source ~/.zshrc && jpush`
- **Check diff vs remote:** `source ~/.zshrc && jdiff`
- **Rebase onto latest main:** `source ~/.zshrc && jrebase`

> **Always run `jfetch` before `jnewmain` or `jnewcurrent`** — even though the aliases call `jj git fetch` internally, `jfetch` fetches all remotes (`--all-remotes`) and ensures the local view is fully up to date before branching, preventing conflicts from stale base commits.

## Resolving rebase conflicts

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

## Remote tracking and bookmark conflicts

### "Stale info" error from `jpush`

Happens when jj's internal remote bookmark tracking is out of sync with the actual remote (common in duplicated repos where the fetch refspec was not set up). Fix sequence:

```sh
git config --add remote.origin.fetch '+refs/heads/TICKET-*:refs/remotes/origin/TICKET-*'
git fetch origin
jj git import
```

After `jj git import`, jj's view of `@origin` will match the real remote. Then `jpush` works if the local bookmark is a descendant of `@origin` (fast-forward).

### Conflicted bookmark (`??` in `jlog`)

Shows as `BOOKMARK-NAME??` in `jlog`. Means jj sees the bookmark pointing to two different commits (usually one local, one from the remote import). Verify with:

```sh
jj bookmark list <bookmark-name>
```

Resolve by explicitly setting it to your local revision:

```sh
jj bookmark set <bookmark-name> -r <your-change-id>
```

Then `jpush` fast-forwards cleanly — **but only if your revision is a descendant of `@origin`**.

### When `jpush` is blocked (non-fast-forward / divergent histories)

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

### Checking the true remote state (bypasses stale tracking refs)

`git fetch` and `jj git fetch` may not update tracking refs if the refspec is wrong. Always verify the real remote with:

```sh
git ls-remote origin <branch-name>
```

## If a needed jj command is missing from ~/.zshrc

Ask the user if they want to add it before proceeding. Do not run raw `jj` commands that are not aliased without confirming first.

## Keeping the alias table in sync

Whenever a jj alias is added or changed in `~/.zshrc` (or discovered in `~/.zshrc` but absent from this table), **always update the Key aliases table above** in the same chezmoi edit session. This applies to jj aliases specifically; for git or other aliases, only sync when the user asks.
