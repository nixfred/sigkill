class_name CoopScreen
extends Node
## Split-screen co-op's screen (W6, PRD 5.5): the game's one window split into two tiles, each player's own view, drawn by
## the game itself and styled as a tiling desktop draws its windows (Omarchy on Hyprland): an outer gap and a gap between
## the tiles, a thin border on each (the active tile's glowing in its player's colour, the other's dim), and a
## terminal-style title bar over each (the player's prompt, the tile's size and share). No window manager is asked for
## anything: nothing here calls the compositor, makes a window or moves one. Two SubViewports draw the one world (the
## arena's own World3D), each through its own camera, which takes its player's camera every frame (place, look, field of
## view, the shot jolt); the window's own 3D view is switched off while the split stands, so the world is drawn twice
## (once a tile), never three times.
##
## The tile trade: the split moves (each player can grow or shrink their own tile, a step at a time with a short cooldown,
## and flip the split between side by side and stacked), and a tile is a window onto the world at the same zoom as the
## whole screen: a bigger tile sees more of it, a smaller one less. A smaller tile pays back in aim: faster looking, and a
## steadier weapon (less spread and recoil); a bigger one looks a little slower and kicks a little wider. Both shown on
## the tile, both ways (trade_for()).
##
## What each tile shows of the players (render layers): its own player's body is out of its view, the other's in it; its
## own player's weapon in its view, the other's held weapon model out of it (the partner's body carries its own); the
## Audit Trail visor's lines only in player 1's tile, whose I turns it on.

const TileShader = preload("res://shaders/coop_tile.gdshader")
const Palette = preload("res://scripts/palette.gd")

## Under the screen post (-1) and the HUD (1): the two views and the desk behind them.
const VIEWS_LAYER := -2
## Over the screen post, under the HUD's menu: the tiles' borders, title bars and HUDs.
const FRAME_LAYER := 0
## At 1080 lines: the gap round the edge and between the tiles, a title bar's height, a border's width.
const GAP_OUT := 10.0
const GAP_IN := 8.0
const TITLE_H := 26.0
const BORDER := 2.0
## The shared bar across the top (as a tiling desktop's bar sits over its windows): its height at 1080 lines.
const BAR_H := 30.0
## The split: player 1's share of the room, its limits, a press's step; how long a resize and a flip take to settle.
const SHARE_LOW := 0.35
const SHARE_HIGH := 0.65
const STEP := 0.075
const RESIZE_S := 0.32
const FLIP_S := 0.45
## How soon a player may move the split again, and how soon the split may be flipped again (by either player: one split).
const COOLDOWN_S := 1.2
const FLIP_COOLDOWN_S := 2.0
## The trade at the limits (the middle is even): a tile at its smallest looks AIM_FAST times as fast and its shots spread and
## kick STEADY_SMALL as much; at its biggest AIM_SLOW and STEADY_BIG.
const AIM_FAST := 1.35
const AIM_SLOW := 0.8
const STEADY_SMALL := 0.55
const STEADY_BIG := 1.25
## Render layers (bits): each player's body, each player's held weapon model, the visor's lines.
const BODY := [0, 1 << 10, 1 << 11]
const GUN := [0, 1 << 12, 1 << 13]
const VISOR := 1 << 14
const ALL_LAYERS := (1 << 20) - 1
## The players' colours: player 1 the game's own teal, player 2 azure (W6; OKLab-far from every hostile's colour; ICE,
## the one near it, stands down in co-op).
const COLOR := [Color(0, 0, 0), Color(0.098039216, 0.827450980, 0.772549020), Color(0.227450980, 0.627450980, 1.0)]
const COLOR_HI := [Color(0, 0, 0), Color(0.490196078, 1.0, 0.811764706), Color(0.74901961, 0.87843137, 1.0)]
const PROMPT := ["", ">_", "$_"]

signal moved(seat: int, what: String)

