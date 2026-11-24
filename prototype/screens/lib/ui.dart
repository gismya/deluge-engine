// PROTOTYPE — throwaway. The small design system the three variants share: colour tokens for a dark
// and a light theme, a type scale on Inter, and a handful of components (buttons, segmented control,
// search field, preset row, waveform, meters, keyboard, engine status).
//
// Rules: one accent colour; surfaces differ by a step of grey and a hairline border, never a shadow
// or a heavy card; spacing on a 4/8 grid; rows 28–40 px high; numbers in tabular figures.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';

// ---------------------------------------------------------------------------------------------
// Tokens

class Tk extends ThemeExtension<Tk> {
  const Tk({
    required this.dark,
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.err,
    this.touch = false,
  });

  final bool dark;
  final bool touch; // a touch screen: 48 dp targets, actions always visible, no key hints
  final Color bg0; // the window
  final Color bg1; // panels
  final Color bg2; // hover, inset controls
  final Color bg3; // pressed, selected neutral
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color onAccent;
  final Color ok;
  final Color warn;
  final Color err;

  static const night = Tk(
    dark: true,
    bg0: Color(0xFF0D0E10),
    bg1: Color(0xFF131417),
    bg2: Color(0xFF1B1D21),
    bg3: Color(0xFF25282D),
    line: Color(0xFF23262B),
    lineStrong: Color(0xFF33373E),
    text: Color(0xFFEDEEF0),
    text2: Color(0xFFA3A7AF),
    text3: Color(0xFF6C717A),
    accent: Color(0xFF8E8CFF),
    onAccent: Color(0xFF0D0E10),
    ok: Color(0xFF4CC38A),
    warn: Color(0xFFE5A53A),
    err: Color(0xFFF2635F),
  );

  static const day = Tk(
    dark: false,
    bg0: Color(0xFFF4F4F6),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFEFEFF2),
    bg3: Color(0xFFE4E4E9),
    line: Color(0xFFE4E5E9),
    lineStrong: Color(0xFFCDCFD6),
    text: Color(0xFF15171C),
    text2: Color(0xFF595E69),
    text3: Color(0xFF8A8F99),
    accent: Color(0xFF5350E0),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF1F9D63),
    warn: Color(0xFFB7791F),
    err: Color(0xFFD9423E),
  );

  static Tk of(BuildContext context) => Theme.of(context).extension<Tk>()!;

  Tk withTouch(bool v) => Tk(dark: dark, bg0: bg0, bg1: bg1, bg2: bg2, bg3: bg3, line: line, lineStrong: lineStrong, text: text, text2: text2, text3: text3, accent: accent, onAccent: onAccent, ok: ok, warn: warn, err: err, touch: v);

  // Sizes that change with the input: a mouse gets dense rows, a finger gets 48 dp.
  double get top => touch ? 56 : 44; // the top bar
  double get bar => touch ? 64 : 48; // a toolbar under it
  double get row => touch ? 48 : 36; // a strip
  double get listRow => touch ? 48 : 28; // a preset in a list
  double get ctl => touch ? 40 : 28; // a button, drawn; its hit area is 48 on touch
  double get _up => touch ? 1 : 0;

  /// The accent as a tint for selected rows.
  Color get accentSoft => accent.withValues(alpha: dark ? 0.14 : 0.10);
  Color get accentLine => accent.withValues(alpha: dark ? 0.55 : 0.5);

  static const _tab = [FontFeature.tabularFigures()];

  TextStyle get body => TextStyle(fontSize: 13 + _up, height: 18 / 13, fontWeight: FontWeight.w400, color: text);
  TextStyle get bodyM => body.copyWith(fontWeight: FontWeight.w500);
  TextStyle get small => TextStyle(fontSize: 12 + _up, height: 16 / 12, fontWeight: FontWeight.w400, color: text2);
  TextStyle get cap => TextStyle(fontSize: 11 + _up, height: 14 / 11, fontWeight: FontWeight.w500, color: text3);
  TextStyle get label =>
      TextStyle(fontSize: 10.5, height: 14 / 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: text3);
  TextStyle get title => TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: text);
  TextStyle get display =>
      TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: text);
  TextStyle get num => body.copyWith(fontFeatures: _tab);
  TextStyle get numSmall => small.copyWith(fontFeatures: _tab);

  @override
  Tk copyWith() => this;
  @override
  Tk lerp(Tk? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(bool dark, {bool touch = false}) {
  final t = (dark ? Tk.night : Tk.day).withTouch(touch);
  final scheme = ColorScheme.fromSeed(seedColor: t.accent, brightness: dark ? Brightness.dark : Brightness.light).copyWith(
    primary: t.accent,
    onPrimary: t.onAccent,
    surface: t.bg1,
    onSurface: t.text,
    outline: t.lineStrong,
    outlineVariant: t.line,
    error: t.err,
  );
  return ThemeData(
    brightness: scheme.brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: t.bg0,
    canvasColor: t.bg1,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: t.bg2,
    dividerColor: t.line,
    extensions: [t],
    textTheme: Typography.englishLike2021.apply(fontFamily: 'Inter', bodyColor: t.text, displayColor: t.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent, selectionColor: t.accent.withValues(alpha: 0.3)),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(color: t.dark ? t.bg3 : t.text, borderRadius: BorderRadius.circular(5)),
      textStyle: TextStyle(fontSize: 11.5, color: t.dark ? t.text : t.bg1, fontFamily: 'Inter'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.bg2,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: t.lineStrong)),
      textStyle: t.body,
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(t.text3.withValues(alpha: 0.35)),
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Primitives

/// Calls [builder] with whether the pointer is over it; taps go to [onTap].
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder, this.onTap, this.onDoubleTap, this.tooltip});
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? tooltip;
  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool over = false;
  @override
  Widget build(BuildContext context) {
    Widget w = MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => over = true),
      onExit: (_) => setState(() => over = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: widget.builder(context, over && widget.onTap != null),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, child: w);
    return w;
  }
}

