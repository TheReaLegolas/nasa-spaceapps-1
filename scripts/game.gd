extends Node
# Autoload "Game": settings and data shared by every scene.

const NasaData = preload("res://scripts/nasa_data.gd")

# ---- Game length. Change these two numbers to make a shorter demo. ----
const SOL_SECONDS := 180.0   # one Mars day (a "sol") lasts 3 minutes
const TOTAL_SOLS := 10       # 10 sols x 3 minutes = 30 minutes

var character := "girl"      # "girl" or "boy"
var result := {}             # filled in when a game ends, read by the end screen


func _ready() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("interact", [KEY_E, KEY_SPACE])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func weather() -> Array:
	return NasaData.WEATHER


func flares() -> Array:
	return NasaData.FLARES


func weather_is_real() -> bool:
	return NasaData.WEATHER_VERIFIED


func credits_text() -> String:
	var lines := PackedStringArray()
	lines.append("Solar flares: real events from NASA's DONKI space weather database (2026).")
	if weather_is_real():
		lines.append("Mars temperatures: real measurements from NASA's Curiosity rover (REMS).")
	else:
		lines.append("Mars temperatures: sample values in the range NASA's Curiosity rover measures.")
	lines.append("Oxygen machine: based on NASA's MOXIE experiment on the Perseverance rover.")
	lines.append("World art: Kenney (kenney.nl). Characters: our team.")
	return "\n".join(lines)
