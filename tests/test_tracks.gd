extends RefCounted

func test_alpha_fades_to_nothing() -> void:
	T.near(Tracks.alpha(0.0), Tracks.START_ALPHA, 0.0001, "fresh marks start at full strength")
	T.near(Tracks.alpha(Tracks.LIFETIME_S * 0.5), Tracks.START_ALPHA * 0.5, 0.0001, "half way, half strength")
	T.eq(Tracks.alpha(Tracks.LIFETIME_S), 0.0, "gone at the end")
	T.eq(Tracks.alpha(99.0), 0.0, "stays gone")
	T.eq(Tracks.alpha(-1.0), Tracks.START_ALPHA, "a slightly behind clock never gives more than full strength")

func test_stamps_once_per_spacing() -> void:
	var t := Tracks.new()
	t.update(1, Vector2(0, 0), 0, true, 0)
	T.eq(t.marks.size(), 0, "first sighting only records a start point")
	t.update(1, Vector2(0, -Tracks.SPACING_PX + 1.0), 0, true, 10)
	T.eq(t.marks.size(), 0, "not far enough yet")
	t.update(1, Vector2(0, -Tracks.SPACING_PX), 0, true, 20)
	T.eq(t.marks.size(), 1, "one mark after a full spacing")
	T.eq(t.marks[0].rot, 0.0, "rotation follows facing 0")
	t.update(1, Vector2(0, -Tracks.SPACING_PX), 2, true, 30)
	T.eq(t.marks.size(), 1, "standing still leaves nothing")

func test_no_marks_while_not_allowed_and_no_trail_across_gaps() -> void:
	var t := Tracks.new()
	t.update(1, Vector2(0, 0), 1, true, 0)
	t.update(1, Vector2(20, 0), 1, false, 10)
	T.eq(t.marks.size(), 0, "on ice: nothing, and the start point follows")
	t.update(1, Vector2(21, 0), 1, true, 20)
	T.eq(t.marks.size(), 0, "no mark dragged in from where it was on ice")
	t.update(1, Vector2(500, 500), 1, true, 30)
	T.eq(t.marks.size(), 0, "a respawn jump leaves no long streak")

func test_prune_expires_and_caps() -> void:
	var t := Tracks.new()
	t.update(1, Vector2.ZERO, 0, true, 0)
	t.update(1, Vector2(0, 5), 0, true, 0)
	t.prune(int(Tracks.LIFETIME_S * 1000.0) + 1)
	T.eq(t.marks.size(), 0, "expired marks are dropped")
	for i in Tracks.MAX_MARKS + 50:
		t.marks.append({"pos": Vector2.ZERO, "rot": 0.0, "born_ms": 1000000})
	t.prune(1000000)
	T.eq(t.marks.size(), Tracks.MAX_MARKS, "capped, oldest dropped first")

func test_forget_drops_the_start_point() -> void:
	var t := Tracks.new()
	t.update(1, Vector2.ZERO, 0, true, 0)
	t.forget(1)
	t.update(1, Vector2(0, 10), 0, true, 10)
	T.eq(t.marks.size(), 0, "after forgetting, the next sighting is a fresh start")
