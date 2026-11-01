<p align="center"><img src="docs/media/nixfred-icon.svg" width="96" alt="nixfred hexagon"></p>

# SIGKILL // CREDITS

```
$ top -p sigkill --credits
PID   USER            %CPU  COMMAND
1     @NixFred        99.9  init: creator, director, kill -9 enthusiast
2     Larry           88.4  writes every line of code (Claude Code)
3     SIGKILL         71.2  producer, designer, daemon wrangler
1337  @QuantaCortex   64.0  audit_trail --visor --trace-parents
1338  @TimProvencio   57.3  ice --white --hunter --black --breakers
1339  @cgranier       50.1  man sigkill; oom-killer --boss; uptime --score
1340  @ocdjeremy      44.6  htop --visor; zoom --stepped; hitbox --real
1341  @MindGamesLabs  38.2  sudo grenade --tries=3
1342  @timsonner      31.9  fsmode --rooms; filehunt --beacon
```

## Community-built

SIGKILL is built in public. Reply to [@NixFred](https://x.com/NixFred) with one prompt; if it makes it into the game, you go here, and in the in-game credits roll.

| Contributor | Idea | In the game as |
|---|---|---|
| Albert / [@QuantaCortex](https://x.com/QuantaCortex) | [Audit Trail visor](https://x.com/QuantaCortex/status/2114564781050908930): trace every enemy to its parent process; sever the spawn chain to change the arena | Audit Trail visor, built in C43 (press I; its HUD says "visor design: @QuantaCortex"); its first taste in mission 2, `defunct` (M2): every zombie's thread to its parent |
| Tim Provencio / [@TimProvencio](https://x.com/TimProvencio) | ICE and ICEbreakers: William Gibson's intrusion countermeasure electronics as a new enemy class, the system defending itself against you (white ICE, hunter ICE, Black ICE), and one-use ICEbreakers to carry against it | ICE: white ICE and hunter ICE built (I1), its HUD tagged "ICE design: @TimProvencio"; ICEbreakers built (I2): brute, exploit, cloak and decoy, pickups and the AI's pick; Black ICE built (I3): rare, unkillable by weapons, its arrival killing the lights, the hum and the AI's link, its touch a flatline, broken only by exploit and brute |
| Carlos Granier / [@cgranier](https://x.com/cgranier) | Five ideas: a `man sigkill` training level (each weapon unlocks after you read its man page in the world; EXAMPLES is a 20-second drill, `--help` replays it), the OOM killer boss that hunts the biggest in-game memory user, self-wiping `/tmp` and shootable-counter `/proc` arenas (invented spaces, not real folders), uptime as the solo score with a kernel-panic stats screen, and music driven by the in-game load average | status: planned, post-1.0 |
| Jeremy / [@ocdjeremy](https://x.com/ocdjeremy) | An htop-style visor overlay of in-game daemons, ICE and players only (never real processes), stepped zoom on scoped weapons with hold or toggle, real hitboxes (head and centre mass hardest, limbs least), each weapon balanced on its own strengths, and VR as a stretch | status: planned, post-1.0 |
| MindGameLabs / [@MindGamesLabs](https://x.com/MindGamesLabs) | A sudo grenade that will not throw until you type a password (an in-game one shown on screen, never yours; nothing typed is kept, sent or checked), three wrong tries and it goes off in your hand; separate from the Z sudo overcharge | status: planned, post-1.0 |
| Tim Sonner / [@timsonner](https://x.com/timsonner) | File mode: walk your folders as rooms and hunt files as monsters built from the existing daemon art; a file hunt (name the file you want and it carries a beacon through the maze); and a root mode, which becomes an opt-in, default-off sandbox that wrecks an in-memory decoy copy of the folder tree (names and sizes only), never real files. Killing a file monster is cosmetic and the real file is never touched; a kill shows the file's path on screen and in an end-of-run found list you open yourself, and nothing is ever opened for you | status: planned, post-1.0 |

## Names the skins borrow

Two of the weapons' light skins (C33) take their names and colours from open terminal themes, with thanks: [Dracula](https://draculatheme.com) (the cannon's purple and green) and [Catppuccin](https://catppuccin.com) (SIGTERM's pink and mauve). Others only nod by name to old machines and tools: green phosphor and `tty1`, CGA's cyan and yellow, the Commodore 64's blue, the VT220's white. A skin is two colours and a line of text; nothing of these projects is bundled.

## Colours the opener's terminal and the theme shift borrow

The opener's fake terminal (C38) ships six demo palettes, and each takes its colours, and only its colours, from an open terminal theme that Omarchy includes, with thanks: [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) (the default), [Catppuccin](https://catppuccin.com) Mocha and Latte, [Gruvbox Material](https://github.com/sainnhe/gruvbox-material), [Nord](https://www.nordtheme.com) and [Everforest](https://github.com/sainnhe/everforest). A palette is a list of colours under Omarchy's names for them; nothing else of these projects is bundled.

The theme shift (W3) plays its six levels in the same six palettes, in this order: Tokyo Night, Gruvbox Material, Nord, Everforest, Catppuccin Mocha and Catppuccin Latte. Each level's name on screen is the theme's own, and its colours are those values and nothing more: the worlds, the daemons and the tear between themes are SIGKILL's own, made in code. With opener data on, one more level plays in the player's own Omarchy theme's colours, read and never changed.

## The shortcuts keybind gunplay teaches

Keybind gunplay (W4) teaches Omarchy's default key bindings, with thanks to [Omarchy](https://github.com/basecamp/omarchy/tree/63f60f4fcc4786d97e5c0384be640bcdef46f9a1/default/hypr/bindings) (MIT, by Basecamp): the chords and the meanings its own binding files give them, Super with one key, as copied at commit 63f60f4. Every card shows Omarchy's own words for its shortcut. What a shortcut does in the game (a terminal blasting open, a window folding shut, the rest), the windows, the sounds and the daemons are SIGKILL's own, made in code. With opener data on, the drills follow the player's own binds, read and never changed.

## The pattern the pit's maze borrows

The opener's node_modules pit (C40) is walled in the classic "10 PRINT" maze, a diagonal one way or the other in each cell, after the one-line Commodore 64 BASIC program `10 PRINT CHR$(205.5+RND(1)); : GOTO 10` that made it famous (and the book about it, *10 PRINT CHR$(205.5+RND(1)); : GOTO 10*, MIT Press, 2012). The game's own shader draws it; nothing is bundled.

## The engine

SIGKILL is made with [Godot Engine](https://godotengine.org) (MIT licensed), with thanks. The in-game credits thank it, and every project above, by name.

## Brand

nixfred hexagon logo, locked. Art and audio original or properly licensed.
