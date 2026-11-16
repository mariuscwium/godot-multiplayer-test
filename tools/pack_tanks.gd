extends SceneTree
# Cuts assets/source/tank-sprite-sheet.png (4 tiers x 2 tread frames on magenta, 256 px cells)
# into assets/tanks.png: 128x64, tier t frame f at (t*32, f*32). One common scale for all eight tanks
# so the biggest (heavy tier) fills the cell and smaller tiers are proportionally smaller.
# Run: godot --headless --path . -s tools/pack_tanks.gd -- assets/source/tank-sprite-sheet.png

const CELL := 32
const FIT := 30.0      # longer side of the biggest tank in px; leaves a 1 px margin
const GAIN := 1.35     # brightness gain so multiply-tinting by player colour does not look dark

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s tools/pack_tanks.gd -- <tank-sprite-sheet.png>")
		quit(1)
		return
	var sheet := Image.load_from_file(args[0])
	if sheet == null or sheet.get_size() != Vector2i(1024, 512):
		printerr("expected a 1024x512 sheet, got %s" % (str(sheet.get_size()) if sheet else "nothing"))
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			var p := sheet.get_pixel(x, y)
			if p.r > 0.9 and p.b > 0.9 and p.g < 0.25:
				sheet.set_pixel(x, y, Color(0, 0, 0, 0))
	sheet.fix_alpha_edges()   # keep keyed edges from darkening when we resample
	var tanks := []
	var biggest := 0
	for r in 2:
		for c in 4:
			var cell := sheet.get_region(Rect2i(c * 256, r * 256, 256, 256))
			var used := cell.get_used_rect()
			if used.size == Vector2i.ZERO:
				printerr("cell r%d c%d is empty" % [r, c])
				quit(1)
				return
			tanks.append({"r": r, "c": c, "img": cell.get_region(used)})
			biggest = maxi(biggest, maxi(used.size.x, used.size.y))
	var k := FIT / biggest
	var out := Image.create(CELL * 4, CELL * 2, false, Image.FORMAT_RGBA8)
	for t in tanks:
		var img: Image = t.img
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(p.r * GAIN, 1.0), minf(p.g * GAIN, 1.0), minf(p.b * GAIN, 1.0), p.a))
		var at := Vector2i(t.c * CELL + (CELL - img.get_width()) / 2, t.r * CELL + (CELL - img.get_height()) / 2)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	var err := out.save_png("res://assets/tanks.png")
	print("wrote assets/tanks.png (scale %.3f): %s" % [k, error_string(err)])
	quit(0 if err == OK else 1)
