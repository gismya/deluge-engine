# Perform in the Engine: findings (issue #17)

Firmware: gismya/deluge-generative `generative` at 4a64f701b (read-only worktree, not edited). Spike code: branch
`task/perform-in-engine` (from `spike/host-compile`). Paths under `spike/` are on that branch; firmware paths are under
`src/deluge/` of the firmware.

## Answer: yes

Perform runs in the Engine built with `ENABLE_SYSEX_TEST`, driven by the firmware's own `perform_*.txt` scripts through
the firmware's own `deluge_probe.py`, both unchanged. It renders a Piece to WAV at about 30x real time (up to 96x),
bit for bit the same on every run. For the one Recipe compared, it matches the delugemu Reference within 0.14 dB of
level per 4 s and 0.55 dB per octave band.

It needed **no new firmware seam**: `spike/overlay/` is unchanged from `spike/host-compile`. All new code is in
hardware stand-ins and the driver (about 170 changed lines of stand-ins plus a 355-line driver).

## 1. Enter Perform, play, render

- `perform_skeleton.txt` passes 37/37: GENERATIVE → PERFORM FROM → GENRE → TECHNO ▸ ACID → OK, KEY/SCALE edits, PLAY,
  gold-knob macro turns, INTRO → GROOVE, `gen_h1`, PLAY stop, LEAVE.
- Renders (factory card, kept in `~/.cache/deluge-engine/notes/perform-wav/`, not in git):

| Run | Audio from PLAY | Peak / RMS | Silent 0.5 s windows | Longest OLED still | Max voices |
|---|---|---|---|---|---|
| Acid techno, probe-driven at 1x pace | 60 s | −1.1 / −16.9 dBFS | 0 of 120 | 0.12 s | 9 |
| Acid techno, injected, pinned entropy | 60 s | −8.3 / −25.2 dBFS | 0 of 120 | 0.12 s | 7 |
| Dub techno seed 7 Energy 40, capture build | 60 s | −4.8 / −21.0 dBFS | 0 of 120 | 0.13 s | 16 |

"Not frozen" is checked as gen_emu's smoke check does: the OLED (it shows the beat) changes at least every 0.13 s
while playing. `cpuDireness` stayed 0 throughout (the virtual clock makes rendering free; spec §6).

**Against delugemu** (same arguments to `gen_emu.py capture --genre techno-dub --seed 7 --energy 40 --seconds 60`, and
the same `generative_capture.h` compiled into the Engine):
- whole-file RMS −20.99 vs −21.00 dBFS
- every 4 s window within ±0.14 dB
- 10 ms energy envelopes align at 0 ms lag
- octave bands 40 Hz–20 kHz within ±0.55 dB

So the Engine plays the same Piece (notes, sections, timing, sound picks). This is one Recipe, not a Parity method;
how to judge a whole Piece is still open on the map.

## 2. How scripts reach the test port

Two routes, both working:

**A. DIN MIDI stand-in over UDP (recommended for scripts).** The DIN UART stand-in carries raw MIDI bytes in UDP
datagrams both ways, framed exactly like delugemu's MIDI bridge:
- input: `uartGetCharWithTiming` (`spike/host/hw_stubs.cpp:204`)
- output: `uartFlushIfNotSending` (`:227`)

So `deluge_probe.py --udp LISTEN:SEND`, `run_one_script()`, `start_state`, `expect event`, `snapshot` and `expect
oled_changed` all work unchanged. `spike/scripts/perform_run.py` launches the Engine on free ports and runs scripts
the way `test_port_emu.py` does. The firmware parses the sysex, `HIDSysex` dispatches it, and the reply goes out on DIN
(`midi_engine.cpp:646`, `hid_sysex.cpp:40`), as in delugemu. This is also the path spec §3.5 picked for CoreMIDI in.

**B. Direct call (deterministic renders).** `perform_engine --inject FILE` hands lines to `TestPort::injectReceived()`
at fixed virtual times (`spike/host/drivers/perform_engine.cpp:121`). It's simpler: no sockets, no Python, no
wall-clock timeouts. But it has no `expect`, so the firmware's own `wait` lines have to stand in for the sync points
(`spike/perform/enter_and_play.txt`). Test events go to stderr (`Debug::midiDebugCable` set to the DIN cable,
`perform_engine.cpp:346`).

