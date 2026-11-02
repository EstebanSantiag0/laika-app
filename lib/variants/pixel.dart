// VARIANTE 3 — PIXEL
// Consola portátil retro de 4 tonos de verde: Laika es un sprite de 16×16,
// sus mensajes son cuadros de diálogo de videojuego que se escriben letra por
// letra, y el cerebro es un mapa de "cuartos" (uno por área de tu vida).
// Atajos: F1 Escritorio · F2 Cerebro · F3 Agenda.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brain.dart';
import '../core/layouts.dart';
import '../core/models.dart';
import '../core/pet.dart';
import '../core/session.dart';
import '../core/stage.dart';
import '../core/widgets.dart';

const _c0 = Color(0xFF0F380F); // más oscuro
const _c1 = Color(0xFF306230);
const _c2 = Color(0xFF8BAC0F);
const _c3 = Color(0xFF9BBC0F); // más claro
const _mono = 'Hack';

TextStyle _px(double size, {Color color = _c0, bool bold = false}) => TextStyle(
      fontFamily: _mono,
      fontFamilyFallback: const ['Liberation Mono', 'monospace'],
      fontSize: size,
      color: color,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      height: 1.35,
      letterSpacing: 0.5,
    );

final pixelSpec = VariantSpec(
  id: 'pixel',
  name: 'Pixel',
  tagline: 'Consola retro verde: Laika en 16×16, diálogos que se escriben solos y un mapa de cuartos.',
  swatch: const [_c0, _c1, _c2, _c3],
  build: (s) => _PixelApp(session: s),
);

class _PixelApp extends StatefulWidget {
  const _PixelApp({required this.session});
  final LaikaSession session;
  @override
  State<_PixelApp> createState() => _PixelAppState();
}

class _PixelAppState extends State<_PixelApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: _c2,
        fontFamily: _mono,
        colorScheme: const ColorScheme.light(primary: _c0, surface: _c3),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: _c0, selectionColor: _c1),
      ),
      home: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f1): () => setState(() => tab = 0),
          const SingleActivator(LogicalKeyboardKey.f2): () => setState(() => tab = 1),
          const SingleActivator(LogicalKeyboardKey.f3): () => setState(() => tab = 2),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Column(children: [
              _MenuBar(tab: tab, onTab: (i) => setState(() => tab = i)),
              Expanded(
                child: IndexedStack(index: tab, children: [
                  PetStage(controller: s.pet, skin: const _PixelSkin()),
                  _PixelBrain(brain: s.brain),
                  _PixelAgenda(rem: s.reminders),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MenuBar extends StatelessWidget {
  const _MenuBar({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    const items = ['ESCRITORIO', 'CEREBRO', 'AGENDA'];
    return Container(
      color: _c0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Text('LAIKA-OS ', style: _px(14, color: _c3, bold: true)),
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            onTap: () => onTab(i),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: i == tab ? _c3 : _c0,
              child: Text('[F${i + 1}] ${items[i]}', style: _px(13, color: i == tab ? _c0 : _c2)),
            ),
          ),
        const Spacer(),
        Text('♥♥♥', style: _px(14, color: _c2)),
      ]),
    );
  }
}

/// Caja con doble borde de píxel.
class _PixBox extends StatelessWidget {
  const _PixBox({required this.child});
  final Widget child;
  static const fill = _c3;
  static const padding = EdgeInsets.all(10);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: fill, border: Border.all(color: _c0, width: 4)),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: padding,
          decoration: BoxDecoration(border: Border.all(color: _c1, width: 2)),
          child: child,
        ),
      );
}

// ── Sprites ─────────────────────────────────────────────────────────────────
// Se define la mitad izquierda (8 columnas) y se refleja: la cara es simétrica.
// '.' transparente · '0' a '3' = tonos de la paleta.

