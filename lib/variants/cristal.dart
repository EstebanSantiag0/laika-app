// VARIANTE 5 — CRISTAL
// Calma y tiempo: fondo pastel con manchas de luz que se mueven despacio,
// paneles de vidrio esmerilado y Laika como una gotita suave. El cerebro son
// "órbitas del tiempo": el centro es AHORA (recordatorios), luego lo que tiene
// fecha, la etapa actual, lo permanente y, en el borde, lo archivado. Cada
// área de tu vida es una rebanada del círculo.

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/brain.dart';
import '../core/layouts.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/session.dart';
import '../core/stage.dart';
import '../core/widgets.dart';

const _text = Color(0xFF3B3355);
const _soft = Color(0xFF8C82A8);
const _accent = Color(0xFF8B7CF6);
const _font = 'Adwaita Sans';

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color color = _text}) =>
    TextStyle(fontFamily: _font, fontSize: size, fontWeight: w, color: color, height: 1.35, letterSpacing: 0.1);

final cristalSpec = VariantSpec(
  id: 'cristal',
  name: 'Cristal',
  tagline: 'Vidrio esmerilado y tonos pastel; el cerebro como órbitas del tiempo (ahora → archivado).',
  swatch: const [Color(0xFFE9D5FF), Color(0xFFFFE4E6), Color(0xFFD1FAE5), _accent],
  build: (s) => _CristalApp(session: s),
);

class _CristalApp extends StatefulWidget {
  const _CristalApp({required this.session});
  final LaikaSession session;
  @override
  State<_CristalApp> createState() => _CristalAppState();
}

class _CristalAppState extends State<_CristalApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: _font,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: _accent),
      ),
      home: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: _Aurora()),
          Positioned.fill(
            child: IndexedStack(index: tab, children: [
              PetStage(controller: s.pet, skin: const _CristalSkin()),
              _CristalBrain(brain: s.brain),
              _CristalAgenda(rem: s.reminders),
            ]),
          ),
          Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: Center(
              child: Frosted(
                radius: 30,
                padding: const EdgeInsets.all(5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final (i, label) in [(0, 'Escritorio'), (1, 'Cerebro'), (2, 'Agenda')])
                    GestureDetector(
                      onTap: () => setState(() => tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: i == tab ? Colors.white.withValues(alpha: 0.85) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: i == tab ? [const BoxShadow(color: Color(0x228B7CF6), blurRadius: 12, offset: Offset(0, 4))] : null,
                        ),
                        child: Text(label, style: _t(14, w: i == tab ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Fondo: manchas de color difusas que se mueven lentamente.
class _Aurora extends StatefulWidget {
  const _Aurora();
  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _AuroraPainter(_c.value * 2 * pi)),
        ),
      );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.a);
  final double a;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F3FF));
    final blobs = [
      (const Color(0xFFD8B4FE), 0.25, 0.3, 0.0),
      (const Color(0xFFFBCFE8), 0.75, 0.25, 1.7),
      (const Color(0xFFA7F3D0), 0.6, 0.78, 3.1),
      (const Color(0xFFBFDBFE), 0.2, 0.8, 4.4),
    ];
    for (final (color, x, y, ph) in blobs) {
      final c = Offset(size.width * (x + 0.08 * cos(a + ph)), size.height * (y + 0.08 * sin(a * 1.3 + ph)));
      final r = max(size.width, size.height) * 0.42;
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.a != a;
}

// ── Escritorio ──────────────────────────────────────────────────────────────

class _CristalSkin extends PetSkin {
  const _CristalSkin();

  @override
  double get petSize => 128;

  @override
  Widget backdrop(BuildContext context) => const SizedBox.expand();

