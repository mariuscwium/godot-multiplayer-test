class_name TankMotion extends RefCounted
# Pure movement step shared by the server Sim and client-side prediction.
# pos is the tank's top-left in px. Directions are Cfg.Dir or Cfg.NONE.

static func _horizontal(d: int) -> bool:
	return d == Cfg.Dir.LEFT or d == Cfg.Dir.RIGHT

static func _on_ice(map: GameMap, pos: Vector2) -> bool:
	var c := pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5
	return map.get_cell(floori(c.x / Cfg.CELL), floori(c.y / Cfg.CELL)) == Cfg.Tile.ICE

static func _free(map: GameMap, p: Vector2) -> bool:
	return not map.tank_blocked(Rect2(p, Vector2(Cfg.TANK_PX, Cfg.TANK_PX)))

# Move along dir by up to dist px, stopping flush against blockers.
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

# blockers: rects of other tanks. A move that newly overlaps one is refused; an existing overlap
# (e.g. a tank spawned on top of another) never traps you.
static func step(map: GameMap, pos: Vector2, facing: int, input_dir: int, slide_t: float, dt: float, blockers: Array = []) -> Dictionary:
	var r := _step_map(map, pos, facing, input_dir, slide_t, dt)
	if blockers.is_empty():
		return r
	var old := Rect2(pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	var moved := Rect2(r.pos, Vector2(Cfg.TANK_PX, Cfg.TANK_PX))
	for b in blockers:
		if moved.intersects(b) and not old.intersects(b):
			r.pos = pos
			break
	return r

static func _step_map(map: GameMap, pos: Vector2, facing: int, input_dir: int, slide_t: float, dt: float) -> Dictionary:
	# Ice: momentum (slide_t) carries the tank on in its old direction with fading speed, and a new
	# direction (turn or brake) only takes over once the momentum has faded below ICE_TURN_FRAC.
	var sliding := slide_t > 0.0
	var steering_locked := sliding and input_dir != Cfg.NONE and input_dir != facing \
		and slide_t > Cfg.ICE_SLIDE_S * Cfg.ICE_TURN_FRAC
	if input_dir == Cfg.NONE or steering_locked:
		if sliding:
			var frac := clampf(slide_t / Cfg.ICE_SLIDE_S, 0.0, 1.0)
			var moved := _advance(map, pos, facing, Cfg.TANK_SPEED * frac * dt)
			slide_t = 0.0 if moved.distance_to(pos) < 0.001 else maxf(0.0, slide_t - dt)   # a wall stops you dead
			pos = moved
		return {"pos": pos, "facing": facing, "slide_t": slide_t}
	if _horizontal(input_dir) != _horizontal(facing):
		# turning onto the other axis: snap the cross coordinate to the 8px grid
		var snapped := pos
		if _horizontal(input_dir):
			snapped.y = roundf(pos.y / Cfg.CELL) * Cfg.CELL
		else:
			snapped.x = roundf(pos.x / Cfg.CELL) * Cfg.CELL
		if _free(map, snapped):
			pos = snapped
	var driven := _advance(map, pos, input_dir, Cfg.TANK_SPEED * dt)
	var blocked := driven.distance_to(pos) < 0.001
	pos = driven
	slide_t = Cfg.ICE_SLIDE_S if _on_ice(map, pos) and not blocked else 0.0
	return {"pos": pos, "facing": input_dir, "slide_t": slide_t}
