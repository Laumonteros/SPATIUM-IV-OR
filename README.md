# SPATIUM IV — Junior Astronaut Mission Trainer

**NASA Space Apps Challenge 2026 · "Build a Junior Astronaut Mission Trainer"**
🇬🇧 English (main) · [🇪🇸 Español abajo](#-español)

SPATIUM IV is a 3D game for kids aged **7–12** where you live in a lunar colony and make the same kind of decisions NASA mission planners make: how to split limited **power** between life support, food, science and communications; when to spend energy on **radiation shielding**; what to **grow**; how to find **water**; and how to make **propellant** to go home. Every choice has a cost, and every number is labeled as **real NASA data**, **adapted real data** or **game value**.

## ⬇ Download and play

Go to **[Releases → latest](../../releases/latest)** and download the ZIP for your system:

| System | File | How to open |
|---|---|---|
| **Windows 10/11 (64-bit)** | `SPATIUM_IV_v1.0.0_windows.zip` | Unzip (*Extract all*) and double-click `SPATIUM_IV.exe`. If Windows shows *"Windows protected your PC"* → **More info → Run anyway**. |
| **macOS 11+ (Intel or Apple Silicon)** | `SPATIUM_IV_v1.0.0_macos.zip` | Unzip and move `SPATIUM IV.app` to Applications. The app is not notarized: **right-click → Open → Open**. If macOS still blocks it, run `xattr -cr "/Applications/SPATIUM IV.app"` in Terminal. |
| **Linux (x86_64)** | `SPATIUM_IV_v1.0.0_linux.zip` | Unzip and run `./SPATIUM_IV.x86_64` (if needed: `chmod +x SPATIUM_IV.x86_64`). |

No installation and no account needed. Keep the files of each ZIP together in the same folder.

### Requirements

| | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit · macOS 11 · Linux x86_64 (glibc 2.31+) | Windows 11 · macOS 13+ |
| Graphics | Vulkan 1.0 (Windows/Linux) or Metal (macOS); integrated GPU OK | Dedicated GPU |
| Memory | 4 GB RAM | 8 GB RAM |
| Disk | 400 MB | — |

On integrated graphics the game picks the **Low** preset automatically. Settings → Graphics lets you change it.

## 🎮 Controls

| Action | Keyboard / mouse |
|---|---|
| Move · run · jump · crouch | W A S D (or arrows) · Shift · Space · C |
| Use / collect / harvest / talk | **E** (or left click with the hand, slot 1) |
| Scanner (marks rocks by what they yield) | **Q** (or slot 2) |
| Binoculars (hold to zoom; shows data cards) | slot **3** + hold click |
| Inventory · Map · Encyclopedia | **Tab** · **M** · see Settings → Keyboard & mouse |
| Build mode | **B** |
| Helmet lights | **F** |
| Pause · settings · save | **Esc** |

All keys can be remapped in **Settings → Keyboard & mouse**.

## 🚀 Quick start

1. **Start new game → Yes, with tutorial** (≈10 minutes, 8 guided steps).
2. Follow **Mission Control** on the radio (voice in English or Spanish) and the mission panel (top-left).
3. The campaign has **13 missions**: first contact → resources → base → survival → research → expansion → mapping → water → helium-3 → maintenance → solar storm → bigger base → **going home**.

Full guide: **[GUIDE.md](GUIDE.md)** · Updates: **[CHANGELOG.md](CHANGELOG.md)**.

## ⚖ The trade-offs (what kids learn)

- **Power budget** — life support, hydroponics, science and comms at 100 % / 50 % / off. What you switch off saves energy but stops working; the screen shows how many hours your batteries last.
- **Solar storms** — a forecast, then a choice: spend battery power to reinforce the shelters (half dose) or save energy and accept more radiation.
- **Random events** — dusty solar panels, hull breaches (patch now with iron or lose air until you get there), comm blackouts, impact flashes, moonquakes, science requests from Earth.
- **Food** — fast crops vs. plentiful crops, each using colony water.
- **Going home** — turn ice into hydrogen and oxygen (electrolysis) to fuel the Ariel module.

## 🛰 Real data used (and why)

| Data | Source | Used for |
|---|---|---|
| Solar flares X5.8 & X8.7 (May 2024), X9.0 (Oct 2024), X9.3 & X8.2 (Sep 2017); May 2024 flare→proton timing and Kp 9 | [NASA CCMC DONKI](https://kauai.ccmc.gsfc.nasa.gov/DONKI/) (archived, not live) | Solar storms, warning time, debrief |
| Lunar surface dose ≈ 1369 µSv/day | Chang'e 4 LND, *Science Advances* (2020) | Radiation meter |
| Water ice ≈ 5.6 % by mass at Cabeus | [NASA LCROSS](https://science.nasa.gov/mission/lcross/) | Ice deposits, water mission |
| Earth, Venus, Mars, Jupiter, Saturn data | [NASA NSSDCA Planetary Fact Sheets](https://nssdc.gsfc.nasa.gov/planetary/factsheet/) | Binocular data cards |
| Crops grown in space | NASA Veggie, VEG-05, Plant Habitat-02, KSC chambers | Greenhouse |
| Rock compositions | Apollo samples, *Lunar Sourcebook* (LPI) | Rock cards, lab |
| Helium-3 from the solar wind | Apollo samples; Wittenberg et al. (1986) | Scarce resource (fusion labeled *future technology*) |
| Dust, micrometeoroids, moonquakes, impact flashes | Apollo reports, ISS, Apollo Passive Seismic Experiment, NASA Lunar Impact Monitoring | Random events |
| Star map | [NASA SVS Deep Star Maps 2020](https://svs.gsfc.nasa.gov/4851) | Milky Way |

Full list with licenses: [docs/SOURCES.es.md](docs/SOURCES.es.md).

## 🛠 Source code

Built with **Godot 4.7.2** (GDScript). Open `game/project.godot` in Godot 4.7.2 to run from source. Large assets use **Git LFS** (`git lfs install` before cloning). `tools/` holds the scripts that generate textures, music, voices and models (Blender 5.3).

---

## 🇪🇸 Español

**SPATIUM IV** es un juego 3D para chicos de **7 a 12 años**: vivís en una colonia lunar y tomás las mismas decisiones que los planificadores de misiones de NASA. Repartís la **energía**, elegís cuándo gastarla en **blindaje contra la radiación**, decidís qué **cultivar**, buscás **agua** y fabricás **propelente** para volver. Ninguna opción es gratis, y cada número indica si es **dato real**, **dato real adaptado** o **valor de juego**.

**Descargar y jugar:** en **[Releases](../../releases/latest)** bajá el ZIP de tu sistema (Windows, macOS o Linux), descomprimilo y abrí el juego.
- **Windows:** si aparece «Windows protegió su PC», tocá **Más información → Ejecutar de todas formas**.
- **macOS:** **clic derecho → Abrir**.
- **Linux:** `./SPATIUM_IV.x86_64`.

**Requisitos:** Windows 10 64 bits, macOS 11 o Linux x86_64; gráficos con Vulkan (Metal en Mac); 4 GB de RAM; 400 MB libres.

**Primeros pasos:** **Empezar nueva partida → Sí, con tutorial**. El idioma se cambia en **Configuración → Idioma**; voz, subtítulos y carteles cambian también.

**Guía completa:** [GUIA.md](GUIA.md) · **Cambios versión por versión:** [docs/CHANGELOG.es.md](docs/CHANGELOG.es.md)

---
Credits: Earth textures © Solar System Scope (CC BY 4.0) · lunar textures Poly Haven (CC0) · fonts SIL OFL · Godot Engine (MIT) · Terrain3D (MIT) · GUT (MIT). Voices: Windows speech synthesis with radio effect.
