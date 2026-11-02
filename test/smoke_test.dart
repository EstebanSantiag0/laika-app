// Pruebas de humo: cada variante arranca, Laika despierta solo si el
// servidor (simulado) responde, contesta, se duerme a los 15 s, y las
// pestañas Cerebro y Agenda se dibujan sin errores.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pet.dart';
import 'package:laika_app/core/stage.dart';
import 'package:laika_app/main.dart';
import 'package:laika_app/pets/skins.dart';

import 'dart:io';

import 'package:laika_app/variants/variants.dart';

/// Cómo encontrar las pestañas Cerebro y Agenda en cada variante.
final tabs = <String, (Finder, Finder)>{
  'laika': (find.text('Cerebro'), find.text('Agenda')),
  'cosmos': (find.byIcon(Icons.blur_on), find.byIcon(Icons.schedule)),
  'papel': (find.text('Cerebro'), find.text('Agenda')),
  'pixel': (find.text('[F2] CEREBRO'), find.text('[F3] AGENDA')),
  'brutal': (find.text('CEREBRO'), find.text('AGENDA')),
  'cristal': (find.text('Cerebro'), find.text('Agenda')),
};

Future<PetController> open(WidgetTester tester, String id) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LaikaPrototypes(initial: id));
  await tester.pump();
  final stage = tester.widget<PetStage>(find.byType(PetStage));
  return stage.controller;
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('hay al menos 5 variantes', () => expect(allVariants.length, greaterThanOrEqualTo(5)));

  test('Laika pone cara según lo que dice', () {
    expect(Mood.forText('jajaja qué bueno'), Mood.laughing);
    expect(Mood.forText('Te quiero ❤️'), Mood.inLove);
    expect(Mood.forText('¡Hola! ¿Cómo estás?'), Mood.greeting);
    expect(Mood.forText('Hmm, no estoy segura'), Mood.doubting);
    expect(Mood.forText('wow, increíble'), Mood.impressed);
    expect(Mood.forText('😈 ya lo anoté'), Mood.scheming);
    expect(Mood.forText('✏️ goed → good'), Mood.cheeky);
    expect(Mood.forText('⚠️ Laika no pudo contestar.'), Mood.ashamed);
    expect(Mood.forText('Muy bien, sigamos con el ruso.'), Mood.happy);
  });

  test('una skin de imágenes usa otra parecida si falta una emoción', () {
    final dir = Directory.systemTemp.createTempSync('laika_skin_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // PNG de 1×1 transparente.
    const png = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      13,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      0,
      1,
      0,
      0,
      5,
      0,
      1,
      13,
      10,
      45,
      180,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ];
    for (final n in ['neutral', 'doubting', 'sleepingLying']) {
      File('${dir.path}/$n.png').writeAsBytesSync(png);
    }
    final look = ImageLook.fromDir(dir)!;
    expect(look.fileFor(Mood.thinking)!.path, endsWith('doubting.png'));
    expect(look.fileFor(Mood.sleeping)!.path, endsWith('sleepingLying.png'));
    expect(look.fileFor(Mood.sleeping, lying: true)!.path, endsWith('sleepingLying.png'));
    expect(look.fileFor(Mood.inLove)!.path, endsWith('neutral.png'));
    expect(ImageLook.fromDir(Directory.systemTemp.createTempSync('laika_vacia_')), isNull);
  });

  test('dormida, despertando y pensando tienen su cara', () async {
    final api = MockLaika()..latency = Duration.zero;
    final c = PetController(api, idle: const Duration(seconds: 30));
    expect(c.mood, Mood.sleeping);
    c.hover();
    expect(c.mood, Mood.waking);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.isAwake, isTrue);
    expect(c.mood, Mood.greeting, reason: 'saluda al despertar');
    c.dispose();
    api.dispose();
  });

  test('no se duerme mientras le escribes (Esteban, 2026-11-02)', () {
    fakeAsync((fa) {
      final api = MockLaika()..latency = Duration.zero;
      final c = PetController(api, idle: const Duration(seconds: 15));
      c.hover();
      fa.elapse(const Duration(seconds: 1));
      expect(c.isAwake, isTrue);
      c.composing(true); // primera letra
      fa.elapse(const Duration(minutes: 2)); // escribe un mensaje largo
      expect(c.isAwake, isTrue, reason: 'hay texto sin mandar');
      c.composing(false); // borró todo
      fa.elapse(const Duration(seconds: 10));
      expect(c.isAwake, isTrue, reason: 'los 15 s cuentan desde que borró');
      fa.elapse(const Duration(minutes: 2));
      expect(c.isAwake, isFalse, reason: 'sin texto y sin burbujas, sí se duerme');
      c.dispose();
      api.dispose();
    });
  });

  test('cada burbuja dura su tiempo de lectura', () {
    expect(readingTime('Muy bien, sigamos con el ruso.'), const Duration(seconds: 18)); // 6 palabras × 3 s
    expect(readingTime('你好'), const Duration(seconds: 4)); // 2 caracteres × 2 s
    expect(readingTime('我要 kāfēi, please'), const Duration(seconds: 10)); // 2 × 2 s + 2 palabras × 3 s
    expect(readingTime('🐾'), const Duration(seconds: 3), reason: 'mínimo 3 s');
    final b = Bubble('hola mundo', at: DateTime(2026, 11, 2, 12));
    expect(b.opacityAt(DateTime(2026, 11, 2, 12, 0, 5)), 1, reason: 'se lee completa 6 s');
    expect(b.opacityAt(b.fadeStart.add(const Duration(milliseconds: 750))), closeTo(0.5, 0.01));
    expect(b.opacityAt(b.gone), 0);
  });

  testWidgets('al despertar te recuerda algo guardado, impresionada, y no se duerme mientras lo lees',
      (tester) async {
    final api = MockLaika()..latency = Duration.zero;
    final c = PetController(api);
    c.hover();
    await tester.pump(const Duration(milliseconds: 10));
    expect(c.mood, Mood.greeting, reason: 'primero saluda');
    await tester.pump(const Duration(seconds: 4));
    expect(c.bubbles.single.text, startsWith('💡 Hace 10 días guardaste'));
    expect(c.mood, Mood.impressed);
    final read = c.bubbles.single.read;
    await tester.pump(read - const Duration(seconds: 1));
    expect(c.state, PetState.awake);
    await tester.pump(const Duration(seconds: 3));
    expect(c.bubbles, isEmpty);
    await tester.pump(const Duration(seconds: 16));
    expect(c.state, PetState.asleep);
    c.hover();
    await tester.pump(const Duration(seconds: 5));
    expect(c.bubbles.where((b) => b.text.startsWith('💡')), isEmpty, reason: 'máximo uno al día');
    c.dispose();
    api.dispose();
  });

  testWidgets('cuando le llega un PDF o un link, come', (tester) async {
    final api = MockLaika()..latency = Duration.zero;
    final c = PetController(api);
    c.hover();
    await tester.pump(const Duration(seconds: 5));
    api.feedPdf();
    await tester.pump(const Duration(milliseconds: 10));
    expect(c.mood, Mood.eating);
    expect(c.bubbles.last.text, startsWith('📚 Leyendo'));
    await tester.pump(const Duration(seconds: 5));
    c.send('mira https://www.instagram.com/p/ejemplo'); // sin await: el tiempo lo avanza pump
    await tester.pump(const Duration(milliseconds: 10));
    expect(c.mood, Mood.eating, reason: 'un link nuevo también se lo come');
    await tester.pump(const Duration(seconds: 3));
    expect(c.bubbles.any((b) => b.text.startsWith('Ñam')), isTrue);
    await tester.pump(const Duration(minutes: 5));
    expect(c.state, PetState.asleep);
    c.dispose();
    api.dispose();
  });

  for (final v in allVariants) {
    testWidgets('${v.id}: despierta, contesta, se duerme y dibuja todo', (tester) async {
      final c = await open(tester, v.id);
      expect(c.state, PetState.asleep);

      // Pasar el mouse por encima → /health responde → despierta.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final petBox = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.grab);
      await mouse.moveTo(tester.getCenter(petBox));
      await tester.pump(const Duration(seconds: 1));
      expect(c.state, PetState.awake);
      expect(c.chatOpen, isFalse, reason: 'despertar no abre la caja de texto');

      // Un clic abre la caja de texto.
      await tester.tap(petBox);
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.chatOpen, isTrue);

      // Escribir y enviar.
      await tester.enterText(find.byType(TextField).first, 'hola');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 2)); // animaciones de entrada
      expect(c.bubbles, isNotEmpty);

      // Laika está a la derecha → sus mensajes salen a su izquierda.
      final petLeft = tester.getTopLeft(petBox).dx;
      final bubbleText = find.textContaining(c.bubbles.last.text.substring(0, 3), findRichText: true);
      expect(tester.getTopRight(bubbleText.last).dx, lessThan(petLeft));

      // Sigue despierta mientras haya mensajes por leer (3 s por palabra)…
      await mouse.moveTo(const Offset(5, 5));
      for (var i = 0; i < 300 && c.bubbles.isNotEmpty; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(c.bubbles, isEmpty, reason: 'cada burbuja se va sola al pasar su tiempo de lectura');
      expect(c.state, PetState.awake, reason: 'no se duerme con mensajes por leer');
      // …y 15 s después de que se desvaneció el último, se duerme.
      await tester.pump(const Duration(seconds: 16));
      expect(c.state, PetState.asleep);
      expect(c.sleepPose, SleepPose.seated, reason: 'a los 15 s duerme sentada');
      expect(c.chatOpen, isFalse);
      await tester.pump(const Duration(seconds: 16));
      expect(c.sleepPose, SleepPose.lying, reason: '15 s después se acuesta');

      // Servidor caído → al pasar el mouse sigue dormida.
      (c.api as MockLaika).online = false;
      await mouse.moveTo(tester.getCenter(petBox));
      await tester.pump(const Duration(seconds: 2));
      expect(c.state, PetState.asleep);
      expect(c.wakeFailed, isTrue);
      (c.api as MockLaika).online = true;

      // Cerebro y Agenda.
      final (brainTab, agendaTab) = tabs[v.id]!;
      await tester.tap(brainTab.first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(600, 450));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(agendaTab.first);
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('a la izquierda de la pantalla, sus mensajes salen a su derecha', (tester) async {
    final c = await open(tester, 'cosmos');
    final petBox = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.grab);
    // Arrastrar a Laika hasta la izquierda.
    await tester.drag(petBox, const Offset(-1100, -300));
    await tester.pump();
    c.poke();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, 'hola');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 4));
    final petRight = tester.getTopRight(petBox).dx;
    final bubble = find.textContaining(c.bubbles.last.text.substring(0, 3), findRichText: true);
    expect(tester.getTopLeft(bubble.last).dx, greaterThan(petRight));
    await close(tester);
  });

  testWidgets('un recordatorio que suena dormida se dice al despertar', (tester) async {
    final c = await open(tester, 'cristal');
    (c.api as MockLaika).fireNextReminderNow();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.pendingReminders, isNotEmpty);
    c.poke();
    await tester.pump(const Duration(seconds: 1));
    expect(c.bubbles.any((b) => b.text.startsWith('⏰')), isTrue);
    await close(tester);
  });
}
