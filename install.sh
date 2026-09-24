#!/usr/bin/env bash
# Copies the runtime part of this plugin into Claude Code's skills directory,
# where it auto-loads as <name>@skills-dir in every session. A copy rather
# than a symlink keeps the installed plugin stable while the repo is edited;
# re-run to pick up changes.
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_NAME="$(jq -r '.name' "$ROOT/.claude-plugin/plugin.json")"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/$PLUGIN_NAME"

usage() { echo "Usage: install.sh [--dest DIR]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || usage; dest="$2"; shift 2 ;;
    *) usage ;;
  esac
done

# Only replace something we installed before; never wipe an unrelated directory.
if [ -e "$dest" ]; then
  existing="$(jq -r '.name' "$dest/.claude-plugin/plugin.json" 2>/dev/null || true)"
  if [ "$existing" != "$PLUGIN_NAME" ]; then
    echo "refusing to replace $dest: not a $PLUGIN_NAME plugin install" >&2
    exit 2
  fi
fi

parent="$(dirname "$dest")"
mkdir -p "$parent"
# Stage in a sibling temp dir so a failed copy never leaves a half-installed plugin.
tmp="$(mktemp -d "$parent/.$PLUGIN_NAME.install.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
for item in .claude-plugin agents bin schemas skills templates README.md; do
  cp -R "$ROOT/$item" "$tmp/"
done

old=""
if [ -e "$dest" ]; then
  old="$parent/.$PLUGIN_NAME.old.$$"
  mv "$dest" "$old"
fi
mv "$tmp" "$dest"
trap - EXIT
if [ -n "$old" ]; then rm -rf "$old"; fi

echo "installed $PLUGIN_NAME to $dest"
echo "It loads as $PLUGIN_NAME@skills-dir in the next session; run /reload-plugins to load it now."
echo "Disable: claude plugin disable $PLUGIN_NAME@skills-dir. Remove: delete the directory."
