extends Control
# Title screen: pick the boy or the girl, then start.

var selected := "girl"
var buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.07, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("MARS COLONY 3030", 64, Color(1.0, 0.62, 0.35))
	title.position = Vector2(0, 44)
	title.size = Vector2(1280, 80)
	add_child(title)

	var sub := _label("Keep the colony alive for 10 Mars days.", 26, Color(1, 1, 1))
	sub.position = Vector2(0, 128)
	sub.size = Vector2(1280, 40)
	add_child(sub)

	var pick := _label("Choose your colonist", 24, Color(1.0, 0.85, 0.5))
	pick.position = Vector2(0, 190)
	pick.size = Vector2(1280, 36)
	add_child(pick)

	_add_card("girl", "Girl", Vector2(420, 236))
	_add_card("boy", "Boy", Vector2(660, 236))
	_select("girl")

	var start := Button.new()
	start.text = "START"
	start.position = Vector2(515, 500)
	start.size = Vector2(250, 64)
	start.add_theme_font_size_override("font_size", 30)
	start.pressed.connect(_on_start)
	add_child(start)

	var help := _label("Move: arrow keys or W A S D        Use / talk / repair / drive: E or SPACE", 20, Color(0.85, 0.85, 0.85))
	help.position = Vector2(0, 584)
	help.size = Vector2(1280, 30)
	add_child(help)

	var help2 := _label("Follow the ! on the minimap. Collect ore from the miners. Drive a rover to get around faster.", 18, Color(0.8, 0.8, 0.8))
	help2.position = Vector2(0, 618)
	help2.size = Vector2(1280, 28)
	add_child(help2)

	var credit := _label("Uses real NASA space weather data. Made for the NASA Space Apps Challenge.", 16, Color(0.7, 0.7, 0.7))
	credit.position = Vector2(0, 672)
	credit.size = Vector2(1280, 26)
	add_child(credit)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _add_card(id: String, text: String, pos: Vector2) -> void:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(200, 240)
	b.text = text
	b.icon = load("res://assets/chars/portrait_%s.png" % id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_select.bind(id))
	add_child(b)
	buttons[id] = b


func _select(id: String) -> void:
	selected = id
	for key in buttons:
		var b: Button = buttons[key]
		if key == id:
			b.modulate = Color(1, 1, 1)
			b.scale = Vector2(1.06, 1.06)
		else:
			b.modulate = Color(0.55, 0.55, 0.55)
			b.scale = Vector2(1, 1)


func _on_start() -> void:
	Game.character = selected
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
