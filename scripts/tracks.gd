class_name Tracks extends RefCounted
# Tread marks left on the ground by moving tanks. Purely visual and client-side: marks are
# stamped from positions the client already draws, fade out over LIFETIME_S, and are capped.

const SPACING_PX := 4.0      # distance travelled between stamps
const LIFETIME_S := 4.0
const START_ALPHA := 0.35
const MAX_MARKS := 300
const JUMP_PX := 32.0        # a bigger step is a respawn or correction, not driving

var marks: Array = []        # {pos: tank centre, rot: radians, born_ms}, oldest first
var _last := {}              # tank id -> where it last stamped

static func alpha(age_s: float) -> float:
	return START_ALPHA * clampf(1.0 - age_s / LIFETIME_S, 0.0, 1.0)

# `stamp_ok` is false where marks make no sense (ice): the start point still follows the tank.
func update(id: int, center: Vector2, facing: int, stamp_ok: bool, now_ms: int) -> void:
	if not _last.has(id):
		_last[id] = center
		return
	var d: float = _last[id].distance_to(center)
	if d >= JUMP_PX or not stamp_ok:
		_last[id] = center
	elif d >= SPACING_PX:
		marks.append({"pos": center, "rot": TankSprite.angle(facing), "born_ms": now_ms})
		_last[id] = center

func forget(id: int) -> void:
	_last.erase(id)

func prune(now_ms: int) -> void:
	var keep: Array = []
	for m in marks:
		if (now_ms - m.born_ms) / 1000.0 < LIFETIME_S:
			keep.append(m)
	if keep.size() > MAX_MARKS:
		keep = keep.slice(keep.size() - MAX_MARKS)
	marks = keep