const _awake = [
  '........', '.00.....', '0110....', '01110000', '01133333', '01333333', '03333333', '03333333',
  '03300333', '03300333', '03333300', '03333330', '00333332', '.0033333', '..000000', '........',
];
const _blink = [
  '........', '.00.....', '0110....', '01110000', '01133333', '01333333', '03333333', '03333333',
  '03333333', '03000333', '03333300', '03333330', '00333332', '.0033333', '..000000', '........',
];
const _lookUp = [
  '........', '.00.....', '0110....', '01110000', '01133333', '01333333', '03300333', '03300333',
  '03333333', '03333333', '03333300', '03333330', '00333333', '.0033333', '..000000', '........',
];
const _halfOpen = [
  '........', '.00.....', '0110....', '01110000', '01133333', '01333333', '03333333', '03333333',
  '03333333', '03300333', '03333300', '03333330', '00333333', '.0033333', '..000000', '........',
];
const _sleep = [
  '........', '........', '........', '........', '...00000', '.0033333', '01133333', '01133333',
  '01333333', '03000333', '03333333', '03333300', '03333333', '00333333', '.0000000', '........',
];

const _pal = [_c0, _c1, _c2, _c3];

void _drawSprite(Canvas canvas, List<String> half, Offset o, double px) {
  final paint = Paint();
  for (var y = 0; y < half.length; y++) {
    final row = half[y] + half[y].split('').reversed.join();
    for (var x = 0; x < row.length; x++) {
      final ch = row[x];
      if (ch == '.') continue;
      paint.color = _pal[int.parse(ch)];
      canvas.drawRect(Rect.fromLTWH(o.dx + x * px, o.dy + y * px, px + 0.5, px + 0.5), paint);
    }
  }
}

/// Letras de píxel mínimas para "Z".
void _drawZ(Canvas canvas, Offset o, double px, Color color) {
  const z = ['1111', '..1.', '.1..', '1111'];
  final p = Paint()..color = color;
  for (var y = 0; y < z.length; y++) {
    for (var x = 0; x < 4; x++) {
      if (z[y][x] == '1') canvas.drawRect(Rect.fromLTWH(o.dx + x * px, o.dy + y * px, px, px), p);
    }
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({required this.state, required this.t, required this.bell});
  final PetState state;
  final double t;
  final bool bell;

  @override
  void paint(Canvas canvas, Size size) {
    final px = (size.width / 20).floorToDouble();
    final o = Offset((size.width - px * 16) / 2, (size.height - px * 16) / 2 + px);
    final frame = (t * 2).floor();
    // Sombra.
    canvas.drawRect(Rect.fromLTWH(o.dx + px * 3, o.dy + px * 15, px * 10, px), Paint()..color = _c1);
    switch (state) {
      case PetState.asleep:
        _drawSprite(canvas, _sleep, o, px);
        final k = frame % 3;
        for (var i = 0; i <= k; i++) {
          _drawZ(canvas, o + Offset(px * (13 + i * 2), px * (3 - i * 3)), px * (0.6 + i * 0.2), _c0);
        }
      case PetState.waking:
        _drawSprite(canvas, _halfOpen, o, px);
        if (frame.isEven) {
          canvas.drawRect(Rect.fromLTWH(o.dx + px * 7, o.dy - px * 2, px * 2, px * 2), Paint()..color = _c0);
        }
      case PetState.thinking:
        _drawSprite(canvas, _lookUp, o + Offset(0, -px * (frame % 2)), px);
        for (var i = 0; i < 3; i++) {
          if (i <= frame % 4) {
            canvas.drawRect(Rect.fromLTWH(o.dx + px * (12 + i * 2), o.dy - px * (1 + i), px, px), Paint()..color = _c0);
          }
        }
      case PetState.awake:
        final blink = (t % 3.3) < 0.18;
        _drawSprite(canvas, blink ? _blink : _awake, o + Offset(0, -px * (frame % 2)), px);
    }
    if (bell) {
      final p = Paint()..color = _c0;
      canvas.drawRect(Rect.fromLTWH(o.dx - px, o.dy, px * 3, px * 3), p);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy + px * 0.5, px, px * 1.2), Paint()..color = _c3);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy + px * 2, px, px * 0.6), Paint()..color = _c3);
    }
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) => true;
}

