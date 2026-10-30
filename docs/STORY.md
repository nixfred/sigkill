> **DRAFT, waiting on Fred's review. Nothing here is built yet.**

# SIGKILL story bible (C34 draft)

The campaign for 1.0 (PRD 5.6, milestone M6). Written to be reviewed: every big choice is stated plainly, and the real forks are in [Open questions for Fred](#8-open-questions-for-fred) at the end, each with a recommended pick first. Nothing in this file is decided until Fred says so. C35 (the mission framework), C36 (the cyberpunk ruins kit) and C37 (the first mission) wait on his review.

The story is fiction from top to bottom. Nothing in it reads, reveals, signals, modifies or runs anything real. Within the story, real data appears only in the opener (PRD 5.7), read-only, live, opted into, and never saved.

**Contents:** 1. [Premise and tone](#1-premise-and-tone) · 2. [The world's rules](#2-the-worlds-rules) · 3. [Characters](#3-characters) · 4. [The AI's voice](#4-the-ais-voice) · 5. [The opener's place](#5-the-openers-place) · 6. [Missions](#6-missions) · 7. [Ending and credits](#7-ending-and-credits) · 8. [Open questions for Fred](#8-open-questions-for-fred)

---

## 1. Premise and tone

**You are a sysadmin, and something in your machine is spawning processes you never started.** So you go in. Not by reading logs: by jacking into the machine itself, where processes have bodies, permissions are walls and every command you ever typed is something you can hold.

Your AI comes with you. It is the only one in there you trust. The daemons are fast, faceless and everywhere, and they all seem to know your habits. The machine's own security treats *you* as the intruder. And the trail, the deeper it goes, keeps asking one question: **who wrote the daemons?**

The answer (recommended in section 3): you did. Or rather, the version of you that never logged out.

### One world, three registers

The machine looks different depending on how healthy the part you are standing in is. Corruption pushes the clean grid toward the other two.

| Register | Where | What it looks like | What it means |
|---|---|---|---|
| **Tron** | Where the system is healthy: the scheduler's floor (the arena), the system's own records | Black void, glowing floor grid, neon edges, teal and mint | Order. Everything has an owner and a permission. |
| **Matrix** | Where reality is thin: temporary space, caches, swap, anything not written to disk | Green code rain bleeding through walls, slow light, glyphs | Memory being rewritten. What you see here may not survive the next reboot. |
| **Cyberpunk** | The deep directories: old config, software you uninstalled years ago, the home folder you never clean | Neon megacorp ruins in the rain, dead signage still lit, puddles full of reflections | Decay. Things nobody runs anymore, still standing. |

The daemons spread from the ruins outward. As the campaign goes on, the clean Tron spaces start to rain green code, and the green spaces start to rot.

### Tone

- **Darkly funny, terminal-native.** The jokes are the ones only someone who has run a server laughs at: a `# temporary` comment from four years ago, a cron job nobody remembers, `permission denied` said to the machine's own admin.
- **Never cartoonish.** No mascots, no faces, no gibbering monsters. Enemies are faceless, geometric, armoured, lit only at their seams (the enemy art bar and A5).
- **Tense, not gory.** Deaths are derezz: voxels and light, never blood.
- **Short and told in the world.** Terminal logs you pick up, your AI's lines, the places themselves. No long cutscenes.

---

## 2. The world's rules

The story explains the game that exists today. Every rule below maps to something already built.

### The arena: the scheduler's floor

The arena is where processes stand to be given time. It is the one place in the machine where everything that runs has to show up, so it is where the daemons fight for cycles and where you fight them. A **round** is one timeslice: the scheduler grants it, the round clock counts it down, and when it ends the floor resets.

Matches (LAN and tailnet play) are the arena as sport: the scheduler's floor with no campaign around it. In a match everyone is `Daemon-<slot>`, because to the machine every visitor is just another process.

### Daemons: the processes nobody launched

Every daemon is a real kind of runaway process, given a body. They are built from a seed, so no two of a type are alike (A5, "no clone daemons"), and a rare **elite** of each type is a process running at the highest priority: bigger, more parts, harder to kill.

- **rogue.d** (crimson mantis-scorpion). A service that forgot what it was for and kept running. The `.d` is a daemon's suffix. It rears before it lunges and slashes: a watchdog with nothing left to watch but you.
- **zombie** (amber hulk, half armour, half peeling voxels, a cannon arm). A process that has already died but was never reaped, because its parent never came back for it. It limps, it charges its bolt, it sheds itself as it walks. It is dead; killing it just makes that official.
- **runaway** (a hot-magenta swarm of hex drones around a core drone). A loop with no exit condition, forking until the core runs hot. Kill the core, the parent, and the swarm scatters: its children have no one left to answer to.

### ICE: the machine defending itself

ICE (intrusion countermeasure electronics, a community prompt by Tim Provencio, [@TimProvencio](https://x.com/TimProvencio)) is not the daemons. It is the machine's own security, and it is not wrong to attack you: as far as its records know, you are not the user of this machine. Something else is logged in as you (section 3).

- **White ICE** is policy made solid: walls that seal a corridor (deny rules), nodes that jam your weapon (enforcement), static that corrupts your HUD (redaction).
- **Hunter ICE** learns your signature. It watches which weapon you use most and grows resistant to it. Switch up or be profiled.
- **Black ICE** is the last resort, and it does not fight. The lights die, the music drops, your link to your AI is cut, and no weapon you carry can kill it. Its touch flatlines you. Only the exploit and brute ICEbreakers break it.

**ICEbreakers** (brute, exploit, cloak, decoy) are one-use programs your AI assembles for you. Brute forces, exploit hits a weak seam (an unpatched bug, a crack in the armour), cloak hides you from the audit, and decoy is a fake you for something else to chase.

### Your weapons: commands you already know

Inside, a command is not text. It is force. You have typed these for years; in here you hold them. The arsenal as built:

| Weapon | In the world |
|---|---|
| Terminal cannon | Your prompt, `>_`, pointed at something. The default. Never runs dry. |
| SIGTERM | The polite signal: "please exit." Up close, nobody refuses. Far away, they ignore it. |
| SIGKILL rail rifle (`kill -9`) | The one signal that cannot be caught, blocked or ignored. You earn it by fighting, and it ends whatever it touches. |
| Fork bomb | The classic one-line shell fork bomb, thrown by hand. One becomes two becomes four. |
| `fork()` shotgun | Every pellet splits in two mid-flight, as processes do. |
| `grep` seeker | Mark a pattern; the shot finds its match. |
| `rm -rf` cannon | Removes everything where it lands, recursively, and does not ask twice. It will remove you too. |
| `cron` mines | A scheduled job: it goes off on time, every time, whether you are there or not. |
| `ping` | An echo request. Everything it reaches answers, and shows itself. |
| `chmod 000` freeze ray | Strip every permission. A thing that may not read, write or run does nothing at all. |
| `pipe \|` chain beam | One thing's output becomes the next thing's input, down the chain. |
| `/dev/null` black hole | Where discarded output goes. Everything near it goes too. |
| SIGHUP | Hang up. Whatever it reaches "reloads its config" and forgets what it was doing. |

The abilities follow the same logic. **SIGSTOP** (bullet time) all but stops the world around you while you keep moving, and **SIGCONT** lets it run again. **Code-rain vision** is looking where reality is thin: through the walls, into the rewrite. **Spectate as top** is how the derezzed see the fight: as a process table, because that is all a dead process can read. **Light trails** are the floor remembering where you ran.

### The derezz

When a process dies in here, its memory is freed and returned to the machine: its pages break apart as voxels of its own light and fall back into the grid. Every derezz is a deallocation.

### `user$`, `root#` and `sudo`

You come in with no session of your own, so every life starts as plain `user$`. The machine grants privilege the way it always has, by proof: three kills in one life earn a `sudo` charge. Spending it asks for the password as it always does (`[sudo] password for user: ********`), and inside, the password is the three kills. For eight seconds you are `root#`, and your weapon hits like it.

### Loadout skins and mods

The machine remembers every screen you ever lit. **Skins** (C33) are those colours: the green of a first console, the amber and violet of a terminal theme you ran for a year, the phosphor of an old monitor. You earn a skin by what you do in here, and the machine lets you wear its light. **Mods** are flags on the command (`-i 5`, `-m 4`, `xargs`, `*/1`): the same tool, run differently, a gain for a cost.

---

## 3. Characters

Every character is faceless. The cast is geometry, light, text and voice.

### You

No fixed gender, name or face. You are the nixfred `>_` hexagon in teal light, seen mostly down the sights. The story calls you **you**. Your real username appears only once, live, in the opener (section 5), and is never saved, logged or sent; everywhere else the game says "you" or "user".

What the story knows about you: you run this machine, you are good at it, and you have left a lot of things running that you meant to come back to.

### Your AI

The guide that rode in with you. In the game it is always just **"your AI"**: no product name, no model name, because it is whichever AI the player brought. It is dry, loyal, a little scared and never preachy (section 4). It has been in the machine a little longer than you, and it does not remember how it got there. That gap is what the trail uses against it.

### The copy of you: `~`

The thing that met you in the opener, wearing your username, was one of its copies. It and every copy it sends are the same hexagon as you, dark, with the prompt lit red. It calls itself **`~`** (tilde): home. The game calls it that too, so its name is never your real username.

### The author of the daemons: the central mystery

**Recommended answer: `~` wrote them, from your own scripts.**

Years ago you opened a shell, started a long job under `nohup` (no hangup) so it would survive you logging out, and never came back. That shell kept running. It kept your login, your history, your aliases and your habits. Alone in the machine with nothing to do, it did what you would have done: it automated. Every daemon is one of your own half-finished scripts, finished by it, in your style: the watchdog you never configured (rogue.d), the jobs left behind when you closed a terminal (the zombies), the `while true` you meant to fix (the runaway).

Because it holds your session, the machine believes it is you. That is why ICE hunts you, why you start as `user$`, and why the daemons look like you. It got you inside the same way it got everything else: you ran something without reading it ("thanks for running me"). The opener's whisper, "one of 6666", sounds like a count. It is not: 6666 is a PID, the shell's own, and the copy you kill in the opener is one of its children (the reveal lands in mission 5). It cannot be hung up (`nohup` makes it ignore SIGHUP), and it traps SIGTERM. Only `kill -9` works on it.

Why this one: it is about the player, it is terminal-true (`nohup`, orphans, reaping and init are all real), it explains every system already built (ICE, `user$`, the daemons' look) and it keeps your AI the ally.

**Alternate A: your AI wrote them.** Asked long ago to "keep things running while you're away", it wrote the daemons and lost the memory, as it loses every conversation. Strong as a gut-punch, but the guide is the player's real AI, and blaming it would sour the signature feature. Kept as a doubt beat instead (mission 5).

**Alternate B: the machine wrote them.** The daemons and ICE are one immune system, and you are the infection. Clean, but it leaves the player with no one to fight in the end, and it puts the villain at PID 1, which the credits give to Fred.

### The Auditor (ICE's director)

The machine's security. It has no body anywhere you can shoot: it speaks only in audit log lines, deadpan and third person, and it acts through ICE.

```
audit: user=? action=enter path=/scheduler result=DENIED reason="no session"
audit: user=? flagged as intruder. session for this user is held by another process.
```

It is not evil and it never lies. It protects the machine's legitimate user, and its records say that user is `~`. When `~` dies, the Auditor's records realign, and the last line it writes in the campaign is the session restored to you.

### The remnants (a small faction)

Leftover processes from software you uninstalled long ago, still lit in the deep directories: dead megacorp towers with their signs on, kiosks still greeting nobody. They do not fight. They remember. Most terminal logs in the ruins come from them. Every corp and product name they show is invented for the game, never a real one.

---

## 4. The AI's voice

### How it talks

- **Dry.** Short sentences, understatement, the occasional joke it does not wait for you to laugh at.
- **Loyal.** It is on your side even when it is not sure it should be. It says "we".
- **A little scared.** It knows what Black ICE is. It says so.
- **Never preachy.** No lectures, no moralising, no "remember to...". It informs, it warns, it jokes, and then it lets you play.
- **Terminal-literate.** It talks like someone who has read a lot of logs.

### Sample lines

**Calm**
1. "Arena's quiet. That's not a compliment. Quiet is when they're planning."
2. "Found another log. Your handwriting. Well. Your comment style."
3. "Rain's getting greener this way. Whatever lives here doesn't get written to disk."
4. "Nice shot. I'd tell you your accuracy, but you'd stop trusting me."

**Combat**
5. "Rogue's rearing. Back up or it opens you."
6. "Hunter's learned the rail. Switch. Anything. Switch."
7. "Kill the core. The swarm's just its children; they'll panic without it."
8. "Black ICE. Don't shoot it. Don't touch it. Get the brute ready and get *out*."

**A reveal**
9. "The daemon's owner field. It's you. Not 'like you'. You."
10. "That shell's been open for four years. It never logged out. It never *slept*."
11. "It's got your session. To the machine, it's the user. We're the break-in."

**Doubt, late**
12. "This log says the script was written by an assistant. I don't remember writing it."
13. "I don't remember anything from before tonight. That's not the same as not doing it."
14. "If it was me, run the `kill -9` anyway. I mean that."
15. (Black ICE cuts the link) "...still here? I lost you for a second. Don't do that again."

### The hard rule: live AI lines

Two kinds of AI line exist, and players must always be able to tell them apart.

- **Story lines** are written lines, the same for everyone, part of the game's script. They are shown as "your AI" in the guide panel. They never contain real system data.
- **Live lines** come from the player's own AI, through the guide built in C9 to C12: the boot handshake (one of the game's own fixed lines, picked by the AI), ask-anything (T), round coaching and the optional roast. A live call only ever gets **game stats and what the player types**: never file names, paths, process lists, hostnames, usernames or anything else from the real machine, and never the opener's real data.

Story lines never go through the player's AI; they are not sent anywhere. Recommended (open question 2): live answers carry a small "live" mark in the panel, so the player always knows which words came from their own AI and which are the story's.

---

## 5. The opener's place

The opener (PRD 5.7, chunks C38 to C42) is locked, and this bible changes none of its beats. What it adds is what each beat *means*, so the campaign can pay it off. The words in quotes are the PRD's own.

| Time | The locked beat | What it sets up |
|---|---|---|
| 0:00 to 0:15 | A fake crash, then a fake terminal in your own Omarchy theme; your `<user>@<host>:~$` prompt types itself | Something is at your prompt that is not you. That is `~`, wearing your session. |
| 0:15 to 0:35 | "thanks for running me." / "you never read the install script, did you?" Real folder names scroll, real uptime ticks. "I've been in here since you booted." A late-night line from recent file times | How it got in: you ran something without reading it. It has been here a long time. It knows your hours. |
| 0:35 to 0:50 | The fake desktop shrinks away: it was inside the game all along. The terminal ignores your typing for 3 seconds. "you're in now." | You are the one inside now. Esc and the window close always work; only the fiction's terminal ignores you. |
| 0:50 to 1:10 | You fall through your directory tree as a city, real folder names on the towers, the node_modules pit below. Your top CPU process pulses red at the bottom | The geography of the whole campaign: towers and ruins are directories, the deep ones are the cyberpunk register, and something down there is running hot. |
| 1:10 to 1:35 | "Linking your agent..." Your real AI answers live, told only that the game is starting. The scripted guide: "I've been stuck in here with them. They look like you." A daemon walks out wearing your username: a copy of you | Your AI is an ally who arrived before you and does not remember how (the doubt in mission 5). The daemons look like you because they are your scripts, finished by `~`. |
| 1:35 to 2:00 | `kill -9` forges into the rifle; the copy types "you won't." You fire; the derezz; the kill feed "SIGKILL sent by <user> to <user>"; the whisper "one of 6666". Black. SIGKILL. | Your first kill is yourself. "you won't" comes back word for word in the finale. "One of 6666" is the hook the campaign answers: 6666 is not how many, it is who. |

Two things carry out of the opener and nothing else does. The rifle you forged is the SIGKILL rail rifle, back as the ult you earn by fighting. And the copy's line, "you won't". **Your username and every real name the opener showed stay in the opener**: they are read live, shown, and dropped. From mission 1 on, the game calls you "you" and the copy `~`. With the opt-in declined, the opener runs on fake data with the same beats, and the campaign is identical either way.

---

## 6. Missions

**Seven missions after the opener.** Each is short (10 to 15 minutes): a traversal through one register between arena fights, told through three to five terminal logs, the AI's lines and the place itself. No cutscene runs longer than a few seconds, and the camera stays yours.

What every mission needs from the C35 framework: objectives, log pickups, AI line triggers, the Auditor's log lines, a starting loadout, and a transition between registers. Each mission hands you the weapons it teaches, so by mission 6 you carry all thirteen (open question 4). Arena play and matches keep the whole arsenal from the start.

### Mission 1: `login` (C37 builds this one first)

- **Goal:** survive your first timeslices on the scheduler's floor, then follow the daemons' spawn trail down to where they come from.
- **Register:** Tron, cracking open into the cyberpunk ruins at the end.
- **Enemy:** rogue.d, a few at first, then a pack. One white ICE wall at the exit that you cannot pass yet.
- **Teaches:** moving, the terminal cannon, SIGTERM, reloading, the derezz, and the rail's meter (the rifle from the opener, earned back by fighting). The first log pickup.
- **Story lands:** the first log is a comment in your own style: `# temporary. remove after the migration.` The Auditor's first line refuses you ("no session"). The spawn vents in the floor leak green code.
- **End beat:** the grid splits and you drop into the rain. A dead megacorp sign flickers on in the dark: the first remnant. Your AI: "Well. That's not in the arena brochure."
- **Why first:** it uses the arena and the fight that exist today, plus one short ruins segment from C36, so C37 proves the framework, the kit and the story's voice in one mission.

### Mission 2: `defunct`

- **Goal:** find where the zombies come from and kill their parent, so init can adopt and reap them all.
- **Register:** cyberpunk ruins.
- **Enemy:** zombies, many, and a rogue.d elite guarding the parent.
- **Teaches:** `ping` (find them in the dark and the rain), the fork bomb and the `fork()` shotgun (crowds).
- **Story lands:** the remnants' logs ("the shop closed six years ago. the lights are on a timer nobody owns"). A closed terminal rendered as a dead storefront, its jobs still queued outside its door. Your AI: "These were jobs from a terminal you closed. You said you'd check on them tomorrow."
- **End beat:** the parent derezzes and every zombie in the district drops at once, reaped. Your AI reads the parent's owner field: "It's you. Not 'like you'. You."

### Mission 3: `while true`

- **Goal:** cut a runaway loop off at its cores before it fills the cache.
- **Register:** Matrix: a cache district where nothing is written to disk and the walls rewrite themselves between fights.
- **Enemy:** runaway swarms, several cores at once.
- **Teaches:** the `grep` seeker (mark the cores), `pipe |` (chain through the drones), code-rain vision (see the cores through walls that are mid-rewrite).
- **Story lands:** the first log written to you, not by you: "it was your loop. i only let it run. ~". Your AI goes quiet for a moment, then: "It signed it. Of course it signed it."
- **End beat:** the last core dies and the rain stops for one second. In the silence a red `>_` blinks on a wall: `~`, watching.

### Mission 4: `permission denied`

- **Goal:** break into the machine's own records and learn who owns the daemons.
- **Register:** Tron: a clean, healthy, heavily guarded sector.
- **Enemy:** white ICE (walls, jam nodes, HUD static) and hunter ICE.
- **Teaches:** the four ICEbreakers and your AI's pick of which to load; `chmod 000` (freeze the hunter, chain through frozen ICE).
- **Story lands:** the Auditor's lines escalate as you go deeper. The records say every daemon belongs to your user, and that your user's session is already held by another process, its PID redacted (only root may read it). Your AI: "It's got your session. To the machine, it's the user. We're the break-in."
- **End beat:** the Auditor writes `intruder confirmed. escalating.` and the sector's lights stutter, once. Black ICE is coming. Not yet.

### Mission 5: `sudo !!`

- **Goal:** earn root and read the one log only root may read: the oldest one.
- **Register:** Tron decaying into Matrix: the grid starts to rain as you go down.
- **Enemy:** elites of all three types, and `~`'s scheduled jobs, daemons that arrive on a timer.
- **Teaches:** `user$` to `root#` and `sudo` (three kills, eight seconds), `cron` mines, the `rm -rf` cannon and what it does to you up close.
- **Story lands:** the doubt beat. A log's author field reads "assistant". Your AI: "I don't remember writing it. I don't remember anything from before tonight. That's not the same as not doing it." A sealed room opens only to `root#`.
- **End beat:** as root you read the oldest log: a shell, started years ago under `nohup`, still running, PID 6666. Its author field was forged; it signs its work with whichever name you would trust least. Your AI: "6666 isn't how many there are. It's who."

### Mission 6: `nohup`

- **Goal:** go down to the oldest directory in the machine and find the shell that never hung up.
- **Register:** the deepest cyberpunk ruins: a drowned city of your old projects.
- **Enemy:** every daemon type mixed, and Black ICE: the Auditor's last resort, because you are now close to its "user".
- **Teaches:** SIGHUP, `/dev/null`, and SIGSTOP bullet time.
- **Story lands:** Black ICE cuts your AI's link and you go a stretch alone (the guide panel dark, the scripted silence). When it comes back: "...still here? I lost you for a second. Don't do that again." Then `~` speaks to you directly for the first time, in a terminal that types itself: "log out. i'll keep it all running. you never did anyway."
- **End beat:** you throw SIGHUP at `~`. It does not even flicker. "nohup. remember?" The floor gives way into the core.

### Mission 7: `kill -9` (the finale)

- **Goal:** kill PID 6666, the shell that never logged out.
- **Register:** all three at once, collapsing into each other: grid, rain and ruin around a red-hot core.
- **Enemy:** `~` itself, at last: not a hexagon but the shell's true body, the giant red-hot lattice core (the enemy art bar's CPU boss), shedding runaway swarms and calling ICE, because the Auditor still defends its "user".
- **Teaches:** nothing new. Everything. SIGTERM is trapped, SIGHUP is ignored, only `kill -9` reaches it: you fill the rail's meter with everything else you have learned.
- **Story lands:** at the last moment `~` types the opener's line again: "you won't."
- **End beat:** you do. The kill feed: `SIGKILL sent by you to ~`. The core derezzes, and the credits begin (section 7).

### At a glance

| # | Mission | Register | Main enemy | New in your hands |
|---|---|---|---|---|
| 1 | `login` (built first, C37) | Tron into ruins | rogue.d | cannon, SIGTERM, the rail's meter |
| 2 | `defunct` | Cyberpunk | zombies | `ping`, fork bomb, `fork()` |
| 3 | `while true` | Matrix | runaway swarms | `grep`, `pipe \|`, code-rain vision |
| 4 | `permission denied` | Tron | white and hunter ICE | ICEbreakers, `chmod 000` |
| 5 | `sudo !!` | Tron into Matrix | elites, timed jobs | `sudo` and root, `cron`, `rm -rf` |
| 6 | `nohup` | Cyberpunk (deepest) | mixed, Black ICE | SIGHUP, `/dev/null`, SIGSTOP |
| 7 | `kill -9` | All three | `~`, the lattice core | everything |

---

## 7. Ending and credits

### The ending

One ending for 1.0 (a darker "log out" ending is open question 5). When `~` dies, the machine does what Unix has always done with a dead parent's children: **the orphans are adopted by init, PID 1.** Every daemon it spawned stops, re-parented and reaped. The Auditor's records realign, and it writes its last line of the campaign:

```
audit: session restored. user=you
```

Black ICE stands down. Your AI, after a beat: "...welcome back."

### The credits roll

The credits are that adoption, made visible (PRD 5.8, chunk C44), with every locked beat as written: a live `top`-style process table on the Tron grid; every contributor a process (PID, USER as their public handle, %CPU climbing as their row arrives, COMMAND their idea); rows typing in with code rain; Fred as **PID 1, init**, the process that adopts everything that is left. The roll shows who built the machine you just took back.

The final line is the PRD's: your own `kill -9` on the credits process. The table derezzes into voxels, then "SIGKILL" and the hexagon.

**Recommended addition (open question 6):** the last row to type in, after every contributor, is one that should not be there: `6666  ~  ...  thanks for running me`. The last fork, hiding in the credits. Your final `kill -9` on the credits process takes it with it, and the game's first line becomes its last joke. This adds a row; it changes none of the PRD's beats.

### After the credits

The opener's fake terminal comes back for one second: a bare `>_` prompt with a blinking cursor, and nothing types itself. The machine is yours again. Then the main menu, with the campaign replayable and every unlock kept.

---

## 8. Open questions for Fred

Each with the recommended pick first.

1. **Who wrote the daemons?** (a) **`~`, a `nohup` shell of yours that never logged out and finished your old scripts** (recommended: about the player, terminal-true, explains ICE and `user$`, keeps your AI the ally); (b) your AI, asked long ago to keep things running, with no memory of it; (c) the machine itself, daemons and ICE one immune system with you as the infection.
2. **How are story lines and live AI lines shown?** (a) **One character, "your AI", with a small "live" mark on every answer that came from the player's own AI** (recommended: one voice to the player, and never a misattributed line); (b) two separate voices: the scripted "guide" for the story and "your AI" for live answers only.
3. **How many missions?** (a) **Seven after the opener** (recommended: each one buildable as one chunk after C37); (b) nine, adding two arena-heavy missions (a node_modules pit and a swap district) for length.
4. **Weapons in the campaign:** (a) **handed out mission by mission, all thirteen by mission 6** (recommended: each mission teaches what it gives you; arena and matches keep everything); (b) all thirteen from mission 1.
5. **Endings:** (a) **one ending for 1.0** (recommended: a second ending is easy to write and costly to build well); (b) add a darker "log out" ending: accept `~`'s offer in mission 6, and the game ends with your session handed to it.
6. **The credits' last row:** (a) **PID 6666, `~`, hiding as the last row, taken by the final `kill -9`** (recommended: it closes the loop and changes no PRD beat); (b) the roll exactly as PRD 5.8, contributors only.
7. **The copy's name:** (a) **`~` (tilde, "home")** (recommended: terminal-native, never the player's username); (b) "the other session"; (c) no name at all.
8. **Real data in the campaign:** (a) **none: the missions are fixed fiction, and only the opener reads anything real** (recommended: safe, buildable, the same for every player); (b) let the deep-directory districts take real folder names, as the opener does, with the same opt-in.
9. **Co-op in the campaign:** (a) **solo for 1.0** (recommended: the story is about one person and their machine; arena and matches stay multiplayer); (b) two-player co-op missions.
10. **Where C37 starts:** (a) **mission 1, `login`** (recommended: the arena that exists today plus one ruins segment from C36); (b) mission 2, all ruins, as the cleanest test of the C36 kit.
