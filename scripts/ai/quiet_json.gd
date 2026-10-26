extends RefCounted
## A JSON reader for local model server answers that never makes Godot print, whatever the
## bytes: Godot's own JSON parser prints on some valid input ("\u0000" escapes, huge
## exponents), and so does String.to_float(). Strings are decoded here, escapes included:
## a lone surrogate or a NUL becomes U+FFFD, so the decoded text is always valid UTF-8.
## Numbers are never converted except plain integers of up to 15 digits; any other number
## reads as null, which is enough for token counts. Depth, string size and item count are
## capped. The input is expected to be the body parse_http_body() already checked as UTF-8.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const MAX_DEPTH := 32
const MAX_STRING_BYTES := 65536
const MAX_ITEMS := 100000
const INT_MAX_DIGITS := 15


## [true, value] for one well-formed JSON document, else [false, null]. Bytes that are not
## well-formed UTF-8, or hold a NUL, are refused before anything is decoded.
static func parse(bytes: PackedByteArray) -> Array:
	if not Detector.is_utf8_text(bytes):
		return [false, null]
	var reader := Reader.new(bytes)
	reader.space()
	var value = reader.value(1)
	reader.space()
	if reader.failed or reader.i != reader.n:
		return [false, null]
	return [true, value]


## value[key] when value is a Dictionary holding that key, else null.
static func field(value: Variant, key: String) -> Variant:
	return value[key] if value is Dictionary and value.has(key) else null


## value[index] when value is an Array that long, else null.
static func item(value: Variant, index: int) -> Variant:
	return value[index] if value is Array and index >= 0 and index < value.size() else null


