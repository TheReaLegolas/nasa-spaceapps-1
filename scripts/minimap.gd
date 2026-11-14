extends Control
# The small map in the corner. The picture is drawn ahead of time
# (assets/ground/minimap.png); this script only adds the moving marks.

var map_tex: Texture2D
var map_scale := 24.0          # world pixels per minimap pixel
var player_pos := Vector2.ZERO
var markers: Array = []        # each one is [world position, kind]; kind is "alert", "fix" or "rover"
var offline := false           # true while the antenna is broken
var blink := 0.0
var no_signal: Label


func _ready() -> void:
	map_tex = load("res://assets/ground/minimap.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(250, 175)
	clip_contents = true
	no_signal = Label.new()
	no_signal.text = "NO SIGNAL"
	no_signal.position = Vector2(0, 74)
	no_signal.size = Vector2(250, 26)
	no_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_signal.add_theme_font_size_override("font_size", 18)
	no_signal.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	no_signal.visible = false
	add_child(no_signal)


func _process(delta: float) -> void:
	blink += delta
	no_signal.visible = offline and fmod(blink, 1.0) < 0.7
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if map_tex != null:
		draw_texture_rect(map_tex, full, false)
	else:
		draw_rect(full, Color(0.6, 0.3, 0.2))
	if offline:
		draw_rect(full, Color(0.05, 0.05, 0.08, 0.94))
		for i in 10:
			var y: float = fmod(blink * 50.0 + float(i) * 19.0, size.y)
			draw_rect(Rect2(0.0, y, size.x, 2.0), Color(1, 1, 1, 0.07))
		return
	var show_alert: bool = fmod(blink, 0.8) < 0.56
	for m in markers:
		var world_pos: Vector2 = m[0]
		var p: Vector2 = world_pos / map_scale
		var k: String = m[1]
		if k == "rover":
			draw_rect(Rect2(p.x - 4.0, p.y - 3.0, 8.0, 6.0), Color(0.15, 0.1, 0.12))
			draw_rect(Rect2(p.x - 3.0, p.y - 2.0, 6.0, 4.0), Color(1, 1, 1))
		elif k == "fix":
			var grow: float = 1.0 + 1.5 * absf(sin(blink * 4.0))
			draw_rect(Rect2(p.x - 4.0 - grow, p.y - 4.0 - grow, 8.0 + grow * 2.0, 8.0 + grow * 2.0), Color(0.15, 0.05, 0.05))
			draw_rect(Rect2(p.x - 3.0 - grow, p.y - 3.0 - grow, 6.0 + grow * 2.0, 6.0 + grow * 2.0), Color(1.0, 0.25, 0.2))
		elif k == "alert" and show_alert:
			draw_circle(p, 9.0, Color(0.15, 0.1, 0.12))
			draw_circle(p, 7.5, Color(1.0, 0.85, 0.25))
			draw_rect(Rect2(p.x - 1.0, p.y - 5.0, 2.0, 6.0), Color(0.15, 0.1, 0.12))
			draw_rect(Rect2(p.x - 1.0, p.y + 2.5, 2.0, 2.0), Color(0.15, 0.1, 0.12))
	var pp: Vector2 = player_pos / map_scale
	draw_circle(pp, 5.5, Color(0.1, 0.1, 0.15))
	draw_circle(pp, 4.0, Color(0.35, 1.0, 0.45))
