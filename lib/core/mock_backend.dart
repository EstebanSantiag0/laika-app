// Backend simulado: se comporta como el servidor de Laika, sin red.
//
// Sirve para diseñar las interfaces sin depender de cc-server. Puedes
// "apagar" el servidor desde el panel de simulación para ver cómo Laika se
// queda dormida cuando no hay respuesta.

import 'dart:async';
import 'dart:math';

import 'api.dart';
import 'models.dart';
import 'sample_data.dart';

class MockLaika implements LaikaApi {
  MockLaika({DateTime? now}) {
    final t = now ?? DateTime.now();
    _graph = buildSampleGraph(t);
    _reminders = buildSampleReminders(t);
    // Cosas guardadas de ejemplo (ficticias) para que Laika te las recuerde.
    _items = [
      Item(id: 1, kind: 'idea', title: 'Usar OCR para los PDFs escaneados de la escuela', format: 'text',
          areas: const ['study'], createdAt: t.subtract(const Duration(days: 10))),
      Item(id: 2, kind: 'for_later', title: 'Video: cómo funciona un sumador en RISC-V', format: 'video',
          areas: const ['projects'], createdAt: t.subtract(const Duration(days: 3))),
    ];
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _checkReminders());
  }

  /// ¿El servidor simulado contesta? (lo cambia el panel de simulación)
  bool online = true;

  /// ¿El modelo (llm) está cargado? Si no, /health dice llm=false.
  bool llmLoaded = true;

  /// Retardo de red simulado.
  Duration latency = const Duration(milliseconds: 450);

  late MemoryGraph _graph;
  late List<Reminder> _reminders;
  late List<Item> _items;
  int _nextItem = 100;
  late final Timer _ticker;
  final _events = StreamController<LaikaEvent>.broadcast();
  final _rng = Random(7);
  int _nextFact = 1000;
  int _nextReminder = 100;

  @override
  Stream<LaikaEvent> get events => _events.stream;

  Future<void> _net() async {
    await Future<void>.delayed(latency);
    if (!online) throw const LaikaOffline();
  }

  @override
  Future<Health> health() async {
    await _net();
    return Health(ok: true, llm: llmLoaded, telegram: true);
  }

  @override
  Future<MemoryGraph> graph({bool all = true}) async {
    await _net();
    if (all) return _graph;
    return MemoryGraph(
      generatedAt: _graph.generatedAt,
      areas: _graph.areas,
      nodes: _graph.nodes.where((n) => n.timeScope != TimeScope.archived).toList(),
      edges: _graph.edges,
    );
  }

  @override
  Future<List<Reminder>> reminders({bool all = true}) async {
    await _net();
    return all ? List.of(_reminders) : _reminders.where((r) => r.isOpen).toList();
  }

  @override
  Future<void> markDone(int id) async {
    await _net();
    final r = _reminders.firstWhere((r) => r.id == id);
    r.status = ReminderStatus.done;
    r.doneAt = DateTime.now();
    _events.add(ReminderEvent(r));
    _replaceNode(reminderNode(r));
  }

  @override
  Future<void> snooze(int id, {int minutes = 60}) async {
    await _net();
    final r = _reminders.firstWhere((r) => r.id == id);
    r.status = ReminderStatus.snoozed;
    r.snoozes++;
    r.dueAt = DateTime.now().add(Duration(minutes: minutes));
    _events.add(ReminderEvent(r));
    _replaceNode(reminderNode(r));
  }

  /// Dispara ya el siguiente recordatorio pendiente (botón del panel).
  void fireNextReminderNow() {
    final open = _reminders.where((r) => r.status == ReminderStatus.pending).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    if (open.isEmpty) return;
    open.first.dueAt = DateTime.now().subtract(const Duration(seconds: 1));
    _checkReminders();
  }

  void _checkReminders() {
    final now = DateTime.now();
    for (final r in _reminders) {
      final due = r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed;
      if (due && !r.dueAt.isAfter(now)) {
        r.status = ReminderStatus.delivered;
        r.deliveredAt = now;
        _events.add(ReminderEvent(r));
      }
    }
  }

  // ── Segundo cerebro ──────────────────────────────────────────────────────

  @override
  Future<List<Item>> resurface() async {
    await _net();
    final now = DateTime.now();
    return _items
        .where((i) => i.status == 'active' && now.difference(i.createdAt ?? now).inDays >= 3)
        .take(3)
        .toList();
  }

  Item _save(String title, String format, {String kind = 'saved', String? url}) {
    final it = Item(id: _nextItem++, kind: kind, title: title, format: format, url: url, createdAt: DateTime.now());
    _items.add(it);
    _events.add(ItemEvent(it));
    return it;
  }

  /// Botón del panel: le llega un PDF (come, lo "lee" y avisa cuando está listo).
  Future<void> feedPdf() async {
    final it = _save('Apuntes de Señales y sistemas.pdf', 'pdf');
    _events.add(LibraryEvent('📚 Leyendo «${it.title}»… (4 capítulos)'));
    await Future<void>.delayed(const Duration(seconds: 6));
    _events.add(LibraryEvent('📚 «${it.title}» ya está en la biblioteca (4 capítulos)'));
  }

  static final _urlRe = RegExp(r'https?://\S+');

  // ── Chat ─────────────────────────────────────────────────────────────────

  @override
  Future<void> send(String text) async {
    await _net();
    _events.add(const TypingEvent(true));
    final reply = _reply(text.trim());
    for (final b in reply) {
      await Future<void>.delayed(Duration(milliseconds: 500 + b.length * 18));
      if (!online) {
        _events.add(const TypingEvent(false));
        throw const LaikaOffline();
      }
      _events.add(BubbleEvent(b));
    }
    _events.add(const TypingEvent(false));
  }

  static final _remindRe = RegExp(
      r'(recu[eé]rdame|remind me|no me dejes olvidar|напомни|提醒我)\s*(.*)',
      caseSensitive: false);

  List<String> _reply(String text) {
    final t = text.toLowerCase();

    final link = _urlRe.firstMatch(text);
    if (link != null) {
      final url = link.group(0)!;
      final video = RegExp(r'instagram|youtu|tiktok').hasMatch(url);
      _save(Uri.tryParse(url)?.host ?? url, video ? 'video' : 'link', url: url);
      return ['Ñam 🔗 lo guardé en tu segundo cerebro.', video ? 'Cuando lo transcriba te cuento de qué trata.' : 'Luego lo leo y te digo de qué trata.'];
    }

    final m = _remindRe.firstMatch(text);
    if (m != null) return _createReminder(m.group(2) ?? '');

    final learned = _maybeLearn(text);

    if (RegExp(r'^(hola|hey|hi|buenas|qué onda|que onda)').hasMatch(t)) {
      return _pick([
        ['¡Hola! 🐾', '¿Qué tal tu día?'],
        ['¡Hey! Justo pensaba en ti.', '¿Cómo vas con el examen de Señales?'],
        ['你好！', '(¡Hola! ¿Practicamos un poco de chino hoy?)'],
      ]);
    }
    if (t.contains('prácticas') || t.contains('practicas') || t.contains('internship')) {
      return [
        'Me acuerdo: buscas prácticas en una empresa de hardware.',
        'Lo tengo como "etapa actual", así que en unas semanas te pregunto si sigue siendo tu plan.',
      ];
    }
    if (t.contains('examen') || t.contains('estudiar')) {
      return [
        'Tu parcial de Señales y sistemas es en 6 días.',
        '¿Hacemos un plan? 20 minutos de Fourier diario y el domingo repaso.',
      ];
    }
    if (t.contains('chino') || t.contains('chinese')) {
      return ['好啊！', '¿Cómo dirías "quiero un café"?', 'Pista: 我要…'];
    }
    if (t.contains('cerebro') || t.contains('memoria') || t.contains('recuerdas')) {
      return [
        'Tengo ${_graph.nodes.length} cosas en mi cerebro sobre ti.',
        'Ábrelo en la pestaña "Cerebro" y las ves conectadas por áreas de tu vida.',
      ];
    }
    if (learned != null) {
      return [
        'Anotado 🧠',
        'Lo guardé en ${_areaName(learned.primaryArea)} como "${learned.timeScope.label.toLowerCase()}".',
      ];
    }
    return _pick([
      ['Mmm, cuéntame más.', '¿Y eso cómo te hizo sentir?'],
      ['Interesante 👀', '¿Quieres que lo guarde en mi memoria?'],
      ['Jaja, ok.', 'Por cierto, ¿ya pagaste el internet? Es mañana.'],
    ]);
  }

  List<String> _pick(List<List<String>> options) => options[_rng.nextInt(options.length)];

  List<String> _createReminder(String what) {
    final clean = what.replaceAll(RegExp(r'^(que|to|de)\s+', caseSensitive: false), '').trim();
    final label = clean.isEmpty ? 'Lo que me pediste' : clean[0].toUpperCase() + clean.substring(1);
    // En la demo, el recordatorio suena en 1 minuto para poder verlo.
    final r = Reminder(
      id: _nextReminder++,
      text: label,
      dueAt: DateTime.now().add(const Duration(minutes: 1)),
      areas: [_guessArea(clean)],
      createdAt: DateTime.now(),
    );
    _reminders.add(r);
    _events.add(ReminderEvent(r));
    _addNode(reminderNode(r));
    return [
      '¡Claro! Te lo recuerdo.',
      '⏰ "$label" — en la demo te aviso en 1 minuto (en el servidor real, a la hora que digas).',
    ];
  }

  MemoryNode? _maybeLearn(String text) {
    final t = text.toLowerCase();
    TimeScope? scope;
    if (RegExp(r'\b(me gusta|me encanta|odio|soy|siempre)\b').hasMatch(t)) {
      scope = TimeScope.permanent;
    } else if (RegExp(r'\b(quiero|estoy|ando|busco|ahorita)\b').hasMatch(t)) {
      scope = TimeScope.stage;
    } else if (RegExp(r'\b(tengo que|mañana|el lunes|la próxima semana)\b').hasMatch(t)) {
      scope = TimeScope.dated;
    }
    if (scope == null) return null;
    final node = MemoryNode(
      id: 'fact:${_nextFact++}',
      kind: NodeKind.fact,
      label: text.length > 48 ? '${text.substring(0, 45)}…' : text,
      text: text,
      areas: [_guessArea(t)],
      timeScope: scope,
      importance: 0.5,
      createdAt: DateTime.now(),
      validFrom: DateTime.now(),
    );
    _addNode(node);
    return node;
  }

  static const _areaWords = {
    'study': ['examen', 'clase', 'tarea', 'uni', 'materia', 'estudiar', 'práctica'],
    'projects': ['proyecto', 'app', 'código', 'programar', 'hackathon'],
    'finance': ['pagar', 'dinero', 'ahorro', 'banco', 'tarjeta', 'internet', 'renta'],
    'legal': ['trámite', 'pasaporte', 'ine', 'curp', 'contrato', 'cita'],
    'skills': ['aprender', 'curso', 'guitarra', 'dibujar'],
    'work': ['trabajo', 'prácticas', 'cv', 'entrevista', 'empresa'],
    'languages': ['chino', 'ruso', 'inglés', 'idioma'],
    'health': ['gym', 'gimnasio', 'dormir', 'doctor', 'correr'],
    'people': ['mamá', 'papá', 'amigo', 'amiga', 'novia', 'novio'],
  };

  String _guessArea(String t) {
    for (final e in _areaWords.entries) {
      if (e.value.any(t.contains)) return e.key;
    }
    return 'home';
  }

  String _areaName(String? id) =>
      _graph.areaById[id]?.name ?? 'Hogar/día a día';

  void _addNode(MemoryNode n) {
    _graph = MemoryGraph(
      generatedAt: DateTime.now(),
      areas: _graph.areas,
      nodes: [..._graph.nodes, n],
      edges: [
        ..._graph.edges,
        for (final a in n.areas) MemoryEdge(source: n.id, target: 'area:$a', kind: 'in_area', weight: 0.3),
      ],
    );
    _events.add(MemoryEvent(n));
  }

  void _replaceNode(MemoryNode n) {
    _graph = MemoryGraph(
      generatedAt: DateTime.now(),
      areas: _graph.areas,
      nodes: [for (final o in _graph.nodes) o.id == n.id ? n : o],
      edges: _graph.edges,
    );
    _events.add(MemoryEvent(n));
  }

  @override
  void composing(bool active) {}

  @override
  void dispose() {
    _ticker.cancel();
    _events.close();
  }
}
