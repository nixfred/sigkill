@tool
extends RefCounted
## SIGKILL palette and material factory. The single source for every colour and look tunable.
##
## Tron look: void-black sky, near-black faces, glowing neon edges and grid lines.
## Teal and mint belong to the player side, red and amber to hostiles.
## The .gdshader files carry matching defaults only so a material previews sensibly in the
## editor. Every value set here wins at runtime. Change colours here, nowhere else.

enum Surface { WALL, FLOOR, ACCENT, CRATE }

# Floats are hex / 255. The hex value is in each comment.
const VOID := Color(0.0, 0.0, 0.0)  # #000000 sky, clear colour, text outlines
const BASE := Color(0.019607843, 0.031372549, 0.039215686)  # #05080a floor, wall and face base
const TEAL := Color(0.098039216, 0.827450980, 0.772549020)  # #19d3c5 player side neon
const MINT := Color(0.490196078, 1.0, 0.811764706)  # #7dffcf player side highlight
const HOSTILE_RED := Color(1.0, 0.2, 0.333333333)  # #ff3355 hostile neon
const HOSTILE_AMBER := Color(1.0, 0.690196078, 0.0)  # #ffb000 hostile highlight
const FLASH := Color(1.0, 1.0, 1.0)  # #ffffff kill flash and hit-marker pop
# Matrix register: green code rain where reality is thin. Nothing else is green.
const MATRIX_GREEN := Color(0.0, 1.0, 0.254901961)  # #00ff41 code rain tails
const MATRIX_HEAD := Color(0.784313725, 1.0, 0.815686275)  # #c8ffd0 the leading glyph of each stream
# Weapon light skins (C16): each weapon's own neon, never hostile red or amber, never green.
const VIOLET := Color(0.615686275, 0.360784314, 1.0)  # #9d5cff SIGTERM body and light
const VIOLET_HI := Color(0.847058824, 0.749019608, 1.0)  # #d8bfff SIGTERM beam and flash
const ICE := Color(0.639215686, 0.933333333, 1.0)  # #a3eeff SIGKILL rail body and light (C17)
const ICE_HI := Color(0.917647059, 0.992156863, 1.0)  # #eafdff SIGKILL rail beam: near white
const FORK := Color(1.0, 0.301960784, 1.0)  # #ff4dff fork bomb body and bomblets (C19)
const FORK_HI := Color(1.0, 0.8, 1.0)  # #ffccff fork bomb blast rings
const YELLOW_HI := Color(1.0, 0.960784314, 0.760784314)  # #fff5c2 fork() pellet trails and fork flashes (C24)
const COBALT := Color(0.301960784, 0.490196078, 1.0)  # #4d7dff grep body, lock brackets and "match" tags (C25)
const COBALT_HI := Color(0.780392157, 0.839215686, 1.0)  # #c7d6ff grep dart trails and its "grep -c" line
const EMBER := Color(1.0, 0.415686275, 0.101960784)  # #ff6a1a rm -rf body, slug and blast ring (C26): orange, between amber and red but neither
const EMBER_HI := Color(1.0, 0.788235294, 0.639215686)  # #ffc9a3 rm -rf slug trail and muzzle flash
const ROSE := Color(1.0, 0.37254902, 0.690196078)  # #ff5fb0 cron mines, their rings and schedule text (C27): pink, between the fork bomb's magenta and hostile red
const ROSE_HI := Color(1.0, 0.760784314, 0.88627451)  # #ffc2e2 a cron mine's brighten before a run
# Weapon viewmodels (A1): dark gunmetal bodies, lighter plates and shrouds, near-black polymer
# grips, under each weapon's neon trim (its light skin) and hot parts (its beam colour).
const GUNMETAL := Color(0.047058824, 0.062745098, 0.078431373)  # #0c1014 viewmodel body
const GUNMETAL_LIGHT := Color(0.109803922, 0.137254902, 0.164705882)  # #1c232a viewmodel plates and shrouds
const POLYMER := Color(0.023529412, 0.027450980, 0.031372549)  # #060708 viewmodel grips and bands
# Daemons (A2): black obsidian glass, a hostile red rim and scanlines, a cyan split in a glitch,
# cores in the type's own hostile colour, red glyphs.
const OBSIDIAN := Color(0.011764706, 0.015686275, 0.019607843)  # #030405 daemon shells
const GLITCH_SPLIT := Color(0.301960784, 0.882352941, 1.0)  # #4de1ff the blue side of a daemon's glitch split
# Arena (A3): gunmetal trims a shade above the base, a darker plinth and corner towers, the
# skyline's near-black towers, screen and rack faces; the depth fog's colour, and the sky's haze at the
# horizon and its abyss below.
const ARENA_PANEL := Color(0.062745098, 0.086274510, 0.105882353)  # #10161b trims, caps, ribs, racks, pylons
const ARENA_PANEL_DARK := Color(0.031372549, 0.043137255, 0.054901961)  # #080b0e the plinth's tiers, the corner towers
const ARENA_TOWER := Color(0.015686275, 0.027450980, 0.039215686)  # #04070a the skyline's towers and slabs
const ARENA_SCREEN := Color(0.007843137, 0.023529412, 0.027450980)  # #020607 a screen's or a rack's face
const FOG := Color(0.011764706, 0.070588235, 0.078431373)  # #031214 the depth fog
const SKY_HORIZON := Color(0.011764706, 0.062745098, 0.070588235)  # #031012 the sky's haze at the horizon
const SKY_ABYSS := Color(0.003921569, 0.015686275, 0.019607843)  # #010405 the sky below the horizon
## Light skin name -> [body, beam]: the viewmodel and muzzle light take the first, tracers,
## the muzzle flash and the sparks of a miss the second. "teal" is the terminal cannon's.
const SKINS := {"teal": [TEAL, MINT], "violet": [VIOLET, VIOLET_HI], "ice": [ICE, ICE_HI], "fork": [FORK, FORK_HI], "yellow": [CROSSHAIR_YELLOW, YELLOW_HI], "cobalt": [COBALT, COBALT_HI], "ember": [EMBER, EMBER_HI], "rose": [ROSE, ROSE_HI]}
# Crosshair colours the settings offer (C16b): the shipped mint and four that stand out.
const CROSSHAIR_YELLOW := Color(1.0, 0.882352941, 0.301960784)  # #ffe14d
const CROSSHAIR_MAGENTA := Color(1.0, 0.301960784, 1.0)  # #ff4dff
const CROSSHAIR_CYAN := Color(0.301960784, 0.882352941, 1.0)  # #4de1ff
const CROSSHAIR := {"mint": MINT, "white": FLASH, "yellow": CROSSHAIR_YELLOW, "magenta": CROSSHAIR_MAGENTA, "cyan": CROSSHAIR_CYAN}
## Light-trail mode (C20): each player's wall colour by match slot, slot 1 first, from the
## neons above; slots past the list go round it again.
const TRAILS := [TEAL, HOSTILE_AMBER, FORK, ICE, VIOLET, MATRIX_GREEN, CROSSHAIR_YELLOW, HOSTILE_RED]

