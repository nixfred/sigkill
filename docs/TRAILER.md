# Teaser footage (T1)

The raw footage for the 70 second teaser at the top of playsigkill.com: real in-game clips, rendered by the game
itself, on demo data only. The producer cuts the final edit and adds the music; this tool makes the clips.

- `tools/trailer.gd` is the shot list: each shot drives the shipped game (the arena, the daemons, ICE, the weapons,
  the opener) the way the tests and the stills tool do, with its own camera moves, the HUD hidden and the 3D drawn
  at twice the window's resolution and filtered down.
- `tools/trailer_capture.sh` renders it: one Godot run a shot under Movie Maker (`--write-movie`, `--fixed-fps 60`,
  1920x1080, the game's own sound mixed into the file), one clip a shot, and `shots.json` beside the clips.

## Re-render

```bash
mkdir -p ~/.cache/sigkill-trailer
tools/trailer_capture.sh ~/.cache/sigkill-trailer                       # every shot
tools/trailer_capture.sh ~/.cache/sigkill-trailer 05-03-rail 07-title    # just these
tools/trailer_capture.sh ~/.cache/sigkill-trailer --list                 # the shot ids
```

The work folder must exist and be empty the first time; after that the script recognises its own (it keeps a
marker file there) and re-renders into it. It renders from a `git archive` copy of this repository's HEAD (set
`TRAILER_COMMIT=<ref>` for another commit), so uncommitted changes are not in the footage. The first run imports
that copy (about a minute). A full render took 50 minutes on the development laptop; the opener's clips are the slow
ones, as each take plays the opener from its start up to its moment (the fall's take is about 55 seconds of opener).

It needs Godot 4.7 (Vulkan), `Xvnc` (TigerVNC), `xauth`, `mcookie`, `ffmpeg` and `ffprobe`, `jq`, `git` and `tar`.
The raw takes are Motion JPEG in the work folder: 100 to 300 MB a shot, the opener's up to 1.2 GB, 7.2 GB in all.

## What it leaves

| Path in the work folder | What |
|---|---|
| `out/<id>.mp4` | the clip: H.264 1920x1080 at 60 fps, the game's sound as AAC 48 kHz stereo; the take fails if it is not exactly that |
| `out/shots.json` | every clip in the running order: its file, `start` and `end` in that order, `duration`, `bytes`, a one-line `description`, the `commit` it was rendered from, `loudest` (the peaks of its own sound louder than -30 dBFS, seconds into the clip, with the sounds that started just before, such as `sigkill_rail fire` or `kill chime`) and `events` (kills with the weapon, a freeze) |
| `out/sheets/<id>.png` | eight frames of the clip side by side, to judge it at a glance |
| `movies/<id>.avi` | the raw take, warm-up included (the clip is cut from it at the take's roll and cut marks) |
| `logs/<id>.log` | Godot's output for the take |
| `runs/<stamp>-<id>/` | that take's fresh, empty user data, settings and caches |

The script deletes nothing: remove the work folder yourself. The clips are never committed (the repository is public
and they are large) and never uploaded by this tool.

## Demo data only

- `tools/trailer.gd` refuses to run without `--demo`, with the opener's real data switched on in the user data it
  would use, or headless. The shell always passes `--demo` and gives every take a fresh, empty user data folder.
- The guide link is a demo one with its own privacy file, with real machine data and the opener's real data written
  off; the opener is checked to be on `DemoOpenerData` before a frame of it is kept (`user@workstation`, invented
  folder names). No AI is called and nothing of the machine is read.
- The display is private: Xvnc with no TCP listener, its VNC side on a unix socket only the owner can open, a fresh
  random cookie, an empty private `XDG_RUNTIME_DIR` and no Wayland socket, so nothing can appear on a desktop. Movie
  Maker plays no sound aloud.

## The shot list

86.9 seconds in all, cut into clips so the edit can pick and trim. The running order is the list's.

| Clip | Seconds | What |
|---|---|---|
| `01a-crash` | 4.05 | The arena mid-fight; the opener seizes the frame, glitches it apart, cuts to black |
| `01b-thanks` | 3.0 | The fake terminal, a slow push-in: `user@workstation:~$ thanks for running me.` |
| `01c-install` | 4.0 | "you never read the install script, did you?", with its typo taken back |
| `01d-since` | 4.2 | The folder scroll, the uptime ticking, "I've been in here since you booted." |
| `01e-reveal` | 3.4 | The shrink-away: the terminal becomes one lit screen on a monolith in a city of folders |
| `01f-fall` | 3.2 | The fall past the top terrace's towers and names (the latte palette, the most vivid city) |
| `02a-skyline` | 3.6 | From the skyline's megastructures in over the arena's wall |
| `02b-trails` | 3.6 | Three light-cycle trails (light-trail mode's own walls) racing across the floor |
| `03a-rogue` | 3.0 | rogue.d up close: its tell and lunge, orbited low |
| `03b-zombie` | 2.8 | A zombie process charging its cannon and firing a glitch bolt |
| `03c-runaway` | 2.8 | The runaway swarm's drones whirling round their core |
| `03d-pack` | 3.2 | Seeded variants and an elite charging the camera, which cranes up as they pass under |
| `04a-ice` | 3.4 | White ICE in the corridor: the cannon cracks it, a brute ICEbreaker smashes through |
| `04b-black-ice` | 3.6 | Black ICE growing out of the floor with the arena's lights low, the camera low and pushing in |
| `05-01-cannon` to `05-13-sighup` | 1.5 to 2.8 each | All 13 weapons firing on daemons, kills derezzing; the big six (rail, fork bomb, chmod 000, pipe, /dev/null, SIGHUP) the longest |
| `06-fight` | 5.0 | A crane over the arena as a crowd of daemons swarms the player and the heavy weapons go off |
| `07-title` | 6.0 | The SIGKILL wordmark in the arena's sign font slamming together out of neon voxels, the nixfred hexagon (the brand file as it is), PRE-ALPHA, playsigkill.com |

## Where the trailer bends the game, and how

- Its own camera on every third-person shot, and a slow push-in on the terminal's layer in `01b` to `01d` (a scale
  of the real screen, nothing redrawn).
- The 3D at twice the window's resolution, filtered down; the HUD and the daemons' floating name tags hidden.
- The daemons a shot needs beyond the arena's four, each from a fixed seed; the player kept standing (its health
  topped up when it runs low; hits still land and show).
- `/dev/null`'s hold (four seconds in play) is cut short once its crowd is in, as the stills tool does.
- No spoilers: nothing past the C40 fall, never `~`'s face or the ending.

## Repeatable, and what to know when cutting

- The takes are seeded and stepped at a fixed 60 frames a second; a second take of the same shot matched the first at
  45 dB PSNR on average (42 dB at worst, some frames identical): the GPU's particles differ by a pixel or so.
- The daemons have no sounds of their own in the game yet (their tells, strikes, bolts and deaths are silent), so
  `03a` to `03d` carry only the arena's low hum: the music has those shots to itself. The weapons, the opener and
  the title are loud (peaks near 0 dBFS).
- The opener's terminal clips (`01b` to `01d`) are mostly a flat dark screen, so they encode to about a megabyte.

Fiction only, as the game: nothing on the machine is read, changed, signalled or run.
