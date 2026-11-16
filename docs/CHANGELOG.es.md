# Registro de cambios

## [1.0.0] — 2026-11-15 · Tutorial, campaña completa, helio-3 y regreso a la Tierra
- **Tutorial opcional** al empezar una partida nueva (8 pasos): caminar, escanear, recolectar, inventario, binoculares, reparto de energía, cultivar y volver a refugio.
- **Campaña de 13 misiones** (7 nuevas): mapear la región, agua en las sombras (cráter Albor), helio-3, mantenimiento (polvo en paneles), tormenta solar con **preaviso** y blindaje de regolito, ampliar la base y **volver a casa**.
- **Helio-3:** recurso nuevo, escaso y lejano (estrella dorada en escáner y mapa), con ficha científica; en el Taller alimenta una **celda experimental** (+20 kWh, tecnología futura: la fusión con helio-3 aún no existe).
- **Propelente y regreso:** el electrolizador del Taller convierte hielo en hidrógeno y oxígeno; con 5 tanques el **módulo Ariel despega** (cuenta regresiva por radio, ascenso filmado) y aparece el **resumen de la misión** (tiempo, dosis, datos, cosechas, logros).
- **Preaviso solar:** antes de cada fulguración, Control de misión avisa por radio y hay 45 s para preparar refugios.
- Las misiones pueden disparar sucesos (polvo, pronóstico solar) y el objetivo «mejora» verifica el blindaje de regolito.
- 3 mensajes de radio nuevos con voz en inglés y español (36 en total).
- Tests: 65 en verde.

## [0.12.0] — 2026-11-15 · Etapa 3: reparto de energía e invernadero jugable
- **Reparto de energía** (terminal del banco de baterías, o «Reparto de energía» desde la consola de estado): cuatro grupos —soporte vital y hábitats, hidroponía, ciencia y taller, comunicaciones— al 100 %, 50 % o apagados. Lo que se apaga deja de consumir **y deja de funcionar**: al 50 % la hidroponía crece a mitad de velocidad, el taller fabrica más lento y los pedidos a la Tierra tardan el doble; con comunicaciones apagadas no se puede pedir nada. El soporte vital nunca baja de 50 %. El panel muestra producción, consumo, si las baterías se cargan o **cuántas horas duran** con ese reparto, y una barra por grupo. Basado en el «load shedding» real de la Estación Espacial.
- **Invernadero jugable:** los bancales ya no se cosechan solos. Al madurar avisan; con E se cosecha (+raciones al almacén) y el bancal queda libre. Con E en un bancal vacío se elige qué plantar entre 6 cultivos de experimentos reales de NASA, cada uno con su costo: rápido o abundante, más o menos agua (lechuga 7 min/2 raciones … papa 15 min/5 raciones).
- **Decisiones con grilla** de hasta 3 opciones por fila.
- Tests: 65 en verde.

## [0.11.0] — 2026-11-15 · Etapa 2: sucesos aleatorios, radio con voz y decisiones con costo
- **Director de sucesos** (`systems/events/event_director.gd`): cada 2,5-5 min ocurre algo distinto (sorteo con pesos y tiempos de espera; cada partida es diferente):
  - **Fulguración solar real** (5 fulguraciones archivadas de NASA DONKI: X5.8 y X8.7 de mayo de 2024, X9.0 de octubre de 2024, X9.3 y X8.2 de septiembre de 2017). Decisión: reforzar el blindaje gastando 4 kWh de batería (mitad de dosis en refugio) o ahorrar energía.
  - **Polvo electrostático en los paneles** (problema real de Apollo): rinden 45 % menos hasta que se los limpia con E.
  - **Perforación por micrometeorito:** se escapa oxígeno de la colonia. Decisión: parchar ya con 2 de hierro o ir en persona (1 de hierro) mientras se pierde aire.
  - **Corte de comunicaciones** con la Tierra: no se pueden pedir suministros; al volver, recuerda el retardo de la luz.
  - **Destello de impacto:** aparece un cráter fresco con rayos de eyecta y 3 muestras nuevas, marcado en el mapa (NASA vigila estos destellos).
  - **Sismo lunar superficial** (registrados por Apollo): la cámara tiembla y puede abrir una fuga.
  - **Pedido científico** de la Tierra: una muestra geológica vale 6 datos científicos.
