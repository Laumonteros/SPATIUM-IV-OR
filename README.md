# SPATIUM IV — Junior Astronaut Mission Trainer

**NASA Space Apps Challenge · "Build a Junior Astronaut Mission Trainer"**

Manage a lunar colony as a young astronaut (ages 7–12). Every decision has a real cost: power, oxygen, water, food, radiation shielding and communication with Earth — grounded in real NASA data.

## ▶ Play in 3 steps (Windows 10/11, 64-bit)

1. Go to **[Releases](../../releases/latest)** and download `SPATIUM_IV_v1.0.0_windows.zip`.
2. Unzip it (right click → *Extract all*). Keep both files in the same folder.
3. Double-click **`SPATIUM_IV.exe`**.

> If Windows shows *"Windows protected your PC"*, click **More info → Run anyway** (the game is not code-signed).
>
> No installation, no account. Recommended: any PC from the last ~6 years; on integrated graphics the game picks the *Low* preset automatically.

At **Start new game** choose **Yes, with tutorial** for a guided first session (≈10 min). Language: **Settings → Language** (English / Español) — voice, subtitles and in-world signs change too.

## Controls

| Action | Key |
|---|---|
| Move / run / jump / crouch | W A S D · Shift · Space · C |
| Use / collect / harvest | E (or left click with the hand, slot 1) |
| Scanner | Q (or slot 2) |
| Binoculars (hold to look far, shows data cards) | slot 3 + hold click |
| Inventory | Tab |
| Map | M |
| Build mode | B |
| Helmet lights | F |
| Pause / settings | Esc |

## The trade-offs you play

- **Power budget** (battery bank terminal): life support, hydroponics, science and comms at 100 % / 50 % / off. What you switch off saves energy but stops working — and the panel tells you how many hours your batteries last.
- **Solar storms**: a forecast, then a decision — spend battery power to reinforce shelters (half dose) or save energy and risk more radiation.
- **Hull breaches, dusty solar panels, comm blackouts, impact flashes, moonquakes**: random events with choices; no option is free.
- **Food**: choose what to plant — fast crops or plentiful crops, each using water from the colony.
- **Going home**: turn ice into propellant (electrolysis) to lift off in the Ariel module.

## Real NASA data used (and why)

| Data | Source | Use in the game |
|---|---|---|
| Solar flares X5.8 & X8.7 (May 2024), X9.0 (Oct 2024), X9.3 & X8.2 (Sep 2017); May 2024 flare→proton timing and Kp 9 storm | **NASA CCMC DONKI** (archived, not live) | Solar storm events, warning time, debrief |
| Lunar surface background dose ~1369 µSv/day | Chang'e 4 LND (Zhang et al., *Science Advances* 2020) | Radiation meter |
| Water ice ~5.6 % by mass at Cabeus | **NASA LCROSS** (2009) | Water ice deposits, mission 8 |
| Earth, Venus, Mars, Jupiter, Saturn data cards | **NASA NSSDCA Planetary Fact Sheets** | Binocular data cards |
| Lettuce, dwarf tomato, radish, wheat, potato, soy | **NASA Veggie, VEG-05, Plant Habitat-02, KSC growth chambers** | Greenhouse crops |
| Rock compositions (regolith, ilmenite, breccia, anorthosite) | Apollo samples / *Lunar Sourcebook* (LPI) | Rock cards and lab |
| Helium-3 implanted by the solar wind | Apollo samples; Wittenberg et al. (1986) | Scarce resource (fusion use labeled as *future technology*) |
| Lunar dust, micrometeoroids, shallow moonquakes, impact flashes | Apollo reports, ISS, Apollo Passive Seismic Experiment, NASA Lunar Impact Monitoring | Random events |
| Star map | NASA SVS Deep Star Maps 2020 | Milky Way in the sky |

Every number in the game is labeled in-game as **Real data**, **Adapted real data** or **Game value**, so players know what is measured and what is simplified (e.g. time runs 1 real second = 1 game minute).

---

## Español

**Jugar:** en **[Releases](../../releases/latest)** descargá el ZIP, descomprimilo y abrí `SPATIUM_IV.exe`. Si Windows avisa, tocá **Más información → Ejecutar de todas formas**. En *Empezar nueva partida* elegí **Sí, con tutorial**. El idioma se cambia en **Configuración → Idioma**.

Credits: textures of Earth © Solar System Scope (CC BY 4.0); lunar textures Poly Haven (CC0); fonts SIL OFL; engine Godot 4.7 (MIT), Terrain3D (MIT).
