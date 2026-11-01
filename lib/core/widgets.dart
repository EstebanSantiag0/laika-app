// Piezas reutilizables que cada variante "viste" con su propio estilo.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'brain.dart';
import 'models.dart';
import 'session.dart';

typedef ChipBuilder = Widget Function(
    BuildContext context, String label, Color color, bool selected, VoidCallback onTap);

/// Filtros del cerebro: áreas, tiempo y archivados. El aspecto de cada
/// "chip" lo decide la variante con [chip].
class BrainFilters extends StatelessWidget {
  const BrainFilters({
    super.key,
    required this.brain,
    required this.chip,
    this.spacing = 6,
    this.showScopes = true,
    this.titleStyle,
  });

  final BrainController brain;
  final ChipBuilder chip;
  final double spacing;
  final bool showScopes;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final g = brain.graph;
    if (g == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Áreas de tu vida', style: titleStyle),
        SizedBox(height: spacing),
        Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (final a in g.areas)
            chip(context, '${a.name} ${brain.countIn(a.id)}', a.color,
                brain.areaFilter.contains(a.id), () => brain.toggleArea(a.id)),
        ]),
        if (showScopes) ...[
          SizedBox(height: spacing * 2),
          Text('Tiempo', style: titleStyle),
          SizedBox(height: spacing),
          Wrap(spacing: spacing, runSpacing: spacing, children: [
            for (final s in TimeScope.values.where((s) => s != TimeScope.archived))
              chip(context, s.label, scopeColor(s), brain.scopeFilter.contains(s),
                  () => brain.toggleScope(s)),
            chip(context, 'Ver archivados', scopeColor(TimeScope.archived), brain.showArchived,
                () => brain.setShowArchived(!brain.showArchived)),
          ]),
        ],
      ],
    );
  }
}

/// Color neutro para cada tipo de tiempo.
Color scopeColor(TimeScope s) => switch (s) {
      TimeScope.permanent => const Color(0xFF64748B),
      TimeScope.stage => const Color(0xFF0EA5E9),
      TimeScope.dated => const Color(0xFFF59E0B),
      TimeScope.reminder => const Color(0xFFEF4444),
      TimeScope.archived => const Color(0xFFA1A1AA),
    };

/// Contenido del panel de detalles de un nodo (la variante pone el marco).
class NodeDetails extends StatelessWidget {
  const NodeDetails({
    super.key,
    required this.brain,
    required this.node,
    required this.title,
    required this.body,
    required this.meta,
    this.linkBuilder,
  });

  final BrainController brain;
  final MemoryNode node;
  final TextStyle title, body, meta;
  final Widget Function(BuildContext, MemoryNode, VoidCallback)? linkBuilder;

  @override
  Widget build(BuildContext context) {
    final g = brain.graph!;
    final links = brain.neighbors(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(describeNode(node, g), style: meta),
        const SizedBox(height: 6),
        Text(node.label, style: title),
        if (node.text.isNotEmpty && node.text != node.label) ...[
          const SizedBox(height: 6),
          Text(node.text, style: body),
        ],
        const SizedBox(height: 8),
        Text(nodeDates(node), style: meta),
        if (links.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Conectado con', style: meta),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in links)
              (linkBuilder ?? _defaultLink)(context, l, () => brain.select(l.id)),
          ]),
        ],
      ],
    );
  }

  Widget _defaultLink(BuildContext context, MemoryNode n, VoidCallback onTap) =>
      InkWell(onTap: onTap, child: Text('• ${n.label}', style: body));
}

/// Busca el nodo más cercano a [p] (en coordenadas de pantalla).
String? hitTest(Map<String, Offset> screen, Offset p, {double radius = 22}) {
  String? best;
  var bestD = radius;
  screen.forEach((id, o) {
    final d = (o - p).distance;
    if (d < bestD) {
      bestD = d;
      best = id;
    }
  });
  return best;
}

/// Contenedor de vidrio esmerilado.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.radius = 18,
    this.blur = 18,
    this.color = const Color(0x66FFFFFF),
    this.border = const Color(0x80FFFFFF),
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final double radius, blur;
  final Color color, border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ),
      );
}

/// Escucha uno o varios ChangeNotifier y reconstruye.
class Watch extends StatelessWidget {
  const Watch({super.key, required this.listenables, required this.builder});
  final List<Listenable> listenables;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge(listenables),
        builder: (context, _) => builder(context),
      );
}
