# PROTOTYPE: Setup and Piece screens (throwaway)

Answers the wayfinder ticket "What do the Setup and Piece screens look like?" (gismya/deluge-engine#19). Three structurally different variants on fake data, no Engine:

- **A, Tabs and tables:** toolbar, a Setup tab with a row per MIDI channel, a Piece tab with form, parts table and render list. Presets are picked in a dialog.
- **B, Browser and strips:** the preset browser is always open; channel strips (Setup) or part strips (Piece); click a preset to put it on the selected strip; A/B deck at the bottom.
- **C, Piece first, palette in view:** Piece controls and A/B compare on top; every Part and lane shows its palette as chips with weights; the live Setup is a side panel.

Run: `flutter run -d chrome --web-browser-flag=--app=about:blank` (or `-d macos` once Xcode is installed). Switch variants with the floating bar or ← →; start on one with `?variant=B` (web) or `--dart-define=VARIANT=B`. The `{}` button shows the full in-memory state; "Simulate freeze" shows the Engine restart.

Screenshots without running: `FLUTTER_ROOT=<flutter sdk> flutter test --update-goldens test/screens_test.dart` writes `test/goldens/*.png`.
