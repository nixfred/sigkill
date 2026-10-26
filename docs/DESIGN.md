# SIGKILL design doc

Native first-person shooter for Omarchy (Arch + Hyprland). You are the nixfred >_ hexagon hunting rogue daemons, zombie processes and runaway apps in a terminal arena.

## Decided
- Name: SIGKILL (Fred).
- Native installable Linux game, not web.
- Code lives at gus:~/Projects/sigkill; Larry (herdr workspace "sigkill") writes all code.
- Safety: game never modifies, deletes, executes, signals or kills anything real. Filesystem/process features read names, sizes, counts only. Demo-data mode for anything public. No Ctrl+Alt hotkeys, no focus stealing, no GPU use when not running.
- Brand: locked nixfred hexagon (icon-only, white >_) on icon, repo, README.

- Visual direction: Tron light-grid plus Matrix code rain (Fred).
- Easy internet multiplayer (room codes/invite links) is a core feature (Fred).
- Signature feature: the player's own real local AI is their in-game guide, shown live as theirs (Fred).
- Quality bar: Rockstar-level polish; Larry builds in small numbered chunks, each verified before the next (Fred).
- Full spec: PRD.md (docs/PRD.md in repo).

## Proposed (waiting on Fred)
- Relay hosting/budget for matchmaking; local-only vs cloud AI keys; windowed playtests on gus; first playable = M1+M2 before multiplayer (producer pick).
- Engine: Godot 4 (Vulkan, single binary), pending Larry ENGINE.md. Fred approved installing godot 4.7.2 from pacman on gus (2026-10-25).
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
- 2026-10-25: ~/Projects/sigkill was empty. Sent Larry step 1: engine recommendation (docs/ENGINE.md) + Godot scaffold + greybox arena, local commit only, no installs. Godot install waiting on Fred.
- 2026-10-25 7:20 PM ET: step 1 committed d086489 (scaffold, syntax-checked only). C1 sent: install Godot, clean headless import, commit PRD.
