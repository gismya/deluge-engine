import 'dart:io';

/// Abstraction for picking a card folder from the OS (injectable in tests).
abstract class FolderPicker {
  Future<String?> pickFolder({String? prompt});
}

/// Native folder picker with zero plugin dependencies (App Sandbox is off per
/// spec §12, so macOS `osascript` invokes the standard NSOpenPanel).
class PlatformFolderPicker implements FolderPicker {
  const PlatformFolderPicker();

  @override
  Future<String?> pickFolder({String? prompt}) async {
    if (!Platform.isMacOS) return null;
    final message = (prompt ?? 'Choose a Deluge card folder')
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
    final result = await Process.run(
      'osascript',
      ['-e', 'POSIX path of (choose folder with prompt "$message")'],
    );
    if (result.exitCode != 0) return null;
    var chosen = (result.stdout as String).trim();
    if (chosen.endsWith('/') && chosen.length > 1) {
      chosen = chosen.substring(0, chosen.length - 1);
    }
    return chosen.isEmpty ? null : chosen;
  }
}