- **Radio de Control de misión** con voz grabada: 15 mensajes en **inglés y en español** (voz según el idioma elegido; inglés por defecto), tonos Quindar de Apollo, texto que se escribe mientras habla y onda animada. La bienvenida también habla en español si el juego está en español.
- **Decisiones de misión:** el juego se pausa y cada opción muestra qué gana (▲) y qué cuesta (▼), con la fuente del dato. Ninguna opción es gratis.
- **Idioma completo:** al cambiar de idioma se recarga el mundo para que carteles y pantallas 3D también cambien (desde el menú vuelve al menú; en partida guarda y retoma en el mismo lugar).
- Tests: 64 en verde (5 nuevos de sucesos).

## [0.10.0] — 2026-11-15 · Etapa 1: recursos, recolección e inventario
- **Hierro (ilmenita) que se distingue:** roca oscura con brillo metálico y cristales tabulares que reflejan el sol. Se agrupa en **vetas**; siempre hay una a 75-120 m de la colonia.
- **Más recursos:** regolito 26, hierro 30, muestras 22, hielo 12 depósitos (antes 16/14/14/7), además de los 160 bloques.
- **Cada partida es distinta:** el reparto usa una semilla nueva en cada partida (se guarda con ella) y cada recurso tiene una riqueza propia (×0,7 a ×1,4): un mundo puede ser rico en hielo y pobre en hierro. Los tests usan semilla fija.
- **Nada aparece dentro de la colonia:** la reserva de terreno ahora incluye cada módulo, instalación, plataforma y el módulo de alunizaje del plano.
- **Recolección con respuesta visual:** fragmentos del color del recurso viajan hasta la bolsa del traje y aparece «+5 Regolito»; la muestra de bonificación se anuncia aparte.
- **Inventario (Tab):** tarjetas por recurso con cantidad, masa, para qué sirve, dónde se encuentra y la fuente del dato (real / adaptado / valor de juego); barra de carga del traje y reservas de la colonia (oxígeno, agua, energía, raciones, datos científicos, kits).
- **Las cápsulas de suministro quedan:** al descargarlas quedan vacías, con la escotilla abierta y cajas al lado, alrededor de la plataforma (se guardan con la partida).
- Tests: 59 en verde.

## [0.9.0] — 2026-11-15 · Cielo procedural, planetas, fichas de rocas, escáner por tipo y minimapa con íconos
- **Se puede salir del módulo central:** cada lado del hábitat tenía la ventana alta y la puerta (o el túnel) en el mismo tramo, y el muro rellenaba con pared todo lo de abajo de la ventana: la puerta y los dos túneles quedaban tapados. Los muros ahora calculan el relleno vertical tramo por tramo (sirve para todos los módulos). Un test con la cápsula del astronauta confirma las tres salidas.
- **Paneles solares con 4 patas:** dos caballetes en los extremos sostienen un eje horizontal; el panel sigue al Sol en un eje con tope de ±60°, así nunca lo atraviesa un poste ni toca el suelo (antes giraba hasta quedar vertical sobre un poste central).
- **Cielo inmersivo:** estrellas puntuales procedurales en varias capas (pocas brillantes, muchas tenues, colores según temperatura, sin titilar porque no hay atmósfera), siempre nítidas y con más estrellas al hacer zoom; la Vía Láctea de la NASA queda como resplandor de fondo. La Tierra suma reflejo del sol en los océanos, sombra de nubes y terminador cálido.
- **Planetas:** Venus, Marte, Júpiter (bandas y Gran Mancha Roja) y Saturno (anillos con división de Cassini), con la fase calculada desde su distancia al Sol. Sin aumento son puntos brillantes; con binoculares, discos.
- **Fichas con binoculares** para la Tierra, cada planeta (datos de NASA Planetary Fact Sheet) y **cada roca**: qué da, composición, extracciones, rareza, si está escaneada, utilidad y fuente.
- **Escáner:** marca todas las rocas según lo que dan (también las de regolito), a medida que pasa la onda; cada recurso tiene color y forma propios y el aviso resume lo encontrado por tipo.
- **Minimapa con íconos por color:** hábitats, hidroponía, laboratorio, taller, baterías, paneles, comando, soporte vital, tripulación, rover, recursos y puntos de interés; el mapa completo (M) tiene leyenda.
- **Menú principal:** Empezar nueva partida · Continuar · Configuración · Salir. El modo evaluador pasó a una opción de Configuración.
- **Esc en partida:** «Salir» ya no cierra el juego: ofrece guardar y volver al menú principal, volver sin guardar, cerrar el juego o cancelar.
- **Interfaces:** paneles con acento lateral, esquinas y sombra; botones con resaltado al pasar el mouse y estilo de deshabilitado.
- Tests: 59 en verde.

