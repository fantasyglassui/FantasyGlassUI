#!/usr/bin/env bash
# Checks the version a release or a beta is about to be cut from.
#   release-version.sh <release|beta> [dir]      (dir defaults to the current folder)
# Reads "## Version:" of FantasyGlassUI/FantasyGlassUI.toc and checks it against the kind's rule
# (release: 13.5.0, beta: 13.5.0-beta.1), then checks the other four TOCs and Core.lua say the same.
# Prints the version and exits 0, or prints what is wrong and exits 1.
set -eu

kind="${1:-}"
dir="${2:-.}"
case "$kind" in
  release) rule='^[0-9]+\.[0-9]+\.[0-9]+$' ;;
  beta) rule='^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$' ;;
  *) echo "usage: release-version.sh <release|beta> [dir]" >&2; exit 2 ;;
esac

version=$(grep -m1 '^## Version:' "$dir/FantasyGlassUI/FantasyGlassUI.toc" | sed 's/^## Version: *//' | tr -d '\r')
if ! echo "$version" | grep -Eq "$rule"; then echo "not a $kind version: $version"; exit 1; fi
for f in FantasyGlassUI_Options/FantasyGlassUI_Options.toc FantasyGlassUI_Locales/FantasyGlassUI_Locales.toc FantasyGlassUI_Planner/FantasyGlassUI_Planner.toc FantasyGlassUI_Gold/FantasyGlassUI_Gold.toc; do
  tr -d '\r' < "$dir/$f" | grep -qxF "## Version: $version" || { echo "$f does not say $version"; exit 1; }
done
grep -qF "ns.version = \"$version\"" "$dir/FantasyGlassUI/Core.lua" || { echo "Core.lua does not say $version"; exit 1; }
echo "$version"
