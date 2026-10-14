# AURA CLUB — discoteca de 3 pisos para Roblox (Luau)

Discoteca de ambiente oscuro (neón, trusses, altavoces colgados, VIP cálido) construida **100 % por código**: un único `Script` que genera todo al darle a Play.

| Piso | Qué hay |
|---|---|
| **1** (y 0) | Hall con alfombra y cola con cuerdas, **pista LED 12×12**, **escenario DJ** con pantalla LED, truss reticulado con focos, **altavoces colgados**, **bola de espejos giratoria**, **6 lasers**, estrobos, humo, barra con botellas, booths, listones acústicos y neón rosa en el techo |
| **2** (y 24) | **VIP cálido** de cristal: 8 lounges con sofás naranja, almohadones y **cuerdas con postes dorados**, barra VIP, balcón sobre la pista, neón en el techo |
| **3** (y 48) | **Rooftop**: DJ con arco y cartel, barra, piscina de neón, fire pits, tumbonas, humo, macetas |

Escaleras: P1→P2 al este y P2→P3 al oeste, de **10 studs de ancho** (antes 8), 24 peldaños de 1 stud, con **descansos de 10×10** libres en la entrada y la llegada de cada tramo, pasamanos de neón y ≥ 8 studs de altura libre (antes ~7 y sin descansos). Los huecos de los pisos 2 y 3 miden 10×20. Spawn en el hall; la entrada está al sur (+Z).

**Bar:** vasos de cristal (tumbler, highball, copa de cóctel y chupitos) con base gruesa, pared translúcida, borde, líquido de colores con brillo, hielo, pajillas y rodajas, sobre posavasos con aro de neón; bandejas de chupitos y un caldero con humo. Son decorativos y no colisionan, así que no bloquean la barra.

**Halloween:** calabazas con cara y luz parpadeante (entrada, escenario, altavoces, pista —colgadas del truss—, barras y mesas), velas en las mesas del VIP y los booths, telarañas en las esquinas del techo, murciélagos (paredes, atrio y arco del rooftop), guirnaldas naranja/morado (entrada y barra) y detalles naranja en las puertas y los descansos. Todo es sin colisión y no invade pasos, escaleras ni la pista.

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

1. **Lighting.Technology = Future.** El `.rbxlx` ya lo trae (sin esa propiedad Studio abría el place con *Compatibility* y lo migraba a *Voxel*). Si usas la opción A o B, ponlo tú en **Lighting → Technology** (un script no puede cambiarlo). Guarda el place después para que se conserve.
2. Pulsa **Play** (F5) en la pestaña Home, no Run.
3. Abre **View → Output**. Debe aparecer:
   ```
   [AuraClub] Sin musica: CONFIG.MusicId esta vacio (opcional). Pon un audio que puedas usar.
   [AuraClub] listo: 2868 partes, 141 luces, 3 pisos.
   ```
   No debe haber líneas rojas. Si las hay, copia el texto completo con su número de línea.
4. Con **Play** el script borra el `Baseplate` y el `SpawnLocation` de la plantilla (los sustituye por el suelo y el spawn del club). Si quieres conservarlos, pon `RemoveTemplateObjects = false` en `CONFIG`.


## Mundo exterior: calles, parqueadero y perímetro

Todo el terreno mide **200 × 258 studs** (X −100..100, Z −100..158) y está cerrado por un **muro de 10 studs** con pilares y neón, más una barrera invisible hasta y = 70 (no se puede saltar ni caer al vacío).

