# deluge-engine v1 spec

deluge-engine builds the Deluge community firmware's own sound code for macOS (Apple Silicon) so a computer can play Deluge Synth and Kit presets from MIDI. The first use is trying sounds for Generative mode in [gismya/deluge-generative](https://github.com/gismya/deluge-generative) without the Deluge. Later uses are a sound-shaping (preset editing) tool and maybe a plugin.

Background: [spike-findings.md](spike-findings.md) (the spike that rendered factory presets natively, code on branch `spike/host-compile`) and the architecture review summarised in this spec.

## 1. Goals and non-goals

v1, in priority order:

1. **Synth presets** load from a card folder (`SYNTHS/`, `SAMPLES/`) and render offline to WAV from a MIDI file or note list.
2. **Real time:** CoreMIDI in, CoreAudio out. One loaded instrument at a time, routed from any MIDI channel.
3. **Kits** (`KITS/`): MIDI notes map to drums the way the firmware maps them.
4. **Song-level FX:** master reverb, delay, sidechain and compressor, set from a song file or from the host.

The bar is **not audibly different from the Deluge**. Bit-exact output is out of scope: the firmware builds with `-ffast-math`, so it can't be bit-exact anyway. Don't chase it.

Out of scope for v1: CPU-load voice culling (§6), preset editing and saving, plugins, Windows and Linux, audio input and sampling, CV and gate, the Deluge's UI.

## 2. Decisions already made

- The engine compiles the **actual firmware source**, never a copy or a rewrite.
- The firmware is a git submodule at `firmware/`, pinned to a commit of gismya/deluge-generative's `generative` branch.
- **Firmware seams:** avoid new ones. Small ones are allowed when needed. Each goes as its own PR to gismya/deluge-generative, and `./dbt sizediff` must show the ARM Release build unchanged.
- **Merging firmware seam PRs:** the agent may merge them into `generative` when the **Run tests** check is green and `./dbt sizediff` shows no change. A seam over about 30 lines of non-mechanical change, or one that changes the size, waits for the user. Mechanical `uintptr_t` cast changes don't count toward the 30 lines.
- **Merging in this repo:** the agent may merge its own PRs when CI is green and a review pass found nothing it must fix.
- **Test content:** CI uses only CC0 content, which is the firmware's `pack/` (3 synths, 7 samples, see `pack/LICENSES.md`) plus fixtures the repo generates. The factory card (171 synths, 43 kits, 397 MB of samples) has no licence statement. Never commit it, renders of it, or excerpts of it, and never upload it anywhere. Factory parity runs only locally. Preset names and metric numbers in reports are fine.
- **No CPU-load culling in v1.** The engine reports its voice count instead.
- Licence: GPL-3.0, like the firmware.

## 3. Architecture

### 3.1 Seam: the driver boundary

Compile nearly all of `firmware/src/deluge` (plus `OSLikeStuff`, `fatfs`, `NE10` and the other non-driver sources), leave out `drivers/` and the RZ/A1 hardware code, and link host replacements for the drivers. The spike showed why there is no smaller "engine only" build. Its render driver used only instrument, kit, audio engine and storage code, yet the link pulled in 451 of 466 firmware objects.

### 3.2 Building against the firmware

- Compile the submodule in place. Don't copy the tree. The spike copied it because `src/definitions.h:3` includes its sibling `RZA1/cpu_specific.h`, which beats `-I` overrides. That header has a classic include guard (`SYSTEM_CPU_SPECIFIC_H_`), so pre-including the host version through the prefix header turns the real one into a no-op. The first build ticket proves this works before the copy goes away. Fallbacks, in order: clang's `-ivfsoverlay`, then a 2-line `#ifndef` seam.
- Keep a script that generates host versions of the RZ/A1 register headers (`iodefine`) so registers live in host RAM. It fails if any raw `0xE8…`/`0xFC…` peripheral address cast survives in the generated output.
- Point `UNUSED_MEMORY_SPACE_ADDRESS` (`cpu_specific.h:124`, written at `voice_sample.cpp:1479`) at a host scratch buffer.
- Take the argon and etl pins from `firmware/lib/CMakeLists.txt` rather than repeating them.
- Compile with `-ffp-contract=off`. Set FPCR.FZ (flush denormals to zero) on the engine thread.
- Once the `uintptr_t` seam lands, drop `-fms-extensions` so new pointer truncations fail the build.
- Audit the roughly 100 `long` uses once, since `long` is 64-bit on the host and 32-bit on the Deluge.
- **Firmware worktree for development:** a CMake option (`-DDELUGE_FIRMWARE_DIR=<path>`) builds against another checkout, for example a worktree with unmerged Generative work.

