// Estado del "cerebro" (grafo de memoria) y de los recordatorios.
// Compartido por las variantes; cada una lo dibuja distinto.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

class BrainController extends ChangeNotifier {
  BrainController(this.api) {
    _sub = api.events.listen((e) {
      if (e is MemoryEvent || e is ReminderEvent) load();
    });
    load();
  }

  final LaikaApi api;
  late final StreamSubscription<LaikaEvent> _sub;

  MemoryGraph? graph;
  String? error;
  bool loading = false;

  String? selectedId;

  /// Áreas visibles (vacío = todas).
  final Set<String> areaFilter = {};

  /// Tiempos visibles (vacío = todos). Por defecto se oculta lo archivado.
  final Set<TimeScope> scopeFilter = {};
  bool showArchived = false;
  String query = '';

  /// Oculta los datos marcados como sensibles (por si alguien ve tu pantalla).
  bool hideSensitive = true;
  MemoryGraph? _raw;

  /// Para que los dibujos sepan cuándo recalcular la posición de los nodos.
  int version = 0;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _raw = await api.graph(all: true);
      graph = _masked(_raw!);
      error = null;
      version++;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  MemoryGraph _masked(MemoryGraph g) => !hideSensitive
      ? g
      : MemoryGraph(
          generatedAt: g.generatedAt,
          areas: g.areas,
          nodes: [for (final n in g.nodes) n.sensitive ? n.masked() : n],
          edges: g.edges,
        );

  void setHideSensitive(bool v) {
    hideSensitive = v;
    if (_raw != null) graph = _masked(_raw!);
    version++;
    notifyListeners();
  }

  // ── Editar el grafo (Esteban: "cada punto se puede editar y borrar, hasta las conexiones") ──

  /// Edita un nodo. Si alguien (Obsidian, Laika) lo cambió después de cargarlo, el
  /// servidor contesta 409: se recarga y se avisa con [LaikaApiError.conflict].
  Future<void> edit(MemoryNode node, Map<String, Object?> fields) async {
    try {
      await api.patchNode(node.id, fields, baseUpdatedAt: node.updatedAtRaw ?? node.updatedAt?.toIso8601String());
    } finally {
      await load();
    }
  }

  /// Qué se llevaría a la papelera (sin borrar nada).
  Future<TrashResult> previewDelete(MemoryNode node, {bool withFacts = false}) =>
      api.deleteNode(node.id, withFacts: withFacts, dryRun: true);

  Future<TrashResult> delete(MemoryNode node, {bool withFacts = false}) async {
    final r = await api.deleteNode(node.id, withFacts: withFacts);
    if (selectedId == node.id) selectedId = null;
    await load();
    return r;
  }

  Future<void> restore(String nodeId) async {
    await api.restoreNode(nodeId);
    await load();
  }

  /// Una conexión tuya entre dos nodos.
  Future<MemoryEdge> link(String source, String target, {String? label}) async {
    final e = await api.createEdge(source, target, label: label);
    await load();
    return e;
  }

  Future<void> relabel(MemoryEdge e, String label) async {
    await api.patchEdge(e.id!, label);
    await load();
  }

  /// Borra una conexión tuya, u oculta una de Laika (se puede deshacer desde la papelera).
  Future<void> unlink(MemoryEdge e) async {
    await api.deleteEdge(e.id!);
    await load();
  }

  Future<void> restoreEdge(String edgeId) async {
    await api.restoreEdge(edgeId);
    await load();
  }

  Future<Trash> trash() => api.trash();

  /// Conexiones de un nodo (con el otro extremo).
  List<(MemoryEdge, MemoryNode)> edgesOf(MemoryNode n) {
    final g = graph;
    if (g == null) return const [];
    return [
      for (final e in g.edges)
        if (e.source == n.id || e.target == n.id)
          if (g.nodeById[e.source == n.id ? e.target : e.source] case final other?) (e, other),
    ];
  }

  MemoryNode? get selected => selectedId == null ? null : graph?.nodeById[selectedId];

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void toggleArea(String id) {
    areaFilter.contains(id) ? areaFilter.remove(id) : areaFilter.add(id);
    notifyListeners();
  }

  void toggleScope(TimeScope s) {
    scopeFilter.contains(s) ? scopeFilter.remove(s) : scopeFilter.add(s);
    notifyListeners();
  }

