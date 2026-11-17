extends RefCounted

func test_takes_oldest_first() -> void:
	var q := [{"seq": 1}, {"seq": 2}]
	T.eq(Server.take_input(q).seq, 1, "oldest")
	T.eq(q.size(), 1, "one consumed per call")

func test_empty_gives_nothing() -> void:
	T.eq(Server.take_input([]), {}, "empty queue")

func test_skips_ahead_when_backlogged() -> void:
	var q := []
	for i in 10:
		q.append({"seq": i + 1})
	T.eq(Server.take_input(q).seq, 10 - Server.MAX_QUEUE + 1, "drops the stale ones")
