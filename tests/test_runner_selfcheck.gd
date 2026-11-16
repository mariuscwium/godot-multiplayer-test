extends RefCounted

func test_dir_vec() -> void:
	T.eq(Cfg.dir_vec(Cfg.Dir.UP), Vector2(0, -1), "up")
	T.eq(Cfg.dir_vec(Cfg.Dir.RIGHT), Vector2(1, 0), "right")
	T.eq(Cfg.dir_vec(Cfg.Dir.DOWN), Vector2(0, 1), "down")
	T.eq(Cfg.dir_vec(Cfg.Dir.LEFT), Vector2(-1, 0), "left")
