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
	var m := _map(_rows(60, 8, "I"))
	var r := TankMotion.step(m, Vector2(8, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1)
	T.near(r.slide_t, Cfg.ICE_SLIDE_S, 0.0001, "momentum armed on ice")
	var x0: float = r.pos.x
	r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 0.1)
	T.near(r.pos.x - x0, 6.0, 0.01, "first coasting tick is still at full speed")
	var guard := 0
	while r.slide_t > 0.0 and guard < 200:
		r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 1.0 / 30.0)
		guard += 1
	var x1: float = r.pos.x
	r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 0.1)
	T.near(r.pos.x, x1, 0.0001, "stopped once the momentum is spent")

func test_ice_coast_is_long_and_fades() -> void:
	var m := _map(_rows(60, 8, "I"))
	var r := TankMotion.step(m, Vector2(8, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var x0: float = r.pos.x
	var first_tick := 0.0
	var last_tick := 0.0
	var guard := 0
	while r.slide_t > 0.0 and guard < 200:
		var before: float = r.pos.x
		r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 1.0 / 30.0)
		if guard == 0:
			first_tick = r.pos.x - before
		last_tick = r.pos.x - before
		guard += 1
	var dist: float = r.pos.x - x0
	T.ok(dist > 30.0 and dist < 42.0, "coasts about half of speed x time (~36px), got %.1f" % dist)
	T.ok(last_tick < first_tick * 0.2, "speed fades out: first %.2f last %.2f" % [first_tick, last_tick])

func test_holding_a_direction_on_ice_keeps_full_speed() -> void:
	var m := _map(_rows(60, 8, "I"))
	var r := TankMotion.step(m, Vector2(8, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var x0: float = r.pos.x
	for i in 30:
		r = TankMotion.step(m, r.pos, r.facing, Cfg.Dir.RIGHT, r.slide_t, 1.0 / 30.0)
	T.near(r.pos.x - x0, 60.0, 0.5, "a second of driving covers 60px")
	T.near(r.slide_t, Cfg.ICE_SLIDE_S, 0.0001, "momentum stays full while driving")

func test_cannot_turn_or_brake_instantly_on_ice() -> void:
	var m := _map(_rows(60, 12, "I"))
	var r := TankMotion.step(m, Vector2(8, 32), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var y0: float = r.pos.y
	var x0: float = r.pos.x
	r = TankMotion.step(m, r.pos, r.facing, Cfg.Dir.UP, r.slide_t, 1.0 / 30.0)
	T.eq(r.facing, Cfg.Dir.RIGHT, "still heading right the tick after pressing up")
	T.ok(r.pos.x > x0, "keeps sliding right")
	T.near(r.pos.y, y0, 0.0001, "has not started going up")
	var b := TankMotion.step(m, Vector2(8, 32), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var bx: float = b.pos.x
	b = TankMotion.step(m, b.pos, b.facing, Cfg.Dir.LEFT, b.slide_t, 1.0 / 30.0)
	T.ok(b.pos.x > bx, "pressing the opposite way does not brake instantly either")

func test_turn_takes_over_once_momentum_has_faded() -> void:
	var m := _map(_rows(60, 12, "I"))
	var r := TankMotion.step(m, Vector2(8, 32), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var guard := 0
	while r.facing == Cfg.Dir.RIGHT and guard < 120:
		r = TankMotion.step(m, r.pos, r.facing, Cfg.Dir.UP, r.slide_t, 1.0 / 30.0)
		guard += 1
	T.eq(r.facing, Cfg.Dir.UP, "eventually turns")
	var secs := guard / 30.0
	T.ok(secs > 0.3 and secs < 0.7, "after roughly half a second of coasting, took %.2fs" % secs)

func test_turning_is_instant_off_ice() -> void:
	var m := _map(_rows(60, 12))
	var r := TankMotion.step(m, Vector2(8, 32), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	r = TankMotion.step(m, r.pos, r.facing, Cfg.Dir.UP, r.slide_t, 1.0 / 30.0)
	T.eq(r.facing, Cfg.Dir.UP, "normal ground: turns at once")

func test_no_tunnel_large_dt() -> void:
	var rows := _rows(20, 8)
	_put(rows, 4, 2, "S")
	_put(rows, 4, 3, "S")
	var m := _map(rows)
	var p := Vector2(0, 16)
	for i in 30:
		p = TankMotion.step(m, p, Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1).pos
	T.ok(p.x <= 16.0 + 0.01, "never past the 1-cell wall, x=%f" % p.x)

func test_blocker_stops_tank() -> void:
	var m := _map(_rows(20, 8))
	var p := Vector2(0, 16)
	for i in 20:
		p = TankMotion.step(m, p, Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1, [Rect2(24, 16, 16, 16)]).pos
	T.ok(p.x <= 8.01, "stopped by the blocker, x=%f" % p.x)

func test_blocker_already_overlapping_does_not_trap() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(20, 16), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 0.1, [Rect2(24, 16, 16, 16)])
	T.near(r.pos.x, 26.0, 0.01, "may move out of an existing overlap")

func test_hitting_a_wall_on_ice_kills_the_momentum() -> void:
	var rows := _rows(30, 12, "I")
	for y in 12:
		_put(rows, 8, y, "S")
	var m := _map(rows)
	var p := Vector2(0, 32)
	var slide := 0.0
	var facing := Cfg.Dir.RIGHT
	for i in 60:   # drive into the wall
		var r := TankMotion.step(m, p, facing, Cfg.Dir.RIGHT, slide, 1.0 / 30.0)
		p = r.pos
		slide = r.slide_t
	T.near(p.x, 48.0, 0.6, "flush against the wall (px 64)")
	var turned := TankMotion.step(m, p, facing, Cfg.Dir.UP, slide, 1.0 / 30.0)
	T.eq(turned.facing, Cfg.Dir.UP, "can turn away at once: a wall leaves no momentum")

func test_coasting_into_a_wall_kills_the_momentum() -> void:
	var rows := _rows(30, 12, "I")
	for y in 12:
		_put(rows, 8, y, "S")
	var m := _map(rows)
	var r := TankMotion.step(m, Vector2(40, 32), Cfg.Dir.RIGHT, Cfg.Dir.RIGHT, 0.0, 1.0 / 30.0)
	var guard := 0
	while r.slide_t > 0.0 and guard < 100:
		r = TankMotion.step(m, r.pos, r.facing, Cfg.NONE, r.slide_t, 1.0 / 30.0)
		guard += 1
	T.ok(guard / 30.0 < Cfg.ICE_SLIDE_S * 0.8, "the wall stopped it long before the momentum would have faded (%.2fs)" % (guard / 30.0))
	var turned := TankMotion.step(m, r.pos, r.facing, Cfg.Dir.UP, r.slide_t, 1.0 / 30.0)
	T.eq(turned.facing, Cfg.Dir.UP, "turns at once after sliding into the wall")
