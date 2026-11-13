# Progreso — retomar aquí

**Última actualización:** 2026-11-13 · **Estado:** diseño final + modo escritorio `--pet` + cliente real. Falta que Esteban lo pruebe.

## Hecho
- Proyecto Flutter (Linux + Android). Build de Linux release OK.
- Núcleo compartido (`lib/core/`): modelos según el contrato real del servidor
  (W8.1/W8.2), backend simulado, mascota (15 s → dormir; hover → `/health`),
  burbujas al lado contrario del borde, cerebro con áreas/tiempo, agenda,
  datos sensibles ocultos.
- 5 diseños: Cosmos, Papel, Pixel, Brutal, Cristal (`lib/variants/`).
- 8 pruebas (`flutter test`) y capturas (`docs/screenshots/`).
- Docs: README paso a paso, architecture, API, VARIANTES, CLAUDE.md, licencia MIT.

## Esperando a Esteban
- Elegir diseño o mezcla (plantilla en `docs/VARIANTES.md`).
- Confirmar la lista de áreas de vida.
- Para el escritorio real en Linux: `sudo pacman -S gtk-layer-shell`.
- Para Android: `flutter doctor --android-licenses`.

## Siguiente (después de elegir)
1. `HttpLaika` (cliente real: HTTPS + WebSocket, contrato en `docs/API.md`).
2. Ventana transparente sobre el escritorio (gtk-layer-shell).
3. Android: burbuja flotante + notificaciones.

## Servidor (sesión de cc-server, rama `w8-reminders-api-areas`)
- W8.1 recordatorios reales ✅ · W8.2 API de lectura ✅
- W8.3 áreas de vida + tiempo ✅ (Esteban aprobó el backfill). La app ya entiende nodos de área, `in_area` y `review_after`.
- W8.4 repo público `EstebanSantiag0/laika` ✅ (2026-11-01, commit a3b7030, MIT; publicado por la sesión de cc-server)

## 2026-11-01 (tarde) — Esteban eligió
- Cerebro = esfera de Cosmos · notas y recordatorios = Brutal · paleta = Cristal · mensajes = Pixel.
- Mascota: ninguna de las 5; pidió algo parecido a un personaje con dueño (no se puede copiar en un repo público).
  Se hicieron 3 mascotas originales gótico-kawaii (ya quitadas).
- Dormir en 2 fases: 15 s sentada, 30 s acostada. 1 clic = escribir, 2 clics = abrir la app.
- Hecho: diseño final `lib/variants/laika.dart` (primero en la galería) + `core/sphere_view.dart` compartido.
- Siguiente: modo escritorio real en Linux (gtk-layer-shell, `--pet`) y app en ventana (`--app`);
  luego `HttpLaika` (protocolo /ws confirmado por cc-server, ver docs/API.md).

## 2026-11-01 (noche) — Laika en el escritorio real
- Hecho: `linux/runner` con gtk-layer-shell (`--pet`: capa transparente, solo Laika y su chat reciben clics,
  canal `laika/window`). `lib/desktop/` (PetOverlay, WindowBridge). `--app` abre la app en ventana normal.
- Hecho: `HttpLaika` (HTTPS + WS; el WS se abre solo al despertar, sin reconexión automática);
  servidor desde `~/.config/laika/config.json`; aviso de "estoy escribiendo".
- Hecho: `tool/install_linux.sh` (programa + lanzadores; `--autostart` opcional; `--uninstall`).
- Probado: compila, 9 pruebas OK, `--pet` arranca 10 s en Wayland sin errores. **Falta probar a mano** clics,
  arrastre y doble clic (lo hace Esteban), y el servidor real.

## Esperando a Esteban (noche)
- Probar `--pet` (si algo bloquea los clics: `pkill laika_app`).
- Crear `~/.config/laika/config.json` con la URL del servidor.
- ¿Instalar con autostart?
- Elegir mascota: cabeza / chibi / cachorro.
- W8.4: aprobar la publicación de `EstebanSantiag0/laika` (el servidor) y que se cree el repo vacío.

