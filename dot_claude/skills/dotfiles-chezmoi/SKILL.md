---
name: dotfiles-chezmoi
description: Edit dotfiles managed by chezmoi (.zshrc, ~/.claude/CLAUDE.md, etc.) via the chezmoi source path, then apply and commit. Use whenever the user asks to edit an alias, add a new one, or modify any managed dotfile. Never push without asking; never commit tokens/passwords/API keys.
---

# Dotfiles management with chezmoi

All dotfiles (`.zshrc`, `CLAUDE.md`, etc.) are managed with chezmoi. When the user asks to edit an alias, add a new one, or modify any dotfile:

## Workflow

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

## What counts as a chezmoi-managed file

Any file where `chezmoi source-path <file>` returns a path (e.g. `~/.zshrc`, `~/.claude/CLAUDE.md`). If the command errors, the file is not managed — add it first with `chezmoi add <file>`.
