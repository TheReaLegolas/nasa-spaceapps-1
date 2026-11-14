extends Node2D
# A vehicle. Rovers are parked until the player drives them; trucks drive
# themselves along a route. Vehicles stay on the roads.
# The node's position is the middle of the vehicle on the ground.

const WorldData = preload("res://scripts/world_data.gd")

var what := "vehicle"
var kind := "rover"            # "rover" or "truck"
var mode := "parked"           # "parked", "driven" or "ai"
var solid := true
var facing := ""               # "left", "right", "up" or "down"
var sprite: Sprite2D
var tex_side: Texture2D
var tex_down: Texture2D
var tex_up: Texture2D
var foot := 17.0               # how far below the middle the wheels touch the ground (art pixels)
var drive_speed := 560.0

# self-driving trucks
var route: Array = []
var route_i := 1
var route_step := 1
var ai_speed := 190.0
var lane := 36.0


func setup(p_kind: String, pos: Vector2) -> void:
	kind = p_kind
	position = pos
	if kind == "truck":
		foot = 19.0
	tex_side = load("res://assets/world/%s_side.png" % kind)
	tex_down = load("res://assets/world/%s_down.png" % kind)
	tex_up = load("res://assets/world/%s_up.png" % kind)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	set_facing("right")


func set_facing(f: String) -> void:
	if f == facing:
		return
	facing = f
	if f == "left" or f == "right":
		sprite.texture = tex_side
		sprite.flip_h = f == "left"
	elif f == "down":
		sprite.texture = tex_down
		sprite.flip_h = false
	else:
		sprite.texture = tex_up
		sprite.flip_h = false
	if sprite.texture != null:
		sprite.offset = Vector2(0, -float(sprite.texture.get_height()) / 2.0 + foot)


func get_col() -> Rect2:
	var sideways: bool = facing == "left" or facing == "right"
	var half_w := 44.0
	var top := -36.0
	var bottom := 34.0
	if kind == "truck":
		half_w = 50.0
		top = -42.0
		bottom = 38.0
		if sideways:
			half_w = 80.0
			top = -30.0
	elif sideways:
		half_w = 62.0
		top = -26.0
	return Rect2(position.x - half_w, position.y + top, half_w * 2.0, bottom - top)


func on_road(p: Vector2) -> bool:
	for d in WorldData.DRIVE_RECTS:
		var r: Rect2 = d
		if r.has_point(p):
			return true
	return false


func drive(dir: Vector2, delta: float) -> bool:
	# moves the rover if the road allows it; returns true if it moved
	if dir.length() < 0.01:
		return false
	var before: Vector2 = position
	var move: Vector2 = dir.normalized() * drive_speed * delta
	var try_x: Vector2 = Vector2(position.x + move.x, position.y)
	if on_road(try_x):
		position = try_x
	var try_y: Vector2 = Vector2(position.x, position.y + move.y)
	if on_road(try_y):
		position = try_y
	if absf(dir.x) >= absf(dir.y):
		if dir.x > 0.0:
			set_facing("right")
		else:
			set_facing("left")
	elif dir.y > 0.0:
		set_facing("down")
	else:
		set_facing("up")
	return position.distance_to(before) > 0.01


func start_route(p_route: Array) -> void:
	route = p_route
	mode = "ai"
	route_i = 1
	route_step = 1
	position = _lane_point(0)


func _seg_dir(i_from: int, i_to: int) -> Vector2:
	var a: Vector2 = route[i_from]
	var b: Vector2 = route[i_to]
	return (b - a).normalized()


func _right_of(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


func _lane_point(i: int) -> Vector2:
	# the point to aim for at corner i of the route, keeping to the right-hand lane
	var p: Vector2 = route[i]
	var prev_i: int = i - route_step
	var next_i: int = i + route_step
	var off := Vector2.ZERO
	if prev_i >= 0 and prev_i < route.size():
		off += _right_of(_seg_dir(prev_i, i)) * lane
	if next_i >= 0 and next_i < route.size():
		off += _right_of(_seg_dir(i, next_i)) * lane
	return p + off


func _process(delta: float) -> void:
	if mode != "ai" or Game.paused:
		return
	if route.size() < 2:
		return
	var target: Vector2 = _lane_point(route_i)
	var to: Vector2 = target - position
	if to.length() < 4.0:
		var next_i: int = route_i + route_step
		if next_i < 0 or next_i >= route.size():
			route_step = -route_step      # end of the route: cross to the other lane and go back
		else:
			route_i = next_i
		return
	var dir: Vector2 = to.normalized()
	# wait while the player is right in front
	var ahead: Vector2 = Game.player_pos - position
	var front: float = ahead.dot(dir)
	var sideways: float = absf(ahead.dot(_right_of(dir)))
	if front > 0.0 and front < 210.0 and sideways < 90.0:
		return
	position += dir * minf(ai_speed * delta, to.length())
	if absf(dir.x) >= absf(dir.y):
		if dir.x > 0.0:
			set_facing("right")
		else:
			set_facing("left")
	elif dir.y > 0.0:
		set_facing("down")
	else:
		set_facing("up")
