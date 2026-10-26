extends SceneTree
## Headless weapon test for SIGKILL (C16). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/weapon_test.gd
##
## The arsenal end to end: every WeaponDef loaded and validated (bad ones refused, from the
## loadout too), the inventory's rules on their own (swap, last weapon, cycling, magazine and
## reserve, reload, the per-weapon interval, no shot mid-swap or mid-reload), SIGTERM's
## pellets and falloff, then the real arena with the real player and real key and wheel
## events (the swap and reload timed to the frame, a point-blank dummy kill, the cannon as it
## was), and a host and a joiner over ENet on 127.0.0.1 (the net test's harness): forged
## intents with an unknown weapon, too fast, switched too fast and from an empty magazine
## dropped by reason, SIGTERM's damage from the host's own pellets at point blank, mid and
## long range, the kill feed naming SIGTERM, an R reload mid-match keeping the ammo. Then the
## weapon strip's layout at two screen sizes. Nothing outside this process is touched.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const WeaponTuningScript = preload("res://scripts/weapon_tuning.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const Inventory = preload("res://scripts/weapons/inventory.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const CombatHud = preload("res://scripts/net/combat_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const CANNON_PATH := "res://resources/terminal_cannon.tres"
const SIGTERM_PATH := "res://resources/sigterm.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
const FX_GROUP := &"cannon_fx"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const EPS := 0.0001
## A clear line across the arena at z 15, from the S2 spawn eastwards: no cover on it.
const LINE_Z := 15.0
const SHOOTER_X := -15.0
const STAND_Y := 0.95
## Where a pellet aimed at a standing player's middle goes in: the body's centre height.
const BODY_Y := 1.0
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "OS.get_environment", "OS.get_user", "execute_with_pipe", "StreamPeerTCP", "TCPServer", "HTTPRequest", "HTTPClient", "UDPServer", "PacketPeerUDP", "ENetMultiplayerPeer", "FileAccess", "DirAccess", "JSON", "RichTextLabel", "bbcode"]
const WEAPON_SOURCES := ["res://scripts/weapons/weapon_def.gd", "res://scripts/weapons/arsenal_tuning.gd", "res://scripts/weapons/inventory.gd", "res://scripts/hud/weapon_hud.gd"]

