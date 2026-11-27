# deluge-engine

The Deluge community firmware's sound code, built for macOS, with a GUI app. It plays Deluge Synth and Kit presets from MIDI, alone or several at once, and renders Generative-mode Pieces so two sets of sounds can be compared. It uses the firmware's own code.

Work in progress. See [docs/spec.md](docs/spec.md) for the plan and [docs/spike-findings.md](docs/spike-findings.md) for the spike that rendered the first presets.

## Building

On an Apple Silicon Mac, with cmake 3.25+ and ninja:

```
git submodule update --init firmware
python3 tools/check.py            # builds build/asan and build/release, runs every check CI runs
```

`build/release/deluge-engine render` renders notes or a MIDI file on a Synth or Kit preset from a card folder to a 24-bit WAV (`build/release/deluge-engine render --card firmware/pack --preset "SYNTHS/GENERATIVE/GEN Sine Sub.XML" --notes "C4:1.0" --out out.wav --audio null`).

The firmware comes from [gismya/deluge-generative](https://github.com/gismya/deluge-generative), a fork of the [Deluge community firmware](https://github.com/SynthstromAudible/DelugeFirmware). GPL-3.0.
