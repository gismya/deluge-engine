import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:deluge_engine_gui/backend/engine_backend.dart';
import 'package:deluge_engine_gui/backend/fake_backend.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/model/state_store.dart';
import 'package:deluge_engine_gui/shell/folder_picker.dart';
import 'package:deluge_engine_gui/shell/shell.dart';
import 'package:deluge_engine_gui/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  final useFake = args.contains('--fake') ||
      Platform.environment['DELUGE_GUI_FAKE'] == '1';
  final audioIndex = args.indexOf('--audio');
  final audio = (audioIndex >= 0 && audioIndex + 1 < args.length)
      ? args[audioIndex + 1]
      : 'default';

  final backend = useFake
      ? FakeBackend(heartbeatInterval: const Duration(milliseconds: 250))
      : EngineBackend(
          audioBackend: audio,
          trace: args.contains('--trace'),
        );
  final store = useFake ? MemoryStateStore() : FileStateStore();
  final model = AppModel(backend: backend, store: store);

  runApp(DelugeEngineApp(model: model, ownsModel: true));
}

/// Top-level Flutter application widget for Deluge Engine.
class DelugeEngineApp extends StatefulWidget {
  const DelugeEngineApp({
    super.key,
    required this.model,
    this.ownsModel = false,
    this.folderPicker = const PlatformFolderPicker(),
    this.pieceBuilder,
    this.setupBuilder,
  });

  final AppModel model;
  final bool ownsModel;
  final FolderPicker folderPicker;
  final ScreenBuilder? pieceBuilder;
  final ScreenBuilder? setupBuilder;

  @override
  State<DelugeEngineApp> createState() => _DelugeEngineAppState();
}

class _DelugeEngineAppState extends State<DelugeEngineApp> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    unawaited(widget.model.init());
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        await widget.model.backend.shutdown();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    if (widget.ownsModel) {
      widget.model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Deluge Engine',
        theme: buildAppTheme(),
        home: ListenableBuilder(
          listenable: widget.model,
          builder: (context, _) => Shell(
            model: widget.model,
            folderPicker: widget.folderPicker,
            pieceBuilder: widget.pieceBuilder,
            setupBuilder: widget.setupBuilder,
          ),
        ),
      );
}
