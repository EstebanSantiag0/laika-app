// Tarjetas del servidor simulado: se comportan como el contrato acordado con
// cc-server (bloqueos, sugerencias de Laika, deshacer, repasos idempotentes,
// tope diario de nuevas), sin red. La agenda imita a FSRS de forma sencilla
// (1 min / 6 min / 10 min / 4 d para las nuevas); el servidor real usa py-fsrs.
//
// Datos de ejemplo ficticios (repo público): caracteres comunes, nada personal.

import 'dart:math';

import 'package:clock/clock.dart';

import 'api.dart';

/// Un diccionario mínimo para "llenar lo que falte" al crear una tarjeta.
const _dict = <String, List<(String, int, String, String, String?)>>{
  // carácter: [(lectura, tono, significado, inglés, palabra)]
  '爱': [('ài', 4, 'amor; amar', 'love; to love', '爱好')],
  '行': [('háng', 2, 'fila; banco (en 银行)', 'row; line; bank', '银行'), ('xíng', 2, 'andar; estar bien', 'to walk; OK', '不行')],
  '学': [('xué', 2, 'estudiar; aprender', 'to study; to learn', '学生')],
  '好': [('hǎo', 3, 'bien; bueno', 'good; well', '你好'), ('hào', 4, 'gustar de', 'to be fond of', '爱好')],
  '妈': [('mā', 1, 'mamá', 'mom', '妈妈')],
  '吗': [('ma', 5, 'partícula de pregunta', 'question particle', '好吗')],
  '银': [('yín', 2, 'plata', 'silver', '银行')],
  '中': [('zhōng', 1, 'medio; China', 'middle; China', '中国')],
  '水': [('shuǐ', 3, 'agua', 'water', '喝水')],
  '书': [('shū', 1, 'libro', 'book', '看书')],
  '茶': [('chá', 2, 'té', 'tea', '喝茶')],
  '猫': [('māo', 1, 'gato', 'cat', '小猫')],
  '狗': [('gǒu', 3, 'perro', 'dog', '小狗')],
  '火': [('huǒ', 3, 'fuego', 'fire', '火车')],
};

class MockCardStore {
  MockCardStore(DateTime t) {
    _seed(t);
  }

  /// cards.new_per_day del servidor.
  int newPerDay = 10;

  final Map<int, Flashcard> _cards = {};
  final List<CardEdit> _edits = [];
  final Set<int> _checkMeaning = {};
  final Map<String, CardWrite> _reviews = {}; // client_id → respuesta (idempotente)
  final Map<int, List<String>> _lockedBefore = {}; // edit → `locked` antes de él
  final Map<String, int> _newShown = {}; // día → nuevas que ya entraron
  int _nextCard = 1;
  int _nextEdit = 1;

  DateTime get _now => clock.now().toUtc();
  String _iso(DateTime d) => d.toUtc().toIso8601String();
  String _day(DateTime d) => d.toLocal().toIso8601String().substring(0, 10);

  static LaikaApiError _missing() => const LaikaApiError(404, 'Esa tarjeta no existe');

  // ── Lectura ──────────────────────────────────────────────────────────────

  /// La tarjeta como la manda el servidor: con sus sugerencias pendientes y avisos.
  Flashcard _out(Flashcard c) => _with(c, {
        'suggestions': [for (final e in _edits) if (e.cardId == c.id && e.pending) e.id],
        'flags': [if (_checkMeaning.contains(c.id) && !c.isLocked('meaning_en')) 'check_meaning'],
      });

  Flashcard _with(Flashcard c, Map<String, Object?> changes) => Flashcard.fromJson({...c.toJson(), ...changes});

  Flashcard _get(int id) => _cards[id] ?? (throw _missing());

  bool _isDue(Flashcard c, DateTime now) =>
      !c.inTrash && !c.suspended && !c.schedule.isNew && !(c.schedule.dueAt ?? now).isAfter(now);

  int get _newLeftToday => max(0, newPerDay - (_newShown[_day(_now)] ?? 0));

  CardCounts counts() {
    final now = _now;
    final live = _cards.values.where((c) => !c.inTrash);
    return CardCounts(
      total: live.length,
      due: live.where((c) => _isDue(c, now)).length,
      newCards: live.where((c) => c.schedule.isNew && !c.suspended).length,
      learning: live.where((c) => c.schedule.state == 'learning' || c.schedule.state == 'relearning').length,
      suspended: live.where((c) => c.suspended).length,
      trash: _cards.values.where((c) => c.inTrash).length,
      newLeftToday: _newLeftToday,
      suggestions: _edits.where((e) => e.pending).length,
    );
  }

