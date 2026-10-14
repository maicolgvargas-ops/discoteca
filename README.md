# AURA CLUB — discoteca de 3 pisos para Roblox (Luau)

Discoteca de ambiente oscuro (neón, trusses, altavoces colgados, VIP cálido) construida **100 % por código**: un único `Script` que genera todo al darle a Play.

| Piso | Qué hay |
|---|---|
| **1** (y 0) | Hall con alfombra y cola con cuerdas, **pista LED 12×12**, **escenario DJ** con pantalla LED, truss reticulado con focos, **altavoces colgados**, **bola de espejos giratoria**, **6 lasers**, estrobos, humo, barra con botellas, booths, listones acústicos y neón rosa en el techo |
| **2** (y 24) | **VIP cálido** de cristal: 8 lounges con sofás naranja, almohadones y **cuerdas con postes dorados**, barra VIP, balcón sobre la pista, neón en el techo |
| **3** (y 48) | **Rooftop**: DJ con arco y cartel, barra, piscina de neón, fire pits, tumbonas, humo, macetas |

Escaleras: P1→P2 al este, P2→P3 al oeste (24 peldaños de 1 stud). Spawn en el hall; la entrada está al sur (+Z).

## Instalación (tu Place1 con Baseplate + SpawnLocation)

Elige **una**:

**A. Pegar el script (recomendado, no toca el resto de tu lugar)**
1. En **Explorer**, clic derecho en **ServerScriptService → Insert Object → Script**. Ponle el nombre `AuraClub`.
2. Abre `AuraClub.server.luau` en un editor de texto, selecciona todo (Ctrl+A), copia (Ctrl+C), y pégalo sustituyendo el contenido del Script.

**B. Insertar `AuraClub.rbxmx`**
1. Clic derecho en **ServerScriptService → Insert from File…** y elige `AuraClub.rbxmx`.
2. Debe aparecer un `Script` llamado `AuraClub`. Si aparece en otro sitio, arrástralo a **ServerScriptService**.

**C. Abrir `AuraClub.rbxlx`** como place nuevo (ya trae el Script en ServerScriptService).

*(Los archivos `.rbxmx` y `.rbxlx` los generé con `tools/make_place.py` y comprobé que el XML es válido y que el Source es idéntico al `.luau`, pero **no los he abierto en Studio**. Si alguno no carga, usa la opción A.)*

## Ejecutar y comprobar

1. En **Lighting**, pon **Technology = Future** (no se puede cambiar desde script; es lo que da sombras y reflejos reales).
2. Pulsa **Play** (F5) en la pestaña Home, no Run.
3. Abre **View → Output**. Debe aparecer:
   ```
   [AuraClub] Sin musica: CONFIG.MusicId esta vacio (opcional). Pon un audio que puedas usar.
   [AuraClub] listo: 1472 partes, 73 luces, 3 pisos.
   ```
   No debe haber líneas rojas. Si las hay, copia el texto completo con su número de línea.
4. Con **Play** el script borra el `Baseplate` y el `SpawnLocation` de la plantilla (los sustituye por el suelo y el spawn del club). Si quieres conservarlos, pon `RemoveTemplateObjects = false` en `CONFIG`.

## Configuración (`CONFIG`, al principio del script)

| Opción | Efecto |
|---|---|
| `MusicId` | **Opcional**, vacío por defecto (no se incluye ningún ID). Acepta `"rbxassetid://123"`, `"123"` o `123`. Usa solo audios que tengas permiso de usar. |
| `MusicVolume` | Volumen (0–10). |
| `TileCount` | Baldosas de la pista (por lado). Bájalo a 8 si hay poco rendimiento. |
| `LowPerformance` | `true` = animaciones a la mitad de frecuencia. |
| `Boundary` | Muros invisibles alrededor de la calle. |
| `RemoveTemplateObjects` | Borra `Baseplate` y `SpawnLocation` de la plantilla. |

Colores: tabla `C` (colores fijos), `cycleColor` y `glowColors` (neones que ciclan), y el cálculo de `hq` en `startAnimations` (baldosas).

## Auditoría y comprobaciones realizadas (sin Studio)

```bash
tests/run.sh        # requiere el binario `luau` (https://github.com/luau-lang/luau/releases)
```

El script se ejecuta contra un **mock de la API de Roblox** (`tests/mock_roblox.luau`) que rechaza clases, propiedades y miembros de `Enum` inexistentes y valida **rangos** (rango de luces ≤ 60, `Angle` ≤ 180, `Transparency` 0–1, bloom, atmósfera…). Comprobaciones (50 en total, todas OK):

- Geometría válida (tamaños/posiciones finitos, todo `Anchored`), 3 pisos con sus huecos (atrio, escaleras, piscina), puerta libre.
- Escaleras de 1 stud hasta el piso siguiente y **alcanzabilidad a pie** (BFS con cuerpo 2×2 desde el spawn hasta escenario, VIP, rooftop, barras y piscina).
- **Ninguna pieza visible flota** sin apoyo (el test detecta los fallos de la versión anterior).
- 90 s simulados de animación sin errores; lasers siempre dentro del atrio; estrobos **nacen apagados** y parpadean en ráfagas; la bola de espejos gira.
- Presupuesto de red: ~1470 escrituras de propiedades/s (< 1700) y 73 luces (< 150).
- Relanzar el script no duplica nada: 1 modelo, 4 efectos de iluminación, 1 conexión activa.
- `luau-compile` OK y `luau-analyze` sin avisos (salvo las globales propias de Roblox, que el analizador no conoce).

**Límite:** el mock no renderiza ni simula físicas. No sustituye una prueba visual en Studio.