# Look tunables. Lengths are in metres, energies multiply the emission colour.
const EDGE_WIDTH := 0.04
const GRID_CELL := 1.0
const GRID_MAJOR_EVERY := 8.0
const GRID_MINOR_WIDTH := 0.02
const GRID_MAJOR_WIDTH := 0.05
const GRID_MINOR_ENERGY := 0.05  # 1.0 before A3: the deck plates carry the floor now
const GRID_MAJOR_ENERGY := 2.2
const WALL_EDGE_ENERGY := 2.0
const ACCENT_EDGE_ENERGY := 2.6
const CRATE_EDGE_ENERGY := 1.6
const HOSTILE_ENERGY := 3.0
# Viewmodel metal (A1): how shiny, the neon rim round the silhouette, the glowing seams, and the
# panel and hex cell sizes, in metres.
const VIEWMODEL_METALLIC := 0.75
const VIEWMODEL_ROUGHNESS := 0.32
const VIEWMODEL_PLATE_ROUGHNESS := 0.5
const VIEWMODEL_RIM_ENERGY := 0.06
const VIEWMODEL_SEAM_ENERGY := 0.05
const VIEWMODEL_CELL_M := 0.045
const VIEWMODEL_HEX_CELL_M := 0.022
const VIEWMODEL_LINE_M := 0.0016
const POLYMER_ROUGHNESS := 0.85
# Daemon look (A2): the shells' true edges (glow and width in pixels), rim, scanlines (per metre, width as a share, climb in m/s), flash
# and lock; the glitch (ticks a second, the share of ticks that glitch, bands per metre, how far a
# band jumps and splits, in metres); the core's energy, breath and flash; the glyphs' energy,
# flicker and flash.
const DAEMON_EDGE_ENERGY := 2.4
const DAEMON_EDGE_PX := 1.3
const DAEMON_RIM_ENERGY := 0.5
const DAEMON_RIM_POWER := 5.0
const DAEMON_SCAN_ENERGY := 0.3
const DAEMON_SCAN_PER_M := 12.0
const DAEMON_SCAN_WIDTH := 0.05
const DAEMON_SCAN_SPEED := 0.35
const DAEMON_FLASH_ENERGY := 6.0
const DAEMON_LOCK_ENERGY := 3.0
const DAEMON_GLITCH_RATE := 9.0
const DAEMON_GLITCH_SHARE := 0.05
const DAEMON_GLITCH_BANDS_PER_M := 7.0
const DAEMON_JITTER_M := 0.018
const DAEMON_SPLIT_M := 0.012
const DAEMON_CORE_ENERGY := 4.0
const DAEMON_CORE_BREATH := 0.18
const DAEMON_CORE_BREATH_HZ := 0.6
const DAEMON_CORE_FLASH_ENERGY := 10.0
const DAEMON_GLYPH_ENERGY := 3.0
const DAEMON_GLYPH_FLICKER := 4.0
const DAEMON_GLYPH_FLASH_ENERGY := 6.0
# Derezz look (A2): the voxels' edge (a share of a face), the face's share of the glow, the edge's
# boost, the cells a face breaks into; the death's flash (a column and a ground ring) and its glow.
const DEREZZ_EDGE_WIDTH := 0.14
const DEREZZ_FACE_SHARE := 0.45
const DEREZZ_EDGE_BOOST := 1.8
const DEREZZ_CELLS := 3.0
const DEREZZ_FLASH_ENERGY := 5.0

