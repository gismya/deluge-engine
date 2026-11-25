// PROTOTYPE — throwaway. The window: top bar, the Piece or the Setup screen, status line.
//
// The Piece screen is one bar and two tabs. The bar holds the tab control (Compare | Timeline)
// and what belongs to the Piece whichever tab shows: Genre, Seed, auto-render, live, render. The
// tabs are two views of the same Piece and keep nothing of their own: the selected row, A/B, the
// playhead and the picker's state all live in the Model, so switching tabs changes the picture only.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'compare.dart';
import 'data.dart';
import 'picker.dart';
import 'setup.dart';
import 'timeline.dart';
import 'ui.dart';

class Shell extends StatelessWidget {
  const Shell({super.key, required this.model, this.trailing = const []});
  final Model model;
  final List<Widget> trailing; // the prototype's own controls, at the end of the top bar

  void _move(int d) {
    final keys = [for (final s in model.slots) s.key];
    final i = keys.indexOf(model.selectedSlot ?? '');
    model.selectSlot(keys[(i + d).clamp(0, keys.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final piece = model.mode == Mode.piece;
    // Extras for a keyboard. Everything they do has a button.
    return Keys(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): model.togglePlay,
        const SingleActivator(LogicalKeyboardKey.tab): model.toggleAB,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): model.render,
        const SingleActivator(LogicalKeyboardKey.keyN): model.rollSeed,
        const SingleActivator(LogicalKeyboardKey.keyL): model.toggleLive,
        if (piece) ...{
          const SingleActivator(LogicalKeyboardKey.keyT): () => model.setTab(model.tab == PieceTab.compare ? PieceTab.timeline : PieceTab.compare),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.enter): () => model.setPicker(true),
          const SingleActivator(LogicalKeyboardKey.escape): () => model.setPicker(false),
          const SingleActivator(LogicalKeyboardKey.keyR): () {
            final s = model.selected;
            if (s != null) pick(model, s, null);
          },
        },
      },
      child: Material(
        color: t.bg0,
        child: Column(children: [
          TopBar(model: model, left: [ModeSeg(model: model)], right: trailing),
          Expanded(child: RestartVeil(model: model, child: piece ? _Piece(model: model) : _Setup(model: model))),
          StatusBar(model: model),
        ]),
      ),
    );
  }
}

const _pickerW = 360.0;

/// Puts the picker beside [main] in a wide window and under it in a narrow one.
Widget _withPicker({required bool narrow, required Widget main, required Widget picker, int mainFlex = 1, int pickerFlex = 1, bool open = true}) => narrow
    ? Column(children: [
        Expanded(flex: mainFlex, child: main),
        const Hr(),
        open ? Expanded(flex: pickerFlex, child: picker) : picker,
      ])
    : Row(children: [
        Expanded(child: main),
        const Vr(),
        open ? SizedBox(width: _pickerW, child: picker) : picker,
      ]);

class _Piece extends StatelessWidget {
  const _Piece({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 900;
        final open = model.pickerOpen;
        return Column(children: [
          _PieceBar(model: model, width: box.maxWidth),
          const Hr(),
          Expanded(
            child: _withPicker(
              narrow: narrow,
              open: open,
              mainFlex: 5,
              pickerFlex: 4,
              main: model.tab == PieceTab.compare ? CompareTab(model: model) : TimelineTab(model: model),
              picker: open ? Picker(model: model, narrow: narrow) : PickerClosed(model: model, narrow: narrow),
            ),
          ),
        ]);
      });
}

class _Setup extends StatelessWidget {
  const _Setup({required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 900;
        return _withPicker(narrow: narrow, mainFlex: 3, pickerFlex: 2, main: SetupPads(model: model), picker: Picker(model: model, narrow: narrow));
      });
}

/// The Piece's bar: the tab control first, then the controls both tabs share. In a narrow window
/// the tabs get a row of their own, across the whole width.
class _PieceBar extends StatelessWidget {
  const _PieceBar({required this.model, required this.width});
  final Model model;
  final double width;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    final narrow = width < 900;
    final controls = [
      GenreMenu(model: model),
      const SizedBox(width: 8),
      SeedField(model: model),
      if (width >= 1360) ...[const SizedBox(width: 16), Facts(model: model)],
      const Spacer(),
      Hover(
        tooltip: 'Render B again after every change to a Sound pick',
        onTap: () => model.setAutoRender(!model.autoRender),
        builder: (_, h) => hitBox(Row(mainAxisSize: MainAxisSize.min, children: [
          _Switch(on: model.autoRender),
          const SizedBox(width: 10),
          Text(width >= 1200 ? 'Auto-render' : 'Auto', style: t.bodyM.copyWith(color: h ? t.text : t.text2)),
        ])),
      ),
      const SizedBox(width: 16),
      LiveBtn(model: model),
      const SizedBox(width: 8),
      RenderBtn(model: model, text: 'Render B'),
    ];
    if (narrow) {
      return Container(
        color: t.bg1,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(children: [
          PieceTabs(model: model, expand: true),
          SizedBox(height: 64, child: Row(children: controls)),
        ]),
      );
    }
    return Container(
      height: t.bar,
      color: t.bg1,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [PieceTabs(model: model), const SizedBox(width: 16), ...controls]),
    );
  }
}

/// The tab control: Compare | Timeline. Big, labelled, and the first thing in the Piece's bar.
class PieceTabs extends StatelessWidget {
  const PieceTabs({super.key, required this.model, this.expand = false});
  final Model model;
  final bool expand;
  static const _items = [
    (PieceTab.compare, 'Compare', Icons.compare_arrows_rounded, 'A against B: waveforms and the Sound picks that differ'),
    (PieceTab.timeline, 'Timeline', Icons.view_timeline_outlined, 'What each Part plays across the Sections'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.bg0, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.lineStrong)),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (tab, name, icon, tip) in _items)
          () {
            final on = model.tab == tab;
            final cell = Hover(
              onTap: () => model.setTab(tab),
              tooltip: '$tip  (T)',
              builder: (_, h) => Container(
                constraints: const BoxConstraints(minWidth: 148),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: on ? t.accentSoft : (h ? t.bg2 : Colors.transparent),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: on ? t.accentLine : Colors.transparent),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 22, color: on ? t.accent : t.text3),
                  const SizedBox(width: 10),
                  Text(name, style: t.title.copyWith(color: on ? t.text : t.text2)),
                ]),
              ),
            );
            return expand ? Expanded(child: cell) : cell;
          }(),
      ]),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final t = Tk.of(context);
    return Container(
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? t.accent : t.bg3, borderRadius: BorderRadius.circular(13)),
      child: Container(width: 20, height: 20, decoration: BoxDecoration(color: on ? t.onAccent : t.text2, shape: BoxShape.circle)),
    );
  }
}
