class_name GameMap extends RefCounted
# Tile grid in CELL-sized (8 px) cells. Server owns the authoritative copy.

var w := 0
var h := 0
var grid := PackedByteArray()
var _spawns: Array = []
var _pending := {}   # key (cy * w + cx) -> [tile, due_time]
var rng := RandomNumberGenerator.new()

const _CHARS := {".": 0, "B": 1, "S": 2, "G": 3, "W": 4, "I": 5}

static func from_text(text: String) -> GameMap:
	var lines := text.strip_edges(false, true).split("\n")
	var m := GameMap.new()
	m.h = lines.size()
	for l in lines:
		m.w = maxi(m.w, l.length())
	m.grid.resize(m.w * m.h)
	for y in m.h:
		for x in m.w:
			var c := lines[y][x] if x < lines[y].length() else "."
			if c == "P":
				m._spawns.append(Vector2(x * Cfg.CELL, y * Cfg.CELL))
				c = "."
			m.grid[y * m.w + x] = _CHARS.get(c, 0)
	return m

static func from_bytes(w_: int, h_: int, b: PackedByteArray) -> GameMap:
	var m := GameMap.new()
	m.w = w_
	m.h = h_
	m.grid = b.duplicate()
	return m

func to_bytes() -> PackedByteArray:
	return grid.duplicate()

func get_cell(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return Cfg.Tile.STEEL
	return grid[cy * w + cx]

func set_cell(cx: int, cy: int, t: int) -> void:
	if cx >= 0 and cy >= 0 and cx < w and cy < h:
		grid[cy * w + cx] = t

func spawn_points() -> Array:
	return _spawns

func tank_blocked(rect: Rect2) -> bool:
	var x0 := floori(rect.position.x / Cfg.CELL)
	var y0 := floori(rect.position.y / Cfg.CELL)
	var x1 := ceili(rect.end.x / Cfg.CELL) - 1
	var y1 := ceili(rect.end.y / Cfg.CELL) - 1
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var t := get_cell(cx, cy)
			if t == Cfg.Tile.BRICK or t == Cfg.Tile.STEEL or t == Cfg.Tile.WATER:
				return true
	return false

func bullet_blocked_at(cx: int, cy: int) -> int:
	return get_cell(cx, cy)

func bullet_passes(t: int) -> bool:
	return t != Cfg.Tile.BRICK and t != Cfg.Tile.STEEL

func destroy(cx: int, cy: int, now: float) -> bool:
	var t := get_cell(cx, cy)
	if cx < 0 or cy < 0 or cx >= w or cy >= h or (t != Cfg.Tile.BRICK and t != Cfg.Tile.STEEL):
		return false
	_pending[cy * w + cx] = [t, now + rng.randf_range(Cfg.REGROW_MIN, Cfg.REGROW_MAX)]
	set_cell(cx, cy, Cfg.Tile.EMPTY)
	return true

func regrow_due(now: float, occupied: Callable) -> Array:
	var out := []
	for key in _pending.keys():
		var p: Array = _pending[key]
		if p[1] > now:
			continue
		var cx: int = key % w
		var cy: int = key / w
		if occupied.call(Rect2(cx * Cfg.CELL, cy * Cfg.CELL, Cfg.CELL, Cfg.CELL)):
			continue
		_pending.erase(key)
		set_cell(cx, cy, p[0])
		out.append([cx, cy, p[0]])
	return out