## The two players by seat (index 1 and 2).
var players: Array = [null, null, null]
## Player 1's share of the room (the target), the layout (stacked or side by side), the active tile.
var share := 0.5
var stacked := false
var focus := 1
## Each seat's cooldowns left.
var cooldown := [0.0, 0.0, 0.0]
var flip_cooldown := 0.0
## Each tile's moments, set by the mode: downed (0 to 1), a hit's flash.
var down := [0.0, 0.0, 0.0]
var hurt := [0.0, 0.0, 0.0]
## The tiles' titles' last words (the mode's): "wave 2/4", "Stopped".
var status := ["", "", ""]

var _share_from := 0.5
var _share_shown := 0.5
var _share_t := 1.0
var _blend := 0.0
var _blend_from := 0.0
var _blend_t := 1.0
var _flash := [0.0, 0.0, 0.0]
var _clock := 0.0
var _views: CanvasLayer
var _frame: CanvasLayer
var _desk: Control
var _chrome: Control
var _box: Array = [null, null, null]
var _port: Array = [null, null, null]
var _cam: Array = [null, null, null]
var _mat: Array = [null, null, null]
var _overlay: Array = [null, null, null]
var _root_3d_was := false
var _built := false


func _init() -> void:
	name = "CoopScreen"
	process_priority = 100  # after the players have moved and looked this frame


## The split stands: the two tiles made over `world`, each player's view in its own; the window's own 3D view off.
func build(p1: Node3D, p2: Node3D) -> void:
	players = [null, p1, p2]
	_views = CanvasLayer.new()
	_views.name = "CoopViews"
	_views.layer = VIEWS_LAYER
	add_child(_views)
	_desk = Control.new()
	_desk.name = "Desk"
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.draw.connect(_draw_desk)
	_views.add_child(_desk)
	_desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = CanvasLayer.new()
	_frame.name = "CoopFrame"
	_frame.layer = FRAME_LAYER
	add_child(_frame)
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.draw.connect(_draw_chrome)
	_frame.add_child(_chrome)
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var world := get_viewport().find_world_3d()
	for seat: int in [1, 2]:
		var box := SubViewportContainer.new()
		box.name = "Tile%d" % seat
		box.stretch = true
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = TileShader
		mat.set_shader_parameter("tint", COLOR[seat])
		box.material = mat
		_views.add_child(box)
		var port := SubViewport.new()
		port.name = "View%d" % seat
		port.world_3d = world
		port.size = Vector2i(64, 64)
		port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		port.handle_input_locally = false
		port.audio_listener_enable_3d = false  # the window's listener stays player 1's: one pair of speakers
		box.add_child(port)
		var cam := Camera3D.new()
		cam.name = "Eye%d" % seat
		cam.cull_mask = cull_for(seat)
		port.add_child(cam)
		cam.current = true
		# Each tile's own HUD sits over its picture (the mode fills it).
		var overlay := Control.new()
		overlay.name = "Hud%d" % seat
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(overlay)
		_box[seat] = box
		_port[seat] = port
		_cam[seat] = cam
		_mat[seat] = mat
		_overlay[seat] = overlay
		_paint_layers(seat)
	_frame.move_child(_chrome, _frame.get_child_count() - 1)  # borders and titles over the tiles' HUDs
	_root_3d_was = get_viewport().disable_3d
	get_viewport().disable_3d = true
	_built = true
	_layout()
	_follow()


## The split comes down: the window's own 3D view back as it was, the tiles gone.
func tear_down() -> void:
	if not _built:
		return
	_built = false
	if is_inside_tree():
		get_viewport().disable_3d = _root_3d_was
	for node in [_views, _frame]:
		if node != null and is_instance_valid(node):
			node.queue_free()


func _exit_tree() -> void:
	tear_down()


## The render layers tile `seat`'s camera draws: everything but its own player's body and the other's held weapon model;
## the visor's lines only in player 1's.
static func cull_for(seat: int) -> int:
	var other := 3 - seat
	var mask: int = ALL_LAYERS & ~int(BODY[seat]) & ~int(GUN[other])
	if seat != 1:
		mask &= ~VISOR
	return mask