- **Calles:** anillo de calzada de 20 studs alrededor del club (carril doble, eje amarillo discontinuo, líneas de borde blancas y líneas de detención), con **aceras interiores y exteriores** y **bordillos** de 0,5 studs.
- **Pasos de peatones elevados:** 4 en el anillo y 1 sobre la calle interior del parqueadero. Están **a ras de las aceras** (sin escalones), alineados con la puerta del club.
- **Conexión peatonal:** puerta del club → acera → paso de peatones → acera exterior → camino central del parqueadero (8 de ancho), todo sin escalones > 0,35 studs.
- **Parqueadero:** 2 filas de 16 plazas de 8×14 con líneas, calle interior de 24, **2 plazas accesibles** azules junto al camino peatonal con su cartel, 15 coches aparcados, **entrada** (este) y **salida** (oeste) con pórtico y cartel, señal de PARE, setos y árboles.
- **Señalización:** ENTRADA/SALIDA, PARE, PEATONES (8 señales), PARQUEADERO ↓ / AURA CLUB ↑, ACCESIBLE y nombres de calle.
- **Iluminación exterior:** 25 farolas con luz real (alcance 48) en calles, aceras, plaza y parqueadero. El 100 % de la ruta peatonal tiene una luz cerca.

## Ajustes de luces y render (`CONFIG.Look`)

Los haces de los láseres ahora son **3 capas de `Beam` translúcidas** (núcleo fino, capa media y halo ancho) con degradado que se desvanece en el origen y la punta; se ve a través de ellos. Los focos tienen un **cono de luz muy tenue**. Se reduce el bloom (intensidad 1,3 → 0,45; tamaño 42 → 20; umbral 0,85 → 1,0) y el brillo de las baldosas.

| Ajuste | Por defecto | Efecto |
|---|---|---|
| `LightIntensity` | 1.0 | Multiplica el brillo de **todas** las luces (0.5 = mitad). |
| `AmbientBoost` | 1.0 | Multiplica el ambiente base: sube si el interior se ve oscuro. |
| `Exposure` | 0.5 | `Lighting.ExposureCompensation`. |
| `Bloom` | `{0.45, 20, 1.0}` | Intensidad, tamaño y umbral del bloom. |
| `BeamTransparency` | 0.0 | Se **suma** a la transparencia de los láseres (+0.05 = más transparentes, −0.1 = más sólidos). |
| `BeamBrightness` | 1.0 | Multiplica la emisión de luz de láseres y conos (0–2). |
| `BeamWidth` | 1.0 | Multiplica el grosor de láseres y conos. |
| `ShaftTransparency` | 0.0 | Se suma a la transparencia de los conos de los focos. |
| `TileBrightness` | 0.85 | Brillo máximo de las baldosas LED. |
| `KeyShadows` | true | Sombras en las 8 luces clave (solo se ven con `Technology = Future` o `ShadowMap`). |
| `Reflections` | 1.0 | `EnvironmentSpecularScale`: reflejos en suelos y cristal. |
| `ShadowSoftness` | 0.35 | Suavidad de las sombras. |

## Si el interior se ve muy negro

- **Comprueba la versión:** el Output debe decir `listo: 2868 partes, 141 luces`. Si dice `1495 partes` o `1472 partes`, estás ejecutando un archivo antiguo: descarga de nuevo.
- **Qué pasaba:** los neones y las baldosas brillan pero **no iluminan**. Solo el 32 % de la pista, el 52 % del VIP y el 18 % del rooftop tenían una luz cerca, así que el interior se veía negro hasta que el motor terminaba de calcular la iluminación. Ahora hay una rejilla de luces de relleno por piso (9 por piso, tono morado/rosa, suave) y el ambiente base es más alto (`Ambient` 46,32,78). El test de cobertura exige ≥ 90 % de celdas caminables con luz; está al 100 % en los 3 pisos.
- **Los primeros segundos:** en Voxel/Compatibility la luz se calcula de forma asíncrona y puede tardar unos segundos tras entrar. Con *Future* es inmediato.
- **Más claro:** sube `Lighting.Ambient` o `ExposureCompensation` en `buildLighting`, o el brillo de `fillGrid` (último argumento). **Más oscuro:** al revés.

## Configuración (`CONFIG`, al principio del script)

