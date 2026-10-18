# LA ALFOMBRA ROJA · v2.1.6

Versión **nueva** (no sustituye a la v1 de la raíz del repositorio ni al `LaAlfombraRoja_v2.rbxlx` anterior, que se conserva tal cual). Conserva el nombre y logo de corona dorada, texto
dorado/rojo, alfombra roja, estilo luxury, muebles blancos y negros brillantes, la bola de espejos corregida
(`MirrorCore` diámetro 7, facetas a 3,56 con reflectancia 0,8) y la cabina de luces. `PhotocallLogo`/`PhotocallMini`
siguen en x = -76,9 y el `ClubSpawn` es invisible (`Transparency = 1`).

> **Estado real:** todo está hecho por código y probado **solo en un simulador** (Luau + una API de Roblox simulada).
> **Nada se ha abierto ni probado en Roblox Studio.** Véase la [matriz de pruebas](#matriz-de-pruebas).
> No se ha publicado nada ni hecho merge.

## Novedades de la 2.1.6 (parche aditivo VipUpgrade: cristal VIP + aros de fuego)
Autorizado por el titular. Nuevo `ReplicatedStorage/AlfombraShared/VipUpgrade` (autocontenido, ver `INTEGRACION_VipUpgrade.md`): cierre de cristal del
VIP (y 24 → 46) con 4 paneles colisionables únicos, «polarizado» solo visual y local por posición de cámara (`LocalTransparencyModifier`; no cambia
`Transparency` global ni permisos; **no es privacidad real**), y 3–4 aros de fuego dorado/negro colgados del techo con llamas `ParticleEmitter` sin daño y
una luz sin sombras por aro. Equilibrado/Alta solo cambia cuántos se construyen y a qué distancia se animan; no toca `UserGameSettings`/`RenderSettings`.
Se cablea con 2 líneas (servidor tras `Control.init`, cliente aislado en `boot`). Pruebas simuladas (32 + 32 en Alta) y 8 sabotajes nuevos; **todo el
aspecto visual y el coste real quedan por probar en Studio** (lista en `INTEGRACION_VipUpgrade.md`). No toca música, inventario, chat ni compras.

## Novedades de la 2.1.5 (pantallas «Ahora suena» orientadas al público)
**QA real aportada por el usuario:** las dos pantallas `NowPlayingL/R` se veían **negras desde la pista**. `Extras.musicScreens` crea el
panel sin rotación en z = −77,65 con `ScreenGui.Face = Front`, y su `LookVector` en ejecución es (0, 0, −1): la cara `Front` mira a la
pared. Desde la cámara (−64, 12, −49) mirando a (−64, 12, −77,65) se veía negro aunque `Title.Text` era «Sin música configurada»; al poner
solo en QA `ScreenGui.Face = Back` aparecían «AHORA SUENA», el título, el aviso y las barras.
**Corrección:** ambas pantallas usan ahora `Face = Back` (normal = +Z, hacia el público). La geometría del panel, el marco dorado y los
textos no cambian. Sin audio real las 24 barras siguen **planas** (el visualizador solo sube con `PlaybackLoudness` real; no simula
reproducción).
**Monitor del DJ revisado por separado, sin cambios:** `DJ_Monitor` usa `CFrame.lookAt` hacia −Z con `Face = Front`, es decir, su pantalla
mira al **operador** (detrás de la mesa), no al público; es lo previsto, así que no se invierte. Una prueba lo fija.
**Baile (confirmado por el usuario, sin tocar código):** el `RightShoulder` (AnimationConstraint) cambió 89 veces en 90 fotogramas y
caminar 14,11 studs limpió `AR_Dance = nil`.
**Pruebas (simulador):** la orientación se comprueba con la normal real de la cara (`Back` = −LookVector): normal +Z, visible desde la
cámara del QA y no desde detrás de la pared; título/aviso/24 barras presentes y planas al inicio; el monitor del DJ mira al operador. Se
sabotea revertir a `Front` y también invertir el monitor: ambos se detectan. **No probado en Studio** (que se vean bien y con el
tamaño/legibilidad adecuados desde distintos puntos de la pista).

## Novedades de la 2.1.4 (salir del asiento)
**QA real aportada por el usuario sobre la 2.1.2:** el shot gratuito se equipa en la hotbar, se sostiene y al activarlo se consume con
el aviso «Has terminado» y desaparece (correcto). Sentarse con E en `BarWStool3_Sit` funciona, **pero «Levantarse» no lo libera**:
tras varios segundos seguían `Humanoid.Sit = true`, `SeatPart = BarWStool3_Sit`, `State = Seated` (JumpPower 50, salto habilitado), y la
barra espaciadora con el viewport enfocado tampoco lo soltaba. El botón solo ponía `Humanoid.Jump = true`.
**Corrección (sin cambiar el resto):**
- **Salida validada en el servidor.** Nueva acción `Stand` del remoto `Social` (con el mismo límite de frecuencia). El servidor solo
  actúa si el jugador está sentado en **un asiento de este club** (`seatSet`, registrado en `setupSeats`) y **ese jugador es el ocupante**
  (`seat.Occupant == humanoid`). Entonces pone `Sit = false`, destruye **solo** el `SeatWeld` de ese asiento (el de su único ocupante) y
  coloca al jugador en un **punto de salida elegido por el servidor** a ≤ `ExitDistance` (2,4 studs) del asiento, comprobando con
  `GetPartBoundsInBox` que el hueco esté libre (detrás, lados, delante; si no hay hueco, justo encima del asiento). El cliente **no envía
  posiciones ni asientos** (se ignoran los argumentos): no hay teletransporte arbitrario. **Nunca libera a otros ocupantes**: un jugador
  de pie, sentado en un `Seat` ajeno al club o en un asiento ocupado por otro no consigue nada.
- **Cooldowns:** `StandCooldown` (1,0 s) tras levantarse por **cualquier causa** (botón, salto, soldadura destruida) el jugador no puede
  volver a sentarse; `SameSeatCooldown` (2,5 s) para el **mismo** asiento; `StandMinInterval` (0,3 s) tras sentarse ignora `Stand`
  (anti-parpadeo); más el `Cooldown` de 0,6 s ya existente entre sentadas.
- **Cliente:** el botón «Levantarse» **y** `UserInputService.JumpRequest` (barra espaciadora y botón de salto del móvil) piden `Stand`
  al servidor (con límite de 0,4 s en el cliente) y además ponen `Jump = true` (camino normal del motor). Solo se envía algo si estás
  sentado. El botón aparece si `Sit` o `SeatPart ~= nil`.
- **Sentarse:** ahora se espera hasta 0,3 s a que el `Occupant` se actualice tras `Seat:Sit` antes de recurrir a la alternativa
  (activar `CanTouch` 1 s y subir al jugador), que podía actuar sin necesidad.
- **Causa raíz NO confirmada.** Sospecha: los `Seat` del club están **anclados** y el personaje soldado a una pieza anclada queda con
  propiedad de red del servidor, por lo que ni `Jump` ni `Sit = false` del cliente liberan. El diseño no depende de esa hipótesis (la
  salida la hace el servidor). Si en Studio sigue fallando, mira en *Output* si hay errores y comprueba `seat.Anchored`,
  `hum.SeatPart`, `seat:FindFirstChild("SeatWeld")` y el propietario de red del personaje (`part:GetNetworkOwner()`).
- **Pruebas (simulador):** el mock **reproduce el fallo real** (Jump y `Sit = false` no liberan, solo destruir el `SeatWeld`). Cubren
  botón, salto (`JumpRequest`), volver a sentarse, cooldowns, asiento ocupado, no liberar a otros, asiento ajeno al club, argumentos
  manipulados, spam de `Stand`/E/salto, liberación por otra vía y salida del servidor sentado.

## Novedades de la 2.1.3 (revisión estática antes de habilitar Robux: libro de recibos duradero)
**Problema encontrado:** `Inventory.recordReceipt` borraba los `PurchaseId` más antiguos al superar `MaxReceipts = 300`. Un callback
repetido de Roblox de un recibo antiguo habría podido **conceder otra vez** lo ya pagado.
**Corrección (sin cambiar otras funciones; las compras reales siguen desactivadas, `ProductId = 0`):**
- **Libro de recibos duradero y sin purga.** Todos los `PurchaseId` pagados se guardan en el mismo registro y en la **misma escritura
  atómica** (`UpdateAsync` con alquiler de sesión) que los vales/artículos: o se guardan los dos o ninguno. No hay escrituras
  separadas ni protocolo de recuperación que hacer. Los guardados/renovaciones/liberaciones hacen la **unión** con el libro
  almacenado, así que nunca se pierde un id.
- **Tope con fallo cerrado, nunca purga silenciosa.** `Config.Data.MaxReceipts = 20000` (≤ 64 caracteres por id ⇒ ~1,6 MB, muy por
  debajo de los 4 MB de una clave). Al llegar al tope: un recibo **nuevo** devuelve `NotProcessedYet` (no se concede y Roblox lo
  reintenta), un recibo **ya conocido** sigue devolviendo `PurchaseGranted` sin conceder otra vez, y se avisa por `warn` (también al
  90 %, `ReceiptWarnFraction`). Un `PurchaseId` vacío o de más de `MaxReceiptIdLength = 64` también falla cerrado.
- **No se ofrecen cobros nuevos si no se puede garantizar guardar.** `Inventory.canTakePayment` exige DataStore real (no memoria),
  sesión cargada con alquiler propio y hueco en el libro; si no, la tienda no llama a `PromptProductPurchase` y avisa al jugador.
- **Recibos de prueba Studio separados de los pagados.** Las concesiones gratis de `StudioTestMode` ya **no llevan `PurchaseId`
  ni entran en el libro**: solo suman al contador `tg` y solo se admiten con `RunService:IsStudio()`. Un id con prefijo `STUDIO-`
  nunca se acepta como recibo. Además, **en Studio se usa siempre otro DataStore**
  (`Config.Data.StudioStoreName = "AlfombraRoja_Inventory_v2_STUDIO"`), así que las pruebas jamás tocan los registros de
  producción.
- **Migración:** los registros antiguos (con `receiptOrder`, hasta 300 ids) se cargan tal cual; `rcount` se recalcula del propio
  libro y `receiptOrder` se descarta en el siguiente guardado, sin perder ningún id. **Atención:** los recibos que la versión
  anterior ya hubiera purgado (si algún jugador superó 300 compras reales con ella) no se pueden recuperar; con
  `ProductId = 0` no hay ninguno.
- **Antes de habilitar Robux**, además: crea los Developer Products, pega los `ProductId` en `Catalog.Products`, prueba un cobro real
  con una cuenta de prueba en un servidor publicado y revisa el `warn` de libro lleno en tu monitorización. El tope de 20000
  recibos por jugador es una decisión de diseño: si lo vieras acercarse, hay que migrar el libro (p. ej. a un OrderedDataStore/segundo
  registro con protocolo de recuperación) **antes** de subirlo.
- Pruebas (simulador): 350 recibos únicos (> 300) con repetición del primero y de los intermedios sin incrementar saldo; rejoin;
  callback reintentado; fallo del DataStore a mitad; libro lleno exacto (nuevo → `NotProcessedYet`, conocido → confirmado, sin
  prompts); id enorme y prefijo de prueba; registro antiguo con 300 ids; separación de almacenes Studio/producción.

## Novedades de la 2.1.2 (baile compatible con el rig R15 actual)
**QA real aportada por el usuario sobre la 2.1.0/2.1.1 (no repetida por mí):** la cabina abre (`InputHoldBegin` 0,8 s) y el preset
Discoteca oscura funciona desde la UI; los 2 focos siguieron al personaje (ambos `SpotLight.Enabled = true`, error horizontal final de
cada `FollowTarget` 0,072 studs tras un `MoveTo` de 35,2 studs); en esa instancia, con calidad gráfica puesta en Manual 8 desde el menú
(estaba en Automático), la medición de 6 s fue ≈ 60 FPS parado y en movimiento. **Eso no es una garantía:** otros equipos y zonas no
están medidos, y el código no cambia ni fuerza la calidad gráfica.
**Fallo confirmado y corregido:** *Bailar → Disco clásico* ponía `Character.AR_Dance = "disco"` pero el personaje no se animaba. El
avatar real era R15 con **cero `Motor6D`**, 15 `AnimationConstraint` (Root, Waist, Neck, RightShoulder, LeftShoulder, LeftHip, RightHip,
LeftElbow, RightElbow…) y 14 `BallSocketConstraint`; `DancePoses.new` solo buscaba `Motor6D` y devolvía `nil` sin avisar.
- **Doble backend** (`DancePoses.luau`): detecta `Motor6D` **y** `AnimationConstraint` por nombre de articulación (R6 y R15 clásicos
  siguen usando `Motor6D.C0`, sin cambios). Con `AnimationConstraint` **no se toca C0/C1/Part0/Part1 (solo lectura)**: se escribe
  `Transform = C0⁻¹ · pose`, que es el canal que usa el Animator.
- **Orden de fotograma:** el Animator reescribe `Transform` antes de la simulación, así que el baile se aplica en
  `RunService.PreSimulation` (no en Heartbeat) y se **mezcla con la pose actual del Animator** (reposo/andar) según el peso, sin
  acumularse; si el Animator no escribió ese fotograma se parte de la identidad.
- **Limpieza:** al parar de bailar, al echar a andar (el servidor corta el baile) o al destruirse el personaje, `Motor6D.C0` vuelve
  al valor original y `AnimationConstraint.Transform` a la identidad; las articulaciones sin padre se ignoran.
- **Nunca más en silencio:** si un avatar no tiene articulaciones reconocidas, el cliente avisa por `warn` con el recuento de
  Motor6D/AnimationConstraint y muestra un aviso al jugador; `print` indica qué backend usa cada avatar bailando. Sigue sin haber
  ningún id de animación inventado (`Config.Dance.Dances[i].AnimationId` es opcional y está vacío).
- **Documentación oficial:** desde este entorno **no pude abrir** las páginas de create.roblox.com (sin acceso de red a ese dominio);
  me apoyé en los resúmenes de búsqueda de la referencia de `AnimationConstraint` (propiedad `Transform`, `C0/C1/Part0/Part1` de solo
  lectura por compatibilidad, `IsKinematic`, `MaxForce/MaxTorque`) y en la evidencia del propio QA. Hay un reporte en DevForum de que
  con *Server Authority* no se puede escribir `Transform` mientras suena una animación: este club no activa Server Authority, pero
  si lo activas vuelve a probar el baile.
- **Sin validar en Studio:** la corrección está probada solo en el simulador (rig R15 moderno simulado, con C0 de solo lectura que
  lanza error si se escribe). No sé si los demás jugadores ven el baile en tu pantalla con constraints (los clientes remotos
  animan localmente y el dueño del personaje replica sus piezas): **compruébalo con 2 clientes**.

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
| `LaAlfombraRoja_v2.1.6.rbxlx` | Place **listo para abrir** (versión actual): todos los Script, LocalScript y ModuleScript ya colocados. `LaAlfombraRoja_v2.1.5.rbxlx`, `LaAlfombraRoja_v2.1.4.rbxlx`, `LaAlfombraRoja_v2.1.3.rbxlx`, `LaAlfombraRoja_v2.1.2.rbxlx`, `LaAlfombraRoja_v2.1.1.rbxlx`, `LaAlfombraRoja_v2.1.0.rbxlx` y `LaAlfombraRoja_v2.rbxlx` son entregas anteriores y se conservan. |
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
| **Libro de recibos duradero**: >300 recibos únicos, repetir el primero/intermedios sin incrementar saldo, rejoin, reintento tras fallo, tope exacto con fallo cerrado (nuevo → NotProcessedYet, conocido → confirmado, sin prompts), id inválido, migración de registros antiguos, recibos de prueba Studio fuera del libro y almacén de pruebas separado | ✅ 27 + 1 (simulado) | ❌ (cobros reales: **nunca probados**, siguen desactivados) |
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
| **Baile con rig R15 moderno (AnimationConstraint, 0 Motor6D)**: reconocimiento, Transform sin tocar C0 (solo lectura), mezcla con Animator simulado sin acumulación, limpieza al parar/caminar/destruir, rig desconocido con aviso, R6 y R15 clásico intactos | ✅ (simulado) | ❌ (**solo QA del fallo; la corrección aún no se ha probado en Studio**) |
| **Asientos**: sentarse con E, salir con botón/salto/`JumpRequest` validado en servidor, cooldowns, volver a sentarse, ocupados, no liberar a otros, asiento ajeno, spam (el mock reproduce el asiento anclado «pegado» observado en Studio) | ✅ 26 + 9 cliente (simulado) | ❌ (**la corrección aún no se ha probado en Studio**; causa raíz sin confirmar) |
| **Pantallas NowPlayingL/R orientadas al público** (normal +Z, visibles desde la cámara del QA, barras planas sin audio) y monitor del DJ hacia el operador | ✅ (simulado) | ❌ (**la corrección aún no se ha visto en Studio**; evidencia previa del usuario con `Face = Back` solo en QA) |
| Arranque aislado de módulos del cliente, registro tardío de focos, luces de acceso vs relleno con oscuridad máxima, menos exposición (valores de `Lighting`/bloom) | ✅ | ❌ (**el aspecto real de la exposición no se ha visto**) |
| Pruebas de sabotaje (56 mutaciones, todas detectadas) | ✅ | n/a |
| Ejecución real, rendimiento/FPS, colisiones, red, multijugador | ❌ | ❌ |

Totales actuales (simulador): servidor 133, VipUpgrade 32 (×2 perfiles), asientos 26, persistencia 33, libro de recibos 27, sin DataStore 14, Studio temporal 8 + 3 (producción), cliente 101, mundo 169 (×2 perfiles), archivos 14 comprobaciones, 56 sabotajes detectados. **Ninguno es una prueba en Studio.**

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
11. Baile: que el avatar R15 moderno (AnimationConstraint) baile bien en TU cliente y en el de otros jugadores, en pie y al reaparecer; que al andar vuelva a su postura; avatares con accesorios/capas.
12. Asientos: que «Levantarse» y la barra espaciadora liberen en Studio (y en móvil), que el punto de salida no quede incrustado en la barra/sofás, y que el cooldown no resulte molesto (`Config.Seats`).
13. Concurrencia real del DataStore (dos servidores a la vez, rejoin rápido, `BindToClose` real).

## Ejecutar las pruebas (opcional, necesita el intérprete `luau`)
```
python3 tools/assemble_tests.py tests/t_server.luau /tmp/s.luau && luau /tmp/s.luau
python3 tools/assemble_tests.py tests/t_persist.luau /tmp/p.luau && luau /tmp/p.luau
for t in vip seats ledger nostore studiotemp studiotemp_prod; do python3 tools/assemble_tests.py tests/t_$t.luau /tmp/$t.luau && luau /tmp/$t.luau; done
python3 tools/assemble_tests.py tests/t_client.luau /tmp/c.luau && luau /tmp/c.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/w.luau && luau /tmp/w.luau
python3 tools/assemble_tests.py tests/t_world.luau  /tmp/wa.luau --set 'Quality="Alta"' && luau /tmp/wa.luau
python3 tools/make_place.py && python3 tools/check_files.py
LUAU=luau python3 tools/mutation_tests.py
```
