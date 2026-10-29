@tool
extends RefCounted
## SIGKILL palette and material factory. The single source for every colour and look tunable.
##
## Tron look: void-black sky, near-black faces, glowing neon edges and grid lines.
## Teal and mint belong to the player side, red and amber to hostiles, magenta to a daemon's
## glitch (A4). Warm sodium (A4) belongs to the world's signs and key lights only, so the eye has
## a warm accent to read against the teal.
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
const LIME := Color(0.721568627, 1.0, 0.176470588)  # #b8ff2d ping's body, its sonar ring and the outline of what it finds (C28): yellow-green, between the code rain's green and fork()'s yellow but neither
const LIME_HI := Color(0.894117647, 1.0, 0.701960784)  # #e4ffb3 ping's ring front and its tags
# Weapon viewmodels (A1): dark gunmetal bodies, lighter plates and shrouds, near-black polymer
# grips, under each weapon's neon trim (its light skin) and hot parts (its beam colour).
const GUNMETAL := Color(0.047058824, 0.062745098, 0.078431373)  # #0c1014 viewmodel body
const GUNMETAL_LIGHT := Color(0.109803922, 0.137254902, 0.164705882)  # #1c232a viewmodel plates and shrouds
const POLYMER := Color(0.023529412, 0.027450980, 0.031372549)  # #060708 viewmodel grips and bands
# Daemons (A2): black obsidian glass, a hostile red rim and scanlines, a cyan split in a glitch,
# cores in the type's own hostile colour, red glyphs.
const OBSIDIAN := Color(0.011764706, 0.015686275, 0.019607843)  # #030405 daemon shells
const GLITCH_SPLIT := Color(1.0, 0.168627451, 0.839215686)  # #ff2bd6 the far side of a daemon's glitch split: hostile magenta (A4; cyan #4de1ff before)
# Daemons' own colours (A5): each type's seams, joints, weak points and glyphs, so the three read
# apart at a glance: rogue.d crimson (deeper than the HUD's hostile red), the zombie hostile amber,
# the runaway hot magenta (redder than the fork bomb's #ff4dff). Their armour (A5): near-black
# gunmetal with a blue cast, catching the arena's light on its bevels.
const CRIMSON := Color(1.0, 0.070588235, 0.188235294)  # #ff1230 rogue.d's seams, visor and stinger
const HOT_MAGENTA := Color(1.0, 0.105882353, 0.643137255)  # #ff1ba4 the runaway's drones, core and trails
const DAEMON_ARMOR := Color(0.050980392, 0.058823529, 0.074509804)  # #0d0f13 every daemon's armour
# ICE (I1): the system defending itself, its own colours, read apart from the player's teal, the
# rail's ice-white, ping's lime and every daemon's (OKLab distances in docs/DESIGN.md "I1 as built").
# White ICE glacier blue (cooler and more azure than grep's cobalt, which the brief's #3d8bff sat on
# top of), hunter ICE a deeper cobalt (bluer and darker than grep's), its HUD text a light tint of it;
# every piece's body a near-black cold glass with a blue cast.
const GLACIER := Color(0.094117647, 0.698039216, 1.0)  # #18b2ff white ICE: walls, nodes, their fields
const HUNTER_COBALT := Color(0.117647059, 0.188235294, 1.0)  # #1e30ff hunter ICE's seams, core and lance
const HUNTER_TEXT := Color(0.603921569, 0.650980392, 1.0)  # #9aa6ff the hunter's HUD line, legible on black
const ICE_CRYSTAL := Color(0.031372549, 0.070588235, 0.121568627)  # #08121f every piece's body
# ICEbreakers (I2): the intruder's one-use programs, their pickups, decoys, seam marks and charge, in an
# ultraviolet of their own: the farthest (OKLab) from every bright colour above that a search of the
# hue wheel found (0.161 from the hunter's cobalt, 0.165 from SIGTERM's violet); its HUD text a light
# tint of it, legible on black and 0.10 from violet and the hunter's line.
const BREAKER := Color(0.454901961, 0.0, 0.8)  # #7400cc pickups, decoys, exploit's seam marks, the brute's charge
const BREAKER_TEXT := Color(0.760784314, 0.498039216, 1.0)  # #c27fff the breaker readout and its notices
# Lighting (A4): the warm accent of the arena's signs and the key lights by them.
const SODIUM := Color(1.0, 0.560784314, 0.149019608)  # #ff8f26 signs and their lamps
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
const SKINS := {"teal": [TEAL, MINT], "violet": [VIOLET, VIOLET_HI], "ice": [ICE, ICE_HI], "fork": [FORK, FORK_HI], "yellow": [CROSSHAIR_YELLOW, YELLOW_HI], "cobalt": [COBALT, COBALT_HI], "ember": [EMBER, EMBER_HI], "rose": [ROSE, ROSE_HI], "lime": [LIME, LIME_HI]}
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
# Daemon look (A2, heavier in A2b): the shells' true edges (glow and width in pixels; a wire part's,
# a ghost's), rim, scanlines (per metre, width as a share, climb in m/s), flash and lock; the
# glitch (ticks a second, the share of ticks that glitch, bands per metre, how far a band jumps and
# splits, in metres; the scanline tear's ticks, share, bands and push; the share of ticks a part
# snaps and how far); the split pass (its glow, its offset in pixels, the pull toward the camera
# in metres, a ghost's share); presence cells per metre; the core's energy, breath and flash; the
# trails' energy; the glyphs' energy, flicker and flash.
const DAEMON_EDGE_ENERGY := 3.0
const DAEMON_EDGE_PX := 1.4
const DAEMON_WIRE_PX := 1.8
const DAEMON_WIRE_ENERGY := 2.8
const DAEMON_GHOST_ENERGY := 1.8
const DAEMON_RIM_ENERGY := 0.6
const DAEMON_RIM_POWER := 5.0
const DAEMON_SCAN_ENERGY := 0.35
const DAEMON_SCAN_PER_M := 12.0
const DAEMON_SCAN_WIDTH := 0.05
const DAEMON_SCAN_SPEED := 0.35
const DAEMON_FLASH_ENERGY := 6.0
const DAEMON_LOCK_ENERGY := 3.0
const DAEMON_GLITCH_RATE := 9.0
const DAEMON_GLITCH_SHARE := 0.08
const DAEMON_GLITCH_BANDS_PER_M := 7.0
const DAEMON_JITTER_M := 0.035
const DAEMON_SPLIT_M := 0.02
const DAEMON_TEAR_RATE := 14.0
const DAEMON_TEAR_SHARE := 0.05
const DAEMON_TEAR_BANDS_PER_M := 24.0
const DAEMON_TEAR_M := 0.06
const DAEMON_PART_SHARE := 0.02
const DAEMON_PART_JUMP_M := 0.05
const DAEMON_SPLIT_ENERGY := 3.0
const DAEMON_SPLIT_PX := 6.0
const DAEMON_SPLIT_PULL_M := 0.12
const DAEMON_GHOST_SPLIT := 0.35
const DAEMON_CELLS_PER_M := 28.0
const DAEMON_CORE_ENERGY := 4.0
const DAEMON_CORE_BREATH := 0.25
const DAEMON_CORE_BREATH_HZ := 0.6
const DAEMON_CORE_FLASH_ENERGY := 10.0
const DAEMON_TRAIL_ENERGY := 4.0
const DAEMON_GLYPH_ENERGY := 3.0
const DAEMON_GLYPH_FLICKER := 4.0
const DAEMON_GLYPH_FLASH_ENERGY := 6.0
# The armour (A5): how metallic and how rough, how far each plate's tone strays, the faint light on
# its true edges (a machined bevel) and its colour, the rim in the type's colour where it turns away,
# a scorched plate's darkening, and its calmer glitch at rest (a hit or a respawn still tears it).
const DAEMON_ARMOR_METALLIC := 0.55
const DAEMON_ARMOR_ROUGHNESS := 0.32
const DAEMON_ARMOR_TINT := 0.35
const DAEMON_ARMOR_BEVEL_ENERGY := 0.24
const DAEMON_ARMOR_BEVEL := Color(0.62, 0.74, 0.8)  # #9ebdcc a cool steel catch-light
const DAEMON_ARMOR_RIM_ENERGY := 0.15
const DAEMON_ARMOR_RIM_POWER := 5.0
const DAEMON_ARMOR_SCORCH := 0.7
const DAEMON_ARMOR_GLITCH_SHARE := 0.015
const DAEMON_ARMOR_TEAR_SHARE := 0.01
const DAEMON_ARMOR_PART_SHARE := 0.004
# The seams (A5): how fast a damaged seam's flicker rolls, a second, and a seam's brightness, a share
# of a core's (dimmer, so it stays its type's colour in the glow instead of burning white).
const DAEMON_SEAM_FLICKER_HZ := 9.0
const DAEMON_SEAM_GLOW := 0.6
# ICE's look (I1): its glass (metal, roughness, specular, each facet's tone), the light inside its
# facets (their share and how few of them hold most of it), its seams' line (fading far off to a share
# of itself between two distances, so a piece never reads as a wire) and its cold rim, its
# cracks (their glow, their cells across a part, their width), a hit's flash; its light (the seams'
# and cores' colour, steadier than a daemon's: a slow breath, never a glitch); a node's field dome
# (its rim, its lattice and how fine, its firing flash).
const ICE_METALLIC := 0.2
const ICE_ROUGHNESS := 0.12
const ICE_SPECULAR := 0.8
const ICE_TINT := 0.3
const ICE_FACET_ENERGY := 0.1
const ICE_FACET_POWER := 3.0
const ICE_EDGE_ENERGY := 0.07
const ICE_EDGE_PX := 1.0
const ICE_EDGE_NEAR_M := 4.0
const ICE_EDGE_FAR_M := 16.0
const ICE_EDGE_FAR := 0.2
const ICE_RIM_ENERGY := 0.12
const ICE_RIM_POWER := 3.0
const ICE_CRACK_ENERGY := 1.1
const ICE_CRACK_CELLS := 3.0
const ICE_CRACK_WIDTH := 0.035
const ICE_FLASH_ENERGY := 2.0
const ICE_LIGHT_ENERGY := 3.2
const ICE_LIGHT_BREATH := 0.15
const ICE_LIGHT_BREATH_HZ := 0.35
const ICE_LIGHT_FLASH_ENERGY := 2.5
const ICE_FIELD_RIM_ENERGY := 2.4
const ICE_FIELD_LATTICE_ENERGY := 1.1
const ICE_FIELD_CELLS := 26.0
const ICE_FIELD_FLASH_ENERGY := 6.0
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

