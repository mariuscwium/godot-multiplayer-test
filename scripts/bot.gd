class_name Bot extends RefCounted
# Test opponent: turn towards the nearest living enemy, drive at it and shoot; shoot bricks that are in the way.
# Pure function of (map, me, others, rng) so it is unit-testable; Client adds reaction jitter.

const AIM := 0.12      # radians off target that still counts as lined up
const ARC := 0.35      # further off than this it spins on the spot; closer it arcs towards the target
const RANGE := 200.0   # px at which it will shoot
const BRICK := 1
const HARD := 2

# Spin on the spot: clockwise (+) is left track forward, right track back.
static func _spin(clockwise: bool) -> int:
	return Cfg.drive(1, -1) if clockwise else Cfg.drive(-1, 1)

static func decide(map: GameMap, me: Dictionary, others: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pos: Vector2 = me.pos
	var heading: float = me.facing
	var target = null
	var best := INF
	for o in others:
		if o.alive and pos.distance_to(o.pos) < best:
			best = pos.distance_to(o.pos)
			target = o
	var drive := Cfg.drive(1, 1)
	var fire := false
	if target == null:
		if rng.randf() < 0.05:
			drive = _spin(rng.randf() < 0.5)
	else:
		var d: Vector2 = target.pos - pos
		var diff := angle_difference(heading, atan2(d.x, -d.y))   # > 0: the target is clockwise of us
		if absf(diff) > ARC:
			drive = _spin(diff > 0.0)
		elif absf(diff) > AIM:
			drive = Cfg.drive(1, 0) if diff > 0.0 else Cfg.drive(0, 1)
		else:
			fire = best <= RANGE
	match _ahead(map, pos, heading):
		BRICK:
			fire = true
		HARD:
			drive = _spin(rng.randf() < 0.5)
			fire = false
	return {"drive": drive, "fire": fire}

# What is directly in front of the tank: 0 free, BRICK (shootable) or HARD (steel/water/edge).
static func _ahead(map: GameMap, pos: Vector2, heading: float) -> int:
	var v := Cfg.heading_vec(heading)
	var perp := Vector2(-v.y, v.x)
	var c := pos + Vector2(8, 8) + v * 10.0
	var result := 0
	for off in [-4.0, 4.0]:
		var p: Vector2 = c + perp * off
		var t := map.get_cell(floori(p.x / Cfg.CELL), floori(p.y / Cfg.CELL))
		if t == Cfg.Tile.STEEL or t == Cfg.Tile.WATER:
			return HARD
		if t == Cfg.Tile.BRICK or t == Cfg.Tile.BRICK_DAMAGED:
			result = BRICK
	return result
