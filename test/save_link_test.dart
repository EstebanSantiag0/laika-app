// Esteban: guardar un link de Tailscale dejó la app gris y congelada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/main.dart';

void main() {
  testWidgets('guardar un link de Tailscale en Guardados no congela la app', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LaikaPrototypes(initial: 'laika'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Guardados').first);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, 'https://cc-server.tu-tailnet.ts.net/');
    await tester.tap(find.text('Guardar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('cc-server.tu-tailnet.ts.net'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('guardar el link de Tailscale como servidor en Ajustes no congela la app', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LaikaPrototypes(initial: 'laika'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ajustes').first);
    await tester.pump(const Duration(seconds: 1));
    final field = find.byType(TextField).last;
    await tester.enterText(field, 'https://cc-server.tu-tailnet.ts.net/');
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar').last);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Servidor guardado ✓'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(seconds: 40)));
}
