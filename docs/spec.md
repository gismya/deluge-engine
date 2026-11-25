# deluge-engine v1 spec

deluge-engine builds the Deluge community firmware's own sound code for macOS (Apple Silicon). A GUI app talks to it, so the computer can play Deluge presets from MIDI and render Generative-mode Pieces to compare sounds. The first use is trying sounds for Generative mode in [gismya/deluge-generative](https://github.com/gismya/deluge-generative) without the Deluge. v2 adds sound editing.

Terms are in [GLOSSARY.md](../GLOSSARY.md). Generative-mode terms (Piece, Recipe, Seed, Part, Lane, Palette, Sound pick, Section, Perform) keep the meanings the firmware's `GLOSSARY.md` gives them.

Background:
- [spike-findings.md](spike-findings.md): the spike that rendered factory presets, on branch `spike/host-compile`.
- [perform-findings.md](perform-findings.md): Perform running in the Engine, spike code on branch `task/perform-in-engine`.
- [setup-findings.md](setup-findings.md): Setups built in memory, spike code on branch `spike/setup-routing`.
- `research/gui-toolkit.md` on branch `research/gui-toolkit`: the toolkit comparison.
- `prototype/screens/` on branch `prototype/screens` (commit f0b02bf): the reference design for the GUI.
- The decisions: [the map](https://github.com/gismya/deluge-engine/issues/15) and its tickets #16 to #21.

The user answered the review on [#20](https://github.com/gismya/deluge-engine/issues/20), and this spec has the answers.

## 1. Goals and non-goals

v1 does three things, all through one GUI app:

1. **Presets.** Load a Synth or Kit preset from a card folder and play it from MIDI, or render notes to a WAV.
2. **Setups.** Play several presets at once, each on its own MIDI channel, live from MIDI.
3. **Pieces.** Render a Piece from a genre, a Seed and Sound picks, then play two Renders against each other (A/B).

The bar is **not audibly different from the Deluge**. Bit-exact output is out of scope: the firmware builds with `-ffast-math`, so it can't be bit-exact anyway. Don't chase it.

Out of scope for v1:
- editing and saving sounds (v2)
- the GUI as a screen for a real Deluge (v2 stretch). The protocol leaves room for it (§7.8).
- steering a Piece live from the GUI
- CPU-load voice culling (§10)
- song-level FX set from the host or from a song file. Presets play under the blank song's defaults, and Perform sets its own song FX. A later release adds it: [#41](https://github.com/gismya/deluge-engine/issues/41).
- plugins (AU, VST)
- Engines for Linux, Windows and Android. The GUI is written so it can run there later.
- a signed, notarised or sandboxed app (§12)
- audio input and sampling, CV and gate

## 2. Standing rules

- The Engine compiles the **actual firmware source**, never a copy or a rewrite.
- The firmware is a git submodule at `firmware/` (§3.3).
- **Firmware seams:** avoid new ones. Small ones are allowed when needed. Each goes as its own PR to gismya/deluge-generative, and `./dbt sizediff` must show the ARM Release build unchanged.
- **Merging firmware seam PRs:** the agent may merge one into `generative`, whatever its size, when `./dbt sizediff` shows no change, the **Run tests** check is green and a review pass is done. A seam that changes the Release build waits for the user. Under this rule the agent merges S1 to S4 and S6. S5 changes Release, so it waits, and the Engine uses its fallback (§3.4).
- **Conflicts on `generative`:** the firmware's own milestone run may merge there in the same week. Whoever merges second brings their branch up to date first.
- **Merging in this repo:** the agent may merge its own PRs when CI is green and a review pass found nothing it must fix.
- **Test content:** CI uses only CC0 content: the firmware's `pack/` folder (see `pack/LICENSES.md`) plus fixtures the repo generates. The factory card (171 synths, 43 kits, 397 MB of samples) has no licence statement. Never commit it, renders of it or excerpts of it, and never upload it anywhere. Factory Parity runs only locally. Preset names and metric numbers in reports are fine.
- **No speakers.** Agents and CI run the Engine with `--audio null`.
- **Every Engine build includes the test port** (`ENABLE_SYSEX_TEST`). Engine builds and References then use the same flags.
- **No CPU-load culling in v1.** The Engine reports its voice count instead.
- Licence: GPL-3.0, like the firmware.

## 3. Architecture

### 3.1 Processes

```
GUI app (Flutter)
  │  protobuf frames over a Unix socket (§7)
  ▼
live Engine  ──►  audio device, MIDI inputs
  │  starts one per Render
  ▼
render worker (the same binary, `deluge-engine render`)  ──►  a WAV file
```

- The **GUI** owns the documents (the card folder, the Setup, the Piece) and draws the screens. It never touches audio or MIDI.
- The **live Engine** is one process that runs the firmware in real time. It plays to the audio device, reads every MIDI input, and plays Renders back for A/B.
- A **render worker** is a second Engine process that renders one Piece offline and exits. The live Engine starts it. The GUI never sees it.
- The firmware is all globals, so there is one firmware instance per process. A firmware freeze ends only its own process.

### 3.2 Seam: the driver boundary

Compile nearly all of `firmware/src/deluge` (plus `OSLikeStuff`, `fatfs`, `NE10` and the other non-driver sources), leave out `drivers/` and the RZ/A1 hardware code, and link hardware stand-ins for the drivers. There is no smaller "sound engine only" build: the spike's render driver used only instrument, kit, audio engine and storage code, yet the link pulled in 451 of 466 firmware objects. Perform needs the UI and the scheduler anyway.

### 3.3 Building against the firmware

- **The pin.** `firmware/` is pinned to a commit of gismya/deluge-generative. It is a commit on `generative` that contains seam S7 (ddeef7fad or later) and seams S1 to S4. Moving the pin is a deliberate commit that reruns every check. The run moves it only to take a merged seam.
- **Compile in place.** Don't copy the firmware tree. `src/definitions.h:3` includes its sibling `RZA1/cpu_specific.h`, which beats `-I` overrides. That header has a classic include guard (`SYSTEM_CPU_SPECIFIC_H_`), so pre-including the host version through the prefix header turns the real one into a no-op. E1 proves this. Fallbacks, in order: clang's `-ivfsoverlay`, then a 2-line `#ifndef` seam.
- **Flags.** The firmware's own (`-std=gnu++23`, `-ffast-math`), plus `-DENABLE_SYSEX_TEST=1` on every file and `-ffp-contract=off`. Set FPCR.FZ (flush denormals to zero) on the engine thread. Don't use the spike's `-fms-extensions`: with S1 on the pin, a new pointer truncation must fail the build.
- **Register headers.** A script generates host versions of the RZ/A1 register headers (`iodefine`) so registers live in host RAM. It fails if any raw `0xE8…`/`0xFC…` peripheral address cast survives in its output.
- Point `UNUSED_MEMORY_SPACE_ADDRESS` (`cpu_specific.h:124`, written at `voice_sample.cpp:1479`) at a host scratch buffer.
- Take the argon and etl pins from `firmware/lib/CMakeLists.txt` rather than repeating them.
- Audit the roughly 100 `long` uses once: `long` is 64-bit on the host and 32-bit on the Deluge.
- **Another firmware checkout:** the CMake option `-DDELUGE_FIRMWARE_DIR=<path>` builds against a worktree, for example one with unmerged Generative work.
- **Repo layout:**

  | Path | Holds |
  |---|---|
  | `firmware/` | the submodule |
  | `engine/` | C++: `platform/` (hardware stand-ins), `core/` (Engine API), `pump/` (real time), `server/` (protocol), `cli/` |
  | `proto/engine.proto` | the protocol schema |
  | `gui/` | the Flutter app |
  | `tools/` | Python: the protocol client, the Parity tools, the check script |
  | `tests/` | Engine tests and CC0 fixtures |

  Nothing under `build/` is tracked.

### 3.4 Startup

Don't call `deluge_main()`. It talks to the PIC, waits on the OLED and USB, and loads the startup song.

- The host runs its own init list, then the firmware's own scheduler: `registerTasks()` (`deluge.cpp:557`) and `startTaskManager()`. The list is the one in `spike/host/drivers/perform_engine.cpp` on branch `task/perform-in-engine`. It includes the calls MIDI input and Perform need (`encoders::init`, `runtimeFeatureSettings.readSettingsFromFile`, `MIDIDeviceManager::readDevicesFromFile`, `midiFollow.readDefaultsFromFile`, `inputRoutine`, the `GRAPHICS_ROUTINE` timer).
- CI hashes the text of `deluge_main` and `registerTasks`, so a pin move that changes them fails loudly and the list gets checked against the new text.
- Seam S5 splits `deluge_main` so the host can call the firmware's own engine init. When S5 is on the pin, the host list and the hash guard go. Nothing waits for S5.

### 3.5 Platform layer

- **Virtual clock.** `getTimerValue` advances by a fixed 33 ticks (1 µs) per read, and the simulated DMA position is a pure function of that clock. The Perform test proved it: no underruns, direness 0, and renders that repeat bit for bit. Don't change the 33 without rerendering the goldens. At 1000 ticks Perform entry never finishes.
  - **Offline**, the clock runs free. A 60 s Piece renders in about 2 s.
  - **In real time**, the engine thread sleeps whenever virtual time is ahead of the frames the audio backend has taken plus the FIFO target (§3.8). The audio device's clock paces the firmware, so the two can't drift apart.
  - `--pace F` holds the clock to F times wall time. Only the firmware's probe scripts need it (§3.7).
- **Allocator.** Link-time replacement of `GeneralMemoryAllocator`, based on `malloc`, as in the spike's `host_gma.cpp`. Add a byte budget with LRU eviction for sample clusters (default 1 GiB), so a long session doesn't keep every cluster in memory.
- **Freezes.** `FREEZE_WITH_ERROR` and the display's error screen report the error code, what was loaded and a backtrace, then exit with status 70. They never busy-wait.
- **Settings.** Defaults, as with erased flash.
- **Stubs** for USB, OLED, PIC, CV, gate, the trigger clock and GPIO, and `dmaBootStates` for the test port. Most are in the spike.
- **Apple-only code** stays in three places: the CoreAudio backend, the CoreMIDI backend and the card image's `newfs_msdos` call. Everything else builds as portable C++.

### 3.6 Storage: the card image

- The Engine builds a **card image** (FAT32) from the user's card folder and caches it under `~/Library/Caches/deluge-engine/cards/`. FatFS (`ff.c`) reads it through a host sector device. A shim at the `f_open` level isn't enough, because samples are read as raw clusters (`audio_file_manager.cpp:830-845`, `:1002`).
  - Use 32 KiB clusters, as `delugemu/scripts/mksd.sh` does. `Cluster::size` follows the FAT cluster size.
  - The firmware's FatFS is built without `f_mkfs`, so format with `newfs_msdos` (built into macOS) and fill the image through the linked FatFS.
  - Refresh the image incrementally from a manifest of path, size and mtime. Report progress (§7.4). The image is as large as the folder.
  - Build and refresh happen before the firmware boots, on their own thread, never on the engine thread.
- **Read-time model.** Each read waits out 300 µs plus 40 µs per sector of virtual time, through the firmware's own `yieldingRoutineWithTimeoutForSD()`. It is on in every mode. Without it, Perform entry takes 0 ms, preloads land earlier than on a Deluge, and `perform_runner.txt` fails. The Perform test saw one DMA overrun in 60 s with the model on (a read inside a nested SD routine). E3 looks for the cause. If it isn't found there, record it in `docs/implementation-notes.md` and go on.
- **Writes never reach the image.** The live Engine and the render workers open the same image read-only. A firmware write goes to an in-memory overlay of changed sectors that belongs to the process and is dropped when it exits. So settings files, Capture songs and Recipe files the firmware writes are gone after a restart. Saving presets is v2.

### 3.7 The test port inside the Engine

The firmware's test port takes text lines and sends test events. The Engine reaches it three ways:

| Route | How | Used for |
|---|---|---|
| Inject | host code calls `TestPort::injectReceived()` at fixed virtual times and reads test events from a host sink | everything the Engine itself asks of Perform. Deterministic. |
| DIN over UDP | `--din-udp LISTEN:SEND` carries raw MIDI bytes in UDP datagrams, framed like delugemu's bridge | running the firmware's `perform_*.txt` scripts with `deluge_probe.py --udp`, at `--pace 1` |
| DIN from MIDI | bytes from CoreMIDI or from `Note` messages go to the DIN UART stand-in (`uartGetChar`), so the firmware's own MIDI parser handles them (`midi_engine.cpp:717`) | live playing |

The firmware's probe times its expects by the wall clock, so script runs need `--pace 1`. At pace 4 most scripts pass, at 10 some fail.

### 3.8 Threads and real time

- One **engine thread** owns all firmware state. Nothing else calls firmware code.
- The engine thread copies finished frames from the 128-frame SSI ring into a lock-free FIFO and sleeps when the FIFO is at its target (default 512 frames).
- The **audio backend** only drains the FIFO. CoreAudio does it from its callback. The null backend does it from a timer and throws the frames away, or writes them to a file for tests. Latency is the FIFO target, plus up to 128 ring frames, plus the device buffer.
- **MIDI in:** the CoreMIDI callback pushes bytes onto a single-producer queue, and the engine thread feeds them to the DIN UART stand-in. v1 delivers each event at once, so timing jitters by up to one buffer.
- **Commands** from the protocol go on a queue. A host task registered with the firmware scheduler drains it, one command at a time: it never starts a command while another is running, because a preset load yields to the scheduler and the task runs again (§5). It skips a turn while `sdRoutineLock` is set, as `test_port.cpp` does for its own lines. Other threads read state from snapshots the engine thread publishes.
- **The player** plays a WAV file by path, a Render or an auditioned sample, and mixes it into the output after the FIFO. It doesn't go through the firmware (§6.5), so it works before the firmware runs live.
- **Watchdog.** A separate thread watches the engine thread. If no audio frame was produced for 2 s of wall time while the backend wanted frames, it reports a freeze with code `HANG` and exits the process.

### 3.9 Engine API and CLI

Three layers:

1. **Engine** (`engine/core`): single-threaded and deterministic. `boot(config)`, `setSetup(bindings)`, `audition(path, note)`, `midi(bytes)`, `testLine(text)`, `render(buffer, frames)`, and a callback for freezes, errors, test events and voice count.
2. **Pump** (`engine/pump`): the engine thread, FIFO, command queue, player and watchdog from §3.8.
3. **Front ends:**
   - `deluge-engine render`: offline to a WAV, for a preset with notes or for a Piece (§6.2). The render worker is this command.
   - `deluge-engine play`: real time from MIDI, for a preset or a Setup, without the protocol. For tests and for trying things by hand.
   - `deluge-engine serve --socket PATH`: the live Engine the GUI starts (§7).

All three take `--card FOLDER` and `--audio null|default|NAME`.

## 4. Firmware seams

Each seam is a small PR to gismya/deluge-generative. The contents of S1 to S5 are in the spike's `spike/overlay.diff` and in [spike-findings.md](spike-findings.md), "Firmware seams and fixes needed".

| # | Seam | Why | Ticket |
|---|---|---|---|
| S1 | 64-bit pointer hygiene: `uintptr_t` for pointer round trips (all 110 cast sites, mechanical); the `String` reference count as `int32_t`; `Song::backedUpParamManagers` key width; the Kit render list keeps the full `Drum*` | crashes, empty strings and failed preset loads on 64-bit | F1 |
| S2 | `swapEndianness32/2x16` asm only on `__arm__`, else `__builtin_bswap32` | silently returns 0 on arm64 | F1 |
| S3 | Clang portability: headers, missing includes, `0L`, `strrchr`, the VLA initializer, `__arm__` guards on the PMU asm and the 3 Generative layout `static_assert`s, `PLACE_*` macros empty when not ELF; plus the uninitialised `noteRowId` fix (`instrument_clip.cpp:963-1033`) | doesn't build with clang; the UB turns into an E380 freeze | F2 |
| S4 | The `String::set` S001 check asks the allocator instead of comparing with `EXTERNAL_MEMORY_END` | a host allocator can't meet fixed address ranges | F3 |
| S5 | Split `deluge_main` into hardware init, engine init and `registerTasks()` | the host reuses the firmware's own startup (§3.4). Optional. It changes the Release build, so the user merges it. | F5 |
| S6 | Test-port lines `load synth PATH`, `load kit PATH` and `midi S D1 D2`, modelled on `load song`. Only under `ENABLE_SYSEX_TEST`. | the preset Reference in delugemu (§9) | F4 |
| S7 | Test-port lines `next recipe …` that set the Recipe and Seed the next roll takes | choosing a Piece at run time (§6.1) | none: merged |

**S7 is delivered.** The firmware built it in gismya/deluge-generative#527 and #528, both merged (`generative` at ddeef7fad). It is not an Engine ticket. Its lines are documented in the firmware's `docs/generative/spec/21-testing.md` §21.3, and `gen_emu.py capture` sends the same lines.

**Seams merge into `generative` directly,** under §2. A ticket that needs a seam is blocked until the seam's PR is merged and the pin has moved to a commit that contains it. There is no branch of unmerged seams and no `patches/` folder.

Firmware rules apply to these PRs: the firmware's `AGENTS.md` (hooks, `git delugepush`, the **Run tests** check, `docs/upstream-candidates.md` for fixes that aren't Generative-specific, which is all of S1 to S4).

## 5. Setups

A Setup is a list of bindings. Each binding is a MIDI channel (1 to 16) and a Synth or Kit preset path. The Engine plays all of them at once from MIDI: a message on channel c from any input goes to the preset bound to c. A channel with no binding is ignored.

The spike in [#42](https://github.com/gismya/deluge-engine/issues/42) proved this with no firmware change. Its findings are [setup-findings.md](setup-findings.md), with the spike code on branch `spike/setup-routing` (f13436f), and its driver is `spike/host/drivers/setup_engine.cpp`. A second route, a song file per Setup through `load song`, wasn't needed.

- **In the firmware,** a Setup lives in the running song, built by host code with the firmware's own calls. MIDI follow is off, and the blank song's default clip is dropped.
- **Building a binding:**
  1. Load the preset.
  2. Give it an always-active session clip, linked the way Generative mode's `link()` does it in `perform_song.cpp`.
  3. Set its MIDI input (`Instrument::midiInput`) to the channel, with no device, so any input matches.
  4. For a Kit, also set the first-row note to 36. Note 36 then plays the first drum, 37 the second, and so on.
- **One change at a time.** Setup changes run on the engine thread, one after another. A preset load yields to the scheduler, which runs host tasks again, so the command queue must never start a command while another is running.
- **Changing a binding:** load the new preset beside the old one, move the binding to it, release the old preset's notes, and free the old preset after its tail (2 s). That leaves no gap, and notes held on other channels are unaffected. Don't use `Song::replaceInstrument`: it cuts the old notes dead, which clicks.
- **MIDI during a load** reaches the old preset, and those notes are released with it. A held note doesn't carry over to the new preset. Both are accepted.
- **Changes from the GUI.** The GUI sends the whole Setup each time (§7.3). The Engine compares it with what is loaded and changes only the bindings that differ.
- **Errors per binding:** a missing file, a preset that fails to load, a missing sample. The other bindings still load.
- **A single preset** in the CLI (`--preset PATH`) is routed by MIDI follow from any channel, set up as the test port's `hold midi_setup` does. It exists before Setups do (E4).
- **Audition** uses one more instrument, built like a binding, on the highest channel that has no binding. The Engine sends it the note itself. `Audition{path, note}` loads the preset there if it isn't the one loaded, and plays the note for the given time. Adding and removing it doesn't disturb the Setup. Release its notes and wait out the tail before removing it, or the tail is cut. With all 16 channels bound, `Audition` of a preset answers with an error. For a `.wav` path (a lane's sample), the player plays the file from the card folder.
- **Comparing renders:** compare levels, not samples. Note timing shifts by up to about a millisecond after a long command, and free-running oscillators differ from run to run.

## 6. Pieces

### 6.1 Choosing a Piece

The GUI describes a Piece by a genre, a Seed and Sound picks. The Engine turns that into S7's test-port lines, one field a line:

```
next recipe genre techno-dub
next recipe seed 12345
next recipe entropy 12345
next recipe part 3 SYNTHS/002 Basic Square Bass.XML
next recipe lane 0 SAMPLES/DRUMS/Snare/909 Snare.wav
```

- **Seed.** The GUI's one Seed number sets both `seed` and `entropy`. `entropy` is what the firmware rolls the tempo, key, scale and unset Sound picks from, so one number fixes the whole Piece. The message can carry a separate entropy (§7.5), and v1's GUI never does.
- **Sound picks.** `part P PATH` takes the roster index (0 to 5) and `lane L PATH` the lane's index in the firmware's `Lane` order (0 to 14). A Part or lane with no pick is rolled from the Palette.
- **Other fields** (the four macros, tempo, key, scale, swing) are in the message and optional. v1's GUI leaves them out, so the roll sets them.
- The firmware answers `gen_next_recipe taken` once the Recipe is the one that plays. A render that doesn't see it fails.
- Palette override files on the card are not used for picks: they also change later re-rolls. Recipe files exist in the firmware now. Loading one is a later, second route.

### 6.2 Rendering a Piece

`deluge-engine render --piece` does this, with every step at a fixed virtual time through the inject route (§3.7):

1. Boot on the card image.
2. Inject the `next recipe` lines.
3. Enter Perform with the genre and wait for `gen_next_recipe taken`. The entry lines are a text file in this repo (`engine/cli/piece_entry.txt`), written from the firmware's `perform_next_recipe.txt` and from what `gen_emu.py capture` sends. A pin move reruns the Piece tests, which catch a menu that changed.
4. Press PLAY. Record audio from the `gen_start` event for the requested length (default 60 s, at most 20 minutes).
5. Write the WAV (44.1 kHz, stereo, 24-bit) to the path the request gives, and report the result.

The result (`RenderDone`, §7.5) carries:

- **The Recipe as played:** tempo, key, scale, swing, macros, and every Part's and lane's Sound pick, including the rolled ones. Read from the firmware's Current Recipe or from its `gen_sound` events.
- **Section markers:** from the `gen_section` events, as name and time.
- **Peaks:** about 2000 min/max pairs for the waveform.
- **Notes per Part and lane,** for the Timeline tab: start, length, pitch and velocity. Three sources, tried in order:
  1. Perform's own log of the Piece, which Capture writes its songs from, read by host code at the end of the render.
  2. The firmware harness's `generator_render --midi-only` on the same Recipe and Seed, built from the submodule. `gen_emu.py` already uses it to check captures.
  3. No notes. The Timeline then shows the Sections and empty rows, and the ticket's handoff says so.
- **Warnings:** each sound the firmware reported missing or silent (`gen_sound_missing`).
- **The peak voice count** over the render (§10).

The same request renders the same bytes every time. A freeze during a render ends the worker, and the live Engine reports `RenderFailed` with the freeze code.

A card folder without the Generative pack plays FX lanes with no sample as silence, as the Deluge does. The warnings name them.

### 6.3 Genres and Palettes

The Engine sends the GUI the list of genres. Each has its Parts in roster order, the lanes of its Drums and FX Parts, and for each Part and lane its Palette: the sounds and their weights. A sound's share of re-rolls is its weight over the Palette's total. Host code reads all of it from the firmware's genre and Palette tables after the card is ready, so Palette override files on the card count. Until the firmware runs live in the Engine (E12), a short-lived helper process reads the lists: `deluge-engine list --card FOLDER`. The GUI has no genre knowledge built in.

If a table can't be read from host code without a firmware change, add a getter under `ENABLE_SYSEX_TEST` as a seam PR (§2, §4).

### 6.4 Render workers

- The live Engine starts one worker process per `RenderPiece`. At most two run at once. More wait in a queue.
- A worker's stdout carries its progress and result as protocol frames. The live Engine passes them on.
- A worker writes to `<path>.part` and renames it when the render is done. `CancelRender` kills the worker and removes the `.part` file.
- Live sound never stops for a render, and A and B render in parallel.

### 6.5 Playing and keeping Renders

**The GUI owns the Render files.** The Engine writes a WAV to the path it is given and plays a WAV by path. It never lists, keeps or deletes Renders.

- `RenderPiece` carries the path to write. The GUI puts Renders in `~/Library/Caches/deluge-engine/renders/` and stores each Render's `RenderDone` beside its WAV.
- The player plays one file at a time. `Play{path, position}` starts it or switches to it. Switching between A and B at the same position has no gap. The player sends `Position` about 10 times a second.
- **The keep rule,** applied by the GUI: it deletes a Render as soon as it is none of the current A, the current B, one of the 10 most recent, or kept. A Render is kept when the user marks it or exports it with "Export WAV…", which copies the file. On quit the GUI deletes everything that isn't kept. Before deleting the file that is playing, it sends `Stop`.

### 6.6 Pieces live

`PlayPiece{recipe}` makes the live Engine enter Perform and play the Piece in real time, with the same lines as §6.2. `StopPiece` leaves Perform. While a Piece plays live, the Setup is unloaded, and the Engine loads it again after `StopPiece`. The capability `play_live` is absent until this works, and the GUI hides the "Play live" button without it. This is the last v1 ticket and a stretch goal: nothing depends on it.

## 7. The protocol

### 7.1 Transport and format

- A Unix domain socket. The GUI picks a path under `$TMPDIR` (the whole path under 100 bytes, else under `/tmp`) and starts `deluge-engine serve --socket PATH`. The Engine listens. The GUI connects, retrying for 5 s. One client at a time.
- A frame is a 4-byte little-endian length and then one protobuf message. `ToEngine` and `FromEngine` are the two envelope messages, each a `oneof` of the kinds below. A frame is at most 16 MiB.
- The schema is one proto3 file, `proto/engine.proto`. It generates C++ for the Engine at build time. The Dart and Python code is generated by `tools/gen_proto.py` and committed, and CI fails when regenerating changes it.
- The Engine's stderr is a plain log. `--trace` logs every message in protobuf text format.
- `tools/engine_client.py` is the Python client that agents and CI drive the Engine with.

### 7.2 Versions and capabilities

The Engine's first message is `Hello{protocol_version, engine_version, firmware_commit, capabilities}`. v1 needs an exact `protocol_version` match (it starts at 1), because the GUI and the Engine ship in one bundle. On a mismatch the GUI shows an error and doesn't go on. Capabilities are strings: `setups`, `audition`, `pieces`, `render`, `play_live`. The GUI hides what a Backend doesn't offer.

### 7.3 State

- **The GUI owns the documents:** the card folder, the Setup's bindings, each Piece's genre, Seed and Sound picks, the device choices, the settings, and the Renders with their files (§6.5). It saves them in `~/Library/Application Support/deluge-engine/state.json`.
- **Commands state the whole result,** not an edit. `SetSetup` carries every binding each time.
- **The Engine keeps nothing across a restart.** It replies with what it applied, with an error per item that failed.
- **The Backend supplies the lists:** the presets on the card, and the genres with their Parts, lanes and Palettes.

### 7.4 Messages: card, Setup, devices, status

GUI to Engine:

| Message | Fields | Effect |
|---|---|---|
| `SetCard` | `folder` | build or refresh the card image, send `CardStatus`, then `Catalog` and `Genres` |
| `SetSetup` | `bindings[]{channel, path}` | apply the Setup (§5), answer `SetupApplied` |
| `Audition` | `path, note, velocity, ms` | play a sound briefly (§5) |
| `Note` | `channel, note, velocity, on` | as MIDI from the on-screen keyboard |
| `SetDevices` | `audio_output, midi_inputs[]` | pick the output and the inputs. Empty means the system default output and every input. |
| `Shutdown` | | exit with status 0 |

Engine to GUI:

| Message | Fields |
|---|---|
| `Hello` | §7.2 |
| `Heartbeat` | `voices, cpu_load, underruns`, 4 times a second |
| `CardStatus` | one of `progress{done, total}`, `ready`, `error{text}` |
| `Catalog` | `synths[]`, `kits[]`, each `{path, name}` |
| `Genres` | §6.3 |
| `SetupApplied` | `results[]{channel, ok, error}` |
| `MidiActivity` | `channel`, at most 10 a second per channel |
| `Devices` | `audio_outputs[]`, `midi_inputs[]`, sent at start and when they change |
| `Freeze` | `code, message, loaded`, sent just before the Engine exits |

### 7.5 Messages: Pieces and Renders

GUI to Engine:

| Message | Fields |
|---|---|
| `RenderPiece` | `id, recipe, length_s, wav_path` |
| `CancelRender` | `id` |
| `Play` | `wav_path, position_s` |
| `Seek` | `position_s` |
| `Stop` | |
| `PlayPiece`, `StopPiece` | `recipe` (§6.6) |

`recipe` is `{genre, seed, entropy?, macros[4]?, tempo?, key?, scale?, swing?, picks[]{part | lane, path}}`.

Engine to GUI:

| Message | Fields |
|---|---|
| `RenderProgress` | `id, done_s, total_s` |
| `RenderDone` | `id, wav_path, duration_s, recipe` (as played), `sections[]{name, time_s}`, `peaks`, `notes[]`, `warnings[]`, `peak_voices` |
| `RenderFailed` | `id, error, freeze_code` |
| `Position` | `wav_path, time_s`, while playing |

### 7.6 Adding to the protocol

A ticket may add fields to a message. A new kind of message is a spec change. During the unattended run, the implementer adds it, raises `protocol_version`, writes it into this section in the same PR, and names it in the handoff. That is not a reason to stop.

### 7.7 Freezes and hangs

- The Engine's protocol thread sends `Heartbeat`, not the engine thread. So building a card image or loading a large preset doesn't look like a hang. The watchdog (§3.8) turns a stuck engine thread into a `Freeze` with code `HANG`.
- The GUI restarts the Engine when the process exits without a `Shutdown`, when it receives `Freeze`, or after 2 s without a `Heartbeat`. After a restart it sends the card, the Setup and the devices again.
- After 3 restarts within a minute the GUI stops restarting. It shows the last freeze code and a Restart button.
- The status bar shows each freeze's code and what was loaded.

### 7.8 Room for a real Deluge

Messages name Deluge things (card paths, MIDI channels, genres, Seeds), never Engine internals. A Deluge Backend would be a small bridge process that speaks this protocol on one side and the sysex test port on the other, with no GUI change. It would offer fewer capabilities. The bridge is out of scope.

## 8. The GUI

A Flutter app in `gui/`, for macOS in v1. It is written with nothing that stops it from building for Android, Windows and Linux later.

**The reference design is round 3 of the prototype:** branch `prototype/screens` at f0b02bf, under `prototype/screens/`. Read `lib/main.dart`'s header and its `README.md`, and look at `test/goldens/*.png`. Build the screens to match those images. The prototype's code is throwaway: take its tokens, sizes and layout, and write the app's own code.

- **Shell.** A top bar with **Piece | Setup**, the card folder, the Engine's state, the voice count and a `{}` control that shows the state for debugging. A status line at the bottom.
- **First launch.** With no card folder, the app shows one screen that asks for it. While the card image builds, it shows the progress.
- **Setup screen.** The 16 MIDI channels as a 4×4 grid of pads, the picker beside it, and an audition keyboard below. A pad shows its preset, Synth or Kit, MIDI activity and a clear button.
- **Piece screen.** One bar with **Compare | Timeline** tabs, then Genre, Seed, the tempo and key as played, Auto-render, Play live and Render B. Play live is hidden until the Backend offers `play_live`.
  - **Compare:** the A and B waveforms on one time axis with the Sections between them, then a table with A's Sound pick beside the working pick for every Part and lane, differing rows tinted, a copy-back arrow per row, "Revert to A" and "Keep B as A".
  - **Timeline:** a row per Part and lane showing its notes across the Sections, with the two Renders as rows on the same time axis and one playhead through everything.
  - The tabs hold no state. The selected row, A/B, the playhead, the playing Render and whether the picker is open live in one model, so switching tabs only changes the view.
- **The picker** is the one way to change a sound, on both tabs and in Setup. It shows the selected row's Palette as pads with each sound's share of re-rolls, then a search over every preset. A tap picks and auditions. It sits beside the screen, or below it under 900 dp wide, and folds to a rail.
- **The working picks.** After a genre or Seed change, the GUI renders with no picks, and the Recipe as played in that Render gives the working picks. From then on it sends every pick. With Auto-render on, a pick renders B again. A newer auto-render cancels an older one that hasn't finished.
- **Renders.** The GUI owns the files and applies the keep rule (§6.5).
- **Voice count.** Each Render shows its peak voice count beside it. The app's settings hold a threshold, and a Render above it is highlighted. The threshold has no default: until the user sets it, after calibrating on a Deluge, nothing is highlighted.
- **Sizing.** Dark mode only. Controls are 44 dp inside 48 dp hit areas, on every platform. Nothing needs a hover, a right click, a drag or a keyboard. Keyboard shortcuts are extras, as the prototype's README lists them.
- **Known gaps in the prototype, to fix:** the audition keyboard's black keys are under 48 dp wide, and at small sizes the Timeline doesn't scroll a selected lane into view.

**Structure.**
- Modules follow the prototype's split: `shell`, `compare`, `timeline`, `picker`, `setup`, `ui` (the design system), plus `model` (the documents and view state) and `backend`.
- `Backend` is a Dart interface with two implementations: `EngineBackend` (the socket, the Engine process and the restart policy of §7.7) and `FakeBackend` (in memory, with fixed data, for tests and for building screens before the Engine can serve them).
- State is plain `ChangeNotifier` models, as in the prototype. No state-management package.

**Tests.**
- Widget tests and golden tests run headless with `flutter test`, against `FakeBackend`. Goldens cover Setup, Compare and Timeline, with the picker open and closed, at 1440×900, 1100×720, 1280×800 and 800×1280.
- Golden images compare with a tolerance of 0.5% of pixels, because text rendering differs between macOS versions. CI is the reference machine.
- `integration_test`s drive the built app against the real Engine with `--audio null` on `pack/` content: the Piece flow (G5), then Setups and a restart (G7).
- The fake data may use factory preset names. It never includes factory audio.

## 9. Parity

**Reference:** delugemu running the ARM firmware built from the same firmware commit as the Engine, never the Engine itself. delugemu is not a real Deluge, but it runs the same ARM code.

### 9.1 Presets

- **Driving both sides.** A test-port script (S6) loads a preset and queues timed `midi` lines with `wait`. Under delugemu's icount mode those times are firmware time. The Engine runs the same script through the inject route. The Reference driver reuses the firmware's `scripts/generative` modules from the submodule (`gen_emu.py`'s session and capture code).
- **The script per preset:** C2 for 1 s, C4 for 1 s, then C3, E3 and G3 together for 2 s, each followed by 1.5 s of release. A Kit plays each of its first 8 drums once, 0.5 s apart.
- **Metrics are phase-insensitive.** Oscillator phases run free from boot, so a null test can't work. Align the note onsets by envelope, then compare per note:

  | Metric | Starting tolerance |
  |---|---|
  | Level | ≤ 0.5 dB |
  | RMS envelope, 10 ms windows | ≤ 1.5 dB |
  | Fundamental frequency | ± 3 cents |
  | Third-octave spectrum | ≤ 1.5 dB per band |
  | Stereo balance | ≤ 0.5 dB |
  | Release time | ± 10% |

- **Calibration.** Render each Reference twice, the second with its start shifted by 37 ms, to measure how much the preset varies by itself (random LFO phase, noise). A preset whose self-variation is above half a tolerance goes on a listening list, not the pass list.
- **Tiers.**
  - **Smoke:** every `pack/` synth, in CI, against metric References stored in the repo. Locally also about 12 factory presets covering each sound type (subtractive, FM, ring mod, wavetable, sample, DX7, a Kit).
  - **Full:** all 171 factory synths and 43 kits, locally.
- **Render window.** Render with two host window sizes. If they agree within tolerance, stop worrying about window size.

### 9.2 Is delugemu fast enough for the full tier?

Yes, by this budget. The full tier is 214 presets at about 8 s each, twice for calibration: about 57 minutes of audio. `gen_emu.py capture` renders 60 s in about 20 s on this machine when it is quiet and 68 s when it is busy. One delugemu then needs 20 to 65 minutes, and four in parallel need under 20.

The rules E5 follows:
- Load many presets per delugemu boot, and run 4 delugemu instances at once. They run under icount, so they take no slot from the firmware's emulator pool and host load doesn't change their output.
- Cache References by firmware commit, preset file hash and script hash. A second run costs nothing.
- Time the first 10 presets. If the full tier projects past 3 hours of wall time, run a subset instead: the 12 smoke presets plus every 4th synth and every 4th kit by number. The report lists the rest as "not run". This is not a reason to stop.

### 9.3 Pieces

A Piece's audio can't be judged note by note. Two delugemu captures of one Recipe from different builds already differ in free-running state: the firmware's own measurement was level per 4 s within about 8% and an envelope correlation of 0.48. The preset tiers judge each sound. Piece Parity asks one question: does the Engine play the same Piece at the same levels?

The Reference is `gen_emu.py capture` in delugemu, with the same genre, Seed and picks. It sends the same `next recipe` lines the Engine does. A Piece passes when all three hold:

1. **The same Recipe.** The Recipe as played in the Engine (tempo, key, scale, swing, macros, every Sound pick) equals the Reference's.
2. **The same notes.** The Engine's WAV passes `gen_emu.py`'s own check against the harness render of that Recipe: sound in the beat after every step where the harness starts a note.
3. **The same levels,** after aligning the two files by their 10 ms energy envelopes within ±50 ms:

   | Metric | Starting tolerance |
   |---|---|
   | Whole-file RMS | ≤ 1.0 dB |
   | RMS per 4 s window | ≤ 1.5 dB |
   | Octave bands, 40 Hz to 20 kHz, whole file | ≤ 1.5 dB |
   | Stereo balance | ≤ 1.0 dB |

**Calibration** is as for presets: capture the Reference twice, the second with entry delayed by 0.5 s of virtual time. A metric whose self-variation is above half its tolerance puts the Piece on the listening list.

**The set:** every genre the firmware lists, two Seeds each (7 and 12345), 60 s, rolled picks, on the plain factory card. That is about 30 minutes of delugemu, cached like the preset References. The Perform test's one sample (Dub techno, Seed 7) was within 0.14 dB per window and 0.55 dB per band.

Piece Parity is local only. CI checks that a Piece on `pack/` content renders the same bytes twice.

### 9.4 Reports

`tools/parity` writes `parity/report.md`: per-preset and per-Piece metrics with pass, fail, listen or not run. It holds no audio. It also builds a blind, level-matched A/B listening pack in `~/.cache/deluge-engine/listening/`, worst first plus a random few, for the user.

### 9.5 What the agent must not do

- claim "not audibly different". It reports metrics and builds the listening pack.
- claim delugemu equals the Deluge
- use a Reference rendered while the firmware's `cpuDireness` was above 0 (the test port reports it)
- judge real-time feel
- loosen a tolerance to turn a check green. A tolerance that looks wrong goes in the report as a question for the user, and the preset or Piece stays failed.

## 10. Host behaviour that differs

- **Culling and direness.** On the Deluge, CPU load drops voices and switches oscillators, interpolation and the ladder filter to cheaper versions (`oscillator.cpp:74`, `sample_controls.cpp:37`, `lpladder.cpp:69`). The virtual clock keeps direness at 0 in the Engine. v1 has no culling and reports the voice count, live and as each Render's peak. A dense Piece may sound richer in the Engine than on the Deluge. The user accepted that. The GUI highlights a Render whose peak passes a threshold the user sets (§8).
- **Card writes** are dropped (§3.6).
- **MIDI timing** jitters by up to one buffer (§3.8).
- **Render window:** checked by the Parity tools (§9.1).
- **FMA and denormals:** not audible. `-ffp-contract=off` and FZ (§3.3) keep the Engine close anyway.

## 11. CI and checks

- GitHub Actions on a macOS arm64 runner. The firmware submodule is public.
- **Engine jobs:** an ASan plus UBSan build at `-O1`, and a release build at `-O2`. Tests:
  - unit tests of the platform layer
  - load and render every `pack/` preset twice under the sanitizers
  - goldens of `pack/` renders, rendered twice and compared bit for bit
  - the smoke Parity tier against stored metric References
  - the real-time path on the null backend, driven by injected MIDI bytes
  - the protocol, driven by `tools/engine_client.py` over the socket
  - a Piece with every pick set to `pack/` content, rendered twice and compared bit for bit
- **GUI job:** install Flutter with `subosito/flutter-action`, pinned to one version. Run `flutter analyze` and `flutter test`. The `integration_test`s against the real Engine run once G5 lands.
- Every test has a timeout, and a freeze aborts the run.
- A nightly canary builds against the tip of the firmware's `generative` branch and opens an issue labelled `needs-triage` when it fails. The orchestrator doesn't act on canary issues.
- **One check script,** `tools/check.py`, runs everything CI runs. Agents run it before pushing. E1 creates it, and each ticket adds its tests to it.
- **Local only:** anything with the factory card or delugemu: the full Parity tier, Piece Parity, and the firmware's `perform_*.txt` scripts against the Engine (`deluge_probe.py --udp`, `--pace 1`).

## 12. Packaging

v1's app is built and run on the user's own Mac. It is not distributed.

- `flutter build macos` makes the app. The build copies the `deluge-engine` binary into the bundle at `Contents/MacOS/deluge-engine`, and the GUI starts it from there by absolute path.
- **App Sandbox is off.** Flutter's macOS template turns it on; remove the entitlement. The app then reads any card folder and starts the Engine with no entitlement work.
- **Signing is ad hoc** (`codesign -s -`), which a local build needs to run on Apple Silicon. No Developer ID, no notarisation, no installer. Those need the user's Apple account, and nothing in v1 needs them.
- One command builds the Engine and the app and runs it: `tools/run_app.py`. The README says how.

Out of scope: a Developer ID signature, notarisation, a DMG, automatic updates and the Mac App Store.

## 13. Order of work and tickets

### 13.1 Order

When several tickets are free, take the one earliest in this list. The dependencies in the table are the only hard limits.

1. **Foundations and presets offline:** F1 to F4, E1, E2, E3, E4.
2. **Pieces offline, usable in the app:** E14, E10, E21, E15, E16 in the Engine, and G1, G3, G5, G6 in the GUI.
3. **Parity:** E5, E6, E7 for presets, E17 for Pieces, E18 for song FX, E20 for DX7.
4. **Real time:** E8, E9.
5. **Setups:** E11, E12, with G2 and G7.
6. **Kits:** E13.
7. **The Timeline tab:** G4, the last GUI screen. Compare never waits for it.
8. **Pieces live:** E19, a stretch goal. Then F5.

The GUI is a second track. It builds against `FakeBackend` from the day the protocol schema lands (E10), so it never waits for the Engine. Run one Engine ticket and one GUI ticket at a time when both are free.

### 13.2 Tickets

F tickets are PRs to gismya/deluge-generative. E tickets (Engine) and G tickets (GUI) are PRs to this repo. All are sub-issues of [#1](https://github.com/gismya/deluge-engine/issues/1), with blocking links that match the last column. Each is sized for one agent session. The IDs are names, not an order: §13.1 gives the order.

| ID | Issue | Ticket | Spec | Blocked by |
|---|---|---|---|---|
| F1 | #2 | S1 + S2: 64-bit pointer hygiene and `swapEndianness` | §4 | |
| F2 | #3 | S3: clang portability and the `noteRowId` fix | §4 | |
| F3 | #4 | S4: allocator-based S001 check | §4 | |
| F4 | #5 | S6: test-port `load synth`, `load kit` and `midi` lines | §4, §9.1 | |
| F5 | #22 | S5: split `deluge_main` (optional, the user merges it) | §3.4, §4 | |
| E1 | #6 | Build: CMake, submodule, in-place compile, check script, CI | §3.3, §11 | F1, F2, F3 |
| E2 | #7 | Platform layer: virtual clock, scheduler startup, allocator, freezes | §3.4, §3.5 | E1 |
| E3 | #8 | Card image: builder, sector device, read-time model, write overlay | §3.6 | E1 |
| E4 | #9 | Engine API and `deluge-engine render` for a preset | §3.7, §3.9 | E2, E3 |
| E5 | #10 | Parity: the Reference driver for presets | §9.1, §9.2 | E4, F4 |
| E6 | #23 | Parity: metrics, calibration, report, listening pack, smoke tier | §9.1, §9.4 | E5 |
| E7 | #24 | Parity: the full synth tier and its fixes | §9.1, §9.2 | E6 |
| E8 | #11 | Real time: the pump, `deluge-engine play` | §3.8 | E4, E21 |
| E9 | #25 | CoreMIDI input | §3.8 | E8 |
| E10 | #26 | Protocol: schema, code generation, `serve`, Python client | §7.1, §7.2 | E1 |
| E11 | #27 | Setups in the firmware | §5 | E8 |
| E12 | #28 | Protocol: the firmware live in `serve`, Setup, notes, audition, MIDI devices | §7.4, §7.7 | E9, E11, E15 |
| E13 | #12 | Kits: in Setups, and the Kit Parity tier | §5, §9.1 | E6, E11 |
| E14 | #29 | Pieces offline: the Perform driver and `render --piece` | §6.1, §6.2 | E4 |
| E15 | #30 | Protocol: card, catalog, genres, render workers, `RenderPiece` | §6.3, §6.4, §7.4, §7.5 | E10, E14 |
| E16 | #31 | The Render player | §6.5, §7.5 | E15, E21 |
| E17 | #32 | Piece Parity | §9.3 | E6, E14 |
| E18 | #33 | Song FX Parity | §9 | E7, E17 |
| E19 | #34 | Pieces live (stretch goal) | §6.6 | E12 |
| E20 | #14 | DX7 kernel | §9.1 | E6 |
| E21 | #47 | Audio output: null and CoreAudio backends | §3.8 | E1 |
| G1 | #35 | GUI: app shell, design system, Backend client, fake Backend, CI | §8, §7.7 | E10 |
| G2 | #36 | GUI: Setup screen and the picker | §8 | G1 |
| G3 | #37 | GUI: Piece screen, Compare tab, the keep rule | §8, §6.5 | G1 |
| G4 | #38 | GUI: Timeline tab | §8 | G3 |
| G5 | #39 | App bundle, end-to-end test of the Piece flow, README | §12, §11 | G3, E16 |
| G6 | #50 | GUI: peak voice count and its threshold setting | §8, §10 | G3 |
| G7 | #51 | End-to-end test of Setups and a restart | §11 | G2, G5, E12 |

The first spec's E8 (song-level FX set from the host, #13) is closed. E18 replaces it, and [#41](https://github.com/gismya/deluge-engine/issues/41) holds host-set song FX for a later release.

## 14. Running unattended

The user is away for about a week, and an orchestrator runs the tickets. It follows [docs/agents/orchestration.md](agents/orchestration.md).

**The run never stops as a whole.** A problem parks one ticket. The orchestrator writes a `needs-info` comment on it and a line under "Questions for the user" in its state file, then takes the next free ticket.

**No design question should need the user.** Where this spec gives a default or a list of fallbacks, take it and record which one. Where the spec is silent, the implementer picks the simplest thing that meets the ticket, records the choice in the handoff and in the PR, and goes on. That includes a new protocol message (§7.6).

**Park a ticket** only when:
- a firmware seam shows a `sizediff` change. Its PR waits for the user with `ready-for-human`.
- a firmware change would touch Generative-mode behaviour
- a Parity failure survives one full session of work on it. Record the metrics and what was tried.
- every fallback the spec lists for the ticket has failed
- the work needs the factory card or delugemu and they are missing or broken on the machine

**Never,** whatever the pressure to finish:
- loosen a Parity tolerance, or claim "not audibly different"
- commit or upload factory content, or play audio
- merge a red PR, or merge a firmware PR outside §2
- judge by listening. Build the listening pack and leave the judging to the user.

**Highest risks,** in the order the tickets meet them:
1. Silent 64-bit errors that change the sound without crashing. Sanitizers, the Parity tools and the `long` audit are the defence.
2. Preset swapping. The spike only ever loaded one preset per run.
3. Parity turning into a bit-exactness chase. The tolerances are the bar.
4. Hangs. Every test has a timeout, and freezes abort.
5. Setup changes running inside one another. A preset load re-enters host tasks, so the command queue needs its guard (§5).
6. The firmware moving under the pin. Don't move the pin during the run except to take a merged seam.
7. Two orchestrators on one machine. The firmware's own milestone run may share `generative` and the CPU (see the orchestration doc's "Shared machine"). Expect merge conflicts on F1 and slow `check_all.py` runs. Whoever merges second brings their branch up to date first.

**When the user is back** they read the state file's top section: what merged, what is open, the questions, the Parity report and the listening pack's path, and which defaults and fallbacks the run took.