# Lighting and post (A4). The tonemapper is AgX: very bright saturated neon rolls off toward white
# without ACES's hue skew (ACES turns hot red toward orange and teal toward a flat cyan-white), so
# each side keeps its colour at the core of a glow; its contrast raised over Godot's so the dark
# world keeps its depth. The glow: only what is over the threshold glows (the neon, never a dark
# face, so no blown-out mush), a tight bright core over a wider soft halo, mixed by Screen so a
# pile of glows never clips to a white blot. SSAO and SSR (the high preset): a short, light
# occlusion in the corners and under the cover, and reflections in the floor's gloss. The grade:
# a touch more contrast and saturation and a per-channel curve that cools the shadows and warms
# the highlights. The floor's deck plates are gloss (seams and vents stay matt) so the neon has
# something to shine in. The signs' lamps and the lair's danger lights (their reach and glow,
# and the danger lights' slow pulse). The screen post effects' strengths (see
# shaders/screen_post.gdshader), off unless their settings are on.
const TONEMAP_AGX_WHITE := 10.0
const TONEMAP_AGX_CONTRAST := 1.35
const TONEMAP_EXPOSURE := 1.05
const GLOW_INTENSITY := 0.8
const GLOW_STRENGTH := 1.1
const GLOW_THRESHOLD := 0.9
const GLOW_HDR_SCALE := 1.4
const GLOW_LUMINANCE_CAP := 5.0
## Each glow level's weight, levels 1 to 7 (the first is the tightest).
const GLOW_LEVELS := [0.0, 0.9, 0.7, 0.5, 0.35, 0.15, 0.0]
const SSAO_RADIUS := 0.9
const SSAO_INTENSITY := 1.4
const SSAO_POWER := 1.6
const SSAO_DETAIL := 0.4
const SSR_STEPS := 40
const SSR_FADE_IN := 0.15
const SSR_FADE_OUT := 2.0
const SSR_DEPTH_TOLERANCE := 0.25
const GRADE_CONTRAST := 1.06
const GRADE_SATURATION := 1.1
## The grade's curve: [input, output red, green, blue] at each point, 0 to 1.
const GRADE_CURVE := [[0.0, 0.0, 0.006, 0.02], [0.25, 0.225, 0.248, 0.27], [0.5, 0.5, 0.5, 0.49], [0.75, 0.775, 0.76, 0.725], [1.0, 1.0, 0.99, 0.95]]
const FLOOR_GLOSS := 0.18
const FLOOR_SPECULAR := 0.5
const SIGN_LAMP_ENERGY := 1.6
const SIGN_LAMP_RANGE_M := 5.0
const DANGER_LIGHT_ENERGY := 2.2
const DANGER_LIGHT_RANGE_M := 7.5
const DANGER_PULSE := 0.35
const DANGER_PULSE_HZ := 0.4
const POST_ABERRATION_PX := 3.0
const POST_SCANLINE_DARK := 0.22
const POST_SCANLINE_PX := 3.0
const POST_GRILLE := 0.06
const POST_VIGNETTE := 0.35

