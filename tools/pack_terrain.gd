extends SceneTree
# Cuts the picked 16x16 tiles out of the Textures atlas by piiixl (https://piiixl.itch.io/textures;
# free for use in games, no resale/redistribution as-is: commit only the packed tiles, never the pack)
# into assets/terrain.png, one row in the order TerrainTiles expects.
# Run: godot --headless --path . -s tools/pack_terrain.gd -- /path/to/Textures-16.png
# Picks are (column, row) in the atlas's 16 px grid.

const PICKS := [
	Vector2i(0, 10),   # ground
	Vector2i(3, 3),    # brick
	Vector2i(8, 4),    # steel
	Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8),   # water frames
	Vector2i(3, 11),   # ice
	Vector2i(2, 16),   # bush
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s tools/pack_terrain.gd -- <Textures-16.png>")
		quit(1)
		return
	var atlas := Image.load_from_file(args[0])
	if atlas == null:
		printerr("cannot read atlas: %s" % args[0])
		quit(1)
		return
	atlas.convert(Image.FORMAT_RGBA8)
	var out := Image.create(PICKS.size() * 16, 16, false, Image.FORMAT_RGBA8)
	for i in PICKS.size():
		var p: Vector2i = PICKS[i]
		var src := Rect2i(p.x * 16, p.y * 16, 16, 16)
		if not Rect2i(Vector2i.ZERO, atlas.get_size()).encloses(src):
			printerr("pick %s is outside the atlas" % str(p))
			quit(1)
			return
		out.blit_rect(atlas, src, Vector2i(i * 16, 0))
	var err := out.save_png("res://assets/terrain.png")
	print("wrote assets/terrain.png (%d tiles): %s" % [PICKS.size(), error_string(err)])
	quit(0 if err == OK else 1)