# Arena look (A3): the panels' true edges (glow, width in pixels, the distance they fade out by),
# their metal and the darkening near the floor; the strips' glow and the wave through them (a share
# of the glow, waves per metre, how fast), the conduits' data flow the same, the beacons' blink (glow,
# blinks a second, the share of each blink lit); the screens', racks', holograms' and walls' light;
# the towers' edges and windows; the sky's glow band and data points; the floor's deck plates.
const ARENA_EDGE_ENERGY := 0.9
const ARENA_DARK_EDGE_ENERGY := 0.5
const ARENA_EDGE_PX := 1.0
const ARENA_EDGE_FADE_M := 45.0
const ARENA_METALLIC := 0.55
const ARENA_ROUGHNESS := 0.45
const ARENA_GRIME := 0.45
const ARENA_GRIME_M := 0.6
const ARENA_STRIP_ENERGY := 2.2
const ARENA_STRIP_PULSE := 0.2
const ARENA_STRIP_WAVES_PER_M := 0.12
const ARENA_STRIP_WAVE_SPEED := 0.25
const ARENA_FLOW_ENERGY := 3.5
const ARENA_FLOW_PULSE := 0.85
const ARENA_FLOW_WAVES_PER_M := 1.2
const ARENA_FLOW_SPEED := 1.4
const ARENA_BEACON_ENERGY := 6.0
const ARENA_BEACON_HZ := 0.6
const ARENA_BEACON_ON := 0.35
const ARENA_SCREEN_ENERGY := 1.6
const ARENA_RACK_ENERGY := 2.2
const ARENA_HOLO_ENERGY := 3.5
const ARENA_WALL_WASH := 0.04
const ARENA_WALL_WASH_M := 0.6
const TOWER_EDGE_ENERGY := 0.8
const TOWER_WINDOW_ENERGY := 1.1
const TOWER_WINDOW_SHARE := 0.12
const TOWER_WINDOW_CELL_M := Vector2(2.2, 3.0)
const TOWER_WINDOW_SIZE := Vector2(0.55, 0.42)
const SLAB_EDGE_ENERGY := 0.9
const SKY_GLOW_ENERGY := 0.35
const SKY_POINT_SHARE := 0.004
const SKY_POINT_ENERGY := 0.9
const FLOOR_PLATE_M := 2.0
const FLOOR_SEAM_M := 0.03
const FLOOR_SEAM_ENERGY := 0.1
const FLOOR_PLATE_TONE := 0.6
const FLOOR_PLATE_GLOW := 0.008
const FLOOR_INSET_M := 0.16
const FLOOR_INSET_SHARE := 0.4
const FLOOR_INSET_ENERGY := 0.07
const FLOOR_VENT_SHARE := 0.06
const FLOOR_VENT_ENERGY := 0.12

