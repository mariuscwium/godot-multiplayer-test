class_name Net extends Node
# All RPC entry points live here: Godot needs the same RPC set on both peers, so Server and
# Client are plain logic nodes that this node forwards to (whichever exist in this process).

var server   # Server, when this process runs one
var client   # Client, when this process has one

@rpc("any_peer", "reliable")
func register(nm: Variant) -> void:
	if server:
		server.on_register(multiplayer.get_remote_sender_id(), nm)

@rpc("any_peer", "unreliable_ordered")
func input(seq: Variant, dir: Variant, fire: Variant) -> void:
	if server:
		server.on_input(multiplayer.get_remote_sender_id(), seq, dir, fire)

@rpc("authority", "reliable")
func c_welcome(info: Dictionary) -> void:
	if client:
		client.on_welcome(info)

@rpc("authority", "unreliable_ordered")
func c_snapshot(snap: Array) -> void:
	if client:
		client.on_snapshot(snap)

@rpc("authority", "reliable")
func c_events(events: Array) -> void:
	if client:
		client.on_events(events)
