class_name Effects extends RefCounted
# Pixel-art effect animations (Super Pixel Effects Gigapack, Will Tice / unTied Games). The server says
# "play <kind> at <pos>" with an fx event; clients draw it from the table below. The pack's animations are
# meant to play at 15 FPS. `size` is the on-screen size in world px; `base_angle` turns a sprite that does
# not face up so that `rot` 0 means "facing up".

const DEFS := {
	"tank_explosion": {"path": "res://assets/fx/explosion_small.png", "fw": 48, "fh": 48, "frames": 9, "cols": 9,
		"fps": 15.0, "size": 48.0, "base_angle": 0.0},
	"hit_tank": {"path": "res://assets/fx/hit_tank.png", "fw": 48, "fh": 48, "frames": 10, "cols": 10, "fps": 15.0, "size": 24.0, "base_angle": 0.0},
	"hit_brick": {"path": "res://assets/fx/hit_brick.png", "fw": 48, "fh": 48, "frames": 7, "cols": 7, "fps": 15.0, "size": 24.0, "base_angle": 0.0},
	"hit_steel": {"path": "res://assets/fx/hit_steel.png", "fw": 32, "fh": 32, "frames": 7, "cols": 7, "fps": 15.0, "size": 32.0, "base_angle": PI / 2.0},   # the sheet's particles fly left
	"pickup_star": {"path": "res://assets/fx/pickup_star.png", "fw": 64, "fh": 64, "frames": 18, "cols": 18, "fps": 15.0, "size": 32.0, "base_angle": 0.0},
	"pickup_helmet": {"path": "res://assets/fx/pickup_helmet.png", "fw": 64, "fh": 64, "frames": 18, "cols": 18, "fps": 15.0, "size": 32.0, "base_angle": 0.0},
	"blast": {"path": "res://assets/fx/blast.png", "fw": 96, "fh": 96, "frames": 9, "cols": 9, "fps": 15.0, "size": 96.0, "base_angle": 0.0},   # the grenade clears a 6-cell radius = 96 px across
	"heal": {"path": "res://assets/fx/heal.png", "fw": 64, "fh": 64, "frames": 16, "cols": 16, "fps": 15.0, "size": 48.0, "base_angle": 0.0},
	"drop_sparkle": {"path": "res://assets/fx/drop_sparkle.png", "fw": 32, "fh": 32, "frames": 14, "cols": 14, "fps": 15.0, "size": 32.0, "base_angle": 0.0},
}

static func has(kind: String) -> bool:
	return DEFS.has(kind)

static func duration(kind: String) -> float:
	return DEFS[kind].frames / DEFS[kind].fps

# Frame to show `age_s` seconds after the effect started, or -1 once it is over.
static func frame_at(kind: String, age_s: float) -> int:
	if age_s >= duration(kind):
		return -1
	return maxi(0, int(age_s * DEFS[kind].fps))

static func src_rect(kind: String, frame: int) -> Rect2:
	var d: Dictionary = DEFS[kind]
	return Rect2((frame % d.cols) * d.fw, (frame / d.cols) * d.fh, d.fw, d.fh)
