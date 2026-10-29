extends Node
## The one owner of LAN and tailnet play (C13, PRD 5.1): one player hosts, another joins by
## address, and each sees the other move. Nothing else in the game opens a socket.
##
## One ENet socket, and only when the player asks: host() opens the tuning's UDP port
## (9009), join() connects to the address the player typed (an IP, or a hostname looked
## up on a worker). No discovery, no broadcast, no relay, no server of anyone else's.
## Solo play never touches this: the session sits OFF with Godot's offline peer.
##
## Handshake, before a peer counts as a player: the joiner sends the protocol version and
## its shown name as Godot's authentication data; the host answers with its own version
## and a verdict (ok with a slot and name, version mismatch, or full) and only completes
## authentication for an ok. A refused joiner reads the verdict, shows it and closes; the
## host drops it after a grace anyway. Until the handshake completes no state is sent
## either way. A join that gets no answer ends after connect_timeout_ms with "couldn't
## reach host" (ENet alone would wait far longer for a closed port).
##
## The host owns the session: who is in it, their slots and names (the roster, sent to
## every player on every change). Each player owns its own movement for now: sync_rate_hz
## times a second it sends position, body yaw, view pitch and velocity; a joiner's state
## goes to the host, which applies it to that player's avatar and passes it to the others
## (Godot's own relay is off, so nothing moves between players without the host's code).
## Remote avatars (scripts/net/remote_player.gd) live under a Players node in the arena
## and interpolate between received positions. The session lives beside the arena, so an
## R reload of the arena keeps the connection; the new arena attaches and avatars return.
##
## Combat (C14) runs on the same session with the host as the one authority
## (scripts/net/combat.gd): a player sends only the intent to fire (shot number, life,
## weapon id, origin, aim); the host validates it (the weapon held, its fire interval, the
## swap time, its magazine), draws a pellet weapon's pellets itself from the aim with its
## own generator (C16: a joiner never chooses where pellets go), raycasts each in its own
## world against walls, dummies and the players' bodies, applies each pellet's damage after
## its falloff, and tells everyone the result. A player also tells the host when it draws a
## weapon and when it starts a reload, so the host keeps the same rules as its inventory;
## both sides start a match with slot 1 drawn and every weapon full (the shot with every pellet's end point, who
## was hit and their health, a death with the weapon, a respawn). The host's own shots go
## through exactly the same path. Joiners never apply damage or decide a kill; they display
## what the host sent, and their own tracers are a guess drawn before the host answers.
## Remote avatars carry a hit volume on the targets layer that nothing walks into. Dummies
## stay each player's own; the host's combat ray stops at one but never damages it. During
## a match an R reload of the arena hands the new player the weapons and ammo the old one
## had, so it never refills a magazine.
##
## Room codes (C15): a host with a live rendezvous (scripts/net/rendezvous_client.gd) draws
## a code from scripts/net/room_code.gd, registers it with its game port and shows it; a
## joiner who types a code or a sigkill://join/ link has it checked here first (a typo never
## reaches the network), then resolved to an address and port, then joined by the C13 path.
## With no relay set (the default) the rendezvous is NullRendezvous, never live: a code gets
## "Online rooms aren't live yet. Use LAN join (address)." and nothing is sent anywhere.
##
## A relay (C16c, relay/relay_server.gd, docs/RELAY.md) is used only when the player sets
## its URL in the settings (or the room tuning names one): then the rendezvous is a
## UdpRendezvous to it. A host's registration gets the room's host token and one relay port
## per joiner slot; the host sends each a small probe from its own ENet socket every few
## seconds (socket_send, no other socket), so the relay knows where to forward and the NAT
## lets it in. A joiner's resolution gets the room's join port on the relay and the join
## token; it connects there with the C13 path and probes from its ENet socket while it
## connects. Every packet of the match then goes through the relay, and a room code only
## ever leads to the relay the player set, never to an address the relay names.
##
## Over WebSocket (C16d): a ws:// or wss:// relay URL picks WsRendezvous
## (scripts/net/ws_rendezvous.gd) instead, for a relay behind an HTTPS proxy on one TCP port.
## The session's relay path stays exactly the same: the rendezvous answers with loopback ports
## of its own (127.0.0.1) where the UDP relay's answers name the relay's ports, so the host's
## probes and the joiner's ENet go there, and the rendezvous carries every datagram over its
## one link. It is pumped once a frame and its tunnel closes with the peer.
##
## The SIGKILL rail (C17): a rail shot is an ordinary intent naming the rail; the host
## believes it only with the shooter's ult meter full (scripts/net/combat.gd owns every
## meter), traces the line itself through every player on it to the first wall, and applies
## the rail's damage to each, so spawn protection still holds. What the other weapons do to
## players here fills the meters by the ult's numbers: the host's for every player, and this
## player's own copy from the same confirmed results (the shot and death messages it already
## gets), so nothing new crosses the wire. A rail kill is named in the feed with the victim's
## fake process id, fake_pid(): never a real one. Its "kill -9" callout comes from this
## player's own trace of where its rail struck, once the host's word of the kill arrives.
##
## SIGSTOP bullet time (C18): in a match it never slows the host's simulation, or anyone's.
## A player's press (scripts/abilities/sigstop.gd) goes to the host as an ask to start or
## end it, _sigstop (life and on or off, untyped and type-checked like every intent); the
## host owns every player's SIGSTOP meter (scripts/net/combat.gd), drops and counts a start
## the meter cannot pay for, and answers that player alone with its word, _sigstop_state
## (life, on or off, the seconds left): after every ask, when the meter runs out and when the
## player joins. Only while its word is "on" does the host draw that player's pellets
## straight; the slow-mo look stays on that player's own screen. Protocol 4.
##
## The fork bomb (C19): the host owns the whole chain. A player's throw goes to the host as
## its own request, _throw (life, weapon, origin, aim, untyped and type-checked: never a shot
## intent), checked against the host's view of the thrower's eye and aim, its bombs and the
## fork bomb's interval, its cap of live bomblets and the cover it stands against
## (scripts/net/combat.gd). The host then runs the chain in its own world
## (scripts/weapons/fork_bomb.gd), judges every blast against the players' bodies with
## nothing of the level between (never the thrower: no self-damage) and tells everyone the
## damage and the deaths as for a shot of the fork bomb, so the kill feed names "fork bomb".
## To every joiner it sends one seed per throw, _bomb (throw id, thrower, weapon, seed,
## origin, aim), from which their screen draws the same chain and the same scatter, and each
## blast as it happens, _blast (throw id, generation, index, where): a joiner's chain goes off
## only on that word and never judges anything. Protocol 5.
##
## Light-trail mode (C20): a match rule, off unless the host turns it on (the settings'
## multiplayer light_trails, or --light-trails on its command line); a joiner takes the
## host's word, _rules (on or off), sent with every roster and whenever it changes. Solo play
## has no trails. The host owns every wall (scripts/modes/light_trails.gd): from each living
## player's place as it knows it (its own body; a joiner's newest position), with a ray down
## to the level for whether they are on the ground, it lays their segments and sends each to
## every joiner, _trail (owner, life, from, to, age 0), whose screen draws it and ages it on
## its own clock (a joiner arriving while walls stand is sent each with its age, so both
## screens end it together); and every physics step it judges every living, unprotected body against
## every wall. A touch is a kill credited to the wall's owner (killing yourself on your own
## older wall counts no kill): the usual death message, with the cause "light trail" in
## place of a weapon, so the feed reads "light trail sent by ...". A death or a respawn
## clears that player's walls on every screen; leaving the match takes them all away.
## Protocol 6.
##
## Root vs user and sudo overcharge (C22): the host owns it (scripts/net/combat.gd keeps
## every player's sudo state). A kill the host credits, by any weapon or wall, counts toward
## the killer's next sudo charge; a player's press of Z is only a request, _sudo (its life,
## untyped and type-checked), which the host believes with a charge held and refuses and
## counts otherwise. While a player is root the host's own judging makes its hits
## damage_scale times harder (its ult meter filling no faster: the share is taken at user's
## strength) and spends none of its ammo. Every change of a player's sudo state goes to every
## joiner at once, _sudo_state (id, life, charges, root seconds left), sent before any shot
## the host judges after it, so every screen shows who is root (the badge and the red glow)
## and each player its own charge. A joiner never applies the harder hits itself. Protocol 7.
##
## Spectate as top (C23): the top table a dead player watches (scripts/hud/spectate_top.gd)
## shows health, deaths, root and names from what every player already gets; its other
## numbers are history a player who joined late never received, so the host sends them: once
## every refresh_s (a second, never faster: resources/spectate_top.tres), to every joiner,
## _top (the match's seconds of play, its kills in the three load windows, and per player its
## game PID by join order, kills, deaths, damage dealt and time alive this life), all from the
## host's own record (scripts/net/combat.gd). A joiner shows them as sent, and shows "-" for
## any it has not been sent yet; it never makes one up. Protocol 8.
##
## fork() (C24): a fork() shot is an ordinary intent (_fire). The host believes it by the same
## checks as any shot, draws its seed with its own generator (a joiner never picks where
## pellets go) and runs the shot as a volley of fast pellets in its own world
## (scripts/weapons/fork_volley.gd), judging each pellet that meets a player (_judge_pellet:
## the pellet's damage for its generation, root's harder hits, told as a shot of fork() to
## one player, and each kill as a death by it). Every joiner gets the seed in the same message
## as a fork bomb's throw, _bomb (shot id, shooter, weapon, seed, origin, aim), and draws the
## same pellets from it, forking once more while the host's word says the shooter is root
## (that word always reaches a joiner before any shot judged after it); a joiner's volley never
## judges a player. No new message: protocol 8 still.
##
## grep (C25): a grep shot is the usual intent (_fire), which carries its claims too: the player
## ids of the marks the shooter's lock holds (scripts/weapons/grep_lock.gd), at most MARKS_LAST
## and untyped and type-checked like the rest. The host believes the shot by the usual checks,
## then each claim by its own (_accept_marks: a living player other than the shooter, within
## the weapon's lock range plus its tolerance of the shot's origin, within its sight cone plus
## its tolerance of the shot's aim, nothing of the level between, no more than the shooter's
## marks as user or root allow) and drops the rest, counted. It runs the darts in its own world
## from the origin, the aim, a seed of its own generator and the believed marks
## (scripts/weapons/seeker_volley.gd), judging each that meets a player as a fork() pellet is
## (_judge_pellet, root's harder hits included), and sends every joiner the seed and the
## believed marks in the seed message, _bomb, which now carries them. A joiner's darts home on
## the marks as its screen shows them and never judge a player. Two messages gained a field, so
## protocol 9: a peer still on 8 gets the version-mismatch refusal.
##
## The rm -rf cannon (C26): its wind-up is the shooter's own (the rail's charge), so the shot is
## the usual intent sent when the wind-up ends. The host believes it as any shot and runs the
## slug in its own world (scripts/weapons/rm_slug.gd); where it stops, the blast is judged here
## (_judge_slug_blast): every living player within its radius (root's larger one) with nothing of
## the level between, the shooter too at the weapon's self-damage share, takes the damage for its
## distance at the shooter's strength (root's harder hits), told as a shot of the rm -rf cannon,
## each kill as a death by it (a shooter it kills: "rm -rf: <name> removed themself" in the feed,
## no kill credited). Every joiner gets the shot in the seed message, _bomb, and the blast in the
## fork bomb's blast word, _blast (now sent from _tell_blast for both): its slug flies the same
## line, goes off only on that word, at the host's place, and never judges anything. No message
## changed: protocol 9 still.
##
## cron mines (C27): a placement is the usual intent; the host sticks the mine where the shooter's
## aim meets the level within the placement range (or at its feet, from the host's view of it),
## and owns the job from then on (scripts/weapons/cron_mine.gd): the schedule, each run judged as
## the rm -rf blast is (_judge_slug_blast; a mine's self-damage share is 0, so it never hurts its
## owner), kills credited to the owner even dead or respawned. Each player holds the weapon's
## crontab limit of jobs: a placement past it removes the oldest. Another player's shot removes a
## mine: a hitscan ray passing within its hit volume (_shoot_mines), a pellet, dart or slug that
## meets one (the host's volleys see the mines' layer), a blast that reaches one (_blast_mines),
## the shooter's own never. A player leaving takes its jobs with it. Joiners hear of a placement
## in the seed message, _bomb (its seed the runs left, negative for a mine already past its arm
## delay, as one sent to a joiner arriving mid-job is), and of each run and each removal in the
## blast word, _blast: a run's generation is the runs left after it, a removal's is negative
## (MINE_CRONTAB, MINE_SHOT with the remover's id as the index, MINE_GONE). A joiner's mine only
## draws and never judges or schedules. No message changed: protocol 9 still.
##
## The daemons fight back (C27b): the host runs every daemon. In a match where they fight (the
## host's rule: its practice setting off), the host's director (scripts/fight/daemon_director.gd)
## steps every daemon's brain against every player of the match, its own and each joiner's
## avatar, and every attack that lands is judged here in the host's combat (daemon_hurt():
## Combat.damage_player with no killer credited, spawn protection holding), told to everyone as
## its own word, _daemon_hit (victim, health, daemon), and a kill as the usual death message with
## the cause "daemon:<n>", so the feed and the banner name the daemon. The daemons' lives are the
## host's too: every player's shot at one is judged by the host where it already judges shots (a
## hitscan ray, the rail's line, a pellet or dart, a blast), the host's own included, and a
## joiner's own copy of a daemon takes nothing from its local shots. Joiners only draw: the host
## sends every joiner the daemons at the sync rate, _daemons (each one's place, facing, state and
## seconds into it, SIGSTOP's hold, its life and health, and every bolt in the air by its id), whose
## brains play it (the tells, lunges, dives and scatters at the host's pace), and each bolt as it
## is thrown, _daemon_bolt (daemon, bolt id, from, aim), which the joiner's copy throws to draw
## only (a bolt the joiner missed, an R reload's, is thrown from the state word; one the host no
## longer has is stopped; one that strayed is put where the host's is, and SIGSTOP's hold on each
## is the host's word). A joiner whose own shot struck a daemon hears it from the host,
## _daemon_struck (daemon, killed), for its hit marker; a kill's credit is in the state word, which
## names whose kill each daemon's last death was, with the death itself. The rule (practice, difficulty) rides
## the match's rules message, _rules, beside light trails; until it comes a joiner's daemons are
## the old dummies. In practice nothing of this is sent and dummies stay each player's own, as
## since C14. Four new messages (_daemons, _daemon_bolt, _daemon_hit, _daemon_struck) and a
## changed one (_rules), so protocol 10: no older message carried a daemon's place or state, each
## machine's dummies having been its own.
##
## No two alike (A5): every daemon is built from a seed, a new one at each spawn on the host, and
## _daemons carries each one's seed too, so a joiner's copy is rebuilt from it and every screen draws
## the same creature (its size, its build, an elite's health). A changed message, so protocol 11.
##
## chmod 000 (C29): a beam tick is an ordinary intent (_fire) of the freeze weapon, sent every tick
## while fire is held. The host believes it by the usual checks (its rate is the tick) and its own: a
## tank not venting (the host keeps every player's coolant) and a shooter not frozen (a frozen player's
## shots and throws are dropped). It casts the tick's ray itself (_beam_freeze): a player it meets
## takes the tick's seconds of beam in the host's combat (never a dead or spawn-protected one); a
## joiner's beam on the host's daemons and ICE, while they fight, lands here, Black ICE only slowed.
## Every screen draws the tick from the shot message, _shot, with no hits. The meters travel in words
## already sent: a daemon's and a piece of ICE's in their state byte (_daemons, _ice: bits 3 to 6 beside
## the state's three and SIGSTOP's), Black ICE's slow as its word's thirteenth number, and every
## player's in the movement word, _remote_state, which gained a byte (the host's own included, and each
## joiner's own sent back to it while it has any). Two messages changed and the loadout grew (weapon
## 10), so protocol 15, no new message.
##
## pipe | (C30): a chain is an ordinary intent (_fire) of the chain beam. The host believes it by the
## usual checks and its own (a pipe buffer that is not blocked: the host keeps every player's), builds
## the chain in its own world (_pipe_judge, scripts/weapons/pipe_chain.gd: the joiner's own aim's ray,
## then the arcs over the host's daemons and ICE and the players' bodies, never a dead or spawn-protected
## player), lands every player's link in its combat and, while they fight, a joiner's links on its
## daemons and ICE (Black ICE only flashed); the host's own chain is the one its player built and drew
## (its own daemons already took their links there). Every screen draws the chain from the shot message,
## _shot, as it always carried the shot's ends: here the chain's points in order, link to link (a miss
## its end twice: no two links of a chain are ever one point), its struck players and their health as
## any shot's. No new message, no changed one; the loadout grew (weapon 11) and _shot's ends mean a
## chain for it, which an older build would neither believe nor draw, so protocol 16.
##
## /dev/null (C31): a throw like the fork bomb's (_throw, the host's usual checks and its own count of each
## player's charges coming back), its live cap one open hole a player. The host runs the hole (_spawn_hole,
## scripts/weapons/dev_null_hole.gd): it opens it, drags and hurts the daemons and ICE it holds while they
## fight, and judges every player it reaches each tick and at its implosion (_judge_hole: the ninth host-only
## damage site; never the thrower, a dead or a spawn-protected player), told as shots of /dev/null at the
## core and deaths by it. Joiners get the throw's seed on _bomb (its sign the thrower's root: a wider hole)
## and its opening place, its collapse and each discard on _blast (generations HOLE_OPENED, HOLE_COLLAPSED,
## HOLE_DISCARDED); each screen drags its own player from its own copy, so the pull is felt with no lag of
## the host's. No new message, no changed one; the loadout grew (weapon 12) and _bomb and _blast mean a
## hole for it, which an older build would neither draw nor feel, so protocol 17.
##
## Over the wire, ever: the protocol version, slots and ids, shown names (a placeholder,
## never the system's user or host name), positions, angles and velocities, shot intents
## and results, health, deaths and respawns by id, SIGSTOP's asks and the host's word on it
## (on or off, the seconds left), the light-trail rule and walls, sudo asks and each
## player's sudo charges and root time, a fork() shot's seed, a grep shot's seed and its claimed and
## believed marks (player ids), an rm -rf shot and where its blast went off, a cron mine's place,
## runs and removals, the top table's numbers (game PIDs, kills,
## deaths, damage dealt, time alive, the match's uptime and load), and the game's daemons
## (C27b: places, facing, states, health and life, bolts, hits by daemon index, the practice
## rule and the difficulty; A5: each one's build seed, a random number; game objects, never a real
## process), and chmod 000's freeze meters (C29: a level and a frozen bit per daemon, piece of ICE and
## player, Black ICE's slow). Nothing about the AI
## guide, the settings, paths, processes or the machine; a game PID is game data, never a
## real one. Nothing real is signalled, killed or run.