/// On a touch screen, gives [child] a 48 dp hit area without drawing it any bigger.
Widget hit(Tk t, Widget child) => t.touch
    ? ConstrainedBox(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), child: Center(widthFactor: 1, heightFactor: 1, child: child))
    : child;

/// A 1 px line.
class Hr extends StatelessWidget {
  const Hr({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: Tk.of(context).line);
}

class Vr extends StatelessWidget {
  const Vr({super.key, this.height});
  final double? height;
  @override
  Widget build(BuildContext context) => Container(width: 1, height: height, color: Tk.of(context).line);
}

/// An upper-case section label.
class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Tk.of(context).label.copyWith(color: color));
}

/// A key cap: ⌘R, Space, Tab.
class Kbd extends StatelessWidget {
  const Kbd(this.keys, {super.key, this.onAccent = false});
  final String keys;
  final bool onAccent;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    if (t.touch) return const SizedBox.shrink();
    final c = onAccent ? t.onAccent.withValues(alpha: 0.7) : t.text3;
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: onAccent ? t.onAccent.withValues(alpha: 0.3) : t.lineStrong),
      ),
      child: Text(keys, style: TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w500, color: c)),
    );
  }
}

/// A small tag. [accent] tints it.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = false, this.color});
  final String text;
  final bool accent;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final c = color ?? (accent ? t.accent : t.text2);
    return Container(
      height: t.touch ? 20 : 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: accent || color != null ? c.withValues(alpha: 0.14) : t.bg2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: t.touch ? 12 : 11, height: 1.2, fontWeight: FontWeight.w500, color: c)),
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost }

class Btn extends StatelessWidget {
  const Btn(this.text, {super.key, this.icon, this.kind = BtnKind.secondary, this.onTap, this.kbd, this.tooltip, this.height});
  final String text;
  final IconData? icon;
  final BtnKind kind;
  final VoidCallback? onTap;
  final String? kbd;
  final String? tooltip;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final primary = kind == BtnKind.primary;
    final kbd = t.touch ? null : this.kbd;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Hover(
        onTap: onTap,
        tooltip: tooltip,
        builder: (_, h) {
          final bg = switch (kind) {
            BtnKind.primary => h ? Color.lerp(t.accent, t.dark ? Colors.white : Colors.black, 0.12)! : t.accent,
            BtnKind.secondary => h ? t.bg3 : t.bg2,
            BtnKind.ghost => h ? t.bg2 : Colors.transparent,
          };
          final fg = primary ? t.onAccent : (kind == BtnKind.ghost && !h ? t.text2 : t.text);
          return hit(t, Container(
            height: t.touch ? t.ctl : (height ?? t.ctl),
            padding: EdgeInsets.only(left: (icon != null ? 8 : 10) + (t.touch ? 4 : 0), right: (kbd != null ? 6 : 10) + (t.touch ? 4 : 0)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: kind == BtnKind.secondary ? Border.all(color: t.lineStrong.withValues(alpha: 0.7)) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: t.touch ? 18 : 15, color: fg), const SizedBox(width: 6)],
              Text(text, maxLines: 1, style: t.bodyM.copyWith(color: fg, fontSize: t.touch ? 14 : 12.5)),
              if (kbd != null) ...[const SizedBox(width: 8), Kbd(kbd, onAccent: primary)],
            ]),
          ));
        },
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, this.onTap, this.tooltip, this.active = false, this.size = 28, this.color, this.filled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final double size;
  final Color? color;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Hover(
        onTap: onTap,
        tooltip: tooltip,
        builder: (_, h) => hit(t, Container(
          width: t.touch ? 40 : size,
          height: t.touch ? 40 : size,
          decoration: BoxDecoration(
            color: filled ? (h ? t.bg3 : t.bg2) : (h ? t.bg3 : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            border: filled ? Border.all(color: t.lineStrong.withValues(alpha: 0.7)) : null,
          ),
          child: Icon(icon, size: t.touch ? 20 : size * 0.57, color: color ?? (active ? t.accent : (h ? t.text : t.text2))),
        )),
      ),
    );
  }
}

/// A segmented control.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.items, required this.value, required this.onChanged, this.expand = false, this.height});
  final Map<T, String> items;
  final T value;
  final void Function(T) onChanged;
  final bool expand;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final height = t.touch ? 48.0 : (this.height ?? 28.0);
    final cells = [
      for (final e in items.entries)
        Hover(
          onTap: () => onChanged(e.key),
          builder: (_, h) {
            final on = e.key == value;
            return Container(
              height: height - 6,
              constraints: BoxConstraints(minWidth: t.touch ? 48 : 0),
              padding: EdgeInsets.symmetric(horizontal: t.touch ? 16 : 10),
              alignment: expand ? Alignment.center : null,
              decoration: BoxDecoration(
                color: on ? (t.dark ? t.bg3 : t.bg1) : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: on ? Border.all(color: t.lineStrong.withValues(alpha: t.dark ? 0.6 : 1)) : Border.all(color: Colors.transparent),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(e.value,
                  maxLines: 1,
                  style: t.bodyM.copyWith(fontSize: t.touch ? 14 : 12.5, color: on ? t.text : (h ? t.text : t.text2))),
              ),
            );
          },
        ),
    ];
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.dark ? t.bg0 : t.bg2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final c in cells) expand ? Expanded(child: c) : c],
      ),
    );
  }
}

/// A search field. [kbd] is the hint shown while it is empty.
class SearchField extends StatelessWidget {
  const SearchField({super.key, this.controller, this.focusNode, required this.hint, this.onChanged, this.kbd, this.autofocus = false, this.height, this.bare = false, this.onSubmitted});
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? kbd;
  final bool autofocus;
  final double? height;
  final bool bare;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final big = (this.height ?? 0) > 36;
    final height = this.height ?? (t.touch ? 48.0 : 32.0);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 8),
      decoration: bare
          ? null
          : BoxDecoration(
              color: t.dark ? t.bg0 : t.bg2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.line),
            ),
      child: Row(children: [
        Icon(Icons.search, size: big ? 18 : 15, color: t.text3),
        SizedBox(width: big ? 10 : 6),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: big ? t.title.copyWith(fontWeight: FontWeight.w400) : t.body,
            cursorWidth: 1.2,
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: (big ? t.title.copyWith(fontWeight: FontWeight.w400) : t.body).copyWith(color: t.text3),
            ),
          ),
        ),
        if (kbd != null) Kbd(kbd!),
      ]),
    );
  }
}

/// A dropdown that looks like a secondary button.
class Menu<T> extends StatelessWidget {
  const Menu({super.key, required this.value, required this.items, required this.onChanged, this.label, this.icon});
  final T value;
  final Map<T, String> items;
  final void Function(T) onChanged;
  final String? label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem<T>(
            value: e.key,
            height: t.touch ? 48 : 30,
            child: Row(children: [
              SizedBox(width: 20, child: e.key == value ? Icon(Icons.check, size: 14, color: t.accent) : null),
              Text(e.value, style: t.body),
            ]),
          ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: hit(t, Container(
          height: t.ctl,
          padding: EdgeInsets.only(left: t.touch ? 14 : 10, right: t.touch ? 10 : 6),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.lineStrong.withValues(alpha: 0.7)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: t.text2), const SizedBox(width: 6)],
            if (label != null) ...[Text(label!, style: t.small.copyWith(color: t.text3)), const SizedBox(width: 6)],
            Text(items[value] ?? '$value', maxLines: 1, style: t.bodyM.copyWith(fontSize: t.touch ? 14 : 12.5)),
            const SizedBox(width: 2),
            Icon(Icons.unfold_more, size: 14, color: t.text3),
          ]),
        )),
      ),
    );
  }
}

