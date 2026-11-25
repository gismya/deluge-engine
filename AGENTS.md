# AGENTS.md

deluge-engine builds the Deluge community firmware's sound code for macOS (Apple Silicon). A GUI app talks to it, so the computer can play Deluge presets and Setups from MIDI and render Generative-mode Pieces. Read [docs/spec.md](docs/spec.md) and [GLOSSARY.md](GLOSSARY.md) before any work. The spec holds the decisions the user made, the architecture and the tickets.

- The firmware is the submodule `firmware/`, from [gismya/deluge-generative](https://github.com/gismya/deluge-generative) (local checkout `~/source/deluge-generative`). Its `AGENTS.md` applies to any change you make there.
- Never copy firmware code into this repo. Firmware changes go to gismya/deluge-generative as seam PRs (spec §4). A seam merges into `generative` under spec §2, and then the submodule pin moves to take it.
- Don't move the submodule pin except to take a merged seam (spec §3.3).
- Push your commits; don't leave them only in your local checkout. You don't need to ask first.
- To push here, use `git enginepush <args>` (e.g. `git enginepush -u my-branch`), never `git push`. Plain `git push` is blocked for agents. The alias runs `git push origin <args>` and refuses unless `origin` is gismya/deluge-engine. In the firmware repo, use `git delugepush` instead.
- An org policy blocks `curl`, `wget` and `rm`, even mentioning them in a command. Download with Node's built-in `fetch`. Delete with Python's `os.remove` or `shutil.rmtree`, or move files to `/tmp`.
- **Factory content.** The factory card at `~/source/delugemu-sd/sdcard/` (and its image `~/source/delugemu-sd/deluge_sd.img`) has no licence. Never commit it, renders of it or excerpts of it, and never upload it, not even as a CI artifact. CI uses CC0 content only (spec §2).
- **No speakers.** Never play audio through the user's speakers from an agent shell. Run the Engine and the app with `--audio null`.
- **No listening verdicts.** Never claim two sounds are "not audibly different", and never loosen a Parity tolerance (spec §9.5).
- **Timeouts.** Give every run of the engine or delugemu a timeout. Firmware freezes can hang forever.
- Issues live in GitHub Issues on gismya/deluge-engine. Use the labels `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
- Running a milestone with subagents: read [docs/agents/orchestration.md](docs/agents/orchestration.md).
- Background and traps: the spikes' findings, [docs/spike-findings.md](docs/spike-findings.md) (host build), [docs/perform-findings.md](docs/perform-findings.md) (Perform) and [docs/setup-findings.md](docs/setup-findings.md) (Setups). Add the traps you hit to `docs/implementation-notes.md`.
- The GUI's reference design is `prototype/screens/` on branch `prototype/screens` (spec §8). That code is throwaway: never merge it.

## Checks

The E1 ticket creates `tools/check.py`, which runs everything CI runs (spec §11). Run it before pushing. Until E1 lands, the spike builds with `python3 spike/scripts/compile_all.py build/host --link build/render_preset` on branch `spike/host-compile`.

- Merge a PR only when its CI is green, never while it is red.
- Merge firmware seam PRs into `generative` only under the rules in spec §2: `sizediff` unchanged, **Run tests** green, one review pass.