const Tuning = preload("res://scripts/net/net_tuning.gd")
const RemotePlayer = preload("res://scripts/net/remote_player.gd")
const Combat = preload("res://scripts/net/combat.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const NullRendezvous = preload("res://scripts/net/null_rendezvous.gd")
const UdpRendezvous = preload("res://scripts/net/udp_rendezvous.gd")
const WsRendezvous = preload("res://scripts/net/ws_rendezvous.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")
## A host probes its relay slot ports this often, which keeps the relay's path and the NAT's
## mapping open while it waits for players.
const RELAY_PROBE_S := 5.0
## A joiner probes the room's join port this often while it connects.
const JOIN_PROBE_S := 0.25
const RoomTuningScript = preload("res://scripts/net/room_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const ArsenalScript = preload("res://scripts/weapons/arsenal_tuning.gd")
const SigstopTuning = preload("res://scripts/abilities/sigstop_tuning.gd")
const SudoTuning = preload("res://scripts/abilities/sudo_overcharge_tuning.gd")
const ForkBomb = preload("res://scripts/weapons/fork_bomb.gd")
const DevNullHoleScript = preload("res://scripts/weapons/dev_null_hole.gd")
const ForkVolley = preload("res://scripts/weapons/fork_volley.gd")
const SeekerVolley = preload("res://scripts/weapons/seeker_volley.gd")
const RmSlug = preload("res://scripts/weapons/rm_slug.gd")
const CronMine = preload("res://scripts/weapons/cron_mine.gd")
const PingPulseScript = preload("res://scripts/weapons/ping_pulse.gd")
## A cron mine's word in _blast (C27): a run's generation is the runs left after it (0 and up);
## a removal's is one of these, the remover's player id the index for a shot.
const MINE_CRONTAB := -1
const MINE_SHOT := -2
const MINE_GONE := -3
## /dev/null's words on _blast (C31): its generation says what (the index is unused but a discard's count).
const HOLE_OPENED := 0
const HOLE_COLLAPSED := 1
const HOLE_DISCARDED := 2
## From a player's middle down to its feet: where a mine placed at the feet looks for the floor.
const FEET_M := 0.9
const LightTrails = preload("res://scripts/modes/light_trails.gd")
const LightTrailTuning = preload("res://scripts/modes/light_trail_tuning.gd")
const Palette = preload("res://scripts/palette.gd")
const TRAIL_TUNING_PATH := "res://resources/light_trail.tres"
const TopTuning = preload("res://scripts/hud/spectate_top_tuning.gd")
const TOP_TUNING_PATH := "res://resources/spectate_top.tres"
## The cause a light-trail death carries where a shot's weapon id goes, and the feed's word.
const LIGHT_TRAIL := "light_trail"
const LIGHT_TRAIL_WORD := "light trail"
## A daemon's death (C27b): its cause is this and the daemon's index ("daemon:2"); the feed's
## second line for it.
const DAEMON_CAUSE := "daemon:"
## A death by hunter ICE's lance (I1), and the name it goes by in the feed.
const ICE_CAUSE := "ice:hunter"
const ICE_NAME := "hunter ICE"
## A flatline by Black ICE's touch (I3): out for the rest of the (host's) round, no respawn till then.
const BLACK_CAUSE := "ice:black"
## The feed's second line for a flatline (I3).
const FLAT_WORD := "flatlined: out until the round ends"
const DAEMON_WORD := "derezzed by a daemon"
## The most daemons, and bolts, the state word may carry.
const DAEMONS_LAST := 64
const BOLTS_LAST := 64
const DAEMON_TIME_LAST := 3600.0
## The command-line flag that turns light-trail mode on for this run's hosting.
const LIGHT_TRAILS_FLAG := "--light-trails"
## What counts as ground under a player for laying a wall: the level.
const GROUND_MASK := 1
## What a fork bomb's blast does not see through: the level.
const BLAST_SIGHT_MASK := 1
## What a claimed grep mark's sight does not see through: the level.
const MARK_SIGHT_MASK := 1
const CannonFx = preload("res://scripts/cannon_fx.gd")

const DEFAULT_TUNING_PATH := "res://resources/net.tres"
const COMBAT_TUNING_PATH := "res://resources/combat.tres"
const ROOM_TUNING_PATH := "res://resources/room.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
## The longest weapon id an intent may carry.
const WEAPON_ID_LAST := 32
## The physics layer the local player's body is on: a joiner's shot must be able to hit it.
const PLAYER_LAYER_MASK := 2
const SPAWNS_NODE := "Arena/Spawns"
const FALLBACK_SPAWN := Vector3(0.0, 0.95, 10.0)
const PLAYER_ID_META := "player_id"
## Changes whenever what goes over the wire changes. Both sides must match.
const PROTOCOL := 17
## An avatar's freeze beam starts this far ahead of its eye and this far below it (C29): its emitter.
const BEAM_AHEAD_M := 0.45
const BEAM_DROP_M := 0.2
const PLACEHOLDER := "player"
const DAEMON := "Daemon-"
const MAGIC_0 := 0x53  # "S"
const MAGIC_1 := 0x4B  # "K"
const HELLO_HEAD := 5
const REPLY_HEAD := 7
const VERSION_LAST := 65535
const SLOT_LAST := 255
## How long a refused joiner gets to read the verdict and close before the host drops it.
const REFUSE_GRACE_MS := 500
## ENet connection slots beyond max_players, so a joiner to a full host can be told so.
const ENET_SLACK := 2
const ENET_TIMEOUT_LIMIT := 32
## A link to this same machine never throttles (C31's fix-it): ENet backs off a peer's unreliable packets
## when its round trip rises, and on a loopback link (a host and its joiners on one machine, as every
## check runs them, in one process) that round trip is only the frame loop's own jitter on a busy machine,
## so the packets it dropped there relieved no congestion. Every other link keeps ENet's own back-off.
const ENET_THROTTLE_INTERVAL_MS := 5000
const WORLD_LAST := 10000.0
const SPEED_LAST := 200.0
## Sequence numbers count up from 1 per session and never reach this.
const SEQ_LAST := 2147483647
const PITCH_LAST := PI * 0.5 + 0.01
## A body yaw is an angle Godot already wrapped: never past one full turn either way.
const YAW_LAST := TAU + 0.01
const ADDRESS_LAST := 260
const HOSTNAME_LAST := 253
const LABEL_LAST := 63
const PORT_LAST := 65535
const NODE_NAME := "NetSession"
const PLAYERS_NODE := "Players"
const CANT_REACH := "couldn't reach host"
const HOST_FULL := "host full"
const HOST_LEFT := "host left"
const BAD_ADDRESS := "not an address: type an IP or a host name, with an optional :port"
const BAD_REPLY := "the host answered in a way this version does not understand"
const ROOM_UNKNOWN := "no open room with code %s"
const ROOM_EXPIRED := "room code %s has expired: ask the host for a new one"
const ROOM_UNREACHABLE := "couldn't reach the room service"
const ROOM_BUSY := "the room service is busy: try again in a moment"
const ROOM_BAD_REPLY := "the room service answered in a way this version does not understand"
const ROOM_NO_CODE := "no room code (%s): LAN join by address still works"
const ROOM_ALL_TAKEN := "every code drawn was taken"
## Until relay hosting is decided (docs/RELAY.md), a room code may lead only to this machine,
## the LAN or a tailnet: never to a public address a rendezvous names.
const ROOM_NOT_LOCAL := "that room is outside your LAN or tailnet; online rooms aren't live yet"

enum State { OFF, HOSTING, RESOLVING, CONNECTING, JOINED, FAILED, ROOM }
enum Verdict { OK, VERSION, FULL }

## Emitted on every change of state, error, roster or address.
signal changed
## Combat, from the host's confirmed results (on the host too, through the same path).
signal combat_changed
signal shot_confirmed(shooter: int, hit: int, origin: Vector3, end_point: Vector3)
signal player_died(victim: int, killer: int)
signal player_respawned(id: int)
## A player's shot removed another player's cron mine (C27): the feed's "crontab -r" line.
signal job_removed(remover: int, owner: int, word: String)
## The host says this player's own shot struck daemon `index` (C27b), and whether it killed it.
signal daemon_struck(index: int, killed: bool)

# Set these before the node enters the tree.
## NetTuning; null for resources/net.tres.
var tuning: Resource = null
## The protocol version this side speaks. A test gives one side another number to prove
## the mismatch is refused. Never changed by the game.
var protocol := PROTOCOL
## CombatTuning; null for resources/combat.tres.
var combat_tuning: Resource = null
## RoomTuning; null for resources/room.tres.
var room_tuning: Resource = null
## The rendezvous for room codes; null: the one RoomTuning gives, today always NullRendezvous.
## A test hands in its fake.
var rendezvous: RefCounted = null
## While hosting with a live rendezvous: this room's code once registered, else "".
var room_code := ""
## Seconds until room_code is given up and a fresh one registered.
var room_expires_s := 0.0

var state: State = State.OFF
## Why the last join or host attempt ended, for the screen, or "".
var error := ""
## What the player typed to join, shown back on their own screen only.
var address_text := ""
## For a host: the last joiner it refused and why, so the host's screen says so too.
var notice := ""
## Everyone in the session, id -> {slot, name}; the host is id 1.
var players := {}
var my_id := 1
## The remote players' avatars in the current arena, id -> RemotePlayer.
var avatars := {}
## State packets sent, and received and applied, this session.
var sent := 0
var received := 0
## The host's combat authority while hosting; null otherwise.
var combat: Combat = null
## What every side shows, from the host: id -> health, dead, protection left, the last
## killer, respawn countdown (for the dead, counted down locally from the host's number).
var health := {}
var dead := {}
var protect_left := {}
var last_killer := {}
## The killer's name as it was at the death, kept for the banner and the feed even after
## that player has left.
var last_killer_name := {}
## The signal the killing weapon sends, for the feed: "SIGKILL" for the cannon (C16).
var last_kill_word := {}
## For a player its own weapon killed, that weapon's self-kill words, for the feed (C26); else "".
var last_kill_self := {}
var respawn_left := {}
## Black ICE's flatlines (I3): a player down by one, held there until the host's next round (every
## screen, from the death's cause); hosting, the ICE round it happened in.
var _flat := {}
var _flat_round := {}
## chmod 000 (C29): hosting, each joiner's freeze meter as last told to it (its own word goes back to it
## while there is any, and once more as it goes); beam ticks the host judged, and the freezes they made.
var _frost_told := {}
var beam_ticks_judged := 0
var freezes_judged := 0
## pipe | (C30): chains the host judged, and the links of the last one (who, where, how hard), for the
## checks.
var chains_judged := 0
var last_judged: Array = []
## Each player's life number: up by one at every respawn, carried in every state packet,
## so a position sent before a respawn and arriving after it is known for what it is.
var lives := {}
## A respawn that arrived for this player while its arena was reloading: the host's chosen
## spawn, in arena space, applied when the next arena attaches. INF when none is waiting.
var _pending_spawn := Vector3.INF
## The weapon that respawn put in this player's hand, applied with it.
var _pending_weapon := ""
## Joiner: whether the first roster has come (the host holds this player from then on),
## and whether this side's weapons have started fresh since, which needs a player.
var _roster_seen := false
var _weapons_synced := false
## How soon the host tries a respawn again when its own arena is absent.
const RESPAWN_RETRY_S := 0.05
## After the host's arena attaches, how long a respawn waits for the opponents' positions
## to arrive (a few send intervals), so the spawn is chosen away from them.
const SPAWN_LOOK_S := 0.5
## The host's clock when its arena last attached; respawns wait a little after it.
var _attached_at := -INF
## Shot intents this player sent (or, hosting, fired), numbered from 1 per session.
var fire_seq := 0

var _t: Tuning
var _enet: ENetMultiplayerPeer
var _arena: Node = null
var _player: Node = null
var _players_node: Node3D = null
var _connect_left_ms := 0.0
var _resolve_item := -1
var _resolve_name := ""
var _join_port := 0
## The local port a joiner's socket was bound to on the tuning's bind address, or 0 when
## it was left to the system on every interface.
var _local_port := 0
var _seq := 0
var _send_wait_s := 0.0
## Host: joiners that passed the handshake, id -> {slot, name}, until peer_connected.
var _pending := {}
## Host: refused joiners and the grace left before they are dropped, id -> ms.
var _refused := {}
var _ct: CombatTuningScript
var _rt: RoomTuningScript
var _rv: RefCounted
## The rendezvous request in flight ("register", "resolve" or ""), the code it is about,
## the codes drawn so far for this room, the port registered, and the time left for it.
var _room_request := ""
var _room_wanted := ""
var _room_attempts := 0
var _room_port := 0
var _room_left_ms := 0.0
## The relay URL the rendezvous in use was made for.
var _rv_url := ""
## Host through a relay: {ip, ports, token} for the room's slot ports, and the next probe.
var _relay_host := {}
var _relay_probe_left := 0.0
## Joiner through a relay: {ip, port, token} for the room's join port, and the next probe.
var _relay_join := {}
var _join_probe_left := 0.0
var _launch_checked := false
## A --join taken before this node was ready (the arena makes the session a frame late):
## the parsed result, applied in _ready.
var _launch_pending := {}
## The arsenal every player holds (C16): id -> WeaponDef, and the swap time.
var _weapons := {}
var _weapon_list: Array = []
var _swap_s := 0.3
## The host's own generator for pellets: a joiner never picks where its pellets go.
var _pellets_rng := RandomNumberGenerator.new()
## Draws each throw's seed (C19); the throws so far (each one's id), and the chains this
## arena runs or draws, throw id -> {chain, thrower}.
var _seeds := RandomNumberGenerator.new()
var _throws := 0
var _chains := {}
## /dev/null's holes in this arena (C31), throw id -> hole.
var _holes := {}
## The fork() volleys this arena runs or draws (C24), shot id -> volley; their ids share the
## throws' count.
var _volleys := {}
## Host: grep claims it did not believe (C25).
var marks_refused := 0
## The cron mines this arena runs or draws (C27), id -> mine (their ids share the throws' count),
## and, hosting, each owner's job ids, oldest first.
var _mines := {}
var _jobs := {}
## During a match: the weapons and ammo of the player whose arena went away (an R reload),
## handed to the next player that attaches.
var _kept_inventory: RefCounted = null
## Joiner: weapon intents (draws, reloads, shots) sent to the host this session. Host: the
## same, received from each player, id -> count. The host's ammo reply after each one names
## the count it has handled, and a joiner takes only a reply that has caught up with all it
## sent: a late one is stale. One that comes while the arena is away waits for the next.
var _sent_actions := 0
var _actions_from := {}
var _ammo_pending := {}
## The host's clock for the fire rate, in seconds of game time.
var _clock := 0.0
## The host's last word on this player's SIGSTOP, [on, seconds left], for an arena that
## comes back after an R reload.
var _stop_word: Array = []
## LightTrailTuning; null for resources/light_trail.tres. Set before the node enters the tree.
var light_trail_tuning: Resource = null
## --light-trails on this run's command line: hosting turns the mode on (C20).
var light_trails_flag := false
## Light-trail mode in this match: the host's own rule as it last told everyone, or, joined,
## the host's word.
var _trails_rule := false
## The host's daemon rule (C27b) as this joiner last heard it: practice (the old never-attack
## dummies) until the host says they fight, and the difficulty. The host's own is its settings.
var host_practice := true
var host_difficulty := "normal"
## The host's ICE setting (I1), as this joiner last heard it: on unless the host turned it off.
var host_ice := true
## Hosting, the wait to the next ICE word; joined, ICE words taken (for the checks).
var _ice_wait_s := 0.0
var ice_words := 0
## Joined: Black ICE words taken (I3, for the checks).
var black_words := 0
## The ICEbreakers (I2): hosting, the wait to the next breaker word and the asks it refused; joined,
## breaker words taken and asks sent (for the checks).
var _breaker_wait_s := 0.0
var breaker_refused := 0
var breaker_words := 0
var breaker_asks := 0
## The rule the host last told its joiners, and the wait to its next daemon word.
var _told_rule := []
var _daemon_wait_s := 0.0
var _lt: LightTrailTuning
## Every player's root seconds left as the host last said, id -> seconds (0: user) (C22).
var root_left := {}
## This player's own sudo charges as the host last said, for an arena back from an R reload.
var _my_charges := 0
## Joiner: the verdict the host sent, kept until the disconnect it causes is reported.
var _refusal := ""
## SpectateTopTuning; null for resources/spectate_top.tres. Set before the node enters the tree.
var top_tuning: Resource = null
## Host: the top table messages sent (one per joiner each time). Joiner: those taken.
var tops_sent := 0
var tops_received := 0
var _top_t: TopTuning
## Host: seconds until every joiner is sent the top table's numbers again.
var _top_left := 0.0
## Joiner: the host's last top table numbers ({uptime, load, rows: id -> {pid, kills, deaths,
## dealt, alive_s}}), or {} before the first.
var _top_word := {}


## The session beside `scene` (its parent's child named NetSession), made if there is none.
## The one just made joins the tree at the end of the frame, so it is ready a frame later.
static func of(scene: Node) -> Node:
	var parent := scene.get_parent()
	if parent == null:
		return null
	var found := parent.get_node_or_null(NODE_NAME)
	if found != null and found.get_script() == load("res://scripts/net/net_session.gd"):
		return found
	var session: Node = load("res://scripts/net/net_session.gd").new()
	session.name = NODE_NAME
	parent.add_child.call_deferred(session)
	return session


static func usable_tuning(candidate: Resource) -> Tuning:
	if candidate is Tuning:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("net tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is Tuning and shipped.problems().is_empty():
		return shipped
	return Tuning.new()


func _ready() -> void:
	tuning_in_use()
	combat_tuning_in_use()
	trail_tuning_in_use()
	top_tuning_in_use()
	room_tuning_in_use()
	rendezvous_in_use()
	if not _launch_pending.is_empty():
		var pending := _launch_pending
		_launch_pending = {}
		_apply_launch(pending)
	var shipped_arsenal = load(ARSENAL_PATH)
	_weapon_list = ArsenalScript.usable_loadout(shipped_arsenal)
	for def in _weapon_list:
		_weapons[def.id] = def
	_swap_s = ArsenalScript.usable_timing(shipped_arsenal).swap_s
	_pellets_rng.randomize()
	_seeds.randomize()
	var m := multiplayer as SceneMultiplayer
	if m == null:
		return
	m.auth_callback = _on_auth
	m.auth_timeout = _t.connect_timeout_ms / 1000.0
	m.server_relay = false
	m.allow_object_decoding = false
	m.peer_authenticating.connect(_on_authenticating)
	m.peer_authentication_failed.connect(_on_auth_failed)
	m.peer_connected.connect(_on_peer_connected)
	m.peer_disconnected.connect(_on_peer_disconnected)
	m.connected_to_server.connect(_on_connected)
	m.connection_failed.connect(_on_connection_failed)
	m.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	_shut_peer()
	if _rv != null and _rv.has_method("shut"):
		_rv.shut()


## The tunings and the rendezvous in use. Made on first use, so a screen that looks at a
## session before it is ready (the arena makes it a frame late) already gets real ones.
func tuning_in_use() -> Tuning:
	if _t == null:
		_t = usable_tuning(tuning)
	return _t


func top_tuning_in_use() -> TopTuning:
	if _top_t == null:
		_top_t = usable_top_tuning(top_tuning)
	return _top_t


func trail_tuning_in_use() -> LightTrailTuning:
	if _lt == null:
		_lt = usable_trail_tuning(light_trail_tuning)
	return _lt


func combat_tuning_in_use() -> CombatTuningScript:
	if _ct == null:
		_ct = usable_combat_tuning(combat_tuning)
	return _ct


func room_tuning_in_use() -> RoomTuningScript:
	if _rt == null:
		_rt = usable_room_tuning(room_tuning)
	return _rt


func rendezvous_in_use() -> RefCounted:
	if _rv == null:
		_rv_url = relay_url_for(room_tuning_in_use())
		_rv = rendezvous if rendezvous != null else rendezvous_for(room_tuning_in_use())
	return _rv


## The rendezvous again when the relay URL changed since it was made, if nothing is in
## flight: a relay set or cleared in the settings counts from the next host or join.
func _refresh_rendezvous() -> void:
	if rendezvous != null or _rv == null or _room_request != "" or relay_url_for(room_tuning_in_use()) == _rv_url:
		return
	if _rv.has_method("shut"):
		_rv.shut()
	_rv = null
	rendezvous_in_use()


## The rendezvous for the relay URL in use: NullRendezvous when there is none, the default,
## which never opens a socket or sends anything; for the relay the player set, the transport
## its scheme picks, a UdpRendezvous for udp:// (C16c) or a WsRendezvous for ws:// and wss://
## (C16d). Making one sends nothing either: its socket opens on its first request.
static func rendezvous_for(tuning: Resource) -> RefCounted:
	var url := relay_url_for(tuning)
	if url == "":
		return NullRendezvous.new()
	if RelayWire.transport_of(url) == "ws":
		return WsRendezvous.new(url)
	return UdpRendezvous.new(url)


## The relay URL in use: the player's, from the settings' Multiplayer section, or the room
## tuning's; "" (no relay, no network call) when neither names a valid one.
static func relay_url_for(tuning: Resource) -> String:
	var chosen: String = GameSettings.current().value("multiplayer", "relay_url")
	if chosen != "" and RelayWire.url_ok(chosen):
		return chosen
	var shipped = tuning.get("relay_url") if tuning != null else ""
	return shipped if shipped is String and shipped != "" and RelayWire.url_ok(shipped) else ""


static func usable_room_tuning(candidate: Resource) -> RoomTuningScript:
	if candidate is RoomTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("room tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(ROOM_TUNING_PATH)
	if shipped is RoomTuningScript and shipped.problems().is_empty():
		return shipped
	return RoomTuningScript.new()


static func usable_top_tuning(candidate: Resource) -> TopTuning:
	if candidate is TopTuning:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("spectate top tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(TOP_TUNING_PATH)
	if shipped is TopTuning and shipped.problems().is_empty():
		return shipped
	return TopTuning.new()


static func usable_trail_tuning(candidate: Resource) -> LightTrailTuning:
	if candidate is LightTrailTuning:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("light trail tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(TRAIL_TUNING_PATH)
	if shipped is LightTrailTuning and shipped.problems().is_empty():
		return shipped
	return LightTrailTuning.new()


static func usable_combat_tuning(candidate: Resource) -> CombatTuningScript:
	if candidate is CombatTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("combat tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(COMBAT_TUNING_PATH)
	if shipped is CombatTuningScript and shipped.problems().is_empty():
		return shipped
	return CombatTuningScript.new()


## The arena to show other players in and the player whose movement to send. The arena
## calls this when it is ready; avatars for everyone in the session appear in it.
func attach(arena: Node, player: Node) -> void:
	_arena = arena
	_player = player
	avatars.clear()
	_players_node = arena.get_node_or_null(PLAYERS_NODE) as Node3D
	if _players_node == null:
		_players_node = Node3D.new()
		_players_node.name = PLAYERS_NODE
		arena.add_child(_players_node)
	if not arena.tree_exiting.is_connected(_on_arena_exit):
		arena.tree_exiting.connect(_on_arena_exit)
	if player.has_signal("fire_intent") and not player.fire_intent.is_connected(_on_fire_intent):
		player.fire_intent.connect(_on_fire_intent)
	if player.has_signal("weapon_drawn") and not player.weapon_drawn.is_connected(_on_weapon_drawn):
		player.weapon_drawn.connect(_on_weapon_drawn)
	if player.has_signal("reload_started") and not player.reload_started.is_connected(_on_reload_started):
		player.reload_started.connect(_on_reload_started)
	if player.has_signal("throw_intent") and not player.throw_intent.is_connected(_on_throw_intent):
		player.throw_intent.connect(_on_throw_intent)
	for id in _chains.keys():
		if not is_instance_valid(_chains[id]["chain"]):
			_chains.erase(id)  # chains of the arena that went away with it
	var vision = player.get("vision")
	if vision != null:
		vision.session = self  # code-rain vision reads which bodies are enemies; it sends nothing (C21)
	var lock = player.get("grep")
	if lock != null:
		lock.session = self  # grep's marks are the other players' avatars in a match (C25)
	var sudo = player.get("sudo")
	if sudo != null and sudo.has_signal("intent"):
		sudo.session = self
		if not sudo.intent.is_connected(_on_sudo_intent):
			sudo.intent.connect(_on_sudo_intent)
		if is_online():
			sudo.take_host(_my_charges, root_left.get(my_id, 0.0))  # the host's word outlives an R reload
	var stop = player.get("sigstop")
	if stop != null and stop.has_signal("intent"):
		stop.session = self
		if not stop.intent.is_connected(_on_sigstop_intent):
			stop.intent.connect(_on_sigstop_intent)
		if is_online() and not _stop_word.is_empty():
			stop.take_host(_stop_word[0], _stop_word[1])  # the host's word outlives an R reload
	if is_online() and _kept_inventory != null and player.has_method("adopt_inventory"):
		player.adopt_inventory(_kept_inventory)  # an R reload mid-match keeps the ammo
	_kept_inventory = null
	if _pending_spawn.is_finite() and player.has_method("respawn_at"):
		player.respawn_at(arena.to_global(_pending_spawn))  # the host chose this while the arena was away
		if player.has_method("refill_weapons"):
			player.refill_weapons()  # and refilled every weapon, as a respawn does
		if _pending_weapon != "" and player.has_method("hold_weapon"):
			player.hold_weapon(_pending_weapon)
	_pending_spawn = Vector3.INF
	_pending_weapon = ""
	if not _ammo_pending.is_empty() and _ammo_pending["life"] == lives.get(my_id, 0) and _ammo_pending["handled"] == _sent_actions and player.has_method("take_ammo"):
		_apply_ammo(_ammo_pending)  # a count that came while the arena was away
	_ammo_pending = {}
	_attached_at = _clock
	if player.has_method("set_alive"):
		player.set_alive(not dead.get(my_id, false))
	_sync_weapons()  # a first roster that came while the arena was away
	for id in players:
		if id != my_id:
			_spawn_avatar(id)


func _on_arena_exit() -> void:
	if is_online() and _player != null and is_instance_valid(_player):
		_kept_inventory = _player.get("inventory")
	_arena = null
	_player = null
	_players_node = null
	avatars.clear()


## Opens the port and waits for players. `port` 0 lets the system pick one (tests), -1
## means the tuning's. False, with `error` set, if it could not.
func host(port: int = -1) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	_end_solo_sigstop()
	_refresh_rendezvous()
	var p := default_port() if port < 0 else port
	if p != 0 and not _port_free(p):
		_fail("port %d is in use" % p)
		return false
	var enet := ENetMultiplayerPeer.new()
	if _t.bind_address != "*":
		enet.set_bind_ip(_t.bind_address)
	if enet.create_server(p, _t.max_players + ENET_SLACK) != OK:
		_fail("couldn't open port %d" % p)
		return false
	_enet = enet
	multiplayer.multiplayer_peer = _enet
	my_id = 1
	players = {1: {"slot": 1, "name": assigned_name(_t.display_name, 1)}}
	_seq = 0
	fire_seq = 0
	_clock = 0.0
	combat = Combat.new(_ct, _weapon_list, _swap_s)
	combat.add_player(1)
	_top_left = top_tuning_in_use().refresh_s
	_reset_player_weapons()
	_mirror_from_combat()
	error = ""
	notice = ""
	address_text = ""
	state = State.HOSTING
	_send_sigstop(1)  # the host's own word, once it is hosting
	if _rv.is_live():
		_room_attempts = 0
		_register_room()
	changed.emit()
	return true


## Joins by a room code or a sigkill://join/ link: checked here first (a typo or a bad link
## is refused at once, with nothing sent), then, with a live rendezvous, resolved to the
## host's address and port and joined by the C13 path. With NullRendezvous: NOT_LIVE.
func join_room(text: String) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	_end_solo_sigstop()
	_refresh_rendezvous()
	var parsed := RoomCode.parse_join(text)
	if parsed.has("error"):
		_fail(parsed["error"])
		return false
	if not _rv.is_live():
		_fail(NullRendezvous.NOT_LIVE)
		return false
	var code: String = parsed["code"]
	if not _rv.resolve(code, protocol):
		_fail(ROOM_UNREACHABLE)
		return false
	_room_request = "resolve"
	_room_wanted = code
	_room_left_ms = _rt.request_timeout_ms
	error = ""
	notice = ""
	players = {}
	address_text = "room " + code
	state = State.ROOM
	changed.emit()
	return true


## The game's own command-line arguments, once per session: a --join with a room code or
## an invite link joins that room; a bad one fails with the reason. True when there was a
## --join at all, good or bad, so the screen can show what came of it.
func take_launch_join(args: PackedStringArray) -> bool:
	if _launch_checked:
		return false
	_launch_checked = true
	var parsed := RoomCode.parse_args(args)
	if parsed.is_empty():
		return false
	if not is_node_ready():
		_launch_pending = parsed  # not in the tree yet: _ready applies it
	else:
		_apply_launch(parsed)
	return true


## The game's own command-line flags that set match rules (C20): --light-trails turns
## light-trail mode on for this run's hosting. Never saved.
func take_launch_flags(args: PackedStringArray) -> void:
	if args.has(LIGHT_TRAILS_FLAG):
		light_trails_flag = true


func _apply_launch(parsed: Dictionary) -> void:
	if parsed.has("error"):
		_fail(parsed["error"])
	else:
		join_room(parsed["code"])


## Connects to what the player typed: "ip", "ip:port", "host", "host:port" or "[v6]:port".
## False, with `error` set, when that is not an address. The outcome comes through
## `changed`: JOINED, or FAILED with the reason.
func join(text: String) -> bool:
	if state != State.OFF and state != State.FAILED:
		return false
	_end_solo_sigstop()
	var parsed := parse_address(text, default_port())
	if parsed.is_empty():
		_fail(BAD_ADDRESS)
		return false
	address_text = text.strip_edges()
	_join_port = parsed["port"]
	_connect_left_ms = _t.connect_timeout_ms
	_refusal = ""
	error = ""
	players = {}
	_seq = 0
	fire_seq = 0
	if parsed["ip"]:
		_connect(parsed["host"])
	else:
		_resolve_name = parsed["host"]
		_resolve_item = IP.resolve_hostname_queue_item(_resolve_name, IP.TYPE_ANY)
		if _resolve_item < 0:
			_fail("couldn't look up %s" % _resolve_name)
			return false
		state = State.RESOLVING
	changed.emit()
	return state != State.FAILED


## Closes the socket: a host sends everyone away, a joiner leaves. Back to OFF.
func leave() -> void:
	if state == State.OFF:
		return
	_shut_peer()
	_clear_players()
	state = State.OFF
	error = ""
	notice = ""
	address_text = ""
	changed.emit()


func is_online() -> bool:
	return state == State.HOSTING or state == State.JOINED


## True while player `id` is in spawn protection, as this side knows it: hosting, the match's combat;
## joined, the host's last word (C31: a hole never drags a protected player on its own screen).
func protected_now(id: int) -> bool:
	if state == State.HOSTING and combat != null:
		return combat.protected(id)
	return protect_left.get(id, 0.0) > 0.0


func is_connecting() -> bool:
	return state == State.RESOLVING or state == State.CONNECTING or state == State.ROOM


## True while a host's room code registration is in flight, and only then.
func is_getting_room_code() -> bool:
	return _room_request == "register"


## The port a host listens on, or 0.
func listen_port() -> int:
	if state != State.HOSTING or _enet == null:
		return 0
	return _enet.host.get_local_port()


## The port a host opens and a join with none goes to (C16b): the settings' default port,
## or the tuning's while the player has left it alone.
func default_port() -> int:
	var chosen: int = GameSettings.current().value("multiplayer", "port")
	return chosen if chosen != 0 else tuning_in_use().port


## The display name from the settings (C16b), or "": a label on this player's own screen
## only. It never goes over the wire (the hello still carries the tuning's placeholder),
## and in a match every player is Daemon-<slot> (assigned_name, C14).
func display_label() -> String:
	var chosen: String = GameSettings.current().value("multiplayer", "display_name")
	return chosen if Tuning.name_ok(chosen) else ""


## The net stats overlay's numbers (C16b): the worst round trip in milliseconds and packet
## loss in percent over the connected peers, and how many there are; {} when not online.
func peer_stats() -> Dictionary:
	if _enet == null or not is_online():
		return {}
	var peers := multiplayer.get_peers()
	var rtt := 0.0
	var loss := 0.0
	var counted := 0
	for id in peers:
		var peer := _enet.get_peer(id)
		if peer == null:
			continue
		rtt = maxf(rtt, peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		loss = maxf(loss, peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / ENetPacketPeer.PACKET_LOSS_SCALE)
		counted += 1
	if counted == 0:
		return {}
	return {"rtt_ms": roundi(rtt), "loss_percent": snappedf(loss, 0.1), "peers": counted}


func my_name() -> String:
	return players.get(my_id, {}).get("name", "")


## The roster in slot order, "name" with "(you)" after this player's, "(you, <display
## name>)" once the player set one in the settings (C16b): a label on this screen only.
func roster_text() -> String:
	var slots := []
	for id in players:
		slots.append([players[id]["slot"], id])
	slots.sort()
	var parts := PackedStringArray()
	for pair in slots:
		var id: int = pair[1]
		var label := display_label()
		parts.append(players[id]["name"] + ((" (you, %s)" % label if label != "" else " (you)") if id == my_id else ""))
	return ", ".join(parts)


func state_word() -> String:
	return State.keys()[state].to_lower()


func _physics_process(delta: float) -> void:
	if _player_ready():
		_player.match_meter = is_online()  # in a match the meter fills only from the host's word
	if _rv != null and _rv.has_method("pump"):
		_rv.pump()  # a relay link's tunnel, both ways (C16d)
	match state:
		State.RESOLVING:
			_tick_resolve(delta)
		State.CONNECTING:
			_connect_left_ms -= delta * 1000.0
			if _connect_left_ms <= 0.0:
				_fail(CANT_REACH)
			else:
				_tick_join_probe(delta)
		State.ROOM:
			_tick_room_lookup(delta)
		State.HOSTING:
			_clock += delta
			_tick_room_code(delta)
			_tick_relay_host(delta)
			_tick_refused(delta)
			_tick_send(delta)
			_tick_trails(delta)
			_tick_daemons(delta)
			_tick_ice(delta)
			_tick_breakers(delta)
			for id in combat.tick_sigstop(delta):
				_send_sigstop(id)  # that SIGSTOP ran out on the host's clock
			combat.tick_sudo(delta)  # root running out on the host's clock (C22)
			_tick_flatlined()
			for id in combat.tick(delta):
				if _flat_round.has(id):
					combat.defer_respawn(id, RESPAWN_RETRY_S)  # flatlined by Black ICE: out until the round ends (I3)
				elif _arena == null or not is_instance_valid(_arena) or _player == null or not is_instance_valid(_player):
					combat.defer_respawn(id, RESPAWN_RETRY_S)  # no arena to choose a spawn in yet
				elif _clock - _attached_at < SPAWN_LOOK_S and _opponents_unseen(id):
					combat.defer_respawn(id, RESPAWN_RETRY_S)  # the arena just came back: wait for their positions
				else:
					_do_respawn(id)
			_mirror_from_combat()
			_tick_frost()
			_tick_protection(delta)
			_flush_sudo()  # kills, deaths, respawns and root's end this tick, told at once (C22)
			_tick_top(delta)
		State.JOINED:
			_tick_send(delta)
			_tick_trails(delta)
			_tick_protection(delta)


func _tick_resolve(delta: float) -> void:
	_connect_left_ms -= delta * 1000.0
	match IP.get_resolve_item_status(_resolve_item):
		IP.RESOLVER_STATUS_DONE:
			var found := IP.get_resolve_item_addresses(_resolve_item)
			IP.erase_resolve_item(_resolve_item)
			_resolve_item = -1
			var ip := ""
			for candidate in found:
				var text := String(candidate)
				if text.is_valid_ip_address() and (ip == "" or (text.count(":") == 0 and ip.count(":") > 0)):
					ip = text
			if ip == "":
				_fail("couldn't find %s" % _resolve_name)
			else:
				_connect(ip)
		IP.RESOLVER_STATUS_ERROR, IP.RESOLVER_STATUS_NONE:
			IP.erase_resolve_item(_resolve_item)
			_resolve_item = -1
			_fail("couldn't find %s" % _resolve_name)
		_:
			if _connect_left_ms <= 0.0:
				_fail(CANT_REACH)


func _tick_refused(delta: float) -> void:
	if _refused.is_empty():
		return
	var m := multiplayer as SceneMultiplayer
	for id in _refused.keys():
		_refused[id] -= delta * 1000.0
		if _refused[id] <= 0.0:
			_refused.erase(id)
			if m.get_authenticating_peers().has(id):
				m.disconnect_peer(id)


func _tick_send(delta: float) -> void:
	if players.size() < 2:
		_send_wait_s = 0.0
		return
	_send_wait_s -= delta
	if _send_wait_s > 0.0:
		return
	_send_wait_s += 1.0 / _t.sync_rate_hz
	_send_state()


# --- Room codes. ---

## Draws a code and asks the rendezvous to hold it for this room's game port.
func _register_room() -> void:
	var code := RoomCode.generate()
	_room_attempts += 1
	_room_port = listen_port()
	if not _rv.register(code, protocol, _room_port):
		notice = ROOM_NO_CODE % ROOM_UNREACHABLE
		return
	_room_request = "register"
	_room_wanted = code
	_room_left_ms = _rt.request_timeout_ms


func _tick_room_code(delta: float) -> void:
	if _room_request == "register":
		var done: Dictionary = _rv.poll()
		if done.is_empty():
			_room_left_ms -= delta * 1000.0
			if _room_left_ms <= 0.0:
				_rv.cancel()
				_rv.close(_room_wanted, protocol, _room_port)  # it may have been taken in all the same
				_room_request = ""
				notice = ROOM_NO_CODE % ROOM_UNREACHABLE
				changed.emit()
			return
		_room_request = ""
		if done.get("ok", false):
			var given = done.get("expires_in_s", 0)
			if not (given is int) or given <= 0:
				_rv.close(_room_wanted, protocol, _room_port)  # held for no time: release it
				notice = ROOM_NO_CODE % ROOM_BAD_REPLY
				changed.emit()
				return
			if done.get("relay", false) and not _take_relay_host(done):
				_rv.close(_room_wanted, protocol, _room_port)  # a relay answer without its ports
				notice = ROOM_NO_CODE % ROOM_BAD_REPLY
				changed.emit()
				return
			room_code = _room_wanted
			room_expires_s = float(mini(given, _rt.code_ttl_s))
			notice = ""
		elif done.get("error", "") == "taken" and _room_attempts < _rt.register_attempts:
			_register_room()  # someone holds that one: draw another
		else:
			if done.get("error", "") != "taken":
				# A timeout or an odd answer: the rendezvous may hold the code all the same.
				_rv.close(_room_wanted, protocol, _room_port)
			notice = ROOM_NO_CODE % _room_error_text(done)
		changed.emit()
	elif room_code != "":
		room_expires_s -= delta
		if room_expires_s <= 0.0:
			# One live code per room: the old one is released, then a fresh one drawn. A match
			# already running through the old relay room goes on there; only probes stop.
			_rv.close(room_code, protocol, _room_port)
			_relay_host = {}
			room_code = ""
			_room_attempts = 0
			_register_room()
			changed.emit()


func _tick_room_lookup(delta: float) -> void:
	var done: Dictionary = _rv.poll()
	if done.is_empty():
		_room_left_ms -= delta * 1000.0
		if _room_left_ms <= 0.0:
			_rv.cancel()
			_room_request = ""
			_fail(ROOM_UNREACHABLE)
		return
	_room_request = ""
	var code := _room_wanted
	if not done.get("ok", false):
		_fail(_room_error_text(done))
		return
	var address = done.get("address", "")
	var port = done.get("port", 0)
	if not (address is String) or not address.is_valid_ip_address() or not (port is int) or port < 1 or port > PORT_LAST:
		_fail(ROOM_BAD_REPLY)
		return
	if done.get("relay", false):
		# Through the relay the player set: only ever to that relay's own address.
		var token = done.get("token")
		if not _rv.has_method("relay_ip") or address != _rv.relay_ip() or not (token is PackedByteArray) or token.size() != RelayWire.TOKEN_SIZE:
			_fail(ROOM_BAD_REPLY)
			return
		_relay_join = {"ip": address, "port": port, "token": token}
	elif not local_address(address):
		_fail(ROOM_NOT_LOCAL)
		return
	state = State.OFF  # from here it is the C13 join, to the address the rendezvous gave
	if join(("[%s]:%d" if address.contains(":") else "%s:%d") % [address, port]):
		address_text = "room " + code


## What went wrong with a rendezvous request, for the screen.
func _room_error_text(done: Dictionary) -> String:
	match done.get("error", ""):
		"unknown":
			return ROOM_UNKNOWN % _room_wanted
		"expired":
			return ROOM_EXPIRED % _room_wanted
		"version":
			return "version mismatch: host %d, you %d" % [int(done.get("host_protocol", 0)), protocol]
		"busy":
			return ROOM_BUSY
		"taken":
			return ROOM_ALL_TAKEN
		"not_live":
			return NullRendezvous.NOT_LIVE
		"bad_reply":
			return ROOM_BAD_REPLY
	return ROOM_UNREACHABLE


## Stops any rendezvous request and releases this room's code, and a code whose
## registration was still unanswered (it may have been taken all the same).
func _end_room() -> void:
	if _rv == null:
		return
	if _room_request != "":
		_rv.cancel()
		if _room_request == "register":
			_rv.close(_room_wanted, protocol, _room_port)
	if room_code != "" and _rv.is_live():
		_rv.close(room_code, protocol, _room_port)
	_room_request = ""
	room_code = ""
	room_expires_s = 0.0
	_room_attempts = 0
	_relay_host = {}


## Keeps a relay registration's slot ports and host token, checked. False for an answer
## without them.
func _take_relay_host(done: Dictionary) -> bool:
	var ip = done.get("address", "")
	var ports = done.get("host_ports")
	var token = done.get("token")
	if not (ip is String) or not ip.is_valid_ip_address() or not (ports is PackedInt32Array) or ports.is_empty() or not (token is PackedByteArray) or token.size() != RelayWire.TOKEN_SIZE:
		return false
	for port in ports:
		if port < 1 or port > PORT_LAST:
			return false
	_relay_host = {"ip": ip, "ports": ports, "token": token}
	_relay_probe_left = 0.0
	return true


## Host through a relay: a probe to each slot port from the game's own ENet socket, now and
## every RELAY_PROBE_S, so the relay can forward each joiner's datagrams here.
func _tick_relay_host(delta: float) -> void:
	if _relay_host.is_empty() or _enet == null:
		return
	_relay_probe_left -= delta
	if _relay_probe_left > 0.0:
		return
	_relay_probe_left = RELAY_PROBE_S
	var probe := RelayWire.probe_bytes(RelayWire.Probe.HOST, _relay_host["token"])
	for port in _relay_host["ports"]:
		_enet.host.socket_send(_relay_host["ip"], port, probe)


## Joiner through a relay: a probe to the room's join port from the game's own ENet socket
## every JOIN_PROBE_S while it connects, so the relay lets its datagrams in.
func _tick_join_probe(delta: float) -> void:
	if _relay_join.is_empty() or _enet == null:
		return
	_join_probe_left -= delta
	if _join_probe_left > 0.0:
		return
	_join_probe_left = JOIN_PROBE_S
	_enet.host.socket_send(_relay_join["ip"], _relay_join["port"], RelayWire.probe_bytes(RelayWire.Probe.JOIN, _relay_join["token"]))


func _connect(ip: String) -> void:
	var enet := ENetMultiplayerPeer.new()
	_local_port = 0
	if _t.bind_address != "*":
		# ENet binds a joiner's socket to the bind address only with a local port named,
		# so one the system has just handed out on that address is taken.
		enet.set_bind_ip(_t.bind_address)
		_local_port = _spare_port()
		if _local_port == 0:
			_fail(CANT_REACH)
			return
	if enet.create_client(ip, _join_port, 0, 0, 0, _local_port) != OK:
		_fail(CANT_REACH)
		return
	_enet = enet
	multiplayer.multiplayer_peer = _enet
	my_id = multiplayer.get_unique_id()
	state = State.CONNECTING
	# Through a relay: the first probe goes out before ENet's own connect does.
	_join_probe_left = 0.0
	_tick_join_probe(0.0)
	changed.emit()


func _fail(message: String) -> void:
	_shut_peer()
	_clear_players()
	state = State.FAILED
	error = message
	changed.emit()


func _shut_peer() -> void:
	_end_room()
	if _resolve_item >= 0:
		IP.erase_resolve_item(_resolve_item)
		_resolve_item = -1
	_pending.clear()
	_refused.clear()
	_relay_join = {}
	if _enet != null:
		_enet.close()
		_enet = null
	if _rv != null and _rv.has_method("end_tunnel"):
		# A relay link's tunnel goes with the peer (C16d), after the peer's goodbye: ENet's
		# close has just put it on the loopback sockets, and it goes out before the link closes.
		_rv.pump()
		_rv.end_tunnel()
	if is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _clear_players() -> void:
	players = {}
	for id in avatars.keys():
		_drop_avatar(id)
	my_id = 1
	_send_wait_s = 0.0
	combat = null
	health = {}
	dead = {}
	protect_left = {}
	last_killer = {}
	last_killer_name = {}
	last_kill_word = {}
	last_kill_self = {}
	respawn_left = {}
	lives = {}
	_flat = {}
	_flat_round = {}
	_pending_spawn = Vector3.INF
	_pending_weapon = ""
	_roster_seen = false
	_weapons_synced = false
	_kept_inventory = null
	_sent_actions = 0
	_actions_from = {}
	_ammo_pending = {}
	_stop_word = []
	_chains = {}
	_volleys = {}
	for mine in _mines.values():
		if is_instance_valid(mine):
			mine.queue_free()  # the match is over: every job with it
	_mines = {}
	_jobs = {}
	_throws = 0
	_trails_rule = false
	LightTrails.drop(_arena)  # the match is over: every wall goes with it
	host_practice = true  # the next match's daemons are the old dummies until its host says (C27b)
	host_difficulty = "normal"
	host_ice = true
	_ice_wait_s = 0.0
	_told_rule = []
	_daemon_wait_s = 0.0
	root_left = {}
	_my_charges = 0
	_top_word = {}
	if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
		_player.set_alive(true)
	combat_changed.emit()


# --- The handshake. ---

func _on_authenticating(id: int) -> void:
	if state == State.CONNECTING and id == 1:
		(multiplayer as SceneMultiplayer).send_auth(1, hello_bytes(protocol, _t.display_name))


func _on_auth(id: int, data: PackedByteArray) -> void:
	if state == State.HOSTING:
		_host_auth(id, data)
	elif state == State.CONNECTING and id == 1:
		_joiner_auth(data)


func _host_auth(id: int, data: PackedByteArray) -> void:
	var m := multiplayer as SceneMultiplayer
	if not m.get_authenticating_peers().has(id) or _pending.has(id) or _refused.has(id):
		return
	var hello := parse_hello(data)
	var verdict := Verdict.OK
	if hello.is_empty() or hello["version"] != protocol:
		verdict = Verdict.VERSION
	elif players.size() + _pending.size() >= _t.max_players:
		verdict = Verdict.FULL
	if verdict != Verdict.OK:
		m.send_auth(id, reply_bytes(protocol, verdict, 0, ""))
		_refused[id] = REFUSE_GRACE_MS
		if verdict == Verdict.VERSION:
			notice = "refused a joiner: version mismatch, host %d, joiner %s" % [protocol, str(hello["version"]) if not hello.is_empty() else "unknown"]
		else:
			notice = "refused a joiner: host full"
		changed.emit()
		return
	var slot := _free_slot()
	var name := assigned_name(hello["name"], slot)
	_pending[id] = {"slot": slot, "name": name}
	m.send_auth(id, reply_bytes(protocol, Verdict.OK, slot, name))
	m.complete_auth(id)


func _joiner_auth(data: PackedByteArray) -> void:
	var reply := parse_reply(data)
	if reply.is_empty():
		_refusal = BAD_REPLY
		_fail(_refusal)
		return
	match reply["verdict"]:
		Verdict.OK:
			players[my_id] = {"slot": reply["slot"], "name": reply["name"]}
			(multiplayer as SceneMultiplayer).complete_auth(1)
		Verdict.VERSION:
			_refusal = "version mismatch: host %d, you %d" % [reply["version"], protocol]
			_fail(_refusal)
		_:
			_refusal = HOST_FULL
			_fail(_refusal)


func _on_auth_failed(id: int) -> void:
	if state == State.HOSTING:
		_pending.erase(id)
		_refused.erase(id)
	elif state == State.CONNECTING and id == 1:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _on_peer_connected(id: int) -> void:
	if state != State.HOSTING or not _pending.has(id):
		return
	players[id] = _pending[id]
	_pending.erase(id)
	_set_peer_timeout(id)
	_steady_loopback(id)
	combat.add_player(id)
	_actions_from[id] = 0
	_mirror_from_combat()
	_spawn_avatar(id)
	_send_roster()
	_send_sigstop(id)
	_send_walls(id)
	_send_mines(id)
	_send_sudo_all(id)
	changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING or not players.has(id):
		return
	players.erase(id)
	combat.remove_player(id)
	_actions_from.erase(id)
	for table in [health, dead, protect_left, last_killer, last_killer_name, last_kill_word, last_kill_self, respawn_left, lives, _flat, _flat_round]:
		table.erase(id)
	_drop_avatar(id)
	_drop_jobs(id)  # cron's jobs leave with their owner (C27)
	_send_roster()
	changed.emit()
	combat_changed.emit()


func _on_connected() -> void:
	if state != State.CONNECTING:
		return
	_set_peer_timeout(1)
	_steady_loopback(1)
	state = State.JOINED
	error = ""
	changed.emit()


func _on_connection_failed() -> void:
	if state == State.CONNECTING:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _on_server_disconnected() -> void:
	if state == State.JOINED:
		_fail(HOST_LEFT)
	elif state == State.CONNECTING:
		_fail(_refusal if _refusal != "" else CANT_REACH)


func _set_peer_timeout(id: int) -> void:
	if _enet == null or not multiplayer.get_peers().has(id):
		return
	_enet.get_peer(id).set_timeout(ENET_TIMEOUT_LIMIT, _t.peer_timeout_ms / 2, _t.peer_timeout_ms)


## Peer `id`'s link, when it is to this same machine: never throttled (C31: ENET_THROTTLE_INTERVAL_MS's
## note). ENet tells the other end too, so both ways run steady.
func _steady_loopback(id: int) -> void:
	if _enet == null or not multiplayer.get_peers().has(id):
		return
	var peer := _enet.get_peer(id)
	if peer != null and is_loopback(peer.get_remote_address()):
		peer.throttle_configure(ENET_THROTTLE_INTERVAL_MS, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)


## True for an address of this same machine: 127.x.x.x, ::1, or 127.x.x.x mapped into IPv6.
static func is_loopback(address: String) -> bool:
	return address.begins_with("127.") or address == "::1" or address.begins_with("::ffff:127.")


func _free_slot() -> int:
	var taken := {}
	for id in players:
		taken[players[id]["slot"]] = true
	for id in _pending:
		taken[_pending[id]["slot"]] = true
	var slot := 1
	while taken.has(slot):
		slot += 1
	return slot


# --- The roster and the state, host to joiners and joiners to host. ---

func _send_roster() -> void:
	var ids := PackedInt32Array()
	var slots := PackedInt32Array()
	var names := PackedStringArray()
	var healths := PackedFloat32Array()
	var deads := PackedByteArray()
	var protects := PackedFloat32Array()
	var life_numbers := PackedInt32Array()
	for id in players:
		ids.append(id)
		slots.append(players[id]["slot"])
		names.append(players[id]["name"])
		healths.append(combat.health_of(id))
		deads.append(0 if combat.alive(id) else 1)
		protects.append(combat.states[id]["protect_left"])
		life_numbers.append(lives.get(id, 0))
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_roster.rpc_id(id, ids, slots, names, healths, deads, protects, life_numbers)
	_send_rules()  # a new joiner learns the match's rules with its first roster


@rpc("authority", "call_remote", "reliable")
func _roster(ids: PackedInt32Array, slots: PackedInt32Array, names: PackedStringArray, healths: PackedFloat32Array, deads: PackedByteArray, protects: PackedFloat32Array, life_numbers: PackedInt32Array) -> void:
	if state != State.JOINED:
		return
	var n := ids.size()
	if n < 1 or n > _t.max_players or slots.size() != n or names.size() != n or healths.size() != n or deads.size() != n or protects.size() != n or life_numbers.size() != n:
		return
	var next := {}
	for i in n:
		if ids[i] < 1 or slots[i] < 1 or slots[i] > SLOT_LAST or not is_finite(healths[i]) or healths[i] < 0.0 or healths[i] > _ct.max_health or not is_finite(protects[i]) or protects[i] < 0.0 or life_numbers[i] < 0:
			return
		next[ids[i]] = {"slot": slots[i], "name": names[i] if Tuning.name_ok(names[i]) else assigned_name("", slots[i])}
	if not next.has(my_id) or not next.has(1):
		return
	players = next
	for i in n:
		health[ids[i]] = healths[i]
		dead[ids[i]] = deads[i] != 0
		protect_left[ids[i]] = protects[i]
		lives[ids[i]] = life_numbers[i]
	for table in [health, dead, protect_left, last_killer, last_killer_name, last_kill_word, last_kill_self, respawn_left, lives, _flat]:
		for id in table.keys():
			if not players.has(id):
				table.erase(id)
	for id in avatars.keys():
		if not players.has(id):
			_drop_avatar(id)
	for id in players:
		if id != my_id:
			_spawn_avatar(id)
			_show_avatar_state(id)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
		_player.set_alive(not dead.get(my_id, false))
	_roster_seen = true
	_sync_weapons()
	changed.emit()
	combat_changed.emit()


func _send_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_seq += 1
	var pos: Vector3 = _player.position
	var yaw: float = _player.rotation.y
	var pitch: float = _player.view_pitch() if _player.has_method("view_pitch") else 0.0
	var vel: Vector3 = _player.velocity if "velocity" in _player else Vector3.ZERO
	var life: int = lives.get(my_id, 0)
	var connected := multiplayer.get_peers()
	if state == State.HOSTING:
		var frost: int = combat.frost_bits(1) if combat != null else 0  # chmod 000's meter, the host's (C29)
		for id in players:
			if id != 1 and connected.has(id):
				_remote_state.rpc_id(id, 1, life, _seq, pos, yaw, pitch, vel, frost)
	elif connected.has(1):
		_state.rpc_id(1, _seq, life, pos, yaw, pitch, vel)
	sent += 1


## A joiner's own movement, to the host. Untyped on purpose: a packet of the wrong types
## is dropped here, never an engine error.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(seq: Variant, life: Variant, pos: Variant, yaw: Variant, pitch: Variant, vel: Variant) -> void:
	if state != State.HOSTING:
		return
	if typeof(seq) != TYPE_INT or typeof(life) != TYPE_INT or typeof(pos) != TYPE_VECTOR3 or typeof(yaw) != TYPE_FLOAT or typeof(pitch) != TYPE_FLOAT or typeof(vel) != TYPE_VECTOR3:
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 1 or not players.has(from) or not seq_sane(seq) or not sane(pos, yaw, pitch, vel):
		return
	# A dead player goes nowhere, and a position from a past life is a packet that was in
	# flight when the respawn happened.
	if combat != null and (not combat.alive(from) or life != lives.get(from, 0)):
		return
	received += 1
	_apply_remote(from, seq, pos, yaw, pitch, vel)
	var frost: int = combat.frost_bits(from) if combat != null else 0  # chmod 000's meter (C29)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and id != from and connected.has(id):
			_remote_state.rpc_id(id, from, life, seq, pos, yaw, pitch, vel, frost)
	# The player its own meter (C29): back to it while there is any, and once more when it is gone.
	if frost != 0 or _frost_told.get(from, 0) != 0:
		_remote_state.rpc_id(from, from, life, seq, pos, yaw, pitch, vel, frost)
	_frost_told[from] = frost


## A player's movement, from the host, with the host's word on its chmod 000 freeze meter (C29: the bits
## Frost packs). The word on this player's own meter comes the same way: only the meter is taken.
@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_state(id: int, life: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3, frost: int) -> void:
	if state != State.JOINED or not players.has(id) or (frost & ~Frost.BITS) != 0:
		return
	if id == my_id:
		if _player_ready() and _player.has_method("take_frost") and life == lives.get(my_id, 0):
			_player.take_frost(frost)
		return
	if not seq_sane(seq) or not sane(pos, yaw, pitch, vel):
		return
	if dead.get(id, false) or life != lives.get(id, 0):
		return
	received += 1
	_apply_remote(id, seq, pos, yaw, pitch, vel)
	var avatar = avatars.get(id)
	if avatar != null and is_instance_valid(avatar) and avatar.has_method("take_frost"):
		avatar.take_frost(frost)


func _apply_remote(id: int, seq: int, pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	var avatar = avatars.get(id)
	if avatar != null and is_instance_valid(avatar):
		avatar.push_sample(seq, pos, yaw, pitch, vel)


func _spawn_avatar(id: int) -> void:
	if _players_node == null or not is_instance_valid(_players_node) or avatars.has(id) or not players.has(id):
		return
	var avatar := RemotePlayer.new()
	avatar.name = "Player%d" % id
	avatar.player_id = id
	avatar.player_name = players[id]["name"]
	avatar.interp_delay_s = _t.interp_delay_ms / 1000.0
	avatar.extrapolate_max_s = _t.extrapolate_max_ms / 1000.0
	_players_node.add_child(avatar)
	avatars[id] = avatar
	_show_avatar_state(id)


## The avatar's health, death and protection as this side knows them.
func _show_avatar_state(id: int) -> void:
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar):
		return
	avatar.health = health.get(id, _ct.max_health)
	avatar.protected = protect_left.get(id, 0.0) > 0.0
	if avatar.has_method("set_root") and avatar.root != (root_left.get(id, 0.0) > 0.0):
		avatar.set_root(root_left.get(id, 0.0) > 0.0)  # an avatar made anew (an R reload) shows root too (C22)
	if dead.get(id, false) and not avatar.dead:
		avatar.hide_dead()


# --- Combat: intents in, the host's results out. ---

## Joiner, once: after the first roster (the host holds this player by then) and with a
## player here, weapons start fresh with slot 1 being drawn, and that draw goes to the host,
## so any draw sent before it held the player is undone and both sides wait the same swap.
## With the arena away it waits for the next one.
func _sync_weapons() -> void:
	if state != State.JOINED or not _roster_seen or _weapons_synced:
		return
	if _player == null or not is_instance_valid(_player) or not _player.has_method("reset_inventory"):
		return
	_weapons_synced = true
	_player.reset_inventory(true)
	_on_weapon_drawn(_player.weapon_tuning().id)


## A match starts with slot 1 drawn and every weapon full on this side, as the host counts.
func _reset_player_weapons() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("reset_inventory"):
		_player.reset_inventory()


## This player drew a weapon or started a reload: the host hears of it as of every shot.
## A joiner sends nothing about its weapons until their fresh start (_sync_weapons): what it
## did before the host held it is undone there on both sides.
func _on_weapon_drawn(weapon: String) -> void:
	if state == State.HOSTING:
		_handle_draw(1, lives.get(my_id, 0), weapon)
	elif state == State.JOINED and _weapons_synced and multiplayer.get_peers().has(1):
		_sent_actions += 1
		_draw.rpc_id(1, lives.get(my_id, 0), weapon)


func _on_reload_started(weapon: String) -> void:
	if state == State.HOSTING:
		_handle_reload(1, lives.get(my_id, 0), weapon)
	elif state == State.JOINED and _weapons_synced and multiplayer.get_peers().has(1):
		_sent_actions += 1
		_reload.rpc_id(1, lives.get(my_id, 0), weapon)


## A joiner drew a weapon, to the host. Untyped like _fire: wrong types are counted, never
## an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _draw(life: Variant, weapon: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING:
		combat.draw(0, 0, "", 0, _clock)  # counted: no such draw
	else:
		_handle_draw(multiplayer.get_remote_sender_id(), life, weapon.left(WEAPON_ID_LAST + 1))
	_ack_actions(multiplayer.get_remote_sender_id())


## A joiner started a reload, to the host.
@rpc("any_peer", "call_remote", "reliable")
func _reload(life: Variant, weapon: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING:
		combat.reload(0, 0, "", 0, _clock)  # counted: no such reload
	else:
		_handle_reload(multiplayer.get_remote_sender_id(), life, weapon.left(WEAPON_ID_LAST + 1))
	_ack_actions(multiplayer.get_remote_sender_id())


func _handle_draw(id: int, life: int, weapon: String) -> void:
	if state == State.HOSTING and combat != null:
		combat.draw(id if players.has(id) else 0, life, weapon, lives.get(id, 0), _clock)


func _handle_reload(id: int, life: int, weapon: String) -> void:
	if state == State.HOSTING and combat != null:
		combat.reload(id if players.has(id) else 0, life, weapon, lives.get(id, 0), _clock)


## One more weapon intent handled from `id`: the host's count of its magazines goes back to
## it with the number handled so far. The host's own player needs none: nothing lies between
## it and the host's count.
func _ack_actions(id: int) -> void:
	if id == 1 or not players.has(id):
		return
	_actions_from[id] = _actions_from.get(id, 0) + 1
	_send_ammo(id)


## The host's count of `id`'s magazine and reserve for every weapon that has one, to that
## player alone, with the intents handled from it so far.
func _send_ammo(id: int) -> void:
	if not multiplayer.get_peers().has(id):
		return
	combat.settle(id, _clock)  # a reload whose time is up counts as done
	var ids := PackedStringArray()
	var mags := PackedInt32Array()
	var reserves := PackedInt32Array()
	for def in _weapon_list:
		if def.has_magazine():
			var ammo: Array = combat.ammo_of(id, def.id)
			ids.append(def.id)
			mags.append(ammo[0])
			reserves.append(ammo[1])
	var s: Dictionary = combat.states.get(id, {})
	_ammo.rpc_id(id, lives.get(id, 0), _actions_from.get(id, 0), ids, mags, reserves, s.get("drawn", ""), s.get("reloading", ""), combat.reload_left(id, _clock), combat.draw_left(id, _clock))


## The host's count of this player's magazines once it has handled `handled` of this side's
## intents, with the weapon in hand, the reload it is running and the time left on that and
## on the draw: taken when that is all this side has sent in this life, else stale and
## dropped.
@rpc("authority", "call_remote", "reliable")
func _ammo(life: int, handled: int, ids: PackedStringArray, mags: PackedInt32Array, reserves: PackedInt32Array, drawn: String, reloading: String, reload_s: float, draw_s: float) -> void:
	if state != State.JOINED or life != lives.get(my_id, 0) or handled != _sent_actions:
		return
	if not is_finite(reload_s) or reload_s < 0.0 or reload_s > WeaponDefScript.RELOAD_LAST_S or not is_finite(draw_s) or draw_s < 0.0 or draw_s > ArsenalScript.SWAP_LAST_S:
		return
	if ids.size() != mags.size() or ids.size() != reserves.size() or ids.size() > _weapon_list.size():
		return
	for i in ids.size():
		var def = _weapons.get(ids[i])
		if def == null or not def.has_magazine() or mags[i] < 0 or mags[i] > def.magazine_size or (reserves[i] != WeaponDefScript.INFINITE and (reserves[i] < 0 or reserves[i] > def.reserve_ammo)):
			return
	var count := {"life": life, "handled": handled, "ids": ids, "mags": mags, "reserves": reserves, "drawn": drawn, "reloading": reloading, "reload_s": reload_s, "draw_s": draw_s}
	if _player != null and is_instance_valid(_player) and _player.has_method("take_ammo"):
		_apply_ammo(count)
	else:
		_ammo_pending = count  # the arena is away: the next player takes it


func _apply_ammo(count: Dictionary) -> void:
	for i in count["ids"].size():
		_player.take_ammo(count["ids"][i], count["mags"][i], count["reserves"][i], count["ids"][i] == count["reloading"])
	if _player.has_method("take_timing"):
		_player.take_timing(count["drawn"], count["reloading"], count["reload_s"], count["draw_s"])


## This player fired (scripts/player.gd): the intent goes to the host, which, when this is
## the host, is the same validation every other shot gets. Only the aim goes: the host
## draws a pellet weapon's pellets itself. A grep shot's claims go with it (C25): the player
## ids of its marks.
func _on_fire_intent(origin: Vector3, direction: Vector3, weapon: String) -> void:
	if not is_online() or _arena == null or not is_instance_valid(_arena):
		return
	if state == State.JOINED and not _weapons_synced:
		return  # the host does not count this player's weapons yet: the fresh start comes first
	fire_seq += 1
	var local_origin: Vector3 = _arena.to_local(origin)
	var local_dir: Vector3 = (_arena.global_transform.basis.inverse() * direction).normalized()
	var life: int = lives.get(my_id, 0)
	var marks := PackedInt32Array()
	if _weapons.has(weapon) and _weapons[weapon].is_seeker() and _player != null and is_instance_valid(_player) and _player.has_method("grep_claims"):
		marks = _player.grep_claims()
	if state == State.HOSTING:
		_handle_fire(1, fire_seq, life, weapon, local_origin, local_dir, marks)
	elif multiplayer.get_peers().has(1):
		_sent_actions += 1
		_fire.rpc_id(1, fire_seq, life, weapon, local_origin, local_dir, marks)


## A joiner's intent to fire, to the host. Untyped on purpose: a packet of the wrong types
## is dropped and counted here, never an engine error. `marks`: a grep shot's claims (C25),
## at most MARKS_LAST player ids, empty for every other shot.
@rpc("any_peer", "call_remote", "reliable")
func _fire(seq: Variant, life: Variant, weapon: Variant, origin: Variant, dir: Variant, marks: Variant = PackedInt32Array()) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(seq) != TYPE_INT or typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3 or typeof(marks) != TYPE_PACKED_INT32_ARRAY or marks.size() > WeaponDefScript.MARKS_LAST:
		combat.validate(0, 0, 0, "", Vector3.ZERO, Vector3.ZERO, Vector3.INF, 0, _clock)  # counted: no such shot
	else:
		_handle_fire(multiplayer.get_remote_sender_id(), seq, life, weapon.left(WEAPON_ID_LAST + 1), origin, dir, marks)
	_ack_actions(multiplayer.get_remote_sender_id())


## The one authority path: validate, draw the pellets, raycast each in the host's world,
## apply, tell everyone. `marks`: a grep shot's claims (C25).
func _handle_fire(shooter: int, seq: int, life: int, weapon: String, origin: Vector3, dir: Vector3, marks: PackedInt32Array = PackedInt32Array()) -> void:
	if state != State.HOSTING or combat == null:
		return
	if not players.has(shooter):
		combat.validate(0, seq, life, weapon, origin, dir, Vector3.INF, 0, _clock)  # counted: no such player
		return
	var eye := _eye_of(shooter)
	if not eye.is_finite():
		combat.validate(0, seq, life, weapon, origin, dir, eye, 0, _clock)  # counted: nothing of it is known yet
		return
	if combat.validate(shooter, seq, life, weapon, origin, dir, eye, lives.get(shooter, 0), _clock) != "":
		return
	var ice := IceDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if shooter != my_id and ice != null and ice.jammed(shooter, weapon):
		combat.drop_after(Combat.DROP_JAM)  # an ICE field jammed this weapon in its hand (I1)
		return
	var def: WeaponDefScript = combat.weapons[weapon]
	# Within the tolerance is not enough: a claimed origin the host's view of the eye
	# cannot see (behind cover it stands against) is a shot through that cover.
	if shooter != 1 and _obstructed(shooter, eye, origin, def.hit_mask):
		combat.drop_after(Combat.DROP_ORIGIN)
		return
	combat.accept(shooter, seq, weapon, _clock)
	var breakers := BreakerDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if breakers != null:
		breakers.fired(shooter)  # a shot ends the shooter's cloak (I2)
	if def.is_freeze():
		_beam_freeze(shooter, origin, dir, def)
		_flush_sudo()
		return
	if def.is_chain():
		_pipe_judge(shooter, origin, dir, def)
		_flush_sudo()
		return
	if def.is_ping():
		# ping (C28): the host sends the ring out from where it last heard the pinger and judges its
		# own daemons with it (one caught mid-tell staggers); every joiner draws the same ring from
		# the seed message, and only the pinger's own screen outlines what it meets. No new message.
		var center := _body_of(shooter)
		if not center.is_finite():
			center = origin
		_throws += 1
		_spawn_ping(_throws, shooter, weapon, center, true)
		_tell_seed(_throws, shooter, weapon, 0, center, dir)
		_flush_sudo()
		return
	if def.is_fork():
		# fork() (C24): the pellets fly as a volley the host runs and judges; every joiner
		# draws the same one from its seed.
		_throws += 1
		var shot_seed := _seeds.randi()
		_spawn_volley(_throws, shooter, weapon, shot_seed, origin, dir, true)
		_tell_seed(_throws, shooter, weapon, shot_seed, origin, dir)
		_flush_sudo()
		return
	if def.is_mine():
		# cron (C27): the host sticks the mine, owns its schedule and judges every run; every
		# joiner draws it from the seed message and each run's word. The crontab keeps its limit.
		var place := _mine_place(shooter, origin, dir, def)
		_throws += 1
		var left := def.runs_for(combat.root(shooter))
		_spawn_mine(_throws, shooter, weapon, place["at"], place["normal"], left, true, false)
		_tell_seed(_throws, shooter, weapon, left, place["at"], place["normal"])
		_crontab_trim(shooter, def)
		_flush_sudo()
		return
	if def.is_slug():
		# The rm -rf cannon (C26): the slug flies in the host's world and its blast is judged
		# here; every joiner draws it from the seed message and the blast word. No seed needed.
		_throws += 1
		_spawn_volley(_throws, shooter, weapon, 0, origin, dir, true)
		_tell_seed(_throws, shooter, weapon, 0, origin, dir)
		_flush_sudo()
		return
	if def.is_seeker():
		# grep (C25): the claims the host believes, then the darts as a volley the host runs and
		# judges; every joiner draws the same one from its seed and the believed marks.
		var believed := _accept_marks(shooter, origin, dir, def, marks)
		_throws += 1
		var dart_seed := _seeds.randi()
		_spawn_volley(_throws, shooter, weapon, dart_seed, origin, dir, true, believed)
		_tell_seed(_throws, shooter, weapon, dart_seed, origin, dir, believed)
		_flush_sudo()
		return
	# Every pellet's damage after its falloff, added up per player it struck; the rail's one
	# line through every player on it.
	var ends := PackedVector3Array()
	var struck := {}
	# A joiner's shot at a daemon while they fight (C27b): the host's daemons are the match's, and
	# here is where every shot at one is judged (the host's own already landed on its arena).
	var at_daemons := shooter != 1 and daemons_fight()
	var from_world: Vector3 = _arena.to_global(origin)
	# Root (C22): every hit damage_scale times harder; the meter's share is the hit at user's
	# strength (the same as before C22 for a user), so root fills it no faster.
	var scale := combat.damage_scale(shooter)
	if def.pierce:
		var line := _rail_trace(shooter, origin, dir, def)
		ends.append(line["end"])
		_shoot_mines(shooter, origin, line["end"], true)  # every mine on the line (C27)
		for victim in line["hits"]:
			struck[victim] = def.damage
		if at_daemons:
			for pair in line["daemons"]:
				_hit_daemon(pair[0], shooter, def.damage_at(from_world.distance_to(pair[1])) * scale, pair[1], (_arena.global_transform.basis * dir).normalized(), weapon)
	else:
		# While the host says the shooter's SIGSTOP is on, every pellet flies straight (C18).
		var steady := combat.sigstop_on(shooter)
		for pellet in (def.steady_directions(dir) if steady else def.pellet_directions(dir, _pellets_rng)):
			var ray := _raycast(shooter, origin, pellet, def)
			ends.append(ray["end"])
			_shoot_mines(shooter, origin, ray["end"], false)  # the first mine on its way (C27)
			if ray["hit"] != 0:
				struck[ray["hit"]] = struck.get(ray["hit"], 0.0) + def.damage_at(ray["distance"])
			elif at_daemons and ray["daemon"] != null:
				_hit_daemon(ray["daemon"], shooter, def.damage_at(ray["distance"]) * scale, _arena.to_global(ray["end"]), (_arena.global_transform.basis * pellet).normalized(), weapon)
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for victim in struck:
		var before := combat.health_of(victim)
		var outcome := combat.damage_player(victim, shooter, struck[victim] * scale)
		if outcome.is_empty():
			continue  # dead or protected: the pellets landed on nothing that counts
		hits.append(victim)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(victim)
		if not def.is_ult():
			combat.add_meter(shooter, minf(struck[victim], before) / _ct.max_health, outcome["killed"])
	# The death is told after the shot, so the mirror learns of it then: the avatar must
	# play its derezz, not be hidden first by the health update.
	_broadcast_shot(shooter, weapon, origin, ends, hits, healths)
	for victim in killed:
		_broadcast_death(victim, shooter, dir, weapon)
	_mirror_from_combat()
	_flush_sudo()


## chmod 000's beam tick (C29), believed: the host's own ray from the shooter's origin along its aim to the
## beam's reach. A player it meets takes the tick's seconds of beam in the match's combat (never a dead or
## spawn-protected one); a joiner's beam on the host's daemons and ICE, while they fight, lands here as its
## shots do (the host's own already landed on its arena), Black ICE only slowed. Every screen draws the
## tick from the shot message: no damage, no hits, no feed. No new message.
func _beam_freeze(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> void:
	beam_ticks_judged += 1
	var ray := _raycast(shooter, origin, dir, def)
	if ray["hit"] != 0:
		if combat.chill_player(ray["hit"], def.fire_cooldown):
			freezes_judged += 1
	elif shooter != 1 and daemons_fight() and ray["daemon"] != null and ray["daemon"].has_method("chill"):
		var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
		if ray["daemon"].chill(def.fire_cooldown, _arena.to_global(ray["end"]), along, def.id) == true:
			freezes_judged += 1
	_broadcast_shot(shooter, def.id, origin, PackedVector3Array([ray["end"]]), PackedInt32Array(), PackedFloat32Array())


## A chain of pipe | (C30), believed: the host's own player's is the chain it built and drew this frame
## (pipe_last(): its own daemons and ICE took their links there); a joiner's is built here from its aim, in
## the host's world, over the host's daemons and ICE and every other player's body. Every player on it
## takes its link in the match's combat (never a dead or spawn-protected one: neither is ever a link);
## while the daemons fight, a joiner's links on them and on ICE land here as its shots do (Black ICE, hit
## first, only flashed). The aim's ray removes the first cron mine on its way, as any shot's does (C27). Told
## as any shot: the chain's points as the shot's ends, the struck players and their health, then the
## deaths.
func _pipe_judge(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> void:
	if state != State.HOSTING or combat == null:
		return
	chains_judged += 1
	var from: Vector3 = _arena.to_global(origin)
	var links: Array = []
	var ray := _raycast(shooter, origin, dir, def)
	var miss: Vector3 = _arena.to_global(ray["end"])
	_shoot_mines(shooter, origin, ray["end"], false)  # the first mine on the aim's way, as a shot's (C27)
	if shooter == 1 and _player_ready() and _player.has_method("pipe_last"):
		links = _player.pipe_last()
	else:
		var first := {}
		if ray["hit"] != 0:
			if combat.alive(ray["hit"]) and not combat.protected(ray["hit"]):
				first = _pipe_player(ray["hit"])
		elif ray["daemon"] != null:
			first = PipeChain.target_of(ray["daemon"])
		var pool := PipeChain.pool_in(_arena)
		for id in players:
			if id != shooter and combat.alive(id) and not combat.protected(id):
				var target := _pipe_player(id)
				if not target.is_empty():
					pool.append(target)
		links = PipeChain.build(first, miss, pool, _pipe_sight, def.pipe_tuning(), def.damage, combat.root(shooter))
	last_judged = links
	var at_daemons := shooter != 1 and daemons_fight()
	var scale := combat.damage_scale(shooter)
	var ends := PackedVector3Array()
	var struck := {}
	var before_point := from
	for link in links:
		var point: Vector3 = link["point"]
		ends.append(_arena.to_local(point))
		if link["kind"] == PipeChain.Kind.PLAYER:
			struck[link["id"]] = struck.get(link["id"], 0.0) + float(link["damage"])
		elif at_daemons and is_instance_valid(link["node"]):
			_hit_daemon(link["node"], shooter, float(link["damage"]) * scale, point, (point - before_point).normalized(), def.id)
		before_point = point
	if ends.is_empty():
		ends = PackedVector3Array([_arena.to_local(miss), _arena.to_local(miss)])  # a miss: its end, twice
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for victim in struck:
		var before := combat.health_of(victim)
		var outcome := combat.damage_player(victim, shooter, struck[victim] * scale)
		if outcome.is_empty():
			continue
		hits.append(victim)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(victim)
		combat.add_meter(shooter, minf(struck[victim], before) / _ct.max_health, outcome["killed"])
	_broadcast_shot(shooter, def.id, origin, ends, hits, healths)
	for victim in killed:
		_broadcast_death(victim, shooter, dir, def.id)
	_mirror_from_combat()


## Player `id` as a chain's target, by the body the host sees: its own player, or that player's avatar
## ({} for one not shown).
func _pipe_player(id: int) -> Dictionary:
	var name: String = players[id]["name"] if players.has(id) and players[id].has("name") else PLACEHOLDER
	if id == 1:
		return PipeChain.player_target(_player, 1, name) if _player_ready() else {}
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return {}
	return PipeChain.player_target(avatar, id, name)


## True when nothing of the level lies between `a` and `b` (world space): a chain never arcs through a wall.
func _pipe_sight(a: Vector3, b: Vector3) -> bool:
	return _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, BLAST_SIGHT_MASK)).is_empty()


## The host's word on every player's freeze meter (C29), on its own screen: its own player and every
## avatar, from the match's combat each step.
func _tick_frost() -> void:
	if combat == null:
		return
	if _player_ready() and _player.has_method("take_frost"):
		_player.take_frost(combat.frost_bits(1))
	for id in avatars:
		var avatar = avatars[id]
		if avatar != null and is_instance_valid(avatar) and avatar.has_method("take_frost"):
			avatar.take_frost(combat.frost_bits(id))


## This player threw a fork bomb (C19): the request goes to the host, which, when this is the
## host, is the same check every other player's throw gets. Only the throw goes: the host
## runs the chain.
func _on_throw_intent(origin: Vector3, direction: Vector3, weapon: String) -> void:
	if not is_online() or _arena == null or not is_instance_valid(_arena):
		return
	if state == State.JOINED and not _weapons_synced:
		return  # the host does not count this player's weapons yet
	var local_origin: Vector3 = _arena.to_local(origin)
	var local_dir: Vector3 = (_arena.global_transform.basis.inverse() * direction).normalized()
	var life: int = lives.get(my_id, 0)
	if state == State.HOSTING:
		_handle_throw(1, life, weapon, local_origin, local_dir)
	elif multiplayer.get_peers().has(1):
		_sent_actions += 1
		_throw.rpc_id(1, life, weapon, local_origin, local_dir)


## A joiner's throw, to the host. Untyped like _fire: wrong types are counted, never an
## engine error.
@rpc("any_peer", "call_remote", "reliable")
func _throw(life: Variant, weapon: Variant, origin: Variant, dir: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(weapon) != TYPE_STRING or typeof(origin) != TYPE_VECTOR3 or typeof(dir) != TYPE_VECTOR3:
		combat.throw(0, 0, "", Vector3.ZERO, Vector3.ZERO, Vector3.INF, Vector3.ZERO, 0, _clock, 0)  # counted: no such throw
	else:
		_handle_throw(multiplayer.get_remote_sender_id(), life, weapon.left(WEAPON_ID_LAST + 1), origin, dir)
	_ack_actions(multiplayer.get_remote_sender_id())


## The host's check of a throw, then the chain: run here, judged here, told to everyone.
func _handle_throw(id: int, life: int, weapon: String, origin: Vector3, dir: Vector3) -> void:
	if state != State.HOSTING or combat == null:
		return
	var eye := _eye_of(id) if players.has(id) else Vector3.INF
	if not eye.is_finite():
		combat.throw(0, life, weapon, origin, dir, eye, Vector3.ZERO, 0, _clock, 0)  # counted: nothing known of it
		return
	if id != 1 and origin.is_finite() and _obstructed(id, eye, origin, BLAST_SIGHT_MASK):
		combat.drop_after(Combat.DROP_ORIGIN)  # a throw from behind the cover it stands against
		return
	var thrown = _weapons.get(weapon)
	var live := DevNullHoleScript.live_of(_arena, _bomb_key(id)) if thrown != null and thrown.is_hole() else ForkBomb.live_of(_arena, _bomb_key(id))
	if combat.throw(id, life, weapon, origin, dir, eye, _view_of(id), lives.get(id, 0), _clock, live) != "":
		return
	var breakers := BreakerDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if breakers != null:
		breakers.fired(id)  # a throw ends the thrower's cloak (I2)
	_throws += 1
	var seed := _seeds.randi()
	if thrown.is_hole():
		seed = (seed & 0x3fffffff) + 1
		seed = -seed if combat.root(id) else seed  # /dev/null (C31): a root's wider hole, told in the seed's sign
	_spawn_chain(_throws, id, weapon, seed, origin, dir, true)
	_tell_seed(_throws, id, weapon, seed, origin, dir)


## A seeded spawn the host believed, to every joiner (or `only` that one): a fork bomb's throw, a
## fork() shot (C24), a grep shot with the marks it believed (C25), an rm -rf shot (C26) or a cron
## mine (C27: its seed the runs left, negative once past its arm delay).
func _tell_seed(throw_id: int, thrower: int, weapon: String, seed: int, origin: Vector3, dir: Vector3, marks := PackedInt32Array(), only := 0) -> void:
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer) and (only == 0 or peer == only):
			_bomb.rpc_id(peer, throw_id, thrower, weapon, seed, origin, dir, marks)


## A throw, a fork() shot or a grep shot the host believed, to every joiner: its seed, so its
## screen draws the same chain, the same pellets (C24) or the same darts on the same marks
## (C25: `marks` the player ids the host believed, empty for the others).
@rpc("authority", "call_remote", "reliable")
func _bomb(throw_id: int, thrower: int, weapon: String, seed: int, origin: Vector3, dir: Vector3, marks: PackedInt32Array) -> void:
	if state != State.JOINED or not players.has(thrower) or not _weapons.has(weapon) or not (_weapons[weapon].is_thrown() or _weapons[weapon].is_volley() or _weapons[weapon].is_ping()):
		return
	if throw_id < 1 or _chains.has(throw_id) or _holes.has(throw_id) or _volleys.has(throw_id) or _mines.has(throw_id) or not origin.is_finite() or not Combat.dir_ok(dir) or _arena == null or not is_instance_valid(_arena):
		return
	# A believed mark of a player who has left since flies its dart straight (_mark_point), so
	# the darts stay as many as the host's and fan the same.
	if marks.size() > WeaponDefScript.MARKS_LAST or (not marks.is_empty() and not _weapons[weapon].is_seeker()):
		return
	if _weapons[weapon].is_ping():
		_spawn_ping(throw_id, thrower, weapon, origin, false)  # its ring from where the host heard the pinger (C28)
		return
	if _weapons[weapon].is_mine():
		var left: int = absi(seed)
		if left < 1 or left > WeaponDefScript.RUNS_LAST + WeaponDefScript.ROOT_EXTRA_RUNS_LAST or _mines.has(throw_id):
			return
		_spawn_mine(throw_id, thrower, weapon, origin, dir, left, false, seed < 0)
	elif _weapons[weapon].is_fork() or _weapons[weapon].is_slug():
		_spawn_volley(throw_id, thrower, weapon, seed, origin, dir, false)
	elif _weapons[weapon].is_seeker():
		_spawn_volley(throw_id, thrower, weapon, seed, origin, dir, false, marks)
	else:
		_spawn_chain(throw_id, thrower, weapon, seed, origin, dir, false)


## A blast of a throw, from the host: where, which generation and which bomblet of it.
@rpc("authority", "call_remote", "reliable")
func _blast(throw_id: int, gen: int, index: int, at: Vector3) -> void:
	if state != State.JOINED or not at.is_finite():
		return
	if _mines.has(throw_id):
		_mine_word(throw_id, gen, index, at)  # a cron mine's run or removal (C27)
		return
	if _holes.has(throw_id):
		_hole_word(throw_id, gen, at)  # /dev/null's opening, collapse or discard (C31)
		return
	if _volleys.has(throw_id):
		# The blast of an rm -rf slug (C26): its slug here goes off at the host's place.
		var slug = _volleys[throw_id]
		if gen == 0 and index == 0 and is_instance_valid(slug) and slug.has_method("apply_blast"):
			slug.apply_blast(_arena.to_global(at))
		return
	if not _chains.has(throw_id):
		return
	var held: Dictionary = _chains[throw_id]
	if is_instance_valid(held["chain"]):
		held["chain"].apply_blast(gen, index, _arena.to_global(at))
	if gen == 0 and held["thrower"] == my_id and _player_ready():
		_player.fork_bomb_burst.emit()


## A chain in this arena: the host's, which decides (fuses, contacts, the judge), or a
## joiner's, which only draws on the host's word. The thrower's own body is never hit.
func _spawn_chain(throw_id: int, thrower: int, weapon: String, seed: int, origin: Vector3, dir: Vector3, deciding: bool) -> void:
	var def: WeaponDefScript = _weapons[weapon]
	if def.is_hole():
		_spawn_hole(throw_id, thrower, weapon, seed, origin, dir, deciding)  # /dev/null (C31): its own throw
		return
	var never: Array[RID] = []
	if thrower == my_id and _player != null and is_instance_valid(_player):
		never.append(_player.get_rid())
	var avatar = avatars.get(thrower)
	if avatar != null and is_instance_valid(avatar):
		never.append(avatar.hit_rid())
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var judge := _judge_blast.bind(thrower, weapon) if deciding else Callable()
	var chain := ForkBomb.spawn(_arena, def.projectile, _arena.to_global(origin), ForkBomb.throw_velocity(def.projectile, along), seed, _bomb_key(thrower), deciding, def.light_skin, never, judge)
	chain.target_mask = PLAYER_LAYER_MASK | RemotePlayer.HIT_LAYER
	_chains[throw_id] = {"chain": chain, "thrower": thrower}
	chain.finished.connect(func(): _chains.erase(throw_id))
	if deciding:
		chain.blasted.connect(_on_chain_blasted.bind(throw_id, thrower))


## /dev/null's hole in this arena (C31): the host's decides (it opens, judges every player it reaches and,
## while the daemons fight, a joiner's hole's hold on them) and tells its opening, its collapse and each
## discard; a joiner's draws, opens at the host's place, drags its own player and takes the host's word for
## the rest. The seed's sign is the thrower's root (a wider hole). The thrower's own screen moves and hurts
## its own idle dummies in a match whose daemons do not fight, as pipe | does (C30).
func _spawn_hole(throw_id: int, thrower: int, weapon: String, seed: int, origin: Vector3, dir: Vector3, deciding: bool) -> void:
	var def: WeaponDefScript = _weapons[weapon]
	var never: Array[RID] = []
	if thrower == my_id and _player != null and is_instance_valid(_player):
		never.append(_player.get_rid())
	var avatar = avatars.get(thrower)
	if avatar != null and is_instance_valid(avatar):
		never.append(avatar.hit_rid())
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var own: bool = thrower == my_id and _player_ready() and _player.has_method("hole_judge")
	var judge_daemon := Callable()
	if own:
		judge_daemon = _player.hole_judge(def)
	elif deciding:
		judge_daemon = func(node: Node, damage: float, point: Vector3, way: Vector3) -> bool:
			return _hit_daemon(node, thrower, damage * combat.damage_scale(thrower), point, way, def.id)
	var moves: bool = own or (deciding and daemons_fight())
	var judge_players := _judge_hole.bind(throw_id, thrower, weapon) if deciding else Callable()
	var tuning: DevNullTuning = def.hole_tuning()
	var hole := DevNullHoleScript.spawn(_arena, tuning, _arena.to_global(origin), DevNullHoleScript.throw_velocity(tuning, along), absi(seed), _bomb_key(thrower), deciding, thrower, seed < 0, def.light_skin, never, judge_daemon, judge_players, moves)
	hole.target_mask = PLAYER_LAYER_MASK | RemotePlayer.HIT_LAYER
	_holes[throw_id] = hole
	hole.finished.connect(func(): _holes.erase(throw_id))
	if deciding:
		hole.opened.connect(func(at: Vector3): _tell_blast(throw_id, HOLE_OPENED, 0, _arena.to_local(at)))
		hole.collapsed.connect(func(at: Vector3): _tell_blast(throw_id, HOLE_COLLAPSED, 0, _arena.to_local(at)))
		hole.discarded.connect(func(_what: Node, at: Vector3): _tell_blast(throw_id, HOLE_DISCARDED, hole.discards, _arena.to_local(at)))
	if thrower == my_id and _player_ready() and _player.has_method("take_hole"):
		_player.take_hole(hole)


## The host's word of hole `id` (C31): opened at `at` (arena space), collapsed, or something discarded there.
func _hole_word(id: int, gen: int, at: Vector3) -> void:
	var hole = _holes[id]
	if not is_instance_valid(hole):
		return
	match gen:
		HOLE_OPENED:
			hole.open_at(_arena.to_global(at))
		HOLE_COLLAPSED:
			hole.collapse_now()
		HOLE_DISCARDED:
			hole.told_discard(_arena.to_global(at))


## The host's judgement of hole `hole` of `thrower`'s for every player it reaches (C31), every tick ("tick")
## and at its implosion ("pulse"): never the thrower, a dead or a spawn-protected player. Held inside the
## horizon a player takes the hole's damage a second for its distance, its tick's share; reaching the core
## it is discarded (the discard's damage: far over any health), once; the implosion's pulse for its distance
## from the core. Told as shots of /dev/null at the core, each kill as a death by it.
func _judge_hole(hole: Node, what: String, throw_id: int, thrower: int, weapon: String) -> void:
	if state != State.HOSTING or combat == null or _player == null or not is_instance_valid(_player) or not is_instance_valid(hole):
		return
	var t: DevNullTuning = hole.tuning
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for id in players:
		if id == thrower or not combat.alive(id) or combat.protected(id):
			continue
		var middle := Vector3.INF
		if id == 1:
			middle = _player.global_position
		else:
			var avatar = avatars.get(id)
			if avatar != null and is_instance_valid(avatar) and avatar.visible:
				middle = _arena.to_global(avatar.latest_position())
		if not middle.is_finite():
			continue
		var reach: Dictionary = hole.reaches(middle, space)
		if not reach["in"]:
			continue
		var base := 0.0
		var discard := false
		if what == "pulse":
			base = t.pulse_at(middle.distance_to(hole.core))
		elif reach["distance"] <= t.core_m and not hole.players_discarded.has(id):
			hole.players_discarded[id] = true
			base = t.discard_damage
			discard = true
		elif reach["distance"] < t.horizon_m:
			base = t.dps_at(reach["distance"]) * t.tick_s
		if base <= 0.0:
			continue
		var before := combat.health_of(id)
		var outcome := combat.damage_player(id, thrower, base * combat.damage_scale(thrower))  # root's harder (C22)
		if outcome.is_empty():
			continue
		hits.append(id)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(id)
		combat.add_meter(thrower, minf(base, before) / _ct.max_health, outcome["killed"])
		if discard:
			hole.told_discard(hole.core)  # its discarded signal tells every joiner
	if hits.is_empty():
		return
	var local: Vector3 = _arena.to_local(hole.core)
	_broadcast_shot(thrower, weapon, local, PackedVector3Array([local]), hits, healths)
	for victim in killed:
		_broadcast_death(victim, thrower, Vector3.UP, weapon)
	_mirror_from_combat()
	_flush_sudo()


## A blast of a chain the host runs, to every joiner; the thrower's callout when it is the
## host's own first.
func _on_chain_blasted(gen: int, index: int, at: Vector3, throw_id: int, thrower: int) -> void:
	_tell_blast(throw_id, gen, index, _arena.to_local(at))
	if gen == 0 and thrower == my_id and _player_ready():
		_player.fork_bomb_burst.emit()


## A blast the host's world saw, to every joiner: a fork bomb's (its generation and index) or an
## rm -rf slug's (C26, generation 0, index 0), `local` in arena space.
func _tell_blast(throw_id: int, gen: int, index: int, local: Vector3) -> void:
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer):
			_blast.rpc_id(peer, throw_id, gen, index, local)


## The host's judgement of one blast (`at`, world space) of `thrower`'s chain: every living
## player but the thrower whose body's middle is within the blast's radius with nothing of
## the level in between takes the tuning's damage for its distance; told as a shot of the
## fork bomb, and each kill as a death by it.
func _judge_blast(_gen: int, _index: int, at: Vector3, thrower: int, weapon: String) -> void:
	if state != State.HOSTING or combat == null or _player == null or not is_instance_valid(_player):
		return
	var tuning: Resource = _weapons[weapon].projectile
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for id in players:
		if id == thrower or not combat.alive(id):
			continue
		var middle := Vector3.INF
		if id == 1:
			middle = _player.global_position
		else:
			var avatar = avatars.get(id)
			if avatar != null and is_instance_valid(avatar) and avatar.visible:
				middle = _arena.to_global(avatar.latest_position())
		if not middle.is_finite():
			continue
		var base: float = tuning.damage_at(at.distance_to(middle))
		var amount: float = base * combat.damage_scale(thrower)  # root's harder blasts (C22)
		if amount <= 0.0:
			continue
		var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, middle, BLAST_SIGHT_MASK)
		if not space.intersect_ray(sight).is_empty():
			continue  # a wall between: the blast does not reach
		var before := combat.health_of(id)
		var outcome := combat.damage_player(id, thrower, amount)
		if outcome.is_empty():
			continue
		hits.append(id)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(id)
		combat.add_meter(thrower, minf(base, before) / _ct.max_health, outcome["killed"])
	_blast_mines(thrower, at, tuning.radius_m)  # a blast reaching another player's mine removes it (C27)
	_blast_daemons(at, thrower, func(dist: float) -> float: return tuning.damage_at(dist), weapon)  # and the daemons while they fight (C27b)
	if hits.is_empty():
		return
	var local: Vector3 = _arena.to_local(at)
	_broadcast_shot(thrower, weapon, local, PackedVector3Array([local]), hits, healths)
	for victim in killed:
		_broadcast_death(victim, thrower, Vector3.UP, weapon)
	_mirror_from_combat()
	_flush_sudo()


## A fork() shot's volley in this arena (C24), from `origin` along `dir` (arena space) with
## `shot_seed`. It forks once more while `shooter` is root: on the host by its own count, on a
## joiner by the host's last word, which always arrives before any shot judged after it.
## `deciding` (the host's): judges every pellet that meets a player. This player's own shot is
## handed to it (its callout, its shot count, its own dummies). A grep shot's darts (C25) go the
## same way, one homing on each of `marks` (player ids) as this side sees it, or one straight.
func _spawn_volley(shot_id: int, shooter: int, weapon: String, shot_seed: int, origin: Vector3, dir: Vector3, deciding: bool, marks := PackedInt32Array()) -> void:
	var def: WeaponDefScript = _weapons[weapon]
	var root: bool = combat.root(shooter) if deciding and combat != null else root_left.get(shooter, 0.0) > 0.0
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var mine: bool = shooter == my_id and _player_ready()
	var judge := Callable()
	if deciding:
		judge = _judge_pellet.bind(shooter, weapon, origin)
	elif mine:
		judge = _player.fork_hit.bind(def)  # this machine's own dummies, never a player
	var volley: Node3D
	# The host's volleys meet the mines' layer too: a pellet, dart or slug that meets another
	# player's mine removes it (C27); a joiner's only draw and pass them.
	var mask: int = def.hit_mask | PLAYER_LAYER_MASK | (CronMine.MINE_LAYER if deciding else 0)
	if def.is_slug():
		# The rm -rf cannon (C26): the host's slug judges its blast; a joiner's only draws it and
		# goes off on the host's word (_blast).
		var blast := _judge_slug_blast.bind(shooter, weapon, root) if deciding else Callable()
		volley = RmSlug.spawn(_arena, def, _arena.to_global(origin), along, root, deciding, mask, _pellets_past.bind(shooter), blast)
		if deciding:
			volley.blasted.connect(_on_slug_blasted.bind(shot_id))
	elif def.is_seeker():
		var points := []
		for id in marks:
			points.append(_mark_point.bind(id))
		volley = SeekerVolley.spawn(_arena, def, _arena.to_global(origin), along, shot_seed, points, deciding, mask, _pellets_past.bind(shooter), judge)
	else:
		volley = ForkVolley.spawn(_arena, def, _arena.to_global(origin), along, shot_seed, def.forks_for(root), deciding, mask, _pellets_past.bind(shooter), judge)
	_volleys[shot_id] = volley
	volley.finished.connect(_on_volley_finished.bind(shot_id))
	if mine:
		_player.take_volley(volley)


func _on_volley_finished(_landed: int, shot_id: int) -> void:
	_volleys.erase(shot_id)


## A ping's ring in this arena (C28), id `id` of `pinger`, from `at` (arena space, the pinger's
## middle as the host heard it): the host's decides (its daemons caught mid-tell stagger), a
## joiner's only draws; this player's own outlines what it meets. Kept with the volleys until done.
func _spawn_ping(id: int, pinger: int, weapon: String, at: Vector3, deciding: bool) -> void:
	var center: Vector3 = _arena.to_global(at)
	var mine: bool = pinger == my_id and _player_ready()
	var pulse := PingPulseScript.spawn(_arena, _weapons[weapon], center, center.y - FEET_M, deciding, mine)
	_volleys[id] = pulse
	pulse.finished.connect(_on_volley_finished.bind(id))
	if mine:
		_player.last_ping = pulse


## Where `shooter`'s mine sticks (C27): the host's view of its aim from `origin` along `dir` (arena
## space) meeting the level within the placement range, else the floor under the host's view of
## its body. {at, normal}, arena space.
func _mine_place(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> Dictionary:
	var basis: Basis = _arena.global_transform.basis
	var body: Vector3 = _player.global_position if shooter == 1 else _arena.to_global(avatars[shooter].latest_position()) if avatars.has(shooter) and is_instance_valid(avatars[shooter]) else _arena.to_global(origin)
	var place := CronMine.place(_player.get_world_3d().direct_space_state, _arena.to_global(origin), (basis * dir).normalized(), def.place_range_m, body, FEET_M)
	return {"at": _arena.to_local(place["at"]), "normal": (basis.inverse() * (place["normal"] as Vector3)).normalized()}


## A cron mine in this arena (C27), id `id` of `owner`, at `at` stuck with `normal` (arena space),
## `left` runs to come: the host's, which keeps the schedule and judges each run, or a joiner's,
## which draws and runs on the host's word (`armed`: already past its arm delay). This player's own
## is handed to it, for the strip's count and the callout.
func _spawn_mine(id: int, owner: int, weapon: String, at: Vector3, normal: Vector3, left: int, deciding: bool, armed: bool) -> void:
	var def: WeaponDefScript = _weapons[weapon]
	var judge := _judge_slug_blast.bind(owner, weapon, false) if deciding else Callable()
	var mine := CronMine.spawn(_arena, def, _arena.to_global(at), (_arena.global_transform.basis * normal).normalized(), id, owner, left, deciding, armed, judge)
	_mines[id] = mine
	mine.finished.connect(_on_mine_finished.bind(id, owner))
	if deciding:
		mine.ran.connect(_on_mine_ran.bind(id))
		var held: Array = _jobs.get(owner, [])
		held.append(id)
		_jobs[owner] = held
	if owner == my_id and _player_ready() and _player.has_method("take_mine"):
		_player.take_mine(mine)


func _on_mine_ran(left: int, at: Vector3, id: int) -> void:
	if _arena != null and is_instance_valid(_arena):
		_tell_blast(id, left, 0, _arena.to_local(at))


func _on_mine_finished(_why: String, id: int, owner: int) -> void:
	_mines.erase(id)
	if _jobs.has(owner):
		_jobs[owner].erase(id)


## The host's word of a cron mine (C27): a run (`gen` the runs left after it) or a removal.
func _mine_word(id: int, gen: int, index: int, at: Vector3) -> void:
	var mine = _mines[id]
	if not is_instance_valid(mine):
		return
	if gen >= 0:
		mine.apply_run(gen, _arena.to_global(at))
		return
	var why := CronMine.CRONTAB if gen == MINE_CRONTAB else CronMine.SHOT if gen == MINE_SHOT else CronMine.GONE
	_mine_removed(mine, why, index if gen == MINE_SHOT else 0)


## A mine of `owner`'s ends here before its job is done (`why`: crontab, shot or gone), on the host
## and on every joiner alike: the strip's note for its owner when the crontab was full, the feed's
## line when another player's shot removed it.
func _mine_removed(mine: Node, why: String, remover: int) -> void:
	mine.remove(why)
	if why == CronMine.CRONTAB and mine.owner_id == my_id and _player_ready() and _player.has_method("note_crontab_full"):
		_player.note_crontab_full(mine.def)
	if why == CronMine.SHOT:
		job_removed.emit(remover, mine.owner_id, mine.def.remove_word)


## The host ends mine `id` (`why`) and tells every joiner, with `remover` the shooter for a shot.
func _remove_mine(id: int, why: String, remover: int) -> void:
	var mine = _mines.get(id)
	if mine == null or not is_instance_valid(mine) or not mine.running():
		return
	var code := MINE_CRONTAB if why == CronMine.CRONTAB else MINE_SHOT if why == CronMine.SHOT else MINE_GONE
	_tell_blast(id, code, remover if why == CronMine.SHOT else 0, _arena.to_local(mine.global_position))
	_mine_removed(mine, why, remover)


## `owner`'s crontab past the weapon's limit: its oldest jobs go (C27).
func _crontab_trim(owner: int, def: WeaponDefScript) -> void:
	var live: Array = _jobs.get(owner, []).filter(func(i): return _mines.has(i) and is_instance_valid(_mines[i]) and _mines[i].running())
	while live.size() > def.crontab_limit:
		_remove_mine(live.pop_front(), CronMine.CRONTAB, 0)


## Every job of `owner`'s goes: it left the match.
func _drop_jobs(owner: int) -> void:
	for id in _jobs.get(owner, []).duplicate():
		_remove_mine(id, CronMine.GONE, 0)
	_jobs.erase(owner)


## A joiner arriving mid-match is sent every mine running, already armed, with its runs left.
func _send_mines(peer: int) -> void:
	for id in _mines:
		var mine = _mines[id]
		if is_instance_valid(mine) and mine.running():
			var normal: Vector3 = (_arena.global_transform.basis.inverse() * (mine.normal as Vector3)).normalized()
			_tell_seed(id, mine.owner_id, mine.def.id, -mine.runs_left, _arena.to_local(mine.global_position), normal, PackedInt32Array(), peer)


## The hit volumes of `shooter`'s own mines: its own shots pass them by.
func _own_mines(shooter: int) -> Array[RID]:
	var out: Array[RID] = []
	for id in _jobs.get(shooter, []):
		var mine = _mines.get(id)
		if mine != null and is_instance_valid(mine) and mine.hit_rid().is_valid():
			out.append(mine.hit_rid())
	return out


## A hitscan ray of `shooter`'s from `a` to `b` (arena space): the first mine of another player's
## whose hit volume it passes removes it, or every one with `pierce` (the rail). Host only.
func _shoot_mines(shooter: int, a: Vector3, b: Vector3, pierce: bool) -> void:
	if _mines.is_empty() or _player == null or not is_instance_valid(_player):
		return
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var skip := _own_mines(shooter)
	for i in WeaponDefScript.PIERCE_LAST:
		var query := PhysicsRayQueryParameters3D.create(_arena.to_global(a), _arena.to_global(b), CronMine.MINE_LAYER)
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return
		skip.append((hit["collider"] as CollisionObject3D).get_rid())
		_shot_mine(hit["collider"], shooter)
		if not pierce:
			return


## A shot of `shooter`'s met mine `collider`: another player's mine is removed. True when it was.
func _shot_mine(collider: Object, shooter: int) -> bool:
	var id: int = collider.get_meta(CronMine.MINE_ID_META, 0)
	if collider.get_meta(CronMine.MINE_OWNER_META, 0) == shooter or not _mines.has(id):
		return false
	_remove_mine(id, CronMine.SHOT, shooter)
	return true


## A blast of `shooter`'s at `at` (world space) reaching `radius`: every mine of another player's
## within it, with nothing of the level between, is removed. Host only.
func _blast_mines(shooter: int, at: Vector3, radius: float) -> void:
	if _mines.is_empty() or _player == null or not is_instance_valid(_player):
		return
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	for id in _mines.keys():
		var mine = _mines[id]
		if not is_instance_valid(mine) or not mine.running() or mine.owner_id == shooter or not mine.authoritative:
			continue
		var place: Vector3 = mine.global_position
		if place.distance_to(at) > radius:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, place, BLAST_SIGHT_MASK)).is_empty():
			_remove_mine(id, CronMine.SHOT, shooter)


## The host's rm -rf slug went off at `at` (world space, C26): every joiner's slug goes off there.
func _on_slug_blasted(at: Vector3, shot_id: int) -> void:
	if _arena != null and is_instance_valid(_arena):
		_tell_blast(shot_id, 0, 0, _arena.to_local(at))


## The host's judgement of the blast of `shooter`'s rm -rf slug at `at` (world space, C26):
## every living player whose middle is within the blast's radius (the larger one with `root`),
## with nothing of the level between, takes the blast's damage for its distance at the shooter's
## strength (combat.damage_scale, C22); the shooter itself too, at the weapon's self_damage_share
## of it (a death it causes credits no kill). Told as a shot of the rm -rf cannon, each kill as a
## death by it. How many players it hurt. A cron mine's run (C27) is judged here too: its
## self-damage share is 0, so it never hurts its owner, and its kills credit the owner even dead.
func _judge_slug_blast(at: Vector3, shooter: int, weapon: String, root: bool) -> int:
	if state != State.HOSTING or combat == null or _player == null or not is_instance_valid(_player) or _arena == null or not is_instance_valid(_arena):
		return 0
	var def: WeaponDefScript = _weapons[weapon]
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var scale := combat.damage_scale(shooter)
	var hits := PackedInt32Array()
	var healths := PackedFloat32Array()
	var killed := PackedInt32Array()
	for id in players:
		if not combat.alive(id):
			continue
		var middle := Vector3.INF
		if id == 1:
			middle = _player.global_position
		else:
			var avatar = avatars.get(id)
			if avatar != null and is_instance_valid(avatar) and avatar.visible:
				middle = _arena.to_global(avatar.latest_position())
		if not middle.is_finite():
			continue
		var base: float = def.blast_damage_at(at.distance_to(middle), root)
		if id == shooter:
			base *= def.self_damage_share  # the blast hurts its shooter too
		if base <= 0.0:
			continue
		var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, middle, BLAST_SIGHT_MASK)
		if not space.intersect_ray(sight).is_empty():
			continue  # a wall between: the blast does not reach
		var before := combat.health_of(id)
		var outcome := combat.damage_player(id, shooter, base * scale)
		if outcome.is_empty():
			continue
		hits.append(id)
		healths.append(outcome["health"])
		if outcome["killed"]:
			killed.append(id)
		if id != shooter:
			combat.add_meter(shooter, minf(base, before) / _ct.max_health, outcome["killed"])
	_blast_mines(shooter, at, def.blast_radius_for(root))  # and another player's mines in reach (C27)
	_blast_daemons(at, shooter, func(dist: float) -> float: return def.blast_damage_at(dist, root), weapon)  # and the daemons while they fight (C27b)
	if hits.is_empty():
		return 0
	var local: Vector3 = _arena.to_local(at)
	_broadcast_shot(shooter, weapon, local, PackedVector3Array([local]), hits, healths)
	for victim in killed:
		_broadcast_death(victim, shooter, Vector3.UP, weapon)
	_mirror_from_combat()
	_flush_sudo()
	return hits.size()


## The host's check of a grep shot's claimed marks (C25), the shot itself already believed from
## `origin` along `dir` (arena space): each claim is believed when it names a living player
## other than the shooter not named before, within the weapon's lock range plus its tolerance of
## the origin, within its sight cone plus its tolerance of the aim, with nothing of the level
## between, and the shooter's marks (as user or as root) are not yet all believed. The rest are
## dropped and counted (marks_refused). The believed player ids, in the order claimed.
func _accept_marks(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript, marks: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cap := def.marks_for(combat.root(shooter))
	var from: Vector3 = _arena.to_global(origin)
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	for id in marks:
		var at := Vector3.INF
		if id != shooter and not out.has(id) and out.size() < cap and combat.has_player(id) and combat.alive(id):
			at = _mark_point(id)
		var ok := at.is_finite()
		if ok:
			var to := at - from
			ok = to.length() <= def.lock_range_m + def.claim_tolerance_m and rad_to_deg(along.angle_to(to)) <= def.sight_cone_degrees + def.claim_tolerance_degrees
		if ok:
			ok = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, at, MARK_SIGHT_MASK)).is_empty()
		if ok:
			out.append(id)
		else:
			marks_refused += 1
	return out


## Where player `id`'s middle is now as this side shows it (world space): this player's own
## body, or that player's avatar; a non-finite vector while it is down or not shown (C25: where
## a grep dart flies, and where the host checks a claim against).
func _mark_point(id: int) -> Vector3:
	if id == my_id:
		var here: bool = _player != null and is_instance_valid(_player) and not dead.get(my_id, false)
		return _player.global_position if here else Vector3.INF
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible or avatar.dead:
		return Vector3.INF
	return avatar.global_position


## What fork() pellets pass through, asked every physics frame (C24): the shooter's own body
## and every corpse; hosting, by the host's own count (as its shot rays), otherwise by what
## this side was told.
func _pellets_past(shooter: int) -> Array[RID]:
	if state == State.HOSTING and combat != null and _player != null and is_instance_valid(_player):
		return _not_in_the_way(shooter) + _own_mines(shooter)
	var out: Array[RID] = []
	if (shooter == my_id or dead.get(my_id, false)) and _player != null and is_instance_valid(_player):
		out.append(_player.get_rid())
	for id in avatars:
		var avatar = avatars[id]
		if avatar != null and is_instance_valid(avatar) and (id == shooter or dead.get(id, false)):
			out.append(avatar.hit_rid())
	return out


## The host's judgement of one fork() pellet of `shooter`'s (C24) of generation `gen` that met
## `collider` at `at` (world space) flying along `dir`: a living player other than the
## shooter takes the pellet's damage for its generation (root's harder hit, C22), told to
## everyone as a shot of fork() and, for a kill, a death by it; a dummy of this arena stops it,
## and only the host's own pellets hurt the host's dummies. True when it dealt damage. A grep
## dart (C25) is judged the same, always generation 0: the weapon's damage.
func _judge_pellet(collider: Object, gen: int, at: Vector3, dir: Vector3, shooter: int, weapon: String, origin: Vector3) -> bool:
	if state != State.HOSTING or combat == null or not is_instance_valid(collider) or _arena == null or not is_instance_valid(_arena):
		return false
	if collider.has_meta(CronMine.MINE_ID_META):
		return _shot_mine(collider, shooter)  # another player's cron mine (C27)
	var victim := 0
	if collider == _player and shooter != 1 and combat.has_player(1):
		victim = 1
	elif collider.has_meta(PLAYER_ID_META):
		var id: int = collider.get_meta(PLAYER_ID_META, 0)
		if id != shooter and combat.has_player(id):
			victim = id
	var def: WeaponDefScript = _weapons[weapon]
	if victim == 0:
		if shooter != my_id and daemons_fight() and _is_daemon(collider):
			return _hit_daemon(collider, shooter, def.fork_damage(gen) * combat.damage_scale(shooter), at, dir, weapon)  # a joiner's pellet on the host's daemon (C27b)
		return shooter == my_id and _player_ready() and _player.fork_hit(collider, gen, at, dir, def)
	var base := def.fork_damage(gen)
	var before := combat.health_of(victim)
	var outcome := combat.damage_player(victim, shooter, base * combat.damage_scale(shooter))
	if outcome.is_empty():
		return false  # dead or protected: the pellet landed on nothing that counts
	combat.add_meter(shooter, minf(base, before) / _ct.max_health, outcome["killed"])
	var local: Vector3 = _arena.to_local(at)
	_broadcast_shot(shooter, weapon, origin, PackedVector3Array([local]), PackedInt32Array([victim]), PackedFloat32Array([outcome["health"]]))
	if outcome["killed"]:
		_broadcast_death(victim, shooter, (_arena.global_transform.basis.inverse() * dir).normalized(), weapon)
	_mirror_from_combat()
	_flush_sudo()
	return true


## The live-cap key of a thrower's bomblets in this arena.
func _bomb_key(id: int) -> String:
	return "p%d" % id


## Where the host believes `id` looks, a unit vector in arena space: its own view for
## itself, the newest one a joiner sent; ZERO when nothing is known yet.
func _view_of(id: int) -> Vector3:
	if id == 1:
		if _player == null or not is_instance_valid(_player):
			return Vector3.ZERO
		var pitch: float = _player.view_pitch() if _player.has_method("view_pitch") else 0.0
		return (Basis(Vector3.UP, _player.rotation.y) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD).normalized()
	var avatar = avatars.get(id)
	return avatar.latest_view() if avatar != null and is_instance_valid(avatar) and avatar.has_method("latest_view") else Vector3.ZERO


## Going online (C18): a solo SIGSTOP ends at once, right here, so not one frame of the
## match (or of the join's own timers) runs with the world slowed.
func _end_solo_sigstop() -> void:
	var stop = _player.get("sigstop") if _player != null and is_instance_valid(_player) else null
	if stop != null and stop.has_method("end_now") and not is_online():
		stop.end_now()


## This player pressed SIGSTOP's key (C18): the ask goes to the host, which, when this is the
## host, is the same check every other player's ask gets. Nothing slows here or there.
func _on_sigstop_intent(on: bool) -> void:
	if not is_online():
		return
	var life: int = lives.get(my_id, 0)
	if state == State.HOSTING:
		_handle_sigstop(1, life, on)
	elif multiplayer.get_peers().has(1):
		_sigstop.rpc_id(1, life, on)


## A joiner's ask to start or end its SIGSTOP, to the host. Untyped like _fire: wrong types
## are counted, never an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _sigstop(life: Variant, on: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(on) != TYPE_BOOL:
		combat.sigstop(0, 0, true, 0)  # counted: no such ask
		return
	_handle_sigstop(multiplayer.get_remote_sender_id(), life, on)


## The host's check of a SIGSTOP ask, and its word back either way: a refused start is
## answered "off" with the meter the host counts.
func _handle_sigstop(id: int, life: int, on: bool) -> void:
	if state != State.HOSTING or combat == null:
		return
	combat.sigstop(id if players.has(id) else 0, life, on, lives.get(id, 0))
	_send_sigstop(id)


## The host's word on `id`'s SIGSTOP, to that player alone: on or off and the seconds left.
func _send_sigstop(id: int) -> void:
	if combat == null or not combat.has_player(id):
		return
	if id == my_id:
		_take_sigstop(combat.sigstop_on(id), combat.sigstop_meter(id))
	elif multiplayer.get_peers().has(id):
		_sigstop_state.rpc_id(id, lives.get(id, 0), combat.sigstop_on(id), combat.sigstop_meter(id))


## The host's word on this player's SIGSTOP, for its life `life`: a stale one is dropped.
@rpc("authority", "call_remote", "reliable")
func _sigstop_state(life: int, on: bool, left: float) -> void:
	if state != State.JOINED or life != lives.get(my_id, 0) or not is_finite(left) or left < 0.0 or left > SigstopTuning.METER_LAST_S:
		return
	_take_sigstop(on, left)


func _take_sigstop(on: bool, left: float) -> void:
	_stop_word = [on, left]
	var stop = _player.get("sigstop") if _player != null and is_instance_valid(_player) else null
	if stop != null and stop.has_method("take_host"):
		stop.take_host(on, left)


## Where the host believes `id`'s eye is, in arena space: its own camera for itself, the
## newest received position (or the spawn it was just put at) plus the eye height for a
## joiner; INF when nothing is known of it yet.
func _eye_of(id: int) -> Vector3:
	if _player == null or not is_instance_valid(_player) or _arena == null:
		return Vector3.INF
	if id == 1:
		return _arena.to_local(_player.eye_position()) if _player.has_method("eye_position") else Vector3.INF
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return Vector3.INF
	var eye_height: float = _player.eye_height() if _player.has_method("eye_height") else 0.7
	return avatar.latest_position() + Vector3(0.0, eye_height, 0.0)


## True when something solid lies between the host's view of the shooter's eye and the
## origin it claims: cover, a dummy or another player's body. The shooter's own avatar,
## which the eye sits inside, does not count.
func _obstructed(shooter: int, eye: Vector3, origin: Vector3, mask: int) -> bool:
	var from: Vector3 = _arena.to_global(eye)
	var to: Vector3 = _arena.to_global(origin)
	if from.distance_to(to) < 0.001:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, mask | PLAYER_LAYER_MASK)
	query.exclude = _not_in_the_way(shooter)
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## What no shot and no cover probe may stop at: the shooter's own body, and every corpse
## (the host's body while the host is dead, every dead avatar's hit volume: a volume is
## switched off a frame after the death, and a second shot in the same poll must not find
## it in between).
func _not_in_the_way(shooter: int) -> Array[RID]:
	var out: Array[RID] = []
	if shooter == 1 or not combat.alive(1):
		out.append(_player.get_rid())
	for id in avatars:
		var avatar = avatars[id]
		if avatar != null and is_instance_valid(avatar) and (id == shooter or not combat.alive(id)):
			out.append(avatar.hit_rid())
	return out


## The host's own raycast for one pellet of a believed shot of weapon `def`: walls,
## dummies, the players' bodies, never the shooter's own. {end, hit, distance}: the end
## point in arena space, the player hit or 0, and how far the pellet flew.
func _raycast(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> Dictionary:
	var from: Vector3 = _arena.to_global(origin)
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var far := from + along * def.fire_range
	var query := PhysicsRayQueryParameters3D.create(from, far, def.hit_mask | PLAYER_LAYER_MASK)
	# Players can stand inside each other, at a shared spawn for one: a shot that starts
	# inside an opponent still hits it. The shooter's own body and every corpse are excluded.
	query.hit_from_inside = true
	query.exclude = _not_in_the_way(shooter)
	var result: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"end": _arena.to_local(far), "hit": 0, "distance": def.fire_range, "daemon": null}
	var collider = result["collider"]
	var hit := 0
	if collider == _player and shooter != 1 and combat.has_player(1):
		hit = 1
	elif is_instance_valid(collider) and collider.has_meta(PLAYER_ID_META):
		var id: int = collider.get_meta(PLAYER_ID_META, 0)
		if id != shooter and combat.has_player(id):
			hit = id
	var flown: float = from.distance_to(result["position"])
	return {"end": _arena.to_local(result["position"]), "hit": hit, "distance": flown, "daemon": collider if _is_daemon(collider) else null}


## The host's own trace of a rail shot (C17): one line from `origin` along `dir` up to the
## rail's range that passes through every player on it (and every dummy) and stops at the
## first piece of the level. {end, hits}: where it stopped, in arena space, and the players
## it passed through, nearest first. The shooter's own body and every corpse are skipped.
func _rail_trace(shooter: int, origin: Vector3, dir: Vector3, def: WeaponDefScript) -> Dictionary:
	var from: Vector3 = _arena.to_global(origin)
	var along: Vector3 = (_arena.global_transform.basis * dir).normalized()
	var far := from + along * def.fire_range
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var exclude := _not_in_the_way(shooter)
	var hits := PackedInt32Array()
	var daemons := []
	var end := far
	for i in WeaponDefScript.PIERCE_LAST + 1:
		var query := PhysicsRayQueryParameters3D.create(from, far, def.hit_mask | PLAYER_LAYER_MASK)
		query.hit_from_inside = true
		query.exclude = exclude
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			break
		var collider = result["collider"]
		var id := 0
		if collider == _player and shooter != 1 and combat.has_player(1):
			id = 1
		elif is_instance_valid(collider) and collider.has_meta(PLAYER_ID_META):
			id = collider.get_meta(PLAYER_ID_META, 0)
		var target: bool = id != 0 or (is_instance_valid(collider) and collider.has_method("hit"))
		if not target:
			end = result["position"]  # the level stops the rail
			break
		exclude.append(collider.get_rid())
		if id != 0 and id != shooter and combat.has_player(id) and not hits.has(id):
			hits.append(id)
		elif id == 0 and _is_daemon(collider):
			daemons.append([collider, result["position"]])  # a daemon on the line, where it struck (C27b)
	return {"end": _arena.to_local(end), "hits": hits, "daemons": daemons}


## A player's fake in-game process id for its life `life` (C17, the kill feed's "SIGKILL
## <pid> sent by <player>"): worked out from the slot and the life alone, the same on every
## machine. Never read from the system, never a real process id.
static func fake_pid(slot: int, life: int) -> int:
	return 1000 + posmod(slot * 4099 + life * 977, 30000)


func _broadcast_shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	_apply_shot(shooter, weapon, origin, ends, hits, healths)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_shot.rpc_id(id, shooter, weapon, origin, ends, hits, healths)


## A shot the host believed: who fired which weapon, where each pellet went, whom it hit
## and their health now.
@rpc("authority", "call_remote", "reliable")
func _shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	if state != State.JOINED or not players.has(shooter) or not _weapons.has(weapon) or not origin.is_finite():
		return
	var most: int = _weapons[weapon].pipe_tuning().root_max_links if _weapons[weapon].is_chain() else _weapons[weapon].pellet_count
	if ends.is_empty() or ends.size() > most or hits.size() != healths.size() or hits.size() > players.size():
		return
	for end in ends:
		if not end.is_finite():
			return
	for i in hits.size():
		if not players.has(hits[i]) or not is_finite(healths[i]) or healths[i] < 0.0 or healths[i] > _ct.max_health:
			return
	_apply_shot(shooter, weapon, origin, ends, hits, healths)


func _apply_shot(shooter: int, weapon: String, origin: Vector3, ends: PackedVector3Array, hits: PackedInt32Array, healths: PackedFloat32Array) -> void:
	if _weapons.has(weapon) and _weapons[weapon].is_freeze():
		_draw_beam_tick(shooter, origin, ends[0])  # chmod 000's beam tick (C29): drawn, nothing else
		return
	# This player's own ult meter, from the host's confirmed results of its other weapons.
	var mine: bool = shooter == my_id and _weapons.has(weapon) and not _weapons[weapon].is_ult() and _player_ready()
	for i in hits.size():
		var before: float = health.get(hits[i], _ct.max_health)
		health[hits[i]] = healths[i]
		_show_avatar_state(hits[i])
		if mine and hits[i] != my_id:
			# Root's harder hit fills it no faster (C22): the share at user's strength, as the host's.
			_player.add_meter(_player.meter_gain(maxf(before - healths[i], 0.0) / _ct.max_health / _root_scale(shooter), false))
	if _weapons[weapon].is_chain():
		_draw_chain(shooter, origin, ends)  # pipe | (C30): the stream link to link
	elif shooter != my_id and _arena != null and is_instance_valid(_arena) and not _weapons[weapon].is_volley():
		for end in ends:
			CannonFx.spawn_beam(_arena, _arena.to_global(origin), _arena.to_global(end), _weapons[weapon])
	if hits.is_empty():
		shot_confirmed.emit(shooter, 0, origin, ends[0])
	for hit in hits:
		shot_confirmed.emit(shooter, hit, origin, ends[0])
	combat_changed.emit()


## Another player's chmod 000 beam tick (C29), on this screen: its avatar's beam from just ahead of its
## eye to where the host's ray ended (arena space), held until the next tick. This player's own is drawn
## by its player.
func _draw_beam_tick(shooter: int, origin: Vector3, end: Vector3) -> void:
	if shooter == my_id or _arena == null or not is_instance_valid(_arena):
		return
	var avatar = avatars.get(shooter)
	if avatar == null or not is_instance_valid(avatar) or not avatar.has_method("beam_to"):
		return
	var to: Vector3 = _arena.to_global(end)
	var eye: Vector3 = _arena.to_global(origin)
	var way := (to - eye).normalized() if to.distance_to(eye) > 0.01 else Vector3.FORWARD
	avatar.beam_to(eye + way * BEAM_AHEAD_M + Vector3.DOWN * BEAM_DROP_M, to, false)


## Another player's chain of pipe | (C30), on this screen: its avatar's stream from just ahead of its eye
## through the chain's points (arena space), link to link; a miss (its end twice) drawn to its end alone,
## with no link. This player's own is drawn by its player.
func _draw_chain(shooter: int, origin: Vector3, ends: PackedVector3Array) -> void:
	if shooter == my_id or _arena == null or not is_instance_valid(_arena):
		return
	var avatar = avatars.get(shooter)
	if avatar == null or not is_instance_valid(avatar) or not avatar.has_method("pipe_to"):
		return
	var points := PackedVector3Array()
	for end in ends:
		points.append(_arena.to_global(end))
	var missed := points.size() == 2 and points[0].is_equal_approx(points[1])
	var eye: Vector3 = _arena.to_global(origin)
	var way := (points[0] - eye).normalized() if points[0].distance_to(eye) > 0.01 else Vector3.FORWARD
	avatar.pipe_to(eye + way * BEAM_AHEAD_M + Vector3.DOWN * BEAM_DROP_M, points.slice(0, 1) if missed else points, 0 if missed else points.size())


# --- Root vs user and sudo overcharge (C22). ---

## This player pressed Z with a charge: a request the host decides, which, when this is the
## host, is the same check every other player's gets.
func _on_sudo_intent() -> void:
	if not is_online():
		return
	var life: int = lives.get(my_id, 0)
	if state == State.HOSTING:
		_handle_sudo(1, life)
	elif multiplayer.get_peers().has(1):
		_sudo.rpc_id(1, life)


## A joiner's ask to spend a sudo charge on root, to the host. Untyped like _fire: wrong
## types are counted, never an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _sudo(life: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT:
		combat.sudo(0, 0, 0)  # counted: no such ask
		return
	_handle_sudo(multiplayer.get_remote_sender_id(), life)


## The host's check of a sudo ask: believed with a charge held (root starts), refused and
## counted otherwise; either way every player hears the outcome.
func _handle_sudo(id: int, life: int) -> void:
	if state != State.HOSTING or combat == null:
		return
	combat.sudo(id if players.has(id) else 0, life, lives.get(id, 0))
	_flush_sudo()


## Tells everyone, this side included, the sudo state of every player whose state changed.
func _flush_sudo() -> void:
	if combat == null:
		return
	var connected := multiplayer.get_peers()
	for id in combat.take_sudo_changed():
		if not players.has(id):
			continue
		var charges := combat.sudo_charges(id)
		var left := combat.root_left(id)
		_apply_sudo(id, charges, left)
		for peer in players:
			if peer != 1 and connected.has(peer):
				_sudo_state.rpc_id(peer, id, lives.get(id, 0), charges, left)


## Every player's sudo state to `peer`, a joiner just arrived.
func _send_sudo_all(peer: int) -> void:
	if combat == null or not multiplayer.get_peers().has(peer):
		return
	for id in players:
		_sudo_state.rpc_id(peer, id, lives.get(id, 0), combat.sudo_charges(id), combat.root_left(id))


## A player's sudo state from the host: its charges and root seconds left, in its life `life`.
@rpc("authority", "call_remote", "reliable")
func _sudo_state(id: int, life: int, charges: int, left: float) -> void:
	if state != State.JOINED or not players.has(id) or life != lives.get(id, -1):
		return
	if charges < 0 or charges > SudoTuning.CHARGES_LAST or not is_finite(left) or left < 0.0 or left > SudoTuning.ROOT_LAST_S:
		return
	_apply_sudo(id, charges, left)


## Shows a player's sudo state: this player's own on its HUD and weapons, anyone else's on
## their avatar.
func _apply_sudo(id: int, charges: int, left: float) -> void:
	root_left[id] = left
	if id == my_id:
		_my_charges = charges
		if _player != null and is_instance_valid(_player):
			var sudo = _player.get("sudo")
			if sudo != null and sudo.state != null:
				sudo.take_host(charges, left)
	else:
		var avatar = avatars.get(id)
		if avatar != null and is_instance_valid(avatar) and avatar.has_method("set_root"):
			avatar.set_root(left > 0.0)
	combat_changed.emit()


## How hard `id` hits as this side knows it: the host's own count while hosting, the host's
## word otherwise. Used only to read the meter's share back at user's strength.
func _root_scale(id: int) -> float:
	if state == State.HOSTING and combat != null:
		return combat.damage_scale(id)
	if id == my_id and _player_ready():
		var sudo = _player.get("sudo")
		if sudo != null and sudo.state != null:
			return sudo.damage_scale()
	return 1.0


# --- Spectate as top (C23). ---

## The top table's numbers of this match as this side knows them: hosting, the host's own
## record now; joined, the host's last word ({} before the first); otherwise {}. {uptime,
## load (the kills in each load window), rows: id -> {pid, kills, deaths, dealt, alive_s}}.
func top_numbers() -> Dictionary:
	if state == State.JOINED:
		return _top_word
	if state != State.HOSTING or combat == null:
		return {}
	var t := top_tuning_in_use()
	var rows := {}
	for id in players:
		var r = combat.record.rows.get(id)
		if r != null:
			rows[id] = {"pid": t.pid_base + r["order"], "kills": r["kills"], "deaths": r["deaths"], "dealt": r["dealt"], "alive_s": r["alive_s"]}
	return {"uptime": combat.record.uptime, "load": combat.record.load_counts(t.windows()), "rows": rows}


## Whether this side knows `id`'s SIGSTOP is on, for the top table's T: the host knows every
## player's; a joiner only its own, from the host's word to it.
func stopped_known(id: int) -> bool:
	if state == State.HOSTING and combat != null:
		return combat.sigstop_on(id)
	if state == State.JOINED and id == my_id and _player_ready():
		var stop = _player.get("sigstop")
		return stop != null and stop.is_on()
	return false


## Host: every refresh_s of its clock, the top table's numbers to every joiner.
func _tick_top(delta: float) -> void:
	_top_left -= delta
	if _top_left > 0.0:
		return
	var t := top_tuning_in_use()
	_top_left = maxf(_top_left + t.refresh_s, 0.0)
	if _top_left <= 0.0:
		_top_left = t.refresh_s
	var numbers := top_numbers()
	var ids := PackedInt32Array()
	var pids := PackedInt32Array()
	var kills := PackedInt32Array()
	var deaths := PackedInt32Array()
	var dealt := PackedFloat32Array()
	var alive := PackedFloat32Array()
	for id in numbers["rows"]:
		var row: Dictionary = numbers["rows"][id]
		ids.append(id)
		pids.append(row["pid"])
		kills.append(row["kills"])
		deaths.append(row["deaths"])
		dealt.append(row["dealt"])
		alive.append(row["alive_s"])
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer):
			_top.rpc_id(peer, numbers["uptime"], numbers["load"], ids, pids, kills, deaths, dealt, alive)
			tops_sent += 1


## The top table's numbers from the host: the match's seconds of play, its kills in each load
## window, and per player its game PID, kills, deaths, damage dealt and time alive this life.
## A malformed one is dropped whole; a player not in the roster is left out.
@rpc("authority", "call_remote", "reliable")
func _top(uptime: float, load: PackedInt32Array, ids: PackedInt32Array, pids: PackedInt32Array, kills: PackedInt32Array, deaths: PackedInt32Array, dealt: PackedFloat32Array, alive: PackedFloat32Array) -> void:
	var n := ids.size()
	if state != State.JOINED or not is_finite(uptime) or uptime < 0.0 or load.size() != 3 or n > _t.max_players:
		return
	if pids.size() != n or kills.size() != n or deaths.size() != n or dealt.size() != n or alive.size() != n:
		return
	for count in load:
		if count < 0:
			return
	var rows := {}
	for i in n:
		if pids[i] < 0 or pids[i] > TopTuning.PID_LAST or kills[i] < 0 or deaths[i] < 0 or not is_finite(dealt[i]) or dealt[i] < 0.0 or not is_finite(alive[i]) or alive[i] < 0.0:
			return
		if players.has(ids[i]):
			rows[ids[i]] = {"pid": pids[i], "kills": kills[i], "deaths": deaths[i], "dealt": dealt[i], "alive_s": alive[i]}
	_top_word = {"uptime": uptime, "load": load, "rows": rows}
	tops_received += 1


# --- Light-trail mode (C20). ---

## Whether light-trail mode is on in this match: hosting, the host's settings or its
## --light-trails; joined, the host's word; solo, never.
func light_trails_on() -> bool:
	if state == State.HOSTING:
		return light_trails_flag or GameSettings.current().value("multiplayer", "light_trails") == true
	if state == State.JOINED:
		return _trails_rule
	return false


## This arena's walls while the mode is on, or null.
func trails_in_arena() -> Node3D:
	if not _trails_rule or _arena == null or not is_instance_valid(_arena):
		return null
	return LightTrails.of(_arena, trail_tuning_in_use())


## Every physics step online: the host's rule told when it changes, every wall aged; hosting,
## each living player's walls laid from where they are and every living, unprotected body
## judged against every wall.
func _tick_trails(delta: float) -> void:
	if state == State.HOSTING and light_trails_on() != _trails_rule:
		_trails_rule = not _trails_rule
		_send_rules()
		if not _trails_rule:
			LightTrails.drop(_arena)  # turned off: every wall goes at once
	var trails := trails_in_arena()
	if trails == null:
		return
	trails.keep_only(players.keys())  # the walls of players who left go with them
	trails.tick(delta)
	if state != State.HOSTING or combat == null:
		return
	var connected := multiplayer.get_peers()
	for id in players:
		var at := _body_of(id)
		if not combat.alive(id) or not at.is_finite():
			continue
		trails.paint(id, Palette.trail_color(players[id]["slot"]))
		var ground := _ground_under(at)
		var laid: Array = trails.advance(id, ground, ground.is_finite())
		if laid.is_empty():
			continue
		for peer in players:
			if peer != 1 and connected.has(peer):
				_trail.rpc_id(peer, id, lives.get(id, 0), laid[0], laid[1], 0.0)
	for id in players:
		var at := _body_of(id)
		if not combat.alive(id) or combat.protected(id) or not at.is_finite():
			continue
		var wall_owner: int = trails.touching(at, id)
		if wall_owner < 0 or not players.has(wall_owner):
			continue
		var push: Vector3 = trails.push_of(at, wall_owner)
		if combat.damage_player(id, wall_owner, _ct.max_health).get("killed", false):
			_mirror_from_combat()
			_broadcast_death(id, wall_owner, push, LIGHT_TRAIL)


## Where player `id`'s body's middle is, in arena space, as the host knows it: its own body,
## or a joiner's newest position. INF when unknown.
func _body_of(id: int) -> Vector3:
	if _arena == null or not is_instance_valid(_arena):
		return Vector3.INF
	if id == my_id:
		if _player == null or not is_instance_valid(_player):
			return Vector3.INF
		return _arena.to_local(_player.global_position)
	var avatar = avatars.get(id)
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return Vector3.INF
	return avatar.latest_position()


## The level under a body whose middle is at `at` (arena space), when it is within
## ground_slack_m of that body's feet; INF when the body is in the air.
func _ground_under(at: Vector3) -> Vector3:
	var arena := _arena as Node3D
	var from := arena.to_global(at)
	var to := arena.to_global(at + Vector3.DOWN * (RemotePlayer.FEET + _lt.ground_slack_m))
	var query := PhysicsRayQueryParameters3D.create(from, to, GROUND_MASK)
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return arena.to_local(hit["position"])


## Every wall standing now, each with its age, to `peer`, a joiner just arrived: it plays
## among the same walls as everyone, and they end on its screen when they end here.
func _send_walls(peer: int) -> void:
	if state != State.HOSTING or not multiplayer.get_peers().has(peer):
		return
	var trails := trails_in_arena()
	if trails == null:
		return
	for id in trails.owners():
		if players.has(id):
			for wall in trails.walls_of(id):
				_trail.rpc_id(peer, id, lives.get(id, 0), wall[0], wall[1], wall[2])


func _send_rules() -> void:
	var connected := multiplayer.get_peers()
	_told_rule = daemon_rule()
	for id in players:
		if id != 1 and connected.has(id):
			_rules.rpc_id(id, _trails_rule, _told_rule[0], _told_rule[1], _told_rule[2])


## The match's rules, from the host: light-trail mode on or off (C20), and the daemons' (C27b):
## practice (the old never-attack dummies) or fighting, at which difficulty; and whether ICE is on
## (I1; never in practice).
@rpc("authority", "call_remote", "reliable")
func _rules(light_trails: bool, practice: bool, difficulty: String, ice: bool) -> void:
	if state != State.JOINED or not DaemonAiTuning.DIFFICULTIES.has(difficulty):
		return
	var news := practice != host_practice or difficulty != host_difficulty or ice != host_ice
	host_practice = practice
	host_difficulty = difficulty
	host_ice = ice
	if light_trails != _trails_rule:
		_trails_rule = light_trails
		if not light_trails:
			LightTrails.drop(_arena)
		news = true
	if news:
		changed.emit()


## A wall segment the host laid for player `id` in its life `life`, from `a` to `b` in arena
## space, `age` seconds ago (0 as it lays it).
@rpc("authority", "call_remote", "reliable")
func _trail(id: int, life: int, a: Vector3, b: Vector3, age: float) -> void:
	if state != State.JOINED or not players.has(id) or life != lives.get(id, -1) or dead.get(id, false):
		return
	if not is_finite(age) or age < 0.0 or age >= trail_tuning_in_use().lifetime_s:
		return
	if not a.is_finite() or not b.is_finite() or a.length() > WORLD_LAST or b.length() > WORLD_LAST:
		return
	if Vector2(b.x - a.x, b.z - a.z).length() > trail_tuning_in_use().segment_last_m + 0.01:
		return
	var trails := trails_in_arena()
	if trails == null:
		return
	trails.paint(id, Palette.trail_color(players[id]["slot"]))
	trails.add(id, a, b, age)


# --- The daemons fight back (C27b). ---

## True while hosting a match whose daemons fight: the host's practice setting off.
func daemons_fight() -> bool:
	return state == State.HOSTING and GameSettings.current().value("gameplay", "practice") != true


## The host's daemon rule now, from its settings: [practice, difficulty, ICE on] (ICE since I1).
func daemon_rule() -> Array:
	var s := GameSettings.current()
	return [s.value("gameplay", "practice") == true, String(s.value("gameplay", "difficulty")), s.value("gameplay", "ice") == true]


func is_hosting() -> bool:
	return state == State.HOSTING


## Every physics step hosting: the daemon rule told when it changes; while they fight, every
## daemon to every joiner at the sync rate.
func _tick_daemons(delta: float) -> void:
	if not _told_rule.is_empty() and daemon_rule() != _told_rule:
		_send_rules()
	if not daemons_fight() or players.size() < 2 or _arena == null or not is_instance_valid(_arena):
		_daemon_wait_s = 0.0
		return
	_daemon_wait_s -= delta
	if _daemon_wait_s > 0.0:
		return
	_daemon_wait_s += 1.0 / _t.sync_rate_hz
	var director := DaemonDirector.of(_arena)
	if director == null:
		return
	var places := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var words := PackedByteArray()
	var times := PackedFloat32Array()
	var life_words := PackedByteArray()
	var healths := PackedFloat32Array()
	var killers := PackedInt32Array()
	var seeds := PackedInt32Array()
	var bolt_ids := PackedInt32Array()
	var bolt_owners := PackedByteArray()
	var bolt_places := PackedVector3Array()
	var bolt_ways := PackedVector3Array()
	var brains := director.brains()
	for bolt in director.bolts():
		if bolt.live and bolt.id > 0 and brains.has(bolt.brain):
			bolt_ids.append(bolt.id)
			bolt_owners.append(brains.find(bolt.brain) | (0x80 if director.frozen(bolt.target) else 0))  # SIGSTOP's hold in the top bit
			bolt_places.append(_arena.to_local(bolt.global_position))
			bolt_ways.append((_arena.global_transform.basis.inverse() * bolt.velocity.normalized()).normalized())
	for brain in brains:
		var dummy: Node3D = brain.dummy
		places.append(_arena.to_local(dummy.global_position))
		yaws.append(dummy.global_rotation.y)
		var chmod: int = dummy.frost.bits() if dummy.get("frost") != null and dummy.is_alive() else 0  # chmod 000's meter (C29)
		words.append(int(brain.state) | chmod | (0x80 if director.frozen(brain.prey) else 0))
		times.append(minf(brain.state_t, DAEMON_TIME_LAST))
		life_words.append(int(dummy.state))
		healths.append(maxf(dummy.health(), 0.0))  # a killing hit leaves it below 0
		killers.append(dummy.killer if dummy.killer != 0 else my_id)  # whose kill its last death was
		seeds.append(dummy.build_seed())  # what it is built from (A5)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_daemons.rpc_id(id, places, yaws, words, times, life_words, healths, killers, seeds, bolt_ids, bolt_owners, bolt_places, bolt_ways)


## Every daemon of the host's, at the sync rate (C27b): where it is (arena space), its facing,
## its brain's state (SIGSTOP's hold in the top bit) and seconds into it, its life and its
## health, whose kill its last death was (so a death and its credit come in one word, Codex
## review), the seed each is built from (A5), in the director's order (both screens hold the same
## arena), and every bolt in the air (its id, its daemon with SIGSTOP's hold in the top bit, where,
## its way). A joiner's copies play it, each rebuilt first when its seed is new.
@rpc("authority", "call_remote", "unreliable_ordered")
func _daemons(places: PackedVector3Array, yaws: PackedFloat32Array, words: PackedByteArray, times: PackedFloat32Array, life_words: PackedByteArray, healths: PackedFloat32Array, killers: PackedInt32Array, seeds: PackedInt32Array, bolt_ids: PackedInt32Array, bolt_owners: PackedByteArray, bolt_places: PackedVector3Array, bolt_ways: PackedVector3Array) -> void:
	if state != State.JOINED or host_practice or _arena == null or not is_instance_valid(_arena):
		return
	var n := places.size()
	if n > DAEMONS_LAST or yaws.size() != n or words.size() != n or times.size() != n or life_words.size() != n or healths.size() != n or killers.size() != n or seeds.size() != n:
		return
	var b := bolt_ids.size()
	if b > BOLTS_LAST or bolt_owners.size() != b or bolt_places.size() != b or bolt_ways.size() != b:
		return
	var director := DaemonDirector.of(_arena)
	if director == null:
		return
	var brains := director.brains()
	for i in mini(n, brains.size()):
		var at := places[i]
		if not at.is_finite() or at.length() > WORLD_LAST or not is_finite(yaws[i]) or absf(yaws[i]) > YAW_LAST:
			continue
		if not is_finite(times[i]) or times[i] < 0.0 or times[i] > DAEMON_TIME_LAST or not is_finite(healths[i]) or healths[i] < 0.0:
			continue
		if (words[i] & IceDirector.STATE_BITS) > DaemonBrain.State.DOWN or life_words[i] > 2 or seeds[i] < 0:
			continue
		brains[i].dummy.follow_seed(seeds[i])  # the host's build first (A5)
		brains[i].take_word(at, yaws[i], words[i] & IceDirector.STATE_BITS, times[i], (words[i] & 0x80) != 0)
		brains[i].dummy.follow_life(life_words[i], healths[i], killers[i] == my_id)
		if brains[i].dummy.has_method("follow_frost"):
			brains[i].dummy.follow_frost(words[i] & Frost.BITS)  # chmod 000's meter (C29)
	var live := {}
	for k in b:
		var at := bolt_places[k]
		var owner: int = bolt_owners[k] & 0x7f
		if bolt_ids[k] <= 0 or owner >= brains.size() or not at.is_finite() or at.length() > WORLD_LAST or not Combat.dir_ok(bolt_ways[k]):
			continue
		live[bolt_ids[k]] = [brains[owner], _arena.to_global(at), (_arena.global_transform.basis * bolt_ways[k]).normalized(), (bolt_owners[k] & 0x80) != 0]
	director.follow_bolts(live)


## A host's zombie threw a bolt from `from` along `dir` (world space, C27b): every joiner's copy
## throws the same one, to draw.
func daemon_bolt(dummy: Node3D, bolt_id: int, from: Vector3, dir: Vector3) -> void:
	if state != State.HOSTING or _arena == null or not is_instance_valid(_arena):
		return
	var index := _daemon_index(dummy)
	if index < 0:
		return
	var local_from: Vector3 = _arena.to_local(from)
	var local_dir: Vector3 = (_arena.global_transform.basis.inverse() * dir).normalized()
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_daemon_bolt.rpc_id(id, index, bolt_id, local_from, local_dir)


## A bolt the host's daemon `index` threw, its id `bolt_id`, from `from` along `dir` (arena
## space): drawn here, judging nothing; one already drawn from the state word is not thrown twice.
@rpc("authority", "call_remote", "reliable")
func _daemon_bolt(index: int, bolt_id: int, from: Vector3, dir: Vector3) -> void:
	if state != State.JOINED or host_practice or _arena == null or not is_instance_valid(_arena):
		return
	if bolt_id <= 0 or not from.is_finite() or from.length() > WORLD_LAST or not Combat.dir_ok(dir):
		return
	var director := DaemonDirector.of(_arena)
	if director == null or index < 0 or index >= director.brains().size() or director.bolt_of(bolt_id) != null:
		return
	director.throw_bolt(director.brains()[index], _arena.to_global(from), (_arena.global_transform.basis * dir).normalized(), bolt_id)


## The host's word to the shooter that its shot struck daemon `dummy` (C27b): its hit marker, and
## a kill's credit. Nothing for the host's own shots, which land on its own arena.
func _tell_struck(shooter: int, dummy: Node, killed: bool) -> void:
	if shooter == 1 or not multiplayer.get_peers().has(shooter):
		return
	var index := _daemon_index(dummy)
	if index >= 0:
		_daemon_struck.rpc_id(shooter, index, killed)


## This player's own shot struck the host's daemon `index`, from the host, and killed it or not:
## its hit marker (the kill's credit comes with the death in the state word).
@rpc("authority", "call_remote", "reliable")
func _daemon_struck(index: int, killed: bool) -> void:
	if state != State.JOINED or _arena == null or not is_instance_valid(_arena):
		return
	var director := DaemonDirector.of(_arena)
	if director == null or index < 0 or index >= director.brains().size():
		return
	daemon_struck.emit(index, killed)


## Hosting: a joiner's brute ICEbreaker charge reaching the host's daemon `dummy` (I2): landed as that
## joiner's hit, its kill theirs, as a shot of theirs is.
func breaker_hit_daemon(dummy: Node, shooter: int, damage: float, point: Vector3, way: Vector3, source: String) -> bool:
	return _hit_daemon(dummy, shooter, damage, point, way, source)


## A joiner's hit on the host's daemon `dummy` (C27b): landed as another player's (its kill not
## the host's), the shooter told. True when it landed.
func _hit_daemon(dummy: Node, shooter: int, damage: float, point: Vector3, way: Vector3, source: String = "") -> bool:
	var landed: bool = dummy.hit_by_other(damage, point, way, shooter, source) == true
	if landed:
		_tell_struck(shooter, dummy, not dummy.is_alive())
	return landed


## `amount` of a daemon's damage on player `victim` (C27b, the host's director's word): judged
## in the match's combat with no killer credited (spawn protection holds), told to everyone, a
## kill told as the usual death with the daemon as its cause. True when it took health.
func daemon_hurt(victim: int, amount: float, dummy: Node3D, way: Vector3) -> bool:
	if state != State.HOSTING or combat == null or not combat.has_player(victim) or _arena == null or not is_instance_valid(_arena):
		return false
	var outcome := combat.damage_player(victim, victim, amount)
	if outcome.is_empty():
		return false
	var index := _daemon_index(dummy)
	_broadcast_daemon_hit(victim, outcome["health"], index)
	if outcome["killed"]:
		var local_way: Vector3 = (_arena.global_transform.basis.inverse() * way).normalized() if not way.is_zero_approx() else Vector3.FORWARD
		var cause := ICE_CAUSE if dummy.is_in_group(IceDirector.PIECES) else DAEMON_CAUSE + str(maxi(index, 0))
		_broadcast_death(victim, victim, local_way, cause)
	_mirror_from_combat()
	_flush_sudo()
	return true


func _broadcast_daemon_hit(victim: int, new_health: float, index: int) -> void:
	_apply_daemon_hit(victim, new_health)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_daemon_hit.rpc_id(id, victim, new_health, index)


## A daemon's hit on player `victim`, from the host: its health now, and which daemon.
@rpc("authority", "call_remote", "reliable")
func _daemon_hit(victim: int, new_health: float, index: int) -> void:
	if state != State.JOINED or not players.has(victim) or not is_finite(new_health) or new_health < 0.0 or new_health > _ct.max_health or index < -1 or index >= DAEMONS_LAST:
		return
	_apply_daemon_hit(victim, new_health)


func _apply_daemon_hit(victim: int, new_health: float) -> void:
	var before: float = health.get(victim, _ct.max_health)
	health[victim] = new_health
	_show_avatar_state(victim)
	if victim == my_id and _player != null and is_instance_valid(_player) and _player.has_method("take_hit"):
		_player.take_hit(maxf(before - new_health, 0.0))
	shot_confirmed.emit(0, victim, Vector3.ZERO, Vector3.ZERO)  # shooter 0, no player: the victim's flash
	combat_changed.emit()


## Daemon `dummy`'s index in this arena's director (the order both screens share); -1 for none.
func _daemon_index(dummy: Node) -> int:
	var director := DaemonDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if director == null:
		return -1
	var brains := director.brains()
	for i in brains.size():
		if brains[i].dummy == dummy:
			return i
	return -1


## The daemon a death's cause names ("daemon:2" is daemon 2), or -1 when it names none.
static func daemon_of(cause: String) -> int:
	if not cause.begins_with(DAEMON_CAUSE):
		return -1
	var rest := cause.substr(DAEMON_CAUSE.length())
	if not rest.is_valid_int():
		return -1
	var index := rest.to_int()
	return index if index >= 0 and index < DAEMONS_LAST else -1


## The name a daemon death's cause shows: the daemon's tag on this screen's copy of the arena.
func _daemon_name(cause: String) -> String:
	if cause == ICE_CAUSE:
		return ICE_NAME
	if cause == BLACK_CAUSE:
		return IceDirector.BLACK_NAME
	var index := daemon_of(cause)
	var director := DaemonDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if director != null and index >= 0 and index < director.brains().size():
		return String(director.brains()[index].dummy.tag_text)
	return "daemon"


## True for one of this arena's daemons (C27b): a target dummy, never a player's avatar; or (I1) a
## piece of ICE, judged here the same way.
func _is_daemon(collider: Object) -> bool:
	return is_instance_valid(collider) and collider is Node and ((collider as Node).is_in_group(DaemonDirector.TARGET_GROUP) or (collider as Node).is_in_group(IceDirector.PIECES)) and collider.has_method("hit") and not collider.has_meta(PLAYER_ID_META)


## Every daemon of this arena a blast at `at` (world space) reaches while they fight (C27b), for
## any shooter's blast: `base_at` gives the damage for a distance, at `shooter`'s strength, with
## nothing of the level between the blast and the daemon's middle. How many it hurt.
func _blast_daemons(at: Vector3, shooter: int, base_at: Callable, weapon: String = "") -> int:
	if not daemons_fight() or _arena == null or not is_instance_valid(_arena) or _player == null or not is_instance_valid(_player):
		return 0
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var hurt := 0
	for dummy in get_tree().get_nodes_in_group(DaemonDirector.TARGET_GROUP):
		if not _arena.is_ancestor_of(dummy) or not dummy.has_method("hit") or not dummy.is_alive():
			continue
		var middle: Vector3 = (dummy as Node3D).global_position + Vector3.UP * DaemonBrain.MIDDLE_M
		var base: float = base_at.call(at.distance_to(middle))
		if base <= 0.0:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, middle, BLAST_SIGHT_MASK)).is_empty():
			continue  # a wall between: the blast does not reach
		var amount: float = base * combat.damage_scale(shooter)
		var way: Vector3 = (middle - at).normalized()
		# The host's own blast lands as its own; another player's as theirs (its kill told to them).
		if (dummy.hit(amount, middle, way, weapon) == true) if shooter == 1 else _hit_daemon(dummy, shooter, amount, middle, way, weapon):
			hurt += 1
	var ice := IceDirector.of(_arena)
	if ice != null:
		hurt += ice.blast(at, base_at, combat.damage_scale(shooter), weapon, space)  # and ICE (I1)
	return hurt