**Which is simpler:** for running the existing scripts, A. Nothing in the scripts or the probe changes, and the stand-in
is about 70 lines. For a render the user asks for, B: it repeats bit for bit (two runs gave the same SHA-1), and route
A can't, since wall-clock jitter decides how much virtual time passes between the probe's lines.

**Same scripts unchanged?** Yes. At real-time pace (`--pace 1`), on one boot per group, 13 scripts pass 1095/1095
expects:

| Script | Expects |
|---|---|
| `test_port_smoke.txt` | 12 |
| `perform_skeleton.txt` | 37 |
| `perform_runner.txt` | 69 (with modelled card time, see §3) |
| `perform_sounds.txt` | 44 |
| `perform_start_state.txt` | 45 |
| `perform_transition.txt` | 157 |
| `perform_genre_change.txt` | 99 |
| `perform_sounds_override.txt` | 75 (its card overlay) |
| `perform_preset_browser.txt` | 194 |
| `perform_retire.txt` | 161 |
| `perform_fill.txt` | 49 |
| `perform_homes.txt` | 84 |
| `perform_transport.txt` | 69 |

`perform_leave.txt` and `perform_choose_002.txt` are includes, not scripts, and fail run alone, as they would in
delugemu.

## 3. Timing

**It needs the firmware scheduler.** The spike's hand loop can't run Perform, so the driver calls `registerTasks()` and
`startTaskManager()` (`perform_engine.cpp:351-353`):
- the Runner's jobs are `addOnceTask`s that `yieldToIdle()` (`generative/firmware/runner.cpp:34,42`)
- the sound-swap, transition and retirement pump runs from `PerformView::graphicsRoutine()` (`gui/views/perform_view.cpp:459`) on the UI timer
- the test port's input is taken in the buttons task (`deluge.cpp:344`) and its events leave from there too (`deluge.cpp:269`)

**The Runner works:** entry, sound preloads, transition preloads, the free job and the leave job all pass their
scripts (runner, sounds, transition, retire, start_state). The stand-ins needed nothing special for it.

**The virtual clock (spec §3.4) works:**
- `getTimerValue` adds a fixed number of ticks per read (`hw_stubs.cpp:116-129`).
- The DMA read position is a pure function of that clock, and every frame it passes goes to the WAV sink (`hw_stubs.cpp:43-60`).
- No run showed an underrun or a culled voice.
- `--pace F` holds it to F x wall time for a client that times itself by the wall clock (`hw_stubs.cpp:101`).

How many ticks a read is worth is the virtual CPU speed:

| Ticks per read | Virtual time per read | 60 s Piece renders in | Notes |
|---|---|---|---|
| 3 | 0.09 µs | 15.6 s (3.8x) | |
| 10 | 0.3 µs | 6.9 s (8.7x) | |
| 33 (default) | 1 µs | 1.95 s (31x) | |
| 100 | 3 µs | 1.33 s (45x) | |
| 330 | 10 µs | 0.62 s (96x) | same RMS |
| 1000 | 30 µs | — | **entry never finishes** |

At 1000, the entry job ran once (`gen_mem before_entry`) and then never again: the scheduler spun with GENERATIVE's
modal screen up. The likely cause: the job's measured run time no longer fits before the audio task's next deadline,
so `chooseBestTask()` never picks it. Wall time at small values is the idle scheduler spinning until the next audio
window. A clock that jumps to the next due task when idle would remove most of that.

**Scripts and pace:**

| Pace | Result |
|---|---|
| 1 (real time) | everything passes |
| 4 | transition, runner and retire pass |
| 10 | `perform_retire.txt` fails 2 |
| unpaced | the skeleton passes in 2.7 s wall, but scripts that race the firmware fail |

Unpaced, firmware time between two probe lines grows about 30x, so a BACK meant for "during entry" lands 9.6 s after
OK. Spec §3.4's claim that offline and real-time share one code path holds. But the probe times its expects by the
wall clock, so a script run needs pacing.

