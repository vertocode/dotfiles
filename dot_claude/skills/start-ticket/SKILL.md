---
name: start-ticket
description: Entry point for starting work on a new Jira ticket or branch. Decides WHERE the work happens — current repo, a specific folder, or a fresh duplicated folder for parallel sessions — then routes to the right setup skill. Use whenever the user asks to start/work on a ticket, branch, or feature and the working location is not already decided.
---

# Start ticket (location dispatcher)

When the user asks to start work on a ticket, branch, or feature, **first decide where the work runs**, then hand off to the matching setup skill. Do not duplicate or set up anything until the location is chosen.

## Step 1 — Gather ticket info

Branch format: `JIRA-100/kebab-description`. If the ticket ID or description is missing, ask for both before continuing.

## Step 2 — Ask the location mode

Unless the user already stated it (e.g. "work in the current repo", "use folder X", "duplicate for parallel"), ask with `AskUserQuestion`:

- **Current repo** — work in the repo at the current working directory. No copy.
- **Specific folder** — work in a repo the user names/points to. No copy.
- **Duplicate for parallel** — copy the repo into a new sibling folder so this session is isolated and other branches run in parallel.

Infer without asking when the user is explicit:
- "current", "here", "this repo" → Current repo
- names a path/folder → Specific folder
- "parallel", "isolated", "duplicate", "new folder" → Duplicate for parallel

## Step 3 — Route

| Choice | Skill to invoke |
|--------|-----------------|
| Current repo | `work-in-folder` (target = cwd) |
| Specific folder | `work-in-folder` (target = the named folder) |
| Duplicate for parallel | `parallel-branch-setup` |

Invoke the chosen skill via the Skill tool and pass along the ticket ID, description, and target folder. That skill owns bookmark setup and any repo prep.

## Notes

- This skill only routes — it never duplicates or runs `jj`/`git` setup itself.
- If the user changes their mind about location mid-session, re-run this dispatch.