/// The Seed: a number you can type, and a die to roll a new one.
class SeedField extends StatefulWidget {
  const SeedField({super.key, required this.model});
  final Model model;
  @override
  State<SeedField> createState() => _SeedFieldState();
}

class _SeedFieldState extends State<SeedField> {
  late final c = TextEditingController(text: '${widget.model.seed}');
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final s = '${widget.model.seed}';
    if (c.text != s && int.tryParse(c.text) != widget.model.seed) c.text = s;
    return Container(
      height: t.touch ? 48 : 28,
      padding: EdgeInsets.only(left: t.touch ? 14 : 10),
      decoration: BoxDecoration(
        color: t.dark ? t.bg0 : t.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Seed', style: t.small.copyWith(color: t.text3)),
        const SizedBox(width: 6),
        SizedBox(
          width: t.touch ? 52 : 44,
          child: TextField(
            controller: c,
            style: t.num.copyWith(fontWeight: FontWeight.w500, fontSize: t.touch ? 14 : 12.5),
            cursorWidth: 1.2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            decoration: const InputDecoration.collapsed(hintText: ''),
            onChanged: (v) => widget.model.setSeed(int.tryParse(v) ?? 0),
          ),
        ),
        IconBtn(Icons.casino_outlined, tooltip: 'New seed  (N)', size: 26, onTap: widget.model.rollSeed),
      ]),
    );
  }
}

/// Global key bindings. Plain keys are ignored while a text field has the focus.
class Keys extends StatefulWidget {
  const Keys({super.key, required this.bindings, required this.child});
  final Map<SingleActivator, VoidCallback> bindings;
  final Widget child;
  @override
  State<Keys> createState() => _KeysState();
}

class _KeysState extends State<Keys> {
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final typing = FocusManager.instance.primaryFocus?.context?.widget is EditableText;
    final kb = HardwareKeyboard.instance;
    for (final b in widget.bindings.entries) {
      final a = b.key;
      if (a.trigger != e.logicalKey || a.meta != kb.isMetaPressed || a.shift != kb.isShiftPressed) continue;
      // While typing, only the keys a text field doesn't use get through.
      const free = [LogicalKeyboardKey.escape, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.enter];
      if (typing && !a.meta && !free.contains(a.trigger)) continue;
      b.value();
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

// ---------------------------------------------------------------------------------------------
// Sound widgets

IconData soundIcon(String? path) => path == null
    ? Icons.add
    : path.startsWith('KITS/')
        ? Icons.grid_view_rounded
        : path.startsWith('SAMPLES/')
            ? Icons.graphic_eq
            : Icons.piano;

String soundKind(String? path) => path == null
    ? 'Empty'
    : path.startsWith('KITS/')
        ? 'Kit'
        : path.startsWith('SAMPLES/')
            ? 'Sample'
            : 'Synth';

/// A preset's number in muted tabular figures, then its title.
class SoundName extends StatelessWidget {
  const SoundName(this.path, {super.key, this.style, this.muted = false, this.number = true});
  final String path;
  final bool number;
  final TextStyle? style;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final (n, title) = splitName(path);
    final s = (style ?? t.body).copyWith(color: muted ? t.text2 : null);
    return Text.rich(
      TextSpan(children: [
        if (n != null && number) TextSpan(text: '$n  ', style: s.copyWith(color: t.text3, fontFeatures: const [FontFeature.tabularFigures()], fontWeight: FontWeight.w400)),
        TextSpan(text: title),
      ]),
      style: s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A Palette weight as a bar and a share: how likely a re-roll lands on this sound.
class WeightBar extends StatelessWidget {
  const WeightBar({super.key, required this.weight, required this.total, this.on = false, this.width = 40});
  final int weight;
  final int total;
  final bool on;
  final double width;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (width > 0) ...[
        SizedBox(
          width: width,
          height: 4,
          child: CustomPaint(painter: _BarPainter(weight / total, on ? t.accent : t.text3, t.lineStrong)),
        ),
        const SizedBox(width: 8),
      ],
      SizedBox(
        width: 36,
        child: Text('${(100 * weight / total).round()}%', textAlign: TextAlign.right, softWrap: false, style: t.numSmall.copyWith(fontSize: 11.5, color: on ? t.text : t.text3)),
      ),
    ]);
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.fg, this.bg);
  final double v;
  final Color fg;
  final Color bg;
  @override
  void paint(Canvas c, Size s) {
    final r = Radius.circular(s.height / 2);
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, r), Paint()..color = bg);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s.width * v, s.height), r), Paint()..color = fg);
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v || o.fg != fg || o.bg != bg;
}

