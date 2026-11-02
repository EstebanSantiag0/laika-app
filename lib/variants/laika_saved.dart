// Diseño Laika — pantallas del segundo cerebro: Guardados y Gustos.
// Mismo estilo que Agenda: tarjetas Brutal con colores Cristal.

part of 'laika.dart';

const _kindColor = {'idea': lPink, 'for_later': lSky, 'saved': lMint};
const _formatIcon = {
  'text': Icons.notes_rounded,
  'link': Icons.link_rounded,
  'video': Icons.smart_display_rounded,
  'pdf': Icons.picture_as_pdf_rounded,
  'book': Icons.menu_book_rounded,
  'image': Icons.image_rounded,
};

/// Aviso corto abajo, con un botón opcional (p. ej. "Deshacer").
void _toast(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: _t(14, color: Colors.white)),
      backgroundColor: lInk,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: action == null ? 3 : 8),
      action: action == null ? null : SnackBarAction(label: action, textColor: lPink, onPressed: onAction!),
    ));
}

/// Mensaje legible de un error del servidor.
String _why(Object e) => switch (e) {
      LaikaApiError(status: 413, :final maxMb) => 'Es muy grande (máximo ${maxMb ?? '?'} MB)',
      LaikaApiError(status: 415) => 'Laika todavía no sabe leer ese tipo de archivo',
      LaikaApiError(status: 409) => 'Alguien lo cambió antes (Obsidian o Laika). Ya se recargó: vuelve a intentarlo',
      LaikaApiError(:final message, :final field?) => '$message ($field)',
      LaikaOffline(:final message) => message,
      _ => '$e',
    };

Widget _chip(String label, Color color, bool selected, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: brutalBox(selected ? color : Colors.white, shadow: selected ? 0 : 2, border: 1.8),
        child: Text(label, style: _t(12.5, w: FontWeight.w700)),
      ),
    );

Widget _action(String label, Color color, VoidCallback? onTap, {IconData? icon}) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: brutalBox(color, shadow: 2, border: 1.8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: lInk), const SizedBox(width: 4)],
          Text(label, style: _t(12, w: FontWeight.w800)),
        ]),
      ),
    );

/// Abre un archivo o URL con el programa del sistema (Linux).
Future<void> _openExternal(Uri uri) async {
  if (Platform.isLinux) await Process.run('xdg-open', [uri.toString()]);
}

// ── Guardados ───────────────────────────────────────────────────────────────

class LaikaSaved extends StatefulWidget {
  const LaikaSaved({super.key, required this.saved, required this.areas});
  final SecondBrainController saved;
  final List<Area> areas;
  @override
  State<LaikaSaved> createState() => _LaikaSavedState();
}

class _LaikaSavedState extends State<LaikaSaved> {
  final _capture = TextEditingController();
  final _search = TextEditingController();
  String? _captureKind; // null = que Laika lo clasifique
  bool _busy = false;
  Timer? _debounce;

  SecondBrainController get s => widget.saved;

  @override
  void initState() {
    super.initState();
    s.load();
  }

