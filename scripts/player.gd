extends Node2D
# The player: walks in four directions and cannot walk through buildings.

const SPEED := 240.0

var sprite: Sprite2D
var tex := {}
var walk_t := 0.0
var obstacles: Array = []      # shared list of machines from main.gd
var world_size := Vector2(2000, 1400)
var frozen := false
var knock := Vector2.ZERO


func setup(character: String) -> void:
	for d in ["down", "up", "side"]:
		tex[d] = load("res://assets/player/%s_%s.png" % [character, d])
	sprite = Sprite2D.new()
	sprite.texture = tex["down"]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.4, 1.4)
	sprite.offset = Vector2(0, -35)
	add_child(sprite)


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not frozen:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	position += (dir * SPEED + knock) * delta
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)

	# push the player out of anything solid
	for o in obstacles:
		if not is_instance_valid(o):
			continue
		var c: Vector2 = o.collider_center()
		var r: float = o.radius + 14.0
		var diff: Vector2 = position - c
		var dist: float = diff.length()
		if dist < r:
			if dist < 0.01:
				diff = Vector2(0, 1)
				dist = 1.0
			position = c + diff / dist * r

	position.x = clampf(position.x, 40.0, world_size.x - 40.0)
	position.y = clampf(position.y, 90.0, world_size.y - 30.0)

	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			sprite.texture = tex["side"]
			sprite.flip_h = dir.x < 0.0
		elif dir.y > 0.0:
			sprite.texture = tex["down"]
			sprite.flip_h = false
		else:
			sprite.texture = tex["up"]
			sprite.flip_h = false
		walk_t += delta * 12.0
		sprite.position.y = -absf(sin(walk_t)) * 4.0
	else:
		walk_t = 0.0
		sprite.position.y = 0.0
