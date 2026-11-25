# Setups in memory: findings (issue #42)

Firmware: gismya/deluge-generative `generative` at 4a64f701b (own worktree, not edited). Spike code: branch
`spike/setup-routing`, from `task/perform-in-engine`. Paths under `spike/` are on this branch; firmware paths are
under `src/deluge/` of the firmware. Full output of the checks: [setup-results.txt](https://github.com/gismya/deluge-engine/blob/spike/setup-routing/spike/setup-results.txt).

## Answer: route 1 works, with no firmware change

Host code builds the Setup in the current song: per binding, it loads a preset, gives it an always-active session
clip and sets its MIDI input to a channel. Notes go in through the DIN UART stand-in, so the firmware's own parser and
`PlaybackHandler::noteMessageReceived()` route them (`playback/playback_handler.cpp:3116`). Each channel plays only its
own instrument. Swapping one binding leaves the other channels' notes alone, and an audition instrument can be added
and removed while the others play.

- **Firmware changes: none.** `spike/overlay/` is unchanged, and the firmware worktree is clean. `./dbt sizediff`
  has nothing to compare.
- Host code: a 24-line MIDI-inject queue in the DIN UART stand-in (`spike/host/hw_stubs.cpp`), and the driver
  `spike/host/drivers/setup_engine.cpp`. About 110 of the driver's lines are the Setup itself (link, unlink, load,
  bind, swap); the rest is the script reader, timing and WAV output.
- Route 2 (a song file per Setup through `loadSong`) wasn't tried: route 1 worked and costs about as much as one
  ticket.

The firmware already does all of this for Generative mode: `generative/firmware/perform_song.cpp` `link()` (:95) and
`freePartOutput()` (:695) build and free a Part's instrument and clip in a private song. The driver uses the same stock
calls; Perform just never binds a MIDI input.

### What a binding is

- **Synth:** `instrument->midiInput` (a `LearnedMIDI`, `model/instrument/instrument.h:90`) with `channelOrZone` set
  to the channel (0-15) and `cable = nullptr`. A null cable matches any input (`LearnedMIDI::equalsCable`,
  `io/midi/learned_midi.h:35`). MIDI learn on the Deluge writes the same fields (`gui/views/view.cpp:730`), and a song
  file stores them as `inputMidiChannel` (`melodic_instrument.cpp:74`).
- **Kit:** the same fields. `noteOrCC` is the note of the Kit's first row (`Kit::offerReceivedNote`, `kit.cpp:1591`):
  the driver uses 36, so note 36 plays row 0, 37 row 1, and so on. A whole-Kit MIDI learn sets it to the learned note.
- **Clip:** `InstrumentClip` with `activeIfNoSolo`, a 1-bar loop, `setAudioInstrument()`,
  `setupAsNewKitClipIfNecessary()` for a Kit, then `sessionClips.insertClipAtIndex()`, `addOutput()` and
  `setActiveClip()`. This is the spike's `linkIntoSong()` from `render_preset.cpp`, and the same as Perform's `link()`.
- Transport doesn't need to run. MIDI input plays the instrument live, as the Deluge does with playback stopped.

## 1. Routing (renders with the factory card, modelled card time 300 µs + 40 µs per sector)

The Setup is ch 1 `026 PW Organ`, ch 2 `025 Soft Synth Organ` and ch 10 `000 TR-808` (first row on note 36). Every
render has notes on one channel or on all of them, with only that channel's preset bound (alone) or with all three
bound.

| Check | Result |
|---|---|
| Voice counts, alone / all three bound | identical on every channel: ch 1 and ch 2 `[1, 2, 1, 0]`, ch 10 `[1, 2, 1, 0, 1, 0, 1, 0]` |
| 50 ms level envelope, alone vs all bound | within 0.06 dB (ch 1), 0.22 dB (ch 2) and 0.28 dB (ch 10) |
| f0 per note, alone / all bound | ch 1: A2 110.1 / 110.1 Hz, E3 165.0 / 165.0 Hz. ch 2 (oscillators +12): D#4 622.3 / 622.2 Hz, A#4 932.5 / 932.4 Hz |
| Level per note, 0.1-0.4 s | equal to 0.1 dB (−21.5, −21.7, −23.6, −24.1 dBFS) |
| Harmonics 1-8 of the measured f0 | ch 1 within 0.01 and 0.19 dB. ch 2 within 9 and 3.4 dB: its two oscillators run free (`retrigPhase -1`), so their beating differs from run to run |
| Kit hits, 50 ms peak | −6.28 / −6.28, −13.68 / −13.71, −9.14 / −9.15, −6.28 / −6.28 dBFS (notes 36, 38, 42, 36: three different drums) |
| Crosstalk | ch 2's 622 Hz in the ch 1 render: −78.7 dBFS (−25.4 in its own). ch 1's 110 Hz in the ch 2 render: −189 dBFS |
| All channels together vs the sum of the three single-channel renders | bit-identical (up to dither) until the second channel's first note; 50 ms envelope within 0.14 dB of the sum over the whole render |
| Notes on unbound channels 3, 5 and 16 | **bit-identical to a render with no notes** (difference −999 dBFS, max \|diff\| 0); voice count stays 0 |