## Every visual part of the player in `seat`'s held weapon models on that seat's weapon layer.
func _paint_layers(seat: int) -> void:
	var p = players[seat]
	if p == null or not is_instance_valid(p):
		return
	var rig = p.get_node_or_null("Head/Camera/ViewmodelRig")
	if rig != null:
		set_layers(rig, GUN[seat])


## `node` and everything under it drawn on `layers` alone.
static func set_layers(node: Node, layers: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers
	for child in node.get_children():
		set_layers(child, layers)


# --- The split. ---

## Player `seat`'s share of the room: the target, or (shown) where the animation is now.
func share_of(seat: int, shown: bool = false) -> float:
	var s := _share_shown if shown else share
	return s if seat == 1 else 1.0 - s


## Grows player `seat`'s tile a step (false on its cooldown or at its limit).
func grow(seat: int) -> bool:
	return _move(seat, STEP)


func shrink(seat: int) -> bool:
	return _move(seat, -STEP)


func _move(seat: int, by: float) -> bool:
	if cooldown[seat] > 0.0:
		return false
	var mine := share_of(seat)
	var want := clampf(snappedf(mine + by, 0.0001), SHARE_LOW, SHARE_HIGH)
	if is_equal_approx(want, mine):
		return false
	_share_from = _share_shown
	share = want if seat == 1 else 1.0 - want
	_share_t = 0.0
	cooldown[seat] = COOLDOWN_S
	focus = seat
	_flash[seat] = 1.0
	moved.emit(seat, "grow" if by > 0.0 else "shrink")
	return true


## Flips the split between side by side and stacked (false on its cooldown, which both players share).
func flip(seat: int) -> bool:
	if flip_cooldown > 0.0:
		return false
	stacked = not stacked
	_blend_from = _blend
	_blend_t = 0.0
	flip_cooldown = FLIP_COOLDOWN_S
	focus = seat
	_flash[1] = 1.0
	_flash[2] = 1.0
	moved.emit(seat, "flip")
	return true


## The trade at a tile's share `s`: {"aim": look speed times, "steady": spread and recoil times}.
static func trade_for(s: float) -> Dictionary:
	var t := clampf((0.5 - s) / (0.5 - SHARE_LOW), -1.0, 1.0)  # 1 at the smallest, -1 at the biggest
	var aim := lerpf(1.0, AIM_FAST, t) if t >= 0.0 else lerpf(1.0, AIM_SLOW, -t)
	var steady := lerpf(1.0, STEADY_SMALL, t) if t >= 0.0 else lerpf(1.0, STEADY_BIG, -t)
	return {"aim": aim, "steady": steady}


## Player `seat`'s view now, in degrees across and down (its tile's picture, at its camera's field of view).
func view_degrees(seat: int) -> Vector2:
	var cam: Camera3D = _cam[seat]
	var r := view_rect(seat)
	if cam == null or r.size.y <= 0.0:
		return Vector2.ZERO
	var v := cam.fov
	var h := rad_to_deg(2.0 * atan(tan(deg_to_rad(v) * 0.5) * r.size.x / r.size.y))
	return Vector2(h, v)


# --- Where everything is. ---

func _k() -> float:
	return maxf(_screen().y / 1080.0, 0.5)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


## Tile `seat`'s whole rectangle (title bar and border included), where the animation has it now.
func tile_rect(seat: int) -> Rect2:
	var k := _k()
	var s := _screen()
	var top := (GAP_OUT * 0.6 + BAR_H + GAP_IN) * k
	var room := Rect2(Vector2(GAP_OUT * k, top), Vector2(s.x - 2.0 * GAP_OUT * k, s.y - top - GAP_OUT * k))
	var gap := GAP_IN * k
	var a := _share_shown
	var side := _split(room, gap, a, false, seat)
	var stack := _split(room, gap, a, true, seat)
	var b := _ease_blend()
	return Rect2(side.position.lerp(stack.position, b), side.size.lerp(stack.size, b))


static func _split(room: Rect2, gap: float, a: float, rows: bool, seat: int) -> Rect2:
	if rows:
		var h1 := (room.size.y - gap) * a
		if seat == 1:
			return Rect2(room.position, Vector2(room.size.x, h1))
		return Rect2(room.position + Vector2(0.0, h1 + gap), Vector2(room.size.x, room.size.y - gap - h1))
	var w1 := (room.size.x - gap) * a
	if seat == 1:
		return Rect2(room.position, Vector2(w1, room.size.y))
	return Rect2(room.position + Vector2(w1 + gap, 0.0), Vector2(room.size.x - gap - w1, room.size.y))


## The shared bar's rectangle, across the top over both tiles.
func bar_rect() -> Rect2:
	var k := _k()
	var s := _screen()
	return Rect2(Vector2(GAP_OUT * k, GAP_OUT * 0.6 * k), Vector2(s.x - 2.0 * GAP_OUT * k, BAR_H * k))


## Tile `seat`'s picture: inside its border, under its title bar.
func view_rect(seat: int) -> Rect2:
	var k := _k()
	var t := tile_rect(seat)
	var b := BORDER * k
	return Rect2(t.position + Vector2(b, TITLE_H * k), t.size - Vector2(2.0 * b, TITLE_H * k + b))


## The HUD node over tile `seat`'s picture (the mode's tile HUD lives in it).
func overlay(seat: int) -> Control:
	return _overlay[seat]


## Tile `seat`'s SubViewport (the visor's HUD is drawn inside player 1's, so it reads that tile's camera).
func port(seat: int) -> SubViewport:
	return _port[seat]


func camera(seat: int) -> Camera3D:
	return _cam[seat]


func _ease_blend() -> float:
	var t := clampf(_blend_t / FLIP_S, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	var to := 1.0 if stacked else 0.0
	return lerpf(_blend_from, to, e)


# --- Every frame. ---

func _process(delta: float) -> void:
	if not _built:
		return
	_clock += delta
	flip_cooldown = maxf(flip_cooldown - delta, 0.0)
	for seat: int in [1, 2]:
		cooldown[seat] = maxf(cooldown[seat] - delta, 0.0)
		_flash[seat] = maxf(_flash[seat] - delta * 2.4, 0.0)
	if _share_t < RESIZE_S:
		_share_t = minf(_share_t + delta, RESIZE_S)
		_share_shown = lerpf(_share_from, share, _back_out(_share_t / RESIZE_S))
	else:
		_share_shown = share
	if _blend_t < FLIP_S:
		_blend_t = minf(_blend_t + delta, FLIP_S)
	_blend = _ease_blend()
	_layout()
	_follow()
	_desk.queue_redraw()
	_chrome.queue_redraw()


## An ease out with a small overshoot: a tile that snaps into place and settles, as a tiling desktop's windows do.
static func _back_out(t: float) -> float:
	var c := 1.4
	var u := t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


func _layout() -> void:
	for seat: int in [1, 2]:
		var r := view_rect(seat)
		var box: SubViewportContainer = _box[seat]
		box.position = r.position.round()
		box.size = r.size.round().max(Vector2(8, 8))
		var o: Control = _overlay[seat]
		o.position = box.position
		o.size = box.size
		var mat: ShaderMaterial = _mat[seat]
		mat.set_shader_parameter("down", down[seat])
		mat.set_shader_parameter("hurt", hurt[seat])
		mat.set_shader_parameter("flash", _flash[seat])
		mat.set_shader_parameter("clock", _clock)
		var p = players[seat]
		if p != null and is_instance_valid(p):
			# The same zoom as the whole screen, over the tile's height: a bigger tile sees more.
			p.view_tan = clampf(r.size.y / maxf(_screen().y, 1.0), 0.1, 1.0)
			var tr := trade_for(share_of(seat, true))
			p.aim_scale = tr["aim"]
			p.steady_scale = tr["steady"]


## Each tile's camera takes its player's: place and look (the shot jolt in it), field of view, the near and far planes.
func _follow() -> void:
	var root := get_viewport()
	for seat: int in [1, 2]:
		var p = players[seat]
		var cam: Camera3D = _cam[seat]
		var port: SubViewport = _port[seat]
		port.scaling_3d_scale = root.scaling_3d_scale
		port.msaa_3d = root.msaa_3d
		port.screen_space_aa = root.screen_space_aa
		port.use_taa = root.use_taa
		if p == null or not is_instance_valid(p):
			continue
		var src = p.get_node_or_null("Head/Camera") as Camera3D
		if src == null:
			continue
		cam.global_transform = src.get_camera_transform()
		cam.fov = src.fov
		cam.near = src.near
		cam.far = src.far
		cam.keep_aspect = src.keep_aspect
		cam.attributes = src.attributes
		cam.environment = src.environment


# --- Drawn. ---

## Behind the tiles: the desk, near black with a faint grid, as a tiling desktop's wallpaper shows in its gaps.
func _draw_desk() -> void:
	var s := _desk.size
	_desk.draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.016, 0.02))
	var k := _k()
	var step := 24.0 * k
	var c := Color(COLOR[1], 0.05)
	var x := 0.0
	while x < s.x:
		_desk.draw_line(Vector2(x, 0), Vector2(x, s.y), c, 1.0)
		x += step
	var y := 0.0
	while y < s.y:
		_desk.draw_line(Vector2(0, y), Vector2(s.x, y), c, 1.0)
		y += step