# Shader names under res://shaders/.
const NEON_EDGE_SHADER := "neon_edge"
const CODE_RAIN_SHADER := "code_rain"
const VIEWMODEL_SHADER := "viewmodel_metal"
const DAEMON_SHELL_SHADER := "daemon_shell"
const DAEMON_CORE_SHADER := "daemon_core"
const DAEMON_GLYPH_SHADER := "daemon_glyphs"
const DEREZZ_VOXEL_SHADER := "derezz_voxel"
const ARENA_PANEL_SHADER := "arena_panel"
const ARENA_LIGHT_SHADER := "arena_light"
const ARENA_SCREEN_SHADER := "arena_screen"
const ARENA_HOLO_SHADER := "arena_holo"
const ARENA_TOWER_SHADER := "arena_tower"
## The arena's light materials (A3) by name: its colour, and whether it flows (the conduits) or
## blinks (the beacons) instead of breathing like a strip.
const ARENA_LIGHTS := {"teal": [TEAL, "strip"], "mint": [MINT, "strip"], "red": [HOSTILE_RED, "strip"], "flow": [TEAL, "flow"], "beacon": [HOSTILE_RED, "beacon"]}

static var _shaders: Dictionary = {}
static var _floor_material_cache: ShaderMaterial
static var _arena_cache: Dictionary = {}
static var _mono: SystemFont


## Greybox surface for a block of the given size. Floors share one world-space grid material.
## Every other kind gets its own material so the edge shader knows the block's size. Those
## use the code rain shader: the neon edge look, plus Matrix rain near enemies, which
## scripts/code_rain_driver.gd switches on. Until it does, the rain is off.
static func surface(kind: int, size: Vector3 = Vector3.ONE) -> ShaderMaterial:
	var mat: ShaderMaterial
	match kind:
		Surface.FLOOR:
			mat = _floor_material()
		Surface.ACCENT:
			mat = _neon_material(CODE_RAIN_SHADER, size, MINT, ACCENT_EDGE_ENERGY)
		Surface.CRATE:
			mat = _neon_material(CODE_RAIN_SHADER, size, TEAL, CRATE_EDGE_ENERGY)
		_:
			mat = _neon_material(CODE_RAIN_SHADER, size, TEAL, WALL_EDGE_ENERGY)
	if kind != Surface.FLOOR:
		# The arena's light strips spilling onto the block's sides (A3).
		mat.set_shader_parameter("wash_energy", ARENA_WALL_WASH)
		mat.set_shader_parameter("wash_m", ARENA_WALL_WASH_M)
	return mat


## Hostile target body: neon edges in hostile red on a hexagonal prism.
## radius is the circumradius of the CylinderMesh, height its full height.
static func hostile_material(radius: float, height: float) -> ShaderMaterial:
	var apothem := radius * 0.8660254  # regular hexagon: radius * cos(30 degrees)
	var mat := _neon_material(NEON_EDGE_SHADER, Vector3(apothem * 2.0, height, 0.0), HOSTILE_RED, HOSTILE_ENERGY)
	mat.set_shader_parameter("hex_prism", true)
	return mat


