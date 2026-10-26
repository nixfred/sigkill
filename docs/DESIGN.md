# SIGKILL design doc

Native first-person shooter for Omarchy (Arch + Hyprland). You are the nixfred >_ hexagon hunting rogue daemons, zombie processes and runaway apps in a terminal arena.

## Decided
- Name: SIGKILL (Fred).
- Native installable Linux game, not web.
- Code lives at the dev machine; Larry (herdr workspace "sigkill") writes all code.
- Safety: game never modifies, deletes, executes, signals or kills anything real. Filesystem/process features read names, sizes, counts only. Demo-data mode for anything public. No Ctrl+Alt hotkeys, no focus stealing, no GPU use when not running.
- Brand: locked nixfred hexagon (icon-only, white >_) on icon, repo, README.

- Visual direction: Tron light-grid plus Matrix code rain (Fred).
- Easy internet multiplayer (room codes/invite links) is a core feature (Fred).
- Signature feature: the player's own real local AI is their in-game guide, shown live as theirs (Fred).
- Quality bar: Rockstar-level polish; Larry builds in small numbered chunks, each verified before the next (Fred).
- Full spec: PRD.md (docs/PRD.md in repo).

- (2026-10-25, Fred) Player AI = the Omarchy default agent (~/.config/omarchy/defaults/agent), called directly in non-interactive mode with tools off, never via omarchy-agent. Fallback: local model server, then scripted guide. Live GPU stats on boot and HUD. Safety rule reworded to allow only this one execution. New chunk C9b (agent adapters).
- Enemy art bar (Fred, 2026-10-25 10:23 PM ET): no cartoon monsters. Daemons are faceless, geometric, menacing: black obsidian shards with floating red terminal glyphs, angular red drone swarms, and a giant red-hot lattice core as the CPU boss. Kills derezz into glowing voxel cubes. Reference: readme-art/sigkill-epic-1.jpg and sigkill-epic-2.jpg (concept art).
- Arsenal (Fred, 2026-10-25 10:25 PM ET): many weapons, each a signal or shell command made physical (kill -9 rail rifle, fork() shotgun, grep seeker, rm -rf cannon, cron mines, ping sonar, chmod 000 freeze ray, pipe chain beam, /dev/null black hole, sudo overcharge, plus the signal set), with mods, light skins and unlocks. Full list in PRD 5.2.
- Story (Fred, 2026-10-25 10:25 PM ET): cyberpunk + Matrix + Tron campaign. A sysadmin jacked into their own machine hunts processes they never started; their AI is the only one they trust, until the trail asks who wrote the daemons. PRD 5.6, milestone M6.
- Opener (Fred, 2026-10-25 10:45 PM ET): 2-minute trapped-in-the-game cold open built from the player's real machine (fake crash in their theme, real usernames/folders/uptime, a copy of them as the first daemon, "SIGKILL sent by you to you"). Real data read-only and shown live only; Esc always works; opt-in with fake-data fallback. PRD 5.7, chunks C38-C42.
- Community prompts (Fred, 2026-10-26): build-in-public on X; accepted prompts get credited. First: Albert / @QuantaCortex's Audit Trail visor (PRD 5.5, C43). Credits roll is a live top-style process table with contributors as processes, Fred as PID 1, ending in a kill -9 derezz (PRD 5.8, C44).