## [0.8.0] — 2026-11-15 · Correcciones de la colonia, sol nuevo, Tierra con datos y voz de Control de misión
- **Rover:** se hundía bajo el terreno cuando el astronauta se alejaba (la colisión del suelo solo existe alrededor del jugador). Ahora, estacionado y a más de 40 m, queda congelado; si alguna vez quedó por debajo del relieve, vuelve a apoyarse sobre la superficie.
- **Entrada a la partida sin atravesar paredes:** la cámara ya no viaja en línea recta del menú al astronauta. Fundido a negro → toma exterior que se acerca al Hábitat Spatium → fundido → interior con la cámara del juego. «Continuar» también entra con fundido.
- **Voz de Control de misión** en inglés con sonido de radio espacial (banda de radio, siseo, cortes de señal y tonos Quindar como en Apollo), subtitulada en el idioma elegido. Los textos ya hablan de la colonia (antes mencionaban el módulo de alunizaje). Cualquier tecla salta la línea.
- **Sol nuevo:** disco con oscurecimiento hacia el borde, corona suave y seis rayos de difracción tenues; brillo moderado y bloom repartido en más niveles, así ya no aparecen los anillos concéntricos al mirarlo.
- **La Tierra con los binoculares:** al apuntarla aparece un círculo de seguimiento que se cierra sobre ella, una línea guía y una ficha al costado con datos reales (distancia, diámetro, retardo de la luz, día sideral, gravedad) y la fase iluminada calculada en vivo. Fuente: NASA, Earth Fact Sheet.
- **Texturas en los módulos:** revestimiento con paneles de 2 × 1 m, juntas, remaches y polvo lunar; chapa antideslizante en los pisos; losas de regolito; trama de tela en tapizados. Proyección triplanar (las piezas fusionadas siguen la misma grilla).
- **Menos neón:** emisión de lámparas, pantallas, LED de cultivo y holograma bajada a la mitad aproximadamente; luces del domo más tenues.
- **Carteles legibles:** todos los textos 3D de la colonia se dibujan al doble de resolución con contorno oscuro y recorte alfa. Los carteles de camino son más grandes (letra +30 %) y se ven hasta 45 m.
- **Puertas:** se abren y cierran consultando quién está cerca en cada paso de física (antes dependían solo de las señales de entrada/salida y a veces quedaban trabadas).
- **Hábitat:** los paneles solares del ala de soporte vital atravesaban el techo y aparecían dentro de la sala; ahora quedan por encima, con patas que llegan al techo.
- **Herramientas de revisión:** el recorrido `autopilot=colony` agrega tomas del rover, de la Tierra con binoculares y del Sol; `-- audit_float` lista piezas de los módulos que no tocan nada.
- Tests: 59 en verde.

## [0.7.0] — 2026-11-15 · Hábitat Spatium (diseño de referencia del equipo)
- **Hábitat Spatium** (`systems/colony/modules/spatium_habitat.gd`): nueva casa del jugador, armada a partir de la lámina de diseño del equipo. Reemplaza al monoblock del jugador; Inés y Tomás siguen en sus monoblocks.
  - Módulo central de 12 lados elevado sobre patas, con revestimiento blanco, franjas naranjas, ventanas reales, banda alta de ventanas y techo facetado de vidrio (se ven las estrellas y la Tierra). Arriba, un mástil con parabólica y antenas.
  - Escalera de acceso con barandas naranjas y marco de puerta octogonal.
  - Túneles presurizados a dos alas: **invernadero** con techo de vidrio y huerta personal (madura y se cosecha con E: +3 raciones), y **soporte vital** con tanques, equipos, una terminal con O₂, agua, raciones y batería, y paneles solares en el techo (cubren parte del consumo).
  - Torre-tanque al costado del invernadero.
  - Interior central: consola octogonal con globo holográfico tenue (estado de la colonia), cama, casilleros, cocina, sillones bajo las ventanas, plantas y anillo de lámparas.
