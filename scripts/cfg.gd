class_name Cfg extends RefCounted
# Shared game constants.

const CELL := 8
const MAP_W := 80
const MAP_H := 80
const TANK_PX := 16
const TANK_SPEED := 60.0
const BULLET_SPEED := 180.0
const BULLET_SPEED_FAST := 300.0
const TICK_HZ := 30
const RESPAWN_S := 2.0
const SPAWN_SHIELD_S := 3.0
const HELMET_S := 8.0
const POWERUP_TTL := 10.0
const REGROW_MIN := 30.0
const REGROW_MAX := 60.0
const MAX_STARS := 3
const ICE_SLIDE_S := 0.25
const NONE := -1

enum Tile { EMPTY, BRICK, STEEL, BUSH, WATER, ICE }
enum Dir { UP, RIGHT, DOWN, LEFT }
enum PowerType { STAR, HELMET, GRENADE }

static func dir_vec(d: int) -> Vector2:
	match d:
		Dir.UP: return Vector2(0, -1)
		Dir.RIGHT: return Vector2(1, 0)
		Dir.DOWN: return Vector2(0, 1)
		Dir.LEFT: return Vector2(-1, 0)
	return Vector2.ZERO
