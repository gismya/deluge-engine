# deluge-engine spike: host build of the Deluge firmware on macOS arm64

The spike code is on branch `spike/host-compile` (final commit `ef8c85d`). Paths under `spike/` below are on that branch. Decisions taken since then are in [spec.md](spec.md), which wins where the two differ.

Firmware: gismya/deluge-generative `generative` at 4a64f701b (read-only worktree, not edited).
Spike code: `~/source/deluge-engine`, branch `spike/host-compile`, final commit listed at the end.
Toolchain: Apple clang 21, arm64, `-std=gnu++23 -O1 -ffast-math -fms-extensions`.

## Result

**It renders.** The firmware's own code loads factory presets from a FAT32 SD image through `StorageManager`, plays a note, and pulls audio through `AudioEngine::routine()`. Nothing in the firmware tree was edited. The 21 patched files the host needs are applied as an overlay on a copy of the tree (`spike/overlay/`, combined in `spike/overlay.diff`, 513 lines). Each one is a firmware seam or fix, listed below.

| Preset | Path exercised | Result |
|---|---|---|
| SYNTHS/000 Rich Saw Bass | subtractive osc, filters, envelopes | pitch correct (C3 with the preset's −24 transpose → 33 Hz), release to silence |
| SYNTHS/002 Basic Square Bass | same | A2 −24 → 27 Hz |
| SYNTHS/050 FM Basic Bass | FM synth mode | 110 Hz peak, decays |
| SYNTHS/169 Double Bass, 170 Sitar | multisample from SAMPLES/, streamed by raw cluster reads | sustains and decays across many clusters |
| KITS/000 TR-808 drums 0 and 1 | Kit, SoundDrum, Kit render list | 50 Hz kick, 180 Hz drum |

Some renders are saved in `~/.cache/deluge-engine/notes/wav/`. Speed: 10 s of a one-voice synth renders in 0.054 s wall clock, about 185× real time at -O1.

Not verified:
- sameness against hardware or delugemu (no null or spectral comparison was run)
- DX7 engine (needs the kernel port, which is written but untested)
- MIDI input through `MidiEngine`
- song-level FX with a loaded song
- CoreAudio and CoreMIDI

## Recommendation: seam B (driver boundary), with a host-owned init sequence

The deciding measurement: the render driver touches only `Instrument`/`Kit`/`AudioEngine`/`StorageManager`. Even so, linking it against an archive of all firmware objects pulls in **451 of 466** objects (`-dead_strip`, `-map`), including 27 `gui/menu_item`, 16 `gui/views` and 42 `generative`.

The sound code's link closure is effectively the whole firmware, because Sound/Song/StorageManager reference the UI, views, display, MIDI and generative code. Seam A ("compile just the sound engine") therefore needs a large set of new seams to cut those references, which is what the constraint forbids. It would buy nothing at link time.

Seam B is small:
- 122 undefined symbols at the first full link (table below)
- a generated register-space shim
- the SSI ring (6 functions)

With B, the firmware's scheduler, cluster streaming, MIDI handling, song FX and voice management all come along unchanged.

**Refinement: don't call `deluge_main()`.** It talks to the PIC, waits on the OLED/DMA and USB, and loads the startup song. The host runs the 9-call init that `spike/host/render_preset.cpp` uses:

1. `functionsInit`
2. `currentPlaybackMode = &session`
3. display object
4. `AudioEngine::init`
5. `audioFileManager.init`
6. `FlashStorage::readSettings`
7. `runtimeFeatureSettings.init`
8. `setupBlankSong`
9. then either `registerTasks` + the task manager, or a host loop

No firmware seam is needed for this, but it duplicates a few lines of `deluge_main`. An optional later seam: split `deluge_main` into `hardwareInit()` and `engineInit()`.

## 1. Compile blockers (Apple clang, arm64)

Starting point: 482 TUs (`src/deluge` + `OSLikeStuff`, `fatfs`, `lib`, `NE10`, top-level C files). Out of the box, 394 compiled and 88 failed with 1226 errors. After the fixes below, 473/473 compile; the drivers and RZA1 are excluded or replaced.

| Category | Count | Example | Spike fix | Product fix |
|---|---|---|---|---|
| `src/arm_neon_shim.h` redefines NEON types (clangd shim for 32-bit) | 924 errors, 7 TUs | arm_neon_shim.h:80+ | override header that includes `<arm_neon.h>` | host include override (no seam) |
| Pointer cast to `uint32_t`/`int32_t` (hard error in clang C++) | 110 sites, 25 files | memory_region.cpp (21), sample_low_level_reader.cpp (20), song.cpp (11) | `-fms-extensions` downgrades to a truncating warning; real fixes for the round-trip sites (§6) | uintptr_t PR (§Seams) |
| ELF `__attribute__((section(".sdram_bss")))` invalid on Mach-O | 111 sites, via `PLACE_SDRAM_*`/`PLACE_INTERNAL_FRUNK` (definitions.h:80-92) | gui/l10n/g_english.cpp:15 | `-D'__section__(x)=unused'`. **Trap:** `aligned(1)` as the no-op *lowered* alignment and caused an arm64 alignment fault in an atomic (dinMIDIPorts) | flag, or 2-line seam `#if defined(__APPLE__)` |
| libstdc++/newlib-only headers | 3 | `<bits/ranges_algo.h>` (sound.cpp:66, audio_engine.cpp:69), `<sys/_intsup.h>` (arpeggiator/rhythm.h:23) | override headers | tiny PR: use `<algorithm>`, drop `_intsup` |
| Missing includes masked by GCC/unity build | 17 | `<compare>` for clock_type.h:45; `intptr_t` in dx/aligned_buf.h:28; `min` in dsp/dx/env.cpp:116 (the dsp lib is a CMake UNITY_BUILD) | `-include` prefix | tiny PR |
| ARM inline asm | 3 TUs fail, 1 header miscompiles | timers_interrupts.h:43-52 (CPSID/DSB), print.cpp:42,91 (PMU), **functions.h:392,398 `rev`/`rev16`** | override header; overlay `#if __arm__` | seam |
| **Silent asm miscompile** | 2 | `swapEndianness32()` assembles to 64-bit `rev x0,x1` on arm64: returns 0 for 0x11223344 (tested). Used by AIFF and wavetable loading | overlay `__builtin_bswap32` | seam (must) |
| ARMv7 NEON asm file | 1 | dsp/dx/neon_fm_kernel.s (DX7 engine; `fm_op_kernel.cpp:21` hard-defines HAVE_NEON) | scalar C port, same op order, `fp contract(off)`: spike/host/host_fm_kernel.c, untested | host file, or NEON-intrinsics port with a bit-exact test |
| `int32_t` is `long` on arm-none-eabi | 1 | ui.cpp:395 `std::max(u, 0L)` | overlay | tiny PR |
| `size_t` is 64-bit | 1 compile error (audio_engine.cpp:1437 `std::min(size_t, 256u)`), 469 `-Wshorten-64-to-32` sites (mostly headers: fx_engine.hpp, d_string.h) | | overlay | PR for the error; warnings are benign |
| GCC extensions | 3 | VLA with initializer in `DEF_STACK_STRING_BUF` (d_stringbuf.h:70), `strrchr` on `const char*` returning `char*` (instrument_clip_view.cpp:2135) | overlay | tiny PR |
| ARM32 layout static_asserts (generative) | 3 | entry_leave.cpp:288 "offset 20 is baked into decideNextStep()" | overlay `#if __arm__` | PR (or exclude generative) |
| Fixed peripheral addresses (`MTU2`, `DMACn`, `RSPI` at 0xE8…/0xFC…) outside drivers/ | about 45 sites in 13 files; live ones are `seedRandom` (functions.cpp:1644), `delayMS`/`delayUS` (cfunctions.c:237-247), MIDI-gate timer (audio_engine.cpp:683), OLED (oled.cpp:1287-1334) | | `spike/scripts/gen_io_overrides.py` rewrites the RZ/A1 iodefines so registers live in a host RAM block (reads 0, writes land). Busy-waits on timer registers would hang | host-generated headers (no seam). Optionally a host thread that ticks the MTU counters |
| `UNCACHED_MIRROR_OFFSET` (+0x40000000) | drivers/pic/pic.h:312, ssi.c, uart.c | PIC LED writes faulted at picTxBuffer+0x40000000 | generated `cpu_specific.h` with offset 0 | host header |

**Trap:** quoted includes resolve next to the including file first. Overriding `RZA1/cpu_specific.h` with `-I` didn't work because `src/definitions.h` finds its sibling first. The spike copies `src/` to `build/host/tree` and overlays and generates files into that copy.

## 2. Link: undefined symbols

Linking all 466 firmware objects with no host code leaves **122 undefined symbols**:

| Subsystem | # | Stubbable? |
|---|---|---|
| Memory allocator (GMA, MemoryRegion, delugeAlloc) | 16 | needs a real host implementation (§3) |
| NE10 | 19 | trivial: compile only the sources `src/NE10/CMakeLists.txt` lists (spike's first glob over-included) |
| DX7 `neon_fm_kernel` | 1 | real port (done, untested) |
| SD/diskio (`disk_*`, `get_fattime`, `currentlyAccessingCard`, `initSPIBSC`) | 10 | real: sector reads over an image (§5) |
| SSI audio (`getTx/RxBuffer*`, `ssiInit`, `clearTxBuffer`) | 8 | real: ring and simulated DMA position (§4) |
| OS timers, critical sections, IRQ, INTC | 12 | real for `getTimerValue` (33.33 MHz counter from `mach_absolute_time`); rest trivial |
| GPIO | 5 | trivial |
| UART: PIC and DIN MIDI (`uart*`, tx buffers, `putchar_`) | 15 | trivial (no input); DIN MIDI could later go here |
| USB host/peripheral | 12 | trivial (never connected) |
| OLED/SPI/CV | 14 | trivial |
| Serial-flash settings (`R_SFLASH_*`) | 3 | trivial (reads 0xFF, so defaults) or a file |
| Trigger clock | 3 | trivial |
| Caches | 2 | trivial |
| `main` | 1 | host driver |

Host code in total is about 460 lines: `spike/host/hw_stubs.cpp`, `hw_stubs_usb.c`, `host_gma.cpp`, `host_diskio.c`, `host_fm_kernel.c`, `host_io.c`.

## 3. Memory

`GeneralMemoryAllocator()` (general_memory_allocator.cpp:41-78) builds 5 regions:
- **Stealable:** `&__sdram_bss_end` .. 0x0FDE0000
- **External:** 2 MiB below `EXTERNAL_MEMORY_END` 0x10000000 (cpu_specific.h:122)
- **External-small:** 128 KiB
- **Internal:** `&__heap_start` .. `&program_stack_start`
- **Internal-small:** `&__frunk_bss_end` .. `&__frunk_slack_end`

The free-list bookkeeping arrays are `PLACE_INTERNAL_FRUNK` statics.

On the host, the real allocator can't be kept by moving the regions:
- **No low memory.** A macOS arm64 binary with `__PAGEZERO` < 4 GiB is killed by the kernel (tested with `-pagezero_size` 0x10000000 → SIGKILL). So no memory below 4 GiB, and truncated addresses can't round-trip.
- **The free list can't hold a 64-bit address.** `EmptySpaceRecord {uint32_t length; uint32_t address}` is the 2-word key of an `OrderedResizeableArrayWithMultiWordKey` (memory_region.h:25). Widening `address` puts padding into the key. A 64-bit port of `MemoryRegion` is a rework, not a type change.
- The repo already treats the real allocator as 32-bit only (tests/32bit_unit_tests builds with `-m32`).

Spike: `spike/host/host_gma.cpp` replaces the allocator at link time:
- `malloc` with the firmware's 4-byte header kept in front, so `getAllocatedSize` works
- `shortenLeft`/`extend` report 0 (callers fall back to allocate and copy)
- `getRegion` returns STEALABLE for stealable headers (`SampleCluster::getCluster` freezes "invalid" otherwise)
- the stealable region gets the `CacheManager` (`deluge::exception NO_CACHE_FOR_REGION` otherwise)
- nothing is ever stolen

Product: the same, plus an eviction policy for sample Clusters (an LRU over the CacheManager queues or a byte budget). Otherwise every sample cluster ever played stays resident.

Address-range checks that a host allocator breaks:
- d_string.cpp:143 freezes S001 unless string memory is in the external region (needs a seam)
- resizeable_array.cpp:213 compares against `INTERNAL_MEMORY_BEGIN` (harmless)
- voice_sample.cpp:1479 writes through `UNUSED_MEMORY_SPACE_ADDRESS` 0x08000000. Not hit in the spike; needs checking (seam or host mapping)

## 4. Audio

- `AudioEngine::routine()` (audio_engine.cpp:1226) loops `routine_()` (:743) while `doSomeOutputting()`.
- `routine_()` reads the TX DMA read position `getTxBufferCurrentPlace()` and renders the frames between the engine's write position `i2sTXBufferPos` and the DMA. It renders about 4-128 frames, doubles anything above 6 and rounds to a multiple of 4.
- `renderAudio(n)` (:846) fills `renderingMemory`, a `std::array<StereoSample,128>` of `{q31 l,r}`.
- `doSomeOutputting()` (:1317) applies master volume, dither and `lshiftAndSaturate`, then writes interleaved int32 L/R into `ssiTxBuffer[128*2]`.
- 44.1 kHz (`kSampleRate`, definitions_cxx.hpp:1047); `SSI_TX_BUFFER_NUM_SAMPLES` 128.
- On the Deluge it runs as scheduler task 0 (deluge.cpp:577, 8/64/128-sample interval), re-entrantly from SD waits, and as idle filler.

Host:
- `spike/host/hw_stubs.cpp` owns `ssiTxBuffer` plus `host_audio_tx_read_frame`, the simulated DMA position.
- The driver plays N frames out of the ring, advances the position, then calls `AudioEngine::routine()`. That gives 128 frames of ring latency on top of the window.
- For CoreAudio: run the firmware (scheduler or a host loop) on one engine thread at real-time priority (audio workgroup). It produces into a lock-free FIFO that the CoreAudio callback drains, and it advances the "DMA position" by what the callback consumed.
- Don't run firmware code inside the callback: SD and cluster loading happen on the same thread.
- The firmware is single-threaded with ISR-style critical sections (`ENTER_CRITICAL_SECTION` stubbed), so every firmware call, MIDI injection included, must go through the engine thread.

## 5. Storage

The XML presets go through `f_read`, but on a `FIL` the code builds from FatFS internals:
- `openFilePointer` sets `obj.sclust`/`obj.fs`/`obj.id` itself (storage_manager.cpp:283-297)
- the browser uses the custom `f_readdir_get_filepointer` (ff.c:4705)

Samples bypass `f_read` entirely:
- `AudioFileManager` walks the FAT chain with `clst2sect`/`get_fat_from_fs` (audio_file_manager.cpp:830-845).
- Clusters are read with raw `disk_read_without_streaming_first(sector, Cluster::size>>9)` (:1002).
- `Cluster::size` = the FAT cluster size.

So a shim at the `f_open`/`f_read` level is **not** enough. Use the real `ff.c` over a sector device.

The spike's `host_diskio.c` reads sectors from a FAT32 image file: the existing 4 GiB `~/source/delugemu-sd/deluge_sd.img`, read-only.

For the product, it's cheaper to keep `ff.c` and give the host a sector device:
- **(a) v1:** build or refresh a FAT32 image from the user's folder (`newfs_msdos`/`hdiutil` or mtools).
- **(b) later:** a read-only virtual FAT32 volume synthesised from a directory, like QEMU's vvfat, about 600 lines.

A higher-level seam would touch `StorageManager::openFilePointer`, `AudioFileManager`'s cluster table and `SampleRecorder`, which is many seams.

Write support (saving presets from a future editor) needs (b) to be writable, or a seam.

## 6. 64-bit verdict: viable, real but bounded risk

64-bit is mandatory (no 32-bit processes on macOS, and no memory below 4 GiB). The spike runs 64-bit, after these fixes, all done in the overlay:

**Silent miscompile:** `swapEndianness32/2x16` asm (above).

**Silent corruption:**
- `String` reference count accessed as `intptr_t` at `stringMemory-4` (d_string.cpp:43,47). On 64-bit it overwrites the first 4 characters, so every `String` reads as empty. Symptom: the preset browser recursed 58 086 deep into "folders" with empty names.

**Wrong results, fail or crash (pointer → uint32 → pointer):**
- quick_sorter.cpp:31 (crashed in `PatchCableSet::setupPatching` at `AudioEngine::init`)
- open_addressing_hash_table.cpp:80,84
- named_thing_vector.cpp:73
- wave_table.cpp:808,860,964
- sample.cpp:1323,1326
- cache_manager.cpp:111
- audio_engine.cpp i2sTX/RXBufferPos, saddr, stopPos, rxBufferWriteAddr stored as `uint32_t` (:181,182,208,1429,1753; audio_engine.h:216-217)

**Pointer-keyed containers:**
- `Song::backedUpParamManagers` is keyed on `{(uint32_t)modControllable, (uint32_t)clip}` against a struct whose pointer members are 8 bytes. Every `loadInstrumentFromFile` failed (FILE_CORRUPTED) until fixed (song.cpp:143, 3835-3919).
- `Kit::drumsWithRenderingActive` stores the truncated pointer as a key and casts it back to `Drum*` (kit.cpp:542, sound_drum.cpp:173).

**Remaining truncations (compile with `-fms-extensions`):**
- 58 sites: pointer differences, which are fine inside one allocation, and hash or search keys (session.cpp, song.cpp:2227, kit search)
- 4 int→pointer casts, which are deliberate small-int-in-pointer tags (note_row.cpp:3234, output.cpp:411)

They work but are fragile. Convert all 110 cast sites to `uintptr_t`/`intptr_t` in one mechanical PR. On arm-none-eabi `uintptr_t` and `uint32_t` are both 32-bit (`unsigned int` vs `unsigned long`), so codegen should be identical. Verify with `./dbt sizediff`; not run in the spike.

**Clang-exposed UB (not 64-bit, but it showed up here):**
- `InstrumentClip::getNoteRowForYNote` reads an uninitialised `noteRowId` (instrument_clip.cpp:995, and the same pattern at :963, :1021, :1033).
- Clang folds the null check away and hits `FREEZE_WITH_ERROR("E380")` on the first note.
- Expect more of this class. Run the host build with UBSan/ASan in CI.

## 7. Hardware timing dependence

- **Voice culling:** `setDireness`/`cullVoices` (audio_engine.cpp:450-571) use `getAverageRunTimeForTask(routine_task_id)`, the scheduler's measured audio-task time in samples, against `numSamplesLimit` 80.
  - With a host loop that doesn't go through `TaskManager::runTask` there are no stats, so no culling.
  - With the scheduler, a host CPU is 50-100× faster, so it almost never culls.
  - So dense patches play more voices than on a Deluge, which could be audibly different.
  - For parity, replace the CPU measure with a host "virtual Deluge load" model, or set a fixed voice cap. Either needs a small seam, or the host feeds fake task timing.
- **Render window:** set by how far the DMA moved (≤128) plus the `numSamples <= 10*numRoutines` skip. On the host, the window is set by how much the driver advances. Block size affects envelope and LFO update granularity (per-window), so keep host windows in the same 4-128 range.
- **Busy-waits on hardware timer registers:** `delayMS`/`delayUS` (cfunctions.c:237-247), OLED (oled.cpp:1287+) and the freeze screen hang with RAM-backed registers. The spike hit one as a hung `FREEZE_WITH_ERROR` (a 600 s tool timeout) and now uses a `HostDisplay` that aborts on freeze. A host thread incrementing the MTU2 `TCNT` words in the register RAM would make them terminate.
- **MIDI and gate output timing** uses `getSystemTicks()` (OSTM0) and arms an MTU timer (audio_engine.cpp:666-688). The host `getTimerValue` is a real 33.33 MHz clock, so this works. Gate output is irrelevant.
- **Song tempo** runs off `audioSampleTimer` (sample-driven), so it's host-independent.
- **Denormals and FP:** ARMv7 NEON flushes to zero and never fuses multiply-add. On arm64, set FPCR.FZ on the engine thread, and use `-ffp-contract=off` if bit-exactness matters. `fixedpoint.h` already has portable non-`__arm__` paths (:42, :385-431); whether they are bit-exact with `smmul`/`vcvt` is untested.

## Firmware seams and fixes needed

Each is in `spike/overlay.diff`. All are small and should leave the ARM Release build unchanged, but that is unverified.

1. **64-bit pointer hygiene** (one PR, about 40 lines): `uintptr_t` round trips in quick_sorter, open_addressing_hash_table, named_thing_vector, wave_table (3), sample.cpp (2), cache_manager, and the audio_engine buffer positions. Optionally all 110 cast sites. *Why:* crashes or wrong results on 64-bit.
2. **`String` refcount as `int32_t`** (d_string.cpp:43,47, 2 lines). *Why:* all strings read as empty on 64-bit.
3. **`String::set` S001 address check** (d_string.cpp:143): ask the allocator (`GeneralMemoryAllocator::isNonAudioExternal(p)`) instead of comparing with `EXTERNAL_MEMORY_END`. About 5 lines plus a GMA method. *Why:* a host allocator can't satisfy fixed address ranges.
4. **`backedUpParamManagers` key width** (song.cpp: key words = `2*sizeof(void*)/4`, built with memcpy, about 12 lines). *Why:* every preset load fails on 64-bit.
5. **Kit render list stores the full `Drum*`** (kit.cpp:542, sound_drum.cpp:173, about 8 lines). *Why:* Kits crash on 64-bit.
6. **`swapEndianness32/2x16`**: `#if defined(__arm__)` asm, else `__builtin_bswap32` (functions.h, 8 lines). *Why:* silently wrong on arm64.
7. **Uninitialised `noteRowId`** (instrument_clip.cpp, 4 lines). *Why:* UB; clang turns it into a freeze. Worth upstreaming regardless.
8. **Clang portability** (about 15 lines): `<algorithm>` instead of `<bits/ranges_algo.h>`, drop `<sys/_intsup.h>`, `#include <algorithm>` in dsp/dx/env.cpp, `<compare>` in clock_type.h, `<cstdint>` in dx/aligned_buf.h, ui.cpp `0L`, `strrchr` cast, `DEF_STACK_STRING_BUF` without a VLA initializer, `__arm__` guards on print.cpp PMU asm and the 3 generative layout static_asserts. *Why:* doesn't compile with clang otherwise.
9. **Optional, `PLACE_*` macros** (definitions.h:80-92): empty when `!defined(__ELF__)`, 2 lines. *Why:* removes the `-D__section__` hack.

Later or optional:
- a voice-budget hook for host culling parity (§7)
- `deluge_main` split
- if a writable virtual FAT is undesirable for preset editing, a storage seam

No seam is needed for: the allocator (link substitution), drivers (link substitution), register space and cpu_specific.h (generated host headers), the timers_interrupts.h asm (host header override), or the NEON shim.

## Spike layout

- `spike/scripts/compile_all.py`: copies `src/` to `build/host/tree`, applies `spike/overlay` and the generated RZ/A1 headers, compiles every TU in parallel, writes per-file logs and a summary, and links with `--link`.
  `python3 spike/scripts/compile_all.py build/host --link build/render_preset`, about 50 s on this machine.
- `spike/scripts/gen_io_overrides.py`: RZ/A1 iodefines → host RAM; `UNCACHED_MIRROR_OFFSET` 0.
- `spike/host/`: host platform layer and the `render_preset` driver.
  `DELUGE_SD_IMAGE=~/source/delugemu-sd/deluge_sd.img build/render_preset "SYNTHS/000 Rich Saw Bass.XML" out.wav [note|drum index] [held s] [total s]`
- `spike/host/include_override/`: NEON shim, libstdc++/newlib header stand-ins, timers_interrupts.h without asm, `host_io.h`.
- `spike/overlay/` and `spike/overlay.diff`: the firmware changes (seams above).
- `spike/scripts/wav_stats.py`: RMS per 250 ms and spectral peaks of a render.

## Ticket breakdown to v1 (ranked scope)

**0. Foundations**
- **T1** Firmware PR "64-bit and clang portability" (seams 1, 2, 4-8), checked with `./dbt sizediff`. Then seam 3. About 2 days including the sizediff and hardware sanity run.
- **T2** deluge-engine CMake project: firmware as a submodule, compiled in place once T1 lands; no tree copy, generated RZ/A1 headers, host override dir; CI on macOS with ASan/UBSan. 2-3 days.
- **T3** Host platform layer from the spike, cleaned up: allocator with cluster eviction, timers, SSI ring, register RAM with a ticking MTU, freeze → error report, settings file instead of erased flash. 3 days.

**1. Synth presets, offline**
- **T4** Engine API: init, load preset by path, note on/off, render N frames. Keep `render_preset` as a CLI. 1-2 days.
- **T5** Parity harness: render the same preset and notes on delugemu (ARM firmware) and on the host. Compare with a null test or spectral distance. Run over all 171 SYNTHS. Fix differences: FP contraction, denormals, `fixedpoint.h` fallbacks. 3-5 days; open-ended if bit-exactness is chased.
- **T6** DX7 kernel: NEON-intrinsics port of `neon_fm_kernel.s`, bit-exact against the ARM build under delugemu. 1-2 days.

**2. Real time**
- **T7** Engine thread running the firmware `TaskManager` (cluster loading, slow routines, culling stats), CoreAudio output via a lock-free FIFO, audio workgroup. 3 days.
- **T8** CoreMIDI in → engine-thread queue → `MidiEngine::midiMessageReceived` (midi_engine.h:147) on a host `MIDICable`. Route to the loaded instrument (MIDI-follow or per-channel learn set up by the host). 2-3 days.
- **T9** Voice-budget and culling policy for the host (§7). 1-2 days, plus a small seam if needed.

**3. Kits**
- **T10** Kit loading and MIDI note → drum mapping (already renders offline). Parity over KITS/. 2 days.

**4. Song-level FX**
- **T11** Master reverb, delay, sidechain and compressor: load a SONGS/*.XML or set song params from the host. Expose song FX params. Parity check. 2-3 days.

**5. Storage UX**
- **T12** Card-folder → FAT image builder (v1). Later, a virtual FAT diskio over a directory (needed for preset editing and saving). 1 day for the builder; about 1 week for virtual FAT.

## Tooling problems

- The firmware worktree has no generated `version.h`/`util/firmware_version.h`. They were copied from `~/source/deluge-generative/build/src/deluge/...`, and `version.cpp.gen` was hand-written.
- macOS arm64 SIGKILLs any binary with `-pagezero_size` < 4 GiB, which ruled out a "keep addresses below 4 GiB" approach.
- lldb could not evaluate expressions in the optimised build ("Couldn't look up symbols"). Temporary `fprintf`s in the overlay were used instead.
- One foreground lldb run hung on a `FREEZE_WITH_ERROR` busy-wait (RAM-backed timer registers never tick) and hit the 600 s tool timeout. Fixed with `HostDisplay`.
- The `-D'__section__(x)=aligned(1)'` no-op silently lowered variable alignment. It produced an alignment fault in an `etl` atomic, far from the cause.
- Quoted-include sibling lookup defeats `-I` overrides of `src/RZA1/*.h` (from `src/definitions.h`), which forced the copy-the-tree build.
- No numpy on the system Python. WAV analysis is pure Python (slow but fine).

Final spike commit: `ef8c85d` on `spike/host-compile` (not pushed).