### 3.3 Startup

Don't call `deluge_main()`. It talks to the PIC, waits on the OLED and USB, and loads the startup song.

- A firmware seam splits `deluge_main` into hardware init, engine init and `registerTasks()`. It's a pure refactor of `deluge.cpp`, so `sizediff` should show no change. The host calls the engine init and `registerTasks()`.
- Until that seam lands, the host keeps its own init list. The spike's list already skips calls that matter for MIDI in, such as `MIDIDeviceManager::readDevicesFromFile` and `midiFollow.readDefaultsFromFile` (`deluge.cpp:864-869`). CI hashes the text of `deluge_main` and `registerTasks`, so a firmware bump that changes them fails loudly.
- The host runs the firmware's own scheduler: `registerTasks()` (`deluge.cpp:557`) and `taskManager.start(duration)`. It doesn't keep a second, hand-written task list.

### 3.4 Platform layer

- **Virtual clock.** The host's `getTimerValue` advances by a fixed small amount per read, and the simulated DMA position is a pure function of that clock. A frozen clock hangs every timeout loop. A wall clock makes renders differ from run to run and lets host speed leak into scheduling. With a virtual clock, offline and real-time rendering share one code path and repeat bit for bit. Time-box this to a day. If it fails, the spike's loop is the fallback.
- **Allocator.** Link-time replacement of `GeneralMemoryAllocator`, based on `malloc`, as in the spike's `host_gma.cpp`. Add a byte budget with LRU eviction for sample clusters, so a long session doesn't keep every cluster in memory.
- **Freezes.** `FREEZE_WITH_ERROR` and the display's error screen abort with the error code and a backtrace. They never busy-wait.
- **Settings.** Defaults, as with erased flash. Later, a settings file.
- **Stubs** for USB, OLED, PIC, CV, gate, the trigger clock and GPIO. Most are already in the spike.

### 3.5 Threads and real time

- One **engine thread** owns all firmware state. Nothing else calls firmware code.
- The engine copies finished frames from the 128-frame SSI ring into a lock-free FIFO. It blocks when the FIFO is at its target size.
- The **CoreAudio callback** only drains the FIFO. Latency is the FIFO target, plus up to 128 ring frames, plus the device buffer.
- **MIDI in:** the CoreMIDI callback pushes bytes onto a single-producer queue. The engine feeds them through the DIN UART stub (`uartGetChar`), so the firmware's own MIDI parser handles them (`midi_engine.cpp:717`). Routing uses MIDI follow, set up as `test_port.cpp:112-170` does. v1 delivers each event at once, so timing jitters by up to one buffer. Timestamped delivery comes later.
- **Commands** from a front end (load a preset, later set a param) go on a queue. A host task registered with the firmware scheduler drains it. It skips a turn while `sdRoutineLock` is set, as `test_port.cpp:793` does. Front ends read state from snapshots the engine thread publishes.
- **Null audio backend.** The real-time path also runs with no audio device, pulling frames on a timer. Agents and CI use it. An agent shell must never play through the user's speakers.

### 3.6 Storage

- **v1:** build a FAT32 image from the user's card folder and cache it. FatFS (`ff.c`) reads it through a host sector device, as in the spike's `host_diskio.c`. A shim at the `f_open` level isn't enough, because samples are read as raw clusters (`audio_file_manager.cpp:830-845`, `:1002`).
  - Use 32 KiB clusters, as `delugemu/scripts/mksd.sh` does. `Cluster::size` follows the FAT cluster size.
  - The firmware's FatFS is built without `f_mkfs` (`FF_USE_MKFS` 0), so format with `newfs_msdos` (built into macOS) and fill the image through the linked FatFS.
  - Refresh the image incrementally from a path, size and mtime manifest.
- **Later, for preset saving:** copy changed files from the image back to the folder after a firmware save, like delugemu's `sdcard_rw` write-back. That's less code than a writable virtual FAT.

### 3.7 Engine API

The API has three layers:

1. **Engine:** single-threaded and deterministic. One per process, because the firmware is all globals.
   - `boot(config)`
   - `loadSynth(path)`, `loadKit(path)`, `loadSong(path)`
   - `midi(bytes, frame)`
   - `render(int32 stereo buffer, frames)`
   - an event callback for freezes, errors and voice count