# --- ICE (I1). ---

## Every physics step hosting: while ICE is on and anyone has joined, the ICE director's word to every
## joiner at the sync rate.
func _tick_ice(delta: float) -> void:
	var ice := IceDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if ice == null or not ice.decides() or players.size() < 2:
		_ice_wait_s = 0.0
		return
	_ice_wait_s -= delta
	if _ice_wait_s > 0.0:
		return
	_ice_wait_s += 1.0 / _t.sync_rate_hz
	var w: Dictionary = ice.word()
	var bw: Dictionary = ice.black_word()
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_ice.rpc_id(id, w["round"], w["seeds"], w["healths"], w["words"], w["times"], w["hunter"], w["weapon"], w["percent"], bw["seed"], bw["word"])


## The host's ICE, at the sync rate (I1): the round; every piece's seed, health, word and seconds into
## it (the two walls, the two nodes, the hunter, in the director's order); the hunter's place, yaw,
## aim (arena space) and reach; the adaptation's weapon and percent; and (I3) Black ICE's seed and word
## (IceDirector's black_word(): its phase, the seconds into it, its seals, its place, yaw, brain state and
## time, SIGSTOP's hold, the hits that flashed it, a broken seal's mend), in the same packet so it never
## runs out of step with the rest of ICE. A joiner's ICE plays it.
@rpc("authority", "call_remote", "unreliable_ordered")
func _ice(round: int, seeds: PackedInt32Array, healths: PackedFloat32Array, words: PackedByteArray, times: PackedFloat32Array, hunter: PackedFloat32Array, weapon: String, percent: int, black_seed: int, black: PackedFloat32Array) -> void:
	if state != State.JOINED or host_practice or not host_ice or _arena == null or not is_instance_valid(_arena):
		return
	var n := IceDirector.PIECE_COUNT
	if round < 1 or round > IceTuning.ROUND_LAST or seeds.size() != n or healths.size() != n or words.size() != n or times.size() != n or hunter.size() != 8:
		return
	if percent < 0 or percent > 100 or weapon.length() > WEAPON_ID_LAST or (weapon != "" and not _weapons.has(weapon)):
		return
	for i in n:
		if seeds[i] < 0 or not is_finite(healths[i]) or healths[i] < 0.0 or healths[i] > 100000.0 or not is_finite(times[i]) or times[i] < 0.0 or times[i] > DAEMON_TIME_LAST:
			return
	for v in hunter:
		if not is_finite(v) or absf(v) > WORLD_LAST:
			return
	if not _black_ok(black_seed, black):
		return
	var ice := IceDirector.of(_arena)
	if ice == null:
		return
	ice_words += 1
	ice.take_word(round, seeds, healths, words, times, hunter, weapon, percent)
	black_words += 1
	ice.take_black_word(black_seed, black)


