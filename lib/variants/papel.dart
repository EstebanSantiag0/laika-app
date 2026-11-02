// VARIANTE 2 — PAPEL
// Un cuaderno: hojas rayadas, tinta azul, trazos a mano que "tiemblan",
// mensajes de Laika en notas adhesivas y el cerebro como un mapa mental
// dibujado en la hoja.

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/brain.dart';
import '../core/layouts.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/session.dart';
import '../core/stage.dart';
import '../core/widgets.dart';

const _paper = Color(0xFFF7F1E3);
const _ink = Color(0xFF1F2A55);
const _blue = Color(0xFF2B59C3);
const _red = Color(0xFFD94848);
const _line = Color(0xFFB7CBE8);
const _serif = 'Noto Serif';

TextStyle _hand(double size, {Color color = _ink, bool italic = true, FontWeight w = FontWeight.w400}) =>
    TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: const ['FreeSerif', 'Liberation Serif', 'serif'],
      fontSize: size,
      color: color,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: w,
      height: 1.3,
    );

final papelSpec = VariantSpec(
  id: 'papel',
  name: 'Papel',
  tagline: 'Cuaderno rayado: Laika dibujada a mano, notas adhesivas y un mapa mental en tinta.',
  swatch: const [_paper, _blue, Color(0xFFFFF09A), _red],
  build: (s) => _PapelApp(session: s),
);

class _PapelApp extends StatefulWidget {
  const _PapelApp({required this.session});
  final LaikaSession session;
  @override
  State<_PapelApp> createState() => _PapelAppState();
}

class _PapelAppState extends State<_PapelApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _blue, surface: _paper),
        fontFamily: _serif,
      ),
      home: Scaffold(
        body: Row(children: [
          Expanded(
            child: IndexedStack(index: tab, children: [
              PetStage(controller: s.pet, skin: const _PapelSkin()),
              _PapelBrain(brain: s.brain),
              _PapelAgenda(rem: s.reminders),
            ]),
          ),
          _Tabs(tab: tab, onTab: (i) => setState(() => tab = i)),
        ]),
      ),
    );
  }
}

