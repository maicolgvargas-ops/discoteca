# EventDecor 1.0.0 — instrucciones breves

**Archivo:** `EventDecor.luau` → créalo como `ModuleScript` (p. ej. `ReplicatedStorage/AlfombraShared/EventDecor` o `ServerScriptService/.../EventDecor`).
Solo se usa en el **servidor** (crea Parts ancladas). Autocontenido: sin `require`, sin assets/IDs, sin HTTP, sin scripts, sin luces, sin bucles en ejecución.

```lua
local EventDecor = require(game.ReplicatedStorage.AlfombraShared.EventDecor)
local parent = workspace.LaAlfombraRoja.Floor3          -- cualquier Folder/Model/Workspace
local piano = EventDecor.buildPiano(parent, CFrame.new(10, 48, -20) * CFrame.Angles(0, math.pi, 0))
local perro = EventDecor.buildRottweiler(parent, CFrame.new(0, 0, 90))
local banos = EventDecor.buildBathroom(parent, CFrame.new(-60, 24, 20))
```
`cf` es el origen local, **siempre en el suelo (y local = 0)**. Opcional: tercer argumento `{ solid = true, name = "..." }` (`solid` hace colisionable también el mobiliario; por defecto **no**).
Cada función devuelve el `Model` (con `PrimaryPart`) y lo deja parentado en `parent`.

| Función | Local (sin rotación) | Dimensiones aprox. | Colisión |
|---|---|---|---|
| `buildPiano` | teclado en z = 0, cuerpo hacia **+Z**, banco con `Seat` en z ≈ −1,7 mirando al teclado | 5,3 × 9,4 (con banco) × 3,5 (6,5 con tapa) | ninguna (el `Seat` no colisiona) |
| `buildRottweiler` | sentado, mira hacia **−Z** | 2,2 × 4,2 × 3,6 | ninguna |
| `buildBathroom` | **entrada hacia −Z** (2 aberturas de 8 × 9 en z = −14), x −16…16, z −14…14, y 0…12 | 32 × 28 × 12 (suelo con cara superior en y = 0; la losa baja a −0,4) | suelo, muros, dinteles, techo y tabiques de las cabinas |

Contenido: **piano** de cola de caoba brillante con tapa inclinada 36° y puntal, 88 teclas (52 + 36), 3 patas, lira con 3 pedales dorados, atril y banco negro con `Seat`; **Rottweiler** negro y fuego (hocico, orejas caídas, collar con chapa, 4 patas con zarpas, cola corta), estático y manso; **baños** con 2 cabinas privadas (puerta de 3,75 de ancho, abierta), 2 inodoros decorativos (no `Seat`), 3 lavabos con espejo y marco dorado + tira LED `Neon` (sin luz real), carteles «BAÑOS» (SurfaceGui con texto), suelo de mármol negro con filetes dorados. No hay cámaras ni mecánicas íntimas.

## Qué hay que mirar al integrar (NO se ha probado en Studio)
Solo se ha ejecutado en un simulador (geometría, límites, solapes, colisiones, alcance de las aberturas con cuerpos de 2/2,5/3,5 de ancho, 42 comprobaciones + análisis estático; 9 sabotajes detectados). **No es un render ni una prueba de Studio.**
1. **Huecos y solapes** con tu copia: el baño ocupa 32 × 28 × 12 exactos; el piano ~ 5,3 × 9,4; comprueba que no cortan paredes, losas, escaleras ni lounges. Los muros del baño y el techo colisionan.
2. **Proporciones a ojo:** escala del perro y del piano frente a los avatares; altura del banco (`Seat` a 2,05 sobre el suelo local) y que el avatar sentado alcance el teclado.
3. **Acabado:** brillo de la caoba (`Reflectance 0,22`), marcos LED `Neon` y mármol con tu iluminación/Future; sin luces nuevas, el interior del baño depende de la luz que ya tengas (las tiras `Neon` del techo solo brillan visualmente).
4. **Orientación** con `cf` girado (el módulo respeta cualquier `CFrame`; comprueba que la entrada del baño queda donde quieres).
5. **Coste móvil:** piano 174 piezas, perro 36, baño 97 (sin luces ni emisores; solo la arquitectura proyecta sombra). Mide en tu base.
6. Si necesitas que el mobiliario sea sólido, pasa `{ solid = true }`.

Alcance: este módulo es **solo** la decoración pedida. El resto del pedido (boletería/VIP de pago, mensajes privados, luces reactivas a la música, piscina/rooftop/evento, esfera descendente, plataforma elevable) no está en este archivo y no se ha tocado ningún cargo ni compra.
