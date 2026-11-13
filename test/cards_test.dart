// Tarjetas: el contrato acordado con cc-server (2026-11-13) y las reglas que
// el servidor simulado debe imitar.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/api.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/mock_cards.dart';
import 'package:laika_app/core/models.dart';
import 'package:laika_app/core/pet.dart';

/// La tarjeta de ejemplo del borrador de cc-server, con lo que se agregó después.
const serverCard = {
  'id': 12,
  'kind': 'hanzi',
  'front': '行',
  'word': '银行',
  'reading': 'háng',
  'tone': 2,
  'meaning_es': 'fila; banco',
  'meaning_en': 'row; bank',
  'note': '',
  'known_words': [
    {'word': '银行', 'reading': 'yínháng', 'gloss_es': 'banco', 'gloss_en': 'bank'},
  ],
  'parts': ['彳', '亍'],
  'audio': '/api/cards/12/audio',
  'source': 'him',
  'created_by': 'him',
  'updated_by': 'laika',
  'created_at': '2026-11-13T10:00:00Z',
  'updated_at': '2026-11-13T12:00:00.123456+00:00',
  'locked': ['meaning_es'],
  'suspended': false,
  'deleted_at': null,
  'editable': ['word', 'reading', 'meaning_es', 'meaning_en', 'note', 'suspended'],
  'schedule': {
    'due_at': '2026-11-14T10:00:00Z',
    'state': 'review',
    'stability': 3.2,
    'difficulty': 5.1,
    'last_review_at': '2026-11-13T10:00:00Z',
  },
  'suggestions': [40],
  'flags': ['check_meaning'],
  'preview': {'1': '2026-11-13T12:10:00Z', '3': '2026-11-16T12:00:00Z'},
};

