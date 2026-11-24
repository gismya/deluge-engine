// PROTOTYPE — throwaway. Screen prototype for the deluge-engine GUI: three structurally different
// variants of the Setup and Piece screens, switched with the floating bar at the bottom (or ← →).
// Start with ?variant=B on the web, or --dart-define=VARIANT=B on desktop. Fake data, no Engine.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'variant_a.dart';
import 'variant_b.dart';
import 'variant_c.dart';

void main() => runApp(const PrototypeApp());

const _variants = ['A', 'B', 'C'];
const _names = {'A': VariantA.name, 'B': VariantB.name, 'C': VariantC.name};

class PrototypeApp extends StatefulWidget {
  const PrototypeApp({super.key, this.initialVariant});
  final String? initialVariant;
  @override
  State<PrototypeApp> createState() => _PrototypeAppState();
}

class _PrototypeAppState extends State<PrototypeApp> {
  // Public for the screenshot test.
  final model = Model();
  late String variant = () {
    final fromUrl = Uri.base.queryParameters['variant'];
    const fromDefine = String.fromEnvironment('VARIANT');
    final v = (widget.initialVariant ?? fromUrl ?? (fromDefine.isEmpty ? 'A' : fromDefine)).toUpperCase();
    return _variants.contains(v) ? v : 'A';
  }();
  bool dark = true;
  bool showState = false;

  void _cycle(int d) => setState(() => variant = _variants[(_variants.indexOf(variant) + d + _variants.length) % _variants.length]);

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    // Leave arrow keys alone while a text field has focus.
    final focus = FocusManager.instance.primaryFocus?.context?.widget;
    if (focus is EditableText) return false;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cycle(-1);
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _cycle(1);
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
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Deluge Engine (prototype)',
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, brightness: dark ? Brightness.dark : Brightness.light, fontFamily: 'Roboto'),
        home: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Stack(children: [
            Positioned.fill(
              child: switch (variant) {
                'B' => VariantB(model: model),
                'C' => VariantC(model: model),
                _ => VariantA(model: model),
              },
            ),
            if (showState)
              Positioned(
                right: 12,
                top: 60,
                bottom: 64,
                width: 340,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(model.toJson(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 12, child: Center(child: _switcher(context))),
          ]),
        ),
      );

  Widget _switcher(BuildContext context) => Material(
        color: Colors.black,
        elevation: 10,
        shape: const StadiumBorder(),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _cycle(-1)),
              Text('PROTOTYPE  $variant (${_names[variant]})'),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _cycle(1)),
              const SizedBox(width: 8),
              IconButton(tooltip: 'Light/dark', icon: Icon(dark ? Icons.light_mode : Icons.dark_mode), onPressed: () => setState(() => dark = !dark)),
              IconButton(tooltip: 'Show state', icon: const Icon(Icons.data_object), onPressed: () => setState(() => showState = !showState)),
            ]),
          ),
        ),
      );
}
