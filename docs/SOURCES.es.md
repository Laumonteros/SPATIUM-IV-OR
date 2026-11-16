# Fuentes, licencias y atribuciones

Todo recurso externo se revisa antes de incorporarse y se registra acá.

## Software y addons incluidos
| Recurso | Versión | Licencia | Ubicación |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | MIT | (externo, no se versiona) |
| Terrain3D (Tokisan Games) | 1.1.0 stable | MIT | `game/addons/terrain_3d/` |
| GUT – Godot Unit Test (bitwes) | 9.7.1 | MIT | `game/addons/gut/` |

## Datos científicos
Cada entrada indica el conjunto de datos, la URL, la fecha y el tipo (`REAL_DATA` / `ADAPTED` / `GAMEPLAY_VALUE`).

| Uso en el juego | Dato | Tipo | Fuente |
|---|---|---|---|
| Hielo de agua (descripción) | LCROSS detectó ~5,6 ± 2,9 % de agua en masa en el material expulsado del cráter Cabeus (2009) | REAL_DATA | Colaprete et al., *Science* 330 (2010); https://science.nasa.gov/mission/lcross/ |
| Muestra geológica (descripción) | Las misiones Apollo trajeron 382 kg de material lunar | REAL_DATA | NASA Astromaterials Curation, https://curator.jsc.nasa.gov/lunar/ |
| Regolito (descripción) | El oxígeno es ~40-45 % de la masa del suelo lunar, ligado químicamente | ADAPTED (redondeado) | *Lunar Sourcebook* (Heiken, Vaniman y French, 1991), LPI |
| Hierro (descripción) | La ilmenita (FeTiO₃) de los basaltos de mar contiene hierro, titanio y oxígeno | ADAPTED | *Lunar Sourcebook*, LPI |
| Gravedad lunar | 1,62 m/s² | REAL_DATA | Valor estándar (NASA Moon Fact Sheet) |
| Morfología de cráteres | Profundidad ~0,2 D; borde ~0,036 D; tamaños N(>D) ∝ D⁻² | ADAPTED | Proporciones de cráteres simples lunares; el terreno es procedimental y ficticio |
| Tamaño de la Tierra en el cielo | Real: ~1,9° de diámetro. En el juego se amplía 2,4× por legibilidad | ADAPTED | — |
| Evento solar (radiación) | DONKI (tormenta de mayo de 2024): FLR 2024-05-11T01:10Z → SEP >100 MeV (GOES) 02:10Z; tormenta geomagnética Kp 9 | REAL_DATA | NASA CCMC DONKI vía https://api.nasa.gov/DONKI/ (consultado el 2026-11-15) |
| Dosis de fondo en la superficie lunar | ~1369 µSv/día (~2,6 × ISS) | REAL_DATA | Zhang et al., *Science Advances* 6 (2020), Chang'e 4 LND |
| Intensidad del pico de la tormenta y factores de blindaje (15 % / 45 %) | Equilibrio del juego | GAMEPLAY_VALUE | — |
| Temperaturas lunares, polvo, destellos Apollo, hielo polar (enciclopedia) | Hechos documentados | REAL_DATA | NASA Science, informes Apollo, LRO Diviner, LCROSS |
| Duración del día lunar (misión 3) | ~29,5 días terrestres (mes sinódico) | REAL_DATA | Valor astronómico estándar |
| Cantidades por depósito, límite de carga (120 kg) | Equilibrio del juego | GAMEPLAY_VALUE | — |
| Fichas de rocas: regolito de tierras altas y basalto de mar (composición) | Óxidos de suelos de Apolo 16 y basaltos de alto Ti de Apolo 11, redondeados | ADAPTED | *Lunar Sourcebook* (Heiken, Vaniman y French, 1991), LPI |
| Ficha de ilmenita | FeTiO₃: 52,7 % TiO₂ y 47,3 % FeO en masa (estequiometría); reducción con H₂ a ~900 °C | REAL_DATA | *Lunar Sourcebook*, cap. 5 |
| Ficha de hielo de agua | 5,6 ± 2,9 % de agua en masa (Cabeus, LCROSS) | REAL_DATA | Colaprete et al., *Science* 330 (2010) |
| Fichas de brecha y anortosita | Edades de ~3.900 y ~4.000 millones de años; muestra 15415 «Roca Génesis» | REAL_DATA / ADAPTED (proporciones minerales aproximadas) | NASA Lunar Sample Compendium, https://curator.jsc.nasa.gov/lunar/lsc/ |
| Cultivos del domo (referencias) | Lechuga de Veggie (~28-33 días), tomate enano VEG-05, rabanito en Plant Habitat-02 (27 días), trigo enano «Apogee», papa y soja en cámaras de KSC | ADAPTED (los ciclos se comprimen a minutos) | NASA Space Station Research; NASA KSC |
| Ficha de la Tierra (binoculares) | Distancia media 384.400 km; diámetro 12.742 km; retardo de la luz 1,28 s; día sideral 23 h 56 min; gravedad 9,81 m/s²; ~1,9° vista desde la Luna. La fase se calcula con las direcciones del Sol y de la Tierra del cielo del juego | REAL_DATA (fase: cálculo geométrico en vivo) | NASA NSSDCA — Earth Fact Sheet y Moon Fact Sheet |
| Fichas de planetas (binoculares) | Distancias a la Tierra, diámetros, rotación, año, gravedad, temperatura y lunas de Venus, Marte, Júpiter y Saturno | REAL_DATA | NASA NSSDCA — Planetary Fact Sheet |
| Tamaño y posición de los planetas en el cielo | Discos ampliados para verse con binoculares; posiciones elegidas para el juego (Venus cerca del Sol) | GAMEPLAY_VALUE | — |
| Fulguraciones de los sucesos | X5.8 (2024-05-11), X8.7 (2024-05-14), X9.0 (2024-10-03), X9.3 (2017-09-06), X8.2 (2017-09-10) | REAL_DATA (archivado, no en vivo) | NASA CCMC DONKI (FLR) |
| Polvo lunar en paneles, micrometeoritos, sismos superficiales, destellos de impacto | Fenómenos documentados (Apollo, ISS, Apollo Passive Seismic Experiment, NASA Lunar Impact Monitoring); intensidades y costos del juego | ADAPTED / GAMEPLAY_VALUE | NASA |
| Objetivos de telescopio | Distancia Tierra-Luna 384.400 km; Júpiter a 588-968 millones de km; M42 a ~1.344 años luz; M31 a ~2,5 millones de años luz | REAL_DATA | NASA NSSDCA Fact Sheets; NASA Hubble Messier Catalog |
| Curvatura visual del planeta: radio de 1 km (la Luna real mide 1.737 km de radio) | Equilibrio del juego: con el radio real no se vería la curvatura a escala humana | GAMEPLAY_VALUE | — |
| Colonia: consumo de cada módulo, blindaje por módulo (8 % a 60 %), tiempos de crecimiento y fabricación, costos en datos científicos, entrega de suministros | Equilibrio del juego | GAMEPLAY_VALUE | — |
| Rendimientos de la base (0,15 kg O₂ por kg de regolito, 1,2 L de agua por unidad de hielo, 3 kW por panel, 10 kWh por batería), ritmos de consumo del traje, 1 s real = 1 min de juego | Equilibrio del juego (tiempo comprimido) | GAMEPLAY_VALUE | — |

