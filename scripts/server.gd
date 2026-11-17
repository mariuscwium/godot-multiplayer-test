class_name Server extends Node
# Owns the Sim, ticks it at Cfg.TICK_HZ (project physics rate), and talks to clients through Net.

const MAX_SEQ_JUMP := 3000
const MAX_QUEUE := 4   # buffered inputs per client before we skip ahead

var sim: Sim
var net: Net
var local_client   # Client in the same process (--host), or null
var _last_seq := {}
# Inputs wait here and the server consumes exactly one per tick. The client predicts one step per input, so
# applying "the latest input once per tick" instead made the server skip or repeat a step whenever the two
# 30 Hz clocks slipped (or packets bunched up), which showed as a 2 px snap about once a second.
var _queue := {}
var _out: Array = []

static func take_input(q: Array) -> Dictionary:
	while q.size() > MAX_QUEUE:
		q.pop_front()   # client got ahead (stalled tab, burst): skip to the recent ones
	return q.pop_front() if not q.is_empty() else {}

static func sanitize_input(seq: Variant, dir: Variant, fire: Variant, last_seq: int) -> Dictionary:
	if typeof(seq) != TYPE_INT or typeof(dir) != TYPE_INT or typeof(fire) != TYPE_BOOL:
		return {}
	if dir < -1 or dir > 3 or seq <= last_seq or seq > last_seq + MAX_SEQ_JUMP:
		return {}
	return {"seq": seq, "dir": dir, "fire": fire}

func start(port: int, ws: bool) -> Error:
	sim = Sim.new(GameMap.from_text(FileAccess.get_file_as_string("res://maps/arena.txt")), randi())
	var peer: MultiplayerPeer = WebSocketMultiplayerPeer.new() if ws else ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	net.server = self
	return OK

func on_register(id: int, nm: Variant) -> void:
	if id == 0:
		id = 1
	if sim.tanks.has(id):
		return
	var name_ := Protocol.clean_name(nm if typeof(nm) == TYPE_STRING else "", id)
	sim.add_tank(id, name_)
	_last_seq[id] = 0
	_queue[id] = []
	print("joined: %s (%d)" % [name_, id])
	var info := build_welcome(id)
	if id == 1 and local_client:
		local_client.on_welcome(info)
	else:
		net.c_welcome.rpc_id(id, info)
	_out.append({"k": "join", "id": id, "name": name_})

func build_welcome(id: int) -> Dictionary:
	return {
		"you": id, "w": sim.map.w, "h": sim.map.h, "grid": sim.map.to_bytes(), "rev": sim.map_rev,
		"roster": Protocol.encode_roster(sim), "snap": Protocol.encode_snapshot(sim),
	}

# A client that noticed it missed terrain/roster events asks for the full state again.
func on_resync(id: int) -> void:
	if id != 0 and id != 1 and sim.tanks.has(id):
		print("resync: %s" % sim.tanks[id].name)
		net.c_welcome.rpc_id(id, build_welcome(id))

func on_input(id: int, seq: Variant, dir: Variant, fire: Variant) -> void:
	if id == 0:
		id = 1
	if not sim.tanks.has(id):
		return
	var r := sanitize_input(seq, dir, fire, _last_seq.get(id, 0))
	if r.is_empty():
		return
	_last_seq[id] = r.seq
	if id == 1 and local_client:
		sim.set_input(id, r.dir, r.fire, r.seq)   # same process: no network jitter to smooth
		return
	var q: Array = _queue.get(id, [])
	q.append(r)
	if q.size() > MAX_QUEUE * 4:
		q.pop_front()
	_queue[id] = q

func _on_left(id: int) -> void:
	var t: Sim.Tank = sim.tanks.get(id)
	if t == null:
		return
	print("left: %s" % t.name)
	sim.remove_tank(id)
	_last_seq.erase(id)
	_queue.erase(id)
	_out.append({"k": "leave", "id": id})

func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	for id in _queue:
		var r := take_input(_queue[id])
		if r.is_empty():
			var t: Sim.Tank = sim.tanks.get(id)   # nothing arrived this tick: hold still, ack unchanged
			if t:
				t.input_dir = Cfg.NONE
				t.input_fire = false
		else:
			sim.set_input(id, r.dir, r.fire, r.seq)
	sim.step(1.0 / Cfg.TICK_HZ)
	var events := sim.drain_events() + _out
	_out = []
	for e in events:
		if e.k == "kill":
			print("kill: %s -> %s" % [_name_of(e.killer), _name_of(e.victim)])
	var snap := Protocol.encode_snapshot(sim)
	if not multiplayer.get_peers().is_empty():
		if not events.is_empty():
			net.c_events.rpc(events)
		net.c_snapshot.rpc(snap)
	if local_client:
		if not events.is_empty():
			local_client.on_events(events)
		local_client.on_snapshot(snap)

func _name_of(id: int) -> String:
	var t: Sim.Tank = sim.tanks.get(id)
	return t.name if t else "#%d" % id
