extends Node2D
# One thing in the world: a building, a colonist, a rock or a scrap pile.
# The node's position is where the thing touches the ground.

var kind := ""          # "panel", "oxygen", "heater", "shield", "battery", "dome", "workshop", "scrap", "npc", "decor"
var title := ""
var role := ""          # for colonists: "engineer", "doctor", "scientist", "journalist"
var radius := 50.0      # how much space it blocks
var broken := false
var is_on := false
var switchable := false

var sprite: Sprite2D
var tex_off: Texture2D
var tex_on: Texture2D
var badge: Label
var name_label: Label
var top := 0.0


func setup(p_kind: String, p_title: String, tex_path: String, p_scale: float, p_radius: float, on_tex_path: String = "", sink: float = 0.42, vis: float = 0.84) -> void:
	kind = p_kind
	title = p_title
	radius = p_radius
	tex_off = load(tex_path)
	tex_on = tex_off
	if on_tex_path != "":
		tex_on = load(on_tex_path)

	sprite = Sprite2D.new()
	sprite.texture = tex_off
	sprite.scale = Vector2(p_scale, p_scale)
	var h := 128.0
	if tex_off != null:
		h = float(tex_off.get_height())
	# Kenney sprites have empty space around them. "sink" moves the picture so
	# its feet sit on the node position; "vis" is how tall the picture really is.
	sprite.offset = Vector2(0, -h * sink)
	add_child(sprite)
	top = h * vis * p_scale

	if p_title != "" and p_kind != "decor":
		name_label = _make_label(p_title, 14, Color(1, 1, 1), Color(0, 0, 0, 0.45))
		name_label.position = Vector2(-80, 4)
		name_label.size = Vector2(160, 20)
		add_child(name_label)

	badge = _make_label("", 14, Color(1, 1, 1), Color(0.2, 0.2, 0.2, 0.85))
	badge.position = Vector2(-45, -top - 22)
	badge.size = Vector2(90, 20)
	badge.visible = false
	add_child(badge)
	refresh()


func _make_label(text: String, font_size: int, color: Color, bg: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 5
	return l


func collider_center() -> Vector2:
	return position + Vector2(0, -radius * 0.6)


func works() -> bool:
	# true when the machine is actually doing its job
	if broken:
		return false
	if switchable:
		return is_on
	return true


func refresh() -> void:
	if sprite == null:
		return
	if broken:
		sprite.texture = tex_off
		sprite.modulate = Color(0.5, 0.42, 0.42)
		_set_badge("BROKEN!", Color(0.8, 0.15, 0.1, 0.95))
	elif switchable:
		if is_on:
			sprite.texture = tex_on
			sprite.modulate = Color(1, 1, 1)
			_set_badge("ON", Color(0.1, 0.6, 0.2, 0.95))
		else:
			sprite.texture = tex_off
			sprite.modulate = Color(0.72, 0.72, 0.78)
			_set_badge("OFF", Color(0.3, 0.3, 0.3, 0.95))
	else:
		sprite.modulate = Color(1, 1, 1)
		badge.visible = false


func _set_badge(text: String, bg: Color) -> void:
	badge.text = text
	badge.visible = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("normal", sb)