**Card time matters (new):**
- With instant card reads, Perform entry took 0 ms of virtual time (`gen_entry done ran=1 ms=0`).
- `perform_runner.txt` step 4 (BACK right behind OK) then can't cancel entry: 3 fails.
- `--card-us 300:40` makes each read wait out 300 µs plus 40 µs per sector, through the firmware's own `yieldingRoutineWithTimeoutForSD()`, the way the RZ/A1 SD driver waits for its DMA (`spike/host/host_diskio.c:56`). Audio and buttons keep running meanwhile.
- Entry then takes 243 ms and the script passes.
- It costs no wall time worth noting, and it stays deterministic.

The Engine should model card time by default. Otherwise preloads land earlier than on the Deluge, which can move a
swap or transition onto another line. It caused one DMA overrun in a 60 s run (a read during a nested SD routine
busy-waits without audio), which wants a look.

## 4. Recipe and Sound picks

- **Recipe files:** not in the firmware yet (milestone M3, `docs/generative/spec/22-build-order.md:22`). Nothing to load.
- **Recipe, test-port lines (no build change):**
  - genre by name: `pick genre techno-dub`
  - KEY/SCALE through the menu (`perform_skeleton.txt`), macros by gold-knob turns, tempo by the tempo encoder
  - Seed: no direct line. `hold entropy` pins every roll (Recipe, seed and sound picks) to a fixed sequence, so a run repeats, but it can't choose a given seed.
- **Recipe, capture build (exact genre, seed, macros, tempo, key, scale, sound entropy):** compile
  `generative/firmware/current_recipe.cpp` with `-DGENERATIVE_CAPTURE=1 -I<dir>` and a `generative_capture.h` written
  by `gen_emu.capture_header()`.
  - `compile_all.py --capture DIR` does it (the spike rebuilds only that file in a cloned build folder).
  - It is the same mechanism and header as the delugemu capture, so the Reference and the Engine render the same Piece from the same arguments (§1).
  - One binary per Recipe. For the GUI, a runtime equivalent (a test-port line, or the overrides read from a file) would be a small `ENABLE_SYSEX_TEST`-only seam in `current_recipe.cpp:138`.
- **Sound picks:**
  - palette override files on the card (`GENERATIVE/PALETTES/<GENRE>.XML`): `perform_sounds_override.txt` passes 75/75 on a card built with the firmware's `test_port_emu.apply_overlay()`
  - the preset browser over the test port: `perform_preset_browser.txt` passes, with `chose part=1 path=SYNTHS/002 ...`
  - NEW SOUND / previous sound presses: `perform_sounds.txt` passes
  - For the GUI's "Sound pick per Part" (the map's open question), both a palette override file and test-port presses work today. The override file needs a card image rebuild. The test-port route needs Perform running.
- **Generative pack:** not needed. The factory image lacks it (no `SAMPLES/FX`, no `SYNTHS/GENERATIVE`), and so does delugemu's card; FX lanes without a sample then stay silent (`palette.cpp:526`, `gen_sound FX RISER silent`). A copy with the pack, made with `fat_image.copy_tree()`, is at `~/.cache/deluge-engine/notes/perform-card-pack.img` (`fsck_msdos -n` clean). Use the plain image for Reference parity.

## 5. Speed

| | Wall time |
|---|---|
| Engine, 60 s Piece after PLAY, default clock | 1.95 s (31x real time) |
| Engine, same, at 330 ticks per read | 0.62 s (96x) |
| Engine, boot → entry → 60 s Piece → WAV (inject, card model) | 2.2–2.9 s |
| delugemu `gen_emu.py capture` of the same 60 s, this machine, no rebuild | 68 s |
| spec §21.5's figure for delugemu | about 18 s per 60 s capture |

So the Engine is about 25x faster than this machine's delugemu capture end to end. Script runs are bound by the
probe's waits and the pace, not by the Engine.

## 6. Seams and stand-ins

**Firmware seams: none.** `spike/overlay/` and `spike/overlay.diff` are unchanged. The 3 Generative files there
(entry_leave, perform_adapter, transitions: the ARM32 layout `static_assert`s) come from the earlier spike and are
part of S3.