## Over the tiles: each one's border and title bar.
func _draw_chrome() -> void:
	var k := _k()
	var font := Palette.mono_font()
	for seat: int in [1, 2]:
		var t := tile_rect(seat)
		var active := seat == focus
		var hue: Color = COLOR[seat]
		var d: float = down[seat]
		var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
		var edge := hue if active else hue.darkened(0.55)
		edge = edge.lerp(Color(1.0, 0.1, 0.18), d * (0.6 + 0.4 * pulse))
		var w := maxf(1.0, BORDER * k * (1.0 if active else 0.75))
		# A glow round the active tile's border.
		if active or d > 0.0:
			for i in 3:
				var g := (i + 1) * 2.0 * k
				_chrome.draw_rect(t.grow(g), Color(edge, 0.10 - i * 0.03), false, maxf(1.0, 2.0 * k))
		_chrome.draw_rect(t, edge, false, w)
		# The title bar: dark glass, the prompt, the tile's size and share, the status.
		var bar := Rect2(t.position + Vector2(w, w), Vector2(t.size.x - 2.0 * w, TITLE_H * k - w))
		_chrome.draw_rect(bar, Color(0.02, 0.03, 0.035, 0.96))
		_chrome.draw_line(bar.position + Vector2(0, bar.size.y), bar.end, Color(edge, 0.5), maxf(1.0, k))
		var fs := int(round(14.0 * k))
		var base := bar.position.y + bar.size.y * 0.5 + fs * 0.36
		var x := bar.position.x + 10.0 * k
		_chrome.draw_rect(Rect2(Vector2(x, bar.position.y + bar.size.y * 0.5 - 4.0 * k), Vector2(8.0 * k, 8.0 * k)), edge)
		x += 16.0 * k
		var left := "p%d@sigkill:/arena$ %s" % [seat, PROMPT[seat]]
		_chrome.draw_string(font, Vector2(x, base), left, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_HI[seat] if active else Color(0.72, 0.78, 0.8))
		x += font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if int(_clock * 2.0) % 2 == 0:
			_chrome.draw_rect(Rect2(Vector2(x + 3.0 * k, base - fs * 0.8), Vector2(fs * 0.5, fs * 0.95)), Color(COLOR_HI[seat], 0.85))
		var r := view_rect(seat)
		var right := "%s   %dx%d   %d%%" % [status[seat], int(r.size.x), int(r.size.y), int(round(share_of(seat, true) * 100.0))]
		var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var right_hue := Color(1.0, 0.35, 0.4) if d > 0.0 else Color(0.62, 0.68, 0.7)
		if bar.size.x > rw + 340.0 * k:
			_chrome.draw_string(font, Vector2(bar.end.x - rw - 10.0 * k, base), right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, right_hue)