  @override
  void dispose() {
    _capture.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final msg = await job();
      if (mounted && msg.isNotEmpty) _toast(context, msg);
    } catch (e) {
      if (mounted) _toast(context, _why(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    final text = _capture.text;
    if (text.trim().isEmpty) return;
    await _run(() async {
      final m = await s.capture(text, kind: _captureKind);
      _capture.clear();
      return m;
    });
  }

  Future<void> _upload() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Documentos', extensions: ['pdf', 'epub', 'fb2', 'docx', 'txt', 'md', 'html', 'png', 'jpg', 'jpeg', 'webp']),
    ]);
    if (f == null) return;
    await _run(() => s.upload(f.path, kind: _captureKind));
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [s],
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Guardados', style: _t(44, w: FontWeight.w900)),
          Text('Ideas, cosas para después, PDFs, links y videos. Laika los lee y te los recuerda.', style: _t(13, color: lSoft)),
          const SizedBox(height: 18),
          _captureBox(),
          const SizedBox(height: 18),
          _searchBox(),
          const SizedBox(height: 14),
          if (s.results != null) ..._results() else ..._list(),
        ],
      ),
    );
  }

  Widget _captureBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: brutalBox(Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _capture,
            minLines: 1,
            maxLines: 4,
            style: _t(15),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Escribe una idea o pega un link (Instagram, YouTube, un artículo, un PDF…)',
              hintStyle: _t(14, color: lSoft),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _chip('Que Laika decida', lLavender, _captureKind == null, () => setState(() => _captureKind = null)),
            for (final k in Item.kinds)
              _chip(itemKindLabels[k]!, _kindColor[k]!, _captureKind == k, () => setState(() => _captureKind = k)),
            const SizedBox(width: 12),
            _action(_busy ? 'Guardando…' : 'Guardar', lLavender, _busy ? null : _save, icon: Icons.add_rounded),
            _action('Subir archivo', lPeach, _busy ? null : _upload, icon: Icons.attach_file_rounded),
          ]),
        ]),
      );

  Widget _searchBox() => Container(
        decoration: brutalBox(Colors.white, shadow: 3),
        child: TextField(
          controller: _search,
          style: _t(14),
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => s.search(q));
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(11),
            prefixIcon: const Icon(Icons.search_rounded, color: lInk),
            hintText: 'Buscar en todo lo guardado y en lo que Laika leyó',
            hintStyle: _t(14, color: lSoft),
            suffixIcon: s.searching
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : (_search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: lInk),
                        onPressed: () {
                          _search.clear();
                          s.search('');
                        })),
          ),
        ),
      );

  List<Widget> _results() {
    final r = s.results!;
    return [
      Text(r.isEmpty ? 'Nada con «${s.query}».' : '${r.length} resultados para «${s.query}»', style: _t(13, w: FontWeight.w700, color: lSoft)),
      const SizedBox(height: 10),
      for (final h in r)
        GestureDetector(
          onTap: () => _openHit(h),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: brutalBox(Colors.white, shadow: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_formatIcon[h.format] ?? Icons.notes_rounded, color: lInk),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(h.title, style: _t(15, w: FontWeight.w800))),
                    if (h.pages != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: brutalBox(lSky, shadow: 0, border: 1.5),
                        child: Text(h.pages!, style: _t(11.5, w: FontWeight.w800)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(h.snippet, style: _t(13), maxLines: 3, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
        ),
    ];
  }

  Future<void> _openHit(SearchHit h) async {
    try {
      final it = await s.api.item(h.itemId);
      if (mounted) await _showItem(context, s, it, widget.areas, page: h.pageFrom);
    } catch (e) {
      if (mounted) _toast(context, _why(e));
    }
  }

  List<Widget> _list() => [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _chip('Todo', lLavender, s.kind == null, () => s.setKind(null)),
          for (final k in Item.kinds) _chip(itemKindLabels[k]!, _kindColor[k]!, s.kind == k, () => s.setKind(k)),
          const SizedBox(width: 14),
          for (final (st, label) in const [('active', 'Activos'), ('done', 'Hechos'), ('archived', 'Archivados')])
            _chip(label, lPeach, s.status == st, () => s.setStatus(st)),
        ]),
        if (s.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (t, n) in s.tags) _chip('#$t · $n', lMint, s.tag == t, () => s.setTag(s.tag == t ? null : t)),
          ]),
        ],
        const SizedBox(height: 16),
        if (s.error != null) Text(_why(s.error!), style: _t(13, color: const Color(0xFFB4235A))),
        if (s.items.isEmpty && !s.loading)
          Text('Aquí no hay nada todavía.', style: _t(14, color: lSoft)),
        Wrap(spacing: 18, runSpacing: 18, children: [for (final it in s.items) _card(it)]),
        if (s.nextBefore != null) ...[
          const SizedBox(height: 18),
          Center(child: _action(s.loading ? 'Cargando…' : 'Ver más', Colors.white, s.more)),
        ],
      ];

  Widget _card(Item it) {
    final doc = it.doc;
    final areaNames = it.areas.map((a) => widget.areas.where((x) => x.id == a).firstOrNull?.name ?? a).join(', ');
    return SizedBox(
      width: 300,
      child: GestureDetector(
        onTap: () => _showItem(context, s, it, widget.areas),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: brutalBox(it.status == 'active' ? Colors.white : const Color(0xFFF4F1FA)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: brutalBox(_kindColor[it.kind]!, shadow: 0, border: 1.5),
                child: Text(it.kindLabel.toUpperCase(), style: _t(10.5, w: FontWeight.w900)),
              ),
              const Spacer(),
              Icon(_formatIcon[it.format] ?? Icons.notes_rounded, size: 18, color: lInk),
            ]),
            const SizedBox(height: 8),
            Text(it.displayTitle, style: _t(16, w: FontWeight.w800), maxLines: 3, overflow: TextOverflow.ellipsis),
            if (it.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('“${it.note}”', style: _t(12.5, color: lSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 6),
            Text(
              [if (areaNames.isNotEmpty) areaNames, ...it.tags.map((t) => '#$t'), if (it.createdAt != null) friendlyDate(it.createdAt!)]
                  .join(' · '),
              style: _t(11.5, w: FontWeight.w600, color: lSoft),
            ),
            if (doc != null && !doc.ready) ...[
              const SizedBox(height: 8),
              Text('Laika: ${doc.stateLabel}', style: _t(11.5, w: FontWeight.w700, color: lAccent)),
              if (doc.fraction != null) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: doc.fraction, color: lAccent, backgroundColor: lLavender, minHeight: 5),
              ],
            ] else if (doc != null && doc.state == 'ready_partial')
              Text('Laika: ${doc.stateLabel}', style: _t(11.5, w: FontWeight.w700, color: lSoft)),
            if (it.format == 'video' && doc == null)
              Text('Laika: lo transcribe cuando estés un rato sin escribirle', style: _t(11.5, w: FontWeight.w700, color: lAccent)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (it.status == 'active') ...[
                _action('Hecho', lMint, () => _patch(it, {'status': 'done'}, 'Marcado como hecho')),
                _action('Archivar', lSky, () => _patch(it, {'status': 'archived'}, 'Archivado')),
              ] else
                _action('Reactivar', lMint, () => _patch(it, {'status': 'active'}, 'De vuelta en activos')),
              _action('Papelera', lPink, () => _delete(it), icon: Icons.delete_outline_rounded),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _patch(Item it, Map<String, Object?> f, String done) async {
    try {
      await s.patch(it, f);
      if (mounted) _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, _why(e));
      await s.load();
    }
  }

  Future<void> _delete(Item it) async {
    try {
      final r = await s.delete(it);
      if (!mounted) return;
      final extra = r.trashed.length > 1 ? ' (y ${r.trashed.length - 1} cosas más)' : '';
      _toast(context, '«${it.displayTitle}» está en la papelera$extra', action: 'Deshacer', onAction: () => s.restore(it));
    } catch (e) {
      if (mounted) _toast(context, _why(e));
    }
  }
}