Sample-level comparisons between renders with different histories don't line up (−25 to −33 dBFS of difference).
The cause is a different start time for the LFOs, the render windows and MIDI delivery, not crosstalk: see Traps.

Binding takes 5.9 ms of virtual time for a synth and 142 ms for the 808 Kit (its samples), with 0 DMA overruns. Audio
keeps playing through the load, because each card read yields to the scheduler.

## 2. Changing one binding while another channel holds a note

Setup: ch 1 holds A6 (`PW Organ`, 1761.7 Hz) from 1.0 to 4.0 s. ch 2 holds D#4 on `Soft Synth Organ` from 1.0 s.
At 2.0 s, ch 2 swaps to `020 Soft Saw Lead` (no samples) or `169 Double Bass` (multisample). A new ch 2 note-on
follows as soon as the swap returns.

Two ways to swap:
- **swap:** the preset browser's way (`load_instrument_preset_ui.cpp:941-985`). `loadInstrumentFromFile()`, then
  `Song::replaceInstrument(old, new)`, which moves `midiInput` itself (`song.cpp:3460`) and deletes the old instrument.
- **swapx:** load the new instrument beside the old one and link it with its own clip. Then move `midiInput`, release
  the old one's notes (`stopAnyAuditioning`), and free it 2 s later (Perform's retire pattern).

| Swap | Load (virtual / wall) | Held ch 1 note | Silence on ch 2 (1 ms windows below −60 dBFS) |
|---|---|---|---|
| swap → Soft Saw Lead | 4.8 ms / 0.6 ms | 1.76 kHz level within 0.07 dB of the ch1-only render; 0 overruns | none: the old note is cut and the new one starts in the same millisecond |
| swap → Double Bass | 328 ms / 8-18 ms | within 0.47 dB (Double Bass partials leak into the bin); 0 overruns | **8 ms** (2.324-2.332 s) between the cut and the new note |
| swapx → Soft Saw Lead | 4.8 ms / 0.1 ms | within 0.02 dB; 0 overruns | none: the old note's release overlaps the new note |
| swapx → Double Bass | 320 ms / 7.5 ms | within 1.22 dB (Double Bass and the old release both leak); 0 overruns | none |
| swap → Double Bass, a ch 2 note sent 50 ms into the load | 328 ms | within 0.15 dB; 0 overruns | from the cut until the next note-on: 255 ms in this render, which sends none |

The same swaps with instant card reads (`--card-us 0:0`) took 0.0-0.1 ms virtual and gave the same picture, with no
silence.

**Does the held note keep sounding?** Yes. The other channel's held note isn't disturbed: 0 DMA overruns, and its
level stays within 0.07 dB when the new sound has no partials near it.

**What happens on the swapped channel:**
- The old preset keeps playing through the whole load: 4.8 ms for a synth, 328 ms for a sample-based preset with
  modelled card time.
- With `swap`, the old preset's notes stop dead when `replaceInstrument()` runs: from −32 to −141 dBFS within 1 ms,
  which will click. The new preset is silent until a new note-on: a held note does not carry over.
- A note-on sent right after the swap sounds within 1 ms for the synth preset and after 8 ms for the multisample one.
- Notes that arrive during the load go to the old preset and are cut with it. The firmware's MIDI task runs inside the
  load's card waits (voice count 2 at 2.0525 s, 0 at 2.3303 s).
- With `swapx`, no gap at all: the old note's release tail rings out over the new preset.

## 3. The audition channel

ch 1 holds A6, and ch 10 plays a kick every 250 ms. At 2.0 s `131 Warm Strings` is bound to ch 16: 21.3 ms virtual,
0 overruns. It plays C4 from 2.5 to 3.0 s and is unbound at 3.5 s: 0.0 ms, 0 overruns.

- Adding and removing ch 16, with or without notes, leaves the render **bit-identical until 2.0047 s**, the moment the
  load starts.
