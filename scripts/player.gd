extends "res://scripts/actor.gd"
# The player: walks in 8 directions with a walking animation and cannot walk
# through buildings, rocks, colonists or vehicles.

const SPEED := 300.0
const RADIUS := 16.0

var solids: Array = []             # shared list from main.gd: everything that blocks
var world_size := Vector2(6000, 4200)
var in_vehicle := false            # true while driving a rover
var knock := Vector2.ZERO          # push from being hit by flying debris
var edge_push := 0.0               # how long the player has been walking into the edge of the map
var step_timer := 0.0              # time until the next footstep sound
var on_wrap := Callable()          # main.gd is told when the player comes out on the other side

const EDGE_SECONDS := 0.35         # walk into the edge this long to come out on the other side


func _process(delta: float) -> void:
	if in_vehicle:
		return
	var dir := Vector2.ZERO
	if not Game.paused:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += (dir * SPEED + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	position = push_out(position)
	var min_x := 30.0
	var max_x: float = world_size.x - 30.0
	var min_y := 100.0
	var max_y: float = world_size.y - 20.0
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)

	# Like Pac-Man: walk off one edge of the map and you come back in on the opposite side.
	var out := Vector2.ZERO
	if dir.x < -0.3 and position.x <= min_x + 1.0:
		out = Vector2(-1, 0)
	elif dir.x > 0.3 and position.x >= max_x - 1.0:
		out = Vector2(1, 0)
	elif dir.y < -0.3 and position.y <= min_y + 1.0:
		out = Vector2(0, -1)
	elif dir.y > 0.3 and position.y >= max_y - 1.0:
		out = Vector2(0, 1)
	if out == Vector2.ZERO:
		edge_push = 0.0
	else:
		edge_push += delta
		if edge_push >= EDGE_SECONDS:
			edge_push = 0.0
			if out.x < 0.0:
				position.x = max_x - 6.0
			elif out.x > 0.0:
				position.x = min_x + 6.0
			elif out.y < 0.0:
				position.y = max_y - 6.0
			else:
				position.y = min_y + 6.0
			position = push_out(position)
			if on_wrap.is_valid():
				on_wrap.call()
	animate(dir, delta)
	if dir.length() > 0.1:
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.3
			Sfx.play("step", randf_range(0.85, 1.15))
	else:
		step_timer = 0.0


func push_out(p: Vector2) -> Vector2:
	# if the point is inside something solid, move it to the nearest edge
	for pass_i in 2:
		for o in solids:
			if not is_instance_valid(o):
				continue
			if not o.solid:
				continue
			var c: Rect2 = o.get_col()
			var r: Rect2 = c.grow(RADIUS)
			if not r.has_point(p):
				continue
			var left: float = p.x - r.position.x
			var right: float = r.end.x - p.x
			var up: float = p.y - r.position.y
			var down: float = r.end.y - p.y
			var m: float = minf(minf(left, right), minf(up, down))
			if m == left:
				p.x = r.position.x
			elif m == right:
				p.x = r.end.x
			elif m == up:
				p.y = r.position.y
			else:
				p.y = r.end.y
	return p
