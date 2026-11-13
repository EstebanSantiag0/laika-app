// Tarjetas (flashcards): un carácter chino en una lectura, agendado con FSRS.
//
// Contrato acordado con la sesión de cc-server el 2026-11-13 (su
// docs/PLAN-phase6.md → docs/API.md). Las tarjetas son solo de la app: la
// mascota no muestra nada de ellas (decisión de Esteban).
//
// Reglas del servidor que la app respeta:
//  • `note` es solo de Esteban; Laika nunca la escribe.
//  • Un campo que Esteban edita queda bloqueado (`locked`): Laika ya no lo
//    cambia, solo lo sugiere (Edit con op "suggest" → Aplicar / No).
//  • Toda escritura devuelve {card, edit_id}; casi todo se puede deshacer.

/// Fecha ISO → DateTime (o null).
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

List<String> _strings(Object? v) => (v as List?)?.whereType<String>().toList() ?? const [];

/// Quién hizo algo: Esteban o Laika.
enum CardWho {
  him,
  laika;

  static CardWho parse(Object? v) => v == 'laika' ? laika : him;
  String get label => this == him ? 'Tú' : 'Laika';
}

/// Una palabra que ya conoces y que usa este carácter (la calcula el servidor).
class KnownWord {
  const KnownWord({required this.word, this.reading = '', this.glossEs = '', this.glossEn = ''});
  final String word;
  final String reading;
  final String glossEs;
  final String glossEn;

  String get gloss => glossEs.isNotEmpty ? glossEs : glossEn;

