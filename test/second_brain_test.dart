// Segundo cerebro contra el servidor simulado: guardar, buscar, gustos,
// editar el grafo, papelera y "Deshacer".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laika_app/core/api.dart';
import 'package:laika_app/core/brain.dart';
import 'package:laika_app/core/mock_backend.dart';
import 'package:laika_app/core/models.dart';
import 'package:laika_app/core/second_brain.dart';
import 'package:laika_app/main.dart';

void main() {
  late MockLaika api;
  setUp(() => api = MockLaika()..latency = Duration.zero);
  tearDown(() => api.dispose());

  test('guardar una idea, un link (y su duplicado) y un archivo', () async {
    final s = SecondBrainController(api);
    await s.load();
    final n = s.items.length;
    expect(await s.capture('PRUEBA idea: un robot que riegue', kind: 'idea'), contains('idea'));
    expect(await s.capture('https://example.com/articulo'), contains('Guardado'));
    expect(await s.capture('https://example.com/articulo'), startsWith('Ya lo tenías'));
    expect(await s.upload('/tmp/PRUEBA apuntes.pdf'), contains('PRUEBA apuntes.pdf'));
    expect(s.items.length, n + 3);
    expect(s.items.first.format, 'pdf');
    s.dispose();
  });

  test('filtros, editar, papelera y deshacer de una cosa guardada', () async {
    final s = SecondBrainController(api);
    s.setKind('idea');
    await s.load();
    expect(s.items.every((i) => i.kind == 'idea'), isTrue);
    final it = s.items.first;
    await s.patch(it, {'kind': 'for_later', 'tags': ['prueba']});
    expect(s.items.any((i) => i.id == it.id), isFalse, reason: 'ya no es idea: sale del filtro');
    s.setKind(null);
    await s.load();
    final changed = s.items.firstWhere((i) => i.id == it.id);
    expect(changed.kind, 'for_later');
    final r = await s.delete(changed);
    expect(r.trashed, ['item:${it.id}']);
    expect((await api.trash()).nodes.map((t) => t.node.id), contains('item:${it.id}'));
    await s.restore(changed);
    expect(s.items.any((i) => i.id == it.id), isTrue);
    await expectLater(s.patch(changed, {'kind': 'raro'}), throwsA(isA<LaikaApiError>().having((e) => e.field, 'field', 'kind')));
    s.dispose();
  });

  test('búsqueda con páginas y gustos', () async {
    final s = SecondBrainController(api);
    await s.search('capacitivos');
    expect(s.results!.single.pages, 'pp. 3–4');
    await s.loadLikes();
    final like = s.likes.first;
    await s.setPolarity(like, 'dislike');
    expect(s.dislikes.map((f) => f.id), contains(like.id));
    await s.archiveLike(like);
    expect([...s.likes, ...s.dislikes].map((f) => f.id), isNot(contains(like.id)));
    s.dispose();
  });

  test('editar el grafo: campos, 409, conectar, ocultar y papelera', () async {
    final b = BrainController(api);
    await b.load();
    final fact = b.graph!.nodes.firstWhere((n) => n.kind == NodeKind.fact);
    expect(fact.editable, contains('text'));
    await b.edit(fact, {'text': 'PRUEBA dato editado'});
    expect(b.graph!.nodeById[fact.id]!.label, 'PRUEBA dato editado');
    // Editar con la versión vieja (alguien lo cambió después) → 409.
    await expectLater(b.edit(fact, {'text': 'otra vez'}), throwsA(isA<LaikaApiError>().having((e) => e.conflict, 'conflict', isTrue)));
    await expectLater(b.edit(b.graph!.nodeById[fact.id]!, {'importance': 1}), throwsA(isA<LaikaApiError>()));

    final area = b.graph!.nodes.firstWhere((n) => n.kind == NodeKind.area);
    expect(area.deletable, isFalse);
    await expectLater(b.delete(area), throwsA(isA<LaikaApiError>().having((e) => e.status, 'status', 409)));

    final other = b.graph!.nodes.firstWhere((n) => n.kind == NodeKind.item);
    final e = await b.link(fact.id, other.id, label: 'para mi pasaporte');
    expect(b.edgesOf(other).map((p) => p.$1.id), contains(e.id));
    await b.relabel(e, 'para este proyecto');
    expect(b.graph!.edges.firstWhere((x) => x.id == e.id).label, 'para este proyecto');
    await b.unlink(e);
    expect(b.graph!.edges.any((x) => x.id == e.id), isFalse);
    expect((await b.trash()).hiddenEdges.map((h) => h.edge.id), contains(e.id));
    await b.restoreEdge(e.id!);
    expect(b.graph!.edges.any((x) => x.id == e.id), isTrue);

    final preview = await b.previewDelete(fact);
    expect(b.graph!.nodeById[fact.id], isNotNull, reason: 'dry_run no borra nada');
    expect(preview.edgesRemoved, isNotEmpty);
    await b.delete(fact);
    expect(b.graph!.nodeById[fact.id], isNull);
    await b.restore(fact.id);
    expect(b.graph!.nodeById[fact.id], isNotNull);
    b.dispose();
  });

  testWidgets('pantalla Guardados: escribir, guardar y mandar a la papelera con Deshacer', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LaikaPrototypes(initial: 'laika'));
    await tester.pump();
    await tester.tap(find.text('Guardados').first);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, 'PRUEBA idea desde la pantalla');
    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PRUEBA idea desde la pantalla'), findsOneWidget);
    final card = find.ancestor(of: find.text('PRUEBA idea desde la pantalla'), matching: find.byType(Column)).first;
    await tester.tap(find.descendant(of: card, matching: find.text('Papelera')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PRUEBA idea desde la pantalla'), findsNothing);
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // termina de entrar el aviso
    await tester.tap(find.text('Deshacer'));
    await tester.pump(const Duration(seconds: 3)); // recuperar + recargar (3 llamadas al simulador)
    expect(find.text('PRUEBA idea desde la pantalla'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
