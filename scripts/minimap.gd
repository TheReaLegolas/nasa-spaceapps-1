extends Control
# The small map in the corner. The picture is drawn ahead of time
# (assets/ground/minimap.png); this script adds the area names and the moving marks.

# The roads cut the map into 9 areas. Each one gets a short name so children
# can see at a glance what is where. [left, top, width, height] in minimap pixels.
const AREAS := [
	["ROCKET PAD", Rect2(0, 0, 87, 54)],
	["HOMES", Rect2(87, 0, 75, 54)],
	["MINE", Rect2(162, 0, 88, 54)],
	["SOLAR FIELD", Rect2(0, 54, 87, 58)],
	["TOWN", Rect2(87, 54, 75, 58)],
	["MACHINES", Rect2(162, 54, 88, 58)],
	["FARM", Rect2(0, 112, 87, 63)],
	["DOME", Rect2(87, 112, 75, 63)],
	["WORKSHOP", Rect2(162, 112, 88, 63)],
]
const PAD_CENTER := Vector2(31.7, 29.2)   # the rocket pad (world 760, 700) on the minimap

var map_tex: Texture2D
var map_scale := 24.0          # world pixels per minimap pixel
var player_pos := Vector2.ZERO
# each one is [world position, kind]; kind is "alert" (talk to someone), "fix" (a machine
# with a problem), "item" (something to pick up) or "rover"
var markers: Array = []
var offline := false           # true while the antenna is broken
var blink := 0.0
var no_signal: Label
var font: Font


func _ready() -> void:
	map_tex = load("res://assets/ground/minimap.png")
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(250, 175)
	clip_contents = true
	no_signal = Label.new()
	no_signal.text = "NO MAP SIGNAL - RADAR ONLY"
	no_signal.position = Vector2(0, 4)
	no_signal.size = Vector2(250, 20)
	no_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_signal.add_theme_font_size_override("font_size", 13)
	no_signal.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	no_signal.visible = false
	add_child(no_signal)


func _process(delta: float) -> void:
	blink += delta
	no_signal.visible = offline
	no_signal.modulate.a = 0.65 + 0.35 * sin(blink * 5.0)
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if map_tex != null:
		draw_texture_rect(map_tex, full, false)
	else:
		draw_rect(full, Color(0.6, 0.3, 0.2))
	if offline:
		# no signal: the map picture is gone and it only works as a simple radar.
		# It still shows where you are and where the problems are, so the player
		# always knows where to go.
		draw_rect(full, Color(0.05, 0.05, 0.08, 0.94))
		for i in 10:
			var y: float = fmod(blink * 50.0 + float(i) * 19.0, size.y)
			draw_rect(Rect2(0.0, y, size.x, 2.0), Color(1, 1, 1, 0.07))
	else:
		_draw_empty_pad()
		_draw_area_names()

	# rovers first, then problems, then people with a "!", so the "!" is always on top
	for pass_kind in ["rover", "item", "fix", "alert"]:
		if offline and pass_kind == "rover":
			continue
		for m in markers:
			if str(m[1]) == pass_kind:
				_draw_marker(m[0] / map_scale, pass_kind)

	var pp: Vector2 = player_pos / map_scale
	draw_circle(pp, 5.5, Color(0.1, 0.1, 0.15))
	draw_circle(pp, 4.0, Color(0.35, 1.0, 0.45))


func _draw_empty_pad() -> void:
	# the rocket has left with the President, so paint over it in the map picture
	draw_circle(PAD_CENTER, 15.5, Color(0.36, 0.33, 0.35))
	draw_circle(PAD_CENTER, 14.3, Color(0.62, 0.6, 0.61))
	draw_arc(PAD_CENTER, 7.0, 0.0, TAU, 24, Color(0.93, 0.93, 0.96), 1.0)
	draw_rect(Rect2(PAD_CENTER.x - 4.0, PAD_CENTER.y - 0.5, 8.0, 1.5), Color(0.93, 0.93, 0.96))
	draw_rect(Rect2(PAD_CENTER.x - 0.5, PAD_CENTER.y - 4.0, 1.5, 8.0), Color(0.93, 0.93, 0.96))


func _draw_area_names() -> void:
	var fs := 9
	for a in AREAS:
		var text: String = a[0]
		var box: Rect2 = a[1]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# bottom of each area, just above the road, where the pictures are emptiest
		var pos := Vector2(box.position.x + (box.size.x - w) / 2.0, box.end.y - 6.0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.1, 0.06, 0.06, 0.85))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.96, 0.85))


func _draw_marker(p: Vector2, k: String) -> void:
	var dark := Color(0.15, 0.1, 0.12)
	if k == "rover":
		draw_rect(Rect2(p.x - 4.0, p.y - 3.0, 8.0, 6.0), dark)
		draw_rect(Rect2(p.x - 3.0, p.y - 2.0, 6.0, 4.0), Color(1, 1, 1))
	elif k == "item":
		# a side-quest item: a purple diamond that pulses
		var r: float = 6.0 + 1.5 * absf(sin(blink * 4.0))
		var outer := PackedVector2Array([p + Vector2(0, -r - 1.5), p + Vector2(r + 1.5, 0), p + Vector2(0, r + 1.5), p + Vector2(-r - 1.5, 0)])
		var inner := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(outer, dark)
		draw_colored_polygon(inner, Color(0.75, 0.45, 1.0))
	elif k == "fix":
		# a machine with a problem: a red box with a "!" that pulses
		var grow: float = 1.0 + 1.5 * absf(sin(blink * 4.0))
		draw_rect(Rect2(p.x - 6.0 - grow, p.y - 6.0 - grow, 12.0 + grow * 2.0, 12.0 + grow * 2.0), dark)
		draw_rect(Rect2(p.x - 5.0 - grow, p.y - 5.0 - grow, 10.0 + grow * 2.0, 10.0 + grow * 2.0), Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(p.x - 1.0, p.y - 4.5, 2.0, 5.5), Color(1, 1, 1))
		draw_rect(Rect2(p.x - 1.0, p.y + 2.5, 2.0, 2.0), Color(1, 1, 1))
	elif k == "alert":
		# someone to talk to: a yellow circle with a "!" (it gently pulses instead of
		# blinking off, so it can never be missed)
		var r2: float = 7.5 + 1.0 * absf(sin(blink * 4.0))
		draw_circle(p, r2 + 1.5, dark)
		draw_circle(p, r2, Color(1.0, 0.85, 0.25))
		draw_rect(Rect2(p.x - 1.0, p.y - 5.0, 2.0, 6.0), dark)
		draw_rect(Rect2(p.x - 1.0, p.y + 2.5, 2.0, 2.0), dark)