var _fails := 0
var _checks := 0
var _branches: Array = []
var _cannon: Resource
var _sigterm: Resource


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_cannon = load(CANNON_PATH)
	_sigterm = load(SIGTERM_PATH)
	_def_checks()
	_arsenal_checks()
	_inventory_checks()
	_host_rule_checks()
	_pellet_checks()
	_source_checks()
	await _solo_checks()
	await _match_checks()
	await _fresh_match_checks()
	await _layout_checks()
	await _cleanup()
	print("WEAPON: %d checks" % _checks)
	print("WEAPON RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- Definitions. ---

func _def_checks() -> void:
	var c = _cannon
	var s = _sigterm
	_check("both shipped weapons are WeaponDefs and pass their own checks, feel included", c is WeaponDefScript and s is WeaponDefScript and c.problems().is_empty() and s.problems().is_empty(), "%s | %s" % [c.problems(), s.problems()])
	_check("the terminal cannon is weapon #1 as it was: damage 25, a 0.16 s interval, 120 m, one pellet, no magazine (infinite ammo), no falloff, SIGKILL in the feed, teal", c.id == "terminal_cannon" and c.damage == 25.0 and c.fire_cooldown == 0.16 and c.fire_range == 120.0 and c.fire_mode == WeaponDefScript.FireMode.HITSCAN_SINGLE and c.pellet_count == 1 and c.magazine_size == WeaponDefScript.INFINITE and c.reserve_ammo == WeaponDefScript.INFINITE and c.reload_s == 0.0 and c.damage_at(119.9) == 25.0 and c.kill_word == "SIGKILL" and c.light_skin == "teal")
	_check("SIGTERM: 9 pellets in a 6 degree cone, 14 each, full to 4 m then down to 20% at 24 m, a 0.9 s pump, 6 in the magazine and 24 in reserve, a 2.2 s reload, violet, its own fiction line", s.id == "sigterm" and s.fire_mode == WeaponDefScript.FireMode.HITSCAN_PELLETS and s.pellet_count == 9 and s.spread_degrees == 6.0 and s.damage == 14.0 and s.falloff_start_m == 4.0 and s.falloff_end_m == 24.0 and s.falloff_floor == 0.2 and s.fire_cooldown == 0.9 and s.magazine_size == 6 and s.reserve_ammo == 24 and s.reload_s == 2.2 and s.light_skin == "violet" and s.fiction == "SIGTERM: please exit." and s.kill_word == "SIGTERM")
	_check("the mod and skin slots are empty data on both: no unlocks yet", c.mod_slots.is_empty() and c.skin_slots.is_empty() and s.mod_slots.is_empty() and s.skin_slots.is_empty())
	_check("the built-in defaults are the cannon: WeaponDef.new() is a usable weapon", WeaponDefScript.new().problems().is_empty() and WeaponDefScript.new().id == "terminal_cannon")
	var bad_slots: Array[String] = [""]
	var cases := [
		[s, "fire_mode", WeaponDefScript.FireMode.PROJECTILE, "not built yet"],
		[s, "fire_mode", WeaponDefScript.FireMode.BEAM, "not built yet"],
		[s, "pellet_count", 1, "pellets must number"],
		[s, "pellet_count", 40, "pellets must number"],
		[c, "pellet_count", 3, "exactly 1 pellet"],
		[s, "spread_degrees", 0.0, "spread above 0"],
		[s, "spread_degrees", 90.0, "spread_degrees"],
		[s, "magazine_size", 0, "magazine_size"],
		[s, "reserve_ammo", -5, "reserve_ammo"],
		[s, "reload_s", 0.0, "reload_s"],
		[c, "reserve_ammo", 10, "no magazine"],
		[s, "falloff_end_m", 2.0, "falloff"],
		[s, "falloff_floor", 1.5, "falloff_floor"],
		[s, "light_skin", "hotpink", "light_skin"],
		[s, "id", "Bad Id", "id must"],
		[s, "id", "", "id must"],
		[s, "fiction", "x".repeat(29), "fiction"],
		[s, "display_name", "", "display_name"],
		[s, "kill_word", "SIG\nTERM", "kill_word"],
		[s, "fire_cooldown", 0.0, "fire interval"],
		[s, "damage", -1.0, "damage"],
		[s, "mod_slots", bad_slots, "mod_slots"],
	]
	var missed := PackedStringArray()
	for case in cases:
		var d: Resource = case[0].duplicate()
		d.set(case[1], case[2])
		var text := ", ".join(d.problems())
		if not text.contains(case[3]):
			missed.append("%s=%s gave [%s]" % [case[1], case[2], text])
	_check("bad weapon values are each refused with the reason: unbuilt modes, pellet counts, spread, magazine, reserve, reload, falloff, an unknown skin, ids, names, fiction, interval, damage, slots (%d cases)" % cases.size(), missed.is_empty(), "; ".join(missed))


func _arsenal_checks() -> void:
	var shipped = load(ARSENAL_PATH)
	_check("the shipped arsenal is valid: the cannon in slot 1, SIGTERM in slot 2, a 0.3 s swap", shipped is Arsenal and shipped.problems().is_empty() and shipped.loadout.size() == 2 and shipped.loadout[0].id == "terminal_cannon" and shipped.loadout[1].id == "sigterm" and shipped.swap_s == 0.3, str(shipped.problems()))
	var bad_sig: Resource = _sigterm.duplicate()
	bad_sig.pellet_count = 0
	var mixed := Arsenal.new()
	var list: Array[Resource] = [_cannon, bad_sig, WeaponTuningScript.new(), _cannon, _sigterm]
	mixed.loadout = list
	var problems := ", ".join(mixed.problems())
	var usable: Array = Arsenal.usable_loadout(mixed)
	_check("a loadout with a broken SIGTERM, a plain WeaponTuning and a repeated id: each refused and named, the good ones kept in order", usable.size() == 2 and usable[0] == _cannon and usable[1] == _sigterm and problems.contains("slot 2 (sigterm) refused") and problems.contains("slot 3 is not a WeaponDef") and problems.contains("slot 4 repeats the id terminal_cannon"), "%s | %s" % [problems, usable.map(func(d): return d.id)])
	var none := Arsenal.new()
	var only_bad: Array[Resource] = [bad_sig]
	none.loadout = only_bad
	var fallback: Array = Arsenal.usable_loadout(none)
	_check("nothing usable leaves the built-in cannon alone; an empty loadout is refused too", fallback.size() == 1 and fallback[0].id == "terminal_cannon" and fallback[0].problems().is_empty() and Arsenal.new().problems().size() >= 1)
	var many := Arsenal.new()
	var ten: Array[Resource] = []
	for i in 10:
		var d: Resource = _cannon.duplicate()
		d.id = "w%d" % i
		ten.append(d)
	many.loadout = ten
	_check("at most nine slots: a tenth weapon is refused", Arsenal.usable_loadout(many).size() == 9 and ", ".join(many.problems()).contains("1 to 9"))
	var slow := Arsenal.new()
	slow.swap_s = 0.0
	slow.loadout = list
	_check("a swap time of 0 is refused and the built-in timing used", Arsenal.usable_timing(slow).swap_s == 0.3 and ", ".join(slow.problems()).contains("swap_s"))


# --- The inventory on its own. ---

func _inventory_checks() -> void:
	var inv := Inventory.new([_cannon, _sigterm], 0.3, 1.6)
	_check("a fresh inventory: the cannon drawn, SIGTERM full at 6 and 24, nothing running", inv.current == 0 and inv.last == 0 and inv.mags == [-1, 6] and inv.reserves == [-1, 24] and not inv.is_swapping() and not inv.is_reloading())
	_check("drawing the drawn weapon or a slot that is not there does nothing", not inv.select(0) and not inv.select(2) and not inv.select(-1) and not inv.is_swapping())
	var drew := inv.select(1)
	var mid := inv.try_fire()
	inv.tick(0.29)
	var still := inv.try_fire()
	inv.tick(0.02)
	_check("drawing SIGTERM takes the swap time: no shot at 0 s or 0.29 s, the fiction line up, then ready", drew and mid == Inventory.BLOCK_SWAP and still == Inventory.BLOCK_SWAP and inv.fiction_left > 0.0 and not inv.is_swapping() and inv.last == 0, "%s %s" % [mid, still])
	var fired := PackedStringArray()
	for i in 6:
		fired.append(inv.try_fire())
		fired.append(inv.try_fire())  # straight after: the pump has not cycled
		inv.tick(0.9)
	_check("six shots empty the magazine, each pump blocking the next for 0.9 s, the reserve untouched", fired == PackedStringArray(["", "cooldown", "", "cooldown", "", "cooldown", "", "cooldown", "", "cooldown", "", "cooldown"]) and inv.mags[1] == 0 and inv.reserves[1] == 24, str(fired))
	var empty := inv.try_fire()
	var during := inv.try_fire()
	inv.tick(2.19)
	var before_done: int = inv.mags[1]
	inv.tick(0.02)
	_check("fire on an empty magazine starts the 2.2 s reload instead of a shot; no shot during it; the rounds go in when it ends", empty == Inventory.BLOCK_EMPTY and during == Inventory.BLOCK_RELOAD and before_done == 0 and inv.mags[1] == 6 and inv.reserves[1] == 18 and not inv.is_reloading())
	inv.try_fire()
	inv.tick(0.9)
	inv.try_fire()
	var started := inv.reload()
	inv.tick(2.21)
	_check("a reload of a half-used magazine takes only what it needs", started and inv.mags[1] == 6 and inv.reserves[1] == 16)
	_check("no reload of a full magazine, nor of the cannon", not inv.reload() and inv.select(0) and not inv.reload())
	inv.tick(0.31)
	inv.select(1)
	inv.tick(0.31)
	inv.try_fire()
	inv.tick(0.9)
	inv.reload()
	inv.tick(1.0)
	var stopped := inv.select(0)
	var reloading_after := inv.is_reloading()
	inv.tick(2.0)
	inv.select(1)
	_check("drawing another weapon stops a reload: the rounds stay where they were", stopped and not reloading_after and inv.mags[1] == 5 and inv.reserves[1] == 16, "%d %d" % [inv.mags[1], inv.reserves[1]])
	var to_last := inv.swap_last()
	var now_cannon: int = inv.current
	var back := inv.swap_last()
	_check("Q swaps to the last weapon and back", to_last and now_cannon == 0 and back and inv.current == 1 and inv.last == 0)
	inv.tick(0.31)
	_check("the wheel cycles both ways and wraps round", inv.cycle(1) and inv.current == 0 and inv.cycle(-1) and inv.current == 1 and inv.cycle(-1) and inv.current == 0)
	inv.tick(0.31)
	inv.select(1)
	inv.tick(0.31)
	inv.try_fire()
	inv.select(0)
	inv.tick(0.31)
	var cannon_ok := inv.try_fire()
	inv.select(1)
	inv.tick(0.31)
	var pump_left := inv.try_fire()
	inv.tick(0.3)
	_check("each weapon's interval runs on while another is drawn: the cannon fires after the swap, SIGTERM's pump is still cycling when it comes back", cannon_ok == "" and pump_left == Inventory.BLOCK_COOLDOWN and inv.try_fire() == "", "%s %s" % [cannon_ok, pump_left])
	inv.mags[1] = 0
	inv.reserves[1] = 0
	inv.tick(0.9)
	_check("an empty magazine with nothing in reserve clicks dry and starts no reload", inv.try_fire() == Inventory.BLOCK_DRY and not inv.is_reloading())
	inv.refill()
	_check("a new life refills every weapon and stops anything running", inv.mags == [-1, 6] and inv.reserves == [-1, 24] and not inv.is_swapping() and not inv.is_reloading())
	var cannon := Inventory.new([_cannon], 0.3)
	var all_fired := true
	for i in 500:
		all_fired = all_fired and cannon.try_fire() == ""
		cannon.tick(0.17)
	_check("the cannon fires 500 times at its interval and never needs a reload", all_fired and cannon.mags[0] == -1 and not cannon.reload())


# --- The host's rules on their own. ---

func _host_rule_checks() -> void:
	var t := CombatTuningScript.new()
	var c := Combat.new(t, [_cannon, _sigterm], 0.3)
	c.add_player(7)
	var eye := Vector3(0, 1.65, 10)
	var dir := Vector3(0, 0, -1)
	var seq := [0]
	var shoot := func(weapon: String, now: float) -> String:
		seq[0] += 1
		var word := c.validate(7, seq[0], 0, weapon, eye, dir, eye, 0, now)
		if word == "":
			c.accept(7, seq[0], weapon, now)
		return word
	var words := PackedStringArray()
	words.append(shoot.call("sigterm", 1.0))  # never drawn: not in hand
	words.append(shoot.call("rm_rf", 1.0))  # no such weapon
	words.append(c.draw(7, 0, "sigterm", 0, 1.0))
	words.append(shoot.call("sigterm", 1.1))  # still being drawn (ready at 1.225)
	words.append(shoot.call("sigterm", 1.25))
	words.append(shoot.call("sigterm", 1.5))  # the pump: 0.675 s at least
	words.append(shoot.call("sigterm", 1.95))
	words.append(shoot.call("terminal_cannon", 2.0))  # the cannon is not in hand
	_check("the host's rules: a weapon never drawn or unknown is not in hand, a fresh draw is not ready for the swap time, SIGTERM's pump is enforced (less the 25% tolerance)", c.drawn_by(7) == "sigterm" and words == PackedStringArray(["weapon", "weapon", "", "swap", "", "rate", "", "weapon"]) and c.ammo_of(7, "sigterm") == [4, 24], str(words))
	var r := PackedStringArray()
	r.append(c.draw(7, 0, "terminal_cannon", 0, 2.0))
	r.append(c.reload(7, 0, "terminal_cannon", 0, 2.5))  # no magazine
	r.append(c.draw(7, 0, "sigterm", 0, 2.6))
	r.append(c.reload(7, 0, "sigterm", 0, 2.7))  # mid-draw (ready at 2.825): taken, from 2.825
	r.append(c.reload(7, 0, "sigterm", 0, 2.9))  # already reloading
	r.append(shoot.call("sigterm", 3.0))  # mid-reload
	r.append(c.reload(7, 0, "sigterm", 0, 3.1))  # already reloading
	r.append(shoot.call("sigterm", 2.825 + 1.64))  # 10 ms before it is done
	r.append(shoot.call("sigterm", 2.825 + 1.66))
	_check("reloads as the inventory has them: none for the cannon or twice, no shot while one runs, the rounds in once its time is up (2.2 s less 25%); one that comes mid-draw (a late draw) is taken and starts when the draw is done", r == PackedStringArray(["", "reload", "", "", "reload", "reload", "reload", "reload", ""]) and c.ammo_of(7, "sigterm") == [5, 22], "%s %s" % [r, c.ammo_of(7, "sigterm")])
	c.reload(7, 0, "sigterm", 0, 5.0)
	c.draw(7, 0, "terminal_cannon", 0, 5.1)
	c.draw(7, 0, "sigterm", 0, 5.2)
	var after_stop: String = shoot.call("sigterm", 7.5)
	_check("drawing another weapon stops a reload still running: its rounds never go in", after_stop == "" and c.ammo_of(7, "sigterm") == [4, 22], str(c.ammo_of(7, "sigterm")))
	c.reload(7, 0, "sigterm", 0, 7.6)
	c.draw(7, 0, "terminal_cannon", 0, 7.6 + 2.3)
	c.draw(7, 0, "sigterm", 0, 7.6 + 2.4)
	var kept_reload: String = shoot.call("sigterm", 7.6 + 2.8)
	_check("a reload whose time was up before a draw keeps its rounds: SIGTERM back in hand fires from a full magazine", kept_reload == "" and c.ammo_of(7, "sigterm") == [5, 20], "%s %s" % [kept_reload, c.ammo_of(7, "sigterm")])
	# The cheat: empty SIGTERM, fire the cannon a while, come back: no reload happened.
	var at := 11.5
	while c.ammo_of(7, "sigterm")[0] > 0 and at < 40.0:
		shoot.call("sigterm", at)
		at += 0.7
	c.draw(7, 0, "terminal_cannon", 0, at)
	at += 0.3
	for i in 20:
		shoot.call("terminal_cannon", at)
		at += 0.17
	c.draw(7, 0, "sigterm", 0, at)
	at += 0.3
	var background: String = shoot.call("sigterm", at)
	var idle_draw := c.draw(7, 0, "terminal_cannon", 0, at + 10.0)
	var instant: String = shoot.call("terminal_cannon", at + 10.05)
	_check("no reload behind the player's back: a SIGTERM emptied, the cannon fired for 3 s, SIGTERM drawn again is still empty; and an idle player who draws still waits out the draw", background == "empty" and idle_draw == "" and instant == "swap", "%s %s" % [background, instant])
	c.states[7]["ammo"]["sigterm"] = {"mag": 1, "reserve": 9, "last_fire": -INF}
	c.draw(7, 0, "sigterm", 0, 44.0)
	c.reload(7, 0, "sigterm", 0, 45.0)
	var timing_ok: bool = absf(c.reload_left(7, 45.5) - (0.225 + 1.65 - 1.5)) < EPS or absf(c.reload_left(7, 45.5) - 1.15) < EPS
	c.settle(7, 46.0)
	var not_yet: Array = c.ammo_of(7, "sigterm")
	c.settle(7, 46.7)
	_check("settle(), run before the host reports a count, puts in a reload's rounds once its time is up and not before; reload_left() says how long it has to go (1.15 s at 45.5)", timing_ok and not_yet == [1, 9] and c.ammo_of(7, "sigterm") == [6, 4] and c.states[7]["reloading"] == "", "%s then %s" % [not_yet, c.ammo_of(7, "sigterm")])
	c.states[7]["ammo"]["sigterm"] = {"mag": 0, "reserve": 0, "last_fire": -INF}
	c.draw(7, 0, "sigterm", 0, 50.0)
	_check("with nothing in reserve there is no reload and the magazine stays empty", c.reload(7, 0, "sigterm", 0, 51.0) == "reload" and shoot.call("sigterm", 52.0) == "empty")
	var dead_draw := c.draw(9, 0, "sigterm", 0, 1.0)
	var past_life := c.draw(7, 0, "terminal_cannon", 1, 53.0)
	c.add_player(9)
	var big := c.damage_player(9, 7, 126.0)
	var refused := c.damage_player(7, 9, 0.0).is_empty() and c.damage_player(7, 9, NAN).is_empty() and c.damage_player(7, 9, -5.0).is_empty()
	c.states[7]["ammo"]["sigterm"] = {"mag": 2, "reserve": 10, "last_fire": -INF}
	var reloading_then: bool = c.reload(7, 0, "sigterm", 0, 54.0) == "" and c.states[7]["reloading"] == "sigterm"
	c.respawn(7)
	_check("damage is the amount the pellets add up to (126 kills from full), never zero, NaN or negative; a new life refills, stops a reload and keeps the weapon in hand; draws from no player or a past life are refused", big == {"health": 0.0, "killed": true} and refused and reloading_then and c.ammo_of(7, "sigterm") == [6, 24] and c.states[7]["reloading"] == "" and c.drawn_by(7) == "sigterm" and dead_draw == "no_player" and past_life == "life")
	_check("drops are counted by reason", c.drops.get("weapon", 0) == 3 and c.drops.get("rate", 0) == 1 and c.drops.get("swap", 0) == 2 and c.drops.get("reload", 0) == 6 and c.drops.get("empty", 0) == 2, str(c.drops))


# --- Pellets and falloff. ---

func _pellet_checks() -> void:
	var s: WeaponDefScript = _sigterm
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var aim := Vector3(0.3, -0.1, -1.0).normalized()
	var cone := deg_to_rad(s.spread_degrees)
	var count_ok := true
	var first_ok := true
	var inside := true
	var widest := 0.0
	var angle_sum := 0.0
	var quadrants := [0, 0, 0, 0]
	var right := aim.cross(Vector3.UP).normalized()
	var up := right.cross(aim).normalized()
	var n := 0
	for i in 2000:
		var dirs := s.pellet_directions(aim, rng)
		count_ok = count_ok and dirs.size() == 9
		first_ok = first_ok and dirs[0].is_equal_approx(aim)
		for k in range(1, dirs.size()):
			var a := dirs[k].angle_to(aim)
			inside = inside and a <= cone + EPS and absf(dirs[k].length() - 1.0) < EPS
			widest = maxf(widest, a)
			angle_sum += a
			n += 1
			quadrants[(1 if dirs[k].dot(right) > 0.0 else 0) + (2 if dirs[k].dot(up) > 0.0 else 0)] += 1
	var mean := angle_sum / n / cone
	print("WEAPON pellets: 2000 shots, widest %.3f deg of %.1f, mean %.3f of the cone (2/3 for an even spread over the disc), quadrants %s" % [rad_to_deg(widest), s.spread_degrees, mean, quadrants])
	_check("SIGTERM fires 9 pellets: the first straight down the aim, the others inside the 6 degree cone, unit length", count_ok and first_ok and inside)
	_check("the pellets spread evenly over the cone: they reach its edge, average two thirds out, and fill all four quarters", widest > cone * 0.98 and mean > 0.62 and mean < 0.71 and quadrants.min() > 0.23 * n and quadrants.max() < 0.27 * n)
	var long_aim := aim * 1.009
	var widest_long := 0.0
	var all_unit := true
	for i in 2000:
		for d in s.pellet_directions(long_aim, rng):
			widest_long = maxf(widest_long, d.angle_to(aim))
			all_unit = all_unit and absf(d.length() - 1.0) < EPS
	_check("an aim 0.9%% too long (within the host's tolerance) narrows nothing: every pellet unit length, the cone still reaching its full 6 degrees and no further (%.3f; a narrowed one stops near 5.947)" % rad_to_deg(widest_long), all_unit and widest_long > cone * 0.997 and widest_long <= cone + EPS)
	var probe := RandomNumberGenerator.new()
	probe.seed = 5
	var before := probe.state
	var single: PackedVector3Array = _cannon.pellet_directions(aim, probe)
	_check("the cannon fires one ray straight down the aim and draws nothing from the generator", single.size() == 1 and single[0].is_equal_approx(aim) and probe.state == before)
	var at := {0.0: 14.0, 4.0: 14.0, 12.0: 9.52, 14.0: 8.4, 24.0: 2.8, 40.0: 2.8}
	var wrong := PackedStringArray()
	for d in at:
		if absf(s.damage_at(d) - at[d]) > 0.001:
			wrong.append("%s m: %.3f" % [d, s.damage_at(d)])
	_check("falloff per pellet: 14 to 4 m, easing to 20% at 24 m (9.52 at 12 m), 2.8 beyond", wrong.is_empty(), ", ".join(wrong))
	var point_blank := 9 * s.damage_at(1.5)
	var mid := 9 * s.damage_at(12.0)
	var long := 9 * s.damage_at(30.0)
	print("WEAPON SIGTERM with every pellet in: %.1f at 1.5 m, %.2f at 12 m, %.1f at 30 m (players have 100)" % [point_blank, mid, long])
	_check("the tuning: point blank one-shots a 100-health player (126), mid range never can (85.7 at most), long range is weak (25.2 at most, four shots even if every pellet lands)", point_blank >= 100.0 and mid < 100.0 and long <= 25.2 + EPS)
	var cone_at := 1.5 * tan(cone)
	_check("at 1.5 m the whole cone (%.2f m across from the aim) fits inside a body (0.4 m radius): every pellet lands" % cone_at, cone_at < 0.4)


# --- Source and controls. ---

func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var player := _code("res://scripts/player.gd")
	_check("an intent carries only the aim: _fire takes the number, life, weapon, origin and direction, nothing about pellets", session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _fire(seq: Variant, life: Variant, weapon: Variant, origin: Variant, dir: Variant) -> void:') and player.contains("fire_intent.emit(origin, forward, _w.id)"))
	_check("a draw and a reload reach the host as untyped, type-checked any_peer intents of a life number and a weapon id, nothing else", session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _draw(life: Variant, weapon: Variant) -> void:') and session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _reload(life: Variant, weapon: Variant) -> void:') and _body(session, "_draw").contains("typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING") and _body(session, "_reload").contains("typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING") and player.contains("weapon_drawn.emit(_w.id)") and player.contains("reload_started.emit(_w.id)"))
	_check("the host's ammo count goes to one player only, as an authority RPC: a life number, the intents handled, the magazines and reserves, the weapon in hand, the reload running and the time left on it and on the draw", session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _ammo(life: int, handled: int, ids: PackedStringArray, mags: PackedInt32Array, reserves: PackedInt32Array, drawn: String, reloading: String, reload_s: float, draw_s: float) -> void:') and _body(session, "_send_ammo").contains('_ammo.rpc_id(id, lives.get(id, 0), _actions_from.get(id, 0), ids, mags, reserves, s.get("drawn", ""), s.get("reloading", ""), combat.reload_left(id, _clock), combat.draw_left(id, _clock))') and _body(session, "_ammo").contains("handled != _sent_actions"))
	_check("the host draws the pellets with its own generator, in _handle_fire only", session.count("pellet_directions(") == 1 and _body(session, "_handle_fire").contains("def.pellet_directions(dir, _pellets_rng)"))
	var all := ""
	for path in WEAPON_SOURCES:
		all += _code(path)
	var found := PackedStringArray()
	for word in SOURCE_NEVER:
		if all.contains(word):
			found.append(word)
	_check("the weapon scripts start nothing, read no file, open no socket and parse no rich text: weapons are fiction", found.is_empty(), ", ".join(found))
	var keys := {}
	for action in ["reload", "reset_arena", "weapon_last", "weapon_1", "weapon_2", "weapon_9"]:
		var codes := []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append(event.physical_keycode)
		keys[action] = codes
	var wheel_next := false
	var wheel_prev := false
	for event in InputMap.action_get_events("weapon_next"):
		wheel_next = wheel_next or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	for event in InputMap.action_get_events("weapon_prev"):
		wheel_prev = wheel_prev or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP)
	var chorded := false
	var ours := ["move_forward", "move_back", "move_left", "move_right", "jump", "slide", "release_mouse", "reset_arena", "ask_ai", "toggle_ai", "toggle_roast", "net_menu", "fire", "weapon_next", "weapon_prev", "weapon_last", "reload"]
	for i in 9:
		ours.append("weapon_%d" % (i + 1))
	for action in ours:
		for event in InputMap.action_get_events(action):
			if event is InputEventWithModifiers and (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
				chorded = true
	_check("controls: E reloads (R stays the arena reset), Q swaps back, 1 to 9 pick slots, the wheel cycles, and no binding needs Ctrl, Alt or Super", keys["reload"] == [KEY_E] and keys["reset_arena"] == [KEY_R] and keys["weapon_last"] == [KEY_Q] and keys["weapon_1"] == [KEY_1] and keys["weapon_2"] == [KEY_2] and keys["weapon_9"] == [KEY_9] and wheel_next and wheel_prev and not chorded, str(keys))


# --- The real arena, solo. ---

func _solo_checks() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	var p = main.get_node("Player")
	p.assume_captured = true
	p.get("_pellet_rng").seed = 21
	var wh: WeaponHud = main.get_node("Hud").weapon_hud()
	for i in 10:
		await physics_frame
	var inv = p.inventory
	_check("the player starts with the cannon drawn and the strip says so", inv.current == 0 and p.weapon_tuning() == _cannon and wh.slots_text() == "[1 cannon]  2 SIGTERM" and wh.ammo_text() == "cannon  inf" and wh.state_text() == WeaponHud.KEYS_LINE, "%s | %s | %s" % [wh.slots_text(), wh.ammo_text(), wh.state_text()])
	await _key(KEY_2)
	_check("key 2 draws SIGTERM: the strip shows it drawn, its 6 and 24, and its fiction line", inv.current == 1 and p.weapon_tuning() == _sigterm and wh.slots_text() == "1 cannon  [2 SIGTERM]" and wh.ammo_text() == "SIGTERM  6 / 24" and wh.state_text() == "SIGTERM: please exit.", "%s | %s | %s" % [wh.slots_text(), wh.ammo_text(), wh.state_text()])
	await _key(KEY_Q)
	var after_q: int = inv.current
	await _key(KEY_Q)
	var after_q2: int = inv.current
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var after_down: int = inv.current
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	var after_up: int = inv.current
	await _key(KEY_7)
	var after_seven: int = inv.current
	_check("Q swaps to the last weapon and back, the wheel cycles both ways and wraps, 7 (no such slot) does nothing", after_q == 0 and after_q2 == 1 and after_down == 0 and after_up == 1 and after_seven == 1, "%d %d %d %d %d" % [after_q, after_q2, after_down, after_up, after_seven])
	# The swap, timed to the frame: fire is held from the draw on, aimed at the open sky so
	# no dummy is spent before the point-blank check.
	await _settle(p, 0.5)
	p.get_node("Head").rotation.x = 1.2
	p.select_slot(0)
	await physics_frame
	p.select_slot(1)
	var swap_frames := _frames_for(0.3)
	var first_shot := await _first_shot_frame(p, swap_frames + 5)
	print("WEAPON swap: %.2f s = %d frames; with fire held from the draw, the first shot went off at frame %d" % [0.3, swap_frames, first_shot])
	_check("no shot while SIGTERM is drawn: with fire held every frame, the first shot goes off one swap time (18 frames) after the draw", first_shot >= swap_frames - 1 and first_shot <= swap_frames + 1, "frame %d" % first_shot)
	# Point blank at a dummy given a player's 100 health: only eight pellets or more (112)
	# can derezz it in one shot, so this proves the pellets' damage, not just one ray's.
	var dummy = main.get_node("Arena/Targets/DummyA")
	dummy.max_health = 100.0
	dummy.reset_for_round()
	await _settle(p, 1.0)
	p.respawn_at(main.to_global(Vector3(0.0, STAND_Y, -13.5)))
	await _frames(3)
	_aim(p, Vector3(dummy.global_position.x, p.get_node("Head/Camera").global_position.y, dummy.global_position.z))
	inv.refill()
	var was_alive: bool = dummy.is_hittable() and dummy.health() == 100.0
	var shots_before: int = p.shots_fired
	var hits_before: int = p.hits_landed
	await _fire(p)
	var beams := _count_fx("CannonBeam")
	await process_frame
	await process_frame
	_check("SIGTERM point blank at a 100-health dummy: one shot, a hit, the dummy derezzes (eight pellets or more landed); nine tracers; the magazine down to 5 and the strip says so", was_alive and p.shots_fired == shots_before + 1 and p.hits_landed == hits_before + 1 and dummy.is_hittable() == false and beams == 9 and inv.mags[1] == 5 and inv.reserves[1] == 24 and wh.ammo_text() == "SIGTERM  5 / 24", "shots +%d hits +%d hittable %s beams %d mag %d strip %s" % [p.shots_fired - shots_before, p.hits_landed - hits_before, dummy.is_hittable(), beams, inv.mags[1], wh.ammo_text()])
	# The same dummy at 12 m and at 30 m, back at 100: what the player's own pellets do there.
	var solo := {}
	for d in [12.0, 30.0]:
		dummy.reset_for_round()
		await _settle(p, 0.95)
		p.respawn_at(main.to_global(Vector3(0.0, STAND_Y, dummy.global_position.z + d)))
		await _frames(3)
		_aim(p, Vector3(dummy.global_position.x, p.get_node("Head/Camera").global_position.y, dummy.global_position.z))
		await _fire(p)
		await _frames(2)
		solo[d] = 100.0 - dummy.health()
	print("WEAPON solo damage on a 100-health dummy: %.2f at 12 m, %.2f at 30 m" % [solo[12.0], solo[30.0]])
	_check("the player's own pellets on a 100-health dummy: at 12 m it takes 9.5 to 85.7 and lives, at 30 m 2.8 to 25.2", solo[12.0] >= 9.5 and solo[12.0] <= 85.7 and solo[30.0] >= 2.8 - 0.01 and solo[30.0] <= 25.2 + 0.01 and dummy.is_hittable(), str(solo))
	dummy.max_health = 1.0
	dummy.reset_for_round()
	p.respawn_at(main.to_global(Vector3(0.0, STAND_Y, -13.5)))
	# Spend the magazine, then E: the reload, timed to the frame.
	while inv.mags[1] > 0:
		await _settle(p, 0.95)
		await _fire(p)
	var emptied: bool = inv.mags[1] == 0 and wh.ammo_text() == "SIGTERM  0 / 24" and wh.state_text() == WeaponHud.EMPTY_LINE
	await _key(KEY_E)
	var started: bool = inv.is_reloading()
	# Fire is held while the reload runs, short of its last frames (a press on the frame
	# the rounds go in fires, as it should), then the frames to the end are counted.
	var reload_frames := _frames_for(2.2)
	var frames := 0
	var blocked := true
	var bar_seen := false
	var left_at_start: float = inv.reload_left
	while inv.is_reloading() and frames < reload_frames + 10:
		var shots_now: int = p.shots_fired
		if frames < reload_frames - 6:
			await _fire(p)
		else:
			await _settle(p, 0.0001)
		blocked = blocked and p.shots_fired == shots_now
		bar_seen = bar_seen or wh.state_text().begins_with("reload [")
		frames += 1
	var whole := frames + roundi((2.2 - left_at_start) * 60.0)
	print("WEAPON reload: %.1f s = %d frames; from E to the rounds in %d frames as seen (a test reads a frame behind), fire held for the first %d" % [2.2, reload_frames, whole, reload_frames - 6])
	_check("six shots empty SIGTERM (the strip says empty); E reloads in 2.2 s with the bar up and no shot while it runs, then 6 and 18", emptied and started and blocked and bar_seen and whole >= reload_frames - 1 and whole <= reload_frames + 2 and inv.mags[1] == 6 and inv.reserves[1] == 18, "frames %d mag %d reserve %d" % [whole, inv.mags[1], inv.reserves[1]])
	# The cannon as it was.
	await _key(KEY_1)
	await _settle(p, 0.5)
	p.respawn_at(main.to_global(Vector3(0.0, STAND_Y, 10.0)))
	p.rotation.y = 0.0
	p.get_node("Head").rotation.x = 0.0
	var cannon_shots := 0
	var one_beam_each := true
	for i in 30:
		await _settle(p, 0.2)
		var before_fire: int = p.shots_fired
		await _fire(p)
		cannon_shots += p.shots_fired - before_fire
		one_beam_each = one_beam_each and _count_fx("CannonBeam") == 1
	_check("the cannon as it was: 30 shots at its interval, one beam each, no reload, the strip still says inf", cannon_shots == 30 and one_beam_each and inv.mags[0] == -1 and wh.ammo_text() == "cannon  inf", "%d shots" % cannon_shots)
	# A death refills; a broken weapon in the loadout is refused.
	await _key(KEY_2)
	await _settle(p, 0.5)
	var had: int = inv.mags[1]
	await _fire(p)
	var spent: int = inv.mags[1]
	p.set_alive(false)
	await process_frame
	await process_frame
	var hidden: bool = not wh.get("_stack").visible
	p.set_alive(true)
	_check("derezzed the strip hides; a new life refills every weapon", spent == had - 1 and hidden and inv.mags[1] == 6 and inv.reserves[1] == 24, "%d -> %d, hidden %s" % [had, spent, hidden])
	var broken: Resource = _sigterm.duplicate()
	broken.spread_degrees = -3.0
	var odd := Arsenal.new()
	var odd_list: Array[Resource] = [_cannon, broken]
	odd.loadout = odd_list
	var extra = load("res://scenes/player.tscn").instantiate()
	extra.arsenal = odd
	extra.position = Vector3(0.0, 40.0, 30.0)
	main.add_child(extra)
	_check("a player given a loadout with a broken SIGTERM holds only the cannon", extra.inventory.slot_count() == 1 and extra.inventory.def().id == "terminal_cannon")
	extra.queue_free()
	var flipped := Arsenal.new()
	var flipped_list: Array[Resource] = [_sigterm, _cannon]
	flipped.loadout = flipped_list
	var other = load("res://scenes/player.tscn").instantiate()
	other.arsenal = flipped
	other.position = Vector3(0.0, 40.0, -30.0)
	main.add_child(other)
	var scene_text := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_check("the shipped player scene pins no weapon, so the arsenal alone decides the loadout: one with SIGTERM first holds SIGTERM in slot 1 and the cannon in slot 2", not scene_text.contains("weapon =") and other.inventory.slot_count() == 2 and other.inventory.defs[0].id == "sigterm" and other.inventory.defs[1].id == "terminal_cannon" and p.weapon == null)
	other.queue_free()
	var twin = load("res://scenes/player.tscn").instantiate()
	twin.weapon = _sigterm
	twin.position = Vector3(0.0, 40.0, -35.0)
	main.add_child(twin)
	_check("a slot 1 override equal to a later slot leaves one copy: SIGTERM put in slot 1 over the shipped arsenal holds one SIGTERM, not two with their own magazines", twin.inventory.slot_count() == 1 and twin.inventory.defs[0].id == "sigterm", str(twin.inventory.defs.map(func(d): return d.id)))
	twin.queue_free()
	await physics_frame
	# R in solo play: a fresh arena, a fresh inventory.
	main.free()
	await process_frame
	var main2 = MainScene.instantiate()
	root.add_child(main2)
	current_scene = main2
	await _frames(3)
	var fresh = main2.get_node("Player").inventory
	_check("solo, a fresh arena (what R does) comes with a fresh inventory: the cannon drawn, SIGTERM full", fresh.current == 0 and fresh.mags[1] == 6 and fresh.reserves[1] == 24)
	main2.free()
	await process_frame


# --- A match. ---

func _match_checks() -> void:
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp = host["player"]
	var cid: int = cs.my_id
	hs.get("_pellets_rng").seed = 11
	_check("joined, both sides at full health, the host counting the joiner with the cannon in hand", joined and hs.health[1] == 100.0 and cs.health[1] == 100.0 and hs.combat.drawn_by(cid) == "terminal_cannon")
	# The joiner stands at the west end of the clear line; the host 1.5 m east of it.
	client["player"].respawn_at(client["main"].to_global(Vector3(SHOOTER_X, STAND_Y, LINE_Z)))
	hp.respawn_at(host["main"].to_global(Vector3(SHOOTER_X + 1.5, STAND_Y, LINE_Z)))
	var expected_eye := Vector3(SHOOTER_X, STAND_Y + hp.eye_height(), LINE_Z)
	var synced := await _until(func(): return hs._eye_of(cid).distance_to(expected_eye) < 0.05)
	var eye: Vector3 = hs._eye_of(cid)
	_check("the host sees the joiner at the west end of the line", synced, str(eye))
	# Forgeries first: an unknown weapon, a weapon id that is not text, SIGTERM never drawn.
	var dropped := await _intent(hs, cs, cid, "rm_rf", eye, Vector3(1, 0, 0))
	var weapon_drop: bool = dropped and hs.combat.drops.get("weapon", 0) == 1 and hs.health[1] == 100.0
	var before: int = hs.combat.dropped
	_send(cs, "_fire", [hs.combat.states[cid]["last_seq"] + 1, cs.lives.get(cid, 0), 7, eye, Vector3(1, 0, 0)])
	_send(cs, "_draw", ["junk", "sigterm"])
	_send(cs, "_reload", [cs.lives.get(cid, 0), 9])
	var typed := await _until(func(): return hs.combat.dropped >= before + 3, 2000)
	var to_host := (Vector3(SHOOTER_X + 1.5, BODY_Y, LINE_Z) - eye).normalized()
	var undrawn := await _intent(hs, cs, cid, "sigterm", eye, to_host)
	_check("over 127.0.0.1: a weapon the joiner does not carry, and SIGTERM it never drew, are dropped as not in hand; a fire, draw or reload with a weapon or life that is not the right type is dropped as malformed; nothing applied", weapon_drop and typed and undrawn and hs.combat.drops.get("weapon", 0) == 2 and hs.combat.drops.get("no_player", 0) == 3 and hs.health[1] == 100.0 and hs.combat.drawn_by(cid) == "terminal_cannon", str(hs.combat.drops))
	# The draw: SIGTERM is in hand from the draw, ready after the swap time.
	_send(cs, "_draw", [cs.lives.get(cid, 0), "sigterm"])
	var too_soon := await _intent(hs, cs, cid, "sigterm", eye, to_host)
	_check("over 127.0.0.1: SIGTERM fired straight after its draw is dropped as still being drawn", too_soon and hs.combat.drawn_by(cid) == "sigterm" and hs.combat.drops.get("swap", 0) == 1 and hs.health[1] == 100.0, str(hs.combat.drops))
	await _frames(_frames_for(0.35))
	# Point blank: one SIGTERM shot derezzes the host, and the feed names SIGTERM.
	var believed := await _intent(hs, cs, cid, "sigterm", eye, to_host, false)
	await _until(func(): return cs.dead.get(1, false), 2000)
	await _frames(2)
	var hhud: CombatHud = host["combat_hud"]
	var chud: CombatHud = client["combat_hud"]
	print("WEAPON point blank: host health %.1f, dead %s/%s, feed host %s joiner %s" % [hs.health[1], hs.dead[1], cs.dead[1], hhud.feed_text(), chud.feed_text()])
	_check("SIGTERM point blank over the wire: the host's own nine pellets take all 100 health in one shot, dead on both sides", believed and hs.dead[1] and cs.dead[1] and hs.health[1] == 0.0 and cs.health[1] == 0.0 and hs.combat.ammo_of(cid, "sigterm") == [5, 24])
	_check("the kill feed names the weapon on both sides: SIGTERM sent by Daemon-2 to Daemon-1", hhud.feed_text() == PackedStringArray(["SIGTERM sent by Daemon-2 to Daemon-1"]) and chud.feed_text() == PackedStringArray(["SIGTERM sent by Daemon-2 to Daemon-1"]), "%s | %s" % [hhud.feed_text(), chud.feed_text()])
	# Mid range: 12 m.
	await _back_at(hs, hp, host, SHOOTER_X + 12.0)
	var mid_hits := PackedFloat32Array()
	var to_mid := (Vector3(SHOOTER_X + 12.0, BODY_Y, LINE_Z) - eye).normalized()
	await _settle_net(hs, cid, "sigterm")
	var health_was: float = hs.health[1]
	await _intent(hs, cs, cid, "sigterm", eye, to_mid, false)
	await _frames(2)
	mid_hits.append(health_was - hs.health[1])
	var fast := await _intent(hs, cs, cid, "sigterm", eye, to_mid)
	_send(cs, "_draw", [cs.lives.get(cid, 0), "terminal_cannon"])
	var switch := await _intent(hs, cs, cid, "terminal_cannon", eye, to_mid)
	_check("over 127.0.0.1: SIGTERM again before its pump has cycled is dropped as too fast; the cannon fired straight after drawing it is dropped as still being drawn", fast and switch and hs.combat.drops.get("rate", 0) == 1 and hs.combat.drops.get("swap", 0) == 2, str(hs.combat.drops))
	_send(cs, "_draw", [cs.lives.get(cid, 0), "sigterm"])
	await _frames(_frames_for(0.35))
	var shots_to_kill := 1
	while not hs.dead.get(1, false) and shots_to_kill < 14:
		await _net_round(hs, cs, cid)
		await _settle_net(hs, cid, "sigterm")
		health_was = hs.health[1]
		await _intent(hs, cs, cid, "sigterm", eye, to_mid, false)
		await _frames(2)
		mid_hits.append(health_was - hs.health[1])
		shots_to_kill += 1
	print("WEAPON mid range (12 m): damage per shot %s, %d shots to derezz" % [mid_hits, shots_to_kill])
	_check("mid range (12 m): every shot hurts (the straight pellet at least, 9.5) but none can kill alone (85.7 at most); it takes several", mid_hits[0] >= 9.5 and mid_hits[0] <= 85.7 and hs.dead.get(1, false) and shots_to_kill >= 2 and Array(mid_hits.slice(0, mid_hits.size() - 1)).all(func(x): return x >= 9.5 and x <= 85.7), str(mid_hits))
	# Long range: 30 m, the far end of the line, after a reload the host is told of.
	await _back_at(hs, hp, host, SHOOTER_X + 30.0)
	await _net_reload(hs, cs, cid)
	var to_far := (Vector3(SHOOTER_X + 30.0, BODY_Y, LINE_Z) - eye).normalized()
	var far_hits := PackedFloat32Array()
	for i in 3:
		await _settle_net(hs, cid, "sigterm")
		health_was = hs.health[1]
		await _intent(hs, cs, cid, "sigterm", eye, to_far, false)
		await _frames(2)
		far_hits.append(health_was - hs.health[1])
	print("WEAPON long range (30 m): damage per shot %s" % far_hits)
	_check("long range (30 m) is weak: every shot lands the straight pellet (2.8) and none does more than 25.2", far_hits.size() == 3 and Array(far_hits).all(func(x): return x >= 2.8 - 0.01 and x <= 25.2 + 0.01) and not hs.dead.get(1, false), str(far_hits))
	# An empty magazine over the wire, a reload the host is told of, and no reload behind
	# its back.
	var up := Vector3(0, 1, 0)
	var spent := 0
	while hs.combat.ammo_of(cid, "sigterm")[0] > 0 and spent < 8:
		await _settle_net(hs, cid, "sigterm")
		await _intent(hs, cs, cid, "sigterm", eye, up, false)
		spent += 1
	await _settle_net(hs, cid, "sigterm")
	var empty := await _intent(hs, cs, cid, "sigterm", eye, up)
	var reserve_was: int = hs.combat.ammo_of(cid, "sigterm")[1]
	_send(cs, "_reload", [cs.lives.get(cid, 0), "sigterm"])
	await _frames(_frames_for(1.0))
	var mid_reload := await _intent(hs, cs, cid, "sigterm", eye, up)
	await _frames(_frames_for(1.3))
	var after_reload := await _intent(hs, cs, cid, "sigterm", eye, up, false)
	_check("over 127.0.0.1: SIGTERM fired dry is dropped as an empty magazine; after the joiner's reload starts a shot 1 s in is dropped as mid-reload; once the reload's time is up the shot is believed with the rounds counted from the reserve", empty and mid_reload and after_reload and hs.combat.drops.get("empty", 0) == 1 and hs.combat.drops.get("reload", 0) == 1 and hs.combat.ammo_of(cid, "sigterm") == [5, reserve_was - 6], "%s %s" % [hs.combat.drops, hs.combat.ammo_of(cid, "sigterm")])
	while hs.combat.ammo_of(cid, "sigterm")[0] > 0 and spent < 16:
		await _settle_net(hs, cid, "sigterm")
		await _intent(hs, cs, cid, "sigterm", eye, up, false)
		spent += 1
	_send(cs, "_draw", [cs.lives.get(cid, 0), "terminal_cannon"])
	await _frames(_frames_for(0.35))
	for i in 15:
		await _intent(hs, cs, cid, "terminal_cannon", eye, up, false)
		await _frames(_frames_for(0.17))
	_send(cs, "_draw", [cs.lives.get(cid, 0), "sigterm"])
	await _frames(_frames_for(0.35))
	var no_background := await _intent(hs, cs, cid, "sigterm", eye, up)
	_check("over 127.0.0.1: no reload behind the host's back: SIGTERM emptied, the cannon fired for 2.5 s, SIGTERM drawn again and fired is still empty", no_background and hs.combat.drops.get("empty", 0) == 2, str(hs.combat.drops))
	# A late draw and the reload pressed after waiting it out, arriving in one poll: the
	# reload is taken and the rounds come when it is done, as on the joiner's screen.
	_send(cs, "_draw", [cs.lives.get(cid, 0), "terminal_cannon"])
	await _frames(_frames_for(0.35))
	var reload_drops: int = hs.combat.drops.get("reload", 0)
	_send(cs, "_draw", [cs.lives.get(cid, 0), "sigterm"])
	_send(cs, "_reload", [cs.lives.get(cid, 0), "sigterm"])
	await _frames(_frames_for(0.3 + 2.2 + 0.05))
	var bunched := await _intent(hs, cs, cid, "sigterm", eye, up, false)
	_check("over 127.0.0.1: a draw and a reload arriving together (the draw late on the wire) still reload: the next shot is believed from a full magazine", bunched and hs.combat.drops.get("reload", 0) == reload_drops and hs.combat.ammo_of(cid, "sigterm")[0] == 5, "%s %s" % [hs.combat.drops, hs.combat.ammo_of(cid, "sigterm")])
	# A reload's message so late it arrives with the draw after it: the host stops the reload
	# it just started, and its ammo reply puts the joiner's count back to the host's (its own
	# game had finished the reload: 6 and 6), so no honest shot is refused later for it.
	var ccp = client["player"]
	var sig_slot: int = ccp.inventory.slot_of("sigterm")
	hs.combat.states[cid]["ammo"]["sigterm"] = {"mag": 0, "reserve": 12, "last_fire": -INF}
	ccp.inventory.mags[sig_slot] = 6
	ccp.inventory.reserves[sig_slot] = 6
	_send(cs, "_reload", [cs.lives.get(cid, 0), "sigterm"])
	_send(cs, "_draw", [cs.lives.get(cid, 0), "terminal_cannon"])
	var told := await _until(func(): return ccp.inventory.mags[sig_slot] == 0, 2000)
	_check("over 127.0.0.1: a reload arriving with the draw after it is stopped on the host, and the joiner takes the host's count (0 and 12, not 6 and 6)", told and hs.combat.ammo_of(cid, "sigterm") == [0, 12] and hs.combat.states[cid]["reloading"] == "" and ccp.inventory.reserves[sig_slot] == 12, "host %s joiner %d/%d" % [hs.combat.ammo_of(cid, "sigterm"), ccp.inventory.mags[sig_slot], ccp.inventory.reserves[sig_slot]])
	# Then the joiner's own game, as a player plays it: draw SIGTERM, reload, fire. Both sides
	# count the same afterwards.
	await _frames(_frames_for(0.35))
	ccp.get_node("Head").rotation.x = 1.2
	ccp.select_slot(sig_slot)
	await _settle(ccp, 0.4)
	var reloading_now: bool = ccp.reload_weapon()
	await _settle(ccp, 0.3)
	var during: int = ccp.inventory.mags[sig_slot]
	await _settle(ccp, 2.0)
	cs.fire_seq = hs.combat.states[cid]["last_seq"]
	var seq_was: int = cs.fire_seq
	await _fire(ccp)
	var counted := await _until(func(): return hs.combat.states[cid]["last_seq"] == seq_was + 1, 2000)
	await _frames(3)
	_check("then the joiner's own draw, reload and shot leave both sides counting the same (5 and 6), neither reloading; while the reload ran the strip kept the magazine it had (0)", reloading_now and during == 0 and counted and hs.combat.ammo_of(cid, "sigterm") == [5, 6] and ccp.inventory.mags[sig_slot] == 5 and ccp.inventory.reserves[sig_slot] == 6 and not ccp.inventory.is_reloading() and hs.combat.states[cid]["reloading"] == "", "host %s joiner %d/%d" % [hs.combat.ammo_of(cid, "sigterm"), ccp.inventory.mags[sig_slot], ccp.inventory.reserves[sig_slot]])
	# A reload the host refuses (it counts the magazine full): the joiner takes the host's
	# count, and its own reload, ending, finds nothing to move.
	hs.combat.states[cid]["ammo"]["sigterm"] = {"mag": 6, "reserve": 6, "last_fire": -INF}
	ccp.inventory.mags[sig_slot] = 2
	ccp.inventory.reload_left = 1.0
	var refused_before: int = hs.combat.drops.get("reload", 0)
	_send(cs, "_reload", [cs.lives.get(cid, 0), "sigterm"])
	var taken := await _until(func(): return ccp.inventory.mags[sig_slot] == 6, 2000)
	await _settle(ccp, 1.2)
	_check("over 127.0.0.1: a reload the host refuses (its magazine full) is answered with the host's count: the joiner shows 6 and 6, and its own reload ends moving nothing", taken and hs.combat.drops.get("reload", 0) == refused_before + 1 and ccp.inventory.mags[sig_slot] == 6 and ccp.inventory.reserves[sig_slot] == 6 and not ccp.inventory.is_reloading(), "joiner %d/%d reloading %s" % [ccp.inventory.mags[sig_slot], ccp.inventory.reserves[sig_slot], ccp.inventory.is_reloading()])
	# A reload whose message reaches the host 0.8 s late: the host's reply says how long its
	# reload has to go, the joiner's own lasts at least that long, and its first shot after
	# it, fire held every frame, is believed.
	hs.combat.states[cid]["ammo"]["sigterm"] = {"mag": 0, "reserve": 18, "last_fire": -INF}
	hs.combat.states[cid]["reloading"] = ""
	ccp.inventory.mags[sig_slot] = 0
	ccp.inventory.reserves[sig_slot] = 18
	var started_here: bool = ccp.inventory.reload()  # this side's reload, its message held back
	await _settle(ccp, 0.8)
	var left_before: float = ccp.inventory.reload_left
	cs._on_reload_started("sigterm")
	var stretched := await _until(func(): return ccp.inventory.reload_left > left_before + 0.1, 500)
	var left_after: float = ccp.inventory.reload_left
	cs.fire_seq = hs.combat.states[cid]["last_seq"]
	var seq_late: int = cs.fire_seq
	var reload_drops_late: int = hs.combat.drops.get("reload", 0)
	var shot_frame := await _first_shot_frame(ccp, 200)
	var believed_late := await _until(func(): return hs.combat.states[cid]["last_seq"] == seq_late + 1, 2000)
	print("WEAPON late reload message: this side had %.2f s to go, then %.2f s after the host's reply; first shot after %d frames" % [left_before, left_after, shot_frame])
	_check("a reload whose message reaches the host 0.8 s late: the joiner's reload is stretched to the host's, and its first shot after it (fire held every frame) is believed, none dropped as mid-reload", started_here and stretched and shot_frame > 0 and believed_late and hs.combat.drops.get("reload", 0) == reload_drops_late and hs.combat.ammo_of(cid, "sigterm") == [5, 12], "shot frame %d believed %s drops %s host %s" % [shot_frame, believed_late, hs.combat.drops, hs.combat.ammo_of(cid, "sigterm")])
	# A reply that left the host while its reload ran, arriving after this side's reload has
	# finished: taken as that reload leaves it, so it undoes nothing.
	ccp.inventory.mags[sig_slot] = 6
	ccp.inventory.reserves[sig_slot] = 12
	ccp.inventory.reload_left = 0.0
	cs._ammo(cs.lives.get(cid, 0), cs.get("_sent_actions"), PackedStringArray(["sigterm"]), PackedInt32Array([0]), PackedInt32Array([18]), "sigterm", "sigterm", 1.0, 0.0)
	_check("a reply sent while the host's reload ran, arriving after this side's reload finished, is taken as that reload leaves it: 6 and 12 stay, not 0 and 18", ccp.inventory.mags[sig_slot] == 6 and ccp.inventory.reserves[sig_slot] == 12 and not ccp.inventory.is_reloading(), "%d/%d" % [ccp.inventory.mags[sig_slot], ccp.inventory.reserves[sig_slot]])
	# A stale reply is not taken: one that answers fewer intents than the joiner has sent.
	var stale_mag: int = ccp.inventory.mags[sig_slot]
	cs._ammo(cs.lives.get(cid, 0), cs.get("_sent_actions") - 1, PackedStringArray(["sigterm"]), PackedInt32Array([0]), PackedInt32Array([0]), "sigterm", "", 0.0, 0.0)
	_check("an ammo reply that has not caught up with every intent the joiner sent is stale and not taken", ccp.inventory.mags[sig_slot] == stale_mag and stale_mag == 6)
	# A reply that comes while R has the arena away is kept and taken by the next arena, after
	# it takes over the old player's weapons.
	hs.combat.states[cid]["ammo"]["sigterm"] = {"mag": 0, "reserve": 12, "last_fire": -INF}
	hs.combat.states[cid]["reloading"] = ""
	ccp.inventory.mags[sig_slot] = 6
	ccp.inventory.reserves[sig_slot] = 6
	cs._on_reload_started("sigterm")
	cs._on_weapon_drawn("terminal_cannon")
	var handled_was: int = hs.get("_actions_from").get(cid, 0)
	client["main"].free()
	await _until(func(): return hs.get("_actions_from").get(cid, 0) == handled_was + 2, 2000)
	await _frames(3)
	var pending_kept: bool = not cs.get("_ammo_pending").is_empty()
	var main_back = MainScene.instantiate()
	client["branch"].add_child(main_back)
	client["main"] = main_back
	ccp = main_back.get_node("Player")
	ccp.assume_captured = true
	client["player"] = ccp
	await _frames(3)
	_check("an ammo reply that comes while R has the arena away is kept and taken by the next arena's player: 0 and 12, not the old player's 6 and 6", pending_kept and ccp.inventory.mags[sig_slot] == 0 and ccp.inventory.reserves[sig_slot] == 12 and cs.get("_ammo_pending").is_empty(), "kept %s joiner %d/%d" % [pending_kept, ccp.inventory.mags[sig_slot], ccp.inventory.reserves[sig_slot]])
	# The host's own SIGTERM: the joiner draws every pellet the host drew.
	await _settle(hp, 1.0)
	hp.select_slot(1)
	await _settle(hp, 0.5)
	hp.rotation.y = PI * 0.5
	hp.get_node("Head").rotation.x = 0.0
	var seen := [0]
	var hook := func(shooter: int, _h: int, _o: Vector3, _e: Vector3) -> void:
		if shooter == 1:
			seen[0] += 1
	cs.shot_confirmed.connect(hook)
	await _fire(hp)
	await _until(func(): return seen[0] >= 1, 2000)
	var remote_beams := _count_fx_under(client["main"], "CannonBeam")
	cs.shot_confirmed.disconnect(hook)
	_check("the host's own draw and SIGTERM go through the same path: SIGTERM in hand on the host's count, and the joiner draws all nine of the host's pellets", seen[0] == 1 and remote_beams == 9 and hs.combat.drawn_by(1) == "sigterm" and hs.combat.ammo_of(1, "sigterm") == [5, 24], "beams %d" % remote_beams)
	await _drop(client)
	await _drop(host)


## A fresh match with real players only: practice ammo does not carry in, real shots are
## believed and counted the same on both sides, an R reload keeps the weapons, and a respawn
## that lands while the arena is away still refills.
func _fresh_match_checks() -> void:
	var host := _branch("Host2", Vector3.ZERO)
	var client := _branch("Client2", CLIENT_OFFSET)
	await _frames(2)
	var cp = client["player"]
	cp.select_slot(1)
	await _settle(cp, 0.5)
	cp.get_node("Head").rotation.x = 1.2
	await _fire(cp)
	await _settle(cp, 0.95)
	await _fire(cp)
	var practiced: int = cp.inventory.mags[1]
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp = host["player"]
	var cid: int = cs.my_id
	await _frames(2)
	_check("a match starts fresh on both sides: practice shots before joining (SIGTERM at %d) do not carry in; the cannon drawn, everything full, as the host counts" % practiced, joined and practiced == 4 and cp.inventory.current == 0 and cp.inventory.mags[1] == 6 and cp.inventory.reserves[1] == 24 and hs.combat.drawn_by(cid) == "terminal_cannon" and hs.combat.ammo_of(cid, "sigterm") == [6, 24])
	# A draw the host took in before this side heard it holds the player (sent in the moment
	# between joining and the first roster): the first roster's draw of slot 1 undoes it, and
	# this side waits out that draw too, so a shot fired as soon as the game allows is believed.
	hs.combat.draw(cid, 0, "sigterm", 0, hs.get("_clock"))
	cs.set("_weapons_synced", false)
	cs.fire_seq = hs.combat.states[cid]["last_seq"]
	cp.get_node("Head").rotation.x = 1.2
	var dropped_at_sync: int = hs.combat.dropped
	hs._send_roster()
	var synced_now := await _until(func(): return cs.get("_weapons_synced") and cp.inventory.is_swapping(), 2000)
	var first := await _first_shot_frame(cp, 40)
	var believed_first := await _until(func(): return hs.combat.states[cid]["last_seq"] == cs.fire_seq, 2000)
	_check("a draw the host took before this side's first roster is undone by the draw of slot 1 that roster sends; this side waits out the same draw, and its first shot, as soon as the game allows (frame %d), is believed" % first, synced_now and hs.combat.drawn_by(cid) == "terminal_cannon" and cp.inventory.current == 0 and first >= _frames_for(0.3) - 1 and believed_first and hs.combat.dropped == dropped_at_sync, "synced %s frame %d believed %s drops %s" % [synced_now, first, believed_first, hs.combat.drops])
	# The first roster coming while R has the arena away: the fresh start waits for the next
	# arena, even though that arena takes over the old player's (practice) weapons first.
	cp.inventory.select(1)
	cp.inventory.mags[1] = 2
	cs.set("_weapons_synced", false)
	cs.set("_roster_seen", false)
	client["main"].free()
	await _frames(2)
	hs._send_roster()
	await _until(func(): return cs.get("_roster_seen"), 2000)
	var waited: bool = not cs.get("_weapons_synced")
	var main_r = MainScene.instantiate()
	client["branch"].add_child(main_r)
	client["main"] = main_r
	cp = main_r.get_node("Player")
	cp.assume_captured = true
	client["player"] = cp
	await _frames(3)
	cs.fire_seq = hs.combat.states[cid]["last_seq"]
	cp.get_node("Head").rotation.x = 1.2
	var first_r := await _first_shot_frame(cp, 40)
	var believed_r := await _until(func(): return hs.combat.states[cid]["last_seq"] == cs.fire_seq, 2000)
	_check("a first roster that comes while the arena is away waits: the next arena's player starts fresh (the cannon, SIGTERM full) instead of the old SIGTERM at 2, and its first shot is believed", waited and cs.get("_weapons_synced") and cp.inventory.current == 0 and cp.inventory.mags[1] == 6 and hs.combat.drawn_by(cid) == "terminal_cannon" and first_r > 0 and believed_r and hs.combat.dropped == dropped_at_sync, "waited %s current %d mags %s believed %s" % [waited, cp.inventory.current, cp.inventory.mags, believed_r])
	# Before its fresh start a joiner sends nothing: a SIGTERM shot then stays on its own
	# screen, and the fresh start leaves both sides counting the same full magazine.
	cs.set("_weapons_synced", false)
	cp.inventory.hold(1)
	cp.call("_show_weapon")
	var seq_quiet: int = hs.combat.states[cid]["last_seq"]
	var fired_quiet: int = cs.fire_seq
	await _settle(cp, 0.2)
	await _fire(cp)
	await _frames(5)
	var quiet: bool = hs.combat.states[cid]["last_seq"] == seq_quiet and cs.fire_seq == fired_quiet and cp.inventory.mags[1] == 5
	hs._send_roster()
	await _until(func(): return cs.get("_weapons_synced"), 2000)
	_check("before its fresh start the joiner sends no shot (SIGTERM fired on its own screen, 5 left there, nothing counted by the host); the fresh start leaves both at 6 and 24 with the cannon", quiet and cp.inventory.current == 0 and cp.inventory.mags[1] == 6 and hs.combat.ammo_of(cid, "sigterm") == [6, 24] and hs.combat.drawn_by(cid) == "terminal_cannon", "quiet %s mags %s host %s" % [quiet, cp.inventory.mags, hs.combat.ammo_of(cid, "sigterm")])
	await _frames(_frames_for(0.35))
	cp.select_slot(1)
	await _settle(cp, 0.5)
	cp.get_node("Head").rotation.x = 1.2
	var seq_before: int = hs.combat.states[cid]["last_seq"]
	await _fire(cp)
	await _settle(cp, 0.95)
	await _fire(cp)
	await _until(func(): return hs.combat.states[cid]["last_seq"] == seq_before + 2, 2000)
	_check("real shots from the joiner's SIGTERM are believed, and the host counts the same magazine as the joiner (4 and 24)", hs.combat.states[cid]["last_seq"] == seq_before + 2 and hs.combat.drawn_by(cid) == "sigterm" and hs.combat.ammo_of(cid, "sigterm") == [4, 24] and cp.inventory.mags[1] == 4 and hs.combat.dropped == 0, "%s %s drops %s" % [hs.combat.ammo_of(cid, "sigterm"), cp.inventory.mags[1], hs.combat.drops])
	# R mid-match: the new arena's player takes over the weapons and ammo.
	client["main"].free()
	await _frames(3)
	var main2 = MainScene.instantiate()
	client["branch"].add_child(main2)
	client["main"] = main2
	cp = main2.get_node("Player")
	cp.assume_captured = true
	client["player"] = cp
	await _frames(3)
	var kept_ok: bool = cp.inventory.current == 1 and cp.inventory.mags[1] == 4 and cp.inventory.reserves[1] == 24 and main2.get_node("Hud").weapon_hud().ammo_text() == "SIGTERM  4 / 24"
	cp.get_node("Head").rotation.x = 1.2
	await _settle(cp, 0.95)
	await _fire(cp)
	await _until(func(): return hs.combat.states[cid]["last_seq"] == seq_before + 3, 2000)
	_check("an R reload mid-match keeps SIGTERM drawn at 4 and 24, and the next real shot is believed: 3 on both sides", kept_ok and hs.combat.states[cid]["last_seq"] == seq_before + 3 and hs.combat.ammo_of(cid, "sigterm") == [3, 24] and cp.inventory.mags[1] == 3 and hs.combat.dropped == 0, "%s %s" % [hs.combat.ammo_of(cid, "sigterm"), cp.inventory.mags[1]])
	# The host derezzes the joiner point blank, and the joiner's arena is away for the respawn.
	cp.respawn_at(main2.to_global(Vector3(SHOOTER_X, STAND_Y, LINE_Z)))
	hp.respawn_at(host["main"].to_global(Vector3(SHOOTER_X + 1.5, STAND_Y, LINE_Z)))
	await _until(func(): return hs._eye_of(cid).distance_to(Vector3(SHOOTER_X, STAND_Y + hp.eye_height(), LINE_Z)) < 0.05)
	hp.select_slot(1)
	await _settle(hp, 0.5)
	var avatar = hs.avatars.get(cid)
	_aim(hp, avatar.global_position)
	await _fire(hp)
	var killed := await _until(func(): return cs.dead.get(cid, false), 2000)
	main2.free()
	await _until(func(): return not cs.dead.get(cid, true), 4000)
	await _frames(2)
	var main3 = MainScene.instantiate()
	client["branch"].add_child(main3)
	client["main"] = main3
	await _frames(3)
	var back = main3.get_node("Player")
	back.assume_captured = true
	_check("a respawn that lands while the joiner's arena is away still refills: the next arena's player is alive with SIGTERM drawn and full, as the host counts", killed and back.alive and back.inventory.current == 1 and back.inventory.mags[1] == 6 and back.inventory.reserves[1] == 24 and hs.combat.ammo_of(cid, "sigterm") == [6, 24], "killed %s alive %s mags %s" % [killed, back.alive, back.inventory.mags])
	# A draw that crosses the joiner's death: the host refuses it (dead), the joiner's own
	# screen took it; the respawn hands back the weapon the host counts in hand.
	await _until(func(): return hs.protect_left.get(cid, 0.0) <= 0.0 and hs.protect_left.get(1, 0.0) <= 0.0, 4000)
	back.respawn_at(main3.to_global(Vector3(SHOOTER_X, STAND_Y, LINE_Z)))
	hp.respawn_at(host["main"].to_global(Vector3(SHOOTER_X + 1.5, STAND_Y, LINE_Z)))
	await _until(func(): return hs._eye_of(cid).distance_to(Vector3(SHOOTER_X, STAND_Y + hp.eye_height(), LINE_Z)) < 0.05)
	await _settle(hp, 1.0)
	_aim(hp, hs.avatars.get(cid).global_position)
	await _fire(hp)
	var killed_again := await _until(func(): return hs.dead.get(cid, false), 2000)
	var dead_before: int = hs.combat.drops.get("dead", 0)
	back.inventory.select(0)  # this side drew the cannon a moment before it heard of its death
	back.call("_show_weapon")
	_send(cs, "_draw", [cs.lives.get(cid, 0), "terminal_cannon"])
	var refused := await _until(func(): return hs.combat.drops.get("dead", 0) > dead_before, 2000)
	await _until(func(): return not cs.dead.get(cid, true), 4000)
	await _frames(3)
	var after_held: int = back.inventory.current
	back.get_node("Head").rotation.x = 1.2
	var seq_now: int = hs.combat.states[cid]["last_seq"]
	cs.fire_seq = seq_now
	await _fire(back)
	var believed_after := await _until(func(): return hs.combat.states[cid]["last_seq"] == seq_now + 1, 2000)
	_check("a draw that crossed the joiner's death (refused by the host as dead) is reconciled at the respawn: the joiner holds SIGTERM again, as the host counts, and its next shot is believed", killed_again and refused and after_held == 1 and hs.combat.drawn_by(cid) == "sigterm" and believed_after and back.weapon_tuning().id == "sigterm", "killed %s refused %s held %d believed %s" % [killed_again, refused, after_held, believed_after])
	await _drop(client)
	await _drop(host)


# --- Layout. ---

func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO)
		await _frames(2)
		host["session"].host(0)
		var p = host["player"]
		p.select_slot(1)
		await _settle(p, 0.5)
		await _fire(p)
		p.reload_weapon()
		await _frames(30)
		var hud: CombatHud = host["combat_hud"]
		host["session"].players[7] = {"slot": 2, "name": "Daemon-2"}
		for i in 4:
			hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "SIGTERM", "left": 2.0})
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		host["hud"].net_hud().toggle()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panels := [host["hud"].net_hud().get("_panel"), host["hud"].guide().get("_panel")]
		var strip: Control = host["hud"].weapon_hud().get("_stack")
		var feed: Control = hud.get("_feed")
		var wrong := PackedStringArray()
		var shown := 0
		var strip_labels := 0
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			shown += 1
			var rect: Rect2 = label.get_global_rect()
			if strip.is_ancestor_of(label):
				strip_labels += 1
				if feed.get_global_rect().intersects(rect):
					wrong.append("strip under the feed: %s" % label.text)
			if not screen.encloses(rect):
				wrong.append("outside: %s %s" % [label.text.left(20), rect])
			if rect.size.x >= screen.size.x:
				continue
			for panel in panels:
				if not panel.is_ancestor_of(label) and panel.get_global_rect().intersects(rect):
					wrong.append("under a panel: %s %s" % [label.text.left(20), rect])
			if not strip.is_ancestor_of(label) and label.get_parent() is Control and label.get_parent().name == "Root" and label.text.begins_with("WASD") and strip.get_global_rect().intersects(rect):
				wrong.append("the hint under the strip")
		var state: String = host["hud"].weapon_hud().state_text()
		_check("at %dx%d the weapon strip (reloading), four SIGTERM kills in the feed, the net panel and a long guide notice all sit inside the screen and nothing covers anything" % [size.x, size.y], strip_labels == 3 and state.begins_with("reload [") and wrong.is_empty() and hud.feed_text().size() == 4 and hud.feed_text()[0] == "SIGTERM sent by Daemon-2 to Daemon-1", "%d shown, state %s; %s" % [shown, state, ", ".join(wrong)])
		await _drop(host)
	root.size = before