2. **Pump:** the engine thread, FIFO and command queue from §3.5.
3. **Front ends:**
   - a CLI: `deluge-engine render` (offline to WAV) and `deluge-engine play` (CoreMIDI and CoreAudio, or the null backend)
   - later, the editor and a plugin

Keep commands and events serialisable. A plugin host loads several instances into one process, so a plugin will need a helper process per instance. Parameter access and saving come later, through the command queue.

## 4. Firmware seams

Each seam is a separate small PR to gismya/deluge-generative. Their exact contents are in the spike's `spike/overlay.diff` and in [spike-findings.md](spike-findings.md), "Firmware seams and fixes needed".

| # | Seam | Why |
|---|---|---|
| S1 | 64-bit pointer hygiene: `uintptr_t` for pointer round trips (all 110 cast sites, mechanical); the `String` reference count as `int32_t`; `Song::backedUpParamManagers` key width; the Kit render list keeps the full `Drum*` | crashes, empty strings and failed preset loads on 64-bit |
| S2 | `swapEndianness32/2x16` asm only on `__arm__`, else `__builtin_bswap32` | silently returns 0 on arm64 |
| S3 | Clang portability: headers, missing includes, `0L`, `strrchr`, the VLA initializer, `__arm__` guards on the PMU asm and the 3 Generative layout `static_assert`s, `PLACE_*` macros empty when not ELF; plus the uninitialised `noteRowId` fix (`instrument_clip.cpp:963-1033`) | doesn't build with clang; the UB turns into an E380 freeze |
| S4 | The `String::set` S001 check asks the allocator instead of comparing with `EXTERNAL_MEMORY_END` | a host allocator can't meet fixed address ranges |
| S5 | Split `deluge_main` into hardware init, engine init and `registerTasks()` | the host reuses the firmware's own startup (§3.3) |
| S6 | Test-port lines `load synth PATH`, `load kit PATH` and `midi S D1 D2`, modelled on `loadSong` (`test_port.cpp:718`). They exist only under `ENABLE_SYSEX_TEST`, so Release is unchanged. | the parity reference in delugemu (§5) |

Firmware rules apply to these PRs: the firmware's `AGENTS.md` (hooks, `git delugepush`, the **Run tests** check, `docs/upstream-candidates.md` for fixes that aren't Generative-specific, which is all of S1 to S4).

Until a seam is merged, the engine applies it as a patch from `patches/` in this repo. Each patch is deleted when its seam merges and the submodule pin moves past it. The goal is an empty `patches/`.

## 5. Parity checking

**Reference:** delugemu running the ARM firmware, never the host engine. delugemu is not a real Deluge, but it runs the same ARM code. The tolerance table below takes its CPU timing out of the comparison.

- **Driving both sides.** A test-port script (S6) loads a preset and queues timed `midi` lines with `wait`. Under delugemu's icount mode those times are firmware time (`scripts/generative/gen_emu.py:436-470` in the firmware repo shows the capture loop). If the host engine is built with `ENABLE_SYSEX_TEST`, the same script drives it too.
- **Metrics are phase-insensitive.** Oscillator phases run free from boot, so a null test (subtracting one render from the other) can't work. Align the note onsets by envelope, then compare per note:

  | Metric | Starting tolerance |
  |---|---|
  | Level | ≤ 0.5 dB |
  | RMS envelope, 10 ms windows | ≤ 1.5 dB |
  | Fundamental frequency | ± 3 cents |
  | Third-octave spectrum | ≤ 1.5 dB per band |
  | Stereo balance | ≤ 0.5 dB |
  | Release time | ± 10% |

- **Calibration.** Render each reference twice with a shifted start to measure how much the preset varies by itself, for example from random LFO phase or noise. A preset whose self-variation is above the tolerance goes on a listening list, not the pass list.
- **Tiers.**
  - **Smoke:** about 12 presets covering each engine type (subtractive, FM, ring mod, wavetable, sample, DX7, a Kit). It can use `pack/` content in CI against stored metric references.
  - **Full:** all 171 factory synths and 43 kits, locally. Load many presets per delugemu boot and run several delugemu instances in parallel. Cache references by firmware SHA, preset hash and script hash.
- **Render window.** Render with two host window sizes. If they agree within tolerance, stop worrying about window size.
- **Reports.** `parity/report.md` holds per-preset metrics and pass, fail or listen. It also lists the presets for a blind, level-matched A/B pack in the local notes dir, worst first plus a random few, which the user listens to.
- **What the agent must not do:**
  - claim "not audibly different"; it reports metrics and builds the listening pack
  - claim delugemu equals the Deluge
  - use a reference rendered while the firmware's `cpuDireness` was above 0 (the test port reports it, `test_port.cpp:700`)
  - judge real-time feel
  - loosen a tolerance to turn a check green. A tolerance that looks wrong is a question for the user.

