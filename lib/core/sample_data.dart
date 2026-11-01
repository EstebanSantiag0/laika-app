// Datos de ejemplo para el backend simulado.
//
// Todo es FICTICIO: este repositorio es público, así que aquí nunca van los
// recuerdos reales de Laika. Las fechas se calculan a partir de "ahora" para
// que "hoy", "mañana" y "la próxima semana" siempre se vean correctos.

import 'package:flutter/material.dart';

import 'models.dart';

const kAreas = <Area>[
  Area(id: 'study', name: 'Estudios', color: Color(0xFF5B8DEF)),
  Area(id: 'projects', name: 'Proyectos', color: Color(0xFF8B5CF6)),
  Area(id: 'finance', name: 'Finanzas', color: Color(0xFF22C55E)),
  Area(id: 'legal', name: 'Legal/trámites', color: Color(0xFFEF4444)),
  Area(id: 'skills', name: 'Habilidades', color: Color(0xFFF5B400)),
  Area(id: 'work', name: 'Trabajo/prácticas', color: Color(0xFF14B8A6)),
  Area(id: 'languages', name: 'Idiomas', color: Color(0xFFEC4899)),
  Area(id: 'health', name: 'Salud', color: Color(0xFFF97316)),
  Area(id: 'people', name: 'Personas', color: Color(0xFFA78BFA)),
  Area(id: 'home', name: 'Hogar/día a día', color: Color(0xFF94A3B8)),
];