## Another player's body (C13): the same hexagonal prism as a target, in the player side's
## teal. radius is the circumradius of the CylinderMesh, height its full height.
static func ally_material(radius: float, height: float) -> ShaderMaterial:
	var apothem := radius * 0.8660254
	var mat := _neon_material(NEON_EDGE_SHADER, Vector3(apothem * 2.0, height, 0.0), TEAL, ACCENT_EDGE_ENERGY)
	mat.set_shader_parameter("hex_prism", true)
	return mat


## A weapon light skin's body colour: the viewmodel and the muzzle light. Teal when unknown.
static func skin_body(skin: String) -> Color:
	return SKINS.get(skin, SKINS["teal"])[0]


## A weapon light skin's beam colour: tracers, the muzzle flash, a miss's sparks.
static func skin_beam(skin: String) -> Color:
	return SKINS.get(skin, SKINS["teal"])[1]


## Dark body with a glowing emission colour. Used for the weapon viewmodels.
static func glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.65)
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## A viewmodel's metal (A1): `base` gunmetal or a lighter plate, panel lines or hex cells, and a rim
## of `neon`, the weapon's light skin, round its silhouette.
static func viewmodel_metal(base: Color, neon: Color, hex: bool = false, plate: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(VIEWMODEL_SHADER)
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("neon", neon)
	mat.set_shader_parameter("metallic_amount", VIEWMODEL_METALLIC)
	mat.set_shader_parameter("roughness_amount", VIEWMODEL_PLATE_ROUGHNESS if plate else VIEWMODEL_ROUGHNESS)
	mat.set_shader_parameter("rim_energy", VIEWMODEL_RIM_ENERGY)
	mat.set_shader_parameter("seam_energy", VIEWMODEL_SEAM_ENERGY)
	mat.set_shader_parameter("cell_m", VIEWMODEL_HEX_CELL_M if hex else VIEWMODEL_CELL_M)
	mat.set_shader_parameter("line_m", VIEWMODEL_LINE_M)
	mat.set_shader_parameter("hex_cells", hex)
	return mat


## A viewmodel's grips and bands (A1): near-black polymer, matte.
static func viewmodel_polymer() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = POLYMER
	mat.roughness = POLYMER_ROUGHNESS
	return mat


## A viewmodel's hot parts (A1): lenses, cores and bores, lit through in `color` at `energy`.
static func viewmodel_hot(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## The obsidian of every daemon (A2): one material for all of them; each daemon's clock, flash,
## lock and glitch are instance uniforms.
static func daemon_shell_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_SHELL_SHADER)
	mat.set_shader_parameter("obsidian", OBSIDIAN)
	mat.set_shader_parameter("edge", HOSTILE_RED)
	mat.set_shader_parameter("flash_color", HOSTILE_AMBER)
	mat.set_shader_parameter("lock_color", COBALT)
	mat.set_shader_parameter("split_color", GLITCH_SPLIT)
	mat.set_shader_parameter("edge_energy", DAEMON_EDGE_ENERGY)
	mat.set_shader_parameter("edge_px", DAEMON_EDGE_PX)
	mat.set_shader_parameter("rim_energy", DAEMON_RIM_ENERGY)
	mat.set_shader_parameter("rim_power", DAEMON_RIM_POWER)
	mat.set_shader_parameter("scan_energy", DAEMON_SCAN_ENERGY)
	mat.set_shader_parameter("scan_per_m", DAEMON_SCAN_PER_M)
	mat.set_shader_parameter("scan_width", DAEMON_SCAN_WIDTH)
	mat.set_shader_parameter("scan_speed", DAEMON_SCAN_SPEED)
	mat.set_shader_parameter("flash_energy", DAEMON_FLASH_ENERGY)
	mat.set_shader_parameter("lock_energy", DAEMON_LOCK_ENERGY)
	mat.set_shader_parameter("glitch_rate", DAEMON_GLITCH_RATE)
	mat.set_shader_parameter("glitch_share", DAEMON_GLITCH_SHARE)
	mat.set_shader_parameter("glitch_bands_per_m", DAEMON_GLITCH_BANDS_PER_M)
	mat.set_shader_parameter("jitter_m", DAEMON_JITTER_M)
	mat.set_shader_parameter("split_m", DAEMON_SPLIT_M)
	return mat


## Every daemon's core (A2): one material; the colour is each daemon's own instance uniform.
static func daemon_core_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_CORE_SHADER)
	mat.set_shader_parameter("energy", DAEMON_CORE_ENERGY)
	mat.set_shader_parameter("breath", DAEMON_CORE_BREATH)
	mat.set_shader_parameter("breath_hz", DAEMON_CORE_BREATH_HZ)
	mat.set_shader_parameter("flash_energy", DAEMON_CORE_FLASH_ENERGY)
	mat.set_shader_parameter("flash_color", FLASH)
	return mat


