<p align="center">
  <img src="docs/media/banner-title.jpg" alt="SIGKILL. kill -9 the daemons."><br>
  <sub><em>Concept art, not in-game footage.</em></sub>
</p>

<p align="center">
  <a href="https://godotengine.org/"><img alt="Godot 4" src="https://img.shields.io/badge/Godot-4-19d3c5?logo=godotengine&amp;logoColor=7dffcf&amp;labelColor=05080a"></a>
  <img alt="Vulkan renderer" src="https://img.shields.io/badge/Vulkan-renderer-19d3c5?logo=vulkan&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <img alt="Native Linux" src="https://img.shields.io/badge/Linux-native-19d3c5?logo=linux&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <img alt="Omarchy / Hyprland" src="https://img.shields.io/badge/Omarchy-Hyprland-19d3c5?logo=hyprland&amp;logoColor=7dffcf&amp;labelColor=05080a">
  <img alt="License: TBD" src="https://img.shields.io/badge/license-TBD-ffb000?labelColor=05080a">
  <img alt="Status: pre-alpha" src="https://img.shields.io/badge/status-pre--alpha-ff3355?labelColor=05080a">
</p>

<p align="center"><b>A native Linux first-person shooter for Omarchy. You are the nixfred <code>&gt;_</code> hexagon, hunting rogue daemons inside your own machine, with your own AI at your side.</b></p>

<h3 align="center"><i>your AI has been watching you code for months.<br>what happens when you hand it a gun?</i></h3>

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

You play the nixfred `>_` hexagon, deep inside your own machine, hunting rogue daemons, zombie processes and runaway apps. The world has three visual registers that share one space:

- **Tron** where the system is healthy: a pure black void, glowing light grids, neon edges on every surface. Teal and mint are yours; red and amber are hostile. **Built:** the greybox arena already has the black void, the glowing floor grid and the neon edges.
- **Matrix** where reality is thin: green code rain that bleeds through walls when daemons are near. **Built:** the greybox walls rain glyphs around every live dummy, and the rain fades when it derezzes. Code-rain vision is **Planned** (C21).
- **Cyberpunk** in the deep directories: neon megacorp ruins, rain and signage. **Planned** (C36 ruins art kit).

In the planned game, corruption pushes the clean Tron grid toward Matrix rain and cyberpunk decay, and the core loop is fast arena deathmatch against other players plus a solo or co-op daemon hunt, in the same arenas with the same weapons, wrapped in a story campaign. Today's build is single-player: one greybox arena with target dummies that derezz into voxels when killed and then respawn, and walls that rain code wherever a dummy stands near them.

### Why a big studio can't ship this

A studio game has to be the same on every machine. SIGKILL is different on every machine, on purpose:

