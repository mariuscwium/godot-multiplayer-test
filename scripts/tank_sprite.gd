class_name TankSprite extends RefCounted
# Lookup into assets/tanks.png: 4 upgrade tiers (columns, one per star level) x 2 tread frames
# (rows) of 32x32 cells, cut by tools/pack_tanks.gd. Sprites face up.

const CELL_PX := 32

static func tier(stars: int) -> int:
	return clampi(stars, 0, Cfg.MAX_STARS)

static func src_rect(stars: int, frame: int) -> Rect2:
	return Rect2(tier(stars) * CELL_PX, posmod(frame, 2) * CELL_PX, CELL_PX, CELL_PX)
