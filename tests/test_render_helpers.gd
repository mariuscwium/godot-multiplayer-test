extends RefCounted

func test_hue_in_range() -> void:
	for id in [1, 2, 99, 868152337, 2147483647]:
		var h := Render.hue_for(id)
		T.ok(h >= 0.0 and h < 1.0, "hue %f for id %d in 0..1" % [h, id])

func test_hue_stable() -> void:
	T.eq(Render.hue_for(42), Render.hue_for(42), "same id, same colour")

func test_hue_distinct_for_first_20_ids() -> void:
	for a in range(1, 21):
		for b in range(a + 1, 21):
			var d := absf(Render.hue_for(a) - Render.hue_for(b))
			d = minf(d, 1.0 - d)
			T.ok(d > 0.02, "ids %d and %d too similar (%f)" % [a, b, d])

func test_hp_colors_differ_by_health() -> void:
	T.ok(Render.hp_color(3, 3) != Render.hp_color(2, 3), "3 vs 2")
	T.ok(Render.hp_color(2, 3) != Render.hp_color(1, 3), "2 vs 1")

func test_hp_color_follows_the_fraction_of_max() -> void:
	T.eq(Render.hp_color(5, 6), Render.hp_color(3, 3), "5/6 reads healthy")
	T.eq(Render.hp_color(3, 6), Render.hp_color(2, 3), "3/6 reads hurt")
	T.eq(Render.hp_color(2, 6), Render.hp_color(1, 3), "2/6 reads critical")

func test_terrain_texture_filters_only_itself() -> void:
	# nearest filtering lives on the texture, not the Render node, so name tags keep smooth text
	var tex := Render.load_terrain_texture()
	T.ok(tex is CanvasTexture, "wrapped in a CanvasTexture")
	if tex is CanvasTexture:
		T.eq(tex.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "tile art stays crisp")
		T.eq(tex.get_size(), Vector2(144, 16), "the packed strip")

func test_tank_texture_is_nearest_canvas_texture() -> void:
	var tex := Render.load_nearest_texture("res://assets/tanks.png")
	T.ok(tex is CanvasTexture, "wrapped in a CanvasTexture")
	if tex is CanvasTexture:
		T.eq(tex.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "crisp pixels")
		T.eq(tex.get_size(), Vector2(128, 64), "the packed strip")

func test_is_moving() -> void:
	T.eq(Render.is_moving(null, Vector2(5, 5)), false, "no previous position")
	T.eq(Render.is_moving(Vector2(5, 5), Vector2(5, 5)), false, "standing still")
	T.eq(Render.is_moving(Vector2(5, 5), Vector2(5.5, 5)), true, "moved half a pixel")
