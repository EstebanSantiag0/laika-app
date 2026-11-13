// Estado de la pestaña Tarjetas: el mazo, los filtros, la búsqueda y lo que
// Laika cambió o sugiere. Solo la app; la mascota no sabe de tarjetas.
//
// Sin sondeo: se carga al abrir la pestaña y después de cada acción; si el
// chat en vivo está abierto, los eventos {type:"card"} lo mantienen al día.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

class DeckController extends ChangeNotifier {
  DeckController(this.api) {
    _sub = api.events.listen((e) {
      if (e is CardEvent) _onEvent(e);
    });
  }

  final LaikaApi api;
  late final StreamSubscription<LaikaEvent> _sub;
  bool _disposed = false;

  /// Las tarjetas del filtro actual (el mazo es chico: llegan todas de una vez).
  List<Flashcard> cards = [];
  CardCounts counts = const CardCounts();
  bool loading = false;
  String? error;

  /// all | due | new | his | hers | hard | trash | check (este último es local: flags).
  String filter = 'all';
  String query = '';

  /// Sugerencias de Laika que esperan tu respuesta.
  List<CardEdit> suggestions = [];

  /// Lo último que Laika cambió y todavía se puede deshacer.
  List<CardEdit> laikaChanges = [];

  static const filters = {
    'all': 'Todas',
    'due': 'Para hoy',
    'new': 'Nuevas',
    'his': 'Mías',
    'hers': 'De Laika',
    'hard': 'Difíciles',
    'check': 'Revisar',
    'trash': 'Papelera',
  };

  String get _serverFilter => filter == 'check' ? 'all' : filter;

  /// Cuántas hay en "Revisar" (sugerencias de Laika o significado dudoso), si se sabe.
  int? get toCheck =>
      _serverFilter == 'all' ? cards.where((c) => c.checkMeaning || c.suggestions.isNotEmpty).length : null;

  /// Lo que se ve: el filtro y la búsqueda (pinyin sin tonos, español, inglés, palabra).
  List<Flashcard> get visible {
    final q = query.trim();
    final p = plainPinyin(q);
    final low = q.toLowerCase();
    return [
      for (final c in cards)
        if ((filter != 'check' || c.checkMeaning || c.suggestions.isNotEmpty) &&
            (q.isEmpty ||
                c.front.contains(q) ||
                (c.word ?? '').contains(q) ||
                (p.isNotEmpty && plainPinyin(c.reading).startsWith(p)) ||
                c.meaningEs.toLowerCase().contains(low) ||
                c.meaningEn.toLowerCase().contains(low) ||
                c.note.toLowerCase().contains(low)))
          c,
    ];
  }

