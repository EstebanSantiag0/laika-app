// Estado del "segundo cerebro": lo que guardas (ideas, para después, PDFs,
// links, videos), la búsqueda en todo eso y tus gustos.
// Lo comparten las pantallas Guardados y Gustos (diseño Laika).
//
// Sin sondeo: se carga al abrir la pantalla y se actualiza con los eventos
// {type:"item"} mientras el chat en vivo está abierto.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

final _url = RegExp(r'^https?://\S+$');

class SecondBrainController extends ChangeNotifier {
  SecondBrainController(this.api) {
    _sub = api.events.listen((e) {
      if (e is ItemEvent) _upsert(e.item);
    });
  }

  final LaikaApi api;
  late final StreamSubscription<LaikaEvent> _sub;

  // ── Guardados ───────────────────────────────────────────────────────────
  List<Item> items = [];
  int? nextBefore;
  bool loading = false;
  String? error;

  /// null = todos; idea | for_later | saved.
  String? kind;

  /// active | done | archived
  String status = 'active';
  String? tag;

  // ── Búsqueda (en lo guardado y en lo que Laika leyó) ───────────────────
  String query = '';
  List<SearchHit>? results;
  bool searching = false;

  List<(String, int)> tags = [];

  // ── Gustos ──────────────────────────────────────────────────────────────
  List<Fact> likes = [];
  List<Fact> dislikes = [];

  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    _notify();
    try {
      final page = await api.items(kind: kind, status: status, tag: tag);
      items = page.items;
      nextBefore = page.nextBefore;
      tags = await api.tags();
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    _notify();
  }

  Future<void> more() async {
    if (nextBefore == null || loading) return;
    loading = true;
    _notify();
    try {
      final page = await api.items(kind: kind, status: status, tag: tag, before: nextBefore);
      items = [...items, ...page.items];
      nextBefore = page.nextBefore;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    _notify();
  }

  void setKind(String? k) {
    kind = k;
    load();
  }

  void setStatus(String s) {
    status = s;
    load();
  }

  void setTag(String? t) {
    tag = t;
    load();
  }

  /// Guarda lo que escribiste: un link se guarda como link; un texto, como
  /// idea o "para después" (si no eliges, Laika lo clasifica). Devuelve un
  /// aviso corto para mostrar.
  Future<String> capture(String text, {String? kind}) async {
    text = text.trim();
    if (text.isEmpty) return '';
    final isUrl = _url.hasMatch(text);
    final (item, dup) = await api.createItem(text: isUrl ? null : text, url: isUrl ? text : null, kind: kind);
    _upsert(item);
    return dup ? 'Ya lo tenías guardado: «${item.displayTitle}»' : 'Guardado como ${item.kindLabel.toLowerCase()} 🐾';
  }

  Future<String> upload(String path, {String? kind}) async {
    final (item, dup) = await api.uploadItem(path, kind: kind);
    _upsert(item);
    return dup ? 'Ese archivo ya estaba: «${item.displayTitle}»' : 'Se lo diste a Laika: «${item.displayTitle}» 📚';
  }

  Future<void> patch(Item it, Map<String, Object?> fields) async {
    _upsert(await api.patchItem(it.id, {...fields, if (it.updatedAt != null) 'base_updated_at': it.updatedAt!.toIso8601String()}));
  }

  /// Manda el item a la papelera. Devuelve lo que se llevó (para el aviso con "Deshacer").
  Future<TrashResult> delete(Item it) async {
    final r = await api.deleteNode(it.nodeId);
    items = items.where((x) => x.id != it.id).toList();
    _notify();
    return r;
  }

  Future<void> restore(Item it) async {
    await api.restoreNode(it.nodeId);
    await load();
  }

  Future<void> search(String q) async {
    query = q.trim();
    if (query.isEmpty) {
      results = null;
      _notify();
      return;
    }
    searching = true;
    _notify();
    try {
      final r = await api.search(query);
      if (q.trim() == query) results = r; // ignora respuestas de búsquedas viejas
      error = null;
    } catch (e) {
      error = '$e';
    }
    searching = false;
    _notify();
  }

  /// Llega un item nuevo o cambiado (evento o respuesta): se pone o se cambia en la lista.
  void _upsert(Item it) {
    final i = items.indexWhere((x) => x.id == it.id);
    final fits = (kind == null || it.kind == kind) && (status == 'all' || it.status == status) && (tag == null || it.tags.contains(tag));
    if (i >= 0) {
      items = [...items]..[i] = it;
      if (!fits) items.removeAt(i);
    } else if (fits) {
      items = [it, ...items];
    }
    _notify();
  }

  // ── Gustos ──────────────────────────────────────────────────────────────

  Future<void> loadLikes() async {
    try {
      final (l, d) = await api.likes();
      likes = l;
      dislikes = d;
      error = null;
    } catch (e) {
      error = '$e';
    }
    _notify();
  }

  /// like | dislike | null (deja de ser un gusto, pero sigue siendo un dato).
  Future<void> setPolarity(Fact f, String? polarity) async {
    await api.patchLike(f, {'polarity': polarity});
    await loadLikes();
  }

  Future<void> archiveLike(Fact f) async {
    await api.patchLike(f, {'status': 'archived'});
    await loadLikes();
  }

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