## True for a sound Black ICE word from the host (I3): a seed, and BLACK_WORD finite numbers in the
## world's range, its phase one of BlackIce.Phase, its seals within SEALS_LAST, its times not negative.
func _black_ok(seed: int, word: PackedFloat32Array) -> bool:
	if seed < 0 or word.size() != IceDirector.BLACK_WORD:
		return false
	for v in word:
		if not is_finite(v) or absf(v) > WORLD_LAST:
			return false
	return word[0] >= 0.0 and word[0] <= BlackIce.Phase.GONE and word[2] >= 0.0 and word[2] <= BlackIceTuning.SEALS_LAST and word[1] >= 0.0 and word[8] >= 0.0 and word[10] >= 0.0 and word[11] >= 0.0 and word[12] >= 0.0 and word[12] <= FreezeTuning.BLACK_SLOW_LAST


## Hosting: Black ICE touched player `id` (I3, the host's ICE director's judgement): a flatline. All of its
## health taken at once in the match's combat (spawn protection holds), told to everyone as a death by
## Black ICE, and held down, no respawn, until the host's ICE starts its next round. True when it did.
func black_ice_flatline(id: int, _black: Node, way: Vector3) -> bool:
	if state != State.HOSTING or combat == null or not combat.has_player(id) or _arena == null or not is_instance_valid(_arena):
		return false
	var outcome := combat.damage_player(id, id, combat.health_of(id) + _ct.max_health)
	if outcome.is_empty() or not outcome["killed"]:
		return false
	var ice := IceDirector.of(_arena)
	_flat_round[id] = ice.round_number if ice != null else 0
	var local_way: Vector3 = (_arena.global_transform.basis.inverse() * way).normalized() if not way.is_zero_approx() else Vector3.FORWARD
	_broadcast_death(id, id, local_way, BLACK_CAUSE)
	_mirror_from_combat()
	_flush_sudo()
	return true


