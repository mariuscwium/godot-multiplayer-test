class_name Protocol extends RefCounted
# Wire format. Snapshots are small flat int arrays (positions fixed-point, px * 16).

const FP := 16.0
const TANK_INTS := 9
const BULLET_INTS := 6
const POWERUP_INTS := 5

static func encode_snapshot(sim: Sim) -> Array:
	var tanks := PackedInt32Array()
	for t in sim.tanks.values():
		var flags := (1 if t.alive else 0) | (2 if t.shield_t > 0.0 else 0) | (clampi(t.hp, 0, 7) << 2)
		tanks.append_array([t.id, roundi(t.pos.x * FP), roundi(t.pos.y * FP), t.facing, flags,
			t.stars, t.kills, t.ack_seq, roundi(t.slide_t * 1000.0)])
	var bullets := PackedInt32Array()
	for b in sim.bullets:
		bullets.append_array([b.id, roundi(b.pos.x * FP), roundi(b.pos.y * FP), b.dir, b.owner, 1 if b.stars >= 1 else 0])
	var powerups := PackedInt32Array()
	for p in sim.powerups:
		powerups.append_array([p.id, roundi(p.pos.x * FP), roundi(p.pos.y * FP), p.type, roundi(p.ttl * 1000.0)])
	return [sim.tick, tanks, bullets, powerups, sim.map_rev]

static func decode_snapshot(a: Array) -> Dictionary:
	var out := {"tick": a[0], "tanks": {}, "bullets": [], "powerups": [], "rev": a[4]}
	var t: PackedInt32Array = a[1]
	for i in range(0, t.size(), TANK_INTS):
		out.tanks[t[i]] = {
			"pos": Vector2(t[i + 1], t[i + 2]) / FP, "facing": t[i + 3],
			"alive": (t[i + 4] & 1) != 0, "shield": (t[i + 4] & 2) != 0, "hp": (t[i + 4] >> 2) & 7,
			"stars": t[i + 5], "kills": t[i + 6], "ack": t[i + 7], "slide": t[i + 8] / 1000.0,
		}
	var b: PackedInt32Array = a[2]
	for i in range(0, b.size(), BULLET_INTS):
		out.bullets.append({"id": b[i], "pos": Vector2(b[i + 1], b[i + 2]) / FP, "dir": b[i + 3],
			"owner": b[i + 4], "fast": b[i + 5] != 0})
	var p: PackedInt32Array = a[3]
	for i in range(0, p.size(), POWERUP_INTS):
		out.powerups.append({"id": p[i], "pos": Vector2(p[i + 1], p[i + 2]) / FP, "type": p[i + 3], "ttl": p[i + 4] / 1000.0})
	return out

static func encode_roster(sim: Sim) -> Dictionary:
	var r := {}
	for t in sim.tanks.values():
		r[t.id] = t.name
	return r

static func clean_name(raw: String, id: int) -> String:
	raw = raw.left(64)   # bound the work: a hostile client can send megabytes
	var s := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c >= 32 and c != 127:
			s += raw[i]
	s = s.strip_edges().left(12).strip_edges()
	return s if s != "" else "P%d" % id
