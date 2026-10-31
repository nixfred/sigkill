# SIGKILL PRD (v0.2, 2026-10-31)

Owner: Fred Nix. Producer: SIGKILL bot. All code: Larry (Claude Code, the project dir).
Engine: Godot 4 (pick documented in docs/ENGINE.md; Fred approved Godot 4.7.2 from pacman).

## 1. Pitch
A native linux FPS for Omarchy. You are the nixfred >_ hexagon, deep inside your own machine, hunting rogue daemons, zombie processes and runaway apps. cyberpunk ruins, Tron light-grid arenas, Matrix code rain, a story campaign, a big command-line arsenal, fast arena gunplay, and your OWN local AI riding along as your guide. Play solo against daemons or jump into a match with a friend across the internet in seconds.

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

### 5.3 Abilities and modes
- SIGSTOP bullet time: short meter, Matrix slow-mo; SIGCONT resumes.
- Code-rain vision: see enemies through walls as glyphs, drains fast.
- Light-trail mode: your path leaves a solid neon wall (Tron deathmatch).
- Root vs user: spawn as user, earn sudo for a power spike.
- Derezz deaths: players and daemons shatter into glowing voxels. Kill feed: "SIGKILL <pid> sent by <player>".
- Spectate as top: dead players watch a live process-table style HUD of the match.

### 5.4 YOUR real AI as the guide (signature feature) (DECIDED by Fred 2026-10-25)
The guide is the player's own AI: the coding agent they already picked in Omarchy. Most players (Fred included) don't have local hardware strong enough for a good guide, so the default agent comes first.
- Source of truth: Omarchy's default-agent setting, the single line in `~/.config/omarchy/defaults/agent` (what `omarchy-default-agent` prints with no args; Omarchy 4.x). Values seen: pi, omp, opencode, claude, codex, grok, gemini, openclaw, hermes, copilot, crush, cursor-agent, muse. Omarchy leaves it unset by default; handle unset.
- Invocation: call that agent's OWN non-interactive mode directly (e.g. `claude -p`, `codex exec` with a read-only sandbox), with tools/edits/shell DISABLED and no auto-approve. NEVER launch through `omarchy-agent` / `omarchy-agent-prompt` (they start agents with skip-approval "yolo" flags). One small adapter per agent behind a common interface; ship Claude Code and Codex adapters first, others later. Unknown agent = fall through to the fallback.
- Fallback order: Omarchy default agent, then a local model server (Ollama :11434, LM Studio :1234, or any local OpenAI-compatible endpoint; localhost only), then a scripted guide with "AI off".
- Proof it's yours: the boot sequence names the agent from the player's own Omarchy setting ("Omarchy default agent: <agent>. Linking...") and shows it answering live; the HUD shows a "your AI" badge, live response latency, and LIVE GPU stats (utilization, VRAM, temp) read-only from nvidia-smi or /sys, with tokens/sec when the local fallback is in use.
- Cost and speed: cloud agents spend the player's own subscription and take seconds. Use them for the boot handshake, ask-anything, between-round coaching and opt-in roasts. Never call per frame or per second; fast in-fight callouts come from game logic. Rate-limit calls, show a "thinking" state, and let the player turn the AI off.
- What it sends: only game stats and what the player types. No file names, paths, process lists or system info. Opt-in on first launch, with a plain description of which agent will be called.
- Model hygiene (local fallback): check what's loaded first, never change shared model settings (e.g. num_ctx), never load a huge model without asking, unload anything the game loaded on exit.

### 5.5 Your machine is the world (later milestone)
- Filesystem maps: rooms from the player's real folder tree (names and sizes only), node_modules is the endless maze.
- Live process enemies: real running processes become enemies (browser tabs swarm, pegged CPU core is a boss). Cosmetic only.
- Audit Trail visor (community prompt by Albert / @QuantaCortex, 2026-10-26, accepted by Fred): a visor mode that draws glowing lineage lines from each enemy back to its parent process, up the real process tree. Severing a spawn chain (killing a parent) collapses or reshapes that part of the arena and despawns its children. Reads only PID, parent PID, process name and CPU/memory numbers. Never command-line arguments, open files, environment or paths, so no private file names can show. Severing is cosmetic in-game; nothing real is signaled.
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