## True while player `id` is down by Black ICE's flatline (I3): out until the host's next round.
func flatlined(id: int) -> bool:
	return _flat.get(id, false)


## Hosting: a flatline is over when the host's ICE is on a new round (or off, or gone): that player's
## respawn comes due now.
func _tick_flatlined() -> void:
	if _flat_round.is_empty():
		return
	var ice := IceDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	for id in _flat_round.keys():
		if ice == null or not ice.decides() or ice.round_number != _flat_round[id] or not combat.has_player(id):
			_flat_round.erase(id)
			if combat.has_player(id) and not combat.alive(id):
				combat.defer_respawn(id, RESPAWN_RETRY_S)


## Hosting: a field of this arena's ICE reached joiner `id`: its `kind` (IceDirector.Effect) for
## `seconds`, a jam on `weapon` (its drawn one, as the host counts it).
func ice_effect(id: int, kind: int, seconds: float, weapon: String) -> void:
	if state != State.HOSTING or id == 1 or not multiplayer.get_peers().has(id):
		return
	_ice_effect.rpc_id(id, kind, seconds, weapon)


## An ICE field reached this player, from the host: its effect here.
@rpc("authority", "call_remote", "reliable")
func _ice_effect(kind: int, seconds: float, weapon: String) -> void:
	if state != State.JOINED or host_practice or not host_ice or _arena == null or not is_instance_valid(_arena):
		return
	if (kind != IceDirector.Effect.JAM and kind != IceDirector.Effect.HUD) or not is_finite(seconds) or seconds <= 0.0 or seconds > 60.0:
		return
	if weapon.length() > WEAPON_ID_LAST or (weapon != "" and not _weapons.has(weapon)):
		return
	var ice := IceDirector.of(_arena)
	if ice != null:
		ice.take_effect(kind, seconds, weapon)


