#!/usr/bin/env bash
# Publish this kit to an OCI registry with an automatic version bump.
#
# Usage:
#   ./publish.sh [patch|minor|major|X.Y.Z]
#
# Environment:
#   KIT_IMAGE     Registry reference without the tag
#                 (default: ghcr.io/harindaka/sbx-vscode-commandcode)
#   KIT_SIGN=1    Sign the pushed kit keylessly
#   DRY_RUN=1     Print the release plan and exit without changing anything
#
# Requires a clean working tree, sbx login (or registry credentials), and a
# pushed/committed VERSION file.
set -euo pipefail

usage() {
    cat <<'EOF'
Publish this kit to an OCI registry with an automatic version bump.

Usage:
  ./publish.sh [patch|minor|major|X.Y.Z]

Environment:
  KIT_IMAGE     Registry reference without the tag
                (default: ghcr.io/harindaka/sbx-vscode-commandcode)
  KIT_SIGN=1    Sign the pushed kit keylessly
  DRY_RUN=1     Print the release plan and exit without changing anything
EOF
}

resolve_latest_extension() {
    local json version
    json="$(curl -fsSL --max-time 30 -X POST \
        'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery' \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json;api-version=7.2-preview.1' \
        --data '{"filters":[{"criteria":[{"filterType":7,"value":"commandcode.commandcode-vscode"}]}],"flags":914}')" || return 1
    version="$(printf '%s' "$json" \
        | grep -o '"versions":\[{"version":"[^"]*"' \
        | sed 's/.*"version":"//;s/"$//')"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$version"
}

image="${KIT_IMAGE:-ghcr.io/harindaka/sbx-vscode-commandcode}"
bump_arg="${1:-patch}"
dry_run="${DRY_RUN:-0}"

case "$bump_arg" in
    -h|--help|help)
        usage
        exit 0
        ;;
esac

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v sbx >/dev/null 2>&1 || {
    echo "publish.sh: sbx is not on PATH" >&2
    exit 2
}
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "publish.sh: not a git repository" >&2
    exit 2
}

# Allow the release-managed files to be dirty; everything else must be committed.
dirty="$(git status --porcelain --untracked-files=all \
    | grep -vE '^(\?\?|A |M | M|MM) (VERSION|publish\.sh)$' || true)"
if [ -n "$dirty" ]; then
    printf 'publish.sh: working tree is not clean; commit or stash first:\n%s\n' "$dirty" >&2
    exit 1
fi

[ -f VERSION ] || {
    echo "publish.sh: VERSION file is missing" >&2
    exit 1
}
current="$(tr -d '[:space:]' < VERSION)"
if ! [[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "publish.sh: invalid VERSION '$current'" >&2
    exit 1
fi

if [[ "$bump_arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    new="$bump_arg"
else
    case "$bump_arg" in
        patch|minor|major) ;;
        *)
            echo "publish.sh: unknown bump '$bump_arg'" >&2
            usage >&2
            exit 2
            ;;
    esac
    IFS=. read -r major minor patch_part <<< "$current"
    case "$bump_arg" in
        major)
            major=$((10#$major + 1))
            minor=0
            patch_part=0
            ;;
        minor)
            minor=$((10#$minor + 1))
            patch_part=0
            ;;
        patch) patch_part=$((10#$patch_part + 1)) ;;
    esac
    new="$major.$minor.$patch_part"
fi

tag="v$new"
ref="$image:$new"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "publish.sh: tag $tag already exists" >&2
    exit 1
fi

old_ref="ghcr.io/harindaka/sbx-vscode-commandcode:$current"

extension_version="$(resolve_latest_extension)" || {
    echo "publish.sh: could not resolve the latest Command Code extension version" >&2
    exit 1
}

if [ "$dry_run" = "1" ]; then
    printf 'publish.sh: dry run\n  version:   %s -> %s\n  artifact:  %s\n  tag:       %s\n  extension: %s (latest)\n' \
        "$current" "$new" "$ref" "$tag" "$extension_version"
    exit 0
fi

replace_ref() {
    local file="$1" tmp
    grep -qF "$old_ref" "$file" || {
        echo "publish.sh: $file does not reference $old_ref" >&2
        exit 1
    }
    tmp="$(mktemp)"
    sed "s|$old_ref|$ref|g" "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

if [ "$new" != "$current" ]; then
    printf '%s\n' "$new" > VERSION
    replace_ref vsccc.sh
    replace_ref README.md
fi

sbx kit validate .

rm -rf dist
mkdir -p dist
cp spec.yaml README.md LICENSE dist/

bake_extension_version() {
    local file="$1" version="$2" tmp
    tmp="$(mktemp)"
    awk -v ver="$version" '
        /^args:/ { in_args = 1 }
        in_args && /^    default:/ {
            sub(/default:.*/, "default: \"" ver "\"")
            in_args = 0
        }
        { print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
    grep -q "default: \"$version\"" "$file"
}

bake_extension_version dist/spec.yaml "$extension_version" || {
    echo "publish.sh: could not pin the extension version in dist/spec.yaml" >&2
    exit 1
}
printf 'publish.sh: extension pinned to %s\n' "$extension_version"

sbx kit validate dist

printf 'publish.sh: artifact contents:\n'
(cd dist && find . -type f | sort | sed 's|^\./|  |')

if [ "$new" != "$current" ] || ! git ls-files --error-unmatch VERSION >/dev/null 2>&1; then
    git add VERSION vsccc.sh README.md
    git commit -m "release: $tag"
fi

echo "publish.sh: pushing $ref"
if [ "${KIT_SIGN:-0}" = "1" ]; then
    sbx kit push dist "$ref" --sign || push_failed=1
else
    sbx kit push dist "$ref" || push_failed=1
fi
if [ "${push_failed:-0}" = "1" ]; then
    printf 'publish.sh: push failed; the release commit for %s is local only.\n' "$tag" >&2
    printf 'publish.sh: retry with: ./publish.sh %s\n' "$new" >&2
    exit 1
fi

git tag -a "$tag" -m "Release $tag"
git push origin HEAD
git push origin "$tag"

echo "publish.sh: published $ref and pushed $tag"
