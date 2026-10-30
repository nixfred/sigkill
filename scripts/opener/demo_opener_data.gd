class_name DemoOpenerData
extends OpenerData
## The opener's demo data (C38): fixed, invented values that look like someone's machine and are nobody's. Nothing
## is read: no file, folder, environment variable, clock, process or theme. Every capture and trailer uses it (PRD
## 5.7: "Demo-data mode for every capture; trailers never show real machine data"), and C39 falls back to it.

const USER := "user"
const HOST := "workstation"
## Invented folders, a home folder's worth: its usual ones, then the kind of names people keep. One foreshadows the
## node_modules pit (C40).
const FOLDERS := [
	".config", ".local", ".cache", "Documents", "Downloads", "Music", "Pictures", "Videos",
	"dotfiles", "notes", "code", "code/homelab", "code/rust-playground", "code/half-finished-game",
	"code/website-redesign", "code/website-redesign/node_modules", "screenshots", "wallpapers", "recipes",
	"taxes-2024", "resume-final-v3", "old-laptop-backup", "keyboard-firmware", "dnd-campaign", "photos-unsorted",
	"games", "backups", "scratch",
]
## Up 3 days, 7 hours, 42 minutes and 15 seconds.
const UPTIME_S := 3 * 86400 + 7 * 3600 + 42 * 60 + 15
## "Now": Tuesday 2025-11-04, 22:17. A fixed date, never the clock.
const NOW := {"year": 2025, "month": 11, "day": 4, "hour": 22, "minute": 17, "second": 0}
## Recent file times: one at 03:12 that night (the late hour the line is built from), and ordinary ones.
const FILE_TIMES := [
	{"year": 2025, "month": 11, "day": 4, "hour": 18, "minute": 22, "second": 3},
	{"year": 2025, "month": 11, "day": 4, "hour": 13, "minute": 5, "second": 31},
	{"year": 2025, "month": 11, "day": 4, "hour": 3, "minute": 12, "second": 44},
	{"year": 2025, "month": 11, "day": 3, "hour": 23, "minute": 41, "second": 9},
	{"year": 2025, "month": 11, "day": 2, "hour": 1, "minute": 58, "second": 20},
]

## The demo palette shown (one of OpenerPalette.IDS); the captures go through all of them.
var palette_id := OpenerPalette.DEFAULT_ID


func kind() -> String:
	return "demo"


func user() -> String:
	return USER


func host() -> String:
	return HOST


func palette() -> OpenerPalette:
	return OpenerPalette.named(palette_id)


func folders() -> PackedStringArray:
	return PackedStringArray(FOLDERS)


func uptime_s() -> int:
	return UPTIME_S


func file_times() -> PackedInt64Array:
	var out := PackedInt64Array()
	for when in FILE_TIMES:
		out.append(Time.get_unix_time_from_datetime_dict(when))
	return out


func now() -> int:
	return Time.get_unix_time_from_datetime_dict(NOW)