  Future<void> load() async {
    loading = true;
    _notify();
    try {
      final page = await api.cards(filter: _serverFilter);
      cards = page.cards;
      counts = page.counts;
      await _loadFeed();
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    _notify();
  }

  Future<void> _loadFeed() async {
    final pending = await api.cardEdits(who: 'laika', op: 'suggest', pending: true);
    final recent = await api.cardEdits(who: 'laika', limit: 15);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    suggestions = pending.edits;
    laikaChanges = [
      for (final e in recent.edits)
        if (!e.isSuggestion && e.op != 'review' && e.undoable && e.undoneAt == null && (e.at?.isAfter(weekAgo) ?? false)) e,
    ].take(5).toList();
  }

  Future<void> setFilter(String f) async {
    if (f == filter) return;
    final reload = (f == 'check' ? 'all' : f) != _serverFilter;
    filter = f;
    if (reload) {
      await load();
    } else {
      _notify();
    }
  }

  void search(String q) {
    query = q;
    _notify();
  }

  /// Pone la tarjeta como quedó (o la quita si ya no entra en el filtro).
  void _upsert(Flashcard c) {
    final belongs = switch (_serverFilter) {
      'trash' => c.inTrash,
      'his' => !c.inTrash && c.createdBy == CardWho.him,
      'hers' => !c.inTrash && c.createdBy == CardWho.laika,
      _ => !c.inTrash,
    };
    final i = cards.indexWhere((x) => x.id == c.id);
    if (!belongs) {
      if (i >= 0) cards = [...cards]..removeAt(i);
    } else if (i >= 0) {
      cards = [...cards]..[i] = c;
    } else {
      cards = [c, ...cards];
    }
  }

  void _onEvent(CardEvent e) {
    _upsert(e.card);
    if (e.counts != null) counts = e.counts!;
    _notify();
  }

  /// Después de escribir: la tarjeta en la lista de inmediato; los números y lo
  /// de Laika se ponen al día enseguida, sin hacerte esperar.
  Future<CardWrite> _after(Future<CardWrite> job) async {
    final w = await job;
    _upsert(w.card);
    _notify();
    unawaited(_refreshQuietly());
    return w;
  }

  Future<CardWrite> create({required String front, String? reading, String? word, String? meaningEs, String? meaningEn, String? note}) =>
      _after(api.createCard(front: front, reading: reading, word: word, meaningEs: meaningEs, meaningEn: meaningEn, note: note));

  /// Guarda lo que cambiaste. Solo manda los campos distintos (los que mandas quedan bloqueados para Laika).
  Future<CardWrite?> save(Flashcard c, Map<String, Object?> fields, {List<String> unlock = const []}) async {
    if (fields.isEmpty && unlock.isEmpty) return null;
    return _after(api.patchCard(c.id, fields, baseUpdatedAt: c.updatedAtRaw, unlock: unlock));
  }

  Future<CardWrite> remove(Flashcard c) => _after(api.deleteCard(c.id));
  Future<CardWrite> restore(Flashcard c) => _after(api.restoreCard(c.id));
  Future<CardWrite> undo(int editId) => _after(api.undoCardEdit(editId));
  Future<CardWrite> answer(CardEdit suggestion, {required bool apply}) => _after(api.answerSuggestion(suggestion.id, apply: apply));

  Future<void> _refreshQuietly() async {
    try {
      final page = await api.cards(filter: _serverFilter);
      cards = page.cards;
      counts = page.counts;
      await _loadFeed();
      _notify();
    } catch (_) {
      // La acción ya se hizo; los números se ponen al día la próxima vez.
    }
  }

  /// Al cerrar el repaso: los números y las fechas cambiaron.
  Future<void> reviewed() => _refreshQuietly();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}

/// Una vuelta de repaso: la cola de /api/cards/due, la respuesta oculta y los
/// 4 botones. Cada respuesta lleva un client_id: si se cae la red y la vuelves
/// a mandar, el servidor no la cuenta dos veces.
class ReviewSession extends ChangeNotifier {
  ReviewSession(this.api);

  final LaikaApi api;
  final _rng = Random();
  bool _disposed = false;

  List<Flashcard> queue = [];
  DateTime? serverNow;
  CardCounts counts = const CardCounts();
  bool loading = true;
  bool sending = false;
  bool revealed = false;
  String? error;
  int done = 0;

  /// La última respuesta (para "Deshacer"): el cambio y la tarjeta como estaba.
  (int, Flashcard)? last;

  String? _clientId; // de la respuesta en curso (se reusa si hay que reintentar)
  final _watch = Stopwatch();

  Flashcard? get current => queue.isEmpty ? null : queue.first;

  Future<void> start() async {
    loading = true;
    _notify();
    try {
      final due = await api.dueCards(limit: 50);
      queue = due.cards;
      serverNow = due.now;
      counts = due.counts;
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    _begin();
  }

  void _begin() {
    revealed = false;
    _clientId = null;
    _watch
      ..reset()
      ..start();
    _notify();
  }

  void reveal() {
    if (current == null || revealed) return;
    revealed = true;
    _notify();
  }

  /// "10 min", "3 d" para el botón [rating] (contado desde la hora del servidor).
  String? previewFor(int rating) {
    final due = current?.preview[rating];
    return due == null ? null : dueIn(due, serverNow ?? DateTime.now());
  }

  Future<void> rate(int rating) async {
    final c = current;
    if (c == null || !revealed || sending) return;
    sending = true;
    _clientId ??= 'app-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_rng.nextInt(1 << 30).toRadixString(36)}';
    _notify();
    try {
      final w = await api.reviewCard(c.id, rating, clientId: _clientId!, durationMs: _watch.elapsedMilliseconds);
      if (w.editId != null) last = (w.editId!, c);
      queue = [...queue]..removeAt(0);
      done++;
      error = null;
      sending = false;
      if (queue.isEmpty) {
        await start(); // las que estaban aprendiendo pueden tocar otra vez ya
      } else {
        _begin();
      }
    } catch (e) {
      error = '$e';
      sending = false;
      _notify();
    }
  }

  /// Deshace la última respuesta: la tarjeta vuelve al frente de la cola.
  Future<void> undoLast() async {
    final l = last;
    if (l == null || sending) return;
    sending = true;
    _notify();
    try {
      await api.undoCardEdit(l.$1);
      queue = [l.$2, ...queue.where((c) => c.id != l.$2.id)];
      done = max(0, done - 1);
      last = null;
      error = null;
      sending = false;
      _begin();
    } catch (e) {
      error = '$e';
      sending = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