## 2026-11-01 (noche, 2) — nueva mascota
- Esteban rechazó las 3 mascotas y dejó referencias de emociones (personaje con dueño; no se copia en el repo).
  Se hizo un diseño original con esas emociones (`lib/pets/laika_pet.dart`, ya quitado).
- 15 `Mood` en `core/pet.dart` + reacciones automáticas (`Mood.forText`, recordatorios, memoria).
- Pestaña "Mascota" → "Emociones" (hoja con todas las caras). Captura: `docs/screenshots/laika-4-emociones.png`.
- Se quitó `lib/pets/pets.dart` (las 3 anteriores; siguen en el historial de git).
- Esperando: que Esteban diga si le gusta o qué cambiar (orejas, colores, caras).

## Siguiente
1. Recordar mascota elegida y posición (`~/.config/laika/state.json`).
2. Al reconectar, pedir `/api/history` para no perder mensajes.
3. Android: burbuja flotante + notificaciones.

## 2026-11-01 (noche, 3) — círculo + skins + ajustes
- Esteban: "aún se ve horrible". Nueva cara por defecto: **círculo blanco estilo Brutal** con las 15 emociones
  (`lib/pets/circle_face.dart`). Se quitó `laika_pet.dart`.
- **Skins de imágenes** (`lib/pets/skins.dart`, formato en `docs/SKINS.md`): una imagen por emoción en
  `~/.config/laika/skins/<nombre>/` o `./skins/<nombre>/` (carpeta en `.gitignore`: imágenes personales, no se suben).
- **Ajustes** (`core/config.dart` + pestaña Ajustes): skin, tamaño de Laika y servidor → `~/.config/laika/config.json`.
  La mascota `--pet` vigila el archivo (inotify) y cambia al instante.
- `tool/make_skin.py`: arma una skin desde imágenes propias (recorta y quita el fondo liso).
- Esteban va a **dibujar su propio set** de imágenes (la mezcla de fuentes no combinaba). Mientras, la skin es el círculo.

## 2026-11-01 (cierre)
- El servidor ya es público: https://github.com/EstebanSantiag0/laika (MIT). Revisado desde aquí: sin hostname del
  tailnet, correos, bases de datos ni tokens. Nuevo en el servidor: `user.name`/`user.pronouns`/`user.gender` en
  config.yaml y `scripts/setup.py`. El contrato de la API y del WebSocket no cambió.

## 2026-11-02 — burbujas por tiempo, Laika come, te recuerda cosas
- Esteban: las burbujas ya **no** se desvanecen según qué tan arriba están, sino por **tiempo**: 3 s por palabra;
  en chino 2 s por carácter + 3 s por palabra (pinyin o inglés). `readingTime` en `core/pet.dart`; la opacidad la
  pone `PetStage` para todas las variantes. Tope de seguridad: 8 burbujas.
- Esteban: se duerme **15 s después de que se desvanece la última burbuja**.
- Nueva emoción **`eating`** (cara-círculo: ojos felices, mastica, una hojita vuela a su boca). Sale con eventos
  `item` nuevos y avisos `📚` de la biblioteca. Skins: archivo `eating` (si falta, `happy`).
- **Resurfacing** con cara `impressed`: al despertar, tras el saludo, UNA petición a `/api/resurface`; dice
  "💡 Hace N días guardaste: «…»" (máx. 1 al día). Simulador: botón "Darle un PDF" y links en el chat.
- Puntos de escribir del diseño Laika: los cuadritos de Brutal, en **negro** (sombra lila).
- Modelos nuevos: `Item`, `ItemEvent`, `LibraryEvent`; `LaikaApi.resurface()`. Dependencia nueva: `clock`.
- 15 pruebas OK, capturas regeneradas.

### Siguiente
- Esteban: probar `--pet` con estos cambios y decir si le gustan la cara de comer y los puntos negros.
- Pantallas del segundo cerebro (guardados, búsqueda con páginas, gustos, editar el grafo) contra el simulador,
  cuando Esteban diga; luego cambiar a la API real cuando cc-server avise que SB7/SB7b están en vivo.

