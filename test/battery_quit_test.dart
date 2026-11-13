// Batería y "Cerrar Laika": el reloj lento de las animaciones que nunca
// terminan, el botón de Ajustes que cierra la mascota y la app, y la casilla
// «No abrir Laika al iniciar sesión».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pace.dart';
import 'package:laika_app/core/session.dart';
import 'package:laika_app/desktop/autostart.dart';
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

  group('Autostart (Hidden=true, como Plasma)', () {
    late Directory dir;
    late String path;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('laika-autostart');
      path = '${dir.path}/autostart/laika-pet.desktop';
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('apagar y prender deja el archivo del instalador igual', () async {
      final original = '${Autostart.entryFor('/home/x/.local/share/laika-app/laika_app').join('\n')}\n';
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(original);
      final a = Autostart(path);
      expect(a.enabled, isTrue);

      await a.setEnabled(false);
      expect(a.enabled, isFalse);
      final lines = File(path).readAsLinesSync();
      expect(lines.take(2), ['[Desktop Entry]', 'Hidden=true']);
      expect(lines, contains('Exec=/home/x/.local/share/laika-app/laika_app --pet'));

      await a.setEnabled(false); // dos veces: una sola línea
      expect(File(path).readAsLinesSync().where((l) => l.startsWith('Hidden')).length, 1);

      await a.setEnabled(true);
      expect(a.enabled, isTrue);
      expect(File(path).readAsStringSync(), original);
    });

    test('sin archivo: apagado; prenderlo lo crea con este programa', () async {
      final a = Autostart(path);
      expect(a.enabled, isFalse);
      await a.setEnabled(false);
      expect(File(path).existsSync(), isFalse);
      await a.setEnabled(true);
      expect(a.enabled, isTrue);
      expect(File(path).readAsStringSync(), contains('Exec=${Platform.resolvedExecutable} --pet'));
    });
  });

  group('Ajustes → Cerrar Laika', () {
    Future<LaikaSession> open(WidgetTester tester, Future<void> Function()? onQuit, {Autostart? autostart}) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = LaikaSession(MockLaika()..latency = Duration.zero);
      await tester.pumpWidget(LaikaApp(session: session, showDesktop: false, onQuit: onQuit, autostart: autostart));
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
      await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¿Cerrar Laika?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(quits, 0);

      await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cerrar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(quits, 1);
      await close(tester, s);
    });

    testWidgets('la casilla apaga y prende el inicio automático', (tester) async {
      final dir = Directory.systemTemp.createTempSync('laika-autostart');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/laika-pet.desktop';
      File(path).writeAsStringSync('${Autostart.entryFor('/x/laika_app').join('\n')}\n');
      final s = await open(tester, () async {}, autostart: Autostart(path));
      expect(find.textContaining('Vuelve sola al iniciar sesión'), findsOneWidget);

      // Escribe un archivo de verdad: fuera del reloj falso de la prueba.
      await tester.runAsync(() async {
        await tester.tap(find.text('No abrir Laika al iniciar sesión'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(File(path).readAsStringSync(), contains('Hidden=true'));
      expect(find.text('Ya no se abrirá al iniciar sesión ✓'), findsOneWidget);
      expect(find.textContaining('desmárcala cuando regreses'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byType(Checkbox));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(File(path).readAsStringSync(), isNot(contains('Hidden')));
      expect(find.text('Se abrirá al iniciar sesión ✓'), findsOneWidget);
      await close(tester, s);
    });

    testWidgets('sin escritorio real (prototipos) no aparece', (tester) async {
      final s = await open(tester, null);
      expect(find.text('Ajustes'), findsWidgets);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsNothing);
      expect(find.text('No abrir Laika al iniciar sesión'), findsNothing);
      await close(tester, s);
    });
  });
}
