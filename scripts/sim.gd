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
	var kills := 0
	var input_dir := Cfg.NONE
	var input_fire := false
	var ack_seq := 0
	var slide_t := 0.0

class Bullet extends RefCounted:
	var id := 0
	var pos := Vector2.ZERO        # centre, px
	var dir := Cfg.Dir.UP
	var owner := 0
	var stars := 0                 # shooter's stars at fire time

const BULLET_STEP := 4.0           # max px per collision sub-step
const BULLET_HIT_RADIUS := 5.0

var map: GameMap
var tanks := {}                    # id -> Tank
var bullets: Array = []
var powerups: Array = []
var tick := 0
var time := 0.0
var rng := RandomNumberGenerator.new()
var _events: Array = []
var _cells: Array = []             # [cx, cy, tile] changes this step
var _next_bullet := 1

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
	t.input_dir = Cfg.NONE
	t.input_fire = false
	t.slide_t = 0.0
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
		if not t.alive:
			t.respawn_t -= dt
			if t.respawn_t <= 0.0:
				_respawn(t)
	for id in ids:
		var t: Tank = tanks[id]
		if t.alive:
			_move_tank(t, dt)
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
		_emit({"k": "cells", "c": _cells})
		_cells = []

func _move_tank(t: Tank, dt: float) -> void:
	var r := TankMotion.step(map, t.pos, t.facing, t.input_dir, t.slide_t, dt)
	var np: Vector2 = r.pos
	var new_rect := Rect2(np, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	var old_rect := tank_rect(t)
	for o in tanks.values():
		if o == t or not o.alive:
			continue
		var orect := tank_rect(o)
		if new_rect.intersects(orect) and not old_rect.intersects(orect):
			np = t.pos  # blocked by another tank (unless already overlapping: allow escape)
			break
	t.pos = np
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
		_resolve_bullets()
		if bullets.is_empty():
			break

func _resolve_bullets() -> void:
	var consumed := {}
	var kills := {}   # victim id -> first killer id
	# 1. tank hits (before bullet-vs-bullet so point-blank trades both land)
	for b in bullets:
		for t in tanks.values():
			if not t.alive or t.id == b.owner:
				continue
			if tank_rect(t).grow(1.0).has_point(b.pos):
				consumed[b] = true
				if t.shield_t <= 0.0 and not kills.has(t.id):
					kills[t.id] = b.owner
				break
	# 2. terrain
	for b in bullets:
		if consumed.has(b):
			continue
		var cx := floori(b.pos.x / Cfg.CELL)
		var cy := floori(b.pos.y / Cfg.CELL)
		var tile := map.bullet_blocked_at(cx, cy)
		if map.bullet_passes(tile):
			continue
		consumed[b] = true
		_bullet_hit_terrain(b, cx, cy)
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
	for vid in kills:
		var v: Tank = tanks.get(vid)
		if v != null and v.alive:
			_kill(v, kills[vid])

# Destroys the 2-cell-wide aligned pair across the bullet's path.
func _bullet_hit_terrain(b: Bullet, cx: int, cy: int) -> void:
	var horizontal := b.dir == Cfg.Dir.LEFT or b.dir == Cfg.Dir.RIGHT
	for k in 2:
		var x := cx if horizontal else (cx - cx % 2 if cx >= 0 else cx) + k
		var y := (cy - cy % 2 if cy >= 0 else cy) + k if horizontal else cy
		var t := map.get_cell(x, y)
		if t == Cfg.Tile.BRICK or (t == Cfg.Tile.STEEL and b.stars >= Cfg.MAX_STARS):
			if map.destroy(x, y, time):
				_cells.append([x, y, Cfg.Tile.EMPTY])
