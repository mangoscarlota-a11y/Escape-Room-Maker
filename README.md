# Escape Room Maker (Godot 4 + GDScript)

Juego 3D donde juegas un tutorial y luego **construyes tu propio escape room**.

## Cómo abrirlo
1. Instala **Godot 4.3 o superior** (versión estándar, no .NET).
2. En el Project Manager pulsa **Importar** y elige `project.godot`.
3. Abre el proyecto y pulsa **F5**.

## Menú principal
- **Tutorial**: sala de práctica ya hecha (nota → llave → cofre → puerta).
- **Crear una sala nueva**: abre el editor 3D.
- **Mis salas guardadas**: juega (o edita) las salas que guardaste.

## Controles al jugar
| Tecla | Acción |
|---|---|
| W A S D | Moverse |
| Shift | Correr |
| Espacio | Saltar |
| Ratón | Mirar |
| E | Interactuar |
| M | Volver al menú (o al editor si estás probando tu sala) |
| Esc | Soltar el ratón |

## Modo creador
| Acción | Cómo |
|---|---|
| Volar con la cámara | Mantén **clic derecho** + W A S D (Q baja, E sube, Shift más rápido) |
| Acercar / alejar | Rueda del ratón |
| Colocar un objeto | Elígelo en el panel izquierdo y haz **clic izquierdo** en la sala |
| Objetos sobre muebles | Lámpara, llave y nota se apoyan en mesas, cajas y el librero |
| Seleccionar / mover | Herramienta «Seleccionar», clic en el objeto y arrastra |
| Girar | **R** |
| Borrar | **Supr** / **Retroceso** / **X** |
| Soltar herramienta | **Esc** |

### Puzzles
Selecciona un objeto para editar sus propiedades en el panel derecho:
- **Llave**: su color (Roja, Azul, Verde, Dorada).
- **Cofre**: con qué llave se abre y qué contiene (otra llave o nada).
- **Puerta de salida**: con qué llave se abre. Es fija en la pared norte.
- **Nota**: el texto de la pista.

El editor te avisa si la sala no se puede resolver (por ejemplo, una puerta que pide una llave que no existe).
Con **Probar sala** juegas tu sala al instante y con **M** vuelves al editor.

## Dónde se guardan las salas
Como archivos `.json` en `user://salas/`. En Godot: **Proyecto → Abrir carpeta de datos del usuario**.

## Archivos
- `main.gd`: menú principal y cambio entre modos.
- `player.gd`: jugador en primera persona, inventario y HUD.
- `catalog.gd`: lista de objetos, su apariencia y su lógica de juego.
- `creator.gd`: editor 3D.
- `room_data.gd`: guardar, cargar y validar salas.
- `shell.gd`: paredes y suelo de las salas creadas (8 x 8 m).
- `room_builder.gd`: construye la sala del tutorial.
- `interactable.gd`: base de los objetos que se usan con E.
- `online.gd` / `online_config.gd`: conexión con el servidor de salas (Supabase).
- `supabase_setup.sql`: crea la tabla y las reglas del servidor.
- `export_presets.cfg` y `.github/workflows/pages.yml`: exportar a web y publicar en GitHub Pages.

## Publicar el juego y compartir salas

GitHub Pages solo aloja el juego (archivos estáticos). Las salas que suben los jugadores se guardan en **Supabase** (gratis, sin escribir código de servidor).

### 1. Crear el servidor de salas
1. Crea un proyecto en supabase.com.
2. En **SQL Editor** pega todo `supabase_setup.sql` y pulsa **Run**.
3. En **Project Settings → API** copia la **Project URL** y la clave **anon / publishable**.
4. Pégalas en `online_config.gd`. Esa clave es pública por diseño: lo que protege los datos son las reglas del SQL (solo se puede leer y publicar, no editar ni borrar).

Con eso ya funcionan **Publicar** (en el editor) y **Salas de la comunidad** (en el menú), incluso desde el editor de Godot con F5.

### 2. Publicar el juego en GitHub Pages
1. Crea un repositorio en GitHub y sube todos los archivos (incluidos `.github` y `.gitignore`).
2. En **Settings → Pages**, elige **Source: GitHub Actions**.
3. Cada vez que subas cambios a `main`, GitHub exporta el juego a web y lo publica en `https://TU-USUARIO.github.io/TU-REPO/`.

### Notas
- Las salas guardadas «en tu equipo» se guardan en el navegador de cada persona.
- No hay cuentas de usuario: cualquiera puede publicar. Para borrar una sala, usa el **Table Editor** de Supabase.
- Si el despliegue falla por `export_presets.cfg`, en Godot ve a **Proyecto → Exportar → Añadir… → Web**, desactiva «Soporte de hilos», y sube el `export_presets.cfg` que genere.
- Los gráficos usan el renderizador «Compatibilidad» en web, así que algunos efectos (como SSAO) no se ven allí.

## Ideas para seguir
- Candado de código (teclado numérico) y palancas.
- Más muebles y decoración, y distintos tamaños de sala.
- Temporizador y puntuación.
- Cuentas de usuario, votos y moderación de salas.
