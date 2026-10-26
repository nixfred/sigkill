# AI detector fixtures

Fake inputs for `tests/ai_detector_test.gd`. Every value is obviously fake. Godot ignores
this folder (`.gdignore`); the test reads it by absolute path.

- `agent/`: stand-ins for Omarchy's default-agent setting. `known`, `known_padded` and
  `multiline` name listed agents; `unknown` names no real agent; `empty`, `junk`
  (binary bytes), `oversized` (one 300-byte line) and `unreadable_dir` (a directory) must
  all count as unset.
- `path/with_agent/`: a fake PATH directory. `claude` is an executable stub that leaves a
  mark if it is ever run, which fails the test, since the detector must never run an
  agent. `codex` is not executable and `opencode` is a directory, so both count as absent.
- `path/gpu/nvidia-smi`: a stub that records its arguments and prints canned readings.
- `path/gpu_slow/nvidia-smi`: answers only once the test creates its release file, so it outlasts the deadline.
- `path/gpu_flood/nvidia-smi`: prints far more than the detector keeps.
- `path/empty/`: a PATH directory with nothing in it.
- `sysfs/`: a fake `/sys` with one DRM card that reports nothing and one that reports busy
  percent, VRAM and a temperature. `sysfs_empty/` reports nothing.