/// Detalle de una cosa guardada: editar, ver páginas del PDF, abrir el archivo.
Future<void> _showItem(BuildContext context, SecondBrainController s, Item it, List<Area> areas, {int? page}) =>
    showDialog(context: context, builder: (_) => _ItemDialog(saved: s, item: it, areas: areas, page: page));

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.saved, required this.item, required this.areas, this.page});
  final SecondBrainController saved;
  final Item item;
  final List<Area> areas;
  final int? page;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _note = TextEditingController(text: widget.item.note);
  late final _tags = TextEditingController(text: widget.item.tags.join(', '));
  late String _kind = widget.item.kind;
  late final Set<String> _areas = {...widget.item.areas};
  late int _page = widget.page ?? 1;
  String? _error;

  Item get it => widget.item;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tags = _tags.text.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet().toList();
    if (tags.length > 3) return setState(() => _error = 'Máximo 3 etiquetas');
    final f = <String, Object?>{
      if (_title.text.trim() != it.title) 'title': _title.text.trim(),
      if (_note.text.trim() != it.note) 'note': _note.text.trim(),
      if (_kind != it.kind) 'kind': _kind,
      if (!setEquals(_areas, it.areas.toSet())) 'areas': _areas.toList(),
      if (!listEquals(tags, it.tags)) 'tags': tags,
    };
    if (f.isEmpty) return Navigator.pop(context);
    try {
      await widget.saved.patch(it, f);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _why(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.saved.api;
    final pages = it.doc?.pages;
    final img = it.format == 'pdf' ? api.pageImage(it.id, _page, width: 900) : null;
    final file = it.doc != null ? api.fileUrl(it.id) : null;
    InputDecoration deco(String hint) => InputDecoration(
        isDense: true, hintText: hint, hintStyle: _t(13, color: lSoft), border: const OutlineInputBorder(), labelText: hint);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 760),
        padding: const EdgeInsets.all(20),
        decoration: brutalBox(Colors.white, shadow: 8),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_formatIcon[it.format] ?? Icons.notes_rounded, color: lInk),
              const SizedBox(width: 8),
              Expanded(child: Text(it.displayTitle, style: _t(20, w: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            if (it.url != null)
              GestureDetector(
                onTap: () => _openExternal(Uri.parse(it.url!)),
                child: Text(it.url!, style: _t(12.5, color: lAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (it.text.isNotEmpty && it.text != it.title) ...[
              const SizedBox(height: 8),
              Text(it.text, style: _t(14)),
            ],
            if (it.doc != null) ...[
              const SizedBox(height: 8),
              Text('Documento: ${it.doc!.stateLabel}${pages != null ? ' · $pages páginas' : ''}',
                  style: _t(12, w: FontWeight.w700, color: lSoft)),
            ],
            if (img != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                IconButton(onPressed: _page > 1 ? () => setState(() => _page--) : null, icon: const Icon(Icons.chevron_left_rounded)),
                Text('Página $_page${pages != null ? ' de $pages' : ''}', style: _t(13, w: FontWeight.w700)),
                IconButton(
                    onPressed: pages == null || _page < pages ? () => setState(() => _page++) : null,
                    icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              Container(
                decoration: brutalBox(Colors.white, shadow: 3),
                height: 420,
                alignment: Alignment.center,
                child: Image.network(img.toString(),
                    key: ValueKey(img),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text('No se pudo cargar la página', style: _t(13, color: lSoft)),
                    loadingBuilder: (_, child, p) => p == null ? child : const CircularProgressIndicator()),
              ),
            ],
            if (file != null) ...[
              const SizedBox(height: 10),
              _action('Abrir el archivo', lSky, () => _openExternal(file), icon: Icons.open_in_new_rounded),
            ],
            const Divider(height: 28),
            Text('Editar', style: _t(14, w: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: _title, style: _t(14), maxLength: 120, decoration: deco('Título')),
            TextField(controller: _note, style: _t(14), maxLines: 2, decoration: deco('Nota (para qué lo quieres)')),
            const SizedBox(height: 10),
            TextField(controller: _tags, style: _t(14), decoration: deco('Etiquetas (máx. 3, separadas por comas)')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in Item.kinds) _chip(itemKindLabels[k]!, _kindColor[k]!, _kind == k, () => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 10),
            Text('Áreas (máx. 3)', style: _t(12, w: FontWeight.w700, color: lSoft)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in widget.areas)
                _chip(a.name, a.color.withValues(alpha: 0.45), _areas.contains(a.id), () {
                  setState(() {
                    if (!_areas.remove(a.id) && _areas.length < 3) _areas.add(a.id);
                  });
                }),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: _t(13, color: const Color(0xFFB4235A))),
            ],
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: _action('Guardar cambios', lMint, _save, icon: Icons.check_rounded)),
          ]),
        ),
      ),
    );
  }
}

