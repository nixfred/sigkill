class_name PacketTracerHud
extends CanvasLayer
## The packet tracer's HUD (W5): a panel where a mission's would stand, its heart the trace itself as traceroute prints it
## (the target, every hop reached and its time, a "* * *" for every packet lost on the way), then where the player is
## (the hop and its daemons, the route up, the ride and how far along), the link out and its state, the run's numbers and
## the last few events; a banner for each hop reached and for what goes wrong (a stale route's misroute, an intercept, a
## packet lost, a retransmit), stacked under the ride's own state (INTERCEPTED, TIMEOUT, RST, BURST) at the top of the
## screen, each on its own plate, two at most and never over each other or over the crosshair (P2); on a ride the screen's speed lines (shaders/net_speed.gdshader), and while the link under
## it goes bad a vignette and TIMEOUT with the burst's key; the results card at the end. Reads only the mode.

const Palette = preload("res://scripts/palette.gd")
const SpeedShader = preload("res://shaders/net_speed.gdshader")
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 430.0
const COMPACT_W := 1280.0
const LINE := 17.0
const ALPHA := 0.82
const TITLE := "PACKET TRACER"
const CHIP := "invented network"
const BANNER_S := 2.2
const AMBER := Color(1.0, 0.62, 0.12)
const RST := Color(1.0, 0.2, 0.25)
## The banner stack (P2): its top, as a share of the screen's height; the gap between two plates; the smallest a line is
## shrunk to so it fits its panel (never cut off).
const STACK_AT := 0.16
const STACK_GAP := 8.0
const FIT_MOST := 10

var mode: PacketTracer = null
var _view: Control
var _speed: ColorRect
var _speed_mat: ShaderMaterial
var _font: Font
var _banner := {}
## Frames the speed lines are drawn at nothing as the HUD comes up, so their shader is ready before the first ride.
var _warm := 3


func _ready() -> void:
	layer = 0  # under the HUD's own layer, so the Esc menu is over it (as the other world modes')
	_font = Palette.mono_font()
	_speed_mat = ShaderMaterial.new()
	_speed_mat.shader = SpeedShader
	_speed = ColorRect.new()
	_speed.name = "SpeedLines"
	_speed.material = _speed_mat
	_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed.visible = false
	add_child(_speed)
	_view = Control.new()
	_view.name = "PacketView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)
	if mode != null:
		mode.event.connect(_on_event)


## The banner's head up now, or "" (the checks).
func banner_head() -> String:
	return str(_banner.get("head", ""))


func _on_event(kind: String, text: String) -> void:
	match kind:
		"hop":
			var hop: int = mode.at_island
			var id: String = mode.net.islands[hop]["id"] if mode.net != null else ""
			_banner = {"head": "HOP %d   %s" % [hop, id], "sub": "%s   %s" % [NetBook.address(NetBook.machine(id)), str(NetBook.machine(id).get("motto", ""))], "color": NetBook.machine(id).get("accent", Palette.TEAL), "t": 0.0}
		"stale":
			if text.begins_with("stale route: sent"):
				_banner = {"head": "STALE ROUTE", "sub": text.trim_prefix("stale route: "), "color": Color(0.56, 0.63, 0.72), "t": 0.0}
		"intercepted":
			pass  # the ride's own line says INTERCEPTED while it is held (W5's two INTERCEPTED over each other, folded in W7)
		"lost":
			_banner = {"head": "* * *   PACKET LOST", "sub": text.trim_prefix("* * *  "), "color": RST, "t": 0.0}
		"retransmit":
			if text.begins_with("retransmitted"):
				_banner = {"head": "RETRANSMIT", "sub": text, "color": Palette.MINT, "t": 0.0}
		"dodged":
			_banner = {"head": "DROP DODGED", "sub": text, "color": Palette.LIME, "t": 0.0}
		"done":
			_banner = {"head": "TRACE COMPLETE", "sub": text, "color": Palette.TEAL, "t": 0.0}


func _process(delta: float) -> void:
	if not _banner.is_empty():
		_banner["t"] = float(_banner["t"]) + delta
		if float(_banner["t"]) > BANNER_S:
			_banner = {}
	var riding := mode != null and mode.running and not mode.ride.is_empty()
	if riding:
		var link: NetLink = mode.net.links[int(mode.ride["link"])]
		_speed.visible = true
		_speed_mat.set_shader_parameter("amount", 0.15 if bool(mode.ride["held"]) else (1.0 if float(mode.ride["burst"]) > 0.0 else 0.6))
		_speed_mat.set_shader_parameter("clock", mode.clock())
		_speed_mat.set_shader_parameter("tint", NetBook.color_of(link.proto))
		_speed_mat.set_shader_parameter("danger", 1.0 if link.unstable() else 0.0)
		_speed_mat.set_shader_parameter("danger_tint", RST if link.state == NetLink.State.DROPPED else AMBER)
	elif _warm > 0:
		_warm -= 1
		_speed.visible = true
		_speed_mat.set_shader_parameter("amount", 0.0)
		_speed_mat.set_shader_parameter("danger", 0.0)
	else:
		_speed.visible = false
	_view.queue_redraw()


