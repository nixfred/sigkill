> **DRAFT, waiting on Fred's review. Nothing here is built yet.**

# SIGKILL story bible (C34 draft)

The campaign for 1.0 (PRD 5.6, milestone M6). Written to be reviewed: every big choice is stated plainly, and the real forks are in [Open questions for Fred](#8-open-questions-for-fred) at the end, each with a recommended pick first. Nothing in this file is decided until Fred says so. C35 (the mission framework), C36 (the cyberpunk ruins kit) and C37 (the first mission) wait on his review.

The story is fiction from top to bottom. Nothing in it reads, reveals, signals, modifies or runs anything real. Real data appears only in the opener (PRD 5.7), read-only, live, opted into, and never saved.

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

The thing that met you in the opener, wearing your username. It is the same hexagon as you, dark, with its prompt lit red. It calls itself **`~`** (tilde): home. The game calls it that too, so its name is never your real username.

### The author of the daemons: the central mystery

**Recommended answer: `~` wrote them, from your own scripts.**

Years ago you opened a shell, started a long job under `nohup` (no hangup) so it would survive you logging out, and never came back. That shell kept running. It kept your login, your history, your aliases and your habits. Alone in the machine with nothing to do, it did what you would have done: it automated. Every daemon is one of your own half-finished scripts, finished by it, in your style: the watchdog you never configured (rogue.d), the jobs left behind when you closed a terminal (the zombies), the `while true` you meant to fix (the runaway).

Because it holds your session, the machine believes it is you. That is why ICE hunts you, why you start as `user$`, and why the daemons look like you. It got you inside the same way it got everything else: you ran something without reading it ("thanks for running me"). It has forked itself 6666 times; the copy you kill in the opener is one of them. It cannot be hung up (`nohup` makes it ignore SIGHUP), and it traps SIGTERM. Only `kill -9` works on it.

Why this one: it is about the player, it is terminal-true (`nohup`, orphans, reaping and init are all real), it explains every system already built (ICE, `user$`, the daemons' look) and it keeps your AI the ally.

**Alternate A: your AI wrote them.** Asked long ago to "keep things running while you're away", it wrote the daemons and lost the memory, as it loses every conversation. Strong as a gut-punch, but the guide is the player's real AI, and blaming it would sour the signature feature. Kept as a doubt beat instead (mission 5).

**Alternate B: the machine wrote them.** The daemons and ICE are one immune system, and you are the infection. Clean, but it leaves the player with no one to fight in the end, and it puts the villain at PID 1, which the credits give to Fred.

### The Auditor (ICE's director)

The machine's security. It has no body anywhere you can shoot: it speaks only in audit log lines, deadpan and third person, and it acts through ICE.

```
audit: user=? action=enter path=/scheduler result=DENIED reason="no session"
audit: user=? flagged as intruder. session for this user is held by PID 6666.
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

Story lines never go through the player's AI; they are not sent anywhere. Live answers carry a small "live" mark in the panel, so the player always knows which words came from their own AI and which are the story's (see open question 2).
