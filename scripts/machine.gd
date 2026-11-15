extends Node2D
# One thing standing in the world: a building, a machine, a solar panel,
# an empty building plot, a rock, a lamp...
# The node's position is where the thing touches the ground (bottom-centre of the picture).

var what := "thing"
var tid := ""                  # its name in world_data.gd, for example "oxygen"
# kind is one of: "panel", "turbine", "plot_solar", "plot_wind", "battery", "relay", "oxygen",
# "heater", "shield", "antenna", "drill", "farm", "workshop", "home", "decor"
var kind := ""
var title := ""
var col := Rect2()             # the box that blocks the player (world pixels)
var solid := true
var built := true              # false for an empty plot

var broken := false
var leaking := false           # a home with a hole in it
var dusty := false             # a solar panel covered in dust
var switchable := false
var is_on := false
var patched := false           # fixed with a quick patch: it falls off the next morning
var patch_fault := ""          # the kind of problem that comes back when the patch falls off
var folded := false            # a solar panel folded away to stay safe in a dust storm

var sprite: Sprite2D
var tex_normal: Texture2D
var tex_on: Texture2D
var tex_broken: Texture2D
var tex_dusty: Texture2D
var frames: Array = []         # animation frames (wind turbine)
var anim_t := 0.0
var anim_speed := 6.0
var badge: Label
var name_label: Label
var art_h := 100.0             # height of the picture on screen


func setup(data: Dictionary) -> void:
	tid = str(data["id"])
	kind = str(data["kind"])
	title = str(data["title"])
	col = data["col"]
	solid = data["solid"]
	position = data["pos"]

	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	add_child(sprite)

	name_label = _make_label(title, Color(1, 1, 1), Color(0, 0, 0, 0.45))
	name_label.position = Vector2(-90, 4)
	name_label.size = Vector2(180, 20)
	add_child(name_label)

	badge = _make_label("", Color(1, 1, 1), Color(0.2, 0.2, 0.2, 0.9))
	badge.size = Vector2(96, 20)
	badge.visible = false
	add_child(badge)

	if kind == "plot_solar" or kind == "plot_wind":
		built = false
		z_index = -1               # flat on the ground: always drawn under characters
	set_art(str(data["asset"]))
	refresh()


func _make_label(text: String, color: Color, bg: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 5
	return l


func _load_if_exists(asset: String) -> Texture2D:
	var path: String = "res://assets/world/%s.png" % asset
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	return t


func set_art(asset: String) -> void:
	tex_normal = load("res://assets/world/%s.png" % asset)
	tex_on = null
	tex_broken = null
	tex_dusty = null
	frames = []
	if kind == "shield":
		tex_on = _load_if_exists("shield_on")
	elif kind == "heater":
		tex_on = _load_if_exists("heater_on")
	elif kind == "panel":
		tex_broken = _load_if_exists("solar_panel_broken")
		tex_dusty = _load_if_exists("solar_panel_dusty")
	elif kind == "turbine":
		for i in 4:
			var t: Texture2D = _load_if_exists("wind_turbine_%d" % i)
			if t != null:
				frames.append(t)
	sprite.texture = tex_normal
	if tex_normal != null:
		art_h = float(tex_normal.get_height()) * 2.0
		sprite.offset = Vector2(0, -float(tex_normal.get_height()) / 2.0)
	badge.position = Vector2(-48, -minf(art_h + 26.0, 196.0))
	var named: bool = title != "" and kind != "panel" and kind != "turbine" and kind != "plot_solar" and kind != "plot_wind"
	name_label.text = title
	name_label.visible = named


func convert_to(new_kind: String, asset: String, new_title: String, new_col: Rect2) -> void:
	# an empty plot becomes a real machine
	kind = new_kind
	title = new_title
	col = new_col
	solid = true
	built = true
	z_index = 0
	set_art(asset)
	refresh()


func get_col() -> Rect2:
	return col


func dist_to(p: Vector2) -> float:
	# distance from a point to this thing's box (0 when inside)
	var dx: float = maxf(maxf(col.position.x - p.x, p.x - col.end.x), 0.0)
	var dy: float = maxf(maxf(col.position.y - p.y, p.y - col.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


func works() -> bool:
	# true when the machine is really doing its job
	if not built or broken:
		return false
	if switchable:
		return is_on
	return true


func refresh() -> void:
	if sprite == null:
		return
	var tex: Texture2D = tex_normal
	var tint := Color(1, 1, 1)
	var text := ""
	var bg := Color(0.2, 0.2, 0.2, 0.9)
	if not built:
		text = ""
	elif broken:
		if tex_broken != null:
			tex = tex_broken
		else:
			tint = Color(0.5, 0.42, 0.42)
		text = "BROKEN!"
		bg = Color(0.8, 0.15, 0.1, 0.95)
	elif leaking:
		text = "AIR LEAK!"
		bg = Color(0.8, 0.15, 0.1, 0.95)
	elif folded:
		tint = Color(0.62, 0.66, 0.78)
		text = "FOLDED"
		bg = Color(0.25, 0.35, 0.6, 0.95)
	elif dusty:
		if tex_dusty != null:
			tex = tex_dusty
		text = "DUSTY"
		bg = Color(0.72, 0.46, 0.2, 0.95)
	elif switchable:
		if is_on:
			if tex_on != null:
				tex = tex_on
			text = "ON"
			bg = Color(0.1, 0.6, 0.2, 0.95)
		else:
			tint = Color(0.8, 0.8, 0.86)
			text = "OFF"
			bg = Color(0.3, 0.3, 0.3, 0.95)
		if patched:
			text += " (patched)"
	elif patched:
		text = "PATCHED"
		bg = Color(0.75, 0.55, 0.1, 0.95)
	if frames.is_empty() or broken:
		sprite.texture = tex
	sprite.modulate = tint
	badge.text = text
	badge.visible = text != ""
	badge.size = Vector2(maxf(96.0, 9.0 * float(text.length()) + 18.0), 20.0)
	badge.position.x = -badge.size.x / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("normal", sb)


func _process(delta: float) -> void:
	# spin the wind turbine
	if frames.is_empty() or broken or Game.paused:
		return
	anim_t += delta * anim_speed
	sprite.texture = frames[int(anim_t) % frames.size()]
