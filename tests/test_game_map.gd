extends RefCounted

func _map(t: String) -> GameMap:
	return GameMap.from_text(t)

func test_from_text_dimensions() -> void:
	var m := _map("...\n...")
	T.eq(m.w, 3, "w")
	T.eq(m.h, 2, "h")

func test_edge_is_steel() -> void:
	var m := _map("...\n...")
	T.eq(m.get_cell(-1, 0), Cfg.Tile.STEEL, "left edge")
	T.eq(m.get_cell(3, 0), Cfg.Tile.STEEL, "right edge")
	T.eq(m.get_cell(0, 2), Cfg.Tile.STEEL, "bottom edge")

func test_tank_blocked_by_brick_not_bush() -> void:
	var m := _map("B.G.\n....\n....\n....")
	T.ok(m.tank_blocked(Rect2(0, 0, 16, 16)), "brick at cell 0,0 blocks")
	T.ok(not m.tank_blocked(Rect2(16, 0, 8, 8)), "bush does not block")

func test_water_blocks_tank_not_bullet() -> void:
	var m := _map("W..\n...")
	T.ok(m.tank_blocked(Rect2(0, 0, 8, 8)), "water blocks tank")
	T.eq(m.bullet_blocked_at(0, 0), Cfg.Tile.WATER, "tile reported")
	T.ok(m.bullet_passes(Cfg.Tile.WATER), "bullet passes water")
	T.ok(not m.bullet_passes(Cfg.Tile.BRICK), "bullet stopped by brick")
	T.ok(not m.bullet_passes(Cfg.Tile.STEEL), "bullet stopped by steel")

func test_destroy_brick_then_regrow() -> void:
	var m := _map("B..\n...")
	T.ok(m.destroy(0, 0, 0.0), "destroyed")
	T.eq(m.get_cell(0, 0), Cfg.Tile.EMPTY, "now empty")
	var never := func(_r: Rect2) -> bool: return false
	T.eq(m.regrow_due(29.9, never).size(), 0, "too early")
	var r := m.regrow_due(60.1, never)
	T.eq(r.size(), 1, "one cell regrown")
	T.eq(r[0], [0, 0, Cfg.Tile.BRICK], "cell data")
	T.eq(m.get_cell(0, 0), Cfg.Tile.BRICK, "brick back")

func test_destroy_only_brick_and_steel() -> void:
	var m := _map("G.")
	T.ok(not m.destroy(0, 0, 0.0), "bush not destroyable")
	T.eq(m.get_cell(0, 0), Cfg.Tile.BUSH, "bush intact")

func test_regrow_waits_for_occupant() -> void:
	var m := _map("B..\n...")
	m.destroy(0, 0, 0.0)
	var occupied := func(_r: Rect2) -> bool: return true
	T.eq(m.regrow_due(100.0, occupied).size(), 0, "occupied: stays pending")
	T.eq(m.get_cell(0, 0), Cfg.Tile.EMPTY, "still empty")
	var free := func(_r: Rect2) -> bool: return false
	T.eq(m.regrow_due(101.0, free).size(), 1, "regrows once clear")

func test_spawn_points_are_top_left_of_P_cell() -> void:
	var m := _map("...\n.P.\n...")
	T.eq(m.spawn_points(), [Vector2(8, 8)], "P at cell 1,1")

func test_bytes_roundtrip() -> void:
	var m := _map("B.S\nGWI")
	var m2 := GameMap.from_bytes(m.w, m.h, m.to_bytes())
	for y in 2:
		for x in 3:
			T.eq(m2.get_cell(x, y), m.get_cell(x, y), "cell %d,%d" % [x, y])

func test_arena_loads() -> void:
	var m := GameMap.from_text(FileAccess.get_file_as_string("res://maps/arena.txt"))
	T.eq(m.w, Cfg.MAP_W, "arena w")
	T.eq(m.h, Cfg.MAP_H, "arena h")
	var sp := m.spawn_points()
	T.ok(sp.size() >= 20, "at least 20 spawns, got %d" % sp.size())
	for p in sp:
		T.ok(not m.tank_blocked(Rect2(p, Vector2(16, 16))), "spawn %s free" % str(p))

func test_arena_is_built_from_2x2_blocks() -> void:
	# the level is designed on a 40x40 grid of blocks; each block is 2x2 cells (a spawn marks its top-left cell)
	var lines := FileAccess.get_file_as_string("res://maps/arena.txt").strip_edges().split("\n")
	T.eq(lines.size(), 80, "80 cell rows")
	var bad := 0
	for by in 40:
		for bx in 40:
			var tl: String = lines[by * 2][bx * 2]
			if tl == "P":
				tl = "."
			for dy in 2:
				for dx in 2:
					var c: String = lines[by * 2 + dy][bx * 2 + dx]
					if c == "P":
						c = "."
					if c != tl:
						bad += 1
	T.eq(bad, 0, "every 2x2 cell group is one block type")

func test_arena_has_24_spawns_and_is_connected() -> void:
	var m := GameMap.from_text(FileAccess.get_file_as_string("res://maps/arena.txt"))
	T.eq(m.spawn_points().size(), 24, "24 spawn points")
	# flood fill over cells a tank can stand on if it were to pass bricks (steel and water are permanent)
	var start: Vector2 = m.spawn_points()[0]
	var seen := {}
	var stack := [Vector2i(int(start.x / Cfg.CELL), int(start.y / Cfg.CELL))]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c):
			continue
		var t := m.get_cell(c.x, c.y)
		if t == Cfg.Tile.STEEL or t == Cfg.Tile.WATER:
			continue
		seen[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	for p in m.spawn_points():
		T.ok(seen.has(Vector2i(int(p.x / Cfg.CELL), int(p.y / Cfg.CELL))), "spawn %s reachable from spawn 0" % str(p))

func test_damaged_brick_blocks_tank_and_bullets() -> void:
	var m := _map("...\n...")
	m.set_cell(0, 0, Cfg.Tile.BRICK_DAMAGED)
	T.ok(m.tank_blocked(Rect2(0, 0, 8, 8)), "blocks tanks")
	T.ok(not m.bullet_passes(Cfg.Tile.BRICK_DAMAGED), "stops bullets")

func test_destroying_a_damaged_brick_regrows_a_full_brick() -> void:
	var m := _map("...\n...")
	m.set_cell(0, 0, Cfg.Tile.BRICK_DAMAGED)
	T.ok(m.destroy(0, 0, 0.0), "destroyed")
	T.eq(m.get_cell(0, 0), Cfg.Tile.EMPTY, "gone")
	var r := m.regrow_due(60.1, func(_r: Rect2) -> bool: return false)
	T.eq(r, [[0, 0, Cfg.Tile.BRICK]], "comes back as a full-strength brick")
