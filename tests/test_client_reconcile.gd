extends RefCounted

const CRUISE := Vector2(1, 1)   # tracks already at full speed

func _open() -> GameMap:
	return GameMap.from_text("\n".join(range(8).map(func(_i): return ".".repeat(20))))

func test_drops_acked_inputs() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.heading(Cfg.Dir.RIGHT), CRUISE,
		[[1, Cfg.drive(1, 1)], [2, Cfg.drive(1, 1)], [3, Cfg.drive(1, 1)]], 2)
	T.eq(r.pending, [[3, Cfg.drive(1, 1)]], "only seq 3 remains")

func test_replays_unacked_from_server_pos() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.heading(Cfg.Dir.RIGHT), CRUISE,
		[[1, Cfg.drive(1, 1)], [2, Cfg.drive(1, 1)], [3, Cfg.drive(1, 1)]], 0)
	T.near(r.pos.x, 26.0, 0.01, "3 ticks x 2px")
	T.near(r.pos.y, 16.0, 0.01, "y unchanged")
	T.eq(r.pending.size(), 3, "all still pending")

func test_empty_pending_returns_server_pos() -> void:
	var r := Client.reconcile(_open(), Vector2(33.5, 17.25), Cfg.heading(Cfg.Dir.UP), Vector2.ZERO, [], 9)
	T.eq(r.pos, Vector2(33.5, 17.25), "server position untouched")
	T.eq(r.facing, 0.0, "facing kept")

func test_replay_respects_walls() -> void:
	var rows := range(8).map(func(_i): return ".".repeat(20))
	for y in 8:
		rows[y] = rows[y].substr(0, 6) + "B" + rows[y].substr(7)
	var m := GameMap.from_text("\n".join(rows))
	var r := Client.reconcile(m, Vector2(31, 16), Cfg.heading(Cfg.Dir.RIGHT), CRUISE,
		[[1, Cfg.drive(1, 1)], [2, Cfg.drive(1, 1)], [3, Cfg.drive(1, 1)]], 0)
	T.near(r.pos.x, 33.0, 0.05, "prediction stops flush at the brick (px 48, 1 px hitbox inset)")

func test_replay_updates_facing() -> void:
	var r := Client.reconcile(_open(), Vector2(20, 16), 0.0, Vector2.ZERO, [[1, Cfg.drive(1, -1)]], 0)
	T.ok(r.facing > 0.0, "heading follows the replayed spin")

func test_replay_respects_blockers() -> void:
	var blockers := [Rect2(40, 16, 16, 16)]
	var r := Client.reconcile(_open(), Vector2(20, 16), Cfg.heading(Cfg.Dir.RIGHT), CRUISE,
		[[1, Cfg.drive(1, 1)], [2, Cfg.drive(1, 1)], [3, Cfg.drive(1, 1)], [4, Cfg.drive(1, 1)], [5, Cfg.drive(1, 1)],
		[6, Cfg.drive(1, 1)], [7, Cfg.drive(1, 1)], [8, Cfg.drive(1, 1)], [9, Cfg.drive(1, 1)], [10, Cfg.drive(1, 1)]], 0, blockers)
	T.ok(r.pos.x <= 24.01, "prediction does not walk through another tank, x=%f" % r.pos.x)

func test_in_sync() -> void:
	T.ok(Client.in_sync(4, 4, {1: "a", 2: "b"}, [1, 2]), "same revision, known tanks")
	T.ok(not Client.in_sync(3, 4, {1: "a"}, [1]), "missed a terrain event")
	T.ok(not Client.in_sync(4, 4, {1: "a"}, [1, 2]), "tank missing from the roster")