/// Pestañas de cuaderno en el borde derecho.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    const tabs = [('Escritorio', Color(0xFFFFE58A)), ('Cerebro', Color(0xFFB8E0D2)), ('Agenda', Color(0xFFF6B8B8))];
    return Container(
      width: 46,
      color: const Color(0xFFE9E1CF),
      child: Column(children: [
        const SizedBox(height: 40),
        for (var i = 0; i < tabs.length; i++)
          GestureDetector(
            onTap: () => onTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(bottom: 6, right: i == tab ? 0 : 8),
              height: 120,
              decoration: BoxDecoration(
                color: tabs[i].$2,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                boxShadow: const [BoxShadow(color: Color(0x22000000), offset: Offset(2, 2), blurRadius: 2)],
              ),
              child: RotatedBox(
                quarterTurns: 1,
                child: Center(child: Text(tabs[i].$1, style: _hand(15, w: i == tab ? FontWeight.w700 : FontWeight.w400))),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Trazos a mano ───────────────────────────────────────────────────────────

/// Un trazo que tiembla un poco, como dibujado a mano. Cambia la semilla
/// cada cuarto de segundo para que la línea "hierva".
Path _wobble(List<Offset> pts, int seed, {double amp = 1.6, bool close = false}) {
  final r = Random(seed);
  final p = Path();
  for (var i = 0; i < pts.length; i++) {
    final o = pts[i] + Offset((r.nextDouble() - .5) * amp * 2, (r.nextDouble() - .5) * amp * 2);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  if (close) p.close();
  return p;
}

List<Offset> _ellipsePts(Offset c, double rx, double ry, {int n = 28, double start = 0, double sweep = 2 * pi}) => [
      for (var i = 0; i <= n; i++) c + Offset(cos(start + sweep * i / n) * rx, sin(start + sweep * i / n) * ry),
    ];

void _sketch(Canvas canvas, List<Offset> pts, int seed,
    {Color color = _ink, double width = 2, bool close = false, Color? fill}) {
  if (fill != null) {
    canvas.drawPath(_wobble(pts, seed + 99, amp: 0.8, close: true), Paint()..color = fill);
  }
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(_wobble(pts, seed, close: close), paint);
  canvas.drawPath(_wobble(pts, seed + 7, amp: 1.2, close: close), paint..color = color.withValues(alpha: 0.35));
}

// ── Escritorio ──────────────────────────────────────────────────────────────

class _PapelSkin extends PetSkin {
  const _PapelSkin();

  @override
  double get petSize => 150;

  @override
  Widget backdrop(BuildContext context) => const CustomPaint(painter: _RuledPaper(doodles: true));

  @override
  Widget pet(BuildContext context, PetController c, double t) =>
      CustomPaint(painter: _SketchDog(state: c.state, t: t, bell: c.pendingReminders.isNotEmpty));

  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) {
    final angle = ((text.hashCode % 7) - 3) * 0.008;
    final colors = [const Color(0xFFFFF09A), const Color(0xFFFFD6E0), const Color(0xFFD7F0C2)];
    return Transform.rotate(
      angle: angle,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: colors[text.length % colors.length],
            boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 3)],
          ),
          child: Text(text, style: _hand(16)),
        ),
        Positioned(
          top: -8,
          left: petOnRight ? null : 18,
          right: petOnRight ? 18 : null,
          child: Transform.rotate(
            angle: -0.08,
            child: Container(width: 54, height: 16, color: const Color(0x99E8E2D0)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget typing(BuildContext context, double t, {required bool petOnRight}) =>
      Text('Laika está escribiendo${'.' * (1 + (t * 3).floor() % 3)}', style: _hand(14, color: _blue));

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) => Text(
        '— tú: $text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _hand(13, color: _ink.withValues(alpha: 0.5)),
      );

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Row(children: [
        Text('✎ ', style: _hand(18, color: _blue)),
        Expanded(
          child: TextField(
            controller: text,
            focusNode: focus,
            onSubmitted: (_) => onSend(),
            style: _hand(17, color: _blue),
            cursorColor: _blue,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'escríbele algo…',
              hintStyle: _hand(16, color: _ink.withValues(alpha: 0.3)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _ink, width: 1.2)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _blue, width: 2)),
            ),
          ),
        ),
        TextButton(onPressed: onSend, child: Text('enviar →', style: _hand(15, color: _red))),
      ]);

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final s = statusText(c);
    if (s == null) return null;
    return Transform.rotate(angle: -0.04, child: Text(s, style: _hand(14, color: c.wakeFailed ? _red : _blue)));
  }
}

class _RuledPaper extends CustomPainter {
  const _RuledPaper({this.doodles = false});
  final bool doodles;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    final lp = Paint()..color = _line..strokeWidth = 1;
    for (var y = 70.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    }
    canvas.drawLine(const Offset(72, 0), Offset(72, size.height), Paint()..color = _red.withValues(alpha: 0.6)..strokeWidth = 1.5);
    for (final f in [0.2, 0.5, 0.8]) {
      canvas.drawCircle(Offset(28, size.height * f), 11, Paint()..color = const Color(0xFFE2D9C4));
    }
    if (!doodles) return;
    // Mancha de café.
    canvas.drawCircle(Offset(size.width * 0.78, 120), 46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0x22A0703C));
    final tp = TextPainter(
      text: TextSpan(text: 'Laika · cuaderno', style: _hand(30, color: _ink.withValues(alpha: 0.75))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(96, 22));
    final tp2 = TextPainter(
      text: TextSpan(
          text: 'pasa el mouse sobre ella para despertarla · arrástrala para moverla',
          style: _hand(13, color: _ink.withValues(alpha: 0.45))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 120);
    tp2.paint(canvas, const Offset(98, 76));
  }

  @override
  bool shouldRepaint(covariant _RuledPaper old) => false;
}

class _SketchDog extends CustomPainter {
  _SketchDog({required this.state, required this.t, required this.bell});
  final PetState state;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final seed = (t * 4).floor();
    final asleep = state == PetState.asleep;
    final c = size.center(Offset.zero) + const Offset(0, 10);
    final r = size.width * 0.3;

    if (asleep) {
      // Hecha bolita: cuerpo, cabeza sobre las patas, cola enroscada.
      _sketch(canvas, _ellipsePts(c + Offset(0, r * 0.45), r * 1.25, r * 0.6), seed, fill: Colors.white, close: true);
      _sketch(canvas, _ellipsePts(c + Offset(-r * 0.45, r * 0.15), r * 0.62, r * 0.5), seed + 1, fill: Colors.white, close: true);
      _sketch(canvas, _ellipsePts(c + Offset(-r * 0.15, -r * 0.15), r * 0.28, r * 0.42, start: -pi / 2, sweep: pi), seed + 2,
          fill: const Color(0xFFB6865A));
      for (final dx in [-0.65, -0.3]) {
        _sketch(canvas, _ellipsePts(c + Offset(r * dx, r * 0.12), r * 0.1, r * 0.05, start: 0, sweep: pi), seed + 3, width: 2.2);
      }
      _sketch(canvas, _ellipsePts(c + Offset(r * 1.05, r * 0.35), r * 0.3, r * 0.25, start: -pi * 0.2, sweep: pi * 1.5), seed + 4);
      final z = (t * 0.6) % 1;
      final tp = TextPainter(
        text: TextSpan(text: 'z z z', style: _hand(14 + z * 6, color: _blue.withValues(alpha: 1 - z * 0.7))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(r * 0.1, -r * 1.1 - z * 12));
    } else {
      final bob = sin(t * 2.5) * 3;
      final h = c + Offset(0, bob - r * 0.1);
      // Orejas caídas.
      for (final s in [-1.0, 1.0]) {
        _sketch(canvas, [
          h + Offset(s * r * 0.55, -r * 0.6),
          h + Offset(s * r * 1.05, -r * 0.2),
          h + Offset(s * r * 0.95, r * 0.45),
          h + Offset(s * r * 0.65, r * 0.2),
        ], seed + (s > 0 ? 10 : 11), fill: const Color(0xFFB6865A), close: true);
      }
      _sketch(canvas, _ellipsePts(h, r * 0.8, r * 0.78), seed + 12, fill: Colors.white, close: true);
      // Ojos.
      final blink = (t % 3.7) < 0.15 || state == PetState.waking;
      for (final s in [-1.0, 1.0]) {
        final e = h + Offset(s * r * 0.3, -r * 0.1);
        if (blink) {
          _sketch(canvas, [e - Offset(r * 0.1, 0), e + Offset(r * 0.1, 0)], seed + 13, width: 2.4);
        } else {
          canvas.drawCircle(e, r * 0.08, Paint()..color = _ink);
          canvas.drawCircle(e + Offset(-r * 0.025, -r * 0.03), r * 0.025, Paint()..color = Colors.white);
        }
      }
      // Nariz y boca.
      canvas.drawPath(
          _wobble([h + Offset(-r * 0.1, r * 0.18), h + Offset(r * 0.1, r * 0.18), h + Offset(0, r * 0.3)], seed + 14, amp: .6, close: true),
          Paint()..color = _ink);
      _sketch(canvas, _ellipsePts(h + Offset(-r * 0.1, r * 0.33), r * 0.1, r * 0.08, start: 0, sweep: pi), seed + 15, width: 1.6);
      _sketch(canvas, _ellipsePts(h + Offset(r * 0.1, r * 0.33), r * 0.1, r * 0.08, start: 0, sweep: pi), seed + 16, width: 1.6);
      if (state == PetState.thinking) {
        for (var i = 0; i < 3; i++) {
          _sketch(canvas, _ellipsePts(h + Offset(r * (0.7 + i * 0.25), -r * (1.0 + i * 0.25)), 3.0 + i * 2, 3.0 + i * 2), seed + 20 + i,
              width: 1.4);
        }
      } else {
        // Lengüita.
        _sketch(canvas, _ellipsePts(h + Offset(0, r * 0.46), r * 0.09, r * 0.13, start: 0, sweep: pi), seed + 17,
            fill: const Color(0xFFF28B9B), color: _red, width: 1.4);
      }
    }
    if (bell) {
      final tp = TextPainter(text: TextSpan(text: '¡!', style: _hand(22, color: _red, w: FontWeight.w700)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, c + Offset(-r * 1.25, -r * 1.2));
    }
  }

  @override
  bool shouldRepaint(covariant _SketchDog old) => true;
}

// ── Cerebro: mapa mental ────────────────────────────────────────────────────

class _PapelBrain extends StatefulWidget {
  const _PapelBrain({required this.brain});
  final BrainController brain;
  @override
  State<_PapelBrain> createState() => _PapelBrainState();
}

class _PapelBrainState extends State<_PapelBrain> {
  static const _canvas = 1500.0;
  final _tc = TransformationController();
  bool _centered = false;
  BrainController get b => widget.brain;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [b],
      builder: (context) {
        final g = b.graph;
        if (g == null) return Center(child: Text(b.error ?? 'abriendo el cuaderno…', style: _hand(18)));
        final visible = b.visibleNodes;
        final pos = radialLayout(g, visible, _canvas * 0.47)
            .map((k, v) => MapEntry(k, v + const Offset(_canvas / 2, _canvas / 2)));
        return Row(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              if (!_centered) {
                _centered = true;
                final s = (min(box.maxWidth, box.maxHeight) / _canvas).clamp(0.3, 1.0);
                _tc.value = Matrix4.identity()
                  ..translateByDouble((box.maxWidth - _canvas * s) / 2, (box.maxHeight - _canvas * s) / 2, 0, 1)
                  ..scaleByDouble(s, s, 1, 1);
              }
              return Stack(children: [
                const Positioned.fill(child: CustomPaint(painter: _RuledPaper())),
                InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(800),
                  child: GestureDetector(
                    onTapUp: (d) => b.select(hitTest(pos, d.localPosition, radius: 30)),
                    child: CustomPaint(
                      size: const Size(_canvas, _canvas),
                      painter: _MindMapPainter(brain: b, graph: g, visible: visible, pos: pos),
                    ),
                  ),
                ),
                Positioned(
                  left: 96,
                  top: 18,
                  child: Text('Mi cerebro, según Laika', style: _hand(28)),
                ),
              ]);
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
      width: 320,
      color: const Color(0xFFEFE7D3),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        TextField(
          onChanged: b.setQuery,
          style: _hand(16),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'buscar…',
            hintStyle: _hand(16, color: _ink.withValues(alpha: 0.35)),
            prefixText: '🔍 ',
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _ink)),
          ),
        ),
        const SizedBox(height: 18),
        if (sel != null)
          Transform.rotate(
            angle: -0.012,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF09A),
                boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(2, 3), blurRadius: 3)],
              ),
              child: NodeDetails(
                brain: b,
                node: sel,
                title: _hand(19, w: FontWeight.w700, italic: false),
                body: _hand(15),
                meta: _hand(12, color: g.colorOf(sel)),
                linkBuilder: (context, n, onTap) => InkWell(
                  onTap: onTap,
                  child: Text('→ ${n.label}', style: _hand(14, color: _blue).copyWith(decoration: TextDecoration.underline)),
                ),
              ),
            ),
          )
        else
          Text('Toca una palabra del mapa para leer lo que Laika sabe.', style: _hand(15, color: _ink.withValues(alpha: 0.6))),
        const SizedBox(height: 22),
        BrainFilters(
          brain: b,
          spacing: 8,
          titleStyle: _hand(16, w: FontWeight.w700, italic: false),
          chip: (context, label, color, selected, onTap) => GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.35) : null,
                border: Border.all(color: selected ? _ink : color, width: selected ? 1.6 : 1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(label, style: _hand(14, color: _ink)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MindMapPainter extends CustomPainter {
  _MindMapPainter({required this.brain, required this.graph, required this.visible, required this.pos});
  final BrainController brain;
  final MemoryGraph graph;
  final List<MemoryNode> visible;
  final Map<String, Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final sel = brain.selectedId;
    final hot = {?sel, if (sel != null) ...brain.neighbors(sel).map((n) => n.id)};

    void curve(Offset a, Offset b, int seed, Color color, double w) {
      final mid = (a + b) / 2;
      final n = Offset(-(b - a).dy, (b - a).dx) * 0.12;
      final pts = [for (var i = 0; i <= 16; i++) _quad(a, mid + n, b, i / 16)];
      _sketch(canvas, pts, seed, color: color, width: w);
    }

    // Centro → áreas.
    for (final a in graph.areas) {
      final p = pos['area:${a.id}'];
      if (p == null) continue;
      if (brain.areaFilter.isNotEmpty && !brain.areaFilter.contains(a.id)) continue;
      curve(center, p, a.id.hashCode, _ink.withValues(alpha: 0.6), 2.2);
    }
    // Área → entidades y nodos sueltos; entidad → sus datos.
    final aboutOf = <String, String>{};
    for (final e in brain.visibleEdges) {
      if (e.kind == 'about' || e.kind == 'in_episode') aboutOf.putIfAbsent(e.source, () => e.target);
    }
    for (final n in visible) {
      final p = pos[n.id];
      if (p == null) continue;
      final parentId = n.kind == NodeKind.entity ? null : aboutOf[n.id];
      final parent = parentId != null && pos[parentId] != null ? pos[parentId]! : pos['area:${n.primaryArea}'];
      if (parent == null) continue;
      final lit = hot.contains(n.id) && (parentId == null || hot.contains(parentId));
      curve(parent, p, n.id.hashCode, lit ? _red : graph.colorOf(n).withValues(alpha: 0.55), lit ? 2.4 : 1.3);
    }
    // Relaciones entre entidades (punteadas).
    for (final e in brain.visibleEdges.where((e) => e.kind == 'related')) {
      final a = pos[e.source], bb = pos[e.target];
      if (a == null || bb == null) continue;
      final dash = Paint()..color = _ink.withValues(alpha: 0.25)..strokeWidth = 1;
      final len = (bb - a).distance;
      for (var d = 0.0; d < len; d += 10) {
        canvas.drawLine(a + (bb - a) * (d / len), a + (bb - a) * (min(d + 5, len) / len), dash);
      }
    }

    // Etiquetas.
    _label(canvas, center, 'YO', 30, _ink, circle: true, seed: 1);
    for (final a in graph.areas) {
      final p = pos['area:${a.id}'];
      if (p == null) continue;
      if (brain.areaFilter.isNotEmpty && !brain.areaFilter.contains(a.id)) continue;
      _label(canvas, p, a.name, 20, _ink, circle: true, seed: a.id.hashCode, marker: a.color);
    }
    for (final n in visible) {
      final p = pos[n.id];
      if (p == null) continue;
      final isSel = n.id == sel;
      final archived = n.timeScope == TimeScope.archived;
      final size = n.kind == NodeKind.entity ? 16.0 : 13.0;
      final prefix = switch (n.kind) {
        NodeKind.reminder => '⏰ ',
        NodeKind.episode => '💬 ',
        _ => n.timeScope == TimeScope.dated ? '📅 ' : '',
      };
      _label(canvas, p, '$prefix${n.label}', size, archived ? _ink.withValues(alpha: 0.4) : _ink,
          seed: n.id.hashCode,
          marker: isSel ? const Color(0xFFFFE14D) : (brain.matches(n) ? const Color(0xFFB8F5A0) : null),
          strike: archived,
          bold: n.kind == NodeKind.entity);
    }
  }

  Offset _quad(Offset a, Offset c, Offset b, double t) =>
      a * ((1 - t) * (1 - t)) + c * (2 * (1 - t) * t) + b * (t * t);

  void _label(Canvas canvas, Offset p, String text, double size, Color color,
      {bool circle = false, int seed = 0, Color? marker, bool strike = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: _hand(size, color: color, w: bold || circle ? FontWeight.w700 : FontWeight.w400, italic: !circle).copyWith(
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 170);
    final rect = Rect.fromCenter(center: p, width: tp.width + 18, height: tp.height + 10);
    if (marker != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(4)),
          Paint()..color = marker.withValues(alpha: circle ? 0.28 : 0.7));
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(4)), Paint()..color = _paper);
    }
    if (circle) _sketch(canvas, _ellipsePts(p, rect.width / 2 + 6, rect.height / 2 + 6), seed, width: 1.8);
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MindMapPainter old) => true;
}

