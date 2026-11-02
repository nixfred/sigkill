class_name CoopTileHud
extends Control
## One co-op tile's HUD (W6, scripts/coop/coop_hunt.gd), drawn over its picture in its player's colour: the crosshair (its
## gap the tile's steadiness: tighter in a smaller tile), a hit's tick on it; the health bar (segments, bottom left); the
## weapon and its ammo (bottom right); the tile's trade (top right: the view in degrees across and down, the aim's speed,
## the spread); the player's kills and downs (top left); and the moments: downed (the job stopped, bleeding out, the
## partner told where to stand), out (back at the wave's end), and the partner down (a marker over them, through walls,
## with the distance, and the revive's progress while standing close). Made in code; it reads the mode and the player.

const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

var mode: CoopHunt = null
var seat := 1
var _hit := 0.0
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p = _me()
	if p != null and p.has_signal("shot_fired"):
		p.shot_fired.connect(_on_shot)


func _on_shot(hit: bool) -> void:
	if hit:
		_hit = 0.22


func _me():
	if mode == null or not is_instance_valid(mode):
		return null
	return mode.player if seat == 1 else mode.player2


func _process(delta: float) -> void:
	_clock += delta
	_hit = maxf(_hit - delta, 0.0)
	queue_redraw()


func _k() -> float:
	return clampf(minf(size.y / 620.0, size.x / 560.0), 0.55, 1.25)


## The tile's trade as shown: {"view": "VIEW 98x74", "aim": "AIM x1.18", "spread": "SPREAD -22%"}.
func trade_text() -> Dictionary:
	var screen := mode.screen if mode != null else null
	if screen == null:
		return {}
	var v := screen.view_degrees(seat)
	var tr := CoopScreen.trade_for(screen.share_of(seat, true))
	var spread := int(round((float(tr["steady"]) - 1.0) * 100.0))
	return {"view": "VIEW %d°x%d°" % [int(round(v.x)), int(round(v.y))], "aim": "AIM x%.2f" % float(tr["aim"]), "spread": "SPREAD %s%d%%" % ["+" if spread > 0 else ("-" if spread < 0 else "±"), absi(spread)]}


