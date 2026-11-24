// PROTOTYPE — throwaway. Widgets the variants share: preset browser, waveform, engine status, state drawer.

import 'dart:math';

import 'package:flutter/material.dart';

import 'data.dart';

/// A searchable list of Synth and Kit presets. Tap to choose, the speaker button auditions.
class PresetBrowser extends StatefulWidget {
  const PresetBrowser({super.key, required this.model, required this.onChoose, this.dense = false, this.only});
  final Model model;
  final void Function(String sound) onChoose;
  final bool dense;
  final String? only; // 'SYNTHS' or 'KITS' to lock the folder
  @override
  State<PresetBrowser> createState() => _PresetBrowserState();
}

class _PresetBrowserState extends State<PresetBrowser> {
  String folder = 'SYNTHS';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final f = widget.only ?? folder;
    final names = f == 'SYNTHS' ? synthNames : kitNames;
    final shown = names.where((n) => n.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.only == null)
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'SYNTHS', label: Text('Synths')), ButtonSegment(value: 'KITS', label: Text('Kits'))],
              selected: {folder},
              onSelectionChanged: (s) => setState(() => folder = s.first),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search), hintText: 'Search presets'),
              onChanged: (q) => setState(() => query = q),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final path = f == 'SYNTHS' ? synth(shown[i]) : kit(shown[i]);
            return ListTile(
              dense: true,
              visualDensity: widget.dense ? VisualDensity.compact : null,
              title: Text(shown[i]),
              onTap: () => widget.onChoose(path),
              trailing: IconButton(
                tooltip: 'Audition',
                icon: Icon(widget.model.auditioning == path ? Icons.volume_up : Icons.volume_up_outlined),
                onPressed: () => widget.model.audition(path),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

Future<String?> pickPreset(BuildContext context, Model model, {String? only}) => showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 480,
          height: 560,
          child: PresetBrowser(model: model, only: only, onChoose: (p) => Navigator.pop(ctx, p)),
        ),
      ),
    );

/// A fake waveform, stable per render.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.seed, this.height = 48, this.color});
  final int seed;
  final double height;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(painter: _WavePainter(seed, color ?? Theme.of(context).colorScheme.primary), size: Size.infinite),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.seed, this.color);
  final int seed;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final p = Paint()..color = color;
    const bars = 160;
    final w = size.width / bars;
    for (var i = 0; i < bars; i++) {
      final beat = (i % 8 == 0) ? 1.0 : 0.45 + 0.35 * sin(i / 9);
      final h = size.height * (0.15 + 0.85 * beat * (0.6 + 0.4 * r.nextDouble()));
      canvas.drawRect(Rect.fromLTWH(i * w, (size.height - h) / 2, max(1, w - 1), h), p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.seed != seed || old.color != color;
}

/// Engine state, voice count and the freeze simulator.
class EngineStatus extends StatelessWidget {
  const EngineStatus({super.key, required this.model, this.compact = false});
  final Model model;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final running = model.engine == EngineState.running;
    final chip = Chip(
      avatar: Icon(running ? Icons.circle : Icons.sync, size: 14, color: running ? Colors.green : Colors.orange),
      label: Text(running ? 'Engine running · ${model.totalVoices} voices' : 'Engine restarting…'),
    );
    if (compact) return chip;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip,
      const SizedBox(width: 8),
      TextButton(onPressed: running ? model.simulateFreeze : null, child: const Text('Simulate freeze')),
    ]);
  }
}

/// The status line: last message and last error.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(model.status, overflow: TextOverflow.ellipsis)),
        if (model.lastError != null)
          Text(model.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]);
}

/// Card folder chooser. The prototype only pretends to open a folder dialog.
class CardFolderButton extends StatelessWidget {
  const CardFolderButton({super.key, required this.model});
  final Model model;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.sd_card_outlined),
        label: Text(model.cardFolder),
        onPressed: () => model.setCardFolder(model.cardFolder.endsWith('card') ? '~/Deluge/Backup 2026' : '~/Music/Deluge card'),
      );
}

/// A row of "pick from palette" chips for one Part or lane, weights shown.
class PaletteChips extends StatelessWidget {
  const PaletteChips({super.key, required this.model, required this.slot});
  final Model model;
  final Slot slot;
  @override
  Widget build(BuildContext context) {
    final current = model.picks[slot.key];
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final e in slot.palette)
        ChoiceChip(
          label: Text('${shortName(e.sound)}  ×${e.weight}'),
          selected: current == e.sound,
          onSelected: (_) => model.setPick(slot.key, e.sound),
        ),
    ]);
  }
}
