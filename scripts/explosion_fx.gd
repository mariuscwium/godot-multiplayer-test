class_name ExplosionFx extends RefCounted
# Tank-destroyed explosion: assets/fx/explosion_small.png, 9 frames of 48x48 played at 15 FPS
# (Super Pixel Effects Gigapack, stylized_explosion_001_small_yellow).

const FRAMES := 9
const FRAME_PX := 48
const FPS := 15.0
const DURATION_S := FRAMES / FPS

# Frame to show `age_s` seconds after the explosion started, or -1 once it is over.
static func frame_at(age_s: float) -> int:
	if age_s >= DURATION_S:
		return -1
	return maxi(0, int(age_s * FPS))

static func src_rect(frame: int) -> Rect2:
	return Rect2(frame * FRAME_PX, 0, FRAME_PX, FRAME_PX)
