extends RefCounted

func _client() -> Client:
	var c := Client.new()
	c.welcomed = true
	return c

func test_frame_at_uses_the_kinds_fps_and_length() -> void:
	T.eq(Effects.frame_at("tank_explosion", 0.0), 0, "starts on frame 0")
	T.eq(Effects.frame_at("tank_explosion", 0.07), 1, "one frame is 66.7 ms")
	T.eq(Effects.frame_at("tank_explosion", 0.59), 8, "last frame")
	T.eq(Effects.frame_at("tank_explosion", 0.61), -1, "over after 9 frames")
	T.eq(Effects.frame_at("tank_explosion", -0.1), 0, "a clock slightly behind still shows frame 0")
	T.near(Effects.duration("tank_explosion"), 0.6, 0.0001, "9 frames at 15 fps")

func test_every_def_matches_its_sheet() -> void:
	for kind in Effects.DEFS:
		var d: Dictionary = Effects.DEFS[kind]
		var tex := Render.load_nearest_texture(d.path)
		T.ok(tex != null, "%s: sheet loads" % kind)
		if tex == null:
			continue
		var rows := ceili(d.frames / float(d.cols))
		T.eq(tex.get_size(), Vector2(d.cols * d.fw, rows * d.fh), "%s: sheet size matches its frame layout" % kind)
		T.ok(d.size > 0.0 and d.fps > 0.0 and d.frames > 0, "%s: sane numbers" % kind)

func test_src_rect_is_row_major() -> void:
	T.eq(Effects.src_rect("tank_explosion", 0), Rect2(0, 0, 48, 48), "first frame")
	T.eq(Effects.src_rect("tank_explosion", 8), Rect2(384, 0, 48, 48), "last frame of a single-row sheet")

func test_client_plays_fx_events() -> void:
	var c := _client()
	c.on_events([{"k": "fx", "fx": "tank_explosion", "pos": Vector2(10, 20), "rot": 0.5}])
	T.eq(c.fx.size(), 1, "one effect")
	T.eq(c.fx[0].kind, "tank_explosion", "kind")
	T.eq(c.fx[0].pos, Vector2(10, 20), "position")
	T.near(c.fx[0].rot, 0.5, 0.0001, "rotation")
	c.free()

func test_client_ignores_unknown_or_malformed_fx_events() -> void:
	var c := _client()
	c.on_events([
		{"k": "fx", "fx": "no_such_effect", "pos": Vector2(1, 1), "rot": 0.0},
		{"k": "fx", "fx": "tank_explosion"},
		{"k": "fx", "fx": 5, "pos": Vector2(1, 1)},
		{"k": "fx", "fx": "tank_explosion", "pos": "far away"},
		{"k": "fx"},
	])
	T.eq(c.fx.size(), 0, "nothing playable in those, and no crash")
	c.free()

func test_client_caps_active_effects_at_64() -> void:
	var c := _client()
	for i in 80:
		c.on_events([{"k": "fx", "fx": "tank_explosion", "pos": Vector2(i, 0), "rot": 0.0}])
	T.eq(c.fx.size(), 64, "capped")
	T.eq(c.fx[0].pos, Vector2(16, 0), "the oldest were dropped")
	c.free()

func test_kill_event_starts_a_tank_explosion() -> void:
	var c := _client()
	c.on_events([{"k": "kill", "killer": 1, "victim": 2, "pos": Vector2(40, 56)}])
	T.eq(c.fx.size(), 1, "one explosion")
	if c.fx.size() == 1:
		T.eq(c.fx[0].kind, "tank_explosion", "the tank explosion")
		T.eq(c.fx[0].pos, Vector2(40, 56), "at the victim")
	c.free()

func test_prune_uses_each_kinds_duration() -> void:
	var c := _client()
	c.fx = [{"kind": "tank_explosion", "pos": Vector2.ZERO, "rot": 0.0, "born_ms": 1000},
		{"kind": "tank_explosion", "pos": Vector2.ZERO, "rot": 0.0, "born_ms": 5000}]
	c.prune_fx(5200)
	T.eq(c.fx.size(), 1, "the finished one is gone, the fresh one stays")
	c.free()

func test_sim_fx_helper_emits_an_event() -> void:
	var s := Sim.new(GameMap.from_text("...\n..."))
	s._fx("tank_explosion", Vector2(5, 5), 0.5)
	var ev := s.drain_events()
	T.eq(ev, [{"k": "fx", "fx": "tank_explosion", "pos": Vector2(5, 5), "rot": 0.5}], "the event the clients play")
