import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// First-launch card folder prompt and card-image build progress view (spec §8).
class FirstLaunchCardScreen extends StatefulWidget {
  const FirstLaunchCardScreen({
    super.key,
    required this.model,
    required this.onPickFolder,
  });

  final AppModel model;
  final VoidCallback onPickFolder;

  @override
  State<FirstLaunchCardScreen> createState() => _FirstLaunchCardScreenState();
}

class _FirstLaunchCardScreenState extends State<FirstLaunchCardScreen> {
  final TextEditingController _pathController = TextEditingController();

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _submitPath() {
    final value = _pathController.text.trim();
    if (value.isNotEmpty) {
      widget.model.setCardFolder(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final model = widget.model;
    final building = model.cardState == CardState.building;
    final hasError = model.cardState == CardState.error;
    final total = model.cardProgressTotal;
    final done = model.cardProgressDone;
    final fraction = total > 0 ? (done / total).clamp(0.0, 1.0) : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.accentLine),
                      ),
                      child: Icon(
                        Icons.sd_card_outlined,
                        size: 20,
                        color: t.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        building
                            ? 'Building card image'
                            : 'Choose a Deluge card folder',
                        style: t.display,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  building
                      ? 'Preparing a cached FAT32 card image from ${model.cardFolder ?? ''}. Your folder is read-only and never modified.'
                      : 'Select a folder laid out like a Deluge SD card (SYNTHS, KITS, SAMPLES). The Engine reads sounds from a cached card image and never writes to your folder.',
                  style: t.body.copyWith(color: t.text2),
                ),
                const SizedBox(height: 24),
                if (building) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: t.bg3,
                      valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.cardFolder ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.small.copyWith(color: t.text3),
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '$done / $total',
                          style: t.numSmall.copyWith(color: t.text2),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  if (hasError && model.cardError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: t.err.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.err.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: t.err),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              model.cardError!,
                              style: t.small.copyWith(color: t.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  AppButton(
                    'Choose card folder…',
                    icon: Icons.folder_open_rounded,
                    kind: BtnKind.primary,
                    onTap: widget.onPickFolder,
                  ),
                  const SizedBox(height: 20),
                  const Hr(),
                  const SizedBox(height: 16),
                  const SectionLabel('Or enter folder path'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SearchField(
                          controller: _pathController,
                          hint: '/Users/you/Music/Deluge card',
                          icon: Icons.folder_outlined,
                          onSubmitted: (_) => _submitPath(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        'Use folder',
                        onTap: _submitPath,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking error view shown when `Hello.protocol_version` does not match
/// `PROTOCOL_VERSION_CURRENT` (spec §7.2).
class VersionMismatchScreen extends StatelessWidget {
  const VersionMismatchScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.err.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 24, color: t.err),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Incompatible Engine version',
                        style: t.display,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(message, style: t.body.copyWith(color: t.text2)),
                const SizedBox(height: 12),
                Text(
                  'Rebuild the GUI and Engine from the same commit so their protocol versions match.',
                  style: t.small.copyWith(color: t.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking view when the Engine could not start (for example, binary missing).
class EngineErrorScreen extends StatelessWidget {
  const EngineErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.err.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 24, color: t.err),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Engine could not start', style: t.display),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(message, style: t.body.copyWith(color: t.text2)),
                const SizedBox(height: 20),
                AppButton(
                  'Restart Engine',
                  icon: Icons.refresh_rounded,
                  kind: BtnKind.primary,
                  onTap: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
