// Prueba EN VIVO del contrato con el servidor real (SB8). No es parte de
// `flutter test`: escribe en los datos reales de Laika, así que solo usa
// cosas que empiezan con "PRUEBA SB8" y al final las manda a la papelera.
//
//   LAIKA_SERVER=https://<tu-servidor> LAIKA_FILES=<carpeta con un PDF y un PNG "PRUEBA SB8 …"> \
//     flutter test tool/live_test.dart
//
// La URL del servidor va en la variable de entorno: nunca en el repo (es público).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/api.dart';
import 'package:laika_app/core/http_laika.dart';
import 'package:laika_app/core/models.dart';

void main() {
  final server = Platform.environment['LAIKA_SERVER'];
  final files = Platform.environment['LAIKA_FILES'];
  if (server == null || server.isEmpty) {
    test('sin LAIKA_SERVER: no hay prueba en vivo', () {}, skip: 'pon LAIKA_SERVER');
    return;
  }
  final api = HttpLaika(server);
  final events = <LaikaEvent>[];
  final sub = api.events.listen(events.add);
  final created = <int>[];
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  tearDownAll(() async {
    // Todo lo de la prueba a la papelera (se purga después, con el OK de Esteban).
    for (final id in created) {
      try {
        await api.deleteNode('item:$id');
      } catch (_) {}
    }
    stdout.writeln('SB8 items creados (en la papelera): ${created.join(', ')}');
    await sub.cancel();
    api.dispose();
  });

  Future<Map<String, dynamic>> raw(Uri uri) async {
    final c = HttpClient();
    final r = await (await c.getUrl(uri)).close();
    final bytes = await r.fold<int>(0, (n, b) => n + b.length);
    c.close();
    return {'status': r.statusCode, 'type': r.headers.contentType?.mimeType, 'bytes': bytes};
  }

  test('1. lecturas: health, grafo, items, tags, gustos, resurface', () async {
    final h = await api.health();
    expect(h.canWake, isTrue);
    final g = await api.graph();
    stdout.writeln('grafo: ${g.nodes.length} nodos, ${g.edges.length} conexiones');
    expect(g.nodes.where((n) => n.kind != NodeKind.area).every((n) => n.updatedAt != null || n.kind == NodeKind.tag), isTrue,
        reason: 'updated_at en todo menos áreas y etiquetas');
    expect(g.nodes.any((n) => n.editable.isNotEmpty), isTrue);
    expect(g.nodes.where((n) => n.kind == NodeKind.area).every((n) => !n.deletable), isTrue);
    expect(g.edges.every((e) => e.id != null), isTrue, reason: 'cada conexión trae id');
    for (final n in g.nodes.where((n) => n.kind == NodeKind.item)) {
      expect(Item.kinds, contains(n.itemKind));
    }
    final page = await api.items(limit: 5);
    stdout.writeln('items: ${page.items.length} (next_before ${page.nextBefore})');
    await api.tags();
    final (likes, dislikes) = await api.likes();
    stdout.writeln('gustos: ${likes.length} / ${dislikes.length}');
    expect([...likes, ...dislikes].every((f) => f.id.startsWith('fact:')), isTrue);
    await api.resurface();
  });

  late Item idea;
  test('2. guardar una idea, un link y su duplicado; editar; 409; resurface', () async {
    final (i, dup) = await api.createItem(text: 'PRUEBA SB8 idea $stamp: regar el jardín con un robot', kind: 'idea');
    created.add(i.id);
    idea = i;
    expect(dup, SaveResult.created);
    expect(i.kind, 'idea');
    expect(i.resurfaceAt, isNotNull, reason: 'las ideas vuelven a los 3 días');

    final (l, d1) = await api.createItem(url: 'https://example.com/prueba-sb8-$stamp?utm_source=x');
    created.add(l.id);
    expect(d1, SaveResult.created);
    expect(l.format, 'link');
    final (l2, d2) = await api.createItem(url: 'https://www.example.com/prueba-sb8-$stamp/');
    expect(d2, SaveResult.duplicate, reason: 'misma URL normalizada');
    expect(l2.id, l.id);

    final p = await api.patchItem(i.id, {'tags': ['prueba-sb8'], 'areas': ['projects'], 'note': 'PRUEBA SB8'});
    expect(p.tags, ['prueba-sb8']);
    expect(p.updatedAt, isNotNull);
    await expectLater(
        api.patchItem(i.id, {'note': 'viejo', 'base_updated_at': DateTime(2020).toIso8601String()}),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409)));
    await expectLater(api.patchItem(i.id, {'kind': 'raro'}),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 422).having((e) => e.field, 'field', 'kind')));
    await expectLater(api.item(999999999), throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 404)));

    final r = await api.resurfaceAction(i.id, 'later');
    stdout.writeln('resurface later → ${r.resurfaceAt}');
    idea = await api.item(i.id);
  });

  test('3. subir un PDF, esperar a que Laika lo lea, buscar con páginas, ver la página', () async {
    if (files == null) return markTestSkipped('sin LAIKA_FILES');
    final src = Directory(files).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.pdf'));
    // Una copia única en cada corrida (un comentario PDF al final cambia el sha256).
    final pdf = File('${Directory.systemTemp.createTempSync('laika_sb8_').path}/PRUEBA SB8 sensor capacitivo $stamp.pdf')
      ..writeAsBytesSync([...src.readAsBytesSync(), ...'\n% $stamp\n'.codeUnits]);
    final (it, dup) = await api.uploadItem(pdf.path, note: 'PRUEBA SB8 $stamp');
    expect(dup, SaveResult.created, reason: 'archivo nuevo');
    created.add(it.id);
    expect(it.format, 'pdf');
    stdout.writeln('PDF item ${it.id}, doc ${it.doc?.state}');
    var cur = it;
    final until = DateTime.now().add(const Duration(minutes: 7));
    while (!(cur.doc?.ready ?? false) && cur.doc?.state != 'failed' && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(seconds: 15));
      cur = await api.item(it.id);
      stdout.writeln('  doc: ${cur.doc?.state} ${cur.doc?.progress}');
    }
    expect(cur.doc?.ready, isTrue, reason: 'el PDF debió quedar listo');
    expect(cur.doc?.pages, 1);
    final hits = await api.search('capacitivo PRUEBA SB8');
    final mine = hits.where((h) => h.itemId == it.id).toList();
    stdout.writeln('búsqueda: ${hits.length} resultados; del PDF: ${mine.map((h) => '${h.pages} ${h.snippet}').toList()}');
    expect(mine, isNotEmpty);
    expect(mine.any((h) => h.pageFrom == 1), isTrue, reason: 'cita la página');
    final png = await raw(api.pageImage(it.id, 1, width: 400)!);
    expect(png['status'], 200);
    expect(png['type'], 'image/png');
    final file = await raw(api.fileUrl(it.id)!);
    expect(file['status'], 200);
    final beyond = await raw(api.pageImage(it.id, 5)!);
    expect(beyond['status'], 404);
  }, timeout: const Timeout(Duration(minutes: 9)));

  test('4. subir una imagen sin texto', () async {
    if (files == null) return markTestSkipped('sin LAIKA_FILES');
    final img = Directory(files).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.png'));
    final (it, dup) = await api.uploadItem(img.path, note: 'PRUEBA SB8 $stamp');
    created.add(it.id);
    expect(it.format, 'image');
  });

  test('4b. lo que está en la papelera vuelve si lo mandas otra vez; base_updated_at en otro formato no da 409', () async {
    final (l, _) = await api.createItem(url: 'https://example.com/prueba-sb8-vuelve-$stamp');
    created.add(l.id);
    await api.deleteNode(l.nodeId);
    final (back, how) = await api.createItem(url: 'https://example.com/prueba-sb8-vuelve-$stamp');
    expect(how, SaveResult.restored);
    expect(back.id, l.id, reason: 'el mismo item, no uno nuevo');
    expect(back.doc?.state, isNot('trashed'));
    final cur = await api.item(l.id);
    // El mismo instante escrito en UTC: no debe dar 409.
    await api.patchItem(l.id, {'note': 'PRUEBA SB8', 'base_updated_at': cur.updatedAt!.toUtc().toIso8601String()});
  });

  test('5. editar el grafo: nodo, conexión, ocultar, papelera y recuperar; errores', () async {
    final (other, _) = await api.createItem(text: 'PRUEBA SB8 para después $stamp', kind: 'for_later');
    created.add(other.id);
    var g = await api.graph();
    final node = g.nodeById['item:${idea.id}']!;
    expect(node.editable, contains('title'));
    final up = await api.patchNode(node.id, {'title': 'PRUEBA SB8 idea editada $stamp'}, baseUpdatedAt: node.updatedAtRaw);
    expect(up.node.label, 'PRUEBA SB8 idea editada $stamp');
    await expectLater(api.patchNode(node.id, {'importance': 1}),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 422)));
    await expectLater(api.patchNode(node.id, {'title': 'x'}, baseUpdatedAt: '2020-01-01T00:00:00-06:00'),
        throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409)));

    final e = await api.createEdge(node.id, other.nodeId, label: 'PRUEBA SB8');
    expect(e.id, startsWith('link:'));
    expect(e.origin, 'user');
    final e2 = await api.patchEdge(e.id!, 'PRUEBA SB8 razón');
    expect(e2.label, 'PRUEBA SB8 razón');
    await expectLater(api.createEdge(node.id, node.id), throwsA(isA<LaikaApiError>().having((x) => x.status, 'status', 422)));
    await api.deleteEdge(e.id!);
    final t1 = await api.trash();
    stdout.writeln('papelera: ${t1.nodes.length} nodos, ${t1.hiddenEdges.length} conexiones ocultas');
    await api.restoreEdge(e.id!);
    g = await api.graph();
    expect(g.edges.any((x) => x.id == e.id), isTrue, reason: 'la conexión volvió');

    final dry = await api.deleteNode(other.nodeId, dryRun: true);
    expect(dry.trashed, contains(other.nodeId));
    expect((await api.graph()).nodeById[other.nodeId], isNotNull, reason: 'dry_run no borra');
    await api.deleteNode(other.nodeId);
    expect((await api.graph()).nodeById[other.nodeId], isNull);
    expect((await api.trash()).nodes.map((n) => n.node.id), contains(other.nodeId));
    await api.restoreNode(other.nodeId);
    g = await api.graph();
    expect(g.nodeById[other.nodeId], isNotNull);
    expect(g.edges.any((x) => x.id == e.id), isTrue, reason: 'recuperar trae sus conexiones');

    final area = g.nodes.firstWhere((n) => n.kind == NodeKind.area);
    await expectLater(api.deleteNode(area.id), throwsA(isA<LaikaApiError>().having((x) => x.status, 'status', 409)));
    await expectLater(api.deleteNode('fact:999999999'), throwsA(isA<LaikaApiError>().having((x) => x.status, 'status', 404)));
  });

  test('6. por el WebSocket llegaron eventos "item"', () async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final ids = events.whereType<ItemEvent>().map((e) => e.item.id).toSet();
    stdout.writeln('eventos item: $ids; avisos 📚: ${events.whereType<LibraryEvent>().map((e) => e.text).toList()}');
    expect(ids.intersection(created.toSet()), isNotEmpty);
  });
}
