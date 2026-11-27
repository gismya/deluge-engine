import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/shell/chrome.dart';
import 'package:deluge_engine_gui/shell/first_launch.dart';
import 'package:deluge_engine_gui/shell/folder_picker.dart';
import 'package:deluge_engine_gui/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

typedef ScreenBuilder = Widget Function(BuildContext context, AppModel model);

/// Root application shell: top bar, active screen (first launch, Piece, or
/// Setup), freeze/restart veil, bottom status bar, and `{}` debug drawer
/// (spec §8).
///
/// G2 (Setup screen) and G3/G4 (Piece screen) plug into [setupBuilder] and
/// [pieceBuilder].
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.model,
    this.folderPicker = const PlatformFolderPicker(),
    this.pieceBuilder,
    this.setupBuilder,
  });

  final AppModel model;
  final FolderPicker folderPicker;
  final ScreenBuilder? pieceBuilder;
  final ScreenBuilder? setupBuilder;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _showState = false;

  Future<void> _pickCardFolder() async {
    final chosen = await widget.folderPicker.pickFolder(
      prompt: 'Choose a Deluge card folder',
    );
    if (chosen != null && chosen.isNotEmpty) {
      await widget.model.setCardFolder(chosen);
    }
  }

  Widget _buildBody(BuildContext context) {
    final model = widget.model;
    final status = model.backendStatus;

    if (status == BackendStatus.versionMismatch) {
      return VersionMismatchScreen(
        message: model.versionMismatchMessage ??
            'Engine protocol version does not match this GUI.',
      );
    }

    if (status == BackendStatus.error) {
      return EngineErrorScreen(
        message: model.lastError ?? 'Failed to start the Engine process.',
        onRetry: model.restartBackend,
      );
    }

    if (model.cardState != CardState.ready) {
      return FirstLaunchCardScreen(
        model: model,
        onPickFolder: _pickCardFolder,
      );
    }

    if (model.mode == AppMode.setup) {
      return widget.setupBuilder?.call(context, model) ??
          _ScreenPlaceholder(
            title: 'Setup',
            subtitle:
                '${model.setupBindings.length} of 16 MIDI channels bound · '
                '${model.catalog.synths.length} synths, '
                '${model.catalog.kits.length} kits available on card',
            icon: Icons.grid_view_rounded,
          );
    }

    return widget.pieceBuilder?.call(context, model) ??
        _ScreenPlaceholder(
          title: 'Piece',
          subtitle:
              '${model.genres.length} genres ready · '
              '${model.catalog.synths.length} synths, '
              '${model.catalog.kits.length} kits available on card',
          icon: Icons.compare_arrows_rounded,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final model = widget.model;
    final showMode = model.cardState == CardState.ready &&
        model.backendStatus != BackendStatus.versionMismatch &&
        model.backendStatus != BackendStatus.error;

    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: t.bg0,
            child: Column(
              children: [
                TopBar(
                  model: model,
                  showState: _showState,
                  onToggleState: () => setState(() => _showState = !_showState),
                  onPickCardFolder: _pickCardFolder,
                  showModeSwitch: showMode,
                ),
                Expanded(
                  child: RestartVeil(
                    model: model,
                    child: _buildBody(context),
                  ),
                ),
                StatusBar(model: model),
              ],
            ),
          ),
        ),
        if (_showState)
          Positioned(
            right: 12,
            top: t.top + 8,
            bottom: 40,
            width: 340,
            child: StateInspectorPanel(model: model),
          ),
      ],
    );
  }
}

class _ScreenPlaceholder extends StatelessWidget {
  const _ScreenPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.accentLine),
                ),
                child: Icon(icon, size: 20, color: t.accent),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.title),
                    const SizedBox(height: 4),
                    Text(subtitle, style: t.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
