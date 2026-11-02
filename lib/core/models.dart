// Modelos de datos de Laika.
//
// Siguen el contrato de la API del servidor (ver docs/API.md). El backend
// simulado (mock_backend.dart) y el futuro cliente HTTP real producen
// exactamente estos objetos, así que las interfaces no saben de dónde vienen.

import 'package:flutter/material.dart';

/// Qué tan "vivo" está un recuerdo en el tiempo.
enum TimeScope {
  /// Siempre válido: "hablo español", "estudio ingeniería".
  permanent('permanent', 'Permanente'),

  /// Válido en esta etapa de la vida: "quiero hacer prácticas".
  stage('stage', 'Etapa actual'),

  /// Un evento o fecha límite: "examen el 15 de noviembre".
  dated('dated', 'Con fecha'),

  /// Algo que Laika debe recordarte en un momento concreto.
  reminder('reminder', 'Recordatorio'),

  /// Ya no es actual; se conserva como historia.
  archived('archived', 'Archivado');

  const TimeScope(this.wire, this.label);
  final String wire;
  final String label;

  static TimeScope parse(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => permanent);
}

/// Tipo de nodo en el cerebro.
enum NodeKind {
  area('area', 'Área'),
  entity('entity', 'Entidad'),
  fact('fact', 'Dato'),
  episode('episode', 'Conversación'),
  reminder('reminder', 'Recordatorio'),

  /// Algo guardado en el segundo cerebro (en el grafo su `kind` es idea,
  /// for_later o saved; ver [MemoryNode.itemKind]).
  item('item', 'Guardado'),

  /// Una etiqueta (`tag:<nombre>`).
  tag('tag', 'Etiqueta');

  const NodeKind(this.wire, this.label);
  final String wire;
  final String label;

  static NodeKind parse(String? s, [String id = '']) {
    if (s != null && (Item.kinds.contains(s) || id.startsWith('item:'))) return item;
    return values.firstWhere((v) => v.wire == s, orElse: () => id.startsWith('tag:') ? tag : fact);
  }
}

/// Nombre en español de cada tipo de cosa guardada.
const itemKindLabels = {'idea': 'Idea', 'for_later': 'Para después', 'saved': 'Guardado'};

