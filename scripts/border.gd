extends Node2D
# The land outside the map. Mars is not a neat rectangle, so the ground ends in a
# messy, uneven ridge (the line is WorldData.BORDER). This script paints the dark
# highlands beyond that ridge, with boulders on them. Nobody can go there.

const WorldData = preload("res://scripts/world_data.gd")

const HIGHLAND := Color(0.36, 0.17, 0.12)       # the ground beyond the ridge
const RIDGE_DARK := Color(0.22, 0.09, 0.07)     # the shadow side of the ridge
const RIDGE_LIGHT := Color(0.6, 0.3, 0.2)       # the sunny rim of the ridge
const BOULDERS := 900                           # how many boulders to try to place

var boulders: Array = []       # each one is [position, size, colour]


func _ready() -> void:
	z_index = -9                   # above the ground pictures, under everything else
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030                # the same boulders every game
	var size: Vector2 = WorldData.WORLD_SIZE
	for i in BOULDERS:
		var p := Vector2(rng.randf_range(-40.0, size.x + 40.0), rng.randf_range(-40.0, size.y + 40.0))
		var r: float = rng.randf_range(5.0, 22.0)
		var shade: float = rng.randf_range(-0.05, 0.07)
		if Game.inside_map(p):
			continue
		boulders.append([p, r, Color(HIGHLAND.r + shade, HIGHLAND.g + shade * 0.6, HIGHLAND.b + shade * 0.5)])


static func outer_point(p: Vector2, size: Vector2, grow: float) -> Vector2:
	# where the line from the middle of the map through p reaches the edge of the picture
	var c: Vector2 = size / 2.0
	var d: Vector2 = p - c
	var t := 999999.0
	if absf(d.x) > 0.001:
		t = minf(t, (size.x / 2.0 + grow) / absf(d.x))
	if absf(d.y) > 0.001:
		t = minf(t, (size.y / 2.0 + grow) / absf(d.y))
	return c + d * t


static func outside_pieces(border: PackedVector2Array, size: Vector2, grow: float) -> Array:
	# the land between the uneven edge and the edge of the picture, cut into simple pieces
	var pieces := []
	var n: int = border.size()
	for i in n:
		var a: Vector2 = border[i]
		var b: Vector2 = border[(i + 1) % n]
		var oa: Vector2 = outer_point(a, size, grow)
		var ob: Vector2 = outer_point(b, size, grow)
		var piece := PackedVector2Array([a, b, ob])
		if absf(oa.x - ob.x) > 0.5 and absf(oa.y - ob.y) > 0.5:
			# this piece goes around a corner of the picture: add the corner itself
			var corner := Vector2(oa.x, ob.y)
			if absf(absf(corner.x - size.x / 2.0) - (size.x / 2.0 + grow)) > 0.5 or absf(absf(corner.y - size.y / 2.0) - (size.y / 2.0 + grow)) > 0.5:
				corner = Vector2(ob.x, oa.y)
			piece.append(corner)
		piece.append(oa)
		pieces.append(piece)
	return pieces


func _draw() -> void:
	var border: PackedVector2Array = Game.border
	if border.size() < 3:
		return
	for piece in outside_pieces(border, WorldData.WORLD_SIZE, 60.0):
		var poly: PackedVector2Array = piece
		draw_colored_polygon(poly, HIGHLAND)
	for b in boulders:
		var p: Vector2 = b[0]
		var r: float = b[1]
		var col: Color = b[2]
		draw_circle(p + Vector2(0.0, r * 0.25), r, RIDGE_DARK)
		draw_circle(p, r, col)
	# the ridge itself: a dark band with a lighter rim on top
	var line := PackedVector2Array(border)
	line.append(border[0])
	draw_polyline(line, RIDGE_DARK, 30.0)
	draw_polyline(line, RIDGE_LIGHT, 7.0)
