class_name Render extends Node2D
# Draws the world: terrain from assets/terrain.png tiles; tanks, bullets, power-ups in code.
# Bushes are drawn after other tanks/bullets so they hide them; your own tank draws on top.

const C := Cfg.CELL

var client: Client
var tiles: Texture2D

# Nearest filtering is set on the texture, not on this node, so name tags keep smooth text.
static func load_terrain_texture() -> Texture2D:
	var base := load("res://assets/terrain.png") as Texture2D
	if base == null:
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = base
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ct

static func hp_color(hp: int) -> Color:
	return Color("3ddc4a") if hp >= 3 else (Color("f2c21b") if hp == 2 else Color("e5392b"))

static func hue_for(id: int) -> float:
	return fmod(absf(float(id)) * 0.61803398875, 1.0)

func _ready() -> void:
	client = get_parent()
	tiles = load_terrain_texture()
	if tiles == null:
		push_error("assets/terrain.png is missing or not imported (run: godot --headless --path . --import)")
		get_tree().quit(1)

func _process(_d: float) -> void:
	queue_redraw()

func _visible_cells() -> Rect2i:
	var half := get_viewport_rect().size / client.cam.zoom * 0.5
	# cam.position is only where we ask the camera to be: map-edge limits shift the real view,
	# so cull around the centre the camera actually shows
	var c: Vector2 = client.cam.get_screen_center_position()
	return Rect2i(floori((c.x - half.x) / C) - 1, floori((c.y - half.y) / C) - 1,
		ceili(half.x * 2.0 / C) + 3, ceili(half.y * 2.0 / C) + 3)

func _draw() -> void:
	if not client.welcomed or client.map == null:
		return
	var map: GameMap = client.map
	var vis := _visible_cells()
	var t := Time.get_ticks_msec() / 1000.0
	for cy in range(maxi(vis.position.y, 0), mini(vis.end.y, map.h)):
		for cx in range(maxi(vis.position.x, 0), mini(vis.end.x, map.w)):
			_draw_cell(TerrainTiles.GROUND, cx, cy)
			var tile := map.get_cell(cx, cy)
			if tile != Cfg.Tile.EMPTY and tile != Cfg.Tile.BUSH:
				_draw_cell(TerrainTiles.index_for(tile, t), cx, cy)
	for p in client.view.powerups:
		_draw_powerup(p, t)
	for id in client.view.tanks:
		var tk: Dictionary = client.view.tanks[id]
		if id != client.my_id and tk.alive:
			_draw_tank(id, client.shown.get(id, tk.pos), tk, t)
	_draw_bullets()
	for cy in range(maxi(vis.position.y, 0), mini(vis.end.y, map.h)):
		for cx in range(maxi(vis.position.x, 0), mini(vis.end.x, map.w)):
			if map.get_cell(cx, cy) == Cfg.Tile.BUSH:
				_draw_cell(TerrainTiles.BUSH, cx, cy)
	var me: Dictionary = client.view.tanks.get(client.my_id, {})
	if not me.is_empty() and me.alive:
		var mine := me.duplicate()
		mine.facing = client.my_facing  # predicted facing, not the older snapshot's
		_draw_tank(client.my_id, client.my_pos, mine, t, true)

# One 8 px cell, drawn from the matching quarter of its 16x16 tile.
func _draw_cell(index: int, cx: int, cy: int) -> void:
	draw_texture_rect_region(tiles, Rect2(cx * C, cy * C, C, C), TerrainTiles.src_rect(index, cx, cy))

