extends RefCounted

const FWD := 8       # Cfg.drive(1, 1)
const DT := 1.0 / 30.0

func _rows(w: int, h: int, fill := ".") -> Array:
	var rows := []
	for y in h:
		rows.append(fill.repeat(w))
	return rows

func _map(rows: Array) -> GameMap:
	return GameMap.from_text("\n".join(rows))

func _put(rows: Array, cx: int, cy: int, c: String) -> void:
	rows[cy] = rows[cy].substr(0, cx) + c + rows[cy].substr(cx + 1)

# Run a drive code for secs; returns {pos, facing, slide_t}.
func _run(m: GameMap, pos: Vector2, heading: float, drive: int, secs: float, slide := 0.0) -> Dictionary:
	var r := {"pos": pos, "facing": heading, "slide_t": slide}
	for i in roundi(secs / DT):
		r = TankMotion.step(m, r.pos, r.facing, drive, r.slide_t, DT)
	return r

func test_both_tracks_forward_drives_straight() -> void:
	var m := _map(_rows(40, 20))
	var r := _run(m, Vector2(8, 40), Cfg.heading(Cfg.Dir.RIGHT), FWD, 1.0)
	T.near(r.pos.x, 68.0, 0.01, "60 px in a second")
	T.near(r.pos.y, 40.0, 0.01, "no sideways drift")
	T.near(r.facing, PI / 2.0, 0.0001, "heading unchanged")

func test_both_tracks_back_reverses() -> void:
	var m := _map(_rows(40, 20))
	var r := _run(m, Vector2(100, 40), Cfg.heading(Cfg.Dir.RIGHT), Cfg.drive(-1, -1), 0.5)
	T.near(r.pos.x, 70.0, 0.01, "backed up 30 px")
	T.near(r.facing, PI / 2.0, 0.0001, "heading unchanged")

func test_idle_does_not_move() -> void:
	var m := _map(_rows(20, 8))
	var r := TankMotion.step(m, Vector2(10, 16), 1.0, Cfg.STOP, 0.0, 0.1)
	T.eq(r.pos, Vector2(10, 16), "no movement without input")
	T.eq(r.facing, 1.0, "no turning without input")

func test_left_track_only_turns_clockwise() -> void:
	var m := _map(_rows(60, 40))
	var r := _run(m, Vector2(100, 100), 0.0, Cfg.drive(1, 0), 0.5)
	T.ok(r.facing > 0.5 and r.facing < PI, "heading swung clockwise, got %f" % r.facing)
	T.ok(r.pos.x > 100.0, "and the tank curved to the right")

func test_right_track_only_turns_anticlockwise() -> void:
	var m := _map(_rows(60, 40))
	var r := _run(m, Vector2(100, 100), 0.0, Cfg.drive(0, 1), 0.5)
	T.ok(r.facing > PI and r.facing < TAU - 0.5, "heading swung anticlockwise, got %f" % r.facing)
	T.ok(r.pos.x < 100.0, "and the tank curved to the left")

func test_one_track_circles_about_the_idle_track() -> void:
	var m := _map(_rows(60, 40))
	var start := Vector2(100, 100)
	var centre := start + Vector2(8, 8)
	# the idle (right) track sits TRACK_GAP / 2 to the right of the centre when facing up
	var pivot := centre + Vector2(Cfg.TRACK_GAP * 0.5, 0)
	var r := _run(m, start, 0.0, Cfg.drive(1, 0), 1.0)
	var c: Vector2 = r.pos + Vector2(8, 8)
	T.near(c.distance_to(pivot), Cfg.TRACK_GAP * 0.5, 0.5, "stays on a circle round the idle track")

func test_opposite_tracks_spin_on_the_spot() -> void:
	var m := _map(_rows(40, 20))
	var r := _run(m, Vector2(100, 40), 0.0, Cfg.drive(1, -1), 0.5)
	T.near(r.pos.x, 100.0, 0.001, "x unchanged")
	T.near(r.pos.y, 40.0, 0.001, "y unchanged")
	T.near(r.facing, 2.0 * Cfg.TANK_SPEED / Cfg.TRACK_GAP * 0.5, 0.01, "turned by omega * t")

func test_heading_wraps_into_0_tau() -> void:
	var m := _map(_rows(40, 20))
	var r := _run(m, Vector2(100, 40), 0.1, Cfg.drive(-1, 1), 0.2)
	T.ok(r.facing >= 0.0 and r.facing < TAU, "wrapped: %f" % r.facing)

func test_stops_flush_at_brick() -> void:
	var rows := _rows(20, 8)
	for y in 8:
		_put(rows, 6, y, "B")
	var m := _map(rows)
	var r := _run(m, Vector2(0, 16), Cfg.heading(Cfg.Dir.RIGHT), FWD, 2.0)
	T.near(r.pos.x, 48.0 - 15.0, 0.1, "flush against the brick at px 48 (1 px hitbox inset)")
	T.ok(not m.tank_blocked(Rect2(r.pos + Vector2(1, 1), Vector2(14, 14))), "not inside the brick")

