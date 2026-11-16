extends RefCounted

func _rows(w: int, h: int, fill := ".") -> Array:
	var rows := []
	for y in h:
		rows.append(fill.repeat(w))
	return rows

func _map(rows: Array) -> GameMap:
	return GameMap.from_text("\n".join(rows))

func _put(rows: Array, cx: int, cy: int, c: String) -> void:
	rows[cy] = rows[cy].substr(0, cx) + c + rows[cy].substr(cx + 1)

func test_moves_right_in_open() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(0, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.5)
	T.near(r.pos.x, 30.0, 0.01, "x after 0.5s")
	T.near(r.pos.y, 16.0, 0.01, "y unchanged")
	T.eq(r.facing, Cfg.Dir.RIGHT, "facing")

func test_idle_does_not_move() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(10, 16), Cfg.Dir.RIGHT, Cfg.NONE, 0.0, 0.1)
	T.eq(r.pos, Vector2(10, 16), "no movement without input")

func test_stops_flush_at_brick() -> void:
	var rows := _rows(20, 8)
	for y in 8:
		_put(rows, 6, y, "B")
	var m := _map(rows)
	var p := Vector2(0, 16)
	for i in 20:
		p = TankMotion.step(m, p, Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1).pos
	T.near(p.x, 32.0, 0.5, "flush against brick at px 48")
	T.ok(not m.tank_blocked(Rect2(p, Vector2(16, 16))), "not inside the brick")

func test_turn_snaps_to_8px() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(40, 13), Cfg.Dir.UP, Cfg.Dir.RIGHT, 0.0, 0.01)
	T.near(r.pos.y, 16.0, 0.001, "13 rounds to 16")
	r = TankMotion.step(m, Vector2(40, 21), Cfg.Dir.UP, Cfg.Dir.RIGHT, 0.0, 0.01)
	T.near(r.pos.y, 24.0, 0.001, "21 rounds to 24")
	r = TankMotion.step(m, Vector2(13, 40), Cfg.Dir.LEFT, Cfg.Dir.DOWN, 0.0, 0.01)
	T.near(r.pos.x, 16.0, 0.001, "x snaps when turning to vertical")

func test_no_snap_when_continuing_same_axis() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(40, 13), Cfg.Dir.RIGHT, Cfg.Dir.LEFT, 0.0, 0.01)
	T.near(r.pos.y, 13.0, 0.001, "reversing along the same axis keeps y")

func test_snapped_tank_enters_two_cell_gap() -> void:
	var rows := _rows(20, 8)
	for x in range(4, 20):
		for y in [0, 1, 4, 5, 6, 7]:
			_put(rows, x, y, "B")
	var m := _map(rows)
	var r := TankMotion.step(m, Vector2(8, 17), Cfg.Dir.UP, Cfg.Dir.RIGHT, 0.0, 0.5)
	T.near(r.pos.y, 16.0, 0.001, "snapped into the gap row")
	T.near(r.pos.x, 38.0, 0.01, "travelled 30px along the gap")

func test_ice_slides_after_release() -> void:
	var rows := _rows(20, 8, "I")
	var m := _map(rows)
	var r := TankMotion.step(m, Vector2(8, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1)
	T.near(r.slide_t, Cfg.ICE_SLIDE_S, 0.0001, "slide armed on ice")
	var x0: float = r.pos.x
	r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 0.1)
	T.near(r.pos.x - x0, 6.0, 0.01, "slides 6px")
	r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 0.2)
	T.near(r.slide_t, 0.0, 0.0001, "slide spent")
	var x1: float = r.pos.x
	r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 0.1)
	T.near(r.pos.x, x1, 0.0001, "stopped")

func test_no_tunnel_large_dt() -> void:
	var rows := _rows(20, 8)
	_put(rows, 4, 2, "S")
	_put(rows, 4, 3, "S")
	var m := _map(rows)
	var p := Vector2(0, 16)
	for i in 30:
		p = TankMotion.step(m, p, Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1).pos
	T.ok(p.x <= 16.0 + 0.01, "never past the 1-cell wall, x=%f" % p.x)
