// PROTOTYPE — renders each variant to PNG (with real fonts) so the screens can be looked at
// without running the app: flutter test --update-goldens test/screens_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screens_prototype/main.dart';

Future<void> _font(String family, List<String> files) async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File('$fonts/$f').readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
    await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  for (final v in ['A', 'B', 'C']) {
    for (final tab in [0, 1]) {
      testWidgets('variant $v screen $tab', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(PrototypeApp(initialVariant: v));
        await tester.pump();
        // Put something in A and B so the compare views show.
        final state = tester.state<State<PrototypeApp>>(find.byType(PrototypeApp)) as dynamic;
        await tester.runAsync(() async {
          await state.model.render();
          state.model.rollSeed();
          await state.model.render();
        });
        await tester.pump();
        if (tab == 1) {
          if (v == 'A') await tester.tap(find.text('Piece').first);
          if (v == 'B') await tester.tap(find.text('Piece').first);
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }
        if (!(v == 'C' && tab == 1)) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$v-$tab.png'));
        }
      });
    }
  }
}
