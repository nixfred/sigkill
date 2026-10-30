# Release checklist: 0.33.0-prealpha

What is left before the `v0.33.0-prealpha` tag. Prepped already (2026-10-30): the version in `project.godot`, the corners and the window title; the "Linux x86_64" export preset; `tools/export_linux.sh`; `packaging/linux/` (launcher entry, icon, install and uninstall); the README's Download (pre-alpha) section; [the release notes](RELEASE_NOTES-0.33.0-prealpha.md); a privacy sweep of the tree and of what the export packs; the full gate.

Each box below is done in order. **Fred's yes** marks the ones that wait on him; nothing public happens without it.

- [ ] **1. Export templates** (Fred's yes: a download). Get the official Godot **4.7.2.stable** export templates from godotengine.org, check them against the release's published SHA-512 sums, and unpack them so that `~/.local/share/godot/export_templates/4.7.2.stable/linux_release.x86_64` exists. `tools/export_linux.sh` names that folder if it is missing.
- [ ] **2. Build.** `tools/export_linux.sh` on a clean checkout of the release commit. It must end with `ok:` lines for `build/sigkill-0.33.0-prealpha-linux-x86_64.tar.gz` and its `.sha256`, and `build/export.log` must hold no `ERROR` line. The tarball holds one folder with eight files: `sigkill.x86_64`, `LICENSE`, `README.md`, `CREDITS.md`, `sigkill.svg`, `sigkill.desktop`, `install.sh`, `uninstall.sh`.
- [ ] **3. Headless boot of the binary.** `build/sigkill.x86_64 --headless --quit-after 300` exits 0 with no `ERROR` or `SCRIPT ERROR` line (the boot screen goes straight to the arena headless, as in the gate's step 3). Then, on the private Xvnc display only, never a desktop: the window's title reads `SIGKILL v0.33.0-prealpha` (no "(DEBUG)" in a release build), its class is `SIGKILL`, and the boot screen's corner shows `v0.33.0-prealpha`.
- [ ] **4. Privacy scan of what ships.** The standing privacy regex over `strings` of the binary and over the unpacked tarball: no home paths, hostnames, user names, process lists, model names, tokens or tailnet addresses.
- [ ] **5. Clean-install test on a spare machine** (the producer routes it). A fresh Omarchy install, no Godot: `sha256sum -c`, untar, `./install.sh`; SIGKILL shows in the app launcher with the hexagon icon, starts, and its window is matched to the launcher entry on Wayland (unchecked so far: only X11 was); play a round alone and a LAN match against another machine; Esc, Loadout; quit, relaunch, the unlocks are kept; `./uninstall.sh` removes exactly its three files and leaves the saves. Note the GPU, driver and anything rough.
- [ ] **6. README.** Drop "(The first build is not up yet; until it is, run from source, below.)" from Download (pre-alpha), and put any clean-install finding in the release notes' known issues.
- [ ] **7. Tag** (Fred's yes). An annotated `v0.33.0-prealpha` tag on the release commit, pushed. Never moved once pushed.
- [ ] **8. GitHub release** (Fred's yes). A pre-release on `v0.33.0-prealpha`: the tarball and its `.sha256` as assets, the body from the release notes.
- [ ] **9. Site download button.** Points at the GitHub release (the asset or the release page), labelled pre-alpha.
- [ ] **10. X post** (Fred's yes on the exact text). Facts only, demo-data stills or clips only, the PRE-ALPHA label in the post, a link to the release.

Not in this release, on purpose: the public relay for room codes (hosting waits on Fred), AppImage and AUR packages, and the 1.0 list (M5, M6).
