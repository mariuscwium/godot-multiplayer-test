extends RefCounted

func test_src_rect_quadrants() -> void:
	T.eq(TerrainTiles.src_rect(TerrainTiles.BRICK, 0, 0), Rect2(16, 0, 8, 8), "top-left quarter")
	T.eq(TerrainTiles.src_rect(TerrainTiles.BRICK, 1, 0), Rect2(24, 0, 8, 8), "top-right quarter")
	T.eq(TerrainTiles.src_rect(TerrainTiles.BRICK, 0, 1), Rect2(16, 8, 8, 8), "bottom-left quarter")
	T.eq(TerrainTiles.src_rect(TerrainTiles.BRICK, 3, 5), Rect2(24, 8, 8, 8), "odd/odd is bottom-right")

func test_negative_cells_use_positive_modulo() -> void:
	T.eq(TerrainTiles.src_rect(TerrainTiles.STEEL, -1, -1), TerrainTiles.src_rect(TerrainTiles.STEEL, 1, 1), "-1 is odd")
	T.eq(TerrainTiles.src_rect(TerrainTiles.STEEL, -2, -3), TerrainTiles.src_rect(TerrainTiles.STEEL, 0, 1), "-2 even, -3 odd")

func test_water_frames_cycle() -> void:
	T.eq(TerrainTiles.water_index(0.0), 3, "frame 0")
	T.eq(TerrainTiles.water_index(0.34), 4, "frame 1")
	T.eq(TerrainTiles.water_index(0.67), 3, "back to frame 0: only the two matching wave frames, never the darker third tile")
	T.eq(TerrainTiles.water_index(1.01), 4, "keeps alternating")

func test_index_for() -> void:
	T.eq(TerrainTiles.index_for(Cfg.Tile.EMPTY, 0.0), TerrainTiles.GROUND, "empty is ground")
	T.eq(TerrainTiles.index_for(Cfg.Tile.BRICK, 0.0), TerrainTiles.BRICK, "brick")
	T.eq(TerrainTiles.index_for(Cfg.Tile.STEEL, 0.0), TerrainTiles.STEEL, "steel")
	T.eq(TerrainTiles.index_for(Cfg.Tile.BUSH, 0.0), TerrainTiles.BUSH, "bush")
	T.eq(TerrainTiles.index_for(Cfg.Tile.ICE, 0.0), TerrainTiles.ICE, "ice")
	T.eq(TerrainTiles.index_for(Cfg.Tile.WATER, 0.34), 4, "water follows the clock")
	T.eq(TerrainTiles.index_for(Cfg.Tile.BRICK_DAMAGED, 0.0), TerrainTiles.BRICK_DAMAGED, "damaged brick has its own tile")

func test_terrain_png_is_packed() -> void:
	var tex := load("res://assets/terrain.png") as Texture2D   # needs the import step; same path the game uses
	T.ok(tex != null, "assets/terrain.png loads")
	var img: Image = tex.get_image() if tex else null
	if img == null:
		return
	T.eq(img.get_size(), Vector2i(144, 16), "9 tiles of 16px in one row")
	var opaque := true
	for y in 16:
		for x in 144:
			if img.get_pixel(x, y).a < 1.0:
				opaque = false
	T.ok(opaque, "every pixel opaque")

func test_ground_tile_is_dimmed_sand() -> void:
	var tex := load("res://assets/terrain.png") as Texture2D
	if tex == null:
		T.ok(false, "assets/terrain.png loads")
		return
	var img := tex.get_image()
	var r := 0.0
	var b := 0.0
	var lum := 0.0
	for y in 16:
		for x in 16:
			var p := img.get_pixel(TerrainTiles.GROUND * 16 + x, y)
			r += p.r
			b += p.b
			lum += p.get_luminance()
	r /= 256.0
	b /= 256.0
	lum /= 256.0
	T.ok(r > b + 0.04, "warm (sandy), not navy: r=%.3f b=%.3f" % [r, b])
	T.ok(lum > 0.3 and lum < 0.6, "dimmed sand (the author-approved look measures ~0.51; undimmed sand is ~0.7): luminance %.3f" % lum)

func test_ice_tile_has_no_glass_shine() -> void:
	# the first ice pick was a glass pane with a bright white diagonal highlight; ice should look frosty instead
	var tex := load("res://assets/terrain.png") as Texture2D
	if tex == null:
		T.ok(false, "assets/terrain.png loads")
		return
	var img := tex.get_image()
	var shiny := 0
	for y in 16:
		for x in 16:
			if img.get_pixel(TerrainTiles.ICE * 16 + x, y).get_luminance() > 0.85:
				shiny += 1
	T.ok(shiny < 8, "fewer than 8 near-white pixels in the ice tile, got %d" % shiny)

func test_damaged_brick_tile_is_a_clearly_different_colour() -> void:
	var tex := load("res://assets/terrain.png") as Texture2D
	if tex == null:
		T.ok(false, "assets/terrain.png loads")
		return
	var img := tex.get_image()
	var mean_a := Color(0, 0, 0)
	var mean_b := Color(0, 0, 0)
	for y in 16:
		for x in 16:
			mean_a += img.get_pixel(TerrainTiles.BRICK * 16 + x, y)
			mean_b += img.get_pixel(TerrainTiles.BRICK_DAMAGED * 16 + x, y)
	mean_a /= 256.0
	mean_b /= 256.0
	var d := absf(mean_a.r - mean_b.r) + absf(mean_a.g - mean_b.g) + absf(mean_a.b - mean_b.b)
	T.ok(d > 0.25, "average colour differs noticeably after the first hit, got %.2f" % d)
