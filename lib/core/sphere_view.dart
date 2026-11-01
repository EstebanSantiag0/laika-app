// El cerebro como esfera 3D (lo usan Cosmos y el diseño final de Laika).
// Cada área ocupa una zona de la esfera; se gira arrastrando, la rueda
// acerca y un clic elige un recuerdo.

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'brain.dart';
import 'layouts.dart';
import 'models.dart';
import 'widgets.dart';

/// Colores y letras de la esfera.
class SphereTheme {
  const SphereTheme({
    this.background,
    required this.globe,
    required this.ring,
    required this.edge,
    required this.edgeLit,
    required this.selected,
    required this.match,
    required this.reminder,
    required this.label,
    this.labelPill,
    this.nodeBorder,
  });

  /// Dibuja el fondo (estrellas, degradado…).
  final void Function(Canvas canvas, Size size)? background;
  final Color globe, ring, edge, edgeLit, selected, match, reminder;
  final TextStyle Function(bool selected, double depth) label;

  /// Si no es null, las etiquetas van sobre una "pastilla" de este color.
  final Color? labelPill;

  /// Borde de cada nodo (null = sin borde).
  final Color? nodeBorder;
}

class SphereController extends ChangeNotifier {
  double yaw = 0.4, pitch = -0.25, zoom = 1;
  bool spinning = true;

  void toggleSpin() {
    spinning = !spinning;
    notifyListeners();
  }

  void _changed() => notifyListeners();
}

class SphereView extends StatefulWidget {
  const SphereView({super.key, required this.brain, required this.theme, required this.controller});

  final BrainController brain;
  final SphereTheme theme;
  final SphereController controller;

  @override
  State<SphereView> createState() => _SphereViewState();
}

class _SphereViewState extends State<SphereView> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..addListener(() {
      if (sc.spinning) {
        sc.yaw += 0.0025;
        sc._changed();
      }
    })
    ..repeat();
  Map<String, Vec3> _pos = {};
  int _ver = -1;
  Map<String, Offset> _screen = {};

  SphereController get sc => widget.controller;
  BrainController get b => widget.brain;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = b.graph;
    if (g == null) return const SizedBox.expand();
    if (_ver != b.version) {
      _pos = sphereLayout(g);
      _ver = b.version;
    }
    return LayoutBuilder(builder: (context, box) {
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            sc.zoom = (sc.zoom * (e.scrollDelta.dy > 0 ? 0.92 : 1.08)).clamp(0.5, 2.6);
            sc._changed();
          }
        },
        child: GestureDetector(
          onPanStart: (_) => sc.spinning = false,
          onPanUpdate: (d) {
            sc.yaw += d.delta.dx * 0.008;
            sc.pitch = (sc.pitch + d.delta.dy * 0.008).clamp(-1.4, 1.4);
            sc._changed();
          },
          onTapUp: (d) {
            final id = hitTest(_screen, d.localPosition);
            b.select(id);
            if (id != null) {
              sc.spinning = false;
              sc._changed();
            }
          },
          child: CustomPaint(
            size: box.biggest,
            painter: _SpherePainter(
              brain: b,
              graph: g,
              pos: _pos,
              sc: sc,
              theme: widget.theme,
              onProject: (m) => _screen = m,
            ),
          ),
        ),
      );
    });
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter({
    required this.brain,
    required this.graph,
    required this.pos,
    required this.sc,
    required this.theme,
    required this.onProject,
  }) : super(repaint: Listenable.merge([sc, brain]));

  final BrainController brain;
  final MemoryGraph graph;
  final Map<String, Vec3> pos;
  final SphereController sc;
  final SphereTheme theme;
  final void Function(Map<String, Offset>) onProject;

  @override
  void paint(Canvas canvas, Size size) {
    theme.background?.call(canvas, size);
    final c = size.center(Offset.zero);
    final zoom = sc.zoom;
    final radius = min(size.width, size.height) * 0.36 * zoom;
    const camera = 3.2;

    final visible = brain.visibleNodes;
    final proj = <String, (Offset, double)>{};
    for (final n in visible) {
      final p = pos[n.id];
      if (p == null) continue;
      final v = p.rotate(sc.yaw, sc.pitch);
      final k = camera / (camera - v.z);
      proj[n.id] = (c + Offset(v.x, v.y) * radius * k, v.z);
    }

    canvas.drawCircle(
        c,
        radius * 1.02,
        Paint()
          ..shader = RadialGradient(colors: [theme.globe, theme.globe.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: radius * 1.1)));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = theme.ring;
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(Rect.fromCenter(center: c, width: radius * 2, height: radius * 2 * (i / 3.4)), ring);
    }

    final sel = brain.selectedId;
    final hot = <String>{?sel, if (sel != null) ...brain.neighbors(sel).map((n) => n.id)};

    for (final e in brain.visibleEdges) {
      final a = proj[e.source], bb = proj[e.target];
      if (a == null || bb == null) continue;
      final depth = ((a.$2 + bb.$2) / 2 + 1) / 2;
      final lit = hot.contains(e.source) && hot.contains(e.target);
      canvas.drawLine(
          a.$1,
          bb.$1,
          Paint()
            ..strokeWidth = lit ? 1.8 : 0.9
            ..color = lit ? theme.edgeLit : theme.edge.withValues(alpha: theme.edge.a * (0.3 + 0.7 * depth)));
    }

    final order = proj.keys.toList()..sort((x, y) => proj[x]!.$2.compareTo(proj[y]!.$2));
    final screen = <String, Offset>{};
    for (final id in order) {
      final n = graph.nodeById[id]!;
      final (o, z) = proj[id]!;
      final depth = (z + 1) / 2;
      final col = graph.colorOf(n);
      final base = switch (n.kind) {
        NodeKind.entity => 6.5,
        NodeKind.episode => 5.0,
        NodeKind.reminder => 5.5,
        _ => 3.4,
      };
      final r = (base + n.importance * 3) * (0.55 + 0.6 * depth) * zoom.clamp(0.8, 1.6);
      final isSel = id == sel;
      final match = brain.matches(n);
      final alpha = n.timeScope == TimeScope.archived ? 0.35 : 0.4 + 0.6 * depth;
      canvas.drawCircle(o, r * 3, Paint()..color = col.withValues(alpha: 0.14 * alpha));
      canvas.drawCircle(o, r, Paint()..color = col.withValues(alpha: alpha));
      if (theme.nodeBorder != null) {
        canvas.drawCircle(o, r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = theme.nodeBorder!.withValues(alpha: alpha));
      }
      if (n.kind == NodeKind.reminder) {
        canvas.drawCircle(o, r + 3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = theme.reminder.withValues(alpha: alpha));
      }
      if (isSel || match) {
        canvas.drawCircle(o, r + 6, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = isSel ? theme.selected : theme.match);
      }
      screen[id] = o;
      final showLabel = isSel || match || hot.contains(id) || (n.kind == NodeKind.entity && z > 0.35);
      if (showLabel) {
        final tp = TextPainter(
          text: TextSpan(text: n.label, style: theme.label(isSel, depth)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 180);
        final at = o + Offset(r + 6, -tp.height / 2);
        if (theme.labelPill != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - 5, at.dy - 2, tp.width + 10, tp.height + 4), const Radius.circular(8)),
            Paint()..color = theme.labelPill!.withValues(alpha: theme.labelPill!.a * (0.5 + 0.5 * depth)),
          );
        }
        tp.paint(canvas, at);
      }
    }
    onProject(screen);
  }

  @override
  bool shouldRepaint(covariant _SpherePainter old) => true;
}
