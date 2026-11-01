# Skins: cambiar cómo se ve Laika

Por defecto Laika es un **círculo blanco estilo Brutal** (borde grueso, sombra
dura) que cambia de cara con sus 15 emociones. También puedes darle tu propia
apariencia con imágenes.

## Formato

Una carpeta por skin, con **una imagen por emoción**:

```
~/.config/laika/skins/<nombre>/      ← instalada (la usa también la mascota --pet)
./skins/<nombre>/                    ← junto al proyecto (está en .gitignore: no se sube)
    neutral.png
    happy.png
    sleepingLying.png
    …
    skin.json                        ← opcional
```

| Archivo | Cuándo se ve |
|---|---|
| `neutral` | despierta, sin nada que hacer |
| `happy` | cuando te contesta |
| `greeting` | al despertar o cuando dice "hola" |
| `laughing` | jaja, lol, 😂 |
| `inLove` | ❤️, te quiero |
| `surprised` | cuando suena un recordatorio |
| `impressed` | cuando aprende algo nuevo, wow |
| `doubting` | 🤔, hmm |
| `ashamed` | cuando algo le sale mal |
| `crying` | 😭, qué triste |
| `scheming` | cuando anota un recordatorio, 😈 |
| `cheeky` | cuando te corrige, 😜 |
| `thinking` | mientras escribe su respuesta |
| `waking` | mientras pregunta a `/health` |
| `sleeping` | dormida (15 s sin hacerle caso) |
| `sleepingLying` | dormida profunda (15 s después) |

- Formatos: `png`, `webp`, `gif` (animado también), `jpg`. Mejor PNG con fondo transparente.
- **No hace falta tenerlas todas.** Si falta una se usa otra parecida
  (`thinking` → `doubting`, `waking` → `sleeping`, `greeting` → `happy`…) y al final `neutral`.
- `skin.json` (opcional): `{"name": "Mi skin", "moods": {"happy": "feliz.png"}}` para
  ponerle nombre o usar archivos con otros nombres.
- Encima de las imágenes la app agrega solo "zzz", los puntitos de "pensando" y la campanita.

## Consejos para dibujar tu propio set

- Lienzo cuadrado de **512×512 px** con fondo **transparente**, exportado a PNG.
- Mismo grosor de línea, misma paleta y mismo tamaño de personaje en todas;
  los pies (o la base) siempre a la **misma altura**, cerca del borde de abajo.
- Haz primero `neutral` y úsala como plantilla (capa de referencia) para las demás.
- Deja libre la esquina **superior derecha**: ahí la app dibuja "zzz", "…" y la campanita.
- Si son pixel art, dibújalas pequeñas y escálalas ×8 o ×16 *sin suavizado* (vecino más cercano).
- Herramientas en Arch: Krita (`krita`), o LibreSprite/Pixelorama para pixel art.
- Si ya están con el nombre correcto y fondo transparente, solo cópialas a la carpeta; no hace falta el script.

## Crear una skin con tus imágenes

`tool/make_skin.py` quita el fondo liso, recorta y deja cada imagen en 512×512 transparente:

```bash
tool/make_skin.py mia \
  neutral=~/Imágenes/quieta.png \
  happy=~/Imágenes/feliz.png \
  sleepingLying=~/Imágenes/dormida.png
# → skins/mia/  (añade --destino ~/.config/laika/skins para instalarla directo)
```

Luego en la app: **Ajustes → Skin → ↻ Buscar skins** y elígela. La mascota del
escritorio cambia al instante.

> Las skins son para tu uso personal. Si usas imágenes de personajes o arte de
> otras personas, no las subas a ningún repositorio público: por eso `skins/`
> está en `.gitignore`.
