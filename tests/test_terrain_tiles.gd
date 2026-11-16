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

func test_terrain_png_is_packed() -> void:
	var tex := load("res://assets/terrain.png") as Texture2D   # needs the import step; same path the game uses
	T.ok(tex != null, "assets/terrain.png loads")
	var img: Image = tex.get_image() if tex else null
	if img == null:
		return
	T.eq(img.get_size(), Vector2i(128, 16), "8 tiles of 16px in one row")
	var opaque := true
	for y in 16:
		for x in 128:
			if img.get_pixel(x, y).a < 1.0:
				opaque = false
	T.ok(opaque, "every pixel opaque")