- Los monoblocks de la tripulación llevan las mismas franjas naranjas (familia visual común).
- Plano: la planta de O₂ pasó detrás del hábitat (6; -9) y los caminos rodean las alas. El test de rutas confirma que nadie atraviesa paredes ni muebles.
- La misión 1 habla de alejarse del hábitat.
- Tests: 59 en verde.

## [0.6.0] — 2026-11-15 · Planeta curvo, barra de herramientas y base más ordenada
- **Planeta curvo (estilo Astroneer):** el suelo se curva hacia el horizonte y las montañas lejanas bajan detrás de él. Es una deformación visual de vértices (`autoload/curved_world.gd`, radio de juego de 1 km): la física sigue plana y cerca del astronauta la diferencia es de centímetros. Los materiales estándar se convierten a un shader equivalente con la curvatura (`systems/visual/curved_standard.gdshaderinc`); el terreno recibe la misma caída en su shader y los textos 3D se compensan cuadro a cuadro. La intro se ve plana.
- **Cámara al horizonte:** arranca casi a nivel (-5°), así el horizonte y la curvatura quedan al centro de la pantalla.
- **Barra de herramientas** abajo al centro, con ranuras cuadradas: 1 Mano (clic = agarrar/usar), 2 Escáner (clic o Q), 3 Binoculares (mantener clic = mirar lejos, con la distancia arriba de la ranura). Se cambia con 1-3, la rueda o la cruceta. **Se quitó el catalejo de la Z**, con su mira y su borde negro.
- **Sin neón:** las luces de los módulos son lámparas con emisión suave (ya no "unshaded"), las LED de cultivo son blanco rosado, y los colores de sector pasan a pintura mate apagada (postes, carteles, franjas de los tripulantes).
- **Parpadeo de texturas (z-fighting):** se separaron al menos 1 cm las capas casi coplanares (revestimientos interiores, franjas y alfombras del piso, pisos del domo, textos de pantallas y placas).
- **Carteles nuevos:** tablas oscuras con franja del color del sector, flecha física y texto centrado y legible en las dos caras («◀ Hidroponía · 58 m»), sin cortes. Se ubican solas fuera de todo camino.
- **Base menos apretada:** todas las distancias del plano se ampliaron ×1,6 (`data/colony/colony_layout.json`).
- **Colisiones:** radiadores, cajas eléctricas, barandas de rampas, postes de camino, bases de balizas, vallas, banquetas, respaldos de sillas y patas del cohete ahora bloquean al astronauta.
- **Tripulantes que atravesaban muebles:** se corrigieron sus recorridos (la mesa del monoblock salió del pasillo central) y un test nuevo barre con una cápsula cada tramo de las rutas de la tripulación y del bot contra paredes y muebles.
- **Tests:** 59 en verde.

## [0.5.0] — 2026-11-15 · Colonia lunar preinstalada: sectores, interiores, tripulación y mecánicas de base
Detalle completo y control de cambios (qué funciona por código y qué es decoración): [`docs/colonia_modulos.md`](colonia_modulos.md).
- **Nota:** los FBX que pedía el documento de módulos (`spatium_*.fbx`) son de la versión Unity y no están en la rama `godot`. Los módulos se arman por código con un kit modular (1 u = 1 m); un GLB futuro puede reemplazar cada exterior sin tocar la lógica.
- **Colonia instalada desde el minuto uno** en seis sectores (`data/colony/colony_layout.json`):
  - Residencial: 5 monoblocks (jugador + Inés + Tomás + 2 de reserva), planta de O₂ y tablero de distribución.
  - Hidroponía: cúpula geodésica con 6 bancales y almacén refrigerado conectado.
  - Energía: banco de baterías de 20 kWh y 2 paneles solares (el «puesto inicial» de la 0.4.0 pasó a este sector).
  - Investigación: laboratorio con fichas de rocas, estación de análisis y 2 observatorios.
  - Taller de fabricación.
  - Comando: cohete de 24 m con torre, elevador y cabina refugio. El módulo de alunizaje Ariel se movió a este sector.