// ── Escritorio ──────────────────────────────────────────────────────────────

class _PixelSkin extends PetSkin {
  const _PixelSkin();

  @override
  double get petSize => 160;

  @override
  double get chatWidth => 340;

  @override
  Widget backdrop(BuildContext context) => const CustomPaint(painter: _Scanlines(title: true));

  @override
  Widget pet(BuildContext context, PetController c, double t) =>
      CustomPaint(painter: _SpritePainter(state: c.state, t: t, bell: c.pendingReminders.isNotEmpty));

  @override
  Widget bubble(BuildContext context, String text, {required bool petOnRight, required int age}) =>
      _PixBox(
        child: TweenAnimationBuilder<int>(
          key: ValueKey(text),
          tween: IntTween(begin: 0, end: text.length),
          duration: Duration(milliseconds: 25 * text.length),
          builder: (context, n, _) => Text(
            '${text.substring(0, n)}${n == text.length && age == 0 ? ' ▼' : ''}',
            style: _px(14),
          ),
        ),
      );

  @override
  Widget typing(BuildContext context, double t, {required bool petOnRight}) =>
      Text('LAIKA ESCRIBE${'.' * (1 + (t * 4).floor() % 3)}', style: _px(12, color: _c0, bold: true));

  @override
  Widget mine(BuildContext context, String text, {required bool petOnRight}) =>
      Text('TÚ> $text', maxLines: 2, overflow: TextOverflow.ellipsis, style: _px(12, color: _c1));

  @override
  Widget input(BuildContext context, TextEditingController text, FocusNode focus, VoidCallback onSend,
          {required bool petOnRight}) =>
      Container(
        color: _c0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(children: [
          Text('> ', style: _px(15, color: _c3, bold: true)),
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onSubmitted: (_) => onSend(),
              style: _px(15, color: _c3),
              cursorColor: _c3,
              cursorWidth: 9,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'ESCRIBE Y PULSA ENTER',
                hintStyle: _px(13, color: _c1),
              ),
            ),
          ),
        ]),
      );

  @override
  Widget? status(BuildContext context, PetController c, double t) {
    final String? s;
    if (c.wakeFailed) {
      s = 'SIN SEÑAL';
    } else if (c.state == PetState.waking) {
      s = 'CONECTANDO${'.' * (1 + (t * 4).floor() % 3)}';
    } else if (c.justLearned != null) {
      s = '+1 RECUERDO';
    } else {
      s = null;
    }
    if (s == null) return null;
    return Container(color: _c0, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), child: Text(s, style: _px(12, color: _c3)));
  }
}

class _Scanlines extends CustomPainter {
  const _Scanlines({this.title = false});
  final bool title;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _c2);
    final dot = Paint()..color = _c1.withValues(alpha: 0.18);
    for (var y = 0.0; y < size.height; y += 8) {
      for (var x = (y / 8).floor().isEven ? 0.0 : 4.0; x < size.width; x += 8) {
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), dot);
      }
    }
    final line = Paint()..color = _c0.withValues(alpha: 0.06);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
    if (title) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'LAIKA-OS v0.1\n> PASA EL MOUSE SOBRE LAIKA PARA DESPERTARLA\n> ARRÁSTRALA PARA MOVERLA',
          style: _px(13, color: _c0),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, const Offset(20, 16));
    }
  }

  @override
  bool shouldRepaint(covariant _Scanlines old) => false;
}

// ── Cerebro: mapa de cuartos ────────────────────────────────────────────────

class _PixelBrain extends StatelessWidget {
  const _PixelBrain({required this.brain});
  final BrainController brain;

