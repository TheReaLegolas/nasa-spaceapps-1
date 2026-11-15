extends "res://scripts/actor.gd"
# The player: walks in 8 directions with a walking animation and cannot walk
# through buildings, rocks, colonists or vehicles, or past the uneven edge of the map.

const SPEED := 300.0
const RADIUS := 16.0

var solids: Array = []             # shared list from main.gd: everything that blocks
var world_size := Vector2(6000, 4200)
var in_vehicle := false            # true while driving a rover (and during the films)
var sitting := false               # true while resting on a bench: main.gd decides when to stand up
var knock := Vector2.ZERO          # push from being hit by flying debris
var step_timer := 0.0              # time until the next footstep sound
var moving := false                # true while the player is really walking (used for the little dust puffs)


func _process(delta: float) -> void:
	moving = false
	if in_vehicle or sitting:
		return
	var dir := Vector2.ZERO
	if not Game.paused:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var before: Vector2 = position
	position += (dir * SPEED + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	position = push_out(position)
	position.x = clampf(position.x, 30.0, world_size.x - 30.0)
	position.y = clampf(position.y, 100.0, world_size.y - 20.0)

	# The edge of the map is an uneven ridge. If a step would cross it, slide along it instead.
	if not Game.inside_map(position):
		var slide_x := Vector2(position.x, before.y)
		var slide_y := Vector2(before.x, position.y)
		if Game.inside_map(slide_x):
			position = slide_x
		elif Game.inside_map(slide_y):
			position = slide_y
		elif Game.inside_map(before):
			position = before

	moving = dir.length() > 0.1 and position.distance_to(before) > 0.5
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
			if o.has_method("get_shape"):
				var outline: PackedVector2Array = o.get_shape()
				if outline.size() >= 3:
					# a building with a real outline (a round dome, a sloped roof...)
					p = _push_out_of_outline(p, outline)
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


func _push_out_of_outline(p: Vector2, outline: PackedVector2Array) -> Vector2:
	# keeps the player RADIUS pixels away from the outline of a building
	var nearest := p
	var best := 999999.0
	for i in outline.size():
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])
		var d: float = p.distance_to(q)
		if d < best:
			best = d
			nearest = q
	if Geometry2D.is_point_in_polygon(p, outline):
		# inside the building: go to the nearest wall and a little further out
		var out: Vector2 = nearest - p
		if out.length() < 0.01:
			out = Vector2(0, 1)
		return nearest + out.normalized() * RADIUS
	if best < RADIUS:
		var away: Vector2 = p - nearest
		if away.length() < 0.01:
			away = Vector2(0, 1)
		return nearest + away.normalized() * RADIUS
	return p
