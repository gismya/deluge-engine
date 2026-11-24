# PROTOTYPE: Setup and Piece screens, round 2 (throwaway)

Answers the wayfinder ticket "What do the Setup and Piece screens look like?" (gismya/deluge-engine#19). Round 1's variants A, B and C are gone (git keeps them); the verdict was "ugly, B is the best". This round has one iteration on B and two new ideas, on fake data with no Engine.

## The three variants

- **B2, Browser and strips.** B's idea, redone. The preset browser is always open on the left and says what it fills ("Fill ACID"); it lists that slot's Palette first, with each sound's share of re-rolls, then every preset. The middle holds dense strips in hairline groups (the Kit's lanes, the Parts, the FX lanes, past renders; or the 16 MIDI channels in Setup). Under them, an inspector for the selected strip with a keyboard to audition it: v2's "edit this sound" opens here. The A/B deck is fixed at the bottom: two lanes on one time axis with one playhead, and a line saying which picks differ.
- **D, Compare bench.** Built around A/B. A is the reference render, B the candidate. Top: both waveforms on one time axis, A drawn up and B drawn down from the Section ruler. Middle: the Piece as a diff table, A's Sound pick beside B's, differing rows tinted. Right: the picker for the selected row, with the Palette as pads and every preset below. A pick re-renders B by itself, so the loop is pad, Tab, listen. Setup is a 4 x 4 grid of channel pads.
- **E, Timeline.** Sound-first. Each Part or lane is a row showing what it plays across the Sections (Intro, Groove, Build, Drop, Break, Outro), and the two renders are rows of the same timeline with one playhead through everything. No browser on screen: changing a sound opens a command palette (Palette first, then every preset, then actions) where the arrow keys audition and Enter picks. Setup is a list of the 16 channels with the same palette.

All three share one small design system (`lib/ui.dart`): near-black neutral surfaces, one indigo accent, Inter with tabular figures, a 4/8 spacing grid, hairlines instead of cards, dark and light themes.

## Mouse and touch

The design has two densities, picked by `Tk.touch`:

- **Mouse** (macOS): 28 to 36 px rows, hover shows row actions, key hints are shown.
- **Touch** (Android tablet): every target is at least 48 dp, row actions are always visible, key hints are hidden, and nothing needs hover, a right click, a keyboard or a drag. A tap on a strip or row selects it and plays it. Waveforms seek on a tap, so no gesture competes with scrolling. Below 900 dp wide (portrait) the side panels move under the main area.

Touch is on by default on Android and iOS, with `--dart-define=TOUCH=true`, or with the hand icon in the prototype switcher.

Known exception: the black keys of the audition keyboard are narrower than 48 dp.

## Run

    flutter run -d macos                              # starts on B2
    flutter run -d macos --dart-define=VARIANT=D      # or E
    flutter run -d macos --dart-define=TOUCH=true     # tablet sizes on the desktop

The pill in the middle of the top bar switches variants (also F1, F2, F3), light or dark, mouse or touch, and shows the in-memory state (`{}`). Click the Engine pill to see a freeze and restart.

Keys (mouse density): Space play, Tab A/B, ⌘R render, R re-roll the selected Part, N new seed, L play live, / search. D and E: ↑↓ move between rows. E: ↵ or ⌘K opens the palette.

## Screenshots without running

    FLUTTER_ROOT=$(dirname $(dirname $(readlink -f $(which flutter)))) flutter test --update-goldens test/screens_test.dart

writes `test/goldens/<variant>-<state>-[tablet-]<theme>-<size>.png`: each variant's Piece, Setup and A/B states (and E's palette), at 1440x900 and 1100x720 (mouse), and at 1280x800 and 800x1280 (touch).

## Files

- `lib/data.dart`: fake data and the in-memory `Model`.
- `lib/ui.dart`: tokens, type scale, components.
- `lib/variant_b2.dart`, `variant_d.dart`, `variant_e.dart`: the variants, each with its design intent at the top.
- `lib/main.dart`: the app and the switcher.
- `assets/fonts/`: Inter 4.1 (SIL Open Font License).
