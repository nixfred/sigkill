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

## Which AI the guide will use, in the PRD 5.4 fallback order.
enum Source {
	AGENT,  ## the player's Omarchy default agent: KNOWN and its command on the PATH
	LOCAL_SERVER,  ## a local model server on 127.0.0.1 listing at least one model
	SCRIPTED,  ## no AI: the scripted guide, with "AI off"
}

## The choice, and its name: the agent's name, "ollama", "openai-compatible" or "ai-off".
var source: Source = Source.SCRIPTED
var source_name := "ai-off"

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

## GPU stats, read-only. gpu_source is "sysfs", "nvidia-smi" or "none"; when no source
## works, gpu_available is false and the HUD hides GPU stats. A field a source does not
## give is -1. Utilization in percent, memory in MiB, temperature in whole degrees C.
var gpu_available := false
var gpu_source := "none"
var gpu_util_percent := -1
var gpu_vram_used_mib := -1
var gpu_vram_total_mib := -1
var gpu_temp_c := -1


## Copies a GPU reading from AiSourceDetector.poll_gpu() into the gpu_ fields.
func set_gpu(reading: Dictionary) -> void:
	gpu_available = reading.get("available", false)
	gpu_source = reading.get("source", "none")
	gpu_util_percent = reading.get("util_percent", -1)
	gpu_vram_used_mib = reading.get("vram_used_mib", -1)
	gpu_vram_total_mib = reading.get("vram_total_mib", -1)
	gpu_temp_c = reading.get("temp_c", -1)


## Every field as a plain Dictionary, for the string form and for later chunks.
func to_dict() -> Dictionary:
	return {
		"source": {
			"kind": Source.keys()[source].to_lower(),
			"name": source_name,
		},
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
		"gpu": {
			"available": gpu_available,
			"source": gpu_source,
			"util_percent": gpu_util_percent,
			"vram_used_mib": gpu_vram_used_mib,
			"vram_total_mib": gpu_vram_total_mib,
			"temp_c": gpu_temp_c,
		},
	}


func _to_string() -> String:
	return JSON.stringify(to_dict(), "", true)
