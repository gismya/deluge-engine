// PROTOTYPE — throwaway. Screen prototype for the deluge-engine GUI, round 2: three structurally
// different takes on the Setup and Piece screens, switched with the floating pill in the top bar
// (or F1, F2, F3). Start on one with --dart-define=VARIANT=D (or ?variant=D on the web).
// Fake data, no Engine.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'ui.dart';
import 'variant_b2.dart';
import 'variant_d.dart';
import 'variant_e.dart';

void main() => runApp(const PrototypeApp());

const variants = ['B2', 'D', 'E'];
const _names = {'B2': VariantB2.name, 'D': VariantD.name, 'E': VariantE.name};

class PrototypeApp extends StatefulWidget {
  const PrototypeApp({super.key, this.initialVariant, this.dark = true, this.touch, this.showSwitcher = true});
  final bool? touch; // null: touch on Android and iOS, or with --dart-define=TOUCH=true
  final String? initialVariant;
  final bool dark;
  final bool showSwitcher; // the screenshot test hides it
  @override
  State<PrototypeApp> createState() => PrototypeAppState();
}

class PrototypeAppState extends State<PrototypeApp> {
  final model = Model();
  late String variant = () {
    final fromUrl = Uri.base.queryParameters['variant'];
    const fromDefine = String.fromEnvironment('VARIANT');
    final v = (widget.initialVariant ?? fromUrl ?? (fromDefine.isEmpty ? 'B2' : fromDefine)).toUpperCase();
    return variants.contains(v) ? v : 'B2';
  }();
  late bool dark = widget.dark;
  late bool touch = widget.touch ??
      (const bool.fromEnvironment('TOUCH') || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  bool showState = false;

  void _cycle(int d) => setState(() => variant = variants[(variants.indexOf(variant) + d + variants.length) % variants.length]);

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final i = [LogicalKeyboardKey.f1, LogicalKeyboardKey.f2, LogicalKeyboardKey.f3].indexOf(e.logicalKey);
    if (i < 0) return false;
    setState(() => variant = variants[i]);
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Deluge Engine (prototype)',
        theme: buildTheme(dark, touch: touch),
        home: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Stack(children: [
            Positioned.fill(
              child: switch (variant) {
                'D' => VariantD(model: model),
                'E' => VariantE(model: model),
                _ => VariantB2(model: model),
              },
            ),
            if (showState)
              Positioned(
                right: 12,
                top: 52,
                bottom: 40,
                width: 340,
                child: Builder(builder: (context) {
                  final t = Tk.of(context);
                  return Material(
                    color: t.bg2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: t.lineStrong)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(model.toJson(), style: TextStyle(fontFamily: 'Menlo', fontSize: 11, color: t.text2)),
                    ),
                  );
                }),
              ),
            if (widget.showSwitcher) Positioned(left: 0, right: 0, top: 8, child: Center(child: Builder(builder: _switcher))),
          ]),
        ),
      );

  /// The prototype's own control. It floats in the free middle of the top bar.
  Widget _switcher(BuildContext context) {
    final t = Tk.of(context);
    return Material(
      color: t.dark ? const Color(0xFF2A2D33) : const Color(0xFF15171C),
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 8),
          const Text('PROTOTYPE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFF9A9FA8))),
          const SizedBox(width: 8),
          for (final v in variants)
            Tooltip(
              message: '${_names[v]}  (F${variants.indexOf(v) + 1})',
              child: GestureDetector(
                onTap: () => setState(() => variant = v),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 22,
                    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: v == variant ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                    child: Text(
                      v == variant ? '$v  ${_names[v]}' : v,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: v == variant ? Colors.black : Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          _mini(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, 'Light or dark', () => setState(() => dark = !dark)),
          _mini(touch ? Icons.mouse_outlined : Icons.touch_app_outlined, 'Mouse or touch sizes', () => setState(() => touch = !touch)),
          _mini(Icons.data_object, 'Show the state', () => setState(() => showState = !showState)),
          _mini(Icons.chevron_right, 'Next variant', () => _cycle(1)),
        ]),
      ),
    );
  }

  Widget _mini(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 15, color: Colors.white70)),
          ),
        ),
      );
}