# Shader names under res://shaders/.
const NEON_EDGE_SHADER := "neon_edge"
const CODE_RAIN_SHADER := "code_rain"
const VIEWMODEL_SHADER := "viewmodel_metal"
const DAEMON_SHELL_SHADER := "daemon_shell"
const DAEMON_CORE_SHADER := "daemon_core"
const DAEMON_GLYPH_SHADER := "daemon_glyphs"
const DAEMON_SPLIT_SHADER := "daemon_split"
const DAEMON_TRAIL_SHADER := "daemon_trail"
const DAEMON_ARMOR_SHADER := "daemon_armor"
const ICE_CRYSTAL_SHADER := "ice_crystal"
const ICE_FIELD_SHADER := "ice_field"
const DEREZZ_VOXEL_SHADER := "derezz_voxel"
const ARENA_PANEL_SHADER := "arena_panel"
const ARENA_LIGHT_SHADER := "arena_light"
const ARENA_SCREEN_SHADER := "arena_screen"
const ARENA_HOLO_SHADER := "arena_holo"
const ARENA_TOWER_SHADER := "arena_tower"
## The arena's light materials (A3) by name: its colour, and whether it flows (the conduits) or
## blinks (the beacons) instead of breathing like a strip.
const ARENA_LIGHTS := {"teal": [TEAL, "strip"], "mint": [MINT, "strip"], "red": [HOSTILE_RED, "strip"], "flow": [TEAL, "flow"], "beacon": [HOSTILE_RED, "beacon"], "warm": [SODIUM, "strip"]}

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


