extends Node
# Autoload "Game": settings and data shared by every scene.

const NasaData = preload("res://scripts/nasa_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

# ---- Game length. One sol (a day on Mars) = DAY + DUSK + NIGHT + DAWN.
# Change these numbers to make the game longer or shorter.
# For a quick demo try 60, 20, 40 and 20: the whole game then takes about 16 minutes.
const DAY_SECONDS := 240.0    # full daylight: 4 minutes
const DUSK_SECONDS := 60.0    # sunset: the sky slowly turns dark (1 minute)
const NIGHT_SECONDS := 120.0  # night: 2 minutes
const DAWN_SECONDS := 60.0    # sunrise: the sky slowly turns bright again (1 minute)
const SOL_SECONDS := DAY_SECONDS + DUSK_SECONDS + NIGHT_SECONDS + DAWN_SECONDS
const TOTAL_SOLS := 7         # the President is away for 7 sols

# F9 jumps to the next part of the day (day, sunset, night, sunrise). Handy for testing
# and for showing the game quickly. Set this to false to switch the shortcut off.
const DEV_KEYS := true

var character := "girl"      # "girl" or "boy"
var show_tour := true        # the machine tour at the start of a game (the title screen can switch it off)
var result := {}             # filled in when a game ends, read by the end screen

# These three are updated by main.gd every frame and read by colonists and vehicles.
var paused := false          # true while a dialog is open: everything in the world waits
var shelter := false         # true at night and during storms: townspeople go home
var player_pos := Vector2.ZERO

# The uneven edge of the map (from world_data.gd). Nobody can walk or drive past it.
var border := PackedVector2Array()


func _ready() -> void:
	for p in WorldData.BORDER:
		border.append(p)
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


func inside_map(p: Vector2) -> bool:
	# true when the point is on the ground you can walk on, inside the uneven edge
	if border.size() < 3:
		return true
	return Geometry2D.is_point_in_polygon(p, border)


func weather() -> Array:
	return NasaData.WEATHER


func cold_nights() -> Array:
	return NasaData.COLD_NIGHTS


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
	lines.append("Greenhouse: NASA grows lettuce and other plants under LED lights on the International Space Station ('Veggie').")
	lines.append("Art: our team, made with AI tools.")
	return "\n".join(lines)
