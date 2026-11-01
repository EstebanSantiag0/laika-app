// Laika — cliente de escritorio y Android.
//
//   laika_app --pet    → Laika sobre tu escritorio (ventana transparente, Linux/Wayland)
//   laika_app --app    → la app completa: cerebro, agenda y mascota
//   laika_app          → galería de prototipos de diseño
//
//   flutter run -d linux -a --pet
//   flutter run -d linux --dart-define=VARIANT=pixel → directo a una variante
//
// Servidor: --dart-define=LAIKA_SERVER=…, variable LAIKA_SERVER o
// ~/.config/laika/config.json. Sin servidor se usa el simulado.

import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/http_laika.dart';
import 'core/session.dart';
import 'desktop/pet_overlay.dart';
import 'desktop/window_bridge.dart';
import 'variants/laika.dart';
import 'variants/variants.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ajustes compartidos entre la mascota (--pet) y la app (--app).
  if (args.contains('--pet') || args.contains('--app')) watchConfig();
  LaikaSession session() {
    final url = laikaServerUrl();
    return LaikaSession(url == null ? null : HttpLaika(url));
  }

  if (args.contains('--pet')) {
    if (await WindowBridge.isPetMode()) {
      runApp(PetOverlay(session: session()));
      return;
    }
    // Sin capa transparente (X11 o sin gtk-layer-shell): la mascota en una ventana normal.
    runApp(LaikaApp(session: session(), initialTab: 0));
    return;
  }
  if (args.contains('--app')) {
    runApp(LaikaApp(session: session(), showDesktop: false));
    return;
  }
  runApp(const LaikaPrototypes());
}

class LaikaPrototypes extends StatefulWidget {
  const LaikaPrototypes({super.key, this.initial});

  /// Variante que se abre directo (para pruebas).
  final String? initial;

  @override
  State<LaikaPrototypes> createState() => _LaikaPrototypesState();
}

class _LaikaPrototypesState extends State<LaikaPrototypes> {
  static const _fromDefine = String.fromEnvironment('VARIANT');
  late VariantSpec? open = _find(widget.initial ?? _fromDefine);

  VariantSpec? _find(String id) {
    for (final v in allVariants) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final v = open;
    if (v != null) {
      return VariantHost(key: ValueKey(v.id), spec: v, onExit: () => setState(() => open = null));
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laika · prototipos',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6E56CF), fontFamily: 'Adwaita Sans'),
      home: _Gallery(onOpen: (s) => setState(() => open = s)),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.onOpen});
  final ValueChanged<VariantSpec> onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F7),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        children: [
          const Text('Laika · prototipos', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Cinco estilos muy distintos con el mismo comportamiento: Laika se duerme tras 15 s, '
            'despierta solo si el servidor (simulado) responde, sus mensajes salen a su lado, y su cerebro '
            'se organiza por áreas de tu vida y por tiempo. Elige uno, o dime qué mezclar.',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 20, runSpacing: 20, children: [
            for (var i = 0; i < allVariants.length; i++)
              _Card(n: i + 1, spec: allVariants[i], onTap: () => onOpen(allVariants[i])),
          ]),
          const SizedBox(height: 28),
          const Text('Dentro de cada variante: ⚙ SIM (abajo a la izquierda) apaga el servidor simulado, '
              'cambia la latencia o hace sonar un recordatorio. "←" vuelve aquí.',
              style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.n, required this.spec, required this.onTap});
  final int n;
  final VariantSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.black12)),
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 90,
              child: Row(children: [for (final c in spec.swatch) Expanded(child: ColoredBox(color: c))]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$n · ${spec.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(spec.tagline, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Text('flutter run -d linux --dart-define=VARIANT=${spec.id}',
                    style: const TextStyle(fontFamily: 'Hack', fontSize: 10.5, color: Colors.black38)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
