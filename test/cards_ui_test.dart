// La pestaña Tarjetas con el servidor simulado: lo que hace Esteban con el
// mouse (aplicar una sugerencia de Laika, agregar, corregir, repasar).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/session.dart';
import 'package:laika_app/variants/laika.dart';

void main() {
  late LaikaSession session;

  Future<MockLaika> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MockLaika()..latency = const Duration(milliseconds: 20);
    session = LaikaSession(api);
    await tester.pumpWidget(LaikaApp(session: session, showDesktop: false));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tarjetas').first);
    await settle(tester);
    return api;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('Laika sugiere en una tarjeta tuya: Aplicar la cambia', (tester) async {
    final api = await open(tester);
    expect(find.textContaining('Repasar · '), findsOneWidget);
    expect(find.text('Sugiere (es tuyo, decides tú):'), findsOneWidget);
    expect(find.textContaining('fila; profesión'), findsOneWidget);

    await tester.tap(find.text('Aplicar').first);
    await settle(tester);
    expect(find.text('Sugiere (es tuyo, decides tú):'), findsNothing);
    expect(api.cardStore.card(1).meaningEs, 'fila; profesión; banco (en 银行)');
    // Sigue siendo tuyo: Laika no lo puede volver a cambiar sola.
    expect(api.cardStore.card(1).isLocked('meaning_es'), isTrue);
    await close(tester);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('agregar un carácter: Laika llena el resto, y se puede deshacer', (tester) async {
    final api = await open(tester);
    await tester.enterText(find.byType(TextField).first, '猫');
    await tester.tap(find.text('Agregar'));
    await settle(tester);
    expect(find.text('Agregada: 猫 māo · gato'), findsOneWidget);
    final id = api.cardStore.list(q: '猫').cards.single.id;

    await tester.tap(find.text('Deshacer').last);
    await settle(tester);
    expect(api.cardStore.card(id).inTrash, isTrue);

    // Repetida: avisa en vez de duplicarla.
    await tester.enterText(find.byType(TextField).first, '爱');
    await tester.tap(find.text('Agregar'));
    await settle(tester);
    expect(find.text('Ya la tienes: 爱'), findsOneWidget);
    await close(tester);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('corregir una tarjeta la deja como tuya', (tester) async {
    final api = await open(tester);
    await tester.tap(find.text('茶'));
    await settle(tester);
    expect(find.text('Editar'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Significado'), 'té (la bebida)');
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    final c = api.cardStore.card(12);
    expect(c.meaningEs, 'té (la bebida)');
    expect(c.locked, ['meaning_es']);
    expect(find.text('Guardado: 茶 chá'), findsOneWidget);
    await close(tester);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('repasar: mostrar, calificar y deshacer', (tester) async {
    final api = await open(tester);
    final before = api.cardStore.counts().toStudy;
    await tester.tap(find.textContaining('Repasar · '));
    await settle(tester);
    expect(find.text('Mostrar (espacio)'), findsOneWidget);

    await tester.tap(find.text('Mostrar (espacio)'));
    await settle(tester);
    expect(find.text('Bien'), findsOneWidget);
    expect(find.textContaining('3 · '), findsOneWidget); // con la vista previa

    await tester.tap(find.text('Bien'));
    await settle(tester);
    expect(find.textContaining('1 hechas'), findsOneWidget);
    expect(api.cardStore.counts().toStudy, before - 1);

    await tester.tap(find.text('Deshacer (U)'));
    await settle(tester);
    expect(find.textContaining('0 hechas'), findsOneWidget);
    expect(api.cardStore.counts().toStudy, before);
    await close(tester);
  }, timeout: const Timeout(Duration(seconds: 40)));
}

/// La app tiene animaciones sin fin (fondo, mascota): no se puede esperar a
/// que "se calme", así que se avanza el reloj lo suficiente para la red simulada.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