/// Un área de la vida: estudios, finanzas, legal...
class Area {
  const Area({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  factory Area.fromJson(Map<String, dynamic> j) => Area(
        id: j['id'] as String,
        name: j['name'] as String,
        color: _parseColor(j['color'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      };
}

Color _parseColor(String? hex) {
  if (hex == null || hex.length < 7) return const Color(0xFF888888);
  return Color(0xFF000000 | int.parse(hex.substring(1, 7), radix: 16));
}

/// Un recuerdo (o un área, entidad, conversación...) dentro del grafo.
class MemoryNode {
  const MemoryNode({
    required this.id,
    required this.kind,
    required this.label,
    this.text = '',
    this.areas = const [],
    this.timeScope = TimeScope.permanent,
    this.validFrom,
    this.validTo,
    this.dueAt,
    this.importance = 0.5,
    required this.createdAt,
    this.subkind,
    this.sensitive = false,
    this.status,
    this.reviewAfter,
    this.editable = const [],
    this.deletable = false,
    this.updatedAt,
    this.updatedAtRaw,
    this.itemKind,
    this.tags = const [],
    this.url,
    this.polarity,
    this.count,
  });

  /// Campos que se pueden editar desde la app (PATCH /api/nodes/{id}).
  final List<String> editable;

  /// ¿Se puede mandar a la papelera? (las áreas no).
  final bool deletable;

  /// Para no pisar una edición más nueva (PATCH con base_updated_at → 409).
  final DateTime? updatedAt;

  /// updated_at tal como lo mandó el servidor: se devuelve igualito en base_updated_at.
  final String? updatedAtRaw;

  /// Solo cosas guardadas: idea | for_later | saved.
  final String? itemKind;
  final List<String> tags;
  final String? url;

  /// Solo datos: like | dislike | null.
  final String? polarity;

  /// Solo etiquetas: cuántos nodos la usan.
  final int? count;

  /// Solo datos de "etapa actual": desde este día Laika pregunta si sigue siendo cierto.
  final DateTime? reviewAfter;

  final String id;
  final NodeKind kind;

  /// Entidades: person|place|thing|topic|work. Datos: identity|habit|opinion|
  /// event|goal|preference|relationship|language|worry|us|laika_self.
  final String? subkind;

  /// Dato sensible: en pantalla se muestra oculto (ver BrainController.hideSensitive).
  final bool sensitive;

  /// Solo recordatorios: pending|delivered|snoozed|done.
  final String? status;
  final String label;
  final String text;
  final List<String> areas;
  final TimeScope timeScope;
  final DateTime? validFrom;
  final DateTime? validTo;
  final DateTime? dueAt;

  /// 0..1 — qué tan importante es (afecta el tamaño en el grafo).
  final double importance;
  final DateTime createdAt;

  String? get primaryArea => areas.isEmpty ? null : areas.first;

  factory MemoryNode.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final kind = NodeKind.parse(j['kind'] as String?, id);
    return MemoryNode(
        id: id,
        kind: kind,
        label: j['label'] as String? ?? j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        areas: (j['areas'] as List?)?.cast<String>() ?? const [],
        timeScope: TimeScope.parse(j['time_scope'] as String?),
        validFrom: _date(j['valid_from']),
        validTo: _date(j['valid_to']),
        dueAt: _date(j['due_at']),
        importance: (j['importance'] as num?)?.toDouble() ?? 0.5,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        subkind: j['subkind'] as String?,
        sensitive: j['sensitive'] == true,
        status: j['status'] as String?,
        reviewAfter: _date(j['review_after']),
        editable: (j['editable'] as List?)?.cast<String>() ?? const [],
        deletable: j['deletable'] == true,
        updatedAt: _date(j['updated_at']),
        updatedAtRaw: j['updated_at'] as String?,
        itemKind: kind == NodeKind.item ? (Item.kinds.contains(j['kind']) ? j['kind'] as String : 'saved') : null,
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        url: j['url'] as String?,
        polarity: j['polarity'] as String?,
        count: (j['count'] as num?)?.toInt(),
      );
  }

  /// Copia con la etiqueta y el texto ocultos (para datos sensibles).
  MemoryNode masked() => MemoryNode(
        id: id,
        kind: kind,
        label: '🔒 privado',
        text: 'Dato sensible: oculto en pantalla. Actívalo en el panel si estás solo.',
        areas: areas,
        timeScope: timeScope,
        validFrom: validFrom,
        validTo: validTo,
        dueAt: dueAt,
        importance: importance,
        createdAt: createdAt,
        subkind: subkind,
        sensitive: true,
        status: status,
        reviewAfter: reviewAfter,
        editable: const [], // un dato oculto no se edita hasta mostrarlo
        deletable: deletable,
        updatedAt: updatedAt,
        updatedAtRaw: updatedAtRaw,
        itemKind: itemKind,
        polarity: polarity,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': itemKind ?? kind.wire,
        if (editable.isNotEmpty) 'editable': editable,
        'deletable': deletable,
        if (updatedAt != null) 'updated_at': updatedAtRaw ?? updatedAt!.toIso8601String(),
        if (tags.isNotEmpty) 'tags': tags,
        if (url != null) 'url': url,
        if (polarity != null) 'polarity': polarity,
        if (count != null) 'count': count,
        'label': label,
        'text': text,
        'areas': areas,
        'time_scope': timeScope.wire,
        'valid_from': validFrom?.toIso8601String(),
        'valid_to': validTo?.toIso8601String(),
        'due_at': dueAt?.toIso8601String(),
        'importance': importance,
        'created_at': createdAt.toIso8601String(),
        'subkind': subkind,
        'sensitive': sensitive,
        'status': status,
        'review_after': reviewAfter == null
            ? null
            : '${reviewAfter!.year}-${reviewAfter!.month.toString().padLeft(2, '0')}-${reviewAfter!.day.toString().padLeft(2, '0')}',
      };
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Una conexión entre dos nodos.
class MemoryEdge {
  const MemoryEdge({
    required this.source,
    required this.target,
    this.kind = 'related',
    this.weight = 0.5,
    this.id,
    this.origin = 'computed',
    this.label,
  });

  final String source;
  final String target;

  /// about | related | in_area | in_episode | similar | tagged | link
  final String kind;
  final double weight;

  /// "link:42", "about:17" o "similar:fact:12:fact:40". Sin id no se puede borrar.
  final String? id;

  /// computed | auto | user (las que dibujaste tú).
  final String origin;

  /// Por qué están conectados (las tuyas, o la razón corta de Laika).
  final String? label;

  bool get deletable => id != null;

  factory MemoryEdge.fromJson(Map<String, dynamic> j) => MemoryEdge(
        source: j['source'] as String,
        target: j['target'] as String,
        kind: j['kind'] as String? ?? 'related',
        weight: (j['weight'] as num?)?.toDouble() ?? 0.5,
        id: j['id'] as String?,
        origin: j['origin'] as String? ?? 'computed',
        label: j['label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'kind': kind,
        'weight': weight,
        if (id != null) 'id': id,
        'origin': origin,
        if (label != null) 'label': label,
      };
}

/// Respuesta de GET /api/graph.
class MemoryGraph {
  MemoryGraph({
    required this.generatedAt,
    required this.areas,
    required this.nodes,
    required this.edges,
  });

  final DateTime generatedAt;
  final List<Area> areas;
  final List<MemoryNode> nodes;
  final List<MemoryEdge> edges;

  late final Map<String, Area> areaById = {for (final a in areas) a.id: a};
  late final Map<String, MemoryNode> nodeById = {for (final n in nodes) n.id: n};

  Color colorOf(MemoryNode n) =>
      areaById[n.primaryArea]?.color ?? const Color(0xFF9AA0A6);

  factory MemoryGraph.fromJson(Map<String, dynamic> j) => MemoryGraph(
        generatedAt: _date(j['generated_at']) ?? DateTime.now(),
        areas: (j['areas'] as List).map((e) => Area.fromJson(e)).toList(),
        nodes: (j['nodes'] as List).map((e) => MemoryNode.fromJson(e)).toList(),
        edges: (j['edges'] as List).map((e) => MemoryEdge.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt.toIso8601String(),
        'areas': areas.map((a) => a.toJson()).toList(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };
}

enum ReminderStatus {
  pending('pending', 'Pendiente'),
  delivered('delivered', 'Avisado'),
  done('done', 'Hecho'),
  snoozed('snoozed', 'Pospuesto');

  const ReminderStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ReminderStatus parse(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => pending);
}

/// Respuesta de GET /api/reminders.
class Reminder {
  Reminder({
    required this.id,
    required this.text,
    required this.dueAt,
    this.status = ReminderStatus.pending,
    this.areas = const [],
    this.sourceMessageId,
    this.timeDefaulted = false,
    this.createdAt,
    this.deliveredAt,
    this.doneAt,
    this.snoozes = 0,
  });

  final int id;
  final String text;
  DateTime dueAt;
  ReminderStatus status;
  final List<String> areas;

  /// Mensaje del chat donde se pidió.
  final int? sourceMessageId;

  /// true si no dijiste hora y el servidor eligió la de por defecto (10:00).
  final bool timeDefaulted;
  final DateTime? createdAt;
  DateTime? deliveredAt;
  DateTime? doneAt;
  int snoozes;

  bool get isOpen =>
      status == ReminderStatus.pending ||
      status == ReminderStatus.delivered ||
      status == ReminderStatus.snoozed;

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as int,
        text: j['text'] as String,
        dueAt: _date(j['due_at']) ?? DateTime.now(),
        status: ReminderStatus.parse(j['status'] as String?),
        areas: (j['areas'] as List?)?.cast<String>() ?? const [],
        sourceMessageId: j['source_message_id'] as int?,
        timeDefaulted: j['time_defaulted'] == true,
        createdAt: _date(j['created_at']),
        deliveredAt: _date(j['delivered_at']),
        doneAt: _date(j['done_at']),
        snoozes: (j['snoozes'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'due_at': dueAt.toIso8601String(),
        'status': status.wire,
        'areas': areas,
        'source_message_id': sourceMessageId,
        'time_defaulted': timeDefaulted,
        'created_at': createdAt?.toIso8601String(),
        'delivered_at': deliveredAt?.toIso8601String(),
        'done_at': doneAt?.toIso8601String(),
        'snoozes': snoozes,
      };
}

/// Respuesta de GET /health.
class Health {
  const Health({required this.ok, required this.llm, required this.telegram});

  final bool ok;
  final bool llm;
  final bool telegram;

  /// Laika solo despierta si el servidor responde Y el modelo está cargado.
  bool get canWake => ok && llm;

  factory Health.fromJson(Map<String, dynamic> j) => Health(
        ok: j['ok'] == true,
        llm: j['llm'] == true,
        telegram: j['telegram'] == true,
      );
}

/// Eventos que llegan del servidor (por el WebSocket /ws en la versión real).
sealed class LaikaEvent {
  const LaikaEvent();
}

/// Laika está escribiendo (o dejó de hacerlo).
class TypingEvent extends LaikaEvent {
  const TypingEvent(this.typing);
  final bool typing;
}

/// Una burbuja de mensaje de Laika. Ella suele mandar varias seguidas,
/// como en WhatsApp.
class BubbleEvent extends LaikaEvent {
  const BubbleEvent(this.text);
  final String text;
}

/// Cambió un recordatorio. El servidor manda este evento al crearlo,
/// al avisarlo (status=delivered), al marcarlo hecho y al posponerlo:
/// {"type":"reminder","origin":"app","reminder":{...}}
class ReminderEvent extends LaikaEvent {
  const ReminderEvent(this.reminder);
  final Reminder reminder;

  /// ¿Es el aviso de que llegó la hora?
  bool get isDue => reminder.status == ReminderStatus.delivered;
}

/// Laika guardó (o cambió) algo en su memoria.
class MemoryEvent extends LaikaEvent {
  const MemoryEvent(this.node);
  final MemoryNode node;
}

/// Laika avisa algo de su biblioteca ("📚 Reading «…»", "📚 «…» is in the
/// library", "📚 I couldn't add…"): llega como mensaje `system` por /ws.
class LibraryEvent extends LaikaEvent {
  const LibraryEvent(this.text);
  final String text;

  /// No pudo leer el archivo.
  bool get failed => RegExp(r"couldn't|can't|no pude", caseSensitive: false).hasMatch(text);
}

/// Cambió algo guardado en su segundo cerebro: {"type":"item","item":{...}}.
class ItemEvent extends LaikaEvent {
  const ItemEvent(this.item);
  final Item item;
}

/// Algo guardado en el segundo cerebro: una idea, algo para después o un
/// archivo/link (contrato: PLAN-second-brain §5 y docs/API.md del servidor).
class Item {
  const Item({
    required this.id,
    this.kind = 'saved',
    this.title = '',
    this.text = '',
    this.note = '',
    this.format = 'text',
    this.url,
    this.areas = const [],
    this.tags = const [],
    this.status = 'active',
    this.doc,
    this.createdAt,
    this.updatedAt,
    this.updatedAtRaw,
    this.resurfaceAt,
  });

  final int id;

  /// idea | for_later | saved (lo desconocido cuenta como saved).
  final String kind;
  final String title;
  final String text;
  final String note;

  /// pdf | book | link | video | image | text
  final String format;
  final String? url;
  final List<String> areas;
  final List<String> tags;

  /// active | done | archived
  final String status;

  /// El documento que Laika leyó (PDF, página del link, transcripción…), o null.
  final ItemDoc? doc;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// updated_at tal como lo mandó el servidor (para base_updated_at).
  final String? updatedAtRaw;
  final DateTime? resurfaceAt;

  static const kinds = {'idea', 'for_later', 'saved'};

  String get nodeId => 'item:$id';
  String get kindLabel => itemKindLabels[kind] ?? 'Guardado';
  String get displayTitle => title.isNotEmpty ? title : (text.isNotEmpty ? text : (url ?? 'Sin título'));

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: (j['id'] as num).toInt(),
        kind: kinds.contains(j['kind']) ? j['kind'] as String : 'saved',
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        note: j['note'] as String? ?? '',
        format: j['format'] as String? ?? 'text',
        url: j['url'] as String?,
        areas: (j['areas'] as List?)?.cast<String>() ?? const [],
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        status: j['status'] as String? ?? 'active',
        doc: j['doc'] is Map<String, dynamic> ? ItemDoc.fromJson(j['doc'] as Map<String, dynamic>) : null,
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
        updatedAtRaw: j['updated_at'] as String?,
        resurfaceAt: _date(j['resurface_at']),
      );

  Item copyWith({String? kind, String? status, List<String>? areas, List<String>? tags, String? note, String? title}) =>
      Item(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        text: text,
        note: note ?? this.note,
        format: format,
        url: url,
        areas: areas ?? this.areas,
        tags: tags ?? this.tags,
        status: status ?? this.status,
        doc: doc,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        resurfaceAt: resurfaceAt,
      );
}

/// El documento de una cosa guardada, mientras Laika lo lee y cuando termina.
class ItemDoc {
  const ItemDoc({required this.id, this.title = '', this.state = 'queued', this.progress = const {}, this.pages});

  final int id;
  final String title;

  /// queued | indexing | ocr_pending | ready | ready_partial | failed
  final String state;

  /// {"chunks": {"done", "failed", "todo"}, "sections": {...}, "pages": {...}}
  final Map<String, dynamic> progress;
  final int? pages;

  bool get ready => state == 'ready' || state == 'ready_partial';

  /// 0..1 según los fragmentos ya leídos (null si no se sabe).
  double? get fraction {
    final c = progress['chunks'];
    if (c is! Map) return null;
    final done = (c['done'] as num?)?.toDouble() ?? 0;
    final total = done + ((c['failed'] as num?) ?? 0) + ((c['todo'] as num?) ?? 0);
    return total == 0 ? null : done / total;
  }

  String get stateLabel => switch (state) {
        'queued' => 'en la fila',
        'indexing' => 'leyendo',
        'ocr_pending' => 'esperando OCR',
        'ready' => 'listo',
        'ready_partial' => 'listo (con partes que no pudo leer)',
        'failed' => 'no pudo leerlo',
        _ => state,
      };

  factory ItemDoc.fromJson(Map<String, dynamic> j) => ItemDoc(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        state: j['state'] as String? ?? 'queued',
        progress: (j['progress'] as Map?)?.cast<String, dynamic>() ?? const {},
        pages: (j['pages'] as num?)?.toInt(),
      );
}

/// Cómo quedó un POST /api/items: nuevo (201), ya estaba (200 duplicate) o
/// estaba en la papelera y volvió (201 restored).
enum SaveResult { created, duplicate, restored }

/// Una página de GET /api/items.
class ItemPage {
  const ItemPage(this.items, this.nextBefore);
  final List<Item> items;

  /// Para pedir la siguiente página (`before=`), o null si no hay más.
  final int? nextBefore;
}

/// Un gusto o algo que no le gusta (un dato con polaridad).
class Fact {
  const Fact({required this.id, required this.text, this.areas = const [], this.createdAt, this.sensitive = false, this.polarity});

  /// "fact:12". En la ruta PATCH /api/likes/{n} va solo el número.
  final String id;
  final String text;
  final List<String> areas;
  final DateTime? createdAt;
  final bool sensitive;

  /// like | dislike | null
  final String? polarity;

  int get number => int.parse(id.split(':').last);

  factory Fact.fromJson(Map<String, dynamic> j, {String? polarity}) => Fact(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        areas: (j['areas'] as List?)?.cast<String>() ?? const [],
        createdAt: _date(j['created_at']),
        sensitive: j['sensitive'] == true,
        polarity: j['polarity'] as String? ?? polarity,
      );
}

/// Un resultado de GET /api/search.
class SearchHit {
  const SearchHit({
    required this.itemId,
    this.docId,
    this.chunkId,
    this.title = '',
    this.kind = 'saved',
    this.format = 'text',
    this.snippet = '',
    this.pageFrom,
    this.pageTo,
    this.score = 0,
  });

  final int itemId;
  final int? docId;
  final int? chunkId;
  final String title;
  final String kind;
  final String format;
  final String snippet;

  /// Páginas del PDF (null hasta que el servidor las tenga, SB3).
  final int? pageFrom;
  final int? pageTo;
  final double score;

  String? get pages => pageFrom == null
      ? null
      : (pageTo == null || pageTo == pageFrom ? 'p. $pageFrom' : 'pp. $pageFrom–$pageTo');

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
        itemId: (j['item_id'] as num).toInt(),
        docId: (j['doc_id'] as num?)?.toInt(),
        chunkId: (j['chunk_id'] as num?)?.toInt(),
        title: j['title'] as String? ?? '',
        kind: j['kind'] as String? ?? 'saved',
        format: j['format'] as String? ?? 'text',
        snippet: j['snippet'] as String? ?? j['text'] as String? ?? '',
        pageFrom: (j['page_from'] as num?)?.toInt(),
        pageTo: (j['page_to'] as num?)?.toInt(),
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

/// Lo que devuelve editar un nodo: el nodo nuevo y sus conexiones.
class NodeUpdate {
  const NodeUpdate(this.node, this.edges);
  final MemoryNode node;
  final List<MemoryEdge> edges;
}

/// Lo que se fue (o se iría, con dry_run) a la papelera al borrar.
class TrashResult {
  const TrashResult(this.trashed, this.edgesRemoved);
  final List<String> trashed;
  final List<String> edgesRemoved;

  factory TrashResult.fromJson(Map<String, dynamic> j) => TrashResult(
        (j['trashed'] as List?)?.cast<String>() ?? const [],
        (j['edges_removed'] as List?)?.cast<String>() ?? const [],
      );
}

/// GET /api/trash
class Trash {
  const Trash(this.nodes, this.hiddenEdges);
  final List<TrashedNode> nodes;
  final List<HiddenEdge> hiddenEdges;

  factory Trash.fromJson(Map<String, dynamic> j) => Trash(
        [for (final n in (j['nodes'] as List? ?? const [])) TrashedNode.fromJson(n as Map<String, dynamic>)],
        [for (final e in (j['hidden_edges'] as List? ?? const [])) HiddenEdge.fromJson(e as Map<String, dynamic>)],
      );
}

class TrashedNode {
  const TrashedNode(this.node, {this.trashedAt, this.purgeAt, this.withIds = const [], this.renamedTo});
  final MemoryNode node;
  final DateTime? trashedAt;

  /// Cuándo se borra para siempre (30 días).
  final DateTime? purgeAt;

  /// Lo que se llevó consigo (p. ej. los datos de una entidad).
  final List<String> withIds;

  /// Si fue una etiqueta renombrada (fusionada): el nombre nuevo.
  final String? renamedTo;

  factory TrashedNode.fromJson(Map<String, dynamic> j) => TrashedNode(
        MemoryNode.fromJson(j),
        trashedAt: _date(j['trashed_at']),
        purgeAt: _date(j['purge_at']),
        withIds: (j['with'] as List?)?.cast<String>() ?? const [],
        renamedTo: j['renamed_to'] as String?,
      );
}

class HiddenEdge {
  const HiddenEdge(this.edge, this.hiddenAt);
  final MemoryEdge edge;
  final DateTime? hiddenAt;

  factory HiddenEdge.fromJson(Map<String, dynamic> j) => HiddenEdge(MemoryEdge.fromJson(j), _date(j['hidden_at']));
}
