extends RefCounted

func _open() -> GameMap:
	return GameMap.from_text("\n".join(range(8).map(func(_i): return ".".repeat(20))))

func test_drops_acked_inputs() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.Dir.RIGHT, 0.0,
		[[1, Cfg.Dir.RIGHT], [2, Cfg.Dir.RIGHT], [3, Cfg.Dir.RIGHT]], 2)
	T.eq(r.pending, [[3, Cfg.Dir.RIGHT]], "only seq 3 remains")

func test_replays_unacked_from_server_pos() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.Dir.RIGHT, 0.0,
		[[1, Cfg.Dir.RIGHT], [2, Cfg.Dir.RIGHT], [3, Cfg.Dir.RIGHT]], 0)
	T.near(r.pos.x, 26.0, 0.01, "3 ticks x 2px")
	T.near(r.pos.y, 16.0, 0.01, "y unchanged")
	T.eq(r.pending.size(), 3, "all still pending")

func test_empty_pending_returns_server_pos() -> void:
	var r := Client.reconcile(_open(), Vector2(33.5, 17.25), Cfg.Dir.UP, 0.0, [], 9)
	T.eq(r.pos, Vector2(33.5, 17.25), "server position untouched")
	T.eq(r.facing, Cfg.Dir.UP, "facing kept")

func test_replay_respects_walls() -> void:
	var rows := range(8).map(func(_i): return ".".repeat(20))
	for y in 8:
		rows[y] = rows[y].substr(0, 6) + "B" + rows[y].substr(7)
	var m := GameMap.from_text("\n".join(rows))
	var r := Client.reconcile(m, Vector2(31, 16), Cfg.Dir.RIGHT, 0.0,
		[[1, Cfg.Dir.RIGHT], [2, Cfg.Dir.RIGHT], [3, Cfg.Dir.RIGHT]], 0)
	T.near(r.pos.x, 32.0, 0.05, "prediction stops flush at the brick (px 48)")

func test_replay_updates_facing() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.Dir.UP, 0.0, [[1, Cfg.Dir.RIGHT]], 0)
	T.eq(r.facing, Cfg.Dir.RIGHT, "facing follows replayed input")