/// One preset in a list. Click picks it; the play button, shown on hover, auditions it.
class PresetRow extends StatelessWidget {
  const PresetRow({super.key, required this.path, required this.model, this.current = false, this.cursor = false, this.onTap, this.trailing, this.height, this.padding = 12});
  final String path;
  final Model model;
  final bool current; // the sound the target has now
  final bool cursor; // keyboard highlight
  final VoidCallback? onTap;
  final Widget? trailing;
  final double? height;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final playing = model.auditioning == path;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Container(
        height: height ?? t.listRow,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.only(left: padding - 6, right: 4),
        decoration: BoxDecoration(
          color: current ? t.accentSoft : (h || cursor ? t.bg2 : Colors.transparent),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(children: [
          Expanded(child: SoundName(path, style: current ? t.bodyM : t.body)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(width: 4),
          if (t.touch && current) Icon(Icons.check, size: 16, color: t.accent),
          SizedBox(
            width: t.touch ? 48 : 22,
            child: playing
                ? Icon(Icons.volume_up_rounded, size: t.touch ? 18 : 14, color: t.accent)
                : (h || cursor || t.touch)
                    ? IconBtn(Icons.play_arrow_rounded, size: 22, tooltip: 'Audition', onTap: () => model.audition(path))
                    : current
                        ? Icon(Icons.check, size: 13, color: t.accent)
                        : null,
          ),
        ]),
      ),
    );
  }
}

/// The loudness of a render over time, as n values in 0..1. It follows the Sections and the beat,
/// so the picture reads as music and two renders of one Piece look alike but not identical.
List<double> waveEnv(int seed, int n) {
  final r = Random(seed);
  final tone = 0.85 + 0.15 * r.nextDouble();
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final bar = i / n * totalBars;
    var start = 0.0;
    var level = 0.5;
    for (final (name, bars, l) in sections) {
      if (bar < start + bars) {
        final p = (bar - start) / bars;
        level = switch (name) {
          'Intro' => l + 0.2 * p,
          'Build' => 0.5 + 0.45 * p,
          'Outro' => l * (1 - 0.75 * p),
          _ => l,
        };
        break;
      }
      start += bars;
    }
    final beat = (bar * 4) % 1.0;
    final kick = exp(-beat * 3.2);
    final downbeat = bar % 1.0 < 0.12 ? 0.12 : 0.0;
    out[i] = (level * tone * (0.5 + 0.62 * kick + downbeat) * (0.7 + 0.3 * r.nextDouble())).clamp(0.05, 1.0);
  }
  return out;
}

enum WaveAlign { center, up, down }

/// A render's waveform: thin rounded bars, the played part in [color], the rest in [rest].
class Wave extends StatelessWidget {
  const Wave({super.key, required this.seed, this.progress, this.color, this.rest, this.align = WaveAlign.center, this.bar = 2, this.gap = 1});
  final int seed;
  final double? progress; // null draws every bar in [color]
  final Color? color;
  final Color? rest;
  final WaveAlign align;
  final double bar;
  final double gap;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return CustomPaint(
      painter: _WavePainter(seed, progress, color ?? t.accent, rest ?? t.text3.withValues(alpha: 0.55), align, bar, gap),
      size: Size.infinite,
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.seed, this.progress, this.color, this.rest, this.align, this.bar, this.gap);
  final int seed;
  final double? progress;
  final Color color;
  final Color rest;
  final WaveAlign align;
  final double bar;
  final double gap;
  @override
  void paint(Canvas canvas, Size size) {
    final n = (size.width / (bar + gap)).floor();
    if (n <= 0) return;
    final env = waveEnv(seed, n);
    final on = Paint()..color = color;
    final off = Paint()..color = rest;
    final r = Radius.circular(bar / 2);
    for (var i = 0; i < n; i++) {
      final h = max(2.0, env[i] * size.height);
      final x = i * (bar + gap);
      final top = switch (align) {
        WaveAlign.center => (size.height - h) / 2,
        WaveAlign.up => size.height - h,
        WaveAlign.down => 0.0,
      };
      final played = progress == null || i / n <= progress!;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, top, bar, h), r), played ? on : off);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) =>
      o.seed != seed || o.progress != progress || o.color != color || o.rest != rest || o.align != align;
}

