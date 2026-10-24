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
# Defaults: NAME=command-code-agent, WORKSPACE=$PWD,
#           KIT=ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2
# Override the kit with VSCCC_KIT (absolute path to a local kit, or another ref).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kit_ref="${VSCCC_KIT:-ghcr.io/harindaka/sbx-vscode-commandcode:0.1.2}"
default_name="command-code-agent"

cmd="${1:-}"
shift || true
name="${1:-$default_name}"
workspace="${2:-$PWD}"

exists() {
    sbx ls -q | grep -qxF "$name"
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
        exec "$script_dir/open-vscode.sh" "$name"
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
        exec "$script_dir/open-vscode.sh" "$name" "${2:-/home/agent/workspace}"
        ;;
    *)
        sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
