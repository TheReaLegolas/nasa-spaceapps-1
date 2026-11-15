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

# movement animation: the body bounces on its wheels, leans when it turns and leaves dust behind
var last_pos := Vector2.ZERO
var anim_t := 0.0              # runs while the vehicle is moving
var rolling := 0.0             # 0 = standing still, 1 = driving (changes smoothly)
var squash := 0.0              # a quick squeeze when it starts, stops or turns
var puff_timer := 0.0
var puffs: Array = []          # dust puffs on the ground: {"node", "life", "vel"}

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
	last_pos = position


func set_facing(f: String) -> void:
	if f == facing:
		return
	if facing != "":
		squash = 1.0               # lean into the turn
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
	# the roads run on past the uneven edge of the map, but vehicles cannot
	if not Game.inside_map(p):
		return false
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
	# look a little ahead, so the nose of the rover stops at the edge of the map
	var try_x: Vector2 = Vector2(position.x + move.x, position.y)
	if on_road(try_x) and Game.inside_map(try_x + Vector2(signf(move.x) * 70.0, 0.0)):
		position = try_x
	var try_y: Vector2 = Vector2(position.x, position.y + move.y)
	if on_road(try_y) and Game.inside_map(try_y + Vector2(0.0, signf(move.y) * 70.0)):
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
	_animate(delta)
	_drive_itself(delta)


func _animate(delta: float) -> void:
	# bounce, lean and dust: this is what makes a vehicle look like it is really driving
	_update_puffs(delta)
	if Game.paused:
		last_pos = position
		return
	var step: Vector2 = position - last_pos
	last_pos = position
	var is_moving: bool = step.length() > 0.2 and step.length() < 200.0
	var target := 0.0
	if is_moving:
		target = 1.0
	if (rolling < 0.5) != (target < 0.5):
		squash = 1.0               # the body dips when it sets off and when it brakes
	rolling = move_toward(rolling, target, delta * 5.0)
	squash = move_toward(squash, 0.0, delta * 5.0)
	if is_moving:
		anim_t += delta
	var sideways: bool = facing == "left" or facing == "right"
	# the body hops on the bumpy ground; a truck is heavier, so it hops less
	var hop: float = 2.6
	if kind == "truck":
		hop = 1.8
	var bounce: float = -absf(sin(anim_t * 17.0)) * hop * rolling
	# a parked rover with the driver inside shakes a tiny bit: the engine is running
	if mode == "driven" and rolling < 0.1:
		bounce = sin(Time.get_ticks_msec() / 28.0) * 0.5
	sprite.position = Vector2(0.0, bounce)
	if sideways:
		sprite.rotation = sin(anim_t * 8.5) * 0.022 * rolling
	else:
		sprite.rotation = 0.0
		sprite.position.x = sin(anim_t * 8.5) * 1.2 * rolling
	sprite.scale = Vector2(2.0 + 0.11 * squash, 2.0 - 0.11 * squash)
	# dust behind the wheels
	if is_moving:
		puff_timer -= delta
		if puff_timer <= 0.0:
			puff_timer = 0.07
			var back: Vector2 = -step.normalized()
			_add_puff(position + back * 52.0 + Vector2(randf_range(-10.0, 10.0), 8.0 + randf_range(-6.0, 6.0)), back)


func _add_puff(at: Vector2, back: Vector2) -> void:
	var parent = get_parent()
	if parent == null or puffs.size() > 40:
		return
	var puff := Polygon2D.new()
	var pts := PackedVector2Array()
	for j in 10:
		var a: float = TAU * float(j) / 10.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 5.0))
	puff.polygon = pts
	puff.color = Color(0.86, 0.62, 0.46, 0.55)
	puff.position = at
	puff.z_index = -1              # flat on the ground, under people and vehicles
	parent.add_child(puff)
	puffs.append({"node": puff, "life": 0.7, "vel": back * 40.0 + Vector2(0.0, -14.0)})


func _update_puffs(delta: float) -> void:
	if puffs.is_empty():
		return
	var keep := []
	for d in puffs:
		var node: Polygon2D = d["node"]
		d["life"] = float(d["life"]) - delta
		var vel: Vector2 = d["vel"]
		node.position += vel * delta
		node.scale += Vector2(1.6, 1.6) * delta
		node.color.a = clampf(float(d["life"]) / 0.7, 0.0, 1.0) * 0.55
		if float(d["life"]) <= 0.0:
			node.queue_free()
		else:
			keep.append(d)
	puffs = keep


func _drive_itself(delta: float) -> void:
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