## Proposed (waiting on Fred)
- Relay hosting/budget for matchmaking; local-only vs cloud AI keys; windowed playtests on the dev machine; first playable = M1+M2 before multiplayer (producer pick).
- Engine: Godot 4 (Vulkan, single binary), pending Larry ENGINE.md. Fred approved installing godot 4.7.2 from pacman on the dev machine (2026-10-25).
- Hook: filesystem maps + Larry announcer (Random Bot's pick).

## Idea pile
- Signal weapons (SIGTERM shotgun, SIGHUP, SIGKILL railgun, fork bomb), SIGSTOP bullet time, code-rain vision, light-trail mode, root vs user, derezz deaths, spectate as top (Fred: loves all, in PRD)
- Filesystem is the map (folders = rooms, size = room height, node_modules = endless maze)
- Live process hunting (tabs = swarms, pegged core = boss), cosmetic kills only
- Ramblr voice commands ("reload", "Larry, cover me") via Ramblr bot
- Hyprland split-screen co-op (tile size trades view for aim speed)
- Larry AI announcer roasting real round stats (local model)
- Keybind gunplay mapped to real Omarchy shortcuts
- Theme-shift levels (Tokyo Night, Catppuccin, Gruvbox), palette-only enemies
- Packet tracer arena: tailnet machines as islands

## State
- 2026-10-25: the project dir was empty. Sent Larry step 1: engine recommendation (docs/ENGINE.md) + Godot scaffold + greybox arena, local commit only, no installs. Godot install waiting on Fred.
- 2026-10-25 7:20 PM ET: step 1 committed d086489 (scaffold, syntax-checked only). C1 sent: install Godot, clean headless import, commit PRD.
- 2026-10-25 10:15 PM ET: C4 (de7c203) and C4b README graphics pass (52383f3) verified: pushed to private origin, check.sh exit 0, privacy grep clean, docs/media has banner, title banner, 2 concept images (captioned "Concept art, not in-game footage"), Controls table matches scripts/controls.gd. Codex: 1 low finding fixed. Larry switched to the default build model.
- 2026-10-25 10:15 PM ET: C5 movement feel sent on the default build model. Producer decisions: slide on the C key (no Ctrl), head_bob_enabled toggle in the MovementTuning resource (default on), headless movement test wired into check.sh.
- 2026-10-25 10:40 PM ET: C5 verified: c223950 pushed to private origin, check.sh exit 0 (import, 300 frames, new headless movement test), privacy grep clean. Codex: 3 medium + 3 low, 5 fixed, 1 rejected with reason. Window-only feel still unverified. The docs sync commit (player AI = Omarchy default agent) was not done in C5, so it is step 0 of C6.
- 2026-10-25 10:40 PM ET: C6 terminal cannon feel sent on the default build model. Producer decisions: placeholder SFX generated procedurally in-engine (no downloaded audio), hit marker plus impact sparks in the neon palette, all cannon tunables in one WeaponTuning resource, README screenshots only if an offscreen capture works with no window.
- 2026-10-25 11:30 PM ET: C6 verified: 43b1f74 (docs: player AI = Omarchy default agent) and 6403dbd (cannon feel) pushed to private origin, local matches origin/main, check.sh exit 0 (new headless cannon test, 46 checks). Codex: 4 medium + 3 low fixed, then 1 mouse-path pitch clamp fix, third run clean. No screenshot possible (no offscreen compositor, none may be installed). Visual and audio feel unverified.
- 2026-10-25 11:30 PM ET: C6b deep README rewrite sent on the default build model, as Fred asked at 10:47 PM. Producer decision: new commits drop the model-naming Co-Authored-By and session-link trailers and keep model names out of commit bodies; existing history is not rewritten. Next after C6b: C7.
- 2026-10-26 12:10 AM ET: C6b verified: README rebuilt (456 lines, 12 sections) in d217645, 70c951d, df9d6f4, 7a49a5e, de05ce1, all pushed, local matches origin/main. Both key-art images in docs/media captioned "Concept art, not in-game footage", every docs/media path exists, arsenal and roadmap statuses match git log (only C1-C6 built), opener teased without beats, privacy grep clean, check.sh exit 0. Codex: 10 findings over four passes, all fixed; one deferral (neon edge shader comment says "thinner", fix in the next code chunk). Step 0 doc sync was a no-op (PRD already matched).
- 2026-10-26 12:10 AM ET: Producer decisions on two PRD tensions Larry flagged. (1) Reading the one-line Omarchy default-agent setting is a named, narrow exception to "never file contents": that single config value only, nothing else. (2) GPU stats: prefer /sys reads; a query-only nvidia-smi call (--query-gpu with --format=csv, no control flags) is a second named execute exception, optional, and the HUD hides GPU stats when it's unavailable. Also: model names are stripped from this doc's State log. C6c credits + community prompt sync sent next, then C7.

- 2026-10-26 12:45 AM ET: C6c verified: d3223b1 (PRD sync), 68ecde7 (DESIGN sync), 5f89bf8 (CREDITS.md + credits mockup), e14440c (README credits and community prompts), 3c178a4 (neon edge shader comment fix), all pushed, local matches origin/main, repo still private. docs/PRD.md byte-identical to the producer copy, CREDITS.md at repo root, mockup captioned "Mockup of the in-game credits roll, not in-game footage.", Albert (@QuantaCortex) credited for the Audit Trail visor (Planned, C43), C43/C44 in the M5 roadmap row, every docs/media path exists, privacy grep clean, check.sh exit 0. Codex: 1 low finding (C43 plan line omitted memory while 5.5 allows it).
- 2026-10-26 12:45 AM ET: Producer decision: section 5.5 wins, so the C43 plan line now reads "read-only PID/PPID/name/CPU/mem only" (synced in C7 step 0). C7 derezz sent next. Producer decisions for C7: voxel shatter is pooled, capped and GPU-cheap (no per-voxel rigid bodies), all tunables in one DerezzTuning resource, dummies respawn after a short delay, red-hot voxels per the enemy art bar, plus a headless derezz test in check.sh. The kill feed stays with the netcode chunk.
