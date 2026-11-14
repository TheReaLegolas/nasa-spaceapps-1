extends Control
# Opening: newspapers spin onto the screen and tell the story from 2026 to 3030.

# Edit this list to change the story. Each entry is one newspaper.
const PAPERS := [
	{
		"date": "July 2026",
		"headline": "HUMANS AIM FOR THE MOON AGAIN - AND THEN MARS",
		"body": "Space agencies say the Moon is only the first step. One day, people may live on the Red Planet.",
	},
	{
		"date": "March 2190",
		"headline": "EARTH IS GETTING CROWDED: 20 BILLION PEOPLE",
		"body": "Cities are full. Clean water, food and energy are harder to share every year.",
	},
	{
		"date": "October 2512",
		"headline": "NO MORE ROOM! LEADERS LOOK TO MARS",
		"body": "The whole world agrees on one plan: build a new home on another planet.",
	},
	{
		"date": "May 2841",
		"headline": "ROBOTS START BUILDING ON MARS",
		"body": "Machines land in a red desert and begin building domes, solar panels and an oxygen machine.",
	},
	{
		"date": "January 2994",
		"headline": "COLONY 'NEW HOPE' OPENS ITS DOORS",
		"body": "The first families arrive on Mars. Life is hard: the air cannot be breathed and nights are freezing.",
	},
	{
		"date": "Today, 3030",
		"headline": "NEW HOPE NEEDS A NEW OPERATOR: YOU!",
		"body": "Energy, oxygen and spare parts are limited. Every choice has a cost. Can you keep the colony alive?",
	},
]

var index := -1
var busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hint := Label.new()
	hint.text = "Press SPACE or click to continue"
	hint.position = Vector2(0, 672)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.z_index = 50
	add_child(hint)

	var skip := Button.new()
	skip.text = "Skip"
	skip.position = Vector2(1160, 20)
	skip.size = Vector2(100, 40)
	skip.focus_mode = Control.FOCUS_NONE
	skip.z_index = 50
	skip.pressed.connect(_start_game)
	add_child(skip)

	_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_next()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next()


func _next() -> void:
	if busy:
		return
	index += 1
	if index >= PAPERS.size():
		_start_game()
		return
	_show_paper(PAPERS[index])


func _show_paper(data: Dictionary) -> void:
	busy = true
	var paper := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.89, 0.78)
	style.border_color = Color(0.25, 0.2, 0.15)
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	paper.add_theme_stylebox_override("panel", style)
	paper.size = Vector2(780, 460)
	paper.position = Vector2(250, 110)
	paper.pivot_offset = paper.size / 2.0
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)

	var ink := Color(0.12, 0.1, 0.08)
	_paper_text(paper, "THE EARTH TIMES", 40, ink, Vector2(20, 14), Vector2(740, 54), true)
	var line := ColorRect.new()
	line.color = ink
	line.position = Vector2(20, 74)
	line.size = Vector2(740, 4)
	paper.add_child(line)
	_paper_text(paper, str(data["date"]), 20, Color(0.35, 0.3, 0.25), Vector2(20, 84), Vector2(740, 30), true)
	_paper_text(paper, str(data["headline"]), 40, ink, Vector2(30, 126), Vector2(720, 170), true)
	_paper_text(paper, str(data["body"]), 24, Color(0.2, 0.18, 0.15), Vector2(50, 310), Vector2(680, 130), true)

	var tilt := deg_to_rad(-5.0 + 3.0 * float(index % 4))
	paper.scale = Vector2(0.1, 0.1)
	paper.rotation = tilt - TAU * 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(paper, "scale", Vector2(1, 1), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(paper, "rotation", tilt, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_paper_done)


func _paper_done() -> void:
	busy = false


func _paper_text(parent: Control, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2, centered: bool) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
