class_name Cfg extends RefCounted
# Shared game constants.

const CELL := 8
const MAP_W := 80
const MAP_H := 80
const TANK_PX := 16
const TANK_SPEED := 60.0
const BULLET_SPEED := 180.0
const BULLET_SPEED_FAST := 300.0
const BULLET_RANGE := 208.0     # px a bullet flies before vanishing: one screen height, so you can fire again soon
const FIRE_COOLDOWN_S := 0.4    # minimum seconds between a tank's shots, so point-blank wall shooting can't be spammed
const TICK_HZ := 30
const RESPAWN_S := 2.0
const SPAWN_SHIELD_S := 3.0
const HELMET_S := 8.0
const POWERUP_TTL := 10.0
const REGROW_MIN := 30.0
const REGROW_MAX := 60.0
const HEAL_DELAY_S := 4.0       # seconds after the last damage before a tank starts healing
const HEAL_INTERVAL_S := 5.0    # then it regains 1 hp every this many seconds
const MAX_STARS := 3
const MAX_HP := 3              # base shots to kill a tank; each star adds one more (snapshots pack hp in 3 bits: max 7)
const ICE_SLIDE_S := 1.2        # momentum on ice: seconds to coast to a stop, speed fading linearly
const TRACK_GAP := 16.0         # px between the two tracks: the smaller it is, the tighter one-track turns are
const HIT_INSET := 1.0          # terrain hitbox is the tank square shrunk by this per side, so free steering still fits 2-cell gaps
const GRENADE_CELLS := 6
const INPUT_TIMEOUT_S := 0.5   # a client silent this long is treated as having released everything
const PORT := 7777
const STOP := 4                 # drive code with both tracks idle (see drive())

enum Tile { EMPTY, BRICK, STEEL, BUSH, WATER, ICE, BRICK_DAMAGED }   # BRICK_DAMAGED only appears in play: a brick hit once
enum Dir { UP, RIGHT, DOWN, LEFT }
enum PowerType { STAR, HELMET, GRENADE }

# A drive code packs the two tracks, each -1 (back), 0 (idle) or +1 (forward): (left + 1) * 3 + (right + 1).
static func drive(left: int, right: int) -> int:
	return (clampi(left, -1, 1) + 1) * 3 + clampi(right, -1, 1) + 1

static func drive_left(code: int) -> int:
	return code / 3 - 1

static func drive_right(code: int) -> int:
	return code % 3 - 1

# Headings are radians: 0 faces up and they grow clockwise, so right = PI/2.
static func heading(d: int) -> float:
	return d * PI / 2.0

static func heading_vec(h: float) -> Vector2:
	return Vector2(sin(h), -cos(h))

static func max_hp_for(stars: int) -> int:
	return MAX_HP + clampi(stars, 0, MAX_STARS)

static func dir_vec(d: int) -> Vector2:
	match d:
		Dir.UP: return Vector2(0, -1)
		Dir.RIGHT: return Vector2(1, 0)
		Dir.DOWN: return Vector2(0, 1)
		Dir.LEFT: return Vector2(-1, 0)
	return Vector2.ZERO
