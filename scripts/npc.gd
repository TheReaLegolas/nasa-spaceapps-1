extends "res://scripts/actor.gd"
# A colonist. Three kinds of behaviour:
#   "stand"  - stays in one place and turns to look at the player (named colonists)
#   "patrol" - walks between a few points with a pause at each (miners)
#   "town"   - walks between home, the market stalls and the plaza (townspeople)

const WorldData = preload("res://scripts/world_data.gd")

var what := "npc"
var npc_id := ""
var npc_name := ""
var role := ""
var mode := "stand"
var solid := false
var speed := 120.0

var alert: Sprite2D            # the "!" above the head
var buy: Sprite2D              # the little coin bubble when shopping
var bubble: Label              # shows how much ore a miner is holding
var name_tag: Label
var bob := 0.0

# patrol
var points: Array = []
var point_i := 0
var wait := 0.0
var ore := 0
var ore_timer := 0.0

# town
var home := 0                  # index into WorldData.WALK_NODES
var at := 0
var goal := 0
var step := 0
var state := "inside"          # "inside", "walk", "shop" or "idle"
var timer := 0.0
var side := Vector2.ZERO       # small personal offset so people do not walk in single file


func setup_npc(p_id: String, p_name: String, p_role: String, sheet: String) -> void:
	npc_id = p_id
	npc_name = p_name
	role = p_role
	setup_actor(sheet)

	alert = Sprite2D.new()
	alert.texture = load("res://assets/world/alert.png")
	alert.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	alert.scale = Vector2(2, 2)
	alert.position = Vector2(0, -138)
	alert.z_index = 6
	alert.visible = false
	add_child(alert)

	buy = Sprite2D.new()
	buy.texture = load("res://assets/world/buy.png")
	buy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	buy.scale = Vector2(2, 2)
	buy.position = Vector2(22, -100)
	buy.z_index = 6
	buy.visible = false
	add_child(buy)

	bubble = _tag("", Color(1.0, 0.95, 0.6), Color(0.1, 0.1, 0.14, 0.8))
	bubble.position = Vector2(-45, -110)
	bubble.visible = false
	add_child(bubble)

	name_tag = _tag(p_name, Color(1, 1, 1), Color(0, 0, 0, 0.45))
	name_tag.position = Vector2(-90, 6)
	name_tag.size = Vector2(180, 20)
	name_tag.visible = p_name != ""
	add_child(name_tag)


func _tag(text: String, color: Color, bg: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(90, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 5
	return l


func set_alert(on: bool) -> void:
	if alert != null:
		alert.visible = on


func set_bubble(text: String) -> void:
	bubble.text = text
	bubble.visible = text != ""


func get_col() -> Rect2:
	return Rect2(position.x - 18.0, position.y - 16.0, 36.0, 22.0)


func start_patrol(p_points: Array) -> void:
	mode = "patrol"
	points = p_points
	point_i = 1
	position = points[0]
	wait = randf_range(0.5, 3.0)


func start_town(p_home: int) -> void:
	mode = "town"
	home = p_home
	at = p_home
	goal = p_home
	step = p_home
	side = Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0))
	speed = randf_range(95.0, 135.0)
	var start: Vector2 = WorldData.WALK_NODES[p_home]
	position = start + side
	name_tag.visible = false
	state = "inside"
	visible = false
	timer = randf_range(0.5, 14.0)


func _process(delta: float) -> void:
	bob += delta
	if alert.visible:
		alert.position.y = -138.0 + sin(bob * 5.0) * 5.0
	if Game.paused:
		return
	if mode == "patrol":
		_patrol(delta)
	elif mode == "town":
		_town(delta)
	else:
		var to_player: Vector2 = Game.player_pos - position
		if to_player.length() < 240.0:
			face(to_player)
			show_frame(0)


func _patrol(delta: float) -> void:
	if points.size() < 2:
		return
	if wait > 0.0:
		wait -= delta
		animate(Vector2.ZERO, delta)
		return
	var target: Vector2 = points[point_i]
	var to: Vector2 = target - position
	if to.length() < 6.0:
		point_i = (point_i + 1) % points.size()
		wait = randf_range(2.5, 4.5)
		return
	var dir: Vector2 = to.normalized()
	position += dir * speed * delta
	animate(dir, delta)


func _town(delta: float) -> void:
	if state == "walk":
		var node_pos: Vector2 = WorldData.WALK_NODES[step]
		var to: Vector2 = node_pos + side - position
		if to.length() < 5.0:
			at = step
			if at == goal:
				_arrive()
			else:
				step = WorldData.WALK_NEXT[at][goal]
			return
		var dir: Vector2 = to.normalized()
		position += dir * speed * delta
		animate(dir, delta)
	else:
		timer -= delta
		if timer <= 0.0:
			_pick_goal()


func _arrive() -> void:
	animate(Vector2.ZERO, 0.0)
	if goal == home:
		state = "inside"
		visible = false
		timer = randf_range(6.0, 16.0)
	elif WorldData.WALK_STALLS.has(goal):
		state = "shop"
		face(Vector2(0, -1))
		show_frame(0)
		buy.visible = true
		timer = randf_range(3.5, 7.0)
	else:
		state = "idle"
		timer = randf_range(2.0, 5.0)


func _pick_goal() -> void:
	buy.visible = false
	if Game.shelter:
		if at == home:
			state = "inside"
			visible = false
			timer = randf_range(4.0, 8.0)
			return
		goal = home
	else:
		var r: float = randf()
		if r < 0.55:
			goal = WorldData.WALK_STALLS[randi() % WorldData.WALK_STALLS.size()]
		elif r < 0.8:
			goal = WorldData.WALK_HANG[randi() % WorldData.WALK_HANG.size()]
		else:
			goal = home
	if goal == at:
		timer = 1.0
		return
	visible = true
	state = "walk"
	step = WorldData.WALK_NEXT[at][goal]
