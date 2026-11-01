// Genera las capturas de docs/screenshots/ con las fuentes reales del sistema.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// (No forma parte de `flutter test`: las capturas dependen de las fuentes
// instaladas en cada computadora.)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/session.dart';
import 'package:laika_app/core/stage.dart';
import 'package:laika_app/main.dart';
import 'package:laika_app/variants/variants.dart';

final _flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;

const _fonts = {
  'Adwaita Sans': ['/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf'],
  'Noto Serif': [
    '/usr/share/fonts/noto/NotoSerif-Regular.ttf',
    '/usr/share/fonts/noto/NotoSerif-Italic.ttf',
    '/usr/share/fonts/noto/NotoSerif-Bold.ttf',
    '/usr/share/fonts/noto/NotoSerif-BoldItalic.ttf',
  ],
  'Hack': ['/usr/share/fonts/TTF/Hack-Regular.ttf', '/usr/share/fonts/TTF/Hack-Bold.ttf'],
  'Liberation Sans': ['/usr/share/fonts/liberation/LiberationSans-Regular.ttf'],
};

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);
  for (final e in _fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      if (File(f).existsSync()) loader.addFont(bytes(f));
    }
    await loader.load();
  }
  final icons = '$_flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(icons).existsSync()) await (FontLoader('MaterialIcons')..addFont(bytes(icons))).load();
  final roboto = '$_flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (File(roboto).existsSync()) await (FontLoader('Roboto')..addFont(bytes(roboto))).load();
}

final _tabs = <String, (Finder, Finder)>{
  'laika': (find.text('Cerebro'), find.text('Agenda')),
  'cosmos': (find.byIcon(Icons.blur_on), find.byIcon(Icons.schedule)),
  'papel': (find.text('Cerebro'), find.text('Agenda')),
  'pixel': (find.text('[F2] CEREBRO'), find.text('[F3] AGENDA')),
  'brutal': (find.text('CEREBRO'), find.text('AGENDA')),
  'cristal': (find.text('Cerebro'), find.text('Agenda')),
};

void main() {
  setUpAll(_loadFonts);

  for (final v in allVariants) {
    testWidgets('capturas: ${v.id}', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(LaikaPrototypes(initial: v.id));
      await tester.pump();
      final c = tester.widget<PetStage>(find.byType(PetStage)).controller;
      final s = tester.widget<SessionScope>(find.byType(SessionScope)).session;

      Future<void> say(String text) async {
        await tester.enterText(find.byType(TextField).first, text);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      c.poke();
      await tester.pump(const Duration(seconds: 1));
      await say('quiero hacer prácticas este verano');
      await say('recuérdame pagar la renta');
      await tester.pump(const Duration(seconds: 2));
      await expectLater(find.byType(VariantHost), matchesGoldenFile('../docs/screenshots/${v.id}-1-escritorio.png'));

      final (brainTab, agendaTab) = _tabs[v.id]!;
      await tester.tap(brainTab.first);
      s.brain.select('entity:app');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(VariantHost), matchesGoldenFile('../docs/screenshots/${v.id}-2-cerebro.png'));

      await tester.tap(agendaTab.first);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(VariantHost), matchesGoldenFile('../docs/screenshots/${v.id}-3-agenda.png'));

      if (v.id == 'laika') {
        await tester.tap(find.text('Mascota'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await expectLater(find.byType(VariantHost), matchesGoldenFile('../docs/screenshots/laika-4-mascotas.png'));
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
