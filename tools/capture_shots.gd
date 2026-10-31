extends SceneTree
## Demo-data stills of SIGKILL for the README, by set (-- --set=a1, the default, a2, a3, a2b, a4, c27b, c28, a5, i1, i2, i3, c29, c30, c31, c32, c33, c38, c39, c40, c41 or c42):
## a1, every weapon of the arsenal held in first person, at rest and mid-shot (and mid-charge for
## one that charges), and one wider view, the rail on a daemon; a2, each kind of daemon up close,
## several in one view, a derezz mid-shatter, and one wider view, grep locked on a daemon between
## the pillars; a3, the arena: a wide overview from above, the skyline and the void from off its
## north-east corner, then in play the west corridor, the lair's front, and one wider view, daemons
## ahead and a weapon in hand; a2b, the daemons as creatures: each one's hero view from a free
## camera and a strip of three stills of its motion side by side (the rogue daemon's through a rear
## and its strike), one view in play with all three kinds in it, and the rogue daemon's death in
## shards; a4, the arena lit and finished: the overview from above, a fight (the cannon fired past the
## rogue daemon into its lair's wall: the muzzle burst, the beam, the sparks), the west corridor with the zombie,
## one view at the low and the high preset side by side (with each preset's GPU time printed), the
## same view with both post effects on, and every weapon held at the spawn as a4-weapon-* stills.
## The a4 set uses nothing A4 made, so it shoots the same views from a copy from before A4. c27b,
## the daemons fighting back, in play: a rogue daemon mid-lunge, a zombie's bolt in flight, the
## hit's red vignette and the death it ends in; c28, ping: its ring going out across the floor seen
## from above and behind, daemons outlined through the west cover wall with their tags, and rogue.d
## caught mid-tell by a ping, reeling; a5, the armoured daemons (A5): rogue.d in its tell, rearing
## tall at the player, its visor flared; a zombie's cannon charging at the player, its bands lit; the
## runaway's drones round their core; a line-up of three of each type built from other seeds, no two
## alike (each creature's own art, standing, facing the camera, one row a type, the rows stacked);
## the three elites in their tells; and the runaway's core killed, its drones scattering; then it
## prints what daemons cost: each type's posing timed alone, and the GPU's time with nine drawn and
## with them hidden; i1, ICE in play: the west corridor's wall mid-crack under the cannon's beam, the
## jam node's tell with its dome, the HUD corrupted by the HUD node's field, the hunter mid-tell with
## its adaptation on the HUD and in its shields, and a line-up of hunters and nodes from other seeds;
## then it prints what ICE costs; i2, the ICEbreakers: the readout bottom left with exploit's seam marks
## lit on a daemon and the corridor's wall while a cloak runs (both effect lines up, the edges washed),
## the brute's charge breaking the wall up close, the hunter's lance going into a decoy the player threw
## instead of into the player, and a line-up of the four pickups and a decoy; then it prints what the breakers
## cost; i3, Black ICE: its arrival seen in play (the arena's lights down, the warning up, the guide's link
## cut, it forming out of the floor), the combo (a decoy pinning it, exploit's marks on its seals, a brute
## breaking one), a line-up of three from other seeds, and the loss screen of a flatline alone; then it
## prints what Black ICE costs; c29, chmod 000: the beam freezing rogue.d in the middle of its tell (its frost
## whole, "PERMISSION DENIED" over it), the strip's two rows in play cut from that frame and shown twice
## the size, a zombie half frozen with the meter under the crosshair, a frozen daemon shattering under the
## cannon, the hunter frozen, and Black ICE only slowed ("Operation not permitted"); then it prints what
## the beam and the frost cost; c30, pipe |: one chain arcing across four daemons, the chain written out
## under the crosshair, the strip's two rows with the pipe drawn cut from that frame and shown three times
## the size, a chain through a daemon chmod 000 froze (it conducts, and shatters), a chain stopped by a
## wall (the daemon behind it untouched), a chain from a zombie through the hunter (frozen) to a node, and Black ICE
## refusing it ("pipe: broken pipe"); then it prints what a chain costs; c31, /dev/null: a hole mid-pull dragging
## four daemons in (stretched toward its core, the floor's mark, the readout over the crosshair), the strip's two
## rows with /dev/null drawn cut from that frame and shown three times the size, the implosion, a knot of daemons
## the hole drew together chained by pipe |, ICE (the hunter pulled, a node held in place, the gate flickering)
## and Black ICE refusing it ("/dev/null: device busy"); then it prints what a hole costs; c32, SIGHUP: a burst
## mid-wave over four daemons (its carrier trace on the floor, its curtain of static running out, each daemon it
## has reached stalled "reloading config"), the strip's two rows with SIGHUP drawn cut from that frame and shown
## three times the size, a crowd of fighting daemons confused (their "?", their seams cycling) turning on each
## other (a lash caught mid-strike), a caught player's own screen (the glitch, the drifting crosshair, the link
## hung up), ICE (the hunter confused, a node reloading, the gate untouched) and Black ICE refusing it
## ("SIGHUP: ignored (nohup)"); then it prints what a burst costs; c33, unlocks, mods and light skins, on demo progress
## (counts a few sessions might leave): the loadout screen from the Esc menu with the cannon on its turntable in
## Dracula's purple and green, its overclock fitted; the same screen on SIGHUP with a locked skin (dial tone) under
## the pointer lighting the handset while its card says how it is earned; a line-up of weapons in earned skins on
## the open floor, each on a plinth with its skin's name; and the toast in play, "UNLOCKED: Catppuccin" over a
## SIGTERM shot in its ^C cyan; then it prints what the turntable costs; c38, the opener's first 35 seconds on demo
## data, picked from the Esc menu as a player would: the game's own frame frozen and coming apart mid-crash, the
## prompt that typed itself, the first lines typed, the folder scroll with the uptime ticking and the last lines, the
## terminal in each of the six demo palettes side by side, and the same terminal in a 960x540 window; c39, the
## settings' "opener data" switch and its note (on a demo run, so it says so), the terminal with wide-character
## folder names (invented, C39_FOLDERS: CJK, an emoji, accents, hangul, fullwidth; demo data, no machine's) at
## 1920x1080 and 960x540, and the six palettes as drawn through the readability pass. Every other set plays in practice,
## the old dummies, as it was shot.
## After each still it prints what the GPU drew for it (draw calls, primitives, objects, and the
## same for shadows). A tool, never part of the game.
##
## It draws, so it never runs headless, and it never runs on a real desktop: run it from a clean
## copy on a private virtual display, sound off, with user data in a temporary folder, as
## tools/capture_shots.sh does. The stills land in user://shots/.
##
## Demo data only: the guide link is a demo one with its privacy file in user://, as the tests
## park theirs, so nothing of the machine is read or shown. Times are counted in frames (run it
## with --fixed-fps 60), so the same tree gives the same stills.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const OpenerScene = preload("res://scenes/opener.tscn")
const Palette = preload("res://scripts/palette.gd")
const OUT := "user://shots"
## Frames after a weapon is drawn before its still: the raise done and the fiction line gone.
const SETTLE_FRAMES := 110
## Frames after a shot leaves for its mid-shot still.
const FIRE_FRAMES := 3
## How far through a charge its mid-charge still is taken.
const CHARGE_SHARE := 0.8
## A mine is placed looking this far down, in degrees, so it lands in view.
const MINE_PITCH := -24.0
## The wider view: where the player stands, the daemon it shoots (between two pillars), and the
## frames after the shot for its still, the flash gone and the beam and the derezz showing.
const WIDE_AT := Vector3(4.0, 0.95, 4.0)
const WIDE_TARGET := "Arena/Targets/DummyC"
const WIDE_FRAMES := 7
## a2: where the player stands for each daemon's close view, and the daemon it looks at.
const A2_CLOSE := [["rogue", Vector3(0.0, 0.95, -13.1), "DummyA"], ["zombie", Vector3(-17.5, 0.95, 6.9), "DummyB"], ["swarm", Vector3(-8.0, 0.95, 14.45), "DummyD"]]
## a2: the view with several daemons in it (the swarm on its platform to the right, a zombie ahead):
## where the player stands and the point it looks at.
const A2_MIXED_AT := Vector3(-14.0, 0.95, 16.0)
const A2_MIXED_LOOK := Vector3(-12.5, 1.2, 8.5)
## a2: where the player stands for the lock on the zombie between the pillars.
const A2_LOCK_AT := Vector3(8.0, 0.95, 4.2)
## a2: frames after the killing shot for the mid-shatter still; frames of aiming for the lock.
const A2_DEREZZ_FRAMES := 7
const A2_LOCK_FRAMES := 75
const DUMMY_MIDDLE := Vector3(0.0, 0.9, 0.0)
## a3: the overview's camera (free, high over the south-west corner) and what it looks at, and the
## free cameras' field of view; then each view in play: where the player stands and the point it
## looks at (arena space).
const A3_OVERVIEW_AT := Vector3(-36.0, 26.0, 38.0)
const A3_OVERVIEW_LOOK := Vector3(0.0, 0.0, -3.0)
const A3_OVERVIEW_FOV := 60.0
## The skyline's camera (free, off the north-east corner, over the plinth's edge, looking along the
## north wall's outside to the towers beyond) and its look.
const A3_SKYLINE_AT := Vector3(31.0, 10.0, -29.0)
const A3_SKYLINE_LOOK := Vector3(-60.0, 2.0, -95.0)
const A3_VIEWS := [["corridor", Vector3(-17.5, 0.95, 18.0), Vector3(-17.5, 1.6, -6.0)], ["slab", Vector3(3.5, 0.95, -1.0), Vector3(-1.5, 2.0, -8.0)], ["gameplay", Vector3(-2.0, 0.95, 18.5), Vector3(-10.5, 1.6, 7.0)]]
## a2b: each daemon's hero view: its name, its target, the free camera and the point it looks at
## (arena space); then its motion strip: the frames before each of its three stills, counted from
## the hero still (for the rogue daemon, from the start of its next rear).
const A2B_HEROES := [["rogue", "DummyA", Vector3(2.9, 1.25, -11.2), Vector3(0.0, 1.0, -15.0), [10, 30, 30]], ["zombie", "DummyB", Vector3(-16.1, 1.45, 9.3), Vector3(-17.5, 1.05, 5.0), [12, 12, 12]], ["swarm", "DummyD", Vector3(-5.3, 2.3, 14.7), Vector3(-8.0, 1.95, 12.0), [8, 8, 8]]]
const A2B_FOV := 50.0
## a2b: the part of each still a strip keeps (the middle, where the daemon is), and the longest the
## rogue daemon is waited for to rear, in frames.
const A2B_CROP := Rect2i(400, 90, 1120, 900)
const A2B_REAR_WAIT := 480
## a2b: the view in play (where the player stands and the point it looks at, arena space); the
## death's free camera and look, its target, and the frames after the killing shot for its still.
const A2B_GAMEPLAY_AT := Vector3(-1.5, 0.95, 18.5)
const A2B_GAMEPLAY_LOOK := Vector3(-1.0, 1.2, 0.0)
const A2B_SHATTER_AT := Vector3(3.4, 1.5, -10.6)
const A2B_SHATTER_LOOK := Vector3(0.0, 1.0, -15.0)
const A2B_SHATTER_TARGET := "DummyA"
const A2B_SHATTER_FRAMES := 14
## a4: the fight (where the player stands, the daemon it shoots, the weapon, where it aims: past the
## daemon's side into the lair's wall, as every hit is a kill and a kill's flash would hide the rest;
## frames after the shot), the corridor, the view shown at low and high (each half the size, side
## by side), and how many frames each preset's GPU time is averaged over.
const A4_FIGHT_AT := Vector3(2.6, 0.95, -9.4)
const A4_FIGHT_TARGET := "DummyA"
const A4_FIGHT_SLOT := 0
const A4_FIGHT_AIM := Vector3(1.7, 0.4, 0.0)
const A4_FIGHT_FRAMES := 3
const A4_CORRIDOR_AT := Vector3(-17.5, 0.95, 18.0)
const A4_CORRIDOR_LOOK := Vector3(-17.5, 1.6, -6.0)
const A4_COMPARE_AT := Vector3(-1.5, 0.95, 18.5)
const A4_COMPARE_LOOK := Vector3(-1.0, 1.2, 0.0)
const A4_GPU_FRAMES := 90
## c27b (C27b): where the player stands and where each daemon is put, facing it, in arena space;
## where the still is taken: the lunge this far through its strike, the bolt this long in flight.
const C27B_PLAYER_AT := Vector3(0.0, 0.95, 15.0)
const C27B_ROGUE_AT := Vector3(0.6, 0.0, 12.45)
const C27B_LUNGE_SHARE := 0.45
const C27B_ZOMBIE_AT := Vector3(-3.2, 0.0, 7.4)
const C27B_BOLT_FRAMES := 40
## Frames after the player's death for its still: the derezz's voxels flying, the banner up.
const C27B_DOWN_FRAMES := 14
## Under the floor: where a daemon a still does not use waits, out of every sight line.
const C27B_PARKED := Vector3(0.0, -50.0, 0.0)
## c28 (C28): the ring seen from a camera riding above and behind the player, when it has gone this
## many frames out, with three daemons round it; the reveal from behind the west cover wall (3 m
## high), two daemons beyond it, this long after the ping; the stagger this long after a ping caught
## rogue.d's tell.
const C28_PING_AT := Vector3(0.0, 0.95, 12.0)
const C28_CHASE := Vector3(0.0, 6.5, 8.5)
const C28_CHASE_LOOK := Vector3(0.0, 0.0, -4.0)
const C28_RING_FRAMES := 14
const C28_ROUND := [Vector3(-5.5, 0.0, 9.5), Vector3(4.5, 0.0, 6.0), Vector3(2.0, 1.0, 15.5)]
const C28_WALL_AT := Vector3(-12.0, 0.95, -2.5)
const C28_BEYOND := [Vector3(-13.2, 0.0, 4.8), Vector3(-10.4, 0.0, 6.6)]
const C28_REVEAL_FRAMES := 36
const C28_STAGGER_FRAMES := 26
## Ping's slot (weapon 9).
const C28_SLOT := 8
## a5 (A5): rogue.d put where it hunts the player and shot in its tell (this far in, then its
## camera beside the player, this far toward the player, out to the side and up); the zombie's
## charge, the player and the zombie where c27b put them, the still this far through its tell, its
## free camera and look (arena space); the runaway's; the line-up's rows (type, name, places, the
## share of its size range each seed rolls), its camera and look, and the band of each row's still
## kept; the elites' places, camera and look; the scatter's camera, its frames after the kill; and
## how many frames the cost is averaged over.
const A5_ROGUE_AT := Vector3(0.5, 0.0, 10.5)
const A5_ROGUE_TELL_S := 0.25
const A5_ROGUE_FRAMES := 8
const A5_ROGUE_CAM := Vector3(1.7, 1.15, 3.0)
const A5_ZOMBIE_CAM := Vector3(-0.4, 1.35, 9.2)
const A5_ZOMBIE_LOOK := Vector3(-3.2, 1.15, 7.4)
const A5_CHARGE_SHARE := 0.8
const A5_SWARM_CAM := Vector3(-5.0, 2.2, 15.6)
const A5_SWARM_LOOK := Vector3(-8.0, 2.05, 12.0)
const A5_SWARM_FOV := 40.0
const A5_ROWS := [["rogue_daemon", "rogue.d", [Vector3(-4.3, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(4.3, 0.0, 10.0)], [0.95, 0.1, 0.55]], ["zombie_process", "zombie", [Vector3(-3.4, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(3.4, 0.0, 10.0)], [0.55, 0.95, 0.1]], ["runaway_swarm", "runaway", [Vector3(-4.6, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(4.6, 0.0, 10.0)], [0.1, 0.55, 0.95]]]
const A5_LINEUP_CAM := Vector3(0.0, 1.5, 16.8)
const A5_LINEUP_LOOK := Vector3(0.0, 1.1, 10.0)
const A5_LINEUP_BAND := Rect2i(0, 270, 1920, 500)
const A5_ELITES := [["rogue_daemon", "rogue.d", Vector3(-4.0, 0.0, 10.5)], ["zombie_process", "zombie", Vector3(0.0, 0.0, 10.5)], ["runaway_swarm", "runaway", Vector3(4.4, 0.0, 10.5)]]
const A5_ELITE_CAM := Vector3(0.0, 1.5, 18.2)
const A5_ELITE_LOOK := Vector3(0.0, 1.2, 10.5)
const A5_SCATTER_CAM := Vector3(-4.4, 2.6, 16.2)
const A5_SCATTER_LOOK := Vector3(-8.0, 1.6, 12.0)
const A5_SCATTER_FRAMES := 12
const A5_COST_FRAMES := 120
## i1: the corridor's wall's damage for its still (of its 600), where the player stands inside the
## corridor and the point it looks at; where it stands for the jam node's tell (inside its trigger, out
## of its dome) and for the HUD node's field (inside it); how far into a tell its still is; the
## cannon damage the round has seen before the hunter's still (its adaptation) and where the player
## stands for it, in the hunter's sight; the line-up's pieces (art, kind, place) and its camera.
const I1_WALL_DAMAGE := 350.0
const I1_WALL_AT := Vector3(-17.0, 0.95, 2.6)
const I1_WALL_LOOK := Vector3(-17.6, 1.55, 8.0)
const I1_JAM_AT := Vector3(-6.5, 0.95, 3.0)
const I1_HUD_AT := Vector3(-13.6, 0.95, -2.2)
const I1_TELL_SHARE := 0.62
const I1_FIELD_CAM := Vector3(6.5, 4.2, 9.0)
const I1_FIELD_LOOK := Vector3(-4.5, 1.2, -4.5)
const I1_ADAPT_DAMAGE := 340.0
const I1_HUNTER_AT := Vector3(6.1, 0.95, -0.5)
const I1_LINEUP := [["hunter_art", "", Vector3(-5.2, 0.0, 9.0)], ["hunter_art", "", Vector3(0.0, 0.0, 9.0)], ["hunter_art", "", Vector3(5.2, 0.0, 9.0)], ["node_art", "jam", Vector3(-4.2, 0.0, 12.5)], ["node_art", "jam", Vector3(-1.4, 0.0, 12.5)], ["node_art", "hud", Vector3(1.4, 0.0, 12.5)], ["node_art", "hud", Vector3(4.2, 0.0, 12.5)]]
const I1_LINEUP_CAM := Vector3(0.0, 3.4, 18.6)
const I1_LINEUP_LOOK := Vector3(0.0, 1.2, 9.5)
## i2: where the player stands in the corridor for exploit's marks (the wall ahead, a zombie at the side)
## and the zombie's place; where it stands for the brute, close to the wall's other face; where it stands
## for the decoy (in the hunter's sight) and where the decoy is thrown at; the line-up's pickups and its
## decoy, and its camera.
const I2_MARKS_AT := Vector3(-17.0, 0.95, 2.6)
const I2_MARKS_LOOK := Vector3(-17.9, 1.3, 7.0)
const I2_ZOMBIE_AT := Vector3(-18.9, 0.0, 5.2)
const I2_BRUTE_AT := Vector3(-17.6, 0.95, 5.7)
const I2_BRUTE_LOOK := Vector3(-17.6, 1.5, 8.0)
const I2_BRUTE_FRAMES := 9
const I2_DECOY_AT := Vector3(0.5, 0.95, -3.0)
const I2_DECOY_THROW := Vector3(4.6, 2.2, 2.4)
const I2_LANCE_FRAMES := 2
const I2_LINEUP := [Vector3(-4.5, 0.0, 12.0), Vector3(-1.5, 0.0, 12.0), Vector3(1.5, 0.0, 12.0), Vector3(4.5, 0.0, 12.0)]
const I2_LINEUP_DECOY := Vector3(0.0, 0.0, 14.6)
const I2_LINEUP_CAM := Vector3(0.0, 2.4, 19.6)
const I2_LINEUP_LOOK := Vector3(0.0, 1.15, 12.6)
## i3: where the player stands to watch it arrive (it forms at BLACK_SPOTS[3], between the gate and the
## low wall, seen from east of the low wall so nothing stands between), how far the view turns right of it
## (so it stands left of the gun in hand) and how far up it looks, and how far through its tell the still is; for the combo, which way the player stands from it, how far, and the frames after
## the brute; for the decoy, where the decoy is thrown and where the player watches from; the line-up's
## places, seeds and camera.
const I3_ARRIVE_AT := Vector3(6.4, 0.95, 3.4)
const I3_ARRIVE_TURN := -0.22
const I3_ARRIVE_LOOK_H := 2.9
const I3_ARRIVE_SHARE := 0.9
const I3_SPOT := 3
const I3_COMBO_FROM := Vector3(-2.0, 0.95, 4.0)
const I3_COMBO_M := 3.9
const I3_COMBO_FRAMES := 32
const I3_DECOY_AT := Vector3(9.0, 0.0, 0.5)
const I3_DECOY_WATCH := Vector3(2.5, 0.95, 4.5)
const I3_LINEUP := [Vector3(-4.6, 0.0, 10.0), Vector3(0.0, 0.0, 10.0), Vector3(4.6, 0.0, 10.0)]
const I3_LINEUP_SEEDS := [3101, 3101 + 7919, 3101 + 2 * 7919]
const I3_LINEUP_CAM := Vector3(0.0, 2.6, 19.5)
## c29 (C29): chmod 000's slot; where the player stands and rogue.d is put (arena space); how full its
## meter is made before its tell so the beam's last ticks land in it; the frames after the freeze for its
## still (the chips flying); the strip's corner cut from it (the bottom right of the 1920x1080 frame) and
## how many times it is shown larger; the zombie half frozen (where it is put, the frames of beam); the
## shatter's frames after the cannon's shot; the hunter's view (round 2) and Black ICE's (round 4, its spot,
## where the player stands off it, the frames of beam).
const C29_SLOT := 9
const C29_PLAYER_AT := Vector3(1.6, 0.95, 15.0)
const C29_ROGUE_AT := Vector3(2.1, 0.0, 10.4)
const C29_PRECHILL := 0.8
const C29_FREEZE_FRAMES := 5
const C29_STRIP_CROP := Rect2i(1580, 935, 340, 120)
const C29_STRIP_SCALE := 3
const C29_ZOMBIE_AT := Vector3(1.0, 0.0, 9.8)
const C29_CHILL_FRAMES := 33
const C29_SHATTER_FRAMES := 8
const C29_HUNTER_FROM := Vector3(10.0, 0.95, 7.0)
const C29_BLACK_SPOT := 3
const C29_BLACK_OFF := Vector3(1.5, 0.95, 8.5)
const C29_BLACK_FRAMES := 50
const I3_LINEUP_LOOK := Vector3(0.0, 2.1, 10.0)
## c30 (C30): pipe |'s slot; where the player stands; the four daemons of the chain (arena space: rogue.d
## first, aimed at, then the zombie, the runaway and the second zombie), toughened so they stand through it;
## the frames after the shot for its still (every link lit); the strip's corner and its scale; the frozen
## link's daemons (rogue.d aimed at in the middle, the frozen zombie to its left, the runaway to its right); the
## wall's (rogue.d before the low wall, the zombie behind it, in reach, its top showing over it); the ICE
## chain's (round 2: the second zombie, the hunter put over the floor and frozen, the jam node at its post); Black
## ICE's spot and stand.
const C30_SLOT := 10
const C30_PLAYER_AT := Vector3(1.6, 0.95, 16.0)
const C30_CHAIN := [Vector3(0.6, 0.0, 9.6), Vector3(4.6, 0.0, 7.2), Vector3(1.2, 1.0, 4.2), Vector3(-3.4, 0.0, 6.4)]
const C30_TOUGH := 400.0
const C30_CHAIN_FRAMES := 20
const C30_STRIP_CROP := Rect2i(1580, 935, 340, 120)
const C30_STRIP_SCALE := 3
const C30_FROZEN_FROM := Vector3(1.0, 0.95, 16.8)
const C30_FROZEN := [Vector3(1.0, 0.0, 10.6), Vector3(-2.0, 0.0, 9.8), Vector3(4.8, 1.0, 10.2)]
const C30_FROZEN_FRAMES := 12
## Frames for the round's first-kill callout to come and go before the shatter (its own kill shows none).
const C30_CALLOUT_FRAMES := 180
const C30_WALL_FROM := Vector3(3.2, 0.95, 9.6)
const C30_WALL := [Vector3(2.2, 0.0, 4.6), Vector3(-1.0, 0.0, -0.8)]
const C30_ICE_FROM := Vector3(4.0, 0.95, -0.5)
const C30_ICE_ROGUE := Vector3(-0.5, 0.0, -0.8)
const C30_ICE_HUNTER := Vector3(-3.0, 0.0, -2.6)
const C30_BLACK_SPOT := 3
const C30_BLACK_OFF := Vector3(1.5, 0.95, 8.5)
## c31 (C31): /dev/null's slot; where the player stands and where the device is dropped (arena space: its core
## opens a metre over the floor there); the four daemons it drags (rogue.d, the zombie, the runaway, the second
## zombie), toughened so they stand until the core; the frames after it opens for its still; the frames into the
## implosion; the knot (the daemons round a second hole, gathered for KNOT_FRAMES, then pipe | fired into them);
## ICE's (round 2: the hunter, the jam node, the gate); Black ICE's stand.
const C31_SLOT := 11
const C31_PIPE := 10
const C31_PLAYER_AT := Vector3(1.0, 0.95, 14.4)
const C31_DROP := Vector3(0.0, 0.3, 7.6)
const C31_CROWD := [Vector3(-4.0, 0.0, 6.6), Vector3(4.2, 0.0, 8.8), Vector3(2.6, 1.0, 4.2), Vector3(-1.8, 0.0, 10.8)]
const C31_HOLE_FRAMES := 30
const C31_IMPLODE_FRAMES := 9
const C31_KNOT_FRAMES := 22
const C31_KNOT_CHAIN_FRAMES := 30
const C31_ICE_FROM := Vector3(5.5, 0.95, 4.5)
const C31_ICE_DROP := Vector3(-1.6, 0.3, -3.6)
## c32 (C32): SIGHUP's slot; where the player stands and where the device is dropped (arena space: it goes off
## half a metre over the floor there); the four daemons round it (rogue.d, the zombie, the runaway, the second
## zombie); the frames after it goes off for its still (its front then most of the way out); the crowd that
## turns on itself (close enough to lash), and the most frames waited for a lash's strike; ICE's drop.
const C32_SLOT := 12
const C32_PLAYER_AT := Vector3(1.0, 0.95, 14.6)
const C32_DROP := Vector3(0.0, 0.2, 7.4)
const C32_CROWD := [Vector3(-3.0, 0.0, 6.2), Vector3(3.4, 0.0, 8.6), Vector3(1.6, 1.0, 4.4), Vector3(-1.4, 0.0, 9.9)]
const C32_WAVE_FRAMES := 19
const C32_KNOT := [Vector3(-1.1, 0.0, 7.6), Vector3(1.1, 0.0, 7.8), Vector3(0.2, 0.0, 6.0), Vector3(0.0, 0.0, 9.2)]
const C32_LASH_WAIT := 330
const C32_KNOT_FROM := Vector3(0.8, 0.95, 12.0)
const C32_ICE_FROM := Vector3(5.5, 0.95, 4.0)
const C32_ICE_DROP := Vector3(-2.6, 0.2, -3.4)
## c33 (C33): the demo progress the stills are shot on (a few sessions' worth: the cannon's every unlock, SIGTERM's
## ^C, the rail's blacklight); the line-up (each weapon in an earned skin), where it stands on the open floor and
## how far apart, how much bigger than in the hand, how it is turned to the camera; the camera; the turntable's
## frames before a still (a three-quarter view); where the toast's shot is taken from and at.
const C33_PROGRESS := {"kills_terminal_cannon": 82, "kills_sigterm": 27, "rail_heads": 4, "kills_fork_bomb": 9, "pings": 12, "discards": 3, "hups": 4, "freezes": 6, "shatters": 1, "grep_marks": 8}
const C33_LINEUP := [["terminal_cannon", "tty1"], ["sigkill_rail", "blacklight"], ["sigterm", "catppuccin"], ["rm_rf_cannon", "preserve_root"], ["sighup", "dial_tone"], ["fork_bomb", "exponential"]]
## The line-up stands on an arc round the camera, this far from it, spread over this many radians; each model this
## much bigger than in the hand, this high, turned this far past side-on toward the camera (its muzzle to the left).
const C33_ARC_R := 5.0
const C33_ARC_SPREAD := 1.35
const C33_LINEUP_SCALE := 2.25
const C33_LINEUP_LIFT := 0.6
const C33_LINEUP_TURN := 0.65
const C33_CAM_AT := Vector3(0.0, 1.45, 12.6)
const C33_CAM_LOOK := Vector3(0.0, 0.45, 7.6)
const C33_TURN_FRAMES := 50
const C33_SHOT_FROM := Vector3(0.8, 0.95, 14.4)
const C33_SHOT_AT := Vector3(0.0, 0.0, 8.8)
## The opener (C38): the seconds each still is taken at (the crash between its two drops to black, the prompt with
## its cursor lit, the first lines done, the last lines done, the palettes after the tear) and the palette grid's
## columns.
const C38_CRASH_AT := 2.15
const C38_PROMPT_AT := 14.0
const C38_TERMINAL_AT := 22.9
const C38_UPTIME_AT := 34.7
const C38_PALETTES_AT := 35.6
const C38_GRID_COLUMNS := 3
## The opener (C39): the seconds its stills are taken at (the folders scrolled and the uptime ticking; the palettes
## after the tear).
const C39_WIDE_AT := 26.8
const C39_PALETTES_AT := 35.6
## c40's stills: [name, the opener's second], the one shot at 960x540, the sheet of the move (these, in order), and
## the frames measured for the cost (every frame from the reveal to the landing).
const C40_SHOTS := [["c40-ignore", 38.3], ["c40-shrink", 41.9], ["c40-panel", 44.0], ["c40-machine", 46.6], ["c40-edge", 49.4], ["c40-drop", 52.0], ["c40-names", 55.0], ["c40-deep", 58.5], ["c40-pit", 62.5], ["c40-landed", 69.0]]
const C40_SMALL_AT := 57.0
const C40_SHEET := ["c40-shrink", "c40-panel", "c40-machine", "c40-edge", "c40-drop", "c40-names", "c40-deep", "c40-landed"]
const C40_SHEET_COLUMNS := 4
## c40's palettes: the same moment of the fall, the machine built in each demo palette, three to a row.
const C40_PALETTES_AT := 55.0
## c41's stills: [name, the opener's second], the sheet of the beat (these, in order), the one shot at 960x540, and the
## copy's face cut from c41-copy (the region, drawn at twice its size).
## c41-rim is shot RIM_AFTER seconds after the copy's first foot touches the floor (its red rings in front of the player).
const C41_SHOTS := [["c41-link", 71.3], ["c41-signal", 72.9], ["c41-live", 73.78], ["c41-rise", 87.4], ["c41-rim", -1.0], ["c41-walk", 91.6], ["c41-copy", 94.0]]
const C41_RIM_AFTER := 0.15
const C41_SHEET := ["c41-link", "c41-signal", "c41-live", "c41-rise", "c41-rim", "c41-walk"]
const C41_SHEET_COLUMNS := 3
const C41_SMALL_AT := 94.0
const C41_FACE := Rect2i(760, 150, 400, 360)
## c42's stills: before the shot, [name, the opener's second]; fire pressed at C42_PRESS; after the shot, [name, seconds
## after it]; the sheet (these, in order, three to a row); the intro's Esc menu over the stream at C42_PAUSE_AT; the
## title again at 960x540, C42_SMALL_AFTER after its shot.
const C42_BEFORE := [["c42-type", 95.75], ["c42-charge", 96.7], ["c42-stream", 97.75], ["c42-forged", 99.32], ["c42-dare", 104.55]]
const C42_PRESS := 104.62
const C42_AFTER := [["c42-shot", 0.11], ["c42-derezz", 0.62], ["c42-feed", 1.45], ["c42-whisper", 3.0], ["c42-slam", 5.27], ["c42-title", 6.95]]
const C42_SHEET := ["c42-type", "c42-stream", "c42-forged", "c42-dare", "c42-shot", "c42-derezz", "c42-feed", "c42-slam", "c42-title"]
const C42_SHEET_COLUMNS := 3
const C42_PAUSE_AT := 98.1
const C42_SMALL_AFTER := 6.95
const C31_ICE_HUNTER := Vector3(3.0, 0.0, -2.0)
const C31_ICE_FRAMES := 40
const C31_BLACK_OFF := Vector3(2.0, 0.95, 12.0)

## Invented demo data with wide-character folder names (C39): the demo's user, host, uptime and times, and folders
## no machine has, in the scripts and widths real names can bring.
class WideDemo extends DemoOpenerData:
	const WIDE_FOLDERS := [".config", ".local", "Documents", "写真", "写真/2024-京都", "音楽", "音楽/お気に入り", "ゲーム", "🎮 games", "🎮 games/saves", "café-recettes", "Документы", "한글-노트", "ｆｕｌｌｗｉｄｔｈ", "naïve-bayes", "code", "code/日本語-site", "code/日本語-site/node_modules", "taxes-2024", "scratch"]

	func folders() -> PackedStringArray:
		return PackedStringArray(WIDE_FOLDERS)


var _main: Node
var _player: Node
var _shots := 0
var _set := "a1"


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture: headless draws nothing; run it on a private virtual display")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_set = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT)
	var link := Link.new()
	link.settings_path = "user://capture-privacy.cfg"
	link.demo = true
	Link.park(link)
	_main = MainScene.instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player")
	_player.assume_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Every set is shot as it was: practice, the old dummies (C27b); c27b turns them loose once its
	# daemons are placed.
	GameSettings.current().set_value("gameplay", "practice", true)
	await _frames(90)  # shaders compiled, the code rain running
	if _set == "c27b":
		await _c27b()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a5":
		await _a5()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "i1":
		await _i1()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "i2":
		await _i2()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "i3":
		await _i3()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c29":
		await _c29()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c30":
		await _c30()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c31":
		await _c31()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c32":
		await _c32()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c38":
		await _c38()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c39":
		await _c39()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c40":
		await _c40()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c41":
		await _c41()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c42":
		await _c42()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c33":
		await _c33()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "c28":
		await _c28()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a2":
		await _a2()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a3":
		await _a3()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a2b":
		await _a2b()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	if _set == "a4":
		await _a4()
		print("capture: %d stills" % _shots)
		quit(0)
		return
	var defs: Array = _player.inventory.defs
	for slot in defs.size():
		var def: Resource = defs[slot]
		var name := "a1-weapon-%d-%s" % [slot + 1, def.id.replace("_", "-")]
		_player.select_slot(slot)
		await _frames(SETTLE_FRAMES)
		await _save(name)
		await _shoot(def, name)
		await _frames(150)  # the shot's effects gone, ready again
	await _wide()
	print("capture: %d stills" % _shots)
	quit(0)


## One shot of the drawn weapon: a still mid-charge for one that charges (the rail's coils, the
## rm -rf wind-up), and one just after the shot leaves. The rail, an ult, gets a full meter first.
func _shoot(def: Resource, name: String) -> void:
	_player.inventory.add_meter(_player.inventory.meter_full())
	# A press counts on the physics step after the one it is made before: made just after a still
	# (after the draw), the next frame's own press would overwrite it, so wait for a step first.
	await physics_frame
	var mine: bool = def.has_method("is_mine") and def.is_mine()
	if mine:
		_player.get_node("Head").rotation.x = deg_to_rad(MINE_PITCH)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	if def.charge_s > 0.0:
		var frames := ceili(def.charge_s * 60.0)
		var early := int(frames * CHARGE_SHARE)
		await _frames(early - 1)
		await _save(name + "-charge")
		await _frames(frames - early)
	await _frames(FIRE_FRAMES)
	await _save(name + "-fire")
	if mine:
		_player.get_node("Head").rotation.x = 0.0


## The wider view: off to one side of the spawn, the rail on a daemon as its shot lands.
func _wide() -> void:
	_player.respawn_at(_main.to_global(WIDE_AT))
	var target: Node3D = _main.get_node(WIDE_TARGET)
	await _frames(30)
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := target.global_position + Vector3.UP - cam.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	_player.select_slot(2)
	await _frames(SETTLE_FRAMES)
	_player.inventory.add_meter(_player.inventory.meter_full())
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(ceili(_player.inventory.defs[2].charge_s * 60.0) + WIDE_FRAMES)
	await _save("a1-gameplay")


## a2: each kind of daemon up close, several at once, a derezz mid-shatter, grep locked on one.
func _a2() -> void:
	for view in A2_CLOSE:
		await _stand(view[1], _main.get_node("Arena/Targets/" + view[2]).global_position + DUMMY_MIDDLE)
		await _save("a2-daemon-" + view[0])
	await _stand(A2_MIXED_AT, _main.to_global(A2_MIXED_LOOK))
	await _save("a2-mixed")
	# The rogue daemon shot down from its close view, the shatter mid-flight.
	var rogue: Node3D = _main.get_node("Arena/Targets/DummyA")
	await _stand(A2_CLOSE[0][1], rogue.global_position + DUMMY_MIDDLE)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(A2_DEREZZ_FRAMES)
	await _save("a2-derezz")
	# grep aimed at the zombie between the pillars until it is marked.
	var zombie: Node3D = _main.get_node("Arena/Targets/DummyC")
	await _stand(A2_LOCK_AT, zombie.global_position + DUMMY_MIDDLE)
	_player.select_slot(5)
	await _frames(SETTLE_FRAMES)
	for i in A2_LOCK_FRAMES:
		_player.set("_aiming", true)
		_player.drive_input(Vector2.ZERO)
		await physics_frame
	await _save("a2-gameplay")


## a3: the arena from above and the void beyond its wall (free cameras), then each view in play, the
## last with the cannon drawn and a shot just leaving.
func _a3() -> void:
	await _free_view("a3-overview", A3_OVERVIEW_AT, A3_OVERVIEW_LOOK)
	await _free_view("a3-skyline", A3_SKYLINE_AT, A3_SKYLINE_LOOK)
	for view in A3_VIEWS:
		await _stand(view[1], _main.to_global(view[2]))
		if view[0] == "gameplay":
			_player.drive_input(Vector2.ZERO, false, false, true)
			await physics_frame
			await _frames(FIRE_FRAMES)
		await _save("a3-" + view[0])


## a2b: each daemon's hero view and its motion strip from a free camera, then the view in play
## with all three kinds in it, then the rogue daemon's death in shards.
func _a2b() -> void:
	for hero in A2B_HEROES:
		var cam := _free_camera(hero[2], hero[3], A2B_FOV)
		await _frames(40)
		await _save("a2b-" + hero[0])
		if hero[0] == "rogue":
			# Wait for its rear (an art that never rears, as A2's for the before stills, does not wait).
			var art: Node = _main.get_node("Arena/Targets/" + hero[1]).art_node()
			var waited := 0
			while art.has_method("rear") and art.rear() < 0.02 and waited < A2B_REAR_WAIT:
				await _frames(1)
				waited += 1
		var stills: Array[Image] = []
		for wait in hero[4]:
			await _frames(wait)
			stills.append(await _grab())
		await _save_strip("a2b-%s-motion" % hero[0], stills)
		_free_camera_done(cam)
	await _stand(A2B_GAMEPLAY_AT, _main.to_global(A2B_GAMEPLAY_LOOK))
	await _save("a2b-gameplay")
	var cam := _free_camera(A2B_SHATTER_AT, A2B_SHATTER_LOOK, A2B_FOV)
	await _frames(30)
	var dummy: Node3D = _main.get_node("Arena/Targets/" + A2B_SHATTER_TARGET)
	dummy.hit(100.0, dummy.global_position + Vector3(0.4, 1.2, 0.5), Vector3(-0.6, 0.0, -1.0).normalized())
	await _frames(A2B_SHATTER_FRAMES)
	await _save("a2b-shatter")
	_free_camera_done(cam)


## a4: the overview, a fight, the corridor, low beside high (and each preset's GPU time), the post
## effects, then every weapon held at the spawn.
func _a4() -> void:
	var settings := GameSettings.current()
	settings.set_value("video", "quality", "high")
	await _free_view("a4-overview", A3_OVERVIEW_AT, A3_OVERVIEW_LOOK)
	var rogue: Node3D = _main.get_node("Arena/Targets/" + A4_FIGHT_TARGET)
	_player.select_slot(A4_FIGHT_SLOT)
	await _stand(A4_FIGHT_AT, rogue.global_position + DUMMY_MIDDLE + A4_FIGHT_AIM)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(A4_FIGHT_FRAMES)
	await _save("a4-fight")
	_player.select_slot(0)
	await _stand(A4_CORRIDOR_AT, _main.to_global(A4_CORRIDOR_LOOK))
	await _save("a4-corridor")
	await _stand(A4_COMPARE_AT, _main.to_global(A4_COMPARE_LOOK))
	var halves: Array[Image] = []
	for preset in ["low", "medium", "high"]:
		settings.set_value("video", "quality", preset)
		await _frames(30)
		print("capture: %s preset, GPU %.2f ms a frame at 1920x1080" % [preset, await _gpu_ms(A4_GPU_FRAMES)])
		if preset != "medium":
			var still := await _grab()
			still.resize(still.get_width() / 2, still.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			halves.append(still)
	var pair := Image.create(halves[0].get_width() * 2, halves[0].get_height(), false, Image.FORMAT_RGBA8)
	for i in halves.size():
		pair.blit_rect(halves[i], Rect2i(Vector2i.ZERO, halves[i].get_size()), Vector2i(halves[0].get_width() * i, 0))
	pair.save_png(OUT.path_join("a4-low-high.png"))
	_shots += 1
	print("capture: a4-low-high, the low preset left of the high one")
	if GameSettings.SCHEMA["video"].has("crt"):
		settings.set_value("video", "chromatic_aberration", true)
		settings.set_value("video", "crt", true)
		await _frames(10)
		await _save("a4-post")
		settings.set_value("video", "chromatic_aberration", false)
		settings.set_value("video", "crt", false)
	_player.respawn_at(_main.to_global(Vector3(0.0, 0.95, 10.0)))
	_player.rotation.y = 0.0
	_player.get_node("Head").rotation.x = 0.0
	var defs: Array = _player.inventory.defs
	for slot in defs.size():
		_player.select_slot(slot)
		await _frames(SETTLE_FRAMES)
		await _save("a4-weapon-%d-%s" % [slot + 1, defs[slot].id.replace("_", "-")])


## c27b: the daemons fighting back, from the player's own view: a rogue daemon mid-lunge, the hit's
## vignette as its slash lands, the player derezzed by its next one (the banner naming it), and a
## zombie's amber bolt in flight. Every daemon a still does not
## use waits under the floor.
func _c27b() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var life := _main.get_node("SoloLife")
	var rogue: Node3D = targets.get_node("DummyA")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ROGUE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_c27b_place(rogue, _main.to_global(C27B_ROGUE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)  # the daemons fight back from here
	var strike_s: float = (load("res://resources/daemon_ai.tres") as DaemonAiTuning).rogue_strike_s
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.STRIKE and rogue.brain.state_t >= C27B_LUNGE_SHARE * strike_s):
		await _frames(1)
		waited += 1
	print("capture: the rogue's strike after %d frames, the player at %.0f health" % [waited, life.health()])
	await _save("c27b-lunge")
	waited = 0
	while life.health() >= 100.0:
		await _frames(1)
		waited += 1
	await _frames(1)
	print("capture: its slash landed %d frames later" % waited)
	await _save("c27b-hit")
	# Its next slash takes the last of the player's health: the derezz and the banner naming it.
	life.damage(life.health() - 4.0, rogue, Vector3.FORWARD)
	waited = 0
	while life.alive():
		await _frames(1)
		waited += 1
	await _frames(C27B_DOWN_FRAMES)
	print("capture: derezzed by its next slash %d frames later" % waited)
	await _save("c27b-down")
	_c27b_place(rogue, C27B_PARKED)
	life.reset_for_round()
	var zombie: Node3D = targets.get_node("DummyC")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ZOMBIE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.3, 0.0)))
	_c27b_place(zombie, _main.to_global(C27B_ZOMBIE_AT))
	var director: DaemonDirector = _main.get_node("DaemonDirector")
	waited = 0
	while director.bolts_live() == 0:
		await _frames(1)
		waited += 1
	print("capture: the zombie's bolt after %d frames" % waited)
	await _frames(C27B_BOLT_FRAMES)
	await _save("c27b-bolt")


## c28: ping. The ring from above and behind the player as it goes out across the floor, three
## daemons round it (outlined as it meets them); from behind the west cover wall, rogue.d and a
## zombie beyond it outlined through it with their tags; and rogue.d caught rearing by a ping, reeling
## outlined. Every daemon a still does not use waits under the floor; the daemons fight back.
func _c28() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "practice", false)
	_player.select_slot(C28_SLOT)
	await _stand(C28_PING_AT, _main.to_global(C28_PING_AT + Vector3(0.0, -0.4, -6.0)))
	await _frames(90)  # past the fiction line drawing shows
	var names := ["DummyA", "DummyC", "DummyD"]
	for i in names.size():
		_c27b_place(targets.get_node(names[i]), _main.to_global(C28_ROUND[i]))
	var cam := _free_camera(C28_PING_AT + C28_CHASE, C28_PING_AT + C28_CHASE_LOOK, A3_OVERVIEW_FOV)
	await _frames(20)
	await _ping()
	await _frames(C28_RING_FRAMES)
	print("capture: the ring %.1f m out" % (_player.last_ping.radius() if is_instance_valid(_player.last_ping) else -1.0))
	await _save("c28-ping")
	_free_camera_done(cam)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _frames(roundi(_player.weapon_tuning().fire_cooldown * 60.0))  # the cooldown back
	# Behind the west cover wall: two daemons beyond it, out of sight, outlined through it.
	await _stand(C28_WALL_AT, _main.to_global(Vector3(-11.8, 1.2, 5.5)))
	_c27b_place(targets.get_node("DummyA"), _main.to_global(C28_BEYOND[0]))
	_c27b_place(targets.get_node("DummyC"), _main.to_global(C28_BEYOND[1]))
	await _frames(20)
	await _ping()
	await _frames(C28_REVEAL_FRAMES)
	await _save("c28-reveal")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _frames(roundi(_player.weapon_tuning().fire_cooldown * 60.0))
	# rogue.d caught rearing, reeling.
	var rogue: Node3D = targets.get_node("DummyA")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ROGUE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_c27b_place(rogue, _main.to_global(C27B_ROGUE_AT))
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.TELL and rogue.brain.state_t >= 0.3):
		await _frames(1)
		waited += 1
	await _ping()
	await _frames(C28_STAGGER_FRAMES)
	print("capture: rogue.d's tell after %d frames, staggered %d, reeling %.2f" % [waited, rogue.brain.staggers, rogue.art_node().staggered()])
	await _save("c28-stagger")


