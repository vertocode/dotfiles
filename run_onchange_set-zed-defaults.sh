#!/bin/sh
# Sets Zed as the default application for common code file extensions.
# Runs whenever this script changes (chezmoi run_onchange_).

if ! command -v duti >/dev/null 2>&1; then
  echo "duti not found, installing..."
  brew install duti
fi

for ext in c cpp cs css go h js json jsx kt md py rb rs sh swift toml ts tsx txt yaml yml; do
  duti -s dev.zed.Zed .$ext all
done
