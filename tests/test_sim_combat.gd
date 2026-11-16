extends RefCounted

func _rows(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		rows.append(".".repeat(w))
	return rows

func _put(rows: Array, cx: int, cy: int, c: String) -> void:
	rows[cy] = rows[cy].substr(0, cx) + c + rows[cy].substr(cx + 1)

func _sim(rows: Array) -> Sim:
	return Sim.new(GameMap.from_text("\n".join(rows)))

func _run(sim: Sim, secs: float) -> void:
	for i in int(secs * Cfg.TICK_HZ):
		sim.step(1.0 / Cfg.TICK_HZ)

# add a tank at an exact spot, shield off, for deterministic combat tests
func _tank(sim: Sim, id: int, pos: Vector2, facing: int) -> Sim.Tank:
	sim.add_tank(id, "t%d" % id)
	var t: Sim.Tank = sim.tanks[id]
	t.pos = pos
	t.facing = facing
	t.shield_t = 0.0
	return t

func _rects_overlap(a: Sim.Tank, b: Sim.Tank) -> bool:
	return Rect2(a.pos, Vector2(16, 16)).intersects(Rect2(b.pos, Vector2(16, 16)))

func test_add_tank_spawns_free_of_others() -> void:
	var rows := _rows(30, 14)
	_put(rows, 1, 1, "P")
	_put(rows, 14, 1, "P")
	_put(rows, 1, 10, "P")
	var s := _sim(rows)
	for id in [1, 2, 3]:
		s.add_tank(id, "p%d" % id)
	T.ok(not _rects_overlap(s.tanks[1], s.tanks[2]), "1/2 apart")
	T.ok(not _rects_overlap(s.tanks[1], s.tanks[3]), "1/3 apart")
	T.ok(not _rects_overlap(s.tanks[2], s.tanks[3]), "2/3 apart")
	T.ok(s.tanks[1].alive and s.tanks[1].shield_t > 0.0, "alive with shield")

func test_new_tank_picks_spawn_farthest_from_others() -> void:
	var rows := _rows(30, 6)
	_put(rows, 1, 1, "P")
	_put(rows, 5, 1, "P")
	_put(rows, 27, 1, "P")
	var s := _sim(rows)
	s.add_tank(1, "a")
	s.add_tank(2, "b")
	s.add_tank(3, "c")
	T.eq(s.tanks[1].pos, Vector2(8, 8), "first takes the first spawn")
	T.eq(s.tanks[2].pos, Vector2(216, 8), "second goes far away")
	T.eq(s.tanks[3].pos, Vector2(40, 8), "third takes the remaining free spawn")

func test_spawn_when_all_spawns_occupied_does_not_crash() -> void:
	var rows := _rows(10, 6)
	_put(rows, 1, 1, "P")
	var s := _sim(rows)
	s.add_tank(1, "a")
	s.add_tank(2, "b")
	T.ok(s.tanks[2].alive, "second tank still spawns")
	_run(s, 0.5)
	T.ok(s.tanks.has(1) and s.tanks.has(2), "both survive stepping")

func test_tanks_block_each_other() -> void:
	var s := _sim(_rows(20, 8))
	var a := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	_tank(s, 2, Vector2(24, 16), Cfg.Dir.RIGHT)
	s.set_input(1, Cfg.Dir.RIGHT, false, 1)
	_run(s, 1.0)
	T.ok(a.pos.x <= 8.01, "stopped by the other tank, x=%f" % a.pos.x)

func test_fire_creates_one_bullet_limit() -> void:
	var s := _sim(_rows(40, 8))
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.step(1.0 / 30)
	T.eq(s.bullets.size(), 1, "second shot refused while one is in flight")

func test_two_stars_allow_two_bullets() -> void:
	var s := _sim(_rows(60, 8))
	var t := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	t.stars = 2
	s.set_input(1, Cfg.NONE, true, 1)
	for i in 4:
		s.step(1.0 / 30)
	T.eq(s.bullets.size(), 2, "two in flight with 2 stars")

func test_bullet_kills_tank_and_credits_killer() -> void:
	var s := _sim(_rows(20, 8))
	var a := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	_run(s, 1.0)
	T.ok(not b.alive, "victim dead")
	T.eq(a.kills, 1, "killer credited")
	var kills := s.drain_events().filter(func(e): return e.k == "kill")
	T.eq(kills.size(), 1, "one kill event")
	T.eq(kills[0].killer, 1, "killer id")
	T.eq(kills[0].victim, 2, "victim id")

func test_shield_absorbs_bullet() -> void:
	var s := _sim(_rows(20, 8))
	var a := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	b.shield_t = 5.0
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	_run(s, 1.0)
	T.ok(b.alive, "shielded tank survives")
	T.eq(a.kills, 0, "no credit")
	T.eq(s.bullets.size(), 0, "bullet consumed")

func test_mutual_kill_same_tick() -> void:
	var s := _sim(_rows(20, 8))
	var a := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(16, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.set_input(2, Cfg.NONE, true, 1)
	_run(s, 0.2)
	T.ok(not a.alive and not b.alive, "both dead")
	T.eq(a.kills, 1, "a credited")
	T.eq(b.kills, 1, "b credited")

func test_brick_destroyed_two_cells_wide() -> void:
	var rows := _rows(20, 8)
	for y in [1, 2, 3, 4]:
		_put(rows, 8, y, "B")
	var s := _sim(rows)
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	_run(s, 1.0)
	T.eq(s.map.get_cell(8, 2), Cfg.Tile.EMPTY, "row 2 destroyed")
	T.eq(s.map.get_cell(8, 3), Cfg.Tile.EMPTY, "row 3 destroyed")
	T.eq(s.map.get_cell(8, 1), Cfg.Tile.BRICK, "row 1 intact")
	T.eq(s.map.get_cell(8, 4), Cfg.Tile.BRICK, "row 4 intact")
	T.eq(s.bullets.size(), 0, "bullet consumed")
	var cells := s.drain_events().filter(func(e): return e.k == "cells")
	T.ok(cells.size() >= 1, "terrain change reported")

func test_steel_needs_three_stars() -> void:
	var rows := _rows(20, 8)
	_put(rows, 8, 2, "S")
	_put(rows, 8, 3, "S")
	var s := _sim(rows)
	var t := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	_run(s, 1.0)
	T.eq(s.map.get_cell(8, 2), Cfg.Tile.STEEL, "plain shot bounces off steel")
	T.eq(s.bullets.size(), 0, "bullet consumed")
	t.stars = 3
	s.set_input(1, Cfg.NONE, true, 3)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 4)
	_run(s, 1.0)
	T.eq(s.map.get_cell(8, 2), Cfg.Tile.EMPTY, "3-star shot breaks steel")
	T.eq(s.map.get_cell(8, 3), Cfg.Tile.EMPTY, "both cells")

func test_bullets_cancel() -> void:
	var s := _sim(_rows(30, 8))
	var a := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(160, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.set_input(2, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	s.set_input(2, Cfg.NONE, false, 2)
	_run(s, 1.5)
	T.eq(s.bullets.size(), 0, "both bullets gone")
	T.ok(a.alive and b.alive, "nobody hit")

func test_respawn_after_2s_with_shield() -> void:
	var rows := _rows(20, 8)
	_put(rows, 10, 5, "P")
	var s := _sim(rows)
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	_run(s, 0.5)
	T.ok(not b.alive, "dead after the hit")
	_run(s, 1.0)
	T.ok(not b.alive, "still dead before 2s have passed")
	_run(s, 1.0)
	T.ok(b.alive, "respawned")
	T.ok(b.shield_t > 1.0, "respawn shield active")
	T.eq(b.stars, 0, "stars reset")

func test_remove_tank_keeps_its_bullets_flying() -> void:
	var s := _sim(_rows(20, 8))
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.remove_tank(1)
	_run(s, 1.0)
	T.ok(not b.alive, "bullet from a departed player still resolves")
	T.ok(not s.tanks.has(1), "no ghost tank")

func test_set_input_rejects_bad_dir() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	s.set_input(1, 7, false, 5)
	T.eq(t.input_dir, Cfg.NONE, "dir 7 becomes NONE")
	T.eq(t.ack_seq, 5, "seq still acked")
	s.set_input(99, 1, false, 1)
	T.ok(not s.tanks.has(99), "unknown id ignored")
