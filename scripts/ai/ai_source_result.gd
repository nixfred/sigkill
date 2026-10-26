extends RefCounted
## What scripts/ai/ai_source_detector.gd found: which AI the game can talk to, and what GPU
## stats it can show. Plain data, no behaviour. Every field is a fixed word, a known agent
## name from the detector's list, or a number. It never holds a path, a hostname, a user
## name, a model name, or the raw text of the agent setting; to_dict() and the string form
## show exactly the fields below.

## What Omarchy's default-agent setting said.
enum AgentState {
	UNSET,  ## no usable setting: missing, empty, unreadable, oversized or not text
	KNOWN,  ## one of the agents the detector knows; its name is in `agent`
	UNKNOWN,  ## set, but to something the detector does not know; the value is not kept
}

## Omarchy default-agent setting.
var agent_state: AgentState = AgentState.UNSET
## The agent's name when agent_state is KNOWN, otherwise empty.
var agent := ""
## Whether that agent's command is on the player's PATH: a file there with an execute bit.
## Only looked for when the agent is KNOWN; the command is never run.
var agent_cli_present := false

## Ollama on localhost: whether it answered, how fast, and how many models it lists.
## Latency and count are -1 when unknown. Model names are never kept.
var ollama_reachable := false
var ollama_latency_ms := -1
var ollama_model_count := -1
## A local OpenAI-compatible server (LM Studio and others), the same three facts.
var openai_reachable := false
var openai_latency_ms := -1
var openai_model_count := -1


## Every field as a plain Dictionary, for the string form and for later chunks.
func to_dict() -> Dictionary:
	return {
		"agent": {
			"state": AgentState.keys()[agent_state].to_lower(),
			"name": agent,
			"cli_present": agent_cli_present,
		},
		"local_servers": {
			"ollama": {
				"reachable": ollama_reachable,
				"latency_ms": ollama_latency_ms,
				"model_count": ollama_model_count,
			},
			"openai_compatible": {
				"reachable": openai_reachable,
				"latency_ms": openai_latency_ms,
				"model_count": openai_model_count,
			},
		},
	}


func _to_string() -> String:
	return JSON.stringify(to_dict(), "", true)