## The trace as traceroute prints it: its head line, then a line a hop (a lost packet's "* * *").
func trace_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null:
		return out
	var target := NetBook.machine(NetBook.TARGET)
	out.append("traceroute to %s (%s), %d hops" % [NetBook.TARGET, NetBook.address(target), NetBook.hops()])
	for row in mode.trace:
		if int(row["hop"]) == 0:
			continue
		if bool(row["lost"]):
			out.append("%2d  * * *" % int(row["hop"]))
		else:
			out.append("%2d  %s (%s)  %.1f ms" % [int(row["hop"]), str(row["id"]), str(row["addr"]), float(row["ms"])])
	return out


## Every line the panel shows now, for the checks.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if mode == null or not mode.running:
		return out
	out.append(TITLE + "  " + CHIP)
	out.append_array(trace_lines())
	out.append(_where())
	var next := mode.next_link()
	if next != null and mode.phase != "ride":
		out.append("next: -> %s  %s  %s" % [next.to_id, NetBook.PROTOCOLS[next.proto]["label"], _state_word(next)])
	var s := PacketTracer.stats
	out.append("drops dodged %d  taken %d   kills %d   %s" % [int(s.get("dodged", 0)), int(s.get("taken", 0)), int(s.get("kills", 0)), _clock_text(float(s.get("time", 0.0)))])
	return out


func _where() -> String:
	var id: String = mode.net.islands[mode.at_island]["id"] if mode.net != null else ""
	match mode.phase:
		"island":
			return "HOP %d  %s   %d daemons hold the route" % [mode.at_island, id, mode.standing_on(id)]
		"clear":
			if id == NetBook.TARGET:
				return "HOP %d  %s" % [mode.at_island, id]
			return "ROUTE UP   step onto the port to %s" % NetBook.LINKS[NetBook.forward_from(id)][1]
		"ride":
			var link: NetLink = mode.net.links[int(mode.ride["link"])]
			var held := "  HELD" if bool(mode.ride["held"]) else ""  # the stack's INTERCEPTED says why (P2: said once, and it fits)
			return "RIDING  %s -> %s  %s  %d%%%s" % [mode.ride["from"], mode.ride["to"], NetBook.PROTOCOLS[link.proto]["label"], int(float(mode.ride["u"]) * 100.0), held]
		"fall":
			return "PACKET LOST   retransmitting"
		"done", "results":
			return "TRACE COMPLETE"
	return ""


static func _state_word(link: NetLink) -> String:
	match link.state:
		NetLink.State.DOWN:
			return "NO ROUTE"
		NetLink.State.SYN:
			return "SYN"
		NetLink.State.UP:
			return "UP"
		NetLink.State.FLAKY:
			return "TIMEOUT"
		NetLink.State.DROPPED:
			return "DROPPED"
	return ""


## The results card's lines (the checks): the trace, then the run's numbers.
func result_lines() -> PackedStringArray:
	var out := trace_lines()
	var s := PacketTracer.stats
	out.append("")
	out.append("hops %d of %d   rides %d   bursts %d" % [int(s.get("hops", 0)), NetBook.hops(), int(s.get("rides", 0)), int(s.get("bursts", 0))])
	out.append("drops dodged %d   packets lost %d   falls %d" % [int(s.get("dodged", 0)), int(s.get("taken", 0)), int(s.get("falls", 0))])
	out.append("kills %d   misrouted %d   intercepted %d   time %s" % [int(s.get("kills", 0)), int(s.get("misrouted", 0)), int(s.get("intercepted", 0)), _clock_text(float(s.get("time", 0.0)))])
	return out


static func _clock_text(s: float) -> String:
	var whole := int(s)
	return "%d:%02d" % [whole / 60, whole % 60]


func _draw_view() -> void:
	if mode == null or not mode.running:
		return
	var v := _view
	var compact := v.size.x < COMPACT_W
	if mode.phase == "results":
		_draw_results(v, compact)
		return
	_draw_panel(v, compact)
	_draw_stack(v, compact)