func _draw() -> void:
	if mode == null or not is_instance_valid(mode) or not mode.running:
		return
	var p = _me()
	if p == null or not is_instance_valid(p):
		return
	var k := _k()
	var font := Palette.mono_font()
	var hue: Color = CoopScreen.COLOR[seat]
	var hi: Color = CoopScreen.COLOR_HI[seat]
	var st := mode.state(seat)
	var mid := size * 0.5
	# The trade, top right.
	var tt := trade_text()
	if not tt.is_empty():
		var fs := int(round(15.0 * k))
		var y := 22.0 * k
		for key in ["view", "aim", "spread"]:
			var line: String = tt[key]
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_rect(Rect2(Vector2(size.x - w - 18.0 * k, y - fs * 0.95), Vector2(w + 10.0 * k, fs * 1.25)), Color(0, 0, 0, 0.42))
			draw_string(font, Vector2(size.x - w - 13.0 * k, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hi if key == "view" else Color(hi, 0.9))
			y += fs * 1.35
	# Kills and downs, top left (giving way to the visor's header in player 1's tile while it is on).
	var r: Dictionary = mode.per[seat] if not mode.per[seat].is_empty() else {}
	var visor_up: bool = seat == 1 and mode.visor != null and is_instance_valid(mode.visor) and mode.visor.get("on") == true
	var fs2 := int(round(15.0 * k))
	var left := "kills %d   downs %d   revives %d" % [int(r.get("kills", 0)), int(r.get("downs", 0)), int(r.get("revives", 0))]
	var ly := 22.0 * k if not visor_up else size.y - 64.0 * k
	draw_rect(Rect2(Vector2(8.0 * k, ly - fs2 * 0.95), Vector2(font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x + 10.0 * k, fs2 * 1.25)), Color(0, 0, 0, 0.42))
	draw_string(font, Vector2(13.0 * k, ly), left, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(hi, 0.92))
	if st == "up":
		_crosshair(mid, k, hue, hi, p)
	_health(k, hue, hi, font)
	_weapon(k, hi, font, p)
	_partner(k, font)
	if seat == 1 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and st == "up" and not p.get("input_blocked"):
		_banner(mid + Vector2(0, -90.0 * k), "[ click to engage ]", int(26 * k), hi, font)
	if st == "down":
		_downed(mid, k, font)
	elif st == "out":
		_banner(mid, "[%d]+  Killed" % seat, int(34 * k), Color(1.0, 0.35, 0.42), font)
		_banner(mid + Vector2(0, 40.0 * k), "back at the wave's end", int(18 * k), Color(1, 1, 1, 0.8), font)


func _crosshair(mid: Vector2, k: float, hue: Color, hi: Color, p) -> void:
	var steady := float(p.get("steady_scale")) if p.get("steady_scale") != null else 1.0
	var gap := (7.0 + 9.0 * steady) * k
	var arm := 9.0 * k
	var w := maxf(1.5, 2.0 * k)
	var c := Color(hi, 0.95)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(mid + d * gap, mid + d * (gap + arm), Color(0, 0, 0, 0.6), w + 2.0)
		draw_line(mid + d * gap, mid + d * (gap + arm), c, w)
	draw_circle(mid, maxf(1.5, 1.8 * k), c)
	if _hit > 0.0:
		var a := _hit / 0.22
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n := (d as Vector2).normalized()
			draw_line(mid + n * 10.0 * k, mid + n * 20.0 * k, Color(1, 1, 1, a), w)


func _health(k: float, hue: Color, hi: Color, font: Font) -> void:
	var hp := mode.health(seat)
	var share := clampf(hp / CoopHunt.MAX_HEALTH, 0.0, 1.0)
	var cells := 10
	var cw := 15.0 * k
	var ch := 12.0 * k
	var at := Vector2(16.0 * k, size.y - 26.0 * k)
	var fs := int(round(15.0 * k))
	var hp_text := "HP %d" % int(ceil(hp))
	draw_rect(Rect2(at + Vector2(-5.0 * k, -8.0 * k - fs), Vector2(font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0 * k, fs * 1.25)), Color(0, 0, 0, 0.45))
	draw_string(font, at + Vector2(0, -8.0 * k), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hi)
	var lit := int(ceil(share * cells - 0.001))
	var low := share <= 0.3
	for i in cells:
		var r := Rect2(at + Vector2(i * (cw + 3.0 * k), 0), Vector2(cw, ch))
		draw_rect(r, Color(0, 0, 0, 0.5))
		if i < lit:
			var c := hue if not low else Color(1.0, 0.22, 0.3).lerp(hue, 0.5 + 0.5 * sin(_clock * 8.0))
			draw_rect(r.grow(-1.5), c)
	var life: Dictionary = mode.lives[seat]
	var protect := float(life.get("protect", 0.0))
	if protect > 0.0 and protect <= CoopHunt.PROTECT_S and str(life.get("state", "")) == "up":
		draw_string(font, at + Vector2(cells * (cw + 3.0 * k) + 8.0 * k, ch), "protected", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), Color(hi, 0.7))


func _weapon(k: float, hi: Color, font: Font, p) -> void:
	var inv = p.get("inventory")
	if inv == null:
		return
	var def = inv.def()
	if def == null:
		return
	var line := ""
	var mag: int = inv.mags[inv.current]
	var reserve: int = inv.reserves[inv.current]
	if def.is_ult():
		line = "%s  %s" % [def.short_name, "READY" if inv.meter_ready() else "%d%%" % floori(inv.meter_share() * 100.0)]
	elif def.is_thrown():
		line = "%s  x%d" % [def.short_name, mag]
	elif not def.has_magazine():
		line = "%s  inf" % def.short_name
	else:
		line = "%s  %d / %s" % [def.short_name, mag, "inf" if reserve == WeaponDefScript.INFINITE else str(reserve)]
	if inv.is_reloading():
		line += "  reloading"
	var fs := int(round(20.0 * k))
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(size.x - w - 16.0 * k, size.y - 16.0 * k)
	draw_rect(Rect2(at + Vector2(-6.0 * k, -fs), Vector2(w + 12.0 * k, fs * 1.3)), Color(0, 0, 0, 0.45))
	draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hi)