  @override
  Widget pet(BuildContext context, PetController c, double t) =>
      CustomPaint(painter: _BlobDog(state: c.state, t: t, bell: c.pendingReminders.isNotEmpty));

  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) => Opacity(
        opacity: (1 - age * 0.2).clamp(0.3, 1.0),
        child: Frosted(
          radius: 22,
          blur: 14,
          color: Colors.white.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(text, style: _t(15)),
        ),
      );

  @override
  Widget typing(BuildContext context, double t, {required bool petOnRight}) => Frosted(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.25 + 0.6 * (0.5 + 0.5 * sin(t * 5 - i * 0.9))),
              ),
            ),
        ]),
      );

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) =>
      Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(12, color: _soft));

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Frosted(
        radius: 26,
        blur: 16,
        color: Colors.white.withValues(alpha: 0.7),
        padding: const EdgeInsets.only(left: 18, right: 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onSubmitted: (_) => onSend(),
              style: _t(15),
              decoration: InputDecoration(border: InputBorder.none, hintText: 'Mensaje para Laika', hintStyle: _t(15, color: _soft)),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFC4B5FD), _accent])),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      );

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final s = statusText(c);
    if (s == null) return null;
    return Frosted(
      radius: 14,
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(s, style: _t(12, color: c.wakeFailed ? const Color(0xFFD9467A) : _soft)),
    );
  }
}

class _BlobDog extends CustomPainter {
  _BlobDog({required this.state, required this.t, required this.bell});
  final PetState state;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final asleep = state == PetState.asleep;
    final c = size.center(Offset.zero) + const Offset(0, 8);
    final breathe = 1 + (asleep ? 0.03 : 0.02) * sin(t * (asleep ? 1.4 : 2.6));
    final r = size.width * 0.34;

    // Halo.
    canvas.drawCircle(c, r * 1.6,
        Paint()..shader = RadialGradient(colors: [(asleep ? const Color(0xFFC7D2FE) : const Color(0xFFFBCFE8)).withValues(alpha: 0.7), Colors.transparent]).createShader(Rect.fromCircle(center: c, radius: r * 1.6)));

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(breathe, 1 / breathe);
    // Orejas caídas.
    for (final s in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(s * r * 0.78, -r * 0.35);
      canvas.rotate(s * (asleep ? 0.5 : 0.25 + 0.05 * sin(t * 2)));
      canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 0.5, height: r * 0.95),
          Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD6BCFA), Color(0xFFB794F4)]).createShader(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 0.5, height: r * 0.95)));
      canvas.restore();
    }
    // Cuerpo-gota.
    final body = Path()
      ..moveTo(0, -r)
      ..cubicTo(r * 0.95, -r, r * 1.1, r * 0.2, r * 0.9, r * 0.65)
      ..cubicTo(r * 0.7, r * 1.05, -r * 0.7, r * 1.05, -r * 0.9, r * 0.65)
      ..cubicTo(-r * 1.1, r * 0.2, -r * 0.95, -r, 0, -r)
      ..close();
    canvas.drawShadow(body, const Color(0x558B7CF6), 10, false);
    canvas.drawPath(body,
        Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF3E8FF), Color(0xFFE9D5FF)]).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    // Brillo.
    canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.4, -r * 0.55), width: r * 0.42, height: r * 0.22), Paint()..color = Colors.white.withValues(alpha: 0.9));

    final ink = Paint()
      ..color = _text
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      final e = Offset(s * r * 0.35, r * 0.05);
      if (asleep || (t % 4.5) < 0.14) {
        canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.26, height: r * 0.18), 0.15, pi - 0.3, false, ink);
      } else if (state == PetState.waking) {
        canvas.drawLine(e - Offset(r * 0.1, 0), e + Offset(r * 0.1, 0), ink);
      } else {
        final look = state == PetState.thinking ? Offset(r * 0.05, -r * 0.06) : Offset.zero;
        canvas.drawCircle(e + look, r * 0.075, Paint()..color = _text);
        canvas.drawCircle(e + look + Offset(-r * 0.025, -r * 0.03), r * 0.025, Paint()..color = Colors.white);
      }
      // Mejillas.
      canvas.drawOval(Rect.fromCenter(center: Offset(s * r * 0.58, r * 0.3), width: r * 0.26, height: r * 0.14), Paint()..color = const Color(0x66F9A8D4));
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.22), width: r * 0.16, height: r * 0.1), Paint()..color = _text);
    if (!asleep) {
      canvas.drawArc(Rect.fromCenter(center: Offset(-r * 0.07, r * 0.32), width: r * 0.14, height: r * 0.12), 0, pi, false, ink..strokeWidth = 1.8);
      canvas.drawArc(Rect.fromCenter(center: Offset(r * 0.07, r * 0.32), width: r * 0.14, height: r * 0.12), 0, pi, false, ink);
    }
    canvas.restore();

    if (asleep) {
      // Lunita.
      final m = c + Offset(r * 1.05, -r * 1.1 + sin(t) * 3);
      canvas.drawCircle(m, 11, Paint()..color = const Color(0xFFFDE68A));
      canvas.drawCircle(m + const Offset(5, -3), 9, Paint()..color = const Color(0xFFF7F3FF));
    }
    if (state == PetState.thinking) {
      for (var i = 0; i < 3; i++) {
        final ph = (t * 0.8 + i / 3) % 1;
        canvas.drawCircle(c + Offset(r * 0.9 + i * 6, -r * 1.0 - ph * 20), 3.5 - i * 0.6,
            Paint()..color = _accent.withValues(alpha: 1 - ph));
      }
    }
    if (bell) {
      canvas.drawCircle(c + Offset(-r * 1.0, -r * 0.95), 9, Paint()..color = const Color(0xFFF472B6));
      canvas.drawCircle(c + Offset(-r * 1.0, -r * 0.95), 13, Paint()..color = const Color(0x44F472B6));
    }
  }

  @override
  bool shouldRepaint(covariant _BlobDog old) => true;
}

