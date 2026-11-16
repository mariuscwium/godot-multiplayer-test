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
	t.hp = 1   # these tests are about other things: one hit kills
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
	_put(rows, 3, 2, ".")      # near: set to damaged brick below
	_put(rows, 5, 3, "B")      # near
	_put(rows, 4, 1, "S")      # steel survives
	_put(rows, 40, 2, "B")     # far
	var s := _sim(rows)
	s.map.set_cell(3, 2, Cfg.Tile.BRICK_DAMAGED)
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
	T.eq(s.map.get_cell(3, 2), Cfg.Tile.EMPTY, "near damaged brick gone too")
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

func test_star_pickup_raises_max_hp_and_heals_one() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.hp = 3
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 1, "star")
	T.eq(t.hp, 4, "full health tank gets the extra point at once")
	t.hp = 2
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 2, "second star")
	T.eq(t.hp, 3, "a damaged tank also gains one point (2 -> 3 of 5)")

func test_star_at_max_stars_gives_no_hp() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.stars = 3
	t.hp = Cfg.max_hp_for(3)
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.step(1.0 / 30)
	T.eq(t.stars, 3, "capped")
	T.eq(t.hp, 6, "no further hp")
	T.eq(s.powerups.size(), 0, "still consumed")

func _fx_events(s: Sim, kind: String) -> Array:
	return s.drain_events().filter(func(e): return e.k == "fx" and e.fx == kind)

func test_star_pickup_emits_its_effect() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.drain_events()
	s.step(1.0 / 30)
	var fx := _fx_events(s, "pickup_star")
	T.eq(fx.size(), 1, "one effect")
	T.eq(fx[0].pos, t.pos + Vector2(8, 8), "on the tank that took it")

func test_star_pickup_at_max_stars_still_shows_its_effect() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.stars = 3
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.drain_events()
	s.step(1.0 / 30)
	T.eq(_fx_events(s, "pickup_star").size(), 1, "the pickup happened, so it shows")

func test_helmet_pickup_emits_its_effect() -> void:
	var s := _sim(_rows(20, 8))
	_tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.HELMET)
	s.drain_events()
	s.step(1.0 / 30)
	T.eq(_fx_events(s, "pickup_helmet").size(), 1, "shield burst")

func test_grenade_emits_a_blast() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.GRENADE)
	s.drain_events()
	s.step(1.0 / 30)
	var fx := _fx_events(s, "blast")
	T.eq(fx.size(), 1, "one blast")
	T.eq(fx[0].pos, t.pos + Vector2(8, 8), "centred on the tank that took it")

func test_dead_tanks_trigger_no_pickup_effect() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(16, 16), Cfg.Dir.RIGHT)
	t.alive = false
	t.respawn_t = 100.0
	s.drop_powerup(Vector2(16, 16), Cfg.PowerType.STAR)
	s.drain_events()
	s.step(1.0 / 30)
	T.eq(_fx_events(s, "pickup_star").size(), 0, "nothing was picked up")

func test_heal_tick_emits_a_heart_effect_per_healed_point() -> void:
	var s := _sim(_rows(20, 8))
	var t := _tank(s, 1, Vector2(0, 16), Cfg.Dir.RIGHT)
	t.hp = 1
	t.last_hit = s.time
	s.drain_events()
	var hearts := 0
	for i in int((Cfg.HEAL_DELAY_S + 3.0 * Cfg.HEAL_INTERVAL_S) * Cfg.TICK_HZ):
		s.set_input(1, Cfg.NONE, false, i + 1)
		s.step(1.0 / Cfg.TICK_HZ)
		hearts += s.drain_events().filter(func(e): return e.k == "fx" and e.fx == "heal").size()
	T.eq(t.hp, 3, "healed to full")
	T.eq(hearts, 2, "one heart effect for each of the two healed points, none at full health")

func test_drop_emits_a_sparkle_where_the_powerup_lands() -> void:
	var s := _sim(_rows(20, 8))
	s.drop_powerup(Vector2(64, 16), Cfg.PowerType.STAR)
	var fx := _fx_events(s, "drop_sparkle")
	T.eq(fx.size(), 1, "one sparkle")
	T.eq(fx[0].pos, Vector2(72, 24), "at the centre of the power-up")
