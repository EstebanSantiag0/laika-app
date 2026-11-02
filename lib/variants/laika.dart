// DISEÑO FINAL — "Laika" (la mezcla que eligió Esteban el 2026-11-01)
//
//  • Paleta: Cristal (pastel + vidrio esmerilado).
//  • Mensajes: estilo Pixel (cuadro de diálogo que se escribe letra por letra,
//    prompt "> _"), con los colores de Cristal.
//  • Cerebro: la esfera 3D de Cosmos, en versión clara.
//  • Notas y recordatorios: estilo Brutal (bordes gruesos, sombras duras),
//    con los colores de Cristal.
//  • Segundo cerebro: Guardados, Gustos y editar el grafo (laika_saved.dart, laika_edit.dart).
//  • Mascota: cara-círculo estilo Brutal con 16 emociones (lib/pets/circle_face.dart)
//    o una skin de imágenes elegida en Ajustes (lib/pets/skins.dart).

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/brain.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/second_brain.dart';
import '../core/session.dart';
import '../core/sphere_view.dart';
import '../core/stage.dart';
import '../core/widgets.dart';
import '../core/config.dart';
import '../pets/skins.dart';

part 'laika_saved.dart';
part 'laika_edit.dart';

// ── Paleta Cristal ──────────────────────────────────────────────────────────
const lInk = Color(0xFF3B3355);
const lSoft = Color(0xFF8C82A8);
const lAccent = Color(0xFF8B7CF6);
const lLavender = Color(0xFFE9D5FF);
const lPink = Color(0xFFFBCFE8);
const lMint = Color(0xFFD1FAE5);
const lSky = Color(0xFFDBEAFE);
const lPeach = Color(0xFFFFE4E6);
const _sans = 'Adwaita Sans';
const _mono = 'Hack';

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color color = lInk}) =>
    TextStyle(fontFamily: _sans, fontSize: size, fontWeight: w, color: color, height: 1.35);

TextStyle _m(double size, {FontWeight w = FontWeight.w400, Color color = lInk}) => TextStyle(
    fontFamily: _mono, fontFamilyFallback: const ['Liberation Mono', 'monospace'], fontSize: size, fontWeight: w, color: color, height: 1.4);

/// Caja "brutal" con colores de Cristal: borde grueso tinta + sombra dura.
BoxDecoration brutalBox(Color fill, {double shadow = 5, double border = 2.5}) => BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: lInk, width: border),
      boxShadow: shadow > 0 ? [BoxShadow(color: lInk, offset: Offset(shadow, shadow))] : null,
    );

final laikaSpec = VariantSpec(
  id: 'laika',
  name: 'Laika (mezcla elegida)',
  tagline: 'Paleta Cristal, mensajes Pixel, cerebro-esfera de Cosmos y notas Brutal. cara con 16 emociones, segundo cerebro y skins propias.',
  swatch: const [lLavender, lPink, lMint, lAccent],
  build: (s) => LaikaApp(session: s),
);

/// Fondo pastel con manchas de luz que se mueven despacio.
class Aurora extends StatefulWidget {
  const Aurora({super.key});
  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(animation: _c, builder: (context, _) => CustomPaint(painter: _AuroraPainter(_c.value * 6.283))),
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
          Paint()
            ..shader = RadialGradient(colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.a != a;
}

// ── La mascota y sus mensajes ───────────────────────────────────────────────

/// [transparent]: en el escritorio real no hay fondo (solo Laika y sus mensajes).
class LaikaSkin extends PetSkin {
  const LaikaSkin({this.transparent = false});
  final bool transparent;

  @override
  double get petSize => config.value.petSize;

  @override
  double get chatWidth => 330;

  @override
  Widget backdrop(BuildContext context) => transparent
      ? const SizedBox.expand()
      : Stack(children: [
          const Positioned.fill(child: Aurora()),
          Positioned(
            left: 28,
            top: 74,
            child: Text('Pasa el mouse sobre Laika para despertarla · 1 clic: escribir · 2 clics: abrir la app',
                style: _t(13, color: lSoft)),
          ),
        ]);

  @override
  Widget pet(BuildContext context, PetController c, double t) => currentLook.value
      .build(c.mood, lying: c.sleepPose == SleepPose.lying, t: t, bell: c.pendingReminders.isNotEmpty);

