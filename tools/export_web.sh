#!/usr/bin/env bash
# Export the single-threaded Web build to build/web/ (no COOP/COEP headers needed, so GitHub Pages works).
# Creates export_presets.cfg if missing (it is gitignored). Needs the Web export templates:
#   python3 -I tools/install_web_templates.py
G=${GODOT:-$HOME/godot-bin/Godot_v4.7.2-stable_linux.x86_64}
cd "$(dirname "$0")/.." || exit 1
TPL=$HOME/.local/share/godot/export_templates/4.7.2.stable/web_nothreads_release.zip
if [ ! -f "$TPL" ]; then
	echo "Missing Web export templates ($TPL). Install them with: python3 -I tools/install_web_templates.py" >&2
	exit 1
fi
if [ ! -f export_presets.cfg ]; then
	cat > export_presets.cfg <<'CFG'
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="maps/*"
exclude_filter="tests/*, docs/*, tools/*, .superpowers/*, Dockerfile, README.md"
export_path="build/web/index.html"

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
CFG
fi
mkdir -p build/web
"$G" --headless --path . --import >/dev/null 2>&1
"$G" --headless --path . --export-release Web build/web/index.html 2>&1 | grep -vE "^(Godot Engine|$)"
test -f build/web/index.html && ls -la build/web && echo "OK: build/web/index.html" || { echo "export failed" >&2; exit 1; }
