extends RefCounted

func test_tier_clamps() -> void:
	T.eq(TankSprite.tier(-1), 0, "negative")
	T.eq(TankSprite.tier(0), 0, "no stars")
	T.eq(TankSprite.tier(3), 3, "max stars")
	T.eq(TankSprite.tier(9), 3, "capped")

func test_src_rect() -> void:
	T.eq(TankSprite.src_rect(0, 0), Rect2(0, 0, 32, 32), "tier 0 frame 0")
	T.eq(TankSprite.src_rect(2, 1), Rect2(64, 32, 32, 32), "tier 2 frame 1")
	T.eq(TankSprite.src_rect(9, 3), Rect2(96, 32, 32, 32), "stars capped, odd frame wraps to 1")

func test_tanks_png_has_eight_clean_tanks() -> void:
	var tex := load("res://assets/tanks.png") as Texture2D
	T.ok(tex != null, "assets/tanks.png loads")
	if tex == null:
		return
	var img := tex.get_image()
	T.eq(img.get_size(), Vector2i(128, 64), "4 tiers x 2 frames of 32px")
	for f in 2:
		for t in 4:
			var opaque := 0
			for y in 32:
				for x in 32:
					if img.get_pixel(t * 32 + x, f * 32 + y).a > 0.5:
						opaque += 1
			T.ok(opaque > 300, "tier %d frame %d has a tank (%d opaque px)" % [t, f, opaque])
			T.eq(img.get_pixel(t * 32, f * 32).a, 0.0, "tier %d frame %d corner is transparent" % [t, f])
	var leaks := 0
	for y in 64:
		for x in 128:
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and p.r > 0.9 and p.b > 0.9 and p.g < 0.25:
				leaks += 1
	T.eq(leaks, 0, "no opaque magenta fringe")