| Opción | Efecto |
|---|---|
| `MusicId` | **Opcional**, vacío por defecto (no se incluye ningún ID). Acepta `"rbxassetid://123"`, `"123"` o `123`. Usa solo audios que tengas permiso de usar. |
| `MusicVolume` | Volumen (0–10). |
| `TileCount` | Baldosas de la pista (por lado). Bájalo a 8 si hay poco rendimiento. |
| `LowPerformance` | `true` = animaciones a la mitad de frecuencia. |
| `Boundary` | Barrera invisible (y 10–70) sobre el muro perimetral para que no se pueda saltar ni escalar. |
| `Look` | **Ajustes de luces y render**: ver la tabla de abajo. |
| `RemoveTemplateObjects` | Borra `Baseplate` y `SpawnLocation` de la plantilla. |

Colores: tabla `C` (colores fijos), `cycleColor` y `glowColors` (neones que ciclan), y el cálculo de `hq` en `startAnimations` (baldosas).

## Auditoría y comprobaciones realizadas (sin Studio)

```bash
tests/run.sh        # requiere `luau` (https://github.com/luau-lang/luau/releases) y python3
```

El script se ejecuta contra un **mock de la API de Roblox** (`tests/mock_roblox.luau`) que rechaza clases, propiedades y miembros de `Enum` inexistentes y valida **rangos** (rango de luces ≤ 60, `Angle` ≤ 180, `Transparency` 0–1, bloom, atmósfera…). Comprobaciones (128 en total, todas OK):

- **Escaleras:** ancho ≥ 10, descansos 10×10 libres de sólidos, altura libre ≥ 7 studs sobre cada peldano (mínimo medido 8.0), ≥ 8 celdas caminables a lo ancho, pasillos laterales de ≥ 4 studs y P1→P2→P3 conectados a pie. **Vasos:** bordes, paredes translúcidas, ≥ 5 colores de líquido, hielo, pajillas, posavasos, sin colisión y ≤ 4 studs sobre la barra. **Halloween:** calabazas, velas, telarañas, murciélagos, guirnaldas y calderos presentes y sin colisión; pista libre de sólidos.
- Geometría válida (tamaños/posiciones finitos, todo `Anchored`), 3 pisos con sus huecos (atrio, escaleras, piscina), puerta libre.
- Escaleras de 1 stud hasta el piso siguiente y **alcanzabilidad a pie** (BFS con cuerpo 2×2 desde el spawn hasta escenario, VIP, rooftop, barras y piscina).
- **Ninguna pieza visible flota** sin apoyo (el test detecta los fallos de la versión anterior).
- 90 s simulados de animación sin errores; lasers siempre dentro del atrio; estrobos **nacen apagados** y parpadean en ráfagas; la bola de espejos gira.
- Presupuesto de red: ~1560 escrituras de propiedades/s (< 1700) y 141 luces (< 150).
- Relanzar el script no duplica nada: 1 modelo, 4 efectos de iluminación, 1 conexión activa.
- **Mundo exterior:** perímetro sin huecos (muro + barrera, muestreado cada 2 studs), suelo en todo el terreno, el área alcanzable a pie queda dentro del muro, ruta peatonal **sin escalones** de la puerta al parqueadero, plazas, coches sin solapes, plazas accesibles libres, señalización, farolas y luz en la ruta exterior. **Haces:** transparencia mínima por capa, degradado, grosor, emisión, bloom y los 12 ajustes de `Look`.
- **Pruebas de sabotaje:** 8 versiones rotas a propósito (sin muro, láseres sólidos, bloom alto, paso sin elevar, coche en plaza accesible, escalera estrecha, sin barrera, sin farolas) hacen fallar los tests esperados.
- **Cobertura de luz** ≥ 90 % de las celdas caminables por piso, ambiente base legible, y los archivos generados (`tests/check_files.py`): XML válido, Source idéntico al `.luau` y `Lighting.Technology = Future`.
- `luau-compile` OK y `luau-analyze` sin avisos (salvo las globales propias de Roblox, que el analizador no conoce).

**Límite:** el mock no renderiza ni simula físicas. No sustituye una prueba visual en Studio.
