# LA ALFOMBRA ROJA · v2

Versión **nueva** (no sustituye a la v1 de la raíz del repositorio). Conserva el nombre y logo de corona dorada, texto
dorado/rojo, alfombra roja, estilo luxury, muebles blancos y negros brillantes, la bola de espejos corregida
(`MirrorCore` diámetro 7, facetas a 3,56 con reflectancia 0,8) y la cabina de luces. `PhotocallLogo`/`PhotocallMini`
siguen en x = -76,9 y el `ClubSpawn` es invisible (`Transparency = 1`).

> **Estado real:** todo está hecho por código y probado **solo en un simulador** (Luau + una API de Roblox simulada).
> **Nada se ha abierto ni probado en Roblox Studio.** Véase la [matriz de pruebas](#matriz-de-pruebas).
> No se ha publicado nada ni hecho merge.

## Contenido

| Archivo | Para qué |
|---|---|
| `LaAlfombraRoja_v2.rbxlx` | Place **listo para abrir**: todos los Script, LocalScript y ModuleScript ya colocados. |
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
  (`PurchaseGranted`) si el guardado ha ido bien**; si falla devuelve `NotProcessedYet` y Roblox lo reintenta.
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

### Límite conocido de los datos
El inventario usa `DataStore:UpdateAsync` (idempotente por `PurchaseId`, escritura inmediata en compras y canjes,
autoguardado, guardado al salir y en `BindToClose`; si la carga falla la sesión queda en **solo lectura** y nunca
sobrescribe). **No hay bloqueo de sesión entre servidores**: si un jugador está en dos servidores a la vez, el último
guardado de datos no críticos (equipar/beber) puede pisar al otro. Para producción seria considera ProfileService/ProfileStore.

## Matriz de pruebas
**Simulado** = ejecutado con Luau contra una API de Roblox simulada (`tests/mock_roblox.luau`); **no** es Studio.
**Studio** = **nada se ha probado en Studio todavía**.

| Área | Simulado | Probado en Studio |
|---|---|---|
| Catálogo y modelos 3D (botellas/copas: piezas, líquido, etiquetas, contraste) | ✅ | ❌ |
| Inventario: carga/guardado, vales, canje, equipar, sorbos, fallos de DataStore, solo lectura | ✅ | ❌ |
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
| Pruebas de sabotaje (13 mutaciones, todas detectadas) | ✅ | n/a |
| Ejecución real, rendimiento/FPS, colisiones, red, multijugador | ❌ | ❌ |

Totales actuales: servidor 126, cliente 54, mundo 156 (×2 perfiles), archivos 10 comprobaciones.

### Puntos que **no** se han podido verificar y conviene mirar primero en Studio
1. Que `Seat:Sit(humanoid)` siente al jugador y que los asientos quedan bien colocados.
2. La orientación del agarre de las `Tool` (botella/copa en la mano) y que el nivel del líquido baje bien.
3. La vista previa 3D (`ViewportFrame` no dibuja `SurfaceGui`: las etiquetas se leen en el texto bajo el modelo).
4. Los `ProximityPrompt` (distancias, textos) y el aspecto/tamaño de las ventanas en móvil.
5. Grupos de colisión de la barrera de entrada (jugadores y su personaje al reaparecer).
6. Configuración de `TextChatService` (ventana, barra de chat, burbujas) en tu versión de chat.
7. DataStore en Studio (requiere *Enable Studio Access to API Services*).
8. Rendimiento: ~5,9 mil partes y 144 luces (Equilibrado) / ~6,2 mil y 188 (Alta), sin medir.

## Ejecutar las pruebas (opcional, necesita el intérprete `luau`)
```
python3 tools/assemble_tests.py tests/t_server.luau /tmp/s.luau && luau /tmp/s.luau
python3 tools/assemble_tests.py tests/t_client.luau /tmp/c.luau && luau /tmp/c.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/w.luau && luau /tmp/w.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/wa.luau --set 'Quality="Alta"' && luau /tmp/wa.luau
python3 tools/make_place.py && python3 tools/check_files.py
LUAU=luau python3 tools/mutation_tests.py
```