> El cráter "Albor" y su hielo son ficticios: la ubicación del hielo en sombra permanente se inspira en los cráteres polares reales, pero es una decisión de juego.

Fuentes previstas: NASA DONKI, NASA Moon Trek / LRO LOLA, Curiosity RAD (PDS PPI), NASA Image and Video Library, NASA 3D Resources, NASA OSDR, NTRS.

> Nota de uso: el material de NASA en general no tiene copyright en EE. UU., pero **los logos e insignias de NASA no pueden usarse** de forma que sugiera respaldo oficial. Las imágenes con personas identificables o de terceros tienen restricciones propias: revisar cada una.

## Modelos, texturas, imágenes, tipografías y sonidos
Solo se aceptan licencias CC0, CC-BY (con atribución acá) o material propio.

| Recurso | Licencia | Autor / fuente | Ubicación |
|---|---|---|---|
| Texturas `moon_dusted_02` y `moon_03` (regolito y roca) | CC0 | Poly Haven (fotografía: Greg Zaal, Rico Cilliers; Jenelle van Heerden) — https://polyhaven.com | `game/assets/textures/terrain/` (empaquetadas por `tools/pack_terrain_textures.py`) |
| Mapa estelar "Deep Star Maps 2020" (4k) | Dominio público (NASA) | NASA/Goddard Space Flight Center Scientific Visualization Studio — https://svs.gsfc.nasa.gov/4851 | `game/assets/textures/sky/nasa_starmap_2020_4k.png` |
| Texturas de la Tierra (día y nubes, 2k) | **CC BY 4.0** — requiere atribución | Solar System Scope (basadas en datos de NASA) — https://www.solarsystemscope.com/textures/ | `game/assets/textures/sky/earth_*_2k.jpg` |
| Exo 2, Inter, JetBrains Mono | SIL Open Font License 1.1 | Google Fonts (licencias incluidas junto a cada fuente) | `game/assets/fonts/` |
| Astronauta, rocas y depósitos | Propio | Generados por `tools/blender/*.py` | `game/assets/models/`, `art_source/blender/` |
| Efectos de sonido | Propio | Sintetizados por `tools/generate_sfx.py` | `game/assets/audio/sfx/` |
| Voces de Control de misión (inglés y español) | Propio | Síntesis de voz de Windows (voces «Microsoft David» y «Microsoft Sabina», `tools/generate_voice_tts.ps1`) + efecto de radio propio con tonos Quindar (`tools/generate_voice_radio.py`) | `game/assets/audio/voice/` |
| Texturas de módulos (revestimiento, chapa de piso, losa de regolito) | Propio | Procedurales, `tools/generate_module_textures.py` | `game/assets/textures/modules/` |

Nota: se intentó usar la Blue Marble de NASA Earth Observatory para la Tierra, pero el servidor no respondía desde el entorno de desarrollo. Si se consigue más adelante, se puede reemplazar (es de dominio público).