**Build flags, no source change:**
- `-DENABLE_SYSEX_TEST=1` on every TU (`compile_all.py --sysex-test`). The whole tree compiled with clang at once (474/474 TUs).
- `-DGENERATIVE_CAPTURE=1 -I<dir>` on `current_recipe.cpp` (`--capture DIR`)

**New or changed hardware stand-ins:**

| Stand-in | Where | Size | Why | Test builds only? |
|---|---|---|---|---|
| `dmaBootStates[]` | `spike/host/host_testport.cpp` | 8 lines | `test_port.cpp`'s `report boot_dma` links against `dmac.c`'s array; the only undefined symbol of the `ENABLE_SYSEX_TEST` link | yes |
| Virtual clock with optional pace | `hw_stubs.cpp:93-134` | ~45 lines | deterministic time, renders faster than real time, real time for the probe | no |
| DMA position follows the clock, plus audio sink and overrun count | `hw_stubs.cpp:35-60` | ~25 lines | the scheduler's audio task, not the driver, decides when to render | no |
| DIN UART ↔ UDP | `hw_stubs.cpp:171-264` | ~70 lines | test port and scripts unchanged; also the spec's MIDI-in path | used by the test port, but generic MIDI |
| Modelled card time (yielding wait per read) | `host_diskio.c:10-24,52-55` | ~20 lines | entry, preloads and the BACK races take time as on the Deluge | no |
| Test events printed to stderr when no link | `hw_stubs.cpp:228-246` | ~18 lines | inject-mode logging | events exist only in test builds |

**Driver** (`spike/host/drivers/perform_engine.cpp`, 355 lines):
- It extends the spike's init list with:
  - `encoders::init`
  - `runtimeFeatureSettings.readSettingsFromFile`
  - `MIDIDeviceManager::readDevicesFromFile`
  - `midiFollow.readDefaultsFromFile`
  - `inputRoutine`
  - the `GRAPHICS_ROUTINE` timer
  - `sdRoutineLock = false`
  - `Screensaver::settingsChanged`
- Then it calls `registerTasks()` and `startTaskManager()`.
- A host task (`hostTask`, `:232`) in the firmware's scheduler notes PLAY, watches the OLED, feeds `--inject` lines and ends the run.
- These lines copy `deluge_main` (spec §3.3's S5 split would remove them).

Spike tooling: `compile_all.py` gained `--driver`, `--sysex-test`, `--capture` and an incremental build. A no-op
rebuild takes 2 s instead of 50 s: objects are kept by a dependency-file check, and the generated register headers
are written only when they change. `perform_run.py` is the probe wrapper.

## Not verified

- Parity beyond one Recipe and one genre change. No per-note metrics; mono vs stereo assumed the same as delugemu (both read unplugged jacks as 0, so `renderInStereo` follows `inputRoutine` on both).
- The real-time path (CoreAudio, CoreMIDI), and a Piece longer than 2 minutes in one boot. The firmware itself never crashed or froze: the longest paced session ran about 630 virtual s, and an unpaced one about 4500 s until the driver's own crash (Tooling problems).
- The one DMA overrun with modelled card time.
- Memory growth: `host_gma` never steals, and `gen_mem` reports 0 on the host.

## Tooling problems

- My first long unpaced batch crashed (SIGSEGV) in the driver's own audio vector after about 4500 virtual seconds (about 1.6 GB of frames). The macOS crash report (`~/Library/Logs/DiagnosticReports/perform_engine-*.ips`) gave a symbolised backtrace, quicker than lldb. Audio is now kept only with `--out`, capped at 20 minutes.
- The driver's `--play-seconds` default (60) ended a script batch early, since `perform_runner.txt` starts playback with MIDI Start.
- Two scripts are includes, not standalone scripts (`perform_leave.txt`, `perform_choose_002.txt`), and fail when run alone.
- `compile_all.py` reported a failed driver compile only in the summary line, and the old binary stayed in place. One run used a stale binary until I checked the log.
- `/tmp/claude-501` is shared with other sessions; later scratch files went to this session's scratchpad.
- No numpy on the system Python. The Reference comparison is pure-Python Goertzel bands (about 1 minute).
