extends Node2D
# Modes (flags after --):
#   --server [--ws]            dedicated server, no window needed (add --headless)
#   --host [--ws] [--name=X]   run the server and play in the same process
#   --join [ip|ws(s)://url]    join a server; no target = find one on the LAN
#   --bot                      with --join: AI-driven client for testing
# Web export reads ?server=wss://...&name=... from the page URL.
# Client test flags: --lag=<ms> --loss=<0..1> --nopredict --shot=<png>

var net: Net

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var my_name := ""
	for a in args:
		if a.begins_with("--name="):
			my_name = a.substr(7)
	net = Net.new()
	net.name = "Net"
	add_child(net)
	if OS.has_feature("web"):
		my_name = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('name') || ''"))
		_join(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''")), my_name, true)
	elif "--server" in args or "--host" in args:
		_serve(args, my_name)
	elif "--join" in args:
		var i := args.find("--join")
		var target: String = args[i + 1] if args.size() > i + 1 and not args[i + 1].begins_with("--") else ""
		_join(target, my_name, false)
	else:
		print("usage: -- --server | --host | --join [target]   (see main.gd)")

func _serve(args: PackedStringArray, my_name: String) -> void:
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
	if not ws:  # LAN broadcast only makes sense for UDP games
		var d := Discovery.new()
		add_child(d)
		d.start_announcing(my_name if my_name != "" else "host")
	if "--server" in args:
		print("dedicated server listening on %s %d" % ["TCP (WebSocket)" if ws else "UDP", Cfg.PORT])
	else:
		var client := _make_client(my_name)
		client.start_local(server)

func _make_client(my_name: String) -> Client:
	var client := Client.new()
	client.name = "Client"
	client.net = net
	client.my_name = my_name
	net.client = client
	add_child(client)
	return client

func _join(target: String, my_name: String, web: bool) -> void:
	var client := _make_client(my_name)
	if target != "":
		client.connect_to(target)
	elif web:
		client.msg = "Add ?server=wss://your-host to the page URL"  # browsers can't do UDP discovery
	else:
		var d := Discovery.new()
		add_child(d)
		client.msg = "Searching for host on LAN..."
		d.found.connect(func(ip): client.connect_to(ip))
		d.timed_out.connect(func(): client.msg = "No host found on LAN (try --join <ip>)")
		d.start_finding()