- **It is built from your machine.** Later milestones turn your real folder tree into rooms and your running processes into enemies, using only names, sizes and counts. The few other planned reads are narrow and read-only, and the [safety section](#safety-and-privacy) lists them all. Every kill is cosmetic.
- **It plays alongside your AI.** Your guide will be the coding agent you already chose in Omarchy, talking to you live, on your own subscription or your own hardware (Planned, M2). A studio cannot ship your AI in the box.
- **It is made for one desktop.** Omarchy themes, Hyprland and the terminal culture around them are the setting, not an afterthought.

<table>
  <tr>
    <td align="center" width="33%">🟦<br><b>Tron arena</b><br>Black void, glowing light grid, neon edges.<br><sub>✅ Built, as a greybox arena</sub></td>
    <td align="center" width="33%">📡<br><b>Signal weapons</b><br>SIGTERM shotgun, SIGHUP confusion grenade, the SIGKILL rail rifle.<br><sub>⬜ Planned from C16; the terminal cannon is built</sub></td>
    <td align="center" width="33%">🧠<br><b>Your REAL AI</b><br>The coding agent you already picked in Omarchy rides along as your guide.<br><sub>🔧 In progress, M2: the detector (C9), agent adapters (C9b) and boot screen (C10) are built</sub></td>
  </tr>
  <tr>
    <td align="center">🌐<br><b>One-click multiplayer</b><br>Internet matches by room code. No port forwarding.<br><sub>⬜ Planned, M3</sub></td>
    <td align="center">🟢<br><b>Code-rain vision</b><br>See daemons through walls as Matrix glyphs.<br><sub>⬜ Planned, C21</sub></td>
    <td align="center">🐧<br><b>Native linux binary</b><br>Godot 4 on Vulkan, built for Omarchy and Hyprland.<br><sub>✅ Runs from source; packaged builds planned</sub></td>
  </tr>
</table>

Built today: the greybox arena with the Tron look, tight movement, the terminal cannon, target dummies that derezz into voxels and respawn, and Matrix code rain on the walls near enemies. The game opens on a boot screen (C10) that names your Omarchy default agent, asks before it is ever called, shows it answering, and reads your GPU; under it, the AI source detector (C9) and the guide's agent adapters (C9b). Everything else on this page is labeled with its real status, and the roadmap below tracks it chunk by chunk.

## Story

> **Status: Planned** (story bible C34, missions C35 to C37, the opener C38 to C42). None of the campaign is built yet.

**You're a sysadmin jacked into your own machine, because something is spawning processes you never started.** Your AI is the only one you trust, until the trail leads to a question nobody wants answered: who wrote the daemons?

The campaign is told in short missions between arenas, through terminal logs you pick up, your AI's lines and the places themselves. There are no long cutscenes. The story is fiction from top to bottom: nothing in it reads or reveals real system data.

### The opener

> Something has been living in your machine longer than you have been playing.
>
> It has been waiting for you to notice.
>
> The first time you run SIGKILL, it notices you back.

The opener runs live in the engine, never pre-rendered, and can be skipped after the first viewing. It uses your machine's real names only if you allow it on first launch, read-only; otherwise it runs on fake data. Esc and the window's close button always work. Status: Planned (C38 to C42, after the boot sequence exists; the derezz effect it needs is built, C7).

## The arsenal

Every weapon is a Unix signal or shell command made physical, and each one will get its own Tron light skin, mods and unlocks earned by playing. They are fiction: no weapon runs, signals or touches anything real on your machine.

| Weapon | What it does | Status |
|---|---|---|
| Terminal cannon | The default hitscan rifle. Neon muzzle flash with a light, camera recoil with smooth recovery, a hit marker on confirmed hits, sparks off the surface you hit, synthesised zap and hit sounds | ✅ Built (C6) |
| SIGTERM | Polite shotgun | ⬜ Planned (C16) |
| SIGKILL / `kill -9` | Uncatchable rail rifle that one-shots and derezzes. The ult, with a "kill -9" headshot callout | ⬜ Planned (C17) |
| Fork bomb | Grenade that splits 1, 2, 4, 8 | ⬜ Planned (C19) |
| `sudo` | Power-up that overcharges the current weapon, tied into Root vs user | ⬜ Planned (C22) |
| `fork()` | Shotgun whose pellets split in two mid-flight | ⬜ Planned (C24) |
| `grep` | Seeker smart gun that locks onto a marked target | ⬜ Planned (C25) |
| `rm -rf` | Slow, devastating cannon with friendly-fire risk | ⬜ Planned (C26) |
| `cron` | Timed mines | ⬜ Planned (C27) |
| `ping` | Sonar pulse that reveals hidden daemons | ⬜ Planned (C28) |
| `chmod 000` | Freeze ray | ⬜ Planned (C29) |
| `pipe \|` | Chain beam that arcs between enemies | ⬜ Planned (C30) |
| `/dev/null` | Black-hole grenade | ⬜ Planned (C31) |
| SIGHUP | Confusion grenade: enemies "reload" and wander | ⬜ Planned (C32) |

Nothing in the arsenal is in progress right now: the cannon is finished and the rest waits for the weapon framework.

**Abilities and modes**

| Ability or mode | What it does | Status |
|---|---|---|
| Derezz deaths | Daemons shatter into glowing voxels that burst, tumble, land and fade. Built on the target dummies, which then respawn at full health. Players derezz, and the kill feed "SIGKILL &lt;pid&gt; sent by &lt;player&gt;" arrives, with synced combat (C14) | ✅ Built on dummies (C7) · ⬜ Players and kill feed planned (C14) |
| SIGSTOP bullet time | Short meter of Matrix slow-mo; SIGCONT resumes | ⬜ Planned (C18) |
| Light-trail mode | Your path leaves a solid neon wall, for Tron deathmatch | ⬜ Planned (C20) |
| Code-rain vision | See enemies through walls as glyphs; drains fast | ⬜ Planned (C21) |
| Root vs user | Spawn as user, earn sudo for a power spike | ⬜ Planned (C22) |
| Spectate as top | Dead players watch a live process-table style view of the match | ⬜ Planned (C23) |

**How weapons are built.** Today the cannon's every number lives in one resource, `resources/terminal_cannon.tres`, read through `scripts/weapon_tuning.gd`. The weapon framework (C16) generalises that into data-driven weapon resources with a swap wheel, ammo, and slots for mods and skins; unlocks, mods and light skins follow in C33.

## Your AI in the game

> **Status: In progress** (M2). **Built:** the AI source detector (C9), the agent adapters (C9b) and the boot screen that uses them (C10). **Planned:** the guide HUD (C11), coaching and roasts (C12). The rest of this section describes the design Fred decided in PRD 5.4.

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
- **Asking first.** Before the first call to an agent or a local server, the screen names it, says what it gets ("only game stats and what you type"), and waits for Y to allow or N to keep the AI off. Plain keys only; a Ctrl, Alt or Super chord is ignored. `scripts/boot/guide_settings.gd` keeps the answer in the game's own data folder, `user://settings.cfg`. It counts only for that agent or server, so a different one is asked again, and a damaged file means one more question, never a call without a yes. No yes, no call: the guide's AI switch is turned on only on the screen's own copy of the guide tuning, and only after a yes. The in-game switch to change the answer later comes with the guide HUD (C11).
- **The handshake.** One request through the C9b registry and request builder, with a fixed prompt and no player data at all (its stats line reads "Game stats: none"). A "thinking" spinner runs while it waits; then the answer and its latency, plus tokens per second from a local server. A timeout or an error shows "No answer from <agent> (<reason>)." and the scripted guide. A local server with nothing loaded shows "Local model available, not loaded. Load it later from settings." and is never asked to load anything.
- **Only SIGKILL's own words on screen.** The handshake prompt asks the AI to reply with exactly one of five fixed SIGKILL lines, such as "Online. Daemons beware.", and the screen shows SIGKILL's own copy of the line it picked, or "Link up." for anything else. So the AI shows it is answering live, but its own words, which could name a person, a machine or a model, never reach the screen. The local adapter also replaces the loaded model's name in its answers. Agent names come only from the detector's known list, and error reasons only if they are short lowercase words.
- **The headless guard.** In any headless run, or with the `--no-ai` argument, the boot screen never makes a real detector and never asks the registry, whatever was saved, so no agent is launched and no model server is contacted. A headless run with nothing handed in goes straight to the arena, which keeps `scripts/check.sh`'s 300-frame run real-call-free while it still runs the arena. Traced with strace: no network connection at all.
- **Demo-data mode**, for screenshots and trailers: `godot --path . -- --demo`. Agent "claude", fake GPU numbers, a canned answer and latency, and no detector, no settings file, no process and no network.
- **Tuning.** Typing speed, pauses, the spinner, the demo timings, the GPU interval (never under a second), the wait before the arena, text sizes and colours are in BootTuning, `scripts/boot/boot_tuning.gd` with `resources/boot.tres`.
- **Seen headless only.** No window has shown it yet, and no real agent or model server has been called from it; the first real call waits for Fred's yes.

The test, `tests/boot_sequence_test.gd`, uses fakes only: a spy detector, the C9 detector pointed at the fixtures and a fake model server on a random local port, and a stub adapter.

### Why it never uses omarchy-agent

Omarchy ships `omarchy-agent` and `omarchy-agent-prompt` to launch agents quickly, and they launch them with skip-approval flags so the agent can act without asking. A game must never hand an agent that kind of power. SIGKILL calls each agent's own CLI itself, with tools off and approvals on. That restricted launch is one of only two things the game may ever execute; see [Safety and privacy](#safety-and-privacy).

### What gets sent, and what never does

| Sent to your AI | Never sent |
|---|---|
| Game stats: accuracy, deaths, where you got caught | File names and paths |
| What you type into the chat key | Process lists |
| The boot handshake | System information of any kind |
| | Anything the opener or the machine-world features read |

The AI is opt-in on first launch, with a plain description of which agent will be called, and you can turn it off at any time.

### Cost, speed and model hygiene

- **Cloud agents spend your own subscription and take seconds to answer**, so SIGKILL uses them only where seconds are fine: the boot handshake, ask-anything, between-round coaching and opt-in roasts. It never calls them per frame or per second; fast in-fight callouts come from game logic. Calls are rate-limited and the HUD shows a "thinking" state.
- **With the local fallback** the game checks what is already loaded first, never changes shared model settings, never loads a huge model without asking, and unloads anything it loaded when it exits.

### Proof it's yours

- **Boot sequence (C10), built:** names the agent from your own Omarchy setting, `Omarchy default agent: <agent>. Linking...`, and shows it answering live, with the latency and a live GPU readout. See [Built: boot sequence (C10)](#built-boot-sequence-c10).
- **In-game HUD (C11):** a "your AI" badge, live response latency, tokens per second on the local fallback, and live GPU stats: utilisation, VRAM and temperature.
- **GPU stats are read-only.** The game prefers reading them from /sys. Its only alternative is an optional, query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader,nounits`, never with control flags, which is the second and last thing the game may ever execute. The detector above already does exactly this. If neither works, the HUD simply hides GPU stats.
- **Coaching (C12):** between-round coaching from your real round stats, and an opt-in roast announcer.

## Your machine is the world

> **Status: Planned** (M5 including the Audit Trail visor in C43, plus the opener's read-only reader in C39).

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

- **Read-only, and only the outside of things:** names, sizes and counts. The Audit Trail visor adds process IDs, parent process IDs and CPU and memory numbers; the opener also uses modification times and theme colours. Never file contents, command lines, environment or paths.
- **Cosmetic kills.** Shooting a process-named enemy despawns a game object. Nothing on your system is signalled, stopped or changed.
- **Opt-in.** On first launch SIGKILL asks before it reads any folder or process names. Say no and every feature runs on fake data.
- **Nothing leaves the moment.** What is read is shown live and never saved, logged or sent anywhere. Your AI gets none of it.
- **Demo-data mode** for every capture and trailer, so no real machine data ever ends up in a screenshot.

## Visual tech

### Built: the Tron arena

- **Floor grid**, `shaders/floor_grid.gdshader`. A spatial shader that works in world space: the vertex stage passes `MODEL_MATRIX * VERTEX` to the fragment stage, so every floor block shares one continuous grid. Lines run along X and Z with 1 m cells and a brighter major line every 8 m, set by `GRID_CELL` and `GRID_MAJOR_EVERY` in `scripts/palette.gd`. Line coverage is anti-aliased with `fwidth`, and once a pixel is wider than a line the line's energy is spread over that pixel, so the far floor fades into the dark instead of shimmering. The lines are emission on a near-black base, which is what the glow pass blooms.
- **Neon edges**, `shaders/neon_edge.gdshaderinc`. Glowing outlines on every greybox block except the floor, which has its own grid shader, and on the target dummies, found without normals or extra geometry. The edge maths lives in that include file; `shaders/neon_edge.gdshader` is the plain look the dummies use, and the code rain shader below includes the same maths for the blocks. In local space, a point on a flat face sits at distance zero from its own face plane, so the second-smallest plane distance is its distance to the nearest edge. A box has three plane families; the dummies' hexagonal prism has four, three side-plane pairs plus the caps. Edge width and colour are uniforms, and every block gets its own material sized to its half extents. On the hexagon the side faces meet at 120 degrees, so the plane distance underestimates the true distance along a face and the vertical edges draw about 15 percent wider than the rims.
- **Environment**, `scenes/arena.tscn`. One WorldEnvironment: a black background, glow in screen blend with an HDR threshold of 0.5 so emissive edges bloom while faces stay dark, black exponential fog at density 0.02 so distance fades into the void, and the filmic tonemapper. SSAO, SSR and SDFGI are off to keep it cheap.
- **Colour**, `scripts/palette.gd`. The single source for every material and environment colour, and the factory for every material: void `#000000`, base `#05080a`, teal `#19d3c5` and mint `#7dffcf` for the player side, hostile red `#ff3355` and amber `#ffb000`. `scripts/main.gd` applies the exact palette colours to the environment at runtime; the scene file carries approximations only so the editor previews the look. Two light colours still live in their scenes: the sun in `scenes/main.tscn` and the room light in `scenes/arena.tscn`.
- **Cannon effects**, `scripts/cannon_fx.gd`. The beam, the muzzle flash and its light, the impact flash and the sparks use unlit, over-bright materials so the glow pass picks them up. Sparks are CPU particles launched along the surface normal: hostile hits spark amber, the world sparks mint. Every effect frees itself when its lifetime ends.

**What is verified, and what is not.** Headless Godot still runs the shading-language front end, so `scripts/check.sh` catches shader syntax and semantic errors; deliberately broken shaders were used to prove it. During C4 a one-off probe also checked the edge-distance maths against real mesh data. What nobody has seen yet is the result on a real screen: the GPU-side compile and the actual look stay unverified until the first windowed capture.

### Built: derezz on the target dummies

- **The effect**, `scripts/derezz_fx.gd`. A killed dummy shatters into voxels that fill its hexagonal prism. One MultiMeshInstance3D per death holds every voxel as an instance, so there is no node and no physics body per voxel, and the count is capped, at 160 by default. Every derezz shares one voxel mesh and one unlit, over-bright material. About half the voxels glow hostile red; the rest are obsidian with a faint red tint.
- **Motion** is scripted on the CPU at a fixed 60 Hz step, so it plays the same at any frame rate: an outward burst from the body's centre, a push along the killing shot's direction, random spread, gravity, a tumble, and a damped bounce with friction on landing. Each voxel finds the real ground below it with a downward ray that only hits the world, measured again whenever it moves sideways on the way down, so voxels knocked off the raised platform fall to the floor beneath it and voxels flying over a higher surface land on top of it. Voxels shrink and fade along a power curve, and the effect frees itself once the last one is gone.
- **The dummy**, `scripts/target_dummy.gd`, is a small state machine. Alive: it takes hits. Derezzing: collision off, body and tag hidden, every hit ignored, and cannon shots pass straight through. Respawning: it grows back in its own spot, still not hittable. Then alive again at full health.
- **Tuning**, `scripts/derezz_tuning.gd` with `resources/derezz.tres`: the voxel cap, size and colours, the burst, push and spread, gravity, bounce, friction and the ground layers, the tumble, the lifetime and fade curve, the respawn delay and the regrow time.

The kill feed is not part of this chunk; it arrives with synced combat (C14). Like the rest of the look, the derezz has only run headless so far. Under `--headless` Godot keeps no MultiMesh data to read back, so the test checks the voxel state, and through a test hook the transform and colour each frame builds from it for the MultiMesh. Whether they reach the screen, and how it looks, stays unverified until the first windowed capture.

### Built: code rain on the walls

- **The shader**, `shaders/code_rain.gdshader`. Every greybox block but the floor carries it: the neon edge look, plus Matrix glyph streams that bleed through the block when a daemon is near. With no enemy in reach it produces exactly the neon edge result. The glyphs are original and procedural, no fonts or textures: each face is cut into a world-space grid of glyph cells, so streams run across block seams; each column rolls a hash for whether it carries a stream, its speed and its phase; a stream is a bright leading glyph, a fading tail and a dark gap, stepping down one cell at a time like the film; each glyph is a four by six bit grid mirrored left to right so it reads like a character, re-rolled a few times a second.
- **Reach** is per pixel. The shader holds up to eight enemies, each a world position and a weight, and every pixel measures its own distance to each one: a share that fades to nothing at the falloff radius, combined like independent chances so two enemies never push it past full. The rain pools on the part of a wall nearest the enemy, on both sides of it, which is what makes it bleed through.
- **The driver**, `scripts/code_rain_driver.gd`, one node in the arena. It fills the enemy slots from the live target dummies and uploads them to every block material as one small uniform array. The weight is the part that moves in time: it climbs at the fade-in rate while the dummy is alive and falls at the fade-out rate once it derezzes, so the rain never pops and never overshoots; distance does the rest in the shader. When more enemies are alive than the slots hold, the nearest to the player win. It runs at the fixed physics rate. It collects the blocks and targets again only when one enters or leaves the tree or a block rebuilds its material, and that collection is the one place it allocates or uploads unconditionally; an ordinary tick allocates nothing and uploads nothing when no slot changed.
- **Tuning**, `scripts/code_rain_tuning.gd` with `resources/code_rain.tres`: the falloff radius, the minimum and maximum intensity, the enemy cap, the fade-in and fade-out rates, column density, glyph size, the fall speed range, tail length, flicker rate, brightness, and the head and tail colours, which default to the palette's Matrix green.

Like the rest of the look, the rain has only run headless so far: the shader compiles under the dummy renderer, and the test checks GDScript mirrors of the falloff maths and the glyph hash, which prove the design and the numbers the driver uploads, not the pixels the shader draws. Nobody has seen a glyph on a real screen. The look, the glyph density and the brightness stay unverified until the first windowed capture. Code-rain vision (C21), seeing enemies through walls, and bullet time with motion trails (C18) build on this.

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

Today's targets are greybox hexagonal prisms with red neon edges, tagged with invented process names. They already die the way daemons will: a voxel derezz (C7).

## Multiplayer (planned)

> **Status: Planned** (M3: C13, C14, C15). No networking code exists yet.

Multiplayer has to just work: join by a 6-character room code or a `sigkill://` invite link, with no port forwarding.

```mermaid
flowchart LR
    A["Player A"] -->|"LAN or tailnet: direct, ENet"| B["Player B"]
    A -->|"room code"| M["Matchmaking and relay service<br/>planned, hosting not decided"]
    B -->|"room code"| M
    A -.->|"internet: NAT punch-through, WebRTC data channel"| B
    M -.->|"fallback relay"| B
```

- **LAN and tailnet mode (C13):** instant play between machines on the same network, host and join by address.
- **Synced combat (C14):** shooting, damage, respawn and the kill feed.
- **Room codes and invite links (C15):** peer-to-peer over the internet with NAT punch-through, plus a tiny matchmaking and relay service for "find me an opponent" and as a fallback.
- **Built on Godot's high-level multiplayer:** ENet for direct play and WebRTC data channels for punch-through.
- **Hosting cost is Fred's call** before anything is deployed; nothing runs on a server today.

## Architecture

### Project tree

The project layout, from `git ls-files`. Godot also keeps a small `.uid` file next to each script and shader, and the media folder under docs holds the README images.

```text
sigkill/
├── README.md                   This page
├── .gitignore                  Keeps Godot's cache and build output out of git
├── CREDITS.md                  Contributors and community prompts
├── project.godot               Godot 4.7 project: main scene, physics layer names, Forward+, black clear colour
├── scenes/
│   ├── boot.tscn               The boot screen, the main scene: AI link, opt-in, GPU readout, then the arena
│   ├── main.tscn               Root level: sun light, arena, player and HUD
│   ├── arena.tscn              Greybox arena, its WorldEnvironment, the four target dummies and the code rain driver
│   ├── player.tscn             First-person player: capsule, head, camera, muzzle marker, both tuning resources
│   ├── grey_block.tscn         One greybox building block
│   ├── target_dummy.tscn       Hexagonal-prism target dummy with a floating tag
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
│   │   └── guide_settings.gd       The AI opt-in answer, kept in user://settings.cfg and read strictly
│   ├── main.gd                 Wires targets, player, HUD and the rain driver, applies palette colours, R respawns targets
│   ├── player.gd               Movement, slide, head bob, FOV kick, mouse look, cannon, recoil, the test hook
│   ├── controls.gd             The input map, registered in code
│   ├── movement_tuning.gd      MovementTuning: the exposed movement and camera tuning, validated
│   ├── weapon_tuning.gd        WeaponTuning: the exposed cannon tuning, validated
│   ├── derezz_tuning.gd        DerezzTuning: the exposed derezz and respawn tuning, validated
│   ├── code_rain_tuning.gd     CodeRainTuning: the exposed code rain tuning, validated
│   ├── guide_tuning.gd         GuideTuning: the guide's switch, pacing, timeouts and caps, validated
│   ├── palette.gd              Every colour, plus the material factory
│   ├── grey_block.gd           Builds a block's mesh, collision and material; registers for code rain; previews in the editor
│   ├── target_dummy.gd         Dummy state machine: takes hits, derezzes, respawns at full health
│   ├── derezz_fx.gd            The derezz: capped voxels in one MultiMesh per death; self-freeing
│   ├── code_rain_driver.gd     Feeds live enemy positions and faded weights to the code rain shader
│   ├── hud.gd                  Status line, hint line, click-to-engage overlay, crosshair and hit marker
│   ├── crosshair.gd            Crosshair drawn in code; kicks on every shot
│   ├── hit_marker.gd           Diagonal hit marker, shown only on a confirmed hit
│   ├── cannon_fx.gd            Beam, muzzle flash and light, impact flash and sparks; all self-freeing
│   ├── sfx_synth.gd            Fire and hit sounds synthesised in code
│   └── check.sh                The headless quality gate
├── shaders/
│   ├── floor_grid.gdshader     World-space glowing floor grid
│   ├── neon_edge.gdshaderinc   The neon edge maths, shared by the two shaders below
│   ├── neon_edge.gdshader      Neon outline edges for boxes and hexagonal prisms; the dummies' look
│   └── code_rain.gdshader      Neon edges plus Matrix code rain near enemies; the blocks' look
├── resources/
│   ├── movement_tuning.tres    Default movement tuning
│   ├── terminal_cannon.tres    Default terminal cannon tuning
│   ├── derezz.tres             Default derezz tuning
│   ├── code_rain.tres          Default code rain tuning
│   ├── guide.tres              Default guide tuning, AI off
│   └── boot.tres               Default boot screen tuning
├── tests/
│   ├── movement_test.gd        Headless movement test
│   ├── cannon_test.gd          Headless cannon test
│   ├── derezz_test.gd          Headless derezz test
│   ├── code_rain_test.gd       Headless code rain test
│   ├── ai_detector_test.gd     Headless AI detector test, fakes only
│   ├── guide_adapter_test.gd   Headless guide adapter test, stubs and a fake server only
│   ├── boot_sequence_test.gd   Headless boot sequence test, spies, stubs and a fake server only
│   └── fixtures/ai/            Fake agent settings, PATH, /sys and stubs for the AI tests, with a README.md
│       └── guide/              Stub claude and codex CLIs that record how they were launched
└── docs/
    ├── PRD.md                  Product requirements: features, safety rules, chunk plan
    ├── DESIGN.md               Decisions log and design notes
    ├── ENGINE.md               Why Godot 4
    └── media/                  README art; .gdignore keeps Godot from importing it
```

### Tuning resources

Feel is data, not code. Six custom resources hold the exposed tuning parameters for player movement, the camera, the cannon, the derezz, the code rain, the AI guide and the boot screen, each with a default instance: the player scene loads the first two, every target dummy loads the derezz tuning, the arena's rain driver loads the code rain tuning, the guide adapters load the guide tuning, and the boot screen loads its own. Some numbers live elsewhere on purpose or for now: gravity comes from the project settings, the player's collision capsule from its scene, and HUD sizes and the dummies' hit pulse from their own scripts.

- **MovementTuning**, `scripts/movement_tuning.gd` with `resources/movement_tuning.tres`. Groups: Ground, Air, Slide, Camera, Head bob, World. Walk speed, acceleration and friction, gravity scale, jump, air control, the whole slide (threshold, burst, friction, timer, cooldown, slide-jump cap, lowered camera), mouse sensitivity and pitch limit, FOV and its kick, head bob and its on/off toggle, fall respawn height.
- **WeaponTuning**, `scripts/weapon_tuning.gd` with `resources/terminal_cannon.tres`. Groups: Firing, Viewmodel, Recoil, Beam, Muzzle flash, Impact, Hit marker, Audio. Cooldown, range, damage and hit layers, the cannon's size and kick, recoil and its caps and recovery, every effect's size, brightness and lifetime, the hit marker, and every parameter of the synthesised sounds including a master volume.
- **CodeRainTuning**, `scripts/code_rain_tuning.gd` with `resources/code_rain.tres`. Groups: Reach, Fade, Glyphs, Colours. The falloff radius, the minimum and maximum intensity, the enemy cap, the fade-in and fade-out rates, column density, glyph size, fall speed range, tail length, flicker rate, brightness, head and tail colours.
- **DerezzTuning**, `scripts/derezz_tuning.gd` with `resources/derezz.tres`. Groups: Voxels, Motion, Fade, Respawn. The voxel cap and size, the share that glows red and the obsidian tint, glow brightness, burst, upward and shot-push speeds, spread, gravity, bounce, ground friction and the ground layers, the tumble range, the shortest and longest voxel life and the fade curve, the respawn delay and the regrow time.
- **GuideTuning**, `scripts/guide_tuning.gd` with `resources/guide.tres`. Groups: Switch, Pacing, Limits. The AI on/off switch (shipped off), the shortest time between two requests, the agent and local server timeouts, the typed text, answer, agent output and local response caps, and the most tokens asked of a local model per answer.
- **BootTuning**, `scripts/boot/boot_tuning.gd` with `resources/boot.tres`. Groups: Typing, Handshake, Readout, Handoff, Text, Colours. Typing speed and the pause between lines, the spinner's pace, the demo handshake's wait and latency, the GPU interval (never under 1 second), the wait before the arena, the title, line and hint sizes, the hint's opacity, and the title, text, prompt and warning colours.

All six resources validate themselves on load with `problems()`. If a value would break the game, for example a negative easing rate, a voxel cap of zero, a fade rate of zero, a guide timeout of zero or a typing speed of zero, the player, the dummy, the rain driver, the guide adapter or the boot screen prints a warning and falls back to the built-in defaults instead of misbehaving. `scripts/player.gd` itself holds no movement or cannon numbers at all, and every material colour comes from `scripts/palette.gd`.

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

It fails on any parse error, any `ERROR` or `SCRIPT ERROR` line in Godot's output, or a nonzero Godot exit. Exit 0 means clean, 1 means a problem was found, 2 means the gate itself could not run. It also takes a project directory, which is how deliberately broken copies are checked.

The tests are SceneTree scripts that drive the real scenes through a one-frame input hook on the player, `drive_input()`, with `--fixed-fps 60` so every run is deterministic and faster than real time:

- **Movement test.** A flat floor and the real player scene. Measures the start and the stop in frames, repeats them at 60 Hz and 120 Hz to prove nothing depends on the frame rate, and covers the slide (threshold, burst, timer, cooldown boundary, same-frame jump), slide-jump momentum, air control, head bob scaling and its toggle, the FOV kick, and the tuning fallback.
- **Cannon test.** The real main scene. Fires at the real dummy, then the wall behind it, then the open sky, and checks the hit, the hit marker, recoil and its recovery at 60 Hz and 120 Hz, each effect's own lifetime, misses without a marker, the cooldown boundary, the pitch clamp including mouse look, the synthesised sounds, the tuning fallback, and that no orphan nodes are left behind.
- **Derezz test.** The real main scene. Kills a real dummy with the real cannon and checks the state machine, collision, the voxel cap, the burst and the fade, the effect freeing itself on time, hits ignored while derezzing and while respawning, and the respawn at full health in the same spot. It also runs one seeded derezz at 30 and at 144 frames per second and requires identical voxels. It checks that the voxels follow the shot's own direction, both from a real cannon shot grazing a dummy's side and from a direct hit, and that voxels knocked off the raised platform settle on the floor below and never in mid-air. Finally it runs 20 rapid kill cycles with no leaked or orphaned nodes, and confirms every tuning resource file lists every tunable of its script.
- **Code rain test.** The shader and tuning load and validate, then the real main scene: every block but the floor carries the rain shader and receives the tuning and the enemy slots; with no enemy the intensity is the minimum, at an enemy the maximum, at the radius nothing, and it never rises with distance; the rain fades in and out at the tuned rates, converges exactly and never overshoots; a derezzed dummy stops counting and a respawned one counts again; more enemies than the cap stay bounded, nearest to the player first; a settled arena uploads nothing. Headless Godot cannot read a shader's pixels, so the test checks GDScript mirrors of the falloff maths and the glyph hash instead; the shader itself is only known to compile.
- **AI detector test.** Fakes only. A scan of the detector's source proves its one program start is the nvidia-smi query and its one connection goes to 127.0.0.1, and that outside scripts/ai only the boot screen uses it. Then every agent-setting case, the command check against a fake PATH (with a stub agent that fails the test if it is ever run), a fake model server that answers, lists nothing or hangs, a closed port, a fake /sys and a stub nvidia-smi whose recorded arguments must be exactly the query, the once-a-second limit, the fallback order across combinations, the worker thread, and that no result ever holds a path, a user or host name, or a model name.
- **Guide adapter test.** Fakes only. Stub `claude` and `codex` scripts record their arguments, PID, working folder and stdin, and a fake model server on a random local port records every request. A scan of the guide's source, comments left out, proves there is no shell, no `omarchy-agent`, one program start, only guarded stops of the game's own child, and no pull, delete, `num_ctx`, `options` or `keep_alive`. Then: the request whitelist drops a seeded fake path, host name, process name and user; each agent's arguments are exactly the documented flags, with every forbidden flag absent; Codex gets the empty scratch folder and a closed stdin; ANSI escapes, control bytes and floods are cut down, and 64 KiB of padding followed by a sentinel proves nothing past the cap is ever read; a hung stub is stopped at the timeout by its own PID while a bystander stub keeps running; cancel and a guide freed mid-request stop their child; the rate limit (with a fake clock), one request in flight and AI off; the local adapter's loopback refusal, loaded model, LM Studio's loaded and unloaded models under just-in-time loading, `needs_consent` with no chat request and `/v1/models` never asked, exact request body, tokens per second, hostile, truncated and broken answers, and a server that never answers; the registry's fallback order; and that no result holds a path, a user or host name, the server address or a model name.

Before a test is trusted, deliberately broken copies of the project prove it can fail: no friction, a missing slide timer, a hit marker that never shows, effects that never free, a cooldown cut short, a dummy that stays solid while it derezzes, voxel motion that changes with the frame rate, voxels resting on air past a ledge, rain that never fades out, an enemy cap ignored, a detector that runs the agent's command or an extra nvidia-smi flag, a hung agent reported as anything but a timeout, a boot screen with its headless guard removed (the fixtures' agent stub then runs and leaves its mark), and more. Each one makes `scripts/check.sh` exit 1.

### The Codex bug run

Every chunk ends with a second opinion. After the gate passes, the chunk's diff goes to the Codex CLI, run non-interactively in a read-only sandbox, with a prompt to hunt bugs, Godot API misuse, frame-rate dependence, edge cases and safety-rule violations. Real findings get fixed and the gate is re-run; findings that are rejected are written down with the reason. When the fixes are substantial, Codex reviews the fixes too. Codex never gets write access, never commits and never pushes.

### The chunk pipeline

SIGKILL is built one small numbered chunk at a time, from the PRD. Every chunk goes through the same path before it lands.

```mermaid
flowchart LR
    PRD["docs/PRD.md"] --> Chunk["Numbered chunk brief"]
    Chunk --> Build["Larry builds it"]
    Build --> Check["scripts/check.sh<br/>parse, headless import, headless run"]
    Check --> Codex["Codex bug run<br/>read-only sandbox"]
    Codex -- real findings --> Build
    Codex --> Commit["Commit, push to main"]
    Commit --> Audit["Producer audit"]
    Audit --> Chunk
```

### Docs

- [`docs/PRD.md`](docs/PRD.md): what we are building, the hard safety rules, the chunk plan
- [`docs/DESIGN.md`](docs/DESIGN.md): decisions log and design notes
- [`docs/ENGINE.md`](docs/ENGINE.md): why Godot 4
- [`CREDITS.md`](CREDITS.md): who made what, including community prompts

## Install and play

Runs from source today. Packaged builds (AppImage, AUR) are planned and not available yet. Nothing is published.

**Requirements**

- Godot 4.x from pacman (the project is built against 4.7)
- A Vulkan-capable GPU and driver
- git
- For running the checks: `uvx`, which fetches the GDScript parser, unless `gdparse` is already installed
- Optional: an AI guide. The boot screen uses your Omarchy default agent (Claude Code and Codex so far), with a local model server such as Ollama or LM Studio as the fallback, and asks you before the first call

**Quickstart (Omarchy / Arch)**

```bash
sudo pacman -S --needed godot git
git clone https://github.com/nixfred/sigkill.git   # private for now, ask for access
cd sigkill
godot --path .
```

The game opens on the boot screen. It names your AI, asks once before calling it (Y allows, N keeps it off), then moves on to the arena; Esc or Enter skips straight there. Two launch options, after `--`:

```bash
godot --path . -- --demo    # demo data only: nothing read from your machine, no AI called
godot --path . -- --no-ai   # the boot screen without any AI link
```

Click into the window to grab the mouse. Esc gives it back, and so does switching away from the window.

### Controls

Bindings are registered in code in `scripts/controls.gd`, with mouse look and the click-to-engage rule in `scripts/player.gd`. There are no Ctrl, Alt or Super chords.

| Input | Action |
|---|---|
| W / A / S / D, or the arrow keys | Move |
| Mouse | Look |
| Space | Jump |
| C | Slide, when running fast on the ground. Jump during a slide to keep its speed |
| Left click | Fire the terminal cannon (the first click only grabs the mouse) |
| R | Respawn all targets |
| Esc | Release the mouse |
| Esc or Enter, on the boot screen | Skip to the arena |
| Y or N, on the boot screen | Allow the AI guide, or keep it off |

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
```

## Safety and privacy

These rules apply to every chunk, from PRD section 6, in plain language:

- **SIGKILL never changes your system.** It never modifies, deletes, executes, signals or kills anything on your machine, with one exception: it stops the agent process it launched itself, by that process's own PID, on a timeout, a cancel or exit. Everything it looks at is read-only: folder and process names, sizes and counts for the machine-world features; process IDs, parent process IDs and CPU and memory numbers for the Audit Trail visor; modification times, uptime and theme colours for the opener; GPU utilisation, VRAM and temperature for the HUD; model names and whether they are loaded, for the local AI fallback. It never reads what is inside your files, with one narrow exception: the single line of Omarchy's default-agent setting, read to find your AI.
- **Two narrow exceptions, and nothing else.** First, the game may launch your Omarchy default agent's own command-line tool in its non-interactive mode, with tools, file edits and shell disabled, no auto-approve flags, never through `omarchy-agent`, and with only game stats and what you type in the prompt. Second, for the HUD's GPU stats, it may run an optional, query-only `nvidia-smi --query-gpu=<fields> --format=csv,noheader`, never with control flags; it prefers reading /sys, and if neither works the HUD hides GPU stats. Nothing else is ever executed.
- **Asked first, and never in a test.** The AI is called only after you say yes on the boot screen, for that agent or server. Headless runs and `--no-ai` never call it, whatever was saved.
- **One thing outside the game's own code.** The Godot engine itself, at startup, runs `xdg-user-dir DESKTOP` through `sh` and connects to the D-Bus session and system buses. It does this for any project, even an empty one (seen with strace). SIGKILL's code does neither, and this is noted for the PRD.
- **Nothing private leaves your machine or lands in the repo.** No real paths, hostnames, process lists or model lists in the repository, in screenshots or in trailers. Anything public uses demo data.
- **Your desktop stays yours.** No Ctrl+Alt hotkeys. The mouse is captured only while the window is focused and is released on Esc or when focus leaves. The game never steals focus and uses no GPU when it is not running.
- **The opener plays fair.** Everything that looks hacked is rendered fiction. Esc and the window's close button always work. A one-line content note and an opt-in come first, and saying no gives you the same opener on fake data.
- **Original art and audio.** Today's sounds are synthesised in code, and the repository contains no audio files. Concept art is always labelled as concept art.
- **Private until Fred says otherwise.** Local commits and pushes to a private repository only. Nothing goes public without Fred's yes, and every chunk reports real command output.

## Roadmap

Status from `git log`. Hashes are the commits that finished each chunk.

| Milestone | Chunks | Status |
|---|---|---|
| M0 Foundations | C1 Godot installed, clean headless import (`823de8b`) · C2 quality gate and first Codex bug run (`c26061f`) · C3 private repository (`e57697a`) | ✅ Done |
| M1 Look and feel | C4 Tron environment (`de7c203`) · C4b README graphics (`52383f3`) · C5 movement feel (`c223950`) · C6 terminal cannon feel (`6403dbd`) · C6b this README · C7 derezz deaths on the dummies (`238d3ac`) · C8 code-rain walls (`3ee66b1`) | ✅ Done |
| M2 Your AI | C9 AI source detector (`1bd17b2`) · C9b agent adapters (`f9cf9b4`) · C10 boot sequence (`3184454`) · C11 guide HUD · C12 coaching and roasts | 🔧 In progress |
| M3 Multiplayer | C13 LAN and tailnet · C14 synced combat · C15 room codes, invite links and relay | ⬜ Planned |
| M4 Arsenal and modes | C16 weapon framework and SIGTERM · C17 SIGKILL rail rifle · C18 bullet time · C19 fork bomb · C20 light trails · C21 code-rain vision · C22 root vs user and `sudo` · C23 spectate as top · C24 to C32 the shell-command weapons · C33 unlocks, mods and skins | ⬜ Planned |
| M5 Your machine is the world | Filesystem maps, process enemies, theme levels, keybind gunplay, voice commands, packet tracer arena, split-screen co-op · C43 Audit Trail visor · C44 in-game credits roll (CREDITS.md itself is already in the repo) | ⬜ Planned |
| M6 Story campaign | C34 story bible · C35 mission framework · C36 cyberpunk ruins art kit · C37 first mission · C38 to C42 the opener | ⬜ Planned |

Before M0 came the scaffold (`d086489`), and the decision that the player's AI is the Omarchy default agent landed as its own docs commit (`43b1f74`).

## Credits and community prompts

SIGKILL is built in public, and the full list of who made what lives in [`CREDITS.md`](CREDITS.md).

<p align="center">
  <img src="docs/media/credits-mockup.jpg" alt="A top-style process table on a code-rain background, listing the creator, the builder, the producer and a community contributor as processes, with a kill -9 prompt below"><br>
  <em>Mockup of the in-game credits roll, not in-game footage.</em>
</p>

**Send a prompt.** Anyone can reply to [@NixFred](https://x.com/NixFred) on X with a prompt for the game. If a prompt makes it in, its author is credited in [`CREDITS.md`](CREDITS.md) and in the in-game credits roll, and the feature it became carries a small in-game tag with their handle. Nobody is credited without their own public reply.

**How a public prompt reaches the build.** Every public prompt is reviewed against the [safety rules](#safety-and-privacy) and rewritten into a chunk brief before any of it reaches the build. Raw public text is never passed in.

**The first community feature.** Albert ([@QuantaCortex](https://x.com/QuantaCortex)) pitched the Audit Trail visor: trace every enemy back to its parent process, and sever the spawn chain to change the arena. ⬜ Planned (C43); see [Your machine is the world](#your-machine-is-the-world).

**The credits roll.** A live `top`-style process table on the Tron grid. Every contributor is a process: their handle as the USER, their idea as the COMMAND, the CPU column climbing as their row types in with code rain. Fred is PID 1. It ends with your own kill -9 on the credits process, which derezzes the whole table into voxels. ⬜ Planned (C44).

## Screenshots

Real in-game captures land once the renderer chunks are verified.

Every illustration on this page is concept art or a mockup and is labelled that way; the badges and the hexagon are brand marks. Real captures need a window on screen, so they wait for windowed playtests, and they will use demo data.

<p align="center">
  <img src="docs/media/nixfred-icon.svg" alt="nixfred" width="64" height="64"><br>
  <sub>a nixfred joint</sub><br>
  <sub>Made by Fred Nix. Built chunk by chunk by Larry, produced by SIGKILL bot. Engine: Godot. Art and audio are original; concept art is labelled as concept art.</sub>
</p>
