# LA ALFOMBRA ROJA — discoteca de lujo de 3 pisos para Roblox (Luau)

Antes MAYA CLUB / AURA CLUB. Se construye **100 % por código**: un `Script` genera el club y un `LocalScript` anima y regula las luces en cada pantalla. No necesita ningún asset de Roblox.

> **Qué se ha probado y qué no.** Todo lo marcado como "comprobado" se verificó con el **simulador** (`tests/run.sh`: los scripts se ejecutan contra un mock de la API de Roblox con el CLI de Luau). **No he abierto Roblox Studio**: no hay render, físicas, red ni FPS reales en esa prueba. Los **FPS, la calidad visual y la colisión con avatares reales están pendientes de que los midas tú** (ver "Medir el rendimiento"). Las cifras de "escrituras por segundo" son un indicador relativo del trabajo de las animaciones, **no** FPS.

## Archivos

| Archivo | Qué es |
|---|---|
| `src/ServerScriptService/LaAlfombraRoja.server.luau` | Script del servidor: construye todo, estado de luces, cabina, operador |
| `src/StarterPlayer/StarterPlayerScripts/LaAlfombraRojaFX.client.luau` | LocalScript: animaciones locales, aplicación del estado de luces, panel en español |
| `LaAlfombraRoja.rbxlx` | Place listo para abrir (ambos scripts colocados, `Lighting.Technology = Future`) |
| `LaAlfombraRoja.rbxmx` | Modelo para *Insert from File…*: el Script con el LocalScript como hijo `ClientEffects` |
| `assets/LaAlfombraRoja_logo.png` / `.svg` | Recurso limpio del logo (ver "Logo") |
| `tools/make_place.py`, `tools/make_logo.py`, `tests/` | Generadores y pruebas |

## Novedades de esta versión

- **LA ALFOMBRA ROJA sustituye al guardarropa:** alfombra roja de 16 de ancho con filete dorado, **14 postes dorados con cordones rojos**, **photocall** negro con marco dorado y el logo repetido (1 grande + 6 pequeños), **2 softboxes** de fotografía (difusor blanco + foco cálido), cámara de video, palmeras en macetas doradas y 2 mesas de champán con cubo, botella y velas. Los pasillos quedan libres: los cordones no colisionan y todo cuerpo de 7 studs recorre la alfombra.
- **Marca:** "MAYA CLUB" pasa a **LA ALFOMBRA ROJA** en fachada, rooftop, frente del DJ, pantalla LED, señales, 7 logos de pared y la interfaz. El logo (corona dorada de piezas, "LA" y "ALFOMBRA" en serif dorada, "ROJA" en rojo, filetes dorados, sobre negro) funciona sin ninguna imagen.
- **Estilo luxury conservado:** poco neón, mobiliario blanco y negro pulido, mármol y latón.
- **Bola de espejos corregida:** cada faceta apoya su cara interior **sobre** el núcleo (radio 3,5; esquinas a ≥ 3,56), ninguna queda metida; reflectancia 0,8 y plata (228/176) en vez de blanco puro, foco de acento y luz interior suaves → sin reflejos quemados.
- **Perfiles Equilibrado y Alta**, animaciones **en el cliente** (nada decorativo se replica desde el servidor) y **cabina de control de luces** (abajo).

## Instalación

**A. Abrir `LaAlfombraRoja.rbxlx`** (recomendado): ya contiene el Script en ServerScriptService y el LocalScript `LaAlfombraRojaFX` en StarterPlayer › StarterPlayerScripts.

**B. Insertar `LaAlfombraRoja.rbxmx`** en tu place: clic derecho en ServerScriptService › *Insert from File…*. Aparece el Script `LaAlfombraRoja` con un hijo `ClientEffects`; al pulsar Play el Script lo copia solo a StarterPlayerScripts. Pon tú `Lighting.Technology = Future` (un script no puede cambiarlo).

**C. A mano:** pega `LaAlfombraRoja.server.luau` en un Script de ServerScriptService y `LaAlfombraRojaFX.client.luau` en un LocalScript llamado **`LaAlfombraRojaFX`** dentro de StarterPlayerScripts. Si pegas solo el Script del servidor funciona con una animación de respaldo (menos fluida, sin cabina de control) y lo avisa en Output.

