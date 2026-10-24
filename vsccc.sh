#!/usr/bin/env bash
# Start, stop, or remove a sandbox from this kit for the current directory.
#
# Usage:
#   ./vsccc.sh up [NAME] [WORKSPACE]
#   ./vsccc.sh down [NAME]
#   ./vsccc.sh rm [NAME]
#   ./vsccc.sh ls
#
# 'up' is idempotent: it creates the sandbox if needed, starts it if it is
# stopped, then connects VS Code Desktop with /home/agent/workspace open.
#
# Defaults: NAME=command-code-agent, WORKSPACE=$PWD,
#           KIT=ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2
# Override the kit with VSCCC_KIT (absolute path to a local kit, or another ref).
set -euo pipefail

kit_ref="${VSCCC_KIT:-ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2}"
default_name="command-code-agent"
default_folder="/home/agent/workspace"

cmd="${1:-}"
shift || true
name="${1:-$default_name}"
workspace="${2:-$PWD}"

exists() {
    sbx ls -q | grep -qxF "$name"
}

open_vscode() {
    if ! command -v code >/dev/null 2>&1; then
        echo "vsccc.sh: the 'code' CLI is not on PATH" >&2
        echo "vsccc.sh: in VS Code, run 'Shell Command: Install code command in PATH'" >&2
        exit 2
    fi
    exec code --remote "ssh-remote+$1" "$2"
}

case "$cmd" in
    up)
        workspace="$(cd "$workspace" && pwd)"
        if exists; then
            echo "vsccc.sh: starting sandbox '$name' (workspace stays as created)"
            sbx run -d --name "$name"
        else
            echo "vsccc.sh: creating sandbox '$name' for $workspace"
            sbx run -d --name "$name" "$kit_ref" "$workspace"
        fi
        open_vscode "$name" "$default_folder"
        ;;
    down)
        sbx stop "$name"
        ;;
    rm)
        sbx rm --force "$name"
        ;;
    ls)
        sbx ls
        ;;
    *)
        sed -n '2,${/^#/!q;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"
        exit 2
        ;;
esac
