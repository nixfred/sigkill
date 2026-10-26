extends "res://scripts/ai/agent_adapter.gd"
## The player's Codex CLI as the guide: `codex exec` in a read-only sandbox, no approval
## bypass, the shell tools switched off. Each flag and the `codex exec --help` line
## (codex-cli 0.164.0) it relies on:
##   exec                       "Run Codex non-interactively"
##   --sandbox read-only        "-s, --sandbox <SANDBOX_MODE>  Select the sandbox policy ...
##                              [possible values: read-only, workspace-write,
##                              danger-full-access]": read-only, never the other two
##   --skip-git-repo-check      "Allow running Codex outside a Git repository" (the scratch
##                              directory is not one)
##   --ephemeral                "Run without persisting session files to disk"
##   --ignore-user-config       "Do not load `$CODEX_HOME/config.toml`; auth still uses
##                              `CODEX_HOME`": none of the player's MCP servers or tool
##                              settings load
##   --ignore-rules             "Do not load user or project execpolicy `.rules` files"
##   --color never              "Specifies color settings for use in the output"
##   --disable shell_tool       "--disable <FEATURE>  Disable a feature (repeatable).
##   --disable unified_exec     Equivalent to `-c features.<name>=false`". The two feature
##                              names come from third-party documentation of Codex's
##                              feature flags, not from --help, and are unverified here:
##                              running `codex features list` is outside this chunk. If
##                              Codex rejects a name it fails, and the adapter reports an
##                              error: a safe failure.
##   --config include_environment_context=false
##                              "-c, --config <key=value>  Override a configuration value
##                              that would otherwise be loaded from" the Codex config file:
##                              without it Codex adds its own environment note to the
##                              prompt (working directory, shell, date), and the working
##                              directory's path names the player's home folder. The key
##                              name is not in --help; it was read from the field names in
##                              the codex-cli 0.164.0 binary, without running it, and its
##                              effect is unverified until Fred allows a real run.
##   --cd <scratch dir>         "-C, --cd <DIR>  Tell the agent to use the specified
##                              directory as its working root": the empty directory
##   --output-last-message <f>  "-o, --output-last-message <FILE>  Specifies file where the
##                              last message from the agent should be written": a file
##                              the game owns, outside the scratch directory
## The prompt is the last argument, one element, starting with the preamble.
##
## stdin: the help says "If stdin is piped and a prompt is also provided, stdin is appended
## as a `<stdin>` block", so Codex reads piped stdin to its end, and Godot's pipe never ends
## while it is open. The game therefore closes it at once. Godot's pipe has one handle for
## stdin and stdout, so this closes Codex's stdout too; the answer comes from the
## --output-last-message file instead, and counts even if Codex then dies writing to the
## closed stdout.

const COMMAND := "codex"
const ANSWER_FILE := "codex-answer.txt"
const FLAGS: PackedStringArray = [
	"exec",
	"--sandbox", "read-only",
	"--skip-git-repo-check",
	"--ephemeral",
	"--ignore-user-config",
	"--ignore-rules",
	"--color", "never",
	"--disable", "shell_tool",
	"--disable", "unified_exec",
	"--config", "include_environment_context=false",
]


func adapter_name() -> String:
	return COMMAND


func closes_stdin() -> bool:
	return true


## Where Codex writes its answer: in the game's guide folder, outside the working directory.
func answer_path() -> String:
	return ProjectSettings.globalize_path(scratch_root.path_join(ANSWER_FILE))


func arguments(request: RefCounted, workdir_path: String) -> PackedStringArray:
	var args := FLAGS.duplicate()
	args.append_array(PackedStringArray(["--cd", workdir_path, "--output-last-message", answer_path(), request.full_prompt()]))
	return args


## Empties the answer file before the launch, so an old answer can never be read back.
func _prepare(_dir: String) -> String:
	var file := FileAccess.open(answer_path(), FileAccess.WRITE)
	if file == null:
		return "launch_failed"
	file.close()
	return ""


func _finish(process: Process) -> Dictionary:
	var answer := ""
	var file := FileAccess.open(answer_path(), FileAccess.READ)
	if file != null:
		answer = clean_answer(file.get_buffer(stdout_cap()), _t.answer_max_chars)
		file.close()
	if answer != "":
		return result(true, answer, "")
	return result(false, "", "agent_error" if process.exit_code != 0 else "empty")
