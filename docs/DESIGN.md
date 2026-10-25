# SIGKILL - design (stub)

Status: stub for prototype step 1. Everything here is intent, not commitment.

## Pitch

You are the nixfred hexagon. Rogue daemons, zombie processes and runaway apps have
taken over a terminal arena. Hunt them down with the terminal cannon.

Tone: dark terminal. Near-black surfaces, teal and mint accents, monospace type,
dry sysadmin humour in the flavour text.

## Pillars

1. **Native and snappy.** Starts fast, runs on Wayland, feels like a first-person shooter.
2. **Terminal arena.** The look is a terminal, not a skin on a generic shooter.
3. **Harmless by design.** See the safety contract. Non-negotiable.

## Safety contract (hard rules)

The game must never modify, delete, execute, signal or kill anything on the player's system.

- Banned in game code: running programs, spawning processes, sending signals, opening
  external URLs or programs, renaming or removing files, and writing any file outside
  `user://`. In Godot terms that means no `OS.execute`, `OS.create_process`, `OS.kill`,
  `OS.shell_open`, no `DirAccess.remove` or `DirAccess.rename`, and no `FileAccess` write
  mode outside `user://`.
- Future features that look at the player's system (arena built from directory names,
  enemies named after processes) read **only names, sizes and counts**. Never file
  contents, command lines, environment or paths of other users. Anything read stays
  in memory and is never saved, logged or sent anywhere.
- Enemies are cosmetic. "Killing" a process-named enemy only despawns a game object.
- Nothing private in the repo: no real paths, hostnames or process lists. Test data uses
  invented names (`rogue.d`, `zombie`, `<defunct>`, `runaway`).
- Audit before every commit:

```bash
rg -n 'OS\.(execute|create_process|kill|shell_open)|DirAccess\.(remove|rename)|FileAccess\.open' scripts/
```

Any hit needs a comment explaining why it is safe, and review.

## Input and focus contract

- No Ctrl+Alt binds, and no Ctrl/Alt/Super chords at all.
- The mouse is captured only after a click inside the focused window.
- Esc releases it. Losing window focus releases it. The game never re-grabs on its own
  and never steals focus.

## Controls (prototype)

WASD move, mouse look, Space jump, left click fire, R respawn targets, Esc release mouse.
Bindings live in `scripts/controls.gd`.

## Greybox arena (prototype)

40 by 40 m open-top arena, 4 m outer walls, a doorway room to the north, an L-shaped
nook west, two pillars east, crates and a jump platform near the spawn.
Four static hexagonal dummies tagged with invented process names. One hit despawns
a dummy. R reloads the scene.

Physics layers: 1 world, 2 player, 3 targets. The cannon ray masks 1 and 3.

Palette and placeholder materials live in `scripts/palette.gd`.

## Backlog

- Verify the project in the Godot editor and fix first-launch issues.
- Moving enemies with simple behaviours (patrol, rush, hide).
- Weapon feel: recoil, muzzle flash, sound, hit markers.
- Health, damage, pickups, game states, pause menu with a real quit.
- Audio.
- Settings: sensitivity, FOV, key rebinding.
- Packaging: PKGBUILD that builds from source on the target machine.

## Open questions

- Will the arena ever read real directory or process names? If yes, the contract above
  applies in full and needs a design pass first.
- Pause menu and quit flow. Today only the window close button quits.
- Exact hexagon enemy silhouettes versus the player mark (keep the player mark
  unique to the logo).

## TODO

- Icon: use the official icon-only hexagon with white `>_` from `/workspace/nixfredos/brand`.
  Do not redraw it. Set `config/icon` in `project.godot` once the file is available.
