#!/usr/bin/env bash
# Start, stop, or remove a sandbox from this kit for the current directory.
#
# Usage:
#   ./vsccc.sh up [NAME] [WORKSPACE]
#   ./vsccc.sh down [NAME]
#   ./vsccc.sh rm [NAME]
#   ./vsccc.sh ls
#   ./vsccc.sh open [NAME] [FOLDER]
#
# 'up' and 'open' then connect VS Code Desktop to the sandbox with FOLDER
# (default /home/agent/workspace) already open.
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
    local sandbox="$1" folder="$2"
    case "$folder" in
        /*) ;;
        *) folder="/$folder" ;;
    esac
    if ! command -v code >/dev/null 2>&1; then
        echo "vsccc.sh: the 'code' CLI is not on PATH" >&2
        echo "vsccc.sh: in VS Code, run 'Shell Command: Install code command in PATH'" >&2
        exit 2
    fi
    exec code --remote "ssh-remote+$sandbox" "$folder"
}

case "$cmd" in
    up)
        workspace="$(cd "$workspace" && pwd)"
        if exists; then
            echo "vsccc.sh: restarting sandbox '$name' (workspace stays as created)"
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
    open)
        open_vscode "$name" "${2:-$default_folder}"
        ;;
    *)
        sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
