extends RefCounted
## Picks the guide adapter for what the C9 detector found, in the PRD 5.4 order: the
## player's Omarchy default agent if it has an adapter here (Claude Code, Codex) and its
## command is on the PATH; otherwise Ollama, then another OpenAI-compatible server, each
## only if it answered and lists a model; otherwise null, which means the scripted guide
## with "AI off". An agent without an adapter here (every other agent Omarchy can name)
## falls through to the local server the same way.

const Found = preload("res://scripts/ai/ai_source_result.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Claude = preload("res://scripts/ai/claude_adapter.gd")
const Codex = preload("res://scripts/ai/codex_adapter.gd")
const Local = preload("res://scripts/ai/local_openai_adapter.gd")

## Agents with an adapter, by the name Omarchy's setting uses.
const AGENT_ADAPTERS := {"claude": Claude, "codex": Codex}


## The adapter for `found` (a C9 result), or null for the scripted guide. `detector` is the
## one that produced it: its PATH lookup gives the agent's absolute path and its ports the
## local servers. The path stays inside the adapter; no result ever carries it.
static func adapter_for(found: Found, detector: Detector, tuning: Resource = null) -> RefCounted:
	if found.agent_state == Found.AgentState.KNOWN and found.agent_cli_present and AGENT_ADAPTERS.has(found.agent):
		var path := detector.find_command(found.agent)
		var agent = AGENT_ADAPTERS[found.agent].new(path, tuning)
		if agent.is_available():
			return agent
	if found.ollama_reachable and found.ollama_model_count > 0:
		var ollama = Local.new(tuning)
		if ollama.configure(Local.KIND_OLLAMA, Detector.LOCALHOST, detector.ollama_port):
			return ollama
	if found.openai_reachable and found.openai_model_count > 0:
		var openai = Local.new(tuning)
		if openai.configure(Local.KIND_OPENAI, Detector.LOCALHOST, detector.openai_port):
			return openai
	return null
