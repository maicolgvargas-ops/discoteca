# MAYA CLUB — discoteca de 3 pisos para Roblox (Luau)

**Versión LUXURY:** negro lacado, marfil, cromo y latón; mucho menos neón; bola de espejos de ~175 facetas; mobiliario blanco y negro pulido. Detalles en la sección "Estilo luxury".

Versión profesional basada en el logo adjunto (monograma "M" geométrico plateado con acentos violeta y cian + texto **MAYA CLUB**). Se construye **100 % por código**: un único `Script` genera todo al darle a Play. No necesita ningún asset de Roblox.

> **Qué se ha probado y qué no.** Todo lo de este documento marcado como "comprobado" se verificó con el **simulador** (`tests/run.sh`: el script se ejecuta contra un mock de la API de Roblox con el CLI de Luau). **No he abierto Roblox Studio** ni hay físicas ni render reales en esa prueba: el aspecto visual, el rendimiento real y la colisión con avatares reales siguen pendientes de tu prueba en Studio (F5). La versión anterior (2868 partes / 141 luces) sí la ejecutaste tú sin líneas rojas.

## Resumen de cambios (v. AURA CLUB → MAYA CLUB)

| Área | Antes | Ahora |
|---|---|---|
| Edificio | 100 × 100 por piso | **160 × 160 por piso**, 3 pisos (y 0 / 24 / 48), layout rediseñado |
| Terreno | 200 × 258 | **256 × 334** (X −128..128, Z −128..206) con muro de 10 + barrera invisible hasta y = 70 |
| Pasillos | 4–8 | **principales ≥ 8, secundarios ≥ 6**, lounges separados ≥ 22 y mesas altas ≥ 16 entre centros |
| Pista LED | 12×12 de 64×64 | **16×16 baldosas (256) en 64×64**, base de mármol, juntas, cristal ahumado, bisel metálico e hilo de neón |
| Parqueadero | coches de bloques | **20 deportivos** (3 siluetas, 4 colores) en **36 plazas de 10 × 20** |
| Marca | AURA CLUB | **MAYA CLUB** en fachada, rooftop, DJ, 8 monogramas, señales y UI |
| Totales (mock) | 2868 partes / 141 luces | **5214 partes / 172 luces** |

## Identidad MAYA CLUB

- **Monograma por geometría** (`monogram`): dos barras exteriores y dos diagonales en V de metal plateado con respaldo de neón violeta, núcleo central y trazos cian, sobre placa azul marino. **8 monogramas**: fachada, 2 en el lobby, 2 junto al escenario, 2 en el VIP y 1 en el rooftop.
- **Texto cromado** ("MAYA CLUB") con degradado plata en el letrero de la fachada, el rooftop, el frente del DJ y la pantalla LED.
- **UI** (`StarterGui/MayaClubUI`): banner con el título MAYA CLUB y el monograma.
- **Logo opcional con imagen:** `assets/MayaClub_logo_reference.png` es el PNG de referencia. Para usarlo: sube la imagen a tu cuenta en *Create → Creator Dashboard → Decals/Images*, copia el ID y ponlo en `CONFIG.LogoImageId` (`"rbxassetid://123"`, `"123"` o `123`). Entonces el letrero principal y la UI muestran la imagen además del texto. **Vacío por defecto: nunca se inventa un ID**; sin él se usa el monograma de piezas.

## Edificio de 160 × 160

| Piso | Qué hay |
|---|---|
| **1** (y 0) | Lobby con alfombra, taquilla y guardarropa; **pista LED 64×64** bajo un atrio de doble altura; **escenario DJ** (68×14) con pantalla LED, truss con focos, altavoces colgados, **bola de espejos**, **6 láseres**, estrobos y humo; **barras este y oeste**, booths y listones acústicos |
| **2** (y 24) | **VIP**: 14 lounges con sofás, mesas y velas, barra VIP con trasbarra, balcón con barandilla de cristal sobre la pista, cuerdas con postes |
| **3** (y 48) | **Rooftop**: DJ elevado, barra, piscina de neón, fire pits, tumbonas, parapetos de cristal |

- **Escaleras:** P1→P2 en el lado este (sube al norte) y P2→P3 en el oeste (sube al sur); **10 studs de ancho**, 24 peldaños de 1 stud, **descansos de 10×10 libres** en cada extremo, pasamanos y ≥ 7 studs de altura libre.
- **Pasillos:** el comprobador recorre el edificio con un cuerpo de **7 studs** (pasillos de 8) y de **5 studs** (pasillos de 6), más amplio que dos avatares cruzándose (2 × 2). Nadie tiene que saltar muebles.
- **Accesos a pie** comprobados a las 4 barras, taquilla, guardarropa, escenarios, piscina y los descansos de las escaleras.

## Parqueadero premium

