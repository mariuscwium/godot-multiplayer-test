extends RefCounted

func test_frame_at_plays_nine_frames_at_15_fps() -> void:
	T.eq(ExplosionFx.frame_at(0.0), 0, "starts on frame 0")
	T.eq(ExplosionFx.frame_at(0.07), 1, "one frame is 66.7 ms")
	T.eq(ExplosionFx.frame_at(0.30), 4, "mid-way")
	T.eq(ExplosionFx.frame_at(0.59), 8, "last frame")
	T.eq(ExplosionFx.frame_at(0.61), -1, "over after 9 frames (0.6 s)")
	T.eq(ExplosionFx.frame_at(-0.1), 0, "a clock that runs slightly behind still shows frame 0")

func test_src_rect_walks_along_the_strip() -> void:
	T.eq(ExplosionFx.src_rect(0), Rect2(0, 0, 48, 48), "first frame")
	T.eq(ExplosionFx.src_rect(8), Rect2(384, 0, 48, 48), "last frame")

func test_explosion_sheet_is_packed_as_expected() -> void:
	var tex := Render.load_nearest_texture("res://assets/fx/explosion_small.png")
	T.ok(tex is CanvasTexture, "loads as a nearest-filtered texture")
	if tex is CanvasTexture:
		T.eq(tex.get_size(), Vector2(432, 48), "9 frames of 48x48")

func test_client_starts_an_explosion_on_a_kill_event() -> void:
	var c := Client.new()
	c.welcomed = true
	c.on_events([{"k": "kill", "killer": 1, "victim": 2, "pos": Vector2(40, 56)}])
	T.eq(c.fx.size(), 1, "one explosion")
	if c.fx.size() == 1:
		T.eq(c.fx[0].pos, Vector2(40, 56), "at the victim")
	c.free()

func test_client_drops_finished_explosions() -> void:
	var c := Client.new()
	c.fx = [{"pos": Vector2.ZERO, "born_ms": 1000}, {"pos": Vector2.ZERO, "born_ms": 5000}]
	c.prune_fx(5200)
	T.eq(c.fx.size(), 1, "the old one is gone, the fresh one stays")
	c.free()
