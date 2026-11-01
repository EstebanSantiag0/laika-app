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
  reminder('reminder', 'Recordatorio');

  const NodeKind(this.wire, this.label);
  final String wire;
  final String label;

  static NodeKind parse(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => fact);
}

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
  });

  final String id;
  final NodeKind kind;
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

  factory MemoryNode.fromJson(Map<String, dynamic> j) => MemoryNode(
        id: j['id'] as String,
        kind: NodeKind.parse(j['kind'] as String?),
        label: j['label'] as String? ?? '',
        text: j['text'] as String? ?? '',
        areas: (j['areas'] as List?)?.cast<String>() ?? const [],
        timeScope: TimeScope.parse(j['time_scope'] as String?),
        validFrom: _date(j['valid_from']),
        validTo: _date(j['valid_to']),
        dueAt: _date(j['due_at']),
        importance: (j['importance'] as num?)?.toDouble() ?? 0.5,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.wire,
        'label': label,
        'text': text,
        'areas': areas,
        'time_scope': timeScope.wire,
        'valid_from': validFrom?.toIso8601String(),
        'valid_to': validTo?.toIso8601String(),
        'due_at': dueAt?.toIso8601String(),
        'importance': importance,
        'created_at': createdAt.toIso8601String(),
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
  });

  final String source;
  final String target;

  /// about | related | in_area | in_episode | similar
  final String kind;
  final double weight;

  factory MemoryEdge.fromJson(Map<String, dynamic> j) => MemoryEdge(
        source: j['source'] as String,
        target: j['target'] as String,
        kind: j['kind'] as String? ?? 'related',
        weight: (j['weight'] as num?)?.toDouble() ?? 0.5,
      );

  Map<String, dynamic> toJson() =>
      {'source': source, 'target': target, 'kind': kind, 'weight': weight};
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
