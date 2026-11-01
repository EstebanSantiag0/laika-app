// VARIANTE 4 — BRUTAL
// Neobrutalismo: bordes negros gruesos, sombras duras, colores planos y
// letras enormes. Laika es geométrica y rebota; el cerebro es un grafo de
// fuerzas donde puedes arrastrar cada nodo.

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/brain.dart';
import '../core/layouts.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/session.dart';
import '../core/stage.dart';
import '../core/widgets.dart';

const _bg = Color(0xFFFFFDF5);
const _k = Colors.black;
const _yellow = Color(0xFFFFE14D);
const _pink = Color(0xFFFF7AC6);
const _blue = Color(0xFF5B8CFF);
const _green = Color(0xFF3DDC97);
const _font = 'Adwaita Sans';

TextStyle _b(double size, {FontWeight w = FontWeight.w800, Color color = _k}) =>
    TextStyle(fontFamily: _font, fontFamilyFallback: const ['Liberation Sans'], fontSize: size, fontWeight: w, color: color, height: 1.2);

BoxDecoration _box(Color color, {double shadow = 5, double border = 3}) => BoxDecoration(
      color: color,
      border: Border.all(color: _k, width: border),
      boxShadow: shadow > 0 ? [BoxShadow(color: _k, offset: Offset(shadow, shadow))] : null,
    );

final brutalSpec = VariantSpec(
  id: 'brutal',
  name: 'Brutal',
  tagline: 'Neobrutalismo: bordes negros, sombras duras, colores planos y un grafo que arrastras.',
  swatch: const [_yellow, _pink, _blue, _k],
  build: (s) => _BrutalApp(session: s),
);

class _BrutalApp extends StatefulWidget {
  const _BrutalApp({required this.session});
  final LaikaSession session;
  @override
  State<_BrutalApp> createState() => _BrutalAppState();
}

class _BrutalAppState extends State<_BrutalApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _bg,
        fontFamily: _font,
        colorScheme: ColorScheme.fromSeed(seedColor: _yellow, surface: _bg),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: _k, selectionColor: _yellow),
      ),
      home: Scaffold(
        body: Column(children: [
          Expanded(
            child: IndexedStack(index: tab, children: [
              PetStage(controller: s.pet, skin: const _BrutalSkin()),
              _BrutalBrain(brain: s.brain),
              _BrutalAgenda(rem: s.reminders),
            ]),
          ),
          Container(
            decoration: const BoxDecoration(color: _bg, border: Border(top: BorderSide(color: _k, width: 3))),
            padding: const EdgeInsets.fromLTRB(120, 12, 16, 16),
            child: Row(children: [
              for (final (i, label, color) in [(0, 'ESCRITORIO', _yellow), (1, 'CEREBRO', _pink), (2, 'AGENDA', _green)])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        transform: Matrix4.translationValues(i == tab ? 4 : 0, i == tab ? 4 : 0, 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: _box(i == tab ? color : Colors.white, shadow: i == tab ? 1 : 5),
                        child: Center(child: Text(label, style: _b(18, w: FontWeight.w900))),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Escritorio ──────────────────────────────────────────────────────────────

class _BrutalSkin extends PetSkin {
  const _BrutalSkin();

  @override
  double get petSize => 150;

  @override
  double get chatWidth => 320;

  @override
  Widget backdrop(BuildContext context) => const CustomPaint(painter: _Backdrop());

  @override
  Widget pet(BuildContext context, PetController c, double t) =>
      CustomPaint(painter: _BlockDog(state: c.state, t: t, bell: c.pendingReminders.isNotEmpty));

  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _box(age == 0 ? _yellow : Colors.white, shadow: age == 0 ? 6 : 3),
        child: Text(text, style: _b(16, w: FontWeight.w700)),
      );

  @override
  Widget typing(BuildContext context, double t, {required bool petOnRight}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(right: 6),
              width: 14,
              height: 14,
              transform: Matrix4.translationValues(0, -6 * max(0, sin(t * 7 - i)), 0),
              decoration: _box([_pink, _blue, _green][i], shadow: 2, border: 2),
            ),
        ],
      );

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: _k,
        child: Text('TÚ: $text', maxLines: 2, overflow: TextOverflow.ellipsis, style: _b(12, color: Colors.white)),
      );

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Container(
        decoration: _box(Colors.white),
        child: Row(children: [
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onSubmitted: (_) => onSend(),
              style: _b(16, w: FontWeight.w700),
              decoration: InputDecoration(border: InputBorder.none, hintText: 'DILE ALGO', hintStyle: _b(16, color: Colors.black26)),
            ),
          ),
          GestureDetector(
            onTap: onSend,
            child: Container(
              color: _k,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Text('→', style: _b(18, color: _yellow, w: FontWeight.w900)),
            ),
          ),
        ]),
      );

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final s = statusText(c) ?? (c.state == PetState.asleep ? 'ZZZ' : null);
    if (s == null) return null;
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: _box(c.wakeFailed ? const Color(0xFFFF5A5A) : _pink, shadow: 3, border: 2),
        child: Text(s.toUpperCase(), style: _b(12, w: FontWeight.w900)),
      ),
    );
  }
}

