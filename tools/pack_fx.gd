extends SceneTree
# Copies effect sheets out of the Super Pixel Effects Gigapack into assets/fx/<kind>.png and prints the
# numbers for Effects.DEFS (frame size, frame count, columns). The pack's licence allows use inside a game
# with attribution but not redistribution of the pack: copy only the sheets the game uses.
# Run: godot --headless --path . -s tools/pack_fx.gd -- [kind ...]     (no kinds = all listed below)

const ROOT := "/mnt/c/Users/wium/Downloads/Super Pixel Effects Gigapack (Free Version) v3.2.0/Super Pixel Effects Gigapack (Free Version)/spritesheet/"
const SHEETS := {
	# kind -> Category/animation/variant
}

func _init() -> void:
	var kinds: Array = Array(OS.get_cmdline_user_args())
	if kinds.is_empty():
		kinds = SHEETS.keys()
	var failed := false
	for kind in kinds:
		if not SHEETS.has(kind):
			printerr("unknown kind: %s" % kind)
			failed = true
			continue
		var dir: String = ROOT + SHEETS[kind].get_base_dir() + "/" + SHEETS[kind].get_file()
		var img := Image.load_from_file(dir + "/spritesheet.png")
		var txt := FileAccess.get_file_as_string(dir + "/spritesheet.txt").strip_edges().split("\n")
		if img == null or txt.size() == 0:
			printerr("cannot read %s" % dir)
			failed = true
			continue
		var first := txt[0].split("=")[1].strip_edges().split(" ")
		var fw := int(first[2])
		var fh := int(first[3])
		var cols := img.get_width() / fw
		var err := img.save_png("res://assets/fx/%s.png" % kind)
		print('"%s": {"path": "res://assets/fx/%s.png", "fw": %d, "fh": %d, "frames": %d, "cols": %d, "fps": 15.0, "size": %d.0, "base_angle": 0.0},  # %s %s' % [kind, kind, fw, fh, txt.size(), cols, fw, SHEETS[kind], error_string(err)])
	quit(1 if failed else 0)
