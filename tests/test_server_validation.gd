extends RefCounted

func test_accepts_valid() -> void:
	var r := Server.sanitize_input(5, Cfg.Dir.LEFT, true, 4)
	T.eq(r, {"seq": 5, "dir": Cfg.Dir.LEFT, "fire": true}, "valid input passes through")

func test_accepts_none_dir() -> void:
	T.eq(Server.sanitize_input(1, -1, false, 0).dir, -1, "NONE is valid")

func test_rejects_bad_dir() -> void:
	T.eq(Server.sanitize_input(5, 7, false, 4), {}, "dir 7")
	T.eq(Server.sanitize_input(5, -2, false, 4), {}, "dir -2")

func test_rejects_stale_seq() -> void:
	T.eq(Server.sanitize_input(4, 0, false, 4), {}, "equal seq")
	T.eq(Server.sanitize_input(3, 0, false, 4), {}, "older seq")

func test_rejects_huge_seq_jump() -> void:
	T.eq(Server.sanitize_input(4 + 10000000, 0, false, 4), {}, "would lock out the real client")
	T.eq(Server.sanitize_input(1 << 40, 0, false, 4), {}, "64-bit seq")

func test_rejects_wrong_types() -> void:
	T.eq(Server.sanitize_input(NAN, 0, false, 4), {}, "NaN seq")
	T.eq(Server.sanitize_input("5", 0, false, 4), {}, "string seq")
	T.eq(Server.sanitize_input(5, 1.5, false, 4), {}, "float dir")
	T.eq(Server.sanitize_input(5, 0, "yes", 4), {}, "string fire")
	T.eq(Server.sanitize_input(5, null, false, 4), {}, "null dir")