func _draw_tank(id: int, pos: Vector2, tk: Dictionary, t: float, mine := false) -> void:
	var col := Color.from_hsv(hue_for(id), 0.75, 1.0)
	var dark := col.darkened(0.55)
	var horizontal: bool = tk.facing == Cfg.Dir.LEFT or tk.facing == Cfg.Dir.RIGHT
	var tread := int(t * 12.0) % 2
	if horizontal:
		draw_rect(Rect2(pos + Vector2(0, 0), Vector2(16, 4)), dark)
		draw_rect(Rect2(pos + Vector2(0, 12), Vector2(16, 4)), dark)
		for i in range(tread, 16, 4):
			draw_rect(Rect2(pos + Vector2(i, 0), Vector2(1, 4)), Color.BLACK)
			draw_rect(Rect2(pos + Vector2(i, 12), Vector2(1, 4)), Color.BLACK)
		draw_rect(Rect2(pos + Vector2(2, 4), Vector2(12, 8)), col)
	else:
		draw_rect(Rect2(pos + Vector2(0, 0), Vector2(4, 16)), dark)
		draw_rect(Rect2(pos + Vector2(12, 0), Vector2(4, 16)), dark)
		for i in range(tread, 16, 4):
			draw_rect(Rect2(pos + Vector2(0, i), Vector2(4, 1)), Color.BLACK)
			draw_rect(Rect2(pos + Vector2(12, i), Vector2(4, 1)), Color.BLACK)
		draw_rect(Rect2(pos + Vector2(4, 2), Vector2(8, 12)), col)
	var c := pos + Vector2(8, 8)
	var v := Cfg.dir_vec(tk.facing)
	draw_rect(Rect2(c + v * 2.0 - Vector2(1.5, 1.5), Vector2(3, 3)).merge(Rect2(c + v * 9.0 - Vector2(1.5, 1.5), Vector2(3, 3))), dark.lightened(0.3))
	draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), col.lightened(0.25))
	for i in tk.stars:
		draw_rect(Rect2(pos + Vector2(5 + i * 3, 7), Vector2(2, 2)), Color.YELLOW)
	for i in Cfg.MAX_HP:   # health bar under the tank: one segment per hit it can take
		draw_rect(Rect2(pos + Vector2(i * 6, 18), Vector2(4, 2)), hp_color(tk.hp) if i < tk.hp else Color(0.25, 0.25, 0.25))
	if tk.shield and int(t * 10.0) % 2 == 0:
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(18, 18)), Color(1, 1, 1, 0.9), false, 1.0)
	var nm: String = client.roster.get(id, "")
	if nm != "":
		draw_string(ThemeDB.fallback_font, pos + Vector2(-16, -2), nm, HORIZONTAL_ALIGNMENT_CENTER, 48, 6, Color(1, 1, 1, 0.85 if not mine else 1.0))


func _draw_bullets() -> void:
	var age := minf((Time.get_ticks_msec() - client.snap_ms) / 1000.0, 0.1)
	for b in client.view.bullets:
		var sp := Cfg.BULLET_SPEED_FAST if b.fast else Cfg.BULLET_SPEED
		var p: Vector2 = b.pos + Cfg.dir_vec(b.dir) * sp * age
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.95, 0.6))

func _draw_powerup(p: Dictionary, t: float) -> void:
	if p.ttl < 3.0 and int(t * 6.0) % 2 == 0:
		return
	var o: Vector2 = p.pos
	draw_rect(Rect2(o, Vector2(16, 16)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(14, 14)), Color.WHITE, false, 1.0)
	var c := o + Vector2(8, 8)
	match p.type:
		Cfg.PowerType.STAR:
			var pts := PackedVector2Array()
			for i in 10:
				var r := 6.0 if i % 2 == 0 else 2.6
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color.YELLOW)
		Cfg.PowerType.HELMET:
			draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 6)), Color("4fa3ff"))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 3)), Color("4fa3ff"))
			draw_rect(Rect2(c + Vector2(-2, 1), Vector2(4, 2)), Color.BLACK)
		Cfg.PowerType.GRENADE:
			draw_circle(c + Vector2(0, 1), 5.0, Color("2f7a2f"))
			draw_rect(Rect2(c + Vector2(-1, -6), Vector2(3, 3)), Color("c0c0c0"))
			draw_rect(Rect2(c + Vector2(2, -7), Vector2(2, 2)), Color.RED)
