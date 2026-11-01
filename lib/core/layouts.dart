// Algoritmos para acomodar los nodos del cerebro. Cada variante usa uno.
// Todos son deterministas: el mismo grafo siempre queda igual.

import 'dart:math';
import 'dart:ui';

import 'models.dart';

/// Punto 3D simple.
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  double get length => sqrt(x * x + y * y + z * z);
  Vec3 get normalized {
    final l = length;
    return l == 0 ? const Vec3(0, 0, 1) : Vec3(x / l, y / l, z / l);
  }

  /// Gira alrededor del eje Y (yaw) y luego del eje X (pitch).
  Vec3 rotate(double yaw, double pitch) {
    final cy = cos(yaw), sy = sin(yaw);
    final x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
    final cp = cos(pitch), sp = sin(pitch);
    return Vec3(x1, y * cp - z1 * sp, y * sp + z1 * cp);
  }
}

int _hash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return h;
}

/// Número pseudoaleatorio estable en [0,1) a partir de un texto.
double stableRand(String s, [int salt = 0]) => (_hash('$s#$salt') % 100000) / 100000;

/// N puntos repartidos uniformemente sobre una esfera (espiral de Fibonacci).
List<Vec3> fibonacciSphere(int n) {
  final pts = <Vec3>[];
  final golden = pi * (3 - sqrt(5));
  for (var i = 0; i < n; i++) {
    final y = 1 - (i / max(1, n - 1)) * 2;
    final r = sqrt(1 - y * y);
    final th = golden * i;
    pts.add(Vec3(cos(th) * r, y, sin(th) * r));
  }
  return pts;
}

/// Esfera: cada área ocupa una zona; sus recuerdos se agrupan alrededor.
Map<String, Vec3> sphereLayout(MemoryGraph g) {
  final dirs = fibonacciSphere(g.areas.length);
  final areaDir = {for (var i = 0; i < g.areas.length; i++) g.areas[i].id: dirs[i]};
  final out = <String, Vec3>{};
  for (final n in g.nodes) {
    var v = const Vec3(0, 0, 0);
    for (final a in n.areas) {
      v = v + (areaDir[a] ?? const Vec3(0, 0, 1));
    }
    final j = Vec3(stableRand(n.id, 1) - .5, stableRand(n.id, 2) - .5, stableRand(n.id, 3) - .5);
    final spread = n.kind == NodeKind.entity ? 0.55 : 0.95;
    final dir = (v.normalized + j * spread).normalized;
    final radius = switch (n.kind) {
      NodeKind.entity => 0.82,
      NodeKind.episode => 0.9,
      _ => 0.97 + stableRand(n.id, 4) * 0.08,
    };
    out[n.id] = dir * radius;
  }
  return out;
}

/// Mapa mental radial: centro → áreas → entidades → datos.
Map<String, Offset> radialLayout(MemoryGraph g, List<MemoryNode> visible, double r) {
  final out = <String, Offset>{};
  final areas = g.areas;
  final sector = 2 * pi / areas.length;
  final angleOf = <String, double>{};
  for (var i = 0; i < areas.length; i++) {
    final a = -pi / 2 + i * sector;
    angleOf[areas[i].id] = a;
    out['area:${areas[i].id}'] = Offset(cos(a), sin(a)) * (r * 0.32);
  }
  final byArea = <String, List<MemoryNode>>{};
  for (final n in visible) {
    byArea.putIfAbsent(n.primaryArea ?? areas.first.id, () => []).add(n);
  }
  for (final e in byArea.entries) {
    final base = angleOf[e.key] ?? 0;
    final ents = e.value.where((n) => n.kind == NodeKind.entity).toList();
    final rest = e.value.where((n) => n.kind != NodeKind.entity).toList();
    for (var i = 0; i < ents.length; i++) {
      final a = base + (i - (ents.length - 1) / 2) * sector * 0.8 / max(1, ents.length);
      out[ents[i].id] = Offset(cos(a), sin(a)) * (r * (i.isEven ? 0.55 : 0.67));
    }
    for (var i = 0; i < rest.length; i++) {
      final a = base + (i - (rest.length - 1) / 2) * sector * 0.9 / max(1, rest.length);
      final rr = r * (0.82 + (i.isEven ? 0 : 0.12));
      out[rest[i].id] = Offset(cos(a), sin(a)) * rr;
    }
  }
  return out;
}