  bool _matches(Flashcard c, String q) {
    final p = plainPinyin(q.trim());
    final low = q.trim().toLowerCase();
    return c.front.contains(q.trim()) ||
        (c.word ?? '').contains(q.trim()) ||
        plainPinyin(c.reading).contains(p) ||
        c.meaningEs.toLowerCase().contains(low) ||
        c.meaningEn.toLowerCase().contains(low);
  }

  CardPage list({String filter = 'all', String? q, int? before, int limit = 500}) {
    final now = _now;
    bool keep(Flashcard c) => switch (filter) {
          'trash' => c.inTrash,
          'due' => _isDue(c, now),
          'new' => !c.inTrash && c.schedule.isNew,
          'his' => !c.inTrash && c.createdBy == CardWho.him,
          'hers' => !c.inTrash && c.createdBy == CardWho.laika,
          'hard' => !c.inTrash && (c.schedule.difficulty ?? 0) >= 7,
          _ => !c.inTrash,
        };
    final all = _cards.values
        .where(keep)
        .where((c) => q == null || q.trim().isEmpty || _matches(c, q))
        .where((c) => before == null || c.id < before)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final page = all.take(limit.clamp(1, 500)).toList();
    return CardPage([for (final c in page) _out(c)],
        nextBefore: all.length > page.length ? page.last.id : null, counts: counts());
  }

  (Flashcard, List<CardEdit>) get(int id) {
    final c = _out(_get(id));
    final history = [for (final e in _edits.reversed) if (e.cardId == id) _withUndoable(e)];
    return (c, history);
  }

  List<Flashcard> trash() => [for (final c in _cards.values) if (c.inTrash) _out(c)];

  DueCards due({int limit = 20}) {
    final now = _now;
    final reviews = _cards.values.where((c) => _isDue(c, now)).toList()
      ..sort((a, b) => (a.schedule.dueAt ?? now).compareTo(b.schedule.dueAt ?? now));
    final fresh = _cards.values.where((c) => !c.inTrash && !c.suspended && c.schedule.isNew).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final picked = [...reviews, ...fresh.take(_newLeftToday)].take(limit).toList();
    return DueCards([
      for (final c in picked)
        _with(_out(c), {
          'preview': {for (final r in [1, 2, 3, 4]) '$r': _iso(_schedule(c.schedule, r, now).dueAt!)},
        }),
    ], now: now, counts: counts());
  }

  CardEditPage edits({String? who, String? op, bool pending = false, int? before, int limit = 50}) {
    final all = [
      for (final e in _edits.reversed)
        if ((who == null || e.who.name == who) &&
            (op == null || e.op == op) &&
            (!pending || e.pending) &&
            (before == null || e.id < before))
          e,
    ];
    final page = all.take(limit.clamp(1, 200)).toList();
    return CardEditPage([for (final e in page) _withUndoable(e)], nextBefore: all.length > page.length ? page.last.id : null);
  }

  // ── Escritura ────────────────────────────────────────────────────────────

  CardEdit _record(int cardId, CardWho who, String op, Map<String, Object?> before, Map<String, Object?> after,
      {String? reason, String? status, List<String>? lockedBefore}) {
    final c = _cards[cardId];
    final e = CardEdit(
      id: _nextEdit++,
      cardId: cardId,
      at: _now,
      who: who,
      op: op,
      before: before,
      after: after,
      reason: reason,
      status: status,
      card: c == null ? null : CardRef(id: c.id, front: c.front, reading: c.reading, word: c.word),
    );
    _edits.add(e);
    if (lockedBefore != null) _lockedBefore[e.id] = lockedBefore;
    return e;
  }

  CardEdit _replaceEdit(CardEdit e, Map<String, Object?> changes) {
    final n = CardEdit.fromJson({...e.toJson(), ...changes});
    _edits[_edits.indexWhere((x) => x.id == e.id)] = n;
    return n;
  }

  /// ¿Algún cambio posterior (no deshecho) choca con deshacer [e]? (409)
  /// Una edición: otra edición de los mismos campos. Un repaso: otro repaso.
  /// Crear/borrar/recuperar: otro borrar/recuperar.
  bool _touchedLater(CardEdit e) => _edits.any((x) {
        if (x.id <= e.id || x.cardId != e.cardId || x.undoneAt != null || x.isSuggestion) return false;
        return switch (e.op) {
          'edit' => x.op == 'edit' && x.fields.any(e.fields.contains),
          'review' => x.op == 'review',
          'create' || 'delete' || 'restore' => x.op == 'delete' || x.op == 'restore',
          _ => false,
        };
      });

