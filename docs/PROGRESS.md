# Progreso — retomar aquí

**Última actualización:** 2026-11-02 · **Estado:** diseño final + modo escritorio `--pet` + cliente real. Falta que Esteban lo pruebe.

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