## The obsidian of every daemon (A2, A2b): one material for all of them, the RGB split its next
## pass; each daemon's flash, lock, glitch, seed and edge colour are instance uniforms.
static func daemon_shell_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_SHELL_SHADER)
	mat.set_shader_parameter("obsidian", OBSIDIAN)
	mat.set_shader_parameter("flash_color", HOSTILE_AMBER)
	mat.set_shader_parameter("lock_color", COBALT)
	mat.set_shader_parameter("split_color", GLITCH_SPLIT)
	mat.set_shader_parameter("edge_energy", DAEMON_EDGE_ENERGY)
	mat.set_shader_parameter("edge_px", DAEMON_EDGE_PX)
	mat.set_shader_parameter("wire_px", DAEMON_WIRE_PX)
	mat.set_shader_parameter("wire_energy", DAEMON_WIRE_ENERGY)
	mat.set_shader_parameter("ghost_energy", DAEMON_GHOST_ENERGY)
	mat.set_shader_parameter("rim_energy", DAEMON_RIM_ENERGY)
	mat.set_shader_parameter("rim_power", DAEMON_RIM_POWER)
	mat.set_shader_parameter("scan_energy", DAEMON_SCAN_ENERGY)
	mat.set_shader_parameter("scan_per_m", DAEMON_SCAN_PER_M)
	mat.set_shader_parameter("scan_width", DAEMON_SCAN_WIDTH)
	mat.set_shader_parameter("scan_speed", DAEMON_SCAN_SPEED)
	mat.set_shader_parameter("flash_energy", DAEMON_FLASH_ENERGY)
	mat.set_shader_parameter("lock_energy", DAEMON_LOCK_ENERGY)
	mat.set_shader_parameter("split_m", DAEMON_SPLIT_M)
	mat.set_shader_parameter("cells_per_m", DAEMON_CELLS_PER_M)
	_daemon_glitch(mat)
	var split := ShaderMaterial.new()
	split.shader = _shader(DAEMON_SPLIT_SHADER)
	split.set_shader_parameter("split_color", GLITCH_SPLIT)
	split.set_shader_parameter("split_energy", DAEMON_SPLIT_ENERGY)
	split.set_shader_parameter("split_px", DAEMON_SPLIT_PX)
	split.set_shader_parameter("edge_px", DAEMON_EDGE_PX)
	split.set_shader_parameter("pull_m", DAEMON_SPLIT_PULL_M)
	split.set_shader_parameter("ghost_split", DAEMON_GHOST_SPLIT)
	_daemon_glitch(split)
	mat.next_pass = split
	return mat