func test_slides_along_a_wall_when_driving_diagonally() -> void:
	var rows := _rows(20, 12)
	for y in 12:
		_put(rows, 10, y, "S")
	var m := _map(rows)
	var heading := PI / 4.0 + PI / 2.0 * 0.0   # up and to the right
	var r := _run(m, Vector2(40, 60), heading, FWD, 1.0)
	T.near(r.pos.x, 80.0 - 15.0, 0.1, "x stopped at the wall")
	T.ok(r.pos.y < 50.0, "kept moving up along it, y=%f" % r.pos.y)

func test_fits_through_a_two_cell_gap_at_any_offset() -> void:
	var rows := _rows(20, 8)
	for x in range(4, 20):
		for y in [0, 1, 4, 5, 6, 7]:
			_put(rows, x, y, "B")
	var m := _map(rows)
	# gap rows 2-3 (px 16..32): driving right a little off true still gets in thanks to the hitbox inset
	var r := _run(m, Vector2(8, 16.6), Cfg.heading(Cfg.Dir.RIGHT), FWD, 0.5)
	T.near(r.pos.x, 38.0, 0.01, "travelled 30 px along the gap")

func test_turning_is_never_blocked_by_walls() -> void:
	var rows := _rows(20, 8)
	for y in 8:
		_put(rows, 6, y, "B")
	var m := _map(rows)
	var r := TankMotion.step(m, Vector2(31, 16), Cfg.heading(Cfg.Dir.RIGHT), Cfg.drive(1, -1), 0.0, 0.1)
	T.ok(r.facing != Cfg.heading(Cfg.Dir.RIGHT), "still rotates against a wall")

func test_other_tank_blocks_moving_but_not_turning() -> void:
	var m := _map(_rows(40, 8))
	var other := Rect2(Vector2(24, 16), Vector2(16, 16))
	var r := TankMotion.step(m, Vector2(7, 16), Cfg.heading(Cfg.Dir.RIGHT), FWD, 0.0, 0.1, [other])
	T.eq(r.pos, Vector2(7, 16), "move refused")
	r = TankMotion.step(m, Vector2(7, 16), Cfg.heading(Cfg.Dir.RIGHT), Cfg.drive(1, -1), 0.0, 0.1, [other])
	T.ok(r.facing != Cfg.heading(Cfg.Dir.RIGHT), "spin allowed")

func test_existing_overlap_does_not_trap() -> void:
	var m := _map(_rows(40, 8))
	var other := Rect2(Vector2(10, 16), Vector2(16, 16))
	var r := TankMotion.step(m, Vector2(8, 16), Cfg.heading(Cfg.Dir.LEFT), FWD, 0.0, 0.1, [other])
	T.ok(r.pos.x < 8.0, "can drive away from an overlapping tank")

func test_ice_keeps_coasting_when_released() -> void:
	var rows := _rows(60, 8)
	for x in range(0, 60):
		for y in range(0, 8):
			_put(rows, x, y, "I")
	var m := _map(rows)
	var r := _run(m, Vector2(8, 16), Cfg.heading(Cfg.Dir.RIGHT), FWD, 0.3)
	T.ok(r.slide_t > 0.0, "momentum while driving on ice")
	var x0: float = r.pos.x
	r = _run(m, r.pos, r.facing, Cfg.STOP, 0.5, r.slide_t)
	T.ok(r.pos.x > x0 + 5.0, "coasted on after release, moved %f" % (r.pos.x - x0))
	r = _run(m, r.pos, r.facing, Cfg.STOP, 2.0, r.slide_t)
	T.eq(r.slide_t, 0.0, "momentum fades out")

func test_ice_momentum_is_signed_when_reversing() -> void:
	var rows := _rows(60, 8)
	for x in range(0, 60):
		for y in range(0, 8):
			_put(rows, x, y, "I")
	var m := _map(rows)
	var r := _run(m, Vector2(100, 16), Cfg.heading(Cfg.Dir.RIGHT), Cfg.drive(-1, -1), 0.2)
	T.ok(r.slide_t < 0.0, "backward momentum is negative")
	var x0: float = r.pos.x
	r = _run(m, r.pos, r.facing, Cfg.STOP, 0.3, r.slide_t)
	T.ok(r.pos.x < x0, "keeps coasting backwards")

func test_wall_stops_an_ice_slide_dead() -> void:
	var rows := _rows(20, 8)
	for x in range(0, 20):
		for y in range(0, 8):
			_put(rows, x, y, "I")
	for y in 8:
		_put(rows, 8, y, "B")
	var m := _map(rows)
	var r := _run(m, Vector2(20, 16), Cfg.heading(Cfg.Dir.RIGHT), Cfg.STOP, 1.0, Cfg.ICE_SLIDE_S)
	T.eq(r.slide_t, 0.0, "momentum cleared on impact")
