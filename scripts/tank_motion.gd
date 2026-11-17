class_name TankMotion extends RefCounted
# Pure movement step shared by the server Sim and client-side prediction.
# Differential drive: each track runs forward, back or idle (Cfg.drive). Both forward drives straight ahead,
# one forward and one idle circles about the idle track, opposite tracks spin on the spot.
# pos is the tank's top-left in px; heading is radians (0 = up, clockwise), see Cfg.heading_vec.

static func _on_ice(map: GameMap, pos: Vector2) -> bool:
	var c := pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5
	return map.get_cell(floori(c.x / Cfg.CELL), floori(c.y / Cfg.CELL)) == Cfg.Tile.ICE

# Terrain hitbox: the tank square shrunk a little, and it does not rotate with the sprite.
static func _free(map: GameMap, p: Vector2) -> bool:
	var i := Cfg.HIT_INSET
	return not map.tank_blocked(Rect2(p + Vector2(i, i), Vector2(Cfg.TANK_PX - 2.0 * i, Cfg.TANK_PX - 2.0 * i)))

# Move along an axis dir by up to dist px, stopping flush against blockers.
static func _advance(map: GameMap, pos: Vector2, dir: int, dist: float) -> Vector2:
	var v := Cfg.dir_vec(dir)
	var left := dist
	while left > 0.0:
		var s := minf(1.0, left)
		var np := pos + v * s
		if _free(map, np):
			pos = np
			left -= s
			continue
		# blocked: bisect for the flush position within this sub-step
		var lo := 0.0
		var hi := s
		for _i in 6:
			var mid := (lo + hi) * 0.5
			if _free(map, pos + v * mid):
				lo = mid
			else:
				hi = mid
		return pos + v * lo
	return pos

# Move by d, x then y, so a tank pushing diagonally into a wall slides along it.
static func _slide(map: GameMap, pos: Vector2, d: Vector2) -> Vector2:
	if d.x != 0.0:
		pos = _advance(map, pos, Cfg.Dir.RIGHT if d.x > 0.0 else Cfg.Dir.LEFT, absf(d.x))
	if d.y != 0.0:
		pos = _advance(map, pos, Cfg.Dir.DOWN if d.y > 0.0 else Cfg.Dir.UP, absf(d.y))
	return pos

# blockers: rects of other tanks. A move that newly overlaps one is refused (the tank can still turn); an
# existing overlap (e.g. a tank spawned on top of another) never traps you.
# Returns {pos, facing (the new heading), slide_t}. slide_t is ice momentum: signed, + forward, - backward.
static func step(map: GameMap, pos: Vector2, heading: float, drive: int, slide_t: float, dt: float, blockers: Array = []) -> Dictionary:
	var r := _step_map(map, pos, heading, drive, slide_t, dt)
	if blockers.is_empty():
		return r
	var old := Rect2(pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	var moved := Rect2(r.pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	for b in blockers:
		if moved.intersects(b) and not old.intersects(b):
			r.pos = pos
			break
	return r

static func _step_map(map: GameMap, pos: Vector2, heading: float, drive: int, slide_t: float, dt: float) -> Dictionary:
	var l := Cfg.drive_left(drive)
	var r := Cfg.drive_right(drive)
	var v := (l + r) * 0.5 * Cfg.TANK_SPEED               # px/s along the heading
	var w := (l - r) * Cfg.TANK_SPEED / Cfg.TRACK_GAP     # rad/s, clockwise when the left track is faster
	var coasting := l == 0 and r == 0 and slide_t != 0.0
	if l == 0 and r == 0 and not coasting:
		return {"pos": pos, "facing": heading, "slide_t": 0.0}
	if coasting:   # ice: carry on straight with fading speed
		v = signf(slide_t) * Cfg.TANK_SPEED * clampf(absf(slide_t) / Cfg.ICE_SLIDE_S, 0.0, 1.0)
	var mid := heading + w * dt * 0.5
	var np := _slide(map, pos, Cfg.heading_vec(mid) * v * dt)
	var moved := np.distance_to(pos) > 0.001
	if coasting:
		slide_t = signf(slide_t) * maxf(0.0, absf(slide_t) - dt) if moved else 0.0   # a wall stops you dead
	else:
		slide_t = signf(v) * Cfg.ICE_SLIDE_S if v != 0.0 and moved and _on_ice(map, np) else 0.0
	return {"pos": np, "facing": wrapf(heading + w * dt, 0.0, TAU), "slide_t": slide_t}
