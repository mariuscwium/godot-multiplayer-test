#!/usr/bin/env bash
# Publish build/web/ to the gh-pages branch (GitHub Pages) via a temporary worktree.
# Without --push it only commits locally; with --push it also pushes origin gh-pages.
# Run tools/export_web.sh first. Then in repo Settings > Pages choose branch gh-pages, / (root).
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f build/web/index.html ] || { echo "No build/web/index.html: run tools/export_web.sh first" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'git worktree remove --force "$tmp" 2>/dev/null || true' EXIT
if git show-ref --verify --quiet refs/heads/gh-pages; then
	git worktree add "$tmp" gh-pages >/dev/null
else
	git worktree add --detach "$tmp" >/dev/null
	git -C "$tmp" checkout --orphan gh-pages >/dev/null 2>&1
	git -C "$tmp" rm -rf . >/dev/null 2>&1 || true
fi
find "$tmp" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r build/web/. "$tmp"/
touch "$tmp/.nojekyll"
git -C "$tmp" add -A
if git -C "$tmp" diff --cached --quiet; then
	echo "gh-pages already up to date"
else
	git -C "$tmp" commit -qm "Publish web build"
	echo "committed to local gh-pages"
fi
if [ "${1:-}" = "--push" ]; then
	git push origin gh-pages
else
	echo "Not pushed. To publish: tools/publish_pages.sh --push"
fi