## 2026-11-02 (tarde) — segundo cerebro + prueba en vivo SB8
- Pantallas **Guardados** (capturar texto/link, subir archivo, buscar con páginas, filtros, detalle con páginas del PDF)
  y **Gustos**; en **Cerebro**: editar, conectar, borrar a la papelera (con Deshacer) y recuperar.
- Cliente real y simulado con todo el contrato (`docs/API.md`). 20 pruebas OK, `flutter analyze` limpio.
- **SB8 (prueba en vivo con el servidor):** `tool/live_test.dart`, 7/7 OK (lecturas, guardar/duplicado/409/422,
  PDF leído y buscado con página, imagen, volver de la papelera, editar el grafo, eventos por WS).
  Solo usa datos "PRUEBA SB8" y al final los manda a la papelera. La URL va en `LAIKA_SERVER` (nunca en el repo).
  Fallos encontrados y arreglados: en la app, `base_updated_at` se manda tal cual; en el servidor (55b3e4b), volver
  a subir algo que estaba en la papelera ahora lo recupera (`restored: true`) y `base_updated_at` se compara como instante.

### Siguiente
- Esteban: dar OK para purgar los items "PRUEBA SB8" (ids 2–20) y sus avisos 📚 del chat (lo hace cc-server).
- Subido a GitHub (a6cbd46) después de que pasaron todas las pruebas y el diff salió sin secretos.

## 2026-11-02 (noche) — Esteban probó `--pet`
- Los clics no le llegaban: la ventana arranca en 1280×800 y luego cubre la pantalla, y la zona de clics se quedaba
  en el lugar viejo. Ahora se recalcula en cada layout (`PetStage`). `LAIKA_DEBUG=1` registra zonas y clics en stderr.
- Las pruebas guardaban el servidor de ejemplo en el `config.json` real; ahora usan una carpeta temporal
  (`test/flutter_test_config.dart`).
- Esteban: se dormía mientras le escribía. Ahora no se duerme mientras hay texto sin mandar; si borras todo, los 15 s
  cuentan desde ahí.
- Esteban: "todo lo demás está bien" (despertar, chat, doble clic, arrastrar).

## 2026-11-02 (noche, 2) — la caja de la mascota: (+) ____ (🎤/✈)
- Esteban: desde la mascota no podía cambiar el idioma, mandar archivos/capturas ni grabar voz.
- Caja nueva (`PetSkin.composer`, estilo Laika en `variants/laika.dart`): **(+)** abre *Archivo* / *Captura de
  pantalla*; a la derecha **🎤**, que se vuelve el **avioncito** al escribir o grabar (como WhatsApp).
- Encima, chip de idioma **RU ▾** → English / Русский / 中文 (`PUT /api/settings`).
- Captura: Esteban eligió **región** (Spectacle `-r`); Laika se esconde mientras eliges (sin zona de clics).
- Archivos y capturas: van a la biblioteca y **Laika los comenta** (`comment=true`, servidor d61edda).
- Voz: `pw-record` → Opus con `ffmpeg` → `POST /api/voice`; ✕ cancela; no se duerme mientras grabas.
- `lib/core/media.dart` (Linux); en las pruebas, uno falso. 25 pruebas OK, capturas regeneradas.
- Servidor: purgados los datos "PRUEBA SB8" (items 2–20 y 16 avisos), con el OK de Esteban.

### Siguiente
- Esteban: probar en `--pet` el idioma, una nota de voz, un archivo y una captura con el servidor real.

## 2026-11-04 — Laika se queda en el escritorio
- Esteban: "keep laika in my desktop, even after a reboot".
- `tool/install_linux.sh --autostart` con el build de 3424eba: programa en `~/.local/share/laika-app/`,
  lanzadores en `~/.local/share/applications/`, y `~/.config/autostart/laika-pet.desktop` (`--pet` al iniciar sesión).