// ── Cerebro: órbitas del tiempo ─────────────────────────────────────────────

class _CristalBrain extends StatelessWidget {
  const _CristalBrain({required this.brain});
  final BrainController brain;

  @override
  Widget build(BuildContext context) {
    final b = brain;
    return Watch(
      listenables: [b],
      builder: (context) {
        final g = b.graph;
        if (g == null) return Center(child: Text(b.error ?? 'Cargando…', style: _t(16, color: _soft)));
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 76, 16, 16),
          child: Row(children: [
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final r = min(box.maxWidth, box.maxHeight) / 2 - 12;
                final c = box.biggest.center(Offset.zero);
                final pos = orbitLayout(g.areas, b.visibleNodes, r).map((k, v) => MapEntry(k, v + c));
                return GestureDetector(
                  onTapUp: (d) => b.select(hitTest(pos, d.localPosition, radius: 16)),
                  child: CustomPaint(size: box.biggest, painter: _OrbitPainter(brain: b, graph: g, pos: pos, r: r)),
                );
              }),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 320, child: _side(g)),
          ]),
        );
      },
    );
  }

  Widget _side(MemoryGraph g) {
    final b = brain;
    final sel = b.selected;
    return Frosted(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: ListView(children: [
        Text('Órbitas del tiempo', style: _t(22, w: FontWeight.w300)),
        Text('Centro = ahora · borde = pasado', style: _t(12, color: _soft)),
        const SizedBox(height: 14),
        TextField(
          onChanged: b.setQuery,
          style: _t(14),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar',
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _soft),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        if (sel != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: g.colorOf(sel).withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: NodeDetails(
              brain: b,
              node: sel,
              title: _t(17, w: FontWeight.w600),
              body: _t(13, color: _soft),
              meta: _t(11, color: g.colorOf(sel), w: FontWeight.w600),
              linkBuilder: (context, n, onTap) => GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: g.colorOf(n).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(n.label, style: _t(11)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        BrainFilters(
          brain: b,
          spacing: 6,
          titleStyle: _t(12, color: _soft, w: FontWeight.w600),
          chip: (context, label, color, selected, onTap) => GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label, style: _t(12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.brain, required this.graph, required this.pos, required this.r});
  final BrainController brain;
  final MemoryGraph graph;
  final Map<String, Offset> pos;
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final n = graph.areas.length;
    final sector = 2 * pi / n;

    // Rebanadas por área.
    for (var i = 0; i < n; i++) {
      final a = graph.areas[i];
      final dim = brain.areaFilter.isNotEmpty && !brain.areaFilter.contains(a.id);
      final start = -pi / 2 + i * sector;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sector, true,
          Paint()..color = a.color.withValues(alpha: dim ? 0.02 : 0.07));
      canvas.drawLine(c, c + Offset(cos(start), sin(start)) * r, Paint()..color = Colors.white.withValues(alpha: 0.8));
      final mid = start + sector / 2;
      final tp = TextPainter(
        text: TextSpan(text: a.name, style: _t(12, color: a.color.withValues(alpha: dim ? 0.3 : 1), w: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      final lp = c + Offset(cos(mid), sin(mid)) * (r + 2) - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, lp + Offset(cos(mid) * tp.width * 0.3, sin(mid) * 8));
    }
    // Órbitas.
    for (var ring = 0; ring < orbitNames.length; ring++) {
      final rr = r * orbitRadius(ring);
      canvas.drawCircle(c, rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.95));
      final tp = TextPainter(text: TextSpan(text: orbitNames[ring], style: _t(10, color: _soft)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, c + Offset(4, -rr - tp.height));
    }
    // Centro: ahora.
    canvas.drawCircle(c, r * 0.09, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]).createShader(Rect.fromCircle(center: c, radius: r * 0.12)));
    final now = TextPainter(text: TextSpan(text: 'ahora', style: _t(12, w: FontWeight.w600, color: _accent)), textDirection: TextDirection.ltr)..layout();
    now.paint(canvas, c - Offset(now.width / 2, now.height / 2));

    final sel = brain.selectedId;
    final hot = {?sel, if (sel != null) ...brain.neighbors(sel).map((x) => x.id)};
    for (final e in brain.visibleEdges) {
      if (!hot.contains(e.source) || !hot.contains(e.target)) continue;
      final a = pos[e.source], b = pos[e.target];
      if (a == null || b == null) continue;
      final ctrl = c + ((a + b) / 2 - c) * 0.6;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _accent.withValues(alpha: 0.6));
    }
    for (final node in brain.visibleNodes) {
      final o = pos[node.id];
      if (o == null) continue;
      final col = graph.colorOf(node);
      final rad = node.kind == NodeKind.entity ? 7.5 : 5.0 + node.importance * 2.5;
      final archived = node.timeScope == TimeScope.archived;
      canvas.drawCircle(o, rad * 2.4, Paint()..color = col.withValues(alpha: archived ? 0.05 : 0.18));
      canvas.drawCircle(o, rad, Paint()..color = archived ? col.withValues(alpha: 0.35) : col);
      canvas.drawCircle(o, rad, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white);
      final isSel = node.id == sel;
      if (isSel || brain.matches(node)) {
        canvas.drawCircle(o, rad + 5, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = isSel ? _accent : const Color(0xFFF472B6));
      }
      if (isSel || hot.contains(node.id) || brain.matches(node) || node.kind == NodeKind.reminder) {
        final tp = TextPainter(
          text: TextSpan(text: node.label, style: _t(11, w: isSel ? FontWeight.w600 : FontWeight.w400)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 150);
        final rect = Rect.fromLTWH(o.dx + rad + 5, o.dy - tp.height / 2 - 2, tp.width + 10, tp.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = Colors.white.withValues(alpha: 0.8));
        tp.paint(canvas, rect.topLeft + const Offset(5, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}

// ── Agenda: línea de tiempo ─────────────────────────────────────────────────

class _CristalAgenda extends StatelessWidget {
  const _CristalAgenda({required this.rem});
  final RemindersController rem;

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [rem],
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 90, 20, 60),
            children: [
              Text('Agenda', style: _t(34, w: FontWeight.w200)),
              Text('Laika te avisa a la hora; si estás lejos, por Telegram.', style: _t(13, color: _soft)),
              const SizedBox(height: 20),
              for (final e in rem.grouped().entries) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 8),
                  child: Text(e.key.label, style: _t(12, w: FontWeight.w600, color: e.key == ReminderGroup.overdue ? const Color(0xFFD9467A) : _accent)),
                ),
                for (final r in e.value)
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(
                        width: 30,
                        child: Column(children: [
                          Container(
                            margin: const EdgeInsets.only(top: 18),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: r.isOpen ? _accent : Colors.white,
                              border: Border.all(color: _accent, width: 2),
                            ),
                          ),
                          Expanded(child: Container(width: 2, color: Colors.white)),
                        ]),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Frosted(
                            radius: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r.text,
                                      style: _t(15, w: FontWeight.w500, color: r.isOpen ? _text : _soft)
                                          .copyWith(decoration: r.isOpen ? null : TextDecoration.lineThrough)),
                                  Text('${friendlyDate(r.dueAt)} · ${r.status.label}', style: _t(12, color: _soft)),
                                ]),
                              ),
                              if (r.isOpen) ...[
                                TextButton(onPressed: () => rem.snooze(r), child: const Text('Luego')),
                                FilledButton.tonal(onPressed: () => rem.done(r), child: const Text('Listo')),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
