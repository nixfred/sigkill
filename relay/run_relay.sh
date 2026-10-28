#!/usr/bin/env bash
# Runs the SIGKILL relay (docs/RELAY.md) in the foreground under a headless Godot 4.7.
#
#   relay/run_relay.sh [flags]          flags as in relay/relay_main.gd, e.g. --port 9010
#
# Settings: SIGKILL_RELAY_* environment variables or flags (a flag wins). With none set the
# relay listens on 127.0.0.1:9010 only; a server sets SIGKILL_RELAY_BIND=* itself.
# SIGKILL_GODOT names the Godot binary (default: godot on the PATH). Godot keeps its own log
# file in the runtime directory (systemd's RuntimeDirectory, a tmpfs wiped at stop, else
# XDG_RUNTIME_DIR, else /tmp), or SIGKILL_RELAY_LOG: it only ever holds the relay's own
# output, its counter lines, which hold no address. Nothing is installed or enabled here.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${SIGKILL_GODOT:-godot}
command -v "$godot_bin" >/dev/null || { echo "SIGKILL relay: no Godot binary: set SIGKILL_GODOT to a Godot 4.7 binary" >&2; exit 2; }
[ -f "$here/project.godot" ] && [ -f "$here/relay/relay_main.gd" ] || { echo "SIGKILL relay: run this from a copy of the SIGKILL project" >&2; exit 2; }

log_file=${SIGKILL_RELAY_LOG:-${RUNTIME_DIRECTORY:-${XDG_RUNTIME_DIR:-/tmp}}/sigkill-relay.log}

exec "$godot_bin" --headless --log-file "$log_file" --path "$here" --script res://relay/relay_main.gd -- "$@"
