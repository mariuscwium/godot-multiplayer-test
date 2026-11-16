class_name TerrainTiles extends RefCounted
# Lookup into assets/terrain.png: a one-row strip of 16x16 tiles (cut by tools/pack_terrain.gd).
# Cells are 8 px, so each cell draws one quarter of its tile and walls look continuous.

const TILE_PX := 16
const GROUND := 0
const BRICK := 1
const STEEL := 2
const WATER0 := 3      # water alternates frames 3 and 4 (tile 5 is a deeper shade, kept in the strip but unused)
const ICE := 6
const BUSH := 7
const BRICK_DAMAGED := 8

static func water_index(t: float) -> int:
	return WATER0 + int(t * 3.0) % 2

static func index_for(terrain: int, t: float) -> int:
	match terrain:
		Cfg.Tile.BRICK: return BRICK
		Cfg.Tile.BRICK_DAMAGED: return BRICK_DAMAGED
		Cfg.Tile.STEEL: return STEEL
		Cfg.Tile.WATER: return water_index(t)
		Cfg.Tile.ICE: return ICE
		Cfg.Tile.BUSH: return BUSH
	return GROUND

static func src_rect(index: int, cx: int, cy: int) -> Rect2:
	var half := Cfg.CELL
	return Rect2(index * TILE_PX + posmod(cx, 2) * half, posmod(cy, 2) * half, half, half)
