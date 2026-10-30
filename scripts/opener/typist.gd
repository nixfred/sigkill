class_name Typist
extends RefCounted
## Human typing for the opener's fake terminal (C38): turns a line into the keystrokes a person would make and
## when, so text "types itself" the way a hand types, never at a machine's even beat. Every key waits its own time
## (a jitter round the pace), a word's first key hesitates, punctuation comes a little late, and now and then two
## keys roll out fast together. A line is segments: a String types, a float waits that many seconds (the beat
## before a punchline), and typo() mistypes, notices, and backspaces to carry on. Seeded, so the same line with the
## same seed types the same way every time (the tests count frames). C41 and C42 reuse it for the copy's lines.

## The key a backspace is, in a plan.
const BACKSPACE := "\b"
## A key's wait is the pace times SPREAD_LOW plus up to SPREAD more, at random.
const SPREAD_LOW := 0.55
const SPREAD := 0.9
## The first key of a word waits up to this share of the pace more; a space this share of its wait.
const WORD_START := 0.5
const SPACE_SHARE := 0.8
## Punctuation waits this share of the pace more.
const PUNCTUATION := ".,?!:;"
const PUNCTUATION_LATE := 0.6
## How often a key rolls out fast after the one before, and how fast: this share of the pace.
const ROLL_CHANCE := 0.18
const ROLL := 0.35
## A typo: the pause while the hand notices, and each backspace's wait.
const NOTICE_S := 0.28
const BACK_S := 0.075
## The very first key comes this share of the pace after the line starts.
const FIRST := 0.5


## A typo for a line's segments: types `wrong`, notices, then backspaces `back` keys of it.
static func typo(wrong: String, back: int) -> Dictionary:
	return {"typo": wrong, "back": back}


## The keystrokes for `segments`, typed at `pace` seconds a key on average: [{"at": seconds from the line's start,
## "key": a character or BACKSPACE}], in order.
static func plan(segments: Array, seed: int, pace: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var keys: Array = []
	var at := 0.0
	var prev := " "
	var first := true
	for part in segments:
		if part is float or part is int:
			at += float(part)
			continue
		var text := ""
		var back := 0
		if part is Dictionary:
			text = part.get("typo", "")
			back = part.get("back", 0)
		else:
			text = str(part)
		for i in text.length():
			var key := text[i]
			at += _wait(rng, pace, key, prev, first)
			first = false
			keys.append({"at": at, "key": key})
			prev = key
		if back > 0:
			at += NOTICE_S
			for _i in back:
				at += BACK_S * (0.8 + 0.4 * rng.randf())
				keys.append({"at": at, "key": BACKSPACE})
	return keys


## `keys` squeezed to end within `within_s` seconds, every wait (pauses too) by the same share; as they were if
## they already fit.
static func fit(keys: Array, within_s: float) -> Array:
	var took := duration(keys)
	if took <= within_s or took <= 0.0:
		return keys
	var k := within_s / took
	var out: Array = []
	for key in keys:
		out.append({"at": key["at"] * k, "key": key["key"]})
	return out


## When the last key of `keys` lands.
static func duration(keys: Array) -> float:
	return keys[-1]["at"] if not keys.is_empty() else 0.0


## What `keys` leave on the line.
static func text_of(keys: Array) -> String:
	var out := ""
	for key in keys:
		if key["key"] == BACKSPACE:
			out = out.left(out.length() - 1)
		else:
			out += key["key"]
	return out


## The text of `segments` once typed (a typo's kept part included).
static func text_of_segments(segments: Array) -> String:
	var out := ""
	for part in segments:
		if part is Dictionary:
			var wrong: String = part.get("typo", "")
			out += wrong.left(wrong.length() - int(part.get("back", 0)))
		elif part is String:
			out += part
	return out


static func _wait(rng: RandomNumberGenerator, pace: float, key: String, prev: String, first: bool) -> float:
	if first:
		return pace * FIRST
	if rng.randf() < ROLL_CHANCE:
		return pace * ROLL
	var wait := pace * (SPREAD_LOW + SPREAD * rng.randf())
	if prev == " ":
		wait += pace * WORD_START * rng.randf()
	if key == " ":
		wait *= SPACE_SHARE
	if PUNCTUATION.contains(key):
		wait += pace * PUNCTUATION_LATE
	return wait