/// A level meter of small segments: voices sounding on a channel, or the Engine's total.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.segments = 8, this.max = 8, this.height = 10});
  final int value;
  final int segments;
  final int max;
  final double height;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final lit = (value / max * segments).ceil().clamp(0, segments);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < segments; i++)
        Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < lit ? (i >= segments - 2 ? t.warn : t.accent) : t.bg3,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ]);
  }
}

/// A small piano. A click plays the selected sound at that note.
class MiniKeys extends StatelessWidget {
  const MiniKeys({super.key, required this.onNote, this.octaves = 2, this.height = 56, this.lit});
  final void Function(int note) onNote;
  final int octaves;
  final double height;
  final int? lit;
  static const _black = {1: 0, 3: 1, 6: 3, 8: 4, 10: 5}; // semitone -> the white key it follows
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final whiteC = t.dark ? const Color(0xFFD6D8DD) : Colors.white;
    final blackC = t.dark ? const Color(0xFF0D0E10) : const Color(0xFF23262B);
    const whites = [0, 2, 4, 5, 7, 9, 11];
    return LayoutBuilder(builder: (context, box) {
      final octaves = t.touch ? (box.maxWidth / (7 * 48)).floor().clamp(1, 4) : this.octaves;
      final count = octaves * 7 + 1;
      final w = box.maxWidth / count;
      return Container(
        height: height,
        decoration: t.dark ? null : BoxDecoration(color: t.lineStrong, border: Border.all(color: t.lineStrong), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4))),
        child: Stack(children: [
          Row(children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Hover(
                  onTap: () => onNote(48 + (i ~/ 7) * 12 + whites[i % 7]),
                  builder: (_, h) {
                    final note = 48 + (i ~/ 7) * 12 + whites[i % 7];
                    return Container(
                      margin: EdgeInsets.only(right: i == count - 1 ? 0 : 1),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: lit == note ? t.accent : (h ? Color.lerp(whiteC, t.accent, 0.35) : whiteC),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                      child: i % 7 == 0
                          ? Text('C${3 + i ~/ 7}', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500, color: Colors.black.withValues(alpha: 0.45)))
                          : null,
                    );
                  },
                ),
              ),
          ]),
          for (var o = 0; o < octaves; o++)
            for (final e in _black.entries)
              Positioned(
                left: (o * 7 + e.value + 1) * w - w * 0.3,
                width: w * 0.6,
                top: 0,
                height: height * 0.6,
                child: Hover(
                  onTap: () => onNote(48 + o * 12 + e.key),
                  builder: (_, h) => Container(
                    decoration: BoxDecoration(
                      color: h ? Color.lerp(blackC, t.accent, 0.5) : blackC,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
        ]),
      );
    });
  }
}

// ---------------------------------------------------------------------------------------------
// App chrome

/// The Card folder: where the sounds come from. The prototype only pretends to open a folder dialog.
class CardPill extends StatelessWidget {
  const CardPill({super.key, required this.model, this.compact = false});
  final Model model;
  final bool compact; // the icon alone, for a narrow window
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Hover(
      tooltip: 'Card folder: 171 synths, 43 kits. Click to choose another',
      onTap: () => model.setCardFolder(model.cardFolder.endsWith('card') ? '~/Deluge/Backup 2026' : '~/Music/Deluge card'),
      builder: (_, h) => hit(t, Container(
        height: t.ctl,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: h ? t.bg2 : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sd_card_outlined, size: t.touch ? 18 : 14, color: t.text3),
          if (!compact) ...[const SizedBox(width: 6), Text(model.cardFolder, maxLines: 1, style: t.small)],
        ]),
      )),
    );
  }
}

