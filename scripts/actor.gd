extends Node2D
# A character drawn from one of the sprite sheets in assets/chars.
# Each sheet has frames of 32x48 pixels: row 0 is a standing turnaround, and
# rows 1 to 8 hold a 10-frame walk for the 8 directions we use
# (up, up-right, right, down-right, down, down-left, left, up-left).

var body: Sprite2D
var dir8 := 4          # 0 = up, 2 = right, 4 = down, 6 = left
var anim_t := 0.0


func setup_actor(sheet: String) -> void:
	body = Sprite2D.new()
	body.texture = load("res://assets/chars/%s.png" % sheet)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.hframes = 20
	body.vframes = 9
	body.scale = Vector2(2, 2)
	body.offset = Vector2(0, -20)      # puts the feet on the node's position
	add_child(body)
	show_frame(0)


func animate(move: Vector2, delta: float) -> void:
	# call every frame with the direction of movement (zero when standing still)
	if move.length() > 0.01:
		face(move)
		anim_t += delta * 12.0
		show_frame(int(anim_t) % 10)
	else:
		anim_t = 0.0
		show_frame(0)


func face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	var a: float = atan2(v.x, -v.y)        # 0 = up, growing clockwise
	var d: int = int(round(a / (PI / 4.0))) % 8
	if d < 0:
		d += 8
	dir8 = d


func show_frame(col: int) -> void:
	if body != null:
		body.frame_coords = Vector2i(col, 1 + dir8)
