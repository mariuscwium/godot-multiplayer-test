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

func _me(pos: Vector2, facing := Cfg.Dir.RIGHT) -> Dictionary:
	return {"pos": pos, "facing": facing}

func _enemy(pos: Vector2, alive := true) -> Dictionary:
	return {"pos": pos, "alive": alive}

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r

func test_aligned_enemy_fires_and_faces_it() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [_enemy(Vector2(100, 16))], _rng())
	T.eq(r.fire, true, "fires")
	T.eq(r.dir, Cfg.Dir.RIGHT, "faces the enemy")

func test_aligned_vertically_fires_up() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(64, 80), Cfg.Dir.RIGHT), [_enemy(Vector2(64, 8))], _rng())
	T.eq(r.fire, true, "fires")
	T.eq(r.dir, Cfg.Dir.UP, "faces up")

func test_unaligned_enemy_moves_to_align_without_firing() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [_enemy(Vector2(100, 60))], _rng())
	T.eq(r.dir, Cfg.Dir.DOWN, "reduces the smaller offset first")
	T.eq(r.fire, false, "no shot until aligned")

func test_blocked_by_brick_fires_to_clear() -> void:
	var rows := _open()
	_put(rows, 0, 4, "B")
	_put(rows, 1, 4, "B")
	var r := Bot.decide(_map(rows), _me(Vector2(0, 16), Cfg.Dir.DOWN), [_enemy(Vector2(100, 60))], _rng())
	T.eq(r.dir, Cfg.Dir.DOWN, "keeps heading for the enemy")
	T.eq(r.fire, true, "shoots the brick")

func test_blocked_by_steel_turns_away() -> void:
	var rows := _open()
	_put(rows, 0, 4, "S")
	_put(rows, 1, 4, "S")
	var r := Bot.decide(_map(rows), _me(Vector2(0, 16), Cfg.Dir.DOWN), [_enemy(Vector2(100, 60))], _rng())
	T.ok(r.dir != Cfg.Dir.DOWN, "does not push into steel")
	T.eq(r.fire, false, "no wasted shot")

func test_dead_enemies_are_ignored() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [_enemy(Vector2(100, 16), false)], _rng())
	T.eq(r.fire, false, "nothing to shoot")

func test_picks_nearest_enemy() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(100, 16), Cfg.Dir.RIGHT),
		[_enemy(Vector2(280, 16)), _enemy(Vector2(40, 16))], _rng())
	T.eq(r.dir, Cfg.Dir.LEFT, "turns to the nearer enemy on the left")

func test_no_enemies_wanders() -> void:
	var r := Bot.decide(_map(_open()), _me(Vector2(0, 16)), [], _rng())
	T.ok(r.dir >= -1 and r.dir <= 3, "valid dir")
	T.eq(r.fire, false, "no firing at nothing")

func test_never_outputs_invalid_dir() -> void:
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
		T.ok(r.dir >= -1 and r.dir <= 3, "dir %s out of range" % str(r.dir))
		T.ok(typeof(r.fire) == TYPE_BOOL, "fire is a bool")