# --- ICEbreakers (I2). ---

## This player pressed U with a breaker of `kind` loaded, from its eye along `aim` (world space): on a
## joiner only a request to the host, which runs it from where it last heard this player's eye.
func breaker_intent(kind: int, _eye: Vector3, aim: Vector3) -> void:
	if state != State.JOINED or _arena == null or not is_instance_valid(_arena) or not multiplayer.get_peers().has(1):
		return
	breaker_asks += 1
	_breaker.rpc_id(1, lives.get(my_id, 0), kind, (_arena.global_transform.basis.inverse() * aim).normalized())


## A joiner's ask to run its loaded breaker, to the host. Untyped like _fire: wrong types are counted,
## never an engine error.
@rpc("any_peer", "call_remote", "reliable")
func _breaker(life: Variant, kind: Variant, dir: Variant) -> void:
	if state != State.HOSTING or combat == null:
		return
	if typeof(life) != TYPE_INT or typeof(kind) != TYPE_INT or typeof(dir) != TYPE_VECTOR3:
		breaker_refused += 1
		return
	_handle_breaker(multiplayer.get_remote_sender_id(), life, kind, dir)


## The host's check of a joiner's breaker ask: a known, live player in this life, a kind that exists,
## a way to aim, not frozen by chmod 000 (C29); then the breakers' director runs it (or refuses it: none
## of that kind, too soon).
func _handle_breaker(id: int, life: int, kind: int, dir: Vector3) -> void:
	var breakers := BreakerDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	var eye := _eye_of(id) if players.has(id) else Vector3.INF
	if breakers == null or not eye.is_finite() or life != lives.get(id, 0) or not combat.alive(id) or combat.frozen(id) or kind < 0 or kind >= Breakers.NAMES.size() or not dir.is_finite() or dir.length_squared() < 0.0001:
		breaker_refused += 1
		return
	var aim: Vector3 = (_arena.global_transform.basis * dir).normalized()
	if not breakers.handle_intent(id, kind, _arena.to_global(eye), aim):
		breaker_refused += 1


