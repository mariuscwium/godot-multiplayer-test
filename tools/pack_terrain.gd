extends SceneTree
# Cuts the picked 16x16 tiles out of the "Textures" atlas by piiixl (https://piiixl.itch.io/textures,
# file textures_02_08_25.png, 24x26 tiles) into assets/terrain.png, one row in the order TerrainTiles
# expects. Licence: free for use in games, no resale/redistribution as-is: commit only the packed
# tiles, never the pack.
# Run: godot --headless --path . -s tools/pack_terrain.gd -- /path/to/textures_02_08_25.png
# Picks are (column, row) in the atlas's 16 px grid.

const PICKS := [
	Vector2i(8, 4),    # ground: sand, dimmed below
	Vector2i(13, 2),   # brick
	Vector2i(15, 3),   # steel
	Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 6),   # water frames (the game alternates the first two)
	Vector2i(10, 6),   # ice: pale blue chevrons (the first pick (8,8) was a glass pane; (9,6) is a busier teal alternative)
	Vector2i(18, 12),  # bush
	Vector2i(10, 2),   # damaged brick: dark maroon, so a wall hit once visibly changes colour ((18,2) dusty, (16,3) cracked are alternatives)
]
const GROUND_DIM := 0.35                       # how far the ground is pulled toward dark navy
const GROUND_DARK := Color(0.08, 0.08, 0.14)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s tools/pack_terrain.gd -- <textures_02_08_25.png>")
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
	for y in 16:
		for x in 16:
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, c.lerp(GROUND_DARK, GROUND_DIM))
	var err := out.save_png("res://assets/terrain.png")
	print("wrote assets/terrain.png (%d tiles): %s" % [PICKS.size(), error_string(err)])
	quit(0 if err == OK else 1)
