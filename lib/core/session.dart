// Une todo para una variante: backend simulado + mascota + cerebro +
// recordatorios, y el panel de simulación para probar sin servidor.

import 'package:flutter/material.dart';

import 'api.dart';
import 'brain.dart';
import 'mock_backend.dart';
import 'models.dart';
import 'pet.dart';

class LaikaSession {
  /// Sin [api] usa el servidor simulado.
  LaikaSession([LaikaApi? api]) : api = api ?? MockLaika() {
    pet = PetController(this.api);
    brain = BrainController(this.api);
    reminders = RemindersController(this.api);
  }

  final LaikaApi api;
  late final PetController pet;
  late final BrainController brain;
  late final RemindersController reminders;

  void dispose() {
    pet.dispose();
    brain.dispose();
    reminders.dispose();
    api.dispose();
  }
}

/// Descripción de una variante para la galería.
class VariantSpec {
  const VariantSpec({
    required this.id,
    required this.name,
    required this.tagline,
    required this.swatch,
    required this.build,
  });

  final String id;
  final String name;
  final String tagline;

  /// Colores de muestra para la tarjeta de la galería.
  final List<Color> swatch;

  /// Construye la app completa de la variante.
  final Widget Function(LaikaSession session) build;
}

/// Monta una variante con su sesión y el panel de simulación encima.
class VariantHost extends StatefulWidget {
  const VariantHost({super.key, required this.spec, this.onExit});

  final VariantSpec spec;
  final VoidCallback? onExit;

  @override
  State<VariantHost> createState() => _VariantHostState();
}

class _VariantHostState extends State<VariantHost> {
  final session = LaikaSession();

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: SessionScope(session: session, child: widget.spec.build(session))),
          Positioned(
            left: 10,
            bottom: 10,
            child: SimPanel(session: session, onExit: widget.onExit),
          ),
        ],
      ),
    );
  }
}

/// Da acceso a la sesión desde cualquier widget (y desde las pruebas).
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});
  final LaikaSession session;

  static LaikaSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()?.session;

  @override
  bool updateShouldNotify(SessionScope oldWidget) => oldWidget.session != session;
}

/// Panel neutro (igual en todas las variantes) para simular el servidor.
class SimPanel extends StatefulWidget {
  const SimPanel({super.key, required this.session, this.onExit});
  final LaikaSession session;
  final VoidCallback? onExit;

  @override
  State<SimPanel> createState() => _SimPanelState();
}

class _SimPanelState extends State<SimPanel> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final api = widget.session.api;
    if (api is! MockLaika) return const SizedBox.shrink();
    final style = const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Hack', decoration: TextDecoration.none);
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xE6101014),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: DefaultTextStyle(
          style: style,
          child: open
              ? SizedBox(
                  width: 250,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('SIMULACIÓN'),
                        const Spacer(),
                        _btn('×', () => setState(() => open = false)),
                      ]),
                      _switch('Servidor en línea', api.online, (v) => api.online = v),
                      _switch('Modelo cargado (llm)', api.llmLoaded, (v) => api.llmLoaded = v),
                      Text('Latencia: ${api.latency.inMilliseconds} ms'),
                      SliderTheme(
                        data: const SliderThemeData(trackHeight: 2),
                        child: Slider(
                          value: api.latency.inMilliseconds.toDouble(),
                          min: 50,
                          max: 6000,
                          onChanged: (v) => setState(() => api.latency = Duration(milliseconds: v.round())),
                        ),
                      ),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _btn('Dormirla ya', widget.session.pet.sleep),
                        _btn('Sonar recordatorio', api.fireNextReminderNow),
                        if (widget.onExit != null) _btn('← Galería', widget.onExit!),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Prueba: "recuérdame pagar la renta"\n"quiero aprender a soldar"',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  _btn('⚙ SIM ${api.online ? '●' : '○'}', () => setState(() => open = true)),
                  if (widget.onExit != null) ...[
                    const SizedBox(width: 6),
                    _btn('←', widget.onExit!),
                  ],
                ]),
        ),
      ),
    );
  }

  Widget _switch(String label, bool v, ValueChanged<bool> set) => Row(children: [
        Expanded(child: Text(label)),
        Switch(value: v, onChanged: (x) => setState(() => set(x))),
      ]);

  Widget _btn(String label, VoidCallback onTap) => InkWell(
        onTap: () {
          onTap();
          setState(() {});
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label),
        ),
      );
}

/// "Dato · Etapa actual · Estudios"
String describeNode(MemoryNode n, MemoryGraph g) {
  final areas = n.areas.map((a) => g.areaById[a]?.name ?? a).join(', ');
  final scope = n.kind == NodeKind.entity ? null : n.timeScope.label;
  return [n.kind.label, ?scope, if (areas.isNotEmpty) areas].join(' · ');
}

/// Fechas relevantes de un nodo en texto.
String nodeDates(MemoryNode n) {
  String f(DateTime d) => '${d.day}/${d.month}/${d.year}';
  final parts = <String>[
    if (n.dueAt != null) 'para el ${f(n.dueAt!)}',
    if (n.validTo != null) 'válido hasta ${f(n.validTo!)}',
    if (n.reviewAfter != null) 'Laika preguntará si sigue siendo cierto desde el ${f(n.reviewAfter!)}',
    'guardado el ${f(n.createdAt)}',
  ];
  return parts.join(' · ');
}
