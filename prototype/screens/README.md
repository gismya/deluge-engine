# PROTOTYPE: Setup and Piece screens, round 3 (throwaway)

Answers the wayfinder ticket "What do the Setup and Piece screens look like?" (gismya/deluge-engine#19). Round 2 had three variants (B2, D and E; git keeps them). The verdict: "Base it on D, but add the timeline from E as a tab. Only do the dark mode and the touch sizing." This round is that one design, on fake data with no Engine.

## The design

- **Piece | Setup** in the top bar switches screens.
- **Piece** has one bar and two tabs. The bar starts with the tab control, **Compare | Timeline**, then holds what belongs to the Piece whichever tab shows: Genre, Seed, auto-render, Play live, Render B. In portrait the tab control gets its own row across the window.
  - **Compare** (round 2's D): A is the reference render, B the candidate. Both waveforms on one time axis, A drawn up and B drawn down from the Section ruler, then the Piece as a diff table, A's Sound pick beside B's, differing rows tinted.
  - **Timeline** (round 2's E): each Part or lane is a row showing what it plays across the Sections, and the two renders are rows of the same timeline with one playhead through everything.
  - The tabs are two views of one Piece. The selected row, A/B, the playhead and the picker carry over when you switch, because they all live in the `Model`.
- **The picker** is the one way to change a sound, on both tabs and in Setup. It shows the selected row's Palette as pads (tap to pick and hear), then every preset. It sits beside the Piece, or under it below 900 dp wide. Its close button folds it to a rail (a bar in portrait) that still names the selected row; while it is closed, every row has a "change the sound" button that opens it on that row. A pick re-renders B by itself.
- **Setup**: the 16 MIDI channels as a 4 x 4 grid of pads, a keyboard to audition, and the same picker.

## Dark and touch only

One dark theme and one density, on every platform, macOS included, because the app is used live. Every target is at least 48 dp, every action has a visible button, and nothing needs a hover, a right click, a drag or a keyboard. A tap on a row or a pad selects it and plays it. Waveforms seek on a tap, so no gesture competes with scrolling.

Known exception: the black keys of the audition keyboard are narrower than 48 dp.

Keyboard shortcuts are extras: Space play, Tab A/B, T the other tab, ↑↓ row, ↵ open the picker, Esc close it, R re-roll the selected row, ⌘R render, N new seed, L play live, / search.

## Run

    flutter run -d macos

The `{}` button at the end of the top bar shows the in-memory state as JSON. Tap the Engine pill to see a freeze and restart.

## Screenshots without running

    FLUTTER_ROOT=$(dirname $(dirname $(readlink -f $(which flutter)))) flutter test --update-goldens test/screens_test.dart

writes `test/goldens/<state>-<size>.png` for Setup, Compare and Timeline, the last two with the picker closed and open, at 1440x900, 1100x720, 1280x800 and 800x1280.

## Files

- `lib/main.dart`: the app, the state panel, and the design intent.
- `lib/shell.dart`: the window, the Piece's bar and the tab control.
- `lib/compare.dart`, `lib/timeline.dart`: the two tabs.
- `lib/picker.dart`: the picker, open and closed.
- `lib/setup.dart`: the Setup screen.
- `lib/ui.dart`: tokens, type scale, components.
- `lib/data.dart`: fake data and the in-memory `Model`.
- `assets/fonts/`: Inter 4.1 (SIL Open Font License).