## Every physics step hosting: while breakers are carried and anyone has joined, each joiner's own
## breaker word at the sync rate.
func _tick_breakers(delta: float) -> void:
	var breakers := BreakerDirector.of(_arena) if _arena != null and is_instance_valid(_arena) else null
	if breakers == null or not breakers.decides() or players.size() < 2:
		_breaker_wait_s = 0.0
		return
	_breaker_wait_s -= delta
	if _breaker_wait_s > 0.0:
		return
	_breaker_wait_s += 1.0 / _t.sync_rate_hz
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			var w: Dictionary = breakers.word_for(id)
			_breakers.rpc_id(id, w["counts"], w["timers"], w["decoys"], w["pickups"], w["brute"], w["ran"], w["seeds"])


## The host's word on this joiner's breakers (I2), at the sync rate: its own counts by kind, its
## exploit's and cloak's seconds left, every decoy (arena space, its call left, landed or -1 for none),
## every pickup spot (0 none, else 1 + its kind), the last brute charge (its count, from, way), its own
## last run and pickup (a count and a kind each), and every decoy's and pickup's seed.
@rpc("authority", "call_remote", "unreliable_ordered")
func _breakers(counts: PackedByteArray, timers: PackedFloat32Array, decoys: PackedFloat32Array, pickups: PackedByteArray, brute: PackedFloat32Array, ran: PackedInt32Array, seeds: PackedInt32Array) -> void:
	if state != State.JOINED or host_practice or _arena == null or not is_instance_valid(_arena):
		return
	if counts.size() != Breakers.NAMES.size() or timers.size() != 2 or decoys.size() != BreakerDirector.DECOYS_LAST * BreakerDirector.DECOY_WORD or pickups.size() != BreakerDirector.SPOTS.size() or brute.size() != BreakerDirector.BRUTE_WORD:
		return
	if ran.size() != 4 or seeds.size() != BreakerDirector.DECOYS_LAST + BreakerDirector.SPOTS.size() or ran[0] < 0 or ran[2] < 0 or not Breakers.valid(ran[1]) or not Breakers.valid(ran[3]):
		return
	for v in seeds:
		if v < 0:
			return
	for c in counts:
		if c > BreakerTuning.CARRY_LAST:
			return
	for p in pickups:
		if p > Breakers.NAMES.size():
			return
	for v in timers:
		if not is_finite(v) or v < 0.0 or v > 60.0:
			return
	for v in decoys + brute:
		if not is_finite(v) or absf(v) > WORLD_LAST * 1000.0:
			return
	var breakers := BreakerDirector.of(_arena)
	if breakers == null:
		return
	breaker_words += 1
	breakers.take_word(counts, timers, decoys, pickups, brute, ran, seeds)


