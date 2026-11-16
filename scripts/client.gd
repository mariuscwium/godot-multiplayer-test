class_name Client extends Node2D
# Joins a Server (or is attached to a local one with --host), predicts only the local tank,
# interpolates everyone else. Drawing lives in Render/Hud children added by main.gd.

const VIEW_PX := 208.0     # world px visible vertically (26 cells, like the original screen)

var net: Net
var local_server           # Server in the same process (--host); then no RPC and no prediction
var my_name := ""
var my_id := 0
var map: GameMap
var roster := {}           # id -> name
var view := {}             # latest decoded snapshot
var snap_ms := 0
var welcomed := false
var msg := ""              # connection problems / status for the HUD
var feed: Array = []       # [text, expires_ms] kill feed
var shown := {}            # id -> smoothed position of remote tanks
var my_pos := Vector2.ZERO
var my_facing := Cfg.Dir.UP
var my_slide := 0.0
var seq := 0
var pending: Array = []    # [seq, dir] sent but not yet acked
var lag_ms := 0
var loss := 0.0
var predict := true
var bot := false
var cam: Camera2D
var _queue: Array = []
var _held: Array = []      # direction keys in press order; last pressed wins

# Server state + replay of inputs the server has not acked yet.
static func reconcile(map_: GameMap, server_pos: Vector2, facing: int, slide: float, pending_: Array, ack: int) -> Dictionary:
	var pos := server_pos
	var f := facing
	var s := slide
	var rest := []
	for p in pending_:
		if p[0] <= ack:
			continue
		rest.append(p)
		var r := TankMotion.step(map_, pos, f, p[1], s, 1.0 / Cfg.TICK_HZ)
		pos = r.pos
		f = r.facing
		s = r.slide_t
	return {"pos": pos, "facing": f, "slide": s, "pending": rest}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lag="): lag_ms = int(a.substr(6))
		if a.begins_with("--loss="): loss = float(a.substr(7))
		if a == "--nopredict": predict = false
		if a == "--bot": bot = true
	cam = Camera2D.new()
	add_child(cam)

func connect_to(target: String) -> void:
	msg = "Connecting..."
	multiplayer.connected_to_server.connect(func(): net.register.rpc_id(1, my_name))
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_lost)
	if target.begins_with("ws://") or target.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		ws.create_client(target)
		multiplayer.multiplayer_peer = ws
	else:
		var peer := ENetMultiplayerPeer.new()
		peer.create_client(target, Cfg.PORT)
		multiplayer.multiplayer_peer = peer

func start_local(server) -> void:
	local_server = server
	server.local_client = self
	server.on_register(1, my_name)

func _on_failed() -> void:
	msg = "Could not connect to host"
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _on_lost() -> void:
	msg = "Host disconnected"
	welcomed = false
	view = {}
	shown.clear()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func on_welcome(info: Dictionary) -> void:
	map = GameMap.from_bytes(info.w, info.h, info.grid)
	roster = info.roster
	my_id = info.you
	welcomed = true
	msg = ""
	seq = 0
	pending.clear()
	_queue.clear()
	view = Protocol.decode_snapshot(info.snap)
	var me: Dictionary = view.tanks.get(my_id, {})
	if not me.is_empty():
		my_pos = me.pos
		my_facing = me.facing
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map.w * Cfg.CELL
	cam.limit_bottom = map.h * Cfg.CELL
	print("connected as %d (map %dx%d)" % [my_id, map.w, map.h])

func on_snapshot(snap: Array) -> void:
	if not welcomed:
		return
	view = Protocol.decode_snapshot(snap)
	snap_ms = Time.get_ticks_msec()
	var me: Dictionary = view.tanks.get(my_id, {})
	if me.is_empty():
		return
	if not me.alive:
		pending.clear()
		my_pos = me.pos
		my_facing = me.facing
		my_slide = 0.0
		return
	var r := reconcile(map, me.pos, me.facing, me.slide, pending, me.ack)
	pending = r.pending
	if predict and local_server == null:
		my_pos = r.pos
		my_facing = r.facing
		my_slide = r.slide
	else:
		my_pos = me.pos
		my_facing = me.facing
		my_slide = me.slide

func on_events(events: Array) -> void:
	if not welcomed:
		return
	for e in events:
		match e.k:
			"cells":
				for c in e.c:
					map.set_cell(c[0], c[1], c[2])
			"kill":
				feed.append(["%s > %s" % [roster.get(e.killer, "?"), roster.get(e.victim, "?")], Time.get_ticks_msec() + 5000])
			"join":
				roster[e.id] = e.name
			"leave":
				roster.erase(e.id)
				shown.erase(e.id)

func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		var d := Cfg.NONE
		match e.keycode:
			KEY_UP, KEY_W: d = Cfg.Dir.UP
			KEY_RIGHT, KEY_D: d = Cfg.Dir.RIGHT
			KEY_DOWN, KEY_S: d = Cfg.Dir.DOWN
			KEY_LEFT, KEY_A: d = Cfg.Dir.LEFT
		if d != Cfg.NONE:
			_held.erase(d)
			if e.pressed:
				_held.append(d)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_held.clear()

func _read_input() -> Dictionary:
	if bot:
		return {"dir": Cfg.Dir.RIGHT, "fire": true}  # replaced by Bot in a later task
	var fire := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return {"dir": _held.back() if not _held.is_empty() else Cfg.NONE, "fire": fire}

func _physics_process(_delta: float) -> void:
	if not welcomed:
		return
	var inp := _read_input()
	seq += 1
	var dir: int = inp.dir
	if local_server == null:
		pending.append([seq, dir])
		if pending.size() > 300:
			pending.pop_front()
		var me: Dictionary = view.tanks.get(my_id, {})
		if predict and (me.is_empty() or me.alive):
			var r := TankMotion.step(map, my_pos, my_facing, dir, my_slide, 1.0 / Cfg.TICK_HZ)
			my_pos = r.pos
			my_facing = r.facing
			my_slide = r.slide_t
		_send_delayed(seq, dir, inp.fire)
	else:
		local_server.on_input(1, seq, dir, inp.fire)

# --lag=ms / --loss=0..1 fake the client->server path for testing
func _send_delayed(s: int, dir: int, fire: bool) -> void:
	var now := Time.get_ticks_msec()
	_queue.append([now + lag_ms, s, dir, fire])
	while not _queue.is_empty() and _queue[0][0] <= now:
		var q: Array = _queue.pop_front()
		if randf() >= loss:
			net.input.rpc_id(1, q[1], q[2], q[3])

func _process(delta: float) -> void:
	if not welcomed:
		return
	for id in view.tanks:
		if id == my_id:
			continue
		var target: Vector2 = view.tanks[id].pos
		if not shown.has(id) or shown[id].distance_to(target) > 64.0:
			shown[id] = target
		else:
			shown[id] = shown[id].lerp(target, 1.0 - exp(-20.0 * delta))
	for id in shown.keys():
		if not view.tanks.has(id):
			shown.erase(id)
	var now := Time.get_ticks_msec()
	feed = feed.filter(func(f): return f[1] > now)
	cam.position = my_pos + Vector2(Cfg.TANK_PX, Cfg.TANK_PX) * 0.5
	var z := get_viewport_rect().size.y / VIEW_PX
	cam.zoom = Vector2(z, z)