// ── Gustos ──────────────────────────────────────────────────────────────────

class LaikaLikes extends StatefulWidget {
  const LaikaLikes({super.key, required this.saved});
  final SecondBrainController saved;
  @override
  State<LaikaLikes> createState() => _LaikaLikesState();
}

class _LaikaLikesState extends State<LaikaLikes> {
  SecondBrainController get s => widget.saved;

  @override
  void initState() {
    super.initState();
    s.loadLikes();
  }

  Future<void> _do(Future<void> Function() job, String done) async {
    try {
      await job();
      if (mounted) _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, _why(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      listenables: [s],
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(36, 80, 36, 60),
        children: [
          Text('Gustos', style: _t(44, w: FontWeight.w900)),
          Text('Lo que Laika sabe que te gusta y que no. Se los dices platicando; aquí los acomodas.', style: _t(13, color: lSoft)),
          if (s.error != null) Text(_why(s.error!), style: _t(13, color: const Color(0xFFB4235A))),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) {
              final cols = [_column('Le gusta', '❤️', lPink, s.likes, 'like'), _column('No le gusta', '🙅', lSky, s.dislikes, 'dislike')];
              return box.maxWidth > 760
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: cols[0]),
                      const SizedBox(width: 24),
                      Expanded(child: cols[1]),
                    ])
                  : Column(children: [cols[0], const SizedBox(height: 24), cols[1]]);
            },
          ),
        ],
      ),
    );
  }

  Widget _column(String title, String emoji, Color color, List<Fact> facts, String polarity) {
    final other = polarity == 'like' ? 'dislike' : 'like';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: brutalBox(color, shadow: 2, border: 2),
        child: Text('$emoji  ${title.toUpperCase()} · ${facts.length}', style: _t(12, w: FontWeight.w900)),
      ),
      const SizedBox(height: 12),
      if (facts.isEmpty) Text('Nada todavía.', style: _t(13, color: lSoft)),
      for (final f in facts)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: brutalBox(Colors.white, shadow: 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.sensitive ? '🔒 privado' : f.text, style: _t(15, w: FontWeight.w700)),
            if (f.createdAt != null) Text(friendlyDate(f.createdAt!), style: _t(11.5, w: FontWeight.w600, color: lSoft)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _action(polarity == 'like' ? 'Pasar a "no le gusta"' : 'Pasar a "le gusta"', polarity == 'like' ? lSky : lPink,
                  () => _do(() => s.setPolarity(f, other), 'Movido')),
              _action('Ya no es un gusto', lLavender, () => _do(() => s.setPolarity(f, null), 'Ahora es solo un dato')),
              _action('Archivar', lPeach, () => _do(() => s.archiveLike(f), 'Archivado (ya no es cierto)')),
            ]),
          ]),
        ),
    ]);
  }
}