  factory KnownWord.fromJson(Map<String, dynamic> j) => KnownWord(
        word: j['word'] as String? ?? '',
        reading: j['reading'] as String? ?? '',
        glossEs: j['gloss_es'] as String? ?? '',
        glossEn: j['gloss_en'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {'word': word, 'reading': reading, 'gloss_es': glossEs, 'gloss_en': glossEn};
}

/// Cuándo toca repasarla (FSRS).
class CardSchedule {
  const CardSchedule({this.dueAt, this.state = 'new', this.stability, this.difficulty, this.lastReviewAt});

  final DateTime? dueAt;

  /// new | learning | review | relearning
  final String state;
  final double? stability;
  final double? difficulty;
  final DateTime? lastReviewAt;

  static const labels = {'new': 'Nueva', 'learning': 'Aprendiendo', 'review': 'Repaso', 'relearning': 'Reaprendiendo'};
  String get label => labels[state] ?? state;
  bool get isNew => state == 'new';

  factory CardSchedule.fromJson(Map<String, dynamic>? j) => j == null
      ? const CardSchedule()
      : CardSchedule(
          dueAt: _date(j['due_at']),
          state: labels.containsKey(j['state']) ? j['state'] as String : 'new',
          stability: (j['stability'] as num?)?.toDouble(),
          difficulty: (j['difficulty'] as num?)?.toDouble(),
          lastReviewAt: _date(j['last_review_at']),
        );

  Map<String, Object?> toJson() => {
        'due_at': dueAt?.toUtc().toIso8601String(),
        'state': state,
        'stability': stability,
        'difficulty': difficulty,
        'last_review_at': lastReviewAt?.toUtc().toIso8601String(),
      };
}

/// Una tarjeta. `kind` hoy siempre es "hanzi" (después puede haber otros).
class Flashcard {
  const Flashcard({
    required this.id,
    this.kind = 'hanzi',
    required this.front,
    this.word,
    this.reading = '',
    this.tone = 5,
    this.meaningEs = '',
    this.meaningEn = '',
    this.note = '',
    this.knownWords = const [],
    this.parts = const [],
    this.audio,
    this.source = 'him',
    this.createdBy = CardWho.him,
    this.updatedBy = CardWho.him,
    this.createdAt,
    this.updatedAt,
    this.updatedAtRaw,
    this.locked = const [],
    this.suspended = false,
    this.deletedAt,
    this.editable = defaultEditable,
    this.schedule = const CardSchedule(),
    this.suggestions = const [],
    this.flags = const [],
    this.preview = const {},
  });

  final int id;
  final String kind;

  /// El carácter (行).
  final String front;

  /// Una palabra que muestra esta lectura (银行), o null.
  final String? word;

  /// Pinyin con tono (háng).
  final String reading;

  /// 1–4, o 5 = tono neutro.
  final int tone;
  final String meaningEs;
  final String meaningEn;

  /// Solo de Esteban: Laika nunca la escribe.
  final String note;

  /// Palabras que ya conoces con este carácter (solo lectura).
  final List<KnownWord> knownWords;

  /// Componentes (彳, 亍) (solo lectura).
  final List<String> parts;

  /// Ruta del audio en el servidor (/api/cards/12/audio).
  final String? audio;

  /// `him` | `laika` | `book:<id>`
  final String source;
  final CardWho createdBy;
  final CardWho updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// updated_at tal como lo mandó el servidor (para base_updated_at).
  final String? updatedAtRaw;

  /// Campos que Esteban editó: Laika ya no los cambia, solo los sugiere.
  final List<String> locked;
  final bool suspended;
  final DateTime? deletedAt;

  /// Campos que se pueden mandar en PATCH.
  final List<String> editable;
  final CardSchedule schedule;

  /// Ids de las sugerencias de Laika que esperan tu respuesta.
  final List<int> suggestions;

  /// p. ej. ["check_meaning"]: el significado en inglés de Laika no coincide con el diccionario.
  final List<String> flags;

  /// Solo en GET /api/cards/due: cuándo volvería según cada botón (1–4).
  final Map<int, DateTime> preview;

  static const defaultEditable = ['word', 'reading', 'meaning_es', 'meaning_en', 'note', 'suspended'];

  /// Campos de texto que se pueden bloquear (los demás son de Esteban o no se bloquean).
  static const lockable = ['word', 'reading', 'meaning_es', 'meaning_en'];

  static const fieldLabels = {
    'front': 'Carácter',
    'word': 'Palabra',
    'reading': 'Lectura',
    'meaning_es': 'Significado',
    'meaning_en': 'En inglés',
    'note': 'Tu nota',
    'suspended': 'Pausada',
  };

  bool isLocked(String field) => locked.contains(field);
  bool get checkMeaning => flags.contains('check_meaning');
  bool get inTrash => deletedAt != null;
  bool get byLaika => createdBy == CardWho.laika;

  /// Lo que se ve como significado principal.
  String get meaning => meaningEs.isNotEmpty ? meaningEs : meaningEn;

  /// El valor de un campo por su nombre en la API (para el historial y las sugerencias).
  Object? field(String name) => switch (name) {
        'front' => front,
        'word' => word,
        'reading' => reading,
        'tone' => tone,
        'meaning_es' => meaningEs,
        'meaning_en' => meaningEn,
        'note' => note,
        'suspended' => suspended,
        _ => null,
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) {
    final preview = <int, DateTime>{};
    final p = j['preview'];
    if (p is Map) {
      for (final e in p.entries) {
        final r = int.tryParse('${e.key}');
        final d = _date(e.value);
        if (r != null && d != null) preview[r] = d;
      }
    }
    return Flashcard(
      id: _int(j['id']),
      kind: j['kind'] as String? ?? 'hanzi',
      front: j['front'] as String? ?? '',
      word: j['word'] as String?,
      reading: j['reading'] as String? ?? '',
      tone: _int(j['tone'], 5).clamp(1, 5),
      meaningEs: j['meaning_es'] as String? ?? '',
      meaningEn: j['meaning_en'] as String? ?? '',
      note: j['note'] as String? ?? '',
      knownWords: [for (final w in (j['known_words'] as List? ?? const []).whereType<Map<String, dynamic>>()) KnownWord.fromJson(w)],
      parts: _strings(j['parts']),
      audio: j['audio'] as String?,
      source: j['source'] as String? ?? 'him',
      createdBy: CardWho.parse(j['created_by']),
      updatedBy: CardWho.parse(j['updated_by']),
      createdAt: _date(j['created_at']),
      updatedAt: _date(j['updated_at']),
      updatedAtRaw: j['updated_at'] as String?,
      locked: _strings(j['locked']),
      suspended: j['suspended'] == true,
      deletedAt: _date(j['deleted_at']),
      editable: j['editable'] is List ? _strings(j['editable']) : defaultEditable,
      schedule: CardSchedule.fromJson(j['schedule'] as Map<String, dynamic>?),
      suggestions: [for (final s in (j['suggestions'] as List? ?? const [])) if (s is num) s.toInt()],
      flags: _strings(j['flags']),
      preview: preview,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'front': front,
        'word': word,
        'reading': reading,
        'tone': tone,
        'meaning_es': meaningEs,
        'meaning_en': meaningEn,
        'note': note,
        'known_words': [for (final w in knownWords) w.toJson()],
        'parts': parts,
        'audio': audio,
        'source': source,
        'created_by': createdBy.name,
        'updated_by': updatedBy.name,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAtRaw ?? updatedAt?.toUtc().toIso8601String(),
        'locked': locked,
        'suspended': suspended,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'editable': editable,
        'schedule': schedule.toJson(),
        'suggestions': suggestions,
        'flags': flags,
        if (preview.isNotEmpty) 'preview': {for (final e in preview.entries) '${e.key}': e.value.toUtc().toIso8601String()},
      };
}

/// Lo mínimo de una tarjeta que viene dentro de cada Edit del historial.
class CardRef {
  const CardRef({required this.id, this.front = '', this.reading = '', this.word});
  final int id;
  final String front;
  final String reading;
  final String? word;

  factory CardRef.fromJson(Map<String, dynamic> j) =>
      CardRef(id: _int(j['id']), front: j['front'] as String? ?? '', reading: j['reading'] as String? ?? '', word: j['word'] as String?);

  Map<String, Object?> toJson() => {'id': id, 'front': front, 'reading': reading, 'word': word};
}

/// Un cambio en una tarjeta (tuyo o de Laika), o una sugerencia de Laika.
class CardEdit {
  const CardEdit({
    required this.id,
    required this.cardId,
    this.at,
    this.who = CardWho.him,
    this.op = 'edit',
    this.before = const {},
    this.after = const {},
    this.reason,
    this.undoneAt,
    this.status,
    this.undoable = false,
    this.card,
  });

  final int id;
  final int cardId;
  final DateTime? at;
  final CardWho who;

  /// create | edit | delete | restore | suggest | review
  final String op;
  final Map<String, Object?> before;

  /// Lo nuevo. En una sugerencia: lo que Laika propone ({"deleted": true} = borrarla).
  final Map<String, Object?> after;

  /// Por qué (p. ej. "corregiste el significado en el chat").
  final String? reason;
  final DateTime? undoneAt;

  /// Solo en sugerencias: pending | applied | dismissed.
  final String? status;
  final bool undoable;
  final CardRef? card;

  bool get isSuggestion => op == 'suggest';
  bool get pending => isSuggestion && status == 'pending';
  bool get proposesDeletion => isSuggestion && after['deleted'] == true;

  /// Campos que tocó (sin la agenda de un repaso).
  List<String> get fields => [
        for (final k in {...before.keys, ...after.keys})
          if (k != 'schedule' && k != 'deleted') k,
      ];

  static const opLabels = {
    'create': 'creó',
    'edit': 'editó',
    'delete': 'mandó a la papelera',
    'restore': 'recuperó',
    'suggest': 'sugiere',
    'review': 'repasó',
  };
  String get opLabel => opLabels[op] ?? op;

  factory CardEdit.fromJson(Map<String, dynamic> j) => CardEdit(
        id: _int(j['id']),
        cardId: _int(j['card_id']),
        at: _date(j['at']),
        who: CardWho.parse(j['who']),
        op: j['op'] as String? ?? 'edit',
        before: (j['before'] as Map?)?.cast<String, Object?>() ?? const {},
        after: (j['after'] as Map?)?.cast<String, Object?>() ?? const {},
        reason: j['reason'] as String?,
        undoneAt: _date(j['undone_at']),
        status: j['status'] as String?,
        undoable: j['undoable'] == true,
        card: j['card'] is Map<String, dynamic> ? CardRef.fromJson(j['card'] as Map<String, dynamic>) : null,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'card_id': cardId,
        'at': at?.toUtc().toIso8601String(),
        'who': who.name,
        'op': op,
        'before': before,
        'after': after,
        'reason': reason,
        'undone_at': undoneAt?.toUtc().toIso8601String(),
        'status': status,
        'undoable': undoable,
        if (card != null) 'card': card!.toJson(),
      };
}

/// Cuántas hay de cada cosa (para las pestañas y el botón de repasar).
class CardCounts {
  const CardCounts({
    this.total = 0,
    this.due = 0,
    this.newCards = 0,
    this.learning = 0,
    this.suspended = 0,
    this.trash = 0,
    this.newLeftToday = 0,
    this.suggestions = 0,
  });

  final int total;

  /// Para repasar hoy (sin contar las nuevas).
  final int due;
  final int newCards;
  final int learning;
  final int suspended;
  final int trash;

  /// Nuevas que todavía caben hoy (el tope lo pone el servidor: cards.new_per_day).
  final int newLeftToday;

  /// Sugerencias de Laika que esperan tu respuesta.
  final int suggestions;

  /// Lo que saldría al darle "Repasar".
  int get toStudy => due + (newCards < newLeftToday ? newCards : newLeftToday);

  factory CardCounts.fromJson(Map<String, dynamic>? j) => j == null
      ? const CardCounts()
      : CardCounts(
          total: _int(j['total']),
          due: _int(j['due']),
          newCards: _int(j['new']),
          learning: _int(j['learning']),
          suspended: _int(j['suspended']),
          trash: _int(j['trash']),
          newLeftToday: _int(j['new_left_today']),
          suggestions: _int(j['suggestions']),
        );

  Map<String, Object?> toJson() => {
        'total': total,
        'due': due,
        'new': newCards,
        'learning': learning,
        'suspended': suspended,
        'trash': trash,
        'new_left_today': newLeftToday,
        'suggestions': suggestions,
      };
}

/// GET /api/cards
class CardPage {
  const CardPage(this.cards, {this.nextBefore, this.counts = const CardCounts()});
  final List<Flashcard> cards;
  final int? nextBefore;
  final CardCounts counts;

  factory CardPage.fromJson(Map<String, dynamic> j) => CardPage(
        [for (final c in (j['cards'] as List? ?? const []).whereType<Map<String, dynamic>>()) Flashcard.fromJson(c)],
        nextBefore: (j['next_before'] as num?)?.toInt(),
        counts: CardCounts.fromJson(j['counts'] as Map<String, dynamic>?),
      );
}

/// GET /api/cards/due: lo que toca repasar, con la hora del servidor.
class DueCards {
  const DueCards(this.cards, {this.now, this.counts = const CardCounts()});
  final List<Flashcard> cards;

  /// La hora del servidor (para decir "en 10 min" aunque el reloj de aquí esté movido).
  final DateTime? now;
  final CardCounts counts;

  factory DueCards.fromJson(Map<String, dynamic> j) => DueCards(
        [for (final c in (j['cards'] as List? ?? const []).whereType<Map<String, dynamic>>()) Flashcard.fromJson(c)],
        now: _date(j['now']),
        counts: CardCounts.fromJson(j['counts'] as Map<String, dynamic>?),
      );
}

/// Respuesta de toda escritura: la tarjeta como quedó y el cambio (para Deshacer).
class CardWrite {
  const CardWrite(this.card, this.editId);
  final Flashcard card;
  final int? editId;

  factory CardWrite.fromJson(Map<String, dynamic> j) =>
      CardWrite(Flashcard.fromJson(j['card'] as Map<String, dynamic>), (j['edit_id'] as num?)?.toInt());
}

/// GET /api/cards/edits
class CardEditPage {
  const CardEditPage(this.edits, {this.nextBefore});
  final List<CardEdit> edits;
  final int? nextBefore;

  factory CardEditPage.fromJson(Map<String, dynamic> j) => CardEditPage(
        [for (final e in (j['edits'] as List? ?? const []).whereType<Map<String, dynamic>>()) CardEdit.fromJson(e)],
        nextBefore: (j['next_before'] as num?)?.toInt(),
      );
}

/// Los 4 botones del repaso (FSRS).
const ratingLabels = {1: 'Otra vez', 2: 'Difícil', 3: 'Bien', 4: 'Fácil'};

/// "en 10 min", "en 3 d"… desde [now] (la hora del servidor si la hay).
String dueIn(DateTime due, DateTime now) {
  final d = due.difference(now);
  if (d.inMinutes < 1) return 'ya';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  if (d.inDays < 31) return '${d.inDays} d';
  if (d.inDays < 365) return '${(d.inDays / 30).round()} m';
  return '${(d.inDays / 365).toStringAsFixed(1)} a';
}

/// Pinyin sin tonos y en minúsculas (para buscar "hang" y encontrar "háng").
String plainPinyin(String s) {
  const map = {
    'āáǎà': 'a', 'ēéěè': 'e', 'īíǐì': 'i', 'ōóǒò': 'o', 'ūúǔù': 'u', 'ǖǘǚǜü': 'v',
  };
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    var out = ch;
    for (final e in map.entries) {
      if (e.key.contains(ch)) {
        out = e.value;
        break;
      }
    }
    b.write(out);
  }
  return b.toString().replaceAll(RegExp(r'[1-5]'), '');
}

/// Tono de un pinyin con marca (háng → 2); sin marca = 5 (neutro).
int toneOf(String reading) {
  const marks = ['āēīōūǖ', 'áéíóúǘ', 'ǎěǐǒǔǚ', 'àèìòùǜ'];
  for (var i = 0; i < marks.length; i++) {
    if (reading.split('').any(marks[i].contains)) return i + 1;
  }
  final digit = RegExp(r'[1-5]$').firstMatch(reading);
  return digit != null ? int.parse(digit.group(0)!) : 5;
}
