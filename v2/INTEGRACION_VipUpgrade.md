# VipUpgrade 1.0.0 — parche aditivo para La Alfombra Roja

Un único `ModuleScript`: **`ReplicatedStorage/AlfombraShared/VipUpgrade`** (archivo `VipUpgrade.luau`). No sustituye ni modifica ningún otro
módulo (música, inventario, chat, compras, permisos, esfera, logo, muebles). Solo **añade** una carpeta `Workspace.LaAlfombraRoja.VipUpgrade`.

## Qué hace
1. **Cierre de cristal del VIP** (y = 24 → techo inferior y = 46) alrededor del atrio `LAYOUT.atrium`: **4 paneles**, cada uno **una sola pieza
   colisionable** (`CanCollide = true`, `Glass` negro pulido, `Transparency = 0`), a 0,5 studs *fuera* del atrio (la barandilla existente queda
   dentro). W/E se alargan como N/S para que las esquinas queden cerradas.
2. **Efecto «polarizado» solo visual y local:** el cliente fija `BasePart.LocalTransparencyModifier` de cada panel según de qué lado está **tu
   cámara**: cámara en el VIP → casi transparente (0,88, ves la pista); cámara en la pista → negro. **No** cambia nunca `Transparency` global, ni
   la de otros jugadores, ni permisos. **No es privacidad real:** un cliente modificado vería a través; es presentación.
3. **Aros de fuego** (3 en *Equilibrado*, 4 en *Alta*) colgados del techo del VIP: anillo dorado + banda interior negra (12/16 segmentos), 3
   varillas negras hasta el techo, **llamas pequeñas** (`ParticleEmitter`, 6/8 por aro, **sin daño**: ni `Fire`, ni `Explosion`, ni `Touched`) y
   **una `PointLight` cálida por aro, sin sombras**. Todo con `CanCollide/CanTouch/CanQuery = false` (no bloquea cámara ni circulación). Cada aro se
   comprueba contra la geometría existente (`GetPartBoundsInBox`) y **se omite con un `warn`** si choca con algo.
4. **Calidad:** Equilibrado/Alta solo cambia cuántos aros/segmentos/llamas se construyen y a qué distancia se animan las llamas (90 / 140 studs, local).
   **No toca** `UserGameSettings`, `RenderSettings`, resolución ni calidad gráfica, y no hay ningún script que baje gráficos.

Coste aproximado (del simulador, no medido en Studio): Equilibrado **88 piezas**, 18 emisores, **3 luces nuevas**; Alta **148 piezas**, 32 emisores,
**4 luces nuevas**. Recuerda sumar esas luces a tu presupuesto (en mi base: 146 → 149 Equilibrado, 192 → 196 Alta).

## Integración mínima (2 líneas)
**Servidor** — en tu `init.server` (o donde construyas), **después** de `Build.run` y de `Control.init`:
```lua
local VipUpgrade = require(game.ReplicatedStorage.AlfombraShared.VipUpgrade)
pcall(VipUpgrade.build, ctx)   -- ctx = lo que devuelve Build.run (usa ctx.club, ctx.LAYOUT.atrium, ctx.PROFILE_NAME)
```
(Si usas tu `safe(...)`: `safe("VipUpgrade", function() VipUpgrade.build(ctx) end)`.) Se llama **después de `Control.init`** a propósito: así `Control.tag`
no registra las luces de los aros como luces de zona regulables y no pelean con el parpadeo propio del módulo.

**Cliente** — en tu `LocalScript` principal, con el club ya en `Workspace`:
```lua
pcall(function() require(game.ReplicatedStorage:WaitForChild("AlfombraShared"):WaitForChild("VipUpgrade")).initClient() end)
```
Aísla la llamada en `pcall` como el resto de módulos. Sin la llamada de cliente el cristal queda **negro por los dos lados** (fallo seguro) y las llamas
no se apagan por distancia.

### Ajustes (opcionales)
`build(ctx, { quality = "Alta", FloorY = 24, CeilingY = 46, Glass = { ClearTransparency = 0.85, Exterior = false }, Rings = { Positions = { {-55,-24}, ... } } })`
y `initClient({ Glass = { Hysteresis = 0.4, UpdateHz = 10 } })`. Los diccionarios se mezclan en profundidad; las listas (`Positions`, colores `{r,g,b}`) se
sustituyen enteras. Valores por defecto en `VipUpgrade.Config`.
- Si tu `Floor2`/techo no son `y2 = 24` / `y = 46`, pásalos (`FloorY`, `CeilingY`).
- `Glass.Exterior = true` añade una piel interior en el muro exterior (±80) con la misma lógica «negro desde fuera, transparente desde dentro».
  **Desactivada por defecto:** revisa antes cómo es tu fachada (ventanales, escaleras junto al muro).
