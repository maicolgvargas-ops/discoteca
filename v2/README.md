# LA ALFOMBRA ROJA · v2.1.1

Versión **nueva** (no sustituye a la v1 de la raíz del repositorio ni al `LaAlfombraRoja_v2.rbxlx` anterior, que se conserva tal cual). Conserva el nombre y logo de corona dorada, texto
dorado/rojo, alfombra roja, estilo luxury, muebles blancos y negros brillantes, la bola de espejos corregida
(`MirrorCore` diámetro 7, facetas a 3,56 con reflectancia 0,8) y la cabina de luces. `PhotocallLogo`/`PhotocallMini`
siguen en x = -76,9 y el `ClubSpawn` es invisible (`Transparency = 1`).

> **Estado real:** todo está hecho por código y probado **solo en un simulador** (Luau + una API de Roblox simulada).
> **Nada se ha abierto ni probado en Roblox Studio.** Véase la [matriz de pruebas](#matriz-de-pruebas).
> No se ha publicado nada ni hecho merge.

## Novedades de la 2.1.1 (correcciones tras la primera prueba REAL en Studio)
La prueba F5 del usuario mostró: escena y HUD correctos, pero el servidor **abortaba** con *"You must publish this place to the web
to access DataStore"* (`GetDataStore` fuera de `pcall`), muebles blancos/pista/photocall **sobreexpuestos**, ambiente aún claro y focos
rojos **sin confirmar**. Cambios (todos **sin validar todavía en Studio**; solo pruebas en simulador):
- **El servidor ya no aborta.** `GetDataStore` va en `pcall` y cada subsistema (`Music`, `Control`, `Interactions`, `Inventory`,
  `Purchases`) arranca aislado: si uno falla se avisa por `warn` y el resto sigue. Sin DataStore (`persistence = "none"`): inventario y
  compras con Robux **bloqueados** (`ProcessReceipt` → `NotProcessedYet`, nunca se confirma un cobro), pero entrada, guardias,
  credencial, asientos, baile, música, cabina y luces siguen funcionando. La UI de la tienda lo explica.
- **Modo Studio temporal (explícito, separado de producción):** `Config.Data.StudioTemporaryMode = true` (por defecto `false`). Solo si
  `RunService:IsStudio()`: el inventario vive **en memoria** (nada se guarda; banner «MODO STUDIO TEMPORAL: el inventario NO se
  guarda»). **No activa cobros:** `ProcessReceipt` sigue devolviendo `NotProcessedYet` y las compras con Robux están bloqueadas; para
  obtener bebidas usa además `Config.Purchases.StudioTestMode = true` (gratis, solo Studio). Fuera de Studio se ignora con un aviso.
  Desactívalo antes de publicar. Alternativa sin modo temporal: publica el place y activa *Enable Studio Access to API Services*.
- **Menos sobreexposición:** `Config.Look` ahora usa `LightIntensity 0.8`, `AmbientBoost 0.55`, `Exposure -0.15`, bloom suave
  (`0.12 / tamaño 12 / umbral 1.8`), relleno de pisos ×0,6 (`FillScale`), `Lighting.Brightness 0.5` (`SunBrightness`),
  `EnvironmentDiffuseScale 0.25`, pista LED y neones animados más suaves (`TileBrightness 0.45`, `GlowBrightness 0.55`), cuero
  marfil y mármol marfil algo más oscuros (siguen siendo «blancos»), y el difusor del softbox del photocall ya no es `Neon`
  (plástico) con menos brillo. Se conservan los reflejos (`Reflectance`) y el negro lacado. **Son valores iniciales razonados, no
  medidos en Studio:** ajústalos en `Config.Look` mirando la escena real.
- **Discoteca oscura más oscura:** `Dark 0.85` (ambiente local hasta el 30 % y exposición −0,34), `Master 0.8`, pista 30 %, VIP/rooftop
  40 %. Las luces de **acceso** (escaleras, descansos, puertas, alfombra de entrada, pasillos y lámparas de las barras, atributo
  `acc`) mantienen **siempre ≥ 45 %**; solo el relleno se atenúa. La alfombra/entrada queda al 100 %.
- **Focos rojos (arranque):** el registro tolera que la luz, el haz o el objetivo se repliquen después de la cabeza etiquetada; los
  módulos del cliente arrancan y se ejecutan **aislados** (un error en `Effects`, por ejemplo, ya no detiene los focos); el cliente
  imprime `[LaAlfombraRoja] foco rojo FollowLightN registrado en el cliente` y `focos rojos ACTIVOS en el cliente (N focos)` (y un
  `warn` si se activan sin focos registrados) para poder confirmarlo en *Output*. Además, antes el servidor abortaba en
  `Inventory.init`, así que `Purchases.init` nunca llegaba a ejecutarse: eso queda resuelto.

## Novedades de la 2.1.0
- **Discoteca más oscura + focos rojos móviles.** 2 focos rojos (perfil Equilibrado) o 4 (Alta) colgados del truss del atrio.
  Cada uno tiene luz roja (`SpotLight` sin sombras, rango ≤ 60) y un haz visible (`Beam`). Los mueve **solo el cliente**:
  siguen con suavidad a quien está **dentro de la pista**, se reparten entre las personas (cambian de persona cada 5 s),
  **nunca apuntan fuera de la pista** (rectángulo de `LAYOUT.dance` con margen) y, sin nadie, barren la pista despacio.
  Están **apagados por defecto**; se activan en la cabina: pestaña *Luces → Focos rojos y ambiente* (interruptor,
  intensidad 0–150 %, velocidad ×0,25–×2, oscuridad 0–100 %) o con el preset **Discoteca oscura**.
- **Preset «Discoteca oscura»** (`Control.PRESETS.DiscotecaOscura`): (2.1.1) oscuridad 0,85, pista 30 %, VIP/rooftop 40 %, alfombra/entrada
  100 %, paleta dorada (los focos son lo único rojo), estrobo **apagado**, láseres apagados. Cualquier preset restablece primero
  zonas, focos y oscuridad (`PRESET_BASE`), así que al volver a «Elegante» todo vuelve a su sitio.
- **Visibilidad conservada:** la oscuridad solo baja `Lighting.Ambient/OutdoorAmbient/ExposureCompensation` **en tu pantalla**
  y (2.1.1) nunca por debajo del 30 % del valor original; escaleras, entrada (zona alfombra), pasillos y las lámparas de las barras tienen
  luz mínima de seguridad (45 %, luces de acceso); logo, photocall, esfera y muebles no se tocan.
- **Rendimiento:** apagados = cero trabajo; encendidos, 20 actualizaciones/s (30 en Alta) solo si estás cerca del club, y se escribe
  una propiedad solo cuando cambia. Sin sombras nuevas. **No** se baja ninguna calidad ni resolución automáticamente.
- **Persistencia de producción** (corregida en 2.1.1): bloqueo de sesión con *lease* (ver más abajo), recibos idempotentes guardados **en la misma
  escritura** que el inventario, y liberación segura al salir/cerrar.

## Contenido

| Archivo | Para qué |
|---|---|
| `LaAlfombraRoja_v2.1.1.rbxlx` | Place **listo para abrir** (versión actual): todos los Script, LocalScript y ModuleScript ya colocados. `LaAlfombraRoja_v2.1.0.rbxlx` y `LaAlfombraRoja_v2.rbxlx` son entregas anteriores y se conservan. |
| `src/` | Fuentes modulares `.luau` (estructura Rojo). Son idénticos a lo que lleva el `.rbxlx`. |
| `default.project.json` | Proyecto Rojo opcional (`rojo build -o LaAlfombraRoja_v2.rbxlx`). |
| `tools/make_place.py` | Regenera el `.rbxlx` desde `src/`. `tools/check_files.py` comprueba que coinciden. |
| `tests/`, `tools/assemble_tests.py`, `tools/mutation_tests.py` | Pruebas en simulador y pruebas de sabotaje. |

### Instalación
1. Abre `LaAlfombraRoja_v2.rbxlx` en Studio (o `rojo build` y ábrelo).
2. *Game Settings → Security → Enable Studio Access to API Services* (para probar el inventario persistente en Studio).
3. Comprueba que el chat usa **TextChatService** (*Chat → Chat Version = TextChatService*); no se crea ningún chat propio.
4. Pulsa *Play*. El club se construye al arrancar (unos segundos) en `Workspace.LaAlfombraRoja`.

### Estructura
```
ReplicatedStorage/AlfombraShared      Config, Catalog, DrinkModels, Rig, DancePoses, Util   (módulos compartidos)
ServerScriptService/LaAlfombraRoja    Script (init) + Build, Extras, Inventory, Purchases, Music, Control, Interactions, Remotes
StarterPlayerScripts/LaAlfombraRojaClient   LocalScript (init) + Effects, ControlUi, ShopUi, Dance, GuardUi, Npcs, Hud, Ui
```

## Qué incluye (por prioridad)
1. **Entrada** → dos guardias grandes en la puerta. Cada jugador tiene una **credencial FICTICIA** del club (`AR-XXXXXX`,
   generada y validada en el servidor). El diálogo muestra avatar, nombre, credencial y el aviso de que **no es un
   documento ni comprueba la edad** (eso lo gestiona Roblox). El acceso es **por jugador**: una barrera con grupo de
   colisión solo bloquea a quien aún no ha presentado la credencial. **La salida nunca se bloquea.**
2. **Bar y compra** → bartenders NPC (barra este, oeste, VIP y rooftop) abren la carta. Categorías Champaña, Tequila,
   Whisky y Shots; vista previa 3D que se puede girar; cantidad; comprar/canjear. Botellas y copas son **geometría
   original** hecha por código (no hay logos ni assets externos); el nombre va escrito como texto.
3. **Inventario y equipar** → persistente (DataStore). Equipar da una `Tool` 3D (botella o copa); se bebe a sorbos
   (botella = 5, shot/copa = 1); "Guardar" la devuelve a la mochila.
4. **Sentarse y bailar** → 124 `Seat` reales discretos (sofás, taburetes) con `ProximityPrompt` y botón *Levantarse*.
   Panel de baile con 5 bailes procedurales (R6 y R15, **sin ids de animación**); opcionalmente `AnimationId` propio en
   `Config.Dance.Dances`. 4 bailarinas NPC elegantes y vestidas en tarimas de la zona VIP.
5. **Cabina de música y luces** → mesa de DJ detallada (platos, mezcladora, monitor) con el mismo operador único que las luces.
   Dos pantallas "Ahora suena" con visualizador de audio **real** (`PlaybackLoudness`; no es vídeo).

## Configuración

Todo en `ReplicatedStorage/AlfombraShared/Config.luau` y `Catalog.luau`:

- **Calidad**: `Config.Quality = "Equilibrado"` (por defecto) o `"Alta"`. Solo cambia lo que se construye y el trabajo de
  las animaciones locales. No se tocan `UserGameSettings` ni `RenderSettings` y no se cambia la calidad automáticamente.
- **Catálogo**: filas de `Catalog.Items` (Id único, `Category`, `Tier` = `bottle`|`shot`, `Kind` del modelo, `Label`,
  colores). Los nombres de marcas conocidas (Moët, Veuve Clicquot, Dom Pérignon, Don Julio 1942, Clase Azul, Patrón…)
  los pidió el titular como **texto de ejemplo**: son marcas de terceros. Revisa permisos y políticas de Roblox antes
  de publicar o pon `Catalog.UseGenericNames = true` (hay `GenericName` para cada una).
- **Acceso a la cabina**: `Config.Control.Access = "Todos" | "Lista" | "Dueno"`, `UserIds`, `GroupId`/`MinRank`.
- **Guardias**: `Config.Guards` (`Enabled`, `BlockedUserIds`, frases). Con `Enabled = false` no hay barrera.
- **Música**: ver más abajo. **Chat**: `Config.Chat.Enable`.

### ProductIds pendientes (Robux)
Las compras con Robux usan **Developer Products** y son **repetibles**. El jugador compra *vales* (por tier) y los canjea
por el artículo que elige; la compra se concede en `ProcessReceipt` (un único manejador en el servidor).

| Clave | Concede | `ProductId` | Estado |
|---|---|---|---|
| `vale_botella` | 1 vale de botella | `0` | **PENDIENTE** (crear en Creator Hub y pegar el ID en `Catalog.Products`) |
| `vale_shot` | 1 vale de shot/copa | `0` | **PENDIENTE** |

- `ProductId = 0` ⇒ esa compra con Robux está **desactivada** (la UI dice "Compra con Robux no disponible / Precio
  pendiente"). **No hay ningún ID inventado.**
- Las cifras `DraftRobux` (400 botella / 50 shot) son un **borrador interno**: nunca se muestran como precio real.
  El precio que ve el jugador es el que devuelve `MarketplaceService:GetProductInfoAsync` del producto enlazado.
- `ProcessReceipt` valida el recibo, concede de forma **atómica e idempotente** (por `PurchaseId`) y **solo confirma
  (`PurchaseGranted`) si el guardado ha ido bien y el servidor tiene el alquiler de la sesión**; si falla (o el registro está en
  otro servidor) devuelve `NotProcessedYet` y Roblox lo reintenta, también al reconectar.
  `PromptProductPurchaseFinished` jamás concede nada.
- **Modo de prueba en Studio (gratis, separado):** `Config.Purchases.StudioTestMode = true`. Solo actúa si
  `RunService:IsStudio()`; en un servidor real no hace nada aunque se deje en `true`. **Está en `false` por defecto**
  y la UI muestra un aviso cuando está activo. Pasos: abrir en Studio → activarlo → *Play* → hablar con un bartender →
  elegir artículo → *Probar gratis*. Desactívalo antes de publicar.

### AudioIds pendientes (música)
`Config.Music.Tracks = {}` está **vacío**: no hay ningún audio inventado. Para añadir música:
```lua
Tracks = { { Id = "rbxassetid://TU_ID", Title = "Título", Artist = "Artista" } },
```
El audio debe ser tuyo o tener permiso de uso en tu experiencia. Sin pistas, el panel de la cabina y las pantallas
explican que no hay música configurada y no ofrecen botones que simulen reproducción. Solo suenan pistas de esta
lista blanca (el cliente envía un **índice**, nunca un assetId) y solo las controla el **operador** de la cabina.

### Clasificación de contenido (pendiente del titular)
El club incluye alcohol **ficticio** (bebidas virtuales cosméticas), por lo que la experiencia deberá declarar la
clasificación de contenido que corresponda (p. ej. Restricted, si procede) en el *Maturity Questionnaire* / ajustes del
creador. **No se ha cambiado ningún ajuste de cuenta ni de privacidad**: lo configura el titular antes de publicar.
La credencial del club es un elemento de juego; **no verifica edad** ni sustituye a la verificación de Roblox.

## Seguridad y rendimiento (diseño)
- Remotos con validación de tipos/rangos y **límite de frecuencia** por jugador y remoto (`Remotes.allow`), y límite
  adicional en la UI. El servidor decide cercanía, permisos, precios, vales, cantidades y recibos; el cliente no.
- Decoración (luces, láseres, estrobo, pista, bola, NPC, bailes ajenos, visualizador) **solo en el cliente** y limitada
  por distancia (`Npcs.AnimateDistance`, `Dance.MaxAnimateDistance`, máximos `MaxAnimated`/`MaxVisible`). El servidor no
  anima nada (0 escrituras/s en prueba).
- Estrobo opcional y apagado de inicio, ≤ 2,5 destellos/s por foco, con aviso para personas fotosensibles.
- No se prometen FPS: **no se ha medido en Studio ni en dispositivos**. Mide con el *MicroProfiler* y, si hace falta,
  usa `Quality = "Equilibrado"`, baja `Npcs.MaxAnimated`/`Dance.MaxVisible` o desactiva láseres/haces desde la cabina.
- No hay paneles ni comandos de benchmark.

### Persistencia y bloqueo de sesión (lease)
Modos de persistencia (`Inventory.persistence()`): `"datastore"` (normal), `"memory"` (solo Studio temporal, ver arriba) y `"none"` (sin DataStore: bloqueado).
El inventario vive en un único registro por jugador (`DataStore`, clave `u<UserId>`) que incluye inventario, vales, **recibos**
(`PurchaseId`) y un **alquiler**: `lock = { o = <token de sesión>, e = <caducidad> }`.
- **Cargar** = `UpdateAsync` que toma el alquiler solo si está libre, caducado o ya es nuestro. Si otro servidor lo tiene vivo
  se espera (`LockWaitSeconds`, reintento cada `LockRetrySeconds`) y después la sesión queda en **solo lectura** («inventario en
  uso en otro servidor»), reintentando cada 15 s. **Nunca se sobrescribe** lo guardado.
- **Escribir** (compra, canje, autoguardado, renovación): cada `UpdateAsync` comprueba *dentro de la misma escritura atómica* que
  el alquiler sigue siendo nuestro. Si no lo es, no escribe nada, la sesión pasa a solo lectura (se descartan solo los cambios no
  guardados) y se recarga lo más reciente cuando el otro servidor suelta.
- **Renovación** cada `RenewSeconds` (40 s) con un alquiler de `LeaseSeconds` (120 s): si un servidor cae, el alquiler caduca solo.
- **Recibos**: el `PurchaseId` se registra en el mismo registro y en la misma escritura que los vales/artículos, así que o se
  guardan ambos o ninguno. Un reintento (reconexión, otro servidor, `NotProcessedYet`) no duplica ni pierde nada.
- **Liberar**: al salir se guarda y se pone `lock = nil` en una sola escritura; en `BindToClose` se liberan todos en paralelo. Si
  la liberación falla, el alquiler caduca solo en ≤ 120 s y el jugador espera/queda bloqueado temporalmente, sin pérdida.
- **Límites honestos:** `UpdateAsync` es atómico por clave en Roblox, pero aquí solo se ha **simulado** (un hilo, un DataStore
  simulado; «otro servidor» se emula editando el registro). Depende de relojes razonablemente sincronizados (margen de 120 s).
  No hay expulsión del jugador bloqueado (decisión de diseño). No se ha probado con servidores reales ni en Studio.

## Matriz de pruebas
**Simulado** = ejecutado con Luau contra una API de Roblox simulada (`tests/mock_roblox.luau`); **no** es Studio.
**Studio** = **nada se ha probado en Studio todavía**.

| Área | Simulado | Probado en Studio |
|---|---|---|
| Catálogo y modelos 3D (botellas/copas: piezas, líquido, etiquetas, contraste) | ✅ | ❌ |
| Inventario: carga/guardado, vales, canje, equipar, sorbos, fallos de DataStore, solo lectura | ✅ | ❌ |
| **Sin DataStore: `GetDataStore` lanza error** (servidor no aborta, inventario/cobros bloqueados, entrada/cabina/luces siguen) y **modo Studio temporal** (memoria, sin cobros, ignorado fuera de Studio) | ✅ 14 + 11 | ❌ (Studio real) |
| **Alquiler de sesión**: toma/renovación/liberación, otro servidor con alquiler vivo o caducado, alquiler perdido a mitad, fallos al salir, cierre del servidor, recibos atómicos e idempotentes | ✅ 32 (simulado, un hilo) | ❌ (servidores reales) |
| Compras: `ProcessReceipt`, idempotencia, no confirmar si falla el guardado, producto desconocido, recibos mal formados, modo Studio | ✅ | ❌ |
| Música: lista blanca, índices inválidos, volumen, siguiente/anterior, fin de pista, estado vacío | ✅ | ❌ |
| Operador único, permisos y límites de la cabina | ✅ | ❌ |
| Asientos (`Seat`, prompts, orientación) | ✅ | ❌ (`Seat:Sit` y la colocación real) |
| Guardias, credencial, barrera por jugador, salida libre | ✅ (grupos de colisión simulados) | ❌ |
| Baile (R6/R15), corte al andar, distancia, NPC bailarinas | ✅ (poses sobre `Motor6D` simulados) | ❌ |
| Chat oficial (`TextChatService`) | ✅ (solo activación de configuraciones) | ❌ |
| UI cliente: tienda, vista previa, mochila, cabina, guardias, HUD, límites | ✅ | ❌ (aspecto visual, tamaño en móvil) |
| Mundo: navegación (cuerpos 1/2,5/3,5), pasillos, escaleras, luz, piezas flotantes, estilo | ✅ 156 + 156 (Equilibrado + Alta) | ❌ |
| Láseres dentro del atrio, estrobo ≤ 3/s | ✅ | ❌ |
| **Focos rojos de seguimiento**: apagados por defecto, límites de pista, suavidad, reparto entre personas, intensidad/velocidad, cero trabajo apagados o lejos, preset y su restablecimiento, oscuridad con mínimo 30 % del ambiente y 45 % en luces de acceso | ✅ | ❌ (aspecto real del haz, intensidad, sensación de oscuridad) |
| Arranque aislado de módulos del cliente, registro tardío de focos, luces de acceso vs relleno con oscuridad máxima, menos exposición (valores de `Lighting`/bloom) | ✅ | ❌ (**el aspecto real de la exposición no se ha visto**) |
| Pruebas de sabotaje (29 mutaciones, todas detectadas) | ✅ | n/a |
| Ejecución real, rendimiento/FPS, colisiones, red, multijugador | ❌ | ❌ |

Totales actuales (simulador): servidor 133, persistencia 32, sin DataStore 14, Studio temporal 8 + 3 (producción), cliente 78, mundo 162 (×2 perfiles), archivos 14 comprobaciones, 29 sabotajes detectados. **Ninguno es una prueba en Studio.**

### Puntos que **no** se han podido verificar y conviene mirar primero en Studio
1. Que `Seat:Sit(humanoid)` siente al jugador y que los asientos quedan bien colocados.
2. La orientación del agarre de las `Tool` (botella/copa en la mano) y que el nivel del líquido baje bien.
3. La vista previa 3D (`ViewportFrame` no dibuja `SurfaceGui`: las etiquetas se leen en el texto bajo el modelo).
4. Los `ProximityPrompt` (distancias, textos) y el aspecto/tamaño de las ventanas en móvil.
5. Grupos de colisión de la barrera de entrada (jugadores y su personaje al reaparecer).
6. Configuración de `TextChatService` (ventana, barra de chat, burbujas) en tu versión de chat.
7. DataStore en Studio (requiere *Enable Studio Access to API Services*).
8. Rendimiento (**sin medir**): ~5,9 mil partes y 146 luces (Equilibrado) / ~6,2 mil y 192 (Alta), sin medir.
9. Aspecto de los focos rojos: ángulo (26°), brillo, anchura del haz y cuánto se ve la «niebla» del haz; ajusta `Config.Follow`.
10. Que `Lighting.Ambient` local se vea bien con `Technology = Future` y que el nivel «Discoteca oscura» siga siendo legible en móvil.
11. Concurrencia real del DataStore (dos servidores a la vez, rejoin rápido, `BindToClose` real).

## Ejecutar las pruebas (opcional, necesita el intérprete `luau`)
```
python3 tools/assemble_tests.py tests/t_server.luau /tmp/s.luau && luau /tmp/s.luau
python3 tools/assemble_tests.py tests/t_persist.luau /tmp/p.luau && luau /tmp/p.luau
for t in nostore studiotemp studiotemp_prod; do python3 tools/assemble_tests.py tests/t_$t.luau /tmp/$t.luau && luau /tmp/$t.luau; done
python3 tools/assemble_tests.py tests/t_client.luau /tmp/c.luau && luau /tmp/c.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/w.luau && luau /tmp/w.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/wa.luau --set 'Quality="Alta"' && luau /tmp/wa.luau
python3 tools/make_place.py && python3 tools/check_files.py
LUAU=luau python3 tools/mutation_tests.py
```
