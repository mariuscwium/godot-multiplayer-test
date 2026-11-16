class_name Render extends Node2D
# Draws the world: terrain from assets/terrain.png tiles; tanks, bullets, power-ups in code.
# Bushes are drawn after other tanks/bullets so they hide them; your own tank draws on top.

const C := Cfg.CELL

var client: Client
var tiles: Texture2D
var tanks: Texture2D
var tracks := Tracks.new()
var fx_tex := {}         # effect kind -> texture
var _last_pos := {}      # tank id -> position drawn last frame
var _moved_ms := {}      # tank id -> when it last moved (treads keep rolling between 30 Hz updates)

# Nearest filtering is set on the texture, not on this node, so name tags keep smooth text.
static func load_nearest_texture(path: String) -> Texture2D:
	var base := load(path) as Texture2D
	if base == null:
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = base
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ct

static func load_terrain_texture() -> Texture2D:
	return load_nearest_texture("res://assets/terrain.png")

static func is_moving(prev: Variant, now: Vector2) -> bool:
	return prev != null and prev.distance_to(now) >= 0.05

static func hp_color(hp: int, max_hp: int) -> Color:
	# by fraction of max: healthy above 2/3, hurt above 1/3, otherwise critical
	if hp * 3 > max_hp * 2:
		return Color("3ddc4a")
	return Color("f2c21b") if hp * 3 > max_hp else Color("e5392b")

static func hue_for(id: int) -> float:
	return fmod(absf(float(id)) * 0.61803398875, 1.0)

func _ready() -> void:
	client = get_parent()
	tiles = load_terrain_texture()
	tanks = load_nearest_texture("res://assets/tanks.png")
	var fx_ok := true
	for kind in Effects.DEFS:
		fx_tex[kind] = load_nearest_texture(Effects.DEFS[kind].path)
		fx_ok = fx_ok and fx_tex[kind] != null
	if tiles == null or tanks == null or not fx_ok:
		push_error("a texture in assets/ is missing or not imported (run: godot --headless --path . --import)")
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
	_draw_tracks()
	for p in client.view.powerups:
		_draw_powerup(p, t)
	for id in client.view.tanks:
		var tk: Dictionary = client.view.tanks[id]
		if id != client.my_id and tk.alive:
			_draw_tank(id, client.shown.get(id, tk.pos), tk, t)
	_draw_bullets()
	for id in _last_pos.keys():
		if not client.view.tanks.has(id):
			_last_pos.erase(id)
			_moved_ms.erase(id)
			tracks.forget(id)
	for cy in range(maxi(vis.position.y, 0), mini(vis.end.y, map.h)):
		for cx in range(maxi(vis.position.x, 0), mini(vis.end.x, map.w)):
			if map.get_cell(cx, cy) == Cfg.Tile.BUSH:
				_draw_cell(TerrainTiles.BUSH, cx, cy)
	var me: Dictionary = client.view.tanks.get(client.my_id, {})
	if not me.is_empty() and me.alive:
		var mine := me.duplicate()
		mine.facing = client.my_facing  # predicted facing, not the older snapshot's
		_draw_tank(client.my_id, client.my_draw_pos, mine, t, true)
	_draw_effects()

# Tread marks lie on the ground: over the terrain, under tanks and bushes.
func _draw_tracks() -> void:
	var now := Time.get_ticks_msec()
	tracks.prune(now)
	for m in tracks.marks:
		var a := Tracks.alpha((now - m.born_ms) / 1000.0)
		if a <= 0.0:
			continue
		draw_set_transform(m.pos, m.rot, Vector2.ONE)
		var col := Color(0, 0, 0, a)
		draw_rect(Rect2(-7, -2, 3, 4), col)
		draw_rect(Rect2(4, -2, 3, 4), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Effect animations play on top of everything in the world, bushes included.
func _draw_effects() -> void:
	var now := Time.get_ticks_msec()
	for f in client.fx:
		var frame := Effects.frame_at(f.kind, (now - f.born_ms) / 1000.0)
		if frame < 0:
			continue
		if Effects.hidden_in_bush(f.kind, f.pos, f.tank, client.my_id, client.map):
			continue
		var d: Dictionary = Effects.DEFS[f.kind]
		var half: float = d.size * 0.5
		draw_set_transform(f.pos, f.rot + d.base_angle, Vector2.ONE)
		draw_texture_rect_region(fx_tex[f.kind], Rect2(-half, -half, d.size, d.size), Effects.src_rect(f.kind, frame))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# One 8 px cell, drawn from the matching quarter of its 16x16 tile.
func _draw_cell(index: int, cx: int, cy: int) -> void:
	draw_texture_rect_region(tiles, Rect2(cx * C, cy * C, C, C), TerrainTiles.src_rect(index, cx, cy))

func _draw_tank(id: int, pos: Vector2, tk: Dictionary, t: float, mine := false) -> void:
	var now_ms := Time.get_ticks_msec()
	if is_moving(_last_pos.get(id), pos):
		_moved_ms[id] = now_ms
	_last_pos[id] = pos
	var center := pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5
	var cell := client.map.get_cell(floori(center.x / C), floori(center.y / C))
	tracks.update(id, center, tk.facing, cell != Cfg.Tile.ICE, now_ms)
	var frame := int(t * 10.0) % 2 if now_ms - _moved_ms.get(id, -1000) < 120 else 0
	draw_set_transform(pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5, TankSprite.angle(tk.facing), Vector2.ONE)
	draw_texture_rect_region(tanks, Rect2(-8, -8, Cfg.TANK_PX, Cfg.TANK_PX), TankSprite.src_rect(tk.stars, frame),
		Color.from_hsv(hue_for(id), 0.55, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var max_hp := Cfg.max_hp_for(tk.stars)   # health bar under the tank: one equal segment per hit it can take
	var seg := clampi((18 - (max_hp - 1)) / max_hp, 2, 5)
	var x_start := (Cfg.TANK_PX - (max_hp * seg + (max_hp - 1))) / 2
	for i in max_hp:
		draw_rect(Rect2(pos + Vector2(x_start + i * (seg + 1), 18), Vector2(seg, 2)),
			hp_color(tk.hp, max_hp) if i < tk.hp else Color(0.25, 0.25, 0.25))
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