## The partner, when down: a marker over them in this tile (clamped to its edge when out of view), the distance, and the
## revive's progress while this player stands close.
func _partner(k: float, font: Font) -> void:
	var other := 3 - seat
	if mode.state(other) != "down" or mode.screen == null:
		return
	var them = mode.player if other == 1 else mode.player2
	var cam := mode.screen.camera(seat)
	var me = _me()
	if them == null or not is_instance_valid(them) or cam == null or me == null:
		return
	var at: Vector3 = them.global_position + Vector3.UP * 0.4
	var dist: float = Vector2(me.global_position.x - them.global_position.x, me.global_position.z - them.global_position.z).length()
	# In the camera's own space: a point level with the eye (no depth) cannot be projected, so it is nudged ahead first.
	var local := cam.global_transform.affine_inverse() * at
	var behind := local.z > 0.0
	if absf(local.z) < 0.05:
		local.z = -0.05
	var sp := cam.unproject_position(cam.global_transform * local)
	if behind:
		sp = size - sp
	var margin := 40.0 * k
	var inside := not behind and Rect2(Vector2.ZERO, size).grow(-margin).has_point(sp)
	sp = sp.clamp(Vector2.ONE * margin, size - Vector2.ONE * margin)
	var hue: Color = CoopScreen.COLOR[other]
	var pulse := 0.6 + 0.4 * sin(_clock * 6.0)
	var red := Color(1.0, 0.25, 0.32)
	draw_circle(sp, 13.0 * k, Color(red, 0.25 + 0.2 * pulse))
	draw_arc(sp, 13.0 * k, 0.0, TAU, 24, red, maxf(1.5, 2.0 * k))
	var rev: float = float(mode.lives[other].get("revive", 0.0))
	if rev > 0.0:
		draw_arc(sp, 18.0 * k, -PI * 0.5, -PI * 0.5 + TAU * rev, 32, hue, maxf(2.0, 4.0 * k))
	var fs := int(round(15.0 * k))
	var text := "p%d DOWN  %dm" % [other, int(round(dist))] if dist > CoopHunt.REVIVE_M else "fg %%%d  %d%%" % [other, int(rev * 100.0)]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, sp + Vector2(-w * 0.5, -22.0 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red.lerp(hue, rev) if inside or rev > 0.0 else red)
	if dist <= CoopHunt.REVIVE_M:
		_banner(size * 0.5 + Vector2(0, 70.0 * k), "fg %%%d   reviving p%d   %d%%" % [other, other, int(rev * 100.0)], int(22 * k), hue, font)
		var bar := Rect2(size * 0.5 + Vector2(-110.0 * k, 84.0 * k), Vector2(220.0 * k, 8.0 * k))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * rev, bar.size.y)), hue)


## This player down: the job stopped, bleeding out, the partner told what to do.
func _downed(mid: Vector2, k: float, font: Font) -> void:
	var life: Dictionary = mode.lives[seat]
	var bleed := maxf(float(life.get("bleed", 0.0)), 0.0)
	var rev := float(life.get("revive", 0.0))
	_banner(mid + Vector2(0, -24.0 * k), "[%d]+  Stopped" % seat, int(40 * k), Color(1.0, 0.3, 0.38), font)
	_banner(mid + Vector2(0, 18.0 * k), "bleeding out  %ds" % int(ceil(bleed)), int(20 * k), Color(1, 1, 1, 0.85), font)
	var other := 3 - seat
	var line := "p%d: stand close to revive  (fg %%%d)" % [other, seat] if rev <= 0.0 else "fg %%%d   %d%%" % [seat, int(rev * 100.0)]
	_banner(mid + Vector2(0, 52.0 * k), line, int(18 * k), CoopScreen.COLOR_HI[other], font)
	var bar := Rect2(mid + Vector2(-140.0 * k, 66.0 * k), Vector2(280.0 * k, 7.0 * k))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(bleed / CoopHunt.BLEED_S, 0.0, 1.0), bar.size.y)), Color(1.0, 0.25, 0.32))
	if rev > 0.0:
		draw_rect(Rect2(bar.position + Vector2(0, 10.0 * k), Vector2(bar.size.x * rev, bar.size.y)), CoopScreen.COLOR[other])


func _banner(center: Vector2, text: String, fs: int, color: Color, font: Font) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(center + Vector2(-w * 0.5 - 12.0, -fs * 1.0), Vector2(w + 24.0, fs * 1.35)), Color(0, 0, 0, 0.55))
	draw_string(font, center + Vector2(-w * 0.5, fs * 0.05), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
