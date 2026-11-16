extends Node2D
# Run: --host (host + play) | --server (dedicated, no player) | --join [ip|ws(s)://url] (none = find host on LAN)
# Add --ws to host/server for WebSocket instead of ENet (browser clients; put TLS proxy/tunnel in front).
# Web export reads ?server=wss://...&name=... from the page URL.
# Arrows move (client sends input, server simulates). Click = shoot. Enter = chat. R = ready. --name=X sets your name.

const PORT := 7777
const SPEED := 300.0
const WIN := 5
const DISC_PORT := 7778  # UDP broadcast: host announces, clients listen

var log_label: Label
var line: LineEdit
var hud: Label
var bullet_spawner: MultiplayerSpawner
var next_bullet := 0
var status: Label
var player_spawner: MultiplayerSpawner
var my_name := ""
var phase := "lobby"   # "lobby" | "playing"; server decides, set_phase RPC mirrors it
var announcer: PacketPeerUDP   # host side
var announce_t := 0.0
var finder: PacketPeerUDP      # client side while searching
var find_deadline := 0
var msg := ""          # connection problems shown to the user

class Player extends Node2D:
	var ack := 0                 # last input seq the server applied (replicated)
	var seq := 0
	var shown := Vector2.ZERO    # what we draw; position is raw server state
	var pending := []            # [seq, vec, dt] sent but not yet acked
	var lag_ms := 0
	var loss := 0.0
	var predict := true
	var hp := 3                  # server-owned, replicated
	var score := 0
	var last_fire := 0
	var pname := ""              # from spawn data
	var is_ready := false         # server-owned, replicated
	var queue := []
	func _init() -> void:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--lag="): lag_ms = int(a.substr(6))
			if a.begins_with("--loss="): loss = float(a.substr(7))
			if a == "--nopredict": predict = false
	func _ready() -> void:
		# authority stays 1 (server): only the server writes position/ack
		var sync := MultiplayerSynchronizer.new()
		var cfg := SceneReplicationConfig.new()
		cfg.add_property(^":position")
		cfg.add_property(^":ack")
		cfg.add_property(^":hp")
		cfg.add_property(^":score")
		cfg.add_property(^":is_ready")
		sync.replication_config = cfg
		add_child(sync)
		modulate = Color.from_hsv(fmod(name.to_int() * 0.37, 1.0), 0.8, 1.0)
		shown = position
	func read_input() -> Vector2:
		if get_viewport().gui_get_focus_owner():  # typing in chat
			return Vector2.ZERO
		return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	@rpc("any_peer", "unreliable_ordered")
	func send_input(s: int, v: Vector2, dt: float) -> void:
		# server validates sender owns this player, clamps input and step
		# ponytail: a client can still flood messages to speedhack; add a per-second budget if it matters
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() == name.to_int() and s > ack:
			position += v.limit_length(1.0) * SPEED * minf(dt, 0.1)
			ack = s
	func _process(delta: float) -> void:
		var mine := name.to_int() == multiplayer.get_unique_id()
		if multiplayer.is_server():
			if mine:
				position += read_input() * SPEED * delta
			shown = position
		elif mine:
			var v := read_input()
			seq += 1
			pending.append([seq, v, delta])
			# fake lag/loss on client->server input (--lag=ms --loss=0..1)
			var now := Time.get_ticks_msec()
			queue.append([now + lag_ms, seq, v, delta])
			while queue and queue[0][0] <= now:
				var q: Array = queue.pop_front()
				if randf() >= loss:
					send_input.rpc_id(1, q[1], q[2], q[3])
			# prediction: server state + replay of inputs it hasn't seen yet
			while pending and pending[0][0] <= ack:
				pending.pop_front()
			shown = position
			if predict:
				for p in pending:
					shown += p[1] * SPEED * p[2]
		else:
			# remote players: smooth toward latest server position
			# ponytail: exponential smoothing, not a snapshot buffer; upgrade if it looks mushy
			shown = shown.lerp(position, 1.0 - exp(-20.0 * delta))
		queue_redraw()
	func _draw() -> void:
		var o := shown - position
		draw_rect(Rect2(o + Vector2(-16, -16), Vector2(32, 32)), Color.WHITE)
		for i in hp:
			draw_rect(Rect2(o + Vector2(-16 + i * 12, -30), Vector2(8, 6)), Color.WHITE)

