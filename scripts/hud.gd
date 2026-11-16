class_name Hud extends CanvasLayer
# Leaderboard, your status, kill feed, respawn banner and connection messages.

var client: Client
var board: Label
var mine: Label
var feed: Label
var banner: Label
var status: Label
var _death_ms := 0
var _was_alive := true

func _label(size := 16) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l

func _ready() -> void:
	client = get_parent()
	board = _label()
	mine = _label()
	feed = _label(14)
	banner = _label(28)
	status = _label(22)
	feed.position = Vector2(8, 8)

func _process(_d: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	status.text = client.msg
	status.position = (vp - status.size) * 0.5
	if not client.welcomed:
		board.text = ""
		mine.text = ""
		banner.text = ""
		feed.text = ""
		return
	var ranked: Array = client.view.tanks.keys()
	ranked.sort_custom(func(a, b): return client.view.tanks[a].kills > client.view.tanks[b].kills)
	var lines := ["PLAYERS %d" % ranked.size()]
	for i in mini(5, ranked.size()):
		var id: int = ranked[i]
		lines.append("%d. %s  %d%s" % [i + 1, client.roster.get(id, "?"), client.view.tanks[id].kills, "  <" if id == client.my_id else ""])
	var my_rank: int = ranked.find(client.my_id)
	if my_rank >= 5:
		lines.append("%d. %s  %d  <" % [my_rank + 1, client.my_name, client.view.tanks[client.my_id].kills])
	board.text = "\n".join(lines)
	board.position = Vector2(vp.x - board.size.x - 8, 8)
	var me: Dictionary = client.view.tanks.get(client.my_id, {})
	mine.text = "" if me.is_empty() else "KILLS %d   STARS %d" % [me.kills, me.stars]
	mine.position = Vector2(8, vp.y - mine.size.y - 8)
	feed.text = "\n".join(client.feed.map(func(f): return f[0]))
	var alive: bool = me.is_empty() or me.alive
	if _was_alive and not alive:
		_death_ms = Time.get_ticks_msec()
	_was_alive = alive
	if alive:
		banner.text = ""
	else:
		var left := ceili(maxf(0.0, Cfg.RESPAWN_S - (Time.get_ticks_msec() - _death_ms) / 1000.0))
		banner.text = "DESTROYED - respawn in %d" % maxi(left, 1)
	banner.position = Vector2((vp.x - banner.size.x) * 0.5, vp.y * 0.4)