void main() {
  group('contrato', () {
    test('lee la tarjeta del servidor', () {
      final c = Flashcard.fromJson(serverCard);
      expect(c.front, '行');
      expect(c.tone, 2);
      expect(c.isLocked('meaning_es'), isTrue);
      expect(c.isLocked('meaning_en'), isFalse);
      expect(c.updatedBy, CardWho.laika);
      expect(c.schedule.state, 'review');
      expect(c.schedule.label, 'Repaso');
      expect(c.knownWords.single.glossEs, 'banco');
      expect(c.suggestions, [40]);
      expect(c.checkMeaning, isTrue);
      expect(c.preview.keys, [1, 3]);
      // base_updated_at se manda tal cual llegó.
      expect(c.updatedAtRaw, '2026-11-13T12:00:00.123456+00:00');
    });

    test('evento card, edit con sugerencia de borrar y conteos', () {
      final e = CardEvent.fromJson({
        'type': 'card',
        'op': 'edited',
        'who': 'laika',
        'card': serverCard,
        'edit_id': 41,
        'counts': {'total': 5, 'due': 2, 'new': 3, 'new_left_today': 1, 'suggestions': 1},
      });
      expect(e.who, CardWho.laika);
      expect(e.counts!.toStudy, 3); // 2 para hoy + 1 nueva que todavía cabe
      final s = CardEdit.fromJson({
        'id': 40, 'card_id': 12, 'who': 'laika', 'op': 'suggest', 'status': 'pending',
        'before': {}, 'after': {'deleted': true}, 'undoable': false,
        'card': {'id': 12, 'front': '行', 'reading': 'háng', 'word': '银行'},
      });
      expect(s.pending, isTrue);
      expect(s.proposesDeletion, isTrue);
      expect(s.fields, isEmpty);
      expect(s.card!.front, '行');
    });

    test('pinyin sin tonos para buscar', () {
      expect(plainPinyin('Háng'), 'hang');
      expect(plainPinyin('lǜ'), 'lv');
      expect(plainPinyin('hao3'), 'hao');
      expect(toneOf('háng'), 2);
      expect(toneOf('ma'), 5);
      expect(toneOf('shuǐ'), 3);
    });
  });

  group('servidor simulado', () {
    final t0 = DateTime.utc(2026, 11, 13, 12);
    late MockCardStore s;
    setUp(() => s = withClock(Clock.fixed(t0), () => MockCardStore(t0)));
    T at<T>(T Function() f, [Duration plus = Duration.zero]) => withClock(Clock.fixed(t0.add(plus)), f);

    test('lo que editas queda bloqueado: Laika solo sugiere, y tú decides', () {
      at(() {
        final c = s.card(4); // 学, de Laika, sin bloqueos
        final w = s.patch(4, {'meaning_es': 'estudiar; aprender'}, baseUpdatedAt: c.updatedAtRaw);
        expect(w.card.isLocked('meaning_es'), isTrue);
        expect(w.editId, isNotNull);

        final e = s.laikaEdits(4, {'meaning_es': 'aprender'}, reason: 'prueba');
        expect(e.op, 'suggest');
        expect(s.card(4).meaningEs, 'estudiar; aprender'); // no la tocó
        expect(s.card(4).suggestions, contains(e.id));

        final applied = s.answer(e.id, apply: true);
        expect(applied.card.meaningEs, 'aprender');
        expect(applied.card.suggestions, isNot(contains(e.id)));
        // Aplicar también se puede deshacer.
        expect(s.undo(applied.editId!).card.meaningEs, 'estudiar; aprender');
      });
    });

    test('lo que no es tuyo, Laika lo cambia (y se puede deshacer)', () {
      at(() {
        final e = s.laikaEdits(7, {'meaning_en': 'question word'});
        expect(e.op, 'edit');
        expect(s.card(7).meaningEn, 'question word');
        expect(s.edits(who: 'laika').edits.first.undoable, isTrue);
        expect(s.undo(e.id).card.meaningEn, 'question particle');
      });
    });

    test('unlock le devuelve el campo a Laika', () {
      at(() {
        expect(s.card(1).isLocked('meaning_es'), isTrue);
        final w = s.patch(1, {}, unlock: ['meaning_es']);
        expect(w.card.isLocked('meaning_es'), isFalse);
      });
    });

    test('409 si la tarjeta cambió mientras la editabas', () {
      at(() {
        final viejo = s.card(3).updatedAtRaw;
        at(() => s.patch(3, {'note': 'primero'}), const Duration(minutes: 1));
        expect(() => s.patch(3, {'note': 'segundo'}, baseUpdatedAt: viejo),
            throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409)));
      });
    });

    test('no se puede deshacer si algo posterior tocó el mismo campo', () {
      at(() {
        final a = s.patch(3, {'note': 'uno'});
        at(() => s.patch(3, {'note': 'dos'}), const Duration(minutes: 1));
        expect(() => s.undo(a.editId!), throwsA(isA<LaikaApiError>().having((e) => e.conflict, 'conflict', isTrue)));
      });
    });

    test('crear: 409 con card_id si ya existe; si estaba en la papelera, vuelve', () {
      at(() {
        expect(() => s.create(front: '行', reading: 'háng'),
            throwsA(isA<LaikaApiError>().having((e) => e.cardId, 'cardId', 1)));
        final back = s.create(front: '书');
        expect(back.card.id, 11);
        expect(back.card.inTrash, isFalse);
        final nueva = s.create(front: '猫');
        expect(nueva.card.reading, 'māo'); // el servidor llena lo que falta
        expect(nueva.card.meaningEs, 'gato');
        expect(nueva.card.locked, isEmpty); // no escribiste nada más que el carácter
        expect(() => s.create(front: '猫', reading: 'gǒu'),
            throwsA(isA<LaikaApiError>().having((e) => e.field, 'field', 'reading')));
      });
    });

    test('repasar: idempotente con client_id, deshacible, y tope diario de nuevas', () {
      at(() {
        s.newPerDay = 2;
        final due = s.due();
        expect(due.cards.where((c) => c.schedule.isNew).length, 2);
        expect(due.cards.every((c) => c.preview.length == 4), isTrue);
        expect(due.now, t0);

        final nueva = due.cards.firstWhere((c) => c.schedule.isNew);
        final a = s.review(nueva.id, 3, clientId: 'x1');
        final b = s.review(nueva.id, 3, clientId: 'x1'); // reintento: no cuenta dos veces
        expect(b.editId, a.editId);
        expect(s.counts().newLeftToday, 1);
        expect(a.card.schedule.state, 'learning');

        s.undo(a.editId!);
        expect(s.card(nueva.id).schedule.isNew, isTrue);
        expect(s.counts().newLeftToday, 2);
      });
    });

    test('papelera y filtros', () {
      at(() {
        expect(s.list(filter: 'trash').cards.map((c) => c.front), ['书']);
        s.delete(2);
        expect(s.list(filter: 'trash').cards.length, 2);
        expect(s.list().cards.any((c) => c.id == 2), isFalse);
        expect(s.list(filter: 'hers').cards.every((c) => c.byLaika), isTrue);
        expect(s.list(q: 'hang').cards.single.front, '行');
        expect(s.card(8).checkMeaning, isTrue);
        s.patch(8, {'meaning_en': 'silver'});
        expect(s.card(8).checkMeaning, isFalse);
      });
    });
  });

  test('la mascota ignora las tarjetas (decisión de Esteban)', () async {
    final api = MockLaika()..latency = Duration.zero;
    final pet = PetController(api, idle: const Duration(seconds: 30));
    pet.hover();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pet.isAwake, isTrue);
    final bubbles = pet.bubbles.length, mood = pet.mood;
    api.laikaEditsCard(7, {'meaning_en': 'question word'});
    api.laikaEditsCard(1, {'meaning_es': 'otra cosa'}); // sugerencia en un campo tuyo
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(pet.bubbles.length, bubbles);
    expect(pet.mood, mood);
    pet.dispose();
    api.dispose();
  });
}
