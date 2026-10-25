# SIGKILL PRD (v0.1, 2026-10-25)

Owner: Fred Nix. Producer: SIGKILL bot. All code: Larry (Claude Code, gus, ~/Projects/sigkill).
Engine: Godot 4 (pick documented in docs/ENGINE.md; Fred approved Godot 4.7.2 from pacman).

## 1. Pitch
A native linux FPS for Omarchy. You are the nixfred >_ hexagon, deep inside your own machine, hunting rogue daemons, zombie processes and runaway apps. Tron light-grid arenas, Matrix code rain, fast arena gunplay, and your OWN local AI riding along as your guide. Play solo against daemons or jump into a match with a friend across the internet in seconds.

## 2. Quality bar
"Rockstar quality" means: nothing ships that feels placeholder. Every chunk is judged on game feel (movement, recoil, hit feedback, audio), visual polish (lighting, glow, VFX), stability (no errors in the log, steady frame time) and clarity (the player always knows what happened and why). We get there by small chunks that are each finished properly, not by big drops.

## 3. Visual direction
- Tron: pure black void, neon light-edges on every surface, glowing floor grid, teal/mint on black for the player, red/amber for hostiles. Bloom and glow, light fog.
- Matrix: green glyph code rain that bleeds through walls when daemons are near; code-rain vision mode; slow-mo with motion trails.
- Brand: locked nixfred hexagon (icon-only, white >_) as game icon, splash, README. Never redesigned.
- All art and audio original or properly licensed.

## 4. Core loop (v1)
Fast arena deathmatch (PvP) plus a solo/co-op daemon hunt (PvE), same arenas, same weapons.

## 5. Features
### 5.1 Multiplayer that just works
- Join by 6-character room code or a `sigkill://` invite link. No port forwarding.
- Peer-to-peer with NAT punch-through; a tiny matchmaking/relay service for "find me an opponent" and fallback relay. (Hosting cost: Fred decides before anything is deployed.)
- Tailnet/LAN mode: instant play between machines on the same network.
- Built on Godot high-level multiplayer (ENet / WebRTC data channels for punch-through).

### 5.2 Weapons (signals)
- SIGTERM: polite shotgun.
- SIGHUP: confusion grenade, enemies "reload" and wander.
- SIGKILL: uncatchable railgun, the ult. "kill -9" headshot callout.
- Fork bomb: grenade that splits 1, 2, 4, 8.
- Terminal cannon: default hitscan rifle.

### 5.3 Abilities and modes
- SIGSTOP bullet time: short meter, Matrix slow-mo; SIGCONT resumes.
- Code-rain vision: see enemies through walls as glyphs, drains fast.
- Light-trail mode: your path leaves a solid neon wall (Tron deathmatch).
- Root vs user: spawn as user, earn sudo for a power spike.
- Derezz deaths: players and daemons shatter into glowing voxels. Kill feed: "SIGKILL <pid> sent by <player>".
- Spectate as top: dead players watch a live process-table style HUD of the match.

### 5.4 YOUR real AI as the guide (signature feature)
The game finds the AI already running on the player's own machine and makes it their in-game guide, and proves it's real:
- Detects local model servers read-only (Ollama at localhost:11434 /api/tags and /api/ps, LM Studio at localhost:1234 /v1/models, more later). Lists the real model names it finds.
- Boot sequence shows it live: "Found ollama: gemma3 loaded, 9.3 GB VRAM on your RTX 5070. Linking..." using the real model name and real GPU readout (nvidia-smi or equivalent, read-only).
- The guide talks in-game with tokens streaming visibly, a live tokens/sec and latency readout, and a "this is running on YOUR machine" badge. Player can ask it anything mid-match from a chat key and it answers with their own model.
- It coaches from real round stats: accuracy, deaths, where you got caught. Doubles as the Larry-style roast announcer (opt-in).
- Privacy: everything stays on the machine. Nothing is sent off-box. Opt-in on first launch, with a clear "AI off" mode that falls back to a scripted guide.
- Model hygiene: check what's loaded before using it, never change shared model settings (e.g. num_ctx), never load a huge model without asking, unload anything the game loaded when it exits.

