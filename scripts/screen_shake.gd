class_name ScreenShake extends RefCounted
# A short, decaying camera shake, played when you score a kill.

const AMPLITUDE_PX := 2.5    # world px at the start (about 8 screen px at the default window size)
const DURATION_S := 0.25

static func amplitude(age_s: float) -> float:
	if age_s >= DURATION_S:
		return 0.0
	return AMPLITUDE_PX * (1.0 - clampf(age_s / DURATION_S, 0.0, 1.0))

static func offset(age_s: float, rng: RandomNumberGenerator) -> Vector2:
	var a := amplitude(age_s)
	if a <= 0.0:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-a, a), rng.randf_range(-a, a))