## Every daemon's glowing parts (A2, A2b): one material; the colour is each daemon's own instance
## uniform.
static func daemon_core_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_CORE_SHADER)
	mat.set_shader_parameter("energy", DAEMON_CORE_ENERGY)
	mat.set_shader_parameter("breath", DAEMON_CORE_BREATH)
	mat.set_shader_parameter("breath_hz", DAEMON_CORE_BREATH_HZ)
	mat.set_shader_parameter("flash_energy", DAEMON_CORE_FLASH_ENERGY)
	mat.set_shader_parameter("flash_color", FLASH)
	mat.set_shader_parameter("cells_per_m", DAEMON_CELLS_PER_M)
	mat.set_shader_parameter("flicker_hz", DAEMON_SEAM_FLICKER_HZ)
	_daemon_glitch(mat)
	return mat


## Every daemon's armour (A5): one material for all of them; each daemon's flash, lock, glitch, seed
## and colour (its rim, edge_color) are instance uniforms, each plate's tone and scorch its custom
## data. Solid: no split pass, and a calmer glitch at rest than the obsidian's.
static func daemon_armor_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_ARMOR_SHADER)
	mat.set_shader_parameter("armor", DAEMON_ARMOR)
	mat.set_shader_parameter("metallic_amount", DAEMON_ARMOR_METALLIC)
	mat.set_shader_parameter("roughness_amount", DAEMON_ARMOR_ROUGHNESS)
	mat.set_shader_parameter("tint", DAEMON_ARMOR_TINT)
	mat.set_shader_parameter("bevel_color", DAEMON_ARMOR_BEVEL)
	mat.set_shader_parameter("bevel_energy", DAEMON_ARMOR_BEVEL_ENERGY)
	mat.set_shader_parameter("edge_px", DAEMON_EDGE_PX)
	mat.set_shader_parameter("rim_energy", DAEMON_ARMOR_RIM_ENERGY)
	mat.set_shader_parameter("rim_power", DAEMON_ARMOR_RIM_POWER)
	mat.set_shader_parameter("scorch_dark", DAEMON_ARMOR_SCORCH)
	mat.set_shader_parameter("flash_color", HOSTILE_AMBER)
	mat.set_shader_parameter("flash_energy", DAEMON_FLASH_ENERGY)
	mat.set_shader_parameter("lock_color", COBALT)
	mat.set_shader_parameter("lock_energy", DAEMON_LOCK_ENERGY)
	mat.set_shader_parameter("cells_per_m", DAEMON_CELLS_PER_M)
	_daemon_glitch(mat)
	mat.set_shader_parameter("glitch_share", DAEMON_ARMOR_GLITCH_SHARE)
	mat.set_shader_parameter("tear_share", DAEMON_ARMOR_TEAR_SHARE)
	mat.set_shader_parameter("part_share", DAEMON_ARMOR_PART_SHARE)
	return mat