func _draw_panel(v: Control, compact: bool) -> void:
	var main := lines()
	var notes: Array = mode.events.slice(maxi(mode.events.size() - (1 if compact else 2), 0))
	var accent := Palette.TEAL
	var w := PANEL_W if not compact else 360.0
	var h := 30.0 + LINE * (main.size() - 1) + 16.0 + LINE * notes.size() + 12.0
	var rect := Rect2(PANEL_AT, Vector2(w, h))
	v.draw_rect(rect, Color(Palette.VOID, ALPHA))
	v.draw_rect(Rect2(rect.position, Vector2(3, h)), accent)
	var scan := fposmod(mode.clock() * 0.35, 1.0)
	v.draw_rect(Rect2(rect.position + Vector2(3, h * scan), Vector2(w - 3, 1)), Color(accent, 0.12))
	var x := PANEL_AT.x + 14.0
	var y := PANEL_AT.y + 24.0
	v.draw_string(_font, Vector2(x, y), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	var cw := _font.get_string_size(CHIP, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var cx := PANEL_AT.x + w - cw - 12.0
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Color(Palette.MINT, 0.16))
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Palette.MINT, false, 1.0)
	v.draw_string(_font, Vector2(cx + 6, y), CHIP, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.MINT)
	var size := 12 if compact else 13
	for i in range(1, main.size()):
		y += LINE
		var line: String = main[i]
		var colour := Palette.MINT
		if line.begins_with("traceroute"):
			colour = Color(Palette.MINT, 0.7)
		elif line.contains("* * *"):
			colour = RST
		elif line.begins_with("HOP") or line.begins_with("RIDING") or line.begins_with("ROUTE UP") or line.begins_with("PACKET") or line.begins_with("TRACE"):
			y += 4
			colour = Palette.FLASH if not line.begins_with("PACKET") else RST
			if line.ends_with(" HELD"):
				colour = Color(0.86, 0.45, 1.0)
		elif line.begins_with("next:"):
			colour = Palette.LIME if line.ends_with(" UP") else (AMBER if line.ends_with("TIMEOUT") or line.ends_with("SYN") else (RST if line.ends_with("DROPPED") or line.ends_with("NO ROUTE") else Palette.MINT))
		elif line.begins_with("drops"):
			colour = Color(Palette.MINT, 0.8)
		v.draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(line, w - 24, size), colour)
		if line.begins_with("RIDING"):
			var u := clampf(float(mode.ride["u"]), 0.0, 1.0)
			v.draw_rect(Rect2(x, y + 5, (w - 28), 2), Color(accent, 0.25))
			v.draw_rect(Rect2(x, y + 5, (w - 28) * u, 2), Palette.FLASH)
	y += 8.0
	v.draw_rect(Rect2(x, y, w - 28, 1), Color(accent, 0.3))
	for e in notes:
		y += LINE
		var age: float = mode.clock() - float(e["t"])
		v.draw_string(_font, Vector2(x, y), str(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(str(e["text"]), w - 24, 12), Color(Palette.MINT, clampf(1.2 - age / 12.0, 0.4, 1.0)))


## The font size `size` shrunk (to FIT_MOST at the least) until `text` fits `width`: a panel line is never cut off.
func _fit(text: String, width: float, size: int) -> int:
	var n := size
	while n > FIT_MOST and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > width:
		n -= 1
	return n


## On a ride, its state now: INTERCEPTED while it is held, the link going bad (TIMEOUT, the burst's key while it is still
## to spend), RST, BURST; else {}. Pulses while it lasts.
func _ride_entry() -> Dictionary:
	if mode == null or mode.ride.is_empty():
		return {}
	var link: NetLink = mode.net.links[int(mode.ride["link"])]
	if bool(mode.ride["held"]):
		return {"head": "INTERCEPTED", "sub": "shoot the man in the middle", "color": Color(0.86, 0.3, 1.0), "alpha": 1.0, "pulse": true}
	if link.state == NetLink.State.FLAKY:
		var sub := "[Space] burst through" if int(mode.ride["bursts"]) == 0 else "bursting"
		return {"head": "TIMEOUT %.1f" % maxf(NetLink.FLAKY_S - link.state_t, 0.0), "sub": sub, "color": AMBER, "alpha": 1.0, "pulse": true}
	if link.state == NetLink.State.DROPPED:
		return {"head": "RST", "sub": "the link is tearing", "color": RST, "alpha": 1.0, "pulse": true}
	if float(mode.ride["burst"]) > 0.0:
		return {"head": "BURST", "sub": "", "color": Palette.FLASH, "alpha": 1.0, "pulse": true}
	return {}


## The event banner now (a hop, a misroute, a lost packet...), fading in and out over BANNER_S; else {}.
func _event_entry() -> Dictionary:
	if _banner.is_empty():
		return {}
	var t := float(_banner["t"])
	return {"head": str(_banner["head"]), "sub": str(_banner["sub"]), "color": _banner["color"], "alpha": clampf(minf(t / 0.2, (BANNER_S - t) / 0.5), 0.0, 1.0), "pulse": false}


## The banner stack on a screen of `size` (P2): the ride's state first, then the event banner, each on its own plate
## under the last, two at most, so a man in the middle's INTERCEPTED and a hop's banner never pile over each other or
## over the target. Each entry: head, sub, color, alpha, pulse, big (its head's size), rect (its plate).
func layout(size: Vector2, compact: bool) -> Array:
	var out: Array = []
	var big := 26 if compact else 40
	var y := size.y * STACK_AT
	for e in [_ride_entry(), _event_entry()]:
		if e.is_empty() or (not out.is_empty() and out[0]["head"] == e["head"]):
			continue
		var hw := _font.get_string_size(e["head"], HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var sw := _font.get_string_size(e["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x if e["sub"] != "" else 0.0
		var w := maxf(hw, sw) + 56.0
		var h := big + (52.0 if e["sub"] != "" else 22.0)
		e["big"] = big
		e["rect"] = Rect2(Vector2((size.x - w) * 0.5, y), Vector2(w, h))
		out.append(e)
		y += h + STACK_GAP
		big = 24 if compact else 30  # the second plate a step smaller: the ride's state leads
	return out


## The heads the stack shows now, top first (the checks).
func stack_heads() -> PackedStringArray:
	var out := PackedStringArray()
	if _view == null:
		return out
	for e in layout(_view.size, _view.size.x < COMPACT_W):
		out.append(e["head"])
	return out


func _draw_stack(v: Control, compact: bool) -> void:
	for e in layout(v.size, compact):
		var rect: Rect2 = e["rect"]
		var a := float(e["alpha"])
		var accent: Color = e["color"]
		var big := int(e["big"])
		var glow := (0.75 + 0.25 * sin(mode.clock() * 14.0)) if bool(e["pulse"]) else 1.0
		var hw := _font.get_string_size(e["head"], HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		v.draw_rect(rect, Color(Palette.VOID, 0.72 * a))
		v.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(accent, a))
		var hx := rect.position.x + (rect.size.x - hw) * 0.5
		var hy := rect.position.y + big + 6.0
		v.draw_string(_font, Vector2(hx + 3, hy + 3), e["head"], HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(Palette.VOID, 0.8 * a))
		v.draw_string(_font, Vector2(hx, hy), e["head"], HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(accent.lerp(Color.WHITE, 0.2), a * glow))
		if e["sub"] != "":
			var sw := _font.get_string_size(e["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			v.draw_string(_font, Vector2(rect.position.x + (rect.size.x - sw) * 0.5, hy + 30.0), e["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.MINT.lerp(accent, 0.25), a))


func _draw_results(v: Control, compact: bool) -> void:
	var rows := result_lines()
	var size := 15 if not compact else 11
	var lh := size + 9.0
	var w := 0.0
	for r in rows:
		w = maxf(w, _font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w = maxf(w, 520.0) + 48.0
	var h := 78.0 + lh * rows.size() + 60.0
	var at := Vector2((v.size.x - w) * 0.5, (v.size.y - h) * 0.5)
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.VOID, 0.88))
	v.draw_rect(Rect2(at, Vector2(w, h)), Color(Palette.TEAL, 0.9), false, 2.0)
	v.draw_rect(Rect2(at, Vector2(w, 3)), Palette.TEAL)
	v.draw_string(_font, at + Vector2(24, 40), "TRACE COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, size + 10, Palette.TEAL)
	v.draw_string(_font, at + Vector2(24, 62), "every machine and address here is made up; no packet left this game", HORIZONTAL_ALIGNMENT_LEFT, w - 48, size - 3, Color(Palette.MINT, 0.7))
	var y := at.y + 96.0
	for i in rows.size():
		var line: String = rows[i]
		var colour := Palette.MINT
		if i == 0:
			colour = Color(Palette.MINT, 0.75)
		elif line.contains("* * *"):
			colour = RST
		elif line.begins_with("hops") or line.begins_with("drops") or line.begins_with("kills"):
			colour = Palette.FLASH
		v.draw_string(_font, Vector2(at.x + 24, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		y += lh
	v.draw_string(_font, Vector2(at.x + 24, y + 14), "[Enter] trace it again    [Esc] menu", HORIZONTAL_ALIGNMENT_LEFT, -1, size - 2, Palette.HOSTILE_AMBER)