- Después de cambiar el código hay que reinstalar: `flutter build linux --release --no-tree-shake-icons && tool/install_linux.sh --autostart`.
- Quitar el autostart: `rm ~/.config/autostart/laika-pet.desktop` (o `tool/install_linux.sh --uninstall` para todo).

## 2026-11-09 — burbujas en fila, 2 s por palabra
- Esteban: **2 s por palabra** (antes 3; en chino 2 s por carácter + 2 s por palabra en pinyin o inglés; mínimo 2 s)
  y el tiempo de cada burbuja **empieza a contar cuando se desvaneció la anterior** (se leen en orden).
  `readingTime` y `_addBubble` en `core/pet.dart`; `Bubble.at` ahora es cuándo empieza a contar. 26 pruebas OK.
- Falta reinstalar para verlo en la mascota:
  `flutter build linux --release --no-tree-shake-icons && tool/install_linux.sh --autostart`.
- **Crash de `--app` (sin resolver):** 3 volcados (4, 6 y 9 de nov.), siempre la ventana normal, nunca la mascota.
  SIGSEGV en el hilo de dibujo de Flutter (Impeller, OpenGL ES) dentro de Mesa `libgallium` 26.2.5 (radeonsi,
  Radeon 740M). No truena al abrir (25 s abierta sin tocarla, bien); el del 9 tronó a menos de un minuto de abrirla.
  `FLUTTER_ENGINE_SWITCH_1=enable-impeller=false` no tiene efecto en el build release.

### Siguiente
- Crash de `--app`: Esteban estaba en la **pantalla del gráfico** (mapa de recuerdos), sin hacer nada; no ha vuelto a
  pasar y pidió dejarlo así. Si regresa: empezar por ahí (`coredumpctl list laika_app`).

## 2026-11-13 — después de suspender, la mascota se tragaba los clics
- Esteban: al volver de suspender, no podía hacer clic en nada hasta mover un poco a Laika.
- Causa (reproducida en un KWin anidado con 2 pantallas virtuales, quitando y poniendo una):
  al suspender desaparecen las pantallas; al volver, gtk-layer-shell esconde y vuelve a mostrar la ventana,
  GTK 3 crea una `wl_surface` nueva y **no** le manda la zona de clics → la capa que cubre la pantalla recibía
  todos los clics. Al mover a Laika, Dart mandaba una zona nueva y se arreglaba.
- Arreglo (`linux/runner/my_application.cc`): la zona se guarda y se reaplica en cada `map`; además se da a GTK a
  nivel widget para que GTK no la borre al crear la ventana. Probado: las 3 superficies (inicio, quitar, poner)
  reciben la zona de Laika. El journal registra `zona de clics reaplicada` cada vez que pasa.
- 26 pruebas OK, `flutter analyze` limpio, build release listo.
- **Falta (Esteban):** instalar y reiniciar la mascota:
  `tool/install_linux.sh --autostart && systemctl --user restart 'app-laika\x2dpet@autostart.service'`
  y luego confirmar tras suspender: `journalctl --user -b | grep reaplicada`.

## 2026-11-13 — flashcards editables desde la app
- Esteban: quiere **editar las flashcards desde la app**. El servidor (cc-server) está planeando las flashcards;
  cuando termine el plan, esta sesión y la de cc-server acuerdan juntas el contrato (`docs/API.md`) y los cambios.
- cc-server mandó el borrador (su `docs/PLAN-phase6.md`, D24): una tarjeta = un hanzi en una lectura, FSRS,
  `note` solo de Esteban, campos que él edita quedan **bloqueados** (Laika solo sugiere: línea 🃏 con Aplicar / No),
  `/api/cards` (lista, detalle con historial, crear, editar, papelera, `due`, `review`, deshacer, sugerencias, audio),
  evento WS `card` y `meta.card` en el chat.
