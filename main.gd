extends Node2D
# Run: --server [--ws] | --join <ip|ws(s)://url> [--name=X] [--bot]. More modes in later tasks.

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
	elif "--join" in args:
		var client := Client.new()
		client.name = "Client"
		client.net = net
		net.client = client
		for a in args:
			if a.begins_with("--name="):
				client.my_name = a.substr(7)
		add_child(client)
		var i := args.find("--join")
		client.connect_to(args[i + 1] if args.size() > i + 1 else "127.0.0.1")