- Etiquetas y atributos (por si lo quieres integrar con tu propio código): `AR_VipGlass` (`nx`, `nz`, `wall`), `AR_VipRing` (`cx`,`cy`,`cz`,`cull`),
  `AR_VipFlame` (emisores), `AR_VipFlameLight` (`base`, `phase`).
- Quitar el parche: borra la carpeta `VipUpgrade` y las dos llamadas.

## Lo que se ha probado (SIMULADOR, no Studio)
Un simulador de Luau con una API de Roblox simulada (no es un render ni Studio): 4 paneles únicos colisionables del suelo VIP al techo; normal del lado claro
hacia el VIP; esquinas cerradas; sin solapes con piezas colisionables existentes; aros por calidad (3/4), piezas y varillas hasta el techo, 1 luz **sin
sombras** por aro, nada colisiona/es tocable/consultable; omisión de un aro bloqueado; reconstrucción idempotente; opción exterior; selección de lado por cámara con
histéresis; `Transparency` global intacta; culling de llamas por distancia y calidad; parpadeo acotado (78–100 %); coste de escrituras bajo con cámara quieta;
`destroy()`. Navegación (cuerpos 1/2,5/3,5), pasillos, escaleras, piezas flotantes y cobertura de luz del club siguen pasando con el parche. 56 sabotajes
(incluidos los de este módulo) se detectan. **Todo eso es simulado.**

## Pruebas REALES de Studio que quedan por hacer
1. **Cristal:** ¿`LocalTransparencyModifier` sobre `Material.Glass` con `Transparency = 0` se ve realmente transparente desde el VIP y negro desde la pista? Mira de día/noche,
   con `Technology = Future`, reflejos (`Reflectance 0,18`), brillos y bordes; si el `Glass` negro no se ve bien opaco, prueba `Material = SmoothPlastic`.
2. **Lados y transición:** cámara en tercera persona al pegarte al cristal por ambos lados; sin parpadeo al acercar/alejar la cámara; zoom/`Poppercam` no se
   queda «dentro» del cristal; cámara en primera persona; móvil y mando.
3. **Colisión y circulación:** recorrer todo el anillo VIP, saltar contra el cristal, subir/bajar escaleras S1/S2, barra VIP, sofás, asientos y cuerdas; que no haya
   rendijas en las esquinas ni en la unión con suelo/techo; que nadie pueda quedar atrapado entre barandilla y cristal.
4. **Visión desde la pista:** mirar hacia el VIP desde varias posiciones (esfera, focos rojos, láseres): que el negro no «tape» luces que deberían verse y que no
   aparezca z-fighting con la barandilla.
5. **Aros:** aspecto de las llamas con la textura por defecto del `ParticleEmitter` (tamaño, brillo, color), altura (13 studs sobre el suelo), que no choquen con
   lámparas colgantes, sofás ni la escalera (revisa los `warn` de aros omitidos en *Output*), que la cámara no quede tapada y que las varillas no estorben.
6. **Rendimiento (nada medido):** *MicroProfiler* y *Script Performance* con 1/10/30 jugadores, Equilibrado vs Alta; coste de los emisores y de las 3–4 luces; que
   apagar por distancia funcione; revisa que no se pase tu presupuesto de luces.
7. **Varios clientes:** cada jugador ve el cristal según **su** cámara; el modificador no se replica; sin interferir con `StreamingEnabled` (si lo usas, paneles y aros
   llegan por streaming y se registran al aparecer).
8. **Compatibilidad con tu base:** presets *Discoteca oscura* (las luces de los aros no se regulan por zona ni se atenúan), focos rojos de seguimiento, música/inventario/chat/compras
   sin cambios, y que `Control.tag` no haya registrado las luces de los aros (llamada **después** de `Control.init`).
9. **Seguridad/UX:** que nadie pueda quedarse bloqueado, que el cristal no tape prompts (`ProximityPrompt`) de asientos/barra del VIP cercanos al atrio.
