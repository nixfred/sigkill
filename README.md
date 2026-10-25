# SIGKILL

A native first-person shooter for Omarchy (Arch + Hyprland). You are the nixfred
hexagon, hunting rogue daemons, zombie processes and runaway apps in a terminal arena.

**Status:** prototype step 1, greybox only. This scaffold was written without Godot
installed, so it has not been opened or run yet. Expect a few first-launch fixes.

## Run

Needs Godot 4.7 (Arch: `godot` in extra). This project does not install it.

```bash
godot --path .            # play
godot --editor --path .   # open the editor
```

## Controls

| Input | Action |
|-------|--------|
| Click | Engage (captures the mouse) |
| W A S D | Move |
| Mouse | Look |
| Space | Jump |
| Left click | Fire the terminal cannon (hitscan) |
| R | Respawn all targets |
| Esc | Release the mouse |

The mouse is captured only after you click in, and is released on Esc or when the
window loses focus. There are no Ctrl/Alt/Super bindings.

## Safety

The game never modifies, deletes, executes, signals or kills anything on your system.
See `docs/DESIGN.md` for the full contract.

## Docs

- `docs/ENGINE.md` - why Godot 4
- `docs/DESIGN.md` - design stub, safety contract, backlog