## Every daemon's floating glyphs (A2): one material, hostile red.
static func daemon_glyph_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_GLYPH_SHADER)
	mat.set_shader_parameter("glyph_color", HOSTILE_RED)
	mat.set_shader_parameter("energy", DAEMON_GLYPH_ENERGY)
	mat.set_shader_parameter("flicker_rate", DAEMON_GLYPH_FLICKER)
	mat.set_shader_parameter("flash_energy", DAEMON_GLYPH_FLASH_ENERGY)
	return mat


## A derezz's voxels (A2): glowing edges round a dimmer face in each voxel's colour, breaking up
## cell by cell as it fades; `energy` the derezz tuning's glow.
static func derezz_voxel_material(energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DEREZZ_VOXEL_SHADER)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("edge_width", DEREZZ_EDGE_WIDTH)
	mat.set_shader_parameter("face_share", DEREZZ_FACE_SHARE)
	mat.set_shader_parameter("edge_boost", DEREZZ_EDGE_BOOST)
	mat.set_shader_parameter("cells", DEREZZ_CELLS)
	return mat


## The arena's panels (A3): gunmetal with teal true edges, or with `dark` the plinth's and corner
## towers' darker metal with dimmer edges. One of each for the whole arena, made once.
static func arena_panel_material(dark: bool = false) -> ShaderMaterial:
	var key := "panel_dark" if dark else "panel"
	if not _arena_cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = _shader(ARENA_PANEL_SHADER)
		mat.set_shader_parameter("base_color", ARENA_PANEL_DARK if dark else ARENA_PANEL)
		mat.set_shader_parameter("edge_color", TEAL)
		mat.set_shader_parameter("edge_energy", ARENA_DARK_EDGE_ENERGY if dark else ARENA_EDGE_ENERGY)
		mat.set_shader_parameter("edge_px", ARENA_EDGE_PX)
		mat.set_shader_parameter("edge_fade_m", ARENA_EDGE_FADE_M * (3.0 if dark else 1.0))
		mat.set_shader_parameter("metallic_amount", ARENA_METALLIC)
		mat.set_shader_parameter("roughness_amount", ARENA_ROUGHNESS)
		mat.set_shader_parameter("grime", 0.0 if dark else ARENA_GRIME)
		mat.set_shader_parameter("grime_m", ARENA_GRIME_M)
		_arena_cache[key] = mat
	return _arena_cache[key]


## One of the arena's lights (A3) by its ARENA_LIGHTS name: a strip's colour breathing, the
## conduits' flow, or the beacons' blink. One of each for the whole arena, made once.
static func arena_light_material(light: String) -> ShaderMaterial:
	var key := "light_" + light
	if not _arena_cache.has(key):
		var spec: Array = ARENA_LIGHTS.get(light, ARENA_LIGHTS["teal"])
		var mat := ShaderMaterial.new()
		mat.shader = _shader(ARENA_LIGHT_SHADER)
		mat.set_shader_parameter("light_color", spec[0])
		match spec[1]:
			"flow":
				mat.set_shader_parameter("energy", ARENA_FLOW_ENERGY)
				mat.set_shader_parameter("pulse", ARENA_FLOW_PULSE)
				mat.set_shader_parameter("waves_per_m", ARENA_FLOW_WAVES_PER_M)
				mat.set_shader_parameter("wave_speed", ARENA_FLOW_SPEED)
				mat.set_shader_parameter("blink", 0.0)
			"beacon":
				mat.set_shader_parameter("energy", ARENA_BEACON_ENERGY)
				mat.set_shader_parameter("pulse", 0.0)
				mat.set_shader_parameter("blink", 1.0)
				mat.set_shader_parameter("blink_hz", ARENA_BEACON_HZ)
				mat.set_shader_parameter("blink_on", ARENA_BEACON_ON)
			_:
				mat.set_shader_parameter("energy", ARENA_STRIP_ENERGY)
				mat.set_shader_parameter("pulse", ARENA_STRIP_PULSE)
				mat.set_shader_parameter("waves_per_m", ARENA_STRIP_WAVES_PER_M)
				mat.set_shader_parameter("wave_speed", ARENA_STRIP_WAVE_SPEED)
				mat.set_shader_parameter("blink", 0.0)
		_arena_cache[key] = mat
	return _arena_cache[key]


