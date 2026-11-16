extends RefCounted

func test_build_welcome_has_grid_roster_and_rev() -> void:
	var s := Server.new()
	s.sim = Sim.new(GameMap.from_text("...\n..."))
	s.sim.add_tank(5, "Bob")
	var w := s.build_welcome(5)
	T.eq(w.you, 5, "id")
	T.eq(w.w, 3, "width")
	T.eq(w.grid.size(), 6, "grid bytes")
	T.eq(w.roster, {5: "Bob"}, "roster")
	T.eq(w.rev, s.sim.map_rev, "map revision")
	s.free()
