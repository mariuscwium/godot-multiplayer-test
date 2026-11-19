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
# Returns {pos, facing (the new heading), trk (the two track speeds, see _step_map)}.
static func step(map: GameMap, pos: Vector2, heading: float, drive: int, trk: Vector2, dt: float, blockers: Array = []) -> Dictionary:
	var r := _step_map(map, pos, heading, drive, trk, dt)
	if blockers.is_empty():
		return r
	var old := Rect2(pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	var moved := Rect2(r.pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	for b in blockers:
		if moved.intersects(b) and not old.intersects(b):
			r.pos = pos
			break
	return r

static func _step_map(map: GameMap, pos: Vector2, heading: float, drive: int, trk: Vector2, dt: float) -> Dictionary:
	# trk = current speed of the left/right track in -1..1. It chases the driven target, so the tank has weight.
	var target := Vector2(Cfg.drive_left(drive), Cfg.drive_right(drive))
	if target == Vector2.ZERO and trk == Vector2.ZERO:
		return {"pos": pos, "facing": heading, "trk": trk}
	var grip := Cfg.ICE_GRIP if _on_ice(map, pos) else 1.0
	trk = Vector2(_chase(trk.x, target.x, dt * grip), _chase(trk.y, target.y, dt * grip))
	var v := (trk.x + trk.y) * 0.5 * Cfg.TANK_SPEED            # px/s along the heading
	var w := (trk.x - trk.y) * Cfg.TANK_SPEED / Cfg.TRACK_GAP  # rad/s, clockwise when the left track is faster
	var mid := heading + w * dt * 0.5
	var np := _slide(map, pos, Cfg.heading_vec(mid) * v * dt)
	if v != 0.0 and np.distance_to(pos) < 0.001:
		trk = Vector2.ZERO   # hit a wall: stop dead
	return {"pos": np, "facing": wrapf(heading + w * dt, 0.0, TAU), "trk": trk}

# Move a track speed toward its target: gentle when speeding up in its direction, firmer when braking/reversing.
static func _chase(cur: float, target: float, dt: float) -> float:
	var speeding := absf(target) > absf(cur) and signf(target) == signf(cur) or cur == 0.0
	return move_toward(cur, target, (Cfg.TRACK_ACCEL if speeding else Cfg.TRACK_BRAKE) * dt)
