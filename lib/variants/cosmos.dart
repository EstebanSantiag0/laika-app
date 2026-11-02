// VARIANTE 1 — COSMOS
// Laika como la perrita espacial: casco de vidrio, antena que indica si el
// servidor contestó, burbujas de neón y un cerebro en forma de esfera 3D de
// estrellas que puedes girar.

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/brain.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/session.dart';
import '../core/sphere_view.dart';
import '../core/stage.dart';
import '../core/widgets.dart';

const _bg = Color(0xFF05060F);
const _cyan = Color(0xFF6EE7F9);
const _violet = Color(0xFFA78BFA);
const _ink = Color(0xFFE6F1FF);

final cosmosSpec = VariantSpec(
  id: 'cosmos',
  name: 'Cosmos',
  tagline: 'Perrita espacial con casco, neón y un cerebro-esfera 3D que giras con el mouse.',
  swatch: const [_bg, _cyan, _violet, Color(0xFFE8C9A0)],
  build: (s) => _CosmosApp(session: s),
);

class _CosmosApp extends StatefulWidget {
  const _CosmosApp({required this.session});
  final LaikaSession session;
  @override
  State<_CosmosApp> createState() => _CosmosAppState();
}

class _CosmosAppState extends State<_CosmosApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _cyan, secondary: _violet, surface: _bg),
        fontFamily: 'Adwaita Sans',
      ),
      home: Scaffold(
        body: Row(children: [
          _Rail(tab: tab, onTab: (i) => setState(() => tab = i)),
          Expanded(
            child: IndexedStack(index: tab, children: [
              PetStage(controller: s.pet, skin: const _CosmosSkin()),
              _CosmosBrain(brain: s.brain),
              _CosmosAgenda(rem: s.reminders),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.rocket_launch_outlined, 'Escritorio'),
      (Icons.blur_on, 'Cerebro'),
      (Icons.schedule, 'Agenda'),
    ];
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0C1C),
        border: Border(right: BorderSide(color: Color(0x2238BDF8))),
      ),
      child: Column(children: [
        const SizedBox(height: 18),
        const Text('LAIKA', style: TextStyle(color: _cyan, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Tooltip(
              message: items[i].$2,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTab(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: i == tab ? const Color(0x2238BDF8) : Colors.transparent,
                    border: Border.all(color: i == tab ? _cyan : Colors.transparent),
                    boxShadow: i == tab ? [const BoxShadow(color: Color(0x5538BDF8), blurRadius: 18)] : null,
                  ),
                  child: Icon(items[i].$1, color: i == tab ? _cyan : Colors.white54),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Escritorio ──────────────────────────────────────────────────────────────

class _CosmosSkin extends PetSkin {
  const _CosmosSkin();

  @override
  double get petSize => 140;

  @override
  Widget backdrop(BuildContext context) => const CustomPaint(painter: _StarsPainter(seed: 3, count: 260));

  @override
  Widget pet(BuildContext context, PetController c, double t) =>
      CustomPaint(painter: _SpaceDogPainter(state: c.state, t: t, bell: c.pendingReminders.isNotEmpty));

  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1026),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(petOnRight ? 18 : 4),
          bottomRight: Radius.circular(petOnRight ? 4 : 18),
        ),
        border: Border.all(color: _cyan.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: _cyan.withValues(alpha: 0.25), blurRadius: 16)],
      ),
      child: Text(text, style: const TextStyle(color: _ink, fontSize: 14, height: 1.3)),
    );
  }

  @override
  Widget typing(BuildContext context, double t, {required bool petOnRight}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cyan.withValues(alpha: 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 6 - i))),
              ),
            ),
        ],
      );

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) => Text(
        'tú › $text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      );

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Container(
        decoration: BoxDecoration(
          color: const Color(0xE60B1026),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _violet.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.25), blurRadius: 14)],
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: _ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Escríbele a Laika…',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
          ),
          IconButton(onPressed: onSend, icon: const Icon(Icons.north_east, color: _cyan, size: 20)),
        ]),
      );

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final s = statusText(c) ?? (c.state == PetState.asleep ? 'zZz' : null);
    if (s == null) return null;
    return Text(s,
        style: TextStyle(
          color: c.wakeFailed ? const Color(0xFFFF8A8A) : _cyan.withValues(alpha: 0.85),
          fontSize: 12,
          letterSpacing: 1,
        ));
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter({required this.seed, required this.count});
  final int seed, count;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.6, -0.4),
          radius: 1.3,
          colors: [Color(0xFF1B1446), Color(0xFF0A0B22), _bg],
        ).createShader(Offset.zero & size),
    );
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final s = r.nextDouble();
      p.color = Colors.white.withValues(alpha: 0.2 + 0.6 * s);
      canvas.drawCircle(o, 0.4 + s * 1.3, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => false;
}