- **20 coches deportivos** con siluetas distintas: *Ferrari* (central, bajo y ancho, parabrisas muy inclinado, tomas laterales, alerón, 4 pilotos redondos), *Ford GT* (cabina en gota, caderas anchas, arbotantes, dos pilotos circulares, ala) y *Mustang* (capó largo, parrilla con barra cromada, fastback, franjas, 3 pilotos por lado). Cada uno lleva faldones, espejos, faros, antinieblas, escapes, 4 neumáticos con llanta y buje. Colores **rojo, azul, blanco y negro**; cristal translúcido y metal/pintura con reflectancia equilibrada.
- **Tamaño real:** carrocería de ~7 × 16 studs (≈ 1,9 × 4,5 m con 1 stud ≈ 0,28 m). Solo la carrocería baja y la cabina colisionan.
- **Plazas de 10 × 20** con líneas, líneas frontales y topes de rueda; calle interior de 28, flechas de sentido, entrada (este) y salida (oeste) con pórtico y cartel, 2 plazas **accesibles** azules (siempre libres) junto al camino peatonal central, bordillos, aceras, setos, árboles, farolas y señalización.
- **Ruta peatonal sin escalones** (> 0,35 studs): puerta → acera → paso elevado → acera exterior → camino del parqueadero.

## Pista de baile LED

- Base de mármol oscuro reflectante, **256 baldosas** con juntas de 0,5, damero con la mitad más tenue, **cristal ahumado** encima (reflejos), bisel metálico y 4 tiras de neón que ciclan.
- Animación coherente: una **onda radial desde el centro** con matiz cian→violeta lento. Brillo máximo 0,85 (nada sobreexpuesto); el bloom (0,45 / 20 / 1,0) no tapa texturas.
- Haces de láser y conos de los focos **translúcidos** en 3 capas (nucleo ≥ 0,55, media ≥ 0,8, halo ≥ 0,9 de transparencia); no ocultan a los avatares.

## Halloween y cristalería (conservados y adaptados)

Calabazas con cara y llama parpadeante, velas, telarañas, murciélagos, guirnaldas y calderos, repartidos por el espacio ampliado, sin colisión. Vasos de cristal (tumbler, highball, copa y chupitos) con base, pared translúcida, borde, líquido, hielo, pajillas, rodajas y posavasos, en las 4 barras; decorativos y sin colisión.

## Estilo luxury (renderizado y acabado)

- **Paleta:** negro lacado, marfil, cromo y latón/champán. Los antiguos acentos magenta/cian/violeta pasan a oro rosa, hielo y lila suave; los neones animados oscilan despacio entre champán y blanco hielo (nada saturado). El monograma conserva un violeta suave como guiño al logo.
- **Menos neón:** marcos, esquinas, remates, filetes de techo y tiras ahora son **latón pulido** (Metal), no neón; los pasamanos son cromo; los anillos de altavoz, discos del DJ, zócalos de sofá y pies de mesa dejan de brillar. Las baldosas LED bajan a un máx. de 0,7 (onda champán → hielo) y el bloom a 0,3. Piezas Neon totales: **1369 → 1081** (incluye 256 baldosas, peldaños y Halloween); los neones no-Halloween saturados desaparecen.
- **Bola de espejos:** 175 facetas cuadradas de 0,92 en 11 anillos de latitud (desfasados como ladrillo), `Metal` con `Reflectance = 1`, alternando dos tonos de plata para que cada faceta se lea; núcleo oscuro mate (las juntas se ven negras), casquete/motor y varilla cromados, **dos focos de acento** que la bañan y luz puntual interior. Gira a 0,4 rad/s.
- **Mobiliario blanco y negro, pulido:** sofás (cuero lacado negro / marfil, vivo dorado, zócalo cromado), mesas bajas de **mármol blanco**, mesas altas **lacadas en negro**, taburetes de cuero negro con pie cromado, barras con cuerpo negro lacado y encimera de mármol blanco, tumbonas marfil, estanterías lacadas, suelo de mármol negro con `Reflectance 0,24`.
- **Iluminación:** ambiente casi neutro cálido, `ColorCorrection` con tinte cálido y saturación −0,08, atmósfera ahumada cálida, luces de relleno blancas/cálidas, reflejos al máximo (`Reflections = 1`). Cócteles en tonos ámbar, burdeos, menta, rosado y hielo.
- Todos los ajustes siguen en `CONFIG.Look`; para volver a más color sube `TileBrightness` y `Bloom`.

## Instalación

Elige **una**:

**A. Pegar el script (recomendado)** — en **ServerScriptService → Insert Object → Script**, nómbralo `MayaClub`, y pega el contenido de `MayaClub.server.luau`.
**B. Insertar `MayaClub.rbxmx`** — clic derecho en ServerScriptService → *Insert from File…*.
**C. Abrir `MayaClub.rbxlx`** como place nuevo (ya trae el Script y `Lighting.Technology = Future`).

Los archivos se generan con `tools/make_place.py` (XML validado, Source idéntico al `.luau`); **no se han abierto en Studio**. Si alguno no carga, usa la opción A.

## Ejecutar