/// Engine state and voice count. Click it to see the restart (the prototype's freeze simulator).
class EnginePill extends StatelessWidget {
  const EnginePill({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final running = model.engine == EngineState.running;
    final c = running ? t.ok : t.warn;
    return Hover(
      tooltip: running ? 'Engine running. Click to simulate a freeze (prototype)' : 'The Engine froze and is restarting',
      onTap: running ? model.simulateFreeze : null,
      builder: (_, h) => hit(t, Container(
        height: t.ctl,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: running ? (h ? t.bg2 : Colors.transparent) : t.warn.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(running ? 'Engine' : 'Engine restarting…', style: t.small.copyWith(color: running ? t.text2 : t.warn)),
          if (running) ...[
            const SizedBox(width: 8),
            Meter(value: model.totalVoices, max: 16, segments: 8, height: 9),
            const SizedBox(width: 4),
            SizedBox(
              width: t.touch ? 60 : 52,
              child: Text('${model.totalVoices} voices', textAlign: TextAlign.right, softWrap: false, style: t.numSmall.copyWith(color: t.text3, fontSize: t.touch ? 12.5 : 11.5)),
            ),
          ],
        ]),
      )),
    );
  }
}

/// The top bar every variant uses: the app's name, [left] (usually the mode switch), then the
/// Card folder and the Engine on the right. The middle stays free for the prototype switcher.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.model, this.left = const [], this.right = const []});
  final Model model;
  final List<Widget> left;
  final List<Widget> right;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Container(
      height: t.top,
      decoration: BoxDecoration(color: t.bg1, border: Border(bottom: BorderSide(color: t.line))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(5)),
          child: Icon(Icons.graphic_eq_rounded, size: 13, color: t.onAccent),
        ),
        const SizedBox(width: 8),
        if (!narrow) Text('Deluge Engine', style: t.bodyM.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        ...left,
        const Spacer(),
        ...right,
        CardPill(model: model, compact: narrow),
        const SizedBox(width: 4),
        EnginePill(model: model),
      ]),
    );
  }
}

/// The Piece/Setup switch.
class ModeSeg extends StatelessWidget {
  const ModeSeg({super.key, required this.model, this.pieceName = 'Piece'});
  final Model model;
  final String pieceName;
  @override
  Widget build(BuildContext context) =>
      Seg<Mode>(items: {Mode.piece: pieceName, Mode.setup: 'Setup'}, value: model.mode, onChanged: model.setMode);
}

/// The bottom line: what just happened on the left, the last error on the right.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.model, this.hints = const []});
  final Model model;
  final List<(String, String)> hints; // (key, what it does)
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final restarting = model.engine == EngineState.restarting;
    return Container(
      height: t.touch ? 28 : 26,
      decoration: BoxDecoration(color: t.bg1, border: Border(top: BorderSide(color: t.line))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (restarting) ...[
          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: t.warn)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(model.status, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cap.copyWith(color: restarting ? t.warn : t.text2)),
        ),
        if (model.lastError != null) ...[
          Icon(Icons.error_outline, size: 12, color: t.err),
          const SizedBox(width: 4),
          Text('Last error: ${model.lastError}', style: t.cap.copyWith(color: t.err)),
          const SizedBox(width: 16),
        ],
        if (!t.touch)
          for (final (k, what) in hints) ...[
          Kbd(k),
          const SizedBox(width: 5),
          Text(what, style: t.cap),
          const SizedBox(width: 14),
        ],
      ]),
    );
  }
}

/// The Sections of a render along a time axis: names over a tick per bar.
class SectionRuler extends StatelessWidget {
  const SectionRuler({super.key, this.height = 18, this.bars = true});
  final double height;
  final bool bars;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _RulerPainter(t, bars), size: Size.infinite),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.t, this.bars);
  final Tk t;
  final bool bars;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = t.lineStrong;
    var start = 0;
    for (final (name, n, _) in sections) {
      final x = start / totalBars * size.width;
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), line);
      final tp = TextPainter(
        text: TextSpan(
          text: name.toUpperCase(),
          style: TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: t.text3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 6, (size.height - tp.height) / 2));
      if (bars) {
        final tp2 = TextPainter(
          text: TextSpan(
            text: '${start + 1}',
            style: TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w500, color: t.text3.withValues(alpha: 0.6), fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final w = n / totalBars * size.width;
        if (tp.width + tp2.width + 20 < w) tp2.paint(canvas, Offset(x + 6 + tp.width + 6, (size.height - tp2.height) / 2));
      }
      start += n;
    }
  }

  @override
  bool shouldRepaint(_RulerPainter o) => o.t != t;
}