Pulsa **Play (F5)**, no *Run* (*Run* no ejecuta LocalScripts). Output debe mostrar `[LaAlfombraRoja] listo: … partes, … luces, 3 pisos.` (simulador: Equilibrado 5180 partes / 138 luces; Alta 5360 / 182). Sin líneas rojas. Los LocalScripts requieren `StreamingEnabled` desactivado (valor por defecto de un place nuevo).

## CABINA DE CONTROL DE LUCES

**Dónde:** en el escenario del piso 1, a la **izquierda del DJ** (x ≈ −20), con vista a la pista: consola negra lacada con filete dorado, 8 faders con mandos dorados, 3 pantallas, rótulo "CABINA DE LUCES" y una placa que muestra **OPERADOR: LIBRE / nombre**.

**Cómo usarla:** acércate a la consola, pulsa **E** ("Abrir panel de luces") y se abre el panel en español. Solo hay **un operador a la vez**: otro jugador recibe "La cabina está en uso por …". El control se libera al pulsar **Cerrar** / **Soltar el control**, al alejarte (>45 studs), al salir del juego o tras 180 s sin acciones.

| Sección del panel | Qué hace |
|---|---|
| **Intensidad** | General (0–150 %) y por zona: **Pista, VIP, Rooftop, Alfombra roja** (– / + de 10 %) y botón Activa/Apagada por zona |
| **Presets** | **Elegante cálido** (inicial), **Fiesta**, **Discoteca**, **Apagado de efectos** |
| **Efectos** | Haces de luz, Láseres, Movimiento de focos, Pulso de color, Giro de la bola de espejos, Velocidad de efectos (×0,25–×2) y de la bola (×0–×2) |
| **Colores** | Champán, Hielo, Rosa, Violeta, Rojo, Multicolor |
| **Estrobo (opcional)** | Interruptor **independiente**, **apagado de inicio**; ningún preset lo enciende |
| **Restaurar iluminación elegante** | Vuelve a todo lo inicial (zonas, intensidades, paleta, efectos, estrobo apagado) |

**Seguridad y comodidad**
- Las luces de **pasillos y escaleras nunca bajan del 45 %**, aunque apagues la zona o pongas el general a 0 (rejilla de relleno de cada piso, luces de escaleras, puerta y alfombra). Comprobado: solo con ellas se cubre ≥ 90 % de los tres pisos y de todos los peldaños.
- Ninguna luz supera el 150 % de su brillo base.
- **Estrobo:** máx. 2,5 destellos por segundo, en ráfagas de 2 s cada 8 s, brillo ≤ 2,5. El panel avisa de que puede afectar a personas fotosensibles.
- **Sincronizado:** el estado vive en atributos de `LaAlfombraRoja.Control` (replicados por Roblox). Todos los clientes ven lo mismo; el servidor no anima nada.
- **Anti-abuso:** el servidor valida acción, tipo y rango, comprueba que quien pide es el operador y que sigue cerca, y limita a **8 peticiones por segundo y jugador** (cubo de fichas; aviso al exceder). La interfaz además espacia los clics (≥ 0,12 s).

**Permisos (en `CONFIG.Control`)**

```lua
Control = {
	Enabled = true,
	Access = "Todos",   -- "Todos" | "Lista" | "Dueno"
	UserIds = {},       -- con "Lista": { 123456, 789012 }
	GroupId = 0,        -- opcional: grupo y rango mínimo
	MinRank = 1,
	Range = 14,         -- studs para tomar el control (se mantiene hasta 3x)
	IdleTimeout = 180,  -- segundos de inactividad
	MaxRequestsPerSecond = 8,
}
```
`"Todos"` es cómodo para probar (un solo operador a la vez evita que se pisen). Para un servidor real usa `"Lista"` (por UserId o rango de grupo) o `"Dueno"` (el creador; en Studio se permite siempre para poder probar).

## Perfiles gráficos: Equilibrado y Alta

Se elige con `CONFIG.Quality = "Equilibrado"` (por defecto, prioriza fluidez) o `"Alta"`. **No cambia la calidad gráfica del jugador ni la del editor**: solo decide qué construye el script y cuánto trabajo hacen las animaciones locales.