## The arena's terminal screens, or with `racks` its server racks' faces (A3). Made once each.
static func arena_screen_material(racks: bool = false) -> ShaderMaterial:
	var key := "racks" if racks else "screen"
	if not _arena_cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = _shader(ARENA_SCREEN_SHADER)
		mat.set_shader_parameter("back_color", ARENA_SCREEN)
		mat.set_shader_parameter("text_color", TEAL)
		mat.set_shader_parameter("hot_color", MINT)
		mat.set_shader_parameter("alert_color", HOSTILE_RED)
		mat.set_shader_parameter("racks", racks)
		mat.set_shader_parameter("energy", ARENA_RACK_ENERGY if racks else ARENA_SCREEN_ENERGY)
		_arena_cache[key] = mat
	return _arena_cache[key]


## The floating ">_" glyphs over the arena's pylons (A3): one material for their one MultiMesh.
static func arena_holo_material() -> ShaderMaterial:
	if not _arena_cache.has("holo"):
		var mat := ShaderMaterial.new()
		mat.shader = _shader(ARENA_HOLO_SHADER)
		mat.set_shader_parameter("holo_color", MINT)
		mat.set_shader_parameter("energy", ARENA_HOLO_ENERGY)
		_arena_cache["holo"] = mat
	return _arena_cache["holo"]


## The skyline's towers with their windows, or with `windows` off the drifting slabs, edges only
## and brighter (A3). Made once each.
static func arena_tower_material(windows: bool = true) -> ShaderMaterial:
	var key := "tower" if windows else "slab"
	if not _arena_cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = _shader(ARENA_TOWER_SHADER)
		mat.set_shader_parameter("body_color", ARENA_TOWER)
		mat.set_shader_parameter("edge_color", TEAL)
		mat.set_shader_parameter("window_color", TEAL)
		mat.set_shader_parameter("hot_color", MINT)
		mat.set_shader_parameter("alert_color", HOSTILE_RED)
		mat.set_shader_parameter("edge_energy", TOWER_EDGE_ENERGY if windows else SLAB_EDGE_ENERGY)
		mat.set_shader_parameter("window_energy", TOWER_WINDOW_ENERGY)
		mat.set_shader_parameter("window_share", TOWER_WINDOW_SHARE if windows else 0.0)
		mat.set_shader_parameter("window_cell_m", TOWER_WINDOW_CELL_M)
		mat.set_shader_parameter("window_size", TOWER_WINDOW_SIZE)
		_arena_cache[key] = mat
	return _arena_cache[key]


## Every material the arena's dressing and skyline use (A3), for the checks.
static func arena_materials() -> Array:
	var out := [arena_panel_material(), arena_panel_material(true), arena_screen_material(), arena_screen_material(true), arena_holo_material(), arena_tower_material(), arena_tower_material(false)]
	for light in ARENA_LIGHTS:
		out.append(arena_light_material(light))
	return out


