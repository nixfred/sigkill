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
- 2026-10-25 10:15 PM ET: C4 (de7c203) and C4b README graphics pass (52383f3) verified: pushed to private origin, check.sh exit 0, privacy grep clean, docs/media has banner, title banner, 2 concept images (captioned "Concept art, not in-game footage"), Controls table matches scripts/controls.gd. Codex: 1 low finding fixed. Larry's dev tooling settings changed.
- 2026-10-25 10:15 PM ET: C5 movement feel sent. Producer decisions: slide on the C key (no Ctrl), head_bob_enabled toggle in the MovementTuning resource (default on), headless movement test wired into check.sh.
- 2026-10-25 10:40 PM ET: C5 verified: c223950 pushed to private origin, check.sh exit 0 (import, 300 frames, new headless movement test), privacy grep clean. Codex: 3 medium + 3 low, 5 fixed, 1 rejected with reason. Window-only feel still unverified. The docs sync commit (player AI = Omarchy default agent) was not done in C5, so it is step 0 of C6.
- 2026-10-25 10:40 PM ET: C6 terminal cannon feel sent. Producer decisions: placeholder SFX generated procedurally in-engine (no downloaded audio), hit marker plus impact sparks in the neon palette, all cannon tunables in one WeaponTuning resource, README screenshots only if an offscreen capture works with no window.