# --- Harness. ---

func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 4000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.5
	t.kill_feed_fade_s = 30.0
	return t


func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	session.combat_tuning = _combat_tuning()
	branch.add_child(session)
	_branches.append(branch)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": main.get_node("Hud"), "combat_hud": main.get_node("Hud").combat_hud()}
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
	return out


func _drop(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	await process_frame


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


## A forged intent from the joiner's side, counted as the joiner's game counts what it sends,
## so the host's ammo replies line up with it as with a real game.
func _send(cs: Session, method: String, args: Array) -> void:
	cs.set("_sent_actions", cs.get("_sent_actions") + 1)
	cs.callv("rpc_id", [1, method] + args)


## A forged intent from the joiner, numbered after the last one the host believed. With
## `expect_drop` true: true once the host counted it as dropped; false: true once believed.
func _intent(hs: Session, cs: Session, cid: int, weapon: String, origin: Vector3, dir: Vector3, expect_drop: bool = true) -> bool:
	var seq: int = hs.combat.states[cid]["last_seq"] + 1
	var dropped_before: int = hs.combat.dropped
	_send(cs, "_fire", [seq, cs.lives.get(cid, 0), weapon, origin, dir])
	if expect_drop:
		return await _until(func(): return hs.combat.dropped > dropped_before, 2000) and hs.combat.states[cid]["last_seq"] == seq - 1
	return await _until(func(): return hs.combat.states[cid]["last_seq"] == seq, 2000) and hs.combat.dropped == dropped_before


## Waits until SIGTERM's pump has cycled for the host's count of the joiner (0.95 s since
## its last believed shot), never long enough to earn a reload.
func _settle_net(hs: Session, cid: int, weapon: String) -> void:
	var last: float = hs.combat.states[cid]["ammo"][weapon]["last_fire"]
	var left: float = 0.95 - (hs.get("_clock") - last)
	if left > 0.0:
		await _frames(ceili(left * 60.0))


## The joiner reloads SIGTERM as the host is told (a forged reload message, the joiner's
## own life), when it has room and rounds, and the reload's time is waited out.
func _net_reload(hs: Session, cs: Session, cid: int) -> void:
	var ammo: Array = hs.combat.ammo_of(cid, "sigterm")
	if ammo[0] >= 6 or ammo[1] == 0:
		return
	_send(cs, "_reload", [cs.lives.get(cid, 0), "sigterm"])
	await _frames(_frames_for(2.3))


## A reload first when the host counts SIGTERM's magazine empty.
func _net_round(hs: Session, cs: Session, cid: int) -> void:
	if hs.combat.ammo_of(cid, "sigterm")[0] <= 0:
		await _net_reload(hs, cs, cid)


## The host back alive, out of its protection, and put `x` along the line from the shooter.
func _back_at(hs: Session, hp: Node, host: Dictionary, x: float) -> void:
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0, 6000)
	hp.respawn_at(host["main"].to_global(Vector3(x, STAND_Y, LINE_Z)))
	await _frames(3)


