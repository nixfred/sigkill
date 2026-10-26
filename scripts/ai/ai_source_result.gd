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


## Every field as a plain Dictionary, for the string form and for later chunks.
func to_dict() -> Dictionary:
	return {
		"agent": {
			"state": AgentState.keys()[agent_state].to_lower(),
			"name": agent,
		},
	}


func _to_string() -> String:
	return JSON.stringify(to_dict(), "", true)
