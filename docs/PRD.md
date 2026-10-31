# SIGKILL PRD (v0.7, 2026-10-31)

Owner: Fred Nix. Producer: SIGKILL bot. All code: Larry (Claude Code, the project dir).
Engine: Godot 4 (pick documented in docs/ENGINE.md; Fred approved Godot 4.7.2 from pacman).
License: MIT (Fred, 2026-10-28 9:57 PM ET); the repository nixfred/sigkill is public. Stage: pre-alpha; the latest release is [v0.33.0-prealpha](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha) (2026-10-30).

This is the entire, current PRD (Fred, 2026-10-30 8:37 PM ET). [docs/DESIGN.md](DESIGN.md) is the decision log behind it: every decision in its own words, and every chunk as built. [docs/STORY.md](STORY.md) is the locked story bible and the source of truth for the story. Section numbers are kept from v0.1, since the code, the tests and the other docs cite them ("PRD 5.7"); new sections are added after the old ones.

## Scope: 1.0, after 1.0, and 2.0

- **1.0 is locked** (Fred, 2026-10-29 10:42 AM ET): everything in the design doc at the lock is 1.0. In this PRD that is sections 1 to 5.9, the safety rules (6) and every chunk in section 8 down to C44, apart from what is marked post-1.0 or 2.0 below.
- **Post-1.0:** every new idea after the lock, unless Fred pulls it in. That includes the community ideas from Carlos Granier, Jeremy and MindGameLabs (5.10). One older decision is post-1.0 in its own words: ICE taking its look from the names of security software on the host (1.x, with process enemies; 5.9). VR is a stretch beyond that, likely 2.x.
- **2.0:** the browser version (Fred, 2026-10-28 12:46 AM ET): a Godot web export (WebGL renderer, shader fallbacks) on the WebSocket relay, with demo-data maps only (no filesystem, processes, local announcer or voice in a browser). It is not being built now; the native game ships first.
- **Set aside:** the story's forks that were not picked (a second ending, nine missions, co-op missions; STORY.md section 8) are not planned at all.

## 1. Pitch
A native linux FPS for Omarchy. You are the nixfred >_ hexagon, deep inside your own machine, hunting rogue daemons, zombie processes and runaway apps. cyberpunk ruins, Tron light-grid arenas, Matrix code rain, a story campaign, a big command-line arsenal, fast arena gunplay, and your OWN local AI riding along as your guide. Play solo against daemons or jump into a match with a friend across the internet in seconds.

## 2. Quality bar
"Rockstar quality" means: nothing ships that feels placeholder. Every chunk is judged on game feel (movement, recoil, hit feedback, audio), visual polish (lighting, glow, VFX), stability (no errors in the log, steady frame time) and clarity (the player always knows what happened and why). We get there by small chunks that are each finished properly, not by big drops.

## 3. Visual direction
- Tron: pure black void, neon light-edges on every surface, glowing floor grid, teal/mint on black for the player, red/amber for hostiles. Bloom and glow, light fog.
- Matrix: green glyph code rain that bleeds through walls when daemons are near; code-rain vision mode; slow-mo with motion trails.
- Brand: locked nixfred hexagon (icon-only, white >_) as game icon, splash, README. Never redesigned.
- All art and audio original or properly licensed.

