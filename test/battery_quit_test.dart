// Batería y "Cerrar Laika": el reloj lento de las animaciones que nunca
// terminan, y el botón de Ajustes que cierra la mascota y la app.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pace.dart';
import 'package:laika_app/core/session.dart';
import 'package:laika_app/desktop/quit.dart';
import 'package:laika_app/variants/laika.dart';

void main() {
  group('Pace', () {
    testWidgets('avisa solo fps veces por segundo, y en pausa ni avisa ni avanza', (tester) async {
      final p = Pace(fps: 10);
      var ticks = 0;
      p.addListener(() => ticks++);
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, inInclusiveRange(9, 10)); // antes: un cuadro por refresco (144)

      p.on = false;
      final t = p.t;
      ticks = 0;
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, 0);
      expect(p.t, t);

      p
        ..on = true
        ..fps = 30;
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, inInclusiveRange(29, 30));
      p.dispose();
    });

    testWidgets('whenFocused: quieto mientras la ventana no está al frente', (tester) async {
      final p = Pace(fps: 10, whenFocused: true);
      var ticks = 0;
      p.addListener(() => ticks++);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, 0);
      expect(p.running, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, inInclusiveRange(9, 10));
      p.dispose();
    });
  });

  test('petPids encuentra solo las mascotas (laika_app --pet)', () {
    final proc = Directory.systemTemp.createTempSync('laika-proc');
    addTearDown(() => proc.deleteSync(recursive: true));
    void fake(String id, List<String>? args) {
      final d = Directory('${proc.path}/$id')..createSync();
      if (args != null) File('${d.path}/cmdline').writeAsStringSync('${args.join('\x00')}\x00');
    }

    fake('100', ['/home/x/.local/share/laika-app/laika_app', '--pet']);
    fake('101', ['/home/x/.local/share/laika-app/laika_app', '--app']);
    fake('102', ['bash', '--pet']);
    fake('103', null); // ya terminó
    fake('self', ['laika_app', '--pet']);
    fake('$pid', ['laika_app', '--pet']); // este mismo proceso no
    expect(petPids(proc: proc.path), [100]);
    expect(petPids(proc: '${proc.path}/no-existe'), isEmpty);
  });

  group('Ajustes → Cerrar Laika', () {
    Future<LaikaSession> open(WidgetTester tester, Future<void> Function()? onQuit) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = LaikaSession(MockLaika()..latency = Duration.zero);
      await tester.pumpWidget(LaikaApp(session: session, showDesktop: false, onQuit: onQuit));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ajustes').first);
      await tester.pump(const Duration(milliseconds: 300));
      return session;
    }

    Future<void> close(WidgetTester tester, LaikaSession session) async {
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('pregunta antes, y Cancelar no cierra nada', (tester) async {
      var quits = 0;
      final s = await open(tester, () async => quits++);
      await tester.tap(find.text('⏻  Cerrar Laika'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¿Cerrar Laika?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(quits, 0);

      await tester.tap(find.text('⏻  Cerrar Laika'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cerrar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(quits, 1);
      await close(tester, s);
    });

    testWidgets('sin escritorio real (prototipos) no aparece', (tester) async {
      final s = await open(tester, null);
      expect(find.text('Ajustes'), findsWidgets);
      expect(find.text('⏻  Cerrar Laika'), findsNothing);
      await close(tester, s);
    });
  });
}
