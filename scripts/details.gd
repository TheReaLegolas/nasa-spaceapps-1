extends Node
# Small touches that make New Hope feel alive:
#   - you can sit on a bench and rest (health comes back faster while you sit)
#   - the street lamps light up at night, and go dark when the battery is empty
#   - townspeople say hello when you walk past them
#   - your boots kick up a little dust
# main.gd calls update() every frame.

const GREETINGS := ["Hello!", "Hi there!", "Nice sol!", "Good job!", "Stay safe!", "Howdy!", "Go, Operator!"]
const GREET_DISTANCE := 120.0      # how close you must be for a hello
const GREET_AGAIN := 30.0          # seconds before the same person says hello again
const REST_BONUS := 4.0            # health comes back this many times faster on a bench
const LAMP_COLOR := Color(1.0, 0.86, 0.6)

var main
var lamps: Array = []              # each one is {"light": PointLight2D, "bulb": Polygon2D}
var lights_out := false            # true in the sad ending: every lamp goes dark
var greet_timer := 0.0
var greeted := {}                  # a person's id -> the time they may say hello again
var bubbles: Array = []            # speech bubbles that are showing: [person, seconds left]
var bench = null                   # the bench the player is sitting on (or null)
var puffs: Array = []              # dust puffs from the player's boots
var puff_timer := 0.0


func setup(p_main) -> void:
	main = p_main
	_make_lamps()


# ---------------------------------------------------------------- street lamps

func _make_lamps() -> void:
	# one soft round light, shared by every lamp
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(0, 0, 0, 0))
	var glow := GradientTexture2D.new()
	glow.gradient = fade
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	for m in main.things:
		if not str(m.tid).begins_with("lamp"):
			continue
		var light := PointLight2D.new()
		light.texture = glow
		light.texture_scale = 3.4
		light.color = LAMP_COLOR
		light.energy = 0.0
		light.enabled = false
		light.position = Vector2(0, -56)
		m.add_child(light)
		var bulb := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in 10:
			var a: float = TAU * float(j) / 10.0
			pts.append(Vector2(cos(a) * 7.0, sin(a) * 7.0))
		bulb.polygon = pts
		bulb.color = Color(1.0, 0.95, 0.7, 0.0)
		bulb.position = Vector2(0, -float(m.art_h) + 14.0)
		m.add_child(bulb)
		lamps.append({"light": light, "bulb": bulb})


func _update_lamps(delta: float) -> void:
	# lamps come on as it gets dark. No power in the battery means no light.
	var want := 0.0
	if not lights_out and main.energy > 0.0:
		want = clampf((1.0 - main._sun()) * 1.3, 0.0, 1.0)
	for l in lamps:
		var light: PointLight2D = l["light"]
		var bulb: Polygon2D = l["bulb"]
		light.energy = move_toward(light.energy, want * 0.9, delta * 1.2)
		light.enabled = light.energy > 0.01
		bulb.color.a = clampf(light.energy / 0.9, 0.0, 1.0)


# ---------------------------------------------------------------- hellos

func _update_greetings(delta: float) -> void:
	var keep := []
	for b in bubbles:
		b[1] = float(b[1]) - delta
		var who = b[0]
		if float(b[1]) <= 0.0 or not is_instance_valid(who):
			if is_instance_valid(who):
				who.set_bubble("")
		else:
			keep.append(b)
	bubbles = keep
	greet_timer -= delta
	if greet_timer > 0.0:
		return
	greet_timer = 0.35
	if main.driving != null or Game.paused:
		return
	for n in main.towns:
		if not n.visible or n.bubble.visible:
			continue
		var id: int = n.get_instance_id()
		if main.elapsed < float(greeted.get(id, 0.0)):
			continue
		if n.position.distance_to(main.player.position) > GREET_DISTANCE:
			continue
		n.set_bubble(GREETINGS[randi() % GREETINGS.size()])
		bubbles.append([n, 2.2])
		greeted[id] = main.elapsed + GREET_AGAIN
		return                     # one hello at a time


# ---------------------------------------------------------------- dust from your boots

func _update_boot_dust(delta: float) -> void:
	if main.player.moving and main.player.visible and not Game.paused:
		puff_timer -= delta
		if puff_timer <= 0.0:
			puff_timer = 0.16
			var puff := Polygon2D.new()
			var pts := PackedVector2Array()
			for j in 8:
				var a: float = TAU * float(j) / 8.0
				pts.append(Vector2(cos(a) * 5.0, sin(a) * 3.0))
			puff.polygon = pts
			puff.color = Color(0.88, 0.64, 0.48, 0.5)
			puff.position = main.player.position + Vector2(randf_range(-6.0, 6.0), randf_range(-2.0, 2.0))
			puff.z_index = -1
			main.world.add_child(puff)
			puffs.append({"node": puff, "life": 0.45})
	if puffs.is_empty():
		return
	var keep := []
	for d in puffs:
		var node: Polygon2D = d["node"]
		d["life"] = float(d["life"]) - delta
		node.position.y -= 10.0 * delta
		node.scale += Vector2(1.4, 1.4) * delta
		node.color.a = clampf(float(d["life"]) / 0.45, 0.0, 1.0) * 0.5
		if float(d["life"]) <= 0.0:
			node.queue_free()
		else:
			keep.append(d)
	puffs = keep


# ---------------------------------------------------------------- benches

func sitting() -> bool:
	return bench != null


func sit(on_bench) -> void:
	var p = main.player
	bench = on_bench
	p.sitting = true
	p.knock = Vector2.ZERO
	# in front of the bench, lifted onto the seat and a little shorter: that reads as sitting
	p.position = on_bench.position + Vector2(0, 2)
	p.face(Vector2(0, 1))
	p.show_frame(0)
	p.body.position = Vector2(0, -12)
	p.body.scale = Vector2(2.0, 1.72)
	Sfx.play("ui_select")
	main.hud.toast("You sit down and rest. Health comes back faster while you sit.")


func stand() -> void:
	if bench == null:
		return
	var p = main.player
	var from = bench
	bench = null
	p.sitting = false
	p.body.position = Vector2.ZERO
	p.body.scale = Vector2(2, 2)
	p.position = p.push_out(from.position + Vector2(0, 26))


func rest_bonus() -> float:
	# how much faster health comes back right now
	if bench != null:
		return REST_BONUS
	return 1.0


# ---------------------------------------------------------------- every frame

func update(delta: float) -> void:
	_update_lamps(delta)
	_update_greetings(delta)
	_update_boot_dust(delta)
	# stand up as soon as the player wants to walk away
	if bench != null and not Game.paused:
		if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.3:
			stand()