| | **Equilibrado** | **Alta** |
|---|---|---|
| Baldosas de la pista | 12 × 12 | 16 × 16 |
| Facetas de la bola de espejos | ≈ 140 (anillos cada 18°) | ≈ 204 (cada 12°) |
| Luces con sombras | **4** | **12** |
| Luces totales (simulador) | 138 (se quitan velas, calabazas, llamas, calderos, tiras de barra y la mitad de los downlights) | 182 |
| Capas por láser / conos de luz | 2 / 6 | 3 / 12 |
| Humo de escenario y calderos | no | sí |
| Profundidad de campo | no | sí |
| Bloom | ×0,75 | ×1 |
| Animaciones locales | pista a 5 Hz, neones 4 Hz, espejo ≈ 7 Hz | pista 8 Hz, neones 5 Hz, espejo ≈ 12 Hz |

**Rendimiento por diseño**
- Las animaciones decorativas (pista, neones, láseres, focos, espejo, estrobo, llamas, carteles) **se ejecutan en el cliente**: el servidor mantiene 1 sola conexión (el vigilante del operador) y **0 escrituras de animación**. Antes ≈ 1100–2500 propiedades/s se replicaban a cada jugador.
- Las escrituras locales solo se hacen **cuando cambia el valor** (colores cuantizados) y se espacian solas si tu equipo va justo (a 20 fps escribe ≈ la mitad que a 60) o dejan de ejecutarse si la cámara está a > 240 studs del club.
- Simulador (escrituras locales/s, no FPS): Equilibrado ≈ 1400 elegante, 2400 discoteca, 240 con efectos apagados; Alta ≈ 3200 / 5000 / 500.

### Configuración manual recomendada

**En el juego (cada jugador, Roblox › Ajustes › Gráficos):**
- *Equilibrado:* modo Manual, calidad gráfica **5–6**; si baja de 30 FPS, prueba 3–4 o el modo Automático. Con el panel puedes elegir **Apagado de efectos**.
- *Alta:* modo Manual, calidad **8–10** (requiere GPU dedicada o similar). En equipos justos quédate en Equilibrado.

**En el editor (Studio):**
- *Equilibrado:* `CONFIG.Quality = "Equilibrado"`. Si con `Lighting.Technology = Future` no llegas al objetivo, cambia a **ShadowMap** (más barato; el aspecto es algo más plano). Studio › File › Settings › Rendering: *Edit Quality Level* Automático.
- *Alta:* `CONFIG.Quality = "Alta"`, `Lighting.Technology = Future` (lo trae el `.rbxlx`), *Edit Quality Level* alto para previsualizar.
- `Lighting.Technology` no se puede cambiar por script; se guarda con el place.

### Medir el rendimiento (obligatorio antes de dar un perfil por bueno)

El objetivo de diseño es **60 FPS y, como mínimo, 30 estables**, **sujeto a medición real**: no está medido. Cómo medirlo: Play en Studio y en un cliente real (Roblox Player) con tu hardware objetivo; *View › Stats* / consola del desarrollador (**F9**) para FPS y memoria; **MicroProfiler (Ctrl+F6)** para ver cuánto cuestan los scripts y el renderizado. Mide con 1 y con varios jugadores, mirando la pista, el rooftop y desde el parqueadero. Si no llegas: (1) pasa a Equilibrado, (2) `Lighting.Technology = ShadowMap`, (3) `CONFIG.TileCount = 8`, (4) `CONFIG.Look.KeyShadows = false`, (5) `CONFIG.LowPerformance = true`.

## Logo

- `assets/LaAlfombraRoja_logo.png` (1024 × 1024, negro) y `assets/LaAlfombraRoja_logo.svg` son un **recurso limpio recreado** a partir de la composición de la imagen de referencia (corona, LA, ALFOMBRA, ROJA en rojo, filetes). Es una recreación vectorial (serif tipo Times/Bodoni), no un recorte de la foto: pásalo por tu tipografía exacta si tienes el original.
- **Mientras no subas la imagen no hace falta nada:** el logo se dibuja con piezas y texto (corona dorada en 3D + `Bodoni` dorado + ROJA en rojo, `RichText`). **No hay ningún ID inventado**: `CONFIG.LogoImageId` está vacío.
- Para usar la imagen: Creator Hub › *Assets* › sube el PNG (Image/Decal), copia el ID y ponlo en `CONFIG.LogoImageId` (`"rbxassetid://123"`, `"123"` o `123`). Entonces los logos, el letrero principal y la UI muestran la imagen en vez de la corona/texto de piezas.

## Edificio y exterior (sin cambios de fondo)