class _SpaceDogPainter extends CustomPainter {
  _SpaceDogPainter({required this.state, required this.t, required this.bell});
  final PetState state;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final asleep = state == PetState.asleep;
    final waking = state == PetState.waking;
    final c = size.center(Offset.zero);
    final bob = asleep ? sin(t * 1.2) * 1.5 : sin(t * 2.2) * 4;
    final r = size.width * 0.36;
    final center = c + Offset(0, bob + 6);

    // Antena: verde = despierta, ámbar = preguntando, roja = dormida.
    final antennaTop = center + Offset(r * 0.55, -r * 1.25);
    canvas.drawLine(center + Offset(r * 0.4, -r * 0.9), antennaTop,
        Paint()..color = Colors.white70..strokeWidth = 2);
    final light = asleep
        ? const Color(0xFFFF5D5D)
        : waking
            ? (sin(t * 12) > 0 ? const Color(0xFFFFC94D) : const Color(0x55FFC94D))
            : const Color(0xFF5DFF9B);
    canvas.drawCircle(antennaTop, 5, Paint()..color = light);
    canvas.drawCircle(antennaTop, 11, Paint()..color = light.withValues(alpha: 0.25));

    // Cabeza.
    final face = Paint()..color = const Color(0xFFE8C9A0);
    final dark = Paint()..color = const Color(0xFF6B4A2F);
    final tilt = asleep ? -0.18 : sin(t * 0.8) * 0.05;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    // Orejas.
    for (final sgn in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(sgn * r * 0.25, -r * 0.45)
        ..quadraticBezierTo(sgn * r * 0.75, -r * (asleep ? 0.55 : 1.0), sgn * r * 0.72, -r * 0.1)
        ..close();
      canvas.drawPath(ear, dark);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.35, height: r * 1.25), face);
    // Mancha del ojo.
    canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.25, -r * 0.12), width: r * 0.55, height: r * 0.5),
        Paint()..color = const Color(0xFFB98A5E));
    // Hocico.
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.7, height: r * 0.45),
        Paint()..color = const Color(0xFFF7E6CF));
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.17), width: r * 0.22, height: r * 0.15),
        Paint()..color = const Color(0xFF2B1D14));
    // Ojos.
    final eye = Paint()..color = const Color(0xFF1B1B2F);
    final blink = !asleep && (t % 4.2) < 0.13;
    for (final sgn in [-1.0, 1.0]) {
      final e = Offset(sgn * r * 0.27, -r * 0.1);
      if (asleep || blink) {
        canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.24, height: r * 0.16), 0.2, pi - 0.4, false,
            Paint()
              ..color = const Color(0xFF1B1B2F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round);
      } else {
        final h = waking ? r * 0.08 : r * 0.2;
        canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.18, height: h), eye);
        if (!waking) canvas.drawCircle(e + Offset(-r * 0.03, -r * 0.04), r * 0.035, Paint()..color = Colors.white);
      }
    }
    if (state == PetState.thinking) {
      for (var i = 0; i < 3; i++) {
        final a = t * 3 + i * 2 * pi / 3;
        canvas.drawCircle(Offset(cos(a) * r * 0.9, -r * 0.9 + sin(a) * r * 0.2), 3,
            Paint()..color = _cyan);
      }
    }
    canvas.restore();

    // Casco de vidrio.
    final helmet = Rect.fromCircle(center: center, radius: r * 1.05);
    canvas.drawCircle(
      center,
      r * 1.05,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [
            Colors.white.withValues(alpha: 0.18),
            (asleep ? const Color(0xFF1A2244) : _cyan).withValues(alpha: asleep ? 0.35 : 0.08),
          ],
        ).createShader(helmet),
    );
    canvas.drawCircle(center, r * 1.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = (asleep ? Colors.white24 : _cyan).withValues(alpha: 0.8));
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.88), pi * 1.1, 0.7, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55));
    // Cuello del traje.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: center + Offset(0, r * 1.08), width: r * 1.3, height: r * 0.26),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    if (asleep) {
      for (var i = 0; i < 3; i++) {
        final ph = (t * 0.5 + i / 3) % 1;
        final tp = TextPainter(
          text: TextSpan(
              text: 'z',
              style: TextStyle(fontFamily: 'Adwaita Sans', color: Colors.white.withValues(alpha: 1 - ph), fontSize: 12 + ph * 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center + Offset(-r * 1.2 - ph * 14, -r * 0.6 - ph * 30));
      }
    }
    if (bell) {
      canvas.drawCircle(center + Offset(-r * 0.9, -r * 0.85), 9, Paint()..color = const Color(0xFFFF5D5D));
      final tp = TextPainter(
        text: const TextSpan(text: '!', style: TextStyle(fontFamily: 'Adwaita Sans', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center + Offset(-r * 0.9 - tp.width / 2, -r * 0.85 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceDogPainter old) => true;
}

// ── Cerebro: esfera 3D ──────────────────────────────────────────────────────

class _CosmosBrain extends StatefulWidget {
  const _CosmosBrain({required this.brain});
  final BrainController brain;
  @override
  State<_CosmosBrain> createState() => _CosmosBrainState();
}

final _cosmosSphere = SphereTheme(
  background: (canvas, size) => const _StarsPainter(seed: 11, count: 380).paint(canvas, size),
  globe: const Color(0xFF1E1B4B).withValues(alpha: 0.55),
  ring: _cyan.withValues(alpha: 0.07),
  edge: Colors.white.withValues(alpha: 0.2),
  edgeLit: _cyan.withValues(alpha: 0.85),
  selected: Colors.white,
  match: const Color(0xFFFFE066),
  reminder: const Color(0xFFFF5D5D),
  label: (selected, depth) => TextStyle(
    fontFamily: 'Adwaita Sans',
    color: Colors.white.withValues(alpha: selected ? 1 : 0.4 + 0.5 * depth),
    fontSize: selected ? 13 : 11,
    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
  ),
);

class _CosmosBrainState extends State<_CosmosBrain> {
  final _sphere = SphereController();
  BrainController get b => widget.brain;

  @override
  void dispose() {
    _sphere.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [b, _sphere],
      builder: (context) {
        final g = b.graph;
        if (g == null) return Center(child: Text(b.error ?? 'Cargando cerebro…', style: const TextStyle(color: _cyan)));
        return Row(children: [
          Expanded(child: SphereView(brain: b, theme: _cosmosSphere, controller: _sphere)),
          _side(context, g),
        ]);
      },
    );
  }

  Widget _side(BuildContext context, MemoryGraph g) {
    final sel = b.selected;
    return Container(
      width: 330,
      decoration: const BoxDecoration(
        color: Color(0xF00A0C1C),
        border: Border(left: BorderSide(color: Color(0x2238BDF8))),
      ),
      padding: const EdgeInsets.all(18),
      child: ListView(children: [
        Row(children: [
          const Text('Cerebro', style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w300)),
          const Spacer(),
          IconButton(
            tooltip: _sphere.spinning ? 'Pausar giro' : 'Girar',
            onPressed: _sphere.toggleSpin,
            icon: Icon(_sphere.spinning ? Icons.pause_circle_outline : Icons.play_circle_outline, color: _cyan),
          ),
        ]),
        Text('${b.visibleNodes.length} recuerdos · ${b.visibleEdges.length} conexiones',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 14),
        TextField(
          onChanged: b.setQuery,
          style: const TextStyle(color: _ink),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
            hintText: 'Buscar en su memoria',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0x1438BDF8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        if (sel != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0x1438BDF8),
              border: Border.all(color: g.colorOf(sel).withValues(alpha: 0.7)),
            ),
            child: NodeDetails(
              brain: b,
              node: sel,
              title: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600),
              body: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
              meta: TextStyle(color: g.colorOf(sel), fontSize: 11, letterSpacing: 0.5),
              linkBuilder: (context, n, onTap) => ActionChip(
                onPressed: onTap,
                label: Text(n.label, style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0x1438BDF8),
                side: BorderSide(color: g.colorOf(n).withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        BrainFilters(
          brain: b,
          titleStyle: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5),
          chip: (context, label, color, selected, onTap) => InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
                border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.45)),
              ),
              child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Arrastra para girar · rueda para acercar · clic en una estrella para leerla',
            style: TextStyle(color: Colors.white30, fontSize: 11)),
      ]),
    );
  }
}