/// Grafo de fuerzas 2D (Fruchterman–Reingold) con atracción hacia su área.
Map<String, Offset> forceLayout(List<MemoryNode> nodes, List<MemoryEdge> edges,
    List<Area> areas, Size size, {int iterations = 260}) {
  final w = size.width, h = size.height;
  final center = Offset(w / 2, h / 2);
  final anchors = <String, Offset>{};
  for (var i = 0; i < areas.length; i++) {
    final a = 2 * pi * i / areas.length;
    anchors[areas[i].id] = center + Offset(cos(a) * w * 0.3, sin(a) * h * 0.3);
  }
  final pos = <String, Offset>{
    for (final n in nodes)
      n.id: (anchors[n.primaryArea] ?? center) +
          Offset((stableRand(n.id, 5) - .5) * 120, (stableRand(n.id, 6) - .5) * 120),
  };
  final k = sqrt(w * h / max(1, nodes.length)) * 0.55;
  var temp = w / 10;
  for (var it = 0; it < iterations; it++) {
    final disp = {for (final n in nodes) n.id: Offset.zero};
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i].id, b = nodes[j].id;
        var d = pos[a]! - pos[b]!;
        var dist = d.distance;
        if (dist < 0.01) {
          d = const Offset(0.1, 0.1);
          dist = 0.14;
        }
        final f = k * k / dist;
        final push = d / dist * f;
        disp[a] = disp[a]! + push;
        disp[b] = disp[b]! - push;
      }
    }
    for (final e in edges) {
      final pa = pos[e.source], pb = pos[e.target];
      if (pa == null || pb == null) continue;
      final d = pa - pb;
      final dist = max(0.01, d.distance);
      final pull = d / dist * (dist * dist / k) * (0.4 + e.weight);
      disp[e.source] = disp[e.source]! - pull;
      disp[e.target] = disp[e.target]! + pull;
    }
    for (final n in nodes) {
      final anchor = anchors[n.primaryArea] ?? center;
      disp[n.id] = disp[n.id]! + (anchor - pos[n.id]!) * 0.9;
      final d = disp[n.id]!;
      final dist = max(0.01, d.distance);
      var p = pos[n.id]! + d / dist * min(dist, temp);
      p = Offset(p.dx.clamp(70, w - 90), p.dy.clamp(70, h - 50));
      pos[n.id] = p;
    }
    temp *= 0.985;
  }
  return pos;
}

/// "Cuartos" de una cuadrícula: cada área es un cuarto y sus recuerdos se
/// listan dentro, uno por renglón (en dos columnas si cabe). Devuelve el
/// rectángulo de cada área y la posición del ícono de cada nodo.
({Map<String, Rect> rooms, Map<String, Offset> cells, double colWidth}) roomsLayout(
    List<Area> areas, List<MemoryNode> visible, Size size, double row) {
  final cols = size.width > size.height ? 5 : 2;
  final rows = (areas.length / cols).ceil();
  final rw = size.width / cols, rh = size.height / rows;
  final rooms = <String, Rect>{};
  final cells = <String, Offset>{};
  var colWidth = rw;
  for (var i = 0; i < areas.length; i++) {
    final r = Rect.fromLTWH((i % cols) * rw + 6, (i ~/ cols) * rh + 6, rw - 12, rh - 12);
    rooms[areas[i].id] = r;
    final members = visible.where((n) => n.primaryArea == areas[i].id).toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final perCol = max(1, ((r.height - 34) / row).floor());
    final listCols = members.length > perCol ? 2 : 1;
    colWidth = (r.width - 12) / listCols;
    for (var j = 0; j < members.length; j++) {
      final c = j ~/ perCol;
      if (c >= listCols) break; // no cabe: se ve al filtrar por área
      cells[members[j].id] = Offset(r.left + 14 + c * colWidth, r.top + 34 + (j % perCol) * row + row / 2);
    }
  }
  return (rooms: rooms, cells: cells, colWidth: colWidth);
}

/// Órbitas del tiempo: el ángulo es el área, la distancia al centro es el
/// tiempo (cerca = urgente/ahora, lejos = permanente o pasado).
Map<String, Offset> orbitLayout(List<Area> areas, List<MemoryNode> visible, double r) {
  final sector = 2 * pi / areas.length;
  final idx = {for (var i = 0; i < areas.length; i++) areas[i].id: i};
  final out = <String, Offset>{};
  final counters = <String, int>{};
  for (final n in visible) {
    final ring = orbitRing(n);
    final key = '${n.primaryArea}|$ring';
    final k = counters[key] = (counters[key] ?? 0) + 1;
    final base = -pi / 2 + (idx[n.primaryArea] ?? 0) * sector;
    final a = base + sector * (0.15 + 0.7 * ((k * 0.381966) % 1));
    out[n.id] = Offset(cos(a), sin(a)) * (r * orbitRadius(ring));
  }
  return out;
}

/// 0 recordatorios, 1 con fecha, 2 etapa actual, 3 permanente, 4 archivado.
int orbitRing(MemoryNode n) => switch (n.kind) {
      NodeKind.reminder when n.timeScope != TimeScope.archived => 0,
      NodeKind.entity => 3,
      NodeKind.episode => 2,
      _ => switch (n.timeScope) {
          TimeScope.reminder => 0,
          TimeScope.dated => 1,
          TimeScope.stage => 2,
          TimeScope.permanent => 3,
          TimeScope.archived => 4,
        },
    };

double orbitRadius(int ring) => const [0.2, 0.38, 0.56, 0.74, 0.93][ring];
const orbitNames = ['Recordatorios', 'Con fecha', 'Etapa actual', 'Permanente', 'Archivado'];
