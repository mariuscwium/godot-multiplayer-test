class_name Sim extends RefCounted
# Authoritative game simulation. No nodes, no networking: stepped at a fixed rate by Server.

class Tank extends RefCounted:
	var id := 0
	var name := ""
	var pos := Vector2.ZERO        # top-left, px
	var facing := Cfg.Dir.UP
	var alive := true
	var respawn_t := 0.0
	var shield_t := 0.0
	var stars := 0
	var hp := Cfg.MAX_HP
	var last_hit := -1000.0        # sim time of the last damage taken
	var heal_t := 0.0              # progress towards the next healed hp
	var kills := 0
	var input_dir := Cfg.NONE
	var input_fire := false
	var ack_seq := 0
	var slide_t := 0.0
	var last_input := 0.0          # sim time of the last accepted input

class Bullet extends RefCounted:
	var id := 0
	var pos := Vector2.ZERO        # centre, px
	var dir := Cfg.Dir.UP
	var owner := 0
	var stars := 0                 # shooter's stars at fire time
	var travelled := 0.0           # px flown since the muzzle

const BULLET_STEP := 4.0           # max px per collision sub-step
const BULLET_HIT_RADIUS := 5.0

var map: GameMap
var tanks := {}                    # id -> Tank
var bullets: Array = []
var powerups: Array = []
var tick := 0
var map_rev := 0                   # number of terrain events emitted; clients use it to detect lost events
var time := 0.0
var rng := RandomNumberGenerator.new()
var _events: Array = []
var _cells: Array = []             # [cx, cy, tile] changes this step
var _next_bullet := 1
var _next_powerup := 1

func _init(map_: GameMap, seed_: int = 0) -> void:
	map = map_
	rng.seed = seed_

static func tank_rect(t: Tank) -> Rect2:
	return Rect2(t.pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))

func add_tank(id: int, name_: String) -> void:
	var t := Tank.new()
	t.id = id
	t.name = name_
	tanks[id] = t
	_respawn(t)

func remove_tank(id: int) -> void:
	tanks.erase(id)

func set_input(id: int, dir: int, fire: bool, seq: int) -> void:
	var t: Tank = tanks.get(id)
	if t == null:
		return
	t.ack_seq = seq
	t.last_input = time
	if not t.alive:
		return
	t.input_dir = dir if dir >= 0 and dir <= 3 else Cfg.NONE
	t.input_fire = fire

func drain_events() -> Array:
	var e := _events
	_events = []
	return e

func _emit(e: Dictionary) -> void:
	_events.append(e)

func _respawn(t: Tank) -> void:
	t.pos = _pick_spawn(t)
	t.facing = Cfg.Dir.UP
	t.alive = true
	t.shield_t = Cfg.SPAWN_SHIELD_S
	t.stars = 0
	t.hp = Cfg.MAX_HP
	t.input_dir = Cfg.NONE
	t.input_fire = false
	t.slide_t = 0.0
	t.last_input = time
	_emit({"k": "spawn", "id": t.id})