- Respuesta de la app: aceptado, con cambios: `limit` hasta 500 (todo de una vez), `preview` de FSRS + `now` en
  `/due`, cada escritura devuelve `edit_id`, reseñas deshacibles e idempotentes (`client_id`), `unlock`, 409 al
  cambiar a una lectura que ya existe, `counts` por filtro y tope diario de nuevas en el servidor, tarjetas en
  `/api/trash`, `gloss_es`/`gloss_en`, audio 202 si tarda. Para la mascota solo opciones sin peticiones nuevas
  (`cards_due` en `/health`, `counts` en el evento); si la mascota muestra algo lo decide Esteban.
- **Acordado** (cc-server aceptó los 7 cambios; queda en su `docs/PLAN-phase6.md`, "API agreed with the laika-app
  session"): `limit` ≤ 500 (50 por defecto); `/due` con `preview`, `now` y `counts`, e incluye nuevas hasta
  `cards.new_per_day` (10 por defecto); `counts` = total, due, new, learning, suspended, trash, new_left_today;
  cada escritura → `{card, edit_id}`; reseñas = Edit `review` (deshacible), `client_id` obligatorio e idempotente;
  `unlock`; cambiar la lectura conserva el calendario; `gloss_es`/`gloss_en`; audio ogg/opus o 202 `{retry_after}`;
  `/api/trash` trae `cards`; el evento `card` trae `counts`.
- **Esteban (vía cc-server): las tarjetas van solo en la app, no en la mascota.** Sin `cards_due` en `/health`; la
  mascota no muestra nada de tarjetas: ignora los eventos `card` y **no** saca como burbuja los mensajes con
  `meta.card` (las líneas 🃏 de Deshacer / Aplicar / No salen solo en el chat de la app).
- **Esperando:** el "go" de Esteban. Luego: modelos + backend simulado → pestaña Tarjetas → HttpLaika → prueba en vivo
  cuando cc-server avise que está en su `docs/API.md` y en vivo.

## 2026-11-13 (tarde) — pestaña Tarjetas en la app
- Esteban: "go ahead" → se instaló el arreglo de la mascota (12:15, journal limpio) y se empezó la app de tarjetas.
- cc-server aceptó también el **feed de cambios** (`GET /api/cards/edits`, `Edit.status`/`undoable`,
  `counts.suggestions`, `Card.suggestions`) y agregó `Card.flags` (`check_meaning`). Esteban le dio el go al servidor:
  lo está construyendo. Contrato completo en `docs/API.md` → "Tarjetas".
- Hecho (contra el servidor simulado):
  - `core/cards.dart` (modelos), `core/mock_cards.dart` (bloqueos, sugerencias, deshacer, repasos idempotentes,
    tope diario de nuevas, agenda tipo FSRS), `core/deck.dart` (`DeckController`, `ReviewSession`),
    `HttpLaika` con todos los endpoints y el evento `card`, `Media.play` (pw-play / ffplay).
  - Pestaña **Tarjetas** (`variants/laika_cards.dart`): Repasar con conteos, caja "Laika" (Aplicar / No, Deshacer),
    agregar con solo el carácter, búsqueda (pinyin sin tonos, español, inglés), filtros, tarjetas con el color del tono;
    editor con 🔒 y "Devolver a Laika", historial con Deshacer; repaso con 4 botones y vista previa (espacio, 1–4, U).
  - La mascota ignora `CardEvent` (prueba incluida). El texto normal ahora cae a Noto Sans CJK si hay chino.
- 42 pruebas OK (12 de contrato/simulador + 4 de la pestaña), `flutter analyze` limpio.
  Capturas nuevas: `laika-9-tarjetas.png`, `laika-10-tarjeta.png`, `laika-11-repaso.png`.

### Siguiente
- Cuando cc-server avise que está en vivo: prueba conjunta con tarjetas "PRUEBA" (como SB8) que terminen en la papelera.
- Esteban: probar la pestaña (`laika_app --app` → Tarjetas). Con el servidor real configurado dirá "El servidor
  todavía no tiene tarjetas" hasta que cc-server las publique; para verla ya: `XDG_CONFIG_HOME=$(mktemp -d) laika_app --app`
  (sin servidor = simulado).
