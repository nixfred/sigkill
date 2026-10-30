#!/usr/bin/env bash
# SIGKILL Linux release build (the release prep): exports the "Linux x86_64" preset (export_presets.cfg)
# into build/sigkill.x86_64, one executable with the game's pack inside, then packs it with the license,
# the README, the credits, the icon, the launcher entry and the user-local installer into
#
#   build/sigkill-<version>-linux-x86_64.tar.gz          (version: project.godot application/config/version)
#   build/sigkill-<version>-linux-x86_64.tar.gz.sha256
#
#   tools/export_linux.sh
#
# Needs the Godot export templates for this exact engine version, installed by hand beforehand (Godot's
# editor: Editor > Manage Export Templates, or the official templates file unpacked into the folder named
# below). This script never downloads or installs anything: without them it stops and says where they go.
#
# Safety: every Godot call is --headless (no window, no editor). It writes only under build/, which git
# ignores, replacing its own earlier outputs there, and deletes nothing. Exit 0 with both files written;
# 1 when the export or the packing fails; 2 when it cannot start (a tool, the templates, a file missing).

set -u -o pipefail

PRESET="Linux x86_64"
BINARY="build/sigkill.x86_64"

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/.." && pwd)
cd "$root" || exit 2

die() { printf 'FAIL: %s\n' "$1" >&2; exit "${2:-1}"; }

for tool in godot tar gzip sha256sum sed head; do
	command -v "$tool" >/dev/null || die "required tool not found on PATH: $tool" 2
done
for file in project.godot export_presets.cfg LICENSE README.md CREDITS.md packaging/linux/sigkill.svg packaging/linux/sigkill.desktop packaging/linux/install.sh packaging/linux/uninstall.sh; do
	[ -f "$file" ] || die "missing $file" 2
done
grep -q "^name=\"$PRESET\"$" export_presets.cfg || die "export_presets.cfg has no preset named \"$PRESET\"" 2

version=$(sed -n 's/^config\/version="\([^"]*\)"$/\1/p' project.godot | head -n 1)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "no usable application/config/version in project.godot (found \"$version\")" 2

# The templates folder is named for the engine's version and status ("4.7.2.stable"), without the build
# name a distribution adds ("4.7.2.stable.arch_linux.<hash>" from godot --version).
engine=$(godot --version 2>/dev/null | head -n 1)
[[ "$engine" =~ ^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+[0-9]*) ]] || die "could not read the engine version from godot --version (got \"$engine\")" 2
templates_version=${BASH_REMATCH[1]}
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$templates_version"
if [ ! -f "$templates/linux_release.x86_64" ]; then
	cat >&2 <<MSG
FAIL: the Godot $templates_version export templates are not installed.
      Expected: $templates/linux_release.x86_64
      Install the templates for exactly $templates_version first (Godot editor: Editor > Manage Export
      Templates; or the official $templates_version export templates file, unpacked into that folder).
      Nothing was exported. This script downloads nothing by itself.
MSG
	exit 2
fi

mkdir -p build
name="sigkill-$version-linux-x86_64"
tarball="build/$name.tar.gz"
log="build/export.log"

# A fresh clone has no import cache yet: import first, so the export never races the importer.
echo "importing (headless)..."
nice -n 10 godot --headless --path "$root" --import > "$log" 2>&1 || die "the headless import failed: see $log"
echo "exporting \"$PRESET\" to $BINARY (headless)..."
nice -n 10 godot --headless --path "$root" --export-release "$PRESET" "$BINARY" >> "$log" 2>&1
status=$?
[ "$status" -eq 0 ] || die "the export failed (godot exit $status): see $log"
grep -qE 'SCRIPT ERROR|Parse Error|ERROR' "$log" && die "the export printed errors: see $log"
[ -s "$BINARY" ] && [ "$(head -c 4 "$BINARY" | od -An -c | tr -d ' ')" = "177ELF" ] || die "no executable at $BINARY after the export: see $log"
chmod 755 "$BINARY"

# The tarball: one folder, $name/, holding the binary, the papers and the launcher files, owned by root:root
# with the last commit's time, so the same tree packs the same way.
stamp=$(git log -1 --format=%ct 2>/dev/null || date +%s)
tar --create --file - --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$stamp" \
	--transform 's,^build/,,' --transform 's,^packaging/linux/,,' --transform "s,^,$name/," \
	"$BINARY" LICENSE README.md CREDITS.md packaging/linux/sigkill.svg packaging/linux/sigkill.desktop \
	packaging/linux/install.sh packaging/linux/uninstall.sh | gzip -n -9 > "$tarball" \
	|| die "packing $tarball failed"
(cd build && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256") || die "writing the checksum failed"

echo "ok: $tarball"
tar -tzvf "$tarball"
echo "ok: $tarball.sha256"
cat "$tarball.sha256"
