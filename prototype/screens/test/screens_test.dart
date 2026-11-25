// PROTOTYPE — renders the design's main states to PNG (with the real fonts) so the screens can be
// looked at without running the app: flutter test --update-goldens test/screens_test.dart
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screens_prototype/data.dart';
import 'package:screens_prototype/main.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}

/// The Piece mid-comparison: a second Sound pick changed since A, A playing at 0:37.
void _piece(Model m, PieceTab tab, {required bool picker}) {
  m.setTab(tab);
  m.setPicker(picker);
  m.selectSlot('DRONE');
  m.setPick('DRONE', synth('126 Dark FM Pad'));
  m.play(m.slotA);
  m.seek(0.62);
}

/// A named state: what to do to the model before the picture is taken.
final shots = <String, void Function(Model m)>{
  'setup': (m) => m.setMode(Mode.setup),
  'compare': (m) => _piece(m, PieceTab.compare, picker: false),
  'compare-picker': (m) => _piece(m, PieceTab.compare, picker: true),
  'timeline': (m) => _piece(m, PieceTab.timeline, picker: false),
  'timeline-picker': (m) => _piece(m, PieceTab.timeline, picker: true),
};

void main() {
  setUpAll(() async {
    final material = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    await _font('Inter', ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-SemiBold.ttf']);
    await _font('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  });

  for (final shot in shots.entries) {
    // A Mac window large and small, and a tablet in landscape and portrait. One theme, one density.
    for (final size in const [Size(1440, 900), Size(1100, 720), Size(1280, 800), Size(800, 1280)]) {
      final file = '${shot.key}-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(file, (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const PrototypeApp());
        shot.value(tester.state<PrototypeAppState>(find.byType(PrototypeApp)).model);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$file.png'));
      });
    }
  }
}
