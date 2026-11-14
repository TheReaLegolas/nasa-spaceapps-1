extends "res://scripts/actor.gd"
# The player: walks in 8 directions with a walking animation and cannot walk
# through buildings, rocks, colonists or vehicles.

const SPEED := 300.0
const RADIUS := 16.0

var solids: Array = []             # shared list from main.gd: everything that blocks
var world_size := Vector2(6000, 4200)
var in_vehicle := false            # true while driving a rover
var knock := Vector2.ZERO          # push from being hit by flying debris


func _process(delta: float) -> void:
	if in_vehicle:
		return
	var dir := Vector2.ZERO
	if not Game.paused:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += (dir * SPEED + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	position = push_out(position)
	position.x = clampf(position.x, 30.0, world_size.x - 30.0)
	position.y = clampf(position.y, 100.0, world_size.y - 20.0)
	animate(dir, delta)


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