  CardEdit _withUndoable(CardEdit e) {
    final ok = e.undoneAt == null && (!e.isSuggestion || e.status == 'dismissed') && !_touchedLater(e);
    return ok == e.undoable ? e : CardEdit.fromJson({...e.toJson(), 'undoable': ok});
  }

  CardWrite _write(Flashcard c, CardEdit? e) {
    _cards[c.id] = c;
    return CardWrite(_out(c), e?.id);
  }

  (String, int, String, String, String?)? _lookup(String front, String? reading) {
    final options = _dict[front];
    if (options == null || options.isEmpty) return null;
    if (reading == null || reading.isEmpty) return options.first;
    for (final o in options) {
      if (plainPinyin(o.$1) == plainPinyin(reading) && (toneOf(reading) == 5 || toneOf(reading) == o.$2)) return o;
    }
    return null;
  }

  Flashcard? _existing(String front, String reading, {int? except}) {
    for (final c in _cards.values) {
      if (c.id != except && c.front == front && plainPinyin(c.reading) == plainPinyin(reading) && toneOf(c.reading) == toneOf(reading)) {
        return c;
      }
    }
    return null;
  }

  CardWrite create(
      {required String front, String? reading, String? word, String? meaningEs, String? meaningEn, String? note, CardWho who = CardWho.him}) {
    final f = front.trim();
    if (f.runes.length != 1) throw const LaikaApiError(422, 'Escribe un solo carácter', field: 'front');
    final known = _lookup(f, reading);
    if (reading != null && reading.trim().isNotEmpty && _dict.containsKey(f) && known == null) {
      throw const LaikaApiError(422, 'Ese carácter no tiene esa lectura', field: 'reading');
    }
    final r = (reading?.trim().isNotEmpty ?? false) ? reading!.trim() : (known?.$1 ?? '');
    final dup = _existing(f, r);
    if (dup != null) {
      if (!dup.inTrash) throw LaikaApiError(409, 'Ya tienes esa tarjeta', cardId: dup.id);
      final back = _with(dup, {'deleted_at': null, 'updated_at': _iso(_now)});
      final e = _record(dup.id, who, 'restore', {'deleted': true}, {'deleted': false});
      return _write(back, e);
    }
    final now = _now;
    final given = {
      if (reading?.trim().isNotEmpty ?? false) 'reading',
      if (word?.trim().isNotEmpty ?? false) 'word',
      if (meaningEs?.trim().isNotEmpty ?? false) 'meaning_es',
      if (meaningEn?.trim().isNotEmpty ?? false) 'meaning_en',
    };
    final c = Flashcard(
      id: _nextCard++,
      front: f,
      reading: r,
      tone: toneOf(r),
      word: (word?.trim().isNotEmpty ?? false) ? word!.trim() : known?.$5,
      meaningEs: (meaningEs?.trim().isNotEmpty ?? false) ? meaningEs!.trim() : (known?.$3 ?? ''),
      meaningEn: (meaningEn?.trim().isNotEmpty ?? false) ? meaningEn!.trim() : (known?.$4 ?? ''),
      note: who == CardWho.him ? (note ?? '').trim() : '',
      source: who.name,
      createdBy: who,
      updatedBy: who,
      createdAt: now,
      updatedAt: now,
      updatedAtRaw: _iso(now),
      locked: who == CardWho.him ? given.toList() : const [],
    );
    _cards[c.id] = c;
    final e = _record(c.id, who, 'create', const {}, {
      for (final k in ['front', 'reading', 'word', 'meaning_es', 'meaning_en']) k: c.field(k),
    });
    return _write(c, e);
  }

