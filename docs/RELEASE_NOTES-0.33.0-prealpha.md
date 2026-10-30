# SIGKILL 0.33.0-prealpha

**Pre-alpha. Build 33, after chunk C33. Linux x86_64. MIT.**

This is the first public build of SIGKILL, a native first-person shooter for Omarchy. It is a pre-alpha: everything below is in the game and passes the headless checks, but most of it has only been played on one machine, the story is not written yet, and 1.0 is a long way off. Expect rough edges, and saves that a later build may reset.

Download and install: [README, Download (pre-alpha)](../README.md#download-pre-alpha). What changes on your machine: [README, Safety and privacy](../README.md#safety-and-privacy).

## What is in

- **The arena.** A Tron arena in a black void: neon grid and edges, code rain bleeding through the walls near daemons, a skyline, props and signs, lit with AgX tone mapping, glow, SSAO and SSR, with high, medium and low graphics presets.
- **13 weapons**, every one a Unix signal or shell command made physical, each with its own first-person model: the terminal cannon, SIGTERM, the SIGKILL rail rifle (`kill -9`, the ult), the fork bomb, the `fork()` shotgun, the `grep` seeker, the `rm -rf` cannon, `cron` mines, `ping`, `chmod 000` (the freeze ray), `pipe |` (the chain beam), `/dev/null` (the black hole) and SIGHUP (the confusion grenade). Keys 1 to 9, and Shift+1 to 4 for the second bank.
- **Daemons that fight back.** Rogue daemons, zombie processes and runaway swarms, in solid dark armour lit only at their seams, with rare elites. They hunt you with readable tells; alone you have 100 health. Easy, normal and hard, and a practice mode where they never attack.
- **ICE and ICEbreakers** (a community prompt by Tim Provencio, [@TimProvencio](https://x.com/TimProvencio)): white ICE walls and nodes, the adaptive hunter, rare Black ICE that no weapon kills; and four one-use ICEbreakers to fight them (brute, exploit, cloak, decoy).
- **Abilities and modes.** SIGSTOP bullet time, code-rain vision through walls, root vs user with `sudo` overcharge, spectate as `top`, derezz deaths, and light-trail mode for Tron deathmatch.
- **Multiplayer over LAN or a tailnet.** Direct play between two machines, the host judging every shot; the host's rules (light trails, difficulty, practice, ICE, mods) are the match's.
- **Unlocks, mods and light skins.** Every weapon has its own skin and two more to earn by playing (solo against the daemons, or the host's word in a match), and one mod, a sidegrade. Esc, Loadout shows them on a turning model. Offline and local only: no store, no account, no network call, no telemetry.
- **Your AI as a guide (optional, asked first).** The boot screen finds your Omarchy default agent (Claude Code or Codex) or a local model server, and calls it only after you say yes: a guide you can ask anything with T, round coaching, and an optional roast announcer. `--no-ai` and `--demo` keep it off.
- **Settings for everything,** on one screen: controls and rebinding (no Ctrl, Alt or Super chords, none bindable), video, audio, HUD and accessibility (a colourblind-safe palette among them), privacy, gameplay and multiplayer.

## What is not in yet

- **The story.** The campaign, its story bible (C34), the mission framework (C35), the cyberpunk ruins art kit (C36), the first mission (C37) and the opener (C38 to C42).
- **"Your machine is the world"** (M5): filesystem maps, process enemies, theme levels, keybind gunplay, voice commands, the packet tracer arena, split-screen co-op, the Audit Trail visor (C43) and the in-game credits roll (C44).
- **Online rooms.** Room codes and invite links need a relay, and the public relay is not hosted yet: with none set, the game says so and sends nothing. LAN and tailnet play by address works.
- **Music.** The sounds are synthesised in code; the music bus has nothing on it yet.
- **Packages.** No AppImage, no AUR package: the tarball and running from source only.

## Known issues

From the design log's State section (`docs/DESIGN.md`), the ones a player is most likely to meet:

- **Barely playtested.** Every feature is checked headless and in stills shot on a private display; few have been played in a window, all on one machine, and the newest (SIGHUP, unlocks and mods) not at all: thresholds, numbers and timings wait for a playtest.
- **One GPU family seen.** It has run on NVIDIA only. The medium preset is aimed at an RTX 4050-class laptop GPU but has not been measured on one, and two of `/dev/null`'s shaders use `pow()` on negative numbers, which draw correctly on the one GPU tried and are untested elsewhere.
- **Trust in a match.** The host judges hits, damage and kills, but some things are each player's own screen's: its position, its charge wind-ups, its unlocks and look. A modified client could wear a skin it never earned or skip a wind-up; mods are sidegrades, and the host can turn them off.
- **A joiner earns less.** In a match a joiner earns only from weapon kills and `kill -9` headshots that the host confirms; the other feats count alone, or for the host.
- **Crouch is local.** The view drops and the pace slows, but the hitbox stays standing and other players do not see it.
- **Saves.** Unlock counts are saved at a round's end, on pause, on quit and at most every 30 seconds, so a crash can lose up to 30 seconds of counts. This is save format 1; a later build may reset it.
- **The engine at startup.** Godot itself, for any project, runs `xdg-user-dir DESKTOP` through `sh` and connects to the D-Bus buses at startup; SIGKILL's own code does neither.
- **Not yet checked on Wayland.** The launcher entry matches the window by its class, `SIGKILL`, checked on X11; the window's id on a native Wayland session has not been checked.
- **Test flakes.** A few headless checks (the WebSocket relay's real-time code expiry, the guide HUD's GPU poll, and the net and cannon tests) have each failed in a full gate run now and then and passed in the runs after; none failed in this build's gate. The boot test prints a warning about objects left at its own exit (17 to 20 objects over eight runs, on this release and on C33 alike); the gate does not count warnings.

## How it was checked

The full headless gate (`scripts/check.sh`) ran on a clean copy of C33's last commit (`ed20765`) on 2026-10-30 and ended:

```text
ok:   unlocks test: exit 0, no error lines
CHECK PASSED
```

All 47 steps passed (every script parses, a headless import, a 300-frame run, and 44 headless test suites, all over 127.0.0.1 and fakes only). The release binary itself has not been built yet; see [`docs/RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).
