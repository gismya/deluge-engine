// PROTOTYPE — throwaway. Screen prototype for the deluge-engine GUI, round 3: the one design.
// Fake data, no Engine.
//
// Design intent
// - Round 2's Compare bench (D) is the base, with round 2's Timeline (E) as a second tab of the
//   Piece screen. The question the tool answers is "is this sound better than that one, in the
//   music?": Compare shows A against B (waveforms, then a diff table of the Sound picks), Timeline
//   shows where each Part plays across the Sections, with the renders as rows on the same time axis.
// - The tab control (Compare | Timeline) is the first thing in the Piece's bar, under the
//   Piece | Setup switch. Both tabs show the same Piece: the selected row, A/B, the playhead and the
//   picker carry over when you switch.
// - One way to change a sound: the picker. It sits beside the Piece (under it in portrait), shows
//   the selected row's Palette as pads and every preset below, and folds away to a rail when the
//   Piece should have the whole window. A pick re-renders B by itself, so the loop is: tap a pad,
//   tap B, listen. Setup uses the same picker to fill its 16 MIDI channel pads.
// - Dark only, and sized for a finger on every platform, macOS included: it is used live. Every
//   target is at least 48 dp, every action has a visible button, nothing needs a hover, a right
//   click, a drag or a keyboard. Keyboard shortcuts exist as extras.
//
// Files: shell.dart (window, Piece bar, tabs), compare.dart, timeline.dart, picker.dart, setup.dart,
// ui.dart (design system), data.dart (fake data and the Model).

import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'shell.dart';
import 'ui.dart';

void main() => runApp(const PrototypeApp());

class PrototypeApp extends StatefulWidget {
  const PrototypeApp({super.key});
  @override
  State<PrototypeApp> createState() => PrototypeAppState();
}

class PrototypeAppState extends State<PrototypeApp> {
  final model = Model();
  bool showState = false;

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Deluge Engine (prototype)',
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: model,
          builder: (context, _) {
            final t = Tk.of(context);
            return Stack(children: [
              Positioned.fill(
                child: Shell(
                  model: model,
                  // The prototype's own control: the in-memory state as JSON.
                  trailing: [
                    IconBtn(Icons.data_object, tooltip: 'Show the state (prototype)', active: showState, color: showState ? null : t.text3, onTap: () => setState(() => showState = !showState)),
                  ],
                ),
              ),
              if (showState)
                Positioned(
                  right: 12,
                  top: t.top + 8,
                  bottom: 40,
                  width: 340,
                  child: Material(
                    color: t.bg2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: t.lineStrong)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(model.toJson(), style: TextStyle(fontFamily: 'Menlo', fontSize: 12, color: t.text2)),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}
