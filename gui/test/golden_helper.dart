import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Pixel-difference tolerance for GUI goldens across macOS versions (spec §8).
const double kGoldenPixelTolerance = 0.005; // 0.5%

/// [LocalFileComparator] allowing up to [precisionTolerance] (0.5%) differing
/// pixels to absorb minor cross-macOS font rasterization differences (spec §8).
class TolerantGoldenFileComparator extends LocalFileComparator {
  TolerantGoldenFileComparator(
    super.testFile, {
    this.precisionTolerance = kGoldenPixelTolerance,
  });

  final double precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) {
      result.dispose();
      return true;
    }
    if (result.diffPercent <= precisionTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Installs [TolerantGoldenFileComparator] for the current test file.
void installTolerantGoldenComparator(String testFileRelativePath) {
  final testUri = Uri.file(p.absolute(testFileRelativePath));
  goldenFileComparator = TolerantGoldenFileComparator(testUri);
}

/// Loads the bundled Inter font family and Flutter SDK's MaterialIcons font so
/// headless golden tests render real glyphs instead of Ahem boxes.
Future<void> loadTestFonts() async {
  await _loadFont('Inter', const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
  ]);

  final materialIconsPath = _findMaterialIconsFont();
  if (materialIconsPath != null) {
    await _loadFont('MaterialIcons', [materialIconsPath]);
  }
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final filePath in paths) {
    final bytes = File(filePath).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

String? _findMaterialIconsFont() {
  final candidates = <String>[];
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    candidates.add(
      p.join(
        envRoot,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ),
    );
  }

  // Walk up from Platform.resolvedExecutable (inside flutter/bin/cache/...).
  var dir = Directory(p.dirname(Platform.resolvedExecutable));
  for (var i = 0; i < 8; i++) {
    candidates.add(
      p.join(
        dir.path,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ),
    );
    candidates.add(
      p.join(
        dir.path,
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ),
    );
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}
