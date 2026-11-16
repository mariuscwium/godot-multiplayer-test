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

func _tank(sim: Sim, id: int, pos: Vector2, facing: int) -> Sim.Tank:
	sim.add_tank(id, "t%d" % id)
	var t: Sim.Tank = sim.tanks[id]
	t.pos = pos
	t.facing = facing
	t.shield_t = 0.0
	return t

func test_kill_drops_powerup_at_victim() -> void:
	var rows := _rows(20, 8)
	_put(rows, 1, 6, "P")
	var s := _sim(rows)
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	_tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	s.set_input(1, Cfg.NONE, true, 1)
	s.step(1.0 / 30)
	s.set_input(1, Cfg.NONE, false, 2)
	_run(s, 0.5)
	T.eq(s.powerups.size(), 1, "one drop")
	T.eq(s.powerups[0].pos, Vector2(64, 16), "at the victim's spot, grid aligned")
	T.near(s.powerups[0].ttl, Cfg.POWERUP_TTL, 0.6, "fresh ttl")

func test_powerup_expires_after_10s() -> void:
	var s := _sim(_rows(20, 8))
	s.drop_powerup(Vector2(120, 16), Cfg.PowerType.STAR)
	_run(s, 9.5)
	T.eq(s.powerups.size(), 1, "still there at 9.5s")
	_run(s, 1.0)
	T.eq(s.powerups.size(), 0, "gone after 10s")
	var gone := s.drain_events().filter(func(e): return e.k == "powerup_gone")
	T.eq(gone.size(), 1, "expiry reported")

func test_pickup_star_caps_at_3() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.stars = 2
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 3, "third star")
	T.eq(s.powerups.size(), 0, "consumed")
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 3, "capped")
	T.eq(s.powerups.size(), 0, "still consumed")
	var picks := s.drain_events().filter(func(e): return e.k == "pickup")
	T.eq(picks.size(), 2, "two pickup events")
	T.eq(picks[0].tank, 1, "who")

func test_pickup_helmet_sets_shield() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	s.drop_powerup(Vector2(24, 16), Cfg.PowerType.HELMET)
	s.step(1.0 / 30)
	T.near(t.shield_t, Cfg.HELMET_S, 0.1, "helmet shield")

func test_grenade_clears_nearby_brick_and_bullets_not_tanks() -> void:
	var rows := _rows(60, 10)
	_put(rows, 3, 2, "B")      # near
	_put(rows, 5, 3, "B")      # near
	_put(rows, 4, 1, "S")      # steel survives
	_put(rows, 40, 2, "B")     # far
	var s := _sim(rows)
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var e := _tank(s, 2, Vector2(40, 40), Cfg.Dir.LEFT)
	var near_b := Sim.Bullet.new()
	near_b.pos = Vector2(30, 60)
	near_b.dir = Cfg.Dir.UP
	near_b.owner = 2
	var far_b := Sim.Bullet.new()
	far_b.pos = Vector2(400, 60)
	far_b.dir = Cfg.Dir.UP
	far_b.owner = 2
	s.bullets = [near_b, far_b]
	s.drop_powerup(Vector2(0, 16), Cfg.PowerType.GRENADE)
	s.step(1.0 / 30)
	T.eq(s.map.get_cell(3, 2), Cfg.Tile.EMPTY, "near brick gone")
	T.eq(s.map.get_cell(5, 3), Cfg.Tile.EMPTY, "near brick gone 2")
	T.eq(s.map.get_cell(4, 1), Cfg.Tile.STEEL, "steel stays")
	T.eq(s.map.get_cell(40, 2), Cfg.Tile.BRICK, "far brick stays")
	T.eq(s.bullets, [far_b], "only the far bullet remains")
	T.ok(e.alive, "grenade never hurts tanks")
	var cells := s.drain_events().filter(func(ev): return ev.k == "cells")
	T.ok(cells.size() >= 1, "terrain change reported")

func test_death_resets_stars() -> void:
	var rows := _rows(20, 8)
	_put(rows, 1, 6, "P")
	var s := _sim(rows)
	_tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	var b := _tank(s, 2, Vector2(64, 16), Cfg.Dir.LEFT)
	b.stars = 2
	s.set_input(1, Cfg.NONE, true, 1)
	_run(s, 0.5)
	T.ok(not b.alive, "victim dead")
	T.eq(b.stars, 0, "stars reset on death")

func test_dead_tank_cannot_pickup() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.alive = false
	t.respawn_t = 100.0
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 0, "no pickup while dead")
	T.eq(s.powerups.size(), 1, "still on the ground")
