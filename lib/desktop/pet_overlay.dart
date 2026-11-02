// Laika sobre tu escritorio de verdad (Linux, `laika_app --pet`).
//
// Ventana transparente que cubre la pantalla; solo Laika y sus mensajes
// reciben clics (ver WindowBridge). 1 clic = escribirle, 2 clics = abrir la
// app completa en una ventana normal (otro proceso con --app).

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/session.dart';
import '../core/stage.dart';
import '../variants/laika.dart';
import 'window_bridge.dart';

class PetOverlay extends StatefulWidget {
  const PetOverlay({super.key, required this.session});
  final LaikaSession session;

  @override
  State<PetOverlay> createState() => _PetOverlayState();
}

class _PetOverlayState extends State<PetOverlay> {
  /// LAIKA_DEBUG=1: registra clics y zonas en stderr.
  static final _debug = Platform.environment['LAIKA_DEBUG'] != null;

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  Future<void> _openApp() async {
    try {
      await Process.start(Platform.resolvedExecutable, ['--app'], mode: ProcessStartMode.detached);
    } catch (_) {
      // Si no se pudo abrir, Laika sigue en el escritorio; no hay más que hacer.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laika',
      color: Colors.transparent,
      theme: ThemeData(
        fontFamily: 'Adwaita Sans',
        colorScheme: ColorScheme.fromSeed(seedColor: lAccent),
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: lAccent),
      ),
      home: _debug
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) =>
                  stderr.writeln('[laika] flutter down ${e.kind.name} at ${e.position.dx.round()},${e.position.dy.round()}'),
              onPointerUp: (e) => stderr.writeln('[laika] flutter up at ${e.position.dx.round()},${e.position.dy.round()}'),
              child: _home(),
            )
          : _home(),
    );
  }

  Widget _home() => Material(
    type: MaterialType.transparency,
    // Si cambias la skin o el tamaño en Ajustes, se actualiza aquí al instante.
    child: ValueListenableBuilder(
      valueListenable: config,
      builder: (context, cfg, _) => PetStage(
        key: ValueKey(cfg.petSize),
        controller: widget.session.pet,
        skin: const LaikaSkin(transparent: true),
        onOpenApp: _openApp,
        onRegions: (r) {
          if (_debug) {
            stderr.writeln('[laika] flutter regions: ${r.map((x) => '${x.left.round()},${x.top.round()} ${x.width.round()}x${x.height.round()}').join(' | ')}');
          }
          WindowBridge.setInputRegion(r);
        },
      ),
    ),
  );
}
