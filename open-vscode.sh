#!/usr/bin/env bash
# Opens VS Code Desktop connected to an sbx sandbox with a folder already open.
#
# Usage:
#   ./open-vscode.sh [SANDBOX] [REMOTE_FOLDER]
#
# Defaults: SANDBOX=command-code-agent, REMOTE_FOLDER=/home/agent/workspace
set -euo pipefail

sandbox="${1:-command-code-agent}"
folder="${2:-/home/agent/workspace}"

case "$folder" in
    /*) ;;
    *) folder="/$folder" ;;
esac

if ! command -v code >/dev/null 2>&1; then
    echo "open-vscode.sh: the 'code' CLI is not on PATH" >&2
    echo "open-vscode.sh: in VS Code, run 'Shell Command: Install code command in PATH'" >&2
    exit 2
fi

exec code --remote "ssh-remote+${sandbox}" "$folder"