MemoryGraph buildSampleGraph(DateTime now) {
  DateTime d(int days, [int hour = 10]) =>
      DateTime(now.year, now.month, now.day + days, hour);

  final nodes = <MemoryNode>[];
  final edges = <MemoryEdge>[];

  void entity(String id, String label, List<String> areas, String text,
      {double imp = 0.6}) {
    nodes.add(MemoryNode(
      id: 'entity:$id',
      kind: NodeKind.entity,
      label: label,
      text: text,
      areas: areas,
      importance: imp,
      createdAt: d(-30),
    ));
  }

  var factN = 0;
  void fact(String label, List<String> areas, TimeScope scope,
      {String? about,
      String text = '',
      int ageDays = 10,
      DateTime? validTo,
      DateTime? dueAt,
      double imp = 0.5,
      bool sensitive = false}) {
    final id = 'fact:${++factN}';
    nodes.add(MemoryNode(
      id: id,
      kind: NodeKind.fact,
      label: label,
      text: text.isEmpty ? label : text,
      areas: areas,
      timeScope: scope,
      validFrom: d(-ageDays),
      validTo: validTo,
      dueAt: dueAt,
      importance: imp,
      createdAt: d(-ageDays),
      sensitive: sensitive,
      reviewAfter: scope == TimeScope.stage ? d(21 - ageDays) : null,
    ));
    if (about != null) {
      edges.add(MemoryEdge(source: id, target: 'entity:$about', kind: 'about', weight: 0.9));
    }
  }

  void related(String a, String b, [double w = 0.6]) =>
      edges.add(MemoryEdge(source: 'entity:$a', target: 'entity:$b', weight: w));

  // ── Entidades ────────────────────────────────────────────────────────────
  entity('uni', 'Universidad', ['study'], 'Estudias ingeniería; vas en 5.º semestre.', imp: 0.9);
  entity('digitales', 'Sistemas digitales', ['study'], 'Materia con prácticas en VHDL.');
  entity('senales', 'Señales y sistemas', ['study'], 'La materia que más te cuesta este semestre.');
  entity('cpu', 'CPU de práctica', ['projects', 'study'], 'Un procesador pequeño hecho en VHDL para la escuela.', imp: 0.7);
  entity('app', 'App Laika', ['projects', 'skills'], 'Esta misma app: mascota de escritorio y Android.', imp: 0.8);
  entity('flutter', 'Flutter', ['skills'], 'Framework para apps de escritorio y móvil.');
  entity('chino', 'Chino mandarín', ['languages'], 'Lo practicas con Laika casi a diario.', imp: 0.8);
  entity('ruso', 'Ruso', ['languages'], 'Nivel principiante.');
  entity('ingles', 'Inglés', ['languages', 'work'], 'Nivel avanzado; lo usas para leer documentación.');
  entity('ahorro', 'Cuenta de ahorro', ['finance'], 'Ahorras para una laptop nueva.');
  entity('beca', 'Beca', ['finance', 'study', 'legal'], 'Hay que renovarla cada semestre.', imp: 0.7);
  entity('pasaporte', 'Pasaporte', ['legal'], 'Vence el próximo año.');
  entity('practicas', 'Prácticas profesionales', ['work', 'study'], 'Buscas prácticas para el próximo verano.', imp: 0.8);
  entity('gym', 'Gimnasio', ['health'], 'Vas 3 veces por semana cuando puedes.');
  entity('mama', 'Mamá', ['people'], 'Hablas con ella los domingos.');
  entity('diego', 'Diego', ['people', 'projects'], 'Amigo del equipo del hackathon.');
  entity('guitarra', 'Guitarra', ['skills', 'home'], 'Estás aprendiendo canciones sencillas.');

  related('digitales', 'cpu', 0.9);
  related('uni', 'digitales');
  related('uni', 'senales');
  related('app', 'flutter', 0.9);
  related('app', 'chino');
  related('beca', 'uni', 0.8);
  related('practicas', 'ingles');
  related('practicas', 'uni');
  related('diego', 'app', 0.4);
  related('ahorro', 'app', 0.3);

  // ── Datos (facts) ────────────────────────────────────────────────────────
  fact('Estudias ingeniería en computación', ['study'], TimeScope.permanent, about: 'uni', ageDays: 60, imp: 0.9);
  fact('Hablas español como lengua materna', ['languages'], TimeScope.permanent, ageDays: 60, imp: 0.8);
  fact('Te gusta programar de noche', ['home', 'skills'], TimeScope.permanent, ageDays: 40);
  fact('Te encanta el café de olla', ['home'], TimeScope.permanent, ageDays: 8, imp: 0.3);
  fact('Examen de Señales y sistemas', ['study'], TimeScope.dated, about: 'senales', dueAt: d(6, 8), validTo: d(6, 23), text: 'Tienes examen parcial; te preocupa la transformada de Fourier.', imp: 0.8);
  fact('Entregar la práctica 4 (ALU)', ['study', 'projects'], TimeScope.dated, about: 'cpu', dueAt: d(2, 23), validTo: d(3), imp: 0.7);
  fact('Quieres hacer prácticas en una empresa de hardware', ['work'], TimeScope.stage, about: 'practicas', text: 'Por ahora buscas prácticas; Laika te preguntará en unas semanas si sigue siendo así.', imp: 0.8);
  fact('Estás actualizando tu CV en inglés', ['work', 'languages'], TimeScope.stage, about: 'ingles', ageDays: 3);
  fact('Ahorras 500 al mes para una laptop', ['finance'], TimeScope.stage, about: 'ahorro', ageDays: 20);
  fact('La beca se renueva en enero', ['finance', 'legal'], TimeScope.dated, about: 'beca', dueAt: d(60), imp: 0.7);
  fact('El pasaporte vence el próximo año', ['legal'], TimeScope.dated, about: 'pasaporte', dueAt: d(200));
  fact('Aprendiste a pedir comida en chino', ['languages'], TimeScope.permanent, about: 'chino', ageDays: 7, text: 'Practicaste: 我要一碗面 (quiero un tazón de fideos).');
  fact('Confundes el 3.er y 4.º tono', ['languages', 'skills'], TimeScope.stage, about: 'chino', ageDays: 5);
  fact('Te cuesta pronunciar la letra ы', ['languages'], TimeScope.stage, about: 'ruso', ageDays: 9);
  fact('Haces la app de Laika en Flutter', ['projects', 'skills'], TimeScope.stage, about: 'app', ageDays: 0, imp: 0.8);
  fact('Diego quiere ir al próximo hackathon', ['people', 'projects'], TimeScope.stage, about: 'diego', ageDays: 2);
  fact('Hablas con tu mamá los domingos', ['people'], TimeScope.permanent, about: 'mama', ageDays: 30);
  fact('Vas al gimnasio lunes, miércoles y viernes', ['health'], TimeScope.stage, about: 'gym', ageDays: 14);
  fact('Dormiste mal toda la semana de exámenes', ['health'], TimeScope.archived, ageDays: 35, validTo: d(-28), sensitive: true);
  fact('Te preocupa pagar la colegiatura', ['finance'], TimeScope.stage, ageDays: 6, sensitive: true);
  fact('Aprendiste tu primera canción en guitarra', ['skills'], TimeScope.permanent, about: 'guitarra', ageDays: 12);
  fact('Querías estudiar alemán', ['languages'], TimeScope.archived, ageDays: 120, validTo: d(-90), text: 'Lo dejaste para enfocarte en chino. Se guarda como historia.');
  fact('Buscabas departamento cerca de la uni', ['home', 'finance'], TimeScope.archived, ageDays: 150, validTo: d(-100));
  fact('Terminaste la práctica 3 (sumador)', ['study'], TimeScope.archived, about: 'cpu', ageDays: 15, validTo: d(-12));

  // ── Conversaciones (episodes) ────────────────────────────────────────────
  void episode(String id, String label, List<String> areas, int ageDays,
      List<String> factIds, String text) {
    nodes.add(MemoryNode(
      id: 'episode:$id',
      kind: NodeKind.episode,
      label: label,
      text: text,
      areas: areas,
      importance: 0.5,
      createdAt: d(-ageDays),
    ));
    for (final f in factIds) {
      edges.add(MemoryEdge(source: 'episode:$id', target: f, kind: 'in_episode', weight: 0.7));
    }
  }

  episode('1', 'Nervios por el examen', ['study', 'health'], 1,
      ['fact:5', 'fact:6'], 'Platicaron de cómo repartir el estudio antes del parcial.');
  episode('2', 'Planes para el verano', ['work'], 3, ['fact:7', 'fact:8'],
      'Hablaron de qué empresas buscar y de mejorar el CV.');
  episode('3', 'Práctica: pedir comida en chino', ['languages'], 7,
      ['fact:12', 'fact:13'], 'Simularon un restaurante: tú pedías y Laika era la mesera.');
  episode('4', 'Domingo tranquilo', ['people', 'home'], 4, ['fact:17', 'fact:21'],
      'Hablaste con tu mamá y practicaste guitarra.');
  episode('5', 'Idea: la app de Laika', ['projects'], 0, ['fact:15'],
      'Decidiste que Laika tenga una mascota de escritorio y un cerebro visible.');

  // Los recordatorios también son nodos del cerebro (ver buildSampleReminders).
  for (final r in buildSampleReminders(now)) {
    nodes.add(reminderNode(r));
  }
  edges.add(const MemoryEdge(source: 'reminder:2', target: 'entity:pasaporte', kind: 'about'));
  edges.add(const MemoryEdge(source: 'reminder:3', target: 'entity:cpu', kind: 'about'));
  edges.add(const MemoryEdge(source: 'reminder:4', target: 'entity:beca', kind: 'about'));

  // Como en el servidor real: un nodo por área y aristas in_area hacia él.
  for (final a in kAreas) {
    nodes.add(MemoryNode(
      id: 'area:${a.id}',
      kind: NodeKind.area,
      label: a.name,
      text: a.name,
      areas: [a.id],
      createdAt: d(-90),
    ));
  }
  for (final n in List.of(nodes)) {
    if (n.kind == NodeKind.area) continue;
    for (final a in n.areas) {
      edges.add(MemoryEdge(source: n.id, target: 'area:$a', kind: 'in_area', weight: 0.3));
    }
  }

  return MemoryGraph(generatedAt: now, areas: kAreas, nodes: nodes, edges: edges);
}

List<Reminder> buildSampleReminders(DateTime now) {
  DateTime d(int days, [int hour = 10]) =>
      DateTime(now.year, now.month, now.day + days, hour);
  return [
    Reminder(id: 1, text: 'Pagar el internet', dueAt: d(1, 10), areas: ['finance', 'home']),
    Reminder(id: 2, text: 'Sacar cita para renovar el pasaporte', dueAt: d(5, 9), areas: ['legal']),
    Reminder(id: 3, text: 'Subir el reporte de la práctica 4', dueAt: d(2, 20), areas: ['study', 'projects']),
    Reminder(id: 4, text: 'Llevar comprobante de inscripción para la beca', dueAt: d(-1, 12), status: ReminderStatus.done, areas: ['finance', 'legal']),
  ];
}

MemoryNode reminderNode(Reminder r) => MemoryNode(
      id: 'reminder:${r.id}',
      kind: NodeKind.reminder,
      label: r.text,
      text: 'Laika te lo recordará: ${r.text}.',
      areas: r.areas,
      timeScope: r.status == ReminderStatus.done ? TimeScope.archived : TimeScope.reminder,
      dueAt: r.dueAt,
      importance: 0.7,
      createdAt: r.dueAt.subtract(const Duration(days: 2)),
    );