  CardWrite patch(int id, Map<String, Object?> fields, {String? baseUpdatedAt, List<String>? unlock}) {
    final c = _get(id);
    if (c.inTrash) throw const LaikaApiError(409, 'Está en la papelera: recupérala primero');
    if (baseUpdatedAt != null) {
      final base = DateTime.tryParse(baseUpdatedAt);
      if (base == null) throw const LaikaApiError(422, 'Fecha inválida', field: 'base_updated_at');
      if (c.updatedAt != null && !base.isAtSameMomentAs(c.updatedAt!)) {
        throw LaikaApiError(409, 'La tarjeta cambió mientras la editabas', cardId: id);
      }
    }
    for (final k in fields.keys) {
      if (!c.editable.contains(k)) throw LaikaApiError(422, 'Ese campo no se puede editar', field: k);
    }
    final changes = <String, Object?>{};
    for (final MapEntry(:key, :value) in fields.entries) {
      final v = value is String ? value.trim() : value;
      if (key == 'word' && v == '') {
        if (c.word != null) changes['word'] = null;
      } else if (c.field(key) != v) {
        changes[key] = v;
      }
    }
    if (changes['reading'] case final String r) {
      if (_dict.containsKey(c.front) && _lookup(c.front, r) == null) {
        throw const LaikaApiError(422, 'Ese carácter no tiene esa lectura', field: 'reading');
      }
      final dup = _existing(c.front, r, except: id);
      if (dup != null) throw LaikaApiError(409, 'Ya tienes esa lectura en otra tarjeta', cardId: dup.id);
      changes['tone'] = toneOf(r);
    }
    final locked = {...c.locked, ...changes.keys.where(Flashcard.lockable.contains), ...fields.keys.where(Flashcard.lockable.contains)}
      ..removeAll(unlock ?? const []);
    if (changes.isEmpty && _setEq(locked, c.locked.toSet())) return CardWrite(_out(c), null);
    final now = _now;
    final next = _with(c, {
      ...changes,
      'locked': locked.toList(),
      'updated_by': 'him',
      'updated_at': _iso(now),
    });
    if (changes.containsKey('meaning_en')) _checkMeaning.remove(id);
    final e = _record(id, CardWho.him, 'edit', {for (final k in changes.keys) k: c.field(k)}, changes, lockedBefore: c.locked);
    return _write(next, e);
  }

  CardWrite delete(int id, {CardWho who = CardWho.him}) {
    final c = _get(id);
    if (c.inTrash) return CardWrite(_out(c), null);
    final e = _record(id, who, 'delete', {'deleted': false}, {'deleted': true});
    return _write(_with(c, {'deleted_at': _iso(_now), 'updated_at': _iso(_now)}), e);
  }

  CardWrite restore(int id) {
    final c = _get(id);
    if (!c.inTrash) return CardWrite(_out(c), null);
    final e = _record(id, CardWho.him, 'restore', {'deleted': true}, {'deleted': false});
    return _write(_with(c, {'deleted_at': null, 'updated_at': _iso(_now)}), e);
  }

  /// La agenda después de contestar [rating] (imita a FSRS, sin sus fórmulas).
  CardSchedule _schedule(CardSchedule s, int rating, DateTime now) {
    const m = Duration(minutes: 1), d = Duration(days: 1);
    final Duration iv;
    final String state;
    switch (s.state) {
      case 'review':
        final prev = max(1.0, s.stability ?? 1.0);
        (iv, state) = switch (rating) {
          1 => (m * 10, 'relearning'),
          2 => (d * (prev * 1.2).round(), 'review'),
          3 => (d * (prev * 2.5).round(), 'review'),
          _ => (d * (prev * 3.5).round(), 'review'),
        };
      default: // new, learning, relearning
        final again = s.state == 'relearning' ? 'relearning' : 'learning';
        (iv, state) = switch (rating) {
          1 => (m, again),
          2 => (m * 6, again),
          3 => s.isNew ? (m * 10, 'learning') : (d, 'review'),
          _ => (d * 4, 'review'),
        };
    }
    return CardSchedule(
      dueAt: now.add(iv),
      state: state,
      stability: state == 'review' ? iv.inHours / 24 : (s.stability ?? 0.5),
      difficulty: ((s.difficulty ?? 5) + (3 - rating) * 0.8).clamp(1, 10).toDouble(),
      lastReviewAt: now,
    );
  }

  CardWrite review(int id, int rating, {required String clientId, int? durationMs, DateTime? reviewedAt}) {
    final again = _reviews[clientId];
    if (again != null) return again;
    if (rating < 1 || rating > 4) throw const LaikaApiError(422, 'La calificación va de 1 a 4', field: 'rating');
    final c = _get(id);
    if (c.inTrash) throw const LaikaApiError(409, 'Está en la papelera');
    final at = (reviewedAt ?? _now).toUtc();
    if (c.schedule.isNew) _newShown.update(_day(at), (n) => n + 1, ifAbsent: () => 1);
    final s = _schedule(c.schedule, rating, at);
    final e = _record(id, CardWho.him, 'review', {'schedule': c.schedule.toJson()}, {'schedule': s.toJson(), 'rating': rating});
    final w = _write(_with(c, {'schedule': s.toJson()}), e);
    _reviews[clientId] = w;
    return w;
  }