1. **Lighting.Technology = Future** (el `.rbxlx` ya lo trae; en A/B ponlo tú: un script no puede cambiarlo).
2. Pulsa **Play (F5)** y abre **View → Output**. Debe aparecer:
   ```
   [MayaClub] Sin musica: CONFIG.MusicId esta vacio (opcional). Pon un audio que puedas usar.
   [MayaClub] listo: 5214 partes, 172 luces, 3 pisos.
   ```
   No debe haber líneas rojas. Si las hay, copia el texto con su número de línea.
3. Con Play se borran el `Baseplate` y el `SpawnLocation` de la plantilla (`RemoveTemplateObjects = false` para conservarlos).

## Configuración (`CONFIG`)

| Opción | Efecto |
|---|---|
| `MusicId` | Opcional, vacío por defecto. Acepta `"rbxassetid://123"`, `"123"` o `123`. Usa solo audios con permiso. |
| `LogoImageId` | Opcional, vacío por defecto. Imagen del logo ya subida (ver arriba). |
| `MusicVolume` | Volumen (0–10). |
| `TileCount` | Baldosas por lado (16). Bájalo a 8 si hay poco rendimiento. |
| `LowPerformance` | `true` = animaciones a la mitad de frecuencia. |
| `Boundary` | Barrera invisible sobre el muro perimetral. |
| `RemoveTemplateObjects` | Borra Baseplate y SpawnLocation de la plantilla. |

### `CONFIG.Look` (luces y render)

| Ajuste | Por defecto | Efecto |
|---|---|---|
| `LightIntensity` | 1.0 | Multiplica el brillo de todas las luces. |
| `AmbientBoost` | 1.0 | Multiplica el ambiente base (sube si el interior se ve oscuro). |
| `Exposure` | 0.5 | `Lighting.ExposureCompensation`. |
| `Bloom` | `{0.45, 20, 1.0}` | Intensidad, tamaño y umbral. |
| `BeamTransparency` | 0.0 | Se suma a la transparencia de los láseres. |
| `BeamBrightness` | 1.0 | Emisión de luz de láseres y conos. |
| `BeamWidth` | 1.0 | Grosor de láseres y conos. |
| `ShaftTransparency` | 0.0 | Se suma a la transparencia de los conos de los focos. |
| `TileBrightness` | 0.85 | Brillo máximo de las baldosas. |
| `KeyShadows` | true | Sombras en las 12 luces clave (con Future o ShadowMap). |
| `Reflections` | 1.0 | `EnvironmentSpecularScale`. |
| `ShadowSoftness` | 0.35 | Suavidad de sombras. |

## Comprobaciones realizadas (simulador, sin Studio)

```bash
tests/run.sh        # requiere `luau` (https://github.com/luau-lang/luau/releases) y python3
```

El script se ejecuta contra `tests/mock_roblox.luau`, que rechaza clases, propiedades y miembros de `Enum` inexistentes y valida rangos. **146 comprobaciones, todas OK:**

- **Tamaños:** losas de 160 × 160 en los 3 pisos; terreno 256 × 334; suelo en todo el terreno; perímetro sin huecos (muro hasta y = 10 + barrera hasta 70, muestreo cada 2 studs); el área alcanzable a pie queda dentro del muro.
- **Rutas (BFS por celdas de 1 stud):** desde el spawn se alcanzan escenario, pista, pisos 2 y 3, DJ del rooftop, piscina, las 4 barras, taquilla, guardarropa y los 4 descansos; >90 % de las celdas planas de cada piso. Con cuerpo de 7 studs se recorre el piso 1 y cada nivel desde el descanso de su escalera; con cuerpo de 5 studs, los 3 pisos. Ruta sin escalones del club al parqueadero.
- **Escaleras:** 24 peldaños de 1 stud y 10 de ancho, altura libre ≥ 7 studs, descansos libres.
- **Coches:** 20, 3 siluetas, 4 colores, cada uno con 4 neumáticos/llantas/bujes, cabe en su plaza de 10 × 20 con ≥ 0,7 de holgura lateral, sin solapes, plazas accesibles libres, altura ≤ 4,6.
- **Identidad:** sin rastro de "AURA" en nombres ni textos, 8 monogramas, "MAYA CLUB" en letreros y UI; con `LogoImageId` definido aparecen las `ImageLabel` (variante probada aparte).
- **Luces:** 170 (límite 260), cobertura ≥ 90 % de las celdas caminables por piso y ≥ 85 % en el exterior, 12 luces con sombra, ~1915 escrituras de propiedades/s (límite 2600), haces y bloom dentro de los valores indicados.
- **Animación:** 90 s simulados sin errores, láseres dentro del atrio, pista LED animada sin sobreexposición, bola de espejos girando; ninguna pieza visible flota; relanzar no apila conexiones.
- **Sabotaje:** versiones rotas a propósito (coches solapados, sin barrera, puerta tapada, baldosa sobreexpuesta) hacen fallar los tests esperados.
- `luau-compile` OK; `luau-analyze` sin avisos salvo las globales de Roblox que no conoce; archivos generados válidos (`tests/check_files.py`).

**Límite:** el mock no renderiza ni simula físicas. No sustituye una prueba visual en Studio.