160 × 160 por piso (y 0 / 24 / 48): lobby con boletería y **zona de fotos**, pista LED 64 × 64 bajo atrio de doble altura, escenario DJ con la **cabina de luces**, bola de espejos, láseres, barras E/O, booths; VIP con 14 lounges, barra y balcón; rooftop con DJ, barra, piscina y fire pits. Escaleras de 10 de ancho (24 peldaños, descansos 10 × 10), pasillos ≥ 8 / ≥ 6. Terreno 256 × 334 con calles, aceras, parqueadero de 36 plazas con 20 deportivos, ruta peatonal sin escalones, muro de 10 + barrera invisible hasta y = 70. Halloween y cristalería conservados.

## Configuración (`CONFIG`)

| Opción | Efecto |
|---|---|
| `Quality` | `"Equilibrado"` (defecto) o `"Alta"` |
| `Control` | Cabina de luces: acceso, rango, inactividad, límite de peticiones |
| `MusicId` | Opcional, vacío. Solo audios con permiso |
| `LogoImageId` | Opcional, vacío (ver Logo) |
| `TileCount` | `0` = según perfil; o un número fijo de baldosas por lado |
| `LowPerformance` | `true` = respaldo de servidor al doble de intervalo |
| `Boundary`, `RemoveTemplateObjects`, `MusicVolume` | Barrera perimetral, limpiar plantilla, volumen |
| `Look` | `LightIntensity`, `AmbientBoost`, `Exposure`, `Bloom`, `BeamTransparency`, `BeamBrightness`, `BeamWidth`, `ShaftTransparency`, `TileBrightness`, `KeyShadows`, `Reflections`, `ShadowSoftness` |

## Comprobaciones realizadas (simulador, sin Studio)

```bash
tests/run.sh                          # geometria, rutas, identidad, perfiles (Equilibrado)
QUALITY=Alta tests/run.sh             # lo mismo con el perfil Alta
MODE=client tests/run.sh              # cabina de control + LocalScript de efectos
MODE=client QUALITY=Alta tests/run.sh
```
Requiere `luau` y python3. **Resultado: 163 comprobaciones de geometría/archivos y 118 de cabina/cliente por perfil, 0 fallos.**

- **Zona LA ALFOMBRA ROJA:** sin rastro del guardarropa; alfombra roja con filetes; 14 postes y 12 cordones; photocall con marco y 7 logos; 2 softboxes con foco; cámara, palmeras, mesas; alfombra transitable para cuerpos de 7 studs; ≥ 8 studs libres junto a las mesas altas.
- **Identidad:** sin "MAYA"/"AURA" en nombres ni textos; rótulos "LA ALFOMBRA ROJA" con ROJA en rojo; 14 logos con corona; ALFOMBRA en serif dorada y ROJA en rojo en todos; con `LogoImageId` definido aparecen las imágenes (variante probada aparte).
- **Bola de espejos:** facetas Metal en dos platas con reflectancia ≤ 0,9 y color ≤ 0,95; **ninguna faceta dentro del núcleo** (esquinas interiores a ≥ 3,56 con núcleo de 3,5); luz interior ≤ 1,2 y focos ≤ 2.
- **Cabina:** estado por defecto, estrobo apagado; un solo operador; permisos Todos / Lista (UserIds y grupo/rango) / Dueño; rechazo de valores no válidos, NaN y tipos erróneos; límite de 8 peticiones/s; liberación por soltar, lejanía, inactividad y salida del jugador; presets; Restaurar.
- **Cliente:** luces = brillo base × zona; seguridad ≥ 45 %; tope 150 %; láseres, focos, espejo, estrobo (≤ 3 destellos/s) y paletas responden al estado; 0 escrituras en el servidor; frecuencia adaptativa; cámara lejos = 0 escrituras; panel en español (todos los textos, botones y avisos) y límite de clics.
- **Seguridad de luz:** solo con las luces de seguridad quedan cubiertos los 3 pisos y las 720 celdas de peldaño.
- **Pruebas de sabotaje:** estrobo encendido de inicio, sin límite de peticiones, sin comprobar al operador, sin mínimo de seguridad, sin tope de intensidad, facetas dentro del núcleo, coches solapados, etc., hacen fallar los tests esperados.
- `luau-compile` OK; `luau-analyze` sin avisos salvo las globales de Roblox; archivos generados válidos (`tests/check_files.py`).

**Límite:** el mock no renderiza, no simula red, físicas ni FPS, ni la interfaz real de `ProximityPrompt`. Prueba en Studio la cabina (E, panel, dos jugadores con *Test › Clients and Servers*), el aspecto de los logos y la medición de FPS.
