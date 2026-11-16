extends SceneTree
# Run: godot --headless --path . -s tests/run_tests.gd [-- name_filter]

func _init() -> void:
	var filter := ""
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		filter = ua[0]
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files := []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s: script does not parse" % f)
			failed += 1
			continue
		var inst = script.new()
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_") or (filter != "" and not (f + "::" + mname).contains(filter)):
				continue
			T.fails = []
			inst.call(mname)
			if T.fails.is_empty():
				passed += 1
			else:
				failed += 1
				printerr("FAIL %s::%s" % [f, mname])
				for msg in T.fails:
					printerr("   " + msg)
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