func _broadcast_death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	_apply_death(victim, killer, dir, weapon)
	var connected := multiplayer.get_peers()
	for id in players:
		if id != 1 and connected.has(id):
			_death.rpc_id(id, victim, killer, dir, weapon)


## A player went down, from the host, and to which weapon.
@rpc("authority", "call_remote", "reliable")
func _death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	if state != State.JOINED or not players.has(victim) or not players.has(killer) or not dir.is_finite() or not (_weapons.has(weapon) or weapon == LIGHT_TRAIL or daemon_of(weapon) >= 0 or weapon == ICE_CAUSE or weapon == BLACK_CAUSE):
		return
	_apply_death(victim, killer, dir, weapon)


func _apply_death(victim: int, killer: int, dir: Vector3, weapon: String) -> void:
	dead[victim] = true
	health[victim] = 0.0
	last_killer[victim] = killer
	last_killer_name[victim] = players.get(killer, {}).get("name", assigned_name("", 0))
	last_kill_word[victim] = _feed_word(victim, weapon)
	last_kill_self[victim] = _weapons[weapon].self_kill_word if killer == victim and _weapons.has(weapon) else ""
	if daemon_of(weapon) >= 0 or weapon == ICE_CAUSE or weapon == BLACK_CAUSE:
		last_killer_name[victim] = _daemon_name(weapon)  # derezzed by the daemon, named as this screen shows it (C27b); or by hunter ICE (I1), or Black ICE (I3)
		last_kill_self[victim] = FLAT_WORD if weapon == BLACK_CAUSE else DAEMON_WORD
	if killer == my_id and killer != victim and _weapons.has(weapon) and _player_ready():
		if _weapons[weapon].is_ult():
			_player.rail_kill.emit(_player.took_head(victim))
		else:
			_player.add_meter(_player.meter_gain(0.0, true))  # the kill bonus
	respawn_left[victim] = _ct.respawn_delay_s
	if weapon == BLACK_CAUSE:
		_flat[victim] = true  # out until the round ends (I3): no countdown
		respawn_left[victim] = 0.0
	var trails := LightTrails.find(_arena)
	if trails != null:
		trails.clear(victim)  # a death takes that player's walls away
	if victim == my_id:
		if _player != null and is_instance_valid(_player) and _player.has_method("set_alive"):
			_player.set_alive(false)
	else:
		var avatar = avatars.get(victim)
		if avatar != null and is_instance_valid(avatar):
			avatar.die(dir)
	player_died.emit(victim, killer)
	combat_changed.emit()


## The kill feed's word for `victim` killed by `weapon`: its kill word, and for the rail the
## victim's fake process id after it ("SIGKILL 4107").
func _feed_word(victim: int, weapon: String) -> String:
	if weapon == LIGHT_TRAIL:
		return LIGHT_TRAIL_WORD
	if daemon_of(weapon) >= 0 or weapon == ICE_CAUSE or weapon == BLACK_CAUSE:
		return _daemon_name(weapon)
	if not _weapons.has(weapon):
		return ""
	var def: WeaponDefScript = _weapons[weapon]
	if not def.feed_pid:
		return def.kill_word
	return "%s %d" % [def.kill_word, fake_pid(players.get(victim, {}).get("slot", 0), lives.get(victim, 0))]


func _player_ready() -> bool:
	return _player != null and is_instance_valid(_player) and _player.has_method("add_meter")


func _do_respawn(id: int) -> void:
	var pos := _pick_spawn(id)
	combat.respawn(id)
	_mirror_from_combat()
	var life: int = lives.get(id, 0) + 1
	var held := combat.drawn_by(id)
	_apply_respawn(id, life, pos, _ct.spawn_protection_s, combat.health_of(id), held)
	var connected := multiplayer.get_peers()
	for peer in players:
		if peer != 1 and connected.has(peer):
			_respawn.rpc_id(peer, id, life, pos, _ct.spawn_protection_s, combat.health_of(id), held)


## True while some living opponent of `id` has sent no position since this arena attached.
func _opponents_unseen(id: int) -> bool:
	for other in players:
		if other == id or other == 1 or not combat.alive(other):
			continue
		var avatar = avatars.get(other)
		if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
			return true
	return false


## The arena's spawn point farthest from the nearest living opponent, in arena space.
func _pick_spawn(id: int) -> Vector3:
	var spawns := []
	if _arena != null and is_instance_valid(_arena):
		var node := _arena.get_node_or_null(SPAWNS_NODE)
		if node != null:
			for marker in node.get_children():
				if marker is Node3D:
					spawns.append(_arena.to_local(marker.global_position))
	if spawns.is_empty():
		spawns.append(FALLBACK_SPAWN)
	var threats := []
	for other in players:
		if other == id or not combat.alive(other):
			continue
		if other == 1:
			if _player != null and is_instance_valid(_player):
				threats.append(_player.position)
		else:
			# A player just put at a spawn, with no new position yet, stands there all the same.
			var avatar = avatars.get(other)
			if avatar != null and is_instance_valid(avatar) and avatar.visible:
				threats.append(avatar.latest_position())
	return Combat.farthest_spawn(spawns, threats)


## A player is back, from the host: its new life number, where, how long safe, with what
## health.
@rpc("authority", "call_remote", "reliable")
func _respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float, held: String) -> void:
	if state != State.JOINED or not players.has(id) or life < 0 or not pos.is_finite() or not is_finite(protect_s) or protect_s < 0.0 or not is_finite(new_health) or new_health <= 0.0 or new_health > _ct.max_health or not _weapons.has(held):
		return
	_apply_respawn(id, life, pos, protect_s, new_health, held)


## A respawn, with `held`, the weapon in the player's hand as the host counts it: this
## player takes it, so a draw that crossed its death leaves no difference behind.
func _apply_respawn(id: int, life: int, pos: Vector3, protect_s: float, new_health: float, held: String) -> void:
	dead[id] = false
	_flat.erase(id)
	health[id] = new_health
	protect_left[id] = protect_s
	lives[id] = life
	respawn_left.erase(id)
	var trails := LightTrails.find(_arena)
	if trails != null:
		trails.clear(id)  # a new life starts its walls afresh where it stands
	if id == my_id:
		if _player != null and is_instance_valid(_player) and _arena != null and is_instance_valid(_arena):
			if _player.has_method("respawn_at"):
				_player.respawn_at(_arena.to_global(pos))
			if _player.has_method("set_alive"):
				_player.set_alive(true)
			if _player.has_method("hold_weapon"):
				_player.hold_weapon(held)
		else:
			_pending_spawn = pos  # the arena is reloading: the next one puts the player there
			_pending_weapon = held
	else:
		var avatar = avatars.get(id)
		if avatar != null and is_instance_valid(avatar):
			avatar.revive(pos)
	_show_avatar_state(id)
	player_respawned.emit(id)
	combat_changed.emit()


func _tick_protection(delta: float) -> void:
	var any := false
	for id in protect_left.keys():
		if protect_left[id] > 0.0:
			protect_left[id] = maxf(protect_left[id] - delta, 0.0)
			any = true
			if protect_left[id] == 0.0:
				_show_avatar_state(id)
	for id in respawn_left.keys():
		respawn_left[id] = maxf(respawn_left[id] - delta, 0.0)
		any = true
	if any:
		combat_changed.emit()


## The host's own screen shows the authority's numbers.
func _mirror_from_combat() -> void:
	if combat == null:
		return
	for id in combat.states:
		health[id] = combat.health_of(id)
		dead[id] = not combat.alive(id)


func _drop_avatar(id: int) -> void:
	var avatar = avatars.get(id)
	avatars.erase(id)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()


# --- Pure helpers, checked on their own by the test. ---

## True for an address on this machine, a private LAN or a tailnet: IPv4 loopback, 10/8,
## 172.16/12, 192.168/16, the 100.64/10 shared range tailnets use, link-local 169.254/16;
## IPv6 loopback, unique-local fc00::/7 and link-local fe80::/10. A rendezvous may only send
## a joiner to one of these until relay hosting is decided.
static func local_address(ip: String) -> bool:
	if not ip.is_valid_ip_address():
		return false
	if ip.contains(":"):
		var g := ipv6_groups(ip)
		if g.size() != 8:
			return false
		if g == PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 1]):
			return true
		if g[0] == 0 and g[1] == 0 and g[2] == 0 and g[3] == 0 and g[4] == 0 and g[5] == 0xFFFF:
			return local_address("%d.%d.%d.%d" % [g[6] >> 8, g[6] & 0xFF, g[7] >> 8, g[7] & 0xFF])  # IPv4-mapped
		return (g[0] & 0xFE00) == 0xFC00 or (g[0] & 0xFFC0) == 0xFE80
	var o := ip.split(".")
	var a := int(o[0])
	var b := int(o[1])
	return a == 127 or a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


## An IPv6 address as its eight 16-bit groups, "::" expanded and a trailing IPv4 part folded
## in; empty when it is not one.
static func ipv6_groups(ip: String) -> PackedInt32Array:
	var text := ip.to_lower()
	var tail4 := PackedStringArray()
	var last := text.rfind(":")
	if last >= 0 and text.substr(last + 1).contains("."):
		tail4 = text.substr(last + 1).split(".")
		if tail4.size() != 4:
			return PackedInt32Array()
		text = text.substr(0, last + 1) + "0:0"
	var halves := text.split("::")
	if halves.size() > 2:
		return PackedInt32Array()
	var head := halves[0].split(":", false)
	var tail := halves[1].split(":", false) if halves.size() == 2 else PackedStringArray()
	var gap := 8 - head.size() - tail.size()
	if (halves.size() == 1 and gap != 0) or (halves.size() == 2 and gap < 1):
		return PackedInt32Array()
	var out := PackedInt32Array()
	for part in head:
		out.append(_hex_group(part))
	for i in gap if halves.size() == 2 else 0:
		out.append(0)
	for part in tail:
		out.append(_hex_group(part))
	if out.has(-1):
		return PackedInt32Array()
	if not tail4.is_empty():
		for octet in tail4:
			if not octet.is_valid_int() or int(octet) < 0 or int(octet) > 255:
				return PackedInt32Array()
		out[6] = (int(tail4[0]) << 8) | int(tail4[1])
		out[7] = (int(tail4[2]) << 8) | int(tail4[3])
	return out


static func _hex_group(part: String) -> int:
	if part.is_empty() or part.length() > 4 or not part.is_valid_hex_number():
		return -1
	return part.hex_to_int()


## True for a sequence number a sender could have counted to.
static func seq_sane(seq: int) -> bool:
	return seq >= 1 and seq < SEQ_LAST


## True when every number of a state packet is one a player could have.
static func sane(pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> bool:
	if not pos.is_finite() or not vel.is_finite() or not is_finite(yaw) or not is_finite(pitch):
		return false
	if absf(pos.x) > WORLD_LAST or absf(pos.y) > WORLD_LAST or absf(pos.z) > WORLD_LAST:
		return false
	return absf(yaw) <= YAW_LAST and absf(pitch) <= PITCH_LAST and vel.length() <= SPEED_LAST


## The name a player is shown under: "Daemon-<slot>", always. A requested name is read
## and checked but never used for the name, so no joiner can call itself Daemon-1 or
## borrow another player's name; the slot alone tells players apart. Never anything from
## the system.
static func assigned_name(_requested: String, slot: int) -> String:
	return "%s%d" % [DAEMON, slot]


## {host, port, ip} from what the player typed, or {} when it is not an address. Accepts
## "ip", "ip:port", "name", "name:port", "[v6]" and "[v6]:port"; a bare IPv6 address with
## its colons is taken whole. `default_port` fills in a missing port.
static func parse_address(text: String, default_port: int) -> Dictionary:
	var s := text.strip_edges()
	if s.is_empty() or s.length() > ADDRESS_LAST:
		return {}
	var host := s
	var port_text := ""
	if s.begins_with("["):
		var close := s.find("]")
		if close < 0:
			return {}
		host = s.substr(1, close - 1)
		var rest := s.substr(close + 1)
		if rest != "":
			if not rest.begins_with(":"):
				return {}
			port_text = rest.substr(1)
	elif s.count(":") == 1:
		var parts := s.split(":")
		host = parts[0]
		port_text = parts[1]
	var port := default_port
	if port_text != "":
		if port_text.length() > 5:
			return {}
		for i in port_text.length():
			var code := port_text.unicode_at(i)
			if code < 0x30 or code > 0x39:
				return {}
		port = int(port_text)
	if port < 1 or port > PORT_LAST:
		return {}
	if host.is_valid_ip_address():
		return {"host": host, "port": port, "ip": true}
	if not hostname_ok(host):
		return {}
	return {"host": host, "port": port, "ip": false}


## True for a host name made of letters, digits and hyphens in dot-separated labels.
static func hostname_ok(name: String) -> bool:
	if name.is_empty() or name.length() > HOSTNAME_LAST:
		return false
	for label in name.split("."):
		if label.is_empty() or label.length() > LABEL_LAST or label.begins_with("-") or label.ends_with("-"):
			return false
		for i in label.length():
			var code := label.unicode_at(i)
			var ok := (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) or code == 0x2D
			if not ok:
				return false
	return true


## The joiner's hello: "SK", the protocol version, the name's length and the name.
static func hello_bytes(version: int, name: String) -> PackedByteArray:
	var shown := name if Tuning.name_ok(name) else PLACEHOLDER
	var out := PackedByteArray([MAGIC_0, MAGIC_1, 0, 0, 0])
	out.encode_u16(2, clampi(version, 0, VERSION_LAST))
	out.encode_u8(4, shown.length())
	out.append_array(shown.to_ascii_buffer())
	return out


## {version, name} from a hello, or {} when it is not one. A name the game cannot show
## becomes the placeholder.
static func parse_hello(data: PackedByteArray) -> Dictionary:
	if data.size() < HELLO_HEAD or data[0] != MAGIC_0 or data[1] != MAGIC_1:
		return {}
	var n := data.decode_u8(4)
	if data.size() != HELLO_HEAD + n:
		return {}
	var name := data.slice(HELLO_HEAD).get_string_from_ascii()
	return {"version": data.decode_u16(2), "name": name if Tuning.name_ok(name) else PLACEHOLDER}


## The host's reply: "SK", its version, the verdict, the slot and the assigned name.
static func reply_bytes(version: int, verdict: int, slot: int, name: String) -> PackedByteArray:
	var out := PackedByteArray([MAGIC_0, MAGIC_1, 0, 0, 0, 0, 0])
	out.encode_u16(2, clampi(version, 0, VERSION_LAST))
	out.encode_u8(4, clampi(verdict, 0, Verdict.size() - 1))
	out.encode_u8(5, clampi(slot, 0, SLOT_LAST))
	out.encode_u8(6, name.length())
	out.append_array(name.to_ascii_buffer())
	return out


## {version, verdict, slot, name} from a reply, or {} when it is not one, or an ok reply
## has no slot or no name the game can show.
static func parse_reply(data: PackedByteArray) -> Dictionary:
	if data.size() < REPLY_HEAD or data[0] != MAGIC_0 or data[1] != MAGIC_1:
		return {}
	var n := data.decode_u8(6)
	if data.size() != REPLY_HEAD + n:
		return {}
	var verdict := data.decode_u8(4)
	if verdict >= Verdict.size():
		return {}
	var slot := data.decode_u8(5)
	var name := data.slice(REPLY_HEAD).get_string_from_ascii()
	if verdict == Verdict.OK and (slot < 1 or not Tuning.name_ok(name)):
		return {}
	return {"version": data.decode_u16(2), "verdict": verdict, "slot": slot, "name": name}


func _port_free(port: int) -> bool:
	var probe := PacketPeerUDP.new()
	var ok := probe.bind(port, _t.bind_address) == OK
	probe.close()
	return ok


## A port on the bind address the system has just handed out and given back, or 0.
func _spare_port() -> int:
	var probe := PacketPeerUDP.new()
	var port := probe.get_local_port() if probe.bind(0, _t.bind_address) == OK else 0
	probe.close()
	return port