  @override
  Widget build(BuildContext context) {
    final b = brain;
    return Watch(
      listenables: [b],
      builder: (context) {
        final g = b.graph;
        if (g == null) return Center(child: Text(b.error ?? 'CARGANDO MAPA...', style: _px(16)));
        final sel = b.selected;
        return Row(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              const row = 19.0;
              final lay = roomsLayout(g.areas, b.visibleNodes, box.biggest, row);
              // Zona de clic: todo el renglón (ícono + nombre).
              final hits = {for (final e in lay.cells.entries) e.key: e.value + Offset(lay.colWidth / 2 - 10, 0)};
              return Stack(children: [
                const Positioned.fill(child: CustomPaint(painter: _Scanlines())),
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (d) => b.select(hitTest(hits, d.localPosition, radius: lay.colWidth / 2)),
                    child: CustomPaint(
                      painter: _RoomsPainter(brain: b, graph: g, rooms: lay.rooms, cells: lay.cells, colWidth: lay.colWidth, row: row),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          Container(
            width: 300,
            color: _c0,
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 70), children: [
              Text('MAPA DEL CEREBRO', style: _px(15, color: _c3, bold: true)),
              Text('${b.visibleNodes.length} RECUERDOS', style: _px(11, color: _c2)),
              const SizedBox(height: 10),
              if (sel != null) ...[
                _PixBox(
                  child: NodeDetails(
                    brain: b,
                    node: sel,
                    title: _px(15, bold: true),
                    body: _px(12),
                    meta: _px(10, color: _c1),
                    linkBuilder: (context, n, onTap) => GestureDetector(
                      onTap: onTap,
                      child: Container(
                        color: _c0,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text('► ${n.label}', style: _px(11, color: _c3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                onChanged: b.setQuery,
                style: _px(13, color: _c3),
                cursorColor: _c3,
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: 'BUSCAR> ',
                  prefixStyle: _px(13, color: _c2),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _c2)),
                ),
              ),
              const SizedBox(height: 14),
              BrainFilters(
                brain: b,
                titleStyle: _px(12, color: _c2, bold: true),
                chip: (context, label, color, selected, onTap) => GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: selected ? _c3 : _c1,
                    child: Text('${selected ? '[x]' : '[ ]'} ${label.toUpperCase()}', style: _px(11, color: selected ? _c0 : _c3)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('LEYENDA\n■ ENTIDAD   ▪ DATO\n+ CONVERSACIÓN\n! RECORDATORIO   □ ARCHIVADO', style: _px(11, color: _c2)),
            ]),
          ),
        ]);
      },
    );
  }
}

class _RoomsPainter extends CustomPainter {
  _RoomsPainter({
    required this.brain,
    required this.graph,
    required this.rooms,
    required this.cells,
    required this.colWidth,
    required this.row,
  });
  final BrainController brain;
  final MemoryGraph graph;
  final Map<String, Rect> rooms;
  final Map<String, Offset> cells;
  final double colWidth, row;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = _c0;
    final mid = Paint()..color = _c1;
    final light = Paint()..color = _c3;
    for (final a in graph.areas) {
      final r = rooms[a.id]!;
      if (brain.areaFilter.isNotEmpty && !brain.areaFilter.contains(a.id)) {
        canvas.drawRect(r, Paint()..color = _c1.withValues(alpha: 0.25));
        continue;
      }
      canvas.drawRect(r, light);
      canvas.drawRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _c0);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 22), dark);
      final tp = TextPainter(
        text: TextSpan(text: '${a.name.toUpperCase()} (${brain.countIn(a.id)})', style: _px(11, color: _c3, bold: true)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: r.width - 10);
      tp.paint(canvas, Offset(r.left + 6, r.top + 4));
    }

    final sel = brain.selectedId;
    final linked = sel == null ? <String>{} : brain.neighbors(sel).map((n) => n.id).toSet();
    // Pasillos: solo las conexiones del recuerdo elegido, en escalón.
    if (sel != null && cells[sel] != null) {
      for (final id in linked) {
        final a = cells[sel]!, b = cells[id];
        if (b == null) continue;
        final corner = Offset(b.dx, a.dy);
        for (final (s, t) in [(a, corner), (corner, b)]) {
          final len = (t - s).distance;
          for (var d = 0.0; d < len; d += 6) {
            canvas.drawRect(Rect.fromCenter(center: s + (t - s) * (d / len), width: 3, height: 3), dark);
          }
        }
      }
    }

    for (final entry in cells.entries) {
      final n = graph.nodeById[entry.key]!;
      final o = entry.value;
      final isSel = n.id == sel;
      final hot = isSel || linked.contains(n.id) || brain.matches(n);
      if (hot) {
        canvas.drawRect(Rect.fromLTWH(o.dx - 8, o.dy - row / 2 + 1, colWidth - 8, row - 2), isSel ? dark : mid);
      }
      final ink = hot ? light : dark;
      final s = n.kind == NodeKind.entity ? 10.0 : 7.0;
      final rect = Rect.fromCenter(center: o, width: s, height: s);
      switch (n.kind) {
        case NodeKind.episode:
          canvas.drawRect(Rect.fromCenter(center: o, width: 9, height: 3), ink);
          canvas.drawRect(Rect.fromCenter(center: o, width: 3, height: 9), ink);
        case NodeKind.reminder:
          canvas.drawRect(Rect.fromLTWH(o.dx - 1.5, o.dy - 5, 3, 6), ink);
          canvas.drawRect(Rect.fromLTWH(o.dx - 1.5, o.dy + 3, 3, 2), ink);
        default:
          if (n.timeScope == TimeScope.archived) {
            canvas.drawRect(rect, Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = ink.color);
          } else {
            canvas.drawRect(rect, ink);
          }
      }
      final tp = TextPainter(
        text: TextSpan(
          text: n.kind == NodeKind.entity ? n.label.toUpperCase() : n.label,
          style: _px(10.5, color: hot ? _c3 : (n.timeScope == TimeScope.archived ? _c1 : _c0), bold: n.kind == NodeKind.entity),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: colWidth - 30);
      tp.paint(canvas, Offset(o.dx + 10, o.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RoomsPainter old) => true;
}

// ── Agenda: registro de misiones ────────────────────────────────────────────

class _PixelAgenda extends StatelessWidget {
  const _PixelAgenda({required this.rem});
  final RemindersController rem;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _Scanlines())),
      Watch(
        listenables: [rem],
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
          children: [
            _PixBox(
              child: Text('REGISTRO DE MISIONES\nLAIKA TE AVISA CUANDO LLEGUE LA HORA.', style: _px(15, bold: true)),
            ),
            const SizedBox(height: 14),
            for (final e in rem.grouped().entries) ...[
              Container(
                color: _c0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text('== ${e.key.label.toUpperCase()} ==', style: _px(13, color: _c3, bold: true)),
              ),
              for (final r in e.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(r.isOpen ? '[ ] ' : '[X] ', style: _px(15, bold: true)),
                    Expanded(
                      child: Text('${r.text.toUpperCase()}  ·  ${friendlyDate(r.dueAt).toUpperCase()}',
                          style: _px(14, color: r.isOpen ? _c0 : _c1)),
                    ),
                    if (r.isOpen) ...[
                      _PixButton('+1H', () => rem.snooze(r)),
                      const SizedBox(width: 6),
                      _PixButton('HECHO', () => rem.done(r)),
                    ],
                  ]),
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    ]);
  }
}

class _PixButton extends StatelessWidget {
  const _PixButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: const BoxDecoration(color: _c0, boxShadow: [BoxShadow(color: _c1, offset: Offset(3, 3))]),
          child: Text(label, style: _px(12, color: _c3, bold: true)),
        ),
      );
}
