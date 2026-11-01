# Progreso — retomar aquí

**Fecha:** 2026-11-01 · **Estado:** construyendo 5 prototipos de interfaz con backend simulado.

## Hecho
- Proyecto Flutter (Linux + Android) creado.
- Núcleo compartido en `lib/core/`: modelos (contrato de la API), backend simulado,
  lógica de la mascota (se duerme a los 15 s, despierta solo si `/health` responde),
  escritorio con burbujas al lado de Laika, cerebro y recordatorios.
- Variante 1: Cosmos (`lib/variants/cosmos.dart`).

## Siguiente
- Variantes 2–5: Papel, Pixel, Brutal, Cristal.
- Pruebas de humo, docs (README paso a paso, architecture, API), repo público en GitHub.

## Servidor (lo hace la sesión de cc-server)
Pasos 1–4 enviados el 2026-11-01: recordatorios reales, `/api/graph` + `/api/reminders`,
memoria por áreas y tiempo, repo público `EstebanSantiag0/laika`.