class Bullet extends Node2D:
	var vel := Vector2.ZERO  # clients simulate from spawn data; server despawns
	var owner_id := 0
	var life := 2.0
	func _process(delta: float) -> void:
		position += vel * delta
		life -= delta
		if life <= 0 and multiplayer.is_server():
			queue_free()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 5, Color.YELLOW)

@rpc("any_peer", "reliable")
func chat_send(text: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1  # local call from host
	var p = get_node_or_null(str(id))
	chat_show.rpc("%s: %s" % [p.pname if p else str(id), text.left(200)])

@rpc("authority", "call_local", "reliable")
func chat_show(msg: String) -> void:
	log_label.text += msg + "\n"

func _clean(nm: String, id: int) -> String:
	nm = nm.strip_edges().left(12)
	return nm if nm != "" else "P%d" % id

func _players() -> Array:
	var out := []
	for p in get_children():
		if p is Player and not p.is_queued_for_deletion():
			out.append(p)
	return out

@rpc("any_peer", "reliable")
func register(nm: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if get_node_or_null(str(id)):
		return  # already registered
	print("player joined: %s (%d)" % [_clean(nm, id), id])
	player_spawner.spawn([id, _clean(nm, id)])
	set_phase.rpc_id(id, phase)  # late joiners learn the current phase

@rpc("authority", "call_local", "reliable")
func set_phase(ph: String) -> void:
	phase = ph

@rpc("any_peer", "reliable")
func toggle_ready() -> void:
	if not multiplayer.is_server() or phase != "lobby":
		return
	var id := multiplayer.get_remote_sender_id()
	var p = get_node_or_null(str(id if id != 0 else 1))
	if p:
		p.is_ready = not p.is_ready
		_check_start()

func _check_start() -> void:
	var ps := _players()
	if phase != "lobby" or ps.size() < 2:
		return
	for p in ps:
		if not p.is_ready:
			return
	for p in ps:
		p.hp = 3
		p.score = 0
	set_phase.rpc("playing")
	chat_show.rpc("Round start! First to %d kills wins." % WIN)

func _end_round(winner) -> void:
	if winner:
		chat_show.rpc("%s wins!" % winner.pname)
	for p in _players():
		p.is_ready = false
		p.hp = 3
	set_phase.rpc("lobby")

func _on_peer_left(id: int) -> void:
	var n = get_node_or_null(str(id))
	if n:
		n.queue_free()
	if phase == "playing" and _players().size() < 2:
		_end_round(null)
	else:
		_check_start()

func _on_failed() -> void:
	msg = "Could not connect to host"
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _on_lost() -> void:
	msg = "Host disconnected"
	for n in get_children() + $Bullets.get_children():
		if n is Player or n is Bullet:
			n.queue_free()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

@rpc("any_peer", "reliable")
func fire(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	var p = get_node_or_null(str(id))
	var now := Time.get_ticks_msec()
	if phase != "playing" or p == null or dir.length() < 0.01 or now - p.last_fire < 250:  # server-side cooldown
		return
	p.last_fire = now
	next_bullet += 1
	bullet_spawner.spawn([next_bullet, p.position, dir.normalized() * 500.0, id])

func _hit(p, killer: int) -> void:
	p.hp -= 1
	if p.hp <= 0:
		p.hp = 3
		p.position = Vector2(100 + randi() % 400, 100 + randi() % 300)
		var k = get_node_or_null(str(killer))
		if k:
			k.score += 1
			if k.score >= WIN:
				_end_round(k)

func _connect(target: String) -> void:
	if target.begins_with("ws://") or target.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		ws.create_client(target)
		multiplayer.multiplayer_peer = ws
	else:
		var peer := ENetMultiplayerPeer.new()
		peer.create_client(target, PORT)
		multiplayer.multiplayer_peer = peer

func _discovery(delta: float) -> void:
	if announcer:
		announce_t += delta
		if announce_t >= 1.0:
			announce_t = 0.0
			# ponytail: 255.255.255.255 uses the default interface only; per-interface broadcast if multi-homed
			announcer.put_packet(("godotmp|%s" % (my_name if my_name != "" else "host")).to_utf8_buffer())
	if finder:
		if finder.get_available_packet_count() > 0:
			var data := finder.get_packet().get_string_from_utf8()
			var ip := finder.get_packet_ip()
			if data.begins_with("godotmp|"):
				print("found host %s at %s" % [data.substr(8), ip])
				finder.close()
				finder = null
				msg = ""
				_connect(ip)
		elif Time.get_ticks_msec() > find_deadline:
			finder.close()
			finder = null
			msg = "No host found on LAN (try --join <ip>)"

func _process(delta: float) -> void:
	_discovery(delta)
	var players := _players()
	var lines := []
	for p in players:
		lines.append("%s  hp %d  score %d%s" % [p.pname, p.hp, p.score, "  READY" if p.is_ready and phase == "lobby" else ""])
	hud.text = "\n".join(lines)
	if msg != "":
		status.text = msg
	elif phase == "lobby":
		status.text = "LOBBY - press R to ready (need 2+ players)"
	else:
		status.text = ""
	if not multiplayer.is_server() or phase != "playing":
		return
	for b in $Bullets.get_children():
		if b.is_queued_for_deletion():
			continue
		for p in players:
			if p.name.to_int() != b.owner_id and b.position.distance_to(p.position) < 22:
				b.queue_free()
				_hit(p, b.owner_id)
				break

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ENTER:
		line.grab_focus()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		if multiplayer.is_server():
			toggle_ready()
		else:
			toggle_ready.rpc_id(1)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		line.release_focus()
		var me = get_node_or_null(str(multiplayer.get_unique_id()))
		if me == null:
			return
		var dir: Vector2 = get_global_mouse_position() - me.shown
		if multiplayer.is_server():
			fire(dir)
		else:
			fire.rpc_id(1, dir)

func _on_submit(text: String) -> void:
	line.clear()
	line.release_focus()
	if text.strip_edges() == "":
		return
	if multiplayer.is_server():
		chat_send(text)
	else:
		chat_send.rpc_id(1, text)

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	log_label = Label.new()
	log_label.position = Vector2(8, 8)
	ui.add_child(log_label)
	line = LineEdit.new()
	line.placeholder_text = "Enter to chat"
	line.position = Vector2(8, 560)
	line.custom_minimum_size.x = 400
	line.text_submitted.connect(_on_submit)
	ui.add_child(line)

	hud = Label.new()
	hud.position = Vector2(900, 8)
	ui.add_child(hud)
	var bullets := Node2D.new()
	bullets.name = "Bullets"
	add_child(bullets)
	bullet_spawner = MultiplayerSpawner.new()
	bullet_spawner.name = "BulletSpawner"
	add_child(bullet_spawner)
	bullet_spawner.spawn_path = ^"../Bullets"
	bullet_spawner.spawn_function = func(d: Array) -> Node:
		var b := Bullet.new()
		b.name = "b%d" % d[0]
		b.position = d[1]
		b.vel = d[2]
		b.owner_id = d[3]
		return b

	status = Label.new()
	status.position = Vector2(380, 280)
	ui.add_child(status)

	player_spawner = MultiplayerSpawner.new()
	player_spawner.name = "Spawner"
	add_child(player_spawner)
	player_spawner.spawn_path = ^".."
	player_spawner.spawn_function = func(d: Array) -> Node:
		var p := Player.new()
		p.name = str(d[0])
		p.pname = d[1]
		p.position = Vector2(100 + randi() % 400, 100 + randi() % 300)
		return p
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--name="):
			my_name = a.substr(7)
	if "--host" in args or "--server" in args:
		var peer: MultiplayerPeer = WebSocketMultiplayerPeer.new() if "--ws" in args else ENetMultiplayerPeer.new()
		peer.create_server(PORT)
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_disconnected.connect(_on_peer_left)
		if "--server" in args:
			print("dedicated server listening on %s %d" % ["TCP (WebSocket)" if "--ws" in args else "UDP", PORT])
		else:
			player_spawner.spawn([1, _clean(my_name, 1)])
		announcer = PacketPeerUDP.new()
		announcer.set_broadcast_enabled(true)
		announcer.set_dest_address("255.255.255.255", DISC_PORT)
	elif "--join" in args or OS.has_feature("web"):
		multiplayer.connected_to_server.connect(func(): register.rpc_id(1, my_name))
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_lost)
		var target := ""  # "" = discover on LAN
		if OS.has_feature("web"):
			target = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''"))
			my_name = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('name') || ''"))
		else:
			var i := args.find("--join")
			if args.size() > i + 1 and not args[i + 1].begins_with("--"):
				target = args[i + 1]
		if target != "":
			_connect(target)
		elif OS.has_feature("web"):
			msg = "Add ?server=wss://your-host to the page URL"  # browsers can't do UDP discovery
		else:
			finder = PacketPeerUDP.new()
			finder.bind(DISC_PORT)
			find_deadline = Time.get_ticks_msec() + 10000
			msg = "Searching for host on LAN..."
