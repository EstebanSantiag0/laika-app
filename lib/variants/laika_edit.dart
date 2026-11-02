// Diseño Laika — editar el cerebro desde la app (Esteban: "cada punto se
// puede editar y borrar desde la app, hasta las conexiones").
//
// Solo se muestran los controles que el servidor permite (node.editable,
// node.deletable, edge.id). Borrar manda a una papelera de 30 días y
// siempre hay "Deshacer".

part of 'laika.dart';

/// Botones bajo la nota del nodo seleccionado + sus conexiones editables.
class NodeActions extends StatelessWidget {
  const NodeActions({super.key, required this.brain, required this.node});
  final BrainController brain;
  final MemoryNode node;

  @override
  Widget build(BuildContext context) {
    final edges = brain.edgesOf(node).where((p) => p.$1.deletable && p.$1.kind != 'in_area').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (node.editable.isNotEmpty) _action('Editar', lMint, () => _editNode(context, brain, node), icon: Icons.edit_rounded),
        _action('Conectar con…', lSky, () => _connect(context, brain, node), icon: Icons.add_link_rounded),
        if (node.deletable) _action('Papelera', lPink, () => _deleteNode(context, brain, node), icon: Icons.delete_outline_rounded),
      ]),
      if (edges.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Conexiones', style: _t(11.5, w: FontWeight.w700, color: lSoft)),
        const SizedBox(height: 4),
        for (final (e, other) in edges)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(e.origin == 'user' ? Icons.gesture_rounded : Icons.auto_awesome_rounded, size: 14, color: lSoft),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => brain.select(other.id),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: other.label, style: _t(12.5, w: FontWeight.w700)),
                    if ((e.label ?? '').isNotEmpty) TextSpan(text: '  · ${e.label}', style: _t(12, color: lSoft)),
                  ])),
                ),
              ),
              if (e.id!.startsWith('link:') || e.id!.startsWith('about:'))
                IconButton(
                  tooltip: 'Cambiar la razón',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => _relabel(context, brain, e),
                  icon: const Icon(Icons.edit_note_rounded, color: lInk),
                ),
              IconButton(
                tooltip: e.origin == 'user' ? 'Borrar conexión' : 'Ocultar conexión',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: () => _unlink(context, brain, e),
                icon: const Icon(Icons.link_off_rounded, color: lInk),
              ),
            ]),
          ),
      ],
    ]);
  }
}

Future<void> _guard(BuildContext context, Future<void> Function() job, [String? done]) async {
  try {
    await job();
    if (context.mounted && done != null) _toast(context, done);
  } catch (e) {
    if (context.mounted) _toast(context, _why(e));
  }
}

Future<void> _unlink(BuildContext context, BrainController brain, MemoryEdge e) => _guard(context, () async {
      await brain.unlink(e);
      if (!context.mounted) return;
      final what = switch (e.kind) {
        'tagged' => 'Etiqueta quitada',
        'link' => 'Conexión borrada',
        _ => 'Conexión oculta (Laika no la vuelve a poner)',
      };
      _toast(context, what, action: e.kind == 'tagged' ? null : 'Deshacer', onAction: () => brain.restoreEdge(e.id!));
    });

Future<String?> _ask(BuildContext context, String title, {String initial = '', String hint = '', int max = 80}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: _t(18, w: FontWeight.w800)),
      content: TextField(controller: c, autofocus: true, maxLength: max, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Listo')),
      ],
    ),
  );
}

Future<void> _relabel(BuildContext context, BrainController brain, MemoryEdge e) async {
  final label = await _ask(context, '¿Por qué están conectados?', initial: e.label ?? '');
  if (label == null || !context.mounted) return;
  await _guard(context, () => brain.relabel(e, label), 'Listo');
}

/// Elegir otro nodo y conectarlo con este.
Future<void> _connect(BuildContext context, BrainController brain, MemoryNode node) async {
  final target = await showDialog<MemoryNode>(context: context, builder: (_) => _NodePicker(brain: brain, exclude: node.id));
  if (target == null || !context.mounted) return;
  final label = await _ask(context, 'Conectar «${node.label}» con «${target.label}»',
      hint: 'para qué (opcional): "para mi pasaporte", "puede servir para este proyecto"');
  if (label == null || !context.mounted) return;
  await _guard(context, () => brain.link(node.id, target.id, label: label.isEmpty ? null : label), 'Conectados 🔗');
}

class _NodePicker extends StatefulWidget {
  const _NodePicker({required this.brain, required this.exclude});
  final BrainController brain;
  final String exclude;
  @override
  State<_NodePicker> createState() => _NodePickerState();
}