## The arena's environment in the palette's exact colours (the scene file carries approximations so
## the editor previews it): the void, the ambient teal, the depth fog (A3) and the sky's (A3).
static func apply_arena_environment(env: Environment) -> void:
	env.background_color = VOID
	env.ambient_light_color = TEAL
	env.fog_light_color = FOG
	if env.sky != null and env.sky.sky_material is ShaderMaterial:
		var sky := env.sky.sky_material as ShaderMaterial
		sky.set_shader_parameter("zenith_color", VOID)
		sky.set_shader_parameter("horizon_color", SKY_HORIZON)
		sky.set_shader_parameter("abyss_color", SKY_ABYSS)
		sky.set_shader_parameter("glow_color", TEAL)
		sky.set_shader_parameter("point_color", MINT)
		sky.set_shader_parameter("alert_color", HOSTILE_RED)
		sky.set_shader_parameter("glow_energy", SKY_GLOW_ENERGY)
		sky.set_shader_parameter("point_share", SKY_POINT_SHARE)
		sky.set_shader_parameter("point_energy", SKY_POINT_ENERGY)


## Unlit translucent material for beams and impact flashes.
static func unlit_alpha(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


## Unlit, translucent and over-bright, for effects that should bloom: beams, flashes,
## sparks. energy scales the colour above 1 so the glow pass picks it up.
static func unlit_glow(color: Color, energy: float) -> StandardMaterial3D:
	return unlit_alpha(Color(color.r * energy, color.g * energy, color.b * energy, color.a))


## The light-trail wall colour of match slot `slot` (1 and up; anything else gets slot 1's).
static func trail_color(slot: int) -> Color:
	return TRAILS[(maxi(slot, 1) - 1) % TRAILS.size()]


## Unlit, see-through from both sides, and coloured per instance: light-trail walls (C20),
## whose MultiMesh gives each segment its player's colour pushed past full brightness for
## bloom, and its fade in the alpha.
static func trail_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = FLASH
	return mat


## Opacity ramp for particles: fully visible at birth, gone by the end of their life.
static func fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, FLASH)
	ramp.set_color(1, Color(FLASH, 0.0))
	return ramp


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	return _mono


static func _shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]


static func _floor_material() -> ShaderMaterial:
	if _floor_material_cache == null:
		var mat := ShaderMaterial.new()
		mat.shader = _shader("floor_grid")
		mat.set_shader_parameter("base_color", BASE)
		mat.set_shader_parameter("minor_color", TEAL)
		mat.set_shader_parameter("major_color", MINT)
		mat.set_shader_parameter("cell_size", GRID_CELL)
		mat.set_shader_parameter("major_every", GRID_MAJOR_EVERY)
		mat.set_shader_parameter("minor_width", GRID_MINOR_WIDTH)
		mat.set_shader_parameter("major_width", GRID_MAJOR_WIDTH)
		mat.set_shader_parameter("minor_energy", GRID_MINOR_ENERGY)
		mat.set_shader_parameter("major_energy", GRID_MAJOR_ENERGY)
		mat.set_shader_parameter("plate_m", FLOOR_PLATE_M)
		mat.set_shader_parameter("seam_m", FLOOR_SEAM_M)
		mat.set_shader_parameter("seam_energy", FLOOR_SEAM_ENERGY)
		mat.set_shader_parameter("plate_tone", FLOOR_PLATE_TONE)
		mat.set_shader_parameter("plate_glow", FLOOR_PLATE_GLOW)
		mat.set_shader_parameter("inset_m", FLOOR_INSET_M)
		mat.set_shader_parameter("inset_share", FLOOR_INSET_SHARE)
		mat.set_shader_parameter("inset_energy", FLOOR_INSET_ENERGY)
		mat.set_shader_parameter("vent_share", FLOOR_VENT_SHARE)
		mat.set_shader_parameter("vent_energy", FLOOR_VENT_ENERGY)
		_floor_material_cache = mat
	return _floor_material_cache


static func _neon_material(shader_name: String, size: Vector3, edge: Color, energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(shader_name)
	mat.set_shader_parameter("face_color", BASE)
	mat.set_shader_parameter("edge_color", edge)
	mat.set_shader_parameter("edge_width", EDGE_WIDTH)
	mat.set_shader_parameter("edge_energy", energy)
	mat.set_shader_parameter("hex_prism", false)
	mat.set_shader_parameter("half_extents", size * 0.5)
	return mat