### 3.1 The art bar, as built (A1 to A5)
- **The art pass** (producer, 2026-10-28 9:05 AM ET) ran right after C27 and before C28, so playsigkill.com launched with real screenshots; A5 came after C28. Original procedural and shader art only, no paid or ripped assets.
- **A1, weapon viewmodels:** every weapon is held as its own model, built in code from simple shapes (boxes, prisms, tubes and a ">" glyph): dark gunmetal and polymer under neon trim in the weapon's own colour, with its beams and muzzle flash starting at the barrel's tip.
- **A2 and A2b, enemies as creatures** (after Fred's "boxes, yawn" note, 2026-10-28): articulated, procedurally animated creatures of rigid crystal parts posed every frame, with hit reactions and shard deaths.
- **A3, the arena:** depth, trims, props, terminal signs, a stepped plinth, a skyline, sky and fog. It is visual only and adds no collision.
- **A4, lighting, post and particles:** the AgX tonemapper, so hot red never drifts orange and teal never goes flat. A capped glow, and SSAO and SSR only where they are cheap. A subtle grade, with chromatic aberration and CRT scanlines as settings, and pooled GPU particles (a muzzle burst for each weapon family, sparks, derezz bits, trails). Hostile reds and magentas mark danger, warm amber the signs and key lights, teal and mint the player. Graphics presets are low, medium (aimed at an RTX 4050-class laptop GPU) and high, plus individual toggles.
- **A5, the monster redo** (Fred, 2026-10-28 9:50 PM ET: "All the enemies look the same, have the same color... I want REALLY cool monsters"): every daemon has a solid dark armoured body, lit only in its seams and weak points (Tron Legacy style, not glowing wireframe), still faceless and geometric. **One colour per type:**
  - **rogue.d, crimson `#ff1230`:** an obsidian mantis-scorpion with scythe arms and one visor slit. It rears tall before it lunges.
  - **The zombie, amber `#ffb000`:** hulking, half armour and half peeling voxels, with a cannon arm that charges its bolt and a limp.
  - **The runaway, hot magenta `#ff1ba4`:** a swarm of hex drones with blade wings orbiting a bigger core drone. Killing the core scatters the swarm.
  - **ICE** has its own glacier and cobalt (5.9).
- **No clone daemons** (Fred, 2026-10-28 9:51 PM ET: "dont make all the monsters of the same type be exact copies that gets boring"): each daemon is built from a per-spawn seed, so no two of a type are alike. They differ in size (within a hitbox-safe range), plate layout, seam pattern, stance, gait timing and battle damage. Each type has a rare elite variant, bigger and with extra parts. Every type keeps its colour and silhouette, so the player always knows what it is. Demo and test seeds are fixed, so captures and tests stay deterministic.

## 4. Core loop (v1)
Fast arena deathmatch (PvP) plus a solo/co-op daemon hunt (PvE), same arenas, same weapons.
- **Daemons fight back** (producer, 2026-10-28 6:25 PM ET; built in C27b). Solo play has player health and real daemon AI with readable tells: rogue.d rears before its lunge, a zombie charges its bolt, and the swarm gathers before a dive.
- Difficulty is a setting. Practice mode keeps the old dummies that never attack, and in a match the host runs the daemons.

## 5. Features
### 5.1 Multiplayer that just works
- Join by 6-character room code or a `sigkill://` invite link. No port forwarding.
- Peer-to-peer with NAT punch-through; a tiny matchmaking/relay service for "find me an opponent" and fallback relay. (Hosting cost: Fred decides before anything is deployed.)
- Tailnet/LAN mode: instant play between machines on the same network.
- Built on Godot high-level multiplayer (ENet / WebRTC data channels for punch-through).
- **As built:**
  - **C13:** LAN and tailnet host and join by address.
  - **C14:** synced combat.
  - **C15:** room codes and invite links, on the client side.
  - **C16c:** the relay, local only. Every room-code match goes through it rather than a direct link after the rendezvous (docs/RELAY.md).
  - **C16d:** a WebSocket relay mode for proxy-only hosts (producer, 2026-10-28). The game picks the transport from the relay URL's scheme, and UDP stays the VPS alternative.
- **Nothing is hosted.** With no relay set, room codes answer "Online rooms aren't live yet. Use LAN join (address)." Relay hosting and its budget wait on Fred (section 9, question 1).

### 5.2 Arsenal: signals and shell commands (DECIDED by Fred 2026-10-25 10:25 PM ET)
Lots of guns. Every weapon is a signal or shell command made physical, and every one gets its own Tron light skin, mods and unlocks earned by playing.
- Terminal cannon: default hitscan rifle.
- SIGTERM: polite shotgun.
- SIGHUP: confusion grenade; enemies "reload" and wander.
- SIGKILL / `kill -9`: uncatchable rail rifle that one-shots and derezzes, the ult. "kill -9" headshot callout.
- `fork()`: shotgun whose pellets split in two mid-flight.
- Fork bomb: grenade that splits 1, 2, 4, 8.
- `grep`: seeker smart gun that locks onto a marked target.
- `rm -rf`: slow, devastating cannon with friendly-fire risk.
- `cron`: timed mines.
- `ping`: sonar pulse that reveals hidden daemons.
- `chmod 000`: freeze ray.
- `pipe |`: chain beam that arcs between enemies.
- `/dev/null`: black-hole grenade.
- `sudo`: power-up that unlocks overcharge on the current weapon (ties into Root vs user).
- Bullet time stays the SIGSTOP ability (5.3). Weapons are cosmetic fiction only: none of them run, signal or touch anything real.

**As built: thirteen weapons on two banks** (C6, C16 to C32). Keys 1 to 9 draw bank 1, and Shift+1 to Shift+4 draw bank 2 (C29). Q swaps to the last weapon, and the weapon cycle reaches every one. All of a weapon's numbers live in one `WeaponDef` resource (`resources/<id>.tres`, the loadout `resources/arsenal.tres`).

| Key | Weapon | What it does, as built | Chunk |
|---|---|---|---|
| 1 | Terminal cannon | The default hitscan rifle, with infinite ammo | C6, C16 |
| 2 | SIGTERM | The polite shotgun: nine pellets in a cone, a slow pump, damage that falls off with distance | C16 |
| 3 | SIGKILL / `kill -9` | The rail rifle and the ult. Its meter fills with kills from the other weapons; one rail pierces every target up to the first wall | C17 |
| 4, or G to throw without drawing | Fork bomb | Splits 1, 2, 4, 8. It never hurts its thrower (producer, C19), and in a match the host owns the whole chain | C19 |
| 5 | `fork()` | Pellets fly as fast projectiles and fork in two 4 m out | C24 |
| 6 | `grep` | The seeker: hold aim to build locks, up to three marks (five as root), then one dart per mark | C25 |
| 7 | `rm -rf` | A confirm wind-up, then a slow, heavy slug whose blast hurts its shooter too, at half (the friendly-fire risk) | C26 |
| 8 | `cron` | Timed mines: a stud armed after 1 s that runs three telegraphed blasts | C27 |
| 9 | `ping` | A sonar ring through walls. Every daemon it meets is outlined for 4 s, and one caught mid-tell staggers. No damage | C28 |
| Shift+1 | `chmod 000` | The freeze ray: hold the beam until the target freezes solid for 3 s | C29 |
| Shift+2 | `pipe \|` | The chain beam: up to five links (six as root), each 70% of the one before | C30 |
| Shift+3 | `/dev/null` | The black-hole grenade: a singularity that drags everything in sight toward its core for four seconds | C31 |
| Shift+4 | SIGHUP | The confusion grenade: daemons caught by its wave "reload", wander and lash out at each other | C32 |

- `sudo` is not a weapon slot. Z spends a charge (earned by 3 kills in one life) on 8 s of root: the weapon in hand hits 1.5 times as hard and spends no ammo (C22, 5.3).
- Every key is rebindable in Settings (C16b), and no binding uses Ctrl+Alt.

#### 5.2.1 Unlocks, mods and light skins (built in C33)
- **Earned by playing, and only on this machine:** no store, no money, no account, no network call, no telemetry, nothing to buy. Progress is kept in `user://progress.cfg`.
- **A feat counts only where the daemons are really fighting:** alone against them, or for the host's own player in a match, never in practice. A joiner's feats come from the host's word.
- **Every weapon has its own skin, two more light skins and one mod** (its kit, `resources/<id>_kit.tres`), each unlocked by a feat with that weapon. Feats include kills, kill -9 headshots, a fork bomb's tree derezzing three, pings, freezes, shatters and three-link chains. For example, the cannon's overclock mod comes at 10 kills, its tty1 green skin at 25 and its Dracula skin at 75.
- **The loadout screen** (Esc, Loadout) shows each weapon on a turntable, and a toast says what was just earned.
- Skins keep clear of the hostile colours, measured in OKLab, and protocol 19 carries a player's look into a match.
- Two skins take their names and colours from open terminal themes, Dracula and Catppuccin, with thanks (CREDITS.md).
- **Campaign weapons (C35):** each mission hands out the weapons it teaches for keeps (STORY.md, pick 4), kept among these unlocks as `<weapon>__campaign` and told by the same toast; the loadout screen says which mission hands out each one. Arena play and matches keep the whole arsenal whatever the campaign has handed out.

### 5.3 Abilities and modes
- SIGSTOP bullet time: short meter, Matrix slow-mo; SIGCONT resumes.
- Code-rain vision: see enemies through walls as glyphs, drains fast.
- Light-trail mode: your path leaves a solid neon wall (Tron deathmatch).
- Root vs user: spawn as user, earn sudo for a power spike.
- Derezz deaths: players and daemons shatter into glowing voxels. Kill feed: "SIGKILL <pid> sent by <player>".
- Spectate as top: dead players watch a live process-table style HUD of the match.
- **As built** (every key rebindable, none of them Ctrl+Alt):
  - **SIGSTOP (C18):** F starts it (it needs a quarter of the meter) and F again sends SIGCONT. Alone, the world runs at 0.3x and you at 0.9x.
    - Fairness (producer, C18, 2026-10-27): in a match nothing touches the engine's time scale. The effect is self-only (the look and the pitched-down sound, and zero spread and recoil while the host says it is on), and the host owns and checks every meter.
  - **Code-rain vision (C21):** an ability, not a weapon. Hold V. It has its own meter, about 3 s of use refilling in about 12 s, and while it is on every enemy within about 40 m shows as a green-glyph silhouette through walls.
  - **Light-trail mode (C20):** an optional match rule, off by default. The host turns it on in Settings, Multiplayer, "light trails", or with `-- --light-trails`. Touching any trail wall, your own included, derezzes you and credits the wall's owner.
  - **Root vs user (C22):** every life starts as `user$`, and 3 kills in one life earn one sudo charge. Z shows a cosmetic `[sudo] password for user: ********`, then `root#` for 8 s. The host owns it in a match.
  - **Spectate as top (C23):** while you are dead in a match, a full-width `top` of the match stays up until you respawn. Hold Tab for it any time.
  - **Derezz (C7, C14):** a voxel shatter. The kill feed names the weapon's own signal.

### 5.4 YOUR real AI as the guide (signature feature) (DECIDED by Fred 2026-10-25)
The guide is the player's own AI: the coding agent they already picked in Omarchy. Most players (Fred included) don't have local hardware strong enough for a good guide, so the default agent comes first.
- Source of truth: Omarchy's default-agent setting, the single line in `~/.config/omarchy/defaults/agent` (what `omarchy-default-agent` prints with no args; Omarchy 4.x). Values seen: pi, omp, opencode, claude, codex, grok, gemini, openclaw, hermes, copilot, crush, cursor-agent, muse. Omarchy leaves it unset by default; handle unset.
- Invocation: call that agent's OWN non-interactive mode directly (e.g. `claude -p`, `codex exec` with a read-only sandbox), with tools/edits/shell DISABLED and no auto-approve. NEVER launch through `omarchy-agent` / `omarchy-agent-prompt` (they start agents with skip-approval "yolo" flags). One small adapter per agent behind a common interface; ship Claude Code and Codex adapters first, others later. Unknown agent = fall through to the fallback.
- Fallback order: Omarchy default agent, then a local model server (Ollama :11434, LM Studio :1234, or any local OpenAI-compatible endpoint; localhost only), then a scripted guide with "AI off".
- Proof it's yours: the boot sequence names the agent from the player's own Omarchy setting ("Omarchy default agent: <agent>. Linking...") and shows it answering live; the HUD shows a "your AI" badge, live response latency, and LIVE GPU stats (utilization, VRAM, temp) read-only from nvidia-smi or /sys, with tokens/sec when the local fallback is in use.
- Cost and speed: cloud agents spend the player's own subscription and take seconds. Use them for the boot handshake, ask-anything, between-round coaching and opt-in roasts. Never call per frame or per second; fast in-fight callouts come from game logic. Rate-limit calls, show a "thinking" state, and let the player turn the AI off.
- What it sends: only game stats and what the player types. No file names, paths, process lists or system info. Opt-in on first launch, with a plain description of which agent will be called.
- Model hygiene (local fallback): check what's loaded first, never change shared model settings (e.g. num_ctx), never load a huge model without asking, unload anything the game loaded on exit.
- **As built:**
  - **C9:** the source detector.
  - **C9b:** the Claude Code, Codex and local OpenAI-compatible adapters.
  - **C10:** the boot sequence.
  - **C11:** the guide HUD. T asks your AI anything, and O turns it on or off.
  - **C11b:** a local model loads only with the player's yes.
  - **C12:** round coaching and the opt-in roast announcer, on B.
  - **C41:** the opener's one call, at its link beat (5.7). It is told only that the game is starting, and SIGKILL shows its own copy of the fixed line the AI picked, marked live.
  - **C35:** a mission's lines from your AI are story lines: written, the same for every player, shown in the guide panel as "your AI" with no live mark, never sent to the player's AI. No mission makes a call.
  - **C42:** a replay of the opener keeps the session's calls: once the AI has answered live this session, the replay shows that answer again, marked live and "earlier", and calls nothing (unless the AI was turned off since).
- Tests use fakes and stub binaries only. No test or capture calls a real AI.
- **One voice** (STORY.md, pick 2): every line in the game is "your AI's". An answer that came live from the player's own AI carries a small "live" mark, so no line is ever misattributed.

### 5.5 Your machine is the world (later milestone)
1.0 scope, under the 2026-10-29 lock. "Later" is its place in the build order (8.1), after the opener and the missions. Live process enemies come before the Audit Trail visor (C43), which needs them. Its features other than C43 have no chunk numbers yet; the producer numbers them when they come up.
- Filesystem maps: rooms from the player's real folder tree (names and sizes only), node_modules is the endless maze.
- Live process enemies: real running processes become enemies (browser tabs swarm, pegged CPU core is a boss). Cosmetic only.
- Audit Trail visor (community prompt by Albert / @QuantaCortex, 2026-10-26, accepted by Fred): a visor mode that draws glowing lineage lines from each enemy back to its parent process, up the real process tree. Severing a spawn chain (killing a parent) collapses or reshapes that part of the arena and despawns its children. Reads only PID, parent PID, process name and CPU/memory numbers. Never command-line arguments, open files, environment or paths, so no private file names can show. Severing is cosmetic in-game; nothing real is signaled. Its HUD carries the tag "visor design: @QuantaCortex".
- Theme-shift levels using Omarchy themes; palette-only enemies.
- Keybind gunplay mapped to real Omarchy shortcuts (opt-in, no conflicts).
- Ramblr voice commands (read Ramblr's existing output, never open the mic).
- Packet tracer arena: tailnet machines as islands.
- Hyprland split-screen co-op.

### 5.6 Story: cyberpunk + Matrix + Tron (DECIDED by Fred 2026-10-25 10:25 PM ET)
- Premise: you're a sysadmin jacked into your own machine, because something is spawning processes you never started. Your AI is the only one you trust, until the trail leads to the question of who wrote the daemons.
- Three visual registers, one world: cyberpunk (neon megacorp ruins, rain, signage in the deep directories), Matrix (green code where reality is thin), Tron (clean light grids where the system is healthy). Corruption pushes Tron toward Matrix and cyberpunk decay.
- Delivery: short campaign missions between arenas, told through terminal logs, your AI's lines and environmental storytelling. No long cutscenes. The story is fiction; nothing in it reads or reveals real system data.
- Enemy art bar (Fred): faceless geometric daemons (obsidian shards + floating red glyphs), angular drone swarms, giant red-hot lattice core bosses, voxel derezz deaths. No cartoon monsters.

**The story is locked** (Fred, 2026-10-30 6:10 PM ET). [docs/STORY.md](STORY.md) is the source of truth for the campaign, its characters and the opener's `~` beats. Fred approved it with all ten recommended picks, which are in its section 8. In short, with the spoilers left to STORY.md:
1. **The daemons have an author, and the answer is decided:** `~`. Who `~` is, is the campaign's mystery (STORY.md section 3).
2. **One voice:** "your AI", with a small "live" mark on every answer from the player's own AI.
3. **Seven missions after the opener:** `login`, `defunct`, `while true`, `permission denied`, `sudo !!`, `nohup` and `kill -9`.
4. **Weapons are handed out mission by mission**, all thirteen by mission 6. Arena play and matches keep the whole arsenal from the start.
5. **One ending for 1.0.**
6. **The credits' last row is PID 6666, `~`**, taken by the final `kill -9`.
7. **The copy of you is called `~`** (tilde, home), never the player's username. The username and every real name stay in the opener.
8. **No real data in the campaign.** The missions are fixed fiction, and only the opener reads anything real.
9. **The campaign is solo for 1.0.** Arena play and matches stay multiplayer.
10. **C37 builds mission 1, `login`, first.**

**The missions (M6), after the opener:**
- **C35, the mission framework:** objectives, terminal-log pickups, AI dialogue triggers, the Auditor's log lines, a starting loadout, and the transitions between registers.
  - **As built (C35):** every mission is data, one `MissionDef` file each in `resources/missions/`, checked as it is read. A file names:
    - its title, order, register, goal, loadout and the weapons it hands out;
    - its objectives: kill so many of a daemon type, reach a point, pick up a terminal log, or survive;
    - its terminal logs, its lines (your AI's, the Auditor's, `~`'s), its register shifts, its own fail rule (a time limit) and the mission after it.

    All seven are in from STORY.md: titles, order and handout real, and the objectives of 2 to 7 placeholders their chunks fill in. Mission 1, `login`, plays now as a first cut (on the arena as C35 built it, in its ruins since C36), and C37 builds it for real. A hidden test range (never listed, never recorded) runs every kind.
  - **The runner, in the arena:**
    - a card, then the objectives one after another;
    - the round clock held, ICE standing down unless the mission has it, only its loadout carried (objectives can hand weapons over mid-mission);
    - fail by death or its own rule, then Retry or R reloads into the next try;
    - complete records it and hands its weapons out through the C33 unlocks, all 13 by mission 6 and never sooner;
    - solo only: refused in a match, and ended by one starting.
  - **What the player sees:**
    - the objective panel, with a marker through walls;
    - your AI's story lines in the guide panel (one voice, never through the player's own AI);
    - the Auditor's and `~`'s lines in the mission's terminal, and logs read as `$ cat <name>`;
    - register shifts tearing the screen;
    - `exit 0` and `exit 137` end screens;
    - Esc, Missions (`ls -l /campaign`, locked ones redacted), and Esc mid-mission offering resume, restart and quit, the player shielded while it is open.

    Progress lives in `[missions]` of `user://progress.cfg`: a C33 save loads unchanged, and a missing or damaged one is no progress. Check step 54. Also: quitting while the opener's score is still being made no longer waits for it.
- **C36:** the cyberpunk ruins district art kit.
  - **As built (C36):** the places the missions happen in, original and procedural (code, primitives and shaders; no imported or ripped asset).
    - **Districts are data.** A `RuinsSet` per file in `resources/ruins/` holds a seed, a size, how many ruin blocks, holes, cover, towers, giants, cables and signs, and the demo folder names and sign words. Three ship: `scheduler_breach` (Tron, mission 1's), `deep_dirs` (cyberpunk) and `cache_district` (Matrix).
    - **The plan is seeded and repeatable.** A pure-data layout on 4 m cells:
      - the outline cut into the void, a kept route from the start to the exit, and a plaza;
      - ruin blocks and holes into the void, each kept only if the floor stays one piece;
      - parapets over jump height on every edge, overlooks among them;
      - cover kept only while every point stays walkable (a 0.5 m walk grid);
      - towers in the void, giants far out, cables never lower than 4.6 m over the floor, signs;
      - the named points (`start`, `exit`, `plaza`, `log_n`, `daemon_n`, `breaker_n`, `spawn_n`, `vista_n`) and all the collision, as boxes.
    - **The pieces, no two alike** (each from its own dice): rack towers that slip, lose blades, spill cables and die light by light; giants; directory monoliths with half-lit folder names; fallen towers; cover; broken edges; towers rising out of holes; pylons; cut cables that swing and spark; and neon signs. They are merged per 16 m chunk and kept per set, so a retry builds nothing.
    - **Registers:** Tron, cyberpunk and Matrix, and all three at once for the finale. One shader global blends every ruins shader; the fog, sky, sun, lamps and weather (rain, motes, falling glyphs) follow it. A mission's register shift now changes the world, over 1.4 s with a tear. Every ruins colour keeps 0.1 OKLab or more from the daemons' and ICE's, the signs' magenta `#d24bff` and amber `#ff7a1a` included.
    - **Mission 1 stands in its ruins.** `MissionDef.ruins` names a set, and a reach's or a log's `at` may name a point. The arena loading for such a mission is staged before anything else is made: its level goes, the ruins are built in its place, and the player, spawns, daemons and ICEbreaker pickups move to the ruins' points. ICE stays out of ruins for now. `--ruins=<id>` (with `--demo`) stands an arena in a set with no mission.
    - **The C35 leftovers, done:** the arena's counter hides during a mission, and a reload into a mission comes in from black.
    - **Cost:** about 250,000 triangles, 2.75 to 2.90 ms of GPU a frame at 1920x1080 in the captures (high preset, a recent laptop GPU), and a 1.2 s first build. Check step 55.
- **C37:** mission 1, `login`, end to end.
- **Missions 2 to 7:** one chunk each, after C37.

### 5.7 The opener: "you got tricked into this" (DECIDED by Fred 2026-10-25 10:45 PM ET)
A 2-minute, darkest-possible cold open, real-time in-engine (never pre-rendered), built from the player's real machine so it makes them blink. Skippable after the first viewing.
- 0:00-0:15 Fake crash: black, then a FAKE terminal rendered by the game in the player's active Omarchy theme colors. `<user>@<host>:~$` types itself.
- 0:15-0:35 "thanks for running me." / "you never read the install script, did you?" Real folder names scroll, real uptime ticks. "I've been in here since you booted." Late-night line driven by recent file modification times (mtimes only).
- 0:35-0:50 The fake desktop shrinks away: it was inside the game all along. The fake terminal ignores typing for 3 seconds. "you're in now."
- 0:50-1:10 Fall through the player's directory tree as a city (real folder names on towers, node_modules pit). Their top CPU process, named, pulses red at the bottom.
- 1:10-1:35 "Linking your agent..." The player's real AI answers live, told only that the game is starting. Scripted guide: "I've been stuck in here with them. They look like you." A daemon walks out wearing their username: a copy of them.
- 1:35-2:00 `kill -9` forges into the rifle; the copy types "you won't." Player fires, derezz, kill feed "SIGKILL sent by <user> to <user>", whisper "one of 6666." Black. Title: SIGKILL.
Safety for the opener (on top of section 6):
- Everything "hacked" is rendered fiction; nothing runs, signals or changes. Real data is names, sizes, counts, mtimes and theme colors only, read-only, shown live, never saved, logged or sent (the AI gets none of it).
- A real way out always works: Esc and the window close are never blocked; only the in-fiction terminal ignores typing for 3 seconds.
- First launch: one-line content note plus opt-in "let SIGKILL read your folder and process names?" No = a fake-data version with the same beats.
- Demo-data mode for every capture; trailers never show real machine data.
- Music and SFX original (e.g. generated with ElevenLabs), no ripped audio.

**As built** (C38 to C42: the opener is whole):
- **C38, 0:00 to 0:35, on demo data:**
  - The fake crash, the fake terminal in the theme's colours, and the typed lines.
  - An `OpenerData` seam, read once as the opener starts.
  - `DemoOpenerData`, all invented: `user@workstation`, 28 invented folders, up 3 days 07:42:15.
  - Six demo palettes taken from open themes Omarchy ships (CREDITS.md).
  - To play it: Esc, then "Play the opener", or `godot --path . -- --demo --opener`.
- **C39, the real-data reader, opt-in and read-only:**
  - **Off by default:** Settings, Privacy and AI, "opener data". A missing or damaged setting reads as off, and a demo run always plays demo data. Since C42 the first launch asks too (below).
  - **What it reads, and nothing else:**
    - the user name and the home folder (its only environment)
    - the host name and the uptime, each at most 64 bytes
    - the active Omarchy theme's colours (`#rrggbb` and the mode only, at most 16 KB)
    - folder names under the home folder, how many entries each holds, and modification times
  - **What it never reads:** file contents, byte sizes or processes. It reads names, counts and times only.
  - **Caps:** 3 levels deep, 600 entries, 64 folders listed, 200 entries a folder and 150 ms for the whole read. It keeps 128 folder names and the 256 newest times.
  - **What it skips:**
    - Symbolic links are never listed, walked or timed.
    - node_modules is counted, never walked.
    - A folder on another filesystem stays a name.
    - Hidden folders below the top level are skipped, and file times come only from what is not hidden.
  - **How it runs:** on its own low-priority thread. Any value that is not in by the cut (3.1 s), cannot be read or is unusable falls back to the demo's, one value at a time.
  - **What it never does:** it writes, saves, logs, sends and runs nothing, and the AI gets none of it. Every value is dropped when the opener ends.
- **C40, 0:35 to 1:10:**
  - "you're in now.", with the 3 s in which typing is ignored.
  - The terminal moves into a viewport of its own, pixel for pixel, and shrinks away to one lit screen on a monolith in a city of folders.
  - The fall through the directory tree begins at 0:50 and lands by 1:10. The node_modules pit is walled in the 10 PRINT maze.
  - Nothing new is read. The hot process at the bottom is the demo's "node" for every source, because no reader reads processes yet. The real name comes with the read-only process reader that M5's process enemies and C43 need, under the same opt-in.
- **C41, 1:10 to 1:35** (scripts/opener/opener_link.gd, link_beat.gd, pit_beat.gd, copy_art.gd):
  - **"Linking your agent..."** types itself as the guide HUD comes alive (the "your AI" badge, its signal bars, the panel) and lines of signal climb out of the pit.
  - **The call.** The player's real AI is asked once, through the session's guide link (5.4: the agent's own CLI with tools off, never omarchy-agent, only with the player's yes, the session's pace and cap). The call starts at 0:50, as the fall begins.
    - **What it is told, all of it:** the guide's fixed preamble, "Game stats: none", and SIGKILL's own text saying the game is starting and asking for one of five fixed lines. No opener data, no user or host name, no folder, no time, no stats.
    - **What is shown:** SIGKILL's copy of the line it picked, marked "live" (STORY.md's one voice), with the call's real latency on the badge. The AI's own words never reach the screen.
  - **The fallbacks.** AI off, no agent, the cap, an error, a local model not loaded, or no answer by 1:17: the scripted line instead, the badge saying why, any call still running stopped. Every beat comes at the same moment either way: the opener never waits. Demo data calls nothing (a canned answer).
  - **The model.** A local model server is never asked to load or change a model (no num_ctx). The opener loads nothing, so nothing is left to unload; the guide link still unloads anything the game loaded when the game exits.
  - **The guide's line:** "I've been stuck in here with them. They look like you." (the PRD's words).
  - **The copy** walks up out of the pit on a stair of red hexagons that light under its feet, forming as it crosses the rim, and stops 4.2 m in front of the player on a whole step, wearing the player's username.
    - **The username** is the one the opener already took, cleaned; the demo's "user" unless the C39 opt-in is on. It is never sent, saved or logged, and is dropped as the opener ends.
    - **The look:** A5's armour lit crimson in its seams, the player's teal on its rim. Its head is the nixfred hexagon with the prompt lit red and mirrored, `_<`, and the brand's ring of six bars behind it.
    - **It mirrors the player's look** once it stands. The story calls it `~` from mission 1 (STORY.md section 5); the opener never says who `~` is.
  - **Sounds**, all procedural: the carrier, the lock, the copy's rise and its steps.
  - **The hand-off to C42** is at 1:34.4, the copy standing.
  - **The test** is step 52 (tests/opener_link_test.gd), stubs only.
- **C42, 1:35 to 2:00, the skip logic and the first launch** (scripts/opener/forge_beat.gd, title_beat.gd, opener_score.gd, intro_menu.gd; scripts/settings/intro_state.gd; scripts/hud/first_launch_card.gd; scripts/daemons/daemon_voice.gd):
  - **The forge, on the score's grid.** At 1:34.4 the guide's panel shuts and `kill -9` types itself in the air between the player and the copy, a letter on each eighth note, in the player's teal, each letter a block of glowing cells. The letters charge and break into their cells, which stream on curves into the player's hands. There the SIGKILL rail rifle (the game's own model) prints itself from its back to its muzzle, a white-hot band of hex cells sweeping down the barrel. Its four coils light on the last four sixteenths, and on the drop (1:39.2) it is whole and kicks into the hands as the metal comes in.
  - **"you won't."** The copy squares up and stares; its line types itself in crimson in the air by its head, and its face's cursor races (STORY.md's words).
  - **The first kill.** From 1:44 the rifle is the player's: a reticle, and "[left mouse]  kill -9" (the fire key as bound). The player fires, and the shot lands on the next sixteenth of the press. If they do not, it fires itself at 1:47.2: the opener never waits. A beam of the rail's light hits the copy's heart; it flares and shudders, and on the beat it bursts, its own parts flung apart with a storm of crimson and teal voxels (the derezz).
  - **Then, on the beat:** the kill feed "SIGKILL sent by <user>" / "to <user>" (the feed's two lines; the user name only, never the host), the whisper "one of 6666" (spoken as breath, made in code, and shown), black and silence, and the title. The brand's own icon file, the hexagon with the white `>_` (never redrawn), slams in out of the dark on the score's downbeat 13 beats after the shot. "SIGKILL" is hammered in a letter a sixteenth, the title punching on every beat and tearing on the snare, over the machine's grid racing toward the player. It ends torn away by 2:00 (at the latest 1:58).
  - **The hand-off.** Played from the Esc menu, back to the menu as it was. The first launch's own goes straight into the arena.
  - **The music.** An original score made in code at run time (no sample, loop or recording of anyone's), on a worker thread as the opener starts, at 150 bpm in E minor. A dark synth bed with glitching arpeggios from 0:40 through the fall, the link and the copy. Heavy metal from the forge: down-tuned guitars chugging, double kick, the drop riff. A two-bar loop while the copy waits for the shot, and the stinger: the shot's crack, the derezz, the whisper, the slam's riff. It is on the Music bus (the Music and Master volumes), each part at its own loudness under full scale.
  - **Skipping, at any moment.** Esc pauses the intro in its own menu: Resume intro, Skip intro (focused, so Esc then Enter skips), and "Skip the intro next time". Holding Space for a second skips too (one key, no Ctrl or Alt); a key or a click shows how. The window's close is never touched.
  - **First launch.** The first time the arena loads, a card over the paused arena gives one line of content note and asks whether the intro may show the player's real user name and folder names (C39's opener data, which also covers the host name, uptime, theme colours and file times, said on the card). No is highlighted and focused: N, Enter or Esc answer no and leave opener data off; Y turns it on.
    - Then the opener plays itself, once. Watched to its end or skipped, it never auto-plays again; cut short (the window closed), it plays again at the next launch. "Skip the intro next time" stops that too, and sticks across restarts.
    - Kept in the settings file's own `[intro]` section, beside the privacy answers. The unlocks' save is untouched. Never in headless or script runs. "Play the opener" in the Esc menu always replays it.
  - **Replays keep the AI's calls** (5.4): a live answer is kept for the session.
  - **The daemons' and ICE's voices** (T1 found them near silent): each type's tell, strike, hit and death in its own voice, made in code, on the Effects bus. rogue.d chitters and slashes, the zombie groans and booms, the runaway's swarm buzzes and dives, ICE rings like glass and shatters.
  - **The test** is step 53 (tests/opener_end_test.gd), stubs only.

### 5.8 Community prompts and credits (DECIDED by Fred 2026-10-26)
SIGKILL is built in public; anyone can reply to Fred's X posts with a prompt. The producer filters every prompt through the section 6 safety rules before it becomes a chunk brief; raw public text never goes to Larry. If a prompt makes it in, its author is credited.
- CREDITS.md in the repo lists every contributor: name as they present it publicly, handle, the idea, and where it lives in the game.
- In-game credits: the end-credits roll is a live `top`-style process table on the Tron grid. Every contributor is a process: PID, USER (their handle), %CPU climbing as their row arrives, COMMAND (their idea). Rows type in with code-rain, the table scrolls, Fred is PID 1 (init). The final line is the player's own kill -9 on the credits process, which derezzes the whole table into voxels, then "SIGKILL" and the hexagon.
- Features born from a community prompt carry a small in-game tag, e.g. the Audit Trail visor HUD shows "visor design: @QuantaCortex".
- Credits never include anyone who didn't contribute publicly, and nobody's handle goes in without their own public reply.
- **Credited so far:**
  - Albert, @QuantaCortex: the Audit Trail visor, C43, the first.
  - Tim Provencio, @TimProvencio: ICE and ICEbreakers, built in I1 to I3, the second.
  - Carlos Granier, @cgranier, the third.
  - Jeremy, @ocdjeremy, the fourth.
  - MindGameLabs, @MindGamesLabs, the fifth.
  - The last three are post-1.0 ideas (5.10).
  - Built features carry their tag, such as "ICE design: @TimProvencio" on ICE's HUD (I1).
- **The C44 credits roll, planned:**
  - Contributors appear as processes: PID 1 @NixFred (init), Larry, the SIGKILL producer, then every community contributor, with their public handle as USER and their idea as COMMAND. That means @QuantaCortex, @TimProvencio, Carlos Granier @cgranier, Jeremy @ocdjeremy and MindGameLabs @MindGamesLabs, and everyone credited after them.
  - The last row stays `6666  ~  ...  thanks for running me` (STORY.md, pick 6). The final `kill -9` on the credits process takes it with the rest. Then come the derezz, "SIGKILL" and the hexagon.
  - Captures of the roll use demo data. CREDITS.md mirrors the roll.

### 5.9 ICE and ICEbreakers (DECIDED by Fred 2026-10-28 10:21 PM ET; built in I1 to I3)
A community prompt by Tim Provencio ([@TimProvencio](https://x.com/TimProvencio)), a public reply on X, credited as the second community feature after @QuantaCortex.
- ICE (William Gibson's intrusion countermeasure electronics) is a new enemy class, separate from the daemons: the system defending itself against the player as the intruder.
- **White ICE:** barriers that seal corridors, jam weapons and corrupt the HUD.
- **Hunter ICE:** it tracks the player and adapts by countering their most-used weapon.
- **Black ICE:** rare and frightening, and not just a bigger health bar. When it arrives the lights die, the music drops and the AI guide's link is cut, and normal weapons cannot kill it. Its touch flatlines you: out for the rest of the round in a match, the run over in solo.
- **ICEbreakers:** one-use programs carried beside the weapons, never in a weapon slot.
  - **brute** cracks ICE.
  - **exploit** hits weak seams (A5's weak points).
  - **cloak** hides you.
  - **decoy** is a sacrifice to get away.
  - The AI guide recommends which to load from the round's numbers only, with the scripted guide as the fallback.
- **As built:**
  - **I1, white ICE and hunter ICE:**
    - walls that seal a doorway and a corridor, a jam field, a HUD-corruption field, and the adaptive hunter
    - glacier `#18b2ff` and cobalt `#1e30ff` faceted glass
    - Settings, Gameplay, "ICE": on by default, off in practice, the host's setting in a match
    - the HUD tag "ICE design: @TimProvencio"
    - protocol 12
  - **I2, the four ICEbreakers:**
    - one of each kind at a round's start, at most two of a kind
    - U runs the loaded one and Y loads the next kind; both are rebindable
    - pickups, and your AI's pick
    - protocol 13
  - **I3, Black ICE:**
    - never in round 1; from round 2, a rolled chance of 20% rising to 40%, and at most one a round
    - exploit and brute are the only things that break it
    - protocol 14
- **Post-1.0** (1.x, with process enemies): ICE may take its look from the names of security software running on the host. Names only, read-only, and demo data for anything public.
- Everything is simulated; nothing real is touched.

### 5.10 Community ideas (post-1.0)
These came in as public replies on X after the 1.0 lock (2026-10-29), so each is post-1.0 unless Fred pulls it in. Each is fully simulated, read-only and never touches the real system: nothing here reads, changes, signals or runs anything on the player's machine (section 6), and every number they use is the game's own.

**Carlos Granier ([@cgranier](https://x.com/cgranier)), the third community contributor** (Fred, 2026-10-30 11:27 PM ET):
- **man sigkill:** a training level where each weapon unlocks after you read its man page in the game's world. The EXAMPLES section is a 20-second drill against a dummy, and `--help` on any weapon replays its drill. The man pages are the game's own text.
- **The OOM killer:** a boss that wakes under high in-game memory pressure and hunts whatever uses the most in-game memory. That is often you, if you keep a big weapon out or hoard ammo. Switching to light weapons shrinks you and drops its aggro, which pushes you to use all 13 weapons. The memory is a game number, never the machine's.
- **The /tmp and /proc arenas:** invented in-game spaces, not real directories.
  - /tmp wipes itself every round: cover, ICE walls and cron mines reset.
  - /proc has walls that are live in-game counters you can shoot to change the arena, such as freezing a gravity value.
  - Game state only, never the real /tmp or /proc.
- **Uptime as the solo score:**
  - Each round survived adds uptime, and the daemons scale with the in-game load average.
  - A kernel panic ends the run, with a panic screen showing your stats as a stack trace.
  - A leaderboard by uptime, local first. Any online board would be public, and waits on Fred.
- **Music from the load average:** the tempo follows how many daemons are alive, and the bass drops when Black ICE arrives. It is driven by the in-game load only, never the machine's, and is original procedural audio with nothing ripped.
- Credit: "Carlos Granier (@cgranier)" in CREDITS.md, the README's community section and the C44 credits roll.

**Jeremy ([@ocdjeremy](https://x.com/ocdjeremy)), the fourth community contributor** (Fred, 2026-10-30 11:31 PM ET):
- **An htop-style AR overlay** in the visor, which you can toggle: a live htop pane of the game's own daemons, ICE and players only, never real processes. The real-data Audit Trail visor stays C43, @QuantaCortex's.
- **Stepped zoom on scoped weapons** (the grep seeker, the kill -9 rail) instead of aim-down-sights on or off, with hold or toggle as a setting (the existing aim hold/toggle setting extends to it).
- **Real hitboxes:** headshots and centre mass hit hardest and limbs least, so nobody gets one-shot in the toe.
- **Balance each weapon on its own strengths**, instead of automatically nerfing anything that fires fast.
- **Stretch:** VR support (post-1.0, likely 2.x; OpenXR in Godot).
- Credit: "Jeremy (@ocdjeremy)" in CREDITS.md, the README's community section and the C44 credits roll.

**MindGameLabs ([@MindGamesLabs](https://x.com/MindGamesLabs)), the fifth community contributor** (Fred, 2026-10-30 11:31 PM ET):
- **A sudo grenade:** a new throwable, separate from the existing Z sudo overcharge. It will not throw until you type a password, and three wrong tries make it go off in your hand.
- **The password is an in-game one, shown on screen as a typing challenge.** The game never asks for, reads or stores the player's real password. Nothing typed is stored, logged, sent or checked against the system, and no Ctrl+Alt keys are used.
- Credit: "MindGameLabs (@MindGamesLabs)" in CREDITS.md, the README's community section and the C44 credits roll.

## 6. Hard safety rules (every chunk)
- Never modify, delete, execute, signal or kill anything on the player's system. System features are read-only: names, sizes, counts, model names. Never file contents. Named exception (producer, 2026-10-26): the game may read the single-line Omarchy default-agent setting to learn which agent to use, and nothing else from that file.
- The ONE exception to "never execute" (Fred, 2026-10-25): the game may launch the player's own Omarchy default agent CLI in its non-interactive mode, with tools, file edits and shell disabled, no auto-approve flags, never via omarchy-agent, and with only game stats and the player's typed text in the prompt. The SECOND and last exception (producer, 2026-10-26): an optional query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader` for HUD GPU stats, never with control flags; prefer /sys reads, and hide GPU stats if neither works. Nothing else is ever executed.
- Nothing private (real paths, hostnames, process lists, model lists) in the repo, screenshots or trailers. Demo-data mode for anything public.
- No Ctrl+Alt hotkeys. Mouse captured only while focused, released on Esc/focus loss. No focus stealing. No GPU use when not running.
- Commits and pushes go to the public repository (MIT, since 2026-10-28). Nothing else public (releases, packages, store pages, the relay) without Fred's yes. (The v0.33.0-prealpha pre-release went out with his yes, 2026-10-30.)
- Never invent results: every chunk reports real command output.

## 7. How Larry builds it
One small chunk at a time, from a producer brief: exact goal, files to touch, acceptance checks with real output, then stop and report. No chunk starts until the previous one is verified by the producer. No open-ended tasks.
- **Commit and push to origin main often,** at every working checkpoint, not in one commit at the end.
  - Never force push, and never rewrite history.
  - Commits carry no Co-Authored-By trailer and no session link.
  - `git remote -v` before every commit. Before every push, a privacy grep of the diff and a secret scan (the repository is public).
- **The gate is `scripts/check.sh`:** gdparse, a headless import, a headless 300-frame run and the headless tests, 55 steps as of C36.
  - It runs in the foreground, and it is green before any report.
  - A known flake may be rerun once, and the report says so.
- **Self-review, the current rule:** Codex bug runs are paused (Fred, 2026-10-28 8:04 PM ET), so Larry reviews each chunk's full diff himself before the report. He looks for bugs, Godot API misuse, frame-rate dependence, edge cases, safety-rule violations and anything private.
- **When Fred turns Codex back on,** it runs read-only on the chunk's diff (`codex exec` in a read-only sandbox, or `codex review`), hunting bugs, Godot API misuse, safety-rule violations and edge cases.
  - Larry summarizes its findings in the report, fixes the real ones, re-runs the gate, and notes each rejected finding with the reason.
  - Codex never gets write access and never pushes.
  - (Every chunk ended with a Codex run from 2026-10-25, Fred's rule. It has been off and on since, and off since 2026-10-28 8:04 PM ET.)
- **Docs and website current** (Fred, 2026-10-30 8:37 PM ET): README.md always has a current "Where we are" section, this PRD is the entire current PRD and is updated whenever decisions or the chunk plan change, and playsigkill.com is kept up to date after every verified chunk. Every chunk keeps README "Where we are" and this PRD current, and bumps the PRD's version and date line when decisions or the chunk plan change.
- **Choices a brief does not cover:** Larry picks what is closest to the brief's intent, records it in docs/DESIGN.md and lists it in the report.
- **Working rules:**
  - No installs, releases, packages or publishing.
  - No real AI calls in tests or captures.
  - No windows on Fred's desktop: headless, or a private virtual display only.
  - Scratch lives outside the repository.

## 8. Milestones and chunk plan

### 8.1 Build order: player-facing first
Fred, 2026-10-30 6:17 PM ET: "Work on the pieces that the user sees first." What is left goes in the order a new player sees it:
1. The opener: done (C38 to C42, with D1).
2. The missions: C35 (done: the framework, mission 1 a first cut), C36 (done: the ruins art kit, mission 1 standing in its ruins), C37 (next: mission 1), then missions 2 to 7.
3. M5's world features. The producer numbers them when they come up, and live process enemies come before C43, which needs them.
4. C43, the Audit Trail visor, then C44, the credits.
5. 1.0.

### 8.2 Every chunk and its status
Statuses are taken from `git log` (2026-10-31, after C36): **done**, **in progress**, **next** or **planned**. The hashes are the commits that finished each chunk. Before M0 came the scaffold (`d086489`), and the decision that the player's AI is the Omarchy default agent landed as its own docs commit (`43b1f74`).

**M0 Foundations**

| Chunk | What | Status | Commits |
|---|---|---|---|
| C1 | Install Godot 4.7.2 (pacman, approved). Headless import of the project with zero errors. Fix only what breaks import. | done | `823de8b` |
| C2 | Add scripts/check.sh (gdparse + headless import + headless 300-frame run, nonzero on any error), first Codex bug run over everything so far, sync PRD and DESIGN.md. | done | `c26061f` |
| C3 | GitHub repo nixfred/sigkill, push main. (Private at first; public under the MIT license since 2026-10-28.) | done | `e57697a` |

**M1 Look and feel** (the "Rockstar" pass on the greybox)

| Chunk | What | Status | Commits |
|---|---|---|---|
| C4 | Tron environment: black void, glowing floor grid shader, neon edge shader on blocks, WorldEnvironment glow + fog. | done | `de7c203` |
| C4b | README graphics pass: banner, badges, concept art. | done | `52383f3` |
| C5 | Movement feel: accel/decel curves, air control, slide, head bob, FOV kick, all tunables in one resource. | done | `c223950` |
| C6 | Terminal cannon feel: muzzle flash, recoil, hit marker, impact sparks, placeholder SFX. | done | `6403dbd` |
| C6b | The deep README rewrite. | done | `70c951d` to `de05ce1` |
| C6c | PRD and DESIGN sync, CREDITS.md and the credits roll mockup. | done | `d3223b1` to `3c178a4` |
| C7 | Derezz death effect on dummies (voxel shatter). | done | `238d3ac` |
| C8 | Matrix code-rain wall shader, intensity driven by nearby enemies. | done | `3ee66b1` |

**M2 Your AI**

| Chunk | What | Status | Commits |
|---|---|---|---|
| C9 | AI source detector (no UI): read the Omarchy default-agent file (handle unset/unknown), detect local fallback servers on localhost, read GPU stats read-only. Tests use a fake agent file, a stub agent CLI and a fake local server; no real agent calls in tests. | done | `1bd17b2` |
| C9b | Agent adapters: a common interface plus Claude Code and Codex adapters calling each CLI's non-interactive mode with tools disabled, plus the local OpenAI-compatible adapter. Tested against stub binaries; one optional manual smoke test only with Fred's yes. | done | `f9cf9b4` |
| C10 | Boot sequence screen: names the player's Omarchy default agent (or fallback), live GPU readout, "Linking..." handshake (demo-data mode for screenshots). | done | `3184454` |
| C11 | In-game guide HUD: "your AI" badge, live GPU stats, latency (tok/s on local fallback), thinking state, ask-anything key, rate limits. | done | `be2f220` |
| C11b | Local model-load consent: the game loads a local model only with the player's yes. | done | `1fc87b7` |
| C12 | Round-stat coaching and opt-in roast announcer. | done | `e72c644` |

**M3 Multiplayer**

| Chunk | What | Status | Commits |
|---|---|---|---|
| C13 | LAN/tailnet: host + join by IP, two players see each other move. | done | `6a83ae0` |
| C14 | Synced shooting, damage, respawn, kill feed. | done | `19a4781` |
| C15 | Room codes + invite links (design + cost note for the relay, Fred decides before deploy). | done: the client side and the relay design | `5c1a8d3` |
| C16c | The relay itself, local only (UDP); every room-code match goes through it (docs/RELAY.md). | done, hosted nowhere | `b5a2f42` |
| C16d | WebSocket relay mode for proxy-only hosts, tested on 127.0.0.1. | done, hosted nowhere | `3c78dc3` |
| Relay hosting | Where the relay runs and its budget. | waits on Fred (section 9, question 1) | |

**M4 Arsenal and modes**

| Chunk | What | Status | Commits |
|---|---|---|---|
| C16 | Weapon framework (data-driven weapon resource, swap wheel, ammo, mods/skins slots) + SIGTERM. | done | `619a109` |
| C16b | Full settings screen in the Esc menu: controls, video, audio, HUD and accessibility, privacy and AI, multiplayer. | done | `76afcbc` |
| C17 | SIGKILL rail rifle. | done | `e10a006` |
| C18 | SIGSTOP bullet time. | done | `7927cb2` |
| C19 | Fork bomb. | done | `372d91a` |
| C20 | Light-trail mode. | done | `4d5e92e` |
| C21 | Code-rain vision. | done | `d6d4576` |
| C22 | Root vs user + `sudo` overcharge. | done | `658a09f` |
| C23 | Spectate as top. | done | `cf991a5` |
| C24 | `fork()` shotgun. | done | `88aeb92` |
| C25 | `grep` seeker. | done | `23dd69b` |
| C26 | `rm -rf` cannon. | done | `7a7c042` |
| C27 | `cron` mines. | done | `eac8a86` |
| C27b | Daemons fight back: AI with readable tells, solo health, difficulty and practice, the host's daemons in a match. | done | `3ae7dbe`, `7cbd5b2`, `0e6181c`, `a311cd6`, `51e1376` |
| C28 | `ping` sonar. | done | `f7f13ed`, `f05eeb8` |
| C29 | `chmod 000` freeze ray, and the weapon strip's second bank. | done | `2ae2c88`, `1c0f53d`, `0728187` |
| C30 | `pipe \|` chain beam. | done | `022762f`, `1fb849e`, `a10b20e` |
| C31 | `/dev/null` black hole. | done | `6fb9f28`, `c96e2c8`, `1062d95` |
| C32 | SIGHUP confusion grenade. | done | `517ddd6`, `9b8b766` |
| C33 | Unlocks, mods and light skins (5.2.1). | done | `4af5320`, `77293ba` |

**Art pass** (3.1)

| Chunk | What | Status | Commits |
|---|---|---|---|
| A1 | Weapon viewmodels. | done | `aa3ca98` |
| A2 | Enemy art: daemons, a drone swarm, the derezz. | done | `0d7cbdb` |
| A2b | Enemy redo: articulated creatures, hit reactions, shard deaths. | done | `766cec6` |
| A3 | Arena: depth, props, signs, skyline, sky and fog. | done | `1590eb0` |
| A4 | Lighting, post and particles, graphics presets. | done | `c72cc0c`, `ab05c07` |
| A5 | Monster redo: solid armoured daemons, one colour a type, no two alike, rare elites. | done | `8c0511f`, `db57bc3` |

**ICE and ICEbreakers** (5.9)

| Chunk | What | Status | Commits |
|---|---|---|---|
| I1 | White ICE and hunter ICE. | done | `1b8fdec` |
| I2 | ICEbreakers: brute, exploit, cloak, decoy, pickups, your AI's pick. | done | `d87527a` |
| I3 | Black ICE. | done | `bf42ef9` |

**Release:** the 0.33.0-prealpha drop (build 33, after C33) is done. It went out 2026-10-30 as a GitHub pre-release, [v0.33.0-prealpha](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha): the tag is on `655ff4b` and the assets were built from `341c182` (docs/RELEASE_CHECKLIST.md, docs/RELEASE_NOTES-0.33.0-prealpha.md). It came before the opener, so the opener is on `main` only for now.

**M5 Your machine is the world** (5.5)

| Chunk | What | Status | Commits |
|---|---|---|---|
| M5 world features | Filesystem maps, live process enemies, theme-shift levels, keybind gunplay, Ramblr voice commands, packet tracer arena, Hyprland split-screen co-op. | planned; not yet numbered | |
| C43 | Audit Trail visor (after process enemies exist): lineage lines, read-only PID/PPID/name/CPU/mem only, chain-sever arena reaction, credit tag. | planned | |
| C44 | CREDITS.md + in-game top-style credits roll (demo data for captures). CREDITS.md itself is in the repo since C6c; the roll is C44's. | planned | |

**M6 Story campaign** (5.6, 5.7). The opener chunks are built after C10 boot and C7 derezz exist.

| Chunk | What | Status | Commits |
|---|---|---|---|
| C34 | Story bible in docs/STORY.md (premise, characters, AI's voice, mission list) for Fred's review before any mission is built. | done; locked by Fred 2026-10-30 | `a80a229`, `431e41a` |
| C38 | Opener: fake terminal + typed lines (demo data first). | done | `bda0ecc`, `ee41bbd`, `0f94ca7` |
| C39 | Opener: real-data reader (read-only names/sizes/counts/mtimes/theme, opt-in, fake-data fallback). | done | `8c74319`, `a349d1a` |
| C40 | Opener: shrink-away reveal + directory-tree fall. | done | `e6d0b73`, `2d4466e` |
| C41 | Opener: AI link beat + the copy of you. | done | `7106cec`, `14c7c2b`, `59095b3` |
| C42 | Opener: kill -9 forge, first kill, title slam, music, skip logic; the first-launch content note and opt-in question; the daemons' voices. | done | `77254c0`, `e04dffe`, `e31bd68`, `ffa5eaa` |
| C35 | Mission framework (objectives, terminal-log pickups, AI dialogue triggers). | done | `a724aae`, `aee2e1c` |
| C36 | Cyberpunk ruins district art kit. | done | `31ef6f0`, `0650508`, `63b99bc` |
| C37 | First mission end to end: mission 1, `login`. | **next** | |
| Missions 2 to 7 | Further missions one chunk each. | planned | |

**Website, teaser and docs**

| Chunk | What | Status | Commits |
|---|---|---|---|
| T1 | Teaser footage (Fred, 2026-10-30 8:53 PM ET: a 70 second teaser of real in-game footage, demo data, for the top of playsigkill.com): tools/trailer_capture.sh renders the clips (docs/TRAILER.md); the edit and the original soundtrack are the producer's. | done | `b2392e8`, `f17ae86`, `bb82508`, `1087887`, `67e8e8c` |
| D1 | Full PRD rewrite (this file, v0.3), README "Where we are", three community credits. | done | `e1e658d`, `e79b9e5` |

T1 keeps 5.7's rule that trailers never show real machine data. The tool refuses to run without `--demo`, with the opener's real data on, or headless. It renders a `git archive` copy on a private virtual display, with fresh, empty user data for every take.

The site is [playsigkill.com](https://playsigkill.com) (Fred, 2026-10-28 8:45 AM ET). It is built by the Website Builder Bot and kept current after every verified chunk. The teaser's edit and soundtrack are the producer's, outside this repository.

**Post-1.0 and 2.0** (Scope, 5.9, 5.10). If Fred pulls one in, the producer numbers it into a chunk.

| Idea | From | Status |
|---|---|---|
| man sigkill training level | Carlos Granier, @cgranier | planned, post-1.0 |
| The OOM killer boss | Carlos Granier, @cgranier | planned, post-1.0 |
| The /tmp and /proc arenas | Carlos Granier, @cgranier | planned, post-1.0 |
| Uptime as the solo score, kernel panic, local leaderboard | Carlos Granier, @cgranier | planned, post-1.0 |
| Music from the in-game load average | Carlos Granier, @cgranier | planned, post-1.0 |
| htop-style AR overlay (in-game entities only) | Jeremy, @ocdjeremy | planned, post-1.0 |
| Stepped zoom on scoped weapons, hold or toggle | Jeremy, @ocdjeremy | planned, post-1.0 |
| Real hitboxes (head and centre mass hardest, limbs least) | Jeremy, @ocdjeremy | planned, post-1.0 |
| Each weapon balanced on its own strengths | Jeremy, @ocdjeremy | planned, post-1.0 |
| VR support (OpenXR) | Jeremy, @ocdjeremy | planned, post-1.0 stretch (likely 2.x) |
| sudo grenade (an in-game password only) | MindGameLabs, @MindGamesLabs | planned, post-1.0 |
| ICE looks from security software names | Tim Provencio, @TimProvencio (5.9) | planned, post-1.0 (1.x) |
| Browser version | Fred | planned, 2.0 |

## 9. Open questions for Fred
1. Matchmaking/relay hosting: where and what budget? (Needed before C15 deploys.) Still open: the relay is built (C16c, C16d) and hosted nowhere.
2. ~~AI guide source~~ DECIDED: Omarchy default agent first, local model fallback, scripted last.
3. Windowed playtests on the dev machine: OK to pop a game window on your desk when I ask, or keep it to headless + clips?
4. First playable target: M1 + M2 (solo, looks great, your AI talks) before multiplayer? (Producer's pick: yes.) Overtaken: M1 to M4 are built.
