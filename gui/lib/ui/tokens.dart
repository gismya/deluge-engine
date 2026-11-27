import 'package:material_ui/material_ui.dart';

/// Round-3 dark-only design tokens for Deluge Engine (spec §8).
///
/// Rules:
/// - Dark mode only, finger-sized targets (44 dp controls inside 48 dp hit
///   areas) on every platform including macOS.
/// - One accent colour; surfaces step by grey + 1 px hairline border, never
///   heavy drop shadows.
/// - Numbers in tabular figures.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
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
  });

  final Color bg0; // window background
  final Color bg1; // panels, bars
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

  static const AppTokens night = AppTokens(
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

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  // Layout sizes (spec §8).
  double get top => 56; // top bar
  double get bar => 72; // secondary toolbar
  double get row => 48; // list / table row
  double get ctl => 44; // drawn control height inside a 48 dp hit area
  double get hit => 48; // minimum touch target

  Color get accentSoft => accent.withValues(alpha: 0.14);
  Color get accentLine => accent.withValues(alpha: 0.55);

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  TextStyle get body => TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: text,
      );

  TextStyle get bodyM => body.copyWith(fontWeight: FontWeight.w500);

  TextStyle get small => TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        height: 17 / 13,
        fontWeight: FontWeight.w400,
        color: text2,
      );

  TextStyle get cap => TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: text3,
      );

  TextStyle get label => TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: text3,
      );

  TextStyle get title => TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: text,
      );

  TextStyle get display => TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: text,
      );

  TextStyle get num => body.copyWith(fontFeatures: _tabular);
  TextStyle get numSmall => small.copyWith(fontFeatures: _tabular);

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) => this;
}

/// Builds the single dark theme with pinned touch-friendly density (spec §8).
ThemeData buildAppTheme() {
  const t = AppTokens.night;
  final scheme =
      ColorScheme.fromSeed(seedColor: t.accent, brightness: Brightness.dark)
          .copyWith(
    primary: t.accent,
    onPrimary: t.onAccent,
    surface: t.bg1,
    onSurface: t.text,
    outline: t.lineStrong,
    outlineVariant: t.line,
    error: t.err,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: t.bg0,
    canvasColor: t.bg1,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: t.bg2,
    dividerColor: t.line,
    extensions: const [t],
    textTheme: Typography.englishLike2021.apply(
      fontFamily: 'Inter',
      bodyColor: t.text,
      displayColor: t.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accent,
      selectionColor: t.accent.withValues(alpha: 0.3),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(fontSize: 13, color: t.text, fontFamily: 'Inter'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.bg2,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.lineStrong),
      ),
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
