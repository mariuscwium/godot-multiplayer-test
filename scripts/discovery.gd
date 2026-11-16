class_name Discovery extends Node
# LAN discovery over UDP broadcast: hosts announce once a second, clients listen.

signal found(ip: String)
signal timed_out

const DISC_PORT := 7778

var host_name := ""
var _announcer: PacketPeerUDP
var _announce_t := 0.0
var _finder: PacketPeerUDP
var _deadline := 0

static func make_packet(name_: String) -> String:
	return "godotmp|%s" % (name_ if name_ != "" else "host")

static func parse_packet(data: String) -> String:
	return data.substr(8) if data.begins_with("godotmp|") else ""

func start_announcing(name_: String) -> void:
	host_name = name_
	_announcer = PacketPeerUDP.new()
	_announcer.set_broadcast_enabled(true)
	_announcer.set_dest_address("255.255.255.255", DISC_PORT)

func start_finding(timeout_ms := 10000) -> void:
	_finder = PacketPeerUDP.new()
	_finder.bind(DISC_PORT)
	_deadline = Time.get_ticks_msec() + timeout_ms

func _process(delta: float) -> void:
	if _announcer:
		_announce_t += delta
		if _announce_t >= 1.0:
			_announce_t = 0.0
			# ponytail: 255.255.255.255 uses the default interface only; per-interface broadcast if multi-homed
			_announcer.put_packet(make_packet(host_name).to_utf8_buffer())
	if _finder:
		if _finder.get_available_packet_count() > 0:
			var data := _finder.get_packet().get_string_from_utf8()
			var ip := _finder.get_packet_ip()
			if parse_packet(data) != "":
				print("found host %s at %s" % [parse_packet(data), ip])
				_finder.close()
				_finder = null
				found.emit(ip)
		elif Time.get_ticks_msec() > _deadline:
			_finder.close()
			_finder = null
			timed_out.emit()
