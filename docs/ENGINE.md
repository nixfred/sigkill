# Engine recommendation

**Pick: Godot 4 (GDScript, Forward+ renderer on Vulkan).**

## What the game needs

A native first-person shooter for Omarchy (Arch, Hyprland on Wayland). Target hardware is an
NVIDIA RTX 5070 laptop GPU plus an Intel iGPU. It must ship as one installable program and
must be fast to iterate on, because the early work is feel: movement, hit response, level shape.

## Candidates

Godot 4, Bevy (Rust) and raylib (C). Unity and Unreal were not considered: heavy, closed, and
poor fits for a small Linux-first project.

| | Godot 4 | Bevy | raylib |
|---|---|---|---|
| Linux, Wayland, Hyprland | Native Wayland display driver since 4.3, XWayland fallback. Mouse capture goes through the pointer-lock protocol that Hyprland supports. | winit gives native Wayland by default. Good. | GLFW 3.4 has a Wayland backend, but it depends on how the distro package was built. |
| NVIDIA RTX 5070 and Intel iGPU | Vulkan Forward+ by default. A Compatibility (OpenGL) renderer exists as a fallback for a weak iGPU. A `--gpu-index` flag picks the device. | wgpu over Vulkan. Prefers the high-performance adapter by default. | OpenGL only. On a hybrid laptop the driver or PRIME environment variables decide. |
| One installable binary | Exports a Linux executable, with the data pack embeddable. Needs export templates that match the engine version exactly. | `cargo build --release` gives one binary. Assets ship beside it unless embedded. | Trivial. One C binary. |
| FPS iteration speed | Editor, scene tree, live run in about a second, no compile step. Character body, ray queries, physics, audio, UI and input map are built in. | No production editor. Incremental builds take seconds to tens of seconds, the first build several minutes of heavy CPU. Controller and physics crates break between releases. | Fastest to compile, but everything an FPS needs (scene graph, collision, physics, UI, level tooling) must be written by hand. |

All table cells are from engine documentation and general knowledge, not tested on this machine.

## Why Godot 4

- It is the only option here with an editor and the FPS building blocks included, so the first
  playable arrives in days, not weeks.
- Vulkan on both GPUs, native Wayland, MIT licence, no runtime fees.
- It is packaged by Arch: `godot 4.7.2-2` in the extra repository (checked with a read-only
  `pacman -Si`). A Mono build exists too, but GDScript needs neither .NET nor extra tooling.
- Bevy is the strongest runner-up if the game ever becomes simulation-heavy. A Rust
  GDExtension can cover that inside Godot without a rewrite.

## Risks and open items

1. **Nothing here has been run in Godot yet.** The scaffold was written without the engine
   installed. Expect small first-launch fixes, especially around 4.7 API details.
2. **Export templates are the packaging question.** It is not confirmed whether the Arch
   package ships them (the pacman file database was not synced, so its contents could not be
   listed). The installable build should come from a PKGBUILD that builds on the target
   machine, either from pinned release templates with checksums or from source.
3. **Hybrid GPU.** Confirm which adapter Godot picks under Hyprland and whether `--gpu-index`
   is needed.
4. **Wayland mouse capture and focus-loss release** are untested. The code assumes the
   engine's focus-out notifications fire and the compositor honours pointer lock.