  CardWrite undo(int editId) {
    final i = _edits.indexWhere((e) => e.id == editId);
    if (i < 0) throw const LaikaApiError(404, 'Ese cambio no existe');
    final e = _withUndoable(_edits[i]);
    if (!e.undoable) throw LaikaApiError(409, 'Ya no se puede deshacer: algo lo cambió después', cardId: e.cardId);
    final c = _get(e.cardId);
    final now = _now;
    Flashcard next;
    switch (e.op) {
      case 'create' || 'restore':
        next = _with(c, {'deleted_at': _iso(now)});
      case 'delete':
        next = _with(c, {'deleted_at': null});
      case 'review':
        final before = CardSchedule.fromJson((e.before['schedule'] as Map?)?.cast<String, dynamic>());
        if (before.isNew && before.dueAt == null) {
          final day = _day(e.at ?? now);
          _newShown.update(day, (n) => max(0, n - 1), ifAbsent: () => 0);
        }
        next = _with(c, {'schedule': before.toJson()});
      case 'suggest':
        next = c; // una sugerencia descartada vuelve a quedar pendiente
        _replaceEdit(e, {'status': 'pending'});
      default:
        next = _with(c, {
          ...e.before,
          if (e.before['reading'] case final String r) 'tone': toneOf(r),
          'locked': ?_lockedBefore[e.id],
        });
    }
    if (e.op != 'suggest') _replaceEdit(e, {'undone_at': _iso(now)});
    return _write(_with(next, {'updated_at': _iso(now)}), e);
  }

  CardWrite answer(int editId, {required bool apply}) {
    final i = _edits.indexWhere((e) => e.id == editId);
    if (i < 0 || !_edits[i].isSuggestion) throw const LaikaApiError(404, 'Esa sugerencia no existe');
    final s = _edits[i];
    if (!s.pending) throw LaikaApiError(409, 'Ya contestaste esa sugerencia', cardId: s.cardId);
    final c = _get(s.cardId);
    if (!apply) {
      _replaceEdit(s, {'status': 'dismissed'});
      return CardWrite(_out(c), s.id);
    }
    _replaceEdit(s, {'status': 'applied'});
    if (s.proposesDeletion) return delete(s.cardId, who: CardWho.laika);
    final changes = {for (final k in s.after.keys) if (c.editable.contains(k)) k: s.after[k]};
    final e = _record(s.cardId, CardWho.laika, 'edit', {for (final k in changes.keys) k: c.field(k)}, changes,
        reason: 'aceptaste su sugerencia', lockedBefore: c.locked);
    return _write(
        _with(c, {
          ...changes,
          if (changes['reading'] case final String r) 'tone': toneOf(r),
          'updated_by': 'laika',
          'updated_at': _iso(_now),
        }),
        e);
  }

  /// Laika corrige una tarjeta (p. ej. desde el chat). Si el campo es tuyo
  /// (bloqueado), solo lo sugiere. Devuelve el Edit.
  CardEdit laikaEdits(int id, Map<String, Object?> fields, {String? reason}) {
    final c = _get(id);
    final mine = fields.keys.where(c.isLocked).toList();
    if (mine.isNotEmpty || fields.containsKey('deleted')) {
      return _record(id, CardWho.laika, 'suggest', {for (final k in fields.keys) k: c.field(k)}, fields,
          reason: reason, status: 'pending');
    }
    final e = _record(id, CardWho.laika, 'edit', {for (final k in fields.keys) k: c.field(k)}, fields, reason: reason);
    _cards[id] = _with(c, {
      ...fields,
      if (fields['reading'] case final String r) 'tone': toneOf(r),
      'updated_by': 'laika',
      'updated_at': _iso(_now),
    });
    return e;
  }

  Flashcard card(int id) => _out(_get(id));

  // ── Ejemplo ──────────────────────────────────────────────────────────────

