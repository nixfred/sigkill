extends "res://scripts/ai/agent_adapter.gd"
## The player's Claude Code CLI as the guide: its own print mode, every tool off, no
## permission bypass. Each flag and the `claude --help` line (Claude Code 2.1.310) it
## relies on:
##   -p                         "-p, --print  Print response and exit (useful for pipes)"
##   --tools ""                 "--tools <tools...> ... Use "" to disable all tools"
##   --permission-mode dontAsk  "--permission-mode <mode>  Permission mode ... (choices:
##                              "acceptEdits", "auto", "bypassPermissions", "manual",
##                              "dontAsk", "plan")": deny anything not pre-approved, never
##                              acceptEdits, auto or bypassPermissions
##   --permission-prompts none  ""none" (nobody: anything that would prompt is denied
##                              automatically ...)"
##   --strict-mcp-config        "Only use MCP servers from --mcp-config, ignoring all other
##                              MCP configurations"; no --mcp-config is given, so none run
##   --safe-mode                "Start with all customizations (CLAUDE.md, skills, installed
##                              plugins, hooks, MCP servers, custom commands and agents ...)
##                              disabled ... Auth, model selection ... work normally"
##   --disable-slash-commands   "Disable all skills and commands"
##   --no-session-persistence   "Disable session persistence - sessions will not be saved to
##                              disk and cannot be resumed (only works with --print)"
##   --output-format text       "Output format (only works with --print): "text" (default)"
##   --system-prompt <preamble> "System prompt to use for the session": it replaces the
##                              default one, so the per-machine sections (working
##                              directory, environment, memory paths, git status) are
##                              never sent; only the game's fixed preamble is
## The prompt is the last argument, one element, and always starts with "Game stats:", so
## it can never be read as an option; stdin is left alone and nothing is written to it.

const COMMAND := "claude"
const Request = preload("res://scripts/ai/guide_request.gd")
const FLAGS: PackedStringArray = [
	"-p",
	"--tools", "",
	"--permission-mode", "dontAsk",
	"--permission-prompts", "none",
	"--strict-mcp-config",
	"--safe-mode",
	"--disable-slash-commands",
	"--no-session-persistence",
	"--output-format", "text",
]


func adapter_name() -> String:
	return COMMAND


func arguments(request: RefCounted, _workdir: String) -> PackedStringArray:
	var args := FLAGS.duplicate()
	args.append_array(PackedStringArray(["--system-prompt", Request.PREAMBLE, request.user_message()]))
	return args
