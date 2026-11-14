extends CanvasLayer
# Everything drawn on top of the world: bars, clock, tasks, news, dialogs.

var bar_energy: ProgressBar
var bar_oxygen: ProgressBar
var bar_health: ProgressBar
var parts_label: Label
var power_label: Label
var switches_label: Label
var clock_label: Label
var time_label: Label
var tasks_label: Label
var prompt_label: Label
var hold_bar: ProgressBar

var banner: Panel
var banner_title: Label
var banner_text: Label
var banner_left := 0.0

var dialog: Panel
var dialog_name: Label
var dialog_text: Label

var storm_overlay: ColorRect
var flare_overlay: ColorRect
var hurt_overlay: ColorRect
var hurt_alpha := 0.0


func _ready() -> void:
	layer = 10

	storm_overlay = _overlay(Color(0.85, 0.45, 0.2, 0.0))
	flare_overlay = _overlay(Color(0.7, 0.3, 0.9, 0.0))
	hurt_overlay = _overlay(Color(1.0, 0.1, 0.1, 0.0))

	# ---- top left: the three bars
	var stats := _panel(Vector2(12, 12), Vector2(330, 172))
	bar_energy = _bar(stats, 12, "Energy", Color(1.0, 0.82, 0.2))
	bar_oxygen = _bar(stats, 44, "Oxygen", Color(0.3, 0.75, 1.0))
	bar_health = _bar(stats, 76, "Health", Color(0.95, 0.3, 0.35))
	parts_label = _text(stats, "Spare parts: 0", 18, Color(1, 1, 1), Vector2(12, 106), Vector2(170, 24))
	power_label = _text(stats, "", 16, Color(1, 1, 1), Vector2(170, 108), Vector2(150, 22))
	switches_label = _text(stats, "", 14, Color(0.85, 0.85, 0.85), Vector2(12, 136), Vector2(310, 30))

	# ---- top centre: the clock
	var clock := _panel(Vector2(490, 12), Vector2(300, 60))
	clock_label = _text(clock, "", 20, Color(1.0, 0.85, 0.5), Vector2(0, 4), Vector2(300, 26))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label = _text(clock, "", 18, Color(1, 1, 1), Vector2(0, 30), Vector2(300, 24))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- top right: tasks
	var tasks := _panel(Vector2(948, 12), Vector2(320, 180))
	_text(tasks, "TASKS", 18, Color(1.0, 0.85, 0.5), Vector2(12, 6), Vector2(296, 24))
	tasks_label = _text(tasks, "", 16, Color(1, 1, 1), Vector2(12, 32), Vector2(296, 142))
	tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasks_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# ---- news banner
	banner = _panel(Vector2(340, 84), Vector2(600, 92))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.12, 0.25, 0.92)
	bs.border_color = Color(1.0, 0.85, 0.5)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(8)
	banner.add_theme_stylebox_override("panel", bs)
	banner_title = _text(banner, "", 18, Color(1.0, 0.85, 0.5), Vector2(12, 4), Vector2(576, 24))
	banner_text = _text(banner, "", 17, Color(1, 1, 1), Vector2(12, 28), Vector2(576, 60))
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	banner.visible = false

	# ---- bottom: what the E key does right now
	prompt_label = Label.new()
	prompt_label.position = Vector2(240, 610)
	prompt_label.size = Vector2(800, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.6)
	ps.set_corner_radius_all(6)
	prompt_label.add_theme_stylebox_override("normal", ps)
	prompt_label.visible = false
	add_child(prompt_label)

	hold_bar = ProgressBar.new()
	hold_bar.position = Vector2(490, 650)
	hold_bar.size = Vector2(300, 18)
	hold_bar.max_value = 1.0
	hold_bar.step = 0.001
	hold_bar.show_percentage = false
	_style_bar(hold_bar, Color(0.4, 0.9, 0.4))
	hold_bar.visible = false
	add_child(hold_bar)

	# ---- dialog box
	dialog = _panel(Vector2(190, 500), Vector2(900, 190))
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	ds.border_color = Color(1, 1, 1, 0.8)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(10)
	dialog.add_theme_stylebox_override("panel", ds)
	dialog_name = _text(dialog, "", 22, Color(1.0, 0.85, 0.5), Vector2(20, 10), Vector2(860, 30))
	dialog_text = _text(dialog, "", 21, Color(1, 1, 1), Vector2(20, 44), Vector2(860, 110))
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var hint := _text(dialog, "SPACE or E to continue", 15, Color(0.75, 0.75, 0.75), Vector2(20, 160), Vector2(860, 22))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialog.visible = false


func _process(delta: float) -> void:
	if banner_left > 0.0:
		banner_left -= delta
		if banner_left <= 0.0:
			banner.visible = false
	if hurt_alpha > 0.0:
		hurt_alpha = maxf(0.0, hurt_alpha - delta * 1.2)
		hurt_overlay.color.a = hurt_alpha


# ------------------------------------------------------------------ building blocks

func _overlay(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 720)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = panel_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _text(parent: Control, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _style_bar(b: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(5)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)


func _bar(parent: Control, y: float, text: String, color: Color) -> ProgressBar:
	_text(parent, text, 18, Color(1, 1, 1), Vector2(12, y), Vector2(90, 24))
	var b := ProgressBar.new()
	b.position = Vector2(100, y + 2)
	b.size = Vector2(218, 22)
	b.max_value = 100.0
	b.step = 0.1
	b.show_percentage = false
	_style_bar(b, color)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ used by main.gd

func set_bars(energy: float, oxygen: float, health: float) -> void:
	bar_energy.value = energy
	bar_oxygen.value = oxygen
	bar_health.value = health


func set_parts(count: int) -> void:
	parts_label.text = "Spare parts: %d" % count


func set_power(net: float) -> void:
	if net > 0.02:
		power_label.text = "Battery: filling"
		power_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	elif net < -0.02:
		power_label.text = "Battery: draining"
		power_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		power_label.text = "Battery: steady"
		power_label.add_theme_color_override("font_color", Color(1, 1, 1))


func set_switches(text: String) -> void:
	switches_label.text = text


func set_clock(top_line: String, bottom_line: String) -> void:
	clock_label.text = top_line
	time_label.text = bottom_line


func set_tasks(lines: Array) -> void:
	var out := ""
	for line in lines:
		out += "- " + str(line) + "\n"
	tasks_label.text = out


func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func set_hold(progress: float) -> void:
	# pass a negative number to hide the bar
	hold_bar.visible = progress >= 0.0
	if progress >= 0.0:
		hold_bar.value = progress


func show_banner(title: String, text: String, seconds: float = 9.0) -> void:
	banner_title.text = title
	banner_text.text = text
	banner.visible = true
	banner_left = seconds


func show_dialog(speaker: String, text: String) -> void:
	dialog_name.text = speaker
	dialog_text.text = text
	dialog.visible = true


func hide_dialog() -> void:
	dialog.visible = false


func set_weather(storm: float, flare: float) -> void:
	storm_overlay.color.a = storm
	flare_overlay.color.a = flare


func flash_hurt() -> void:
	hurt_alpha = 0.45
	hurt_overlay.color.a = hurt_alpha