// ── Agenda ──────────────────────────────────────────────────────────────────

class _CosmosAgenda extends StatelessWidget {
  const _CosmosAgenda({required this.rem});
  final RemindersController rem;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _StarsPainter(seed: 5, count: 160))),
      Watch(
        listenables: [rem],
        builder: (context) {
          final groups = rem.grouped();
          return ListView(
            padding: const EdgeInsets.fromLTRB(40, 36, 40, 80),
            children: [
              const Text('Agenda de Laika', style: TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w200)),
              const Text('Lo que te va a recordar, y cuándo.', style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 24),
              for (final e in groups.entries) ...[
                Text(e.key.label.toUpperCase(),
                    style: TextStyle(
                        color: e.key == ReminderGroup.overdue ? const Color(0xFFFF8A8A) : _cyan,
                        letterSpacing: 2,
                        fontSize: 11)),
                const SizedBox(height: 8),
                for (final r in e.value)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xB30B1026),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(children: [
                      Icon(r.isOpen ? Icons.radio_button_unchecked : Icons.check_circle,
                          color: r.isOpen ? _violet : Colors.white30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.text,
                              style: TextStyle(
                                color: r.isOpen ? _ink : Colors.white38,
                                decoration: r.isOpen ? null : TextDecoration.lineThrough,
                              )),
                          Text('${friendlyDate(r.dueAt)} · ${r.status.label}',
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                      ),
                      if (r.isOpen) ...[
                        TextButton(onPressed: () => rem.snooze(r), child: const Text('+1 h')),
                        TextButton(onPressed: () => rem.done(r), child: const Text('Hecho')),
                      ],
                    ]),
                  ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    ]);
  }
}
