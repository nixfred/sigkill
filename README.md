<p align="center">
  <img src="docs/media/banner-title.jpg" alt="SIGKILL. kill -9 the daemons."><br>
  <sub><em>Concept art, not in-game footage.</em></sub>
</p>

<p align="center">
  <a href="https://godotengine.org/"><img alt="Godot 4" src="https://img.shields.io/badge/Godot-4-19d3c5?logo=godotengine&amp;logoColor=7dffcf&amp;labelColor=05080a"></a>
  <img alt="Vulkan renderer" src="https://img.shields.io/badge/Vulkan-renderer-19d3c5?logo=vulkan&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <img alt="Native Linux" src="https://img.shields.io/badge/Linux-native-19d3c5?logo=linux&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <img alt="Omarchy / Hyprland" src="https://img.shields.io/badge/Omarchy-Hyprland-19d3c5?logo=hyprland&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-19d3c5?labelColor=05080a"></a>
</p>

<p align="center">
  <a href="#download-pre-alpha"><img alt="PRE-ALPHA v0.33.0, build 33" src="https://img.shields.io/badge/PRE--ALPHA-v0.33.0%20%C2%B7%20build%2033-ff3355?style=for-the-badge&amp;labelColor=05080a"></a>
</p>

<p align="center"><b>A native Linux first-person shooter for Omarchy. You are the nixfred <code>&gt;_</code> hexagon, hunting rogue daemons inside your own machine, with your own AI at your side.</b></p>

<h3 align="center"><i>your AI has been watching you code for months.<br>what happens when you hand it a gun?</i></h3>

## Where we are

- **Pre-alpha.** The latest release is [v0.33.0-prealpha](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha) (build 33, 2026-10-30, a GitHub pre-release). It came before the opener, so the opener is on `main` only for now.
- **Built and playable on `main`, through C42:**
  - the Tron arena and its skyline
  - 13 weapons, with light skins, mods and unlocks
  - SIGSTOP bullet time, code-rain vision, root and `sudo`
  - daemons that fight back: rogue.d, zombies and runaway swarms, with seeded variants and elites, and (new in C42) each type's own voice: its tell, strike, hit and death
  - ICE, ICEbreakers and Black ICE
  - light-trail and LAN modes
  - your own AI as the guide
  - **the whole opener (C38 to C42), two minutes:** the fake crash, the fake terminal, the shrink-away, the fall through your folder tree as a city, your own AI answering live, and the copy of you walking up out of the pit wearing your user name. New in C42:
    - `kill -9` forges into the rifle in your hands, and the copy types "you won't.";
    - you fire; the derezz, the kill feed, the whisper, black, and SIGKILL slammed in on the hexagon;
    - all of it over an original score made in code: dark synths, then heavy metal from the forge.
  - **the first launch:** a card first asks whether the intro may use your real user name and folder names (No is the default). Then the intro plays itself once. Esc pauses it ("Skip intro" is right there), holding Space skips it, and "Play the opener" in the Esc menu replays it any time. It runs on demo data unless you say yes, or switch on Settings, Privacy and AI, opener data.
- **Also on `main`, the teaser tool (T1):** `tools/trailer_capture.sh` renders the teaser's raw footage as real in-game clips on demo data ([docs/TRAILER.md](docs/TRAILER.md)).
- **The teaser:** 70 seconds of that footage, with an original soundtrack, for the top of [playsigkill.com](https://playsigkill.com). The edit and the music are the producer's.
- **Docs (D1) done:** [the PRD](docs/PRD.md) is the entire, current PRD (v0.5 now, with C42): what is 1.0 and what comes after, every feature, the safety rules, and every chunk with its status.
- **Next:** C35, the mission framework, then mission 1 (C36 and C37) and the other six missions.
- **Try the opener** from source: Esc, then "Play the opener", or start with the flag, `godot --path . -- --demo --opener` (a build of `main` takes it the same way, after `--`). A build of `main` also shows the first-launch card and plays it once by itself; the v0.33.0 release came before the opener.
- **Read more:** [the PRD](docs/PRD.md), [the story bible](docs/STORY.md), [the design log](docs/DESIGN.md), [the teaser footage](docs/TRAILER.md).

## Download (pre-alpha)

> [!WARNING]
> **SIGKILL 0.33.0-prealpha is a PRE-ALPHA: build 33, far from 1.0.** In: 13 weapons, daemons that fight back, ICE and ICEbreakers, light-trail and LAN modes, unlocks, mods and light skins. Not yet: the story, the missions and the rest of the 1.0 list. Expect rough edges, and saves that a later build may reset. What is in and what is not: [the release notes](docs/RELEASE_NOTES-0.33.0-prealpha.md).

**Linux x86_64 build.** Get `sigkill-0.33.0-prealpha-linux-x86_64.tar.gz` and its `.sha256` from [the v0.33.0-prealpha release](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha) (a GitHub pre-release; all builds: [Releases](https://github.com/nixfred/sigkill/releases)).

```bash
sha256sum -c sigkill-0.33.0-prealpha-linux-x86_64.tar.gz.sha256
tar -xzf sigkill-0.33.0-prealpha-linux-x86_64.tar.gz
cd sigkill-0.33.0-prealpha-linux-x86_64
./install.sh            # or play without installing: ./sigkill.x86_64
```

`./install.sh` copies three files into your home and nothing else: the game to `~/.local/bin/sigkill`, a launcher entry to `~/.local/share/applications/`, and the hexagon icon to `~/.local/share/icons/`. No sudo, no system folders, no link or file handlers. `./uninstall.sh` removes exactly those three files; your settings and unlocks stay in `~/.local/share/godot/app_userdata/SIGKILL/`. It is one binary with the game inside, for x86_64 Linux with a Vulkan-capable GPU and driver (so far run only on NVIDIA).

**From source** (Omarchy or any Arch; Godot 4.7 from pacman):

```bash
sudo pacman -S --needed godot git
git clone https://github.com/nixfred/sigkill.git && cd sigkill
godot --headless --path . --import   # once, on a fresh clone: builds Godot's cache (about a minute)
godot --path .
```

`scripts/play.sh` does both steps for you. Launch options (`--demo`, `--no-ai`, `--join`, `--light-trails`, `--opener`) are under [Install and play](#install-and-play).

**Controls, in short.** WASD move, mouse look, Space jump, C slide, X crouch, left click fire, right click aim. 1 to 9 draw a weapon, Shift+1 to 4 the second bank, E reload, Q last weapon, F bullet time, V code-rain vision, Z sudo, Tab spectate as top. Esc opens the menu: Resume, Loadout (skins and mods), Settings (most keys can be rebound), Quit. No Ctrl, Alt or Super chords, and none can be bound. [The full table](#controls).

**Multiplayer.** LAN and tailnet direct play works: one player presses M then H to host, the other M then J and types the host's address; the host opens UDP 9009 once (`sudo ufw allow 9009/udp` on Omarchy). Room codes need a relay, and the public relay is not live yet: with none set, the game says so and sends nothing. [Playing on a LAN or tailnet](#playing-on-a-lan-or-tailnet).

**Safety.** SIGKILL never modifies or deletes anything on your system, and never signals or kills a process except the AI agent it started itself. Its "your machine is the world" features read names, sizes and counts only, and the daemons you kill are game objects: no real process is ever touched. The only programs it runs are your own AI agent's command-line tool, with tools and edits off and only after you say yes, and an optional query-only `nvidia-smi` for the GPU readout. It writes only into its own data folder: its settings and your unlocks, plus the Godot engine's own run log and shader caches. Screenshots and trailers use demo data (`--demo`). [Safety and privacy](#safety-and-privacy).

## Key art

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/media/key-art-hunt.jpg" alt="First-person view: a teal kill -9 beam derezzing an obsidian daemon into red voxels, a drone swarm overhead and a red lattice core in the sky"><br>
      <em>Concept art, not in-game footage.</em>
    </td>
    <td align="center" width="50%">
      <img src="docs/media/key-art-city.jpg" alt="The operator and a glowing AI companion standing over a directory-tree megacity, a red lattice core and drones on the horizon"><br>
      <em>Concept art, not in-game footage.</em>
    </td>
  </tr>
</table>

## What SIGKILL is

SIGKILL is a first-person shooter that runs natively on Omarchy, the Arch and Hyprland desktop. It is not a web game and not a port: it is a Godot 4 project, built and checked against Godot 4.7.2 from the Arch `extra` repository, rendered with Vulkan through Godot's Forward+ renderer.

You play the nixfred `>_` hexagon, deep inside your own machine, hunting rogue daemons, zombie processes and runaway apps. The machine defends itself too: **ICE** (I1, a community prompt by [@TimProvencio](https://x.com/TimProvencio)) walls off its doors and corridors, jams your weapon, scrambles your HUD, and sends a hunter that learns which weapon you lean on; against it you carry **ICEbreakers** (I2), one-use programs to break a wall, hit its seams, slip past unseen or throw it a decoy. Rarely, the machine sends its last line of defence, **Black ICE** (I3): the lights die, the hum drops out, your AI's link is cut, and something no weapon can kill comes for you, slower than you run, whose touch ends the run. The world has three visual registers that share one space:

- **Tron** where the system is healthy: a pure black void, glowing light grids, neon edges on every surface. Teal and mint are yours; red and amber are hostile. **Built:** the greybox arena already has the black void, the glowing floor grid and the neon edges.
- **Matrix** where reality is thin: green code rain that bleeds through walls when daemons are near. **Built:** the greybox walls rain glyphs around every live dummy, and the rain fades when it derezzes. Code-rain vision is **Built** (C21): hold V and enemies show through walls as glyph silhouettes.
- **Cyberpunk** in the deep directories: neon megacorp ruins, rain and signage. **Planned** (C36 ruins art kit).

In the planned game, corruption pushes the clean Tron grid toward Matrix rain and cyberpunk decay, and the core loop is fast arena deathmatch against other players plus a solo or co-op daemon hunt, in the same arenas with the same weapons, wrapped in a story campaign. Today's build is single-player: one greybox arena with target dummies that derezz into voxels when killed and then respawn, and walls that rain code wherever a dummy stands near them.

### Why a big studio can't ship this

A studio game has to be the same on every machine. SIGKILL is different on every machine, on purpose:

- **It is built from your machine.** Later milestones turn your real folder tree into rooms and your running processes into enemies, using only names, sizes and counts. The few other planned reads are narrow and read-only, and the [safety section](#safety-and-privacy) lists them all. Every kill is cosmetic.
- **It plays alongside your AI.** Your guide is the coding agent you already chose in Omarchy, talking to you live, on your own subscription or your own hardware (built in M2). A studio cannot ship your AI in the box.
- **It is made for one desktop.** Omarchy themes, Hyprland and the terminal culture around them are the setting, not an afterthought.

<table>
  <tr>
    <td align="center" width="33%">🟦<br><b>Tron arena</b><br>Black void, glowing light grid, neon edges.<br><sub>✅ Built: the greybox arena, dressed with depth, props, terminal signs and a skyline in A3</sub></td>
    <td align="center" width="33%">📡<br><b>Signal weapons</b><br>SIGTERM shotgun, SIGHUP confusion grenade, the SIGKILL rail rifle.<br><sub>🔧 In progress, M4: the weapon framework and SIGTERM (C16), the SIGKILL rail rifle (C17), the fork bomb (C19) and SIGHUP (C32) are built</sub></td>
    <td align="center" width="33%">🧠<br><b>Your REAL AI</b><br>The coding agent you already picked in Omarchy rides along as your guide.<br><sub>✅ Built, M2: detector (C9), adapters (C9b), boot screen (C10), guide HUD (C11), model loading (C11b), round coaching and roasts (C12)</sub></td>
  </tr>
  <tr>
    <td align="center">🌐<br><b>One-click multiplayer</b><br>Internet matches by room code. No port forwarding.<br><sub>🔧 In progress, M3: LAN and tailnet play (C13), synced combat (C14), room codes on the client side (C15) and the relay, over UDP (C16c) or WebSocket (C16d), are built; hosted nowhere yet</sub></td>
    <td align="center">🟢<br><b>Code-rain vision</b><br>See daemons through walls as Matrix glyphs.<br><sub>✅ Built (C21): hold V</sub></td>
    <td align="center">🐧<br><b>Native linux binary</b><br>Godot 4 on Vulkan, built for Omarchy and Hyprland.<br><sub>✅ Runs from source; packaged builds planned</sub></td>
  </tr>
</table>

Built today: the greybox arena with the Tron look, tight movement, the terminal cannon, target daemons that move as creatures in solid dark armour lit only at their seams (A5: a crimson mantis-scorpion, an amber hulk with a cannon arm shedding voxels off its open side, a hot-magenta swarm of hex drones round a core drone), no two alike and now and then an elite, flinch at a hit and burst into shards and voxels when killed, then respawn as a new one, and Matrix code rain on the walls near enemies. The game opens on a boot screen (C10) that names your Omarchy default agent, asks before it is ever called, shows it answering, and reads your GPU. In the arena the guide HUD (C11) shows your AI's badge, latency and GPU, T asks it anything and O turns it on or off; with a local Ollama server that has nothing loaded, T offers to load a model, only with your yes, and SIGKILL unloads it again (C11b). Rounds run for 90 seconds of play, then a 12-second break shows the round's numbers and one line about them from your AI: a tip, or with B a roast of your play; the callouts during a round come from the game itself (C12). Two players on the same LAN or tailnet can play together: one presses M then H to host, the other joins by the host's address, and each sees the other move (C13); they shoot each other, derezz at zero health, respawn away from the enemy and read the kill feed, with the host judging every shot (C14). Room codes and `sigkill://join/` invite links are built (C15), and so is the relay that carries a match across the internet, over UDP (C16c) or, for a host reached only through an HTTPS proxy, over WebSocket on one TCP port (C16d): run on 127.0.0.1 in the tests and hosted nowhere yet, so with no relay set (the default) a code says "not live yet" and nothing goes out. The arsenal runs on data now: each weapon is one resource, the player carries the terminal cannon and SIGTERM, the polite shotgun, swaps with 1 to 9, the wheel and Q, reloads with E, and in a match the host checks every weapon's shot and draws SIGTERM's pellets itself (C16). The SIGKILL rail rifle is the ult in slot 3: a meter filled by your other kills, one charged shot that pierces every target on its line to the first wall, and "kill -9" called out for a headshot (C17). The fork bomb is weapon 4 (C19): two grenades that split 1, 2, 4, 8 in fifteen neon blasts, thrown from slot 4 or with G, judged by the host in a match. Light-trail mode is a match rule (C20): when the host turns on "light trails" in Settings, Multiplayer (or starts with `--light-trails`), every player's path on the ground leaves a neon wall in their own colour for six seconds, and touching one derezzes you, the kill going to the wall's owner. Hold V for code-rain vision (C21): the dummies (or, in a match, the other players) within 40 m show through the walls as green glyph silhouettes and your screen dims toward green, on its own 3-second meter, on your screen alone. Every life starts as `user$` (C22): three kills in it earn a sudo charge, and Z spends it on 8 seconds of `root#`, the weapon in hand hitting 1.5 times as hard and spending no ammo, judged by the host in a match. Derezzed in a match, you watch the match as `top` until you respawn, and Tab shows that table any time (C23). F is SIGSTOP bullet time, with its own meter: alone in the arena the world drops to 0.3x while you still move and fire at 0.9x, and F again sends SIGCONT; in a match nothing slows for anyone, the slow-mo look stays on your own screen, and while the host says it is on your shots go steady, with no spread and no recoil (C18). Esc opens a menu with a full settings screen (C16b): invert Y, sensitivities, key rebinding and hold or toggle for the new crouch and aim, video, audio, HUD and accessibility, the three privacy switches in one place, and multiplayer, all on one screen, saved in one versioned settings file, with a LAN match running on behind it. The art pass has given every weapon its own model (A1), turned the daemons into moving creatures (A2, A2b) and then into solid armoured ones, each built from its own seed (A5), dressed the arena on its rooftop over a city of towers (A3), and lit it all (A4): AgX tonemapping, a glow that never blows out, warm signs against the teal, hostile red and magenta on the daemons, GPU sparks, derezz bits, trails and muzzle bursts, and a graphics preset (low, medium, high, each part its own toggle) with chromatic aberration and CRT scanlines as settings. And the daemons fight back (C27b): alone you have 100 health, every daemon hunts you by sight and every attack comes after a tell you can read (rogue.d rears up, its visor flaring; the zombie raises its cannon, its bands lighting one after another; the swarm pulls tight before each dive), with a difficulty setting, a practice switch for the old never-attack dummies, and in a match the host running every daemon for everyone. Weapon 9 is `ping` (C28): a sonar ring that outlines every daemon within 18 m through the walls for a few seconds, and breaks the tell of any it catches mid-attack. The machine defends itself with ICE (I1): crystal walls that seal a doorway and a corridor, nodes whose fields jam your weapon or scramble your HUD, and from round 2 a hunter that learns your favourite weapon; against it you carry ICEbreakers (I2), four one-use programs beside your weapons (U runs the loaded one, Y loads the next): brute breaks a wall up close, exploit makes your hits on the marked seams land far harder, cloak hides you from ICE and the daemons until you fire, and a decoy pulls the hunter, the daemons and the nodes' fields off you while you get away, with more lying in the arena mid-round and your AI (or the scripted guide) picking which to load. And rarely, from round 2, Black ICE comes (I3): a long, unmistakable arrival (the arena's lights die, its hum drops out, your AI's link shows cut, a warning reads "B L A C K   I C E"), then a huge black sun of crystal spikes that hunts you, slower than your run; weapons only flash it, its touch flatlines you (alone the run is over, in a match you are out for the round), a decoy pulls it off you, a cloak hides you from it, and only exploit then a brute while exploit runs breaks one of its two seals. Weapon 10 is `chmod 000`, the freeze ray (C29), the first of a second bank of weapons drawn with Shift and 1 to 9: hold fire and a cold beam strips a target's permissions, its freeze meter filling until it freezes solid under a frost crust, "PERMISSION DENIED"; a frozen daemon does nothing (a tell it was in is called off), the next hit on it lands twice as hard and a strong one shatters it, the hunter and the nodes freeze too, Black ICE is only slowed, and in a match a player is slowed and then frozen for a second, the host judging all of it. Weapon 11 is `pipe |`, the chain beam (C30), on Shift+2: one click sends a stream of brass light into the first target your aim meets, and it arcs on, link to link, to the nearest target in reach that it can see, up to five, each link 70% of the one before, written out under your crosshair as the command line it was (`$ rogue.d | zombie | runaway`); walls break a chain, a daemon chmod 000 froze conducts it whole and shatters, the hunter and the nodes are links, a wall of ICE ends it and Black ICE refuses it ("pipe: broken pipe"), its ammo is a 64K pipe buffer that fills with each chain and drains on its own, and in a match the host judges every link. Weapon 12 is `/dev/null`, the black-hole grenade (C31), on Shift+3: throw the device and where it lands a singularity opens for four seconds, a black core in a ring of plum fire bending the arena's light round it; everything in its 9 m reach (daemons, the hunter, cron mines, other players) is dragged in and swirled round it, stretched toward the core, hurt inside its 3 m horizon and discarded at the core ("> /dev/null"), and it ends in an implosion; a daemon caught mid-tell has the tell called off, the knot it draws together is ready for a chain or a bomb, a frozen daemon shatters at the core, ICE's walls and Black ICE never move ("/dev/null: device busy"), two charges come back on their own, and in a match the host judges every pull and every hurt; SIGHUP, the confusion grenade (C32), on Shift+4: throw the device (a telephone handset) and it goes off in a hangup, a carrier wave running out 7 m like an oscilloscope's trace with a curtain of static on its front; every daemon it reaches calls off its tell, forgets its target, stalls "reloading config" and then wanders confused (a "?" over it, its seams cycling green, looking round in snaps), and a confused crowd lashes at itself a little; the hunter forgets what it learned about your favourite weapon, a node drops its field to reload, Black ICE ignores it ("SIGHUP: ignored (nohup)"), a guard after each confusion stops anyone chain-locking a daemon, and in a match a player caught gets a moment of glitch on their own screen, never a control taken. Every weapon now has two Tron light skins and a mod to earn (C33): kill with it, or pull off its own feat (a kill -9 headshot, a freeze, a chain of three, a discard, a confused daemon's lash) against daemons that fight back, and an "UNLOCKED" toast says what you earned; Esc, Loadout shows each weapon's own model large on a turntable, lit live in the skin under your pointer, with its skins, its sidegrade mod and how to earn what is still locked; your progress is a small file on your own machine, never bought and never sent anywhere. And the opener's first 35 seconds are built (C38), from Esc, Play the opener: the game freezes on its own last frame, comes apart and cuts to black and silence, then a fake terminal in an Omarchy theme's colours types its own prompt and starts talking to you, on demo data (`user@workstation` and invented folders) unless you turn on "opener data" in Settings, Privacy and AI: then it shows your own user and host names, your Omarchy theme's colours, your folder names, your uptime and a late-night line from your file times, read live and read-only, never a file's contents, kept nowhere (C39). Then (C40) a fresh prompt ignores your typing for 3 seconds, "you're in now." types itself, and the camera pulls back from the terminal: it was one lit screen on a monolith in a machine the size of a city, and you fall through your directory tree as that city, your folder names on its towers, down to the node_modules pit where the hottest process beats red; the arena paused behind it and Esc leaving at any moment. Under them sit the AI source detector (C9) and the guide's agent adapters (C9b). Everything else on this page is labeled with its real status, and the roadmap below tracks it chunk by chunk.

## Story

> **Status: story bible locked (Fred, 2026-10-30)** ([docs/STORY.md](docs/STORY.md), C34: premise, the world's rules, characters, your AI's voice, seven missions, the ending; all ten open questions decided, each on its recommended pick). The work goes in the order a new player meets it: the opener first (C38 to C42, all built, below), then the missions (C35 next, then C36 and C37). None of the missions are built yet.

**You're a sysadmin jacked into your own machine, because something is spawning processes you never started.** Your AI is the only one you trust, until the trail leads to a question nobody wants answered: who wrote the daemons?

The campaign is told in short missions between arenas, through terminal logs you pick up, your AI's lines and the places themselves. There are no long cutscenes. The story is fiction from top to bottom: nothing in it reads or reveals real system data.

### The opener

> Something has been living in your machine longer than you have been playing.
>
> It has been waiting for you to notice.
>
> The first time you run SIGKILL, it notices you back.

The opener runs live in the engine, never pre-rendered. On first launch it plays by itself once, and you can skip it at any moment: Esc pauses it in its own menu with "Skip intro", or hold Space for a second. It uses your machine's real names only if you allow it, read-only: on the first-launch card, or later with Settings, Privacy and AI, **opener data** (off unless you turn it on); otherwise it runs on fake data. The window's close button always works. Status: ✅ built, all two minutes: the crash and the terminal (C38), the real-data reader behind them (C39), the shrink-away and the fall through your folders (C40), your AI's link and the copy of you (C41), and the `kill -9` forge, the first kill, the title, the music, the skip logic and the first launch (C42).

#### Built: the opener's first 35 seconds, on demo data (C38)

Esc, **Play the opener**. Stills in [Screenshots](#screenshots).

- **0:00 to 0:15, the fake crash.** The game freezes on its own last frame, the one you were looking at, while its sound sticks in a buzzing loop. Then the frame comes apart the way a stalled renderer's picture does: slices slip sideways, rows smear, blocks stick in runs, the colour channels split and corrupt toward the daemons' magenta. It drops to black twice, then cuts to black and dead silence at 3.1 s. It is the game glitching inside its own window: never a dialog, never your desktop, never a real freeze (every frame still runs and every key is still read).
- **The fake terminal.** At 6.6 s a terminal window pops in the way an Omarchy desktop draws one: 10 px gaps, a 2 px border in the theme's accent, square corners, 14 px of padding, the terminal's own font on a real monospace grid, a blinking block cursor. Then the prompt types itself, `user@workstation:~$`, in bash's colours.
- **0:15 to 0:35, the lines.** These are the PRD's words, typed as a hand types: every key its own wait, a beat before the punchlines, one typo taken back.
  - "thanks for running me." on your prompt, then "you never read the install script, did you?".
  - Folder names scroll past and the uptime ticks.
  - "I've been in here since you booted.", then a late-night line built from recent file times: "you were still up at 03:12 last night. so was I."
  - Then the cursor drops to a line of its own and a band of rows tears for an instant; C40 goes on from there.
- **Your theme.** The terminal's colours use Omarchy's own names for them (a theme's `colors.toml`), so C39 maps your real theme straight on. Six demo palettes ship, from open terminal themes Omarchy includes: Tokyo Night (the default), Catppuccin Mocha and Latte, Gruvbox Material, Nord and Everforest.
- **The demo data.** Everything comes through one small interface, `OpenerData`, taken once as the opener starts. C38 shipped `DemoOpenerData`: user `user`, host `workstation`, 28 invented folders, up 3 days 07:42:15, and a file time of 03:12 on a fixed date. Nothing real is read: no file, folder, environment variable, clock, process or theme. C39 added the real reader, opt-in and read-only, behind the same interface ([below](#built-the-opener-on-your-own-machine-opt-in-and-read-only-c39)).
- **Always a way out.** Esc leaves at any moment, mid-crash and mid-typing included, and the menu comes back as it was. The window's close button is never held. Alone, the arena is paused behind the opener and is not drawn while the opener covers the screen; in a match the entry is greyed out, since a match cannot pause.
- **Flash-safe.** The screen's brightness never drops to black and back 3 or more times in any second, and the glitch's pattern changes 10 times a second. It jerks, never strobes.
- **Sound.** All made by the game in code: the stuck buzz, the crackle, the silence, a low hum and a keyboard's clicks. The score starts at the shrink-away (C42).

The test, `tests/opener_test.gd` (check step 48), covers:
- the code: no environment variable, clock, program, network or file write, and only its own `res://` files opened;
- the demo data and the interface, with a stub source's names and palette shown only after cleaning;
- the six palettes' contrast;
- the typing's jitter and beats;
- a whole run, every beat in order inside its PRD window, word for word;
- the main loop ticking through the crash, and the flash cap;
- Esc mid-crash, mid-typing and in the hold;
- the menu entry in the real arena, and the `--opener` flag.

#### Built: the opener on your own machine, opt-in and read-only (C39)

Settings, Privacy and AI, **opener data**: off unless you turn it on. Off, the opener runs on the demo data above. On, the next time it plays it shows your machine, read live by `RealOpenerData` (`scripts/opener/real_opener_data.gd`) and let go when it ends. A demo run (`--demo`, or real-machine data off) keeps the demo data whatever the switch says, and the row says so. Stills in [Screenshots](#screenshots).

- **What it reads, all of it:**
  - your user name, from `USER` (or `LOGNAME`), and your home folder, from `HOME`: the only environment it reads, since GDScript has no other way to them;
  - your host name, from the first line of `/proc/sys/kernel/hostname` (or `/etc/hostname`);
  - your uptime, from the first number in `/proc/uptime`;
  - your Omarchy theme's colours, from the active theme's `colors.toml` (Omarchy 4's `~/.local/state/omarchy/current/theme/`, else Omarchy 3's `~/.config/omarchy/current/theme/`);
  - folder names under your home folder, how many entries each holds, and the modification times of what it walks past.
- **Never a file's contents.** Those three small files are the only ones it opens, each for a number or the colours, at most 64 bytes (16 KB for the theme). Everything else is names, counts and times. It writes, saves, prints, logs and sends nothing, runs nothing, and your AI gets none of it.
- **Bounded and fast, off the main thread.** A walk of at most 3 levels, 600 entries, 64 folders listed and 200 entries a folder, inside 150 ms, on a thread of its own, so the opener never waits on it (the test's fake home of 222 entries reads in about 7 ms). It keeps at most 128 folder names and 256 times.
  - Hidden folders are listed from the top level only, after the rest, and never walked, so the scroll shows your own folders before your tools' dotfolders.
  - `node_modules` is counted and never walked (C40's pit).
  - A symbolic link is never listed, walked or timed.
  - A folder on another filesystem (a network share, a removable disk) stays a name; a folder it may not read stays a name, quietly.
  - File times come only from what is not hidden, so an app's cache stirring at 3 in the morning says nothing about you.
- **Each value falls back alone.** The opener takes the values as soon as they are all in, or at 3.1 s regardless, while the screen is still the crash. Anything not read by then, unreadable or unusable is the demo's, for that value alone (the folders and their counts together, and the file times and the clock); a read still going stops there, so nothing changes after.
- **Your theme, kept readable.** `ThemeColors` reads `colors.toml` by Omarchy's own rules: its colour names, the older `bg`, `fg` and `color0` to `color15` names, the shades it derives, its light or dark mode. A theme whose text would be under 4.5:1 on its background is not used; the default palette is. Every palette, the demo ones too, is drawn with its coloured text and cursor at 3:1 or more, a colour under that pulled toward the foreground (latte's green and yellow included).
- **Wide characters.** Real names can be in any script, so the terminal now lays out in cells, as a terminal does: CJK, kana, hangul, fullwidth forms and emoji take two, combining marks and joined emoji none, and a wide character that would split at a row's end starts the next row. A cluster is drawn as one piece, scaled down if its glyph is wider than its cells. Names are cut by cells, never inside a character, and invisible characters that reorder or hide text (bidirectional overrides, isolates, zero-width spaces) are dropped. The widths are a close approximation of Unicode's tables, not the full ones.

The test, `tests/opener_real_test.gd` (check step 49), reads only a fake home folder it builds under `user://` (invented names, a fake theme, fake host and uptime files, a pinned clock) and removes it at the end. It covers:
- the reader's code: nothing written, saved, printed, logged, sent or run; its environment (`HOME`, `USER`, `LOGNAME`) and every engine call it makes, each listed with its reason; one place that opens a file, to read;
- the walk: names in order, counts and times; the depth, entry, listing and time caps; a link in and a link out, never followed; an unreadable folder, another filesystem, hidden folders, wide-character names; nothing written; off the main thread;
- the theme: Omarchy's names, the older ones, the derived shades and the mode, and five kinds of unusable theme falling back;
- each value falling back alone;
- the terminal's cells and `clean()`'s cut;
- the opt-in, in the real arena: the settings row, demo data with it off or on a demo run, the opener on the fake home with it on, the reader dropped as the opener ends.

#### Built: the shrink-away and the fall through your folders (C40)

The opener goes on past the terminal, to 1:10. The same Esc menu entry, on the demo data unless opener data is on, and then on the folder names and counts the terminal just showed: the fall reads nothing new from your machine. Stills in [Screenshots](#screenshots).

- **0:35 to 0:50, the shrink-away.** The PRD's beats:
  - a fresh prompt, and for 3 seconds the terminal ignores whatever you type at it;
  - "you're in now." types itself at your prompt;
  - then the terminal's window shrinks away, as a camera pulling back from it: it was a screen on the face of a monolith, one lit panel on a wall of dark ones under a huge `~/`, in a dark the size of a city. The camera pulls back across a shaft, rises, and tips over its edge to look down: rings of light stepping down and in, a red glow at the bottom.
  - It is a camera move, not a fade. The terminal is drawn into a picture of its own and shown on that screen, and the camera's first frame is the terminal exactly as it was: the capture tool compares the two frames (every other pixel) and finds a mean difference of 0.00 of 255, none off by more than 8.
- **0:50 to 1:10, the fall.** You drop down the shaft as a body does, quicker and quicker, to about 37 m/s, turning slowly round it as you look across at the towers going past, then down at the pit as it nears; you slow and land on its rim, facing it. Speed lines streak up past you and code light pours down the shaft. You may look about a little with the mouse; you never steer.
- **Your directory tree as a city.** `TreeLayout` (`scripts/opener/tree_layout.gd`) builds it from the folder names and entry counts alone, the same city every time for the same names:
  - the home folder is the monolith, `~/` on it;
  - each level of the tree is a round terrace, stepping down and in;
  - each top-level folder is a tower on the top terrace, in a slice of the circle as wide as what it holds; the folders in it stand on the next terrace down, in that slice, hung from its rim by cables of light;
  - entries set a tower's width, height and how many of its windows are lit (the reader's 200 a folder is as big as it gets); a folder that was not counted stands dim, a hidden one short and dim in the back row;
  - each tower carries its folder's name, in the terminal's font;
  - the first `node_modules` is the pit at the bottom: a maze lit from below, deeper than the fog lets you see, its name over it; any other `node_modules` is a maze tower;
  - towers with no name fill the rows behind and megastructures the dark beyond, and a ceiling of circuit traces closes over it all: you are inside the machine.
- **The hottest process.** The PRD has "their top CPU process, named" pulsing red at the bottom. Nothing reads processes yet (C39's reader reads none, and C40 added no reads), so the name beating in the pit's mouth is the demo's invented one, `node`, with opener data on or off.
- **Your theme.** The machine is drawn in the opener's palette: the accent on its edges and rims, blue and cyan windows, green code light, magenta mazes, red heat. A light theme's machine is as dark as any, its colours lifted until they read on the dark.
- **Bounded.** At most 96 towers (the shallow folders first), 40 names, 1024 boxes, 96 cables and 28 streams of code light, from the first 512 folders handed over, and at most 64 nodes in the whole machine whatever the data (every box in one MultiMesh). On the development machine's GPU, which other programs were using too, the machine took 0.78 ms of GPU time a frame on average from the reveal to the landing (12.3 at worst) at 1920x1080 with 4x MSAA, the window's own drawing 0.07 ms.
- **Always a way out.** Esc leaves mid-reveal and mid-fall as it does everywhere else, and the window's close is never held. The machine and its city are let go as the opener ends, however it ends.
- **Flash-safe.** The screen dims smoothly as the terminal shrinks, the hot process swells less than once a second, and the end fades.
- **Sound.** All made in code: a rush as the terminal shrinks away, the fall's wind rising and falling with its speed, the landing, and the hot process's beat as you near it. Under it, the score's dark synths (C42).
- **The hand-off.** At 1:09.6 the camera has landed on the pit's rim and the machine goes on drawing: C41's "Linking your agent..." starts there (below).

The test, `tests/opener_fall_test.gd` (check step 50), uses invented names and fake homes only, and covers:
- the code: the opener builds its city from the values it already took (the folders, their counts and the process name) and nothing more; the city and the machine read no file, environment or clock and print nothing, and no opener script prints;
- the city: the same for the same names, the levels, slices and cables, entries setting sizes, hidden and uncounted folders, the pit, names cleaned and cut in cells, partial and missing data;
- the caps, on a 750-folder tree and on 100,000 folders handed over at once;
- the camera: its first frame filling the view exactly as the terminal did, its whole way smooth and never through a tower, a terrace's edge, a stream, a cable or the ceiling, the landing facing the pit, the beat under once a second, the look clamped;
- in the opener: a source's own names making the city, C39's reader on fake homes (one empty, one of three folders), a source with nothing in it still playing every beat, the machine freed as it ends.

Step 48 (`tests/opener_test.gd`) now also holds the C40 beats inside 0:35 to 0:50 and 0:50 to 1:10, the 3 seconds, the words, and Esc while the terminal ignores you, mid-reveal, mid-fall and landed.

#### Built: your AI's link and the copy of you (C41)

The opener goes on from the pit's rim to 1:35. The same Esc menu entry. Stills in [Screenshots](#screenshots).

- **1:10, "Linking your agent..."** (the PRD's words) types itself in a panel at the bottom, and the guide HUD comes alive for the first time: the "your AI" badge draws itself in at the top right with its signal bars climbing, while lines of teal signal race up out of the pit and up the shaft, with a beam up its middle from the hot core.
- **Your real AI answers.** It was asked one thing, as the fall began: that the game is starting. Its answer locks in no sooner than 1:13.6. The lines flare, rings of teal run out across the floor past you, the badge goes "live" with the call's real latency, and your AI's line types itself in the panel with a small **live** mark.
  - **What it gets, all of it:** the guide's fixed preamble, "Game stats: none", and SIGKILL's own text asking it to reply with one of five fixed lines. Nothing of the opener's data: no user or host name, no folder, no time, no number.
  - **What you see:** SIGKILL's own copy of the line it picked, never its own words, so nothing it says can put a name or a machine on your screen (the same rule as the boot handshake).
  - **It goes through the same guide as everywhere else:** your Omarchy default agent's own CLI with its tools off, never `omarchy-agent`, only with your yes for that agent, under the session's pace and cap. A local model server is never asked to load a model.
- **When there is no live answer** (the AI is off, there's no agent, the session's cap is reached, an error, a local model not loaded, or no answer by 1:17), the scripted guide speaks instead and the badge says why. The opener never waits: every beat after comes at the same moment either way, and a call still running at 1:17 is stopped.
- **The scripted guide**, as the copy comes: "I've been stuck in here with them. They look like you." (the PRD's words).
- **The copy of you.** It walks up out of the pit toward you on a stair of red hexagons that light under its feet as they land. It forms out of cells as it climbs over the rim, and the floor answers with rings of red. It crosses the floor, printing a hexagon at each step, and stops a few metres in front of you on its last step.
  - **Its build:** a tall, broad figure in A5's solid dark armour, lit crimson only in its seams and its heart, its armour's rim in your own teal.
  - **Its head is the nixfred hexagon,** dark, with the prompt lit red on it, mirrored: `_<`, the cursor blinking. Behind it the brand's ring of six bars turns slowly, lit red.
  - **It stares at you as it walks.** Standing, it mirrors where you look, as a reflection would, and tilts its head.
  - **Its tag is your user name:** the demo's `user`, or your own with opener data on. It's the same name the terminal typed, cleaned the same way. It is never sent anywhere, and it is dropped as the opener ends. The story calls it `~` from mission 1 on (docs/STORY.md).
- **The pit's own names fade** as the copy takes their place.
- **Sound, all made in code:** a carrier finding its line as the signal climbs, a lock as the answer lands, a low drone as the copy rises, and its heavy steps; under it, the score (C42).
- **The hand-off.** At 1:34.4 the copy stands in front of you and the machine goes on drawing: C42's `kill -9` starts there (below).

The test, `tests/opener_link_test.gd` (check step 52, 40 checks), uses invented names, a guide link on a fake detector and stub adapters only (the real Claude Code adapter runs only the stub CLI in `tests/fixtures/ai/guide`). It covers:
- the agent run with exactly the tools-off flags, never `omarchy-agent`;
- the whole prompt, the preamble plus `LINK_TEXT` with no stats, and none of the data's values in it;
- every fallback;
- a live and a hung agent playing every beat at the same moments;
- the copy wearing the data's user name (compared, never printed), cleaned, and dropped at the end;
- its feet never sliding (0.0000 m), and it stopping 4.2 m in front on a whole step;
- Esc mid-link and mid-copy;
- demo data calling nothing;
- the link, the beat, the copy and the HUD reading nothing of the machine.

Deliberately broken copies (stats in the request, no 1:17 fallback, the host on the tag) each fail by a named check. Steps 48 and 50 hold the earlier beats on the longer run.

#### Built: the forge, the first kill and the title (C42)

The opener's last 25 seconds, from 1:35 to the end by 2:00, the music under the whole second half, and the way in on a first launch. Stills in [Screenshots](#screenshots).

- **The forge.** The guide's panel shuts and `kill -9` types itself in the air between you and the copy, a letter on each eighth note of the score, in your teal. Each letter is a block of glowing cells. The letters charge and break apart, and the cells stream into your hands. There the SIGKILL rail rifle (the game's own model of it) prints itself from its back to its muzzle, a white-hot band of hex cells running down the barrel. Its four coils light on the last four sixteenths, and on the drop it kicks into your hands as the guitars come in.
- **"you won't."** The copy squares up, stops mirroring you and stares. Its line types itself in crimson in the air by its head (the story bible's words), its face's cursor racing.
- **The first kill.** Then the rifle is yours: a reticle, and "[left mouse]  kill -9" (whatever fire is bound to). Fire, and the shot lands on the next sixteenth of the beat. Don't, and it fires itself after a few seconds, so the opener never waits on you. A beam of the rail's light hits the copy's heart; it flares, shudders, and on the beat it bursts, its own armour flung apart in a storm of crimson and teal voxels.
- **Then, on the beat:**
  - the kill feed, in the game's own words over two lines: "SIGKILL sent by `<user>`" / "to `<user>`" (your user name only, never your host);
  - the whisper, "one of 6666", breathed and shown;
  - black and silence;
  - the title. The nixfred hexagon slams in out of the dark on the downbeat, and it is the brand's own icon file, the white `>_` on the hexagon, never redrawn. "SIGKILL" is hammered in under it a letter at a time. The title punches on every beat of the riff and tears on the snare, over the machine's grid racing toward you, and is torn away at the end.
- **Where it leaves you.** Played from the Esc menu, back at the menu. On a first launch, straight into the arena.
- **The music**, original and made by the game in code as the opener starts (no sample, loop or recording of anyone's), 150 bpm in E minor:
  - a dark synth bed with glitching arpeggios from the shrink-away, through the fall, the link and the copy's walk;
  - heavy metal from the forge: down-tuned guitars chugging, double kick, the drop's riff;
  - a two-bar loop while the copy waits for your shot;
  - then the shot's crack, the derezz, the whisper, and the title's riff.

  It plays on the Music bus, so the Music and Master volumes rule it, and every part peaks under full scale.
- **Skipping, at any moment.** Esc pauses the intro in its own small menu: Resume intro, Skip intro (focused, so Esc then Enter skips), and "Skip the intro next time". Holding Space for a second skips too (one key, no Ctrl or Alt), and pressing any key shows how. The window's close button always works.
- **The first launch.** The first time the arena loads, a card over the paused arena gives a one-line content note and asks whether the intro may show your real user name and folder names, and says what else that covers (host name, uptime, theme colours, recent file times), read-only and never saved, logged or sent.
  - **No is highlighted:** N, Enter or Esc answer no, and opener data stays off. Y turns it on.
  - **Then the intro plays itself, once.** Watched to the end or skipped, it never auto-plays again. If you close the window part way, it plays again at the next launch, unless you ticked "Skip the intro next time".
  - **Where the answer lives:** the settings file's own `[intro]` section. Your unlocks' save is never touched.
- **Replays keep your AI's calls.** Once your AI has answered live in a session, replaying the opener shows that answer again ("live  earlier") and calls nothing.
- **The daemons have voices.** rogue.d chitters as it rears and slashes with a blade's ring; the zombie groans as its cannon charges, booms, and crumbles as it dies; the runaway's swarm buzzes, dives and bursts in a cascade of falling blips; ICE rings like glass and shatters, the hunter chirping as it locks on. Each type has a tell, a strike, a hit and a death, all made in code, from where it stands, on the Effects bus.

The test, `tests/opener_end_test.gd` (check step 53), uses invented names, settings files in its own folder and a stub agent only. It covers:
- the forge on the score's grid, the rifle printing and forged on the drop;
- the copy's line, word for word;
- a press too early doing nothing, the shot on the next sixteenth, and the shot firing itself when no one presses;
- the derezz, the kill feed with the user name and never the host, the whisper, the black and the title, the end by 2:00;
- the flash cap through the shot and the slam;
- the score's parts, lengths, levels and sameness, on the Music bus, each on its moment;
- the daemons' voices on the Effects bus, the volume sliders muting both;
- skipping from all 13 beats both ways;
- the first launch (No by default, yes and no, once only, a cut-short first play, "Skip the intro next time" across a restart, a match waiting);
- an old C33 save still loading;
- a kept AI answer reused with no call.

## The arsenal

Every weapon is a Unix signal or shell command made physical, and each one has its own Tron light skins and a mod, unlocked by playing (C33, [below](#built-unlocks-mods-and-light-skins-c33)). They are fiction: no weapon runs, signals or touches anything real on your machine.

Each one you hold is its own model in first person (A1): dark gunmetal and polymer under neon trim in the weapon's own colour, built in code from simple shapes, with its barrel's tip where its beams and muzzle flash start. They are in [Screenshots](#screenshots).

| Weapon | What it does | Status |
|---|---|---|
| Terminal cannon | The default hitscan rifle. Neon muzzle flash with a light, camera recoil with smooth recovery, a hit marker on confirmed hits, sparks off the surface you hit, synthesised zap and hit sounds. Slot 1, infinite ammo | ✅ Built (C6), weapon #1 of the framework (C16) |
| SIGTERM | Polite shotgun: nine violet pellets in a cone, a slow pump, six shells and 24 in reserve, damage that falls off with distance. "SIGTERM: please exit." Slot 2 | ✅ Built (C16) |
| SIGKILL / `kill -9` | Uncatchable rail rifle that one-shots and derezzes. The ult: fill its meter with the other weapons (about three kills), press 3, fire; it charges for a moment, then one ice-white rail pierces every target on the line up to the first wall. "kill -9" headshot callout. Slot 3 | ✅ Built (C17) |
| Fork bomb | Grenade that splits 1, 2, 4, 8: fifteen short neon blasts, each smaller and brighter than the last generation's. Two bombs, back at every round and every life. Press 4 and fire to throw it on an arc, or G to throw one without drawing it. The blast never hurts the thrower, and walls stop it. Slot 4 | ✅ Built (C19) |
| `sudo` | Power-up that overcharges the current weapon, tied into Root vs user: 3 kills in one life earn a charge, Z spends it on 8 s of root, the weapon in hand (whichever) hitting 1.5 times as hard and spending no ammo | ✅ Built (C22) |
| `fork()` | Shotgun whose pellets split in two mid-flight: six yellow pellets in a flat fan fly as fast projectiles with thin glowing trails, and 4 m out each forks in a small flash into two children 10 degrees apart, each worth 0.6 of its parent. Tight and hard up close, a wider, weaker cloud at range. Four shells, a slow pump, E to reload. Slot 5. With `sudo`'s root the children fork once more: 6, 12, 24 | ✅ Built (C24) |
| `grep` | Seeker smart gun that locks onto a marked target: hold aim to build a lock on the target in its narrow cone, three marks at once (five as root, whose locks build twice as fast), each shown with a cobalt bracket and a "match" tag; a shot sends one fast cobalt dart per mark that turns toward it at a limited rate, or one straight with none. 18 a dart, six in the magazine, E to reload. Slot 6 | ✅ Built (C25) |
| `rm -rf` | Slow, devastating cannon with friendly-fire risk: fire winds it up for 0.6 s ("rm: remove? [y]" types out on the strip, the shooter at half pace), then one heavy ember slug crawls out at 9 m/s and blasts where it stops, 140 at the centre easing to 8 at 6 m, cover stopping it. It hurts its shooter too, at half. One round, E to reload. Slot 7 | ✅ Built (C26) |
| `cron` | Timed mines: fire sticks a rose hex stud on the floor or wall you aim at (or at your feet), a scheduled job. Armed after 1 s, it pulses a blast every 2 s, three runs ("*/2s x3" counting down over it), each telegraphed by a closing ring and a brighten, then fades. It never hurts you; three jobs to a crontab, a fourth removes the oldest; anyone else can shoot one off. Slot 8 | ✅ Built (C27) |
| `ping` | Sonar pulse that reveals hidden daemons: fire sends one lime ring out from you, 18 m in half a second, through walls. Every daemon it meets is outlined through the level for 4 s with a tag (its name and how far), on your screen only, and one it catches in the middle of a tell drops that attack and staggers. No damage, no ammo: a 7 s cooldown. Slot 9 | ✅ Built (C28) |
| `chmod 000` | Freeze ray: hold fire and a cold frost-opal beam strips what it touches of its permissions, its freeze meter filling (a daemon in 1 s of beam); full, it freezes solid for 3 s under a crust of frost, "PERMISSION DENIED", doing nothing at all (a tell it was in is called off). The next hit on it frozen lands twice as hard; a hit of 40 or more shatters it whatever its health, and any kill of it frozen is a shatter. The hunter and the nodes freeze too, walls ignore it, Black ICE is only slowed (up to 40%). No damage, no magazine: a 4 s coolant tank that refills on its own and vents when run dry. Players in a match: slowed, then frozen for 1 s. Slot 10, bank 2: Shift+1 | ✅ Built (C29) |
| `pipe \|` | Chain beam: one click and a stream of brass light hits the first target your aim meets (26), then arcs on to the nearest target within 12 m that it can see, and on from that one, up to five links (six as root), each 70% of the one before (26, 18, 13, 9, 6), written out under your crosshair as the pipeline it was, "$ rogue.d \| zombie \| runaway". Walls break a chain. A daemon chmod 000 froze conducts it: the stream passes through it whole and reaches 1.5 times as far, and the frozen link shatters. The hunter and the nodes are links; a wall of ICE hit first ends the chain; Black ICE is never hurt or chained ("pipe: broken pipe"). Ammo is a 64K pipe buffer: each chain writes 8K, it drains on its own, and full it blocks until half drained. In a match the host judges every link, players' too. Slot 11, bank 2: Shift+2 | ✅ Built (C30) |
| `/dev/null` | Black-hole grenade: throw the device (it arcs like the fork bomb) and where it lands a singularity opens over the floor, or in the air after a 1.6 s fuse. For four seconds it drags everything within 9 m that it can see toward its core and round it, harder the nearer (1 m/s at its edge to 7.5 at the core), stretching what it holds toward it; inside its 3 m horizon it hurts (8 to 40 a second), and whatever reaches the core is discarded, "> /dev/null". Then it implodes: 45 at the core to 10 at 5 m. A daemon caught mid-tell drops it; the knot it draws together is ready for `pipe \|` or the fork bomb; a frozen daemon is pulled whole and shatters at the core; cron mines are drawn in and set off there. The hunter is pulled and hurt, the nodes held in place and hurt, walls of ICE only flicker, Black ICE is never touched ("/dev/null: device busy"). Two charges, one back every 16 s; one hole open at a time; never its thrower. In a match the host judges every pull and every hurt, players dragged on their own screens (never faster than a run). Slot 12, bank 2: Shift+3 | ✅ Built (C31) |
| SIGHUP | Confusion grenade: throw the device (a telephone handset, on the fork bomb's arc) and where it lands, or in the air after a 1.2 s fuse, it goes off in a hangup: a carrier wave runs out to 7 m in half a second, and everything it reaches in sight is caught as the front passes. A daemon caught calls off its tell, drops its target, stalls 1.2 s "reloading config", then wanders confused for 4 s (no idea where you are, a "?" over it), and lashes at a daemon within 3.5 m with its own attack, 75% of its damage, twice at most. No damage of its own: its value is control. Then 6 s guarded, so no daemon is kept confused for ever. `/dev/null` drags the confused harder; a frozen daemon starts confused when it thaws; `ping` outlines the confused in green. The hunter forgets what it learned and wanders, the nodes drop their fields for 5 s, walls are untouched, Black ICE ignores it ("SIGHUP: ignored (nohup)"). Two charges, one back every 12 s. In a match the host judges; a player caught gets 2.5 s of glitch on their own screen, never a control taken. Slot 13, bank 2: Shift+4 | ✅ Built (C32) |

Built: the terminal cannon, SIGTERM, the SIGKILL rail rifle, the fork bomb, the `fork()` shotgun, the `grep` seeker, the `rm -rf` cannon, `cron` mines, `ping`, `chmod 000`, `pipe |`, `/dev/null` and SIGHUP. Keys 1 to 9 draw bank 1; with Shift held they draw bank 2, weapons 10 to 18 (C29): Shift+1 `chmod 000`, Shift+2 `pipe |` (C30), Shift+3 `/dev/null` (C31), Shift+4 SIGHUP (C32). Every other weapon is Planned, each with its chunk, and plugs into the same framework.

**Abilities and modes**

| Ability or mode | What it does | Status |
|---|---|---|
| Derezz deaths | Daemons shatter into glowing voxels that burst, tumble, land and fade. Built on the target dummies, which then respawn at full health. Players derezz too, with the kill feed "SIGKILL sent by &lt;player&gt;", in synced combat (C14); the feed names the weapon's own signal (C16) | ✅ Built on dummies (C7) and players, with the kill feed (C14) |
| SIGSTOP bullet time | Short meter of Matrix slow-mo; SIGCONT resumes. Press F to start it (the meter needs a quarter), F again for SIGCONT; it also ends when the meter runs out. Alone, the world runs at 0.3x and you at 0.9x; in a match only your own screen gets the look, and your shots go steady (no spread, no recoil) while the host says it is on | ✅ Built (C18) |
| Light-trail mode | Your path leaves a solid neon wall, for Tron deathmatch: a segment every half metre on the ground, 1.2 m tall in your own colour, standing six seconds. Touch any wall, your own older one too, and you derezz; the kill goes to its owner. A match rule: the host turns it on in Settings, Multiplayer, "light trails", or with `--light-trails`; joiners play by the host's | ✅ Built (C20) |
| Code-rain vision | See enemies through walls as glyphs; drains fast. Hold V: every enemy body within 40 m shows as a silhouette of the walls' own green glyphs, through any wall, and your screen dims toward green. Its own meter lasts 3 s of use, needs a quarter to start and refills in 12 s after a second of rest; let go, run dry, die or respawn and it is off. On your screen only: nothing is sent | ✅ Built (C21) |
| Root vs user | Spawn as user, earn sudo for a power spike. Every life starts as `user$`; 3 kills in that life earn one sudo charge (one held at most; a death drops it); Z shows a cosmetic `[sudo] password for user: ********` and then `root#` for 8 s, in red. Host-owned in a match | ✅ Built (C22) |
| Spectate as top | Dead players watch a live process-table style view of the match. Derezzed in a match, a full-width `top` of it is up until you respawn; hold Tab for it any time, alone too (you and the dummies as daemons). PID, USER, S, %CPU, RES, TIME+, K, D and COMMAND, sorted by kills, refreshed once a second, every number the host's in a match | ✅ Built (C23) |

**How weapons are built.** Each weapon is one `WeaponDef` resource (`scripts/weapons/weapon_def.gd`), one `.tres` per weapon, holding every number of it once: who it is, how it fires, its ammo, its falloff, its light skin and its whole feel. The loadout is `resources/arsenal.tres`. Its skin and mod slots (empty until C33) name the weapon's kit beside it, `resources/<id>_kit.tres`: its skins, its mod's numbers and what earns each.

### Built: weapon framework and SIGTERM (C16)

The single terminal cannon became an arsenal that the rest of the weapons plug into, and SIGTERM is the first new one. Weapons are fiction: nothing is run, signalled or touched.

- **One resource per weapon.** `WeaponDef` extends the cannon's old `WeaponTuning`, so every value of a weapon, its feel included, lives once in its own file: an id, a name, a fiction line (the signal or command it stands for), the signal the kill feed names, the fire mode (hitscan single and hitscan pellets are built; projectile and beam are reserved and refused until a weapon needs them), damage, the fire interval, magazine and reserve (or no limit), reload time, spread and pellet count, range and distance falloff, a light skin (a colour pair named in `scripts/palette.gd`), a reload sound, and empty mod and skin slots. `problems()` checks all of it; a weapon that fails is refused, and a loadout with nothing usable left holds the built-in cannon.
- **The terminal cannon is weapon #1.** `resources/terminal_cannon.tres`, at the same path, with the same feel: damage 25, a 0.16 s interval, 120 m, no magazine (infinite ammo), no falloff, teal. Every earlier test passes; the cannon test did not change at all.
- **SIGTERM, the polite shotgun.** `resources/sigterm.tres`: nine pellets in a 6 degree cone, the first straight down the aim; 14 damage a pellet up to 4 m, easing down to a fifth of that at 24 m; a 0.9 s pump; six in the magazine, 24 in reserve, a 2.2 s reload; a violet light skin; its own synthesised boom and a reload clack; a placeholder viewmodel. Point blank (1.5 m) every pellet lands: 126, which derezzes a dummy and takes all of a player's 100. At 12 m one shot is at most 85.7 and in the test it took three. At 30 m a shot does at most 25.2, and in the test 2.8.
- **What the player holds.** `scripts/weapons/inventory.gd`: the cannon in slot 1 and SIGTERM in slot 2 (`resources/arsenal.tres`). 1 to 9 pick a slot, the wheel cycles, Q swaps back to the last weapon, E reloads (R was taken: it respawns the arena's targets). Drawing a weapon takes 0.3 s and no shot goes off during it, nor during a reload; drawing another weapon stops a reload; fire on an empty magazine starts one; each weapon's interval runs on while another is drawn; a new life refills everything.
- **The weapon strip.** Bottom right, above the hint line: every slot with its key and the drawn one in brackets (since C17, only the drawn one with its name), the drawn weapon's magazine and reserve ("inf" for the cannon), a reload bar while it reloads, the fiction line for a moment after a draw, and "empty" or "out of ammo" when it is. The kill feed sits above it. No radial menu yet.
- **In a match the host decides.** A shot's intent now names the weapon: its number, life, weapon id, origin and aim, nothing about pellets. The host checks that the weapon is the one in the player's hand, that its draw is done, that no reload is running, its fire interval and the magazine; then it draws SIGTERM's pellets itself from the aim with its own generator, casts each one, eases each by its own distance and applies the sum once per player struck. The player also tells the host when it draws a weapon and when it starts a reload (a life number and a weapon id, nothing more), and the host keeps the same rules as the player's own inventory: the weapon in hand, ready after the swap time, a reload refused where the game refuses it (one that arrives during a late draw starts when the draw is done), its rounds in only when its time is up, a draw stopping it, all less the C14 jitter tolerance. After each of those messages and each shot, the host answers with its count of your magazines and how many of your messages it has handled; your game takes that count once the host has caught up with everything you sent, so a late message on the wire cannot leave the two apart, and if the host's reload or draw has longer to go than yours, your next shot waits for it. A weapon not in hand, fire mid-draw, mid-reload, too fast or from an empty magazine is dropped and counted like C14's forgeries; no magazine refills behind the host's back. A match starts with slot 1 drawn and every weapon full on both sides, whatever was fired before, and a respawn hands back the weapon the host counts in your hand. Your own tracers are a guess drawn at once; hits, damage, deaths and the feed come from the host. An R reload mid-match keeps your weapons and ammo, and a respawn that lands while the arena is reloading still refills them.
- **The kill feed names the weapon.** "SIGTERM sent by Daemon-2" / "to Daemon-1"; the cannon keeps "SIGKILL sent by".
- **Tuning.** Each weapon's numbers are in its `.tres`; the loadout, the swap time (0.3 s), the draw dip, the reload tilt and how long the fiction line shows are in ArsenalTuning, `scripts/weapons/arsenal_tuning.gd` with `resources/arsenal.tres`.
- **Seen in stills only.** A1's demo-data stills show SIGTERM held and firing, and the strip, drawn by a real GPU; no one has played it in a window, and no two machines have fired it at each other. The sounds wait for a windowed playtest.
- **Known limit.** As with C14's fire rate, the host times a draw from when it arrives: a shot that a late draw bunches up with on the wire can be dropped once, and the next one counts.

The test, `tests/weapon_test.gd`, covers the definitions, the loadout, the inventory and the host's rules on their own, the pellets, the real arena with real key and wheel input, and a host and a joiner over 127.0.0.1.

### Built: the SIGKILL rail rifle (C17)

`kill -9`: the signal no process can catch, made into the ult. Fiction only: nothing real is signalled.

- **How to use it.** Play with the cannon and SIGTERM: the meter beside your ammo fills. Press 3 (or wheel or Q to it; slot 3 shows dim until the meter is full), then fire. The rail charges for 0.35 s with a growing glow, then fires once along your aim. The meter empties; fill it again.
- **The meter.** One meter, kept across swaps, emptied by the one shot, by a death and by a new round. It fills by the numbers in `resources/sigkill_rail.tres`: 0.8 for each whole target's worth of health your other weapons take (a quarter of a player's health is 0.2) and 0.2 for each kill, out of 3.0. So one kill is exactly a third and about three kills fill it, whether the targets are dummies (1 health) or players (100). The rail's own kills add nothing.
- **The shot.** 1000 damage, more than any target has, out to 120 m, piercing: it passes through every dummy and player on its line and stops at the first wall. A bright ice-white beam lingers and fades over 0.6 s, and every target it kills derezzes into voxels.
- **"kill -9".** A rail kill whose hit was in the head zone (the top 0.35 m of a body) is called out "kill -9", in-round game logic like every callout, never the AI, shown over whatever callout was up.
- **In a match the host decides.** A rail shot is the ordinary C16 intent naming the rail. The host owns every player's meter, fills it from the damage it applies, believes a rail shot only with the meter full (a forged or early one is dropped and counted as "meter"), traces the pierce itself and applies the damage. Spawn protection is full invulnerability and the rail respects it: fairness first. Your own meter follows the host's from the shot and death results you already receive, so the rail added nothing to the wire (C18's SIGSTOP later did: protocol 4).
- **The kill feed.** A rail kill reads "SIGKILL &lt;pid&gt; sent by &lt;player&gt;", the pid the game's own fake id for the victim's slot and life, worked out the same way on every machine. It is never a real process id: nothing reads one.
- **The strip.** With three slots and more to come, every slot shows its key and only the drawn one its name ("1 [2 SIGTERM] 3": one space between slots since C24, so five fit where four did, since C25 the slot line is smaller than the ammo line, a point then, the small lines' size since C26 and a point under that since C27, so eight fit beside the guide panel at 960x540; a ninth weapon will need two rows); the third line shows the meter when nothing else is there.
- **Seen in stills only.** A1's stills show the charge lighting the coils, the beam and the callout, drawn by a real GPU; no one has played it in a window, and no two machines have fired it at each other.

The test, `tests/rail_test.gd`, covers the resource, the inventory, solo play in the real arena and a host and a joiner over 127.0.0.1.

### Built: the fork bomb (C19)

`:(){ :|:& };:`, the shell's fork bomb, made into a grenade. Fiction only: nothing forks, runs or touches anything real.

- **How to use it.** Press 4 (or the wheel, or Q) and fire to throw one on an arc, or press G to throw one without putting the weapon in hand down. You carry two; the strip shows them on slot 4 ("4(2)"), and a new round or a new life gives them back. G can be rebound in Settings, Controls, where it reads "Fork bomb".
- **The chain.** The thrown bomb goes off after 1.2 s, or at once on hitting a player or a daemon. Each blast of the first three generations throws two children out and up with a little random spread, each on a 0.5 s fuse, and the last generation only goes off: 1, 2, 4, 8, fifteen blasts in all, never more. Each blast is a short neon ring in the fork bomb's own magenta, smaller and brighter each generation, and the first one of each throw is called out ":(){ :|:& };:".
- **The damage.** Each blast does up to 22 within 4 m, easing to 30% of that at the edge, so one blast never kills from 100 but a full chain beside a target in the open does. Walls stop it (a blast needs a clear line to the target), and the thrower is never hurt by its own bombs. The kill feed names it: "fork bomb sent by Daemon-2".
- **Cheap on the frame.** One node per throw, no physics bodies: at most 8 bomblets in flight, each moved with one ray a frame. A player has 16 live at most, every chain together (two full chains), and every node is gone when the chain is.
- **In a match the host owns the chain.** A throw goes to the host as its own request: the host checks it against its view of the thrower's eye and aim, the bombs it counts, the throw interval, the live cap and the cover the thrower stands against, then runs the whole chain itself and judges every blast. It sends each other player one seed per throw, from which their screens draw the same scatter, and every blast as it happens; their chains go off only on the host's word and never judge anything. Forged or empty throws are dropped and counted. The wire became protocol 5 with it (6 since C20).
- **All numbers in one place.** The chain's are in `resources/fork_bomb.tres` (a ForkBombTuning); the weapon itself, its two bombs and its 0.6 s throw interval are `resources/fork_bomb_weapon.tres`.
- **Seen in stills only.** A1's stills show the canister held and a bomb leaving; no window has shown the rings or the callout.

The test, `tests/fork_bomb_test.gd`, covers the resources, the scatter, the rebind, solo play in the real arena and a host and a joiner over 127.0.0.1.

### Built: the fork() shotgun (C24)

A shotgun whose pellets split in two mid-flight. Fiction only: nothing calls a real `fork()`, runs a command or reads anything about your machine.

- **The shot.** Press 5, or reach it with the wheel or Q like the others. Each shot fires six pellets in a flat fan, 5 degrees each side, that fly as fast projectiles (90 m/s) with thin glowing trails in its own yellow, not instant rays, so the split is real and you can see it.
- **The fork.** 4 m out, each pellet forks in a small flash into two children 10 degrees apart, in the plane of the fan, flying on at the same speed: 6 pellets become 12. A pellet that hits something before its fork does its full 12 and never forks; each child does 0.6 of its parent (7.2). Point-blank, all six land for 72; at range the cloud is wider and weaker. Pellets stop at walls and bodies and vanish at 30 m.
- **Like the other shotguns, slower than SIGTERM.** A 1.2 s pump, four shells and 16 in reserve, a 2.6 s reload on E. The kill feed says "fork() sent by ...", and a shot's first fork is the "fork()" callout at the usual pace.
- **With sudo's overcharge** (C22's root): the children fork once more, 4 m later: 6, 12, 24. Root's general rules hold as for every weapon (1.5 times the damage, no ammo spent).
- **In a match the host owns it.** Your shot is the usual intent; the host checks it like any shot, draws its seed with its own generator and runs the pellets in its own world, judging every hit and telling everyone the damage and any kill in the usual shot and death messages. Every screen, yours too, draws the same pellets from that seed: the fan comes from the aim and the seed alone, every fork from its parent. The seed travels in the fork bomb's seed message, so there is no new message: the protocol stayed 8 (9 since C25's grep marks). Your game never decides damage to a player.
- **All numbers in one place.** `resources/fork_shotgun.tres`, a WeaponDef with a new Fork group: pellet count, spread, speed, fork distance and angle, the child share, the generations as user and as root, the range, the pump, the magazine, the reload, and the look.
- **Seen in stills only.** A1's stills show a shot leaving the prongs; no window has shown the forks' flashes yet.

The test, `tests/fork_shotgun_test.gd`, covers the resource, the fan and the fork alone, volleys in an empty world and against a wall, the real arena with real dummies, and a host and a joiner over 127.0.0.1.

### Built: the grep seeker (C25)

A smart gun that marks its targets, then sends a dart after each. Fiction only: nothing runs a real `grep`, searches anything or reads anything about your machine.

- **Marking.** Press 6 (or the wheel, or Q). Hold aim (right mouse, or toggle it in Settings): the target nearest your crosshair inside a narrow 6 degree cone, within 35 m and with nothing of the level in between, builds a lock over 0.5 s. A cobalt bracket closes round it as the lock builds; when it is done the target is marked, its bracket closed with a small "match" tag over it, and the round calls out "grep" (at the usual pace). Move the crosshair to the next one and mark it too: three at once. Under the crosshair, "grep -c: N" counts your marks. Alone the targets are the arena's daemons; in a match, the other players.
- **Keeping a mark.** A mark stays while its target is in sight (within 40 degrees of your crosshair, nothing of the level in between) and within 35 m, or out of either for no longer than 0.75 s. It drops at once when the target derezzes, and every mark drops when you put grep away, die or respawn.
- **Firing.** Each shot spends every mark and fires one dart per mark, fanned a little at the muzzle, or one dart straight along your aim with none. Darts fly at 40 m/s with thin glowing cobalt trails and turn toward their mark at most 220 degrees a second, so a target that breaks hard or ducks behind cover can make one miss. They stop at walls and at the first body they meet, and vanish at 45 m. 18 a dart: under the cannon's 25 a hit, better at tracking. A 0.7 s interval, six in the magazine and 24 in reserve, a 2 s reload on E. The kill feed says "grep sent by ...".
- **With sudo's overcharge** (C22's root): locks build twice as fast and five marks may be held. Root's general rules hold as for every weapon (1.5 times the damage, no ammo spent). When root ends, any marks past three drop, newest first.
- **In a match the host decides.** Your shot is the usual intent, and it carries your claims: the player ids of your marks. The host believes the shot as any other, then checks each claim itself: a living player other than you, within the lock range (plus 1.5 m) of your shot's origin, within the sight cone (plus 4 degrees) of your aim, with nothing of the level between, no more claims than your marks allow. It drops and counts the rest. Then it runs the darts in its own world from your origin, your aim, a seed of its own and the marks it believed, judges every hit (root included) and tells everyone the damage in the usual shot and death messages. Every screen draws the same darts from the seed and the believed marks, which ride in the seed message. A forged claim (behind you, through a wall, out of range, a player who is not there, yourself) gets no homing dart. Your game never decides damage to a player.
- **Protocol 9.** No new message, but two existing ones gained a field (the shot intent its claims, the seed message the believed marks), so a game still on protocol 8 is refused with the usual version line.
- **All numbers in one place.** `resources/grep_seeker.tres`, a WeaponDef with a new Seek group: the lock cone, range, time and grace, the sight cone, the marks as user and as root, root's lock speed, the host's two tolerances, the dart's speed, turn rate and look, and the bracket sizes; the range, damage, interval, magazine, reserve and reload are the usual ones.
- **Seen in stills only.** A1's stills show `grep` held and a straight dart leaving; no window has shown the brackets yet.

The test, `tests/grep_seeker_test.gd`, covers the resource, the darts' first directions alone, darts in an empty world and against a wall, the lock, the marks and the darts in the real arena with real dummies, six slots at 960x540, and a host and a joiner over 127.0.0.1.

### Built: the rm -rf cannon (C26)

A slow, devastating cannon that can take you with it. Fiction only, a hard rule: "rm -rf" is a name and a line of HUD text. Nothing removes, runs or touches a file, a process or anything on your machine, and the test greps the weapon's code to prove it.

- **The wind-up.** Press 7 (or the wheel, or Q). Fire starts a 0.6 s wind-up, the "are you sure" beat: the strip's third line types out "rm: remove? [y]" as it fills, and the shot leaves when it is done, whether or not you are still holding fire. Putting the cannon away, dying or respawning during it cancels the shot and spends nothing. Through the wind-up and for 0.8 s after the shot you move at half your pace and cannot start a slide.
- **The slug.** One heavy glowing ember slug with a thick trail, flying straight at 9 m/s, slower than any other projectile in the game, so it can be seen coming and dodged. It goes off on the first wall, floor or body it meets, or at 45 m.
- **The blast.** A bright ring grows out to the blast's 6 m radius so its reach reads at a glance. Damage is 140 at the centre, more than a full player's 100, easing straight down to 8 at the edge and nothing past it. The level between the blast and a target stops it: cover works.
- **Friendly fire.** The blast hurts everything in its radius, you included, at half what it would deal there, so firing point-blank is a real mistake. There are no teams yet, so it is simply everyone. A blast that kills its own shooter reads "rm -rf: Daemon-2 removed themself" in the feed and credits no kill; other kills read "rm -rf sent by ...". Each blast of yours is called out "rm -rf". Alone you have no health, so the blast only finds the daemons.
- **Slow, never spammy.** One round in the magazine and 3 in reserve, a 3.2 s reload on E, a 2.5 s interval.
- **With sudo's overcharge** (C22's root), "--no-preserve-root": the blast reaches 9 m and the wind-up is 0.3 s. Root's general rules hold as for every weapon (1.5 times the damage, no ammo spent), and your own share of the blast still hurts.
- **In a match the host decides.** The wind-up is yours; when it is done the usual shot intent goes to the host, which believes it as any shot, runs the slug in its own world and judges the blast on every player in it, the shooter too, with the usual combat path (root's scale included), telling everyone the damage and the kills in the usual shot and death messages. Your screen and every other draws the slug from the usual seed message and its blast from the fork bomb's blast word, at the host's place; it never decides damage. No message changed, so the protocol is still 9.
- **All numbers in one place.** `resources/rm_rf_cannon.tres`, a WeaponDef with a new Blast group: the root wind-up share, the move share and how long it lasts after the shot, the slug's speed and look, the blast's radius, root's radius share, the edge damage, the self-damage share, the ring's time and how long a joiner's slug waits for the host's word; the wind-up is the rail's charge_s, the centre damage, range, interval, magazine, reserve and reload the usual ones.
- **Seen in stills only.** A1's stills show the wind-up's glow and the prompt; no window has shown the slug in flight or the ring yet.

The test, `tests/rm_rf_cannon_test.gd`, covers the resource, the falloff alone, the fiction-only scan, slugs in an empty world, the wind-up, its cancels, the weight and the blast in the real arena with real dummies, seven slots at 960x540, and a host and two joiners over 127.0.0.1.

### Built: cron mines (C27)

Timed mines, each one a scheduled job. Fiction only, a hard rule: "cron" and "crontab" are names and HUD text. Nothing touches your real crontab, timers, clock, files or system, and the test greps the weapon's code for calls to prove it.

- **Placing.** Press 8 (or the wheel, or Q). Fire sticks a small glowing rose hex stud on the floor or wall you aim at within 4 m; with nothing in reach it drops at your feet.
- **The schedule.** Armed after 1 s, the mine runs every 2 s, three times, then the job ends and it fades out. Over it, cron-style text shows the schedule and the runs left: "*/2s x3", then x2, x1. Before each run a ring closes from the blast's edge to nothing, and for the last 0.3 s the stud brightens, so you can see it coming and step out.
- **Each run.** A blast with falloff, 55 at the centre easing to 6 at 3 m, and cover stops it. Moderate, not rm -rf's: standing over one, a full-health player survives one run and not all three.
- **Your mines never hurt you.** They are a zoning tool, not a trap for yourself. They hurt every other player in reach (there are no teams yet). Alone they hit the daemons. The kill feed says "cron sent by ...", and the first run of each of your mines is called out "cron".
- **The crontab.** You run three jobs at most. Placing a fourth removes your oldest, and the strip says "crontab full: oldest out" for a moment; otherwise, with cron in hand, it shows "crontab 2/3".
- **Cron runs without you.** Your mines keep running if you die or respawn, and their kills are still yours. They go when you leave the match, and alone when a new round starts.
- **Counterplay.** Any other player can shoot a mine off with any weapon: a ray passing it, a pellet, dart or slug that meets it, or a blast that reaches it. The feed says "crontab -r: Daemon-3 removed Daemon-2's job".
- **Ammo.** Three mines in the magazine, 6 in reserve, a 2.4 s reload on E, a 0.5 s placement interval.
- **With sudo's overcharge** ("root crontab"): each mine placed as root runs once more. Root's general rules hold as for every weapon (1.5 times the damage, no ammo spent).
- **In a match the host owns every job.** A placement is the usual intent. The host sticks the mine where your aim meets the level, keeps its schedule, judges every run, kill and removal with the usual combat path, and tells everyone the damage and kills in the usual shot and death messages. Every screen draws the mine from the usual seed message and each run and removal from the fork bomb's blast word. A joiner arriving mid-match is sent the mines already running. Your game never decides damage or schedules. No message changed, so the protocol is still 9.
- **All numbers in one place.** `resources/cron_mines.tres`, a WeaponDef with a new Mine group (placement range, arm delay, run interval, runs, root's extra runs, crontab limit, the size a shot must pass within, fade, stud size, brighten, the note's time, the removal words) and the Blast group's numbers (radius, centre and edge damage, the ring's time).
- **Seen in stills only.** A1's stills show a placed mine's stud, its ring and its schedule text, drawn by a real GPU; no one has played it in a window yet.

The test, `tests/cron_mines_test.gd`, covers the resource, the fiction-only scan, mines in an empty world, placement, the crontab, the blast and root in the real arena with real dummies, eight slots at 960x540, and a host and two joiners over 127.0.0.1.

### Built: ping sonar (C28)

PRD 5.2's "sonar pulse that reveals hidden daemons", built against the daemons that fight back. Fiction only: "ping" is a name and HUD text. Nothing goes over any network but the game's own, nothing real is listened for, and the test scans the ping code for calls to prove it.

- **One ring.** Press 9 and fire: a lime sonar ring goes out from you across the floor, 18 m in half a second, a low wall of light on its front and a disc of streaks riding it, then fades. It passes through walls. The wall rises over its first few metres, so the ring never blinds you as it leaves.
- **What it finds.** Every daemon the ring reaches is outlined for 4 s, through any wall: its own crystal shape as it stands and moves, the edges bright and scan lines climbing it, with a small tag over it, its name and how far ("rogue.d  12m"). The last 0.8 s fade out, and a daemon that derezzes loses its outline at once. Nothing past the 18 m is shown.
- **It breaks a tell.** A daemon the ring catches in the middle of its tell (rogue.d rearing, a zombie's claw raised with the ember in it, the swarm pulling in before a dive) drops that attack: nothing is thrown, it gives up its attacker slot, and it staggers. rogue.d cowers low and the zombie is thrown back with its arms up, both glitching, knocked half a metre back over a second; the swarm scatters. Then it hunts again after its usual wait, and needs a whole new tell to attack. A daemon doing anything else is only shown: a ping is no hit and rouses no one.
- **No damage, no ammo, a cooldown.** 7 s between pings. Drawn, the strip reads "ping  ready" or the seconds left ("ping  3.5s") and "sonar [#####.....]" filling back, "sonar ready: 18m" when it is. The model's dish has three rings that relight from the inside out as it comes back.
- **Practice.** The ring and the outlines work as ever; the old dummies never tell, so there is nothing to break, and nothing leaves home.
- **In a match the host judges.** Fire is the usual intent. The host sends the ring out from where it heard you and judges its own daemons with it, so a tell it catches is caught for everyone and every screen sees the stagger. Every screen draws the ring from the usual seed message; only your own screen outlines what it meets. Other players are never revealed. No new message, protocol 10.
- **All numbers in one place.** `resources/ping_sonar.tres`, a WeaponDef with a new Ping group (the ring's reach and time, the reveal's time and fade) and its cooldown. The stagger is the daemons' own number, in `resources/daemon_ai.tres` (1 s, knocked 0.5 m).
- **Slot 9, the last free one.** The slot line is a point smaller so nine slots still fit at 960x540; the strip's redesign came with C29 (a second bank on Shift, two rows).
- **Seen in stills and headless only.** No one has played it in a window yet.

The test, `tests/ping_test.gd`, covers the weapon and its numbers, the ring, a daemon behind a wall outlined and tagged, nothing outside the radius, the reveal's fade and end, a tell broken for each daemon type, the cooldown, practice, and a host and a joiner over 127.0.0.1.

### Built: chmod 000, the freeze ray, and the second bank (C29)

PRD 5.2's "chmod 000: freeze ray". Fiction only: "chmod 000" is a name and HUD text. Nothing real has its permissions touched, ever: the game makes no permission call, no file call and no process call for it, and the test scans the freeze code to prove it.

- **The second bank.** Keys 1 to 9 were all taken (ping took the last), so weapons 10 to 18 are a second bank. Hold Shift and press 1 to 9 to draw them: Shift+1 is chmod 000. Shift was free (SIGKILL has no sprint key; you run by default), and it is rebindable in Settings, Controls, where it reads "weapon bank 2". Q and the mouse wheel reach every weapon of both banks. The strip has two slot rows in its own column: bank 1 at the bottom as before, bank 2 over it led by the key ("Shift+ [1 chmod]", "Shift+ [1 chmod] 2" since C30's pipe | took Shift+2). The bank you are in is lit and the other dimmed, and holding Shift lights bank 2, since 1 to 9 then draw its weapons.
- **Hold fire.** A beam, not shots: while fire is held a cold beam runs from the emitter to the first thing in its 22 m, a thin hot core in a frost-opal sheath with light running down it toward the target, frost shards spiralling along it, a bloom and a spray of frost where it lands, and a cold hiss.
- **It strips permissions.** Each tenth of a second of beam builds the target's freeze meter: a daemon fills in 1 s of beam (an elite in 1.5, the hunter and the nodes in 1.6), and a crust of frost creeps up it from the feet as it fills, the meter under your crosshair ("chmod 000  rogue.d [#####.....]"). Once the beam leaves, the meter holds a moment, then melts.
- **Frozen.** A full meter freezes it for 3 s (ICE for 2.2 s): the crust takes the whole body, thick and bright, chips of frost burst off it, and its tag reads "PERMISSION DENIED" over "---------- 000" and the seconds left. A frozen daemon does nothing at all: it does not move, turn or attack, and a tell it was in (rogue.d rearing, a zombie charging its bolt, the swarm pulling in) is called off. It thaws when its time is up and cannot be frozen again for 1.5 s, so there is no freezing a daemon forever.
- **Then hit it.** The next hit on a frozen daemon thaws it and lands twice as hard. A hit of 40 or more (the rail, rm -rf, a cron run) shatters it outright, whatever its health, and any kill of a frozen daemon is a shatter: it derezzes in the frost opal in a storm of frost.
- **Coolant, not ammo.** No damage and no magazine: a tank of 4 s of beam that refills on its own (0.6 s after you let go, empty to full in 3 s). Run it dry and it vents: no beam until it is back to 40%. The strip reads "chmod  coolant 72%" over "coolant [#######...]", or "chmod  VENTING" in amber. The model is a hexagonal emitter with a glass coolant tank on top whose four cells light with what is left, three lock tumblers round the barrel (r, w and x) that spin up while the beam runs, three cold prongs round a crystal lens, and "000" on its flank.
- **Against ICE.** It freezes the hunter and pauses a node's field like a daemon: a lance's tell or a field's tell is called off, and the next hit on frozen ICE lands twice as hard after its hit cap. Walls ignore it ("chmod: read-only file system"). Black ICE cannot be frozen ("chmod: Operation not permitted"): the beam only slows it while it holds, up to 40% of its pace, with a faint frost over it; it never hurts it, never stops its touch and never touches its seals (only the exploit and brute combo does).
- **Its own colour.** A frost opal, `#a87884`, found by a search of the whole colour cube for the point farthest (OKLab) from every bright colour of the palette: every blue and cyan was taken (the player's teal, the rail's ice, grep's cobalt, white ICE's glacier, the hunter's cobalt, Black ICE's slate), so a frozen daemon never reads as ICE. Its nearest are cron's rose (0.174), rm -rf's ember and Black ICE's slate (0.176); glacier is 0.225 away, the hunter's cobalt 0.33, the breakers' ultraviolet 0.28.
- **Practice.** It still freezes the dummies.
- **In a match the host judges.** Each tick of the beam is the usual fire intent; the host checks it (your coolant too, kept on its own clock) and casts the tick's ray itself. A player it meets is slowed as their meter fills (down to 55% of their pace) and then frozen for 1 s: no moving, jumping, firing, throwing or drawing, only looking round, and the host refuses their shots until they thaw, with 2.5 s after it in which they cannot be frozen again. Spawn protection holds. Every screen draws the beam and the frost from words already sent: protocol 15, no new message.
- **All numbers in one place.** `resources/chmod_000.tres`: the weapon (its 0.1 s tick, its 22 m) and its FreezeTuning inside it (the coolant, every meter's time, every freeze's length, the guards, the player's slow, the frozen hit's 2x and the shatter's 40, Black ICE's slow).
- **Seen in stills and headless only.** No one has played it in a window yet: its numbers wait for a playtest.

The test, `tests/freeze_ray_test.gd`, covers the weapon, its numbers, its colour, the bank key and the strip at 960x540, the meter, the freeze and the thaw, a tell called off, the frozen hit and the shatter, the coolant, Black ICE only slowed, walls, the hunter, a node, practice, and a host and a joiner over 127.0.0.1.

### Built: pipe |, the chain beam (C30)

PRD 5.2's "pipe |: chain beam that arcs between enemies". Fiction only: "pipe" is a name, a HUD line and a sound. Nothing real is piped, run or read: the game opens no pipe, starts no process and touches no file for it, and the test scans the pipe's code to prove it.

- **One click, one chain.** Shift+2 draws it (weapon 11, bank 2's second; Q and the wheel reach it). A click sends a stream into the first thing your aim meets within 30 m: link 1. From it the stream jumps to the nearest target not yet in the chain within 12 m that it can see, then on from that one, up to five links (six while you are root), one chain every 0.45 s.
- **Damage falls down the chain.** Link 1 takes 26, each link after it 70% of the one before: 26, 18.2, 12.7, 8.9, 6.2. A plain daemon dies to any link, so in a crowd one click can take five.
- **Walls break a chain.** It never arcs through the level: a daemon in reach behind a wall is skipped, and the readout says so ("1 link: a wall broke the chain").
- **Written out as a command line.** For a moment after each chain, under your crosshair: `$ rogue.d | zombie | runaway   3 links`, a frozen link as `zombie(000)`. A row too long for the screen is drawn smaller, then its names cut short.
- **Through the frozen.** A daemon or a piece of ICE that chmod 000 holds frozen conducts: the stream passes through it losing nothing and jumps 1.5 times as far from it (18 m), while its own hit is the freeze ray's rule, thawed and twice as hard, so a plain daemon shatters in a storm of frost.
- **Exploit counts on every link.** Each link after the first lands on its target's weak seam nearest the way the stream came in (the data finds an open port), so while an exploit runs every link lands 2.5 times harder.
- **Against ICE.** The hunter and the nodes are links like daemons (and the hunter learns the pipe like any weapon). A wall of white ICE hit first takes its hit and passes nothing on, and no chain ever jumps to one. Black ICE is never part of a chain: hit first it only flashes, "pipe: broken pipe", and nothing goes on; no chain jumps to it; its seals and its touch are untouched (only the exploit and brute combo breaks them).
- **The buffer, not a magazine.** A pipe's buffer: 64K, each chain writes 8K, and it drains 24K a second once you have stopped for half a second. Fill it and writes block ("pipe  BLOCKED", "pipe: write blocked, buffer full") until it has drained to half. Root writes nothing. The strip reads "pipe  buffer 24K/64K" over "buffer [####......]".
- **The look.** The model is a length of pipe made into a weapon: bolted flanges, brass conduits along the top, a buffer gauge of eight lit `|` bars on its flank that fill as the buffer does, a tee with glowing outlets and a valve wheel, and at the muzzle a lit `|` filament between two prong plates; its couplings and the valve spin with each chain. The stream races link to link, 0.04 s a link: jagged, braided ribbons of brass light round a hot core, bars of data (the pipe's `|`) flowing down each arc from source to sink, a bloom and a spill of data streaks at every link, and a crackle.
- **Its own colour.** A brass, `#a79300`, found by a search of the colour cube for the point farthest (OKLab) from every bright colour of the palette with chmod's frost opal kept clear: its nearest are the signs' sodium (0.151), the frost opal (0.162), the zombie's amber (0.167) and rm -rf's ember (0.173); ICE's, Black ICE's and the breakers' colours and texts are all 0.21 and more away.
- **Practice.** It chains across the dummies.
- **In a match the host judges.** A chain is the usual fire intent; the host checks it (your buffer too, kept on its own clock), builds a joiner's chain again in its own world and lands every link: on players (a dead or spawn-protected one is never a link) and, while they fight, on its daemons and ICE. The host's own chain is the one its player built and drew, and the aim shoots off a cron mine on its way as any shot does. Every screen draws the other players' chains from the shot message it already gets: protocol 16 (an older build can neither believe nor draw a chain), no new message. Kills read "SIGPIPE" in the feed.
- **All numbers in one place.** `resources/pipe_chain.tres`: the weapon (26, 0.45 s, 30 m) and its PipeTuning inside it (the jump, the links, the falloff, the frozen link, the buffer).
- **Seen in stills and headless only.** No one has played it in a window yet: its numbers wait for a playtest.

The test, `tests/pipe_chain_test.gd`, covers the weapon, its numbers, its colour, the chain's rules, Shift+2, Q and the wheel, the strip and the readout at 960x540, a chain across four dummies in practice, the range, a wall, a frozen link, ICE and exploit, Black ICE, the buffer and root, and a host and a joiner over 127.0.0.1.

### Built: SIGHUP, the confusion grenade (C32)

PRD 5.2's "SIGHUP: confusion grenade; enemies 'reload' and wander". SIGHUP tells a process its terminal hung up, so it rereads its config and forgets what it was doing. Fiction only: SIGHUP is a name, a tag and a sound. The game never sends any signal to any real process, and the test scans its code to prove it.

- **Throw it.** Shift+4 draws it (weapon 13, bank 2's fourth; Q and the wheel reach it); fire throws the device, a telephone handset tumbling end over end, on the fork bomb's arc (14 m/s and 3 up). It goes off where it first meets the floor, a wall or a body, half a metre over the floor, or in the air when its 1.2 s fuse runs out. Two of yours in the air at most; two charges, one back every 12 s on its own (root throws for free and its burst reaches 1.25 times as far). No quick-throw key: every letter is taken, and G stays the fork bomb's.
- **The hangup.** A carrier wave runs out from the burst at 14 m/s to its 7 m reach (half a second); each thing in reach that the burst can see is caught as the front passes it, once a burst. Behind a wall when the front passes, it is spared. It does no damage of its own: its value is control.
- **Reload, then wander.** A daemon caught calls off what it was doing (a tell or a strike), drops its target and stalls for 1.2 s, "SIGHUP: reloading config" typed out over it with a bar, its seams dimmed under a scan of carrier green climbing them. Then it wanders confused for 4 s: no idea where you are, a random walk in short legs at 55% of its speed, stopping between them to look round (its facing snapping side to side), its motion stuttering, a "?" over it, its seams cycling between their own colour and green. Then it is itself again: it walks home, or hunts what it sees.
- **The crowd turns on itself.** Wandering confused, a daemon with another within 3.5 m in sight lashes at it with its own attack, its tell first: rogue.d's lunge and slash, the zombie's bolt, the swarm's dive, at 75% of the attack's damage; at most two lashes a confusion, the first 0.4 s into the wander, 1.4 s apart. A lash's kill is the thrower's. Practice's dummies never lash.
- **No chain-lock.** A hangup on a daemon already confused is refused (it never starts over), and when a confusion ends the daemon is guarded for 6 s; no daemon can be kept confused more than 46% of the time.
- **With the others.** A `/dev/null` hole drags a confused daemon 1.3 times as hard (it does not brace). A chmod-frozen daemon takes the hangup frozen and starts confused when it thaws. `ping` outlines the confused in the carrier green, its tag "hung up", the rest in its lime.
- **Against ICE.** The hunter is confused as a daemon is (it never lashes) and forgets what it learned about your favourite weapon: its adaptation wiped, its shields cobalt again, the HUD's "HUNTER ADAPTED" line gone. A node reloads: its field drops (a tell it was in called off) for 5 s, then it looks again. Walls of white ICE are not touched. Black ICE runs under nohup: it is never confused, its seals and its touch untouched; it flashes once and the burst's tag says "SIGHUP: ignored (nohup)".
- **The look.** The device tumbles with a trail of green sparks. The burst: a flash of carrier light, a spike of light standing up out of it; on the floor the carrier wave, an oscilloscope's sine trace wrapped round its front with three ghosts of it trailing in, broken into dashes that drop out, static over the floor it has swept, stretches of the trace torn out now and then; a curtain of thin interference lines standing on the front, as tall as a daemon, running out with it; static flung out flat; and over it its tag, a modem's last word: "$ kill -HUP", "NO CARRIER  4 reloading". The sound: a handset slammed down, a modem's screech as the carrier drops, two beeps of a busy line.
- **The model.** An old telephone handset cut in hard geometry: an eight-sided handle bending down at both ends into its cups (their grilles lit), the coiled cord springing out of the mouthpiece, three carrier rings breathing off the earpiece along your aim, a carrier light for each charge on its spine and a hook switch between them. With no charge left the rings go dark: the line is dead.
- **Its own colour.** A carrier green, `#00bf00`, an old modem's carrier light: every hue band of the palette is held, so a search of all of sRGB for the point farthest (OKLab) from every bright colour found it here, 0.164 from the pipe's text and 0.170 from its brass, the nearest, 0.176 from the code rain's green and 0.188 from the player's teal; ICE's glacier 0.302, the hunter's cobalt 0.511, Black ICE's slate 0.302, the breakers' ultraviolet 0.530, chmod's frost opal 0.297, /dev/null's plum 0.449 and ping's lime 0.230 (its ring never reads as ping's). Its HUD text `#87d35c`.
- **A player caught.** In a match, on that player's own screen alone, for 2.5 s: the HUD glitching (rows of green static tearing across, scanlines at the edges), the crosshair as drawn drifting up to 22 px off the middle on a slow wander (a faint dot stays at the true middle: the aim never moves), "SIGHUP: hung up  NO CARRIER" over it, and the AI link's badge "HUNG UP". Nothing is inverted, slowed or taken away: every control works. Never the thrower, never a spawn-protected player, and no damage.
- **Practice.** Its never-attack dummies take the reload and wander, then walk home.
- **In a match the host judges.** A throw is the usual `_throw`: the host checks it (your charges too, on its own clock a little quicker), runs the burst, confuses its daemons and ICE while they fight, and judges every player its wave reaches; a player caught is told alone. A daemon's confusion rides the daemons' state word, the hunter's ICE's. Protocol 18, no new message: the seed's sign carries the thrower's root, `_blast` carries where it went off, the count it confused and the word to a caught player.
- **All numbers in one place.** `resources/sighup.tres`: the weapon (two charges, a 0.8 s throw interval) and its SighupTuning inside it (the throw, the recharge, the burst, the reload and the wander, the lashes, the guard, the hole's pull on the confused, a node's reload, a player's confusion).
- **Seen in stills and headless only.** No one has played it in a window yet: its numbers wait for a playtest.

The test, `tests/sighup_test.gd`, covers the weapon, its numbers, its colour, its rules, Shift+4, Q and the wheel, the strip and a caught player's line at 960x540, the throw (its arc, its landing, the fuse, two in the air at most, the recharge, root), a burst over four dummies in practice (each caught as the front passes, one past its reach spared, the look's parts, the tag, the callout, the reload's stall and its tag and seams, the wander, the walk home), the guard, a wall sparing a daemon, a tell called off and the prey dropped, a crowd's lashes and a lash kill's credit, a frozen daemon, a hole on the confused, ping's outline, the hunter and a node, a wall of ICE, Black ICE, and a host and a joiner over 127.0.0.1.

### Built: /dev/null, the black hole (C31)

PRD 5.2's "/dev/null: black-hole grenade". Everything written to /dev/null is discarded. Fiction only: "/dev/null" is a name, a tag and a sound. The game never opens, writes or reads the real /dev/null or any file for it, and the test scans the hole's code to prove it.

- **Throw it.** Shift+3 draws it (weapon 12, bank 2's third; Q and the wheel reach it); fire throws the device on the fork bomb's arc (13 m/s and 3 up). It opens a singularity where it first meets the floor, a wall or a body, its core a metre over the floor, or in the air when its 1.6 s fuse runs out. One hole of yours open at a time; two charges, one back every 16 s on its own (root throws for free and its hole reaches 1.25 times as far). No quick-throw key: every letter is taken, and G stays the fork bomb's.
- **The pull.** For four seconds (it opens over 0.4 s and collapses over 0.35 s) everything within 9 m of its core's axis that the core can see is held: dragged toward the axis at 1 m/s at the edge rising with the square of the depth to 7.5 m/s at the core, growing over its first second, and swirled round it. Walkers slide over the floor; the swarm and the hunter are drawn to the core's height too, but never down behind cover out of its sight. Nothing is pulled through the level.
- **Damage over time, then the core.** Outside its 3 m horizon it only pulls. Inside, a held thing takes 8 to 40 a second, the deeper the more, every 0.25 s, quietly (no flash, no recoil, the pull is its look). Whatever reaches the core (0.8 m from its axis) is discarded: one hit of 500, a daemon of any health gone, the round HUD calling "> /dev/null". Then the implosion: everything still held within 5 m takes 45 at the core easing to 10.
- **Against the daemons.** A held daemon does nothing of its own: a tell or a strike it was in is called off, as chmod 000 calls one off, and once let go it hunts again after its attack's own wait. A crowd is drawn into a knot round the core, the place for a `pipe |` chain or a fork bomb.
- **chmod 000's frozen.** A frozen daemon is pulled like any other and takes nothing on the way in; at the core it shatters (the discard is far over chmod 000's 40).
- **cron mines.** Mines in its reach, anyone's, are torn loose and drawn to the core, where each is set off: one last run of its own blast, its owner's, and its job ends.
- **Against ICE.** The hunter is pulled and hurt like a daemon (its discard held to ICE's hit cap of 100). The nodes are held in place, never moved, but hurt. A wall of white ICE is never moved or hurt: inside the horizon it only flickers. Black ICE is never pulled, held or hurt, its seals and its touch untouched: it flashes once, and the hole's tag says "/dev/null: device busy".
- **The look.** The device is a sphere of black glass in a cage of two turning plum rings with a white-hot pinhole, shedding sparks. The hole is a sphere of nothing (opaque, unlit black) with a white-hot photon ring and a halo round it, the arena behind it bent by a lensing shader (an Einstein ring, the view turned inside out within it), a tilted accretion ring of plum matter streaming in on log spirals, white-hot at its inner edge and brighter on the side swinging toward you, 150 streaks of debris spiralling in from its reach (their paths drawn by a shader), a dark well on the floor with its reach as a ring of drifting dashes, a plum light and a negative light that darkens what is near the core. What it holds is drawn out up to 2.4 times its length toward the core and tipped into the pull, a trail of plum sparks behind it. Over the core its tag, the command it is: "$ cat * > /dev/null", what it holds and what it has discarded. The implosion: a white-hot point pops and dies, a shock ring is flung out over the floor and another, upright, round the core, debris drawn in, "> /dev/null" written over it. A low drawn-in roar while it holds, a rush and a deep boom at the end.
- **The model.** A containment cradle, a sink you hold: three curved prongs from a ring collar cup a sphere of black glass, a photon ring hugging it and two gyroscope rings of plum light turning on crossed axes round it; chevrons down both flanks point in toward it; on the collar a charge cell for each charge, lit as they come back.
- **Its own colour.** A void plum, `#ab389b`, the accretion ring's (the hole itself is black): every hue band of the palette is held, so a search of the plum band for the point farthest (OKLab) from every bright colour found it 0.159 from chmod's frost opal and 0.160 from the breakers' ultraviolet and the runaway's hot magenta, the nearest; ICE's glacier 0.315, the hunter's cobalt 0.283, Black ICE's slate 0.230 (another family of hue: its core never reads as Black ICE) and the pipe's brass 0.312 away. Its HUD text `#ef8fe3`.
- **Practice.** It pulls the dummies, discards them and they come back.
- **In a match the host judges.** A throw is the usual `_throw`: the host checks it (your charges too, counted on its own clock a little quicker than yours), runs the hole, drags and hurts its daemons and ICE while they fight, and judges every player it reaches each tick and at the implosion, never the thrower, a dead or a spawn-protected player, a discard credited to the thrower ("> /dev/null" in the feed). Each screen drags its own player from its own copy of the hole, opened at the host's place on the host's word, never faster than 4.2 m/s (a run is 7: run and you get out); its edges wash plum and the line over the crosshair says "> /dev/null: pulling you in  RUN". Protocol 17, no new message: the seed's sign carries the thrower's root, `_blast` carries the opening, the collapse and each discard.
- **All numbers in one place.** `resources/dev_null.tres`: the weapon (two charges, a 1 s throw interval) and its DevNullTuning inside it (the throw, the recharge, the hole's times and sizes, the pull, the damage, the discard, the implosion).
- **Seen in stills and headless only.** No one has played it in a window yet: its numbers wait for a playtest.

The test, `tests/dev_null_test.gd`, covers the weapon, its numbers, its colour, the hole's rules, Shift+3, Q and the wheel, the strip at 960x540, the throw (its arc, its landing, the fuse, one open at a time, the recharge, root), a hole over four dummies in practice (the pull for each distance, the swirl, the stretch, damage inside the horizon only, the discard, the implosion, the callout, the tag), the end pulse, a tell called off and a knot drawn, a frozen daemon, walls and a wall of ICE, the hunter and a node, Black ICE, cron mines, and a host and a joiner over 127.0.0.1.

### Built: unlocks, mods and light skins (C33)

PRD 5.2's "every one gets its own Tron light skin, mods and unlocks earned by playing". Every weapon has a kit beside its `.tres` (`resources/<id>_kit.tres`): its own skin, two more to earn, and one mod.

- **Earned by playing, and nothing else.** No store, no money, no account, no network call, no telemetry: nothing is ever bought. Your progress is one small file on your own machine, `user://progress.cfg` beside the settings file, written through the settings file's own strict reader and atomic writer (a temporary name renamed over the old one). A missing or damaged file is a fresh profile, never a crash.
- **What counts.** Alone, a feat counts only against the daemons fighting back (C27b), never against practice's dummies that never attack. In a match, only the host's judged results for you count: a kill it credits to you with your weapon, a rail headshot it confirms. The counts are saved at each round's end, when you pause and when you quit; an unlock is saved at once.
- **The unlocks.** A first one comes inside a normal session (the cannon's mod at 10 kills).

| Weapon | Mod: what it gains, what it costs (as shipped); earned by | Light skins, earned by |
|---|---|---|
| Terminal cannon | overclock: a 0.13 s interval, 21 a hit (0.16 s, 25); 10 kills with it | tty1 (25 kills), Dracula (75) |
| SIGTERM | choke: a 4 degree cone, 7 pellets (6, 9); 8 kills | ^C (20 kills), Catppuccin (50) |
| SIGKILL rail | quickdraw: a 0.15 s charge, a meter of 3.6 to fill (0.35 s, 3.0); 3 kills | blacklight (3 kill -9 headshots), P1 phosphor (a round survived with Black ICE out) |
| Fork bomb | ulimit -u: 3 bombs, trees of 3 generations (2, 4); 6 kills | C64 (15 kills), exponential (one bomb's tree derezzing 3) |
| `fork()` | deep fork: 2 forks a pellet, 3 shells (1, 4); 8 kills | jade (20 kills), init (50) |
| `grep` | grep -m 4: 4 marks, a 0.8 s lock (3, 0.5 s); 15 targets marked | --color=always (15 kills), regex (40) |
| `rm -rf` | no prompt: a 0.35 s wind-up, 0.75 of the blast on you (0.6 s, 0.5); 4 kills | --preserve-root (12 kills), dd (5 ICE walls broken) |
| `cron` | \*/1: a run every 1.4 s, 2 runs (2 s, 3); 4 kills | @midnight (12 kills), @reboot (30) |
| `ping` | ping -i 5: a 5 s cooldown, a 13 m ring (7 s, 18 m); 10 daemons found | traceroute (30 found), echo reply (100) |
| `chmod 000` | deep tank: a 5.5 s tank, a 2.2 s freeze on a daemon (4 s, 3 s); 5 freezes | chmod 755 (3 frozen daemons shattered), chattr +i (12) |
| `pipe \|` | xargs: 6 links, 7 as root, each keeping 60% (5, 6, 70%); 3 chains of 3 or more | tee (15 kills), mkfifo (15 chains of 3 or more) |
| `/dev/null` | wide horizon: an 11 m pull, a 3 s hold (9 m, 4 s); 2 discards | /dev/zero (8 discards), /dev/random (25) |
| SIGHUP | wideband: a 9 m burst, a 2.8 s wander (7 m, 4 s); 6 daemons hung up | dial tone (1 kill by a confused daemon's lash), 300 baud (5) |

- **Light skins.** 26 to earn, each with a name and a line of fiction from a terminal theme or an old machine: green phosphor on the first console, the Dracula and Catppuccin themes, CGA's cyan and yellow, the Commodore 64's blue, a blacklight, a VT220's white, a dial tone. A skin relights the weapon's seams, trim and rim (light only in the seams of its dark gunmetal body: the A1 and A4 look), its hot parts, its muzzle burst, its tracers and trails, its thrown device and its burst or hole, chmod's beam, the pipe's arcs, ping's ring, and its entry on the HUD strip. What a weapon leaves on a target keeps the weapon's own colour (the frost, the confusion's green, ping's outlines), so a state reads the same whoever caused it. Cosmetic only. **Never an enemy's colour:** every skin's two lights keep at least 0.16 (OKLab) from every hostile light (the daemons' crimson, hostile red and amber, the runaway's magenta, the glitch's magenta, ICE's glacier, the hunter's cobalt, Black ICE's slate), so a search of the hue wheel left the greens, yellow-greens, cyans, violets, pale pinks and whites; a weapon's own skins keep 0.15 apart, so each reads apart at a glance. In a match the other players see your skins on your shots, throws, beams and arcs.
- **Mods.** One a weapon, a small, readable tradeoff, never strictly better: each one's numbers live in its kit, every gain is checked to move its number the better way and every cost the worse, and the modded weapon must pass the weapon's own checks. Fit one on the loadout screen; it takes effect at once alone (nothing refills). In a match the host judges your shots with your mod applied, while its **mods** rule (Settings, Multiplayer; on by default, fixed when it starts hosting) is on; off, everyone plays the shipped weapons and keeps their skins.
- **The loadout screen.** Esc, then Loadout (no key of its own). The arsenal down the left with what each has earned of its kit; in the middle the weapon's own first-person model, large on a turntable in a world of its own, slowly turning over a dark plinth ringed in its skin's light on a black glass floor that reflects it, a pool of that light falling on it; on the right its skins as cards (two swatches of light, a name, a line of fiction) and its mod as a card of what it gains and what it costs. A card under the pointer lights the model in that skin at once, locked or not; a click wears a held skin or fits a held mod; a locked one says how far along you are ("LOCKED  30 / 75 kills with cannon"). Everything on one screen with no page scroll, shrunk whole to fit 960x540 and up, mouse and keyboard. Alone what you wear changes as it closes; in a match your look holds until the match ends.
- **The toast.** "UNLOCKED: tty1" drops in near the top the moment you earn it, in that skin's light, with where to wear it; several earned at once take turns.
- **Reset progress.** Settings, Reset progress, asks first; a second click within 4 s wipes every count, unlock and choice.
- **For captures and tests.** `--unlock-all` holds every skin and mod for that run, never saved; off unless given.
- **Protocol 19.** A joiner's hello carries its look, one byte a weapon (the skin, a bit for the mod); every roster carries each player's look as the host accepted it; the rules carry the mods rule; the host's word of a hit on a daemon names the weapon (a kill's feat). No new message.
- **The nixfred hexagon logo** is never recoloured or skinned; the test pins it to the byte.
- **Seen headless and in stills only.** No one has played it in a window yet: the thresholds and the mods' numbers wait for a playtest.

The test, `tests/unlocks_test.gd` (check step 47), covers the chunk's code (no connection, nothing written but the save under `user://`, the logo untouched), every kit, every skin's distance from every hostile light, every mod changing exactly its numbers and refused when strictly better, the save written and read back and a missing or corrupt one, a threshold's edges, the `--unlock-all` flag, a real kill earning against fighting daemons and not against practice dummies with its toast, a mod and a skin worn in hand and a real shot landing the mod's damage, reset asking first, the loadout screen at 960x540, the toast's turns, and a host and a joiner over 127.0.0.1: the joiner's mod judged by the host, its skin seen on the host's screen, a kill counted from the host's word, and the mods rule off ignoring the mod.

### Built: SIGSTOP bullet time (C18)

SIGSTOP stops a process and SIGCONT lets it go on; here they stop the world around you. Fiction only: nothing real is stopped or signalled.

- **How to use it.** Press F when the strip's bottom line shows a quarter or more: "F SIGSTOP [####......]". Press F again for SIGCONT; it also ends by itself when the meter runs out. F can be rebound in Settings, Controls, where it reads "SIGSTOP".
- **The meter.** Its own, separate from the rail's: 4 s of slow-mo when full, refilling from empty over 20 s while not in use (never while you are derezzed); a start needs a quarter. A new round fills it and a death empties it. The numbers are in `resources/sigstop.tres`.
- **Alone in the arena.** The world runs at 0.3x: the daemons, the beams and every effect, physics and every timer, the round clock too. You don't: you move, look, aim and fire at 0.9x of your full speed in real time, your weapon cools at that pace and the rail charges at it. Your shots go steady: no spread (SIGTERM's nine pellets fly straight) and no recoil. SIGCONT eases the world back to full speed over 0.25 s.
- **Nothing stays slowed.** The time scale is exactly 1.0 again after SIGCONT and when the meter runs out, and at once on a death, a round's end, the Esc menu or the ask box, when a match starts and when the arena reloads. A safety check puts back any time scale no SIGSTOP holds within a frame.
- **In a match nothing slows, for anyone.** The host's simulation, its clock and every player run at full speed. SIGSTOP is yours and local: your screen goes grey toward the theme's teal with motion trails, and your sound pitches down. While the host says it is on, your shots go steady: zero spread, with the host drawing the pellets, and zero recoil. F asks the host. The host keeps every player's SIGSTOP meter by the same numbers, refuses and counts a start the meter cannot pay for, and its word starts and ends SIGSTOP on your screen. The wire is protocol 4.
- **Callouts.** "SIGSTOP" when it starts and "SIGCONT" when it ends: game logic, never the AI, never held back by the callout pace.
- **Seen headless only.** No window has shown the look or the trails, and no one has heard the pitch drop or felt the slow-mo.

The test, `tests/bullet_time_test.gd`, covers the resource and the meter, the rebind saved and loaded, solo play in the real arena with every way it ends, and a host and a joiner over 127.0.0.1.

### Built: light-trail mode (C20)

Tron's light cycles, on foot. A match rule, off by default.

- **How to turn it on.** Host a match (M, then H) with Settings, Multiplayer, "light trails" ticked, or start the game with `godot --path . -- --light-trails`, which turns it on for this run's hosting without saving anything. The host's setting is the match's: joiners play by the host's, whatever their own says, and the host can turn it on or off mid-match. Solo play has no trails.
- **The walls.** On the ground, every half metre of travel lays a wall segment behind you, from where the last one ended: 1.2 m tall and 8 cm thick, in your slot's own neon (Daemon-1 teal, Daemon-2 amber, then magenta, ice, violet, green, yellow, red), glowing for bloom. Each one stands six seconds, fading over the last 0.75 s, then goes; a trail holds 64 segments at most, the oldest going first. In the air nothing is laid, so a jump leaves a gap and the next wall starts where you land.
- **Touching one.** Any wall, anyone's, your own older one included, derezzes you, and the kill goes to the wall's owner: "light trail sent by Daemon-1" in the feed; dying on your own wall counts no kill. Your own newest segment never touches you, nor do your own segments younger than 0.4 s, so the wall you are laying is never the one that kills you; standing still on it is safe. Jumping clear over a wall is no touch, and spawn protection keeps you safe as it does from every weapon. The walls stop nothing: no bullet, no body. They kill on touch.
- **Deaths and leaving.** A death or a respawn clears that player's walls on every screen; turning the rule off, or leaving the match, takes every wall away at once.
- **In a match the host owns every wall.** It lays each player's walls from where it knows them (its own body, a joiner's newest position) with a ray down to the level to tell the ground from the air, sends each segment to every joiner, and judges every living, unprotected body against every wall. Joiners only draw what the host sends and age it on their own clock; a joiner who arrives while walls stand is sent each one with its age. The wire is protocol 6 (7 since C22); the relay's own protocol is untouched.
- **Cheap on the frame.** No physics bodies: one MultiMesh per player draws its walls, and the touch test is plain geometry, skipping any player's walls whose bounds are out of reach.
- **All numbers in one place.** `resources/light_trail.tres` (a LightTrailTuning): spacing 0.5 m, height 1.2 m, thickness 0.08 m, lifetime 6 s with a 0.75 s fade, 64 segments a player, 0.4 s of grace, the ground within 0.15 m of the feet, a new wall past a 2.5 m gap, glow 2.4.
- **Seen headless only.** No window has shown a wall, its fade or a light-trail derezz.

The test, `tests/light_trail_test.gd`, covers the resource, the setting and the flag, the walls' own rules on one node, and a host and a joiner over 127.0.0.1.

### Built: code-rain vision (C21)

See through walls the way the code rain does: an ability, not a weapon.

- **How to use it.** Hold V (rebindable in Settings, Controls, where it reads "code-rain vision"; never a Ctrl+Alt chord). It stays on while you hold it and the meter lasts. Your weapons fire as always.
- **What you see.** Every enemy body within 40 m, through any wall: alone, the target dummies; in a match, the other players. Each shows as a capsule of the walls' own Matrix glyphs, the same streams, sizes and greens as the code rain (from `resources/code_rain.tres`), drawn over everything with no depth test, the nearest 16 at most. The rest of the picture dims and turns toward green on your screen, easing in and out over 0.2 s: never a flash. With screen shake or motion blur turned off (the comfort settings) the tint is half as strong and the glyphs hold still.
- **The meter.** Its own, separate from SIGSTOP's: a full meter is 3 s of use, a start needs a quarter of it, and once off it rests a second and then refills in 12 s. Letting go of V or an empty meter turns it off, and so do a death, a respawn, the Esc menu or the ask box, and leaving a match; none of them touches the meter, and it does not refill while you are derezzed. Holding V through an empty meter never restarts it: press again.
- **The HUD.** Its meter is the strip's last line, right under SIGSTOP's: "V vision [##########]" in the rain's green, dimmed below the quarter, "V VISION [...]" while on. Under SIGSTOP's and not beside it: at 960x540 the round summary leaves the strip no room to grow wider.
- **Yours alone.** It reads only positions your game already has and sends nothing: no new message, protocol 6 as it was (7 since C22's sudo messages, 8 since C23's top table, 9 since C25's grep marks, none of them vision's), the host's authority and the relay untouched, and nobody learns you used it.
- **All numbers in one place.** `resources/code_rain_vision.tres` (a CodeRainVisionTuning): the meter (3 s), the refill (12 s) after the rest (1 s), the start share (25%), the range (40 m), the tint and its strengths (full, and 0.5 calm), the 0.2 s ease, the silhouette's size and glow.
- **Seen headless only.** No window has shown a silhouette, the tint or the glyphs on a body.

The test, `tests/code_rain_vision_test.gd`, covers the resource, the meter, the rebind, solo play in the real arena behind a real wall and a host and a joiner over 127.0.0.1.

### Built: root vs user and sudo overcharge (C22)

You spawn as an ordinary user; earn root. Fiction only: the game never runs, calls or mentions a real `sudo`, and "user" is a fixed word, never your name.

- **The badge.** Bottom left, above the key hints: `user$` in mint as every life starts, with "sudo ready: Z" beside it once you hold a charge; `root#` in the hostile red while overcharged, with the seconds left.
- **Earning sudo.** Three kills in one life, with no death between, earn one sudo charge: alone, the target dummies you derezz; in a match, the kills the host credits to you, light-trail wall kills included. You hold one at most; kills while you hold it bank nothing. A death ends the streak and drops an unused charge: you come back as user.
- **Using it.** Press Z (rebindable in Settings, Controls, where it reads "sudo"; never a Ctrl+Alt chord). The badge shows a purely cosmetic `[sudo] password for user: ********` for a moment, then `root#` for 8 seconds.
- **Root.** The weapon in your hand, and any you swap to meanwhile, hits 1.5 times as hard and spends no ammo (an empty magazine still fires, fork bombs throw for free). The rail rifle just gets the 1.5 times like the rest: its ult meter fills no faster (a hit's share is counted at user's strength) and its shot is not doubled. Your viewmodels and muzzle flash glow root's red; in a match the other players see your avatar's visor go red and `root#` on your tag. SIGSTOP and code-rain vision are unchanged.
- **When it ends.** At the 8-second mark, at a death, at a respawn and on leaving a match.
- **In a match the host owns it.** The host counts the kills, grants the charge, believes or refuses your Z (a request with no charge is refused and counted), applies the 1.5 times in its own judging of your shots and blasts and spends nothing from your ammo while you are root, and tells everyone who is root. Your game never applies the multiplier itself. Two new messages: your ask and the host's word on each player's charges and root time. The wire is protocol 7 (8 since C23's top table, 9 since C25's grep marks); a game still on protocol 6 was refused with the usual "version mismatch: host 7, you 6". The relay carries the new messages like any other and is otherwise untouched.
- **All numbers in one place.** `resources/sudo_overcharge.tres` (a SudoOverchargeTuning): 3 kills, 1 charge at most, 8 s of root, 1.5 times the damage, the password line's 1.2 s, the glow's 2 times.
- **Seen headless only.** No window has shown the badge, the red glow or the password line.

The test, `tests/root_sudo_test.gd`, covers the resource, the rules, the rebind, solo play in the real arena with a real dummy and a host and joiners over 127.0.0.1.

### Built: spectate as top (C23)

Dead players watch the match as a process table. Fiction only: every PID, user and command in it is game data. The game never reads, lists or names a real process, user, host or path. Its layout, with made-up numbers (an example typed here, not a capture):

```
top - 1:12 up 4:31, 2 users, load average: 1.00, 2.00, 3.00
Tasks: 2 total, 1 running, 0 stopped, 1 zombie

  PID USER     S  %CPU   RES     TIME+   K   D COMMAND
  101 root     R  62.5    75   1:05.25   3   1 Daemon-2
  100 user     Z  37.5     0   0:41.80   1   2 Daemon-1
```

- **When it shows.** Derezzed in a match, from that moment until you respawn (the 3-second respawn delay), the table is up across the top of your screen; your camera does what it always did. Hold Tab (rebindable in Settings, Controls, where it reads "top"; never a Ctrl+Alt chord) to see it any time, alive or dead, alone or in a match. While the round's break summary is up, the summary has the screen and the table waits; the menu, the multiplayer panel and a text box take it over too. While both are up, the death banner sits just below the table as one smaller line ("[ DEREZZED by ... ]   respawn in ..."), clear of the guide's panel and the kill feed.
- **The header.** `top - <round clock> up <time since the match started>, <N> users, load average: a, b, c`, the load being the match's kills in the last 10, 30 and 60 seconds of play, then `Tasks: <total> total, <r> running, <s> stopped, <z> zombie`.
- **The columns.** PID: a game number by join order, from 100. USER: `user`, or `root` while C22's root is on. S: R alive, Z derezzed, T while that player's SIGSTOP is on, where your game knows it (the host knows everyone's, a joiner only its own). %CPU: that player's share of the damage dealt this round. RES: health, rounded up. TIME+: time alive this life, as m:ss.hh. K and D: kills and deaths. COMMAND: the in-game name. Sorted by kills, then %CPU, highest first, like top sorts by CPU; your own row in reverse video and always shown.
- **Alone,** the rows are you and the arena's four dummies as daemon processes, `dummy-1` to `dummy-4`, Z while one derezzes and grows back.
- **Once a second.** The table refreshes like top, not every frame.
- **In a match every number is the host's.** Health, deaths, root and names come from what every player already gets. The rest is history a player who joined late never saw, so the host sends it: one new message once a second (never faster), with each player's game PID, kills, deaths, damage dealt and time alive, and the match's uptime and load. Your game shows them as sent and `-` for anything it has not been sent yet; it never makes a number up. The wire is protocol 8 (9 since C25's grep marks); a game still on protocol 7 is refused with the usual "version mismatch: host 8, you 7". The relay carries it like any other message and is otherwise untouched.
- **All numbers in one place.** `resources/spectate_top.tres` (a SpectateTopTuning): the 1.0 s refresh, the 10, 30 and 60 s load windows, 8 rows at most, PIDs from 100.
- **Seen headless only.** No window has shown the table yet; the layout is checked at 1280x720 and 960x540 by its rectangles.

The test, `tests/spectate_top_test.gd`, covers the resource, the record's rules, top's columns and order, the rebind, solo play in the real arena and a host and a joiner over 127.0.0.1.

### Built: daemons fight back (C27b)

Fred's first windowed playtest asked "Will the monsters fight back at some point?" They do now. Alone in the arena you have 100 health, and every daemon hunts you.

- **Every attack has a tell.** A daemon never strikes without warning, and the tell always reads: **rogue.d** rears up, front legs and scythes high, trembling (0.6 s), then lunges and slashes; **the zombie** raises a claw at you with its ember pulled out of its ribs into the claw, swelling and burning brighter (0.7 s), then throws a slow amber glitch bolt you can sidestep (a real projectile at 9 m/s, never a hitscan); **the runaway swarm** circles you and pulls into a tight, bright ball (0.45 s) before each dive, three dives a burst, each chipping 5, and any hit scatters it and ends the burst. If you break line of sight or step out of reach during a tell, the strike never comes.
- **They hunt by sight.** A daemon sees you within 16 m with nothing of the level between its eye and you, hunts you, goes to the last place it saw you when you break line of sight, and gives up after 2.5 s. It never chases more than 14 m from its spot: past that it walks home. Shooting one rouses it whatever the range. Nothing hits you through a wall: the tell starts only with you in sight, the strike only if you still are, the slash checks the wall again, and a bolt stops on the first thing it meets.
- **Fair numbers.** At most two daemons are in a tell or a strike on you at once; the others circle and wait. SIGSTOP (F) freezes them whole, their tells and their bolts in the air too, and they carry on at SIGCONT. Spawn protection holds against them.
- **Death and respawn, the match's way.** At zero you derezz where you stand, the banner names what got you ("DEREZZED by rogue.d"), and after 3 s you are back at the spawn point farthest from the daemons, full and protected for 2 s: the match's own numbers and flow. A hit flashes red and presses a red vignette in from the screen's edges, which stays faintly on while your health is low; with screen shake on the view jolts too. Nothing warps the picture. Your deaths count in the round's numbers, so the announcer and the roast see them.
- **Difficulty.** Settings, Gameplay: easy (0.6x damage, slower to attack again), normal (the default) or hard (1.5x damage, quicker). The tells never get shorter.
- **Practice.** The same screen's **practice** switch keeps the old daemons that never attack (and hides your health), for testing a weapon in peace.
- **In a match the host runs them.** The host's daemons hunt every player, the host judges every daemon hit with the match's combat (no kill credited), and every player's shots at a daemon are judged by the host too; joiners only draw the daemons, their tells, lunges, dives and bolts, from the host's word. The host's practice and difficulty are the match's. A joiner's own hits on a daemon get their hit marker and a kill its credit from the host's word. Protocol 10: four new messages (the daemons' state, each bolt, each daemon hit, a joiner's own hit on one), since no earlier message carried a daemon.
- **Fair hit volumes.** rogue.d's hit volume is now a box round its whole body, head to tail, turning with it, beside the old cylinder. The zombie's ghosts are its past, not hittable, and the swarm's cloud stays inside its cylinder.
- **All numbers in one place.** `resources/daemon_ai.tres`, a DaemonAiTuning: sight, leash, the cap, each type's tell, strike, damage, speeds and waits, and the difficulty's multipliers.
- **Steering, not a navmesh.** The arena is one open floor with a dozen blocks and the daemons only chase what they see, so a straight seek with feelers and a wall slide is enough; a daemon never paths round the lair to find you.
- **Seen in stills and headless only.** Nobody has played it in a window yet: the feel of the tells and the damage numbers wait for a playtest.

### Built: ICE, white and hunter (I1)

A community prompt by Tim Provencio ([@TimProvencio](https://x.com/TimProvencio)): ICE, William Gibson's intrusion countermeasure electronics, a new enemy class beside the daemons. The daemons are rogue processes; ICE is the system defending itself against you, the intruder. Its HUD carries the tag "ICE design: @TimProvencio".

- **White ICE walls (from round 1).** Two walls of faceted crystal seal the arena: the gate fills the room's doorway (2.7 by 3.5 m, rogue.d's lair sealed until it breaks), and a wider wall closes the west corridor's north end (4.8 by 3 m). A wall stops you, the daemons, their sight and their bolts like any wall, and every shot, pellet, dart, slug and blast lands on it. It takes 600 damage to break, and no one hit takes more than 100 off any piece of ICE (the rail's 1000 too). It cracks as it goes: each pane's fracture lines spread across it, some panes break out of the lattice and fall, and the last point shatters the whole wall in glacier shards. The way is open for the rest of the round; a new round builds it again.
- **White ICE nodes, two fields (from round 1).** Two crystal sentinels guard the walls. Each has a tell you can read before anything happens: an intruder in sight within its trigger range (9 m for the jam node, 10 m for the HUD node) starts it, the node's shields spread and spin up, its heart burns brighter, a rising crystalline swell plays from it, and a dome of lattice light flickers in at exactly the field's reach. The tell lasts 1.2 s (jam) or 1.4 s (HUD), never under a second. Then the field fires on everyone inside the dome and in sight of the node:
  - **Jam** (7 m): the weapon in your hand jams for 2.5 s. It cannot fire; swap and the others fire as usual. The HUD says which weapon and for how long.
  - **HUD corruption** (8 m): for 4 s the status line, the round line, the weapon strip, the sudo badge and the kill feed scramble under glacier glyph noise that tears and flickers. Your health line is never covered.
  - Step out of the dome or behind cover during the tell and nothing lands. A node then waits 7 s (jam) or 9 s (HUD), shorter on hard, longer on easy, as the daemons' waits are. Each has 150 health; break it and its field is gone for the round.
- **Hunter ICE (from round 2).** One hunter at a time, from its post on the east side. It hunts by sight like a daemon (the same brain, C27b), but it is a hunter: it sees you from 26 m, has no leash, keeps its distance at 9 m, and searches the last place it saw you for 6 s before going back to its post. Its attack is the **lance**. Within 16 m, in sight, it tells for 1.3 s: its shields swing round to its nose into an iris, its heart burns, and a cobalt trace reaches from it to you, following you, until the last 0.35 s, when the trace holds still and flashes. That is the moment to step aside. The lance fires along the held line, up to 22 m or the first wall, and hits whoever is within 0.55 m of it for 24 (scaled by the difficulty). Then it waits 3.2 s. A ping meeting it mid-tell staggers it, as it does a daemon. It has 300 health; killed, it is gone for 15 s, then a new one comes from its post.
- **It adapts.** The system notes which weapon hits it hardest. Every hit that lands on a daemon or on ICE counts, each up to the 100 cap (so a rail kill counts 100, a cannon hit 25), and the hunter resists the weapon with the most damage this round: up to 50% less damage from it once that weapon has dealt 500, never immunity. The HUD shows it ("HUNTER ADAPTED: cannon -34%"), and the hunter's shields and their spines shift from cobalt toward that weapon's own colour. Switch weapons to beat it. A new round forgets it all.
- **Practice and the ICE setting.** Practice turns ICE off along with the daemons' attacks, and Settings, Gameplay has its own **ICE** switch beside the difficulty (on by default) to play against the daemons alone. Either way there is no wall, node or hunter at all.
- **In a match the host runs it.** The host builds every piece from its seeds, judges every shot, blast and field, and sends its word to every joiner at the sync rate: each piece's seed, health and state, the hunter's place, aim and adaptation. A joiner's own shot lands nothing on its copy; the host's judging of it does. A field that reaches a joiner jams that joiner's weapon on its own screen, and the host refuses that weapon's shots until the jam clears. The host's practice and ICE setting are the match's. Protocol 12: two new messages (ICE's state, a field's effect on one player), and the rules carry ICE on or off (26 RPCs in all).
- **Hooks for what came next.** Every hit carries its source (the weapon's id), so I2's ICEbreakers add their own: the brute's harder hits on a wall go through the director's hook. Each piece marks its weak points (the wall's lock and joints, a node's heart and rings, the hunter's heart), as A5's daemons do, and I2's exploit aims at them; see [Built: ICEbreakers](#built-icebreakers-i2).
- **All numbers in one place.** `resources/ice.tres`, an IceTuning: the walls, the cap, both nodes, the hunter, the adaptation.
- **Seen in stills and headless only.** Nobody has played ICE in a window yet: the feel of the fields, the lance and the numbers wait for a playtest.

### Built: ICEbreakers (I2)

Tim Provencio's prompt ([@TimProvencio](https://x.com/TimProvencio)), its second half: one-use programs you carry against ICE, beside your weapons, never in a weapon slot or on the 1 to 9 strip. Four kinds. Each round starts you with one of each, and you carry at most two of a kind. **U** runs the loaded one, **Y** loads the next kind you hold (both rebindable; the brief asked for H, but H is the multiplayer panel's own key, kept off every action, so the run is on U beside Y).

- **brute.** A short charge thrown from your eyes along your aim: what stands within 4.5 m inside a 40 degree cone takes it, full strength within 2.25 m and half at 4.5 m. A white ICE wall takes five times the charge, 600, so up close a whole wall breaks in one go (from 3.4 m it is left at a quarter). A node or the hunter takes a hard 120 (a node's 150 nearly gone, the hunter's 300 far from it), and so does a daemon in front of you. The hunter never adapts to a breaker. It is an attack: it ends your cloak.
- **exploit.** For 6 s your hits on weak seams land 2.5 times harder: a daemon's seams, visor and core, a wall's lock, rings and joints, a node's heart and rings, the hunter's heart (A5's and I1's weak points). Only direct hits count (the cannon, SIGTERM, the rail, `fork()`, `grep`), never a blast, and the bonus comes after ICE's cap, so the rail's 1000 on a wall's seam lands 250. While it runs every seam in the arena carries a pulsing ultraviolet diamond on your screen, so you see what to aim at.
- **cloak.** For 5 s neither ICE nor the daemons can see you: a node never starts its tell on you and its field never reaches you, and the hunter and the daemons lose you, going to where they last saw you and then home. A tell already on you ends with nothing thrown; a lunge, a bolt or a lance already loosed still lands. Any shot or throw ends it at once, and so does a brute. The screen tells you: "CLOAKED 4.9s  firing ends it" under the crosshair, the screen's edges washed ultraviolet, both blinking through its last second.
- **decoy.** Throw it along your aim (it arcs and settles where it lands; aim at the floor to drop it at your feet). Once down it calls for 7 s, an effigy of your signal: the hunter goes after it from anywhere within 26 m, even mid-tell on you (its trace swings to the decoy and its lance is judged on the decoy, never on you), every daemon within 26 m whose leash allows goes after it, and a node with the decoy inside its trigger range tells on it and spends its whole field on it, reaching no one. What strikes it only flashes it. That is the escape: it buys you seven seconds while everything hunts the wrong thing.
- **Pickups.** More lie in the arena mid-round: the first 15 s in, then one every 20 s while fewer than two are out, at one of six spots (one inside rogue.d's room, behind the gate), each a split ultraviolet crystal over a plinth with its kind's emblem and name and a beam of light standing from it so you see it across the arena. Walk over one to take it, unless you already carry two of that kind; then it waits for someone else. A new round clears them.
- **The readout.** Bottom left, over the `user$` badge: the loaded breaker with its key and count ("U BRUTE 1", dimmed with none left) and every count by its initial, the loaded one bracketed ("Y [b1] e1 c1 d1"), with a short notice over them when one runs, is empty or is picked up. Not beside the weapon strip: at 960x540 the room over the strip is the kill feed's and the guide panel takes the room to its left, so the strip keeps its whole column for the second weapon bank C29 adds.
- **Your AI picks which to load.** Between rounds and when you press T, the AI guide gets the round's numbers and nothing else (how many ICE walls and nodes stand and their health, whether the hunter is out with its health, the weapon it has adapted to and how far, your breaker counts, the round) and names the breaker to load. On T every question carries those numbers, and Enter with nothing typed asks for the pick alone; at a round's end its one call carries them, and the summary panel shows its pick. With the AI off, busy or silent, the scripted guide picks from the same numbers: a decoy for a hunter that has adapted, exploit for a hunter out, brute for walls standing, cloak for nodes standing.
- **Practice and the ICE switch.** Practice turns breakers off: no readout, no pickups, U and Y do nothing. The ICE switch does not: with ICE off they still work on the daemons (exploit's seams, cloak, the decoy's pull, the brute's charge).
- **In a match the host runs them.** Your U is an ask the host judges, from where it last heard your eyes; it refuses one you hold none of. The host keeps everyone's counts, runs every effect in its world, ends your cloak when it accepts your shot, and sends each joiner its own word at the sync rate: its counts, its exploit and cloak, every decoy, every pickup, the last brute charge, its own last run and pickup, and every decoy's and pickup's seed. Protocol 13: two new messages (the ask and the word), 28 RPCs in all.
- **Seen in stills and headless only.** Nobody has played the breakers in a window yet: the numbers wait for a playtest.

### Built: Black ICE (I3)

The third tier of Tim Provencio's ICE ([@TimProvencio](https://x.com/TimProvencio)): the machine's last line of defence. Rare and frightening, never a bigger health bar.

- **Rare.** Never in round 1, at most one a round. From round 2 its chance is rolled once each round: 20% in round 2, 10 points more each round after, 40% at the most from round 4 on. When it comes it arrives 20 to 40 s into the round's play (the round's own clock, which stops while you are away), at whichever of five open spots is farthest from every player. Demo, test and capture runs fix the roll and the moment by the round (it comes in rounds 3, 4, 5, 9 and 11 of that fixed plan); in play every round rolls anew, and in a match the host rolls.
- **Its arrival is an event.** Six seconds of warning before it can touch anyone, on every screen: "B L A C K   I C E" flickering in, centred high, over "the machine's last defence: weapons only flash it, its touch flatlines" and a countdown with its distance; the arena's lights dying over the first two seconds to a tenth of themselves (the strips, signs, screens, holograms, floor, the walls' rain, the skyline, the sun, the lamps, the lair's danger lights and the sky; its own light, the daemons', ICE's, your weapons' and the HUD stay); the arena's low hum dropping out with them; your AI's link shown cut ("your AI: LINK CUT", flickering, "NO CARRIER   Black ICE on the line"); a deep falling tone; and the thing itself forming out of the floor at its spot, a dashed ring of cold light first at the reach of its touch. All of it comes back when Black ICE is gone. The cut is only what the HUD shows: no AI call is made or cancelled because of it, T still asks and an answer still shows.
- **It hunts.** By sight, from its core high over the low cover, out to 45 m, with no leash, straight at you at 4 m/s; you run at 7. It keeps the place it lost you for 6 s, and with no one in sight it drifts toward the nearest player it is not hidden from at 2.4 m/s: hiding buys time, never the round. A low drone comes from it, and while it is out the HUD shows "BLACK ICE   seals 2/2   14 m" top centre, a tag over it (at the screen's edge with an arrow when it is behind you), and the screen's edges going cold and dark as it comes within 12 m.
- **Touch it and you flatline.** Your middle within 1.65 m of its axis (its body's 1.25 m and your 0.4) is a flatline, cloaked or not (the cloak hides you from its sight, never from its body). Never through spawn protection, and never in its arrival's tell. Alone the run is over: the round ends at once as a loss, the screen darkens behind a red summary headed "FLATLINED by Black ICE   RUN OVER", and the next round is round 1 again. In a match you are out for the rest of the round: the host holds you down until its next round starts, and you watch as `top` meanwhile ("FLATLINED by Black ICE   out until the round ends").
- **Weapons only flash it.** Every shot, pellet, dart, slug and blast flashes its edges and sprays a few shards, and takes nothing: no hit counts, and the hunter learns nothing from it. Exploit's bonus on its seals is still nothing.
- **Only the ICEbreakers deal with it.** It has two seals, rings of cold light crossing round its core (exploit's marks show them). A brute charge that reaches it while your own exploit runs breaks one: it reels back 3 m along the charge for 1.2 s, and the HUD calls "SEAL BROKEN   1 left". Breaking the last kills it ("BLACK ICE DOWN", a burst of its parts). A broken seal mends after 12 s. So a kill takes a plan: two brutes inside one exploit's 6 s, or exploit and brute twice inside the mend, and getting within the brute's 4.5 m of it. A round starts you with one brute: you need a pickup or a teammate. A brute without exploit only flashes it.
- **There is always a way out.** A decoy pulls it off you from anywhere within 26 m and holds it while it calls (7 s); a cloak hides you from it as from the hunter; and it is always slower than your run.
- **Your AI and the scripted guide.** While it is out, a question on T carries its numbers (out, seals standing, how far it is, whether it flatlined you this round: numbers only, in the whitelist) with the game's own line asking for the decoy or the combo, and the round's one call carries them at its end. The scripted guide's word stands under its HUD line: the combo when you hold an exploit and enough brutes for its seals, else the decoy, else the cloak, else run.
- **Practice and the ICE switch** both turn it off.
- **In a match the host runs it.** The host rolls it, steps it, judges every touch and every combo (a joiner's exploit and brute asks too, from where the host last heard its eyes), and sends its word inside ICE's own word at the sync rate, so it never runs out of step with the rest of ICE. Protocol 14: no new message (still 28 RPCs and 31 sends), ICE's word longer and a death cause of its own.
- **All numbers in one place.** `resources/black_ice.tres`, a BlackIceTuning: its rarity, its arrival, its body and touch, its movement, its seals and its withdrawal.
- **Seen in stills and headless only.** Nobody has played Black ICE in a window yet: how frightening it is, and its numbers, wait for a playtest.

## Your AI in the game

> **Status: Built** (M2 done). **Built:** the AI source detector (C9), the agent adapters (C9b), the boot screen that uses them (C10), the guide HUD in the arena (C11), loading a local model with your yes (C11b), and between-round coaching with the opt-in roast announcer (C12). The rest of this section describes the design Fred decided in PRD 5.4.

Your guide is not a character a studio wrote. It is the coding agent you already picked in Omarchy, the same one that has been reading your diffs. SIGKILL finds it, names it on screen, and lets it talk to you while you play. Most players don't have local hardware strong enough for a good local model, so your Omarchy default agent comes first and a local model server is the fallback.

### Finding your AI

```mermaid
flowchart TD
    Boot["Game boot"] --> Choice{"AI turned on?"}
    Choice -->|"no"| Scripted["Scripted guide<br/>AI off"]
    Choice -->|"yes"| Setting["Read Omarchy's default-agent setting<br/>one line, read-only"]
    Setting -->|"agent with an adapter"| Adapter["Agent adapter<br/>the agent's own non-interactive CLI<br/>tools, edits and shell disabled<br/>no auto-approve flags"]
    Setting -->|"unset or unknown agent"| Local["Model server on localhost<br/>Ollama, LM Studio or any<br/>OpenAI-compatible endpoint"]
    Adapter -->|"answers the handshake"| Guide["Your AI is the guide"]
    Adapter -->|"fails"| Local
    Local -->|"found"| Guide
    Local -->|"none"| Scripted
```

1. **The source of truth is Omarchy's own setting.** Omarchy stores the default agent as a single line in its config, the same value `omarchy-default-agent` prints. SIGKILL reads that one line and nothing else. Omarchy leaves it unset by default, and an unset or unknown value simply falls through to the next step.
2. **Each agent gets a small adapter behind one common interface.** Claude Code and Codex adapters ship first; others follow. An adapter calls the agent's own non-interactive mode directly, for example `claude -p`, or `codex exec` in a read-only sandbox, with tools, file edits and shell disabled and no auto-approve flags.
3. **The fallback is a model server on localhost.** Ollama, LM Studio, or any local OpenAI-compatible endpoint. Localhost only, never a remote host.
4. **The last resort is a scripted guide.** It is also exactly what you get with the AI turned off.

### Built: the AI source detector (C9)

`scripts/ai/ai_source_detector.gd` answers two questions with no UI: which AI can this player's game talk to, and what GPU stats can it show. It returns a typed result, `scripts/ai/ai_source_result.gd`, made only of fixed words, known agent names and numbers. The boot screen (C10) calls it.

- **The agent setting.** It reads only the first line of Omarchy's default-agent setting, at most 256 bytes, trims and lowercases it the way Omarchy's own reader does, and checks it against the 13 agents Omarchy can name. A listed name is kept. Anything else is "unknown" and its value is dropped. A missing, empty, unreadable or binary file, or a first line over the cap, counts as unset. It never runs `omarchy-default-agent` or `omarchy-agent`.
- **The agent's command.** For a listed agent it looks along your PATH for a file of that name with an execute bit. It never runs it, not even with `--version`, and it never reads it.
- **Local model servers.** One short GET each to Ollama on port 11434 and an OpenAI-compatible server such as LM Studio on port 1234, on 127.0.0.1 only. The host is a constant, not a setting. A small reader of its own takes the answer, capped at 1 MiB with the deadline checked on every step, and refuses anything truncated, chunked, malformed or not valid text. A JSON scanner of its own then counts the models without ever reading a name as text, so nothing a server sends can make the game print, and nothing about a model is kept but the count. It keeps only whether each answered, how fast, and how many models it lists; model names are counted and dropped, never kept or printed. It never loads, pulls or unloads anything, and never touches a model setting.
- **GPU stats.** It reads a few named /sys attributes first. Only if none answer does it run `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits`, exactly those arguments, with no shell, and only from its fixed system location, never from whatever the PATH finds first. That runs through a non-blocking pipe with a deadline: an nvidia-smi that hangs is left to exit on its own, never killed, and no second one starts until it has. GPU stats are read at most once a second, across every detector in the game. With neither source, the result says so, and the HUD will hide GPU stats.
- **The choice.** Your default agent if it is a listed one and its command is on your PATH; otherwise Ollama, then an OpenAI-compatible server, each only if it lists at least one model; otherwise the scripted guide, "AI off".
- **Never on the main thread.** The probes can wait up to half a second each, so `start()` runs the detection on a worker thread and the game polls `is_done()`. A detection can be cancelled, and dropping a detector mid-run cancels its worker, which stops within about a millisecond.

The test, `tests/ai_detector_test.gd`, uses fakes only: the fixtures under `tests/fixtures/ai`, stub programs, and a fake model server on a random local port. No real agent is called, no real model server is reached, and the real nvidia-smi never runs.

### Built: agent adapters (C9b)

The guide talks to your AI through one interface, `scripts/ai/guide_adapter.gd`. The boot screen (C10) uses it for the handshake; the guide HUD (C11) will use it in play. Every adapter has `is_available()`, a non-blocking `ask()` that the game then `poll()`s once a frame, and `cancel()`, and every answer has one shape: `{ok, text, error_kind, latency_ms, tokens_per_sec}`. `scripts/ai/guide_registry.gd` maps the detector's choice (C9) to an adapter: Claude Code or Codex if that is your default agent and its command is on your PATH, otherwise Ollama, then another OpenAI-compatible server, otherwise none, which means the scripted guide. The other agents Omarchy can name have no adapter yet, so they fall through to the local server the same way.

- **What gets sent.** `scripts/ai/guide_request.gd` builds every request from a whitelist of game stats (shots fired, hits landed, kills, deaths, streak, targets left, accuracy, round time, weapon and mode), each checked against its type and range, plus what you typed, cut to 500 characters with control, direction-changing and invisible characters removed. Any other key is dropped, so a path, a host name or a process name cannot get in by accident. A fixed preamble tells the agent it is the in-game guide and must not use tools, read or write files, or run commands.
- **Claude Code**, `scripts/ai/claude_adapter.gd`. The `claude` command found on your PATH, then exactly:

  ```text
  -p --tools "" --permission-mode dontAsk --permission-prompts none --strict-mcp-config
  --safe-mode --disable-slash-commands --no-session-persistence --output-format text
  --system-prompt <preamble> <game stats and your text>
  ```

  Print mode, every tool off, anything that would ask for permission denied, no MCP server, and no CLAUDE.md, skill, plugin, hook or custom agent loaded; the session is not saved. `--system-prompt` replaces Claude Code's default system prompt, so the default prompt's per-machine parts (working directory, environment, git status) are never sent. Never `--dangerously-skip-permissions`, `bypassPermissions`, `acceptEdits` or `--allowedTools`. Each flag and the `claude --help` line behind it is listed at the top of the file.
- **Codex**, `scripts/ai/codex_adapter.gd`. The `codex` command found on your PATH, then exactly:

  ```text
  exec --sandbox read-only --skip-git-repo-check --ephemeral --ignore-user-config
  --ignore-rules --color never --disable shell_tool --disable unified_exec
  --config include_environment_context=false
  --cd <empty scratch folder> --output-last-message <answer file> <preamble, game stats and your text>
  ```

  A read-only sandbox, the shell tools switched off, no session files, none of your Codex config or rules files loaded, and no environment note (Codex would otherwise add its working directory, shell and date to the prompt). Never `--full-auto`, `--dangerously-bypass-approvals-and-sandbox`, `workspace-write` or `danger-full-access`. Codex reads piped stdin to its end, so the game closes stdin at once; in Godot's pipe that also closes Codex's stdout, so the answer is read from the `--output-last-message` file, which is emptied before every launch. Each flag and the `codex exec --help` line behind it is listed at the top of the file.
- **How an agent is launched.** `scripts/ai/guide_process.gd` is the one place the guide starts a program: the absolute path the detector found, an argument array, never a shell and never `omarchy-agent`. The prompt is a single argument. Codex's working root is an empty folder in the game's own data folder, `user://guide/workdir`, checked empty before every launch. Output is read without blocking and capped at 64 KiB; the answer is stripped of ANSI escapes and control bytes and cut to 600 characters. A request still running after 60 seconds is stopped.
- **Stopping only its own child.** On a timeout, a cancel, or the guide being freed when the game exits, the game stops the agent process it launched itself, by that process's own PID and only while it still runs, and Godot reaps it. It never signals any other process.
- **The local server**, `scripts/ai/local_openai_adapter.gd`. 127.0.0.1 only; any other host, even `localhost`, is refused. It uses only a model that is provably loaded already. On Ollama it asks `/api/ps`, which lists loaded models only. On an OpenAI-compatible server it asks LM Studio's own API, which says per model whether it is loaded: `/api/v1/models` (LM Studio 0.4 and later), then `/api/v0/models`. Only a chat model counts there (type `llm` or `vlm`), never a loaded embedding model. It never trusts the OpenAI-style `/v1/models` for this, because with LM Studio's just-in-time loading on, that list holds every downloaded model and a chat request for one of them loads it. If nothing is loaded, or the server cannot say, it returns `needs_consent` and sends nothing more: it never loads, pulls, deletes or unloads a model. The chat request is one `POST /v1/chat/completions` with only `model`, `messages`, `stream: false` and `max_tokens`, never `num_ctx` or `options`. The model's name lives in memory for that one request only. Tokens per second come from the server's own `usage` count, or -1 when it sends none. Its HTTP client, `scripts/ai/local_http.gd`, and JSON reader, `scripts/ai/quiet_json.gd`, are its own, capped and quiet, so nothing a server sends can make the game print.
- **Pacing.** One request in flight per adapter, at most one start every 10 seconds, and an `ai_enabled` switch that answers `ai_off` at once. It ships off. Every number is in GuideTuning, `scripts/guide_tuning.gd` with `resources/guide.tres`.
- **Known gaps, stated plainly.** Godot cannot set a child process's working directory, so Claude Code runs in the game's own working directory; it has no tools to look at it, and the default system prompt that would name it is replaced. The Codex feature names `shell_tool` and `unified_exec` come from third-party documentation, and the `include_environment_context` key from the field names inside the installed Codex binary, not from `--help`; if Codex rejects a feature name the call fails safely, and whether the key really silences the environment note is untested. Codex can still read your own global Codex instructions and skills; its `--help` offers no switch to stop that, and the game never reads or sends them. Ollama's `/api/ps` does not say whether a loaded model can chat, so if the first one loaded is an embedding model the answer fails instead (it still never loads anything). A local OpenAI-compatible server other than LM Studio cannot prove what is loaded, so it gets `needs_consent` until the consent step exists (C10/C11). `--ignore-user-config` also means a Codex model or provider set in your own config is not used. Nothing here has been tried against a real agent or model server yet; that needs Fred's yes.

The test, `tests/guide_adapter_test.gd`, uses fakes only: stub `claude` and `codex` scripts under `tests/fixtures/ai/guide` and a fake model server on a random local port.

### Built: boot sequence (C10)

SIGKILL now opens on a boot screen, `scenes/boot.tscn` with `scripts/boot/boot_sequence.gd`, and moves on to the arena when it is done. Esc or Enter skips straight to the arena at any point. Nothing on it waits on the main thread: the C9 detector runs on its own worker, the adapter is chosen on a worker too (the registry looks the agent's command up along your PATH), each GPU reading runs on a short worker thread of its own, the handshake adapter is polled once a frame, and the arena loads in the background. Leaving never waits either: it cancels the detector and hands anything still running to a small node that joins it once it has ended.

What a first launch with Claude Code looks like, written out by hand from the screen's own lines and the demo answer. It is not a capture, which needs a window:

```text
SIGKILL boot
Omarchy default agent: claude. Linking...
Allow SIGKILL to call claude? It gets only game stats and what you type.
[Y] allow   [N] keep AI off
Allowed.
> Link up. Daemons detected. Let's go hunting.
answered in 842 ms
Entering the arena...
```

- **The lines.** The agent line follows the C9 detector: your default agent by name; "not set" or "not one SIGKILL knows", said plainly; an agent whose command is missing, or that has no SIGKILL adapter yet, says so. When the C9b registry falls through to a local server: "Local model server found. Linking...". With no AI: "AI off. Scripted guide online." The GPU readout sits top right, utilisation, VRAM and temperature, read at most once a second through the C9 reader and hidden when there is no source.
- **Asking first.** Before the first call to an agent or a local server, the screen names it, says what it gets ("only game stats and what you type"), and waits for Y to allow or N to keep the AI off. Plain keys only; a Ctrl, Alt or Super chord is ignored. `scripts/boot/guide_settings.gd` keeps the answer in the game's own data folder, `user://settings.cfg`. It counts only for that agent or server, so a different one is asked again, and a damaged file means one more question, never a call without a yes. No yes, no call: the guide's AI switch is turned on only on the screen's own copy of the guide tuning, and only after a yes. In the arena, O changes it (C11).
- **The handshake.** One request through the C9b registry and request builder, with a fixed prompt and no player data at all (its stats line reads "Game stats: none"). A "thinking" spinner runs while it waits; then the answer and its latency, plus tokens per second from a local server. A timeout or an error shows "No answer from <agent> (<reason>)." and the scripted guide. A local server with nothing loaded shows "Local model available, not loaded." and how to load one: "Press T in the arena to load one." for Ollama (C11b), "Load one in your local server's own app." for any other server. The boot screen never loads anything itself.
- **Only SIGKILL's own words on screen.** The handshake prompt asks the AI to reply with exactly one of five fixed SIGKILL lines, such as "Online. Daemons beware.", and the screen shows SIGKILL's own copy of the line it picked, or "Link up." for anything else. So the AI shows it is answering live, but its own words, which could name a person, a machine or a model, never reach the screen. The local adapter also replaces the loaded model's name in its answers. Agent names come only from the detector's known list, and error reasons only if they are short lowercase words.
- **The headless guard.** In any headless run, or with the `--no-ai` argument, the boot screen never makes a real detector and never asks the registry, whatever was saved, so no agent is launched and no model server is contacted. A headless run with nothing handed in goes straight to the arena, which keeps `scripts/check.sh`'s 300-frame run real-call-free while it still runs the arena. Traced with strace: no network connection at all.
- **Demo-data mode**, for screenshots and trailers: `godot --path . -- --demo`. Agent "claude", fake GPU numbers, a canned answer and latency, and no detector, no settings file, no process and no network.
- **Tuning.** Typing speed, pauses, the spinner, the demo timings, the GPU interval (never under a second), the wait before the arena, text sizes and colours are in BootTuning, `scripts/boot/boot_tuning.gd` with `resources/boot.tres`.
- **Seen headless only.** No window has shown it yet, and no real agent or model server has been called from it; the first real call waits for Fred's yes.

The test, `tests/boot_sequence_test.gd`, uses fakes only: a spy detector, the C9 detector pointed at the fixtures and a fake model server on a random local port, and a stub adapter.

### Built: guide HUD (C11)

In the arena, `scripts/hud/guide_hud.gd`, built by `scripts/hud.gd`, shows that the guide is your own AI. It keeps the session's link to your AI, `scripts/guide/guide_link.gd`, which the boot screen hands over, so the boot handshake's adapter, pace and call count carry on into the arena, and an R reload keeps them too.

- **Top right.** A badge: "your AI: claude" (or codex: the name from your Omarchy setting), "your AI: local" for a local model server, or "AI off". Under it, the last call's latency; tokens per second only when a local server answered and reported its own token count, never estimated; the GPU readout, at most once a second and hidden with no source; and a status line: the keys, a "thinking" spinner while your AI works, "Next ask in N s." or "Limit reached".
- **Ask anything: T.** Opens a one-line box of up to 160 characters. While it is open the mouse is free and the game takes no input at all: no moving, jumping, firing or looking, R does not reload, and the click that would grab the mouse does nothing. Enter sends and Esc cancels; either way the mouse is captured again only if it was before and the window still has focus. What you typed goes out through the C9b request builder with a few game stats (shots, hits, accuracy, kills, targets left, round time, weapon and mode) and nothing else.
- **Your AI's own words.** This is the one place they reach the screen, because you asked: in a panel titled "your AI (claude) says:", as plain text in a Label (BBCode or any other markup shows as typed, never parsed), with escape sequences, control and invisible characters stripped, and cut to 420 characters and 6 lines. A timeout or an error shows a fixed SIGKILL line instead. A local server with nothing loaded says "Local model available, not loaded.", keeps saying it on the status line until a model answers (T checks again), and nothing is loaded without your yes: on Ollama, T then offers to load one (C11b).
- **Rate limits you can see.** One question at a time, at most one every 10 seconds (the guide tuning's minimum interval), and at most 40 AI calls in a game session, the boot handshake included. A refused T says why instead of doing nothing.
- **AI on or off: O.** Off at once: no calls, "AI off", and the same opt-in setting the boot screen uses (`user://settings.cfg`) records the no; even if the file cannot be written, the answer holds for the session. On asks first, by name, with what it gets; Y allows, N or Esc keeps it off.
- **The same guard and demo.** The headless guard lives in the link, so a headless run or a test never launches an agent or contacts a model server from the HUD either, whatever was saved. `godot --path . -- --demo` fills the HUD with fake values: claude, fake GPU numbers, a canned answer and its latency, with no reads, launches or network.
- **Tuning.** Margins, panel width, text sizes, the caps, how long answers and notices stay up, the session cap, the spinner and GPU pace, the demo values and the colours are in HudTuning, `scripts/hud/hud_tuning.gd` with `resources/hud.tres`. The layout is checked to fit at 1280x720 and 960x540.
- **Seen headless only.** No window has shown it yet, and no real agent has answered in it; that waits for Fred's yes.

The test, `tests/guide_hud_test.gd`, uses fakes only (the shared ones in `tests/support/guide_fakes.gd`), and checks the input blocking in the real arena with the real player.

### Built: loading a local model, with your yes (C11b)

When your fallback is an Ollama server that answers but has nothing loaded, the guide HUD offers to load one, and SIGKILL unloads anything it loaded itself. Everything that loads or unloads is in one file, `scripts/guide/ollama_loader.gd`, run by the session's link (`scripts/guide/guide_link.gd`) on a worker thread.

- **Only after you ask, only Ollama.** With the AI on and nothing loaded, the status line says "Local model available, not loaded.   T loads one". T re-reads Ollama's `/api/ps` first: if something is loaded by then, that is used and nothing is asked. Otherwise SIGKILL reads `/api/tags` and offers exactly one model: the smallest chat model under 8 GiB and, when the GPU readout knows your free VRAM, under that minus 1 GiB. Embedding models are skipped by name and family, and every candidate, smallest first, must pass `/api/show`: an answer that cannot be read rules it out, and listed capabilities must include chat ("completion"). If nothing fits, it says so and the scripted guide stays. If `/api/ps` cannot be read, nothing is offered or loaded, since SIGKILL could not tell what was there before. Other local servers (LM Studio, llama.cpp, vLLM) are never asked to load anything: the line tells you to load one in that server's own app.
- **The question.** "Load fixture-chat-small (2.0 GB) on your local server?" with `[Y] load   [N] keep AI off`; Esc counts as N. On your own screen the real model name and size show, and nowhere else: never in a log, a file or the repo.
- **The load.** Y reads `/api/ps` once more and remembers what was loaded at that moment, then sends one `POST /api/generate` whose body is exactly `{"model": "<name>"}`: no prompt, no options, no `num_ctx`, no `keep_alive`. A "loading model" spinner runs; after 120 seconds it gives up and the scripted guide stays. Esc stops waiting.
- **The unload.** One `POST /api/generate` with exactly `{"model": "<name>", "keep_alive": 0}`, only for the model SIGKILL loaded itself, only if `/api/ps` still lists it, and never for a model that was already loaded when you said Y. It happens when you turn the AI off with O, and at the end of the session. SIGKILL keeps track of each model it loaded until the unload is answered or the model is gone, and retries a failed unload with a growing wait (up to 30 s). A load request that reached the server but that you stopped waiting for (Esc, O or the timeout) is watched and unloaded if it turns up; one that never reached the server is not, so a model another app loads later is left alone. Only one load job runs at a time, on a worker thread.
- **Session only.** Your yes to a load is not saved: each launch asks again.
- **The same guard and demo.** Under the headless guard SIGKILL loads on no server at all, except a fake one a test hands in, even with Y pressed. In demo mode, L shows the question with a fake model and a fake load, with no network.
- **Tuning.** The 8 GiB cap, the 1 GiB VRAM margin, the 120 s load timeout, the time allowed for the unload at exit and how often a stopped load is checked are in GuideTuning's Model loading group (`scripts/guide_tuning.gd`, `resources/guide.tres`): the guide's own tuning, shared by the boot screen and the HUD. The demo load's wait is in HudTuning.
- **Seen headless only.** No real Ollama server has been asked to load or unload anything yet; that waits for Fred's yes.

The test, `tests/model_load_test.gd`, runs the real loader, link, adapter, HUD and boot screen against a fake Ollama server with fake model names, and prints every request it saw.

### Built: round coaching and the roast announcer (C12)

The arena now plays in rounds, and at the end of each one your own AI looks at the numbers. The round loop is `scripts/round/round_hud.gd`, built by `scripts/hud.gd`; the round's numbers are `scripts/round/round_stats.gd`; the AI side is `scripts/round/round_announcer.gd`, which goes through the session's link (`scripts/guide/guide_link.gd`) like everything else.

- **Rounds.** A round is 90 seconds of play, shown under the daemon count: "ROUND 2   1:12 left   B roast: off". The clock runs only while you are playing (the mouse captured and the ask box closed), so stepping away pauses it and never costs an AI call. Then a 12-second break shows the summary panel, every dummy comes back, and the next round starts. Esc and every other key work as before.
- **The round's numbers, and only numbers.** One collector counts each round from the game's own signals: the cannon's shots and hits, each dummy going down, your jumps, slides and steps. The panel shows them, and the AI gets exactly these keys through the C9b request builder's whitelist: `round_number`, `duration_s`, `shots`, `hits`, `accuracy_pct`, `derezzes`, `longest_streak`, `time_to_first_derezz_s` (-1 if nothing went down), `distance_m`, `slides`, `jumps`. No names, paths, system details, model names or free text, and no typed message.
- **One call per round, at most.** At the round's end SIGKILL asks your AI once, counted against the same 10-second minimum interval and 40-call session cap as T. The panel shows "your AI (claude) is thinking" with a spinner. If the AI is off, a call is already out, it is too soon after the last call, the session cap is reached, or no AI is linked (always so in a headless run), there is no call and SIGKILL's own line shows instead, labelled "SIGKILL says (AI off):" and so on. A timeout, an error or an empty answer gets SIGKILL's line too. The next round never waits: if the break ends with the call still out, SIGKILL stops it and drops whatever it would have said. The round's call is only ever its own: if you turn the AI off and on and ask with T while it is out, SIGKILL leaves your T call alone.
- **Coaching, or a roast with B.** By default the AI is asked for one concrete tip drawn from the numbers. B turns the roast announcer on: the AI is asked for a short PG-13 roast of your play in this round, one or two sentences, about the play and the numbers only, never you as a person, no slurs and nothing past mild language. Both instructions are SIGKILL's own fixed words, added to the guide's preamble. The roast announcer is off by default, and B's choice is saved next to the AI opt-in in `user://settings.cfg` (`roast_announcer=on` or `off`); saving either one keeps the other.
- **Their words, as plain text.** The AI's line is shown under "your AI (claude) coaches:" or "roasts:", in a plain Label: escape sequences, control and invisible characters stripped, markup tags such as `[b]` dropped, all on one line, and cut to 240 characters.
- **The summary panel.** "ROUND 2 OVER   next round in 9 s", the numbers, and the line. While it is up, a long answer to T waits, its time on screen paused, and shows in full when the break ends, so the two panels never overlap; notices, the ask box and the AI question still show, under the summary.
- **Callouts are the game's, not the AI's.** During a round, short lines come from game logic only: "First process down.", "3 in a row." (every third hit in a row) and "10 misses in a row. Let the crosshair settle." At most one every 4 seconds, any sooner one dropped, each shown for 2 seconds. They never call the AI.
- **The same guard and demo.** Under the headless guard a round end calls nothing, whatever was saved. `godot --path . -- --demo` fills the summary panel with fake stats, a fake roast and a fake tip, and B flips the switch in memory, with no reads, launches or network.
- **Tuning.** The round and break lengths, the callout gap, how long a callout shows, the streak and miss thresholds, the 240-character cap and the layout are in AnnouncerTuning, `scripts/round/announcer_tuning.gd` with `resources/announcer.tres`. The layout is checked to fit at 1280x720 and 960x540.
- **Seen headless only.** No window has shown a round yet, and no real agent has coached or roasted one; that waits for Fred's yes.

The test, `tests/round_test.gd`, plays a scripted round with the real player and cannon in the real arena, and uses the stub adapter and fake clock from `tests/support/guide_fakes.gd` for every call.

### Why it never uses omarchy-agent

Omarchy ships `omarchy-agent` and `omarchy-agent-prompt` to launch agents quickly, and they launch them with skip-approval flags so the agent can act without asking. A game must never hand an agent that kind of power. SIGKILL calls each agent's own CLI itself, with tools off and approvals on. That restricted launch is one of only two things the game may ever execute; see [Safety and privacy](#safety-and-privacy).

### What gets sent, and what never does

| Sent to your AI | Never sent |
|---|---|
| Game stats: the few numbers T sends, and at a round's end only that round's numbers; with ICEbreakers carried, the round's ICE and breaker counts (I2), and Black ICE's (I3: out or not, its seals, how far, a flatline) | File names and paths |
| What you type into the chat key | Process lists |
| The boot handshake, and the opener's one call (C41): that the game is starting, and SIGKILL's own lines to pick from | System information of any kind |
| | Anything the opener or the machine-world features read |

The AI is opt-in on first launch, with a plain description of which agent will be called, and you can turn it off at any time.

### Cost, speed and model hygiene

- **Cloud agents spend your own subscription and take seconds to answer**, so SIGKILL uses them only where seconds are fine: the boot handshake, ask-anything, between-round coaching and opt-in roasts. It never calls them per frame or per second; fast in-fight callouts come from game logic. Calls are rate-limited and the HUD shows a "thinking" state.
- **With the local fallback** the game checks what is already loaded first, never changes shared model settings, never loads a model without asking, and unloads anything it loaded when it exits. Built for Ollama in C11b: see [Built: loading a local model](#built-loading-a-local-model-with-your-yes-c11b).

### Proof it's yours

- **Boot sequence (C10), built:** names the agent from your own Omarchy setting, `Omarchy default agent: <agent>. Linking...`, and shows it answering live, with the latency and a live GPU readout. See [Built: boot sequence (C10)](#built-boot-sequence-c10).
- **In-game HUD (C11), built:** a "your AI" badge, the last call's latency, tokens per second on the local fallback, and live GPU stats: utilisation, VRAM and temperature. See [Built: guide HUD (C11)](#built-guide-hud-c11).
- **GPU stats are read-only.** The game prefers reading them from /sys. Its only alternative is an optional, query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader,nounits`, never with control flags, which is the second and last thing the game may ever execute. The detector above already does exactly this. If neither works, the HUD simply hides GPU stats.
- **Coaching (C12), built:** between-round coaching from your real round stats, and an opt-in roast announcer on B. See [Built: round coaching and the roast announcer (C12)](#built-round-coaching-and-the-roast-announcer-c12).

## Your machine is the world

> **Status: Planned** (M5 including the Audit Trail visor in C43). The opener's read-only reader is built (C39, [above](#built-the-opener-on-your-own-machine-opt-in-and-read-only-c39)).

The later milestone that makes every copy of SIGKILL different:

- **Filesystem maps.** Rooms come from your real folder tree, sized by what is in them. `node_modules` is the endless maze.
- **Process enemies.** Real running processes become enemies: browser tabs arrive as a swarm, a pegged CPU core is a boss.
- **Audit Trail visor (C43).** A community prompt by Albert ([@QuantaCortex](https://x.com/QuantaCortex)). A visor mode draws glowing lineage lines from each enemy back to its parent process, up the real process tree. Severing a spawn chain, by killing a parent, collapses or reshapes that part of the arena and despawns its children. It reads only process IDs, parent process IDs, names and CPU and memory numbers: never command-line arguments, open files, environment or paths, so no private file name can show. Severing is cosmetic; nothing real is signalled. The visor's HUD carries the tag "visor design: @QuantaCortex".
- **Theme-shift levels.** Levels recoloured from your Omarchy themes, with palette-only enemies.
- **Keybind gunplay.** Opt-in moves mapped to your real Omarchy shortcuts, with no conflicts.
- **Voice commands.** Read from Ramblr's existing output; SIGKILL never opens the microphone itself.
- **Packet tracer arena.** Your tailnet machines as islands.
- **Hyprland split-screen co-op.**

The rules that make this safe, in plain words:

- **Read-only, and only the outside of things:** names, sizes and counts. The Audit Trail visor adds process IDs, parent process IDs and CPU and memory numbers; the opener also uses modification times, the uptime, the host name and theme colours. Never file contents or command lines. The opener reads two environment variables, `HOME` and `USER`, to find your home folder and your name, and shows folders only as `~/name`, never a full path.
- **Cosmetic kills.** Shooting a process-named enemy despawns a game object. Nothing on your system is signalled, stopped or changed.
- **Opt-in.** On first launch SIGKILL asks before it reads any folder or process names. Say no and every feature runs on fake data. (The opener asks on its first-launch card, No by default, since C42; its switch is also in Settings, off unless you turn it on.)
- **Nothing leaves the moment.** What is read is shown live and never saved, logged or sent anywhere. Your AI gets none of it.
- **Demo-data mode** for every capture and trailer, so no real machine data ever ends up in a screenshot.

## Visual tech

### Built: the Tron arena

- **Floor**, `shaders/floor_grid.gdshader`. A spatial shader that works in world space: the vertex stage passes `MODEL_MATRIX * VERTEX` to the fragment stage, so every floor block shares one continuous deck. Since A3 it is dark metal deck plates, 2 m square, parted by thin seams with a faint teal glint, each plate a shade lighter or darker than the next, some with an inset line, some vent grates glowing from below; over them the old grid, its 1 m lines now faint, and a brighter major line every 8 m, a light strip set into the deck (`GRID_*` and `FLOOR_*` in `scripts/palette.gd`). Line coverage is anti-aliased with `fwidth`, and once a pixel is wider than a line the line's energy is spread over that pixel, so the far floor fades into the dark instead of shimmering. The lines are emission on a near-black base, which is what the glow pass blooms.
- **Neon edges**, `shaders/neon_edge.gdshaderinc`. Glowing outlines on every greybox block except the floor, which has its own grid shader, and on the target dummies, found without normals or extra geometry. The edge maths lives in that include file; `shaders/neon_edge.gdshader` is the plain look the dummies use, and the code rain shader below includes the same maths for the blocks. In local space, a point on a flat face sits at distance zero from its own face plane, so the second-smallest plane distance is its distance to the nearest edge. A box has three plane families; the dummies' hexagonal prism has four, three side-plane pairs plus the caps. Edge width and colour are uniforms, and every block gets its own material sized to its half extents. On the hexagon the side faces meet at 120 degrees, so the plane distance underestimates the true distance along a face and the vertical edges draw about 15 percent wider than the rims.
- **Environment**, `scenes/arena.tscn`. One WorldEnvironment: since A3 a sky shader as the background (`shaders/arena_sky.gdshader`: black overhead, a dark teal haze and a thin glowing band at the horizon, a darker abyss below, a sparse scatter of data points; no TIME, so its light is worked out once), and a cheap depth fog in the palette's dark teal, clear for the first 30 m and thickening to 600 m, thicker still below the arena (height fog), so the skyline fades into haze; the glow, the tonemapper, SSAO, SSR and the grade since A4 (below); SDFGI stays off.
- **Colour**, `scripts/palette.gd`. The single source for every material and environment colour, and the factory for every material: void `#000000`, base `#05080a`, teal `#19d3c5` and mint `#7dffcf` for the player side, hostile red `#ff3355` and amber `#ffb000`. `scripts/main.gd` applies the exact palette colours to the environment at runtime; the scene file carries approximations only so the editor previews the look. Two light colours still live in their scenes: the sun in `scenes/main.tscn` and the room light in `scenes/arena.tscn`.
- **Cannon effects**, `scripts/cannon_fx.gd`. The beam, the muzzle flash and its light, the impact flash and the sparks use unlit, over-bright materials so the glow pass picks them up. Sparks are CPU particles launched along the surface normal: hostile hits spark amber, the world sparks mint. Every effect frees itself when its lifetime ends.

**What is verified, and what is not.** Headless Godot still runs the shading-language front end, so `scripts/check.sh` catches shader syntax and semantic errors; deliberately broken shaders were used to prove it. During C4 a one-off probe also checked the edge-distance maths against real mesh data. The first real renders came with A1: demo-data stills drawn by the real GPU (Vulkan) into a private virtual display, in [Screenshots](#screenshots). They show the floor grid, the neon edges and the code rain as built. No one has played in a window yet.

### Built: derezz on the target dummies

- **The effect**, `scripts/derezz_fx.gd`. A killed dummy shatters into voxels that fill its hexagonal prism. One MultiMeshInstance3D per death holds every voxel as an instance, so there is no node and no physics body per voxel, and the count is capped, at 160 by default. Every derezz shares one voxel mesh and one unlit, over-bright material. About half the voxels glow hostile red; the rest are obsidian with a faint red tint.
- **The look since A2**, `shaders/derezz_voxel.gdshader`. Each voxel glows along its edges round a dimmer face in its own colour, and as it fades its faces fall away cell by cell, the edges last, so a cube derezzes instead of only shrinking. The death opens with a flash: a column of light up through the body and a ring spreading along the ground, gone in 0.35 s. The motion, the counts, the sizes, the colours and the timing are as they were; the players' own derezz is the same effect.
- **Motion** is scripted on the CPU at a fixed 60 Hz step, so it plays the same at any frame rate: an outward burst from the body's centre, a push along the killing shot's direction, random spread, gravity, a tumble, and a damped bounce with friction on landing. Each voxel finds the real ground below it with a downward ray that only hits the world, measured again whenever it moves sideways on the way down, so voxels knocked off the raised platform fall to the floor beneath it and voxels flying over a higher surface land on top of it. Voxels shrink and fade along a power curve, and the effect frees itself once the last one is gone.
- **The dummy**, `scripts/target_dummy.gd`, is a small state machine. Alive: it takes hits. Derezzing: collision off, body and tag hidden, every hit ignored, and cannon shots pass straight through. Respawning: it grows back in its own spot, still not hittable. Then alive again at full health.
- **Tuning**, `scripts/derezz_tuning.gd` with `resources/derezz.tres`: the voxel cap, size and colours, the burst, push and spread, gravity, bounce, friction and the ground layers, the tumble, the lifetime and fade curve, the respawn delay and the regrow time.

The kill feed is not part of this chunk; it arrives with synced combat (C14). Like the rest of the look, the derezz has only run headless so far. Under `--headless` Godot keeps no MultiMesh data to read back, so the test checks the voxel state, and through a test hook the transform and colour each frame builds from it for the MultiMesh. A1's wide still catches a derezz on a real GPU, and A2's one mid-shatter, in [Screenshots](#screenshots); no one has watched one in play yet.

### Built: code rain on the walls

- **The shader**, `shaders/code_rain.gdshader`. Every greybox block but the floor carries it: the neon edge look, plus Matrix glyph streams that bleed through the block when a daemon is near. With no enemy in reach it produces the neon edge result, plus since A3 a faint wash of the arena's light strips on the block's sides. The glyphs are original and procedural, no fonts or textures: each face is cut into a world-space grid of glyph cells, so streams run across block seams; each column rolls a hash for whether it carries a stream, its speed and its phase; a stream is a bright leading glyph, a fading tail and a dark gap, stepping down one cell at a time like the film; each glyph is a four by six bit grid mirrored left to right so it reads like a character, re-rolled a few times a second.
- **Reach** is per pixel. The shader holds up to eight enemies, each a world position and a weight, and every pixel measures its own distance to each one: a share that fades to nothing at the falloff radius, combined like independent chances so two enemies never push it past full. The rain pools on the part of a wall nearest the enemy, on both sides of it, which is what makes it bleed through.
- **The driver**, `scripts/code_rain_driver.gd`, one node in the arena. It fills the enemy slots from the live target dummies and uploads them to every block material as one small uniform array. The weight is the part that moves in time: it climbs at the fade-in rate while the dummy is alive and falls at the fade-out rate once it derezzes, so the rain never pops and never overshoots; distance does the rest in the shader. When more enemies are alive than the slots hold, the nearest to the player win. It runs at the fixed physics rate. It collects the blocks and targets again only when one enters or leaves the tree or a block rebuilds its material, and that collection is the one place it allocates or uploads unconditionally; an ordinary tick allocates nothing and uploads nothing when no slot changed.
- **Tuning**, `scripts/code_rain_tuning.gd` with `resources/code_rain.tres`: the falloff radius, the minimum and maximum intensity, the enemy cap, the fade-in and fade-out rates, column density, glyph size, the fall speed range, tail length, flicker rate, brightness, and the head and tail colours, which default to the palette's Matrix green.

Like the rest of the look, the rain has only run headless so far: the shader compiles under the dummy renderer, and the test checks GDScript mirrors of the falloff maths and the glyph hash, which prove the design and the numbers the driver uploads, not the pixels the shader draws. A1's stills, drawn by a real GPU, show the glyphs on the walls; no one has judged the density and brightness in play yet. Code-rain vision (C21), seeing enemies through walls, and bullet time with motion trails (C18) build on this.

### Built: weapon viewmodels (A1)

- **The models**, `scripts/viewmodels/`. One script per weapon builds its model once, in code, when the player is made: boxes, prisms, tubes and a ">" glyph, low poly and faceted, merged into one mesh per material, so a model is a handful of draw calls (all eight are 4632 triangles) and nothing is rebuilt while it is held. Original and procedural: no model, texture or font files. Each weapon's resource names its model (`viewmodel_model`), so a new weapon slots in the same way; one naming none gets the old glowing box.
- **The silhouettes.** Terminal cannon: a compact carbine with a two-fin brake and a ">_" prompt. SIGTERM: an over-under pump with violet rings and "please exit" chevrons. SIGKILL rail: two long rails round a lit core, four coils and a long scope. Fork bomb: a hex cage round a turning drum of six lit pods, held turned toward the eye. `fork()`: one barrel that forks into two prongs. `grep`: a fat scope with lit lenses and a pod of three darts. `rm -rf`: a fat octagonal housing with vent fins and hazard stripes. `cron`: a dispenser with the next hex mine loaded and a clock on top.
- **The look**, `shaders/viewmodel_metal.gdshader`. Dark gunmetal with machined panel lines, or hex cells, cut in the model's own space so they ride on the weapon, and a faint rim of the weapon's neon round its silhouette; lighter plates, near-black polymer grips, neon trim in the weapon's light skin, and hot parts (bores, lenses, cores) in its beam colour. Root (C22) turns all of it red. Colours in `scripts/palette.gd`.
- **Alive in the hand.** The model lags a turn, sways with the stride (off with head bob), trails a jump or a fall, kicks back and up on a shot by the weapon's own weight (SIGTERM light, the rail and `rm -rf` heavy) and settles, rises tipped from below when drawn, and calms down aimed. The rail's coils light one after another as it charges; `rm -rf`'s core and vents glow up through its wind-up; the fork bomb's drum turns, `cron`'s clock hand goes round once a run interval, `grep`'s lens breathes. The numbers are in ArsenalTuning's Viewmodel motion group (`resources/arsenal.tres`).
- **The shot is unchanged.** Every shot still leaves from the eyes, exactly as before; the muzzle only moves where beams and the muzzle flash start. Projectiles are still drawn from the eyes too, except that the `rm -rf` slug is not drawn for its first 0.75 m, where it filled the view.

### Built: daemons (A2, creatures in A2b, armoured in A5)

- **Solid, not wire (A5).** Fred's call on A2b: every enemy looked the same, one colour, all "electricity". Now each daemon is a solid body of near-black armour, real closed shapes with mass (plates, a segmented carapace, limbs with thickness), and its light is only in its seams, its joints and its weak points, in its type's own colour. Faceless and geometric, as the [enemy art bar](#enemy-art-bar) asks: lights and armour, never an eye or a face.
  - `rogue.d` is a **mantis-scorpion** in crimson. A flat hexagonal thorax under overlapping dorsal plates, a scorpion's tail of ribbed hex segments curling up over its back to a stinger with a crimson bulb, a low wedge of a head with one horizontal visor slit, two scythe arms, six thick legs. A crimson band glows between every tail segment and at every knee, elbow and wrist. It crouches low and skitters on its legs by two-bone IK, three legs swinging while the other three hold; its tell rears it up tall, scythes high, tail curled tight, the visor flaring.
  - `zombie` and `<defunct>` (a defunct process is a zombie) are a **hulking amber process**, armoured on its right side and coming apart on its left. A heavy hunched chest under a hump of back plates, a low faceless head sunk between its shoulders, a great pauldron on its right shoulder and a cannon for a right forearm ringed with three charge bands; on its left the armour is gone, the ember burns in the open cavity of its chest, the left arm is a column of loose voxels, and voxels peel off that side all the time and drift away as they derezz. It limps, a lurch on its good leg and the bad one dragged after it; its tell raises the cannon at you, the bands lighting one after another and the muzzle swelling, before the bolt.
  - `runaway` is a **swarm of solid hot-magenta drones**: hex pucks of armour with two blade wings and a magenta light in their middle, each leaving a short trail, flocking as boids round a bigger core drone (two armoured halves turning about a band of magenta light, its heart showing through the gap). **Killing the core scatters the swarm**: its death flies every drone off whole, out from the core in every direction, as it derezzes.
- **No two alike (A5).** Every daemon is built from a seed, and every choice of its build is a roll of it: its size (inside its type's hitbox-safe range), its plates, its seams, its stance, its gait's timing, its battle damage (chipped and scorched plates, flickering seams). In play every spawn rolls a new seed, so a daemon you kill comes back a different one. One spawn in twelve is its type's **elite**: bigger, with extra parts (rogue.d a second pair of scythes and a crown of horns, the zombie three back spikes and a bigger pauldron, the swarm thirty drones and an armoured halo round its core), and it takes at least 30 health where every other daemon dies to one hit, so it lives through a cannon shot. In a match the host sends each daemon's seed, so every screen draws the same daemon.
- **Alive to the game.** A hit that does not kill flares the daemon, knocks its body back to spring to rest, sprays ten glowing shards from where it struck, and brings the kind's own answer (the rogue rears, the swarm scatters faster than it can fly). A kill bursts the creature into its own parts over the derezz's voxels, column and ring, all in its own colour now. A daemon growing back glitches hard as it re-forms, and the grep seeker's mark sweeps a cobalt band down it. A few terminal glyphs float round every one, in its colour, and its name tag floats clear of it.
- **The look.** `shaders/daemon_armor.gdshader` is the armour: dark gunmetal catching the arena's light on its facets and bevels, a faint steel catch-light on its true edges, a thin rim of the type's colour only where it turns away. `shaders/daemon_core.gdshader` draws the seams, joints and weak points in the type's colour, breathing, guttering for a zombie, a damaged seam flickering. The obsidian (`shaders/daemon_shell.gdshader`) is the zombie's peeling voxels now. The glitch (`shaders/daemon_glitch.gdshaderinc`) stays quiet on armour at rest and tears it as hard as ever on a hit or a respawn.
- **Built once per spawn, posed every frame.** `scripts/daemons/daemon_art.gd` is a rig: every part is one instance of a shared unit shape (a shard, a gem, a voxel, a trail's sliver, and since A5 an armour plate, a limb, a blade, a hex puck and a seam ring, made once from the shape kit) in one of four looks, one MultiMesh per shape and look, so a whole creature is a handful of draw calls. Posing moves the instances by their transforms and nothing else; nothing is made after the build. A daemon's art is rebuilt only at a spawn, while it is still nothing. Every daemon shader reads its time from one shader global stepped at the game's pace, so SIGSTOP slows the creatures with the world.
- **The cost** (measured, A5). rogue.d 2,834 triangles in 14 draw calls (budget 4,200 and 16), a zombie 1,722 in 12 (budget 3,400 and 14), the runaway 3,560 in 8 (budget 6,000 and 10), counting a draw call a set and one more for each that throws a shadow. On a real GPU at 1920x1080, nine daemons drawn and hidden in turn cost no measurable GPU time (1.78 to 1.90 ms a frame drawn, 1.79 to 2.01 ms hidden), and add 69 draw calls and 22.5k primitives. Posing, timed on this development machine: rogue.d 158, the zombie 181 and the runaway 233 microseconds a daemon a frame, so the arena's four take about 0.8 ms of CPU a frame. Not measured on an RTX 4050 yet.
- **What changed in the game.** The hit volume is still the 1.8 m cylinder, byte for byte; rogue.d's body box scales with its size. An elite's health (`elite_health` in `resources/daemon_ai.tres`) is the one new number. The daemons' state message carries each one's seed, so the protocol is 11. The zombie's feet no longer slide while it chases you.

### Built: the arena (A3)

- **The dressing**, `scripts/arena/arena_art.gd`. One node in the arena builds it once from the greybox blocks beside it. Every block but the floor gets a kick plate, a bevelled crown (or, on a block a player can stand on, a lip under its edge, so nothing rises above their feet), chamfered corner guards, ribs every 2.6 m or so with panels between, a waist rail and inset frames, and light strips: teal low in each panel, mint high, hostile red where a strip faces into the lair, the rogue daemon's room. The platform gets two shallow steps round its foot. Props: server racks along the lair's back wall and the east wall, terminal screens, vents, cable trays with a live data line, cable bundles down the walls, cables slung between the pillars and from the lair to the outer walls, data conduits in the four corners, and floating `>_` holograms over the pillars, the lair, the corner towers and the masts.
- **Signs**, `scripts/arena/arena_font.gd`: an original 5 by 7 pixel terminal font written as rows of bits in the script, no font file, a sign costing one quad per run of lit pixels. `RING 0` in red over the lair's door, `KILL -9`, `EXIT 137` (a SIGKILLed process's exit status), `PID 1`, `TTY0`, `SIGKILL`, `/DEV/NULL`, `CORE DUMPED`, `SUDO !!`, red arrows on the floor into the lair, and more: invented flavour, nothing of the player's.
- **Outside the walls.** The arena stands on a stepped plinth that falls away in three tiers into the fog on a long column, with parapets of varied heights along the outer walls' tops and a conduit along them, its data flowing, a tower with a blinking beacon at each corner and a mast behind each wall's middle.
- **The void**, `scripts/arena/arena_skyline.gd`. A ring of 72 dark megastructures rising out of the abyss 110 to 430 m out, lit windows and teal edges, beacons on their tops; four giant data towers far out, beams of light standing up from them into the sky; an orbital ring over the arena; and slabs and shards drifting slowly round it, nearer than the towers, so they slide against them as you move. Placed by a seeded generator, so every machine sees the same skyline.
- **The look**, `shaders/arena_*.gdshader`. Gunmetal panels with their true edges drawn in teal (the shape kit's edged buckets, as on the daemons), fading out with distance and darker near the floor; light strips breathing in a slow wave, conduits with packets of data flowing, beacons blinking each on its own phase; terminal screens scrolling procedural text and racks of blinking status lights; the holograms turning and bobbing in the vertex stage; towers with a grid of windows that gives way to its average glow far off, so it never shimmers; and the sky. Every colour and energy is in `scripts/palette.gd`.
- **Built once, visual only.** At load it merges into one mesh of solid parts (a surface per material, throwing shadows), one of light (no shadows), one MultiMesh for the holograms and four meshes for the skyline, all wearing the palette's twelve shared arena materials. The build is kept, so an R reload builds nothing; nothing is rebuilt while it is drawn (the strips, screens, flow and holograms move in their shaders, the ring and the drift by their nodes). Nothing of it collides: the blocks are still the whole of the arena's collision, and the check proves the collision and the sight lines from every spawn point to every daemon byte for byte as before A3. Whatever a player can walk into stands within 0.3 m of a block, under a player's radius, and nothing hangs over a top a player stands on lower than a jump reaches.
- **The cost.** The dressing is 26,826 triangles in 12 draw calls (budget 32,000 and 16), the skyline 5,396 in 11 (budget 8,000 and 12), the whole arena with its blocks 32,450 in 61 (budget 42,000 and 68), counting a draw call a surface and one more for each that throws a shadow. Drawn by a real GPU for the gameplay still: 65 draw calls and 38k primitives, with 44 and 5.8k before A3. It builds in about 0.13 s when the arena loads. It has not been measured on an RTX 4050 or played in a window yet.

### Built: lighting, post and particles (A4)

- **The light**, `scripts/palette.gd` (`apply_arena_environment`). AgX tonemapping with its contrast raised: very bright saturated neon rolls off to white without ACES's hue skew, so hostile red stays red and teal stays teal at the core of a glow. The glow mixes by Screen over a 0.9 HDR threshold, so only the neon glows, and its luminance cap keeps a kill flash or a swarm from spreading into a white blot. A subtle grade on top: a touch more contrast and saturation and a curve that cools the shadows and warms the highlights.
- **Colour to read by.** Hostile reds and magentas on the daemons and danger: a daemon's glitch split is hostile magenta now (it was cyan), the derezz bits fly red to magenta, and two red danger lights pulse in the lair. Warm sodium orange on the signs: the big wall signs (`KILL -9`, `EXIT 137`, `PID 1`, `TTY0`, `SIGKILL`, `/DEV/NULL`, `CORE DUMPED`) glow warm, each with a warm lamp before it lighting the wall and the floor, against the teal.
- **SSAO and SSR, only where cheap.** Both are the high preset's alone. The floor's deck plates are gloss now (the seams and vents stay matt), so SSR shows the neon and the daemons in the deck.
- **Particles**, `scripts/fx/particle_fx.gd`. GPU particles from fixed pools made once with the arena: sparks off whatever a shot strikes, red and magenta derezz bits tumbling off a daemon it hits, debris from every blast (fork bomb, rm -rf, cron), sparks shed behind a projectile in flight, and a muzzle burst per weapon family under each model's barrel (the cannon's pulse, the rail's ring, the shotguns' wide scatter, grep's tight ring, the launchers' chunky embers, rm -rf's heavy ones). Every kind shares one process material and one mesh and every colour one draw material, all made with the pools; an effect takes the next emitter round its pool, so the pools are the caps (1,344 particles at the most) and nothing is made per shot or per frame. The particle level sets how many particles every emitter holds, so low simulates and draws a quarter of them, not just hides them. Another player's projectiles run on your screen too, trails and debris and all, and their hitscan shots spark where each beam ends. C6's beam, flash and sparks stay underneath, as they were.
- **Post effects**, `scripts/fx/screen_post.gd` and `shaders/screen_post.gdshader`: chromatic aberration and CRT scanlines, each a setting, off by default, drawn under the HUD and not at all while off. Neither warps the picture, so what is under the crosshair is what you hit.
- **Graphics settings.** In Settings, Video: a quality preset (low, medium, high) and each thing it sets as its own toggle (bloom, shadows, code rain, SSAO, SSR, the full skyline, and the particle level), plus the two post effects. Change a toggle and the preset reads custom. Low is the cheap one: no glow, shadows, code rain, SSAO or SSR, the skyline without its orbital ring and drifting slabs, a quarter of the particles and no trails (it stops any flying when you pick it). Medium is the target for an RTX 4050-class GPU: glow, rain and the full skyline, half the particles. Saved with every other setting.
- **The weapon in your hands**, `scripts/player.gd`. The viewmodels have a fixed projection: they are drawn as at 80 degrees whatever your field of view, and shrunk toward the eye, which looks the same but keeps every model inside your own radius, so a barrel never pokes into a wall. Projectiles are drawn coming out of the barrel (the slug, grep's darts, fork()'s pellets), alone or in a match, and close on their true paths within 6 m; the shot itself still leaves from your eyes. Through a shot's jolt the shrunk weapon moves on screen exactly as a full-sized one would.
- **SIGSTOP slows the arena too.** The strips' wave, the beacons, the screens and the holograms run on the arena's own shader clock, stepped at the game's pace.
- **The game is unchanged.** Visual and settings only: `resources/` and `scripts/net/` byte for byte as before A4, the protocol still 9, every hitbox and number as it was. Step 36 checks it.

### Built: ICE's look (I1)

- **Its own visual language.** Not daemons and not wire: cold crystalline lattice and shield geometry. Every piece is faceted crystal with mass, near-black cold glass (#08121f) that takes the arena's light on its facets, each facet a shade of its own, a little of the ICE's colour caught inside a few of them. Its light lives in its seams, joints and cores: the walls' seams beside every strut, the lattice's joints, the lock at a wall's heart, a node's heart and rings, the hunter's heart, rim and spines. A hit sprays shards of its colour; a wall never flashes whole, so a wall under fire stays readable.
- **Two colours.** White ICE is **glacier blue, #18b2ff**; hunter ICE a deeper **cobalt, #1e30ff**, its HUD line a light cobalt (#9aa6ff) so it reads on black. Picked by measurement: the brief's starting point, #3d8bff, sat almost on top of grep's cobalt (#4d7dff, OKLab distance 0.035), so glacier moved toward azure. Each keeps at least 0.136 (OKLab) from the player's teal, the rail's ice-white, ping's lime, every daemon's colour, grep's cobalt and SIGTERM's violet, and the two are 0.29 apart; step 40 checks it.
- **The pieces.** A wall: a dark glass backing filling the opening, a frame of double-terminated crystal bars, struts between faceted panes standing proud on both faces (each tilted its own way), a lock of light in a ring at its heart with crystal teeth pointing at it, crystal pylons with bands of light at both ends, a plinth and a crown of crystal spikes. A node: a heart of light in a cage of turning crystal shields over a crystal tripod and a stepped hex plinth; the jam node's cage is closed with a second ring crossing the first (a lock), the HUD node's is open with a crown of lit antennas (a broadcast). The hunter: a hull like a cut lens (two faceted carapaces meeting at a rim of cobalt light), its heart at the nose, swept crystal blades with spines of light, crystal tails, a fin, and shield satellites turning round it that close into an iris at its nose for the tell, the blades swinging forward like pincers.
- **No two alike.** Every piece is built from a seed, a new one each round in play (fixed by name in demo, test and capture runs; the host's in a match): a wall's cells, bars, struts, pane depth and tilt, lock, pylons, crown and chipped panes, and which panes break out and when; a node's shields, orbit, spin, plinth, tripod, spike and antennas; the hunter's hull, blades, shields, orbit, tails, fin and bob. ICE has no elite: its frightening tier is Black ICE (I3).
- **Cracks and fields in the shader.** `shaders/ice_crystal.gdshader` draws the crystal and its cracks: fracture lines (the edges of a cellular pattern in the part's own space) spreading from a point of each part's own, glowing in its colour with a hot core, the glass frosting round them. `shaders/ice_field.gdshader` draws a node's dome: a lattice of light at the field's exact reach, flickering in through the tell, flashing as it fires; the HUD field's lattice torn by scrambled bands. ICE's light is the daemons' core shader, steady, with no glitch at all: ICE is the system's own exact code.
- **The same rig as the daemons.** The ICE art extends A5's rig (`scripts/daemons/daemon_art.gd`): one MultiMesh a shape and look, built once a round, posed by transforms alone, nothing made after the build. Three new unit shapes in the shared kit: a crystal pane (FACET), a double-terminated crystal (PRISM), and the pane again as the hunter's shields (SHIELD, its own set so only the shields take the adaptation's colour); two new looks (ICE's crystal and its light).
- **The cost** (measured, I1). Built once a round. As built, a wall (the corridor's, 4.8 by 3 m) is 2,898 triangles in 12 draw calls, a node 910 in 9, the hunter 1,056 in 11, counting a draw call a set and one more for each that throws a shadow. On a real GPU at 1920x1080, seven pieces (three hunters and four nodes) drawn and hidden in turn cost no measurable GPU time (1.88 to 2.12 ms a frame drawn, 1.90 to 2.07 ms hidden) and add 49 draw calls and 7.2k primitives. Posing, timed on this development machine, quickest of five rounds: a wall 39, a node 58 and the hunter 87 microseconds a piece a frame (medians 43, 58 and 91), so round 2's five pieces take about 0.3 ms of CPU a frame. Not measured on an RTX 4050 yet.

### Built: the ICEbreakers' look (I2)

- **Their own colour.** The breakers are the intruder's own programs, so they are neither ICE's blue nor the player's teal: an **ultraviolet, #7400cc**, found by searching the hue wheel for the point farthest (OKLab) from every bright colour already in the game. Its nearest are the hunter's cobalt at 0.161 and SIGTERM's violet at 0.165; step 41 holds it at least 0.12 from every bright colour of the palette. Its HUD text is a light tint, **#c27fff**, legible on black.
- **Pickups with mass.** Each pickup is a split key crystal: two armoured prism halves parted round a burning ultraviolet core, a seam of light round each half's waist, four faceted plates orbiting it, a few terminal glyphs, over a hex plinth ringed with light. A thin beam of light stands from the plinth so it reads from across the arena, its kind's emblem rides on top (brute a ram of two blades, exploit a lens, cloak a hood of two folded panes, decoy twin shards bound by a ring) and its name floats over it. Solid armour, light only in its seams and cores: never a box, never a wire.
- **The decoy.** A faceless effigy of your signal: a crystal spine on a plinth, torso plates front and back, shoulder panes, a head of light, rings of light climbing the spine in turn and rolling out over the floor (its call). Thrown, it flies folded small and tumbling, then stands up where it lands; its light stutters as its call runs out, and at its end it bursts into its own parts over an ultraviolet derezz. A strike on it flashes and sprays it.
- **The charge and the marks.** The brute throws a ring of ultraviolet streaks out from in front of you and a burst where it lands. Exploit's seam marks are diamonds of ultraviolet light, one MultiMesh of quads facing the camera (`shaders/breaker_mark.gdshader`), pulled a little toward your eyes so the armour they mark never hides them, pulsing a little out of step with each other. The cloak washes the screen's edges ultraviolet with the hit vignette's shader.
- **The same rig again.** Pickups and decoys are built from a seed on A5's rig, one MultiMesh a shape and look, posed by transforms alone (the host's seeds in a match).
- **The cost** (measured, I2). As built, a pickup is 900 triangles in 8 draw calls (no shadow: it is small and hovers), a decoy 898 in 11. With the line-up's five (four pickups and a decoy) drawn and hidden in turn on the real GPU at 1920x1080, the frame's GPU time showed no measurable difference (1.73 to 2.03 ms drawn against 1.70 to 1.96 ms hidden); they add 46 draw calls and 4.7k primitives. Posing is GDScript: 55 microseconds a pickup a frame and 103 a decoy at the quickest of five rounds (medians 57 and 110). Exploit's marks cost 0.22 ms a frame for 59 marks, only while it runs.

### Built: Black ICE's look (I3)

- **The worst thing in the arena.** A black sun of ICE, 5.1 m to its top and 5.5 m across its spikes: a core of black crystal plates hovering round a dim cold heart (its light only in the gaps between the plates and along a few thin veins), long black crystal spikes radiating every way but straight down and slowly breathing, and spike legs reaching down to the floor in a ring as wide as its touch, so what you see standing round it is what flatlines you. Two seals, rings of cold light, cross round its core and turn; a dashed ring of the same light lies on the floor at its touch's reach. Nothing of a face. A first try, a robed wraith of blades, read as a blue armoured gown in the stills and was dropped.
- **Its light is almost absent.** ICE's crystal shader with Black ICE's own material: near-black glass (#020304) that light falls into (rough, barely reflecting, almost no light in its facets), a thin cold rim only where it turns away, its true edges a faint line, and a hit's flash a cold flicker on its edges, never a white sheet. Its colour is **a cold dead slate, #2a6e81**, found by searching the cold hues for the point farthest (OKLab) from every bright colour already in the game: 0.200 from grep's cobalt, 0.243 from white ICE's glacier; step 42 holds it at least 0.15 from every bright colour. Its HUD text is a light tint, **#77bdd3**.
- **Its arrival.** It forms out of nothing over its six seconds: the floor ring first, the plates closing in round the heart, the spikes and legs growing out, the seals lighting last. A broken seal goes dark and flickers while its spikes draw in and it shudders; withdrawing, it comes apart the way it came.
- **No two alike.** Built from a seed on A5's rig (the host's in a match): the spikes (how many, which ways, how long, how they breathe), the legs (how many, where each stands), the core's plates and how it turns, the seals' tilt and turn, which veins burn. Its body and its touch never change with the seed.
- **The arena's own lights.** A new shader global, `arena_light`, is multiplied into the arena's shaders (strips, signs, beacons, panels' edges, screens, racks, holograms, floor, the walls' rain, the skyline), and the sun, the room's light, the lamps, the lair's danger lights and the sky go down with it: one value dims the whole arena and nothing else.
- **The cost** (measured, I3). As built, one Black ICE is 2,192 triangles in 7 draw calls. With the line-up's three drawn and hidden in turn on the real GPU at 1920x1080, the frame's GPU time showed no measurable difference (1.80 to 2.01 ms drawn against 1.66 to 1.86 ms hidden); they add 15 draw calls and 6.8k primitives. Posing is GDScript, 183 microseconds a frame at the quickest of five rounds (median 201), and only one is ever out.

### Where the look is heading

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/media/concept-derezz.jpg" alt="A red wireframe daemon shattering into glowing teal voxels above a light grid"><br>
      <em>Concept art, not in-game footage.</em>
    </td>
    <td align="center" width="50%">
      <img src="docs/media/concept-bullettime.jpg" alt="First-person view of the terminal cannon in bullet time, green tracers frozen mid-air, red daemons leaping"><br>
      <em>Concept art, not in-game footage.</em>
    </td>
  </tr>
</table>

### Enemy art bar

Fred's bar for every hostile: faceless and geometric, never cartoon monsters.

- Daemons: black obsidian shards with floating red terminal glyphs.
- Swarms: angular red drones.
- Bosses: giant red-hot lattice cores, the CPU core being the first.
- Deaths: voxel derezz into glowing cubes.

Built in A2 and redone as creatures in A2b: the daemons and the swarm above, and the derezz into glowing cubes (C7, upgraded in A2), now with the creature's own parts bursting apart over it (A2b). Since A5, Fred's call, they are solid dark armour with light only in their seams, each type its own colour (rogue.d crimson, the zombie amber, the swarm hot magenta), no two alike. Bosses come with process enemies (M5): there is no boss in the game yet, so none is drawn. ICE (I1) holds to the same bar in a language of its own: faceless crystal with mass, glacier blue for white ICE and cobalt for the hunter, light only in its seams and cores, never a box or a wire.

## Multiplayer

> **Status: Built, relay hosting waits on Fred** (M3). **Built:** LAN and tailnet play, host and join by address (C13), synced combat: shooting, damage, death, respawn and the kill feed (C14), room codes and invite links (C15), and the relay itself, a small UDP service any plain Linux server can run (C16c, [docs/RELAY.md](docs/RELAY.md)), and its WebSocket mode on one TCP port for a host behind an HTTPS proxy, such as an exe.dev VM (C16d), both proven on 127.0.0.1 only. **Waiting on Fred:** hosting it (his pick is WebSocket mode on exe.dev; nothing is set up there); until a relay is set in Settings, a room code says online rooms aren't live yet and the game makes no network call.

Multiplayer has to just work: join by a 6-character room code or a `sigkill://` invite link, with no port forwarding. On your own network it works the direct way today; across the internet it goes through a relay, which is built and waits to be hosted.

```mermaid
flowchart LR
    A["Player A"] -->|"LAN or tailnet: direct, ENet"| B["Player B"]
    A -->|"room code"| M["Matchmaking and relay service<br/>planned, hosting not decided"]
    B -->|"room code"| M
    A -.->|"internet: NAT punch-through, WebRTC data channel"| B
    M -.->|"fallback relay"| B
```

- **LAN and tailnet mode (C13), built:** instant play between machines on the same network, host and join by address. See [Built: LAN and tailnet play (C13)](#built-lan-and-tailnet-play-c13) and [Playing on a LAN or tailnet](#playing-on-a-lan-or-tailnet).
- **Synced combat (C14), built:** shooting, damage, respawn and the kill feed, with the host as the one authority. See [Built: synced combat (C14)](#built-synced-combat-c14).
- **Room codes and invite links (C15), client side built:** the code, the link and the rendezvous interface are in the game; the rendezvous, NAT punch-through and fallback relay are designed in [docs/RELAY.md](docs/RELAY.md) and not hosted. See [Built: room codes and invite links (C15)](#built-room-codes-and-invite-links-c15).
- **Built on Godot's high-level multiplayer:** ENet for direct play and WebRTC data channels for punch-through.
- **Hosting cost is Fred's call** before anything is deployed; nothing runs on a server today.

### Built: LAN and tailnet play (C13)

One player hosts, another joins by the host's address, and the two see each other move. Everything that touches the network is in `scripts/net/`, and the only socket the game ever opens is the one ENet socket you ask for by hosting or joining.

- **Host and join: M.** The multiplayer panel opens on M. H hosts on the tuning's UDP port, 9009, on every interface of your machine. J opens an address box: the host's IP or host name, with an optional `:port` (`<host-ip>`, `<host-ip>:9009`, `host.example`, `[<v6>]:9009`); while it is open the mouse is free and the game takes no input, Enter joins, Esc cancels. L leaves (a host sends everyone away), Esc closes the panel. The panel's keys count only while it is up, never with Ctrl, Alt or Super, and nothing else in the game uses M. A net line under the daemon count says where you stand: "net: off   M multiplayer", "net: hosting :9009   players 1/2", "net: joined   players 2/2", or the error.
- **The handshake.** A joiner sends the game's protocol version and its shown name before anything else, as Godot's own authentication step; the host answers with its version and a verdict and only completes the connection for a match with room. Refused joiners see why: "version mismatch: host 2, you 1" or "host full", and the host's own screen says it refused one and why. A host that is not there gives "couldn't reach host" after 5 seconds (SIGKILL keeps its own clock; ENet alone would wait far longer for a closed port), "host left" when the host goes, "port 9009 is in use" when it cannot host, "not an address" at once for anything that is not one. The game never hangs: a connect in progress is cancelled by Esc, and a bad address, a closed port or a dropped peer only ever produce one of these lines.
- **Who is in charge.** The host owns the session: the roster (ids, slots and names, "Daemon-1", "Daemon-2") goes from the host to every joiner on every change, and nothing travels between joiners except through the host's own code (Godot's relay is switched off). Each player owns its own movement for now; C14 revisits authority for shooting.
- **Movement.** Twenty times a second, never per frame, each player sends its position, body yaw, view pitch and velocity: a joiner to the host, the host to everyone. The other player is a teal hexagonal prism with a mint visor and a name tag, built in code from the palette; it is drawn 100 ms behind the newest position and glides between the two positions around that moment (keeping as many positions as that delay needs), keeps going on its last velocity for at most 200 ms when positions stop coming, and never jumps. Every packet is checked before it moves anything: finite numbers, inside the world, a yaw within one turn, a possible pitch and speed, and a sequence number in range and newer but not absurdly far ahead (the first one after a reload or a rejoin sets the baseline), so one bad packet can never freeze the stream behind it. Remote players have no collision yet; shooting them is C14.
- **Over the wire, ever:** the protocol version, slots and ids, the shown name (a placeholder, never your user or host name), positions, angles and velocities. Nothing about your AI, your settings, paths, processes or the machine. Your AI guide stays on your own machine; nothing about it is networked.
- **Solo play is untouched.** With nobody hosting or joining, the session sits off on Godot's offline peer: no socket, nothing sent, no avatar.
- **The arena reloads under it.** The session lives beside the arena, so R keeps the connection; the new arena picks it up and the other player's avatar comes back.
- **Tuning.** The port, the bind address, the player cap (2), the shown name, the connect and peer timeouts, the send rate and the interpolation delay are in NetTuning, `scripts/net/net_tuning.gd` with `resources/net.tres`.
- **Seen headless only.** Two real machines on a LAN or a tailnet have not played yet, and no window has shown the panel or an avatar; that waits for Fred's yes.

The test, `tests/net_test.gd`, runs a host and joiners inside one process, each in its own branch of the tree with its own multiplayer instance and real arena, over ENet on 127.0.0.1 on ports the system hands out.

### Built: synced combat (C14)

In a LAN or tailnet match the players shoot each other. The host decides every hit; the others only ask and display. The rules live in `scripts/net/combat.gd`, the host's authority object; the session (`scripts/net/net_session.gd`) runs every shot through it, raycasts in its own world and sends the results; `scripts/net/combat_hud.gd` shows them.

- **One authority path.** Firing the cannon sends the host an intent: the shot's number, the shooter's life number, origin and direction, and nothing else. The host checks it (below), casts the ray itself against walls, dummies and the players' bodies, takes the one weapon's damage off the victim and tells everyone: the shot with its end point and the victim's health, a death, a respawn. The host's own shots go through exactly the same checks and the same ray; a joiner never applies damage or decides a kill. Godot's relay stays off.
- **What the host believes.** A shot counts only from a living player in its current life (one that was in flight when they died is refused when it lands after the respawn), with a number newer than that player's last believed shot (and not absurdly far ahead; a refused number is not burnt), a finite unit direction, a finite origin, no sooner than the weapon's 0.16 s cooldown less a 25% tolerance for jitter, and an origin within 1.5 m of where the host last saw that player's eyes (its newest received position plus the eye height) that those eyes can actually see: the host probes the short line between the two, so an origin claimed on the far side of cover is refused and nothing is ever shot through a wall. Anything else, a packet of the wrong types included, is dropped and counted, never answered, never printed; a refused shot burns neither its number nor the fire-rate clock.
- **Health, death, respawn.** Everyone spawns with 100 health; the terminal cannon's `damage` is 25, so four hits derezz a player (a dummy's single point of health still goes in one). At zero the victim's avatar shatters with the same derezz effect as a dummy on every screen, the victim's body stops where it is, its cannon goes dark and a banner says who got them; after 3 seconds the host respawns them at the arena's spawn point farthest from the nearest living opponent (five markers under `Arena/Spawns`), with full health and 2 seconds of spawn protection during which they take no damage, shown by mint edges on their avatar and a mint border on their own screen.
- **Feedback follows the host's word.** The C6 hit marker shows when the host confirms a hit, and only then: in a match a dummy hit on your own copy of the arena still derezzes the dummy but lights no marker. The screen flashes hostile red when the host says you were hit, and other players' shots are drawn as beams from the host's numbers. Muzzle flash, sound, the crosshair's kick and the beam of your own shot stay local and immediate.
- **The kill feed.** The last four kills at the bottom right, each for 6 seconds, in SIGKILL's words: "SIGKILL sent by Daemon-2" / "to Daemon-1", with the names as they were at the kill, so a player who leaves keeps their credit; the feed belongs to the match and is empty at the start of the next. Players are Daemon-1, Daemon-2 and so on by slot, always: a name asked for over the wire is read and checked but never used, so nobody can call itself Daemon-1. A line under the net line shows your health, your spawn protection or, dead, who derezzed you and the respawn countdown.
- **Avatars can be hit.** Each remote avatar carries a capsule on the targets layer, which the cannon's ray meets and nobody walks into (players collide with the world layer only); it is off until the player's first position has arrived, and no corpse ever stops a shot or counts as cover: the host leaves every dead body out of its rays, its own included. A shot that starts inside an opponent's body (two players at one spawn) still hits it, and a just-revived player with no new position yet still counts as standing at its spawn. Dummies stay each player's own: the host's ray stops at one but never damages it.
- **Lives.** Every position a player sends carries its life number, which the host raises at each respawn, so a position sent just before a respawn can never drag the respawned avatar back to where it died. A session joining mid-match gets everyone's health, deaths, protection and lives with the roster. R reloads the arena under a match as it does under a session: a respawn that lands while your arena is reloading is kept and applied by the new one, and a host whose own arena is away holds the respawn until it is back, then waits a moment for the opponents' positions before choosing a spawn.
- **Cosmetic and in-game only.** Nothing real is signalled, killed or run. Over the wire, beyond C13: shot intents and results, health, deaths and respawns, by id; since C19, throws of the fork bomb, the host's seed for each and its blasts (since C24 the same seed message carries each `fork()` shot's seed, and since C25 a `grep` shot's seed and the marks the host believed, and the shot intent the marks it claims, since C26 an `rm -rf` shot and its blast in the same two messages, and since C27 each `cron` mine, its runs and its removal there too); since C20, the light-trail rule and each wall segment (its owner, life, two ends and age); since C22, a player's sudo ask and the host's word on each player's sudo charges and root time.
- **Tuning.** Health, the respawn delay, the protection time, the rate and origin tolerances, the feed's length and fade and the flash are in CombatTuning, `scripts/net/combat_tuning.gd` with `resources/combat.tres`; each weapon's damage, range and fire interval are in its own WeaponDef (C16).
- **Seen headless only.** No two real machines have shot each other yet, and no window has shown a derezzed player, the flash or the feed; that waits for Fred's yes.

The test, `tests/combat_test.gd`, uses the net test's harness: real cannons, the host's real raycast, over ENet on 127.0.0.1.

### Built: room codes and invite links (C15)

A friend will join with six characters, or a `sigkill://join/` link, instead of an address. The game side is built; the service behind it is designed in [docs/RELAY.md](docs/RELAY.md) and **not hosted**, so today a room code is answered "Online rooms aren't live yet. Use LAN join (address)." and nothing is sent anywhere.

- **The code.** Six characters from 2-9 and A-Z without I, L and O, so nothing can be misread (no 0, O, 1, I or L), for example `ABC23P`. The last character is a checksum: every single mistyped character and every swap of two neighbours is caught on your own machine, before anything is sent. Spaces, dashes and lower case are forgiven (`abc-23p` works). A code comes from the engine's cryptographic random bytes, never from a name, an address or the time (`scripts/net/room_code.gd`).
- **The invite link.** `sigkill://join/ABC23P`, given to the game on its command line: `godot --path . -- --join sigkill://join/ABC23P`, or just `--join ABC23P`. Parsing is strict: another scheme or path, anything after the code, a second `--join` or no code at all is refused with the reason, and the multiplayer panel opens to show it. SIGKILL registers no link handler, `.desktop` file or `xdg-mime` entry; clicking a link in a browser waits for packaging and Fred.
- **K, in the multiplayer panel.** Opens a box for a room code or a link (the mouse is free and the game takes no input while it is open; Enter joins, Esc cancels). With a rendezvous, the code is looked up and the friend joins by the C13 path, but only to an address on this machine, a LAN or a tailnet: a room placed anywhere else is refused until relay hosting is decided. Today it says rooms aren't live yet. Address join (J) works exactly as before.
- **Hosting with a room code.** When a rendezvous is configured, H also shows "Room code ABC23P   invite sigkill://join/ABC23P" with the time it has left. A code lives 10 minutes at most, then the host releases it and shows a fresh one, and one is released the moment hosting stops; a code someone else holds is redrawn. Without a rendezvous, which is today, hosting looks exactly as in C13.
- **The rendezvous interface.** `RendezvousClient` (`scripts/net/rendezvous_client.gd`) is all the session talks to: register, resolve, close, one request at a time with a timeout. The game's only implementation is `NullRendezvous`, never live, no socket, no lookup; `RoomTuning.relay_url` is empty, and while no network client is built any value means the same. What may ever go to a rendezvous: the room code, the protocol version and the host's game port; the address is whatever the service sees. Never a user or host name, a path, anything about your AI or any player data.
- **Clear errors.** A typo, an unknown code, an expired code, a room on another version, a busy or unreachable service each get one plain line, and LAN join keeps working through all of them.
- **Tuning.** The relay URL (empty), the code lifetime (600 s), the request timeout (4 s) and the redraws on a taken code (5) are in RoomTuning, `scripts/net/room_tuning.gd` with `resources/room.tres`.
- **Seen headless only, against a fake.** The live path is proven against a test-only rendezvous inside the test process on 127.0.0.1; no real service exists, and no window has shown the room box.

The test, `tests/room_test.gd`, uses the net test's harness and the fake rendezvous in `tests/support/fake_rendezvous.gd`.

### Built: the relay, local only (C16c)

The service behind room codes, in `relay/`: a rendezvous and a relay in one small UDP process, run by a headless Godot 4.7 with the same wire-format file as the game. It is **not hosted anywhere**; the tests run it on 127.0.0.1 only. How to run it, its settings and the systemd example are in [docs/RELAY.md](docs/RELAY.md).

- **Every match through the relay.** A host registers a code and gets one relay port per joiner slot; a joiner resolves the code (typed, or a `sigkill://join/` link) and connects to the room's join port with the C13 path. The relay forwards the game's own ENet datagrams untouched. Each side opens its path with a 12-byte probe sent from its own ENet socket, which also gets it through a home NAT. Neither player ever learns the other's address. Punch-through, for direct connections, is not built.
- **Abuse limits.** Per address: registrations, resolutions and live rooms; in all: rooms, players per room, a code's life (10 minutes), idle paths closed after 60 s, a 1400-byte payload cap and a packet rate per room. Bad packets, bad codes, unknown sources and wrong tokens are dropped. A source's first request gets only a cookie it must send back, and a request (64 bytes) is never shorter than a reply, so the relay can't be used to amplify.
- **Privacy.** No accounts, no analytics, no disk. Addresses stay in memory only while a code lives or a path carries traffic, and nothing the relay prints holds an address, a code or a token.
- **Off by default.** The relay URL is empty in the settings and in `resources/room.tres`, so the shipped game makes no network call at all. A player sets one in Settings, Multiplayer (`udp://host:9010`, or since C16d `ws://` or `wss://`); it counts from the next host or join.
- **Run it.** `relay/run_relay.sh` runs it in the foreground (127.0.0.1:9010 unless told otherwise); `relay/sigkill-relay.service` is an example systemd unit for a plain Linux server. Neither is installed or enabled anywhere.
- **Seen on 127.0.0.1 only.** One machine, headless: a real host and joiner played through it. Two real networks, real NATs and the traffic of a real match are untested, so the hosting cost has no monthly figure yet.

The test, `tests/relay_test.gd`, runs the relay as its own process and plays a match through it.

### Built: WebSocket relay mode (C16d)

For a host machine with no public address and no inbound UDP, reached only through an HTTPS proxy on one port: Fred's pick for hosting is an exe.dev VM. **Tested on 127.0.0.1 only, hosted nowhere yet.**

- **The scheme picks the transport.** A relay URL of `udp://` takes the C16c relay; `ws://` and `wss://` the WebSocket one; any other scheme is refused in Settings (it says which three work) and the game makes no connection for it. `wss://<vm-name>.exe.xyz` is what players would set for an exe.dev relay.
- **One port, rooms by token.** `relay/run_relay.sh --ws-port 8000` runs the same relay on one TCP port: the same room codes, `sigkill://join/` links, cookie, rate, room, payload and idle limits as C16c, with rooms told apart by their tokens instead of ports. On top: a cap on connections, a 5 s handshake limit, and a room that ends with its host's link.
- **The match is unchanged.** The game's own ENet still carries it: the game's WebSocket client holds loopback sockets on 127.0.0.1 that ENet talks to, and carries every datagram over its one link to the relay. Neither player sees the other's address, or the relay's.
- **TLS is the proxy's.** `wss://` is TLS that the proxy in front of the relay terminates; the relay speaks plain `ws://` on the VM. A `wss://` URL is proven to take the WebSocket path with TLS, and nothing past that: no proxy stands in for exe.dev's in the tests.
- **TCP, not UDP.** Over WebSocket the match rides one TCP stream, so packet loss shows as hitching where UDP would only drop a packet. The UDP relay stays the choice wherever a server has a public address.
- **Deploy notes** for exe.dev (one HTTP port shared through its HTTPS proxy, an example systemd unit, `relay/sigkill-relay-ws.service`) and the cost note are in [docs/RELAY.md](docs/RELAY.md). Nothing has been deployed, no VM made, no account used.

The test, `tests/relay_ws_test.gd`, runs the WebSocket relay as its own process and plays a match through it by room code.

## Architecture

### Project tree

The project layout, from `git ls-files`. Godot also keeps a small `.uid` file next to each script and shader, and the media folder under docs holds the README images.

```text
sigkill/
├── README.md                   This page
├── .gitignore                  Keeps Godot's cache and build output out of git
├── CREDITS.md                  Contributors and community prompts
├── project.godot               Godot 4.7 project: main scene, version (0.33.0-prealpha), icon, physics layer names, Forward+, black clear colour, the daemons' shader clock
├── export_presets.cfg          The one export preset, "Linux x86_64": one binary with the pack inside; tests, tools, docs and the relay left out
├── packaging/
│   └── linux/
│       ├── sigkill.desktop     The launcher entry the release installs
│       ├── sigkill.svg         The nixfred hexagon, byte for byte the brand file: the launcher's and the window's icon
│       ├── install.sh          User-local install from the unpacked release: three files under ~/.local, no sudo
│       └── uninstall.sh        Removes exactly those three files
├── scenes/
│   ├── boot.tscn               The boot screen, the main scene: AI link, opt-in, GPU readout, then the arena
│   ├── main.tscn               Root level: sun light, arena, player and HUD
│   ├── arena.tscn              Greybox arena, its sky and depth fog, five spawn points, the four target dummies, the code rain driver, the dressing and the skyline
│   ├── player.tscn             First-person player: capsule, head, camera, the movement tuning
│   ├── grey_block.tscn         One greybox building block
│   ├── target_dummy.tscn       A target daemon: its hexagonal hit volume, its art (A2) and a floating tag
│   ├── opener.tscn             The opener (C38): one canvas layer over everything, built in code
│   └── hud.tscn                Canvas layer for the code-built HUD
├── scripts/
│   ├── ai/
│   │   ├── ai_source_detector.gd   Finds your AI and GPU stats: agent setting, PATH, localhost servers, /sys, nvidia-smi
│   │   ├── ai_source_result.gd     What it found: fixed words, known agent names and numbers only
│   │   ├── guide_adapter.gd        The guide adapter interface: ask, poll, cancel, pacing, answer cleaning
│   │   ├── agent_adapter.gd        What the agent CLI adapters share: command check, empty scratch folder, launch
│   │   ├── claude_adapter.gd       Claude Code in print mode, every tool off, no permission bypass
│   │   ├── codex_adapter.gd        codex exec in a read-only sandbox, shell tools off, stdin closed
│   │   ├── local_openai_adapter.gd The local server on 127.0.0.1: an already-loaded model only, else needs_consent
│   │   ├── local_http.gd           Polled, capped HTTP client for 127.0.0.1
│   │   ├── quiet_json.gd           A JSON reader that never prints, whatever it is given
│   │   ├── guide_request.gd        The request: whitelisted game stats, cleaned typed text, the fixed preamble
│   │   ├── guide_process.gd        The one program start: argv only, capped output, stops only its own child
│   │   └── guide_registry.gd       Maps the detector's choice to an adapter, with fall-through
│   ├── boot/
│   │   ├── boot_sequence.gd        The boot screen: typed lines, opt-in, handshake, GPU readout, headless guard, demo mode
│   │   ├── boot_tuning.gd          BootTuning: typing, pauses, spinner, GPU pace, handoff wait, sizes and colours, validated
│   │   └── guide_settings.gd       The privacy answers (AI opt-in, roast, real-machine data, opener data) in user://settings.cfg's [privacy]
│   ├── guide/
│   │   ├── guide_link.gd           The session's link to your AI: detection, adapter, opt-in, AI switch, GPU, headless guard
│   │   └── ollama_loader.gd        Loads a model on your Ollama server after your Y, and unloads only what it loaded
│   ├── hud/
│   │   ├── guide_hud.gd            The guide HUD: badge, latency, GPU, ask box on T, answers, AI toggle on O, rate limits
│   │   ├── pause_menu.gd           The Esc menu and the settings screen: every setting on one screen, rebinding, privacy
│   │   ├── first_launch_card.gd    FirstLaunchCard (C42): the first launch's card: a content note, may the intro use real names, No highlighted
│   │   ├── loadout_screen.gd       The loadout screen (C33, Esc > Loadout): the arsenal, each weapon's skin cards and mod card
│   │   ├── loadout_stage.gd        Its turntable: the weapon's own model large in a world of its own, lit live in a skin
│   │   ├── unlock_toast.gd         "UNLOCKED: <name>" near the top the moment a skin or a mod is earned, each in turn
│   │   ├── weapon_hud.gd           The weapon strip: slots, magazine and reserve, reload bar, fiction line, the ult and SIGSTOP meters
│   │   ├── sudo_badge.gd           Root vs user's badge bottom left: user$, the cosmetic password line, root# in red
│   │   ├── ice_hud.gd              ICE's HUD (I1): the hunter's adaptation, the credit tag, a jam's notice, a field's corruption
│   │   ├── breaker_hud.gd          The ICEbreakers' readout (I2) bottom left, an effect's line under the crosshair, the cloak's edge wash
│   │   ├── black_ice_hud.gd        Black ICE on the HUD (I3): its arrival's warning, its line and the scripted guide's word, its tag, the cold edges
│   │   ├── freeze_hud.gd           chmod 000 on the HUD (C29): what the beam does under the crosshair, your own frost, frozen
│   │   ├── pipe_hud.gd             pipe | on the HUD (C30): the last chain written out as a command line under the crosshair
│   │   ├── dev_null_hud.gd         /dev/null on the HUD (C31): a dragged player's warning and plum edges; a hole's tag is on the hole
│   │   ├── sighup_hud.gd           SIGHUP on the HUD (C32): a caught player's glitch, crosshair drift and "hung up"; never a control
│   │   ├── grep_marks.gd           grep's brackets that close as a lock builds, the "match" tags, "grep -c: N" under the crosshair
│   │   ├── spectate_top.gd         Spectate as top: the match as a process table, dead in a match or on Tab, once a second
│   │   ├── top_ledger.gd           The table's record: join order, kills, deaths, damage dealt, time alive, uptime, load
│   │   ├── spectate_top_tuning.gd  SpectateTopTuning: the refresh, the load windows, the rows, the PID base, validated
│   │   └── hud_tuning.gd           HudTuning: layout, sizes, caps, timings, session cap, demo values and colours, validated
│   ├── round/
│   │   ├── round_hud.gd            Rounds: the clock, the break's summary panel, in-round callouts, the roast switch on B
│   │   ├── round_stats.gd          One round's numbers from the game's signals, under the whitelisted round keys
│   │   ├── round_announcer.gd      The round's end: one call through the link, or SIGKILL's own line; plain text only
│   │   └── announcer_tuning.gd     AnnouncerTuning: round and break lengths, callout pace, the 240 cap, layout, validated
│   ├── net/
│   │   ├── net_session.gd          The one owner of the ENet socket: host, join, the handshake, the roster, state packets, shots
│   │   ├── remote_player.gd        Another player's avatar: teal prism, visor, name tag, snapshot interpolation
│   │   ├── net_hud.gd              The multiplayer panel on M: H host, J join with the address box, L leave; the net line
│   │   ├── net_tuning.gd           NetTuning: port, bind address, player cap, name, timeouts, send rate, validated
│   │   ├── combat.gd               The host's combat authority: health, death, respawn, protection, what shots it believes
│   │   ├── combat_hud.gd           Health line, kill feed, damage flash, protection border, death banner, from the host's word
│   │   ├── combat_tuning.gd        CombatTuning: health, respawn and protection times, tolerances, feed, flash, validated
│   │   ├── room_code.gd            Room codes and sigkill://join/ links: draw, normalize, checksum, strict parsing, --join
│   │   ├── rendezvous_client.gd    RendezvousClient: the interface the session uses for room codes
│   │   ├── null_rendezvous.gd      NullRendezvous: never live, never sends anything; the rendezvous with no relay set
│   │   ├── udp_rendezvous.gd       UdpRendezvous: the client of a relay the player set, one socket to it only
│   │   ├── ws_rendezvous.gd        WsRendezvous: the client of a ws:// or wss:// relay, one link, the loopback tunnel for ENet
│   │   ├── relay_wire.gd           The relay's wire format (version 2), relay URLs and the transport each scheme picks
│   │   └── room_tuning.gd          RoomTuning: relay URL (empty), code lifetime, request timeout, redraws, validated
│   ├── settings/
│   │   ├── settings_file.gd        The one settings file: strict scan, versioned ConfigFile, old-file migration, safe writes
│   │   ├── game_settings.gd        GameSettings: every setting, its default and bounds, binds, load and save
│   │   ├── settings_apply.gd       Puts the engine's settings into effect: buses, volumes, window, vsync, frame cap, binds
│   │   └── intro_state.gd          IntroState (C42): the first launch's [intro] section: asked, played, skip next time
│   ├── unlocks/
│   │   ├── progress.gd             Progress (C33): the local save, the feats' counts, what is earned and chosen, the earned rule
│   │   ├── loadout.gd              Loadout: a player's look (a skin and a mod bit a weapon), cleaned, accepted, worn
│   │   ├── weapon_kit.gd           WeaponKit: a weapon's skins (its own first) and its mod, beside its .tres, validated
│   │   ├── weapon_skin.gd          WeaponSkin: a palette skin by name, its name and fiction, the feat that earns it
│   │   └── weapon_mod.gd           WeaponMod: a sidegrade's gains and costs, each checked the right way, applied to a copy
│   ├── opener/
│   │   ├── opener.gd               Opener (C38 to C42): the whole two minutes, the beats, the reveal, the link, the kill, skipping, the pause, sound, the flash model
│   │   ├── opener_data.gd          OpenerData: the one interface the opener reads "your machine" through, and clean()
│   │   ├── demo_opener_data.gd     DemoOpenerData: fixed, invented values; nothing read
│   │   ├── real_opener_data.gd     RealOpenerData (C39): the opt-in reader: names, counts, times, theme, uptime; never contents
│   │   ├── theme_colors.gd         ThemeColors (C39): a colors.toml to the palette by Omarchy's own rules, or refused
│   │   ├── cell_width.gd           CellWidth (C39): how many terminal cells a character takes (wide 2, marks 0)
│   │   ├── opener_palette.gd       OpenerPalette: Omarchy's colour names, with fallbacks; the demo palettes by id
│   │   ├── opener_tuning.gd        OpenerTuning: every beat's time, the typing paces, the sounds and the screen's look
│   │   ├── fake_terminal.gd        FakeTerminal: Omarchy's window, a monospace grid, bash's colours, a blinking block cursor
│   │   ├── typist.gd               Typist: human typing, seeded jitter, beats, a typo taken back, fitted to its window
│   │   ├── tree_layout.gd          TreeLayout (C40): the city from the folder names and counts alone: terraces, slices, towers, the pit
│   │   ├── tree_fall.gd            TreeFall (C40): the machine, a world of its own: the city drawn, the camera's way, the hand-off
│   │   ├── opener_link.gd          OpenerLink (C41): the one call to your AI through the guide link, told only that the game is starting; the fallbacks
│   │   ├── link_beat.gd            LinkBeat (C41): the guide HUD coming alive: the badge, its bars, the panel, the live mark, the guide's line
│   │   ├── pit_beat.gd             PitBeat (C41): the signal and its rings, the copy's walk out of the pit, its steps of light, its name, its lights
│   │   ├── copy_art.gd             CopyArt (C41): the copy of you on A5's kit: the hexagon head with `_<`, the crown, the armour, a planted gait
│   │   ├── forge_beat.gd           ForgeBeat (C42): `kill -9` in cells, their stream, the rifle printing, the copy's line, the beam, the derezz
│   │   ├── title_beat.gd           TitleBeat (C42): the reticle, the kill feed, the whisper, the black, the title slam on the brand's icon file
│   │   ├── opener_score.gd         OpenerScore (C42): the original score made in code on a worker: bed, forge, wait loop, stinger
│   │   └── intro_menu.gd           IntroMenu (C42): the intro's own Esc menu (Skip intro, skip next time) and hold Space to skip
│   ├── modes/
│   │   ├── light_trails.gd         Light-trail mode: every player's walls in one arena, laid, aged, capped, drawn and judged
│   │   └── light_trail_tuning.gd   LightTrailTuning: spacing, height, thickness, lifetime and fade, cap, grace, ground, glow
│   ├── abilities/
│   │   ├── sigstop.gd              SIGSTOP bullet time: F and SIGCONT, the solo slow-mo and its restores, the look, the host's word in a match
│   │   ├── sigstop_meter.gd        The SIGSTOP meter's rules (drain, refill, start share, death, round), shared by player and host
│   │   ├── sigstop_tuning.gd       SigstopTuning: the meter, the world's and the player's pace, the ease, the look, validated
│   │   ├── code_rain_vision.gd     Code-rain vision: hold V, the silhouettes through walls, the green look, off at release, empty, death
│   │   ├── code_rain_vision_meter.gd   The vision meter's rules: drain, rest, refill, start share; nothing ever sent
│   │   ├── code_rain_vision_tuning.gd  CodeRainVisionTuning: the meter, the rest and refill, the range, the look, validated
│   │   ├── sudo_overcharge.gd      Root vs user and sudo: Z, root's timer, the host's word in a match, off at death and respawn
│   │   ├── sudo_state.gd           The sudo rules (kills to a charge, the cap, root, death), shared by player and host
│   │   └── sudo_overcharge_tuning.gd   SudoOverchargeTuning: kills needed, charges, root time, damage scale, the look, validated
│   ├── art/
│   │   └── shape_kit.gd            ShapeKit: boxes, prisms, tubes, spikes, frustums, flat faces, glyphs, true edges; the weapons', daemons' and arena's shapes
│   ├── arena/
│   │   ├── arena_art.gd            ArenaArt: the arena's trims, props, signs, plinth, towers and holograms, built once; visual only
│   │   ├── arena_skyline.gd        ArenaSkyline: the megastructures, data towers, orbital ring and drifting slabs round the arena
│   │   └── arena_font.gd           The signs' 5 by 7 pixel terminal font, as rows of bits
│   ├── fx/
│   │   ├── particle_fx.gd          ParticleFx: the GPU particle pools (sparks, derezz bits, blast debris, trails, frost) and each family's muzzle burst; made once
│   │   ├── frost_look.gd           FrostLook (C29): a target's own parts crusted in frost as its meter fills, whole when frozen, its tag
│   │   ├── hup_look.gd             HupLook (C32): a confused target's "reloading config" tag, then its "?"; its seams told
│   │   └── screen_post.gd          ScreenPost: chromatic aberration and CRT scanlines, under the HUD, drawn only when on
│   ├── daemons/
│   │   ├── daemon_art.gd           DaemonArt: the rig: parts as MultiMesh instances posed each frame, built from a seed (A5), elites, weak points; visual only
│   │   ├── daemon_shatter.gd       A death in shards: the creature's own parts bursting apart over the derezz, drones flying off whole (A5)
│   │   ├── daemon_voice.gd         DaemonVoice (C42): a daemon's or ICE's own tell, strike, hit and death, on the Effects bus
│   │   ├── rogue_daemon.gd         rogue.d: an armoured crimson mantis-scorpion on six IK legs in a tripod gait, its visor flaring as it rears
│   │   ├── zombie_process.gd       The zombie: an amber hulk, armoured right, voxels peeling off its open left, a cannon arm, a dragging limp
│   │   └── runaway_swarm.gd        The runaway: hot-magenta hex drones flocking as boids round a core drone; killing the core scatters them
│   ├── fight/                      The daemons fighting back (C27b)
│   │   ├── daemon_brain.gd         DaemonBrain: a daemon's hunt by sight, its tell, strike and recovery, steering, the leash
│   │   ├── daemon_director.gd      DaemonDirector: the arena's prey, the attacker cap, SIGSTOP, sight, damage, the bolt pool
│   │   ├── glitch_bolt.gd          GlitchBolt: the zombie's slow amber projectile, stopped by the level
│   │   ├── solo_life.gd            SoloLife: the player's 100 health alone, by the match's combat rules and numbers
│   │   └── daemon_ai_tuning.gd     DaemonAiTuning: every number of the fight, and the difficulty's
│   ├── ice/                        ICE (I1): the system defending itself, beside the daemons
│   │   ├── ice_director.gd         IceDirector: the layout, each round's pieces from seeds, judging hits, the adaptation, the fields, the host's word
│   │   ├── ice_piece.gd            IcePiece: a piece's health, its capped hits with their source, its shatter in its colour
│   │   ├── ice_barrier.gd          IceBarrier: a white ICE wall, a skin shots land on round a core that blocks like the level
│   │   ├── ice_node.gd             IceNode: a white ICE node: its tell, its dome at the field's reach, the jam or the HUD corruption
│   │   ├── hunter_ice.gd           HunterIce: hunter ICE, its body and its shields' colour
│   │   ├── hunter_brain.gd         HunterBrain: the daemons' brain with the hunter's numbers and its lance
│   │   ├── ice_art.gd              IceArt: ICE's art on A5's rig: cracks, a tint, no elite
│   │   ├── barrier_art.gd          A wall: faceted panes in a crystal lattice, a lock, pylons, a crown; cracks and falling panes
│   │   ├── node_art.gd             A node: a heart in a cage of turning crystal shields on a tripod; the jam's lock, the HUD's antennas
│   │   ├── hunter_art.gd           The hunter: a lens hull, swept blades, shield satellites that close into an iris for its tell, its trace and lance
│   │   ├── ice_tuning.gd           IceTuning: every number of ICE, a tell never under a second, never immunity
│   │   ├── breakers.gd             Breakers (I2): one intruder's carried breakers, its counts and the loaded kind
│   │   ├── breaker_director.gd     BreakerDirector: every intruder's breakers, what each does, the decoys, the pickups, the host's word
│   │   ├── decoy.gd                Decoy: a thrown decoy, its flight, its call, what strikes it, its burst
│   │   ├── breaker_pickup.gd       BreakerPickup: a pickup at a seeded spot, its kind's tag
│   │   ├── breaker_art.gd          A pickup's split crystal and emblem, a decoy's effigy, on A5's rig
│   │   ├── exploit_marks.gd        ExploitMarks: exploit's seam marks on this screen, one MultiMesh
│   │   ├── breaker_pick.gd         The guide's breaker pick: the round's numbers only, the scripted pick
│   │   ├── breaker_tuning.gd       BreakerTuning: every number of the breakers and the pickups
│   │   ├── black_ice.gd            BlackIce (I3): its arrival, its phases, its seals and the combo, its touch, the host's word
│   │   ├── black_ice_brain.gd      BlackIceBrain: the daemons' brain with no attack: it hunts by sight, drifts, reels, follows a decoy
│   │   ├── black_ice_art.gd        Black ICE's look: a black sun of crystal spikes on spike legs, a dim heart, seals of cold light
│   │   ├── black_ice_tuning.gd     BlackIceTuning: its rarity, arrival, body, movement, seals; never round 1, always slower than a run
│   │   └── blackout.gd             Blackout: the arena's hum, and its lights dying while Black ICE is out
│   ├── viewmodels/
│   │   ├── viewmodel.gd            Viewmodel: a weapon held in first person, built once from shapes; glow, look, charge, Muzzle
│   │   ├── terminal_cannon.gd      The terminal cannon's model: compact carbine, brake, ">_" prompt
│   │   ├── sigterm.gd              SIGTERM's model: over-under pump, violet rings, chevrons
│   │   ├── sigkill_rail.gd         The rail's model: two rails, four coils lit in order by the charge, long scope
│   │   ├── fork_bomb.gd            The fork bomb's model: a hex cage round a turning drum of lit pods
│   │   ├── fork_shotgun.gd         fork()'s model: one barrel forking into two prongs
│   │   ├── grep_seeker.gd          grep's model: fat scope, lit lenses, dart pod
│   │   ├── rm_rf_cannon.gd         rm -rf's model: fat housing, core and vents lit by the wind-up, hazard stripes
│   │   ├── cron_mines.gd           cron's model: a dispenser, the next mine loaded, a clock hand on top
│   │   ├── ping_sonar.gd           ping's model: a sonar emitter, a dish whose three rings relight with the cooldown, a turning sweep
│   │   ├── chmod_000.gd            chmod 000's model: a hexagonal emitter, a coolant tank lit by what is left, r w x tumblers, a crystal lens
│   │   ├── pipe_chain.gd           pipe |'s model: a length of pipe, a gauge of lit | bars, a tee and its valve, a lit | filament
│   │   ├── dev_null.gd             /dev/null's model: prongs cupping a black glass sphere, a photon ring, two gyro rings, charge cells
│   │   └── sighup.gd               SIGHUP's model: a telephone handset in hard geometry, its coiled cord, carrier rings, charge lights
│   ├── weapons/
│   │   ├── weapon_def.gd           WeaponDef: one weapon, every value once (on top of WeaponTuning), validated; falloff, pellets
│   │   ├── arsenal_tuning.gd       ArsenalTuning: the loadout and the swap, draw and reload numbers; refuses broken weapons
│   │   ├── inventory.gd            What a player holds: slots, magazines, reserves, intervals, swap and reload, the quick throw
│   │   ├── fork_bomb.gd            One throw of the fork bomb: the chain of bomblets, the seeded scatter, the rings, the live cap
│   │   ├── fork_volley.gd          One fork() shot: the fan of pellets in flight, their forks and flashes, walls, range, the judge
│   │   ├── grep_lock.gd            grep's marks: the lock in the cone, range and sight, the cap, the grace, every way a mark drops
│   │   ├── seeker_volley.gd        One grep shot: a dart per mark turning toward it at its limit, or one straight; walls, range, the judge
│   │   ├── rm_slug.gd              One rm -rf shot: the slow slug, where it stops, the blast ring, the judge; a joiner's waits for the word
│   │   ├── cron_mine.gd            One cron mine: where it sticks, its schedule, the closing ring and brighten, each run, its fade
│   │   ├── ping_pulse.gd           One ping: the ring through the walls, the daemons it meets, a tell it catches staggered, its look
│   │   ├── ping_reveal.gd          A daemon ping found: its own parts outlined through the level and its tag, then the fade
│   │   ├── freeze_beam.gd          chmod 000's beam as drawn: its core and sheath, the shards down it, the bloom and spray, the hiss
│   │   ├── frost.gd                Frost: one target's freeze meter, its freeze, the thaw and its guard, the word's bits
│   │   ├── coolant.gd              Coolant: chmod 000's tank, spent by the beam, resting, refilling, venting
│   │   ├── freeze_tuning.gd        FreezeTuning: every number of the freeze and the coolant, validated
│   │   ├── pipe_chain.gd           PipeChain: one chain's rules, link to link, shared by the shooter and the host
│   │   ├── pipe_arc.gd             pipe |'s chain as drawn: braided arcs racing link to link, their packets, blooms and spills
│   │   ├── pipe_buffer.gd          PipeBuffer: the pipe's buffer, written by each chain, draining, blocking when full
│   │   ├── pipe_tuning.gd          PipeTuning: every number of the chain and the buffer, validated
│   │   ├── dev_null_hole.gd        One /dev/null throw: the device's flight, the hole's pull, hold, damage, discard and implosion
│   │   ├── dev_null_look.gd        The hole as drawn: the black core, lensing, accretion ring, debris spiral, floor well, tag, implosion
│   │   ├── dev_null_tuning.gd      DevNullTuning: every number of the throw, the charges and the hole, validated
│   │   ├── sighup_burst.gd         One SIGHUP throw: the device's flight, the wave's sweep, who it confuses, Black ICE's refusal
│   │   ├── sighup_look.gd          The burst as drawn: the handset, the flash and spike, the carrier wave, the curtain, the tag
│   │   ├── sighup_tuning.gd        SighupTuning: every number of the throw, the charges, the burst and the confusion, validated
│   │   └── fork_bomb_tuning.gd     ForkBombTuning: the throw, the fuses, the scatter, the blast and its falloff, the caps, the look
│   ├── main.gd                 Wires targets, player, HUD and the rain driver, applies palette colours, R respawns targets
│   ├── player.gd               Movement, slide, head bob, FOV kick, mouse look, weapons, pellets, recoil, the test hook
│   ├── controls.gd             The input map, registered in code; what may be a bind, and conflicts
│   ├── movement_tuning.gd      MovementTuning: the exposed movement and camera tuning, validated
│   ├── weapon_tuning.gd        WeaponTuning: a weapon's feel (firing, viewmodel, recoil, effects, sounds), validated
│   ├── derezz_tuning.gd        DerezzTuning: the exposed derezz and respawn tuning, validated
│   ├── code_rain_tuning.gd     CodeRainTuning: the exposed code rain tuning, validated
│   ├── guide_tuning.gd         GuideTuning: the guide's switch, pacing, timeouts and caps, validated
│   ├── palette.gd              Every colour, plus the material factory
│   ├── grey_block.gd           Builds a block's mesh, collision and material; registers for code rain; previews in the editor
│   ├── target_dummy.gd         Dummy state machine: takes hits, derezzes, respawns at full health; wears its art
│   ├── derezz_fx.gd            The derezz: capped voxels in one MultiMesh per death, its flash; self-freeing
│   ├── code_rain_driver.gd     Feeds live enemy positions and faded weights to the code rain shader
│   ├── hud.gd                  Status line, hint line, click-to-engage overlay, crosshair, hit marker, the HUDs, the Esc menu, the colour filter
│   ├── crosshair.gd            Crosshair drawn in code, in the style and colour the settings pick; kicks on every shot
│   ├── hit_marker.gd           Diagonal hit marker, shown only on a confirmed hit
│   ├── cannon_fx.gd            Every weapon's beam, muzzle flash and light, impact flash and sparks, in its light skin; self-freeing; A4's GPU particles ride on it
│   ├── sfx_synth.gd            Fire, hit, reload and callout sounds synthesised in code
│   ├── play.sh                 Plays from source: the one-time import if it is missing, then the game
│   └── check.sh                The headless quality gate
├── relay/
│   ├── relay_server.gd         The relay: rendezvous, forwarding, limits, cookies, counters; memory only
│   ├── relay_ws.gd             Its WebSocket transport (C16d): one TCP port, rooms by token, the same rules
│   ├── relay_main.gd           Runs it headless: settings from env and flags, the stop file, counter lines
│   ├── run_relay.sh            Runs it in the foreground (127.0.0.1:9010 unless told otherwise)
│   ├── sigkill-relay.service   Example systemd unit for a plain Linux server; never installed
│   └── sigkill-relay-ws.service Example unit for WebSocket mode behind an HTTPS proxy (exe.dev); never installed
├── shaders/
│   ├── opener_glitch.gdshader  The opener's fake crash on the frozen frame: slipped slices, smears, stuck runs, split channels
│   ├── opener_screen.gdshader  The fake terminal as a screen: a soft glow, faint scanlines, a vignette, a torn band
│   ├── opener_panel.gdshader   The terminal on the monolith's screen (C40): pixel for pixel as the camera starts, then averaged
│   ├── opener_tower.gdshader   The city's boxes (C40): Tron edges, hashed window grids, the wall of screens, mazes, heat
│   ├── opener_terrace.gdshader The terraces and the ceiling (C40): a floor grid, rims of light, circuit traces, the pit's red
│   ├── opener_maze.gdshader    The node_modules pit's walls (C40): a 10 PRINT maze, brighter toward the bottom
│   ├── opener_stream.gdshader  Code light pouring down the shaft and the tree's cables (C40), turned to face the camera
│   ├── opener_speed.gdshader   Motes and speed lines round the camera (C40), placed in the shader
│   ├── opener_sky.gdshader     The dark the machine stands in (C40), red-violet below
│   ├── opener_core.gdshader    The hottest process's core at the bottom of the pit (C40)
│   ├── opener_signal.gdshader  The link's signal (C41): heads racing up out of the pit with tails, a trace, a flare at the lock
│   ├── opener_floor.gdshader   Light on the pit's floor (C41): the link's teal rings, the copy's red rings, its hexagon steps
│   ├── opener_forge.gdshader   The forge's light (C42): the cells of `kill -9` and the derezz's voxels, the shot's beam
│   ├── opener_print.gdshader   The rifle printing itself (C42): a white-hot band of hex cells sweeping down its barrel
│   ├── opener_post.gdshader    The machine's picture punched (C42): split, shake, torn bands, the shot's flash
│   ├── floor_grid.gdshader     World-space floor: dark deck plates, seams, insets and vents, a faint grid and 8 m light strips
│   ├── neon_edge.gdshaderinc   The neon edge maths, shared by the two shaders below
│   ├── neon_edge.gdshader      Neon outline edges for boxes and hexagonal prisms; the dummies' look
│   ├── code_rain.gdshader      Neon edges plus Matrix code rain near enemies; the blocks' look
│   ├── colorblind_safe.gdshader The colorblind-safe palette: a full-screen hue filter to the Okabe-Ito pair
│   ├── sigstop_look.gdshader   SIGSTOP's look on your own screen: grey, the theme's teal, motion trails
│   ├── viewmodel_metal.gdshader The viewmodels' dark metal: panel lines or hex cells, a faint neon rim
│   ├── daemon_glitch.gdshaderinc The daemons' shared glitch, their shader clock and their pinned instance uniforms
│   ├── daemon_armor.gdshader   The daemons' armour (A5): dark gunmetal, a steel catch-light on true edges, a thin rim of the type's colour
│   ├── daemon_shell.gdshader   The daemons' obsidian: true edges, scanlines, the hit and the lock; the zombie's peeling voxels since A5
│   ├── daemon_split.gdshader   The glitch's RGB split: a shell's edges drawn again, offset in hostile magenta (cyan before A4)
│   ├── daemon_core.gdshader    A daemon's seams, joints and weak points in its kind's colour: breathing, guttering, flickering, flaring
│   ├── ice_crystal.gdshader    ICE's crystal (I1): dark faceted glass, light in its seams, fracture lines spreading as it cracks
│   ├── ice_field.gdshader      A white ICE node's field: a lattice dome at its reach, rising through the tell, flashing as it fires
│   ├── breaker_mark.gdshader   Exploit's seam marks (I2): an ultraviolet diamond facing the camera, pulled toward the eye, pulsing
│   ├── daemon_trail.gdshader   The swarm's light trails, white-hot at the head
│   ├── daemon_glyphs.gdshader  The daemons' floating glyphs in each one's colour, procedural, facing the camera
│   ├── derezz_voxel.gdshader   A derezz's voxels: edges lit, faces falling away as they fade
│   ├── vision_glyphs.gdshader  Code-rain vision's silhouettes: the walls' glyphs, additive, with no depth test
│   ├── arena_panel.gdshader    The arena's gunmetal: true edges in teal, fading with distance, darker near the floor
│   ├── arena_light.gdshader    The arena's light strips, sign letters, conduit flow and blinking beacons
│   ├── arena_screen.gdshader   Terminal screens scrolling procedural text, and server racks' blinking units
│   ├── arena_holo.gdshader     The floating ">_" holograms, turning and bobbing in the vertex stage
│   ├── arena_tower.gdshader    The skyline's towers and slabs: true edges and a grid of lit windows
│   ├── arena_sky.gdshader      The sky: the void, a teal haze and glow band at the horizon, the abyss, data points
│   ├── screen_post.gdshader    The post effects: red and blue pulled apart toward the edges, scanlines, a grille, a vignette
│   ├── damage_vignette.gdshader The hit's red vignette: colour from the edges in, never a warp
│   ├── ping_wave.gdshader      ping's ring: the floor's bright front, wash and echo lines, the wall of light on it
│   ├── ping_reveal.gdshader    ping's outline: a daemon's own parts through the level, rim, fill and climbing scan bands
│   ├── freeze_beam.gdshader    chmod 000's beam: a hot core, a frost-opal sheath with light running down it
│   ├── frost_crust.gdshader    chmod 000's frost: a crystalline crust on a target's own parts, creeping up as it fills
│   ├── pipe_arc.gdshader       pipe |'s arcs: a hot core in a brass sheath, bars of data flowing down them
│   ├── dev_null_lens.gdshader  /dev/null's lensing: the arena behind the hole bent round it, the photon ring and the halo
│   ├── dev_null_disc.gdshader  /dev/null's accretion ring: plum matter streaming in on log spirals, white-hot inside
│   ├── dev_null_debris.gdshader  /dev/null's debris: streaks spiralling in, each path drawn by the shader
│   ├── dev_null_floor.gdshader  /dev/null's floor mark: the well, its reach in drifting dashes, the horizon
│   ├── sighup_wave.gdshader    SIGHUP's carrier wave: an oscilloscope trace round its front, its ghosts, static, tears
│   ├── sighup_curtain.gdshader  SIGHUP's curtain: thin lines of interference on the front, the trace low round it
│   └── sighup_glitch.gdshader  SIGHUP on a caught player's screen: rows of green static, scanlines at the edges
├── resources/
│   ├── movement_tuning.tres    Default movement tuning
│   ├── terminal_cannon.tres    Weapon #1, the terminal cannon: a WeaponDef
│   ├── sigterm.tres            SIGTERM, the polite shotgun: a WeaponDef
│   ├── sigkill_rail.tres       The SIGKILL rail rifle, the ult: a WeaponDef with a meter, a charge and a pierce
│   ├── fork_bomb_weapon.tres   The fork bomb, weapon 4: a thrown WeaponDef with two bombs
│   ├── fork_shotgun.tres       The fork() shotgun, weapon 5: 6 pellets that fork at 4 m, every number of it
│   ├── grep_seeker.tres        The grep seeker, weapon 6: the lock, the marks, the darts, every number of it
│   ├── rm_rf_cannon.tres       The rm -rf cannon, weapon 7: the wind-up, the weight, the slug, the blast, every number of it
│   ├── cron_mines.tres         The cron mines, weapon 8: the placement, the schedule, the crontab, the blast, every number of it
│   ├── ping_sonar.tres         ping, weapon 9: the cooldown, the ring's reach and time, the reveal, every number of it
│   ├── chmod_000.tres          chmod 000, weapon 10 (bank 2): the beam, the coolant, the freeze, every number of it
│   ├── pipe_chain.tres         pipe |, weapon 11 (bank 2): the chain, the buffer, every number of it
│   ├── dev_null.tres           /dev/null, weapon 12 (bank 2): the throw, the charges, the hole, every number of it
│   ├── sighup.tres             SIGHUP, weapon 13 (bank 2): the throw, the charges, the burst, the confusion, every number of it
│   ├── <id>_kit.tres           Each weapon's kit beside it (C33, thirteen): its own skin, two to earn, its mod's numbers, each feat
│   ├── fork_bomb.tres          The fork bomb's chain: every number of it
│   ├── light_trail.tres        Light-trail mode: every number of the walls
│   ├── arsenal.tres            The loadout (all thirteen weapons, in slot order, two banks) and the swap timing
│   ├── code_rain_vision.tres   Code-rain vision: the meter, the rest and refill, the range, the look
│   ├── sudo_overcharge.tres    Root vs user and sudo: 3 kills, 1 charge, 8 s of root at 1.5 times, the look
│   ├── spectate_top.tres       Spectate as top: a 1 s refresh, 10, 30 and 60 s load windows, 8 rows, PIDs from 100
│   ├── sigstop.tres            SIGSTOP bullet time: the meter, the world's and the player's pace, the ease, the look
│   ├── derezz.tres             Default derezz tuning
│   ├── daemon_ai.tres          The daemons fighting back: sight, leash, the cap, each type's attack, a ping's stagger, difficulty
│   ├── ice.tres                ICE (I1): the walls, the cap, both nodes, the hunter, the adaptation
│   ├── breakers.tres           The ICEbreakers (I2): the counts, the brute, exploit, cloak, the decoy, the pickups
│   ├── black_ice.tres          Black ICE (I3): its rarity, its arrival, its body and touch, its movement, its seals
│   ├── code_rain.tres          Default code rain tuning
│   ├── guide.tres              Default guide tuning, AI off
│   ├── boot.tres               Default boot screen tuning
│   ├── hud.tres                Default guide HUD tuning
│   ├── announcer.tres          Default round and announcer tuning
│   ├── net.tres                Default LAN and tailnet tuning
│   ├── combat.tres             Default synced combat tuning
│   ├── opener.tres             The opener's timeline and look (C38)
│   ├── opener/                 The opener's six demo palettes: night, mocha, ember, frost, forest, latte
│   └── room.tres               Default room code tuning, no relay URL
├── tests/
│   ├── movement_test.gd        Headless movement test
│   ├── cannon_test.gd          Headless cannon test
│   ├── derezz_test.gd          Headless derezz test
│   ├── code_rain_test.gd       Headless code rain test
│   ├── ai_detector_test.gd     Headless AI detector test, fakes only
│   ├── guide_adapter_test.gd   Headless guide adapter test, stubs and a fake server only
│   ├── boot_sequence_test.gd   Headless boot sequence test, spies, stubs and a fake server only
│   ├── guide_hud_test.gd       Headless guide HUD test, fakes only, input blocking checked in the real arena
│   ├── model_load_test.gd      Headless model load test against a fake Ollama server with fake model names
│   ├── round_test.gd           Headless round test: the real arena's round numbers, one call per round end, stub adapter only
│   ├── net_test.gd             Headless net test: a host and joiners in one process over ENet on 127.0.0.1
│   ├── combat_test.gd          Headless combat test: real cannons and the host's ray, same harness
│   ├── weapon_test.gd          Headless weapon test: defs, loadout, inventory, pellets, the real arena, a match on 127.0.0.1
│   ├── room_test.gd            Headless room code test: codes, links, NullRendezvous, the fake rendezvous on 127.0.0.1
│   ├── settings_test.gd        Headless settings test: the file, binds, the screen, every setting's effect, a match on 127.0.0.1
│   ├── relay_test.gd           Headless relay test: the relay as its own process on 127.0.0.1, a match through it, every limit
│   ├── relay_ws_test.gd        Headless WebSocket relay test: the scheme, a match over ws:// on 127.0.0.1, every limit
│   ├── fork_bomb_test.gd       Headless fork bomb test: 1, 2, 4, 8, the caps, ammo, damage and walls, a match on 127.0.0.1
│   ├── fork_shotgun_test.gd    Headless fork() shotgun test: 6, 12, 24, the fork distance, walls, range, damage, a match on 127.0.0.1
│   ├── grep_seeker_test.gd     Headless grep seeker test: locks to the frame, 3 and 5 marks, drops, homing, misses, forged claims, protocol 9
│   ├── rm_rf_cannon_test.gd    Headless rm -rf cannon test: the wind-up to the frame, cancels, the weight, falloff, cover, self-kills, 3 players
│   ├── cron_mines_test.gd      Headless cron mines test: runs to the frame, placement, the crontab, falloff, persistence, crontab -r, 3 players
│   ├── viewmodel_test.gd       Headless viewmodel test: every model built, muzzles in view, kick, sway, stride, charges, nothing rebuilt
│   ├── enemy_art_test.gd       Headless enemy art test: each daemon kind, budget, shared materials, its clock, the hit volume unchanged, the derezz
│   ├── arena_art_test.gd       Headless arena art test: budgets, no collision, collision and sight lines as before A3, clearance, shared materials
│   ├── enemy_motion_test.gd    Headless enemy motion test: legs, the zombie's armour, voxels and limp, boids, hits, the shatter, scale, budgets
│   ├── graphics_test.gd        Headless lighting, post and particles test: presets, settings, pools and caps, the fixed projection, gameplay as at dee2482
│   ├── daemon_ai_test.gd       Headless daemon AI test: tells before every attack, walls, SIGSTOP, practice, difficulty, the cap, a match
│   ├── ping_test.gd            Headless ping test: the ring, outlines through walls, the radius, the fade, tells broken, the cooldown, a match
│   ├── daemon_variety_test.gd  Headless daemon variety test: seeds, builds, the elite rate, sizes, a respawn rebuilt, the swarm's scatter, a match
│   ├── ice_test.gd             Headless ICE test: the walls, the fields' tells, the hunter's lance and adaptation, off switches, seeds, a match
│   ├── breaker_test.gd         Headless ICEbreaker test: each breaker, counts, pickups, U and Y, the AI pick (stubs), off switches, a match
│   ├── black_ice_test.gd       Headless Black ICE test: rarity, arrival, lights, hum and link, the touch, weapons, the combo, decoy, cloak, a match
│   ├── freeze_ray_test.gd      Headless freeze ray test: the bank keys, the strip, the meter, the freeze, the shatter, coolant, ICE, a match
│   ├── pipe_chain_test.gd      Headless pipe chain test: the chain's rules, Shift+2, the strip, practice, walls, frozen, ICE, a match
│   ├── dev_null_test.gd        Headless /dev/null test: the hole's rules, Shift+3, the throw, practice, tells, frozen, walls, ICE, mines, a match
│   ├── sighup_test.gd          Headless SIGHUP test: its rules, Shift+4, the throw, practice, the guard, lashes, frozen, a hole, ping, ICE, a match
│   ├── unlocks_test.gd         Headless unlocks test: kits, skins' colours, mods, the save, thresholds, earning, the screen at 960x540, a match
│   ├── opener_test.gd          Headless opener test: the code, the seam, palettes, typing, a whole run's windows and words, the flash cap, Esc, the menu
│   ├── opener_real_test.gd     Headless opener real-data test (C39): the reader on a fake home, its caps, links, the theme, fallbacks, cells, the opt-in
│   ├── opener_fall_test.gd     Headless opener fall test (C40): the city from names, its caps, the camera's way, fake homes, the machine dropped
│   ├── trailer_test.gd         Headless trailer test (T1): the shot list, the demo-only refusals, the tool refusing headless, its reads, the shell's display
│   ├── opener_link_test.gd     Headless opener link test (C41): the agent's argv and prompt, the fallbacks, the beats never waiting, the copy, Esc
│   ├── opener_end_test.gd      Headless opener end test (C42): the forge, the shot, the title, the score, voices, skipping, the first launch
│   ├── code_rain_vision_test.gd  Headless code-rain vision test: the meter to the frame, the silhouettes behind a wall, a match on 127.0.0.1
│   ├── root_sudo_test.gd       Headless root and sudo test: the rules, 1.5x and free ammo on a real dummy, a match the host judges
│   ├── spectate_top_test.gd    Headless spectate top test: the record, top's columns, Tab alone, a match on 127.0.0.1, protocol 8 (9 since C25)
│   ├── light_trail_test.gd     Headless light trail test: the walls' rules, the setting and flag, a match the host judges on 127.0.0.1
│   ├── rail_test.gd            Headless rail test: the meter, the charge, the pierce, the callout, the feed, a match on 127.0.0.1
│   ├── bullet_time_test.gd     Headless bullet time test: SIGSTOP's meter, the time scale and its restores, the rebind, a match on 127.0.0.1
│   ├── support/guide_fakes.gd  The fake detector and stub adapter the guide tests share
│   ├── support/fake_rendezvous.gd  Test-only rendezvous server and client on 127.0.0.1
│   └── fixtures/ai/            Fake agent settings, PATH, /sys and stubs for the AI tests, with a README.md
│       └── guide/              Stub claude and codex CLIs that record how they were launched
├── tools/
│   ├── capture_shots.gd        Demo-data stills for this page, by set: a1 the weapons, a2 the daemons, a3 the arena, a2b the creatures, a4 the lit arena, c27b the fight, c28 ping, a5 the armoured daemons, i1 ICE, i2 the ICEbreakers, i3 Black ICE, c29 to c32 bank 2, c33 the loadout, c38 to c40 the opener; the game never runs it
│   ├── capture_shots.sh        Runs it on a private Xvnc display: no TCP, never the desktop, no sound, user data in a work folder
│   ├── trailer.gd              The teaser's shot list (T1): real in-game clips on demo data, its own camera moves, one shot a run
│   ├── trailer_capture.sh      Renders it with Movie Maker on a private Xvnc display from a git archive copy: one clip a shot, shots.json
│   └── export_linux.sh         The release build: the headless export, then the tarball and its sha256 (needs the export templates)
└── docs/
    ├── PRD.md                  Product requirements: features, safety rules, chunk plan
    ├── DESIGN.md               Decisions log and design notes
    ├── ENGINE.md               Why Godot 4
    ├── RELAY.md                The relay: design, wire format, WebSocket mode, limits, running it locally, on a server and on exe.dev, hosting cost
    ├── STORY.md                The story bible (C34): locked 2026-10-30, the source of truth for missions and the opener's `~`
    ├── TRAILER.md              The teaser footage (T1): how to re-render it, what it needs, demo data only
    ├── RELEASE_NOTES-0.33.0-prealpha.md  The pre-alpha drop: what is in, what is not yet, known issues
    ├── RELEASE_CHECKLIST.md    What is left before the 0.33.0-prealpha tag
    └── media/                  README art and A1's in-game stills; .gdignore keeps Godot from importing it
```

### Tuning resources

Feel is data, not code. Twenty-six custom resources hold the exposed tuning parameters for player movement, the camera, the weapons and the loadout, chmod 000's freeze, pipe |'s chain and buffer, /dev/null's hole, SIGHUP's burst and confusion, the daemons, ICE, the ICEbreakers, Black ICE, the fork bomb's chain, light-trail mode's walls, SIGSTOP bullet time, code-rain vision, root vs user and sudo, the top table, the derezz, the code rain, the AI guide, the boot screen, the guide HUD, the rounds, LAN play, synced combat and room codes, each with a default instance: the player scene loads the movement tuning and the player the loadout, every target dummy loads the derezz tuning, the arena's rain driver loads the code rain tuning, the guide adapters load the guide tuning, the boot screen, the guide HUD and the round HUD load their own, and the net session loads its own five (light trails' and the top table's among them). Some numbers live elsewhere on purpose or for now: gravity comes from the project settings, the player's collision capsule from its scene, and HUD sizes and the dummies' hit pulse from their own scripts.

- **MovementTuning**, `scripts/movement_tuning.gd` with `resources/movement_tuning.tres`. Groups: Ground, Air, Slide, Crouch and aim, Camera, Head bob, World. Walk speed, acceleration and friction, gravity scale, jump, air control, the whole slide (threshold, burst, friction, timer, cooldown, slide-jump cap, lowered camera), the crouch height and pace, how far aiming narrows the view, the right stick's turn rate, mouse sensitivity and pitch limit, FOV and its kick, head bob and its on/off toggle, fall respawn height.
- **WeaponDef** (on top of **WeaponTuning**), `scripts/weapons/weapon_def.gd` and `scripts/weapon_tuning.gd`, one `.tres` per weapon: `resources/terminal_cannon.tres`, `resources/sigterm.tres`, `resources/sigkill_rail.tres`, `resources/fork_shotgun.tres` (C24), `resources/grep_seeker.tres` (C25), `resources/rm_rf_cannon.tres` (C26), `resources/cron_mines.tres` (C27), `resources/ping_sonar.tres` (C28), `resources/chmod_000.tres` (C29, with its FreezeTuning inside it, `scripts/weapons/freeze_tuning.gd`: the coolant, the freeze meters' times, the freezes, the guards, the player's slow, the frozen hit and the shatter, Black ICE's slow) and `resources/pipe_chain.tres` (C30, with its PipeTuning inside it, `scripts/weapons/pipe_tuning.gd`). WeaponTuning's groups: Firing, Viewmodel, Recoil, Beam, Muzzle flash, Impact, Hit marker, Audio: the fire interval, range, damage (the cannon's 25, of a player's 100 health; SIGTERM's 14 a pellet), hit layers, the weapon's model in first person, its place and its kick, recoil and its caps and recovery, every effect's size, brightness and lifetime, the hit marker, and every parameter of the synthesised sounds including a master volume. WeaponDef's groups: Identity, Mode, Ammo, Falloff, Look, Rail, Ult, Fork, Seek, Blast, Mine, Slots: id, names, fiction line, kill word, fire mode, pellets and spread, magazine, reserve and reload, the falloff's start, end and floor, the light skin and reload sound, the charge, the pierce and the feed's fake pid (C17), the ult meter and what fills it (C17), fork() pellets' speed, fork distance and angle, child share, generations as user and as root and their look (C24), grep's lock cone, range, time and grace, sight cone, marks as user and as root, root's lock speed, the host's claim tolerances, the darts' speed, turn rate and look and the bracket sizes (C25), the rm -rf cannon's root wind-up share, move share and its time, slug speed and look, blast radius and root's share of it, edge damage, self-damage share, ring time and the joiner's wait, with its self-kill words and charge prompt (C26), cron's placement range, arm delay, run interval, runs and root's extra runs, crontab limit, shot size, fade, stud size, brighten, note time and removal words (C27), and the empty mod and skin slots.
- **ForkBombTuning**, `scripts/weapons/fork_bomb_tuning.gd` with `resources/fork_bomb.tres` (C19). Groups: Throw, Fork, Blast, Caps, Look. The throw's speed and lift, gravity and bounce; 4 generations, the 1.2 s fuse and 0.5 s for each child, the scatter's speed, lift and spread; the blast's 4 m radius, 22 damage and its 30% floor at the edge; 16 live bomblets a player; the rings' time, size, shrink and brightening, and how long a joiner's bomblet waits for the host's word. Fifteen blasts per throw at most, whatever it says.
- **LightTrailTuning**, `scripts/modes/light_trail_tuning.gd` with `resources/light_trail.tres` (C20). Groups: Laying, Wall, Grace, Look. A segment every 0.5 m of ground travel, a new wall past a 2.5 m gap, the ground within 0.15 m of the feet; 1.2 m tall and 0.08 m thick, standing 6 s with a 0.75 s fade, 64 a player; 0.4 s of grace on your own newest walls; a glow of 2.4.
- **SudoOverchargeTuning**, `scripts/abilities/sudo_overcharge_tuning.gd` with `resources/sudo_overcharge.tres` (C22). Groups: Earning, Root, Look. Kills in one life for a sudo charge (3), charges held at most (1), seconds of root (8), the damage multiple while root (1.5), the cosmetic password line's seconds (1.2), the weapon's glow while root (2 times).
- **SpectateTopTuning**, `scripts/hud/spectate_top_tuning.gd` with `resources/spectate_top.tres` (C23). Groups: Refresh, Load average, Rows. Seconds between refreshes, and between the host's table messages (1.0, never less), the three load windows in seconds of play (10, 30, 60), rows shown at most (8) and the first game PID (100).
- **CodeRainVisionTuning**, `scripts/abilities/code_rain_vision_tuning.gd` with `resources/code_rain_vision.tres` (C21). Groups: Meter, Sight, Look. A 3 s meter, a 12 s refill after 1 s of rest, a 25% start; 40 m of sight; the tint (0.45, 0.8, 0.5) at full strength or 0.5 with the comfort settings, a 0.2 s ease, the silhouette capsule (0.6 m by 1.9 m) and its glow (3). The silhouettes' glyphs come from the code rain's own CodeRainTuning.
- **SigstopTuning**, `scripts/abilities/sigstop_tuning.gd` with `resources/sigstop.tres`. Groups: Meter, Slow-mo solo, Look. Seconds of slow-mo in a full meter (4), seconds to refill it from empty (20), the share a start needs (a quarter), the world's pace solo (0.3), the player's pace meanwhile (0.9, in real time), SIGCONT's ease (0.25 s), and the look: how grey, how far toward the theme's teal, how long the motion trails, and every sound's speed (0.7).
- **ArsenalTuning**, `scripts/weapons/arsenal_tuning.gd` with `resources/arsenal.tres`. Groups: Loadout, Swap, Viewmodel motion. The weapons in slot order (up to eighteen in two banks of nine since C29), the swap time (0.3 s), how far a drawn weapon rises (0.25 m), how far a reloading one tips (25 degrees) and how long the fiction line shows (1.6 s); the held weapon's motion (A1): its lag behind a turn (0.025 s, capped at 5 degrees) and how fast it settles, its sway and roll with the stride, its trail behind a fall, the lift in a kick, the tip of a weapon being drawn (22 degrees), and the share of it all kept aimed (0.35).
- **CodeRainTuning**, `scripts/code_rain_tuning.gd` with `resources/code_rain.tres`. Groups: Reach, Fade, Glyphs, Colours. The falloff radius, the minimum and maximum intensity, the enemy cap, the fade-in and fade-out rates, column density, glyph size, fall speed range, tail length, flicker rate, brightness, head and tail colours.
- **DerezzTuning**, `scripts/derezz_tuning.gd` with `resources/derezz.tres`. Groups: Voxels, Motion, Fade, Respawn. The voxel cap and size, the share that glows red and the obsidian tint, glow brightness, burst, upward and shot-push speeds, spread, gravity, bounce, ground friction and the ground layers, the tumble range, the shortest and longest voxel life and the fade curve, the respawn delay and the regrow time.
- **DaemonAiTuning**, `scripts/fight/daemon_ai_tuning.gd` with `resources/daemon_ai.tres` (C27b). Groups: Hunting, rogue.d, zombie, runaway, Ping (C28: a ping's stagger, 1 s and 0.5 m), Difficulty. How far a daemon sees and chases, how long it looks for a player it lost, the attacker cap, its eye, its turning, its feelers; each type's speed, reach, tell, strike, damage, recovery and wait; the bolt's speed, size, life and damage; the swarm's circle, dive and burst; the scatter; easy's and hard's damage and aggression.
- **IceTuning**, `scripts/ice/ice_tuning.gd` with `resources/ice.tres` (I1). Groups: White ICE, Hunter ICE, Adaptation. A wall's health (600) and the most one hit takes off any piece (100); a node's health and how often it looks; each node's trigger range, tell, field, effect and wait; the hunter's first round, health, speed, distance, hover, sight, memory, lance (range, reach, tell, lock, width, damage, strike, recovery, wait) and return; the adaptation's cap (50%) and the damage that reaches it (500). A tell under a second, a lock as long as its tell or adaptation past 0.9 is refused.
- **BreakerTuning**, `scripts/ice/breaker_tuning.gd` with `resources/breakers.tres` (I2). Groups: Carried, brute, exploit, cloak, decoy, Pickups. Each kind's count at a round's start (1) and the cap (2), the gap between two runs; the brute's reach, full-strength distance, far share, cone, damage and a wall's scale; exploit's time, bonus and seam radius; the cloak's time and warning; the decoy's call, throw and pull; the pickups' first, pace, number out and reach.
- **BlackIceTuning**, `scripts/ice/black_ice_tuning.gd` with `resources/black_ice.tres` (I3). Groups: Rarity, Arrival, Body, Movement, Seals, Withdrawing. Its first round (2) and its chance (20%, 10 points a round, 40% at most), the window it arrives in (20 to 40 s of play); the arrival's tell (6 s), how fast and how far the lights go down (2 s, to 10%) and how fast they come back (1.5 s); its body (1.25 m, 4.4 m) and its touch (1.65 m); its speed (4 m/s), drift (2.4), sight (45 m), memory (6 s) and turn; its seals (2), their mend (12 s) and the reel (3 m over 1.2 s); its withdrawal (1.6 s). Round 1, a tell under 3 s, a speed of 5.6 m/s or more (a running player does 7) and a touch inside its own body are refused.
- **FreezeTuning**, `scripts/weapons/freeze_tuning.gd`, inside `resources/chmod_000.tres` (C29). Groups: Coolant, Freeze meter, Frozen, Hits on the frozen, Black ICE. A 4 s tank resting 0.6 s then refilling in 3 s, venting to 40%; the beam's seconds that fill a daemon's meter (1), an elite's (1.5), ICE's (1.6) and a player's (1.5), the hold (0.35 s) and the melt (1.2 s); the freezes (3 s, ICE 2.2, a player 1), the guards after a thaw (1.5 s, a player 2.5), a player's slow (45%); the frozen hit's 2x and the shatter's 40; Black ICE's slow (40% at most, refused past it), in 0.6 s, off in 0.8 s.
- **PipeTuning**, `scripts/weapons/pipe_tuning.gd`, inside `resources/pipe_chain.tres` (C30). Groups: Chain, Frozen link, Buffer. The jump (12 m), the links (5, 6 as root), each link's share of the one before (70%); a frozen link's share (all of it, never less than a plain one's) and its reach (1.5x); the buffer (64K), a chain's write (8K), the rest before it drains (0.5 s), the drain (24K a second) and the share it unblocks at (50%). A one-link chain, root with fewer links, a write bigger than the buffer or a jump past 30 m is refused.
- **DevNullTuning**, `scripts/weapons/dev_null_tuning.gd`, inside `resources/dev_null.tres` (C31). Groups: Throw, Singularity, Pull, Damage. The throw (13 m/s, 3 up, 15 m/s2, a 1.6 s fuse), one hole open at a time and a charge back every 16 s; the hole's times (0.4 s opening, 4 s pulling, 0.35 s collapsing) and sizes (a 9 m reach, 1.25 times as root, a 3 m horizon, a 0.8 m core a metre over the floor); the pull (1 to 7.5 m/s by the square of the depth, a 55% swirl, from 35% to full over its first second, a player at most 4.2 m/s, under a run); the damage (8 to 40 a second inside the horizon every 0.25 s, 500 to discard, the implosion 45 to 10 within 5 m). Refused: a horizon at its reach, a core at its horizon, a pull weaker inside than out, a player's pull a run cannot beat, and the rest out of their bounds.
- **SighupTuning**, `scripts/weapons/sighup_tuning.gd`, inside `resources/sighup.tres` (C32). Groups: Throw, Burst, Confusion, Lashes, Others. The throw (14 m/s, 3 up, 15 m/s2, a 1.2 s fuse), two in the air at most and a charge back every 12 s; the burst (a 7 m reach, 1.25 times as root, its wave 14 m/s, its middle 0.5 m over the floor); the confusion (a 1.2 s reload, a 4 s wander at 55% of the daemon's speed in 1.1 s legs and 0.6 s looks sweeping 1.1 rad, stuttering 30% of each beat at 5 Hz, a 6 s guard after); the lashes (within 3.5 m, 75% of the attack's own damage, two a confusion, the first 0.4 s in, 1.4 s apart); the rest (a hole drags the confused 1.3 times as hard, a node reloads 5 s, a player is confused 2.5 s, its crosshair drifting 22 px). Refused: no guard, no wander, a wave too slow, a first lash after the wander, a stutter that never moves, a player's confusion past 6 s, and the rest out of their bounds.
- **GuideTuning**, `scripts/guide_tuning.gd` with `resources/guide.tres`. Groups: Switch, Pacing, Limits, Model loading. The AI on/off switch (shipped off), the shortest time between two requests, the agent and local server timeouts, the typed text, answer, agent output and local response caps, the most tokens asked of a local model per answer, and the model-load limits: the largest model offered (8 GiB), the VRAM margin (1024 MiB), the load timeout (120 s), the time allowed to unload at exit and how often a stopped load is checked.
- **BootTuning**, `scripts/boot/boot_tuning.gd` with `resources/boot.tres`. Groups: Typing, Handshake, Readout, Handoff, Text, Colours. Typing speed and the pause between lines, the spinner's pace, the demo handshake's wait and latency, the GPU interval (never under 1 second), the wait before the arena, the title, line and hint sizes, the hint's opacity, and the title, text, prompt and warning colours.
- **OpenerTuning**, `scripts/opener/opener_tuning.gd` with `resources/opener.tres` (C38, C40, C41). Groups: Crash, Terminal, Lines, Shrink-away, Fall, Link, Copy, Sound, Screen. C41: the call at 50 s; "Linking your agent..." at 70.2 s; the signal at 70.6; the answer shown no sooner than 73.6 s and the scripted line at 77 s at the latest (a timeline that waits more than 8 s on the AI is refused); the guide's line from 81.4 s; the copy from 82.6 s to 93.6 s; the hand-off to C42 at 94.4 s and the end at 95 s. When the game freezes (0.4 s), comes apart (1.1 to 2.9 s, its pattern changing 10 times a second), drops to black (1.6 and 2.3 s, 0.05 s each) and cuts (3.1 s); the hum (5.6 s) and the terminal's pop-in (6.6 s, 0.18 s); each line's start and the latest it may end (the prompt 8.6 to 13.4 s, then 15.2 to 34.6 s for the rest), the typing paces (0.15 s a key for the prompt, 0.074 s after) and the beats before the punchlines; the folder scroll; the hold until 36 s; the 3 s the terminal ignores typing, "you're in now." (39 to 40.2 s), the shrink-away (40.8 s), the fall (50 s), the landing (68.4 s), the hand-off (69.6 s) and, until C41, the end (70.2 s); the latest moment its data is taken (3.1 s, C39); the sounds' volumes; the terminal's glow, scanlines, vignette and tear. Its `problems()` also refuses a timeline that breaks the PRD's windows (0:35 to 0:50 for the shrink-away, 0:50 to 1:10 for the fall included), ignores typing for anything but 3 seconds, steps the glitch more than 12 times a second, or takes its data after the terminal shows.
- **HudTuning**, `scripts/hud/hud_tuning.gd` with `resources/hud.tres`. Groups: Layout, Ask, Pacing, Demo, Colours. The margin, the panel's width and the gap under it, the badge, line and answer sizes, the panel's opacity, the ask box and answer caps (160 characters; 420 characters and 6 lines), how long answers and notices stay up, the cap of 40 AI calls per session, the spinner and GPU pace (never under 1 second), the demo answer's wait and latency, the demo model load's wait, and the badge, text, off and warning colours.
- **AnnouncerTuning**, `scripts/round/announcer_tuning.gd` with `resources/announcer.tres`. Groups: Round, Callouts, Announcer, Layout. The round length (90 s) and the break (12 s), the shortest gap between callouts (4 s) and how long one shows, the hits-in-a-row and misses-in-a-row thresholds, the cap on the end-of-round line (240 characters, never more), and the round line, callout and summary panel sizes and placement.
- **NetTuning**, `scripts/net/net_tuning.gd` with `resources/net.tres`. Groups: Host, Player, Timing. The UDP port (9009) and the bind address (every interface), the player cap (2), the shown name ("player"), the connect timeout (5 s) and the peer timeout (8 s), the send rate (20 a second), the interpolation delay (100 ms) and the extrapolation cap (200 ms).
- **CombatTuning**, `scripts/net/combat_tuning.gd` with `resources/combat.tres`. Groups: Health, Respawn, Validation, Feedback. Health (100), the respawn delay (3 s) and spawn protection (2 s), the timing tolerance (25% of a weapon's interval, the swap time and a reload's rest) and the origin tolerance (1.5 m), the kill feed's length (4) and fade (6 s), the damage flash (0.25 s).
- **RoomTuning**, `scripts/net/room_tuning.gd` with `resources/room.tres`. Groups: Rendezvous, Codes. The relay URL (empty: no online rooms, no network call; `udp://host[:port]` names a relay, `ws://` or `wss://` its WebSocket mode, and the player's own in Settings comes first), how long a room code lives (600 s), how long a rendezvous request may take (4 s) and how many codes a host draws when they are taken (5).

Every one of these resources validates itself on load with `problems()`. If a value would break the game, for example a negative easing rate, a voxel cap of zero, a fade rate of zero, a guide timeout of zero, a typing speed of zero or a session cap of zero, the player, the dummy, the rain driver, the guide adapter, the boot screen, the guide HUD, the round HUD or the net session prints a warning and falls back to the built-in defaults instead of misbehaving. A weapon that fails its checks is refused and left out of the loadout. `scripts/player.gd` itself holds no movement or weapon numbers at all, and every material colour comes from `scripts/palette.gd`.

### How the checks work

`scripts/check.sh` is the gate every chunk has to pass. It never opens a window: every Godot call is `--headless`.

1. **Parse** every `.gd` file with the GDScript parser.
2. **Import** the project headless.
3. **Run** the main scene for 300 frames headless: the boot screen, which a headless run sends straight to the arena.
4. **Movement test**, `tests/movement_test.gd`.
5. **Cannon test**, `tests/cannon_test.gd`.
6. **Derezz test**, `tests/derezz_test.gd`.
7. **Code rain test**, `tests/code_rain_test.gd`.
8. **AI detector test**, `tests/ai_detector_test.gd`.
9. **Guide adapter test**, `tests/guide_adapter_test.gd`.
10. **Boot sequence test**, `tests/boot_sequence_test.gd`.
11. **Guide HUD test**, `tests/guide_hud_test.gd`.
12. **Model load test**, `tests/model_load_test.gd`.
13. **Round test**, `tests/round_test.gd`.
14. **Net test**, `tests/net_test.gd`.
15. **Combat test**, `tests/combat_test.gd`.
16. **Room test**, `tests/room_test.gd`.
17. **Weapon test**, `tests/weapon_test.gd`.
18. **Settings test**, `tests/settings_test.gd`.
19. **Relay test**, `tests/relay_test.gd`.
20. **Rail test**, `tests/rail_test.gd`.
21. **Bullet time test**, `tests/bullet_time_test.gd`.
22. **WebSocket relay test**, `tests/relay_ws_test.gd`.
23. **Fork bomb test**, `tests/fork_bomb_test.gd`.
24. **Light trail test**, `tests/light_trail_test.gd`.
25. **Code-rain vision test**, `tests/code_rain_vision_test.gd`.
26. **Root and sudo test**, `tests/root_sudo_test.gd`.
27. **Spectate top test**, `tests/spectate_top_test.gd`.
28. **fork() shotgun test**, `tests/fork_shotgun_test.gd`.
29. **grep seeker test**, `tests/grep_seeker_test.gd`.
30. **rm -rf cannon test**, `tests/rm_rf_cannon_test.gd`.
31. **cron mines test**, `tests/cron_mines_test.gd`.
32. **Viewmodel test**, `tests/viewmodel_test.gd`.
33. **Enemy art test**, `tests/enemy_art_test.gd`.
34. **Arena art test**, `tests/arena_art_test.gd`.
35. **Enemy motion test**, `tests/enemy_motion_test.gd`.
36. **Graphics test**, `tests/graphics_test.gd`.
37. **Daemon AI test**, `tests/daemon_ai_test.gd`.
38. **Ping test**, `tests/ping_test.gd`.
39. **Daemon variety test**, `tests/daemon_variety_test.gd`.
40. **ICE test**, `tests/ice_test.gd`.
41. **ICEbreaker test**, `tests/breaker_test.gd`.
42. **Black ICE test**, `tests/black_ice_test.gd`.
43. **Freeze ray test**, `tests/freeze_ray_test.gd`.
44. **Pipe chain test**, `tests/pipe_chain_test.gd`.
45. **/dev/null test**, `tests/dev_null_test.gd`.
46. **SIGHUP test**, `tests/sighup_test.gd`.
47. **Unlocks test**, `tests/unlocks_test.gd`.
48. **Opener test**, `tests/opener_test.gd`.
49. **Opener real-data test**, `tests/opener_real_test.gd`.
50. **Opener fall test**, `tests/opener_fall_test.gd`.
51. **Trailer test**, `tests/trailer_test.gd`.
52. **Opener link test**, `tests/opener_link_test.gd`.
53. **Opener end test**, `tests/opener_end_test.gd`.

It fails on any parse error, any `ERROR` or `SCRIPT ERROR` line in Godot's output, or a nonzero Godot exit. Exit 0 means clean, 1 means a problem was found, 2 means the gate itself could not run. It also takes a project directory, which is how deliberately broken copies are checked.

The tests are SceneTree scripts that drive the real scenes through a one-frame input hook on the player, `drive_input()`, with `--fixed-fps 60` so every run is deterministic and faster than real time:

- **Movement test.** A flat floor and the real player scene. Measures the start and the stop in frames, repeats them at 60 Hz and 120 Hz to prove nothing depends on the frame rate, and covers the slide (threshold, burst, timer, cooldown boundary, same-frame jump), slide-jump momentum, air control, head bob scaling and its toggle, the FOV kick, and the tuning fallback.
- **Cannon test.** The real main scene. Fires at the real dummy, then the wall behind it, then the open sky, and checks the hit, the hit marker, recoil and its recovery at 60 Hz and 120 Hz, each effect's own lifetime, misses without a marker, the cooldown boundary, the pitch clamp including mouse look, the synthesised sounds, the tuning fallback, and that no orphan nodes are left behind.
- **Derezz test.** The real main scene. Kills a real dummy with the real cannon and checks the state machine, collision, the voxel cap, the burst and the fade, the effect freeing itself on time, hits ignored while derezzing and while respawning, and the respawn at full health in the same spot. It also runs one seeded derezz at 30 and at 144 frames per second and requires identical voxels. It checks that the voxels follow the shot's own direction, both from a real cannon shot grazing a dummy's side and from a direct hit, and that voxels knocked off the raised platform settle on the floor below and never in mid-air. Finally it runs 20 rapid kill cycles with no leaked or orphaned nodes, and confirms every tuning resource file lists every tunable of its script.
- **Code rain test.** The shader and tuning load and validate, then the real main scene: every block but the floor carries the rain shader and receives the tuning and the enemy slots; with no enemy the intensity is the minimum, at an enemy the maximum, at the radius nothing, and it never rises with distance; the rain fades in and out at the tuned rates, converges exactly and never overshoots; a derezzed dummy stops counting and a respawned one counts again; more enemies than the cap stay bounded, nearest to the player first; a settled arena uploads nothing. Headless Godot cannot read a shader's pixels, so the test checks GDScript mirrors of the falloff maths and the glyph hash instead; the shader itself is only known to compile.
- **AI detector test.** Fakes only. A scan of the detector's source proves its one program start is the nvidia-smi query and its one connection goes to 127.0.0.1, and that outside scripts/ai only the boot screen, the guide link, the model loader, the guide HUD, the round announcer and the opener's link (C41, the request builder only) touch it; the guide adapter test holds the same list. Then every agent-setting case, the command check against a fake PATH (with a stub agent that fails the test if it is ever run), a fake model server that answers, lists nothing or hangs, a closed port, a fake /sys and a stub nvidia-smi whose recorded arguments must be exactly the query, the once-a-second limit, the fallback order across combinations, the worker thread, and that no result ever holds a path, a user or host name, or a model name.
- **Guide adapter test.** Fakes only. Stub `claude` and `codex` scripts record their arguments, PID, working folder and stdin, and a fake model server on a random local port records every request. A scan of the guide's source, comments left out, proves there is no shell, no `omarchy-agent`, one program start, only guarded stops of the game's own child, and no pull, delete, `num_ctx`, `options` or `keep_alive`. Then: the request whitelist drops a seeded fake path, host name, process name and user; each agent's arguments are exactly the documented flags, with every forbidden flag absent; Codex gets the empty scratch folder and a closed stdin; ANSI escapes, control bytes and floods are cut down, and 64 KiB of padding followed by a sentinel proves nothing past the cap is ever read; a hung stub is stopped at the timeout by its own PID while a bystander stub keeps running; cancel and a guide freed mid-request stop their child; the rate limit (with a fake clock), one request in flight and AI off; the local adapter's loopback refusal, loaded model, LM Studio's loaded and unloaded models under just-in-time loading, `needs_consent` with no chat request and `/v1/models` never asked, exact request body, tokens per second, hostile, truncated and broken answers, and a server that never answers; the registry's fallback order; and that no result holds a path, a user or host name, the server address or a model name.
- **Guide HUD test.** Fakes only. The badge for each kind of AI, latency and when tok/s shows, the GPU line and its pace, the ask box (whitelisted stats, BBCode shown as typed, escapes and control bytes stripped, the caps), fixed lines for every failure, the cooldown and the session cap on screen, the toggle and its question, the headless guard and demo mode, seeded private strings kept off every label, the layout at 1280x720 and 960x540, and in the real arena: with the box open, held keys, typed letters and a click move, jump and fire nothing, and R reloads nothing.
- **Model load test.** A stateful fake Ollama server with fake model names, logging every request. The candidate rules (embedding models, the cap, free VRAM minus the margin, smallest first); N and Esc send nothing; Y sends one load whose body is exactly the model; one unload with keep_alive 0 at the end of the session, on O, and after a stopped load turns up; a load that never finishes times out to the scripted guide; a model loaded by now skips the question; a model loaded before the Y is never loaded or unloaded by the game; other servers never get a load call; the headless guard sends nothing even with Y pressed; demo mode stays off the network; the boot screen's hints.
- **Round test.** Fakes only: the stub adapter with a fake clock, settings in a temporary folder. A scripted round in the real arena with the real cannon (2 shots, 1 hit, 50%, 1 process down, the first down on the round clock, a jump, a slide and the distance run) and one through the collector alone (streaks, misses, the first down); the request carries exactly the 11 round keys as numbers, with seeded names, paths and process lists dropped, and the coach or roast instruction reaches all three adapters; exactly one call per round end, none for the same round twice; no call with the AI off, a call in flight, in the cooldown, at the session cap or under the headless guard, each with SIGKILL's labelled line; a timeout and an empty answer get SIGKILL's line; a hostile answer shows as plain text under 240 characters; a late answer is stopped and dropped and the next round starts on time; a T call started after the round's call was stopped is never polled or stopped by the round; a six-line answer to T waits out the break, and the longest notice, the AI question and the ask box fit under the summary; the roast switch is off by default, saved next to the opt-in, kept by it and read back; callouts fire from game events at most once per 4 s and never call the AI; the demo panel; the layout at both sizes.
- **Net test.** A host and joiners in this one process, each in its own branch of the tree with its own multiplayer instance and real arena (the joiner's arena 1000 m away, so the two physics worlds never touch), over ENet on 127.0.0.1 on ports the system hands out. A scan of the net module proves it starts no program, reads no file, asks the system nothing, opens no other kind of socket and decodes no objects, with Godot's relay off and exactly three RPCs; addresses parse and bad ones are refused; the hello and reply round-trip and junk parses to nothing; impossible state packets are refused. Then solo play (an off session on the offline peer, nothing sent, the player moves as before); host and join with the roster and the avatars; the host's scripted run seen by the joiner 100 ms behind, within a send interval, with no jumps, settling on the host's spot, yaw and pitch too; 20 sends a second; the joiner's run seen by the host; the joiner leaving seen by the host; a second join; the arena replaced under a live session; the host leaving seen by the joiner; a version mismatch and a full host refused with their reasons; a closed port given up on the connect timeout while the game runs on; a bad address, a cancelled connect and a busy port; a host name looked up and joined; hostile packets over the wire (a yaw of 1e300, a NaN position, an impossible speed, a far-ahead sequence number, the largest integer, zero) refused with the avatar watched every frame and the real stream still flowing; a rejoin and an arena reload with the sender's counter long past the jump bound; a 1000 ms delay still glides with the samples it needs; the joiner's socket bound to 127.0.0.1; the host's own notice of a refused join; the panel's keys in the real HUD; the layout at both sizes. Since C31 it also pins that a link to this same machine never throttles: ENet's back-off had been dropping position and meter words on a busy machine (the old delay-buffer and freeze-ray flakes), so loopback links run with none, every other link keeps it.
- **Room test.** The net test's harness, plus a test-only rendezvous server and clients in the same process on 127.0.0.1. A scan proves the room code module, the interface, `NullRendezvous` and the tuning open no socket, read no clock or file and use no ordinary random numbers, that codes come from the engine's cryptographic bytes, that the game's only rendezvous is `NullRendezvous`, that no link handler or `.desktop` entry exists, and that the session's sockets are still exactly C13's. Then: 2000 drawn codes all valid and nearly all different, every symbol used; the checksum catching all 11086 single typos and neighbour swaps tried; forgiven spaces, dashes and case; strict links and `--join` arguments; `NullRendezvous` refusing with the not-live line and sending nothing, with a URL in the tuning too; with the fake, the host's registration (code, protocol, port, seen from 127.0.0.1) and a joiner resolving the code and joining by the C13 path; every request exactly 14 bytes with no name, address or AI word in any of them; a code released when the host leaves; a typo never sent; unknown, expired, other-version, busy and silent rendezvous lines; taken codes redrawn and given up after five; a fresh code after the old one's time, the old one released; a registration left unanswered (leaving early, a lost reply) or given no time released too, and the panel saying a code is coming only while one is; a room placed outside the LAN refused before any connection; `--join` once per run, and kept when it arrives before the session is ready; K in the real panel; solo and address join unchanged; the layout at both sizes.
- **Combat test.** The net test's harness. A scan proves damage is applied only by the host: in `_handle_fire` after validation and the host's own ray, in the fork bomb's `_judge_blast` (C19) and in the light-trail touch in `_tick_trails` after its hosting check (C20), that the host's shot and a joiner's intent reach it the same way, that results leave only as authority RPCs and that the HUD shows only confirmed results; the rules alone (every drop reason, the damage ladder 100, 75, 50, 25, 0, a dead player taking none, the respawn coming due, protection blocking and expiring, the farthest spawn); solo play untouched. Then the match: a joiner's real shot takes 25 off the host on both sides with the joiner's hit marker and the host's flash; four hits derezz the host (dead on both sides, its cannon dark, its avatar hidden with the derezz playing); the feed on both sides; the dead host cannot fire; the respawn after the delay at a far spawn, protected, with the protection blocking a shot and then expiring; the host's own shot through the same path. Forged intents (an origin 3 m off, a NaN or 50-long direction, an infinite origin, numbers far ahead or already believed, one from no player, two inside the cooldown, one from a dead player) are each dropped and counted with nothing applied; a joiner leaving while dead is forgotten cleanly and comes back alive; a host leaving while the joiner is dead; the feed fades; a derezzed body stops and ignores input; a ray through the dead host's corpse goes on; the derezz plays on the host for a killed joiner; wrong-typed packets dropped and counted; a position from the past life ignored after a respawn; a mid-match joiner sees the protection and the life number; a joiner asking to be Daemon-1 is named by its slot; a newcomer with no position cannot be shot at the origin; an origin claimed behind the wall the joiner stands against is refused while an honest shot from there stops at the wall; a shot from inside an opponent's body hits; a just-revived opponent counts for the next spawn choice; the probe sees no cover in the dead host's body; a respawn received with no arena is applied by the next arena at the host's spawn, and a host with its arena away holds the respawn and then picks a real spawn; no result comes back for a rejected intent; a shot through a corpse whose volume is still on passes it; the feed still names a departed player; an intent from the shooter's past life is refused; the feed is gone once the joiner leaves and empty in the next match; a dummy hit in a match shows no hit marker while solo it does; the layout at both sizes with four kills, the net panel and a long guide notice.
- **Weapon test.** Both shipped weapons and the loadout valid with their numbers, the cannon as it was; 23 bad values each refused with the reason (22 before C30 built the beam mode and added a mode outside the list); a loadout's broken, foreign and repeated weapons refused and named, nothing usable leaving the built-in cannon, at most nine slots. The inventory alone: the swap time, the pump, six shots to empty, fire on empty starting the 2.2 s reload, partial reloads, a swap stopping a reload, Q and the wheel, each interval running on while another weapon is drawn, dry with no reserve, a refill, 500 cannon shots with no reload. The host's rules alone: a weapon never drawn or unknown, a draw not yet done, the pump, reloads refused where the game refuses them, a shot mid-reload, a reload stopped by a draw while one whose time was up keeps its rounds, no reload behind the host's back, an idle draw still waiting, damage by amount, a respawn's refill. Pellets: nine, the first on the aim, the rest inside the cone and spread evenly over it in 2000 shots, a slightly long aim narrowing nothing; the falloff exact; the bounds at 1.5, 12 and 30 m. A scan proves the intent carries only the aim, the host alone draws pellets, the weapon scripts open, read and run nothing, and the controls (E reload, R reset, Q, 1 to 9, the wheel) need no Ctrl, Alt or Super. The real arena with real key and wheel input: slots, Q, the wheel, a missing slot; the swap timed to the frame with fire held; a point-blank kill of a dummy given 100 health (eight pellets or more must land) with nine tracers, and that dummy's damage at 12 and 30 m; the magazine spent and E's reload timed with no shot during it; the cannon's 30 shots as before; a death's refill; a broken SIGTERM refused from a player's loadout; a fresh solo arena. A match over 127.0.0.1: an unknown, a never-drawn and a non-text weapon dropped, and fire straight after a draw; SIGTERM point blank derezzes the host with the host's own pellets and the feed says "SIGTERM sent by Daemon-2 to Daemon-1" on both sides; mid range takes several shots, long range is weak; too fast and an empty magazine dropped; a shot mid-reload dropped and believed once the reload is done; no reload behind the host's back; a draw and a reload arriving together still reloading; a reload arriving with the draw after it, and a refused one, answered with the host's count, which the joiner takes; the joiner's own draw, reload and shot then counted the same on both sides; a stale count not taken; a count that comes during an R reload taken by the next arena; a reload message 0.8 s late with the joiner's reload stretched to the host's and its first shot believed; a late count after the joiner's own reload taken as that reload leaves it; a draw still running on the host after the joiner's has ended costing one cannon shot and no more; a reply about a longer host reload holding the joiner's next shot that long; the host's own SIGTERM drawn pellet by pellet on the joiner. A fresh match with real players: practice ammo not carried in, a draw from before the first roster undone with both sides waiting the same draw, a first roster during an R reload waiting for the next arena, nothing sent before the fresh start, real shots counted the same on both sides, an R reload mid-match keeping the ammo, a respawn while the arena is away refilling, and a draw that crossed a death reconciled at the respawn. The layout at both sizes with the strip reloading, four kills, the net panel and a long guide notice.
- **Settings test.** Settings files in a temporary folder only; a headless run has no settings path, so the player's own file is never read or written. The model: the shipped defaults, values of the wrong type, out of range or not a choice refused, floats clamped and snapped, the display name cleaned, the change signal. Binds: Ctrl+Alt refused by name (a key and a mouse button), every other Ctrl, Alt or Super chord and the bare modifier keys refused, Esc and a pad button refused, the default clearing a bind; conflicts between actions (two and three on one key) and with an arrow, a weapon slot key and the wheel; binds reaching the input map, broken ones falling back, the arrows kept, no chord on any game action. The file: every setting and two binds saved and read back with their types; privacy answers and settings each surviving the other's save; one versioned ConfigFile with plain values only; nothing written into the project or with a quote, a backslash or an object; no file and 19 kinds of damaged file (binary, `Color()`, `Object()`, `Resource()`, a dictionary, a list, a bare word, an escaped quote, a key or a section twice, half a section name, no, a newer or a text version, oversized, a key before any section, a line with no `=`, a capital key, a control byte) all giving every default and never counting as a yes; one bad value in a good file defaulting alone; the old file's answers carried over and rewritten as version 1; an old file's unreadable value dropped on the next save. A scan proves the settings code runs nothing, opens no socket and loads nothing from data, the file is scanned before ConfigFile sees it, the menu keeps no privacy state and nothing pauses the tree. The real arena on a damaged file; invert Y flipping the pitch for real mouse motion and real right-stick events, the stick's yaw untouched and its rate; sensitivity, aim (held and toggled, the narrower view and its own sensitivity), crouch (held and toggled, the height and the 3.5 m/s pace, none while input is stopped), the field of view, the shot jolt and the head bob, the speed stretch, the weapons on the Effects bus. The menu: Esc opens it with nothing paused, M, T, 2 and B do nothing behind it, Esc closes it, the multiplayer panel's Esc keeps it shut; its own widgets set the settings and leaving the screen saves them; Ctrl+Alt+J and a bare Alt pressed for a bind refused on screen, Esc cancelling, W shown as a conflict on both rows, a middle click as a bind, reset keys; the AI, roast and real-data rows driving their owners, real data off making the next link demo data and on again real; Defaults leaving the privacy answers alone. The crosshair, the colour filter, subtitles off still ringing the chime, the buses made under Master and the volumes reaching them, the quality presets reaching the arena, the render scale, no window touched. The layout at 1280x720, 1920x1080 and 960x540: every setting on screen, the key list the only scroller, the screen shrunk whole at the small size. Esc still skipping the boot screen. A host and a joiner over 127.0.0.1: the display name a label on the joiner's own screen while the hello still carries the placeholder and the host names it Daemon-2; with the host's menu open its player takes no input and nothing is paused while its clock and its sends run on, the joiner sees it move and can still hit it; the joiner's menu stops nothing either; the net stats line on both sides; the default port.
- **Relay test.** The relay runs as its own process, bound to 127.0.0.1 only, on ports the test hands it, and is stopped with its stop file. The wire format (64-byte requests, replies of 27 to 57 bytes with no address in them, 12-byte probes, malformed ones read as nothing), relay URLs, and the relay's settings (defaults, environment and flags, ten bad ones refused). A scan proves the relay starts no program, opens no other kind of socket, writes no file and prints no address, code or token, that the game's relay client has one socket to the relay only, and that the session sends its probes on its own ENet socket and opens none. With no relay URL (the shipped default) hosting draws no code, a code or link gets the not-live line, nothing is counted and nothing reaches a sniffer on the default relay port or another one; set on the real settings screen to that sniffer (a bad URL refused, a typed one saved), the resolve arrives at once, and cleared, nothing again. Relay A, started through `relay/run_relay.sh`: a real host registers and gets a code and three slot ports, a real joiner resolves the invite link and joins through the relay (the joiner talks to the join port, the host sees it as a slot port), positions cross both ways, a shot lands on both sides, the typed code brings the joiner back on the next slot, and the host leaving releases the code. Relay B, with tight limits: bad packets unanswered (short, oversize, bad magic, a bad checksum), a wrong cookie answered only with a cookie, the room cap (two rooms, the third busy), a code taken, forwarding both ways only after each side probes, a 301-byte payload past a 300-byte cap dropped, a source that never probed, a joiner past a full room and a probe of the wrong kind dropped, a code expiring after 2 s, its idle room giving its ports back, the code forgotten after its expired time, the 7th resolution in a minute answered busy, and every one of those in the relay's own counters. Both relays stop with exit 0 and an output holding no address; a bad setting stops one at once with exit 2.
- **WebSocket relay test.** The relay's WebSocket mode runs as its own process, bound to 127.0.0.1 only, on one TCP port. The scheme picks the transport (`udp://`, `ws://`, `wss://`; `http`, `https`, `tcp`, `ftp`, a capital `WS`, a path or a bad port is no relay), the WebSocket URLs' default ports, the data message, `--ws-port`. A scan proves the WebSocket relay runs nothing, touches no file and prints nothing, keeping the UDP relay's control path, and that the game's client has one link to the URL the player set and loopback sockets on 127.0.0.1 only. `ws://` and `wss://` give the WebSocket client (`wss://` with TLS, to 443), an unknown scheme no relay at all, refused on the real settings screen with the three that work named; a `wss://` relay is reached over TCP; with no URL nothing connects anywhere, and a `ws://` relay that is not running fails cleanly. Relay A: a host and a joiner play a match through it by room code and by link, the joiner's ENet on its loopback mouth and the host seeing the joiner as one of its loopback slots, both moving, a shot judged by the host landing; leaving lets the other side know in milliseconds, the typed code rejoins, the host's close reaches the relay. Relay B, tight limits: bad messages, the cookie, the room count, forwarding by token, the payload cap, a full room and strays, idle expiry, the code's life, a forgotten code, the rate, the connection cap and the handshake time, each in the counters; neither relay prints an address; a bad `--ws-port` exits 2.
- **Fork bomb test.** The chain's resource and the weapon's, their numbers, bad values refused, the damage curve, the scatter from a seed; a scan that nothing real runs, that fifteen blasts is the cap, that the throw is its own request and only the host judges a blast; G moved to H, saved and loaded, Ctrl+Alt+G refused. In the real arena: two bombs, fire and G each throwing one, none thrown with none left, both back at a round's start and a new life; one throw making exactly 1, 2, 4 and 8 blasts, the callout, every node freed; one blast leaving a 100-health daemon at 84.7 and the full chain killing it; a wall stopping a whole chain; a throw against a wall staying on this side; the live cap holding at 16 under spam. Over 127.0.0.1: the joiner's throw checked and run by the host, the joiner's screen drawing the same 15 blasts at the host's places and all 7 forks scattered as the host's, the host killed and the feed naming the fork bomb on both sides, the bombs back after a death, no self-damage, forged throws (a far origin, the wrong aim, the wrong types, a weapon not thrown, none left) dropped and counted, the host's live cap, nothing left behind. Each case pins its scatter seed, so every run throws the same chains, and no outcome checked hangs on the seed.
- **Light trail test.** The resource and its numbers, 12 bad values refused, a session given bad numbers playing by the shipped ones; the setting off by default, its Esc menu row, `--light-trails` and no trails solo; a scan that the wall code runs nothing real and that only the host lays and judges walls, protocol 6. One LightTrails node: 11 segments for 6.9 m at a walking frame of 0.117 m, end to end; nothing in the air and nothing across a jump; a fresh wall past a 2.5 m gap; the cap per player (100 leave the newest 64); grace (your fresh wall spares you and kills anyone else, past 0.4 s your own touches you but never your newest); a wall's height and its 0.44 m reach to a centimetre; the 6 s lifetime. Then a host and a joiner over 127.0.0.1: off by default nothing is laid; the host's setting reaches the joiner; the host's walk and the joiner's copy agree segment for segment; the host lives standing on its newest wall; the joiner walking into the host's wall dies, the kill the host's on both feeds, its own walls gone; the host dies walking back into its own older wall, no kill counted; respawns start bare; a running jump of 5 m lays nothing in the air; each segment expires 6 s after it was laid, to the frame, on both screens; a joiner arriving while walls stand gets them all with their ages; turning the rule off and leaving take every wall away; no orphan nodes. Ten runs in a row print the same output.
- **Code-rain vision test.** The resource and its numbers, 12 bad values refused; the meter alone (drain, its own end, 1 s of rest, a quarter of a second back each second, the 25% start, nothing changed by turning off or by a death); V rebindable, moved to Z and back, Ctrl+Alt+V refused; scans that the vision code sends and opens nothing, that the session's 17 RPCs, 19 sends and protocol 6 are as C20 left them, and that the silhouettes have no depth test and the walls' own hash. In the real arena: the meter to the frame (60 held frames take 1 s; 60 frames of rest, 240 to full; off at frame 180 held through empty, never restarted), the minimum, a death, a respawn and the menu turning it off with the meter kept; a dummy behind a real wall marked only while on, one at 38.7 m yes, 45 m no, a derezzed one no; the look's ease and the comfort settings; the cannon firing with it on. Over 127.0.0.1: the joiner sees the host's avatar and no dummy, the host hears nothing new, leaving turns it off. Ten runs in a row print the same output.
- **Root and sudo test.** The resource and its numbers, 8 bad values refused; the rules alone (the 3rd kill in a life earns exactly one charge, more stack nothing, a death drops it and the streak, 8 s of root at 1.5 times, kills in root count toward the next, a respawn ends root); Z rebindable, moved to U and back, Ctrl+Alt+Z refused; scans that nothing real is run or read, that protocol 7 carries the ask and the host's word, that only the host applies the scale, and that no other ability's or weapon's numbers moved. In the real arena: `user$`; Z with no charge nothing; three dummies down earn one charge, a fourth no second; the password line then `root#`; 37.5 off a dummy where the cannon's hit is 25; SIGTERM and the fork bomb spend nothing; root ends on the frame due; then 25 and a shell spent again; the meter's share equal at both strengths; a death and a respawn end it. Over 127.0.0.1: a protocol 6 joiner refused; a forged ask with no charge refused and counted; three real kills of the host credit the joiner a charge; its root on both screens; its shot 37.5 off the host by the host's judging, its own game's scale still 1; a death and leaving end it. Ten runs in a row print the same output.
- **Spectate top test.** The resource and its numbers, 9 bad values refused; the record alone (join order, damage dealt only off someone else, a kill and a self-kill, time alive stopping at a death and restarting at a respawn, the three load windows, a leaver gone); TIME+ and uptime as top prints them, the columns lined up, "-" for anything not known, top's order (kills, then %CPU, then PID; never by name), the viewer's own row always shown; Tab rebindable, moved to K and back, Ctrl+Alt+Tab refused; scans that the new code calls no process or OS execution API at all, that the table message is the host's, sent only while hosting, and protocol 8. In the real arena: hidden until Tab is held, then the player as PID 100 in reverse video and the four dummies as daemons 101 to 104; a dummy derezzing is Z with D 1, the player's kill puts it first with 100.0 %CPU and a load of 1.00; exactly 3 refreshes in 3 s; a daemon back is R with its TIME+ from 0; T under SIGSTOP; root after a sudo; gone when Tab is let go; hidden on every frame of the round's break summary. Over 127.0.0.1: a protocol 7 joiner refused; a joiner the host has sent nothing shows "-" for every PID, %CPU, TIME+, K and D and its synced health; the host's message exactly once a second; derezzed, the table is up at once on the host's screen and the joiner's, the banner below it, and gone on the first frame alive; on the joiner every number is the host's (PIDs 100 and 101, kills, deaths, health 75, %CPU 49.0 and 51.0 from 25 and 26 damage dealt); root on both screens; T on the host's for both and on the joiner's for itself only; the order flipping when the host's kills pass the joiner's. At 1280x720 and 960x540 the table sits inside the screen under the top lines with nothing under it and the banner below, and is never up on a frame with the round summary.
- **fork() shotgun test.** The resource and its numbers, 17 bad values refused (and the fork group on any other weapon); the fan alone (6 directions in one plane, within the spread, one in each slice, from the aim and the seed alone) and a fork alone (two children 10 degrees apart in that plane); the damage per generation (12, 7.2, 4.32); scans that the new code calls no fork() and no OS call at all and that the shot needs no new message (protocol 8), the host drawing the seed and judging. Volleys in an empty test world, frame by frame: 6 pellets, then 12 at exactly 4 m, gone at exactly 30 m; with root's second fork 6, 12, 24; every live pellet a head and a trail and each fork a flash; the same seed the same pellets on every frame, another seed others; a wall 6 m out stopping all 12 children on its face. In the real arena with the real player: slot 5 on key 5, the wheel and Q; point-blank all 6 parents landing at 12 each and never forking; children landing at 7.2 past the fork; the point-blank total above the long-range one on the same dummy; root forking a real shot twice with no shell spent; the "fork()" callout. Over 127.0.0.1: the host's volley judging and the joiner's drawing the same pellets from the host's seed, the host's health agreed on both screens, a kill named "fork() sent by Daemon-2 to Daemon-1", root's 24 on both screens, the host's own shot the same path.
- **grep seeker test.** The resource and its numbers, 21 bad values refused (and the seek group on any other weapon), its colour unlike every other weapon's; the darts' first directions alone (one straight along the aim, three fanned in the aim's plane from the seed alone); scans that the new code runs no grep and no OS call at all and the wire (protocol 9: no new message, the intent carrying the claims and the seed message the believed marks, the host re-checking every claim, only the host's volley judging). Darts in an empty test world, frame by frame: one with no mark on the aim's line every frame and gone at exactly 45 m; one turning toward a mark 29 degrees off at exactly its limit, 3.667 degrees a frame, never more; the same seed and marks the same darts, another seed others; a wall stopping a homing dart on its face. In the real arena with the real player: slot 6 on key 6, the wheel and Q; no lock outside the cone, past the range or behind a wall; a lock built 1/60 s a frame and marked on frame 30; brackets closing from 34 px toward 14 and a "match" tag; three marks and no fourth, five as root locking in 15 frames; marks dropping on a derezz, on a swap, out of sight or range past the 0.75 s grace and past three when root ends; three darts landing 18 each on their own marks, one curving in from 20 degrees off, one missing a dummy that jumps 6 m aside, one stopped by a wall, one straight with no mark, five at 27 as root with no round spent; the "grep" callout at the usual pace. Six slots inside the screen and clear of every panel at 1280x720 and 960x540, "grep -c" included. Over 127.0.0.1: the joiner marking the host and its claim believed, the host's dart judging and the joiner's only drawing, the same darts on both screens; forged claims (behind the shooter, a player who is not there, itself, through a wall, 38 m off, named twice) refused and counted with no homing dart; a kill named "grep sent by Daemon-2 to Daemon-1"; the host's own shot the same path; a protocol 8 joiner refused.
- **rm -rf cannon test.** The resource and its numbers, 21 bad values refused (and the blast group on any other weapon); the slug slower than every other projectile; ember unlike every other weapon's colour; the falloff alone (140, 74, 8, nothing past 6 m; 8 at 9 m as root); the fiction-only hard rule as a scan (no rm, no OS call, no DirAccess or FileAccess, no move_to_trash, no /proc in the weapon's code); the wire (protocol 9, nothing new, only the host's slug judging). Slugs in an empty test world, frame by frame: 0.15 m a frame, off at exactly 45 m with its ring grown to 6 m; off on a wall, on the floor and on a body; a 9 m ring as root; a joiner's slug passing a body, holding at a wall, off only on the host's word, gone after its wait without one. In the real arena with the real player: slot 7 on key 7, the wheel and Q; the shot exactly 36 frames after the press while "rm: remove? [y]" types out; a swap, a death and a respawn cancelling with the round kept; half pace through the wind-up and 0.8 s after, no slide, mid-air the speed easing down rather than cut; daemons taking the falloff for their distance, none past the radius, none behind cover; root's 18-frame wind-up, 1.5 times, 9 m reach and free round. Seven slots inside the screen and clear of the guide panel at 1280x720 and 960x540. Over 127.0.0.1, a host and two joiners: a protocol 8 joiner refused; one blast judged on the host at its centre (derezzed from full), the other joiner and the shooter itself at half, each exactly its falloff; "rm -rf sent by Daemon-2 to Daemon-1"; the joiners' slugs only drawing, off on the word at the host's place; a point-blank self-kill reading "rm -rf: Daemon-2 removed themself" with no kill credited and the others behind cover untouched.
- **cron mines test.** The resource and its numbers, 21 bad values refused (and the mine group on any other weapon); a moderate blast (one run short of a full player, three past it, under rm -rf's); rose unlike every other weapon's colour; the fiction-only hard rule as a scan (no OS call, no DirAccess or FileAccess, no /proc, nothing setting a clock, no crontab, systemctl, cron or at called, the HUD's "crontab" words told apart); the wire (protocol 9, nothing new, only the host's mine scheduling and judging). Mines in an empty test world, frame by frame: runs on exactly frames 60, 180 and 300, gone 36 frames after; "*/2s x3" down to x0; the ring closing and the 18-frame brighten before each run; four runs as root; a joiner's mine running on the word alone, ended by a removal, and waiting a whole interval for a late last word. In the real arena with the real player: slot 8 on key 8, the wheel and Q; mines on the floor, on a wall and at the feet; the crontab's limit and its note; daemons taking each run's falloff, none past 3 m or behind cover; the "cron" callout; root's four runs at 1.5 times with no mine spent; a new round clearing them. Eight slots inside the screen and clear of the guide panel at 1280x720 and 960x540. Over 127.0.0.1, a host and two joiners: a protocol 8 joiner refused; a joiner arriving mid-job sent the running mine; one run on the host (survived) and the other joiner, the owner untouched; the owner's death leaving its mine to finish the host, the kill its own; the owner's copy running on the host's words alone; another player's cannon shot removing a mine with "crontab -r" in every feed; the owner leaving taking its mine off every screen.
- **Viewmodel test.** The resources: every weapon of the arsenal names a model of its own, a script that is not a model refused, none allowed (the placeholder box); the arsenal's motion numbers, 13 bad ones refused. A scan: the models and the capture tool touch nothing outside the game, nothing that runs each frame makes a mesh, a node or a material, and the game never names the tool. Each model alone: its Muzzle at its front, in front of the camera and in view at 80 degrees at 16:9 and 4:3, never within 4 degrees of the crosshair; its trim in its own skin at its own energy; 200 to 3000 triangles; one mesh with a surface per material; eight different shapes; root's red on every part and back; the rail's coils lighting in order, rm -rf's core and vents together. In the real arena: each weapon drawn shows its model alone with the player's muzzle its Muzzle; a cannon shot's beam starting at the muzzle and its flash on it while the shot's origin is still the eyes; the kick back and up and the settle, SIGTERM's light, the rail's and rm -rf's heavy; the raise from below; the lag behind a turn each way and the settle; the stride's sway within its numbers and none standing; the real charge and wind-up lighting and going back; the drum and the clock hand turning; the very same meshes at the end.

- **Enemy art test.** The sources: every target of the arena names its art, a script that is not art gets the plain look; the art code calls nothing outside the game, no wall clock, nothing loaded at run time, and builds nothing per frame; the daemons' shaders run on their shared shader clock, never the wall clock; the hit volume byte for byte as before A2 (the collision shape, its place, layer and mask, the four targets' places) and nothing under the art can collide; the players' derezz is the same effect. Each kind alone (its checks moved onto A2b's creatures): inside its own triangle and draw-call budget, three different shapes, its glowing parts in its own palette colour, one shared obsidian (its split the next pass), core, trail and glyph material, every part a MultiMesh instance moved by its transform with every mesh kept, its clock half as far at half the engine's time, the flash and the glitch reaching the shaders. In the real arena: each target drawn by its art with the hex volume by no camera; a grep mark locking onto the marked daemon alone; a hit that does not kill flashing it; a kill's derezz with the voxel shader and the flash gone on time, the effect freeing itself, the daemon back after the respawn delay, glitching as it grows, whole after the rematerialise time.
- **Enemy motion test** (A2b). The sources: the art code (the creatures, the rig, the shatter) calls nothing outside the game; nothing in a function that runs each frame makes a node, mesh, MultiMesh, material, array, dictionary or string; every daemon shader pins its instance uniforms to the same slots and reads the one shader clock; the gameplay collision byte for byte as at 1afcdb7 (the dummy's and the arena's scenes by sha256, and the only three lines of the dummy's script that touch its collision shape). Each kind alone: MultiMesh parts only, never a static mesh; the rogue daemon's feet planted dead still on the ground, every leg stepping at least twice in 4 s, legs of both tripods never swinging together, the body gliding, a rear on its own; the zombie's bones flickering (many different sets drawn), three ghosts each further back, the pelvis limping and dipping, its head over the hit volume's head zone; 20 to 40 insects moving, orbiting the nest, keeping together and apart, diving; every creature 1.5 to 2.5 times A2's size and inside its budget; seeded per daemon; on the game clock (a zombie slowed to half time and one at full speed reaching the same pose at the same clock); a hit flashing, knocking back, spraying ten shards and bringing the kind's own answer (the rogue rears; the swarm's insects near the shot outrun its top speed); 120 frames making no object or node. In the real arena: the four targets' collision equal to the 1afcdb7 literal before and after their creatures move; one material per look; a hit through the dummy reaching its creature; a kill bursting the creature's own parts under the derezz, flying apart and gone with it.
- **Graphics test** (A4). The sources: the particle and post code calls nothing outside the game and loads nothing at run time; nothing that runs each frame or each shot (the trails following, an impact, a blast, a muzzle burst, the arena's clock, the viewmodels' projection, a projectile drawn from the muzzle) makes a node, mesh or material; the arena's shaders read the arena's shader clock, never TIME; the post shader warps nothing; no gameplay number changed (`resources/`'s files byte for byte as at dee2482 by sha256, with only C27b's `daemon_ai.tres` beside them, and `scripts/net/`'s tunings as they were; the protocol 9 at A4, 10 since C27b's daemons). The settings: high by default with the post effects off; low dropping every costly feature; a preset setting its toggles, a hand-changed toggle reading custom; every graphics setting round-tripping through the settings file, a file from before A4 taking its preset's toggles, a mismatched one reading custom. In the real arena: AgX, the glow's threshold and levels, the grade's cool shadows and warm highlights, the gloss floor; the warm signs and their lamps, the two red danger lights in the lair pulsing, the magenta glitch split; each preset reaching the glow, the sun's shadows, the rain, SSAO, SSR, the skyline and the particles; the post effects drawn only when on, under the HUD; the pools' sizes, one process material and mesh per kind, a muzzle burst on all eight models; 40 impacts and 40 blasts in one frame reusing the pool and making no object; trails capped at the pool and 120 frames of them making no object or node; a beam drawn alone (a remote player's shot) sparking where it ends, never twice for this player's own, never into the open; low with every emitter and muzzle burst a quarter the size and the flying trail stopped, high putting them back; through a shot's jolt the shrunk model moving on screen as a full-sized one and the muzzle point on its marker; the drawn model covering the same rectangle of the screen at 60, 80 and 120 degrees, every model within 0.35 m of the eye; a slug handed to the player's take_volley (alone or in a match) drawn from the muzzle and joining its true path, that path the same as an undrawn one's; the real SIGSTOP slowing the arena's clock to the engine's pace.
- **Daemon AI test** (C27b). In the real arena, each check's daemons put where it needs them (the others parked under the floor) and the real player standing still: each type damages an idle player in range; a tell before every attack, in every daemon's events and on the rogue's rig (it rears at least 0.9 of the way), and the code's one way into a strike, from a tell's end; no attack through a wall (no tell without sight, sight broken mid-tell calling the strike off, the slash's and the bolt's own checks, each landing with the wall gone); SIGSTOP freezing a tell, the daemons' clocks and a bolt in the air, and them going on after it; practice never attacking or moving; the difficulty's damage (12, 20, 30 for the rogue's slash) and waits; the attacker cap holding and binding; the bolt a real, dodgeable projectile from a fixed pool; aggro range, the leash and the walk home; the solo life (100 health, the flash, the vignette, the jolt only with screen shake, a death, the 3 s respawn at a far spawn, spawn protection against daemons, deaths in the round's numbers); rogue.d's body box; the settings saved; every number in `resources/daemon_ai.tres`; nothing real touched by the fight code; and a host and a joiner on 127.0.0.1: the host's daemons hunting the joiner, their damage judged in the host's combat, the joiner's copies following them (tells, bolts, lives) and refusing its own shots, its shot landing through the host with its hit marker and its kill credited to it, a daemon's kill named on its banner, the host's practice handing back each player's own dummies; protocol 10.
- **Ping test** (C28). The weapon: its resource and numbers (a cooldown, no magazine, no damage), 9 bad values refused and the ping group on another weapon, slot 9 on key 9, its lime its own. The sources: the ping code calls nothing outside the game; the outline is drawn with no depth test from the daemon's own parts; nothing is made while a ring flies or an outline holds. In the real arena with the real player firing it: the ring grows to 9 m at a quarter second and 18 m at its half, fires its streaks and goes; rogue.d and a zombie behind the west cover wall, with no sight line to either, are outlined through it and tagged, and not roused; a daemon 17 m off is met as the front reaches it and one 19.3 m off never is; a daemon in plain sight 17 m off, past its aggro range, is outlined and stays home; the reveal holds, fades over its last 0.8 s and ends at 4 s to the frame, comes back with the next ping and ends at a derezz; rogue.d caught rearing, a zombie with its claw raised and the swarm pulling in each drop the attack (no strike, no bolt, no dive, no damage), rogue.d knocked back, reeling, then telling anew; a ping outside a tell changes nothing; fire held sends the next ping at 7 s and not before, the strip and the dish's rings showing it; practice outlines all three daemons and nothing leaves home. A host and a joiner over 127.0.0.1: the joiner's ping staggers the host's rogue caught mid-tell on it, the copy reeling, the outline only on the joiner's screen, the ring on both, a second ping sent too soon refused by the host; protocol 10, 24 RPCs.
- **Daemon variety test** (A5). Built alone: the same seed builds the same daemon part for part and pose for pose; 24 seeds of each type build 24 sizes, at least 4 part counts and varied battle damage; the elite rate measured over 12,000 seeds against the rule's one in twelve; every build inside its type's hitbox-safe size range, at its smallest, its largest and as an elite nothing drawn outside its box, its tag over it, the zombie's head over the head zone, rogue.d's body box scaled with it; an elite its type's biggest with more armour than any other build of it. In the arena: the seeds fixed by name in a run like this, the four rolling no elite; in play a respawn rebuilt from a new seed (its art, brain, box and tag); an elite living through a cannon shot. Killing the runaway's core flies every drone off whole and away. Then a host and a joiner over ENet on 127.0.0.1: the joiner's daemons are the host's builds, a wrong one put right by the host's word, a host's new spawn followed; the joiner's shot lands nothing on the host's runaway and the host's kill scatters it on the joiner's screen too. Seventeen deliberate breaks each fail it.
- **ICE test** (I1). The sources: the host's ICE word and a field's effect are new messages, the rules carry ICE on or off, joiners' shots and blasts at ICE are the host's to judge, a jammed weapon's shots are refused, protocol 12; the tuning sound, refusing a tell under a second or adaptation to immunity; every hit carrying its source and the brute breaker's hook. The colours: glacier and the hunter's cobalt each at least 0.12 (OKLab) from the player's teal and mint, the rail's two, ping's lime, the three daemons' colours, grep's cobalt and SIGTERM's violet, and from each other. Built alone: the same seed builds the same wall, jam node, HUD node and hunter part for part; twelve other seeds build twelve different ones of each. In the real arena: the gate seals the room's doorway (the level's rays stop at it, a shot lands on it, a walking player is held outside); a 1000 hit takes 100; every hit short of 600 leaves it sealed, its cracks deepening and panes falling; the last point breaks it and the player walks through. The jam node's field fires only at its tell's end (72 frames, its dome and its swell through it), jams the weapon in hand for 2.5 s while another swaps in and fires, and clears; the HUD node's fires at its tell's end, covers three parts of the HUD and more but never the health line, and clears after 4 s; stepping out of the dome during a tell escapes it; a broken node fires no more. The hunter: none in round 1, one at its post in round 2; it tells and its lance hits a player standing still (24), misses one who steps aside in the lock, and a ping mid-tell staggers it with no lance; killed, it is back after 15 s. The adaptation: 10% after the daemons' 100 cannon damage, 50% after 500, the HUD's line, a cannon hit taking half and SIGTERM's all of it, the shields shifting toward the cannon's teal; SIGTERM overtaking it; a new round forgetting it; the credit tag. Practice and the ICE setting each turn every piece off (the doorway open) and back on. A host and a joiner over ENet on 127.0.0.1: the joiner's pieces the host's builds, its own shot refused while the host's judging lands, the wall's cracks and break, the adaptation and its HUD line followed, a node's tell and the hunter's place followed, a field reaching the joiner jamming it there and the host refusing its weapon, the host's ICE setting ruling both screens. Twenty deliberate breaks each fail it.
- **ICEbreaker test** (I2). The sources: a joiner's run is an ask the host judges (from where it last heard the joiner's eye), the host's breaker word is all a joiner shows, an accepted shot or throw ends the shooter's cloak, protocol 13; the tuning sound, refusing a start past the cap or a cloak warning as long as the cloak; the I1 hooks carrying it (the brute through ICE's brute hook, exploit's bonus after the cap, no breaker noted for the adaptation); U and Y free in the input map and rebindable. The colour: the ultraviolet at least 0.12 (OKLab) from every bright colour of the palette. The art: each pickup's emblem and the decoy solid armour and light (no wire, no box) inside their budgets, the same seed the same build and ten other seeds ten others. In the real arena: a round's 1 of each, Y loading the next kind and skipping an empty one, U spending the loaded one and nothing with none left, a pickup taken by walking over it, kept at the cap, laid 15 s into a round, the same first pickup for the same round; the brute breaking a wall up close and leaving it a quarter from 3.4 m, 120 on a node and on the hunter, no ledger entry, a daemon in its cone floored and one behind left alone, a cloak ended; exploit's 2.5 on a seam only, never off it or from a blast, its time, the marks, the rail's 100 then 250; a cloaked player inside a node's range never triggering it until a shot ends the cloak, the hunter mid-tell calling its lance off, losing the player for the cloak's 5 s and seeing it again after, a daemon in sight never spotting a cloaked player; a decoy dropped mid-tell taking the hunter's lance and keeping it for its whole call while the player stands untouched in its sight, the hunter back on the player after, and a node's field going into a decoy instead of the player it jammed before. The readout's lines and effect lines, and its layout at 1280x720 and 960x540 over the sudo badge, clear of the strip, a full kill feed, a long guide notice and the hint line. The pick: the round's numbers only, whitelisted, with no path in the prompt; the scripted rules; with the AI off T's notice and the round's summary showing the scripted pick; with a stub AI (never a real call) Enter alone asking for the pick, and the round's one call carrying the numbers beside the coach task, the summary showing the AI's pick. Practice turning breakers off, the ICE switch leaving them on for the daemons. A host and a joiner over ENet on 127.0.0.1: the joiner's counts the host's word, its exploit run by the host and shown on it, a forged ask refused, its cloak hiding it on the host and its own shot ending it, its decoy thrown in the host's world and drawn where the host's stands from the host's seed, its brute breaking the gate on both screens, the host's own decoy shown on the joiner. Twenty-six deliberate breaks each fail it.
- **Pipe chain test** (C30). The sources: the pipe's code calls nothing outside the game and makes nothing while a chain is drawn. The weapon's numbers and 9 refusals, its brass measured in OKLab. The chain's rules on synthetic targets: the first hit and each link nearest first, 26 falling 70% a link, five links and six as root, the 12 m jump to the hundredth, a wall breaking a chain, a frozen link conducting whole and 1.5 times as far, a wall or Black ICE never jumped to. Shift+2, 2, Q and the wheel; the strip and a root's longest chain of 24-character names at 960x540. In the real arena: four dummies chained in order with each link's damage, the arcs, packets, spills and the model's spin; plain dummies all down and back; 11.8 m linked and 12.3 not; the low wall breaking a chain; a frozen zombie conducting and shattering; ICE with exploit's 2.5x on a node's seam; a wall hit first; Black ICE flashed only and never a link; the buffer filling, blocking, draining, root writing nothing. Then a host and a joiner over 127.0.0.1: the host judging the joiner's chain (its daemon, then the host's own player), spawn protection, the host's own chain built once, a miss drawn with no link, a mine shot off, a blocked buffer refused.
- **/dev/null test** (C31). The sources: the hole's code opens, writes and reads nothing (never the real /dev/null) and makes nothing while a hole holds. The weapon's numbers and 11 refusals, its plum measured in OKLab against every bright colour and far from ICE's, Black ICE's and the pipe's. The hole's rules: the pull growing inward and over its first second, damage inside the horizon only, the implosion's falloff, the charges coming back (the host's a quarter quicker). Shift+3, 3, Q and the wheel. The strip at 960x540 and 1280x720 with a full feed, the net panel and a long notice, a dragged player's warning, the hole's tag. The throw from the eyes, its arc and landing, its core a metre over the floor, one open at a time, the fuse at the sky, the recharge, root. In practice over four dummies: each one frame's drag for its distance against the tuning's (within 5%), the swirl, the look's parts up (the core, the lensing, the ring, the debris, the floor mark, the negative light), the stretch the nearer the more, damage only inside the horizon, the discard of a 400-health daemon at the core, the callout, the tag, the burst, all four discarded, the implosion and its tag, the dummies back. The end pulse for its distance. A fighting rogue.d's tell called off, nothing thrown, a crowd drawn into a knot. A frozen daemon pulled whole, shattered at the core. A daemon behind the low wall never held; the gate never moved or hurt, only flickering. The hunter pulled and hurt within ICE's cap, a node anchored but hurt. Black ICE never held or hurt, its seals whole, the tag's refusal. A cron mine drawn in and set off at the core. A match over 127.0.0.1: protocol 17 and 28 RPCs, the joiner's throw counted and run by the host, its copy opened at the host's place, the host dragged on its own screen, warned, discarded and credited to the joiner, the thrower never dragged, spawn protection holding, the host's hole dragging the joiner on its own screen, a throw with no charge refused, a joiner's hole dragging the host's fighting daemons.
- **SIGHUP test** (C32). The sources: its code (the burst, its look, its tuning, the HUD, a target's tag, the model and the brain's confusion) sends no signal to anything real and makes nothing while a burst runs. The weapon's numbers and 13 refusals, its carrier green measured in OKLab against every bright colour and far from ICE's, Black ICE's, the breakers', chmod's, the pipe's, /dev/null's and the daemons'. Its rules: the wave's time to its reach, the confusion's length and the most of any stretch it can hold, the charges coming back (the host's a quarter quicker). Shift+4, 4, Q and the wheel. The strip at 960x540 and 1280x720 with a full feed, the net panel and a long notice, a caught player's line clear of /dev/null's warning. The throw from the eyes, its arc and landing half a metre over the floor, the fuse at the sky, two in the air at most, the recharge and the model's lights, root. In practice over four dummies: each caught on the frame its front passes it, one past the reach spared, the look's parts, the tag and the callout, the reload's stall with its tag and its seams in the green, the wander (moving, looking round, its "?", its seams cycling, no attack), the walk home. The guard: a second burst while confused and one in the guard refused, one after taken. A daemon behind the low wall spared. A fighting rogue.d's tell called off and its prey dropped, no tell on the player all its confusion, then hunting again. A crowd's lashes (rogue.d's slash and the zombie's bolt, each at the lash's share, at most two each, none at the player), a lash kill credited to the thrower. A frozen daemon taking it frozen and starting on the thaw. A hole dragging the confused 1.3 times as hard. ping's outline green on the confused. The hunter confused and forgetting, a wall of ICE untouched, a node reloading (its field dropped while the player stands in it, then back). Black ICE never confused ("SIGHUP: ignored (nohup)"). A match over 127.0.0.1: protocol 18 and 28 RPCs, the joiner's throw counted and run by the host, its copy gone off at the host's place, the host caught on its own screen (its glitch, its line, its drifting crosshair, its link hung up) still walking and firing, unhurt, the thrower never caught, the confusion passing, spawn protection holding, the host's burst confusing the joiner alone, a throw with no charge refused, a joiner's burst confusing the host's daemons and the joiner's copies showing it, and that borrowed confusion ending quietly when the joiner leaves.
- **Unlocks test** (C33). The sources: the chunk's code (the save, the look, the kits, the skins and mods, the loadout screen, its turntable, the toast) opens no connection, runs no program, opens no file or folder of its own, decodes no object and names no URL; its one write is the progress save through the settings file's writer to `user://progress.cfg`; the nixfred logo is pinned to the byte. Every weapon's kit, a broken kit refused by name, every earned skin's two lights at least 0.16 (OKLab) from every hostile light and a weapon's skins 0.15 apart, every beam legible; every mod changing exactly its numbers on a copy and refused when strictly better. The save written and read back, a missing and a corrupt one (garbage, an object, a newer format, too big) a fresh profile, bad values left out one by one, a save outside `user://` refused. A threshold's edges, each unlock told once in the order reached, `--unlock-all` holding everything without saving it. In the real arena: a real cannon kill earning against fighting daemons with its toast, the same kill against practice dummies earning nothing, a mod and a skin worn in hand and a real shot landing the mod's 21, reset progress asking first, lapsing, then wiping. The loadout screen from the Esc menu at 960x540: whole on screen, every weapon, the cards, a locked one's progress, the turntable turning and lit live by a card under the pointer, Esc back and wearing on close; the toast's turns. A host and a joiner over 127.0.0.1: the joiner's mod judged by the host on a real shot, its tracer and avatar beam in its skin on the host's screen, a kill counted from the host's word alone, the mods rule off ignoring the mod and its skin kept.
- **Opener test** (C38, C40). It covers:
  - **The code.** The opener's 23 files (every script in `scripts/opener/` but the C39 reader, which step 49 checks, and every `opener_` shader), and the places the menu and the arena start it, read no environment variable or clock, run no program, open no connection, write no file and hold no loop. Every load names its own `res://` file, and every sound is made in code.
  - **The interface.** The demo data is fixed and invented. `clean()` drops escapes and control characters. A stub source's user, host, palette and folders reach the screen only through it, a 200-character name is cut to 32 and still typed by 0:15, and an empty source falls back to the demo's names.
  - **The palettes.** Six of them, all 24 of Omarchy's colour names valid, with text at 4.5:1 contrast or more.
  - **The typing.** Jitter (26 different waits in 32 keys), a 0.75 s beat before "did you?", the typo taken back, fit to its window.
  - **A whole run.** Every beat in order and inside its PRD window, the screen word for word, the prompt from the data in bash's colours, the palette applied, the uptime ticking a second at a time, the hold, then (C40) the 3 seconds it ignores typing, "you're in now.", the reveal, the fall inside 0:50 to 1:10, the landing and the hand-back, the machine dropped. The main loop ticks once a frame through every frozen frame. The darkness and the pop-in are drawn from the opener's brightness model, which a WCAG-style counter finds flashing at most twice in any second.
  - **Esc.** It leaves mid-crash, mid-typing, in the hold, while the terminal ignores you, mid-reveal, mid-fall and landed, and so does a pad's cancel, letting go of the pause, the 3D view, the mouse, every sound and the machine.
  - **The menu, in the real arena.** "Play the opener" sits between Loadout and Settings and pauses the arena behind the opener; Esc comes back to the menu as it was; the entry is greyed out in a match; `--opener` plays it.
- **Opener real-data test** (C39). Only a fake home folder it builds under `user://`, removed at the end. It covers:
  - **The reader's code.** It writes, saves, prints, logs, sends and runs nothing. Its environment is `HOME`, `USER` and `LOGNAME`, read in one function. Every engine call it makes is listed with its reason, and one function opens a file, to read, at most its cap.
  - **The walk.** The names in order, the counts, the times; the depth, entry, listing, per-folder and time caps; links in and out never followed; an unreadable folder and another filesystem kept as names; hidden folders from the top level only, last; CJK, emoji and accented names whole; the fake home untouched; the read off the main thread.
  - **The theme.** Omarchy's names, the older names, the derived shades and the mode; five unusable themes and an oversized file falling back; coloured text pulled to 3:1.
  - **Fallbacks.** Each value falling back alone, the file times and the clock together; no home, the root and a relative one.
  - **The terminal.** Cell widths, rows laid out in cells, a whole cluster taken back, `clean()` cut by cells with bidi controls dropped.
  - **Taking the data.** A source that is never ready taken at 3.1 s anyway; the demo's at once; a reader settled as it is taken changes nothing after, and the folders with their counts, and the file times with the clock, only ever arrive together.
  - **The opt-in, in the real arena.** The settings row and its note; off, or a demo run, or real-machine data off: the demo data and no reader made; on: the whole opener on the fake home in its theme, the reader dropped as it ends.
- **Opener fall test** (C40). Invented names and fake homes under `user://` only, removed at the end. It covers:
  - **The code.** The opener's build of its city reads the data's folders, their counts and the process name, and nothing else; the city and the machine touch no data source but `OpenerData.clean()`, read no file, environment or clock, and print nothing; no opener script prints, and the one warning any logs is a refused tuning's.
  - **The city.** The demo's city built twice is the same box for box; its 28 folders all towers or the pit; terraces by level, slices and cables by parent; entries setting width, height and windows; hidden and uncounted folders dim; the first `node_modules` the pit and any other a maze tower; escapes, line breaks, wide characters and a 90-character name cleaned and cut; empty and repeated names, an orphan, missing and short counts, no folders at all.
  - **The caps.** A 750-folder tree keeps 96 towers, the shallow ones first, 40 names, one cable a tower below the top; 100,000 folders are laid out in about 20 ms; the machine is at most 64 nodes.
  - **The camera.** The first frame square in front of the screen, filling the view to a tenth of a millimetre; every frame of its way within 1.5 m and 3 degrees of the last, never inside or through anything; the same way twice; the landing on the pit's rim facing it; the beat under once a second; the look clamped and springing back.
  - **In the opener.** A source's invented names and counts make its city, the process name the demo's; Esc mid-fall frees the machine; a source with nothing plays every beat; C39's reader on a fake home that is not there falls back to the demo's city, and on one of three folders makes them the city.
- **Trailer test** (T1). Nothing is rendered; one privacy file in its own folder under `user://`, removed at the end. It covers: the shot list (every shot a file-name id, a length, a line on what is in it and its own function; 75 to 90 seconds in all; all 13 weapons); the refusal rules (no `--demo`, the opener's real data on in its user data, headless); the tool itself run headless as a separate Godot, listing its shots, refusing without `--demo` and refusing to draw with it; its code parking a demo guide link with the real data written off and checking the opener is on the demo's data, and reading, running and calling nothing; the shell rendering a git archive copy on its private display only, and deleting nothing.
- **Opener link test** (C41). Invented names, a guide link on a fake detector and stub adapters only; the stub CLI's records in its own folder under `user://`, removed at the end. It covers:
  - **The code.** The link asks the guide link only (no process, file, network, model load, clock or print of its own) and builds its one request from `LINK_TEXT` with no stats. The beat, the copy and the HUD read nothing. The copy's name is the user name the opener already took. The new files are on step 48's list.
  - **The agent.** The real Claude Code adapter on the stub CLI: exactly the tools-off flags, no bypass, never `omarchy-agent`. Its system prompt is the preamble, and its prompt "Game stats: none" with `LINK_TEXT`. An answer that is not one of the lines shows as the first line, live.
  - **The fallbacks.** The AI off, no agent, an error, a local model not loaded and the cap each give the scripted line. A hung agent gives it at 77 s within a frame, its call stopped.
  - **In the opener.** A live and a hung agent play every beat at the same moments. The HUD's badge, linking line, live mark, status and the guide's line are right, and nothing of the data reaches the prompt or the line. The copy wears the data's user name (compared, never printed), cleaned. 18 hexagons, 16 steps, standing on its last. Everything is dropped at the end.
  - **The walk.** A whole number of steps; a planted foot never moves (0.0000 m); it stops 4.2 m in front, never nearer; the camera's own look small.
  - **Esc** mid-link (the call stopped) and mid-copy. **Demo data** calls nothing.
- **Arena art test.** The sources: the arena scene holds the dressing, the skyline, a sky and a depth fog; its gameplay nodes (every block, the spawn points, the targets) and the scenes and script that make collision are byte for byte as before A3 (by sha256); the art code calls nothing outside the game, no wall clock, nothing loaded or saved at run time; the dressing has no per-frame code and the skyline's only turns its nodes; the sky never runs on the clock. In the real arena: every block but the floor dressed, the signs in the font, the holograms; the dressing, the skyline and the whole arena inside their triangle and draw-call budgets; nothing under them can collide, and the arena's collision (every body, shape, place and spawn point) and the sight lines from every spawn point to every daemon equal literals taken from the commit before A3; every vertex a player can walk into within 0.3 m of a block, nothing over a top a player stands on below a jump's reach; every surface wearing one of the palette's shared arena materials; 120 frames rebuilding nothing while the ring and the drift turn; the palette's sky and fog in the environment; a reload taking the kept meshes.
- **Bullet time test.** SIGSTOP's resource and numbers, nine bad values refused, the meter's rules alone. A scan proves the engine's time scale is written in two places only, both in `scripts/abilities/sigstop.gd` (a hold that returns first in a match, and a restore to exactly 1.0), that the ability runs, reads and signals nothing, and that the wire is protocol 4 with the host's meter check and zero spread on its word only. F moved to G, saved to a settings file in a temporary folder and read back; Ctrl+Alt+F refused. In the real arena: no start below a quarter of the meter; during SIGSTOP the time scale is exactly 0.3, a falling body, the physics time and the round clock run at 0.3x, while the player walks 6.30 m/s against its 7.00 (0.9x in real time) and its weapon cools at 0.9x, with zero recoil and nine straight pellets; the meter drains a second per real second and refills 0.2 s a second; and the time scale is exactly 1.0 again after SIGCONT's ease, after the meter runs out, at once after a death, a round's end, the Esc menu (mid-ease too), a stray change and the arena being freed. Over 127.0.0.1: hosting mid-SIGSTOP ends it before the match's first frame; the joiner's SIGSTOP, started and ended by the host's word, never moves the time scale off 1.0 or the host's clock off 1/60 s a frame, and both players walk at their normal speed; the host draws the joiner's pellets straight while it says SIGSTOP is on and from its generator again after; an R reload keeps the host's word; a forged empty-meter ask is dropped as "sigstop"; the host's own SIGSTOP slows nothing; a death empties the meter on both sides.

Before a test is trusted, deliberately broken copies of the project prove it can fail: no friction, a missing slide timer, a hit marker that never shows, effects that never free, a cooldown cut short, a dummy that stays solid while it derezzes, voxel motion that changes with the frame rate, voxels resting on air past a ledge, rain that never fades out, an enemy cap ignored, a detector that runs the agent's command or an extra nvidia-smi flag, a hung agent reported as anything but a timeout, a boot screen with its headless guard removed (the fixtures' agent stub then runs and leaves its mark), a player that ignores the ask box's input lock (it then drifts and fires while you type), a loader that ignores what was loaded when you said Y (it then loads and unloads someone else's model), a round announcer that skips the link's gate (it then calls with the AI off, mid-call, in the cooldown, at the cap and under the headless guard), one that forgets which call is its own (it then takes T's answer and stops T's call), a guide HUD that ignores the break's hold (the panels then overlap at 960x540), a net test told to expect 60 sends a second, a session that lets a yaw of 1e300 through (the avatar's rotation then goes infinite for a few frames), an avatar that accepts any newer sequence number (one far-ahead packet then freezes it 2.9 m behind), one that keeps only twelve positions (a 1000 ms delay then jumps and lags 3 m), one with no baseline for a fresh avatar (invisible after a reload), a host that skips the fire-rate check (two shots in one frame both land), a combat test told to expect the wrong health, a host without the life number on positions (a respawned avatar dragged back to its corpse), a host that marks a player dead before telling of the death (no derezz on its screen), a host that skips the cover probe (damage through a wall), a ray blind from inside a body, a probe that counts the dead host as cover, a respawn lost during a reload, a host that lets a shot stop at a corpse, a feed that forgets who a departed player was, a host without the life check on intents, a feed kept across matches, a HUD that lights the hit marker on a local guess in a match, a room code without its checksum (every typo then accepted), a session that applies `--join` before it is ready (a script error, the invite lost), a session that follows a rendezvous to any address, one that forgets an unanswered registration, a panel that keeps saying a code is coming after the registration failed, a weapon test told to expect 8 pellets, an inventory that lets a shot through mid-swap (the first shot then on frame 1), a host that takes an unknown weapon for the cannon, one that ignores the magazine, damage with no falloff, a session that refills ammo on an R reload mid-match, a host that refills on a draw, ignores the draw time or the weapon in hand, or loses a finished reload to a draw, no refill for a respawn while away, no fresh start to a match, no weapon handed back at a respawn, pellets from an aim not made unit length, no draw at the first roster, a joiner sending shots before its fresh start, two copies of one weapon after a slot 1 override, only one pellet doing damage, a reload refused when it comes with a late draw, a host that keeps its count to itself, a game that takes a stale count or loses one that came during an R reload, one that does not wait for the host's longer reload or draw (or waits to the exact frame, or only while its own is still running), one that lets a late count undo its finished reload, a right stick that ignores invert Y, a settings file scan that lets any value through (a `Color()` then loads), a bind check that lets Ctrl+Alt through, a menu that pauses the tree, a relay that ignores its payload cap, skips the cookie or never expires a code, a game that falls back to a relay with no URL set, a menu that saves before the relay box gives up its text, a rail that does not pierce, a host that skips the rail's meter check, a SIGSTOP whose restore never puts the time scale back to 1.0, a SIGCONT that never brings the world back with no safety check behind it, a SIGSTOP that slows the world in a match by the host's word, a host that slows the world for everyone while a player's SIGSTOP is on, a WebSocket relay that lets oversize datagrams through or never closes an idle link, a fork bomb with no generation cap, a joiner's screen that decides the chain, a host that takes a throw with no bomb left, light trails with no grace on your own wall, a trail kill credited to the victim, walls laid in the air, no cap, a death that leaves the walls, a late joiner never sent the standing walls, code-rain vision with no start minimum, no range limit, a death that empties its meter, silhouettes that obey the depth test, no turning off at a death, a host that believes a chargeless sudo ask, a host that skips root's scale, sudo charges that stack, a death that keeps the charge, root that still spends rounds, a meter filled from root's harder hit, a top table that refreshes every frame, one sorted by name, a joiner that shows its own guess at another player's health, a table that stays up after the respawn, one that asks the system for its process id, a host that sends its table every frame, fork() pellets that never fork, grep darts that turn without a limit, a host that believes every grep claim, a lock with no lock time, no cap on marks, marks kept when grep is put away, a joiner that drops a shot whose marked player has left, a lock that holds a freed target typed (a script error every frame), an rm -rf cannon with no wind-up, a blast through cover, a blast that spares its shooter, a cancelled wind-up that spends its round, joiners' slugs that decide, no weight, the weight cutting the air speed at once, a blast with no falloff, an OS call in the slug (a harmless one, never run, to prove the scan), cron mines with no arm delay, no root crontab, a mine hurting its owner, no crontab limit, no brighten before a run, every screen keeping its own schedule, no counterplay, a joiner's mine giving up too soon, an OS call in the mine, no mines for a late joiner, a mine stopping once its owner is dead, jobs outliving their owner, a decoration that collides, the arena's light rebuilt every frame, a light material made each time one is asked for, ten times the skyline's towers, the north wall's collision a metre shorter, an OS call in the skyline, signs standing half a metre off the walls, the fog back to exponential, the sky on the clock, a rogue daemon that never moves, collision scaled with the creatures, a mesh made every frame, a creature material of its own, an OS call in the zombie, an instance uniform left unpinned, sixty insects, creatures at half size, the shell on the wall clock, no shatter at a kill, no reaction to a hit, a gait with no tripod, a zombie with no ghosts, a swarm's scatter clamped to its top speed, a low preset keeping SSAO, a node made every frame in the particle pool, a pool past its cap, a setting not saved, a weapon's damage changed by one, the strips back on TIME, viewmodels with no fixed projection or no shrink, the arena's clock deaf to SIGSTOP, a drawn slug's true path moved, a muzzle burst family not shared, a draw material made per shot, a rig deaf to the shot jolt, a particle level by ratio alone, a beam's end sparking twice; and for C33's unlocks test twenty-three more, each failing it by name: a threshold off by one, feats counted in practice, a newer save read, the save outside `user://`, a skin near a hostile light, a strictly better mod, a mod changing the shipped weapon, the host ignoring its mods rule or judging the shipped weapons, a tracer in the stock skin, a victim counting its own death, a toast never shown, a screen that never shrinks, a preview that lights nothing, reset without asking, a wear that does nothing or refills, a URL in the save's code, the test flag saved, a locked skin worn, a hello without its look, a solo kill not counted, the logo touched; and more. Each one makes `scripts/check.sh` exit 1.

### The Codex bug run

Off for now (Fred, 2026-10-28 8:04 PM ET): no chunk calls Codex until Fred turns it back on, and Larry reviews each chunk's full diff himself before the report instead. When it is on, it works like this. Every chunk ends with a second opinion. After the gate passes, the chunk's diff goes to the Codex CLI, run non-interactively in a read-only sandbox, with a prompt to hunt bugs, Godot API misuse, frame-rate dependence, edge cases and safety-rule violations. Real findings get fixed and the gate is re-run; findings that are rejected are written down with the reason. When the fixes are substantial, Codex reviews the fixes too. Codex never gets write access, never commits and never pushes.

### The chunk pipeline

SIGKILL is built one small numbered chunk at a time, from the PRD. Every chunk goes through the same path before it lands.

```mermaid
flowchart LR
    PRD["docs/PRD.md"] --> Chunk["Numbered chunk brief"]
    Chunk --> Build["Larry builds it"]
    Build --> Check["scripts/check.sh<br/>parse, headless import, headless run"]
    Check --> Review["Self-review of the full diff<br/>(Codex bug run when Fred turns it on)"]
    Review -- real findings --> Build
    Review --> Commit["Commit, push to main"]
    Commit --> Audit["Producer audit"]
    Audit --> Chunk
```

### Docs

- [`docs/PRD.md`](docs/PRD.md): the entire, current PRD (v0.3): what is 1.0, post-1.0 and 2.0, every feature, the hard safety rules, every chunk and its status
- [`docs/DESIGN.md`](docs/DESIGN.md): decisions log and design notes
- [`docs/ENGINE.md`](docs/ENGINE.md): why Godot 4
- [`docs/RELAY.md`](docs/RELAY.md): the rendezvous, punch-through and fallback relay design for room codes, and the hosting cost note (nothing is deployed)
- [`docs/RELEASE_NOTES-0.33.0-prealpha.md`](docs/RELEASE_NOTES-0.33.0-prealpha.md): the pre-alpha drop, what is in and what is not
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md): the 0.33.0-prealpha drop, step by step: done through the GitHub release; the site button and the X post are left
- [`docs/STORY.md`](docs/STORY.md): the story bible (C34), locked by Fred on 2026-10-30
- [`docs/TRAILER.md`](docs/TRAILER.md): the teaser footage (T1): how to re-render it, what it needs, demo data only
- [`CREDITS.md`](CREDITS.md): who made what, including community prompts

## Install and play

Runs from source, and from the Linux x86_64 pre-alpha build on GitHub Releases ([Download (pre-alpha)](#download-pre-alpha); [v0.33.0-prealpha](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha), released 2026-10-30). AppImage and AUR packages are planned and not available.

**Requirements**

- Godot 4.x from pacman (the project is built against 4.7)
- A Vulkan-capable GPU and driver. High is the default graphics preset; medium (Settings, Video) is aimed at an RTX 4050-class laptop GPU (not yet measured on one), and low at anything smaller
- git
- For running the checks: `uvx`, which fetches the GDScript parser, unless `gdparse` is already installed
- Optional: an AI guide. The boot screen uses your Omarchy default agent (Claude Code and Codex so far), with a local model server such as Ollama or LM Studio as the fallback, and asks you before the first call

**Quickstart (Omarchy / Arch)**

```bash
sudo pacman -S --needed godot git
git clone https://github.com/nixfred/sigkill.git
cd sigkill
scripts/play.sh
```

`scripts/play.sh` imports the project once, headless, the first time (a fresh clone has no import cache yet, about a minute), then launches it; after that it starts straight away, and so does `godot --path .`. It installs and changes nothing outside the project. Launch options go after `--` with either: `scripts/play.sh -- --demo`.

The game opens on the boot screen. It names your AI, asks once before calling it (Y allows, N keeps it off), then moves on to the arena; Esc or Enter skips straight there. Five launch options, after `--`:

```bash
godot --path . -- --demo                         # demo data only: nothing read from your machine, no AI called
godot --path . -- --no-ai                        # the boot screen without any AI link
godot --path . -- --join sigkill://join/ABC23P   # join a room by its invite link (or --join ABC23P)
godot --path . -- --light-trails                 # light-trail mode on for this run's hosting (never saved)
godot --path . -- --demo --opener                # play the opener (C38, demo data) from the Esc menu as the arena loads
```

Room codes need a relay: with none set (the default, as no relay is hosted yet), `--join` and K in the multiplayer panel answer "Online rooms aren't live yet. Use LAN join (address)." Use the LAN or tailnet steps below, or run a relay yourself ([docs/RELAY.md](docs/RELAY.md)) and set it in Settings, Multiplayer.

In the arena, T asks your AI anything, O turns it on or off, B turns the roast announcer on or off, and M opens the multiplayer panel.

### Playing on a LAN or tailnet

Two machines, both running SIGKILL from source, on the same network or the same tailnet.

1. **The host** presses M, then H. The panel says "Hosting on port 9009".
2. **The host shares an address** the friend can reach: the machine's LAN IP (`ip -4 addr` shows it), or on a tailnet its tailnet IP or MagicDNS name. The README calls it `<host-ip>` or `host.example`; never type a real one into the repo.
3. **The friend** presses M, then J, types `<host-ip>` (or `<host-ip>:9009` if the host changed the port, or `host.example`), and presses Enter. Within a moment both panels show "players 2/2".
4. Either side presses L to leave.

With a relay set in Settings, Multiplayer (both players set the same one), the host sees a room code on H, and the friend presses M, then K, and types it (or starts the game with `--join` and the invite link); the match then runs through the relay. With none set that answers "Online rooms aren't live yet. Use LAN join (address)."

In the match, shoot each other as you would a dummy: four cannon hits derezz a player, and so does one point-blank SIGTERM shot. A derezzed player respawns three seconds later at the spawn point farthest from you, safe for two seconds. Your health sits under the net line, the kill feed at the bottom right. The host's machine judges every shot, so what you see confirmed is what counted.

For Tron deathmatch the host ticks "light trails" in Settings, Multiplayer before or during the match (or starts with `--light-trails`): every path on the ground leaves a neon wall, and touching one derezzes you. The friend needs nothing; the host's rule is the match's.

SIGKILL uses one UDP port, 9009 by default (`resources/net.tres`), on every interface of the host's machine. **Firewall:** Omarchy ships with ufw on and incoming traffic denied, so the host allows the port once, for LAN and tailnet alike: `sudo ufw allow 9009/udp`. SIGKILL never changes your firewall itself. Only the two of you are on the wire: there is no discovery, no relay and no server of anyone's, unless you set a relay in Settings for room codes. That relay, built in C16c, waits to be hosted.

Click into the window to grab the mouse. Esc gives it back and opens the menu, and switching away from the window gives it back too.

### Controls

Bindings are registered in code in `scripts/controls.gd`, with mouse look and the click-to-engage rule in `scripts/player.gd`. There are no Ctrl, Alt or Super chords, and none can be bound. The table shows the defaults; the moves, jump, slide, crouch, fire, aim, reload, last weapon, respawn, T, O, B, M, F, G, U, Y and the weapon bank key (Shift) can be rebound in Settings.

| Input | Action |
|---|---|
| W / A / S / D, or the arrow keys | Move |
| Mouse, or a gamepad's right stick | Look. Invert Y flips both |
| Space | Jump |
| C | Slide, when running fast on the ground. Jump during a slide to keep its speed |
| X | Crouch: the view drops and the pace slows to 3.5 m/s. Held by default, or a toggle in Settings |
| Left click | Fire the drawn weapon (the first click only grabs the mouse) |
| Right click | Aim down the sights: the view narrows and turns at the aim sensitivity. Held by default, or a toggle in Settings |
| 1 to 9 | Draw the weapon in that slot: 1 the terminal cannon, 2 SIGTERM, 3 the SIGKILL rail rifle (fires only with its meter full), 4 the fork bomb (fire throws it), 5 the `fork()` shotgun, 6 the `grep` seeker (hold aim to mark), 7 the `rm -rf` cannon (fire winds it up), 8 `cron` mines, 9 `ping` (fire sends the sonar ring) |
| Shift + 1 to 9 | Draw the weapon in that slot of bank 2, weapons 10 to 18: Shift+1 `chmod 000`, the freeze ray (hold fire for its beam); Shift+2 `pipe \|`, the chain beam (a click, one chain); Shift+3 `/dev/null`, the black hole (fire throws the device); Shift+4 SIGHUP, the confusion grenade (fire throws the handset). Holding Shift lights bank 2 on the strip |
| G | Throw a fork bomb without drawing it: one of your two, shown on slot 4 |
| U | Run the loaded ICEbreaker (I2): brute, exploit, cloak or decoy. The readout bottom left shows which is loaded and how many you carry |
| Y | Load the next ICEbreaker you carry. (Y and N still answer the guide's questions while one is up) |
| Mouse wheel | Next or previous weapon, round and round |
| Q | Back to the last weapon |
| E | Reload. Fire on an empty magazine reloads too. (R was taken, so reload is E) |
| F | SIGSTOP bullet time, when its meter holds at least a quarter; F again sends SIGCONT. The strip's line under the ult meter shows the meter. Alone the world slows to 0.3x while you keep 0.9x; in a match nothing slows, and your shots go steady while the host says it is on |
| V (hold) | Code-rain vision: enemies within 40 m through walls as glyph silhouettes, your screen dimmed green, while you hold it and its 3-second meter lasts. The strip's last line shows the meter |
| Z | Sudo: spend a sudo charge (3 kills in one life earn one) on 8 s of root: the weapon in hand 1.5 times as hard, no ammo spent. The badge bottom left shows `user$`, then `root#` |
| Tab (hold) | Spectate as top: the match as a process table while you hold it (alone: you and the dummies). Derezzed in a match it is up without Tab until you respawn |
| R | Respawn all targets |
| Esc | Open the menu (Resume, Loadout, Play the opener, Settings, Quit) and release the mouse. Loadout shows every weapon's skins and mod (C33): a card under the pointer lights the turning model, a click wears or fits, up and down pick the weapon. Esc again goes back a step. A box or question that is open takes Esc first |
| Esc, Play the opener | Play the opener, all two minutes (C38 to C42), on demo data, or on your own machine's names with Settings, opener data on (C39), the arena paused behind it. Alone only: greyed out in a match |
| Esc, while the opener plays | Pause it in its own menu: Resume intro, Skip intro (focused: Esc then Enter skips), "Skip the intro next time"; Esc again resumes (C42) |
| Hold Space, while the opener plays | Skip it (a second's hold; C42) |
| Fire, at the end of the opener | The first kill: the forged rifle's one shot (C42) |
| Esc, during the opener | Leave it at once, back to the menu as it was: mid-crash, mid-typing, mid-fall, any moment. Nothing else you press does anything while it plays |
| Mouse, during the opener's fall and after | Look about a little (C40, C41; standing, the copy mirrors it); it springs back, and it never steers |
| Esc or Enter, on the boot screen | Skip to the arena |
| Y or N, on the boot screen | Allow the AI guide, or keep it off |
| T | Ask your AI anything: a one-line box, Enter sends, Esc cancels. The game takes no input while it is open |
| O | Turn the AI guide on or off; turning it on asks first (Y or N) |
| Y or N, when the HUD asks to load a model | Load it on your local Ollama server, or keep the AI off; Esc stops waiting for a load |
| L, in demo mode only | Show the model-load question with a fake model and a fake load |
| B | Turn the roast announcer on or off: at a round's end your AI roasts your play instead of coaching it. Off by default, saved for next time |
| M | Open or close the multiplayer panel |
| H, J, L, in the multiplayer panel | Host on port 9009; join by the host's address (a one-line box: Enter joins, Esc cancels, the game takes no input while it is open); leave |
| K, in the multiplayer panel | Join by a room code or a `sigkill://join/` link (the same kind of box), through the relay set in Settings, Multiplayer. With none set (the default) it answers "Online rooms aren't live yet. Use LAN join (address)." |

### Settings

Esc opens the menu; Settings shows every setting at once, in three columns, with nothing to scroll but the list of keys. Changes work at once and are saved when you leave the screen. The menu pauses nothing: it only stops your own input (the round clock waits too), so in a LAN match the other player, the host's simulation and the shots go on, and you can still be hit.

| Section | Settings |
|---|---|
| Controls | Invert Y (mouse and right stick), mouse sensitivity, a separate aim-down-sights sensitivity, crouch and aim as hold or toggle, and a key for each rebindable action. A key or mouse button press sets it; Ctrl+Alt is refused by name, and so is any Ctrl, Alt or Super key or chord, and Esc; a key another action or a fixed key (an arrow, a weapon slot, the wheel) already uses is shown as a conflict on both rows. Reset keys puts them back |
| Video | Window mode (windowed, fullscreen, borderless), resolution scale (50 to 100%), frame cap, vsync, field of view (60 to 120 degrees; the shipped 80 until you move it), and a quality preset: high has bloom, sun shadows and code rain, medium drops the shadows, low drops all three |
| Audio | Master, effects, music and announcer volumes, each on its own bus. The weapons are effects; the round callouts ring a short chime as the announcer; no music is in the game yet |
| HUD and accessibility | Crosshair style (cross, dot, circle, cross and dot) and colour, a colorblind-safe palette, screen shake (a shot's jolt, which never moves your aim, and the head bob), motion blur (the view stretching wider at speed: SIGKILL draws no other blur), and subtitles for the announcer's callouts. Turning screen shake or motion blur off also calms code-rain vision: half the tint, glyphs held still |
| Privacy and AI | The AI on or off (the same switch as O: turning it on asks the same question by name, Y or N), the roast announcer (B's switch), and real-machine data: off is demo data from the next launch, exactly as `--demo` is; and opener data (C39): off unless you turn it on, it lets the opener show your user and host names, folder names and counts, file times, theme colours and uptime, read live, never a file's contents, never kept; it counts the next time the opener plays, and a demo run keeps the demo data |
| Gameplay | The difficulty (easy, normal, hard; normal until you change it: the daemons' damage and how soon they attack again, never shorter tells) and practice (the old daemons that never attack, your health hidden, and no ICE); and ICE (I1, on by default): off, there is no ICE wall, node or hunter. In a match all three are the host's, as light trails are (C27b) |
| Multiplayer | A display name (letters, digits, spaces, `-`, `_` and `.`; a label on your own screen only, never sent: in a match everyone is Daemon-&lt;slot&gt;), the default port (9009 until you change it), the relay for room codes (`udp://host:9010` (C16c), or `ws://` or `wss://` for its WebSocket mode (C16d); empty, the default, means no online rooms and no network call), a net stats line (round trip, packet loss, send rate), and light trails (C20): light-trail mode for the matches you host, off by default, at once mid-match; a joiner plays by its host's; and mods (C33): on by default, the host judging each player's weapon mod in the matches you host (fixed when you start hosting); off, everyone plays the shipped weapons |
| Progress | Reset progress (C33), under the settings: the first click asks, a second within 4 s wipes every unlock, count and choice; nothing else changes |

### Built: the settings screen (C16b)

- **One file, versioned.** `user://settings.cfg`, a Godot ConfigFile with `[meta] version=1` and a section per area, the privacy answers in `[privacy]` beside the rest (`scripts/settings/settings_file.gd`). It is read strictly before ConfigFile ever sees it: plain ASCII up to 4 KB, every line a comment, a section or a key with a plain value (true, false, a number, a "string" with no quote or backslash). A constructor such as `Color(...)` or `Object(...)`, a list, a dictionary, a key or section twice, an unknown version: the whole file reads as missing, so a damaged file means the defaults and one more AI question, never a call without your yes, and nothing in it ever becomes an object. A single bad value in a good file falls back on its own. The file from before C16b still reads, and its AI answer carries over.
- **The settings.** `scripts/settings/game_settings.gd` holds every setting with its type, default and bounds; every default is the game as it shipped, so nothing changes until you change it. `scripts/settings/settings_apply.gd` puts the engine's into effect (buses and volumes, window, vsync, frame cap, render scale, binds); the player, crosshair, colour filter, round HUD, arena and net HUD read their own.
- **The menu.** `scripts/hud/pause_menu.gd`. Esc reaches it only when no box, panel or question took the key first. A window smaller than the screen (960x540, say) shrinks it whole rather than cutting a row off.
- **Privacy stays with its owners.** The menu keeps no copy of the AI, roast or real-data state: it presses O's and B's own switches and saves the real-data and opener-data answers through `scripts/boot/guide_settings.gd`.
- **New moves for it.** Crouch on X and aim on the right mouse button, both new, and right-stick look. The colorblind-safe palette is a full-screen filter that moves the hostile reds and ambers to vermillion and yellow and the player side's teal and mint to sky blue, the Okabe-Ito pair.
- **Seen headless only.** No window has shown the menu yet; its layout is measured headless at 1280x720, 1920x1080 and 960x540.

The test, `tests/settings_test.gd`, covers invert Y through real mouse and pad events, every setting saved and read back from the model and from the screen's own widgets, Ctrl+Alt and every other chord refused from the model and from real key presses on the screen, conflicts shown, the defaults on a missing file and on 19 kinds of damaged one (and the arena running on them), each setting reaching what it drives, Esc still skipping the boot screen, the layout, and a host and a joiner over 127.0.0.1 whose clocks, state and shots run on while either menu is open.

### Running the checks

```bash
scripts/check.sh
```

Exit 0 means every step passed, 1 means a problem was found, 2 means the gate itself could not run. Each test can also run on its own, headless:

```bash
godot --headless --path . --fixed-fps 60 --script res://tests/movement_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/cannon_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/derezz_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/code_rain_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/ai_detector_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/guide_adapter_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/boot_sequence_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/guide_hud_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/model_load_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/round_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/net_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/combat_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/room_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/weapon_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/settings_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/relay_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/rail_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/bullet_time_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/relay_ws_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/fork_bomb_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/light_trail_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/code_rain_vision_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/root_sudo_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/spectate_top_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/fork_shotgun_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/grep_seeker_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/rm_rf_cannon_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/cron_mines_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/viewmodel_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/enemy_art_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/arena_art_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/enemy_motion_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/graphics_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/daemon_ai_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/ping_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/daemon_variety_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/ice_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/breaker_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/black_ice_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/freeze_ray_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/pipe_chain_test.gd
```

## Safety and privacy

These rules apply to every chunk, from PRD section 6, in plain language:

- **SIGKILL never changes your system.** It never modifies, deletes, executes, signals or kills anything on your machine, with one exception: it stops the agent process it launched itself, by that process's own PID, on a timeout, a cancel or exit. Everything it looks at is read-only: folder and process names, sizes and counts for the machine-world features; process IDs, parent process IDs and CPU and memory numbers for the Audit Trail visor; user and host names, folder names and entry counts, modification times, uptime and theme colours for the opener, only with its switch on; GPU utilisation, VRAM and temperature for the HUD; model names and whether they are loaded, for the local AI fallback. It never reads what is inside your files, with narrow exceptions: the single line of Omarchy's default-agent setting, read to find your AI; and, only with the opener's switch on, three small files read for a number or the colours: your Omarchy theme's `colors.toml`, `/proc/uptime` and the kernel's host name.
- **Two narrow exceptions, and nothing else.** First, the game may launch your Omarchy default agent's own command-line tool in its non-interactive mode, with tools, file edits and shell disabled, no auto-approve flags, never through `omarchy-agent`, and with only round numbers and what you type in the prompt: never file names, paths, process lists or system information. Second, for the HUD's GPU stats, it may run an optional, query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader`, never with control flags; it prefers reading /sys, and if neither works the HUD hides GPU stats. Nothing else is ever executed.
- **Asked first, and never in a test.** The AI is called only after you say yes, on the boot screen or with O in the arena, for that agent or server. A model is loaded on your local Ollama server only after a second, separate yes in the arena, never saved, and only with a body of exactly `{"model": "<name>"}`; SIGKILL unloads only a model it loaded itself and that was not already loaded when you said yes, on O and at the end of the session, and never touches any other model or any shared setting. Between rounds it gets only that round's numbers, at most once per round, within the same pace and session cap. Headless runs and `--no-ai` never call it, whatever was saved.
- **One thing outside the game's own code.** The Godot engine itself, at startup, runs `xdg-user-dir DESKTOP` through `sh` and connects to the D-Bus session and system buses. It does this for any project, even an empty one (seen with strace). SIGKILL's code does neither, and this is noted for the PRD.
- **Its own folder, and nothing else.** Everything the game writes goes in its own data folder (`user://`, which is `~/.local/share/godot/app_userdata/SIGKILL/` on Linux). Two files are the game's: its settings and your privacy answers (`user://settings.cfg`), and your unlocks and loadout (`user://progress.cfg`, C33). It reads both as data only, never as code or objects, and a damaged or missing file gives the defaults. The rest is the Godot engine's own, as for any Godot game: a log of the last few runs' console output (`logs/godot.log`: the engine's version, its warnings, and the game's one status line and warnings about its own tuning files) and its shader caches (`shader_cache/`, `vulkan/`). None of it ever leaves your machine. Turning real-machine data off makes every later launch use demo data. The release's `install.sh` and `uninstall.sh` touch three files of their own in your home and nothing else (see [Download (pre-alpha)](#download-pre-alpha)).
- **Nothing private leaves your machine or lands in the repo.** No real paths, hostnames, process lists or model lists in the repository, in screenshots or in trailers. Anything public uses demo data.
- **One socket, yours.** The only network connection the game makes is the ENet socket you open by hosting or joining (UDP 9009 by default), to the address you typed. Room codes contact nothing unless you set a relay in Settings: with none (the default) the game's rendezvous is `NullRendezvous`, which sends nothing anywhere. With one set, the game talks to that relay only: its control requests (the room code, the protocol version, the host's game port, a cookie and the room's token), and the match itself through it (docs/RELAY.md). A `ws://` or `wss://` relay is one WebSocket connection (TCP) to it, with the match's datagrams passed through loopback sockets on 127.0.0.1 that only the game's own ENet may use (C16d). No discovery, no broadcast, no relay, no server of anyone's. Over it go only the protocol version, player slots and ids, a placeholder name (the display name you set in Settings stays on your own screen), positions, angles and velocities, shot intents and results, health, deaths and respawns by id, SIGSTOP's asks and the host's on-or-off word with its meter, and fork bomb throws with the host's seed and blasts: never paths, host or user names, process lists, settings or anything your AI said. Shooting and kills are in-game fiction: nothing real is signalled, killed or run.
- **Your desktop stays yours.** No Ctrl+Alt hotkeys, and none can be bound: the settings screen refuses any Ctrl, Alt or Super key or chord. The mouse is captured only while the window is focused and is released on Esc (which opens the menu) or when focus leaves. The game never steals focus and uses no GPU when it is not running.
- **The daemons are fiction.** The daemons that hunt you (C27b) are game objects in the arena: their names, attacks and deaths touch no real process, and nothing in the fight code signals, inspects or runs anything on your machine (the daemon AI test scans it).
- **The opener plays fair.** Everything that looks hacked is rendered fiction. Esc always pauses it with "Skip intro" one key away, holding Space skips it, and the window's close button always works. It runs on demo data unless you turn on Settings, Privacy and AI, opener data (C39, off unless you do): then it reads names, counts, file times, your theme's colours and your uptime, read-only and never a file's contents, keeps them in memory only while it plays (the fall through your folders, C40, is built from those same names and counts, nothing more, and the copy of you, C41, wears that same user name), and lets them go as it ends; your AI is told only that the game is starting (C41); nothing is saved, logged or sent, and captures and trailers always use demo data. The first launch asks first (C42), No highlighted; saying no gives you the same opener on fake data. The kill feed names only your user name; the score and every sound are made in code.
- **Original art and audio.** Today's sounds are synthesised in code, and the repository contains no audio files. Concept art is always labelled as concept art.
- **Public repository under the MIT license since 2026-10-28; nothing else goes public (releases, packages, store pages, the relay) without Fred's yes.** Every chunk reports real command output.

## Roadmap

Status from `git log`. Hashes are the commits that finished each chunk.

| Milestone | Chunks | Status |
|---|---|---|
| M0 Foundations | C1 Godot installed, clean headless import (`823de8b`) · C2 quality gate and first Codex bug run (`c26061f`) · C3 GitHub repository, private at first (`e57697a`; public under MIT since 2026-10-28) | ✅ Done |
| M1 Look and feel | C4 Tron environment (`de7c203`) · C4b README graphics (`52383f3`) · C5 movement feel (`c223950`) · C6 terminal cannon feel (`6403dbd`) · C6b this README · C7 derezz deaths on the dummies (`238d3ac`) · C8 code-rain walls (`3ee66b1`) | ✅ Done |
| M2 Your AI | C9 AI source detector (`1bd17b2`) · C9b agent adapters (`f9cf9b4`) · C10 boot sequence (`3184454`) · C11 guide HUD (`be2f220`) · C11b local model-load consent (`1fc87b7`) · C12 coaching and roasts (`e72c644`) | ✅ Done |
| M3 Multiplayer | C13 LAN and tailnet (`6a83ae0`) · C14 synced combat (`19a4781`) · C15 room codes and invite links, client side and relay design (`5c1a8d3`) · C16c the relay itself, local only (`b5a2f42`) · C16d WebSocket relay mode, tested on 127.0.0.1, hosted nowhere yet (`3c78dc3`), relay hosting waits on Fred | ✅ Done, relay hosting waits on Fred |
| M4 Arsenal and modes | C16 weapon framework and SIGTERM (`619a109`) · C16b full settings screen (`76afcbc`) · C17 SIGKILL rail rifle (`e10a006`) · C18 SIGSTOP bullet time (`7927cb2`) · C19 fork bomb (`372d91a`) · C20 light-trail mode (`4d5e92e`) · C21 code-rain vision (`d6d4576`) · C22 root vs user and `sudo` (`658a09f`) · C23 spectate as top (`cf991a5`) · C24 the `fork()` shotgun (`88aeb92`) · C25 the `grep` seeker (`23dd69b`) · C26 the `rm -rf` cannon (`7a7c042`) · C27 `cron` mines (`eac8a86`) · C27b daemons fight back: AI with readable tells, solo health, difficulty and practice, the host's daemons in a match (`3ae7dbe`, `7cbd5b2`, `0e6181c`, `a311cd6`, `51e1376`) · C28 `ping` sonar (`f7f13ed`, `f05eeb8`) · C29 `chmod 000`, the freeze ray, and the strip's second bank (`2ae2c88`, `1c0f53d`, `0728187`) · C30 `pipe \|`, the chain beam (`022762f`, `1fb849e`, `a10b20e`) · C31 `/dev/null`, the black hole (`6fb9f28`, `c96e2c8`; the loopback fix-it `1062d95`) · C32 SIGHUP, the confusion grenade (`517ddd6`, `9b8b766`) · C33 unlocks, mods and light skins: kits, the progress save, the loadout screen, protocol 19 (`4af5320`, `77293ba`) | ✅ Done |
| Art pass | A1 weapon viewmodels (`aa3ca98`) · A2 enemy art: daemons, a drone swarm, the derezz (`0d7cbdb`) · A3 arena: depth, props, signs, skyline, sky and fog (`1590eb0`) · A2b enemy redo: articulated creatures, hit reactions, shard deaths (`766cec6`) · A4 lighting, post and particles: AgX, glow, SSAO and SSR, the grade, warm signs, GPU particles, graphics presets (`c72cc0c`, `ab05c07`) · A5 monster redo: solid armoured daemons lit only at their seams, one colour a type, no two alike, rare elites, the swarm's core (`8c0511f`, `db57bc3`); A1 to A4 right after C27 and before C28, so the site launches with real captures, A5 after C28 | ✅ Done: A1, A2, A3, A2b, A4 and A5 |
| ICE and ICEbreakers | A new enemy class, the system defending itself (a community prompt by Tim Provencio, [@TimProvencio](https://x.com/TimProvencio)) · I1 white ICE and hunter ICE: walls, jam and HUD fields, the adaptive hunter, protocol 12 (`1b8fdec`) · I2 ICEbreakers: brute, exploit, cloak and decoy, pickups, your AI's pick, protocol 13 (`d87527a`) · I3 Black ICE: rare, unkillable by weapons, the flatline, exploit and brute its only kill, protocol 14 (`bf42ef9`) | ✅ Done: I1, I2 and I3 |
| Website, teaser and docs | T1 the teaser's footage: real in-game clips on demo data, rendered with Movie Maker by `tools/trailer_capture.sh` ([docs/TRAILER.md](docs/TRAILER.md); `b2392e8`, `f17ae86`, `bb82508`, `1087887`) · the 70 second edit and its soundtrack (the producer's) for playsigkill.com · D1 the PRD rewritten as the entire, current PRD (v0.3), this README's "Where we are", three community credits (`e1e658d`, `e79b9e5`) | 🟡 T1 footage and D1 done; the edit, the music and the site are the producer's |
| M5 Your machine is the world | Filesystem maps, process enemies, theme levels, keybind gunplay, voice commands, packet tracer arena, split-screen co-op · C43 Audit Trail visor · C44 in-game credits roll (CREDITS.md itself is already in the repo) | ⬜ Planned |
| M6 Story campaign | C34 story bible, locked by Fred on 2026-10-30 ([docs/STORY.md](docs/STORY.md), `a80a229`, `431e41a`) · C38 the opener's first 35 seconds on demo data: the fake crash, the fake terminal, the typed lines (`bda0ecc`, `ee41bbd`, `0f94ca7`) · C39 the opener's real-data reader, opt-in and read-only, and wide characters (`8c74319`, `a349d1a`) · C40 the shrink-away reveal and the fall through your directory tree as a city (`e6d0b73`, `2d4466e`) · C41 the AI link and the copy of you named `~`: the HUD alive, your AI live or the scripted guide, the copy walking out of the pit wearing your user name (`7106cec`, `14c7c2b`, `59095b3`) · C42 the `kill -9` forge, the first kill, the title slam, the score, the skip logic and the first launch, and the daemons' voices (`77254c0`, `e04dffe`, `e31bd68`, `ffa5eaa`) · then C35 mission framework · C36 cyberpunk ruins art kit · C37 first mission, `login` (player-facing first: the opener before the missions) | 🟡 C34 locked; the opener done (C38 to C42); C35 next, then C36 and C37, Planned |

Before M0 came the scaffold (`d086489`), and the decision that the player's AI is the Omarchy default agent landed as its own docs commit (`43b1f74`).

**Pre-alpha drop, 0.33.0-prealpha (build 33, after C33): ✅ released 2026-10-30** as a GitHub pre-release, [v0.33.0-prealpha](https://github.com/nixfred/sigkill/releases/tag/v0.33.0-prealpha) (tag on `655ff4b`, assets built from `341c182`): the version in the corners and the window title, the "Linux x86_64" export preset and `tools/export_linux.sh`, the user-local install in `packaging/linux/`, the [release notes](docs/RELEASE_NOTES-0.33.0-prealpha.md), the clean install verified on a second Omarchy machine ([docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)). 1.0 is further on: M5 and M6 above.

## Credits and community prompts

SIGKILL is built in public, and the full list of who made what lives in [`CREDITS.md`](CREDITS.md).

<p align="center">
  <img src="docs/media/credits-mockup.jpg" alt="A top-style process table on a code-rain background, listing the creator, the builder, the producer and a community contributor as processes, with a kill -9 prompt below"><br>
  <em>Mockup of the in-game credits roll, not in-game footage.</em>
</p>

**Send a prompt.** Anyone can reply to [@NixFred](https://x.com/NixFred) on X with a prompt for the game. If a prompt makes it in, its author is credited in [`CREDITS.md`](CREDITS.md) and in the in-game credits roll, and the feature it became carries a small in-game tag with their handle. Nobody is credited without their own public reply.

**How a public prompt reaches the build.** Every public prompt is reviewed against the [safety rules](#safety-and-privacy) and rewritten into a chunk brief before any of it reaches the build. Raw public text is never passed in.

**The first community feature.** Albert ([@QuantaCortex](https://x.com/QuantaCortex)) pitched the Audit Trail visor: trace every enemy back to its parent process, and sever the spawn chain to change the arena. ⬜ Planned (C43); see [Your machine is the world](#your-machine-is-the-world).

**The second community feature.** Tim Provencio ([@TimProvencio](https://x.com/TimProvencio)) pitched ICE, William Gibson's intrusion countermeasure electronics, as a new enemy class: the system defending itself against you, the intruder. White ICE walls off corridors, jams weapons and corrupts the HUD; hunter ICE tracks you and adapts to the weapon you use most; Black ICE is rare and frightening, never just a bigger health bar. Against it you carry ICEbreakers, one-use programs beside your weapons (brute, exploit, cloak, decoy), and your AI picks which to load from the round's numbers. ✅ I1 built: white ICE (walls that seal a doorway and a corridor, a jam field and a HUD-corruption field) and hunter ICE (it hunts by sight and adapts to your most-used weapon), its HUD tagged "ICE design: @TimProvencio"; see [Built: ICE](#built-ice-white-and-hunter-i1). ✅ I2 built: the four ICEbreakers, pickups and your AI's pick; see [Built: ICEbreakers](#built-icebreakers-i2). ✅ I3 built: Black ICE, rare and unkillable by weapons, its arrival killing the lights, the hum and your AI's link, its touch a flatline; see [Built: Black ICE](#built-black-ice-i3).

**Three more, for after 1.0.** These came in after the 1.0 lock (2026-10-29), so they are post-1.0 ideas unless Fred pulls one in. Every one is fully simulated, and none of them reads or touches anything real on your machine.

- **The third: Carlos Granier ([@cgranier](https://x.com/cgranier)).** ⬜ Planned, post-1.0.
  - `man sigkill`, a training level where each weapon unlocks once you read its man page in the world. Its EXAMPLES section is a 20-second drill, and `--help` replays the drill.
  - The OOM killer, a boss that hunts whatever uses the most in-game memory: often you, carrying a big weapon.
  - A `/tmp` arena that wipes itself every round, and a `/proc` arena whose walls are in-game counters you can shoot. Both are invented spaces, not your real folders.
  - Uptime as the solo score, with a kernel-panic screen that shows your stats as a stack trace.
  - Music driven by the in-game load average.
- **The fourth: Jeremy ([@ocdjeremy](https://x.com/ocdjeremy)).** ⬜ Planned, post-1.0.
  - An htop-style overlay in the visor that shows the game's own daemons, ICE and players, never your real processes.
  - Stepped zoom on the scoped weapons, held or toggled.
  - Real hitboxes, so headshots and centre mass hit hardest and nobody gets one-shot in the toe.
  - Every weapon balanced on its own strengths.
  - VR, as a stretch.
- **The fifth: MindGameLabs ([@MindGamesLabs](https://x.com/MindGamesLabs)).** ⬜ Planned, post-1.0.
  - A sudo grenade that will not throw until you type a password, and goes off in your hand after three wrong tries.
  - The password is an in-game one shown on screen, never yours. Nothing you type is kept, sent or checked against your system.

**Names the skins borrow.** Two light skins (C33) take their names and colours from open terminal themes, Dracula and Catppuccin, with thanks; others only nod by name to old machines and tools (green phosphor, CGA, the Commodore 64, the VT220). A skin is two colours and a line of text: nothing of theirs is bundled. See [`CREDITS.md`](CREDITS.md).

**Colours the opener's terminal borrows.** The opener's six demo palettes (C38) take their colours from open terminal themes Omarchy ships, with thanks: Tokyo Night (the default), Catppuccin Mocha and Latte, Gruvbox Material, Nord and Everforest. Colours only: nothing of theirs is bundled. See [`CREDITS.md`](CREDITS.md).

**The pit's maze.** The node_modules pit's walls (C40) are drawn in the classic "10 PRINT" pattern, a diagonal one way or the other in each cell, after the one-line Commodore 64 BASIC program that made it famous; the game's own shader draws it.

**The credits roll.** A live `top`-style process table on the Tron grid. Every contributor is a process, everyone above included: their handle as the USER, their idea as the COMMAND, the CPU column climbing as their row types in with code rain. Fred is PID 1. It ends with your own kill -9 on the credits process, which derezzes the whole table into voxels. ⬜ Planned (C44).

## Screenshots

Real in-game captures, demo data only (A1, A2b, A3, A4, C27b, C28, A5, I1, I2, I3, C29, C30, C31, C32, C33, C38, C39, C40 and C41). The game drew them itself on a real GPU (Vulkan) into a private virtual display, at 1920x1080, through `tools/capture_shots.sh`: never on a desktop, and every number and name on screen is demo data. They are scripted stills, not a playtest. Every still shot before A5 (the C27b and C28 ones too) shows the daemons as they were then, every one before C29 the strip's single slot row, every one before C30 bank 2 without the pipe, and every one before C31 without /dev/null.

<p align="center">
  <img src="docs/media/a4-overview.png" alt="In-game overview from above after A4: the walled arena on its plinth, warm orange signs on the walls, the red swarm and the magenta-edged creatures glowing, gloss deck plates, dark megastructures with lit teal windows rising out of a teal haze all round"><br>
  <em>The arena from above, lit and finished (A4): warm signs against the teal, the daemons in hostile red and magenta.</em>
</p>

**The opener's first 35 seconds (C38).** From Esc, Play the opener, on demo data: `user@workstation`, invented folders, a fixed uptime and a fixed late hour. Nothing on these stills was read from a machine.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c38-crash.png" alt="The arena frozen mid-frame and coming apart: horizontal slices slipped sideways, long runs of blocks stuck on flat colours, rows smeared, the colour channels split along every edge and a few bands corrupted toward magenta, the HUD's text torn with it, two daemons ahead on the grid"><br><sub>The fake crash, 2.2 s in: the game's own frozen frame coming apart.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c38-prompt.png" alt="A dark blue-grey terminal window filling the screen inside thin gaps, a pale blue border round it; top left the prompt user@workstation in bold green, a colon, a bold blue tilde and a dollar sign, a solid block cursor after it, and nothing else"><br><sub>The prompt that typed itself, in bash's colours, in a Tokyo-Night-like palette.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c38-terminal.png" alt="The same terminal: user@workstation:~$ thanks for running me. on the first line, you never read the install script, did you? on the second, the block cursor after it"><br><sub>"thanks for running me." / "you never read the install script, did you?"</sub></td>
    <td align="center" width="50%"><img src="docs/media/c38-uptime.png" alt="The terminal scrolled: a column of folder names in blue, ~/.local, ~/Documents, ~/code/homelab, ~/code/website-redesign/node_modules, ~/taxes-2024, ~/resume-final-v3 and more down to ~/scratch; under them up 3 days, 07:42:49 in amber; then I've been in here since you booted. and you were still up at 03:12 last night. so was I. with the cursor after it"><br><sub>The folder scroll, the uptime ticking, and the late-night line.</sub></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/c38-palettes.png" alt="Six copies of the same final terminal screen in a grid of three by two, each in a different palette: Tokyo-Night-like blue-grey, Catppuccin Mocha's deep violet-grey, Gruvbox Material's warm brown-grey, Nord's slate, Everforest's green-grey, and Catppuccin Latte light with dark text" width="100%"><br>
  <em>The same screen in each of the six demo palettes: night (the default), mocha, ember, frost, forest and latte, as C38 drew them (C39 has since drawn latte's green and yellow darker, so they read; see below).</em>
</p>

<p align="center">
  <img src="docs/media/c38-960.png" alt="The final terminal screen in a 960 by 540 window, the same thirty rows at a 14 pixel font, every line readable"><br>
  <em>The same screen in a 960x540 window: the same 30 rows, the text scaled with the window.</em>
</p>

**The opener's switch and wide names (C39).** The opener data switch in Settings, and the terminal with folder names in other scripts, laid out in cells as a terminal lays them out. The names are invented for the capture (CJK, kana, an emoji, accents, Cyrillic, hangul and fullwidth letters): demo data, nothing read from a machine. The capture is a demo run, so the switch is off and says "this run: demo data".

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c39-settings.png" alt="The settings screen over the arena; in its right column, PRIVACY AND AI: AI on (demo), roast announcer off, real-machine data on with the note this run: demo data, and opener data off with the same note, then a dim line reading names, counts, times, theme, uptime; no contents"><br><em>Settings, Privacy and AI: "opener data", off unless you turn it on, and what it reads in one line.</em></td>
    <td align="center" width="50%"><img src="docs/media/c39-wide.png" alt="The fake terminal in the Tokyo-Night-like palette: the prompt user@workstation, thanks for running me., the install line, then a column of blue folder names: ~/写真, ~/写真/2024-京都, ~/音楽/お気に入り, ~/ゲーム, a gamepad emoji before games, café-recettes, Документы, 한글-노트, fullwidth letters spaced two cells apart, naïve-bayes, ~/code/日本語-site/node_modules, then the uptime in yellow and the block cursor"><br><em>Wide names: each CJK, kana, hangul or fullwidth character in two cells, the accents in one, the emoji scaled into its two.</em></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/c39-palettes.png" alt="Six copies of the finished terminal with the wide names, in a grid of three by two, one per demo palette; in the light latte one the prompt's green and the uptime's amber are darker than before so they read on the pale background"><br>
  <em>The six palettes as drawn now, every coloured line at 3:1 or more: latte's green and yellow pulled darker to get there, the rest as they were.</em>
</p>

<p align="center">
  <img src="docs/media/c39-wide-960.png" alt="The same wide-name terminal in a 960 by 540 window, the same thirty rows, every name readable"><br>
  <em>The wide names in a 960x540 window.</em>
</p>

**The shrink-away and the fall (C40).** From Esc, Play the opener, on demo data: the invented folders of the stills above are the towers, and the process in the pit is the demo's. Nothing on these stills was read from a machine.

<p align="center">
  <img src="docs/media/c40-sequence.png" alt="Eight frames of the move in a grid of four by two: the terminal shrunk to a glowing screen on a wall of dark screens; the screen a dot on a dark monolith; the monolith with a huge tilde-slash on it among lit towers with folder names; the look down a shaft of concentric rings of light to a red core; the drop past towers named Documents, Pictures, Videos and Music; deeper, towers named homelab, rust-playground and half-finished-game; deeper still, rings and grids; the landing at a glowing maze pit with node_modules over it"><br>
  <em>The whole move, 0:42 to 1:09: the window shrinks away, the machine opens out, the fall, the landing.</em>
</p>

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c40-ignore.png" alt="The terminal with every line typed and below them a fresh prompt, user@workstation:~$ in bash's colours, the block cursor after it"><br><sub>A fresh prompt: for 3 seconds it ignores whatever you type.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c40-shrink.png" alt="The same terminal a second into the camera's pull-back: a smaller screen with a glowing cyan bezel, set in a wall of large dark screens whose grey frames run off the edges"><br><sub>"you're in now." Then the window shrinks away: the camera pulls back.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c40-panel.png" alt="The screen now a small lit rectangle in the middle of a dark wall gridded with dozens of dark screens, its light spilling softly round it"><br><sub>One lit panel on a wall of dark ones.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c40-machine.png" alt="A tall dark monolith edged in blue, a huge glowing tilde-slash on it and the tiny lit screen at its middle; on both sides towers edged in blue with lit windows in blue, cyan and amber, named games/, backups/, scratch/, Documents/ and Downloads/; green code light falling in columns; a ceiling of circuit traces overhead"><br><sub>It was inside the machine all along: the home folder's monolith, your folders round it.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c40-edge.png" alt="Looking straight down a vast shaft: concentric rings of blue light stepping down and in, towers standing on each ring, green streams of code light converging, and at the centre a small red-white core"><br><sub>Over the edge: the tree stepping down to the pit, the hottest process at the bottom.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c40-drop.png" alt="Falling past the top terrace: towers on all sides with lit windows, names Documents/, Pictures/, Videos/ and Music/ at eye level, green code light streaking past, the terrace's ring of light below"><br><sub>The drop: the top-level folders' names going past.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c40-names.png" alt="Lower down, looking across the shaft: a slice of smaller towers on the next terrace named homelab/, rust-playground/ and half-finished-game/, a cable of light hanging to them from the rim above, rings of light below"><br><sub>code/'s folders, a level down, hung from its rim.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c40-deep.png" alt="Deeper still: dark towers with sparse windows on every side, floor grids and rings of light below, the walls reddening near the bottom"><br><sub>Deeper, the walls reddening toward the pit.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c40-pit.png" alt="Looking down at the pit: a ring of light round a round well whose walls are a glowing magenta maze, node_modules/ over it, a red-white core beating deep inside"><br><sub>The node_modules pit, the hottest process beating in it.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c40-landed.png" alt="Landed on the pit's rim at eye height: the pit's mouth ahead, its maze walls glowing magenta, node in red in its mouth, node_modules/ in large letters above, dark towers behind"><br><sub>Landed, facing the pit: where C41 goes on.</sub></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/c40-palettes.png" alt="The same moment of the fall six times in a grid of three by two, one per demo palette: the towers' edges, windows and code light tinted by each theme, the light latte one as dark as the rest with its blues the most saturated"><br>
  <em>The same moment of the fall in each demo palette: night, mocha, ember, frost, forest and latte. A light theme's machine is as dark as any.</em>
</p>

<p align="center">
  <img src="docs/media/c40-fall-960.png" alt="The fall at 960 by 540: the code folder's slice of towers with their names over them, the next terrace below"><br>
  <em>The fall in a 960x540 window.</em>
</p>

**Your AI's link and the copy of you (C41).** From Esc, Play the opener, on demo data: the demo's guide link gives its canned answer (shown live, as every capture does), nothing is called, and the copy wears the demo's user name.

<p align="center">
  <img src="docs/media/c41-sequence.png" alt="Six frames of the beat in a grid of three by two: the HUD's badge and panel coming alive over the pit as a teal beam rises from it; teal lines of signal climbing out of the pit; the answer marked live, a teal ring running out across the floor; the copy's red crown rising out of the pit; the copy stepping over the rim as a red ring runs out across the floor; the copy walking up, wearing the name user"><br>
  <em>The beat, 1:11 to 1:32: linking, the signal, the live answer, the copy rising, stepping over the rim, walking up.</em>
</p>

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c41-link.png" alt="The pit's rim, node_modules/ over it; a teal beam rising out of the pit's middle, teal lines climbing round it; top right the badge your AI: claude, linking; at the bottom the panel, Linking your agent.."><br><sub>"Linking your agent...": the HUD comes alive, the signal climbs out of the pit.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c41-live.png" alt="The same view, the teal lines flaring, a teal ring running across the floor toward the camera; the badge reads live, answered in 2.38 s; the panel your AI with a live mark and Got you typing"><br><sub>The answer lands: marked live, its latency on the badge, rings across the floor.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c41-rise.png" alt="The pit's rim with the copy's red hexagon crown and red-lit head rising out of the pit, the name user over it; the panel reads I've been stuck in here with them. They look like you."><br><sub>"They look like you." The copy comes up out of the pit.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c41-rim.png" alt="The copy, a tall dark armoured figure with a red-lit hexagon head inside a ring of six red bars, stepping over the pit's rim; a red ring running out across the floor"><br><sub>Over the rim: it forms out of cells, and the floor answers in red.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c41-walk.png" alt="The copy walking toward the camera across the floor, red hexagons glowing under its feet, the name user over its crown"><br><sub>Walking up, a hexagon of light at every step.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c41-copy.png" alt="The copy standing a few metres away: broad dark armour edged in teal, crimson seams at the waist, knees and elbows, a red heart on its breastplate, long arms with three claws, its head a dark hexagon with a red mirrored prompt, the red ring of six bars behind it, the name user over it"><br><sub>It stands in front of you, wearing your user name.</sub></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/c41-face.png" alt="Close on the copy's head: a dark pointy-top hexagon face plate with a red mirrored prompt on it, an underscore on the left and a less-than sign on the right, the ring of six red bars behind it, the name user above"><br>
  <em>Its face: the nixfred hexagon, dark, the prompt lit red and mirrored, <code>_&lt;</code>.</em>
</p>

<p align="center">
  <img src="docs/media/c41-copy-960.png" alt="The copy standing in front of the camera at 960 by 540, the badge and the panel fitting the smaller window"><br>
  <em>The copy in a 960x540 window.</em>
</p>

**The forge, the first kill and the title (C42).** The first launch as a player meets it, on demo data (its card answered no), then the opener's end: the demo's guide link gives its canned answer, nothing is called, and the kill feed names the demo's user.

<p align="center">
  <img src="docs/media/c42-sequence.png" alt="Nine frames in a grid of three by three: kill -9 typing itself in teal cells in front of the copy; the cells streaming into the player's hands where the rifle is printing; the rifle whole, its coils lit, a ring of teal running out from it; the copy, you won't. in crimson by its head, the reticle and the fire hint; the shot's blast of light into the copy's heart; the copy bursting into crimson and teal voxels; the voxels on the floor and the kill feed, SIGKILL sent by user, to user; the title slamming in, rings and sparks flying off the hexagon; the title held over a teal grid, SIGKILL under the hexagon"><br>
  <em>1:35 to 1:51: the forge, the dare, the shot, the derezz, the kill feed, the slam, the title.</em>
</p>

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-card.png" alt="The first-launch card over the dimmed arena: the brand's hexagon icon and SIGKILL // before the intro; an amber content note; the question, may the intro show your real user name and folder names; what else it covers and that nothing is saved, logged or sent; No: invented names highlighted in teal, Yes: my real names beside it"><br><sub>The first launch asks first. No is the default.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-paused.png" alt="The intro paused over the pit mid-forge: Resume intro, Skip intro focused, the Skip the intro next time switch, Esc: resume, Enter: skip, hold Space: skip; behind it the copy, and the cells streaming into the rifle"><br><sub>Esc pauses the intro: Skip intro is one key away.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-type.png" alt="kill -9 half typed in large glowing teal pixel letters in the air in front of the copy, its red hexagon head and crown behind"><br><sub><code>kill -9</code> types itself in the air, a letter on each eighth.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-stream.png" alt="The letters broken into white-hot cells streaming toward the bottom right, where the rifle is half printed, its back glowing in teal hex cells"><br><sub>The cells stream into your hands, and the rifle prints itself.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-forged.png" alt="The rifle whole in the player's hands, its four coils lit as white-blue rings, a large ring of teal running out from it, the copy standing ahead"><br><sub>Forged on the drop, its four coils lit.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-dare.png" alt="The copy standing ahead, arms spread, you won't. in crimson in the air by its head; a small reticle in the middle and [left mouse] kill -9 under it"><br><sub>"you won't." Your move.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-shot.png" alt="A blast of white light from the rifle's muzzle into the copy's chest, the copy still lit red behind it, the rifle kicking, the picture split into red, green and blue and torn in bands"><br><sub>The shot: the rail's light burning into its heart.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-derezz.png" alt="The copy bursting into a storm of crimson, teal and white voxels and its own armour plates, over the pit's rim"><br><sub>The derezz: its armour and its memory, flung apart.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-feed.png" alt="Voxels scattered across the floor; at the bottom right the kill feed, SIGKILL sent by user, and under it, to user"><br><sub>The kill feed, in the game's own words.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-whisper.png" alt="The emptied floor where the copy stood, one of 6666 spaced out dim in the middle of the screen, the kill feed still at the bottom right"><br><sub>The whisper: "one of 6666".</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c42-slam.png" alt="The nixfred hexagon with its white prompt slamming in out of the dark, a teal burst of light from it, rings and sparks flying off, its colours split"><br><sub>Black, then the slam, on the downbeat.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c42-title.png" alt="The title: the nixfred hexagon with its white prompt, SIGKILL in large mint letters under it, a teal grid floor racing toward the camera, a streak of teal light through the hexagon"><br><sub>SIGKILL, on the brand's own icon.</sub></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/c42-title-960.png" alt="The title at 960 by 540: the hexagon, SIGKILL under it, the grid floor"><br>
  <em>The title in a 960x540 window.</em>
</p>

**Unlocks, mods and light skins (C33).** Every weapon's two Tron light skins and its mod, earned by playing and worn from Esc, Loadout. The progress in these stills is demo data.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c33-loadout.png" alt="The loadout screen over the darkened arena: on the left the arsenal, 1 cannon 3/3 down to S4 SIGHUP 0/3, each name in its weapon's light; in the middle the terminal cannon's own model large on a black glass floor, turning over a dark plinth ringed in Dracula purple, its seams and trim purple, its muzzle glowing green; under it Terminal cannon, cannon: one line, one hit., skin Dracula, mod overclock; on the right the light skin cards stock teal, tty1 and Dracula (WEARING), each with two swatches, a name and a line of fiction, and the mod card overclock: + fire interval 0.16 > 0.13s, - damage 25 > 21, FITTED"><br><sub>The loadout screen: the cannon on its turntable in Dracula's purple and green, its overclock fitted.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c33-locked.png" alt="The loadout screen on SIGHUP: the telephone handset model turning over a plinth ringed in pale cyan, lit in dial tone's light while the pointer is over the dial tone card; the cards stock carrier (WEARING), dial tone and 300 baud each LOCKED  0 / 1 and 0 / 5 kills by a confused daemon's lash with an empty bar, and the mod card wideband: + reach 7 > 9 m, - wander 4 > 2.8s, LOCKED  4 / 6 daemons hung up [######....]"><br><sub>A locked skin under the pointer lights the model at once, and its card says how it is earned.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c33-skins.png" alt="Six weapons on the arena floor in an arc, each over a dark plinth ringed in its own light, its name under it: the cannon in tty1's phosphor green, the kill -9 rail in blacklight purple, SIGTERM in Catppuccin pink, the rm -rf cannon in --preserve-root white, the SIGHUP handset in dial tone cyan and the fork bomb in exponential chartreuse"><br><sub>Earned skins side by side: tty1, blacklight, Catppuccin, --preserve-root, dial tone, exponential.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c33-unlock.png" alt="In-game first-person view: SIGTERM held in its ^C cyan skin, a shot bursting on rogue.d in pink and white sparks, the zombie beside it; near the top a dark strip with pink corner brackets: UNLOCKED, Catppuccin in mauve, and a light skin for SIGTERM   Esc > Loadout to wear it"><br><sub>The toast the moment one is earned: "UNLOCKED: Catppuccin".</sub></td>
  </tr>
</table>

**SIGHUP, the confusion grenade (C32).** Weapon 13, bank 2's fourth (Shift+4): throw it and the line hangs up; every daemon it reaches reloads its config and wanders confused.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c32-hup.png" alt="In-game first-person view of a SIGHUP burst mid-wave among four daemons: a bright green oscilloscope trace wrapped round the expanding ring on the floor, fainter ghost traces and green static inside it, thin green interference lines standing on its front; over each daemon SIGHUP: reloading config with a progress bar, over the burst $ kill -HUP and NO CARRIER  4 reloading, the callout kill -HUP  NO CARRIER in amber; the telephone handset viewmodel bottom right with green rings off its earpiece"><br><sub>A burst mid-wave: the carrier trace running out, every daemon it reached stalled, "reloading config".</sub></td>
    <td align="center" width="50%"><img src="docs/media/c32-strip.png" alt="The weapon strip, bottom right, cut from the same frame and shown three times the size: Shift+ 1 2 3(2) [4 SIGHUP] on the top row, the bank 1 row 1 2 3 4(2) 5 6 7 8 9 dimmed under it, then SIGHUP  2 left, kill -9 [..........], F SIGSTOP [##########] and V vision [##########]"><br><sub>The strip with SIGHUP drawn: bank 2's fourth, /dev/null's charges beside it.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c32-confused.png" alt="In-game first-person view of a crowd of fighting daemons confused: green question marks over rogue.d, the zombie, the defunct zombie and the runaway, their seams flecked green; rogue.d lunging at the zombie beside it, the runaway diving into the knot in a burst of light"><br><sub>A confused crowd turning on itself: "?" over each, rogue.d's lash at the zombie mid-strike.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c32-player.png" alt="In-game first-person view of a caught player's own screen: rows of green static tearing across, green scanlines at the screen's edges, the crosshair drifted off the middle with a faint dot at the true middle, SIGHUP: hung up  NO CARRIER over it, and top right your AI: HUNG UP and SIGHUP the line hung up, redialling"><br><sub>A caught player's own screen: the glitch, the drifting crosshair, the AI link hung up. Every control still works.</sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c32-ice.png" alt="In-game first-person view of a burst by the gate of white ICE: the green carrier trace running out round the low SUDO crate, the blue hunter ICE with SIGHUP: reloading config over it, the jam node beyond reloading too, the gate's glass grid untouched"><br><sub>Against ICE: the hunter confused (and forgetting what it learned), a node reloading, the gate untouched.</sub></td>
    <td align="center" width="50%"><img src="docs/media/c32-black.png" alt="In-game first-person view of a burst beside Black ICE in the darkened arena: the green carrier trace and its ghosts all over the floor, Black ICE's black spikes unmoved; over it $ kill -HUP, NO CARRIER  0 reloading and SIGHUP: ignored (nohup); top centre BLACK ICE  seals 2/2"><br><sub>Black ICE runs under nohup: "SIGHUP: ignored (nohup)".</sub></td>
  </tr>
</table>

**/dev/null, the black hole (C31).** Weapon 12, bank 2's third (Shift+3): throw it and a singularity opens, dragging everything in reach into its core.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c31-hole.png" alt="In-game first-person view of a /dev/null hole open among four daemons: a sphere of pure black with a white-hot photon ring at the centre, the arena's walls and signs bent round it by its lensing, a plum glow and a tilted ring of plum light round it; rogue.d and the second zombie on the left and the runaway and the zombie on the right stretched long toward it and tipped into the pull, plum spark trails behind them; a dark well on the floor with a ring of dashes at its edge; over the core its tag $ cat * > /dev/null, 4 held  0 discarded; the plum cradle of the device in the player's hand"><br><em>A hole mid-pull: four daemons stretched toward the core, the arena bent round it.</em></td>
    <td align="center" width="50%"><img src="docs/media/c31-strip.png" alt="The weapon strip, bottom right, cut from the same frame and shown three times the size: Shift+ 1 2 [3 /dev/null] on the top row, the bank 1 row 1 2 3 4(2) 5 6 7 8 9 dimmed under it, then /dev/null  2 left, kill -9 [..........], F SIGSTOP [##########] and V vision [##########]"><br><em>The strip: /dev/null in bank 2, its two charges.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c31-implosion.png" alt="In-game first-person view of the implosion: a white-hot point of light where the core was, a plum shock ring flung out flat over the floor and an upright one round the point, streaks of debris drawn in, and > /dev/null written over it in plum"><br><em>The end: the implosion, "> /dev/null".</em></td>
    <td align="center" width="50%"><img src="docs/media/c31-knot.png" alt="In-game first-person view of the knot a hole drew together: the black core with its photon ring at the right, four daemons dragged in round it, the pipe's brass chain arcing from the player's pipe through them; under the crosshair $ defunct | rogue.d | runaway | zombie, 4 links, and over the core the hole's tag $ cat * > /dev/null, 4 held  0 discarded"><br><em>The knot it draws, chained by pipe |.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c31-ice.png" alt="In-game first-person view of a hole beside the gate of white ICE: the blue hunter ICE stretched long toward the black core, the gate's glass grid behind it unmoved, the low SUDO crate in front; over the core its tag $ cat * > /dev/null, 2 held  0 discarded"><br><em>ICE: the hunter pulled in, the gate never moved.</em></td>
    <td align="center" width="50%"><img src="docs/media/c31-black.png" alt="In-game first-person view of a hole open beside Black ICE in the darkened arena: the black spikes of Black ICE unmoved beside the plum-ringed core; over the core its tag $ cat * > /dev/null, 0 held  0 discarded, /dev/null: device busy; top centre BLACK ICE  seals 2/2  8 m"><br><em>Black ICE never moves: "/dev/null: device busy".</em></td>
  </tr>
</table>

**pipe |, the chain beam (C30).** Weapon 11, bank 2's second (Shift+2): one click and the stream arcs from target to target, written out as the command line it was.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c30-chain.png" alt="In-game first-person view of one chain across four daemons in the arena: braided, jagged arcs of brass light run from the pipe in the player's hand into rogue.d, then on to the zombie on the right, the runaway and the second zombie on the left, bright bars of data crossing each arc, blooms where they land; under the crosshair $ rogue.d | zombie | runaway | defunct, 4 links"><br><em>One chain across four daemons, written out under the crosshair.</em></td>
    <td align="center" width="50%"><img src="docs/media/c30-strip.png" alt="The weapon strip, bottom right, cut from the same frame and shown three times the size: Shift+ 1 [2 pipe] on the top row, the bank 1 row 1 2 3 4(2) 5 6 7 8 9 dimmed under it, then pipe   buffer 8K/64K, buffer [#.........] in brass, F SIGSTOP [##########] and V vision [##########]"><br><em>The strip: the pipe in bank 2, its buffer after one chain.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c30-frozen.png" alt="In-game first-person view of a chain through a frozen daemon: the zombie on the left shattering in a pale storm of frost and voxels round a ring of light, the stream running from rogue.d in the middle through it and on to the runaway's drones on the right, bars of data on the arcs; under the crosshair $ rogue.d | zombie(000) | runaway, 3 links"><br><em>Through the frozen: chmod 000's zombie conducts the stream on, and shatters.</em></td>
    <td align="center" width="50%"><img src="docs/media/c30-wall.png" alt="In-game first-person view of rogue.d close in front of the low wall, the stream striking it, and the zombie behind the wall in reach, untouched; under the crosshair $ rogue.d, 1 link: a wall broke the chain"><br><em>Walls break a chain: the zombie behind the low wall is never arced to.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c30-ice.png" alt="In-game first-person view of a chain from a zombie to hunter ICE, frozen, and on to the jam node of white ICE: brass arcs between the zombie in front and the blue crystal pieces behind it; under the crosshair $ defunct | hunter ICE(000) | white ICE: jam, 3 links, and top right HUNTER ADAPTED: pipe -6%"><br><em>ICE: the frozen hunter and a node as links (the hunter learns the pipe).</em></td>
    <td align="center" width="50%"><img src="docs/media/c30-black.png" alt="In-game first-person view of Black ICE 6 m away in the darkened arena, the stream striking its black spikes; under the crosshair pipe: broken pipe, Black ICE takes nothing, and top centre BLACK ICE   seals 2/2   6 m"><br><em>Black ICE refuses it: "pipe: broken pipe".</em></td>
  </tr>
</table>

**chmod 000, the freeze ray (C29).** Weapon 10, on the strip's second bank (Shift+1): hold fire and a cold beam strips what it touches of its permissions.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c29-freeze.png" alt="In-game first-person view of rogue.d 5 m away caught in the middle of its tell and frozen: its whole body sealed in a shell of cracked rose-opal ice, the dark armour and its crimson visor and seams glowing through the ice, chips of frost bursting off it; a thin bright beam runs from the frost-opal emitter in the player's hand to its chest; under the crosshair PERMISSION DENIED   rogue.d   2.9s; bottom right the strip's two rows, Shift+ [1 chmod] over a dimmed 1 2 3 4(2) 5 6 7 8 9, and chmod   coolant 95%"><br><em>The beam freezing rogue.d mid-tell: its attack called off, sealed in ice, "PERMISSION DENIED".</em></td>
    <td align="center" width="50%"><img src="docs/media/c29-strip.png" alt="The weapon strip, bottom right, cut from the same frame and shown three times the size: Shift+ [1 chmod] lit on the top row, the bank 1 row 1 2 3 4(2) 5 6 7 8 9 dimmed under it, then chmod   coolant 95%, coolant [##########] in rose, F SIGSTOP [##########] and V vision [##########]"><br><em>The strip's two rows: bank 2 on Shift over bank 1, the active bank lit, the coolant under them.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c29-chill.png" alt="In-game first-person view of a zombie 5 m away under the beam, half frozen: frost creeping up its legs, a tag over it chmod 000   50%, and under the crosshair chmod 000   zombie [#####.....]"><br><em>The meter filling: half way, the frost creeping up from the feet.</em></td>
    <td align="center" width="50%"><img src="docs/media/c29-shatter.png" alt="In-game first-person view of rogue.d shattering under the terminal cannon's shot while frozen: a storm of pale frost shards and voxels bursting from where it stood, its blades flying apart, First process down. called out over the crosshair"><br><em>Then hit it: a frozen daemon's kill is a shatter.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c29-hunter.png" alt="In-game first-person view of hunter ICE 9 m away frozen in mid-air under the beam, its hull and shields sealed in rose-opal ice, a tag over it PERMISSION DENIED   ---------- 000   2.2s, and under the crosshair PERMISSION DENIED   hunter ICE   2.1s"><br><em>The hunter frozen like a daemon, its lance quiet.</em></td>
    <td align="center" width="50%"><img src="docs/media/c29-black.png" alt="In-game first-person view of Black ICE 6 m away in the darkened arena, its black spikes traced with faint rose cracks of frost; a tag over it chmod: Operation not permitted   slowed -40%, under the crosshair chmod: Operation not permitted   Black ICE -40%, the beam running from the emitter into its core, and top centre BLACK ICE   seals 2/2   6 m"><br><em>Black ICE only slowed: "Operation not permitted", 40% at most, its seals and its touch untouched.</em></td>
  </tr>
</table>

**Black ICE (I3).** The machine's last line of defence: the lights die, the hum drops out, your AI's link is cut, and a black sun of ICE comes for you.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i3-black-ice.png" alt="In-game first-person view of Black ICE arriving 7 m away in the darkened arena: a huge black sun of crystal spikes on spike legs, a dim cold core, two rings of cold light crossing round it; over it the warning B L A C K   I C E, the machine's last defence: weapons only flash it, its touch flatlines, it forms in 0.6 s   7 m away, and a tag [ BLACK ICE 7 m ]; top right the guide's badge reads your AI: LINK CUT over NO CARRIER   Black ICE on the line; the arena's strips and signs dimmed to a tenth"><br><em>Its arrival: the arena's lights down to a tenth, the warning up, the guide's link cut, Black ICE forming.</em></td>
    <td align="center" width="50%"><img src="docs/media/i3-combo.png" alt="In-game first-person view close to Black ICE, its black spikes and legs filling the frame: small ultraviolet diamonds mark its seals and heart, one seal ring dark, the other lit, a few ultraviolet streaks of the brute's charge fading; SEAL BROKEN   1 left called out over the crosshair, EXPLOIT 5.1s under it, and top centre BLACK ICE   seals 1/2   5 m   mends in 11 s over the scripted guide's line"><br><em>The combo: exploit's marks on its seals, then a brute while exploit runs: a seal broken, it reels back.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i3-decoy.png" alt="In-game first-person view of Black ICE 7 m away standing over an ultraviolet decoy effigy, its spike legs round it, exploit's marks on its seals; top centre BLACK ICE   seals 1/2   7 m   mends in 9 s and the scripted guide's line; the player off to the side, untouched"><br><em>The escape: a decoy pulls it off you and holds it while it calls.</em></td>
    <td align="center" width="50%"><img src="docs/media/i3-flatline.png" alt="In-game view of the break's summary after a flatline alone: the screen darkened, a red-bordered panel headed FLATLINED by Black ICE   RUN OVER   round 1 in 11 s over the round's numbers and the scripted guide's pick, and top left FLATLINED by Black ICE   the run is over"><br><em>Touch it and you flatline: alone, the run is over.</em></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/i3-lineup.png" alt="In-game line-up in the lit arena: three Black ICE side by side, each a black sun of crystal spikes on spike legs round a dim core, each with its own spikes and legs"><br>
  <em>No two alike: three Black ICE from other seeds.</em>
</p>

**ICEbreakers (I2).** What you carry against ICE: one-use programs in their own ultraviolet, the readout bottom left.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i2-breakers.png" alt="In-game first-person view down the west corridor at the white ICE wall, with exploit and cloak running: small ultraviolet diamonds pulse over every seam of the wall (its lock, rings and joints) and over the knees and claws of a zombie at the corridor's side; under the crosshair the lines EXPLOIT 5.6s and CLOAKED 4.2s firing ends it; the screen's corners washed ultraviolet; bottom left the readout exploit run, U BRUTE 1, Y [b1] e0 c0 d1 over the user$ badge"><br><em>exploit and cloak at once: every weak seam marked in ultraviolet (the wall's and a zombie's), the effect lines under the crosshair, the readout bottom left.</em></td>
    <td align="center" width="50%"><img src="docs/media/i2-decoy.png" alt="In-game first-person view from the side of the room: hunter ICE on the left, its cobalt shields round its bright heart, firing its lance, a bar of cobalt light, across into a decoy on the right, an ultraviolet effigy on a glowing plinth tagged decoy, flashing white where the lance strikes; the player stands off to the side untouched, ROUND 2 top left"><br><em>The escape: the hunter's lance goes into the decoy the player threw, not into the player watching from the side.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i2-brute.png" alt="In-game first-person view at the moment a brute charge breaks the white ICE wall up close: the wall bursting into glacier-blue crystal panes and voxels, ultraviolet streaks radiating from the charge, the readout bottom left saying brute run"><br><em>brute up close: one charge and the whole wall shatters.</em></td>
    <td align="center" width="50%"><img src="docs/media/i2-lineup.png" alt="In-game line-up: four breaker pickups in a row, each a split ultraviolet crystal hovering over a lit plinth with its emblem (a ram of blades, a lens, a folded hood, twin shards) and its tag brute, exploit, cloak, decoy, a thin beam standing from each; in front a decoy, a faceless effigy with torso plates, shoulder panes and a head of light, rings of light rolling out over the floor"><br><em>The four pickups and a decoy, each built from its own seed.</em></td>
  </tr>
</table>

**ICE (I1).** The system defending itself: white ICE seals the way and throws its fields, hunter ICE tracks you down and learns your favourite weapon.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i1-white-ice.png" alt="In-game view from inside the west corridor: a wall of white ICE sealing its far end, faceted dark crystal panes in a lattice of glacier-blue light, fracture lines glowing across the panes, one pane broken out showing the cracked backing, a lock of light at its heart, crystal spikes along its top, the terminal cannon's beam striking it"><br><em>White ICE sealing the west corridor, mid-crack: panes fracturing, one broken out, the cannon's beam striking.</em></td>
    <td align="center" width="50%"><img src="docs/media/i1-hunter.png" alt="In-game first-person view: hunter ICE hovering 5 m away, a cobalt crystal hunter whose four faceted shields have closed into an iris round a bright cobalt heart, a thick cobalt trace locked from it onto the player, the HUD top right reading HUNTER ADAPTED: cannon -34% over the tag ICE design: @TimProvencio, ROUND 2 top left"><br><em>Hunter ICE mid-tell, its trace on you, adapted to your cannon: the HUD says so and its shields have shifted toward teal.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/i1-field.png" alt="Overhead in-game view: the jam node before the sealed gate of the room, a dome of glacier lattice light round it at the field's reach, mid-tell"><br><em>The jam node's tell: its dome lights at exactly the field's reach before it fires. Step out and nothing lands.</em></td>
    <td align="center" width="50%"><img src="docs/media/i1-corrupted.png" alt="In-game first-person view of the HUD node, its antennas lit, with the HUD corrupted: glacier glyph noise covering the status line top left, the weapon strip bottom right and the sudo badge bottom left, the notice HUD CORRUPTED BY ICE 2.9 s, the health line still readable"><br><em>The HUD node's field: parts of the HUD scrambled for 4 s, never your health.</em></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/i1-lineup.png" alt="In-game line-up: three cobalt crystal hunters of different builds hovering at the back, and in front two jam nodes with their crossed rings and two HUD nodes with their lit antennas, each a different build" width="100%"><br>
  <em>No two alike: three hunters, two jam nodes and two HUD nodes, each built from its own seed.</em>
</p>

**The daemons, armoured (A5).** Solid dark bodies lit only at their seams, one colour a type, no two alike. The A2b stills below are the before.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a5-rogue.png" alt="In-game view from beside the player: rogue.d, a black armoured mantis-scorpion, reared up tall in its tell with its scythes raised, a crimson visor slit flaring across its wedge of a head, crimson bands glowing at its knees and joints, its flat hexagonal thorax and thick dark legs catching the arena's light"><br><em>rogue.d in its tell: reared tall, scythes up, the visor flaring before the lunge.</em></td>
    <td align="center" width="50%"><img src="docs/media/a5-zombie.png" alt="In-game view: the zombie, a hunched black armoured hulk, its right forearm a cannon raised at the player with three amber charge bands lit and the muzzle glowing, amber bands at its knees, voxels with glowing amber edges peeling off its open left side and drifting away"><br><em>A zombie charging: its cannon raised, the bands lit one after another, voxels peeling off its open side.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a5-runaway.png" alt="In-game view over the platform: the runaway, a core drone of two dark armoured hex halves round a bright hot-magenta band, with small dark hex drones with blade wings and magenta lights flying round it, code rain on the walls behind"><br><em>The runaway: hex drones round their core drone.</em></td>
    <td align="center" width="50%"><img src="docs/media/a5-scatter.png" alt="In-game view of the runaway's death: a magenta column of light and a magenta ring on the platform, magenta voxels bursting, and whole drones flying off in every direction"><br><em>Its core killed: the swarm scatters, every drone flying off whole as it derezzes.</em></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/a5-lineup.png" alt="Three rows of in-game stills, one a type: three crimson mantis-scorpions of different sizes, tails and horns; three amber hulks with different spikes, bulk and cannons; three magenta swarms of different drone counts and core sizes" width="100%"><br>
  <em>No two alike: three of each type side by side, each built from its own seed.</em>
</p>

<p align="center">
  <img src="docs/media/a5-elite.png" alt="In-game view of the three elites in their tells: a big crimson mantis-scorpion reared up with a second pair of scythes and a crown of horns, an amber hulk with three back spikes raising its glowing cannon, and a magenta swarm of thirty drones pulled tight round a core drone with an armoured halo" width="100%"><br>
  <em>The elites, one spawn in twelve: bigger, extra parts, and they live through a cannon shot.</em>
</p>

**The daemons fight back (C27b).** Every attack comes after a tell you can read: rogue.d rearing up to lunge, the slash landing behind the red vignette, the death it ends in, a zombie's amber bolt in flight.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c27b-lunge.png" alt="In-game first-person view: the red crystal rogue daemon reared up over the player mid-lunge, its front legs and scythes raised high, the player's health on the combat line top left"><br><em>rogue.d mid-lunge: the rear-up is its tell, then the lunge and the slash.</em></td>
    <td align="center" width="50%"><img src="docs/media/c27b-bolt.png" alt="In-game first-person view: a bright amber crystal bolt flying at the player trailing sparks, the zombie that threw it glowing behind it under its &lt;defunct&gt; tag, warm signs on the walls"><br><em>A zombie's glitch bolt in flight: a real projectile, slow enough to sidestep.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c27b-hit.png" alt="In-game first-person view the moment rogue.d's slash lands: a red flash and a red vignette pressing in from the screen's edges, the health line dropped"><br><em>The slash lands: the red flash and the vignette, health down on the combat line.</em></td>
    <td align="center" width="50%"><img src="docs/media/c27b-down.png" alt="In-game first-person view just after the player is derezzed: glowing pink-white voxels bursting round the view, rogue.d still over the player, and the amber banner DEREZZED by rogue.d, respawn in a few seconds"><br><em>Derezzed by its next slash: the banner names the daemon, and the respawn comes after 3 s.</em></td>
  </tr>
</table>

**Ping (C28).** One sonar ring out across the floor, every daemon it reaches outlined through the walls with its tag, and a tell it catches broken.

<p align="center">
  <img src="docs/media/c28-ping.png" alt="In-game view from above and behind the player: a bright lime sonar ring sweeping out across the dark arena floor, concentric echo lines inside it and a low wall of light on its front, three daemons it has reached glowing lime-white with small tags over them" width="100%"><br>
  <em>A ping going out: the ring, its echo lines and its wall of light, three daemons outlined as it reaches them.</em>
</p>

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/c28-reveal.png" alt="In-game first-person view facing the west cover wall: rogue.d and a zombie on the far side drawn through the wall as bright lime outlines, tags over them with their names and distances, the ping model in hand and the strip showing its cooldown"><br><em>Behind the wall: outlined through it, tagged, out of every sight line.</em></td>
    <td align="center" width="50%"><img src="docs/media/c28-stagger.png" alt="In-game first-person view: rogue.d caught by a ping in the middle of its rear-up, cowering low and outlined in lime, its scythes flung out, the floor washed with the ring that just passed"><br><em>Caught mid-tell: the attack dropped, rogue.d staggering.</em></td>
  </tr>
</table>

**Lit and finished (A4).** A fight with the muzzle burst, the beam and the sparks; the west corridor with the zombie; the low preset beside the high one; and the two post effects on.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a4-fight.png" alt="In-game first-person view in the lair: the terminal cannon fires past the red crystal rogue daemon, a teal beam to the wall behind it with a burst of spark streaks where it lands, a pulse of streaks at the barrel, warm PID 1 and TTY0 signs on the lair's walls, red danger light on the floor"><br><em>A fight: the cannon's muzzle burst, beam and sparks beside the rogue daemon.</em></td>
    <td align="center" width="50%"><img src="docs/media/a4-corridor.png" alt="In-game view down the west corridor: the zombie in amber and hostile magenta, its reflection in the gloss deck plates, warm SIGSTOP, EXIT 137 and SUDO !! signs, the red swarm glowing at the right edge"><br><em>The west corridor: the zombie and its reflection in the deck, warm signs.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a4-low-high.png" alt="The same in-game view twice side by side: on the left the low preset, flat with no glow and no reflections; on the right the high preset, the swarm glowing red, the deck reflecting the strips, the skyline's slabs back"><br><em>Low (left) and high (right): the same view, low with no glow, shadows, SSAO, SSR or skyline slabs.</em></td>
    <td align="center" width="50%"><img src="docs/media/a4-post.png" alt="The in-game gameplay view with chromatic aberration pulling red and blue apart toward the screen's edges and faint CRT scanlines over it"><br><em>Chromatic aberration and CRT scanlines, both settings, off by default.</em></td>
  </tr>
</table>

**The arsenal, lit (A4).** All eight weapons in hand at the spawn, the lair ahead.

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-1-terminal-cannon.png" alt="The terminal cannon in hand, the lair ahead"><br><em>1 terminal cannon</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-2-sigterm.png" alt="SIGTERM in hand, the lair ahead"><br><em>2 SIGTERM</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-3-sigkill-rail.png" alt="The SIGKILL rail in hand, the lair ahead"><br><em>3 SIGKILL rail</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-4-fork-bomb.png" alt="The fork bomb in hand, the lair ahead"><br><em>4 fork bomb</em></td>
  </tr>
  <tr>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-5-fork-shotgun.png" alt="The fork() shotgun in hand, the lair ahead"><br><em>5 fork()</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-6-grep-seeker.png" alt="The grep seeker in hand, the lair ahead"><br><em>6 grep</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-7-rm-rf-cannon.png" alt="The rm -rf cannon in hand, the lair ahead"><br><em>7 rm -rf</em></td>
    <td align="center" width="25%"><img src="docs/media/a4-weapon-8-cron-mines.png" alt="cron mines in hand, the lair ahead"><br><em>8 cron</em></td>
  </tr>
</table>

**The arena (A3).** In play, daemons ahead and a weapon in hand; the lair's front; a corridor; and the void beyond the walls (the daemons as A2 drew them, before A2b, and the light before A4).

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a3-gameplay.png" alt="In-game first-person view firing the teal cannon at the red drone swarm on a stepped platform, terminal signs KILL -9, EXIT 137 and SUDO !! on the walls ahead, the rogue daemon glowing red through the lair's door, towers, a floating shard and glowing >_ holograms on the skyline"><br><em>In play: the cannon on the runaway swarm, the rogue daemon through the lair's door.</em></td>
    <td align="center" width="50%"><img src="docs/media/a3-slab.png" alt="In-game view of the lair's front wall: RING 0 in red over the door, KILL -9 and EXIT 137 signs, server racks inside, red arrows on the floor, ribbed and framed panels with light strips, /DEV/NULL on the far wall"><br><em>The lair's front: RING 0 over the door, server racks inside.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a3-corridor.png" alt="In-game view down the west corridor: a ribbed wall with light strips and a terminal screen of scrolling text on the left, a cover wall on the right, a zombie obelisk ahead, towers and a glowing >_ beyond the walls"><br><em>The west corridor, a zombie at its end.</em></td>
    <td align="center" width="50%"><img src="docs/media/a3-skyline.png" alt="View from beyond the arena's north-east corner: a corner tower with a blinking red beacon and a >_ hologram, the plinth's edge, dark towers with lit windows rising out of a teal haze, a drifting shard and slab"><br><em>The void beyond the walls: towers rising out of the abyss.</em></td>
  </tr>
</table>

**Daemons before A5 (A2b).** Each creature up close; a strip of three stills of its motion side by side (the rogue daemon's through a rear and its strike); one view in play with all three kinds; and a death in shards.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a2b-rogue.png" alt="In-game view in the lair: the rogue daemon, a red crystal spider-mantis on six jointed legs with glowing knees, burning shards along its back, its front raised and scythe arms high, server racks behind it"><br><em>The rogue daemon (rogue.d): a crystal spider-mantis.</em></td>
    <td align="center" width="50%"><img src="docs/media/a2b-zombie.png" alt="In-game view down the west corridor: the zombie process, a hunched amber wireframe humanoid with broken shards jutting off its back and long clawed arms, a pale ghost copy of it trailing just behind, code rain on the walls"><br><em>The zombie process (zombie), a ghost trailing it.</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a2b-swarm.png" alt="In-game view over the platform: the runaway swarm, a cloud of red crystal insects with glowing glints flying round a pulsing red nest, code rain on the wall behind"><br><em>The runaway swarm: insects flocking round their nest.</em></td>
    <td align="center" width="50%"><img src="docs/media/a2b-gameplay.png" alt="In-game first-person view with the teal cannon in hand: the red swarm over its platform on the left, the rogue daemon small and red through the lair's door ahead under RING 0, and the amber defunct zombie by the crates on the right, the skyline beyond"><br><em>In play: the swarm, the rogue daemon through the lair's door, the defunct zombie by the crates.</em></td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/a2b-rogue-motion.png" alt="Three in-game stills side by side of the rogue daemon: rearing with its front legs lifted and scythes raised, still reared and trembling, then lunging forward with its scythes slashing down"><br>
  <em>The rogue daemon rears, holds, and strikes: three stills of its motion.</em>
</p>

<p align="center">
  <img src="docs/media/a2b-zombie-motion.png" alt="Three in-game stills side by side of the zombie process limping down the corridor: its pose changing from step to step, bones flickering out, and a cyan ghost copy trailing behind it in the last"><br>
  <em>The zombie limps, twitches and flickers, a cyan ghost behind it: three stills of its motion.</em>
</p>

<p align="center">
  <img src="docs/media/a2b-swarm-motion.png" alt="Three in-game stills side by side of the runaway swarm: the cloud of red crystal insects reshaping round its nest from still to still"><br>
  <em>The swarm flocks round its nest: three stills of its motion.</em>
</p>

<p align="center">
  <img src="docs/media/a2b-shatter.png" alt="In-game view in the lair: the rogue daemon dying, its red crystal legs and segments flying apart among glowing voxels, a column of red light through where it stood and a ring spreading on the floor"><br>
  <em>A death in shards: the rogue daemon's own parts bursting apart over the derezz.</em>
</p>

<p align="center">
  <img src="docs/media/a1-gameplay.png" alt="In-game first-person view: the SIGKILL rail's beam hits a daemon between two neon pillars, which derezzes into glowing voxels, on the teal grid arena with code rain on the walls"><br>
  <em>The rail on a daemon between the pillars, its derezz starting (A1: the daemons as they were before A2's art, the arena before A3's).</em>
</p>

**Held.** Every weapon of the arsenal in first person, at rest (the A1 stills show the arena before A3's dressing).

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-1-terminal-cannon.png" alt="In-game first-person view holding a compact teal carbine with a two-fin muzzle brake, on the neon grid arena"><br><em>1. Terminal cannon</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-2-sigterm.png" alt="In-game first-person view holding a violet over-under pump shotgun with lit rings and chevrons, on the neon grid arena"><br><em>2. SIGTERM</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-3-sigkill-rail.png" alt="In-game first-person view holding a long ice-white rail rifle with four coils and a scope, on the neon grid arena"><br><em>3. SIGKILL rail</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-4-fork-bomb.png" alt="In-game first-person view holding a magenta hex canister caging a drum of lit pods, on the neon grid arena"><br><em>4. Fork bomb</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-5-fork-shotgun.png" alt="In-game first-person view holding a yellow gun whose barrel forks into two prongs, on the neon grid arena"><br><em>5. fork()</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-6-grep-seeker.png" alt="In-game first-person view holding a cobalt smart gun with a fat scope and a dart pod, on the neon grid arena"><br><em>6. grep</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-7-rm-rf-cannon.png" alt="In-game first-person view holding a heavy ember cannon with vent fins and hazard stripes, on the neon grid arena"><br><em>7. rm -rf</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-8-cron-mines.png" alt="In-game first-person view holding a rose dispenser with a hex mine loaded and a clock on top, on the neon grid arena"><br><em>8. cron</em></td>
  </tr>
</table>

**Firing.** The same weapons mid-shot (and the two that charge, mid-charge).

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-1-terminal-cannon-fire.png" alt="In-game first-person view of a compact teal carbine with a two-fin muzzle brake, mid-shot, the muzzle flash at the barrel"><br><em>1. Terminal cannon, firing</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-2-sigterm-fire.png" alt="In-game first-person view of a violet over-under pump shotgun with lit rings and chevrons, mid-shot, the muzzle flash at the barrel"><br><em>2. SIGTERM, firing</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-3-sigkill-rail-charge.png" alt="In-game first-person view of a long ice-white rail rifle with four coils and a scope, its coils lighting as it charges"><br><em>3. SIGKILL rail, charging</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-3-sigkill-rail-fire.png" alt="In-game first-person view of a long ice-white rail rifle with four coils and a scope, mid-shot, the muzzle flash at the barrel"><br><em>3. SIGKILL rail, firing</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-4-fork-bomb-fire.png" alt="In-game first-person view of a magenta hex canister caging a drum of lit pods, a bomb thrown"><br><em>4. Fork bomb, thrown</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-5-fork-shotgun-fire.png" alt="In-game first-person view of a yellow gun whose barrel forks into two prongs, mid-shot, the muzzle flash at the barrel"><br><em>5. fork(), firing</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-6-grep-seeker-fire.png" alt="In-game first-person view of a cobalt smart gun with a fat scope and a dart pod, mid-shot, the muzzle flash at the barrel"><br><em>6. grep, firing</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-7-rm-rf-cannon-charge.png" alt="In-game first-person view of a heavy ember cannon with vent fins and hazard stripes, its vents glowing through the wind-up"><br><em>7. rm -rf, charging</em></td>
  </tr>
  <tr>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-7-rm-rf-cannon-fire.png" alt="In-game first-person view of a heavy ember cannon with vent fins and hazard stripes, mid-shot, the muzzle flash at the barrel"><br><em>7. rm -rf, firing</em></td>
    <td align="center" width="50%"><img src="docs/media/a1-weapon-8-cron-mines-fire.png" alt="In-game first-person view of a rose dispenser with a hex mine loaded and a clock on top, a mine just placed on the floor ahead"><br><em>8. cron, placed</em></td>
  </tr>
</table>


Everything else on this page is concept art or a mockup and is labelled that way; the badges and the hexagon are brand marks.

## License

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 Fred Nix. The original art and audio in the repository are under the same MIT license. SIGKILL is still pre-alpha.

<p align="center">
  <img src="docs/media/nixfred-icon.svg" alt="nixfred" width="64" height="64"><br>
  <sub>a nixfred joint</sub><br>
  <sub>Made by Fred Nix. Built chunk by chunk by Larry, produced by SIGKILL bot. Engine: Godot. Art and audio are original; concept art is labelled as concept art.</sub>
</p>