  void setShowArchived(bool v) {
    showArchived = v;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q.trim().toLowerCase();
    notifyListeners();
  }

  /// ¿El nodo pasa los filtros? (no confundir con "coincide con la búsqueda")
  bool isVisible(MemoryNode n) {
    if (n.kind == NodeKind.area) return false; // cada diseño dibuja las áreas a su manera
    if (!showArchived && n.timeScope == TimeScope.archived) return false;
    if (scopeFilter.isNotEmpty && n.kind != NodeKind.entity && !scopeFilter.contains(n.timeScope)) {
      return false;
    }
    if (areaFilter.isNotEmpty && !n.areas.any(areaFilter.contains)) return false;
    return true;
  }

  /// ¿Coincide con la búsqueda? (se resalta, no se oculta)
  bool matches(MemoryNode n) =>
      query.isNotEmpty &&
      (n.label.toLowerCase().contains(query) || n.text.toLowerCase().contains(query));

  List<MemoryNode> get visibleNodes =>
      graph == null ? const [] : graph!.nodes.where(isVisible).toList();

  List<MemoryEdge> get visibleEdges {
    final g = graph;
    if (g == null) return const [];
    final ids = {for (final n in visibleNodes) n.id};
    return g.edges
        .where((e) => e.kind != 'in_area' && ids.contains(e.source) && ids.contains(e.target))
        .toList();
  }

  /// Nodos conectados directamente (por aristas).
  List<MemoryNode> neighbors(String id) {
    final g = graph;
    if (g == null) return const [];
    final out = <MemoryNode>[];
    for (final e in g.edges) {
      if (e.kind == 'in_area') continue;
      final other = e.source == id ? e.target : (e.target == id ? e.source : null);
      final n = other == null ? null : g.nodeById[other];
      if (n != null) out.add(n);
    }
    return out;
  }

  int countIn(String areaId) =>
      graph?.nodes.where((n) => n.areas.contains(areaId) && isVisible(n)).length ?? 0;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Agrupación de recordatorios para las listas.
enum ReminderGroup {
  overdue('Atrasados'),
  today('Hoy'),
  tomorrow('Mañana'),
  later('Más adelante'),
  done('Hechos');

  const ReminderGroup(this.label);
  final String label;
}

class RemindersController extends ChangeNotifier {
  RemindersController(this.api) {
    _sub = api.events.listen((e) {
      if (e is ReminderEvent || e is MemoryEvent) load();
    });
    load();
  }

  final LaikaApi api;
  late final StreamSubscription<LaikaEvent> _sub;
  List<Reminder> items = [];
  String? error;

  Future<void> load() async {
    try {
      items = await api.reminders(all: true)
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> done(Reminder r) async {
    try {
      await api.markDone(r.id);
    } catch (e) {
      error = '$e';
    }
    await load();
  }

  Future<void> snooze(Reminder r, {int minutes = 60}) async {
    try {
      await api.snooze(r.id, minutes: minutes);
    } catch (e) {
      error = '$e';
    }
    await load();
  }

  static ReminderGroup groupOf(Reminder r, DateTime now) {
    if (!r.isOpen) return ReminderGroup.done;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
    final diff = day.difference(today).inDays;
    if (r.dueAt.isBefore(now) && r.status != ReminderStatus.snoozed) return ReminderGroup.overdue;
    if (diff <= 0) return ReminderGroup.today;
    if (diff == 1) return ReminderGroup.tomorrow;
    return ReminderGroup.later;
  }

  Map<ReminderGroup, List<Reminder>> grouped([DateTime? now]) {
    final t = now ?? DateTime.now();
    final m = <ReminderGroup, List<Reminder>>{};
    for (final r in items) {
      m.putIfAbsent(groupOf(r, t), () => []).add(r);
    }
    return {for (final g in ReminderGroup.values) if (m[g] != null) g: m[g]!};
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// "hoy 10:00", "mañana 20:00", "lun 3 nov"…
String friendlyDate(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  if (diff == 0) return 'hoy $hm';
  if (diff == 1) return 'mañana $hm';
  if (diff == -1) return 'ayer $hm';
  return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}${d.year != n.year ? ' ${d.year}' : ''}';
}