String clock(double position, int seconds) {
  final s = (position * seconds).floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// What the Engine restart looks like over a screen: a thin banner, the content dimmed.
class RestartVeil extends StatelessWidget {
  const RestartVeil({super.key, required this.model, required this.child});
  final Model model;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    if (model.engine == EngineState.running) return child;
    return Stack(children: [
      Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.45, child: child))),
      Positioned(
        top: 12,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.warn.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: t.warn)),
              const SizedBox(width: 10),
              Text('The Engine froze (E380). Restarting and reloading your Setup…', style: t.bodyM),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------
// Piece controls the variants share

class GenreMenu extends StatelessWidget {
  const GenreMenu({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) =>
      Menu<String>(value: model.genre, items: {for (final g in genres.keys) g: g}, onChanged: model.setGenre, label: 'Genre');
}

/// The musical facts the Seed rolled: tempo and key.
class Facts extends StatelessWidget {
  const Facts({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Text('${model.tempo} BPM  ·  ${model.keyName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.numSmall.copyWith(color: t.text3));
  }
}

/// The primary action: render the working Piece to a WAV.
class RenderBtn extends StatelessWidget {
  const RenderBtn({super.key, required this.model, this.text});
  final Model model;
  final String? text;
  @override
  Widget build(BuildContext context) => Btn(
        model.rendering ? 'Rendering…' : (text ?? 'Render ${model.lengthSeconds} s'),
        icon: Icons.graphic_eq_rounded,
        kind: BtnKind.primary,
        kbd: '⌘R',
        tooltip: 'Render the Piece to a WAV, about 2 s for 60 s of audio',
        onTap: model.rendering || model.engine != EngineState.running ? null : model.render,
      );
}

/// Plays the Generator live instead of a render.
class LiveBtn extends StatelessWidget {
  const LiveBtn({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => Btn(
        model.live ? 'Stop live' : 'Play live',
        icon: model.live ? Icons.stop_rounded : Icons.sensors_rounded,
        kbd: 'L',
        tooltip: 'The Generator plays the Piece live, so a new Sound pick is heard at once',
        onTap: model.engine == EngineState.running ? model.toggleLive : null,
      );
}

/// A dot and a few words when the picks have changed since the newest render.
class DirtyNote extends StatelessWidget {
  const DirtyNote({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    if (!model.dirty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Flexible(child: Text('Changed since the last render', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small.copyWith(color: t.text2))),
    ]);
  }
}

/// The MIDI input the Setup listens to.
class MidiPill extends StatelessWidget {
  const MidiPill({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => Menu<String>(
        value: model.midiIn,
        items: const {'KeyStep 37': 'KeyStep 37', 'Launchkey Mini': 'Launchkey Mini', 'IAC Bus 1': 'IAC Bus 1'},
        onChanged: (v) {
          model.midiIn = v;
          model.setMode(model.mode);
        },
        label: 'MIDI in',
        icon: Icons.settings_input_svideo_rounded,
      );
}

/// How a pick relates to its slot's Palette: its share of re-rolls, or "off palette".
class PaletteMark extends StatelessWidget {
  const PaletteMark({super.key, required this.slot, required this.sound, this.on = false, this.bar = true});
  final Slot slot;
  final String? sound;
  final bool on;
  final bool bar;
  @override
  Widget build(BuildContext context) {
    final e = slot.entry(sound);
    if (e == null) return const Tag('off palette');
    return WeightBar(weight: e.weight, total: slot.total, on: on, width: bar ? 40 : 0);
  }
}

/// A square A or B badge.
class ABBadge extends StatelessWidget {
  const ABBadge(this.letter, {super.key, this.on = false, this.size = 22});
  final String letter;
  final bool on;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? t.accent : t.bg3,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(letter, style: TextStyle(fontSize: size * 0.55, height: 1.1, fontWeight: FontWeight.w600, color: on ? t.onAccent : t.text2)),
    );
  }
}

/// A filterable list of every Synth or Kit preset on the card.
List<String> presetPaths({required bool kits, String query = '', String? tag}) {
  final q = query.trim().toLowerCase();
  return [
    for (final n in kits ? kitNames : synthNames)
      if ((q.isEmpty || n.toLowerCase().contains(q)) && (tag == null || kits || n.contains(tag))) kits ? kit(n) : synth(n),
  ];
}
