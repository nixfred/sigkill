# AI test fixtures

Fake inputs for `tests/ai_detector_test.gd` and `tests/guide_adapter_test.gd`. Every value
is obviously fake. Godot ignores this folder (`.gdignore`); the tests read it by absolute
path.

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
- `guide/claude`, `guide/codex`: stub agent CLIs for the guide adapter test, never a real
  agent. Each records its arguments (NUL-separated), PID, working directory and whether
  its stdin is open or at its end (Codex also the `--cd` value), then answers as
  `SIGKILL_TEST_STUB_MODE` says: `ok`, `hang` (until the test's release file appears, at
  most 10 s), `flood`, `ansi`, `padded` (64 KiB of control bytes, then a sentinel that
  only a reader past the cap would see) and `fail`; Codex also `epipe`. Codex writes its
  answer to the `--output-last-message` file, as the real one does.
- `sysfs/`: a fake `/sys` with one DRM card that reports nothing and one that reports busy
  percent, VRAM and a temperature. `sysfs_empty/` reports nothing.