# Prefer a spawn not overlapping a living tank, farthest from the nearest one.
func _pick_spawn(self_tank: Tank) -> Vector2:
	var cands: Array = map.spawn_points()
	if cands.is_empty():
		cands = [Vector2(map.w * Cfg.CELL * 0.5 - 8.0, map.h * Cfg.CELL * 0.5 - 8.0)]
	var best := Vector2.ZERO
	var best_free := false
	var best_d := -1.0
	for c in cands:
		var r := Rect2(c, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
		var free := true
		var d := INF
		for t in tanks.values():
			if t == self_tank or not t.alive:
				continue
			if r.intersects(tank_rect(t)):
				free = false
			d = minf(d, c.distance_to(t.pos))
		if best_d < 0.0 or (free and not best_free) or (free == best_free and d > best_d):
			best = c
			best_free = free
			best_d = d
	return best

func _kill(victim: Tank, killer_id: int) -> void:
	victim.alive = false
	victim.respawn_t = Cfg.RESPAWN_S
	victim.stars = 0
	victim.shield_t = 0.0
	victim.input_dir = Cfg.NONE
	victim.input_fire = false
	var k: Tank = tanks.get(killer_id)
	if k != null:
		k.kills += 1
	drop_powerup(victim.pos, rng.randi() % 3)
	_emit({"k": "kill", "killer": killer_id, "victim": victim.id})

func _bullets_of(id: int) -> int:
	var n := 0
	for b in bullets:
		if b.owner == id:
			n += 1
	return n

func step(dt: float) -> void:
	time += dt
	tick += 1
	var ids := tanks.keys()
	ids.sort()
	for id in ids:
		var t: Tank = tanks[id]
		t.shield_t = maxf(0.0, t.shield_t - dt)
		if t.alive and t.hp < Cfg.max_hp_for(t.stars) and time - t.last_hit >= Cfg.HEAL_DELAY_S:
			t.heal_t += dt
			if t.heal_t >= Cfg.HEAL_INTERVAL_S:
				t.hp += 1
				t.heal_t = 0.0
		else:
			t.heal_t = 0.0
		if not t.alive:
			t.respawn_t -= dt
			if t.respawn_t <= 0.0:
				_respawn(t)
	for id in ids:
		var t: Tank = tanks[id]
		if t.alive and time - t.last_input > Cfg.INPUT_TIMEOUT_S:
			t.input_dir = Cfg.NONE   # client went silent (stalled, hidden tab): stop driving and firing
			t.input_fire = false
	for id in ids:
		var t: Tank = tanks[id]
		if t.alive:
			_move_tank(t, dt)
	_update_powerups(dt)
	for id in ids:
		var t: Tank = tanks[id]
		if t.alive and t.input_fire:
			_fire(t)
	_step_bullets(dt)
	var occupied := func(r: Rect2) -> bool:
		for t in tanks.values():
			if t.alive and r.intersects(tank_rect(t)):
				return true
		return false
	for c in map.regrow_due(time, occupied):
		_cells.append(c)
	if not _cells.is_empty():
		map_rev += 1
		_emit({"k": "cells", "c": _cells})
		_cells = []

func _move_tank(t: Tank, dt: float) -> void:
	var blockers := []
	for o in tanks.values():
		if o != t and o.alive:
			blockers.append(tank_rect(o))
	var r := TankMotion.step(map, t.pos, t.facing, t.input_dir, t.slide_t, dt, blockers)
	t.pos = r.pos
	t.facing = r.facing
	t.slide_t = r.slide_t

func _fire(t: Tank) -> void:
	if _bullets_of(t.id) >= (2 if t.stars >= 2 else 1):
		return
	var b := Bullet.new()
	b.id = _next_bullet
	_next_bullet += 1
	b.dir = t.facing
	b.owner = t.id
	b.stars = t.stars
	b.pos = t.pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5 + Cfg.dir_vec(t.facing) * 8.0
	bullets.append(b)

func _step_bullets(dt: float) -> void:
	if bullets.is_empty():
		return
	var longest := 0.0
	for b in bullets:
		longest = maxf(longest, (Cfg.BULLET_SPEED_FAST if b.stars >= 1 else Cfg.BULLET_SPEED) * dt)
	var n := maxi(1, ceili(longest / BULLET_STEP))
	for _i in n:
		for b in bullets:
			var sp := Cfg.BULLET_SPEED_FAST if b.stars >= 1 else Cfg.BULLET_SPEED
			b.pos += Cfg.dir_vec(b.dir) * sp * dt / n
			b.travelled += sp * dt / n
		_resolve_bullets()
		bullets = bullets.filter(func(b): return b.travelled < Cfg.BULLET_RANGE)
		if bullets.is_empty():
			break

func _resolve_bullets() -> void:
	var consumed := {}
	var hits := {}    # victim id -> shooter ids, one per bullet that landed
	# 1. tank hits (before bullet-vs-bullet so point-blank trades both land)
	for b in bullets:
		for t in tanks.values():
			if not t.alive or t.id == b.owner:
				continue
			if tank_rect(t).grow(1.0).has_point(b.pos):
				consumed[b] = true
				if t.shield_t <= 0.0:
					if not hits.has(t.id):
						hits[t.id] = []
					hits[t.id].append(b.owner)
				break
	# 2. terrain: a bullet is as wide as a tank, so it tests the two cells straddling its centreline
	for b in bullets:
		if consumed.has(b):
			continue
		var pair := _bullet_pair(b)
		var blocked := false
		for c in pair:
			if not map.bullet_passes(map.bullet_blocked_at(c.x, c.y)):
				blocked = true
		if blocked:
			consumed[b] = true
			_bullet_hit_terrain(b, pair)
	# 3. bullet vs bullet
	for i in bullets.size():
		var a: Bullet = bullets[i]
		if consumed.has(a):
			continue
		for j in range(i + 1, bullets.size()):
			var c: Bullet = bullets[j]
			if consumed.has(c) or a.owner == c.owner:
				continue
			if a.pos.distance_to(c.pos) < BULLET_HIT_RADIUS:
				consumed[a] = true
				consumed[c] = true
				break
	bullets = bullets.filter(func(b): return not consumed.has(b))
	for vid in hits:
		var v: Tank = tanks.get(vid)
		for shooter in hits[vid]:
			if v == null or not v.alive:
				break
			v.hp -= 1
			v.last_hit = time
			v.heal_t = 0.0
			if v.hp <= 0:
				_kill(v, shooter)

# The two cells across the bullet's path, centred on its centreline.
func _bullet_pair(b: Bullet) -> Array:
	if b.dir == Cfg.Dir.LEFT or b.dir == Cfg.Dir.RIGHT:
		var cx := floori(b.pos.x / Cfg.CELL)
		var first := roundi((b.pos.y - Cfg.CELL) / float(Cfg.CELL))
		return [Vector2i(cx, first), Vector2i(cx, first + 1)]
	var cy := floori(b.pos.y / Cfg.CELL)
	var first := roundi((b.pos.x - Cfg.CELL) / float(Cfg.CELL))
	return [Vector2i(first, cy), Vector2i(first + 1, cy)]

func _bullet_hit_terrain(b: Bullet, pair: Array) -> void:
	for c in pair:
		var t := map.get_cell(c.x, c.y)
		if t == Cfg.Tile.BRICK or (t == Cfg.Tile.STEEL and b.stars >= Cfg.MAX_STARS):
			if map.destroy(c.x, c.y, time):
				_cells.append([c.x, c.y, Cfg.Tile.EMPTY])

func drop_powerup(pos: Vector2, type: int) -> void:
	var snapped := (pos / Cfg.CELL).round() * Cfg.CELL
	powerups.append({"id": _next_powerup, "pos": snapped, "type": type, "ttl": Cfg.POWERUP_TTL})
	_next_powerup += 1

func _update_powerups(dt: float) -> void:
	var keep := []
	for p in powerups:
		p.ttl -= dt
		if p.ttl <= 0.0:
			_emit({"k": "powerup_gone", "id": p.id})
			continue
		var rect := Rect2(p.pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
		var taker: Tank = null
		for t in tanks.values():
			if t.alive and tank_rect(t).intersects(rect):
				taker = t
				break
		if taker == null:
			keep.append(p)
			continue
		_apply_powerup(taker, p.type)
		_emit({"k": "pickup", "id": p.id, "tank": taker.id, "type": p.type})
	powerups = keep

func _apply_powerup(t: Tank, type: int) -> void:
	match type:
		Cfg.PowerType.STAR:
			if t.stars < Cfg.MAX_STARS:
				t.stars += 1
				t.hp += 1   # the new maximum comes with the extra point straight away
		Cfg.PowerType.HELMET:
			t.shield_t = Cfg.HELMET_S
		Cfg.PowerType.GRENADE:
			_grenade(t)

# FFA grenade: wipes bricks and bullets within GRENADE_RADIUS cells; never touches tanks or steel.
func _grenade(t: Tank) -> void:
	var c := t.pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5
	var r := Cfg.GRENADE_CELLS * float(Cfg.CELL)
	for cy in range(floori((c.y - r) / Cfg.CELL), ceili((c.y + r) / Cfg.CELL) + 1):
		for cx in range(floori((c.x - r) / Cfg.CELL), ceili((c.x + r) / Cfg.CELL) + 1):
			if map.get_cell(cx, cy) != Cfg.Tile.BRICK:
				continue
			var cc := Vector2(cx + 0.5, cy + 0.5) * Cfg.CELL
			if cc.distance_to(c) <= r and map.destroy(cx, cy, time):
				_cells.append([cx, cy, Cfg.Tile.EMPTY])
	bullets = bullets.filter(func(b): return b.pos.distance_to(c) > r)
