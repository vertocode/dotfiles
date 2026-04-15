#!/bin/sh
# Installs essential dev tools on a new machine.
# Runs whenever this script changes (chezmoi run_onchange_).

set -e

# --- Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# --- NVM ---
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# --- Node (LTS) ---
if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node LTS..."
  nvm install --lts
  nvm use --lts
fi

# --- Claude Code ---
if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
fi

# --- Rust / Cargo ---
if ! command -v cargo >/dev/null 2>&1; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  . "$HOME/.cargo/env"
fi

# --- Bun ---
if ! command -v bun >/dev/null 2>&1; then
  echo "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
fi

# --- jj (Jujutsu) ---
if ! command -v jj >/dev/null 2>&1; then
  echo "Installing jj..."
  brew install jj
fi

# --- gh (GitHub CLI) ---
if ! command -v gh >/dev/null 2>&1; then
  echo "Installing gh..."
  brew install gh
fi

# --- Zed IDE ---
if [ ! -d "/Applications/Zed.app" ]; then
  echo "Installing Zed..."
  brew install --cask zed
fi

echo "Bootstrap complete."
