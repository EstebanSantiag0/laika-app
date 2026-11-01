# Progreso — retomar aquí

**Última actualización:** 2026-11-01 (noche) · **Estado:** diseño final + modo escritorio `--pet` + cliente real. Falta que Esteban lo pruebe.

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
- W8.4 repo público `EstebanSantiag0/laika` (manifiesto + escaneo antes de publicar) ⏳

## 2026-11-01 (tarde) — Esteban eligió
- Cerebro = esfera de Cosmos · notas y recordatorios = Brutal · paleta = Cristal · mensajes = Pixel.
- Mascota: ninguna de las 5; pidió algo tipo Kuromi (no se puede copiar: personaje de Sanrio). Se hicieron
  3 mascotas originales gótico-kawaii (`lib/pets/pets.dart`): cabeza, chibi, cachorro.
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
- Esteban rechazó las 3 mascotas y dejó 13 referencias de Kuromi (emociones) en `~/Pictures/Screenshots/kuromi*.png`.
  Kuromi es de Sanrio y el repo es público → se hizo **un diseño original** con esas emociones:
  `lib/pets/laika_pet.dart` (capucha con orejas de murciélago, luna, nariz de perrito, gorguera lila, cola-corazón).
- 15 `Mood` en `core/pet.dart` + reacciones automáticas (`Mood.forText`, recordatorios, memoria).
- Pestaña "Mascota" → "Emociones" (hoja con todas las caras). Captura: `docs/screenshots/laika-4-emociones.png`.
- Se quitó `lib/pets/pets.dart` (las 3 anteriores; siguen en el historial de git).
- Esperando: que Esteban diga si le gusta o qué cambiar (orejas, colores, caras).

## Siguiente
1. Recordar mascota elegida y posición (`~/.config/laika/state.json`).
2. Al reconectar, pedir `/api/history` para no perder mensajes.
3. Android: burbuja flotante + notificaciones.
