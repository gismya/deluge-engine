import 'package:deluge_engine_gui/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Strips directory prefix and `.XML`/`.wav` suffix from a card sound path.
String shortSoundName(String path) =>
    path.split('/').last.replaceAll(RegExp(r'\.(XML|xml|wav|WAV)$'), '');

/// Splits a preset path into its optional 3-digit number and display title.
(String?, String) splitSoundName(String path) {
  final name = shortSoundName(path);
  final upper = path.toUpperCase();
  final isPreset = (upper.startsWith('SYNTHS/') || upper.startsWith('KITS/')) &&
      RegExp(r'^\d{3} ').hasMatch(name);
  return isPreset ? (name.substring(0, 3), name.substring(4)) : (null, name);
}

IconData soundIcon(String? path) {
  if (path == null) return Icons.add;
  final upper = path.toUpperCase();
  if (upper.startsWith('KITS/')) return Icons.grid_view_rounded;
  if (upper.startsWith('SAMPLES/') || upper.endsWith('.WAV')) {
    return Icons.graphic_eq;
  }
  return Icons.piano;
}

String soundKind(String? path) {
  if (path == null) return 'Empty';
  final upper = path.toUpperCase();
  if (upper.startsWith('KITS/')) return 'Kit';
  if (upper.startsWith('SAMPLES/') || upper.endsWith('.WAV')) return 'Sample';
  return 'Synth';
}

/// Renders a preset's 3-digit number in muted tabular figures followed by its title.
class SoundName extends StatelessWidget {
  const SoundName(
    this.path, {
    super.key,
    this.style,
    this.muted = false,
    this.showNumber = true,
  });

  final String path;
  final TextStyle? style;
  final bool muted;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final (number, title) = splitSoundName(path);
    final base = (style ?? t.body).copyWith(color: muted ? t.text2 : null);
    return Text.rich(
      TextSpan(
        children: [
          if (number != null && showNumber)
            TextSpan(
              text: '$number  ',
              style: base.copyWith(
                color: t.text3,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w400,
              ),
            ),
          TextSpan(text: title),
        ],
      ),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Palette roll-share bar and percentage in tabular figures.
class WeightBar extends StatelessWidget {
  const WeightBar({
    super.key,
    required this.weight,
    required this.total,
    this.on = false,
    this.width = 40,
  });

  final int weight;
  final int total;
  final bool on;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final ratio = total > 0 ? (weight / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (width > 0) ...[
          SizedBox(
            width: width,
            height: 4,
            child: CustomPaint(
              painter: _BarPainter(ratio, on ? t.accent : t.text3, t.lineStrong),
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 36,
          child: Text(
            '${(100 * ratio).round()}%',
            textAlign: TextAlign.right,
            softWrap: false,
            style: t.numSmall.copyWith(color: on ? t.text : t.text3),
          ),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.fg, this.bg);
  final double value;
  final Color fg;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * value, size.height),
        r,
      ),
      Paint()..color = fg,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.fg != fg || old.bg != bg;
}

/// Segmented level/voice meter (8 segments by default; top 2 warn).
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.value,
    this.segments = 8,
    this.max = 16,
    this.height = 10,
  });

  final int value;
  final int segments;
  final int max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final lit = max > 0 ? (value / max * segments).ceil().clamp(0, segments) : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }
}

/// Square A or B render badge.
class AbBadge extends StatelessWidget {
  const AbBadge(this.letter, {super.key, this.on = false, this.size = 22});
  final String letter;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? t.accent : t.bg3,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * 0.55,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: on ? t.onAccent : t.text2,
        ),
      ),
    );
  }
}

/// Formats seconds as `m:ss`.
String formatClock(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}
