// Modo --pet: la ventana arranca en 1280×800 y luego cubre la pantalla. La zona
// que recibe clics tiene que seguir a Laika (si no, los clics no le llegan).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pet.dart';
import 'package:laika_app/core/stage.dart';
import 'package:laika_app/variants/laika.dart';

void main() {
  testWidgets('la zona de clics sigue a Laika cuando la ventana cambia de tamaño', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final api = MockLaika()..latency = Duration.zero;
    final c = PetController(api);
    final regions = <List<Rect>>[];
    await tester.pumpWidget(MaterialApp(
      home: Material(child: PetStage(controller: c, skin: const LaikaSkin(transparent: true), onRegions: regions.add)),
    ));
    await tester.pump();
    final petAt = tester.getRect(find.byType(GestureDetector).first);
    expect(regions.last.first.contains(petAt.center), isTrue);

    tester.view.physicalSize = const Size(1920, 1152); // ya cubre la pantalla
    await tester.pump();
    await tester.pump();
    final moved = tester.getRect(find.byType(GestureDetector).first);
    expect(moved.center, isNot(petAt.center), reason: 'Laika se fue a la nueva esquina');
    expect(regions.last.first.contains(moved.center), isTrue, reason: 'la zona de clics se fue con ella');

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    api.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
