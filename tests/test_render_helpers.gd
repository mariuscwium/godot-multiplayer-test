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