class _Backdrop extends CustomPainter {
  const _Backdrop();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    final grid = Paint()..color = Colors.black.withValues(alpha: 0.06)..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: 'LAIKA',
        style: TextStyle(
          fontFamily: _font,
          fontSize: min(size.width * 0.26, 260),
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black.withValues(alpha: 0.12),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(24, size.height * 0.08));
    void shape(Rect r, Color c, {bool circle = false}) {
      final fill = Paint()..color = c;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _k;
      final shadow = Paint()..color = _k;
      if (circle) {
        canvas.drawOval(r.shift(const Offset(5, 5)), shadow);
        canvas.drawOval(r, fill);
        canvas.drawOval(r, stroke);
      } else {
        canvas.drawRect(r.shift(const Offset(5, 5)), shadow);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, stroke);
      }
    }

    shape(Rect.fromLTWH(size.width * 0.62, size.height * 0.12, 70, 70), _pink, circle: true);
    shape(Rect.fromLTWH(size.width * 0.12, size.height * 0.62, 90, 46), _blue);
    shape(Rect.fromLTWH(size.width * 0.44, size.height * 0.75, 34, 34), _green);
    final hint = TextPainter(
      text: TextSpan(text: 'PASA EL MOUSE SOBRE LAIKA ↘', style: _b(14, w: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(canvas, Offset(28, size.height * 0.08 + tp.height + 4));
  }

  @override
  bool shouldRepaint(covariant _Backdrop old) => false;
}

class _BlockDog extends CustomPainter {
  _BlockDog({required this.state, required this.t, required this.bell});
  final PetState state;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final asleep = state == PetState.asleep;
    final c = size.center(Offset.zero);
    final w = size.width * 0.62;
    final bounce = asleep ? 0.0 : max(0.0, sin(t * 4)) * 10;
    final squash = asleep ? 1.0 : 1 + 0.05 * cos(t * 8).abs();
    canvas.save();
    canvas.translate(c.dx, c.dy + 14 - bounce);
    canvas.scale(1 / squash * (asleep ? 1.08 : 1), squash * (asleep ? 0.86 : 1));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _k
      ..strokeJoin = StrokeJoin.miter;
    final black = Paint()..color = _k;

    // Orejas.
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * w * 0.18, -w * 0.5)
        ..lineTo(s * w * 0.5, asleep ? -w * 0.42 : -w * 0.85)
        ..lineTo(s * w * 0.5, -w * 0.38)
        ..close();
      canvas.drawPath(ear.shift(const Offset(5, 5)), black);
      canvas.drawPath(ear, Paint()..color = _pink);
      canvas.drawPath(ear, stroke);
    }
    // Cabeza.
    final head = Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.9);
    canvas.drawRect(head.shift(const Offset(7, 7)), black);
    canvas.drawRect(head, Paint()..color = asleep ? const Color(0xFFE6D77A) : _yellow);
    canvas.drawRect(head, stroke);
    // Ojos.
    for (final s in [-1.0, 1.0]) {
      final e = Offset(s * w * 0.2, -w * 0.08);
      if (asleep || (t % 3.1) < 0.12) {
        canvas.drawRect(Rect.fromCenter(center: e, width: w * 0.2, height: 5), black);
      } else {
        canvas.drawCircle(e, w * 0.1, Paint()..color = Colors.white);
        canvas.drawCircle(e, w * 0.1, stroke..strokeWidth = 3);
        final look = state == PetState.thinking ? Offset(w * 0.04, -w * 0.04) : Offset.zero;
        final pupil = state == PetState.waking ? w * 0.025 : w * 0.05;
        canvas.drawCircle(e + look, pupil, black);
      }
    }
    // Nariz y boca.
    canvas.drawRect(Rect.fromCenter(center: Offset(0, w * 0.12), width: w * 0.16, height: w * 0.09), black);
    if (!asleep) {
      canvas.drawRect(Rect.fromCenter(center: Offset(0, w * 0.27), width: w * 0.12, height: w * 0.1), Paint()..color = _pink);
      canvas.drawRect(Rect.fromCenter(center: Offset(0, w * 0.27), width: w * 0.12, height: w * 0.1), stroke..strokeWidth = 3);
    }
    canvas.restore();

    if (bell) {
      final r = Rect.fromLTWH(4, 8, 30, 30);
      canvas.drawRect(r.shift(const Offset(3, 3)), black);
      canvas.drawRect(r, Paint()..color = const Color(0xFFFF5A5A));
      canvas.drawRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      final tp = TextPainter(text: TextSpan(text: '!', style: _b(20, w: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BlockDog old) => true;
}

// ── Cerebro: grafo de fuerzas ───────────────────────────────────────────────

class _BrutalBrain extends StatefulWidget {
  const _BrutalBrain({required this.brain});
  final BrainController brain;
  @override
  State<_BrutalBrain> createState() => _BrutalBrainState();
}

class _BrutalBrainState extends State<_BrutalBrain> {
  Map<String, Offset> _world = {};
  String _key = '';
  Offset _pan = Offset.zero;
  double _zoom = 1;
  String? _dragging;
  BrainController get b => widget.brain;

  Offset _toScreen(Offset w) => w * _zoom + _pan;
  Offset _toWorld(Offset s) => (s - _pan) / _zoom;

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [b],
      builder: (context) {
        final g = b.graph;
        if (g == null) return Center(child: Text(b.error ?? 'CARGANDO…', style: _b(22)));
        return Row(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final nodes = b.visibleNodes;
              final edges = b.visibleEdges;
              final key = '${b.version}|${nodes.length}|${box.maxWidth ~/ 50}|${box.maxHeight ~/ 50}';
              if (key != _key) {
                _world = forceLayout(nodes, edges, g.areas, box.biggest);
                _key = key;
              }
              final screen = {for (final e in _world.entries) e.key: _toScreen(e.value)};
              return Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    final f = e.scrollDelta.dy > 0 ? 0.9 : 1.1;
                    setState(() {
                      final before = _toWorld(e.localPosition);
                      _zoom = (_zoom * f).clamp(0.4, 3.0);
                      _pan = e.localPosition - before * _zoom;
                    });
                  }
                },
                child: GestureDetector(
                  onTapUp: (d) => b.select(hitTest(screen, d.localPosition, radius: 20 * _zoom.clamp(1, 2))),
                  onPanStart: (d) => _dragging = hitTest(screen, d.localPosition, radius: 20 * _zoom.clamp(1, 2)),
                  onPanUpdate: (d) => setState(() {
                    final id = _dragging;
                    if (id != null && _world[id] != null) {
                      _world[id] = _world[id]! + d.delta / _zoom;
                    } else {
                      _pan += d.delta;
                    }
                  }),
                  onPanEnd: (_) => _dragging = null,
                  child: CustomPaint(
                    size: box.biggest,
                    painter: _ForcePainter(brain: b, graph: g, screen: screen, zoom: _zoom),
                  ),
                ),
              );
            }),
          ),
          _side(g),
        ]);
      },
    );
  }

  Widget _side(MemoryGraph g) {
    final sel = b.selected;
    return Container(
      width: 340,
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: _k, width: 3))),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Text('CEREBRO', style: _b(40, w: FontWeight.w900)),
        Text('${b.visibleNodes.length} RECUERDOS · ARRASTRA LOS NODOS', style: _b(12)),
        const SizedBox(height: 14),
        Container(
          decoration: _box(Colors.white, shadow: 4),
          child: TextField(
            onChanged: b.setQuery,
            style: _b(15, w: FontWeight.w700),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              hintText: 'BUSCAR',
              hintStyle: _b(15, color: Colors.black26),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (sel != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _box(g.colorOf(sel).withValues(alpha: 1), shadow: 6),
            child: NodeDetails(
              brain: b,
              node: sel,
              title: _b(20, w: FontWeight.w900),
              body: _b(14, w: FontWeight.w500),
              meta: _b(11),
              linkBuilder: (context, n, onTap) => GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: _box(Colors.white, shadow: 2, border: 2),
                  child: Text(n.label, style: _b(11)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        BrainFilters(
          brain: b,
          spacing: 8,
          titleStyle: _b(14, w: FontWeight.w900),
          chip: (context, label, color, selected, onTap) => GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: _box(selected ? color : Colors.white, shadow: selected ? 0 : 3, border: 2),
              child: Text(label.toUpperCase(), style: _b(11)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ForcePainter extends CustomPainter {
  _ForcePainter({required this.brain, required this.graph, required this.screen, required this.zoom});
  final BrainController brain;
  final MemoryGraph graph;
  final Map<String, Offset> screen;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    const _Backdrop().paint(canvas, size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg.withValues(alpha: 0.85));
    final sel = brain.selectedId;
    final hot = {?sel, if (sel != null) ...brain.neighbors(sel).map((n) => n.id)};

    // Etiqueta de cada área en el centro de sus nodos.
    for (final a in graph.areas) {
      final pts = [for (final n in brain.visibleNodes.where((n) => n.primaryArea == a.id)) ?screen[n.id]];
      if (pts.isEmpty) continue;
      final c = pts.reduce((x, y) => x + y) / pts.length.toDouble();
      final tp = TextPainter(
        text: TextSpan(text: a.name.toUpperCase(), style: _b(22 * zoom.clamp(0.7, 1.4), w: FontWeight.w900, color: a.color.withValues(alpha: 0.55))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 + 34));
    }

    for (final e in brain.visibleEdges) {
      final a = screen[e.source], b = screen[e.target];
      if (a == null || b == null) continue;
      final lit = hot.contains(e.source) && hot.contains(e.target);
      canvas.drawLine(a, b, Paint()
        ..color = lit ? _k : Colors.black26
        ..strokeWidth = lit ? 3.5 : 2);
    }

    for (final n in brain.visibleNodes) {
      final o = screen[n.id];
      if (o == null) continue;
      final r = (n.kind == NodeKind.entity ? 15.0 : 9.0 + n.importance * 4) * zoom.clamp(0.7, 1.6);
      final isSel = n.id == sel;
      final archived = n.timeScope == TimeScope.archived;
      final fill = Paint()..color = archived ? Colors.white : graph.colorOf(n);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 4 : 3
        ..color = _k;
      if (n.kind == NodeKind.reminder || n.kind == NodeKind.episode) {
        final rect = Rect.fromCircle(center: o, radius: r);
        canvas.drawRect(rect.shift(const Offset(4, 4)), Paint()..color = _k);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      } else {
        canvas.drawCircle(o + const Offset(4, 4), r, Paint()..color = _k);
        canvas.drawCircle(o, r, fill);
        canvas.drawCircle(o, r, stroke);
      }
      if (brain.matches(n)) {
        canvas.drawCircle(o, r + 8, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _pink);
      }
      if (n.kind == NodeKind.entity || isSel || hot.contains(n.id) || brain.matches(n)) {
        final tp = TextPainter(
          text: TextSpan(text: n.label, style: _b(12, w: FontWeight.w800)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 170);
        final rect = Rect.fromLTWH(o.dx + r + 6, o.dy - tp.height / 2 - 3, tp.width + 10, tp.height + 6);
        canvas.drawRect(rect, Paint()..color = isSel ? _yellow : Colors.white);
        canvas.drawRect(rect, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        tp.paint(canvas, rect.topLeft + const Offset(5, 3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForcePainter old) => true;
}

// ── Agenda ──────────────────────────────────────────────────────────────────

class _BrutalAgenda extends StatelessWidget {
  const _BrutalAgenda({required this.rem});
  final RemindersController rem;

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [rem],
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        children: [
          Text('AGENDA', style: _b(56, w: FontWeight.w900)),
          const SizedBox(height: 18),
          for (final e in rem.grouped().entries) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              color: _k,
              child: Text(e.key.label.toUpperCase(),
                  style: _b(14, color: e.key == ReminderGroup.overdue ? _pink : _yellow, w: FontWeight.w900)),
            ),
            Wrap(spacing: 18, runSpacing: 18, children: [
              for (final r in e.value)
                SizedBox(
                  width: 280,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _box(r.isOpen ? Colors.white : const Color(0xFFEDEDED)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.text, style: _b(18, w: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(friendlyDate(r.dueAt).toUpperCase(), style: _b(12, w: FontWeight.w700)),
                        if (r.isOpen) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            _btn('HECHO', _green, () => rem.done(r)),
                            const SizedBox(width: 10),
                            _btn('+1 H', _blue, () => rem.snooze(r)),
                          ]),
                        ],
                      ]),
                    ),
                    if (!r.isOpen)
                      Positioned(
                        right: 12,
                        top: 14,
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5484D), width: 3)),
                            child: Text('HECHO', style: _b(18, color: const Color(0xFFE5484D), w: FontWeight.w900)),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]),
            const SizedBox(height: 26),
          ],
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: _box(color, shadow: 3, border: 2),
          child: Text(label, style: _b(13, w: FontWeight.w900)),
        ),
      );
}