// ── Agenda: lista de pendientes ─────────────────────────────────────────────

class _PapelAgenda extends StatelessWidget {
  const _PapelAgenda({required this.rem});
  final RemindersController rem;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _RuledPaper())),
      Watch(
        listenables: [rem],
        builder: (context) {
          final groups = rem.grouped();
          return ListView(
            padding: const EdgeInsets.fromLTRB(96, 18, 40, 80),
            children: [
              Text('Pendientes', style: _hand(32)),
              const SizedBox(height: 14),
              for (final e in groups.entries) ...[
                SizedBox(
                  height: 30,
                  child: Text(e.key.label, style: _hand(18, color: e.key == ReminderGroup.overdue ? _red : _blue, w: FontWeight.w700)),
                ),
                for (final r in e.value)
                  SizedBox(
                    height: 30,
                    child: Row(children: [
                      GestureDetector(
                        onTap: r.isOpen ? () => rem.done(r) : null,
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(border: Border.all(color: _ink, width: 1.6)),
                          child: r.isOpen ? null : Text('✗', style: _hand(14, color: _red, italic: false), textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${r.text}  — ${friendlyDate(r.dueAt)}',
                          style: _hand(17, color: r.isOpen ? _ink : _ink.withValues(alpha: 0.4))
                              .copyWith(decoration: r.isOpen ? null : TextDecoration.lineThrough),
                        ),
                      ),
                      if (r.isOpen)
                        TextButton(onPressed: () => rem.snooze(r), child: Text('después', style: _hand(14, color: _blue))),
                    ]),
                  ),
                const SizedBox(height: 30),
              ],
            ],
          );
        },
      ),
    ]);
  }
}