## Waits `seconds` of game time with no input, so every interval runs out.
func _settle(p: Node, seconds: float) -> void:
	for i in _frames_for(seconds):
		p.drive_input(Vector2.ZERO)
		await physics_frame


## Holds fire every physics frame; the frame (from 1) the first shot goes off, or -1.
func _first_shot_frame(p: Node, last: int) -> int:
	var shots: int = p.shots_fired
	for k in range(1, last + 1):
		p.drive_input(Vector2.ZERO, false, false, true)
		await physics_frame
		if p.shots_fired > shots:
			return k
	return -1


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Tracers alive now: effect nodes holding a cylinder. Counted by shape, not name: the
## engine renames siblings that share one ("@Node3D@12"), and nine pellets make nine.
func _count_fx(_kind: String) -> int:
	return _count_fx_under(root, _kind)


func _count_fx_under(parent: Node, _kind: String) -> int:
	var n := 0
	for node in get_nodes_in_group(FX_GROUP):
		if parent.is_ancestor_of(node) and node.get_child_count() > 0 and node.get_child(0) is MeshInstance3D and (node.get_child(0) as MeshInstance3D).mesh is CylinderMesh:
			n += 1
	return n


func _key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _wheel(button: MouseButton) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await physics_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			var session = branch.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			branch.free()
	await process_frame
	OS.delay_msec(300)
	await process_frame