### 5.5 Your machine is the world (later milestone)
- Filesystem maps: rooms from the player's real folder tree (names and sizes only), node_modules is the endless maze.
- Live process enemies: real running processes become enemies (browser tabs swarm, pegged CPU core is a boss). Cosmetic only.
- Theme-shift levels using Omarchy themes; palette-only enemies.
- Keybind gunplay mapped to real Omarchy shortcuts (opt-in, no conflicts).
- Ramblr voice commands (read Ramblr's existing output, never open the mic).
- Packet tracer arena: tailnet machines as islands.
- Hyprland split-screen co-op.

## 6. Hard safety rules (every chunk)
- Never modify, delete, execute, signal or kill anything on the player's system. System features are read-only: names, sizes, counts, model names. Never file contents.
- Nothing private (real paths, hostnames, process lists, model lists) in the repo, screenshots or trailers. Demo-data mode for anything public.
- No Ctrl+Alt hotkeys. Mouse captured only while focused, released on Esc/focus loss. No focus stealing. No GPU use when not running.
- Local commits and private pushes only. Nothing public without Fred's yes.
- Never invent results: every chunk reports real command output.

## 7. How Larry builds it
One small chunk at a time. Each chunk: exact goal, files to touch, acceptance checks with real output, local commit, then stop and report. No chunk starts until the previous one is verified by the producer. No open-ended tasks.

## 8. Milestones and chunk plan
M0 Foundations
- C1 Install Godot 4.7.2 (pacman, approved). Headless import of the project with zero errors. Fix only what breaks import.
- C2 Add scripts/check.sh: gdparse all scripts + headless import + headless 300-frame run, exits nonzero on any error. Commit PRD.md and sync DESIGN.md.
- C3 Private GitHub repo nixfred/sigkill, push main. (Private only.)
M1 Look and feel (the "Rockstar" pass on the greybox)
- C4 Tron environment: black void, glowing floor grid shader, neon edge shader on blocks, WorldEnvironment glow + fog.
- C5 Movement feel: accel/decel curves, air control, slide, head bob, FOV kick, all tunables in one resource.
- C6 Terminal cannon feel: muzzle flash, recoil, hit marker, impact sparks, placeholder SFX.
- C7 Derezz death effect on dummies (voxel shatter).
- C8 Matrix code-rain wall shader, intensity driven by nearby enemies.
M2 Your AI
- C9 AI detector module (read-only, localhost only), with tests against a fake server. No UI yet.
- C10 Boot sequence screen showing real detected model + GPU readout (demo-data mode for screenshots).
- C11 In-game guide HUD: streamed tokens, tok/s, "running on YOUR machine" badge, ask-anything key.
- C12 Round-stat coaching and opt-in roast announcer.
M3 Multiplayer
- C13 LAN/tailnet: host + join by IP, two players see each other move.
- C14 Synced shooting, damage, respawn, kill feed.
- C15 Room codes + invite links (design + cost note for the relay, Fred decides before deploy).
M4 Arsenal and modes
- C16 Weapon framework + SIGTERM. C17 SIGKILL railgun. C18 SIGSTOP bullet time. C19 Fork bomb. C20 Light-trail mode. C21 Code-rain vision. C22 Root vs user. C23 Spectate as top.
M5 Your machine is the world (filesystem maps, process enemies, themes, etc.)

## 9. Open questions for Fred
1. Matchmaking/relay hosting: where and what budget? (Needed before C15 deploys.)
2. AI guide: local models only, or also let players plug in a cloud key later?
3. Windowed playtests on gus: OK to pop a game window on your desk when I ask, or keep it to headless + clips?
4. First playable target: M1 + M2 (solo, looks great, your AI talks) before multiplayer? (Producer's pick: yes.)