## a5: the armoured daemons (A5), each type's hero, the line-up, the elites, the scatter, the cost.
func _a5() -> void:
	var targets := _main.get_node("Arena/Targets")
	var rogue: Node3D = targets.get_node("DummyA")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# rogue.d in its tell: rearing tall at the player, its visor flared, from beside the player.
	await _stand(C27B_PLAYER_AT, _main.to_global(A5_ROGUE_AT + DUMMY_MIDDLE))
	_c27b_place(rogue, _main.to_global(A5_ROGUE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)
	var waited := 0
	while not (rogue.brain.state == DaemonBrain.State.TELL and rogue.brain.state_t >= A5_ROGUE_TELL_S) and waited < 900:
		await _frames(1)
		waited += 1
	var at: Vector3 = _main.to_local(rogue.global_position)
	var face: Vector3 = _main.to_local(_player.global_position) - at
	face.y = 0.0
	face = face.normalized()
	var side: Vector3 = face.cross(Vector3.UP)
	var cam := _free_camera(at + face * A5_ROGUE_CAM.z + side * A5_ROGUE_CAM.x + Vector3.UP * A5_ROGUE_CAM.y, at + Vector3.UP * 1.25, A2B_FOV)
	await _frames(A5_ROGUE_FRAMES)
	print("capture: rogue.d (seed %d, size %.2f) in its tell after %d frames, rearing %.2f, its visor at %.2f" % [rogue.build_seed(), rogue.art_node().size_scale, waited, rogue.art_node().rear(), rogue.art_node().visor_glow()])
	await _save("a5-rogue")
	_free_camera_done(cam)
	GameSettings.current().set_value("gameplay", "practice", true)
	_c27b_place(rogue, C27B_PARKED)
	await _frames(10)
	# A zombie's cannon charging at the player, its bands lighting.
	var zombie: Node3D = targets.get_node("DummyC")
	await _stand(C27B_PLAYER_AT, _main.to_global(C27B_ZOMBIE_AT + DUMMY_MIDDLE))
	_c27b_place(zombie, _main.to_global(C27B_ZOMBIE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)
	var tell_s: float = (load("res://resources/daemon_ai.tres") as DaemonAiTuning).zombie_tell_s
	cam = _free_camera(A5_ZOMBIE_CAM, A5_ZOMBIE_LOOK, A2B_FOV)
	waited = 0
	while not (zombie.brain.state == DaemonBrain.State.TELL and zombie.brain.state_t >= A5_CHARGE_SHARE * tell_s) and waited < 900:
		await _frames(1)
		waited += 1
	print("capture: the zombie (seed %d) charging after %d frames, its bands %s" % [zombie.build_seed(), waited, zombie.art_node().band_glow()])
	await _save("a5-zombie")
	_free_camera_done(cam)
	GameSettings.current().set_value("gameplay", "practice", true)
	_c27b_place(zombie, _main.to_global(Vector3(-17.5, 0.0, 5.0)))
	await _frames(30)
	# The runaway on its platform, its drones round the core.
	var swarm: Node3D = targets.get_node("DummyD")
	_c27b_place(swarm, _main.to_global(Vector3(-8.0, 1.0, 12.0)))
	cam = _free_camera(A5_SWARM_CAM, A5_SWARM_LOOK, A5_SWARM_FOV)
	await _frames(60)
	await _save("a5-runaway")
	_free_camera_done(cam)
	# The line-up: three of each type, each from its own seed. The arena's own wait under the floor.
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# One row a type, each row three of it side by side, the rows stacked in one still: each
	# creature's own art from its seed, standing driven (its idle wander off) and facing the camera,
	# so builds compare like for like.
	cam = _free_camera(A5_LINEUP_CAM, A5_LINEUP_LOOK, A2B_FOV)
	var rows: Array[Image] = []
	var made := 0
	for row in A5_ROWS:
		var three: Array[DaemonArt] = []
		for k in 3:
			three.append(_a5_art(row[0], row[2][k], _a5_seed(row[0], row[3][k], 600 + made * 50), DaemonArt.Act.MOVE, 0.0))
			made += 1
		await _frames(70)
		var built := PackedStringArray()
		for art in three:
			built.append("%d %.2f %d parts" % [art.build_seed, art.size_scale, art.part_count()])
		print("capture: the line-up's %s: %s" % [row[1], "; ".join(built)])
		rows.append(await _grab())
		for art in three:
			art.get_parent().queue_free()
	var sheet := Image.create(A5_LINEUP_BAND.size.x, A5_LINEUP_BAND.size.y * rows.size(), false, Image.FORMAT_RGBA8)
	for i in rows.size():
		sheet.blit_rect(rows[i], A5_LINEUP_BAND, Vector2i(0, A5_LINEUP_BAND.size.y * i))
	sheet.save_png(OUT.path_join("a5-lineup.png"))
	_shots += 1
	print("capture: a5-lineup, %d rows stacked" % rows.size())
	# What daemons cost: the nine of the line-up at once, three rows deep, drawn, then hidden.
	await _frames(5)
	var costed: Array[DaemonArt] = []
	for k in 9:
		var row: Array = A5_ROWS[k / 3]
		costed.append(_a5_art(row[0], row[2][k % 3] + Vector3(0.0, 0.0, -3.5 * (k / 3)), _a5_seed(row[0], row[3][k % 3], 600 + k * 50), DaemonArt.Act.MOVE, 0.0))
	await _frames(70)
	await _a5_cost(costed)
	for art in costed:
		art.get_parent().queue_free()
	_free_camera_done(cam)
	# The three elites, in their tells: rogue.d rearing, its visor flared; the zombie's cannon raised
	# and charging; the swarm pulled tight round its core.
	var elites: Array[DaemonArt] = []
	for e in A5_ELITES:
		elites.append(_a5_art(e[0], e[2], _a5_elite_seed(e[0], 4000 + elites.size() * 1000), DaemonArt.Act.TELL, 0.8))
	cam = _free_camera(A5_ELITE_CAM, A5_ELITE_LOOK, A2B_FOV)
	await _frames(70)
	var big := PackedStringArray()
	for art in elites:
		big.append("%s %d elite %s %.2f, %d parts" % [art.ai_kind, art.build_seed, art.elite, art.size_scale, art.part_count()])
	print("capture: the elites: " + "; ".join(big))
	await _save("a5-elite")
	_free_camera_done(cam)
	for art in elites:
		art.get_parent().queue_free()
	# The runaway's core killed: its drones scatter.
	_c27b_place(swarm, _main.to_global(Vector3(-8.0, 1.0, 12.0)))
	cam = _free_camera(A5_SCATTER_CAM, A5_SCATTER_LOOK, A2B_FOV)
	await _frames(60)
	swarm.hit(1000.0, swarm.global_position + Vector3(0.0, 0.9, 0.0), Vector3(-0.5, 0.0, -1.0).normalized())
	await _frames(A5_SCATTER_FRAMES)
	await _save("a5-scatter")
	_free_camera_done(cam)


## A creature of `type` alone (its art, no daemon round it) at `at` (arena space), built from `seed`,
## facing south to the a5 cameras, doing `act` `u` of the way through (A5).
func _a5_art(type: String, at: Vector3, seed: int, act: int, u: float) -> DaemonArt:
	var holder := Node3D.new()
	_main.add_child(holder)
	holder.position = at + Vector3(0.0, 0.9, 0.0)  # the body's centre over the ground, as a dummy's is
	holder.rotation.y = PI
	var art := DaemonArt.make(load("res://scripts/daemons/%s.gd" % type), null, seed)
	holder.add_child(art)
	art.drive(act, u)
	return art


## A seed of `type` that is no elite and rolls about `share` of its size range, searched from `from`.
func _a5_seed(_type: String, share: float, from: int) -> int:
	var best := from
	for seed in range(from, from + 400):
		if DaemonArt.elite_of(seed):
			continue
		if absf(DaemonArt.roll_of(seed, 9002, 3) - share) < absf(DaemonArt.roll_of(best, 9002, 3) - share):
			best = seed
	return best


## The first elite seed from `from`.
func _a5_elite_seed(_type: String, from: int) -> int:
	for seed in range(from, from + 5000):
		if DaemonArt.elite_of(seed):
			return seed
	return from


## What daemons cost (A5), on this machine: each type's posing timed alone (its three of the line-up,
## its whole _process, five rounds of A5_COST_FRAMES frames: the quickest round and the median, as
## the machine's other work only ever slows a round), and the GPU's time a frame with the nine drawn
## and with them hidden, three times each in turn (its spread is the timer's noise), with what the
## GPU drew each way.
func _a5_cost(lineup: Array[DaemonArt]) -> void:
	for k in 3:
		var three := lineup.slice(k * 3, k * 3 + 3)
		var rounds := PackedFloat32Array()
		for round in 5:
			var usec := 0
			for i in A5_COST_FRAMES:
				for art in three:
					var t0 := Time.get_ticks_usec()
					art._process(1.0 / 60.0)
					usec += Time.get_ticks_usec() - t0
				await _frames(1)
			rounds.append(float(usec) / (A5_COST_FRAMES * three.size()))
		rounds.sort()
		print("capture: a5 cost, %s posing: %.1f us a daemon a frame at the quickest, %.1f the median (rounds %s)" % [three[0].ai_kind, rounds[0], rounds[2], ", ".join(Array(rounds).map(func(x): return "%.1f" % x))])
	var gpu := PackedStringArray()
	var calls := PackedInt32Array([0, 0])
	var prims := PackedInt32Array([0, 0])
	for pass_ in 6:
		var shown := pass_ % 2 == 0
		for art in lineup:
			art.visible = shown
		await _frames(10)
		var ms := await _gpu_ms(A5_COST_FRAMES)
		gpu.append("%s %.3f" % ["drawn" if shown else "hidden", ms])
		calls[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for art in lineup:
		art.visible = true
	print("capture: a5 cost, the GPU's time a frame at 1920x1080 with the nine drawn and hidden in turn: %s ms; drawn %d draw calls and %d primitives, hidden %d and %d" % [", ".join(gpu), calls[0], prims[0], calls[1], prims[1]])


## I1, ICE in play (ICE on, practice off, the daemons parked under the floor): the west corridor's
## wall mid-crack, sealing it, the cannon's beam striking it, from inside the corridor; the jam node
## in its tell, its dome lit at the field's reach, from just outside it; the HUD corrupted by the HUD
## node's field, the health line untouched; the hunter (round 2) mid-tell, its shields closed round
## its nose and its trace on the player, after the round's cannon damage has adapted it (the HUD's
## line and its shields tinted toward the cannon's teal), from the player's own view; and a line-up of
## seven pieces from other seeds (three hunters, two of each node), no two alike. Then it prints what
## ICE costs: each kind's posing timed alone, its triangles and draw calls, and the GPU's time with
## the line-up drawn and hidden.
func _i1() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	ice.start_round(1)
	await _frames(10)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# The corridor's wall mid-crack, the HUD node behind the player broken first (its field would
	# scramble this still's HUD).
	var wall := ice.wall("wall")
	var hud_node := ice.node_of("hud")
	hud_node.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	hud_node.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	for i in 3:
		wall.hit(100.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	wall.hit(I1_WALL_DAMAGE - 300.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	_player.select_slot(0)
	await _stand(I1_WALL_AT, _main.to_global(I1_WALL_LOOK))
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(FIRE_FRAMES)
	print("capture: the corridor's wall (seed %d) at %.0f%% damage, %d of %d panes out, its deepest crack %.2f" % [wall.build_seed, 100.0 - wall.health() / wall.max_health * 100.0, wall.art.panes_out(), wall.art.pane_count(), wall.art.deepest_crack()])
	await _save("i1-white-ice")
	await _frames(60)
	# The jam node in its tell, its dome lit at the field's reach: seen from a free camera well outside
	# it, the player standing inside the node's trigger range (out of the dome) to set it off.
	var jam := ice.node_of("jam")
	await _stand(I1_JAM_AT, jam.heart())
	var field_cam := _free_camera(I1_FIELD_CAM, I1_FIELD_LOOK, A2B_FOV)
	var waited := 0
	while not (jam.state == IceNode.State.TELL and jam.state_t >= I1_TELL_SHARE * jam.tell_s()) and waited < 900:
		await _frames(1)
		waited += 1
	print("capture: the jam node (seed %d) in its tell after %d frames, its dome at %.2f" % [jam.build_seed, waited, jam.dome_shown()])
	await _save("i1-field")
	_free_camera_done(field_cam)
	_player.respawn_at(_main.to_global(C27B_PLAYER_AT))
	await _frames(int((jam.tell_s() + 1.0) * 60.0))
	# The HUD corrupted: a new round's HUD node, the player inside its field.
	ice.start_round(1)
	await _frames(5)
	hud_node = ice.node_of("hud")
	ice.node_of("jam").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("jam").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _stand(I1_HUD_AT, hud_node.heart())
	waited = 0
	while not ice.corrupting() and waited < 900:
		await _frames(1)
		waited += 1
	await _frames(20)
	var hud = _main.get_node("Hud")
	print("capture: the HUD corrupted after %d frames, %d parts covered, the health line '%s'" % [waited, hud.ice_hud().drawn_rects().size(), hud.combat_hud().line_text()])
	await _save("i1-corrupted")
	_player.respawn_at(_main.to_global(C27B_PLAYER_AT))
	await _frames(int((_main.get_node(IceDirector.NODE_NAME).tuning.hud_s + 0.5) * 60.0))
	# The hunter, round 2 (the round HUD's own, so its line says so), adapted to the round's cannon
	# damage, mid-tell at the player.
	_main.get_node("Hud").round_hud()._start_round(2)
	await _frames(5)
	ice.node_of("jam").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("jam").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	for i in 4:
		ice.note_damage("terminal_cannon", I1_ADAPT_DAMAGE / 4.0)  # each hit noted is capped at hit_cap
	var hunter := ice.hunter
	await _stand(I1_HUNTER_AT, hunter.global_position + Vector3.UP * ice.tuning.hunter_hover_m)
	waited = 0
	while not (hunter.brain.state == DaemonBrain.State.TELL and hunter.brain.state_t >= I1_TELL_SHARE * ice.tuning.hunter_tell_s) and waited < 1200:
		await _frames(1)
		waited += 1
	print("capture: the hunter (seed %d, size %.2f, %d shields) mid-tell after %d frames, %.1f m from the player, adapted %s, its shields #%s" % [hunter.build_seed, hunter.art.size_scale, hunter.art.shield_count(), waited, hunter.global_position.distance_to(_player.global_position), hud.ice_hud().adapt_line(), hunter.shield_color.to_html(false)])
	await _save("i1-hunter")
	_player.respawn_at(_main.to_global(C27B_PLAYER_AT))
	ice.start_round(1)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(10)
	# The line-up: three hunters and two of each node from other seeds, standing, facing the camera.
	var cam := _free_camera(I1_LINEUP_CAM, I1_LINEUP_LOOK, A2B_FOV)
	var lineup: Array[DaemonArt] = []
	for k in I1_LINEUP.size():
		var piece: Array = I1_LINEUP[k]
		var art := _ice_piece(piece[0], piece[2] + Vector3(0.0, 0.9, 0.0), 7000 + k * 7919, func(a): _i1_prepare(a, piece[1]))
		art.get_parent().rotation.y = PI
		lineup.append(art)
	await _frames(70)
	var built := PackedStringArray()
	for art in lineup:
		built.append("%s %d: %d parts" % [art.ai_kind, art.build_seed, art.part_count()])
	print("capture: the line-up: " + "; ".join(built))
	await _save("i1-lineup")
	await _i1_cost(lineup)
	_free_camera_done(cam)
	for art in lineup:
		art.get_parent().queue_free()


func _i1_prepare(a: DaemonArt, kind: String) -> void:
	if kind != "":
		a.set("kind", kind)


## What ICE costs, on this machine: each kind's art (a wall's, a node's, a hunter's) its triangles and
## draw calls as built, and its posing timed alone, its whole _process, five rounds of
## A5_COST_FRAMES frames: the quickest round and the median; then the GPU's time a frame with the
## line-up drawn and hidden, three times each in turn, with what the GPU drew each way.
func _i1_cost(lineup: Array[DaemonArt]) -> void:
	var wall: DaemonArt = _ice_piece("barrier_art", Vector3(0.0, -40.0, 0.0), 4242, func(a): a.span = Vector2(4.8, 3.0))
	var kinds: Array = [[wall], lineup.slice(3, 5), lineup.slice(0, 3)]
	for group in kinds:
		var rounds := PackedFloat32Array()
		for round in 5:
			var usec := 0
			for i in A5_COST_FRAMES:
				for art in group:
					var t0 := Time.get_ticks_usec()
					art._process(1.0 / 60.0)
					usec += Time.get_ticks_usec() - t0
				await _frames(1)
			rounds.append(float(usec) / (A5_COST_FRAMES * group.size()))
		rounds.sort()
		var art: DaemonArt = group[0]
		print("capture: i1 cost, %s: %d triangles, %d draw calls; posing %.1f us a piece a frame at the quickest, %.1f the median (rounds %s)" % [art.ai_kind, art.triangles(), art.draw_calls(), rounds[0], rounds[2], ", ".join(Array(rounds).map(func(x): return "%.1f" % x))])
	wall.get_parent().queue_free()
	var gpu := PackedStringArray()
	var calls := PackedInt32Array([0, 0])
	var prims := PackedInt32Array([0, 0])
	for pass_ in 6:
		var shown := pass_ % 2 == 0
		for art in lineup:
			art.visible = shown
		await _frames(10)
		var ms := await _gpu_ms(A5_COST_FRAMES)
		gpu.append("%s %.3f" % ["drawn" if shown else "hidden", ms])
		calls[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for art in lineup:
		art.visible = true
	print("capture: i1 cost, the GPU's time a frame at 1920x1080 with the line-up's seven drawn and hidden in turn: %s ms; drawn %d draw calls and %d primitives, hidden %d and %d" % [", ".join(gpu), calls[0], prims[0], calls[1], prims[1]])


## A piece of ICE's art alone at `at` (arena space, its centre 0.9 over the floor), from `seed`,
## `prepare` setting it up before it builds.
func _ice_piece(type: String, at: Vector3, seed: int, prepare: Callable) -> DaemonArt:
	var holder := Node3D.new()
	_main.add_child(holder)
	holder.position = at
	var art: DaemonArt = load("res://scripts/ice/%s.gd" % type).new()
	prepare.call(art)
	art.setup(null, seed)
	holder.add_child(art)
	return art


func _i2() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	var br: BreakerDirector = _main.get_node(BreakerDirector.NODE_NAME)
	var hud = _main.get_node("Hud")
	ice.start_round(1)
	br.start_round(1)
	await _frames(10)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	# exploit's marks: the HUD node behind the player broken first (its field would scramble the HUD), a
	# cloak run so the zombie set at the corridor's side never sees the player, then exploit, then Y to
	# load the brute: both effect lines up, the readout's counts showing what was spent.
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	_player.select_slot(0)
	await _stand(I2_MARKS_AT, _main.to_global(I2_MARKS_LOOK))
	br.use(1, Breakers.Kind.CLOAK, _player.eye_position(), _player.aim_direction())
	var zombie: Node3D = targets.get_node("DummyB")
	zombie.global_position = _main.to_global(I2_ZOMBIE_AT)
	_c27b_place(zombie, _main.to_global(I2_ZOMBIE_AT))
	await _frames(int(ceil(br.tuning.use_gap_s * 60.0)) + 2)
	br.use(1, Breakers.Kind.EXPLOIT, _player.eye_position(), _player.aim_direction())
	br.mine.loaded = Breakers.Kind.DECOY
	br.press_cycle()
	await _frames(24)
	var marks: ExploitMarks = br.get_node("ExploitMarks")
	print("capture: exploit's marks: %d seams marked; the readout '%s' / '%s'; under the crosshair %s; the edge wash %.2f" % [marks.shown(), hud.breaker_hud().loaded_text(), hud.breaker_hud().counts_text(), hud.breaker_hud().effect_text(), hud.breaker_hud().wash()])
	await _save("i2-breakers")
	# What the marks cost to place, a frame, while they show.
	var usec := 0
	for i in A5_COST_FRAMES:
		var t0 := Time.get_ticks_usec()
		marks._process(1.0 / 60.0)
		usec += Time.get_ticks_usec() - t0
		await _frames(1)
		if not br.exploit_on_me():
			break
	print("capture: i2 cost, exploit's marks: %d placed a frame in %.1f us (one MultiMesh, one draw call)" % [marks.shown(), float(usec) / A5_COST_FRAMES])
	_c27b_place(zombie, C27B_PARKED + Vector3(zombie.get_index() * 3.0, 0.0, 0.0))
	await _frames(int((br.tuning.cloak_s + 0.5) * 60.0))
	# The brute up close: the wall's other face, the charge breaking it whole.
	ice.start_round(1)
	br.start_round(1)
	await _frames(5)
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	ice.node_of("hud").hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _stand(I2_BRUTE_AT, _main.to_global(I2_BRUTE_LOOK))
	var wall := ice.wall("wall")
	br.use(1, Breakers.Kind.BRUTE, _player.eye_position(), _player.aim_direction())
	await _frames(I2_BRUTE_FRAMES)
	print("capture: the brute up close (%.2f m): the wall (seed %d) %s, %d reached" % [_player.eye_position().distance_to(wall.blast_point(_player.eye_position())), wall.build_seed, "broken" if wall.broken else "standing at %.0f" % wall.health(), br.last_brute_hits])
	await _save("i2-brute")
	await _frames(90)
	# The decoy: round 2 (the round HUD's own), both nodes broken; the hunter hunting the player, the
	# decoy thrown off to the side, the hunter's tell swung onto it and its lance going into it, seen from
	# the player's eyes off to the side of them both.
	hud.round_hud()._start_round(2)
	await _frames(5)
	for kind in ["jam", "hud"]:
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var hunter := ice.hunter
	await _stand(I2_DECOY_AT, hunter.global_position + Vector3.UP * ice.tuning.hunter_hover_m)
	var throw_at: Vector3 = _main.to_global(I2_DECOY_THROW)
	br.use(1, Breakers.Kind.DECOY, _player.eye_position(), (throw_at - _player.eye_position()).normalized())
	var waited := 0
	while not (hunter.brain.prey < 0 and hunter.brain.state == DaemonBrain.State.TELL) and waited < 900:
		await _frames(1)
		waited += 1
	var decoy: Decoy = br.calling()[0] if not br.calling().is_empty() else null
	if decoy != null:
		# Both in view, the hunter still in its tell: the player turns to between the decoy and it.
		var mid: Vector3 = (decoy.point() + hunter.global_position + Vector3.UP * ice.tuning.hunter_hover_m) * 0.5
		var eyes: Camera3D = _player.get_node("Head/Camera")
		var to := mid - eyes.global_position
		_player.rotation.y = atan2(-to.x, -to.z)
		_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	# Its lance, a bar of light, going into the decoy instead of the player.
	while not (hunter.brain.prey < 0 and hunter.brain.state == DaemonBrain.State.STRIKE) and waited < 1200:
		await _frames(1)
		waited += 1
	await _frames(I2_LANCE_FRAMES)
	print("capture: the hunter's lance on the decoy after %d frames (prey %d, %d struck), the decoy %.1f m from the player with %.1f s of call left, the hunter %.1f m from it" % [waited, hunter.brain.prey, decoy.struck if decoy != null and is_instance_valid(decoy) else -1, decoy.global_position.distance_to(_player.global_position) if decoy != null and is_instance_valid(decoy) else -1.0, decoy.left if decoy != null and is_instance_valid(decoy) else -1.0, hunter.global_position.distance_to(decoy.global_position) if decoy != null and is_instance_valid(decoy) else -1.0])
	await _save("i2-decoy")
	_player.respawn_at(_main.to_global(C27B_PLAYER_AT))
	hud.round_hud()._start_round(1)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(10)
	# The line-up: the four pickups (each kind's emblem) and a decoy standing before them, from other seeds.
	var cam := _free_camera(I2_LINEUP_CAM, I2_LINEUP_LOOK, A2B_FOV)
	var lineup: Array[Node3D] = []
	for k in I2_LINEUP.size():
		var p := BreakerPickup.new()
		p.kind = k
		p.spawn_seed = 9100 + k * 7919
		_main.add_child(p)
		p.global_position = _main.to_global(I2_LINEUP[k])
		lineup.append(p)
	var standing := Decoy.new()
	standing.tuning = br.tuning
	standing.spawn_seed = 9500
	standing.deciding = false
	_main.add_child(standing)
	standing.take_word(_main.to_global(I2_LINEUP_DECOY), true, br.tuning.decoy_s)
	standing.rotation.y = 0.0
	lineup.append(standing)
	await _frames(70)
	await _save("i2-lineup")
	await _i2_cost(lineup)
	_free_camera_done(cam)
	for node in lineup:
		node.queue_free()


## What the breakers cost, on this machine: a pickup's and a decoy's art, each one's triangles and draw
## calls as built, and its posing timed alone (its whole _process), five rounds of A5_COST_FRAMES frames:
## the quickest round and the median; then the GPU's time a frame with the line-up drawn and hidden,
## three times each in turn, with what the GPU drew each way.
func _i2_cost(lineup: Array[Node3D]) -> void:
	for group in [lineup.slice(0, 4), lineup.slice(4, 5)]:
		var rounds := PackedFloat32Array()
		for round in 5:
			var usec := 0
			for i in A5_COST_FRAMES:
				for node in group:
					var t0 := Time.get_ticks_usec()
					node.art._process(1.0 / 60.0)
					usec += Time.get_ticks_usec() - t0
				await _frames(1)
			rounds.append(float(usec) / (A5_COST_FRAMES * group.size()))
		rounds.sort()
		var art: DaemonArt = group[0].art
		print("capture: i2 cost, %s: %d triangles, %d draw calls; posing %.1f us one a frame at the quickest, %.1f the median (rounds %s)" % [art.ai_kind, art.triangles(), art.draw_calls(), rounds[0], rounds[2], ", ".join(Array(rounds).map(func(x): return "%.1f" % x))])
	var gpu := PackedStringArray()
	var calls := PackedInt32Array([0, 0])
	var prims := PackedInt32Array([0, 0])
	for pass_ in 6:
		var shown := pass_ % 2 == 0
		for node in lineup:
			node.visible = shown
		await _frames(10)
		var ms := await _gpu_ms(A5_COST_FRAMES)
		gpu.append("%s %.3f" % ["drawn" if shown else "hidden", ms])
		calls[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for node in lineup:
		node.visible = true
	print("capture: i2 cost, the GPU's time a frame at 1920x1080 with the line-up's five drawn and hidden in turn: %s ms; drawn %d draw calls and %d primitives, hidden %d and %d" % [", ".join(gpu), calls[0], prims[0], calls[1], prims[1]])


func _i3() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	var br: BreakerDirector = _main.get_node(BreakerDirector.NODE_NAME)
	var hud = _main.get_node("Hud")
	var blackout: Blackout = _main.get_node(Blackout.NODE_NAME)
	# Its arrival: round 3, whose fixed roll brings it; the hunter and the nodes broken first so nothing
	# else is in the frame; the player watching the spot it forms at, from across the floor.
	hud.round_hud()._start_round(3)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	for kind in ["jam", "hud"]:
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	if ice.hunter != null:
		ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var spot: Vector3 = IceDirector.BLACK_SPOTS[I3_SPOT]
	await _stand(I3_ARRIVE_AT, _main.to_global(spot + Vector3(0.0, I3_ARRIVE_LOOK_H, 0.0)))
	_player.rotation.y += I3_ARRIVE_TURN
	var b := ice.summon_black(I3_SPOT)
	while b.phase_t < ice.black_tuning.tell_s * I3_ARRIVE_SHARE:
		await _frames(1)
	print("capture: Black ICE (seed %d) arriving, %.1f s of its %.0f s tell gone; the lights at %.2f, the hum down %.2f; the warning %s; the guide's badge '%s'" % [b.build_seed, b.phase_t, ice.black_tuning.tell_s, blackout.level, blackout.hum_down, hud.black_ice_hud().warning_text(), hud.guide().badge_text()])
	await _save("i3-black-ice")
	# The combo: out and hunting, the player close in front of it: exploit (its marks on the seals), then a
	# brute while it runs, breaking a seal and throwing it back.
	while b.phase != BlackIce.Phase.OUT:
		await _frames(1)
	br.start_round(3)
	br.mine.counts = PackedInt32Array([2, 1, 0, 1])
	var at := b.global_position
	var toward: Vector3 = _main.to_global(I3_COMBO_FROM)
	var from: Vector3 = at + (toward - at).normalized() * I3_COMBO_M
	_player.respawn_at(Vector3(from.x, _main.to_global(Vector3(0.0, 0.95, 0.0)).y, from.z))
	await _frames(2)
	var eyes: Camera3D = _player.get_node("Head/Camera")
	var to := b.global_position + Vector3.UP * 2.4 - eyes.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	br.use(1, Breakers.Kind.EXPLOIT, _player.eye_position(), _player.aim_direction())
	await _frames(int(ceil(br.tuning.use_gap_s * 60.0)) + 1)
	br.use(1, Breakers.Kind.BRUTE, _player.eye_position(), _player.aim_direction())
	await _frames(I3_COMBO_FRAMES)
	print("capture: the combo: seals %d of %d, %s, the call '%s', exploit's marks %d, %.1f m apart" % [b.seals_left, ice.black_tuning.seals, b.brain.state_name(), hud.black_ice_hud().call_text(), br.get_node("ExploitMarks").shown(), Vector2(b.global_position.x - _player.global_position.x, b.global_position.z - _player.global_position.z).length()])
	await _save("i3-combo")
	# The decoy escape: thrown off to the side, it pulls Black ICE off the player, who watches from apart.
	await _frames(int(ceil(br.tuning.use_gap_s * 60.0)) + 2)
	var decoy_at: Vector3 = _main.to_global(I3_DECOY_AT)
	br.use(1, Breakers.Kind.DECOY, _player.eye_position(), (decoy_at + Vector3.UP * 2.5 - _player.eye_position()).normalized())
	_player.respawn_at(_main.to_global(I3_DECOY_WATCH))
	var waited := 0
	while not (b.brain.prey < 0 and br.calling().size() > 0 and Vector2(b.global_position.x - br.calling()[0].global_position.x, b.global_position.z - br.calling()[0].global_position.z).length() < 1.5) and waited < 600:
		await _frames(1)
		waited += 1
	var look_at: Vector3 = b.global_position + Vector3.UP * 2.0
	var view := look_at - eyes.global_position
	_player.rotation.y = atan2(-view.x, -view.z)
	_player.get_node("Head").rotation.x = atan2(view.y, Vector2(view.x, view.z).length())
	await _frames(20)
	print("capture: the decoy pulled it after %d frames (prey %d), the player %.1f m away, untouched" % [waited, b.brain.prey, Vector2(b.global_position.x - _player.global_position.x, b.global_position.z - _player.global_position.z).length()])
	await _save("i3-decoy")
	ice._on_round_ended(3)
	await _frames(int(maxf(ice.black_tuning.withdraw_s, ice.black_tuning.restore_s) * 60.0) + 30)
	# The line-up: three Black ICE from other seeds, standing in a row, seen from a free camera.
	hud.round_hud()._start_round(1)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(10)
	var cam := _free_camera(I3_LINEUP_CAM, I3_LINEUP_LOOK, A2B_FOV)
	var lineup: Array[Node3D] = []
	for i in I3_LINEUP.size():
		var holder := Node3D.new()
		_main.add_child(holder)
		holder.global_position = _main.to_global(I3_LINEUP[i] + Vector3(0.0, 0.9, 0.0))
		holder.rotation.y = 0.0
		var art: DaemonArt = load("res://scripts/ice/black_ice_art.gd").new()
		art.setup(null, I3_LINEUP_SEEDS[i])
		holder.add_child(art)
		art.drive(DaemonArt.Act.IDLE)
		lineup.append(holder)
	await _frames(70)
	await _save("i3-lineup")
	await _i3_cost(lineup)
	_free_camera_done(cam)
	for node in lineup:
		node.queue_free()
	# A flatline alone: the run over, the loss screen.
	GameSettings.current().set_value("gameplay", "ice", true)
	await _frames(10)
	hud.round_hud()._start_round(4)
	await _frames(5)
	for kind in ["jam", "hud"]:
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var life: SoloLife = null
	for child in _main.get_children():
		if child is SoloLife:
			life = child
	while life.protected():
		await _frames(1)
	var c := ice.summon_black(I3_SPOT)
	c.phase_t = ice.black_tuning.tell_s
	await _stand(Vector3(spot.x + 6.0, 0.95, spot.z + 4.0), _main.to_global(spot + Vector3(0.0, 2.0, 0.0)))
	while life.alive():
		_player.respawn_at(c.global_position + Vector3(0.9, 0.95, 0.0))
		await _frames(1)
	await _frames(40)
	print("capture: flatlined alone: '%s'" % hud.round_hud().summary_text().get_slice("\n", 0))
	await _save("i3-flatline")


## What Black ICE costs, on this machine: its art's triangles and draw calls as built, its posing timed
## alone (its whole _process), five rounds of A5_COST_FRAMES frames: the quickest round and the median;
## then the GPU's time a frame with the line-up drawn and hidden, three times each in turn.
func _i3_cost(lineup: Array[Node3D]) -> void:
	var rounds := PackedFloat32Array()
	for round in 5:
		var usec := 0
		for i in A5_COST_FRAMES:
			for node in lineup:
				var t0 := Time.get_ticks_usec()
				(node.get_child(0) as DaemonArt)._process(1.0 / 60.0)
				usec += Time.get_ticks_usec() - t0
			await _frames(1)
		rounds.append(float(usec) / (A5_COST_FRAMES * lineup.size()))
	rounds.sort()
	var art: DaemonArt = lineup[0].get_child(0)
	print("capture: i3 cost, Black ICE: %d triangles, %d draw calls; posing %.1f us one a frame at the quickest, %.1f the median (rounds %s)" % [art.triangles(), art.draw_calls(), rounds[0], rounds[2], ", ".join(Array(rounds).map(func(x): return "%.1f" % x))])
	var gpu := PackedStringArray()
	var calls := PackedInt32Array([0, 0])
	var prims := PackedInt32Array([0, 0])
	for pass_ in 6:
		var shown := pass_ % 2 == 0
		for node in lineup:
			node.visible = shown
		await _frames(10)
		var ms := await _gpu_ms(A5_COST_FRAMES)
		gpu.append("%s %.3f" % ["drawn" if shown else "hidden", ms])
		calls[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims[0 if shown else 1] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for node in lineup:
		node.visible = true
	print("capture: i3 cost, the GPU's time a frame at 1920x1080 with the line-up's three drawn and hidden in turn: %s ms; drawn %d draw calls and %d primitives, hidden %d and %d" % [", ".join(gpu), calls[0], prims[0], calls[1], prims[1]])


## Sends a ping: fire for one frame.
func _ping() -> void:
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


## Daemon `dummy` put at `at` (world space), facing the player, at home there.
func _c27b_place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	var way: Vector3 = _player.global_position - at
	dummy.global_rotation = Vector3(0.0, atan2(-way.x, -way.z), 0.0)
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


## The GPU's time for the root viewport, in milliseconds a frame, averaged over `frames` frames.
func _gpu_ms(frames: int) -> float:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _frames(5)
	var total := 0.0
	for i in frames:
		await _frames(1)
		await RenderingServer.frame_post_draw
		total += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	RenderingServer.viewport_set_measure_render_time(rid, false)
	return total / frames


## A free camera at `at` looking at `look` (arena space), made current, the player and the HUD
## hidden.
func _free_camera(at: Vector3, look: Vector3, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	_main.add_child(cam)
	cam.global_position = _main.to_global(at)
	cam.look_at(_main.to_global(look), Vector3.UP)
	cam.current = true
	_main.get_node("Hud").visible = false
	_player.visible = false
	return cam


## Back to the player's own camera and the HUD.
func _free_camera_done(cam: Camera3D) -> void:
	cam.current = false
	cam.queue_free()
	_main.get_node("Hud").visible = true
	_player.visible = true


func _c29() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var hud = _main.get_node("Hud")
	var life := _main.get_node("SoloLife")
	# The freeze: rogue.d rearing at the player, its meter most of the way, the beam's last ticks landing in
	# the middle of its tell.
	var rogue: Node3D = targets.get_node("DummyA")
	await _stand(C29_PLAYER_AT, _main.to_global(C29_ROGUE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.3, 0.0)))
	_player.select_slot(C29_SLOT)
	await _frames(SETTLE_FRAMES)
	_c27b_place(rogue, _main.to_global(C29_ROGUE_AT))
	GameSettings.current().set_value("gameplay", "practice", false)  # it fights back from here
	life.combat.states[1]["protect_left"] = 0.0
	rogue.frost.chill = C29_PRECHILL
	rogue.frost.hold_left = 100.0
	while rogue.brain.state != DaemonBrain.State.TELL:
		await _frames(1)
	_player.hold_fire = true
	var told := 0.0
	while not rogue.chmod_frozen():
		told = rogue.brain.state_t
		await _frames(1)
	await _frames(C29_FREEZE_FRAMES)
	print("capture: rogue.d frozen in its tell (%d frozen offs, \"%s\"); the readout \"%s\"; the strip \"%s\" over \"%s\", \"%s\"" % [rogue.brain.frozen_offs, rogue.frost_look().tag_text().replace("\n", " "), hud.freeze_hud().line_text(), hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().state_text()])
	var frame := await _grab()
	frame.save_png(OUT.path_join("c29-freeze.png"))
	_shots += 1
	var corner := frame.get_region(C29_STRIP_CROP)
	corner.resize(C29_STRIP_CROP.size.x * C29_STRIP_SCALE, C29_STRIP_CROP.size.y * C29_STRIP_SCALE, Image.INTERPOLATE_NEAREST)
	corner.save_png(OUT.path_join("c29-strip.png"))
	_shots += 1
	print("capture: c29-freeze and c29-strip (its corner %s, %dx) from one frame, frozen %.2f s into the tell" % [C29_STRIP_CROP, C29_STRIP_SCALE, told])
	_player.hold_fire = false
	# The shatter: the cannon drawn while it is still frozen, one shot.
	_player.select_slot(0)
	await _frames(25)
	await physics_frame
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await _frames(C29_SHATTER_FRAMES)
	print("capture: the cannon's hit on rogue.d frozen: %d shatters" % rogue.shatters)
	await _save("c29-shatter")
	_c27b_place(rogue, C27B_PARKED)
	await _frames(60)
	# Half frozen: a zombie the beam has half filled, the meter under the crosshair, the frost creeping up.
	GameSettings.current().set_value("gameplay", "practice", true)
	var zombie: Node3D = targets.get_node("DummyB")
	await _stand(C29_PLAYER_AT, _main.to_global(C29_ZOMBIE_AT + DUMMY_MIDDLE + Vector3(0.0, 0.2, 0.0)))
	_c27b_place(zombie, _main.to_global(C29_ZOMBIE_AT))
	_player.select_slot(C29_SLOT)
	await _frames(SETTLE_FRAMES)
	_player.inventory.coolant(C29_SLOT).refill()
	_player.hold_fire = true
	await _frames(C29_CHILL_FRAMES)
	print("capture: the zombie half frozen: its meter %.2f, \"%s\"" % [zombie.frost.chill, hud.freeze_hud().line_text()])
	await _save("c29-chill")
	while not zombie.chmod_frozen():
		await _frames(1)
	await _beam_cost(zombie)
	_player.hold_fire = false
	_c27b_place(zombie, C27B_PARKED)
	await _frames(90)
	# ICE: round 2's hunter frozen, then Black ICE in round 4, only slowed.
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	hud.round_hud()._start_round(2)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	for kind in ["jam", "hud"]:
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
		ice.node_of(kind).hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var hunter := ice.hunter
	await _stand(C29_HUNTER_FROM, hunter.global_position + Vector3.UP * hunter.tuning.hunter_hover_m)
	life.combat.states[1]["protect_left"] = 1000.0
	_player.inventory.coolant(C29_SLOT).refill()
	_player.hold_fire = true
	while not hunter.chmod_frozen():
		var to: Vector3 = hunter.global_position + Vector3.UP * hunter.tuning.hunter_hover_m - _player.get_node("Head/Camera").global_position
		_player.rotation.y = atan2(-to.x, -to.z)
		await _frames(1)
	await _frames(C29_FREEZE_FRAMES)
	print("capture: the hunter frozen (\"%s\")" % hunter.frost_look().tag_text().replace("\n", " "))
	await _save("c29-hunter")
	_player.hold_fire = false
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _frames(30)
	hud.round_hud()._start_round(4)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	# The player stands first, then Black ICE is out at its spot ahead: it hunts at once, slowed by the beam.
	var spot_at: Vector3 = IceDirector.BLACK_SPOTS[C29_BLACK_SPOT]
	await _stand(spot_at + C29_BLACK_OFF, _main.to_global(spot_at + Vector3.UP * 2.6))
	_player.inventory.coolant(C29_SLOT).refill()
	var b := ice.summon_black(C29_BLACK_SPOT)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	_player.hold_fire = true
	for i in C29_BLACK_FRAMES:
		var to: Vector3 = b.global_position + Vector3.UP * 2.0 - _player.get_node("Head/Camera").global_position
		_player.rotation.y = atan2(-to.x, -to.z)
		await _frames(1)
	print("capture: Black ICE slowed %.0f%%, frozen %s, seals %d (\"%s\")" % [b.slow * 100.0, b.chmod_frozen(), b.seals_left, hud.freeze_hud().line_text()])
	await _save("c29-black")
	_player.hold_fire = false


func _c30() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var hud = _main.get_node("Hud")
	var life := _main.get_node("SoloLife")
	var order := ["DummyA", "DummyB", "DummyD", "DummyC"]
	# The chain: four daemons standing (practice), toughened so every link lands and none derezzes, the
	# aim on rogue.d; the still once every link is lit.
	await _stand(C30_PLAYER_AT, _main.to_global(C30_CHAIN[0] + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_player.select_slot(C30_SLOT)
	await _frames(SETTLE_FRAMES)
	for i in order.size():
		var dummy: Node3D = targets.get_node(order[i])
		_c27b_place(dummy, _main.to_global(C30_CHAIN[i]))
		_c30_tough(dummy)
	await _frames(20)
	await _c30_fire()
	await _frames(C30_CHAIN_FRAMES)
	print("capture: the chain \"%s\" / \"%s\" (%d links lit, %d packets riding it); the strip \"%s\" over \"%s\", \"%s\", \"%s\"" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text(), _player.pipe_arc().lit(), _player.pipe_arc().packets(), hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
	var frame := await _grab()
	frame.save_png(OUT.path_join("c30-chain.png"))
	_shots += 1
	var corner := frame.get_region(C30_STRIP_CROP)
	corner.resize(C30_STRIP_CROP.size.x * C30_STRIP_SCALE, C30_STRIP_CROP.size.y * C30_STRIP_SCALE, Image.INTERPOLATE_NEAREST)
	corner.save_png(OUT.path_join("c30-strip.png"))
	_shots += 1
	await _chain_cost(targets, order)
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	await _frames(60)
	# Through the frozen: the zombie frozen by chmod 000; the chain from rogue.d conducts through it (and
	# shatters it) on to the runaway. The round's first kill made first, off screen, so its callout is gone.
	targets.get_node("DummyC").hit(1000.0)
	await _frames(C30_CALLOUT_FRAMES)
	await _stand(C30_FROZEN_FROM, _main.to_global(C30_FROZEN[0] + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	for i in 3:
		var dummy: Node3D = targets.get_node(order[[0, 1, 2][i]])
		_c27b_place(dummy, _main.to_global(C30_FROZEN[i]))
		_c30_tough(dummy)
	var frozen: Node3D = targets.get_node("DummyB")
	frozen.max_health = 1.0
	frozen.set("_health", 1.0)
	frozen.chill(10.0)
	hud.round_hud().stats.streak = 0  # no streak callout over the still: this shot is a fresh run of hits
	await _frames(40)
	_player.inventory.buffer(C30_SLOT).empty()
	await _c30_fire()
	await _frames(C30_FROZEN_FRAMES)
	print("capture: through the frozen zombie: \"%s\" / \"%s\", %d shatters" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text(), frozen.shatters])
	await _save("c30-frozen")
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	await _frames(90)
	# The wall: rogue.d in the open, the zombie in reach but behind the low wall: one link.
	await _stand(C30_WALL_FROM, _main.to_global(C30_WALL[0] + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	var front: Node3D = targets.get_node("DummyA")
	var behind: Node3D = targets.get_node("DummyB")
	_c27b_place(front, _main.to_global(C30_WALL[0]))
	_c27b_place(behind, _main.to_global(C30_WALL[1]))
	_c30_tough(front)
	_c30_tough(behind)
	await _frames(30)
	_player.inventory.buffer(C30_SLOT).empty()
	await _c30_fire()
	await _frames(C30_CHAIN_FRAMES)
	print("capture: the wall: \"%s\" / \"%s\"; the zombie behind it %.0f of %.0f" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text(), behind.health(), C30_TOUGH])
	await _save("c30-wall")
	_c27b_place(front, C27B_PARKED)
	_c27b_place(behind, C27B_PARKED + Vector3(3.0, 0.0, 0.0))
	await _frames(90)
	# ICE: round 2, a zombie (slow on its feet: the daemons fight here), the hunter (frozen) and the jam node
	# in one chain.
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	hud.round_hud()._start_round(2)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	life.combat.states[1]["protect_left"] = 1000.0  # out of reach of the hunter's lance while it is set up
	var rogue: Node3D = targets.get_node("DummyC")
	await _stand(C30_ICE_FROM, _main.to_global(C30_ICE_ROGUE + DUMMY_MIDDLE + Vector3(0.0, 0.25, 0.0)))
	_c27b_place(rogue, _main.to_global(C30_ICE_ROGUE))
	_c30_tough(rogue)
	var hunter := ice.hunter
	if hunter != null:
		hunter.global_position = _main.to_global(C30_ICE_HUNTER)
		hunter.chill(10.0)  # frozen by chmod 000: it conducts, and its lance's tell is called off
	life.combat.states[1]["protect_left"] = 0.0
	await _frames(3)
	_player.inventory.buffer(C30_SLOT).empty()
	await _c30_fire()
	await _frames(C30_CHAIN_FRAMES)
	print("capture: the ICE chain \"%s\" / \"%s\"" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text()])
	await _save("c30-ice")
	_c27b_place(rogue, C27B_PARKED)
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _frames(30)
	# Black ICE: round 4, out at its spot; the pipe only flashes it: "pipe: broken pipe".
	hud.round_hud()._start_round(4)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var spot_at: Vector3 = IceDirector.BLACK_SPOTS[C30_BLACK_SPOT]
	await _stand(spot_at + C30_BLACK_OFF, _main.to_global(spot_at + Vector3.UP * 2.6))
	var b := ice.summon_black(C30_BLACK_SPOT)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	await _frames(20)
	var to: Vector3 = b.global_position + Vector3.UP * 2.4 - _player.get_node("Head/Camera").global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	_player.inventory.buffer(C30_SLOT).empty()
	await _c30_fire()
	await _frames(C30_CHAIN_FRAMES)
	print("capture: Black ICE: \"%s\" / \"%s\", seals %d" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text(), b.seals_left])
	await _save("c30-black")


func _c31() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var hud = _main.get_node("Hud")
	var life := _main.get_node("SoloLife")
	var def: Resource = load("res://resources/dev_null.tres")
	var order := ["DummyA", "DummyB", "DummyD", "DummyC"]
	# The hole: dropped among four daemons standing (practice), toughened so they stand until the core; the
	# still a moment into its pull, every one of them held, stretched and on its way in.
	await _stand(C31_PLAYER_AT, _main.to_global(C31_DROP + Vector3(0.0, 0.9, 0.0)))
	_player.select_slot(C31_SLOT)
	await _frames(SETTLE_FRAMES)
	for i in order.size():
		var dummy: Node3D = targets.get_node(order[i])
		_c27b_place(dummy, _main.to_global(C31_CROWD[i]))
		_c30_tough(dummy)
	await _frames(20)
	var hole := await _c31_hole(def, C31_DROP)
	await _frames(C31_HOLE_FRAMES)
	print("capture: the hole: its tag \"%s\", %d held, %d discarded; the strip \"%s\" over \"%s\", \"%s\", \"%s\"" % [hole.tag_text().replace("\n", " / "), hole.held_now(), hole.discards, hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
	var frame := await _grab()
	frame.save_png(OUT.path_join("c31-hole.png"))
	_shots += 1
	var corner := frame.get_region(C30_STRIP_CROP)
	corner.resize(C30_STRIP_CROP.size.x * C30_STRIP_SCALE, C30_STRIP_CROP.size.y * C30_STRIP_SCALE, Image.INTERPOLATE_NEAREST)
	corner.save_png(OUT.path_join("c31-strip.png"))
	_shots += 1
	await _hole_cost(hole)
	# The implosion: the daemons taken away, the hole sent to its collapse, the still a few frames after it
	# implodes (the point of light, the shock rings, "> /dev/null").
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	await _frames(2)
	if is_instance_valid(hole):
		hole.open_age = hole.tuning.open_s + hole.tuning.hold_s - 0.01
		await _frames(int(hole.tuning.collapse_s * 60.0) + 2)
	await _frames(C31_IMPLODE_FRAMES)
	await _save("c31-implosion")
	await _frames(120)
	# The knot: the daemons the hole drew together, then pipe | fired into them.
	_player.select_slot(C31_PIPE)
	await _frames(40)
	for i in order.size():
		var dummy: Node3D = targets.get_node(order[i])
		_c27b_place(dummy, _main.to_global(C31_CROWD[i]))
		_c30_tough(dummy)
	await _frames(10)
	var knot := await _c31_hole(def, C31_DROP)
	await _frames(C31_KNOT_FRAMES)
	var nearest: Node3D = null
	for name in order:
		var dummy: Node3D = targets.get_node(name)
		if dummy.is_alive() and knot.core.is_finite() and (nearest == null or dummy.global_position.distance_to(knot.core) < nearest.global_position.distance_to(knot.core)):
			nearest = dummy
	if nearest == null:
		nearest = targets.get_node(order[0])
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := nearest.global_position + Vector3.UP * 1.1 - cam.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(2)
	await _c30_fire()
	await _frames(C31_KNOT_CHAIN_FRAMES)
	print("capture: the knot: \"%s\" / \"%s\"; the hole \"%s\"" % [hud.pipe_hud().line_text(), hud.pipe_hud().small_text(), knot.tag_text().replace("\n", " / ") if is_instance_valid(knot) else ""])
	await _save("c31-knot")
	if is_instance_valid(knot):
		knot.open_age = knot.tuning.life_s() - 0.02
	await _frames(90)
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	await _frames(60)
	# ICE: round 2: the hunter pulled in, the jam node held in place but hurt, the gate only flickering.
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	hud.round_hud()._start_round(2)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	life.combat.states[1]["protect_left"] = 1000.0
	await _stand(C31_ICE_FROM, _main.to_global(C31_ICE_DROP + Vector3(0.0, 1.2, 0.0)))
	_player.select_slot(C31_SLOT)
	await _frames(40)
	if ice.hunter != null:
		ice.hunter.global_position = _main.to_global(C31_ICE_HUNTER)
	var ice_hole := await _c31_hole(def, C31_ICE_DROP)
	await _frames(C31_ICE_FRAMES)
	print("capture: ICE: \"%s\", %d held, the gate flickered %d times" % [ice_hole.tag_text().replace("\n", " / "), ice_hole.held_now(), ice_hole.walls_flickered])
	await _save("c31-ice")
	if is_instance_valid(ice_hole):
		ice_hole.open_age = ice_hole.tuning.life_s() - 0.02
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _frames(90)
	# Black ICE: round 4, out at its spot; the hole never takes it: "/dev/null: device busy".
	hud.round_hud()._start_round(4)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var spot_at: Vector3 = IceDirector.BLACK_SPOTS[C30_BLACK_SPOT]
	await _stand(spot_at + C31_BLACK_OFF, _main.to_global(spot_at + Vector3.UP * 2.2 + Vector3(0.0, 0.0, 3.0)))
	var b := ice.summon_black(C30_BLACK_SPOT)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	await _frames(20)
	var black_hole := await _c31_hole(def, spot_at + Vector3(0.0, 0.3, 4.5))
	await _frames(C31_HOLE_FRAMES)
	print("capture: Black ICE: \"%s\", seals %d, held %s" % [black_hole.tag_text().replace("\n", " / "), b.seals_left, black_hole.held.has(b)])
	await _save("c31-black")


func _c32() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var hud = _main.get_node("Hud")
	var life := _main.get_node("SoloLife")
	var def: Resource = load("res://resources/sighup.tres")
	var order := ["DummyA", "DummyB", "DummyD", "DummyC"]
	# The burst: dropped among four daemons standing (practice); the still with its front most of the way out,
	# each daemon it has passed stalled and scanned green, its tag typing "reloading config".
	await _stand(C32_PLAYER_AT, _main.to_global(C32_DROP + Vector3(0.0, 0.9, 0.0)))
	_player.select_slot(C32_SLOT)
	await _frames(SETTLE_FRAMES)
	for i in order.size():
		var dummy: Node3D = targets.get_node(order[i])
		_c27b_place(dummy, _main.to_global(C32_CROWD[i]))
		_c30_tough(dummy)
	await _frames(20)
	var burst := await _c32_burst(def, C32_DROP)
	await _frames(C32_WAVE_FRAMES)
	print("capture: the burst: its front %.1f m, %d caught; its tag \"%s\"; the strip \"%s\" over \"%s\", \"%s\", \"%s\"" % [burst.front_m(), burst.caught_count, burst.tag_text().replace("\n", " / "), hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
	var frame := await _grab()
	frame.save_png(OUT.path_join("c32-hup.png"))
	_shots += 1
	var corner := frame.get_region(C30_STRIP_CROP)
	corner.resize(C30_STRIP_CROP.size.x * C30_STRIP_SCALE, C30_STRIP_CROP.size.y * C30_STRIP_SCALE, Image.INTERPOLATE_NEAREST)
	corner.save_png(OUT.path_join("c32-strip.png"))
	_shots += 1
	await _hup_cost(burst)
	await _frames(400)
	# The crowd turning on itself: the daemons fight now (the player out of their reach of attack), four
	# close together; the still on a lash's strike (one daemon lunging at, or diving through, another).
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	life.combat.states[1]["protect_left"] = 100000.0
	await _stand(C32_KNOT_FROM, _main.to_global(Vector3(0.0, 1.1, 7.6)))
	for i in order.size():
		var dummy: Node3D = targets.get_node(order[i])
		_c27b_place(dummy, _main.to_global(C32_KNOT[i]))
		_c30_tough(dummy)
		dummy.brain.hup_guard = 0.0
	await _frames(4)
	var knot := await _c32_burst(def, Vector3(0.0, 0.2, 7.8))
	# rogue.d's lunge and slash reads best; any lash's strike will do once the wait is half gone.
	var lashing: Node3D = null
	for i in C32_LASH_WAIT:
		for name in order:
			var dummy: Node3D = targets.get_node(name)
			if dummy.brain.get("_lash_mark") != null and dummy.brain.state == DaemonBrain.State.STRIKE and dummy.brain.state_t > 0.08 and (name == "DummyA" or i > C32_LASH_WAIT / 2):
				lashing = dummy
		if lashing != null:
			break
		await _frames(1)
	var lashes := 0
	for name in order:
		lashes += targets.get_node(name).brain.lashes
	print("capture: the crowd confused: %s lashing (%d lashes so far); %d caught" % [String(lashing.name) if lashing != null else "none", lashes, knot.caught_count if is_instance_valid(knot) else -1])
	await _save("c32-confused")
	await _frames(400)
	# A caught player's own screen (as another player's SIGHUP leaves it): the glitch, the crosshair drifting
	# off the middle (its true point a faint dot), "SIGHUP: hung up", the AI link hung up.
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	GameSettings.current().set_value("gameplay", "practice", true)
	await _stand(C32_PLAYER_AT, _main.to_global(Vector3(0.0, 1.4, 4.0)))
	_player.take_hup(def.hup_tuning().player_s, def.hup_tuning().player_drift_px)
	await _frames(24)
	print("capture: a caught player: \"%s\", the crosshair %s px off, the link hung up %s" % [hud.sighup_hud().line_text(), str(hud.get("_crosshair").drift()), str(hud.guide().link_hung_up())])
	await _save("c32-player")
	await _frames(200)
	for name in order:
		_c27b_place(targets.get_node(name), C27B_PARKED + Vector3(targets.get_node(name).get_index() * 3.0, 0.0, 0.0))
	await _frames(30)
	# ICE: round 2: the hunter confused (it forgets what it learned), the jam node reloading, the gate untouched.
	GameSettings.current().set_value("gameplay", "ice", true)
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(10)
	var ice: IceDirector = _main.get_node(IceDirector.NODE_NAME)
	hud.round_hud()._start_round(2)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _stand(C32_ICE_FROM, _main.to_global(C32_ICE_DROP + Vector3(0.0, 1.2, 0.0)))
	_player.select_slot(C32_SLOT)
	await _frames(40)
	if ice.hunter != null:
		ice.hunter.global_position = _main.to_global(C31_ICE_HUNTER)
	ice.note_damage("sigkill_rail", 300.0)
	var learned := ice.adapt_text()
	var ice_burst := await _c32_burst(def, C32_ICE_DROP)
	await _frames(C32_WAVE_FRAMES + 12)
	print("capture: ICE: learned \"%s\", now \"%s\"; the hunter %s, the jam node %s; %d nodes reloaded" % [learned, ice.adapt_text(), ice.hunter.brain.hup_name() if ice.hunter != null else "none", IceNode.STATE_NAMES[ice.node_of("jam").state], ice_burst.nodes_reloaded if is_instance_valid(ice_burst) else -1])
	await _save("c32-ice")
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	await _frames(90)
	# Black ICE: round 4, out at its spot; the hangup means nothing to it: "SIGHUP: ignored (nohup)".
	hud.round_hud()._start_round(4)
	await _frames(5)
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	if ice.hunter != null:
		for i in 3:
			ice.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var spot_at: Vector3 = IceDirector.BLACK_SPOTS[C30_BLACK_SPOT]
	await _stand(spot_at + C31_BLACK_OFF, _main.to_global(spot_at + Vector3.UP * 2.2 + Vector3(0.0, 0.0, 3.0)))
	var b := ice.summon_black(C30_BLACK_SPOT)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	await _frames(20)
	var black_burst := await _c32_burst(def, spot_at + Vector3(0.0, 0.2, 4.0))
	await _frames(C32_WAVE_FRAMES + 12)
	print("capture: Black ICE: \"%s\", seals %d, confused %s" % [black_burst.tag_text().replace("\n", " / "), b.seals_left, b.brain.hup_name()])
	await _save("c32-black")


func _c33() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var hud = _main.get_node("Hud")
	var p := Progress.current()
	_c33_progress(p)
	p.choose_skin("terminal_cannon", "dracula")
	p.choose_mod("terminal_cannon", true)
	p.choose_skin("sigterm", "ctrl_c")
	_player.wear(_player.chosen_look())
	await _stand(C33_SHOT_FROM, _main.to_global(Vector3(0.0, 1.2, 4.0)))
	_player.select_slot(0)
	await _frames(SETTLE_FRAMES)
	# The loadout screen: the cannon on its turntable in Dracula, its overclock fitted.
	var menu = hud.pause_menu()
	menu.open_loadout()
	var screen: LoadoutScreen = menu.loadout_screen()
	screen.select(0)
	await _frames(C33_TURN_FRAMES)
	print("capture: the loadout: fit %.2f, the stage %s, the panel %s; \"%s\"" % [screen.fit_scale(), str(screen.stage.size), str(screen.panel_rect()), " | ".join(screen.texts()).left(400)])
	await _save("c33-loadout")
	await _c33_cost(screen)
	# A locked skin under the pointer: SIGHUP's dial tone lighting the handset while its card says how it is earned.
	screen.select(12)
	await _frames(20)
	screen.preview(1)
	await _frames(C33_TURN_FRAMES - 20)
	print("capture: locked: %s" % " | ".join(screen.texts()).left(400))
	await _save("c33-locked")
	screen.preview(-1)
	screen.close()
	menu.close()
	await _frames(20)
	# The line-up: weapons in earned skins on the open floor.
	var lineup := _c33_lineup()
	await _free_view("c33-skins", C33_CAM_AT, C33_CAM_LOOK)
	await _frames(40)
	lineup.queue_free()
	await _frames(10)
	# The toast in play: a SIGTERM shot in its ^C cyan at a daemon, and the unlock dropping in.
	var a: Node3D = targets.get_node("DummyA")
	_c27b_place(a, _main.to_global(C33_SHOT_AT))
	_c30_tough(a)
	var b: Node3D = targets.get_node("DummyB")
	_c27b_place(b, _main.to_global(C33_SHOT_AT + Vector3(2.6, 0.0, -2.2)))
	await _stand(C33_SHOT_FROM, a.global_position + Vector3.UP * 1.0)
	_player.select_slot(1)
	await _frames(SETTLE_FRAMES)
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	_player.drive_input(Vector2.ZERO, false, false, false)
	p.count("kills_sigterm", 50 - p.count_of("kills_sigterm"))
	await _frames(14)
	print("capture: the toast \"%s\", the strip \"%s\"" % [hud.unlock_toast().text(), hud.weapon_hud().ammo_text() if hud.weapon_hud().has_method("ammo_text") else ""])
	await _save("c33-unlock")


## c38: the opener from the Esc menu, over the arena as it was (two daemons ahead, the cannon in hand), its stills
## at the seconds C38_* name, on its own clock.
func _c38() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var a: Node3D = targets.get_node("DummyA")
	var b: Node3D = targets.get_node("DummyB")
	_c27b_place(a, _main.to_global(C33_SHOT_AT))
	_c27b_place(b, _main.to_global(C33_SHOT_AT + Vector3(2.6, 0.0, -2.2)))
	await _stand(C33_SHOT_FROM, a.global_position + Vector3.UP * 1.0)
	_player.select_slot(0)
	await _frames(SETTLE_FRAMES)
	var menu = _main.get_node("Hud").pause_menu()
	var opener: Opener = menu.open_opener()
	await _opener_at(opener, C38_CRASH_AT, false)
	print("capture: the crash at %.2f s: glitch %.2f, the world paused %s, a frozen frame %s" % [opener.elapsed(), opener.glitch_amount(), str(paused), str(opener.frame_texture() != null)])
	await _save("c38-crash")
	await _opener_at(opener, C38_PROMPT_AT, true)
	print("capture: the prompt \"%s\"" % opener.terminal().text())
	await _save("c38-prompt")
	await _opener_at(opener, C38_TERMINAL_AT, true)
	await _save("c38-terminal")
	await _opener_at(opener, C38_UPTIME_AT, true)
	print("capture: the screen at %.2f s:\n%s" % [opener.elapsed(), opener.terminal().text()])
	await _save("c38-uptime")
	await _opener_at(opener, C38_PALETTES_AT, false)
	var tiles: Array[Image] = []
	for id in OpenerPalette.IDS:
		opener.set_palette(OpenerPalette.named(id))
		await process_frame
		await process_frame
		tiles.append(await _grab())
	_save_grid("c38-palettes", tiles, C38_GRID_COLUMNS)
	opener.set_palette(OpenerPalette.named(OpenerPalette.DEFAULT_ID))
	root.size = Vector2i(960, 540)
	for i in 6:
		await process_frame
	print("capture: at 960x540 the terminal has %d columns, a %d px font on %d px rows" % [opener.terminal().columns(), opener.terminal().font_px(), opener.terminal().line_px()])
	await _save("c38-960")
	root.size = Vector2i(1920, 1080)
	while is_instance_valid(opener) and opener.playing():
		await process_frame
	await process_frame
	print("capture: the opener done, the menu back %s, the world paused %s, the 3D view drawn %s" % [str(menu.visible and menu.is_open()), str(paused), str(not root.disable_3d)])


## c39: the settings' "opener data" row (on a demo run, the real data stays off and says so), then the opener on
## WideDemo's invented wide names over the arena, at 1920x1080 and 960x540, and the six palettes made readable.
## Demo data only: the menu's real source is replaced by the demo's, and the opener is handed WideDemo itself.
func _c39() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	var a: Node3D = targets.get_node("DummyA")
	_c27b_place(a, _main.to_global(C33_SHOT_AT))
	await _stand(C33_SHOT_FROM, a.global_position + Vector3.UP * 1.0)
	_player.select_slot(0)
	await _frames(SETTLE_FRAMES)
	var menu = _main.get_node("Hud").pause_menu()
	menu.real_opener_source = func() -> OpenerData: return DemoOpenerData.new()
	menu.open_settings()
	await _frames(SETTLE_FRAMES)
	await _save("c39-settings")
	menu.close()
	await _frames(SETTLE_FRAMES)
	var opener: Opener = OpenerScene.instantiate()
	opener.data = WideDemo.new()
	opener.pause_world = true
	root.add_child(opener)
	await _opener_at(opener, C39_WIDE_AT, true)
	print("capture: the screen at %.2f s (%s data):\n%s" % [opener.elapsed(), opener.data.kind(), opener.terminal().text()])
	await _save("c39-wide")
	root.size = Vector2i(960, 540)
	for i in 6:
		await process_frame
	print("capture: at 960x540 the terminal has %d columns, a %d px font on %d px rows" % [opener.terminal().columns(), opener.terminal().font_px(), opener.terminal().line_px()])
	await _save("c39-wide-960")
	root.size = Vector2i(1920, 1080)
	await _opener_at(opener, C39_PALETTES_AT, false)
	var tiles: Array[Image] = []
	for id in OpenerPalette.IDS:
		opener.set_palette(OpenerPalette.named(id))
		await process_frame
		await process_frame
		tiles.append(await _grab())
	_save_grid("c39-palettes", tiles, C38_GRID_COLUMNS)
	opener.skip()
	await process_frame
	opener.free()
	await process_frame
	print("capture: the opener done, the world paused %s, the 3D view drawn %s" % [str(paused), str(not root.disable_3d)])


## c40: the shrink-away and the fall on demo data, played from the Esc menu as a player would: the prompt the
## terminal ignores, its window shrinking away as the camera pulls back from it, the screen one lit panel on the
## monolith's wall of dark ones, the machine opened out, the look over the edge down the shaft, the fall (the top
## terrace's towers and names sweeping past, the cables and the code light, deeper, the pit's red below), the
## landing on the pit's rim facing the hot process, one still at 960x540, and a sheet of the move. It prints how
## exactly the panel's first frame matches the terminal before it, what the machine costs (the GPU's time a frame
## for its viewport and the window's, and the frame's process time), and the city's counts. --at=<s>,<s>,... (an aid
## for tuning the look) shoots c40-at-<s> at those seconds instead.
func _c40() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _stand(C33_SHOT_FROM, _main.to_global(C33_SHOT_AT) + Vector3.UP)
	await _frames(SETTLE_FRAMES)
	var shots: Array = C40_SHOTS
	var tuning := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			tuning = true
			shots = []
			for at in arg.substr(5).split(","):
				shots.append(["c40-at-" + at, float(at)])
	var menu = _main.get_node("Hud").pause_menu()
	var opener: Opener = menu.open_opener()
	var t := opener.timing()
	var saved := {}
	var early: Array = shots.filter(func(shot): return shot[1] < t.shrink_at - 0.5)
	shots = shots.filter(func(shot): return shot[1] >= t.shrink_at - 0.5)
	# A baseline: the clock's time a frame while only the terminal plays, the same way as the machine's below.
	await _opener_at(opener, t.rest_at - 4.0, false)
	var plain: Array[float] = []
	var mark := Time.get_ticks_usec()
	while is_instance_valid(opener) and opener.elapsed() < t.rest_at:
		await process_frame
		plain.append((Time.get_ticks_usec() - mark) / 1000.0)
		mark = Time.get_ticks_usec()
	print("capture: the terminal alone, %d frames: %.2f ms a frame on the clock (worst %.2f)" % [plain.size(), _mean(plain), _most(plain)])
	for shot in early:
		await _opener_at(opener, shot[1], true)
		print("capture: %s at %.2f s (%s): \"%s\"" % [shot[0], opener.elapsed(), opener.phase_name(), opener.terminal().line_text(opener.terminal().line_count() - 1)])
		saved[shot[0]] = await _grab()
		saved[shot[0]].save_png(OUT.path_join(shot[0] + ".png"))
		_shots += 1
	# The swap, frame by frame: the terminal drawn as ever, then (lifted into its own viewport) its picture shown
	# in its place, then the camera's first frame of the panel.
	await _opener_at(opener, t.shrink_at - Opener.LIFT_S - 0.5 / 60.0, false)
	var direct := await _grab()
	await process_frame
	var before := await _grab()
	var lifted := opener.event_time("lift") >= 0.0
	await _opener_at(opener, t.shrink_at, false)
	var after := await _grab()
	print("capture: the lift at %.2f s (%s): %s" % [opener.event_time("lift"), "lifted" if lifted else "not lifted yet", _difference(direct, before)])
	print("capture: the swap at %.2f s: %s" % [opener.elapsed(), _difference(before, after)])
	if tuning:
		before.save_png(OUT.path_join("c40-at-swap-before.png"))
		after.save_png(OUT.path_join("c40-at-swap-after.png"))
	var city := opener.layout()
	print("capture: the city: %d folders given, %d towers, %d boxes, %d names, %d cables, %d streams; the pit %s; %d nodes in the machine" % [city.given, city.rooms.size(), city.pieces.size(), city.labels.size(), city.cables.size(), city.streams.size(), "under a node_modules" if city.pit_path != "" else "unnamed", opener.fall().node_count()])
	var machine_rid: RID = opener.fall().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(machine_rid, true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var gpu: Array[float] = []
	var gpu_root: Array[float] = []
	var cpu: Array[float] = []
	var wall: Array[float] = []
	var tick := Time.get_ticks_usec()
	for shot in shots:
		while is_instance_valid(opener) and opener.playing() and opener.elapsed() < shot[1]:
			await process_frame
			if opener.elapsed() > t.shrink_at + 0.2 and opener.elapsed() < t.land_at:
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(machine_rid))
				gpu_root.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				wall.append((Time.get_ticks_usec() - tick) / 1000.0)
			tick = Time.get_ticks_usec()
		if not is_instance_valid(opener) or not opener.playing():
			break
		var eye := opener.fall().pose(opener.elapsed()).origin
		print("capture: %s at %.2f s (%s): the camera at (%.0f, %.0f, %.0f), falling %.1f m/s" % [shot[0], opener.elapsed(), opener.phase_name(), eye.x, eye.y, eye.z, opener.fall().speed_at(opener.elapsed())])
		saved[shot[0]] = await _grab()
		saved[shot[0]].save_png(OUT.path_join(shot[0] + ".png"))
		_shots += 1
	print("capture: the machine's cost from the reveal to the landing, %d frames: GPU %.2f ms a frame on average for its viewport (worst %.2f), %.2f for the window's (worst %.2f); process %.2f ms (worst %.2f); %.2f ms a frame from start to end on the clock (worst %.2f)" % [gpu.size(), _mean(gpu), _most(gpu), _mean(gpu_root), _most(gpu_root), _mean(cpu), _most(cpu), _mean(wall), _most(wall)])
	if not tuning:
		var sheet: Array[Image] = []
		for name in C40_SHEET:
			if saved.has(name):
				sheet.append(saved[name])
		if sheet.size() == C40_SHEET.size():
			_save_grid("c40-sequence", sheet, C40_SHEET_COLUMNS)
	while is_instance_valid(opener) and opener.playing():
		await process_frame
	await process_frame
	print("capture: the opener done, the menu back %s, the world paused %s, the 3D view drawn %s" % [str(menu.visible and menu.is_open()), str(paused), str(not root.disable_3d)])
	if not tuning:
		await _c40_small(menu)
		await _c40_palettes()


## c41: the link to the player's AI and the copy of them on demo data, played from the Esc menu as a player would (the
## demo's guide link: its canned answer, nothing called): the HUD coming alive as "Linking your agent..." types, the
## signal climbing out of the pit, the lock (the answer marked live, the rings), the copy rising out of the pit on its
## stair of light, stepping over the rim, walking up, and standing before the player wearing their (the demo's) user
## name; the sheet of the beat, the copy's face, and the copy again at 960x540. --at=<s>,<s>,... shoots c41-at-<s> at
## those seconds instead (an aid for tuning the look).
func _c41() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _stand(C33_SHOT_FROM, _main.to_global(C33_SHOT_AT) + Vector3.UP)
	await _frames(SETTLE_FRAMES)
	var shots: Array = C41_SHOTS
	var tuning := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			tuning = true
			shots = []
			for at in arg.substr(5).split(","):
				shots.append(["c41-at-" + at, float(at)])
	var menu = _main.get_node("Hud").pause_menu()
	var opener: Opener = menu.open_opener()
	var saved := {}
	for shot in shots:
		var at: float = shot[1]
		if at < 0.0 and opener.pit() != null:
			at = opener.pit().rim_at() + C41_RIM_AFTER
		await _opener_at(opener, at, false)
		if not is_instance_valid(opener) or not opener.playing():
			break
		var link := opener.link()
		var said := "linking"
		if link.done():
			said = "live (%d ms)" % link.latency_ms() if link.live() else "scripted (%s)" % link.why()
		var walked := PitBeat.walk_at(opener.elapsed(), opener.timing()) if opener.elapsed() >= opener.timing().copy_at else -1.0
		print("capture: %s at %.2f s (%s): the link %s; the copy %s" % [shot[0], opener.elapsed(), opener.phase_name(), said, ("%.1f m along its walk" % walked) if walked >= 0.0 else "not yet"])
		saved[shot[0]] = await _grab()
		saved[shot[0]].save_png(OUT.path_join(shot[0] + ".png"))
		_shots += 1
	if not tuning:
		var sheet: Array[Image] = []
		for name in C41_SHEET:
			if saved.has(name):
				sheet.append(saved[name])
		if sheet.size() == C41_SHEET.size():
			_save_grid("c41-sequence", sheet, C41_SHEET_COLUMNS)
		if saved.has("c41-copy"):
			var face: Image = saved["c41-copy"].get_region(C41_FACE)
			face.resize(C41_FACE.size.x * 2, C41_FACE.size.y * 2, Image.INTERPOLATE_LANCZOS)
			face.save_png(OUT.path_join("c41-face.png"))
			_shots += 1
	while is_instance_valid(opener) and opener.playing():
		await process_frame
	await process_frame
	print("capture: the opener done, the menu back %s, the world paused %s, the 3D view drawn %s" % [str(menu.visible and menu.is_open()), str(paused), str(not root.disable_3d)])
	if not tuning:
		menu.open()
		await process_frame
		root.size = Vector2i(960, 540)
		await _frames(6)
		var small: Opener = menu.open_opener()
		await _opener_at(small, C41_SMALL_AT, false)
		await _save("c41-copy-960")
		small.skip()
		await process_frame
		root.size = Vector2i(1920, 1080)
		await _frames(6)


## c42: the first launch and the opener's end on demo data, as a player meets them: the first-launch card over the paused
## arena (its own intro state in this run's folder), answered no, and the opener playing itself (the demo guide link: its
## canned answer, nothing called); the intro's Esc menu over the stream; `kill -9` typing, charging, streaming into the
## rifle, the rifle forged; the copy's "you won't." with the reticle; fire pressed; the shot, the derezz, the kill feed,
## the whisper, the title's slam and the title; the sheet; the title again at 960x540. --at=<s>,<s>,... shoots
## c42-at-<s> at those seconds instead, fire pressed at C42_PRESS (an aid for tuning the look).
func _c42() -> void:
	var targets := _main.get_node("Arena/Targets")
	for dummy in targets.get_children():
		_c27b_place(dummy, C27B_PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	await _stand(C33_SHOT_FROM, _main.to_global(C33_SHOT_AT) + Vector3.UP)
	await _frames(SETTLE_FRAMES)
	var before: Array = C42_BEFORE
	var after: Array = C42_AFTER
	var tuning := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			tuning = true
			before = []
			after = []
			for at in arg.substr(5).split(","):
				if float(at) < C42_PRESS:
					before.append(["c42-at-" + at, float(at)])
				else:
					after.append(["c42-at-" + at, float(at)])
	var menu = _main.get_node("Hud").pause_menu()
	var opener: Opener = null
	if not tuning:
		# The first launch: its card over the paused arena, answered no; the opener plays itself.
		menu.first_launch_path = "user://capture-intro.cfg"
		menu.begin_first_launch()
		for i in 20:
			await process_frame
		await _save("c42-card")
		menu.card().answer(false)
		await process_frame
		opener = menu.opener()
	else:
		opener = menu.open_opener()
	var saved := {}
	var paused_shot := false
	for shot in before:
		if not tuning and not paused_shot and shot[1] > C42_PAUSE_AT:
			await _opener_at(opener, C42_PAUSE_AT, false)
			opener.pause()
			for i in 4:
				await process_frame
			await _save("c42-paused")
			opener.resume()
			paused_shot = true
		await _opener_at(opener, shot[1], false)
		if not is_instance_valid(opener) or not opener.playing():
			break
		saved[shot[0]] = await _grab()
		saved[shot[0]].save_png(OUT.path_join(shot[0] + ".png"))
		_shots += 1
		print("capture: %s at %.2f s (%s)" % [shot[0], opener.elapsed(), opener.phase_name()])
	await _opener_at(opener, C42_PRESS, false)
	_fire()
	await process_frame
	var shot_at := opener.shot_time()
	print("capture: fire pressed at %.2f s, the shot at %.2f s" % [opener.pressed_at(), shot_at])
	for shot in after:
		var at: float = shot[1] if tuning else shot_at + shot[1]
		await _opener_at(opener, at, false)
		if not is_instance_valid(opener) or not opener.playing():
			break
		saved[shot[0]] = await _grab()
		saved[shot[0]].save_png(OUT.path_join(shot[0] + ".png"))
		_shots += 1
		print("capture: %s at %.2f s (%s): feed \"%s\", whisper \"%s\", title \"%s\"" % [shot[0], opener.elapsed(), opener.phase_name(), opener.title().feed_text(), opener.title().whisper_text(), opener.title().title_text()])
	if not tuning:
		var sheet: Array[Image] = []
		for name in C42_SHEET:
			if saved.has(name):
				sheet.append(saved[name])
		if sheet.size() == C42_SHEET.size():
			_save_grid("c42-sequence", sheet, C42_SHEET_COLUMNS)
	while is_instance_valid(opener) and opener.playing():
		await process_frame
	await process_frame
	print("capture: the opener done, the menu closed into the arena %s, the world paused %s, the 3D view drawn %s" % [str(not menu.is_open()), str(paused), str(not root.disable_3d)])
	if not tuning:
		menu.open()
		await process_frame
		root.size = Vector2i(960, 540)
		await _frames(6)
		var small: Opener = menu.open_opener()
		await _opener_at(small, C42_PRESS, false)
		_fire()
		await process_frame
		await _opener_at(small, small.shot_time() + C42_SMALL_AFTER, false)
		await _save("c42-title-960")
		small.skip()
		await process_frame
		root.size = Vector2i(1920, 1080)
		await _frames(6)


## The fire action pressed, as the player's button does.
func _fire() -> void:
	var press := InputEventAction.new()
	press.action = "fire"
	press.pressed = true
	root.push_input(press)


## The fall again at 960x540, shot at C40_SMALL_AT.
func _c40_small(menu) -> void:
	menu.open()
	await process_frame
	root.size = Vector2i(960, 540)
	await _frames(6)
	var opener: Opener = menu.open_opener()
	await _opener_at(opener, C40_SMALL_AT, false)
	await _save("c40-fall-960")
	opener.skip()
	await process_frame
	root.size = Vector2i(1920, 1080)
	await _frames(6)


## The fall at C40_PALETTES_AT in each demo palette (a light one's city as dark as any, its colours made to read on
## it): machines of their own, built from the demo's city and drawn straight to a still.
func _c40_palettes() -> void:
	var t := load("res://resources/opener.tres") as OpenerTuning
	var tiles: Array[Image] = []
	for id in OpenerPalette.IDS:
		var fall := TreeFall.new()
		fall.shrink_at = t.shrink_at
		fall.fall_at = t.fall_at
		fall.land_at = t.land_at
		fall.process_name = DemoOpenerData.TOP_PROCESS
		fall.size = Vector2i(1920, 1080)
		fall.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(fall)
		fall.build(TreeLayout.build(PackedStringArray(DemoOpenerData.FOLDERS), PackedInt32Array(DemoOpenerData.COUNTS)), OpenerPalette.named(id).readable(), true)
		fall.step(C40_PALETTES_AT, Vector2.ZERO)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var image := fall.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		tiles.append(image)
		fall.queue_free()
		await process_frame
	_save_grid("c40-palettes", tiles, C38_GRID_COLUMNS)


## How far apart two stills are: the mean difference per channel (0 to 255) and the share of pixels off by more
## than 8 in any channel.
static func _difference(a: Image, b: Image) -> String:
	if a.get_size() != b.get_size():
		return "sizes differ"
	var total := 0.0
	var off := 0
	var step := 2
	var n := 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var d := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) * 255.0 / 3.0
			if d > 8.0:
				off += 1
			n += 1
	return "mean difference %.2f of 255, %.2f%% of pixels off by more than 8" % [total / maxf(n, 1), 100.0 * off / maxf(n, 1)]


static func _mean(values: Array[float]) -> float:
	var sum := 0.0
	for v in values:
		sum += v
	return sum / maxf(values.size(), 1)


static func _most(values: Array[float]) -> float:
	var top := 0.0
	for v in values:
		top = maxf(top, v)
	return top


## Frames until `opener` is `seconds` in (and its cursor lit, if `cursor`), on its own clock: it runs through the
## pause it puts the arena in.
func _opener_at(opener: Opener, seconds: float, cursor: bool) -> void:
	while is_instance_valid(opener) and opener.playing() and (opener.elapsed() < seconds or (cursor and not opener.terminal().cursor_showing())):
		await process_frame


## Stills shrunk to half size, `columns` to a row, as one image.
func _save_grid(name: String, stills: Array[Image], columns: int) -> void:
	var w := floori(stills[0].get_width() * 0.5)
	var h := floori(stills[0].get_height() * 0.5)
	var rows := ceili(float(stills.size()) / columns)
	var grid := Image.create(w * columns, h * rows, false, Image.FORMAT_RGBA8)
	for i in stills.size():
		var tile: Image = stills[i].duplicate()
		tile.resize(w, h, Image.INTERPOLATE_LANCZOS)
		grid.blit_rect(tile, Rect2i(0, 0, w, h), Vector2i((i % columns) * w, floori(float(i) / columns) * h))
	grid.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	print("capture: %s, %d stills in a grid" % [name, stills.size()])


## Demo progress for the stills (C33_PROGRESS), everything its counts have earned held, nothing told.
func _c33_progress(p: Progress) -> void:
	p.clear()
	for feat in C33_PROGRESS:
		p.feats[feat] = C33_PROGRESS[feat]
	for def in WeaponKit.shipped_defs():
		var kit := WeaponKit.of(def.id)
		var items: Array = kit.skins.slice(1)
		items.append(kit.mod)
		for item in items:
			if p.count_of(item.feat) >= item.need:
				p.held[Progress.key_of(def.id, item.skin if item is WeaponSkin else item.id)] = true


## Each weapon of C33_LINEUP in its skin, scaled up over a plinth on an arc round the camera, turned three-quarters
## to it, a pool of its skin's light falling on it from above, its skin's name low in front of it.
func _c33_lineup() -> Node3D:
	var row := Node3D.new()
	row.name = "SkinLineup"
	_main.add_child(row)
	var shipped := {}
	for def in WeaponKit.shipped_defs():
		shipped[def.id] = def
	var n := C33_LINEUP.size()
	for i in n:
		var def: Resource = shipped[C33_LINEUP[i][0]]
		var kit := WeaponKit.of(def.id)
		var index := kit.skin_index(C33_LINEUP[i][1])
		var worn := Loadout.apply(def, index, false)
		var body := Palette.skin_body(worn.light_skin)
		var beam := Palette.skin_beam(worn.light_skin)
		var a := lerpf(-C33_ARC_SPREAD * 0.5, C33_ARC_SPREAD * 0.5, float(i) / float(n - 1))
		var at := Vector3(C33_CAM_AT.x + sin(a) * C33_ARC_R, 0.0, C33_CAM_AT.z - cos(a) * C33_ARC_R)
		var spot := Node3D.new()
		row.add_child(spot)
		spot.global_position = _main.to_global(at)
		spot.rotation.y = -a
		var plinth := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.54
		disc.height = 0.08
		disc.radial_segments = 48
		plinth.mesh = disc
		var matte := StandardMaterial3D.new()
		matte.albedo_color = Palette.VOID
		matte.metallic = 0.2
		matte.roughness = 0.85
		plinth.material_override = matte
		plinth.position.y = 0.04
		spot.add_child(plinth)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.51
		torus.outer_radius = 0.523
		torus.rings = 64
		ring.mesh = torus
		ring.material_override = Palette.unlit_glow(body, 3.0)
		ring.position.y = 0.08
		spot.add_child(ring)
		var pool := OmniLight3D.new()
		pool.light_color = beam
		pool.light_energy = 2.8
		pool.omni_range = 1.9
		pool.position = Vector3(0.0, 1.45, 0.3)
		spot.add_child(pool)
		var model := Viewmodel.make(worn)
		model.visible = true
		model.scale = Vector3.ONE * C33_LINEUP_SCALE
		model.rotation.y = PI * 0.5 + C33_LINEUP_TURN
		model.position = Vector3(0.0, C33_LINEUP_LIFT, 0.0)
		model.set_look(body, beam, worn.viewmodel_glow_energy * 1.6)
		spot.add_child(model)
		var tag := Label3D.new()
		tag.text = "%s\n%s" % [kit.skins[index].display_name, def.short_name]
		tag.font = Palette.mono_font()
		tag.font_size = 40
		tag.pixel_size = 0.003
		tag.outline_size = 12
		tag.modulate = beam
		tag.outline_modulate = Palette.VOID
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.shaded = false
		tag.position = Vector3(0.0, 0.2, 1.55)
		spot.add_child(tag)
	return row


## What the loadout screen costs (C33): the GPU's time with it open (its turntable drawing) against closed, twice.
func _c33_cost(screen: LoadoutScreen) -> void:
	var times := []
	for i in 2:
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		screen.visible = false
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		screen.visible = true
	print("capture: the loadout screen costs the GPU %.2f and %.2f ms a frame open, %.2f and %.2f closed" % [times[0], times[2], times[1], times[3]])


## A burst of the player's own dropped at `at` (arena space) as if thrown there, gone off (C32).
func _c32_burst(def: Resource, at: Vector3) -> Node3D:
	var burst = SighupBurst.spawn(_main, def.hup_tuning(), _main.to_global(at), Vector3.ZERO, 32, "solo", true, 0, false, def.light_skin, [_player.get_rid()])
	_player.take_hup_burst(burst)
	for i in 60:
		if burst.went():
			break
		await _frames(1)
	return burst


## What a burst costs (C32): the GPU's time with it held mid-wave and drawn against with its look hidden, twice
## each in turn, and what one step of its wave's sweep takes on this machine.
func _hup_cost(burst: Node3D) -> void:
	var look: Node3D = burst.get("_look")
	var times := []
	burst.set_physics_process(false)  # held mid-wave while it is measured
	for i in 2:
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		look.visible = false
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		look.visible = true
	var passed: Dictionary = burst.get("_passed")
	var was := passed.duplicate()
	passed.clear()
	var t0 := Time.get_ticks_usec()
	burst.call("_sweep")
	var step_us := Time.get_ticks_usec() - t0
	passed.merge(was, true)
	burst.set_physics_process(true)
	print("capture: a burst costs the GPU %.2f and %.2f ms a frame drawn, %.2f and %.2f hidden; one step of its sweep %d microseconds" % [times[0], times[2], times[1], times[3], step_us])


## A hole of the player's own dropped at `at` (arena space) as if thrown there, open (C31).
func _c31_hole(def: Resource, at: Vector3) -> Node3D:
	var hole = DevNullHole.spawn(_main, def.hole_tuning(), _main.to_global(at), Vector3.ZERO, 31, "solo", true, 0, false, def.light_skin, [_player.get_rid()], _player.hole_judge(def))
	_player.take_hole(hole)
	for i in 60:
		if hole.is_open():
			break
		await _frames(1)
	return hole


## What a hole costs (C31): the GPU's time with it open and drawn against with its look hidden, twice each in
## turn, and what one step of its hold takes on this machine.
func _hole_cost(hole: Node3D) -> void:
	var look: Node3D = hole.get("_look")
	var times := []
	hole.set_physics_process(false)  # held still while it is measured: it neither pulls on nor closes
	for i in 2:
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		look.visible = false
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		look.visible = true
	var t0 := Time.get_ticks_usec()
	hole.call("_hold_everything", 0.0)
	var step_us := Time.get_ticks_usec() - t0
	hole.set_physics_process(true)
	print("capture: a hole costs the GPU %.2f and %.2f ms a frame drawn, %.2f and %.2f hidden; one step of its hold %d microseconds" % [times[0], times[2], times[1], times[3], step_us])


## One click of fire, the pipe drawn (C30).
func _c30_fire() -> void:
	await physics_frame
	_player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


## A daemon toughened for a still (C30): every link lands on it and it stands.
func _c30_tough(dummy: Node3D) -> void:
	dummy.max_health = C30_TOUGH
	dummy.set("_health", C30_TOUGH)


## What a chain costs (C30): the GPU's time with a four-link chain held drawn against with it hidden, twice
## each in turn, and the time this machine took to build one.
func _chain_cost(targets: Node, order: Array) -> void:
	var arc: Node3D = _player.pipe_arc()
	var times := []
	for i in 2:
		_player.inventory.buffer(C30_SLOT).empty()
		await _c30_fire()
		await _frames(C30_CHAIN_FRAMES)
		arc.set("_age", PipeArc.LINK_DELAY_S * 4.0)
		arc.set_process(false)
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		arc.visible = false
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		arc.visible = true
		arc.set_process(true)
	var pool := PipeChain.pool_in(_main)
	var first := PipeChain.target_of(targets.get_node(order[0]))
	var tuning: PipeTuning = load("res://resources/pipe_chain.tres").pipe
	var sight := func(a: Vector3, b: Vector3) -> bool: return _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty()
	var t0 := Time.get_ticks_usec()
	var links: Array = []
	for i in 100:
		links = PipeChain.build(first, first["middle"], pool, sight, tuning, 26.0, false)
	var built := float(Time.get_ticks_usec() - t0) / 100.0
	print("capture: a chain of %d links builds in %.0f microseconds; the GPU %.2f and %.2f ms a frame with one drawn, %.2f and %.2f without" % [links.size(), built, times[0], times[2], times[1], times[3]])


## What the beam and the frost cost (C29): the beam's nodes, the frost's crust sets, and the GPU's time
## with the beam running on a frozen daemon against with both hidden, twice each in turn.
func _beam_cost(target: Node3D) -> void:
	var beam: Node3D = _player.freeze_beam()
	var look: FrostLook = target.frost_look()
	var times := []
	for i in 2:
		beam.visible = true
		for crust in look.crusts():
			crust.visible = true
		times.append(await _gpu_ms(A4_GPU_FRAMES))
		beam.visible = false
		for crust in look.crusts():
			crust.visible = false  # the look itself shows itself each frame; its crusts are what draw
		times.append(await _gpu_ms(A4_GPU_FRAMES))
	beam.visible = true
	for crust in look.crusts():
		crust.visible = true
	print("capture: the beam is %d nodes and the frost %d crust sets; the GPU %.2f and %.2f ms a frame with them, %.2f and %.2f without" % [beam.get_child_count(), look.crusts().size(), times[0], times[2], times[1], times[3]])


## A still from a free camera at `at` looking at `look` (arena space), the player and the HUD hidden.
func _free_view(name: String, at: Vector3, look: Vector3) -> void:
	var cam := _free_camera(at, look, A3_OVERVIEW_FOV)
	await _frames(30)
	await _save(name)
	_free_camera_done(cam)


## Stands the player at `at` (arena space) looking at `target` (world space), settled.
func _stand(at: Vector3, target: Vector3) -> void:
	_player.respawn_at(_main.to_global(at))
	await _frames(30)
	var cam: Camera3D = _player.get_node("Head/Camera")
	var to := target - cam.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(SETTLE_FRAMES)


func _frames(n: int) -> void:
	for i in n:
		_player.drive_input(Vector2.ZERO)
		await physics_frame


## What is on screen now, once it is drawn.
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Stills side by side, each cut to A2B_CROP, as one image.
func _save_strip(name: String, stills: Array[Image]) -> void:
	var strip := Image.create(A2B_CROP.size.x * stills.size(), A2B_CROP.size.y, false, Image.FORMAT_RGBA8)
	for i in stills.size():
		strip.blit_rect(stills[i], A2B_CROP, Vector2i(A2B_CROP.size.x * i, 0))
	strip.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	print("capture: %s, %d stills side by side" % [name, stills.size()])


func _save(name: String) -> void:
	var image := await _grab()
	image.save_png(OUT.path_join(name + ".png"))
	_shots += 1
	var drawn := []
	for kind in [Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_TYPE_SHADOW]:
		for info in [Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME, Viewport.RENDER_INFO_OBJECTS_IN_FRAME]:
			drawn.append(root.get_render_info(kind, info))
	print("capture: %s drew %d draw calls, %d primitives, %d objects; shadows %d draw calls, %d primitives, %d objects" % ([name] + drawn))
