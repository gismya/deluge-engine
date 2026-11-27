import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/model/app_model.dart';
import 'package:deluge_engine_gui/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Top application bar matching the round-3 prototype (spec §8):
/// app mark + title, `Piece | Setup` switch, card folder pill, Engine state &
/// voice count pill, and `{}` debug state button.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.model,
    required this.showState,
    required this.onToggleState,
    this.onPickCardFolder,
    this.showModeSwitch = true,
  });

  final AppModel model;
  final bool showState;
  final VoidCallback onToggleState;
  final VoidCallback? onPickCardFolder;
  final bool showModeSwitch;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 900;

    return Container(
      height: t.top,
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 17,
              color: t.onAccent,
            ),
          ),
          const SizedBox(width: 10),
          if (!narrow)
            Text(
              'Deluge Engine',
              style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
            ),
          if (showModeSwitch) ...[
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SegmentedControl<AppMode>(
                items: const {
                  AppMode.piece: 'Piece',
                  AppMode.setup: 'Setup',
                },
                value: model.mode,
                onChanged: model.setMode,
              ),
            ),
          ],
          const Spacer(),
          if (model.cardFolder != null) ...[
            CardPill(
              model: model,
              compact: narrow,
              onTap: onPickCardFolder,
            ),
            const SizedBox(width: 4),
          ],
          EnginePill(model: model),
          AppIconButton(
            Icons.data_object,
            tooltip: 'Show state as JSON',
            active: showState,
            color: showState ? null : t.text3,
            onTap: onToggleState,
          ),
        ],
      ),
    );
  }
}

/// Displays the active card folder path (icon-only under 900 dp) and opens the
/// folder chooser on tap.
class CardPill extends StatelessWidget {
  const CardPill({
    super.key,
    required this.model,
    this.compact = false,
    this.onTap,
  });

  final AppModel model;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final folder = model.cardFolder ?? '';
    final synths = model.catalog.synths.length;
    final kits = model.catalog.kits.length;
    final tip = model.cardState == CardState.ready
        ? 'Card folder: $synths synths, $kits kits. Tap to choose another'
        : 'Card folder: $folder. Tap to choose another';

    return HoverBox(
      tooltip: tip,
      onTap: onTap,
      builder: (_, hovered) => hitBox(
        Container(
          height: t.ctl,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hovered ? t.bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sd_card_outlined, size: 20, color: t.text3),
              if (!compact) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.small,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the Engine lifecycle state, voice meter, and live voice count.
class EnginePill extends StatelessWidget {
  const EnginePill({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final status = model.backendStatus;
    final running = status == BackendStatus.running;
    final isWarn = status == BackendStatus.starting ||
        status == BackendStatus.restarting;
    final isErr = status == BackendStatus.crashed ||
        status == BackendStatus.versionMismatch ||
        status == BackendStatus.error;

    final dotColor = running
        ? t.ok
        : isWarn
            ? t.warn
            : isErr
                ? t.err
                : t.text3;

    final label = switch (status) {
      BackendStatus.running => 'Engine',
      BackendStatus.starting => 'Engine starting…',
      BackendStatus.restarting => 'Engine restarting…',
      BackendStatus.crashed => 'Engine stopped',
      BackendStatus.versionMismatch => 'Version mismatch',
      BackendStatus.error => 'Engine error',
      BackendStatus.stopped => 'Engine stopped',
    };

    final bgColor = isWarn
        ? t.warn.withValues(alpha: 0.12)
        : isErr
            ? t.err.withValues(alpha: 0.12)
            : Colors.transparent;

    return Tooltip(
      message: model.hello != null
          ? 'Engine ${model.hello!.engineVersion} (protocol v${model.hello!.protocolVersion})'
          : label,
      child: hitBox(
        Container(
          height: t.ctl,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: t.small.copyWith(
                  color: running
                      ? t.text2
                      : isWarn
                          ? t.warn
                          : isErr
                              ? t.err
                              : t.text3,
                ),
              ),
              if (running) ...[
                const SizedBox(width: 10),
                Meter(value: model.voices, max: 16, segments: 8, height: 10),
                const SizedBox(width: 4),
                SizedBox(
                  width: 62,
                  child: Text(
                    '${model.voices} voices',
                    textAlign: TextAlign.right,
                    softWrap: false,
                    style: t.numSmall.copyWith(color: t.text3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom status line: current activity on the left, last freeze code & what
/// was loaded (or last error) on the right (spec §7.7, §8).
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final status = model.backendStatus;
    final restarting = status == BackendStatus.restarting ||
        status == BackendStatus.starting;
    final isErr = status == BackendStatus.crashed ||
        status == BackendStatus.versionMismatch ||
        status == BackendStatus.error;

    final freeze = model.lastFreeze;
    final rightError = freeze != null
        ? 'Last freeze: ${freeze.summary}'
        : (model.lastError != null ? 'Last error: ${model.lastError}' : null);

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(top: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (restarting) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: t.warn,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              model.statusMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.cap.copyWith(
                color: isErr
                    ? t.err
                    : restarting
                        ? t.warn
                        : t.text2,
              ),
            ),
          ),
          if (rightError != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.error_outline, size: 14, color: t.err),
            const SizedBox(width: 4),
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  rightError,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cap.copyWith(color: t.err),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dims the workspace during an Engine freeze/restart or after 3 freezes in a
/// minute (when auto-restart stops and shows a Restart button, spec §7.7).
class RestartVeil extends StatelessWidget {
  const RestartVeil({
    super.key,
    required this.model,
    required this.child,
  });

  final AppModel model;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final status = model.backendStatus;
    if (status != BackendStatus.restarting && status != BackendStatus.crashed) {
      return child;
    }

    final freeze = model.lastFreeze;
    final code = freeze?.code ?? 'unknown';
    final loadedSuffix =
        freeze != null && freeze.loaded.isNotEmpty ? ' · ${freeze.loaded}' : '';
    final crashed = status == BackendStatus.crashed;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(opacity: 0.45, child: child),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (crashed ? t.err : t.warn).withValues(alpha: 0.55),
                ),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (crashed)
                        Icon(Icons.error_outline, size: 18, color: t.err)
                      else
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: t.warn,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          crashed
                              ? 'The Engine froze ($code$loadedSuffix) 3 times in a minute and stopped.'
                              : 'The Engine froze ($code$loadedSuffix). Restarting and reloading your Setup…',
                          style: t.bodyM,
                        ),
                      ),
                    ],
                  ),
                  if (crashed)
                    AppButton(
                      'Restart',
                      icon: Icons.refresh_rounded,
                      kind: BtnKind.primary,
                      onTap: model.restartBackend,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating JSON inspector toggled by the `{}` button in the top bar (spec §8).
class StateInspectorPanel extends StatelessWidget {
  const StateInspectorPanel({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      color: t.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.lineStrong),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          model.toDebugJson(),
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 12,
            color: t.text2,
          ),
        ),
      ),
    );
  }
}