- **Interiores recorribles y decorados, sin pantallas de carga:** esclusas de doble puerta, puertas automáticas de 1,3 × 2,25 m, ventanas reales con vidrio, camas, escritorios, cocinas, casilleros, estantes con objetos personales, cañerías y bandejas de cables, luces que pasan a emergencia sin energía y pantallas con telemetría real.
- **Cimentación sobre el relieve:** cada módulo se apoya sobre un zócalo que llega al punto más bajo del terreno, con rampas de 14° como máximo en cada puerta.
- **Refugio por volumen:** el traje se recarga y la radiación baja solo dentro del volumen presurizado de cada módulo, con blindaje propio (cabina del cohete 8 %, monoblock 15 %, laboratorio y taller 30 %, domo 60 %).
- **Cables físicos** entre paneles, banco y residencial: abrazaderas que se agarran y se reubican; largo máximo, nunca se desconectan.
- **Hidroponía continua:** crecimiento visible en 4 etapas con energía y agua, cosecha automática al almacén y excedente directo a la base.
- **Laboratorio:** 6 fichas de rocas con composición, utilidad, rareza y fuente; análisis de muestras; desafío de calibración y seguimiento con telescopios articulados.
- **Taller:** 13 recetas (kits de módulos, equipamiento y mejoras con efecto real), impresora 3D y brazo robótico animados mientras fabrica.
- **Comando:** guardado, pedidos a la Tierra pagados con datos científicos (cápsula que aluniza), estado de la colonia y consumo por sector.
- **Tripulación:** Inés Calvo (botánica) y Tomás Rivas (ingeniero) con rutinas reales entre su monoblock y su sector; informan datos reales al hablarles. Bot de servicio RX-1 patrullando.
- **Mapa:** caminos señalizados con balizas, flechas y distancias por sector; rocas fuera de sectores y caminos.
- **Cámara en interiores:** se acerca a 2,3 m. Inicio dentro del monoblock propio; el rescate de emergencia lleva ahí.
- **Misión 1:** los textos hablan de la colonia y de alejarse del monoblock (el módulo de alunizaje ya no está en el inicio).
- **Rendimiento:** fusión de mallas estáticas por material y distancia de detalle interior de 24 m (de ~2.450 a 600-1.060 llamadas de dibujo con la colonia completa; la escena sin colonia tenía ~370). En este equipo la escena con y sin colonia da 30 fps (límite de la ventana), así que falta medir en el equipo de referencia.
- **Herramienta de revisión:** `-- autopilot=colony shots=<carpeta>` recorre la colonia y guarda 18 capturas.
- **Tests:** 58 en verde (17 nuevos de la colonia sobre la escena real).

## [0.4.0] — 2026-11-15 · Intro nueva, puesto inicial, rocas recolectables y optimización
- **Intro cinematográfica rehecha:**
  - Negro, estrellas, paneo hasta la Tierra.
  - La nave Ariel se acerca desde el espacio, con el resplandor del motor.
  - Descenso con llama y polvo balístico.
  - Menú con la nave a la izquierda y la Tierra a la derecha.
- **Mini-intro al empezar:** tres mensajes de Control de misión mientras la cámara baja hasta el astronauta. Se puede saltar.
- **Puesto inicial:** un panel solar y un banco de baterías llegados en una misión de carga previa. Las misiones 3 y 6 se ajustaron a ese punto de partida.
- **Todas las rocas son recolectables:**
  - Los 160 bloques dan regolito (roca triturada).
  - Los grandes dejan una muestra de brecha al agotarse.
  - No aparecen en el escáner, para no saturar el HUD.
- **Materiales más realistas y livianos:**
  - Tela del traje con trama de tejido (normales y rugosidad 1K, CC0).
  - Cascos con imperfecciones suaves.
  - Lámina térmica dorada arrugada, generada por ruido procedural (sin texturas extra).
