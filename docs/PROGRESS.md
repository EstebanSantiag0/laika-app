# Progreso — retomar aquí

**Última actualización:** 2026-11-01 · **Estado:** 5 prototipos listos; esperando que Esteban elija diseño.

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
