// La caja de la mascota (Esteban, 2026-11-02): (+) ______ (🎤). Con texto o
// grabando, el micrófono se vuelve el avioncito. El (+) abre: Archivo / Captura.
// Encima, el idioma ("RU ▾").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/media.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/pet.dart';
import 'package:laika_app/core/stage.dart';
import 'package:laika_app/variants/laika.dart';

class FakeRecorder extends VoiceRecorder {
  bool on = false;
  @override
  bool get active => on;
  @override
  Future<void> start() async => on = true;
  @override
  Future<String?> stop() async {
    on = false;
    return '/tmp/voz.ogg';
  }

  @override
  Future<void> cancel() async => on = false;
}

class FakeMedia extends Media {
  FakeMedia(this.pet);
  final PetController Function() pet;
  final rec = FakeRecorder();
  bool? hiddenDuringShot;
  @override
  bool get supported => true;
  @override
  VoiceRecorder recorder() => rec;
  @override
  Future<String?> pickFile() async => '/tmp/PRUEBA apuntes.pdf';
  @override
  Future<String?> screenshotRegion() async {
    hiddenDuringShot = pet().hiddenForShot;
    return '/tmp/captura.png';
  }
}

void main() {
  testWidgets('caja: micrófono ↔ avioncito, menú (+), idioma, voz, archivo y captura', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final api = MockLaika()..latency = Duration.zero;
    final c = PetController(api);
    final media = FakeMedia(() => c);
    final regions = <List<Rect>>[];
    await tester.pumpWidget(MaterialApp(
      home: Material(
          child: PetStage(controller: c, skin: const LaikaSkin(transparent: true), onRegions: regions.add, media: media)),
    ));
    c.poke(); // un clic: despierta y abre la caja
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.chatOpen, isTrue);

    // (+) ___ (🎤) y el idioma que ya tenía.
    expect(find.byKey(const ValueKey('pet-plus')), findsOneWidget);
    expect(find.byKey(const ValueKey('pet-mic')), findsOneWidget);
    expect(find.text('RU ▾'), findsOneWidget);

    // Al escribir, el micrófono se vuelve el avioncito; al borrar, regresa.
    await tester.enterText(find.byType(TextField), 'привет');
    await tester.pump();
    expect(find.byKey(const ValueKey('pet-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('pet-mic')), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byKey(const ValueKey('pet-mic')), findsOneWidget);

    // Cambiar de idioma.
    await tester.tap(find.text('RU ▾'));
    await tester.pump();
    await tester.tap(find.text('中文'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.lang, 'zh');
    expect(find.text('ZH ▾'), findsOneWidget);

    // (+) → Captura: Laika se esconde mientras eliges, y luego se la come.
    await tester.tap(find.byKey(const ValueKey('pet-plus')));
    await tester.pump();
    expect(find.text('Archivo'), findsOneWidget);
    expect(find.text('Captura de pantalla'), findsOneWidget);
    await tester.tap(find.text('Captura de pantalla'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(regions.last, isEmpty, reason: 'escondida: no toma clics ni sale en la foto');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(media.hiddenDuringShot, isTrue);
    expect(c.hiddenForShot, isFalse);
    expect(c.lastMine, '🖼️ Captura de pantalla');
    expect(c.mood, Mood.eating);
    await tester.pump(const Duration(seconds: 2));
    expect(c.bubbles.any((b) => b.text.contains('captura.png')), isTrue, reason: 'lo comenta');

    // (+) → Archivo.
    await tester.tap(find.byKey(const ValueKey('pet-plus')));
    await tester.pump();
    await tester.tap(find.text('Archivo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.lastMine, '📎 PRUEBA apuntes.pdf');

    // 🎤: graba (no se duerme), ✈ manda la nota de voz.
    await tester.tap(find.byKey(const ValueKey('pet-mic')));
    await tester.pump();
    expect(media.rec.active, isTrue);
    expect(find.text('grabando…'), findsOneWidget);
    expect(find.byKey(const ValueKey('pet-send')), findsOneWidget);
    await tester.pump(const Duration(seconds: 40));
    expect(c.isAwake, isTrue, reason: 'no se duerme mientras grabas');
    expect(find.text('0:40'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-send')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.lastMine, '🎤 Nota de voz');
    await tester.pump(const Duration(seconds: 1));
    expect(c.bubbles.any((b) => b.text.startsWith('Te escuché')), isTrue);

    // ✕ cancela una grabación sin mandarla.
    await tester.tap(find.byKey(const ValueKey('pet-mic')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pet-cancel-recording')));
    await tester.pump();
    expect(media.rec.active, isFalse);
    expect(c.recordingVoice, isFalse);
    expect(c.lastMine, '🎤 Nota de voz', reason: 'no mandó otra');

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    api.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