- **Optimización:**
  - Astronauta: de 38.900 a 24.100 triángulos. Hábitat: de 14.600 a 8.000.
  - Malla del terreno según el preset (24 / 32 / 48).
  - Se quitó la colisión de partículas del polvo, que volvía a dibujar el terreno al moverse.
  - El pedregullo y las rocas chicas ya no proyectan sombra.
  - Distancias de visibilidad (HLOD) en rocas, depósitos y estructuras.
  - Preset automático: GPU integrada → Bajo.
  - Resultado en el equipo de referencia, a 1080p: **Bajo ~70 fps, Medio ~47 fps**.

## [0.3.0] — 2026-11-15 · Radiación con datos reales, enciclopedia y acceso al cráter
- **Radiación espacial** (sección 12):
  - Dosis de fondo real: 1369 µSv/día, medida por Chang'e 4.
  - Evento solar que recrea la tormenta del 10-11 de mayo de 2024 con datos de NASA DONKI: fulguración, protones >100 MeV una hora después, Kp 9.
  - La hora real de aviso se convierte en 60 s de juego. Durante el evento hay alerta de Control de misión, banner con cuenta regresiva, contador Geiger y destellos de rayos cósmicos.
  - El blindaje es parcial: el hábitat deja pasar el 15 % de la dosis y el módulo el 45 %.
  - Al final llega un informe educativo.
  - Paquete de datos: `data/science/space_weather_may2024.json`.
- **Enciclopedia espacial (J):**
  - Nueve conceptos con fuente.
  - Fichas automáticas de recursos y estructuras.
  - Tipo de dato visible en cada ficha (real / adaptado / valor de juego).
- **Talud de acceso al cráter Albor:** las paredes tenían entre 49° y 66° y dejaban atrapado a quien bajara. El talud tiene 21° como máximo y mira hacia la base.
- **Cámara inicial** mirando al módulo, sin chocar con él.
- **Tests:** 39 en verde.

## [0.2.0] — 2026-11-15 · Etapas 2 a 5 (versión de entrega, alcance reducido)
- **Base lunar:**
  - Módulo de alunizaje "Ariel" como refugio inicial.
  - Cinco estructuras construibles, modeladas en Blender (`tools/blender/build_structures.py`):
    - Hábitat con escudo de sacos de regolito.
    - Panel solar que sigue al Sol y no produce si el relieve lo tapa.
    - Baterías.
    - Generador de O₂ a partir de regolito.
    - Extractor de agua a partir de hielo.
- **Construcción (B):** fantasma de colocación, rotación, validación (pendiente, superposición, obstáculos, materiales) y animación de ensamblado con chispas.
- **Red eléctrica:** producción, consumo y almacenamiento. Si falta energía, se cortan primero las estructuras de menor prioridad.
- **Reservas de la base:** O₂, agua y raciones.
- **Soporte vital:**
  - Oxígeno, energía, agua y alimento, con alertas de nivel bajo y crítico.
  - Recarga dentro de un refugio.
  - Regreso de emergencia al quedarse sin oxígeno.
  - Audio "de vacío" fuera de la base.
- **Campaña lunar:**
  - Seis misiones encadenadas, definidas en JSON.
  - Explicaciones educativas de "Control de misión" y seis logros.
- **Intro y menú:** introducción cinematográfica (estrellas, la Tierra, descenso con motor y polvo, título) y menú principal: Nueva misión, Continuar y Modo evaluador.
- **Distribución:** ejecutable de Windows (`build/SPATIUM_IV.exe`) y guía para evaluadores (`docs/GUIA_EVALUADORES.md`).
- **Tests:** 36 en verde. Las pruebas de integración corren en procesos separados (`tools/run_tests.sh` y `.bat`).

## [0.1.0] — 2026-11-15 · Etapa 1: Prototipo jugable
**Mundo lunar**
- Región Lunar 01 (2 × 2 km) generada por script (`tools/generate_moon_region.py`):
  - Relieve espectral, macizo montañoso al norte y contorno natural del mapa.
  - Cráteres con proporciones reales de cráteres simples y distribución de tamaños por ley de potencias.
  - Cráter principal "Albor" (540 m de diámetro).
