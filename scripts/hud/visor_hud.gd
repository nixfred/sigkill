class_name VisorHud
extends Control
## The Audit Trail visor's HUD (C43, scripts/visor/audit_visor.gd), while the visor is on: its header at the top's middle
## ("AUDIT TRAIL", how many processes, whose data) over the feature's credit, "visor design: @QuantaCortex" (PRD 5.8),
## thin brackets at the screen's corners, and a tag on each process drawn. Never a wall of text: the one nearest the
## crosshair opens in full (PID and name, its state, then its parent's PID, CPU and memory), the NEAR_MOST nearest
## after it show a line, the rest only their PIDs, far ones nothing; a tag that would cover another steps down a size
## or is left out. init, the hidden parent and the jobs are tagged with their names. Draws only; it reads nothing.

const Palette = preload("res://scripts/palette.gd")

const HEADER := "AUDIT TRAIL"
const FOCUS_PX := 120.0
const NEAR_M := 26.0
const NEAR_MOST := 4
const FAR_M := 85.0
const DEMO_WORD := "demo data"
const REAL_WORD := "this machine, read-only"
enum Size { FULL, LINE, PID }

var visor: AuditVisor = null
## What it drew last, for the checks: the header's lines and every tag's text.
var drawn_tags := PackedStringArray()
var drawn_header := PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var up := visor != null and is_instance_valid(visor) and visor.on
	if visible != up:
		visible = up
	if up:
		queue_redraw()
	elif not drawn_tags.is_empty() or not drawn_header.is_empty():
		drawn_tags.clear()
		drawn_header.clear()


## The credit while the visor is on, else "".
func credit_text() -> String:
	return AuditVisor.CREDIT if visible and visor != null and visor.on else ""


func _draw() -> void:
	drawn_tags.clear()
	drawn_header.clear()
	if visor == null or not is_instance_valid(visor) or not visor.on:
		return
	var k := size.y / 1080.0
	var hue := visor.hue()
	var font := Palette.mono_font()
	_corners(k, hue)
	var all := visor.tags()
	var procs := 0
	for t in all:
		if t["kind"] == ProcTree.Kind.DAEMON and not t["down"]:
			procs += 1
	var word := REAL_WORD if visor.showing_real() else DEMO_WORD
	var line1 := "%s   %d %s   %s" % [HEADER, procs, "process" if procs == 1 else "processes", word]
	var big := int(round(17.0 * k))
	var small := int(round(13.0 * k))
	var w1 := font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var top := 16.0 * k
	draw_rect(Rect2(size.x * 0.5 - w1 * 0.5 - 12.0 * k, top - 4.0 * k, w1 + 24.0 * k, 46.0 * k), Color(0.0, 0.0, 0.0, 0.45))
	draw_string(font, Vector2(size.x * 0.5 - w1 * 0.5, top + big), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, big, hue.lightened(0.2))
	var w2 := font.get_string_size(AuditVisor.CREDIT, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(font, Vector2(size.x * 0.5 - w2 * 0.5, top + big + small + 6.0 * k), AuditVisor.CREDIT, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1.0, 1.0, 1.0, 0.62))
	drawn_header.append(line1)
	drawn_header.append(AuditVisor.CREDIT)
	# The header's own room: no tag is drawn over it.
	var keep := Rect2(size.x * 0.5 - w1 * 0.5 - 24.0 * k, 0.0, w1 + 48.0 * k, top + 52.0 * k)
	_tags(all, k, hue, font, keep)


func _corners(k: float, hue: Color) -> void:
	var m := 22.0 * k
	var l := 54.0 * k
	var c := Color(hue, 0.42)
	var w := maxf(1.0, 2.0 * k)
	for corner in [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(l * sx, 0.0), c, w)
		draw_line(corner, corner + Vector2(0.0, l * sy), c, w)