## Every piece of ICE's crystal body (I1): one material for all of them; each piece's colour
## (edge_color: glacier, or a hunter's cobalt tinted toward what it adapted to) and flash are
## instance uniforms, each part's tone, presence and crack its custom data. Still: no glitch.
static func ice_crystal_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(ICE_CRYSTAL_SHADER)
	mat.set_shader_parameter("crystal", ICE_CRYSTAL)
	mat.set_shader_parameter("metallic_amount", ICE_METALLIC)
	mat.set_shader_parameter("roughness_amount", ICE_ROUGHNESS)
	mat.set_shader_parameter("specular_amount", ICE_SPECULAR)
	mat.set_shader_parameter("tint", ICE_TINT)
	mat.set_shader_parameter("facet_energy", ICE_FACET_ENERGY)
	mat.set_shader_parameter("facet_power", ICE_FACET_POWER)
	mat.set_shader_parameter("edge_energy", ICE_EDGE_ENERGY)
	mat.set_shader_parameter("edge_px", ICE_EDGE_PX)
	mat.set_shader_parameter("edge_near_m", ICE_EDGE_NEAR_M)
	mat.set_shader_parameter("edge_far_m", ICE_EDGE_FAR_M)
	mat.set_shader_parameter("edge_far", ICE_EDGE_FAR)
	mat.set_shader_parameter("rim_energy", ICE_RIM_ENERGY)
	mat.set_shader_parameter("rim_power", ICE_RIM_POWER)
	mat.set_shader_parameter("crack_energy", ICE_CRACK_ENERGY)
	mat.set_shader_parameter("crack_cells", ICE_CRACK_CELLS)
	mat.set_shader_parameter("crack_width", ICE_CRACK_WIDTH)
	mat.set_shader_parameter("flash_color", FLASH)
	mat.set_shader_parameter("flash_energy", ICE_FLASH_ENERGY)
	mat.set_shader_parameter("cells_per_m", DAEMON_CELLS_PER_M)
	return mat


## ICE's light (I1): its seams, joints and cores, the daemon core shader in the piece's colour, but
## steady: a slower, shallower breath and no glitch at all (ICE is the system's own exact code).
static func ice_light_material() -> ShaderMaterial:
	var mat := daemon_core_material()
	mat.set_shader_parameter("energy", ICE_LIGHT_ENERGY)
	mat.set_shader_parameter("breath", ICE_LIGHT_BREATH)
	mat.set_shader_parameter("breath_hz", ICE_LIGHT_BREATH_HZ)
	mat.set_shader_parameter("flash_energy", ICE_LIGHT_FLASH_ENERGY)
	for key in ["glitch_share", "tear_share", "part_share", "jitter_m", "tear_m", "part_jump_m"]:
		mat.set_shader_parameter(key, 0.0)
	return mat


## A white ICE node's field dome (I1): one material for every node, its colour and its moment
## (warning, firing flash, scramble) instance uniforms.
static func ice_field_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(ICE_FIELD_SHADER)
	mat.set_shader_parameter("rim_energy", ICE_FIELD_RIM_ENERGY)
	mat.set_shader_parameter("lattice_energy", ICE_FIELD_LATTICE_ENERGY)
	mat.set_shader_parameter("lattice_cells", ICE_FIELD_CELLS)
	mat.set_shader_parameter("flash_energy", ICE_FIELD_FLASH_ENERGY)
	return mat