### 5.8 Community prompts and credits (DECIDED by Fred 2026-10-26)
SIGKILL is built in public; anyone can reply to Fred's X posts with a prompt. The producer filters every prompt through the section 6 safety rules before it becomes a chunk brief; raw public text never goes to Larry. If a prompt makes it in, its author is credited.
- CREDITS.md in the repo lists every contributor: name as they present it publicly, handle, the idea, and where it lives in the game.
- In-game credits: the end-credits roll is a live `top`-style process table on the Tron grid. Every contributor is a process: PID, USER (their handle), %CPU climbing as their row arrives, COMMAND (their idea). Rows type in with code-rain, the table scrolls, Fred is PID 1 (init). The final line is the player's own kill -9 on the credits process, which derezzes the whole table into voxels, then "SIGKILL" and the hexagon.
- Features born from a community prompt carry a small in-game tag, e.g. the Audit Trail visor HUD shows "visor design: @QuantaCortex".
- Credits never include anyone who didn't contribute publicly, and nobody's handle goes in without their own public reply.

## 6. Hard safety rules (every chunk)
- Never modify, delete, execute, signal or kill anything on the player's system. System features are read-only: names, sizes, counts, model names. Never file contents. Named exception (producer, 2026-10-26): the game may read the single-line Omarchy default-agent setting to learn which agent to use, and nothing else from that file.
- The ONE exception to "never execute" (Fred, 2026-10-25): the game may launch the player's own Omarchy default agent CLI in its non-interactive mode, with tools, file edits and shell disabled, no auto-approve flags, never via omarchy-agent, and with only game stats and the player's typed text in the prompt. The SECOND and last exception (producer, 2026-10-26): an optional query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader` for HUD GPU stats, never with control flags; prefer /sys reads, and hide GPU stats if neither works. Nothing else is ever executed.
- Nothing private (real paths, hostnames, process lists, model lists) in the repo, screenshots or trailers. Demo-data mode for anything public.
- No Ctrl+Alt hotkeys. Mouse captured only while focused, released on Esc/focus loss. No focus stealing. No GPU use when not running.
- Commits and pushes go to the public repository (MIT, since 2026-10-28). Nothing else public (releases, packages, store pages, the relay) without Fred's yes.
- Never invent results: every chunk reports real command output.

## 7. How Larry builds it
One small chunk at a time. Each chunk: exact goal, files to touch, acceptance checks with real output, local commit, then stop and report. No chunk starts until the previous one is verified by the producer. No open-ended tasks.

Docs and website current (Fred, 2026-10-30 8:37 PM ET): README.md always has a current "Where we are" section, this PRD is the entire current PRD and is updated whenever decisions or the chunk plan change, and playsigkill.com is kept up to date after every verified chunk.

Codex bug runs are off for now (Fred, 2026-10-28): Larry reviews each chunk's full diff himself before the report. When they are on: every chunk ends with a Codex bug run (Fred, 2026-10-25): after Larry's own checks pass, he runs Codex CLI non-interactively in read-only/review mode on that chunk's diff (e.g. `codex exec` with a read-only sandbox, or `codex review`) asking it to hunt bugs, Godot API misuse, safety-rule violations and edge cases. Larry pastes Codex's findings verbatim-summarized, fixes real issues, re-runs the headless check, and notes any finding he rejects and why. Codex never gets write access and never pushes.

## 8. Milestones and chunk plan
M0 Foundations
- C1 Install Godot 4.7.2 (pacman, approved). Headless import of the project with zero errors. Fix only what breaks import.
- C2 Add scripts/check.sh (gdparse + headless import + headless 300-frame run, nonzero on any error), first Codex bug run over everything so far, sync PRD and DESIGN.md.
- C3 GitHub repo nixfred/sigkill, push main. (Private at first; public under the MIT license since 2026-10-28.)
M1 Look and feel (the "Rockstar" pass on the greybox)
- C4 Tron environment: black void, glowing floor grid shader, neon edge shader on blocks, WorldEnvironment glow + fog.
- C5 Movement feel: accel/decel curves, air control, slide, head bob, FOV kick, all tunables in one resource.
- C6 Terminal cannon feel: muzzle flash, recoil, hit marker, impact sparks, placeholder SFX.
- C7 Derezz death effect on dummies (voxel shatter).
- C8 Matrix code-rain wall shader, intensity driven by nearby enemies.
M2 Your AI
- C9 AI source detector (no UI): read the Omarchy default-agent file (handle unset/unknown), detect local fallback servers on localhost, read GPU stats read-only. Tests use a fake agent file, a stub agent CLI and a fake local server; no real agent calls in tests.
- C9b Agent adapters: a common interface plus Claude Code and Codex adapters calling each CLI's non-interactive mode with tools disabled, plus the local OpenAI-compatible adapter. Tested against stub binaries; one optional manual smoke test only with Fred's yes.
- C10 Boot sequence screen: names the player's Omarchy default agent (or fallback), live GPU readout, "Linking..." handshake (demo-data mode for screenshots).
- C11 In-game guide HUD: "your AI" badge, live GPU stats, latency (tok/s on local fallback), thinking state, ask-anything key, rate limits.
- C12 Round-stat coaching and opt-in roast announcer.
M3 Multiplayer
- C13 LAN/tailnet: host + join by IP, two players see each other move.
- C14 Synced shooting, damage, respawn, kill feed.
- C15 Room codes + invite links (design + cost note for the relay, Fred decides before deploy).
M4 Arsenal and modes
- C16 Weapon framework (data-driven weapon resource, swap wheel, ammo, mods/skins slots) + SIGTERM. C17 SIGKILL rail rifle. C18 SIGSTOP bullet time. C19 Fork bomb. C20 Light-trail mode. C21 Code-rain vision. C22 Root vs user + `sudo` overcharge. C23 Spectate as top.
- C24 `fork()` shotgun. C25 `grep` seeker. C26 `rm -rf` cannon. C27 `cron` mines. C28 `ping` sonar. C29 `chmod 000` freeze ray. C30 `pipe |` chain beam. C31 `/dev/null` black hole. C32 SIGHUP confusion grenade. C33 Unlocks, mods and light skins.
M5 Your machine is the world (filesystem maps, process enemies, themes, etc.)
- C43 Audit Trail visor (after process enemies exist): lineage lines, read-only PID/PPID/name/CPU/mem only, chain-sever arena reaction, credit tag.
- C44 CREDITS.md + in-game top-style credits roll (demo data for captures).
M6 Story campaign
- C34 Story bible in docs/STORY.md (premise, characters, AI's voice, mission list) for Fred's review before any mission is built.
- C38 Opener: fake terminal + typed lines (demo data first). C39 Opener: real-data reader (read-only names/sizes/counts/mtimes/theme, opt-in, fake-data fallback). C40 Opener: shrink-away reveal + directory-tree fall. C41 Opener: AI link beat + the copy of you. C42 Opener: kill -9 forge, first kill, title slam, music, skip logic. (Built after C10 boot and C7 derezz exist.)
- C35 Mission framework (objectives, terminal-log pickups, AI dialogue triggers). C36 Cyberpunk ruins district art kit. C37 First mission end to end. Further missions one chunk each.
Website, teaser and docs
- T1 Teaser footage (Fred, 2026-10-30 8:53 PM ET: a 70 second teaser of real in-game footage, demo data, for the top of playsigkill.com): tools/trailer_capture.sh renders the clips (docs/TRAILER.md); the edit and the original soundtrack are the producer's.
- D1 Full PRD rewrite (next).

## 9. Open questions for Fred
1. Matchmaking/relay hosting: where and what budget? (Needed before C15 deploys.)
2. ~~AI guide source~~ DECIDED: Omarchy default agent first, local model fallback, scripted last.
3. Windowed playtests on the dev machine: OK to pop a game window on your desk when I ask, or keep it to headless + clips?
4. First playable target: M1 + M2 (solo, looks great, your AI talks) before multiplayer? (Producer's pick: yes.)
