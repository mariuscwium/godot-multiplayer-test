extends RefCounted

func test_amplitude_decays_to_nothing() -> void:
	T.near(ScreenShake.amplitude(0.0), ScreenShake.AMPLITUDE_PX, 0.0001, "full strength at the start")
	T.near(ScreenShake.amplitude(ScreenShake.DURATION_S * 0.5), ScreenShake.AMPLITUDE_PX * 0.5, 0.0001, "half way, half strength")
	T.eq(ScreenShake.amplitude(ScreenShake.DURATION_S), 0.0, "over at the end")
	T.eq(ScreenShake.amplitude(5.0), 0.0, "stays over")
	T.eq(ScreenShake.amplitude(-1.0), ScreenShake.AMPLITUDE_PX, "a slightly behind clock never gives more than full strength")

func test_shake_is_small_and_short() -> void:
	T.ok(ScreenShake.AMPLITUDE_PX <= 3.0, "a little shake: at most 3 world px (about 9 screen px)")
	T.ok(ScreenShake.DURATION_S <= 0.35, "quick")

func test_my_kill_starts_a_shake_but_other_kills_do_not() -> void:
	var c := Client.new()
	c.welcomed = true
	c.my_id = 7
	c.on_events([{"k": "kill", "killer": 3, "victim": 4, "pos": Vector2(10, 10)}])
	T.eq(c.shake_start_ms, -1, "someone else's kill does not shake my screen")
	c.on_events([{"k": "kill", "killer": 7, "victim": 4, "pos": Vector2(10, 10)}])
	T.ok(c.shake_start_ms >= 0, "my own kill does")
	c.free()

func test_shake_offset_stays_within_the_amplitude() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var age := rng.randf_range(0.0, ScreenShake.DURATION_S)
		var o := ScreenShake.offset(age, rng)
		T.ok(absf(o.x) <= ScreenShake.amplitude(age) + 0.0001 and absf(o.y) <= ScreenShake.amplitude(age) + 0.0001, "offset %s too big at age %f" % [str(o), age])
	T.eq(ScreenShake.offset(ScreenShake.DURATION_S + 0.1, rng), Vector2.ZERO, "no offset once it is over")