class Reader:
	extends RefCounted
	const QUOTE := 0x22
	const BACKSLASH := 0x5C
	const CONTROL_LAST := 0x1F
	const SPACE := [0x20, 0x09, 0x0A, 0x0D]
	const SIMPLE := {0x22: 0x22, 0x5C: 0x5C, 0x2F: 0x2F, 0x62: 0x08, 0x66: 0x0C, 0x6E: 0x0A, 0x72: 0x0D, 0x74: 0x09}
	const REPLACEMENT := [0xEF, 0xBF, 0xBD]

	var b: PackedByteArray
	var n := 0
	var i := 0
	var failed := false
	var items := 0
	var _next_quote := -1
	var _next_backslash := -1
	var _next_control := -1
	var _control_at := PackedInt64Array()

	func _init(bytes: PackedByteArray) -> void:
		b = bytes
		n = bytes.size()
		_control_at.resize(CONTROL_LAST + 1)
		_control_at.fill(-1)

	func at() -> int:
		return b[i] if i < n else -1

	func fail() -> Variant:
		failed = true
		return null

	func space() -> void:
		while i < n and SPACE.has(b[i]):
			i += 1

	func value(depth: int) -> Variant:
		if failed or depth > MAX_DEPTH:
			return fail()
		items += 1
		if items > MAX_ITEMS:
			return fail()
		space()
		var c := at()
		if c == 0x7B:
			return object(depth)
		if c == 0x5B:
			return array(depth)
		if c == QUOTE:
			return string()
		if c == 0x74:
			return literal("true", true)
		if c == 0x66:
			return literal("false", false)
		if c == 0x6E:
			return literal("null", null)
		if c == 0x2D or (c >= 0x30 and c <= 0x39):
			return number()
		return fail()

	func object(depth: int) -> Variant:
		var out := {}
		i += 1
		space()
		if at() == 0x7D:
			i += 1
			return out
		while not failed:
			space()
			if at() != QUOTE:
				return fail()
			var key = string()
			if failed:
				return null
			space()
			if at() != 0x3A:
				return fail()
			i += 1
			var v = value(depth + 1)
			if failed:
				return null
			out[key] = v
			space()
			if at() == 0x2C:
				i += 1
				continue
			if at() == 0x7D:
				i += 1
				return out
			return fail()
		return null

	func array(depth: int) -> Variant:
		var out := []
		i += 1
		space()
		if at() == 0x5D:
			i += 1
			return out
		while not failed:
			var v = value(depth + 1)
			if failed:
				return null
			out.append(v)
			space()
			if at() == 0x2C:
				i += 1
				continue
			if at() == 0x5D:
				i += 1
				return out
			return fail()
		return null

	func next_control(from: int) -> int:
		if _next_control >= from:
			return _next_control
		var least := n
		for v in CONTROL_LAST + 1:
			if _control_at[v] < from:
				var found := b.find(v, from)
				_control_at[v] = found if found >= 0 else n
			least = mini(least, _control_at[v])
		_next_control = least
		return least

	func string() -> Variant:
		i += 1
		var out := PackedByteArray()
		while not failed:
			if _next_quote < i:
				_next_quote = b.find(QUOTE, i)
				if _next_quote < 0:
					return fail()
			if _next_backslash < i and _next_backslash != n:
				_next_backslash = b.find(BACKSLASH, i)
				if _next_backslash < 0:
					_next_backslash = n
			var segment_end := mini(_next_quote, _next_backslash)
			if next_control(i) < segment_end:
				return fail()
			out.append_array(b.slice(i, segment_end))
			if out.size() > MAX_STRING_BYTES:
				return fail()
			if _next_quote <= _next_backslash:
				i = _next_quote + 1
				return out.get_string_from_utf8()
			i = _next_backslash + 1
			var e := at()
			if SIMPLE.has(e):
				var decoded: int = SIMPLE[e]
				if decoded < 0x20:
					out.append_array(PackedByteArray(REPLACEMENT) if decoded == 0 else PackedByteArray([decoded]))
				else:
					out.append(decoded)
				i += 1
				continue
			if e != 0x75:
				return fail()
			var code := hex4(i + 1)
			if code < 0:
				return fail()
			i += 5
			if code >= 0xD800 and code <= 0xDBFF and i + 5 < n and b[i] == BACKSLASH and b[i + 1] == 0x75:
				var low := hex4(i + 2)
				if low >= 0xDC00 and low <= 0xDFFF:
					code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
					i += 6
			if code == 0 or (code >= 0xD800 and code <= 0xDFFF):
				out.append_array(PackedByteArray(REPLACEMENT))
			else:
				out.append_array(utf8(code))
		return null

	func hex4(at_index: int) -> int:
		if at_index + 4 > n:
			return -1
		var code := 0
		for k in 4:
			var c := b[at_index + k]
			var digit := -1
			if c >= 0x30 and c <= 0x39:
				digit = c - 0x30
			elif c >= 0x41 and c <= 0x46:
				digit = c - 0x41 + 10
			elif c >= 0x61 and c <= 0x66:
				digit = c - 0x61 + 10
			if digit < 0:
				return -1
			code = code * 16 + digit
		return code

	static func utf8(code: int) -> PackedByteArray:
		if code < 0x80:
			return PackedByteArray([code])
		if code < 0x800:
			return PackedByteArray([0xC0 | (code >> 6), 0x80 | (code & 0x3F)])
		if code < 0x10000:
			return PackedByteArray([0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F)])
		return PackedByteArray([0xF0 | (code >> 18), 0x80 | ((code >> 12) & 0x3F), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F)])

	func number() -> Variant:
		var start := i
		var plain := true
		if at() == 0x2D:
			i += 1
		if at() == 0x30:
			i += 1
		elif at() >= 0x31 and at() <= 0x39:
			while at() >= 0x30 and at() <= 0x39:
				i += 1
		else:
			return fail()
		if at() == 0x2E:
			plain = false
			i += 1
			if not (at() >= 0x30 and at() <= 0x39):
				return fail()
			while at() >= 0x30 and at() <= 0x39:
				i += 1
		if at() == 0x65 or at() == 0x45:
			plain = false
			i += 1
			if at() == 0x2B or at() == 0x2D:
				i += 1
			if not (at() >= 0x30 and at() <= 0x39):
				return fail()
			while at() >= 0x30 and at() <= 0x39:
				i += 1
		var text := b.slice(start, i).get_string_from_ascii()
		var digits := text.trim_prefix("-")
		if plain and digits.length() <= INT_MAX_DIGITS:
			return text.to_int()
		return null  # never converted: Godot's own conversion can print

	func literal(word: String, result: Variant) -> Variant:
		var bytes := word.to_ascii_buffer()
		if i + bytes.size() > n or b.slice(i, i + bytes.size()) != bytes:
			return fail()
		i += bytes.size()
		return result
