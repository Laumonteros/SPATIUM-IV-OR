extends Node
## Bus de eventos global de SPATIUM IV.
##
## Los sistemas se comunican emitiendo y escuchando estas señales, sin
## referencias directas entre ellos. Regla: solo se declaran señales que
## cruzan módulos; las señales internas de un sistema viven en su propio nodo.
## Cada etapa agrega aquí únicamente las señales que realmente usa.

# --- Ciclo de partida -------------------------------------------------------
@warning_ignore("unused_signal")
signal game_saved(slot: String)
@warning_ignore("unused_signal")
signal game_loaded(slot: String)
@warning_ignore("unused_signal")
signal save_failed(slot: String, reason: String)

# --- Mundo ------------------------------------------------------------------
## Se emite al cambiar de cuerpo celeste (p. ej. &"moon" -> &"mars").
@warning_ignore("unused_signal")
signal celestial_body_changed(body_id: StringName)

# --- Recursos y exploración --------------------------------------------------
@warning_ignore("unused_signal")
signal resource_collected(item_id: StringName, amount: int)
@warning_ignore("unused_signal")
signal deposit_depleted(deposit_id: String)
## `found`: Array de nodos ResourceDeposit detectados por el pulso del escáner.
@warning_ignore("unused_signal")
signal scan_completed(found: Array)

# --- Base y supervivencia ----------------------------------------------------
@warning_ignore("unused_signal")
signal structure_built(structure: Node)
@warning_ignore("unused_signal")
signal structure_loaded(structure: Node, item_id: StringName, amount: int)
@warning_ignore("unused_signal")
signal vital_alert(vital: StringName, level: StringName)
@warning_ignore("unused_signal")
signal player_rescued
@warning_ignore("unused_signal")
signal player_action(action: StringName)
## phase: &"warning", &"storm", &"over"; text: mensaje para el jugador.
@warning_ignore("unused_signal")
signal radiation_event(phase: StringName, text: String)

# --- Configuración ----------------------------------------------------------
@warning_ignore("unused_signal")
signal settings_changed(section: String, key: String, value: Variant)
@warning_ignore("unused_signal")
signal graphics_preset_changed(preset: int)

# --- Sesión -----------------------------------------------------------------
@warning_ignore("unused_signal")
signal pause_changed(paused: bool)

# --- Interfaz ---------------------------------------------------------------
## Pide a la interfaz mostrar un aviso breve. `kind`: &"info", &"warning", &"alert".
@warning_ignore("unused_signal")
signal notification_requested(text: String, kind: StringName)
