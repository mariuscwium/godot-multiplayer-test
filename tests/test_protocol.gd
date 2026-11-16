extends RefCounted

func _sim() -> Sim:
	var s := Sim.new(GameMap.from_text("\n".join(range(20).map(func(_i): return ".".repeat(40)))))
	return s

func test_snapshot_roundtrip() -> void:
	var s := _sim()
	s.add_tank(7, "a")
	var t: Sim.Tank = s.tanks[7]
	t.pos = Vector2(12.3125, 45.5)
	t.facing = Cfg.Dir.LEFT
	t.shield_t = 2.0
	t.stars = 2
	t.kills = 5
	t.hp = 2
	t.ack_seq = 123
	t.slide_t = 0.2
	var b := Sim.Bullet.new()
	b.id = 9
	b.pos = Vector2(100.25, 50.0)
	b.dir = Cfg.Dir.DOWN
	b.owner = 7
	b.stars = 1
	s.bullets.append(b)
	s.drop_powerup(Vector2(64, 32), Cfg.PowerType.HELMET)
	s.tick = 42
	s.map_rev = 3
	var d := Protocol.decode_snapshot(Protocol.encode_snapshot(s))
	T.eq(d.tick, 42, "tick")
	T.eq(d.rev, 3, "map revision")
	var dt: Dictionary = d.tanks[7]
	T.near(dt.pos.x, 12.3125, 1.0 / 16, "x")
	T.near(dt.pos.y, 45.5, 1.0 / 16, "y")
	T.eq(dt.facing, Cfg.Dir.LEFT, "facing")
	T.eq(dt.alive, true, "alive")
	T.eq(dt.shield, true, "shield")
	T.eq(dt.stars, 2, "stars")
	T.eq(dt.kills, 5, "kills")
	T.eq(dt.hp, 2, "hp")
	T.eq(dt.ack, 123, "ack")
	T.near(dt.slide, 0.2, 0.002, "slide")
	T.eq(d.bullets.size(), 1, "one bullet")
	T.eq(d.bullets[0].owner, 7, "bullet owner")
	T.eq(d.bullets[0].dir, Cfg.Dir.DOWN, "bullet dir")
	T.eq(d.bullets[0].fast, true, "bullet fast")
	T.near(d.bullets[0].pos.x, 100.25, 1.0 / 16, "bullet x")
	T.eq(d.powerups.size(), 1, "one powerup")
	T.eq(d.powerups[0].type, Cfg.PowerType.HELMET, "powerup type")
	T.near(d.powerups[0].ttl, Cfg.POWERUP_TTL, 0.01, "powerup ttl")

func test_dead_and_unshielded_flags() -> void:
	var s := _sim()
	s.add_tank(1, "a")
	var t: Sim.Tank = s.tanks[1]
	t.alive = false
	t.shield_t = 0.0
	var d := Protocol.decode_snapshot(Protocol.encode_snapshot(s))
	T.eq(d.tanks[1].alive, false, "dead")
	T.eq(d.tanks[1].shield, false, "no shield")

func test_snapshot_is_compact() -> void:
	var s := _sim()
	for i in 10:
		s.add_tank(1000000 + i, "p%d" % i)
		var b := Sim.Bullet.new()
		b.id = i
		b.owner = 1000000 + i
		s.bullets.append(b)
	var n := var_to_bytes(Protocol.encode_snapshot(s)).size()
	T.ok(n < 700, "10 tanks + 10 bullets under 700 bytes, got %d" % n)

func test_roster() -> void:
	var s := _sim()
	s.add_tank(3, "Bob")
	T.eq(Protocol.encode_roster(s), {3: "Bob"}, "id to name")

func test_clean_name_cases() -> void:
	T.eq(Protocol.clean_name("", 7), "P7", "empty")
	T.eq(Protocol.clean_name("x".repeat(40), 7), "x".repeat(12), "long")
	T.eq(Protocol.clean_name("a\nb\t", 7), "ab", "control chars")
	T.eq(Protocol.clean_name("  Bob  ", 7), "Bob", "trim")
	T.eq(Protocol.clean_name("\n\n", 7), "P7", "only control chars")
	T.eq(Protocol.clean_name("abcdefghijk  zzz", 7), "abcdefghijk", "trim after cut")

func test_clean_name_is_fast_on_huge_input() -> void:
	var t0 := Time.get_ticks_msec()
	var n := Protocol.clean_name("x".repeat(200000), 7)
	T.eq(n, "x".repeat(12), "still truncated")
	T.ok(Time.get_ticks_msec() - t0 < 100, "took %d ms" % (Time.get_ticks_msec() - t0))

func test_upgraded_hp_survives_the_snapshot() -> void:
	var s := _sim()
	s.add_tank(1, "a")
	s.tanks[1].stars = 3
	s.tanks[1].hp = 6
	var d := Protocol.decode_snapshot(Protocol.encode_snapshot(s))
	T.eq(d.tanks[1].hp, 6, "6 hp fits the packed field")
	T.eq(d.tanks[1].stars, 3, "stars")
