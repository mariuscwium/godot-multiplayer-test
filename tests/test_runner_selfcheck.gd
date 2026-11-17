extends RefCounted

func test_dir_vec() -> void:
	T.eq(Cfg.dir_vec(Cfg.Dir.UP), Vector2(0, -1), "up")
	T.eq(Cfg.dir_vec(Cfg.Dir.RIGHT), Vector2(1, 0), "right")
	T.eq(Cfg.dir_vec(Cfg.Dir.DOWN), Vector2(0, 1), "down")
	T.eq(Cfg.dir_vec(Cfg.Dir.LEFT), Vector2(-1, 0), "left")

func test_drive_codes_roundtrip() -> void:
	for l in [-1, 0, 1]:
		for r in [-1, 0, 1]:
			var c := Cfg.drive(l, r)
			T.ok(c >= 0 and c <= 8, "code %d in range" % c)
			T.eq(Cfg.drive_left(c), l, "left of (%d, %d)" % [l, r])
			T.eq(Cfg.drive_right(c), r, "right of (%d, %d)" % [l, r])
	T.eq(Cfg.drive(0, 0), Cfg.STOP, "STOP is both idle")

func test_heading_vec() -> void:
	T.near(Cfg.heading_vec(0.0).y, -1.0, 0.0001, "0 faces up")
	T.near(Cfg.heading_vec(PI / 2.0).x, 1.0, 0.0001, "PI/2 faces right")
	T.near(Cfg.heading_vec(Cfg.heading(Cfg.Dir.DOWN)).y, 1.0, 0.0001, "down")
