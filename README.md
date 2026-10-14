# AURA CLUB — discoteca de 3 pisos para Roblox (Luau)

Discoteca estilo "Aura Club" (neón púrpura/magenta/cian, pista LED, lasers, VIP de cristal y rooftop) construida **100 % por código**: un único `Script` que genera todo al darle a Play.

| Piso | Qué hay |
|---|---|
| **1** (y 0) | Hall con alfombra roja y cola de terciopelo, **pista LED 12×12** animada, **escenario DJ** con pantalla LED gigante, altavoces, truss con focos/estrobos, **6 lasers** que barren la pista, barra con botellas, booths y mesas altas |
| **2** (y 24) | **VIP lounge** de cristal con **balcón** sobre la pista (atrio de doble altura), barra VIP dorada, 8 lounges con sofás y lámparas |
| **3** (y 48) | **Rooftop**: escenario DJ con arco y cartel, barra, **piscina** neón, fire pits con fuego, loungers, macetas |

Escaleras: P1→P2 al este, P2→P3 al oeste (24 peldaños de 1 stud). Spawn en el hall, entrada por el sur (+Z).

## Cómo usarlo

**Opción A – abrir el place:** abre `AuraClub.rbxlx` en Roblox Studio y pulsa **Play**.
*(Generado con `tools/make_place.py`; no he podido abrirlo en Studio desde el entorno donde lo creé.)*

**Opción B – copiar el script:** crea un `Script` en `ServerScriptService` y pega `src/ServerScriptService/AuraClub.server.luau`. Dale a Play.

**Opción C – Rojo:** `rojo serve` con `default.project.json`.

### Música
`CONFIG.MusicId` está vacío a propósito (no puedo verificar IDs de audio desde aquí). Pon un `rbxassetid://…` de un audio que puedas usar y sonará en los altavoces de la pista y del rooftop.

### Notas
- Por defecto borra el `Baseplate` y el `SpawnLocation` de la plantilla (`CONFIG.RemoveTemplateObjects`).
- El script es idempotente: al relanzarlo reemplaza el modelo anterior.
- Las animaciones (baldosas, neones, lasers, estrobos) corren en el servidor a 5–20 Hz. Si quieres más suavidad, muévelas a un `LocalScript`.
- Suelo/techos y huecos se generan con `slab()`; todo el club son ~890 partes y 44 luces.

## Tests (sin Studio)

```bash
tests/run.sh        # requiere el binario `luau` (https://github.com/luau-lang/luau/releases)
```

Ejecuta el script contra un **mock de la API de Roblox** (`tests/mock_roblox.luau`, que rechaza clases, propiedades y miembros de `Enum` inexistentes) y comprueba: geometría válida, los 3 pisos y sus huecos (atrio, escaleras, piscina), puerta libre, escaleras de 1 stud hasta el piso siguiente, **alcanzabilidad a pie** (BFS con cuerpo 2×2 desde el spawn hasta escenario, VIP, rooftop, barras y piscina), 90 s simulados de animación sin errores, lasers siempre dentro del atrio y que los estrobos/colores cambian.

**Límite:** el mock no renderiza ni simula físicas; no sustituye una prueba visual en Studio.