  void _seed(DateTime t) {
    final now = t.toUtc();
    CardSchedule sched(String state, Duration dueIn, {double stability = 3, double difficulty = 5}) => CardSchedule(
        state: state,
        dueAt: state == 'new' ? null : now.add(dueIn),
        stability: state == 'new' ? null : stability,
        difficulty: state == 'new' ? null : difficulty,
        lastReviewAt: state == 'new' ? null : now.subtract(const Duration(days: 2)));
    void add(String front, String reading, String word, String es, String en, CardSchedule s,
        {CardWho by = CardWho.him, List<String> locked = const [], List<KnownWord> known = const [], List<String> parts = const [],
        bool suspended = false, DateTime? deleted, String note = ''}) {
      final created = now.subtract(Duration(days: 20 - _nextCard));
      final c = Flashcard(
        id: _nextCard++,
        front: front,
        reading: reading,
        tone: toneOf(reading),
        word: word,
        meaningEs: es,
        meaningEn: en,
        note: note,
        knownWords: known,
        parts: parts,
        source: by.name,
        createdBy: by,
        updatedBy: by,
        createdAt: created,
        updatedAt: created,
        updatedAtRaw: _iso(created),
        locked: locked,
        suspended: suspended,
        deletedAt: deleted,
        schedule: s,
      );
      _cards[c.id] = c;
      _edits.add(CardEdit(
        id: _nextEdit++,
        cardId: c.id,
        at: created,
        who: by,
        op: 'create',
        after: {'front': front, 'reading': reading, 'word': word, 'meaning_es': es, 'meaning_en': en},
        card: CardRef(id: c.id, front: front, reading: reading, word: word),
      ));
      if (deleted != null) _record(c.id, by, 'delete', {'deleted': false}, {'deleted': true});
    }

    const kw = KnownWord.new;
    add('行', 'háng', '银行', 'fila; banco', 'row; bank', sched('review', const Duration(hours: -3), difficulty: 7.4),
        locked: ['meaning_es'], known: [kw(word: '银行', reading: 'yínháng', glossEs: 'banco', glossEn: 'bank')], parts: ['彳', '亍'],
        note: 'La de 银行, no la de 不行');
    add('行', 'xíng', '不行', 'andar; estar bien', 'to walk; OK', sched('new', Duration.zero), by: CardWho.laika, parts: ['彳', '亍']);
    add('爱', 'ài', '爱好', 'amor; amar', 'love; to love', sched('review', const Duration(days: 3), stability: 6),
        known: [kw(word: '爱好', reading: 'àihào', glossEs: 'pasatiempo', glossEn: 'hobby')], parts: ['爫', '冖', '友']);
    add('学', 'xué', '学生', 'estudiar', 'study', sched('learning', const Duration(minutes: -5)), by: CardWho.laika,
        known: [kw(word: '学生', reading: 'xuésheng', glossEs: 'estudiante', glossEn: 'student')], parts: ['⺍', '冖', '子']);
    add('好', 'hǎo', '你好', 'bien; bueno', 'good; well', sched('review', const Duration(days: -1), stability: 4),
        known: [kw(word: '你好', reading: 'nǐhǎo', glossEs: 'hola', glossEn: 'hello')], parts: ['女', '子']);
    add('妈', 'mā', '妈妈', 'mamá', 'mom', sched('review', const Duration(days: 9), stability: 12, difficulty: 3), parts: ['女', '马']);
    add('吗', 'ma', '好吗', 'partícula de pregunta', 'question particle', sched('new', Duration.zero), parts: ['口', '马']);
    add('银', 'yín', '银行', 'plata', 'money', sched('new', Duration.zero), by: CardWho.laika, parts: ['钅', '艮']);
    add('中', 'zhōng', '中国', 'medio; China', 'middle; China', sched('review', const Duration(days: 1), stability: 5));
    add('水', 'shuǐ', '喝水', 'agua', 'water', sched('review', const Duration(days: 20), stability: 25), suspended: true);
    add('书', 'shū', '看书', 'libro', 'book', sched('new', Duration.zero), deleted: now.subtract(const Duration(days: 2)));
    add('茶', 'chá', '喝茶', 'té', 'tea', sched('new', Duration.zero), by: CardWho.laika);

    // "money" no coincide con el diccionario (plata / silver): revisar.
    _checkMeaning.add(8);
    // Laika corrigió una suya (se puede deshacer) y sugiere en una tuya (bloqueada).
    laikaEdits(4, {'meaning_en': 'to study; to learn'}, reason: 'lo usaste como verbo en el chat');
    laikaEdits(1, {'meaning_es': 'fila; profesión; banco (en 银行)'}, reason: 'en el chat preguntaste por 行业');
  }
}

bool _setEq<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);