func _tags(all: Array, k: float, hue: Color, font: Font, keep: Rect2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mid := size * 0.5
	var shown: Array = []
	for t in all:
		var at: Vector3 = t["at"]
		if not at.is_finite() or cam.is_position_behind(at):
			continue
		var d := cam.global_position.distance_to(at)
		var virtual: bool = t["kind"] != ProcTree.Kind.DAEMON
		if d > FAR_M and not virtual:
			continue
		var sp := cam.unproject_position(at)
		if sp.x < -40.0 or sp.y < -40.0 or sp.x > size.x + 40.0 or sp.y > size.y + 40.0:
			continue
		shown.append({"t": t, "sp": sp, "d": d, "aim": sp.distance_to(mid), "virtual": virtual})
	# The order they claim room in: the one at the crosshair, the near daemons, the tree's own nodes, the rest.
	var focus := -1
	var best := FOCUS_PX * k
	for i in shown.size():
		var s: Dictionary = shown[i]
		if not s["virtual"] and not s["t"]["down"] and s["aim"] < best:
			best = s["aim"]
			focus = i
	var near: Array = []
	for i in shown.size():
		var s: Dictionary = shown[i]
		if i != focus and not s["virtual"] and s["d"] < NEAR_M:
			near.append(i)
	near.sort_custom(func(a, b): return shown[a]["d"] < shown[b]["d"])
	near = near.slice(0, NEAR_MOST)
	var order: Array = []
	if focus >= 0:
		order.append([focus, Size.FULL])
	for i in near:
		order.append([i, Size.LINE])
	for i in shown.size():
		if shown[i]["virtual"]:
			order.append([i, Size.LINE])
	var rest: Array = []
	for i in shown.size():
		if i != focus and not near.has(i) and not shown[i]["virtual"]:
			rest.append(i)
	rest.sort_custom(func(a, b): return shown[a]["d"] < shown[b]["d"])
	for i in rest:
		order.append([i, Size.PID])
	var taken: Array[Rect2] = [keep]
	for pair in order:
		var s: Dictionary = shown[pair[0]]
		var want: int = pair[1]
		while want <= Size.PID:
			var lines := _text(s["t"], want)
			var rect := _rect(lines, s["sp"], want, k, font)
			var clear := true
			for r in taken:
				if r.intersects(rect):
					clear = false
					break
			if clear:
				taken.append(rect.grow(2.0 * k))
				_draw_tag(s, lines, rect, want, k, hue, font)
				drawn_tags.append(" / ".join(lines))
				break
			want += 1


## A tag's lines at a size.
func _text(t: Dictionary, want: int) -> PackedStringArray:
	var kind: int = t["kind"]
	var pid: String = t["pid"]
	if kind == ProcTree.Kind.HIDDEN:
		return PackedStringArray([ProcTree.REDACTED + "  ppid " + str(t["ppid"])]) if want != Size.PID else PackedStringArray([ProcTree.REDACTED])
	if kind == ProcTree.Kind.ROOT:
		return PackedStringArray(["%s  %s" % [pid, t["name"]]])
	if t["down"]:
		return PackedStringArray(["%s  %s  X" % [pid, t["name"]]]) if want != Size.PID else PackedStringArray([pid])
	var note := ""
	if t["flash"] > 0.0:
		note = "  adopted by init"
	match want:
		Size.FULL:
			return PackedStringArray(["%s  %s  %s" % [pid, t["name"], t["state"]], "ppid %s   cpu %s   mem %s%s" % [t["ppid"], cpu_text(t["cpu"]), mem_text(t["mem_kb"]), note]])
		Size.LINE:
			if kind == ProcTree.Kind.JOB:
				return PackedStringArray(["%s  %s" % [pid, t["name"]]])
			return PackedStringArray(["%s  %s  %s%s" % [pid, t["name"], cpu_text(t["cpu"]), note]])
	return PackedStringArray([pid])


static func cpu_text(cpu: float) -> String:
	return "%.1f%%" % cpu if cpu < 100.0 else "%d%%" % int(cpu)


static func mem_text(kb: int) -> String:
	if kb <= 0:
		return "0K"
	if kb < 1024:
		return "%dK" % kb
	if kb < 1024 * 1024:
		return "%.1fM" % (kb / 1024.0)
	return "%.1fG" % (kb / 1048576.0)


func _font_size(want: int, row: int, k: float) -> int:
	match want:
		Size.FULL:
			return int(round((16.0 if row == 0 else 13.0) * k))
		Size.LINE:
			return int(round(13.0 * k))
	return int(round(11.0 * k))


func _rect(lines: PackedStringArray, sp: Vector2, want: int, k: float, font: Font) -> Rect2:
	var w := 0.0
	var h := 0.0
	for i in lines.size():
		var fs := _font_size(want, i, k)
		w = maxf(w, font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		h += fs + 3.0 * k
	var pad := (7.0 if want != Size.PID else 2.0) * k
	var lift := (16.0 if want != Size.PID else 6.0) * k
	return Rect2(sp + Vector2(12.0 * k, -lift - h - pad * 2.0), Vector2(w + pad * 2.0, h + pad * 2.0))


func _draw_tag(s: Dictionary, lines: PackedStringArray, rect: Rect2, want: int, k: float, hue: Color, font: Font) -> void:
	var t: Dictionary = s["t"]
	var sp: Vector2 = s["sp"]
	var down: bool = t["down"]
	var ember := Palette.EMBER
	var edge := ember if down else hue
	var heat := clampf(float(t["cpu"]) / 100.0, 0.0, 1.0)
	var pad := (7.0 if want != Size.PID else 2.0) * k
	if want != Size.PID:
		draw_line(sp, rect.position + Vector2(0.0, rect.size.y), Color(edge, 0.55), maxf(1.0, 1.2 * k))
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.62))
		draw_rect(rect, Color(edge, 0.7), false, maxf(1.0, k))
		draw_rect(Rect2(rect.position, Vector2(3.0 * k, rect.size.y)), Palette.FLASH.lerp(Palette.HOSTILE_RED, heat) if t["kind"] == ProcTree.Kind.DAEMON and not down else edge)
	var y := rect.position.y + pad
	for i in lines.size():
		var fs := _font_size(want, i, k)
		y += fs
		var colour := Color(1.0, 1.0, 1.0, 0.92) if i > 0 else edge.lightened(0.35)
		if want == Size.PID:
			colour = Color(edge.lightened(0.3), 0.8)
			draw_string_outline(font, Vector2(rect.position.x + pad, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(3.0 * k)), Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, Vector2(rect.position.x + pad + (3.0 * k if want != Size.PID else 0.0), y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colour)
		y += 3.0 * k