class _NodePickerState extends State<_NodePicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final g = widget.brain.graph!;
    final ql = q.toLowerCase();
    final list = g.nodes
        .where((n) => n.id != widget.exclude && n.kind != NodeKind.area && !n.sensitive)
        .where((n) => ql.isEmpty || n.label.toLowerCase().contains(ql) || n.text.toLowerCase().contains(ql))
        .take(60)
        .toList();
    return AlertDialog(
      title: Text('¿Con qué lo conectas?', style: _t(18, w: FontWeight.w800)),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(children: [
          TextField(autofocus: true, onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Buscar')),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (final n in list)
                ListTile(
                  dense: true,
                  title: Text(n.label, style: _t(14, w: FontWeight.w600)),
                  subtitle: Text(describeNode(n, g), style: _t(11.5, color: lSoft)),
                  onTap: () => Navigator.pop(context, n),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Confirmar con lo que se llevaría (dry_run), borrar y ofrecer "Deshacer".
Future<void> _deleteNode(BuildContext context, BrainController brain, MemoryNode node) async {
  var withFacts = false;
  TrashResult preview;
  try {
    preview = await brain.previewDelete(node);
  } catch (e) {
    if (context.mounted) _toast(context, _why(e));
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final more = preview.trashed.length - 1;
        final what = switch (node.kind) {
          NodeKind.entity when !withFacts => 'Sus datos se quedan, solo pierden la conexión.',
          NodeKind.episode => 'Sus datos y mensajes se quedan.',
          NodeKind.item => 'Su documento (PDF, página, transcripción) se va con él.',
          NodeKind.tag => 'Se quita de todo lo que la tenía.',
          NodeKind.reminder => 'Ya no te lo avisará (no es lo mismo que "hecho").',
          _ => null,
        };
        return AlertDialog(
          title: Text('¿Mandar «${node.label}» a la papelera?', style: _t(18, w: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                [
                  if (more > 0) 'También se van $more cosas más.',
                  if (preview.edgesRemoved.isNotEmpty) 'Se quitan ${preview.edgesRemoved.length} conexiones.',
                  ?what,
                  'Se borra para siempre en 30 días; mientras, lo puedes recuperar.',
                ].join('\n'),
                style: _t(14)),
            if (node.kind == NodeKind.entity)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: withFacts,
                title: Text('Llevarme también sus datos', style: _t(14)),
                onChanged: (v) async {
                  final p = await brain.previewDelete(node, withFacts: v == true);
                  setState(() {
                    withFacts = v == true;
                    preview = p;
                  });
                },
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB4235A)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('A la papelera'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  await _guard(context, () async {
    await brain.delete(node, withFacts: withFacts);
    if (context.mounted) {
      _toast(context, '«${node.label}» está en la papelera', action: 'Deshacer', onAction: () => brain.restore(node.id));
    }
  });
}

/// Un editor con un control por campo que el servidor deja editar.
Future<void> _editNode(BuildContext context, BrainController brain, MemoryNode node) =>
    showDialog(context: context, builder: (_) => _NodeEditor(brain: brain, node: node));

class _NodeEditor extends StatefulWidget {
  const _NodeEditor({required this.brain, required this.node});
  final BrainController brain;
  final MemoryNode node;
  @override
  State<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<_NodeEditor> {
  MemoryNode get n => widget.node;
  final Map<String, Object?> _values = {};
  final Map<String, TextEditingController> _text = {};
  String? _error;
  bool _busy = false;

  static const _textFields = {'text', 'title', 'name', 'note', 'summary'};
  static const _dateFields = {'valid_from', 'valid_to', 'review_after', 'due_at'};
  static const _labels = {
    'text': 'Texto',
    'title': 'Título',
    'name': 'Nombre',
    'note': 'Nota',
    'summary': 'Resumen',
    'areas': 'Áreas',
    'tags': 'Etiquetas (separadas por comas)',
    'aliases': 'Otros nombres (separados por comas)',
    'time_scope': 'Tiempo',
    'polarity': 'Gusto',
    'sensitive': 'Dato sensible (se oculta en pantalla)',
    'no_mention': 'Que Laika no lo mencione',
    'kind': 'Tipo',
    'status': 'Estado',
    'subkind': 'Qué es',
    'color': 'Color (#rrggbb)',
    'valid_from': 'Válido desde (AAAA-MM-DD)',
    'valid_to': 'Válido hasta (AAAA-MM-DD)',
    'review_after': 'Preguntar si sigue siendo cierto desde (AAAA-MM-DD)',
    'due_at': 'Para cuándo (AAAA-MM-DD HH:MM)',
  };

  /// Valor actual de un campo, según el nodo.
  Object? _current(String f) => switch (f) {
        'text' => n.kind == NodeKind.entity ? null : n.text,
        'summary' => n.text,
        'title' || 'name' => n.label,
        'areas' => n.areas,
        'tags' => n.tags,
        'time_scope' => n.timeScope.wire,
        'polarity' => n.polarity,
        'sensitive' => n.sensitive,
        'kind' => n.itemKind,
        'status' => n.status,
        'subkind' => n.subkind,
        'color' => n.kind == NodeKind.area ? _hex(widget.brain.graph?.areaById[n.id.substring(5)]?.color) : null,
        'valid_from' => _day(n.validFrom),
        'valid_to' => _day(n.validTo),
        'review_after' => _day(n.reviewAfter),
        'due_at' => n.dueAt == null ? null : '${_day(n.dueAt)} ${n.dueAt!.hour.toString().padLeft(2, '0')}:${n.dueAt!.minute.toString().padLeft(2, '0')}',
        _ => null,
      };

  static String? _day(DateTime? d) => d?.toIso8601String().substring(0, 10);
  static String? _hex(Color? c) => c == null ? null : '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  void initState() {
    super.initState();
    for (final f in n.editable) {
      final v = _current(f);
      _values[f] = v is List ? [...v] : v;
      if (_textFields.contains(f) || _dateFields.contains(f) || f == 'color' || f == 'tags' || f == 'aliases') {
        _text[f] = TextEditingController(text: v is List ? v.join(', ') : (v?.toString() ?? ''));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Solo lo que cambió, ya con el formato del servidor.
  Map<String, Object?> _changes() {
    final out = <String, Object?>{};
    for (final f in n.editable) {
      Object? v = _values[f];
      final c = _text[f];
      if (c != null) {
        final s = c.text.trim();
        if (f == 'tags' || f == 'aliases') {
          v = s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        } else if (f == 'due_at') {
          v = s.isEmpty ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'))?.toIso8601String() ?? s;
        } else {
          v = s.isEmpty && _dateFields.contains(f) ? null : s;
        }
      }
      final old = _current(f);
      final same = (v is List && old is List) ? listEquals(v, old) : (f == 'due_at' ? c!.text.trim() == (old ?? '') : v == old);
      if (!same) out[f] = v;
    }
    return out;
  }

  Future<void> _save() async {
    final f = _changes();
    if (f.isEmpty) return Navigator.pop(context);
    setState(() => _busy = true);
    try {
      // Renombrar una etiqueta a una que ya existe las fusiona: preguntar antes.
      if (n.kind == NodeKind.tag && f['name'] is String) {
        final (into, count) = await widget.brain.api.tagRenamePreview(n.id, f['name'] as String);
        if (into != null && mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('¿Fusionar con #$into?', style: _t(18, w: FontWeight.w800)),
              content: Text('Ya existe #$into. Las $count cosas con #${n.label} pasarán a #$into. Se puede deshacer desde la papelera.',
                  style: _t(14)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fusionar')),
              ],
            ),
          );
          if (ok != true) return setState(() => _busy = false);
        }
      }
      await widget.brain.edit(n, f);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, 'Guardado');
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _why(e);
      });
    }
  }

  Widget _field(String f) {
    final label = _labels[f] ?? f;
    Widget choices(List<(String?, String)> opts) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _t(12, w: FontWeight.w700, color: lSoft)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (v, l) in opts) _chip(l, lLavender, _values[f] == v, () => setState(() => _values[f] = v)),
          ]),
        ]);
    switch (f) {
      case 'areas':
        final g = widget.brain.graph!;
        final max = n.kind == NodeKind.reminder ? 2 : 3;
        final sel = (_values[f] as List).cast<String>();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label (máx. $max)', style: _t(12, w: FontWeight.w700, color: lSoft)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in g.areas)
              _chip(a.name, a.color.withValues(alpha: 0.45), sel.contains(a.id), () {
                setState(() {
                  if (!sel.remove(a.id) && sel.length < max) sel.add(a.id);
                });
              }),
          ]),
        ]);
      case 'time_scope':
        return choices([for (final t in TimeScope.values.where((t) => t != TimeScope.reminder)) (t.wire, t.label)]);
      case 'polarity':
        return choices(const [('like', 'Le gusta'), ('dislike', 'No le gusta'), (null, 'Ninguno')]);
      case 'kind':
        return choices([for (final k in Item.kinds) (k, itemKindLabels[k]!)]);
      case 'status':
        return choices(n.kind == NodeKind.item ? const [('active', 'Activo'), ('done', 'Hecho'), ('archived', 'Archivado')] : const []);
      case 'subkind':
        return choices(const [('person', 'Persona'), ('place', 'Lugar'), ('thing', 'Cosa'), ('topic', 'Tema'), ('work', 'Obra')]);
      case 'sensitive' || 'no_mention':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: _t(14)),
          value: _values[f] == true,
          onChanged: (v) => setState(() => _values[f] = v),
        );
      default:
        final c = _text[f];
        if (c == null) return const SizedBox.shrink();
        final max = switch ((n.kind, f)) {
          (NodeKind.fact, 'text') => 500,
          (NodeKind.reminder, 'text') => 300,
          (_, 'title') => 120,
          (_, 'name') => n.kind == NodeKind.entity ? 80 : 40,
          _ => null,
        };
        return TextField(
          controller: c,
          maxLength: max,
          minLines: 1,
          maxLines: f == 'text' || f == 'summary' || f == 'note' ? 5 : 1,
          style: _t(14),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(20),
        decoration: brutalBox(Colors.white, shadow: 8),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Editar ${n.kind == NodeKind.item ? itemKindLabels[n.itemKind]?.toLowerCase() : n.kind.label.toLowerCase()}',
                style: _t(20, w: FontWeight.w900)),
            const SizedBox(height: 14),
            for (final f in n.editable) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
            if (_error != null) Text(_error!, style: _t(13, color: const Color(0xFFB4235A))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              _action(_busy ? 'Guardando…' : 'Guardar', lMint, _busy ? null : _save, icon: Icons.check_rounded),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// La papelera: lo borrado (30 días) y las conexiones que ocultaste.
Future<void> showTrash(BuildContext context, BrainController brain) =>
    showDialog(context: context, builder: (_) => _TrashDialog(brain: brain));

class _TrashDialog extends StatefulWidget {
  const _TrashDialog({required this.brain});
  final BrainController brain;
  @override
  State<_TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends State<_TrashDialog> {
  late Future<Trash> _trash = widget.brain.trash();

  Future<void> _restore(Future<void> Function() job) async {
    await _guard(context, job, 'Recuperado');
    setState(() => _trash = widget.brain.trash());
  }

  @override
  Widget build(BuildContext context) {
    String f(DateTime? d) => d == null ? '' : friendlyDate(d);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        decoration: brutalBox(Colors.white, shadow: 8),
        child: FutureBuilder<Trash>(
          future: _trash,
          builder: (context, snap) {
            final t = snap.data;
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Papelera', style: _t(24, w: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              Text('Lo borrado se va para siempre a los 30 días.', style: _t(12.5, color: lSoft)),
              const SizedBox(height: 12),
              if (snap.hasError) Text(_why(snap.error!), style: _t(13, color: const Color(0xFFB4235A))),
              if (t == null && !snap.hasError) const Center(child: CircularProgressIndicator()),
              if (t != null && t.nodes.isEmpty && t.hiddenEdges.isEmpty) Text('Vacía.', style: _t(14, color: lSoft)),
              if (t != null)
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    for (final x in t.nodes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(x.renamedTo != null ? '#${x.node.label} → #${x.renamedTo}' : x.node.label, style: _t(14, w: FontWeight.w700)),
                        subtitle: Text(
                            [
                              x.renamedTo != null ? 'Etiqueta fusionada' : x.node.kind.label,
                              if (x.withIds.isNotEmpty) 'con ${x.withIds.length} cosas más',
                              if (x.purgeAt != null) 'se borra el ${f(x.purgeAt)}',
                            ].join(' · '),
                            style: _t(12, color: lSoft)),
                        trailing: _action('Recuperar', lMint, () => _restore(() => widget.brain.restore(x.node.id))),
                      ),
                    if (t.hiddenEdges.isNotEmpty) ...[
                      const Divider(),
                      Text('Conexiones ocultas', style: _t(13, w: FontWeight.w800)),
                    ],
                    for (final h in t.hiddenEdges)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_edgeText(h.edge), style: _t(13.5, w: FontWeight.w600)),
                        subtitle: Text('${h.edge.kind}${h.hiddenAt != null ? ' · oculta el ${f(h.hiddenAt)}' : ''}', style: _t(12, color: lSoft)),
                        trailing: _action('Mostrar', lSky, () => _restore(() => widget.brain.restoreEdge(h.edge.id!))),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      ),
    );
  }

  String _edgeText(MemoryEdge e) {
    final g = widget.brain.graph;
    String name(String id) => g?.nodeById[id]?.label ?? id;
    return '${name(e.source)} ↔ ${name(e.target)}';
  }
}
