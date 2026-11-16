class_name Bot extends RefCounted
# Test opponent: line up with the nearest living enemy and shoot; shoot bricks that are in the way.
# Pure function of (map, me, others, rng) so it is unit-testable; Client adds reaction jitter.

const ALIGN := 8.0     # px of cross-axis offset that still counts as lined up
const RANGE := 200.0   # px at which it will shoot
const BRICK := 1
const HARD := 2

static func decide(map: GameMap, me: Dictionary, others: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos: Vector2 = me.pos
	var target = null
	var best := INF
	for o in others:
		if o.alive and pos.distance_to(o.pos) < best:
			best = pos.distance_to(o.pos)
			target = o
	var dir: int
	var fire := false
	if target == null:
		dir = int(me.facing) if rng.randf() > 0.05 else rng.randi_range(0, 3)
	else:
		var d: Vector2 = target.pos - pos
		var ax := absf(d.x)
		var ay := absf(d.y)
		if ay < ALIGN and ax <= RANGE:
			dir = Cfg.Dir.RIGHT if d.x > 0.0 else Cfg.Dir.LEFT
			fire = true
		elif ax < ALIGN and ay <= RANGE:
			dir = Cfg.Dir.DOWN if d.y > 0.0 else Cfg.Dir.UP
			fire = true
		else:
			# line up on the axis with the smaller offset, unless already lined up: then close in
			var horizontal := ax < ay if minf(ax, ay) >= ALIGN else ax > ay
			if horizontal:
				dir = Cfg.Dir.RIGHT if d.x > 0.0 else Cfg.Dir.LEFT
			else:
				dir = Cfg.Dir.DOWN if d.y > 0.0 else Cfg.Dir.UP
	match _ahead(map, pos, dir):
		BRICK:
			fire = true
		HARD:
			dir = _sidestep(map, pos, dir, rng)
			fire = false
	return {"dir": dir, "fire": fire}

# What is directly in front of the tank: 0 free, BRICK (shootable) or HARD (steel/water/edge).
static func _ahead(map: GameMap, pos: Vector2, dir: int) -> int:
	var v := Cfg.dir_vec(dir)
	var perp := Vector2(-v.y, v.x)
	var c := pos + Vector2(8, 8) + v * 10.0
	var result := 0
	for off in [-4.0, 4.0]:
		var p: Vector2 = c + perp * off
		var t := map.get_cell(floori(p.x / Cfg.CELL), floori(p.y / Cfg.CELL))
		if t == Cfg.Tile.STEEL or t == Cfg.Tile.WATER:
			return HARD
		if t == Cfg.Tile.BRICK:
			result = BRICK
	return result

static func _sidestep(map: GameMap, pos: Vector2, dir: int, rng: RandomNumberGenerator) -> int:
	var turns := [(dir + 1) % 4, (dir + 3) % 4]
	if rng.randf() < 0.5:
		turns.reverse()
	for t in turns:
		if _ahead(map, pos, t) != HARD:
			return t
	return (dir + 2) % 4
