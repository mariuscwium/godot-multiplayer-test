extends RefCounted

func _map(rows: Array) -> GameMap:
	return GameMap.from_text("\n".join(rows))

func _open(w := 30, h := 12) -> Array:
	var rows := []
	for y in h:
		rows.append(".".repeat(w))
	return rows

func _put(rows: Array, cx: int, cy: int, c: String) -> void:
	rows[cy] = rows[cy].substr(0, cx) + c + rows[cy].substr(cx + 1)

func _me(pos: Vector2, dir := Cfg.Dir.RIGHT) -> Dictionary:
	return {"pos": pos, "facing": Cfg.heading(dir)}

func _enemy(pos: Vector2, alive := true) -> Dictionary:
	return {"pos": pos, "alive": alive}

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r

const FWD := 8   # Cfg.drive(1, 1)

func test_aimed_enemy_in_range_fires_and_drives_on() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [_enemy(Vector2(100, 16))], _rng())
	T.eq(r.fire, true, "fires")
	T.eq(r.drive, FWD, "drives at it")

func test_aimed_enemy_out_of_range_does_not_fire() -> void:
	var r := Bot.decide(_map(_open(60)), _me(Vector2(0, 16)), [_enemy(Vector2(400, 16))], _rng())
	T.eq(r.fire, false, "too far")

func test_enemy_behind_makes_it_spin() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(100, 16), Cfg.Dir.RIGHT), [_enemy(Vector2(20, 16))], _rng())
	T.eq(r.fire, false, "no shot while facing away")
	T.ok(r.drive == Cfg.drive(1, -1) or r.drive == Cfg.drive(-1, 1), "spins on the spot")

func test_enemy_clockwise_of_us_spins_clockwise() -> void:
	# facing up, enemy to the right
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 60), Cfg.Dir.UP), [_enemy(Vector2(100, 60))], _rng())
	T.eq(r.drive, Cfg.drive(1, -1), "left track forward, right back = clockwise")

func test_enemy_anticlockwise_of_us_spins_anticlockwise() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(100, 60), Cfg.Dir.UP), [_enemy(Vector2(0, 60))], _rng())
	T.eq(r.drive, Cfg.drive(-1, 1), "right track forward, left back = anticlockwise")

func test_slightly_off_arcs_towards_the_enemy() -> void:
	# a bit clockwise of dead ahead: arc right (left track only) while closing in
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 80), Cfg.Dir.UP), [_enemy(Vector2(20, 0))], _rng())
	T.eq(r.drive, Cfg.drive(1, 0), "arcs clockwise")
	T.eq(r.fire, false, "no shot until lined up")

func test_blocked_by_brick_fires_to_clear() -> void:
	var rows := _open()
	_put(rows, 0, 4, "B")
	_put(rows, 1, 4, "B")
	var r := Bot.decide(_map(rows), _me(Vector2(0, 16), Cfg.Dir.DOWN), [_enemy(Vector2(0, 200))], _rng())
	T.eq(r.fire, true, "shoots the brick")

func test_blocked_by_steel_turns_away() -> void:
	var rows := _open()
	_put(rows, 0, 4, "S")
	_put(rows, 1, 4, "S")
	var r := Bot.decide(_map(rows), _me(Vector2(0, 16), Cfg.Dir.DOWN), [_enemy(Vector2(0, 200))], _rng())
	T.ok(r.drive == Cfg.drive(1, -1) or r.drive == Cfg.drive(-1, 1), "spins instead of pushing into steel")
	T.eq(r.fire, false, "no wasted shot")

func test_dead_enemies_are_ignored() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [_enemy(Vector2(100, 16), false)], _rng())
	T.eq(r.fire, false, "nothing to shoot")

func test_picks_nearest_enemy() -> void:
	var r := Bot.decide(_map(_open(40)), _me(Vector2(100, 60), Cfg.Dir.UP),
		[_enemy(Vector2(280, 60)), _enemy(Vector2(40, 60))], _rng())
	T.eq(r.drive, Cfg.drive(-1, 1), "turns anticlockwise to the nearer enemy on the left")

func test_no_enemies_wanders() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [], _rng())
	T.ok(r.drive >= 0 and r.drive <= 8, "valid drive code")
	T.eq(r.fire, false, "no firing at nothing")

func test_never_outputs_invalid_drive() -> void:
	var rows := _open(20, 20)
	for i in 30:
		_put(rows, i % 20, (i * 7) % 20, "BSWG.I"[i % 6])
	var m := _map(rows)
	var rng := _rng()
	for i in 1000:
		var others := []
		for k in rng.randi_range(0, 3):
			others.append(_enemy(Vector2(rng.randf_range(0, 150), rng.randf_range(0, 150)), rng.randf() < 0.8))
		var r := Bot.decide(m, _me(Vector2(rng.randf_range(0, 140), rng.randf_range(0, 140)), rng.randi_range(0, 3)), others, rng)
		T.ok(r.drive >= 0 and r.drive <= 8, "drive %s out of range" % str(r.drive))
		T.ok(typeof(r.fire) == TYPE_BOOL, "fire is a bool")

func test_damaged_brick_ahead_is_shot_too() -> void:
	var m := _map(_open())
	m.set_cell(0, 4, Cfg.Tile.BRICK_DAMAGED)
	m.set_cell(1, 4, Cfg.Tile.BRICK_DAMAGED)
	var r := Bot.decide(m, _me(Vector2(0, 16), Cfg.Dir.DOWN), [_enemy(Vector2(0, 200))], _rng())
	T.eq(r.fire, true, "shoots the damaged brick")