## A swarm's light trails (A2b): one material, added on top, in each daemon's own colour.
static func daemon_trail_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_TRAIL_SHADER)
	mat.set_shader_parameter("energy", DAEMON_TRAIL_ENERGY)
	mat.set_shader_parameter("head_color", FLASH)
	return mat


## Every daemon's floating glyphs (A2): one material, each daemon's in its own colour (A5: its
## core_color instance uniform; hostile red for all before).
static func daemon_glyph_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(DAEMON_GLYPH_SHADER)
	mat.set_shader_parameter("energy", DAEMON_GLYPH_ENERGY)
	mat.set_shader_parameter("flicker_rate", DAEMON_GLYPH_FLICKER)
	mat.set_shader_parameter("flash_energy", DAEMON_GLYPH_FLASH_ENERGY)
	return mat


## The glitch every daemon shader shares (A2b, shaders/daemon_glitch.gdshaderinc), set on `mat`.
static func _daemon_glitch(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("glitch_rate", DAEMON_GLITCH_RATE)
	mat.set_shader_parameter("glitch_share", DAEMON_GLITCH_SHARE)
	mat.set_shader_parameter("glitch_bands_per_m", DAEMON_GLITCH_BANDS_PER_M)
	mat.set_shader_parameter("jitter_m", DAEMON_JITTER_M)
	mat.set_shader_parameter("tear_rate", DAEMON_TEAR_RATE)
	mat.set_shader_parameter("tear_share", DAEMON_TEAR_SHARE)
	mat.set_shader_parameter("tear_bands_per_m", DAEMON_TEAR_BANDS_PER_M)
	mat.set_shader_parameter("tear_m", DAEMON_TEAR_M)
	mat.set_shader_parameter("part_share", DAEMON_PART_SHARE)
	mat.set_shader_parameter("part_jump_m", DAEMON_PART_JUMP_M)


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
## the editor previews it): the void, the ambient teal, the depth fog (A3) and the sky's (A3); and the
## A4 look: the tonemapper, the glow, SSAO's and SSR's settings (the quality preset turns them on)
## and the grade. Bloom, SSAO and SSR are switched by scripts/main.gd from the settings.
static func apply_arena_environment(env: Environment) -> void:
	env.background_color = VOID
	env.ambient_light_color = TEAL
	env.fog_light_color = FOG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_white = TONEMAP_AGX_WHITE
	env.tonemap_agx_contrast = TONEMAP_AGX_CONTRAST
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.glow_intensity = GLOW_INTENSITY
	env.glow_strength = GLOW_STRENGTH
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_hdr_scale = GLOW_HDR_SCALE
	env.glow_hdr_luminance_cap = GLOW_LUMINANCE_CAP
	env.glow_normalized = false
	for level in GLOW_LEVELS.size():
		env.set_glow_level(level, GLOW_LEVELS[level])
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_power = SSAO_POWER
	env.ssao_detail = SSAO_DETAIL
	env.ssr_max_steps = SSR_STEPS
	env.ssr_fade_in = SSR_FADE_IN
	env.ssr_fade_out = SSR_FADE_OUT
	env.ssr_depth_tolerance = SSR_DEPTH_TOLERANCE
	env.adjustment_enabled = true
	env.adjustment_contrast = GRADE_CONTRAST
	env.adjustment_saturation = GRADE_SATURATION
	env.adjustment_color_correction = grade_curve()
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


## The grade's per-channel curve (A4) as a one-row lookup table, made once.
static func grade_curve() -> GradientTexture1D:
	if not _arena_cache.has("grade"):
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array(GRADE_CURVE.map(func(p): return p[0]))
		ramp.colors = PackedColorArray(GRADE_CURVE.map(func(p): return Color(p[1], p[2], p[3])))
		var lut := GradientTexture1D.new()
		lut.gradient = ramp
		_arena_cache["grade"] = lut
	return _arena_cache["grade"]


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
		mat.set_shader_parameter("gloss", FLOOR_GLOSS)
		mat.set_shader_parameter("specular_amount", FLOOR_SPECULAR)
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
