// Pruebas de humo: cada variante arranca, Laika despierta solo si el
// servidor (simulado) responde, contesta, se duerme a los 15 s, y las
// pestañas Cerebro y Agenda se dibujan sin errores.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pet.dart';
import 'package:laika_app/core/stage.dart';
import 'package:laika_app/main.dart';
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

      // 15 s sin hacer nada → se duerme.
      await mouse.moveTo(const Offset(5, 5));
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
