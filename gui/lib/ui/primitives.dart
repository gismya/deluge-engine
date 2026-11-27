import 'package:deluge_engine_gui/ui/tokens.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A tap target whose hover state only changes surface shading (nothing hides
/// behind hover, spec §8).
class HoverBox extends StatefulWidget {
  const HoverBox({
    super.key,
    required this.builder,
    this.onTap,
    this.tooltip,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<HoverBox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hovered && widget.onTap != null),
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

/// Ensures [child] sits inside a hit area of at least 48 × 48 dp without
/// stretching the visual control (spec §8).
Widget hitBox(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );

/// 1 px horizontal hairline divider.
class Hr extends StatelessWidget {
  const Hr({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTokens.of(context).line);
}

/// 1 px vertical hairline divider.
class Vr extends StatelessWidget {
  const Vr({super.key, this.height});
  final double? height;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: height, color: AppTokens.of(context).line);
}

/// Uppercase tracked section heading.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTokens.of(context).label.copyWith(color: color),
      );
}

/// Compact 22 dp pill tag.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = false, this.color});
  final String text;
  final bool accent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final fg = color ?? (accent ? t.accent : t.text2);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: accent || color != null ? fg.withValues(alpha: 0.14) : t.bg2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost }

/// Standard button drawn at 44 dp inside a 48 dp hit box (spec §8).
class AppButton extends StatelessWidget {
  const AppButton(
    this.text, {
    super.key,
    this.icon,
    this.kind = BtnKind.secondary,
    this.onTap,
    this.tooltip,
  });

  final String text;
  final IconData? icon;
  final BtnKind kind;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isPrimary = kind == BtnKind.primary;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: HoverBox(
        onTap: onTap,
        tooltip: tooltip,
        builder: (_, hovered) {
          final bg = switch (kind) {
            BtnKind.primary =>
              hovered ? Color.lerp(t.accent, Colors.white, 0.12)! : t.accent,
            BtnKind.secondary => hovered ? t.bg3 : t.bg2,
            BtnKind.ghost => hovered ? t.bg2 : Colors.transparent,
          };
          final fg = isPrimary
              ? t.onAccent
              : (kind == BtnKind.ghost && !hovered ? t.text2 : t.text);
          return hitBox(
            Container(
              height: t.ctl,
              padding: EdgeInsets.only(left: icon != null ? 12 : 16, right: 16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: kind == BtnKind.secondary
                    ? Border.all(color: t.lineStrong.withValues(alpha: 0.7))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    maxLines: 1,
                    style: t.bodyM.copyWith(
                      color: fg,
                      fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icon button drawn 44 × 44 dp inside a 48 × 48 dp hit box (spec §8).
class AppIconButton extends StatelessWidget {
  const AppIconButton(
    this.icon, {
    super.key,
    this.onTap,
    this.tooltip,
    this.active = false,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: HoverBox(
        onTap: onTap,
        tooltip: tooltip,
        builder: (_, hovered) => hitBox(
          Container(
            width: t.ctl,
            height: t.ctl,
            decoration: BoxDecoration(
              color: filled
                  ? (hovered ? t.bg3 : t.bg2)
                  : (hovered ? t.bg3 : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: filled
                  ? Border.all(color: t.lineStrong.withValues(alpha: 0.7))
                  : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: color ?? (active ? t.accent : (hovered ? t.text : t.text2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control, 52 dp high so each option has a 48 dp hit target.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.expand = false,
  });

  final Map<T, String> items;
  final T value;
  final void Function(T) onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final cells = [
      for (final e in items.entries)
        HoverBox(
          onTap: () => onChanged(e.key),
          builder: (_, hovered) {
            final on = e.key == value;
            return Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: on ? t.bg3 : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: on
                      ? t.lineStrong.withValues(alpha: 0.6)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  e.value,
                  maxLines: 1,
                  style: t.bodyM.copyWith(color: on || hovered ? t.text : t.text2),
                ),
              ),
            );
          },
        ),
    ];

    return Container(
      height: 52,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.bg0,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final c in cells) expand ? Expanded(child: c) : c],
      ),
    );
  }
}

/// 48 dp high search / text input field.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hint,
    this.icon = Icons.search,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData? icon;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.bg0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: t.text3),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: t.body,
              cursorWidth: 1.2,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: t.body.copyWith(color: t.text3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown button styled like a secondary control with 48 dp items.
class AppMenu<T> extends StatelessWidget {
  const AppMenu({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.icon,
  });

  final T value;
  final Map<T, String> items;
  final void Function(T) onChanged;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem<T>(
            value: e.key,
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: e.key == value
                      ? Icon(Icons.check, size: 18, color: t.accent)
                      : null,
                ),
                Text(e.value, style: t.body),
              ],
            ),
          ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: hitBox(
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 10),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.lineStrong.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: t.text2),
                  const SizedBox(width: 8),
                ],
                if (label != null) ...[
                  Text(label!, style: t.small.copyWith(color: t.text3)),
                  const SizedBox(width: 8),
                ],
                Text(items[value] ?? '$value', maxLines: 1, style: t.bodyM),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more, size: 18, color: t.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat toggle switch matching the round-3 prototype.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? t.accent : t.bg3,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: on ? t.onAccent : t.text2,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Global keyboard shortcuts (extras; every action also has a visible button).
class KeyBindings extends StatefulWidget {
  const KeyBindings({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<SingleActivator, VoidCallback> bindings;
  final Widget child;

  @override
  State<KeyBindings> createState() => _KeyBindingsState();
}

class _KeyBindingsState extends State<KeyBindings> {
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final typing =
        FocusManager.instance.primaryFocus?.context?.widget is EditableText;
    final kb = HardwareKeyboard.instance;
    for (final entry in widget.bindings.entries) {
      final activator = entry.key;
      if (activator.trigger != event.logicalKey ||
          activator.meta != kb.isMetaPressed ||
          activator.shift != kb.isShiftPressed) {
        continue;
      }
      const allowedWhileTyping = [
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ];
      if (typing &&
          !activator.meta &&
          !allowedWhileTyping.contains(activator.trigger)) {
        continue;
      }
      entry.value();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
