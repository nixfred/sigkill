extends RefCounted
## Room codes and invite links (C15, PRD 5.1): the 6 characters a host shares so a friend
## can join without an address, and the sigkill://join/<CODE> link that carries one.
##
## The alphabet has no character a person could misread: 2-9 and A-Z without I, L and O
## (no 0, O, 1, I or L), 31 symbols. The last character is a checksum: the weighted sum of
## the six symbol values (weights 6, 5, 4, 3, 2, 1) is a multiple of 31, and because 31 is
## prime, every single mistyped character and every swap of two neighbours is caught here,
## before anything goes over the network. Five free characters give 31^5, about 28.6 million,
## codes.
##
## A code comes from the engine's cryptographic random generator and nothing else: never a
## user or host name, an address or the time. Pure functions: nothing here reads the
## system or opens a socket.

const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const LENGTH := 6
const WEIGHTS := [6, 5, 4, 3, 2, 1]
const BASE := 31
## The largest multiple of 31 a byte can hold: bytes at or above it are thrown away, so
## every symbol is equally likely.
const BYTE_CUTOFF := 248
const RANDOM_BATCH := 16
const LINK_PREFIX := "sigkill://join/"
## The longest text looked at; anything longer is refused unread.
const INPUT_LAST := 64
const EXAMPLE := "ABC23P"

const NOT_A_CODE := "a room code is %d characters, from 2-9 and A-Z without I, L and O"
const BAD_CHARACTER := "a room code uses only 2-9 and A-Z without I, L and O (no 0, O, 1, I or L)"
const TYPO := "room code %s has a typo: check each character"
const NOT_A_LINK := "not a SIGKILL invite: a link is sigkill://join/ and a 6-character room code, like sigkill://join/%s" % EXAMPLE
const LINK_TAIL := "an invite link is sigkill://join/ and the 6-character room code, with nothing after it"
const JOIN_NEEDS := "--join needs a room code or a sigkill://join/ link, like --join %s" % EXAMPLE
const JOIN_TWICE := "--join may be given only once"
const JOIN_FORM := "write --join and the code or link as two words, like --join %s" % EXAMPLE


## A fresh room code from the engine's cryptographic random bytes.
static func generate() -> String:
	var crypto := Crypto.new()
	var symbols := PackedStringArray()
	var weighted := 0
	while symbols.size() < LENGTH - 1:
		for b in crypto.generate_random_bytes(RANDOM_BATCH):
			if b >= BYTE_CUTOFF or symbols.size() == LENGTH - 1:
				continue
			var v := b % BASE
			weighted += WEIGHTS[symbols.size()] * v
			symbols.append(ALPHABET[v])
	symbols.append(ALPHABET[posmod(-weighted, BASE)])
	return "".join(symbols)


## What a person typed, made comparable: spaces, tabs and dashes dropped, upper case.
static func normalize(text: String) -> String:
	return text.left(INPUT_LAST).replace(" ", "").replace("\t", "").replace("-", "").to_upper()


## "" for a well-formed code with a matching checksum, else why not. `code` is normalized.
static func problem(code: String) -> String:
	if code.length() != LENGTH:
		return NOT_A_CODE % LENGTH
	var total := 0
	for i in LENGTH:
		var v := ALPHABET.find(code[i])
		if v < 0:
			return BAD_CHARACTER
		total += WEIGHTS[i] * v
	if total % BASE != 0:
		return TYPO % code
	return ""


## {code} for a room code as typed (spaces, dashes and case forgiven), else {error}.
static func parse_code(text: String) -> Dictionary:
	if text.length() > INPUT_LAST:
		return {"error": NOT_A_CODE % LENGTH}
	var code := normalize(text)
	var why := problem(code)
	return {"error": why} if why != "" else {"code": code}


## {code} for exactly sigkill://join/<CODE> (the code in either case), else {error}.
## Nothing else is accepted: no other scheme or path, no slash, query or fragment after
## the code, no spaces or dashes inside the link.
static func parse_link(text: String) -> Dictionary:
	if text.length() > INPUT_LAST or not text.begins_with(LINK_PREFIX):
		return {"error": NOT_A_LINK}
	var rest := text.substr(LINK_PREFIX.length())
	if rest.length() != LENGTH:
		return {"error": LINK_TAIL}
	var code := rest.to_upper()
	for i in LENGTH:
		if ALPHABET.find(code[i]) < 0:
			# A letter or digit outside the alphabet is a bad code; anything else is a bad link.
			var c := code.unicode_at(i)
			var alnum := (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A)
			return {"error": BAD_CHARACTER if alnum else LINK_TAIL}
	var why := problem(code)
	return {"error": why} if why != "" else {"code": code}


## {code} for a room code or an invite link, else {error}: a link when it says "://".
static func parse_join(text: String) -> Dictionary:
	var s := text.strip_edges()
	if s.contains("://"):
		return parse_link(s)
	return parse_code(s)


## From the game's own command-line arguments (after --): {} when there is no --join,
## {code} for "--join <code or link>", else {error}.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var at := -1
	for i in args.size():
		if args[i] == "--join":
			if at >= 0:
				return {"error": JOIN_TWICE}
			at = i
		elif args[i].begins_with("--join="):
			return {"error": JOIN_FORM}
	if at < 0:
		return {}
	if at + 1 >= args.size() or args[at + 1].begins_with("--"):
		return {"error": JOIN_NEEDS}
	return parse_join(args[at + 1])


## The invite link for `code`.
static func link(code: String) -> String:
	return LINK_PREFIX + code