## 6. Host behaviour that differs

- **Culling and direness.** On the Deluge, CPU load drops voices and also switches oscillators, interpolation and the ladder filter to cheaper versions (`oscillator.cpp:74`, `sample_controls.cpp:37`, `lpladder.cpp:69`). With one preset, direness stays at 0 on a Deluge, and the virtual clock keeps it at 0 on the host. v1 has no culling and exposes the voice count. A dense full Generative piece may sound richer on the host than on the Deluge. The user accepted that.
- **Render window:** checked by the parity harness (§5).
- **FMA and denormals:** not audible. `-ffp-contract=off` and FZ (§3.2) keep the host close anyway.

## 7. CI

- GitHub Actions on a macOS arm64 runner. The firmware submodule is public.
- Jobs: an ASan plus UBSan build at `-O1`, and a release build at `-O2`.
- Tests:
  - unit tests of the platform layer
  - load and render every `pack/` preset twice under the sanitizers
  - host goldens (`pack/` renders) rendered twice and compared bit for bit, which checks determinism
  - the smoke parity tier against stored metric references
  - the null-backend real-time path, with a CoreMIDI virtual-port loopback if the runner allows it, else an injected-bytes test
- Every test has a timeout, and a freeze aborts the run.
- A nightly (scheduled) canary builds against the tip of the firmware's `generative` branch and opens an issue when it fails.

## 8. Tickets

`→` marks a dependency. F tickets are firmware PRs to gismya/deluge-generative. E tickets are PRs to this repo.

| # | Ticket | Depends on |
|---|---|---|
| F1 | S1 + S2: 64-bit pointer hygiene and `swapEndianness` | |
| F2 | S3: clang portability and the `noteRowId` fix | |
| F3 | S4 + S5: allocator-based S001 check, `deluge_main` split | |
| F4 | S6: test-port `load synth/kit` and `midi` lines, with a delugemu test script | |
| E1 | Build: CMake project, firmware submodule, in-place compile (prove the prefix-header trick), generated register headers, `patches/` for unmerged seams, `deluge_main` hash guard, CI skeleton with sanitizers | |
| E2 | Platform layer: virtual clock, allocator with cluster eviction, SSI ring, freezes abort, stubs, host startup through the firmware scheduler | E1 |
| E3 | Card folder → FAT32 image builder with manifest refresh | E1 |
| E4 | Engine API and `deluge-engine render` (preset + MIDI file or note list → WAV), preset swapping, a load-all-presets-twice loop under ASan, `pack/` goldens | E2, E3 |
| E5 | Parity harness: delugemu driver, metrics, calibration, smoke and full tiers, report, listening pack | F4, E4 |
| E6 | Real time: engine thread, FIFO, CoreAudio and null backends, CoreMIDI in through the DIN UART stub, MIDI follow, `deluge-engine play` | E4 |
| E7 | Kits: note → drum mapping, Kit parity over the full tier | E4, E5 |
| E8 | Song-level FX: `loadSong`, host-set song FX params, parity | E4, E5 |
| E9 | DX7 kernel: a NEON-intrinsics port of `neon_fm_kernel.s`, tested against the scalar port and through parity | E4, E5 |

F1 to F4 and E1 can run in parallel. E1 starts on the spike's overlay as patches and drops each patch as its seam merges. After E4, E5 and E6 can run in parallel.

## 9. Running unattended

The user is away for about a week, and an orchestrator runs the tickets. It follows [docs/agents/orchestration.md](agents/orchestration.md).

**Stop and leave a question** (a `needs-info` comment on the ticket, and a line in the orchestrator's state file) instead of guessing when:
- a firmware seam shows a `sizediff` change or grows past about 30 lines of non-mechanical change
- a parity failure survives a day of work
- a tolerance looks wrong
- anything needs a CPU load model or a listening judgement
- a firmware change would touch Generative-mode behaviour

Then move on to a ticket that isn't blocked.

**Highest risks**, in the order the tickets meet them:
1. Silent 64-bit errors that change the sound without crashing. Sanitizers, the parity harness and the `long` audit are the defence.
2. Preset swapping. The spike only ever loaded one preset per run.
3. Parity turning into a bit-exactness chase. The tolerances are the bar.
4. Hangs. Every test has a timeout, and freezes abort.