  /// Cuadro de diálogo estilo Pixel (doble borde, letra por letra) en colores Cristal.
  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          border: Border.all(color: lInk, width: 3),
          boxShadow: [BoxShadow(color: lAccent.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(border: Border.all(color: lLavender, width: 2)),
          child: TweenAnimationBuilder<int>(
            key: ValueKey(text),
            tween: IntTween(begin: 0, end: text.length),
            duration: Duration(milliseconds: 22 * text.length),
            builder: (context, n, _) => Text(
              '${text.substring(0, n)}${n == text.length && age == 0 ? ' ▼' : ''}',
              style: _m(13.5),
            ),
          ),
        ),
      );

  @override
  /// "Escribiendo…": los cuadritos que brincan de Brutal, en negro (Esteban).
  Widget typing(BuildContext context, double t, {required bool petOnRight}) => Padding(
        padding: const EdgeInsets.only(top: 8, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.only(right: 7),
                width: 13,
                height: 13,
                transform: Matrix4.translationValues(0, -6 * max(0, sin(t * 7 - i)), 0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [BoxShadow(color: lAccent.withValues(alpha: 0.55), offset: const Offset(3, 3))],
                ),
              ),
          ],
        ),
      );

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) =>
      Text('tú> $text', maxLines: 2, overflow: TextOverflow.ellipsis, style: _m(11.5, color: lSoft));

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Container(
        decoration: BoxDecoration(
          color: lInk,
          border: Border.all(color: lInk, width: 2),
          boxShadow: [BoxShadow(color: lAccent.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(children: [
          Text('> ', style: _m(15, color: lPink, w: FontWeight.w700)),
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onSubmitted: (_) => onSend(),
              style: _m(14.5, color: Colors.white),
              cursorColor: lMint,
              cursorWidth: 9,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'escribe y pulsa Enter',
                hintStyle: _m(13, color: lSoft),
              ),
            ),
          ),
        ]),
      );

  /// (+) ____________ (🎤): todo dentro de la misma caja oscura. Con texto o
  /// grabando, el micrófono se vuelve el avioncito de enviar (Esteban).
  @override
  Widget composer(BuildContext context, Composer k, {required bool petOnRight}) {
    final rec = k.recordingFor;
    return Container(
      decoration: BoxDecoration(
        color: lInk,
        border: Border.all(color: lInk, width: 2),
        boxShadow: [BoxShadow(color: lAccent.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(children: [
        _round(Icons.add_rounded, k.onPlus, fill: k.menuOpen ? lLavender : Colors.transparent,
            color: k.menuOpen ? lInk : lLavender, key: const ValueKey('pet-plus')),
        const SizedBox(width: 4),
        Expanded(
          child: rec != null
              ? Row(children: [
                  const Icon(Icons.fiber_manual_record, size: 12, color: Color(0xFFF43F5E)),
                  const SizedBox(width: 6),
                  Text(Composer.clock(rec), style: _m(14, color: Colors.white, w: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('grabando…', overflow: TextOverflow.ellipsis, style: _m(13, color: lSoft))),
                  GestureDetector(
                    key: const ValueKey('pet-cancel-recording'),
                    onTap: k.onCancelRecording,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: lPink),
                    ),
                  ),
                ])
              : TextField(
                  controller: k.text,
                  focusNode: k.focus,
                  onSubmitted: (_) => k.onSend(),
                  style: _m(14.5, color: Colors.white),
                  cursorColor: lMint,
                  cursorWidth: 9,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'escribe…',
                    hintStyle: _m(13, color: lSoft),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        k.showSend
            ? _round(Icons.send_rounded, k.onSend, fill: lMint, color: lInk, key: const ValueKey('pet-send'))
            : _round(Icons.mic_rounded, k.onMic, fill: Colors.transparent, color: lLavender, key: const ValueKey('pet-mic')),
      ]),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {required Color fill, required Color color, Key? key}) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      );

  @override
  Widget chip(BuildContext context, String label, {bool selected = false, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: brutalBox(selected ? lLavender : Colors.white, shadow: 2, border: 1.5),
            child: Text(label, style: _m(12, w: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget menu(BuildContext context, List<MenuEntry> items) => Container(
        decoration: brutalBox(Colors.white, shadow: 3, border: 2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in items)
            GestureDetector(
              onTap: e.onTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Icon(e.icon, size: 18, color: lInk),
                    const SizedBox(width: 10),
                    Text(e.label, style: _m(13, w: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final s = statusText(c);
    if (s == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: brutalBox(c.wakeFailed ? lPink : Colors.white, shadow: 2, border: 1.5),
      child: Text(s, style: _m(11, color: c.wakeFailed ? const Color(0xFFBE185D) : lInk)),
    );
  }
}

// ── La app (doble clic sobre Laika) ─────────────────────────────────────────

class LaikaApp extends StatefulWidget {
  const LaikaApp({super.key, required this.session, this.showDesktop = true, this.initialTab = 0});
  final LaikaSession session;

  /// En los prototipos se muestra también el escritorio simulado. En la app
  /// real (ventana normal) Laika ya está en tu escritorio de verdad.
  final bool showDesktop;
  final int initialTab;

  @override
  State<LaikaApp> createState() => _LaikaAppState();
}

class _LaikaAppState extends State<LaikaApp> {
  late int tab = widget.initialTab;

  List<(String, Widget Function())> get _tabs => [
        if (widget.showDesktop)
          ('Escritorio', () => ValueListenableBuilder(
                valueListenable: config,
                builder: (context, cfg, _) => PetStage(
                    key: ValueKey(cfg.petSize),
                    controller: widget.session.pet,
                    skin: const LaikaSkin(),
                    onOpenApp: () => setState(() => tab = 1)),
              )),
        ('Cerebro', () => LaikaBrain(brain: widget.session.brain)),
        ('Guardados', () => LaikaSaved(saved: widget.session.saved, areas: widget.session.brain.graph?.areas ?? const [])),
        ('Gustos', () => LaikaLikes(saved: widget.session.saved)),
        ('Agenda', () => LaikaAgenda(rem: widget.session.reminders)),
        ('Emociones', () => const MoodSheet()),
        ('Ajustes', () => const LaikaSettings()),
      ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final i = tab.clamp(0, tabs.length - 1);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laika',
      theme: ThemeData(
        fontFamily: _sans,
        colorScheme: ColorScheme.fromSeed(seedColor: lAccent),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: lAccent),
      ),
      home: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: Aurora()),
          Positioned.fill(child: tabs[i].$2()),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Frosted(
                radius: 30,
                padding: const EdgeInsets.all(5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var k = 0; k < tabs.length; k++)
                    GestureDetector(
                      onTap: () => setState(() => tab = k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: k == i ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(tabs[k].$1, style: _t(14, w: k == i ? FontWeight.w600 : FontWeight.w400)),
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

// ── Cerebro: esfera de Cosmos en versión clara ──────────────────────────────

final _lightSphere = SphereTheme(
  globe: Colors.white.withValues(alpha: 0.55),
  ring: lAccent.withValues(alpha: 0.12),
  edge: lInk.withValues(alpha: 0.18),
  edgeLit: lAccent,
  selected: lInk,
  match: const Color(0xFFEC4899),
  reminder: const Color(0xFFEC4899),
  nodeBorder: Colors.white,
  labelPill: Colors.white.withValues(alpha: 0.85),
  label: (selected, depth) => _t(selected ? 12.5 : 11, w: selected ? FontWeight.w700 : FontWeight.w500, color: lInk.withValues(alpha: 0.55 + 0.45 * depth)),
);

class LaikaBrain extends StatefulWidget {
  const LaikaBrain({super.key, required this.brain});
  final BrainController brain;
  @override
  State<LaikaBrain> createState() => _LaikaBrainState();
}

class _LaikaBrainState extends State<LaikaBrain> {
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
        if (g == null) return Center(child: Text(b.error ?? 'Cargando cerebro…', style: _t(16, color: lSoft)));
        final sel = b.selected;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 70, 16, 16),
          child: Row(children: [
            Expanded(child: SphereView(brain: b, theme: _lightSphere, controller: _sphere)),
            const SizedBox(width: 12),
            SizedBox(
              width: 340,
              child: ListView(padding: const EdgeInsets.only(bottom: 60, right: 8), children: [
                Row(children: [
                  Text('Cerebro', style: _t(26, w: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Papelera',
                    onPressed: () => showTrash(context, b),
                    icon: const Icon(Icons.delete_outline_rounded, color: lInk),
                  ),
                  IconButton(
                    tooltip: _sphere.spinning ? 'Pausar giro' : 'Girar',
                    onPressed: _sphere.toggleSpin,
                    icon: Icon(_sphere.spinning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: lInk),
                  ),
                ]),
                Text('${b.visibleNodes.length} recuerdos · arrastra para girar · rueda para acercar', style: _t(12, color: lSoft)),
                const SizedBox(height: 12),
                Container(
                  decoration: brutalBox(Colors.white, shadow: 3),
                  child: TextField(
                    onChanged: b.setQuery,
                    style: _t(14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(11),
                      hintText: 'Buscar en su memoria',
                      hintStyle: _t(14, color: lSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (sel != null) ...[
                  NoteCard(brain: b, node: sel, graph: g),
                  const SizedBox(height: 12),
                  NodeActions(brain: b, node: sel),
                  const SizedBox(height: 18),
                ],
                BrainFilters(
                  brain: b,
                  spacing: 7,
                  titleStyle: _t(13, w: FontWeight.w800),
                  chip: (context, label, color, selected, onTap) => GestureDetector(
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: brutalBox(selected ? color.withValues(alpha: 0.35) : Colors.white, shadow: selected ? 0 : 2, border: 1.5),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(label, style: _t(12, w: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

/// Nota de un recuerdo, estilo Brutal con colores Cristal.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.brain, required this.node, required this.graph});
  final BrainController brain;
  final MemoryNode node;
  final MemoryGraph graph;

  @override
  Widget build(BuildContext context) {
    final col = graph.colorOf(node);
    return Container(
      decoration: brutalBox(Color.lerp(Colors.white, col, 0.18)!, shadow: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 10, decoration: BoxDecoration(color: col, border: const Border(bottom: BorderSide(color: lInk, width: 2.5)))),
        Padding(
          padding: const EdgeInsets.all(14),
          child: NodeDetails(
            brain: brain,
            node: node,
            title: _t(19, w: FontWeight.w800),
            body: _t(14),
            meta: _t(11.5, w: FontWeight.w700, color: lSoft),
            linkBuilder: (context, n, onTap) => GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: brutalBox(Colors.white, shadow: 2, border: 1.5),
                child: Text(n.label, style: _t(11.5, w: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Agenda: tarjetas estilo Brutal, colores Cristal ─────────────────────────

class LaikaAgenda extends StatelessWidget {
  const LaikaAgenda({super.key, required this.rem});
  final RemindersController rem;

  static const _groupColor = {
    ReminderGroup.overdue: lPink,
    ReminderGroup.today: lPeach,
    ReminderGroup.tomorrow: lSky,
    ReminderGroup.later: lMint,
    ReminderGroup.done: Color(0xFFF1EEF8),
  };

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [rem],
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Agenda', style: _t(44, w: FontWeight.w900)),
          Text('Laika te avisa a la hora. Si su ventana no está abierta, por Telegram.', style: _t(13, color: lSoft)),
          const SizedBox(height: 20),
          for (final e in rem.grouped().entries) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: brutalBox(_groupColor[e.key]!, shadow: 2, border: 2),
              child: Text(e.key.label.toUpperCase(), style: _t(12, w: FontWeight.w900)),
            ),
            Wrap(spacing: 18, runSpacing: 18, children: [
              for (final r in e.value)
                SizedBox(
                  width: 290,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: brutalBox(r.isOpen ? Colors.white : const Color(0xFFF4F1FA)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.text, style: _t(17, w: FontWeight.w800, color: r.isOpen ? lInk : lSoft)),
                        const SizedBox(height: 4),
                        Text(
                          '${friendlyDate(r.dueAt)}${r.timeDefaulted ? ' (hora elegida por Laika)' : ''}',
                          style: _t(12, w: FontWeight.w600, color: lSoft),
                        ),
                        if (r.isOpen) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            _btn('Hecho', lMint, () => rem.done(r)),
                            const SizedBox(width: 10),
                            _btn('+1 h', lSky, () => rem.snooze(r)),
                          ]),
                        ],
                      ]),
                    ),
                    if (!r.isOpen)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Transform.rotate(
                          angle: -0.22,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(border: Border.all(color: lAccent, width: 2.5)),
                            child: Text('HECHO', style: _t(15, w: FontWeight.w900, color: lAccent)),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: brutalBox(color, shadow: 3, border: 2),
          child: Text(label, style: _t(13, w: FontWeight.w800)),
        ),
      );
}

// ── Emociones de Laika ──────────────────────────────────────────────────────

/// Todas las caras de Laika y cuándo las pone.
class MoodSheet extends StatefulWidget {
  const MoodSheet({super.key});
  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final _watch = Stopwatch()..start();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _card(PetSkinLook look, String label, String when, Mood mood, {bool lying = false}) => Container(
        width: 180,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        decoration: brutalBox(Colors.white, shadow: 4, border: 2),
        child: Column(children: [
          SizedBox(
            height: 150,
            width: 150,
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) => look.build(mood, lying: lying, t: _watch.elapsedMilliseconds / 1000),
            ),
          ),
          Text(label, style: _t(15, w: FontWeight.w900)),
          Text(when, textAlign: TextAlign.center, style: _t(11.5, color: lSoft)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentLook,
      builder: (context, look, _) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Emociones', style: _t(44, w: FontWeight.w900)),
          Text('Laika cambia de cara según lo que pasa y lo que dice. Las reacciones duran unos segundos. '
              'Skin: ${look.name} (se cambia en Ajustes).',
              style: _t(13, color: lSoft)),
          const SizedBox(height: 22),
          Wrap(spacing: 18, runSpacing: 18, children: [
            for (final m in Mood.values)
              if (m == Mood.sleeping) ...[
                _card(look, 'Dormida', 'tras 15 s sin hacerle caso', m),
                _card(look, 'Dormida profunda', '15 s después', m, lying: true),
              ] else
                _card(look, m.label, m.when, m),
          ]),
        ],
      ),
    );
  }
}

// ── Ajustes ─────────────────────────────────────────────────────────────────

/// Skin, tamaño de Laika y servidor. Se guarda en ~/.config/laika/config.json;
/// la mascota del escritorio (--pet) lo nota al instante.
class LaikaSettings extends StatefulWidget {
  const LaikaSettings({super.key});
  @override
  State<LaikaSettings> createState() => _LaikaSettingsState();
}

class _LaikaSettingsState extends State<LaikaSettings> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final _watch = Stopwatch()..start();
  late final _server = TextEditingController(text: config.value.server ?? '');
  List<PetSkinLook> _skins = availableSkins();
  String? _saved;

  @override
  void dispose() {
    _a.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _set(LaikaConfig next, String msg) async {
    await updateConfig(next);
    if (mounted) setState(() => _saved = msg);
  }

  Widget _section(String title, String hint, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.all(18),
        decoration: brutalBox(Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _t(20, w: FontWeight.w900)),
          Text(hint, style: _t(12.5, color: lSoft)),
          const SizedBox(height: 14),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: config,
      builder: (context, cfg, _) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Ajustes', style: _t(44, w: FontWeight.w900)),
          Text(_saved ?? 'Se guardan en ~/.config/laika/config.json (fuera del repositorio).', style: _t(13, color: lSoft)),
          const SizedBox(height: 22),
          _section(
            'Skin',
            'Cómo se ve Laika. Para agregar una: una carpeta con una imagen por emoción en '
                '~/.config/laika/skins/ (ver docs/SKINS.md).',
            Wrap(spacing: 16, runSpacing: 16, children: [
              for (final s in _skins)
                GestureDetector(
                  onTap: () => _set(cfg.copyWith(skin: s.id), 'Skin: ${s.name} ✓'),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: brutalBox(s.id == cfg.skin ? lLavender : Colors.white, shadow: s.id == cfg.skin ? 2 : 5, border: 2),
                    child: Column(children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: AnimatedBuilder(
                          animation: _a,
                          builder: (context, _) => s.build(Mood.neutral, t: _watch.elapsedMilliseconds / 1000),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(s.name, style: _t(14, w: FontWeight.w800)),
                      Text(s.id == cfg.skin ? '✓ en uso' : 'Elegir',
                          style: _t(12, w: FontWeight.w700, color: s.id == cfg.skin ? lAccent : lSoft)),
                    ]),
                  ),
                ),
              GestureDetector(
                onTap: () => setState(() => _skins = availableSkins()),
                child: Container(
                  width: 150,
                  height: 170,
                  alignment: Alignment.center,
                  decoration: brutalBox(lMint, shadow: 5, border: 2),
                  child: Text('↻ Buscar skins', style: _t(14, w: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          _section(
            'Tamaño en el escritorio',
            'Qué tan grande se ve Laika: ${cfg.petSize.round()} px.',
            Slider(
              value: cfg.petSize,
              min: 80,
              max: 300,
              divisions: 22,
              activeColor: lAccent,
              label: '${cfg.petSize.round()} px',
              onChanged: (v) => config.value = cfg.copyWith(petSize: v),
              onChangeEnd: (v) => _set(cfg.copyWith(petSize: v), 'Tamaño: ${v.round()} px ✓'),
            ),
          ),
          _section(
            'Servidor',
            'Dirección de tu servidor de Laika por Tailscale. Vacío = servidor simulado. '
                'Se usa la próxima vez que abras Laika.',
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _server,
                  style: _m(13),
                  decoration: InputDecoration(
                    hintText: 'https://tu-servidor.tu-tailnet.ts.net',
                    hintStyle: _m(13, color: lSoft),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final v = _server.text.trim();
                  _set(v.isEmpty ? cfg.copyWith(clearServer: true) : cfg.copyWith(server: v),
                      v.isEmpty ? 'Servidor simulado ✓' : 'Servidor guardado ✓');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: brutalBox(lPink, shadow: 3, border: 2),
                  child: Text('Guardar', style: _t(14, w: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
