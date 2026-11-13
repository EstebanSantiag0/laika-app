// Prueba EN VIVO de las tarjetas con el servidor real (junto con cc-server,
// 2026-11-13). No es parte de `flutter test`: escribe en el mazo real, así que
// solo usa caracteres raros (鼋 鼍 夔 鞘) con la nota "PRUEBA" y al final los
// manda a la papelera (se purgan solos a los 30 días). Caracteres raros porque
// volver a crear uno que está en la papelera lo RECUPERA: no queremos que un
// 行 de verdad regrese con el historial de una prueba.
//
// Fase 1:  LAIKA_SERVER=https://<tu-servidor> flutter test tool/cards_live_test.dart
//          Deja 鼍 con su significado bloqueado y escribe su id: con eso cc-server
//          hace que Laika sugiera otro significado y borrarla.
// Fase 2:  LAIKA_SERVER=… LAIKA_CARD=<id> flutter test tool/cards_live_test.dart
//
// La URL del servidor va en la variable de entorno: nunca en el repo (es público).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/api.dart';
import 'package:laika_app/core/http_laika.dart';
import 'package:laika_app/core/models.dart';

Matcher _api(int status) => throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', status));

void main() {
  final server = Platform.environment['LAIKA_SERVER'];
  if (server == null || server.isEmpty) {
    test('sin LAIKA_SERVER: no hay prueba en vivo', () {}, skip: 'pon LAIKA_SERVER');
    return;
  }
  final phase2 = int.tryParse(Platform.environment['LAIKA_CARD'] ?? '');
  final api = HttpLaika(server);
  final events = <CardEvent>[];
  final sub = api.events.listen((e) {
    if (e is CardEvent) events.add(e);
  });
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final note = 'PRUEBA $stamp';
  final trashAtEnd = <int>{};
  var clientSeq = 0;
  String cid() => 'live-$stamp-${clientSeq++}';

  Future<void> waitEvents() => Future<void>.delayed(const Duration(milliseconds: 1500));

  tearDownAll(() async {
    for (final id in trashAtEnd) {
      try {
        await api.deleteCard(id);
      } catch (_) {}
    }
    stdout.writeln('Tarjetas de prueba en la papelera: ${trashAtEnd.join(', ')}');
    await sub.cancel();
    api.dispose();
  });

  if (phase2 != null) {
    _phase2(api, phase2, trashAtEnd);
    return;
  }

  late Flashcard yuan, tuo, kui, qiao, shao;

  test('0. despierta (abre el WS) y lee el mazo', () async {
    expect((await api.health()).canWake, isTrue);
    final page = await api.cards();
    stdout.writeln('mazo: ${page.cards.length} tarjetas · counts ${page.counts.toJson()}');
    final due = await api.dueCards();
    expect(due.now, isNotNull, reason: '/due trae la hora del servidor');
    final feed = await api.cardEdits(limit: 5);
    stdout.writeln('feed: ${feed.edits.length} cambios recientes');
  });

  test('1. crear solo con el carácter: el servidor llena lectura y significados', () async {
    final w = await api.createCard(front: '鼋', note: note);
    yuan = w.card;
    trashAtEnd.add(yuan.id);
    stdout.writeln('鼋 → ${yuan.reading} (tono ${yuan.tone}) · ${yuan.meaningEs} · ${yuan.meaningEn} · locked ${yuan.locked}');
    expect(w.editId, isNotNull);
    expect(yuan.inTrash, isFalse);
    expect(yuan.reading, 'yuán');
    expect(yuan.tone, 2);
    expect(yuan.meaningEs.isNotEmpty || yuan.meaningEn.isNotEmpty, isTrue, reason: 'llenó algún significado');
    expect(yuan.note, note);
    expect(yuan.locked, isNot(contains('note')), reason: 'la nota no se bloquea');
    expect(yuan.editable, containsAll(['word', 'reading', 'meaning_es', 'meaning_en', 'note', 'suspended']));
    expect(yuan.schedule.isNew, isTrue);
    expect(yuan.updatedAtRaw, isNotNull);
  });

  test('2. repetida → 409 con card_id', () async {
    await expectLater(api.createCard(front: '鼋', note: note),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409).having((e) => e.cardId, 'card_id', yuan.id)));
  });

  test('3. lecturas: "qiao4" se acepta, otra lectura del mismo carácter, 409 y 422', () async {
    qiao = (await api.createCard(front: '鞘', reading: 'qiao4', note: note)).card;
    trashAtEnd.add(qiao.id);
    shao = (await api.createCard(front: '鞘', reading: 'shāo', note: note)).card;
    trashAtEnd.add(shao.id);
    stdout.writeln('鞘 → ${qiao.reading} / ${shao.reading}');
    expect(qiao.reading, 'qiào');
    expect(qiao.tone, 4);
    expect(shao.tone, 1);
    await expectLater(api.patchCard(qiao.id, {'reading': 'shāo'}, baseUpdatedAt: qiao.updatedAtRaw),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409).having((e) => e.cardId, 'card_id', shao.id)));
    await expectLater(api.patchCard(qiao.id, {'reading': 'mā'}, baseUpdatedAt: qiao.updatedAtRaw),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 422).having((e) => e.field, 'field', 'reading')));
  });

  test('4. editar bloquea; sin cambios → edit_id null; 409 viejo; unlock; deshacer', () async {
    final w = await api.patchCard(yuan.id, {'meaning_es': 'tortuga gigante (PRUEBA)'}, baseUpdatedAt: yuan.updatedAtRaw);
    expect(w.editId, isNotNull);
    expect(w.card.meaningEs, 'tortuga gigante (PRUEBA)');
    expect(w.card.isLocked('meaning_es'), isTrue);
    expect(w.card.updatedBy, CardWho.him);

    final same = await api.patchCard(yuan.id, {'meaning_es': 'tortuga gigante (PRUEBA)'}, baseUpdatedAt: w.card.updatedAtRaw);
    expect(same.editId, isNull, reason: 'no cambió nada');

    await expectLater(api.patchCard(yuan.id, {'note': '$note viejo'}, baseUpdatedAt: yuan.updatedAtRaw),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409).having((e) => e.cardId, 'card_id', yuan.id)));

    final undone = await api.undoCardEdit(w.editId!);
    expect(undone.card.meaningEs, yuan.meaningEs, reason: 'vuelve el significado de antes');
    await expectLater(api.undoCardEdit(w.editId!), _api(409));
    stdout.writeln('tras deshacer: locked ${undone.card.locked}');

    final un = await api.patchCard(yuan.id, {}, baseUpdatedAt: undone.card.updatedAtRaw, unlock: ['meaning_es']);
    expect(un.card.isLocked('meaning_es'), isFalse);

    final (c, history) = await api.card(yuan.id);
    stdout.writeln('historial de 鼋: ${history.map((e) => '${e.who.name}:${e.op}${e.undoneAt != null ? '(deshecho)' : ''}').join(' ')}');
    expect(history.any((e) => e.op == 'create'), isTrue);
    expect(c.id, yuan.id);
    yuan = c;
  });

  test('5. repasar: preview, client_id idempotente, deshacer el repaso', () async {
    kui = (await api.createCard(front: '夔', note: note)).card;
    trashAtEnd.add(kui.id);
    final due = await api.dueCards(limit: 500);
    final inQueue = due.cards.where((c) => c.id == kui.id).toList();
    stdout.writeln('due: ${due.cards.length} · counts ${due.counts.toJson()} · 夔 en la cola: ${inQueue.isNotEmpty}');
    if (inQueue.isEmpty) {
      markTestSkipped('夔 no entró en /due (¿tope de nuevas del día?)');
    } else {
      expect(inQueue.single.preview.keys.toSet(), {1, 2, 3, 4});
      for (final r in [1, 2, 3, 4]) {
        stdout.writeln('  $r ${ratingLabels[r]} → ${dueIn(inQueue.single.preview[r]!, due.now!)}');
      }
    }
    final left = due.counts.newLeftToday;
    final id = cid();
    final a = await api.reviewCard(kui.id, 3, clientId: id, durationMs: 4200);
    final b = await api.reviewCard(kui.id, 3, clientId: id, durationMs: 4200);
    expect(b.editId, a.editId, reason: 'mismo client_id = mismo repaso');
    expect(a.card.schedule.isNew, isFalse);
    expect(a.card.schedule.lastReviewAt, isNotNull);
    stdout.writeln('夔 tras "Bien": ${a.card.schedule.state}, vuelve ${a.card.schedule.dueAt}');
    if (inQueue.isNotEmpty) {
      final p = inQueue.single.preview[3]!;
      expect(a.card.schedule.dueAt!.difference(p).inSeconds.abs() < 120, isTrue, reason: 'la vista previa es exacta (fuzz off)');
    }

    final undo = await api.undoCardEdit(a.editId!);
    expect(undo.card.schedule.isNew, isTrue, reason: 'deshacer el repaso la deja nueva otra vez');
    final after = (await api.dueCards()).counts.newLeftToday;
    stdout.writeln('nuevas que caben hoy: antes $left, después de repasar y deshacer $after');
  });

  test('6. papelera: borrar, aparece en /api/trash, recuperar; recuperar otra vez → 409', () async {
    final del = await api.deleteCard(kui.id);
    expect(del.card.inTrash, isTrue);
    expect(del.editId, isNotNull);
    final t = await api.trash();
    expect(t.cards.any((c) => c.id == kui.id), isTrue);
    final page = await api.cards(filter: 'trash');
    expect(page.cards.any((c) => c.id == kui.id), isTrue);
    final back = await api.restoreCard(kui.id);
    expect(back.card.inTrash, isFalse);
    await expectLater(api.restoreCard(kui.id), _api(409));
    // Crear uno que está en la papelera lo recupera (201, edit = restore).
    await api.deleteCard(kui.id);
    final again = await api.createCard(front: '夔', note: note);
    expect(again.card.id, kui.id);
    expect(again.card.inTrash, isFalse);
  });

  test('7. búsqueda, filtros y el feed', () async {
    final hang = await api.cards(q: 'yuan');
    expect(hang.cards.any((c) => c.id == yuan.id), isTrue, reason: 'pinyin sin tonos');
    expect((await api.cards(q: '鼋')).cards.any((c) => c.id == yuan.id), isTrue);
    expect((await api.cards(filter: 'his')).cards.any((c) => c.id == yuan.id), isTrue);
    expect((await api.cards(filter: 'hers')).cards.any((c) => c.id == yuan.id), isFalse);
    final mine = await api.cardEdits(who: 'him', limit: 50);
    final e = mine.edits.firstWhere((e) => e.cardId == yuan.id);
    expect(e.card?.front, '鼋', reason: 'cada Edit del feed trae su tarjeta');
  });

  test('8. audio', () async {
    final path = await api.cardAudio(yuan.id);
    expect(path, isNotNull);
    final f = File(path!);
    final head = String.fromCharCodes(f.readAsBytesSync().take(4));
    stdout.writeln('audio de 鼋: ${f.lengthSync()} bytes ($head)');
    expect(head, 'OggS');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('9. eventos por el WS', () async {
    await waitEvents();
    final ops = events.map((e) => '${e.op}:${e.card.front}').toList();
    stdout.writeln('eventos card: ${ops.length} → ${ops.take(12).join(' ')}…');
    expect(events.any((e) => e.op == 'created' && e.card.id == yuan.id), isTrue);
    expect(events.any((e) => e.op == 'reviewed' && e.card.id == kui.id), isTrue);
    expect(events.every((e) => e.counts != null), isTrue, reason: 'cada evento trae counts');
  });

  test('10. deja 鼍 bloqueada para las sugerencias de Laika (fase 2)', () async {
    tuo = (await api.createCard(front: '鼍', note: note)).card;
    final w = await api.patchCard(tuo.id, {'meaning_es': 'aligátor chino (PRUEBA)'}, baseUpdatedAt: tuo.updatedAtRaw);
    expect(w.card.isLocked('meaning_es'), isTrue);
    stdout.writeln('>>> 鼍 id=${tuo.id}: pásaselo a cc-server para la fase 2 (LAIKA_CARD=${tuo.id})');
  });
}

void _phase2(LaikaApi api, int id, Set<int> trashAtEnd) {
  late CardEdit change, deletion;

  test('F2-1. las dos sugerencias de Laika aparecen en el feed y en la tarjeta', () async {
    trashAtEnd.add(id);
    final feed = await api.cardEdits(who: 'laika', op: 'suggest', pending: true);
    final mine = feed.edits.where((e) => e.cardId == id).toList();
    stdout.writeln('sugerencias pendientes de 鼍: ${mine.map((e) => '${e.id} ${e.after}').join(' | ')}');
    expect(mine.length, 2);
    change = mine.firstWhere((e) => !e.proposesDeletion);
    deletion = mine.firstWhere((e) => e.proposesDeletion);
    expect(change.status, 'pending');
    expect(change.who, CardWho.laika);
    expect(change.fields, contains('meaning_es'));
    expect(change.card?.front, '鼍');
    final (c, _) = await api.card(id);
    expect(c.suggestions.toSet(), containsAll({change.id, deletion.id}));
    expect((await api.cards()).counts.suggestions, greaterThanOrEqualTo(2));
  });

  test('F2-2. Aplicar la de significado; contestar otra vez → 409; deshacer', () async {
    final w = await api.answerSuggestion(change.id, apply: true);
    expect(w.card.meaningEs, change.after['meaning_es']);
    expect(w.card.suggestions, isNot(contains(change.id)));
    stdout.writeln('aplicada: ${w.card.meaningEs} · locked ${w.card.locked} · edit ${w.editId}');
    await expectLater(api.answerSuggestion(change.id, apply: true), _api(409));
    if (w.editId != null) {
      final u = await api.undoCardEdit(w.editId!);
      expect(u.card.meaningEs, 'aligátor chino (PRUEBA)');
    }
  });

  test('F2-3. No a la de borrarla: sigue viva', () async {
    final w = await api.answerSuggestion(deletion.id, apply: false);
    expect(w.card.inTrash, isFalse);
    expect(w.card.suggestions, isEmpty);
    final feed = await api.cardEdits(who: 'laika', op: 'suggest');
    final d = feed.edits.firstWhere((e) => e.id == deletion.id);
    expect(d.status, 'dismissed');
    expect(feed.edits.firstWhere((e) => e.id == change.id).status, 'applied');
  });
}