- Terrain3D con texturas PBR CC0 de regolito y roca (Poly Haven), elegidas automáticamente según la pendiente.
- Cielo:
  - Mapa estelar real de NASA SVS (Deep Star Maps 2020).
  - Sol con su tamaño angular real.
  - La Tierra con su fase calculada según la posición del Sol.
- Sol rasante (14°), sombras largas, luz ambiente casi nula (sin atmósfera).
- Ocupación del mapa:
  - 160 bloques de roca con colisión, concentrados en la eyecta de los cráteres.
  - Pedregullo con MultiMesh por celdas y distancia de visibilidad.

**Astronauta**
- Modelo propio generado en Blender (`tools/blender/build_astronaut.py`):
  - Traje SX-1 con visor dorado, mochila de soporte vital (PLSS) con luces y antena, y módulo de pecho.
  - Computadora de muñeca, herramienta en la cadera y anillos de unión.
- 22 huesos con los nombres del perfil humanoide de Godot (preparado para Mixamo).
- Nueve animaciones propias: reposo con respiración, caminata y trote lunar ("lope"), salto, caída, aterrizaje, recolección, escaneo e interacción.
- Controlador de baja gravedad:
  - Usa la gravedad del cuerpo celeste: 1,62 m/s².
  - Poca tracción y flexión previa al salto.
  - Tiempo de coyote al salir de un borde.
- Cámara en tercera persona con suavizado, colisión, soporte de mando y FOV dinámico al correr.
- Luces del casco (F).
- Polvo balístico al pisar y aterrizar: sin aire, el polvo no forma nubes.

**Recolección y exploración**
- Cuatro recursos definidos como datos (`data/items/*.tres`), cada uno con modelo 3D, textos en español e inglés y respaldo científico (`ScienceSource`):
  - Regolito.
  - Hierro (ilmenita).
  - Hielo de agua.
  - Muestra geológica.
- 51 depósitos ubicados según la geología del mapa; se achican al recolectarlos y se agotan.
- Inventario con límite de masa (120 kg).
- Escáner (Q): un pulso que dibuja un anillo sobre el terreno. Los recursos empiezan ocultos y solo se marcan en el HUD después de escanear.

**Interfaz y audio**
- HUD de visor:
  - Indicación de interacción.
  - Panel de carga.
  - Avisos.
  - Marcadores del escáner.
  - Ayuda de controles.
- Menú de pausa completo, con todas sus funciones operativas:
  - Continuar, guardar y cargar.
  - Opciones: gráficos, pantalla completa, volúmenes, mouse, eje invertido e idioma.
  - Salir.
- 15 efectos de sonido sintetizados (`tools/generate_sfx.py`): pasos por vibración del traje, respiración, escáner, recolección e interfaz.

**Técnica**
- Optimización en el equipo de referencia (Ryzen 3 5300G, Radeon integrada, 1080p): el preset Medio pasó de 16 fps a ~50-60 fps.
  - Cielo estático.
  - FSR1 en lugar de FSR2.
  - SSAO solo en el preset Alto.
  - Sombras en 2 cascadas para Bajo y Medio.
- Tests: 27 en verde, incluida una prueba de integración sobre la escena real (recolectar, escanear, guardar y cargar).
- Modo de demostración y medición (`-- autopilot=showcase`, `-- autopilot=run perf`).

## [0.0.1] — 2026-11-15 · Etapa 0: Base
- Proyecto Godot 4.7.2 en `game/` (Forward+, Jolt, gravedad lunar por defecto, capas de física con nombre).
- Autoloads: EventBus, Settings (presets gráficos Bajo/Medio/Alto), InputConfig (teclado + mando, reasignable), DataRegistry, GameState, SaveManager (JSON versionado, atómico, autoguardado, F5/F9), AudioManager (buses y modo vacío).
- Bases de contenido: `GameDef`, `ItemDef`, `ScienceSource` (dato real / adaptado / valor de juego).
- `StateMachine` / `State` genéricos.
- Localización español/inglés por CSV.
- Addons: Terrain3D 1.1.0, GUT 9.7.1. 18 tests unitarios en verde.
- Documentación: diseño técnico, biblia de arte (propuesta), fuentes y licencias.
