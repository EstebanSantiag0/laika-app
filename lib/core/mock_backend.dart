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
          areas: const ['study'], tags: const ['pdf', 'escuela'], createdAt: t.subtract(const Duration(days: 10))),
      Item(id: 2, kind: 'for_later', title: 'Video: cómo funciona un sumador en RISC-V', format: 'video',
          areas: const ['projects'], tags: const ['risc-v'], createdAt: t.subtract(const Duration(days: 3))),
      Item(id: 3, kind: 'saved', title: 'Manual del sensor de humedad.pdf', format: 'pdf', areas: const ['projects'],
          tags: const ['pdf'], text: 'Sensores capacitivos vs. resistivos: los capacitivos duran más.',
          doc: const ItemDoc(id: 3, title: 'Manual del sensor de humedad.pdf', state: 'ready', pages: 12,
              progress: {'chunks': {'done': 38, 'failed': 0, 'todo': 0}}),
          createdAt: t.subtract(const Duration(days: 1))),
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
  final List<MemoryEdge> _links = [];
  int _nextLink = 1;

  /// Conexiones de Laika que ocultaste (id → cuándo).
  final Map<String?, DateTime> _hidden = {};

  /// Papelera: nodo, cuándo, lo que se llevó y las conexiones que quitó.
  final List<(TrashedNode, List<MemoryNode>, List<MemoryEdge>, Item?)> _trash = [];

  /// Gustos de ejemplo (ficticios).
  final List<Fact> _likes = [
    Fact(id: 'fact:901', text: 'Le encanta el ramen picante', areas: const ['home'], createdAt: DateTime(2026, 10, 20), polarity: 'like'),
    Fact(id: 'fact:902', text: 'Le gusta soldar sus propios circuitos', areas: const ['skills'], createdAt: DateTime(2026, 10, 25), polarity: 'like'),
    Fact(id: 'fact:903', text: 'No le gusta estudiar de noche', areas: const ['study'], createdAt: DateTime(2026, 10, 28), polarity: 'dislike'),
  ];
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
    final g = _fullGraph();
    if (all) return g;
    return MemoryGraph(
      generatedAt: g.generatedAt,
      areas: g.areas,
      nodes: g.nodes.where((n) => n.timeScope != TimeScope.archived).toList(),
      edges: g.edges,
    );
  }

  /// Campos que el servidor deja editar en cada tipo de nodo (docs/API.md del servidor).
  static const _editable = {
    'fact': ['text', 'areas', 'time_scope', 'polarity', 'sensitive'],
    'entity': ['name', 'summary', 'subkind'],
    'episode': ['title', 'text'],
    'reminder': ['text', 'due_at', 'areas'],
    'area': ['name', 'color'],
    'tag': ['name'],
    'item': ['title', 'text', 'note', 'kind', 'areas', 'tags', 'status'],
  };

  /// El grafo de ejemplo + lo guardado (items, etiquetas) + tus conexiones, como lo manda el servidor.
  MemoryGraph _fullGraph() {
    final nodes = <MemoryNode>[];
    for (final n in _graph.nodes) {
      final j = n.toJson()
        ..['editable'] = _editable[n.kind.wire] ?? const []
        ..['deletable'] = n.kind != NodeKind.area
        ..['updated_at'] ??= n.createdAt.toIso8601String();
      nodes.add(MemoryNode.fromJson(j));
    }
    final edges = [
      for (final e in _graph.edges)
        MemoryEdge(
            source: e.source,
            target: e.target,
            kind: e.kind,
            weight: e.weight,
            id: e.id ?? '${e.kind}:${e.source}:${e.target}',
            origin: e.origin,
            label: e.label),
    ];
    final tagCount = <String, int>{};
    for (final it in _items.where((i) => i.status != 'archived')) {
      nodes.add(_itemNode(it));
      for (final a in it.areas) {
        edges.add(MemoryEdge(source: it.nodeId, target: 'area:$a', kind: 'in_area', weight: 1, id: 'in_area:${it.nodeId}:area:$a'));
      }
      for (final t in it.tags) {
        tagCount[t] = (tagCount[t] ?? 0) + 1;
        edges.add(MemoryEdge(source: it.nodeId, target: 'tag:$t', kind: 'tagged', id: 'tagged:${it.nodeId}:tag:$t'));
      }
    }
    for (final e in tagCount.entries) {
      nodes.add(MemoryNode(
          id: 'tag:${e.key}',
          kind: NodeKind.tag,
          label: e.key,
          text: e.key,
          createdAt: DateTime.now(),
          count: e.value,
          editable: const ['name'],
          deletable: true));
    }
    edges.addAll(_links);
    final ids = {for (final n in nodes) n.id};
    return MemoryGraph(
      generatedAt: DateTime.now(),
      areas: _graph.areas,
      nodes: nodes,
      edges: [for (final e in edges) if (ids.contains(e.source) && ids.contains(e.target) && !_hidden.containsKey(e.id)) e],
    );
  }

  MemoryNode _itemNode(Item it) => MemoryNode(
        id: it.nodeId,
        kind: NodeKind.item,
        itemKind: it.kind,
        label: it.displayTitle,
        text: it.text.isNotEmpty ? it.text : it.note,
        areas: it.areas,
        tags: it.tags,
        url: it.url,
        subkind: it.format,
        status: it.status,
        createdAt: it.createdAt ?? DateTime.now(),
        updatedAt: it.updatedAt ?? it.createdAt,
        editable: _editable['item']!,
        deletable: true,
      );

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

  @override
  Future<ItemPage> items({String? kind, String? area, String? tag, String? status, String? q, int? before, int limit = 30}) async {
    await _net();
    final want = status ?? 'active';
    final ql = q?.toLowerCase();
    final list = _items.reversed
        .where((i) =>
            (want == 'all' || i.status == want) &&
            (kind == null || i.kind == kind) &&
            (area == null || i.areas.contains(area)) &&
            (tag == null || i.tags.contains(tag)) &&
            (ql == null || ql.isEmpty || '${i.title} ${i.text} ${i.note}'.toLowerCase().contains(ql)) &&
            (before == null || i.id < before))
        .toList();
    final page = list.take(limit).toList();
    return ItemPage(page, list.length > limit ? page.last.id : null);
  }

  @override
  Future<Item> item(int id) async {
    await _net();
    return _itemById(id);
  }

  Item _itemById(int id) =>
      _items.firstWhere((i) => i.id == id, orElse: () => throw const LaikaApiError(404, 'No existe'));

  @override
  Future<(Item, SaveResult)> createItem({String? text, String? url, String? kind, List<String>? areas, List<String>? tags, String? note}) async {
    await _net();
    if (url != null) {
      final old = _items.where((i) => i.url == url).firstOrNull;
      if (old != null) return (old, SaveResult.duplicate);
      final t = _trash.indexWhere((t) => t.$4?.url == url);
      if (t >= 0) {
        final it = _trash[t].$4!;
        await restoreNode(it.nodeId);
        return (it, SaveResult.restored);
      }
    }
    final t = (text ?? '').trim();
    final guessed = kind ?? (url != null ? 'saved' : (RegExp(r'\b(ver|leer|después|luego|later)\b').hasMatch(t.toLowerCase()) ? 'for_later' : 'idea'));
    final it = Item(
      id: _nextItem++,
      kind: guessed,
      title: url != null ? (Uri.tryParse(url)?.host ?? url) : (t.length > 60 ? '${t.substring(0, 57)}…' : t),
      text: url == null ? t : '',
      note: note ?? '',
      format: url == null ? 'text' : (RegExp(r'instagram|youtu|tiktok').hasMatch(url) ? 'video' : 'link'),
      url: url,
      areas: areas ?? [_guessArea(t.toLowerCase())],
      tags: tags ?? const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _items.add(it);
    _events.add(ItemEvent(it));
    return (it, SaveResult.created);
  }

  @override
  Future<(Item, SaveResult)> uploadItem(String path, {String? kind, List<String>? areas, List<String>? tags, String? note}) async {
    await _net();
    final name = path.split('/').last;
    final pdf = name.toLowerCase().endsWith('.pdf');
    final it = Item(
      id: _nextItem++,
      kind: kind ?? 'saved',
      title: name,
      note: note ?? '',
      format: pdf ? 'pdf' : (RegExp(r'\.(png|jpe?g|webp)$').hasMatch(name.toLowerCase()) ? 'image' : 'book'),
      areas: areas ?? const [],
      tags: tags ?? const [],
      doc: ItemDoc(id: _nextItem, title: name, state: 'indexing', pages: pdf ? 12 : null),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _items.add(it);
    _events.add(ItemEvent(it));
    _events.add(LibraryEvent('📚 Leyendo «$name»…'));
    return (it, SaveResult.created);
  }

  @override
  Future<Item> patchItem(int id, Map<String, Object?> fields) async {
    await _net();
    final i = _items.indexWhere((x) => x.id == id);
    if (i < 0) throw const LaikaApiError(404, 'No existe');
    final k = fields['kind'];
    if (k != null && !Item.kinds.contains(k)) throw const LaikaApiError(422, 'Tipo desconocido', field: 'kind');
    final it = _items[i].copyWith(
      kind: k as String?,
      status: fields['status'] as String?,
      areas: (fields['areas'] as List?)?.cast<String>(),
      tags: (fields['tags'] as List?)?.cast<String>(),
      note: fields['note'] as String?,
      title: fields['title'] as String?,
    );
    _items[i] = it;
    _events.add(ItemEvent(it));
    return it;
  }

  @override
  Future<Item> resurfaceAction(int id, String action) async {
    await _net();
    final i = _items.indexWhere((x) => x.id == id);
    final it = _items[i];
    _items[i] = Item(
      id: it.id,
      kind: it.kind,
      title: it.title,
      text: it.text,
      note: it.note,
      format: it.format,
      url: it.url,
      areas: it.areas,
      tags: it.tags,
      status: action == 'done' ? 'done' : it.status,
      doc: it.doc,
      // En la demo "dismiss" y "done" lo sacan de la lista para recordar; "later" lo deja para dentro de 10 días.
      createdAt: action == 'later' ? DateTime.now() : DateTime(2000),
      updatedAt: DateTime.now(),
      resurfaceAt: action == 'later' ? DateTime.now().add(const Duration(days: 10)) : null,
    );
    return _items[i];
  }

  @override
  Uri? pageImage(int id, int page, {int width = 1200}) => null;

  @override
  Uri? fileUrl(int id) => null;

  @override
  Future<List<SearchHit>> search(String q, {int limit = 20}) async {
    await _net();
    final ql = q.toLowerCase();
    return [
      for (final i in _items)
        if ('${i.title} ${i.text} ${i.note}'.toLowerCase().contains(ql))
          SearchHit(itemId: i.id, title: i.displayTitle, kind: i.kind, format: i.format, snippet: i.text.isEmpty ? i.title : i.text,
              pageFrom: i.format == 'pdf' ? 3 : null, pageTo: i.format == 'pdf' ? 4 : null, score: 0.03),
    ].take(limit).toList();
  }

  @override
  Future<List<(String, int)>> tags() async {
    await _net();
    final c = <String, int>{};
    for (final i in _items) {
      for (final t in i.tags) {
        c[t] = (c[t] ?? 0) + 1;
      }
    }
    return [for (final e in c.entries) (e.key, e.value)];
  }

  @override
  Future<(List<Fact>, List<Fact>)> likes() async {
    await _net();
    final newest = _likes.reversed;
    return (newest.where((f) => f.polarity == 'like').toList(), newest.where((f) => f.polarity == 'dislike').toList());
  }

  @override
  Future<Fact> patchLike(Fact fact, Map<String, Object?> fields) async {
    await _net();
    final i = _likes.indexWhere((f) => f.id == fact.id);
    if (i < 0) throw const LaikaApiError(404, 'No existe');
    if (fields['status'] == 'archived') return _likes.removeAt(i);
    final f = Fact(id: fact.id, text: fact.text, areas: fact.areas, createdAt: fact.createdAt, polarity: fields['polarity'] as String?);
    if (f.polarity == null) {
      _likes.removeAt(i);
    } else {
      _likes[i] = f;
    }
    return f;
  }

  // ── Editar el grafo (simulado) ───────────────────────────────────────────

  @override
  Future<NodeUpdate> patchNode(String nodeId, Map<String, Object?> fields, {String? baseUpdatedAt}) async {
    await _net();
    final g = _fullGraph();
    final old = g.nodeById[nodeId];
    if (old == null) throw const LaikaApiError(404, 'No existe');
    final base = baseUpdatedAt == null ? null : DateTime.tryParse(baseUpdatedAt);
    if (base != null && old.updatedAt != null && old.updatedAt!.isAfter(base)) {
      throw LaikaApiError(409, 'Alguien lo cambió antes que tú', nodeId: nodeId);
    }
    for (final k in fields.keys) {
      if (!old.editable.contains(k)) throw LaikaApiError(422, 'Ese campo no se puede editar', field: k);
    }
    if (old.kind == NodeKind.item) {
      await patchItem(int.parse(nodeId.split(':').last), fields);
    } else if (old.kind == NodeKind.tag && fields['name'] is String) {
      final from = old.label, to = fields['name'] as String;
      for (var i = 0; i < _items.length; i++) {
        final t = _items[i].tags;
        if (t.contains(from)) _items[i] = _items[i].copyWith(tags: {for (final x in t) x == from ? to : x}.toList());
      }
      final n = _fullGraph().nodeById['tag:$to']!;
      return NodeUpdate(n, _fullGraph().edges.where((e) => e.source == n.id || e.target == n.id).toList());
    } else {
      final j = old.toJson();
      for (final e in fields.entries) {
        final key = switch (e.key) { 'name' || 'title' => 'label', final k => k };
        j[key] = e.value;
        if (key == 'label' && old.kind != NodeKind.fact) j['text'] = e.value;
        if (e.key == 'text' && old.kind == NodeKind.fact) j['label'] = e.value;
      }
      j['updated_at'] = DateTime.now().toIso8601String();
      final n = MemoryNode.fromJson(j);
      _graph = MemoryGraph(
          generatedAt: DateTime.now(),
          areas: _graph.areas,
          nodes: [for (final o in _graph.nodes) o.id == nodeId ? n : o],
          edges: _graph.edges);
    }
    final ng = _fullGraph();
    final n = ng.nodeById[nodeId]!;
    return NodeUpdate(n, ng.edges.where((e) => e.source == nodeId || e.target == nodeId).toList());
  }

  @override
  Future<(String?, int)> tagRenamePreview(String nodeId, String name) async {
    await _net();
    final from = nodeId.substring(4);
    final exists = _items.any((i) => i.tags.contains(name));
    return (exists ? name : null, _items.where((i) => i.tags.contains(from)).length);
  }

  @override
  Future<TrashResult> deleteNode(String nodeId, {bool withFacts = false, bool dryRun = false}) async {
    await _net();
    final g = _fullGraph();
    final node = g.nodeById[nodeId];
    if (node == null) throw const LaikaApiError(404, 'No existe');
    if (node.kind == NodeKind.area) throw LaikaApiError(409, 'Las áreas se renombran, no se borran', nodeId: nodeId);
    final touching = g.edges.where((e) => e.source == nodeId || e.target == nodeId).toList();
    final along = <MemoryNode>[
      if (withFacts && node.kind == NodeKind.entity)
        for (final e in touching)
          if (e.kind == 'about' && g.nodeById[e.source]?.kind == NodeKind.fact) g.nodeById[e.source]!,
    ];
    final result = TrashResult([nodeId, ...along.map((n) => n.id)], [for (final e in touching) if (e.id != null) e.id!]);
    if (dryRun) return result;
    Item? item;
    if (node.kind == NodeKind.item) {
      item = _itemById(int.parse(nodeId.split(':').last));
      _items.remove(item);
    } else if (node.kind == NodeKind.tag) {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].tags.contains(node.label)) {
          _items[i] = _items[i].copyWith(tags: _items[i].tags.where((t) => t != node.label).toList());
        }
      }
    }
    final gone = {nodeId, ...along.map((n) => n.id)};
    _links.removeWhere((e) => gone.contains(e.source) || gone.contains(e.target));
    _graph = MemoryGraph(
      generatedAt: DateTime.now(),
      areas: _graph.areas,
      nodes: _graph.nodes.where((n) => !gone.contains(n.id)).toList(),
      edges: _graph.edges.where((e) => !gone.contains(e.source) && !gone.contains(e.target)).toList(),
    );
    final now = DateTime.now();
    _trash.add((
      TrashedNode(node, trashedAt: now, purgeAt: now.add(const Duration(days: 30)), withIds: along.map((n) => n.id).toList()),
      along,
      touching,
      item,
    ));
    return result;
  }

  @override
  Future<void> restoreNode(String nodeId) async {
    await _net();
    final i = _trash.indexWhere((t) => t.$1.node.id == nodeId);
    if (i < 0) throw const LaikaApiError(404, 'No está en la papelera');
    final (t, along, edges, item) = _trash.removeAt(i);
    if (item != null) {
      _items.add(item);
    } else if (t.node.kind == NodeKind.tag) {
      for (final e in edges.where((e) => e.kind == 'tagged')) {
        final k = _items.indexWhere((x) => x.nodeId == e.source);
        if (k >= 0) _items[k] = _items[k].copyWith(tags: [..._items[k].tags, t.node.label]);
      }
    }
    final back = [if (item == null && t.node.kind != NodeKind.tag) t.node, ...along];
    _graph = MemoryGraph(
      generatedAt: DateTime.now(),
      areas: _graph.areas,
      nodes: [..._graph.nodes, ...back],
      edges: [..._graph.edges, ...edges.where((e) => e.origin != 'user' && e.kind != 'tagged' && e.kind != 'in_area' || item == null && e.kind == 'in_area')],
    );
    _links.addAll(edges.where((e) => e.origin == 'user'));
  }

  @override
  Future<MemoryEdge> createEdge(String source, String target, {String? label}) async {
    await _net();
    final g = _fullGraph();
    if (source == target) throw const LaikaApiError(422, 'No se puede conectar consigo mismo', field: 'target');
    if (g.nodeById[source] == null) throw const LaikaApiError(422, 'No existe', field: 'source');
    if (g.nodeById[target] == null) throw const LaikaApiError(422, 'No existe', field: 'target');
    if ((label ?? '').length > 80) throw const LaikaApiError(422, 'Máximo 80 caracteres', field: 'label');
    final e = MemoryEdge(source: source, target: target, kind: 'link', weight: 1, id: 'link:${_nextLink++}', origin: 'user', label: label);
    _links.add(e);
    return e;
  }

  @override
  Future<MemoryEdge> patchEdge(String edgeId, String label) async {
    await _net();
    final i = _links.indexWhere((e) => e.id == edgeId);
    if (i < 0) throw const LaikaApiError(422, 'Solo se renombran tus conexiones', field: 'label');
    final o = _links[i];
    return _links[i] = MemoryEdge(source: o.source, target: o.target, kind: o.kind, weight: o.weight, id: o.id, origin: o.origin, label: label);
  }

  @override
  Future<void> deleteEdge(String edgeId) async {
    await _net();
    final e = _fullGraph().edges.where((x) => x.id == edgeId).firstOrNull;
    if (e == null) throw const LaikaApiError(404, 'No existe');
    if (e.kind == 'in_area' || e.kind == 'tagged') {
      final k = _items.indexWhere((x) => x.nodeId == e.source);
      final value = e.target.substring(e.target.indexOf(':') + 1);
      if (k >= 0) {
        final it = _items[k];
        _items[k] = e.kind == 'in_area'
            ? it.copyWith(areas: it.areas.where((a) => a != value).toList())
            : it.copyWith(tags: it.tags.where((t) => t != value).toList());
      }
      return;
    }
    _links.removeWhere((x) => x.id == edgeId);
    _hidden[edgeId] = DateTime.now();
    _hiddenEdges[edgeId] = e;
  }

  final Map<String, MemoryEdge> _hiddenEdges = {};

  @override
  Future<void> restoreEdge(String edgeId) async {
    await _net();
    _hidden.remove(edgeId);
    final e = _hiddenEdges.remove(edgeId);
    if (e != null && e.origin == 'user') _links.add(e);
  }

  @override
  Future<Trash> trash() async {
    await _net();
    return Trash(
      [for (final t in _trash.reversed) t.$1],
      [for (final e in _hiddenEdges.entries) HiddenEdge(e.value, _hidden[e.key])],
    );
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