- After that, the held note's 1.76 kHz level stays within 0.50 dB of the never-added render.
- The kicks keep their peaks to within 0.07 dB (1.12 dB while the strings play over them).
- Some kicks land 25 or 50 samples (0.6-1.1 ms) earlier or later. That's when the driver's host task delivers the
  note-on, not the audition: see Traps.
- **Unbinding cuts the audition's tail dead:** −52 dBFS at 3.503 s, −142 at 3.504 s. A product should release the
  audition's notes and unbind after the tail (or fade it, as Perform's `fadeOutPart()` does).

## Firmware changes route 1 needs

None. Possible seams, none needed now:

| Possible seam | Size | Why it might come up | sizediff |
|---|---|---|---|
| Export a "link instrument with clip into song" and "free it" pair from the firmware. Today Perform's `link()` is file-local in `perform_song.cpp`, `freePartOutput()` takes a Perform `PartOutput`, and the host driver has its own copy | ~60 lines moved | so the Engine and Perform share one copy | no change if pure moves, otherwise small |
| A "release then delete" swap in `Song::replaceInstrument()` | ~20 lines | avoid the hard cut | would change Release; host code can do `swapx` instead |

## Traps

- **Loads re-enter the scheduler.** A card read yields (`yieldingRoutineWithTimeoutForSD`), and the scheduler runs
  other tasks inside the load, including the host's own command task. The first version ran the line after a swap
  from inside the swap's load: its note reached the old preset and was cut. The driver now runs one command at a time
  (`inCommand`). The product's command queue (spec §3.5) needs the same guard.
- **MIDI keeps flowing during a load.** The MIDI task (`playbackHandler.midiRoutine`, `RESOURCE_SD | RESOURCE_USB`)
  ran during the swap's card waits, and a note sent then went to the old preset. That's right for a held binding, but
  the swap cuts it.
- **`replaceInstrument()` and unbinding cut voices dead.** Release first, then remove after the tail.
- **A Kit's `noteOrCC`** defaults to 255, which means "note 0 is row 0". Set it to the first row's note (36 for a
  GM-style map).
- **MIDI follow still runs.** `midiFollow.noteMessageReceived()` sees every note before the instruments do. The
  factory card has no `SETTINGS/MIDIFollow.XML`, so follow A was off (channel 255). A card that sets it would also
  play its channel on the follow target. A Setup should switch follow off, or not read the card's defaults.
- **The blank song's default synth clip stays** (`setupBlankSong` → `ensureAtLeastOneSessionClip`). It has no MIDI
  input, so it is silent. A Setup can delete it or bind it.
- **Renders with different histories don't line up sample for sample.** The driver's host task delivers notes on a
  1 ms tick, and a long command shifts that tick by up to 50 samples. LFOs start at load, and render windows follow
  the scheduler. Compare envelopes, f0 and band levels, not samples, unless the histories match. Up to the first
  difference in history, renders are bit-identical.
- **`std::snprintf` doesn't compile** in host code that includes firmware headers: the firmware's printf library
  defines `snprintf` as a macro (`snprintf_`). Use plain `snprintf`.
- No numpy on the system Python, so the checks are pure Python. All three sections run in about 10 s.

There's no `docs/implementation-notes.md` on this branch (it comes from `spike/host-compile`). The traps above belong
there once the Setups ticket starts on `main`.

## Recommendation for the Setups ticket

- Use route 1. A Setup is the current song plus one clip and instrument per binding. Binding means setting
  `midiInput` (`cable = nullptr`, `channelOrZone`, and the first row's note for a Kit).
- Build Setup changes as engine-thread commands run one at a time from a scheduler task (skip while `sdRoutineLock`
  is set, and never re-enter while a load yields).
- Change a binding the `swapx` way: load beside, link, move `midiInput`, release the old notes, free the old
  instrument after its tail. No gap, and nothing else is disturbed. Keep `replaceInstrument()` only if a hard cut is
  acceptable.
- Expect the new preset to be ready after its load: about 5 ms for a plain synth, and 150-330 ms for sample-based
  presets and Kits with modelled card time. The old preset plays until then.
- Switch MIDI follow off for Setups, and remove the blank song's default clip.
- Route 2 isn't needed. Saving a Setup as a song file is still possible later, because a song file stores the same
  `inputMidiChannel` per instrument.

## Running it

```
DELUGE_FW=<firmware worktree at 4a64f701b> python3 spike/scripts/compile_all.py build/host --driver setup_engine --link build/setup_engine
python3 spike/scripts/setup_run.py [--only routing|swap|audition] [--card-us 300:40]
```

Renders go to `~/.cache/deluge-engine/notes/setup-wav/` (factory content: not in git). Each Engine run has a 120 s
timeout and takes under 0.2 s.
