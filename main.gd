extends Node2D
# Run: --server (dedicated, headless-friendly) [--ws for WebSocket]. Client modes are added in later tasks.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var net := Net.new()
	net.name = "Net"
	add_child(net)
	if "--server" in args:
		var server := Server.new()
		server.name = "Server"
		server.net = net
		add_child(server)
		var ws := "--ws" in args
		var err := server.start(Cfg.PORT, ws)
		if err != OK:
			printerr("could not listen on %d: %s" % [Cfg.PORT, error_string(err)])
			get_tree().quit(1)
			return
		print("dedicated server listening on %s %d" % ["TCP (WebSocket)" if ws else "UDP", Cfg.PORT])
