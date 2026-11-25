# Deluge Engine

The Deluge firmware's own code, running on a computer so it can play Deluge sounds from MIDI or render them to audio files. Generative-mode terms (Generator, Piece, Part, Sound pick, Palette, Driver) keep the meanings that gismya/deluge-generative's `GLOSSARY.md` gives them.

## Language

**Engine**:
This program: the firmware's code built for the computer, with the Deluge's hardware swapped for stand-ins. It is not the Generator, which is one part of the firmware the Engine runs.
_Avoid_: Host build, port, simulator, emulator, plugin

**Hardware stand-in**:
What the Engine puts where the firmware talks to the Deluge's chips: audio out, MIDI in, the SD card, timers, the display, pads and buttons.
_Avoid_: Driver, stub, mock, HAL

**Card folder**:
A folder on the computer laid out like a Deluge SD card (SYNTHS, KITS, SAMPLES, SONGS), which the Engine reads sounds from.
_Avoid_: SD folder, content folder, library

**Card image**:
A FAT32 disk image the Engine builds from a card folder and reads the way the Deluge reads its SD card.
_Avoid_: SD image, disk file

**Setup**:
A set of Synth and Kit presets, each bound to a MIDI channel, that the Engine plays at once from MIDI input.
_Avoid_: Rack, song, layout, patch, multi

**Binding**:
One entry of a Setup: a MIDI channel and the preset that plays on it.
_Avoid_: Slot, track, assignment, mapping

**Reference**:
A render of the same sounds and notes made by the real ARM firmware in delugemu, used to judge whether the Engine sounds the same.
_Avoid_: Golden, ground truth, original

**Parity**:
The Engine's output being within the agreed tolerances of the Reference, for a sound or for a Piece. It never means bit-exact.
_Avoid_: Equivalence, accuracy, fidelity

**Backend**:
What the GUI talks to through its protocol: the Engine, or later a real Deluge.
_Avoid_: Server, host, device

**Live Engine**:
The Engine process the GUI talks to. It plays in real time from MIDI and plays Renders back.
_Avoid_: Server, daemon, main Engine

**Render worker**:
An Engine process that makes one Render and then exits.
_Avoid_: Job, renderer, helper, child

**Render**:
An audio file the Engine makes of a Piece or of notes played to a Setup, kept so it can be played and compared. Not the firmware's Capture, which is a recording made in delugemu.
_Avoid_: Capture, take, bounce

**Audition**:
Playing a sound briefly, from the picker or the on-screen keyboard, before choosing it.
_Avoid_: Preview, test, try
