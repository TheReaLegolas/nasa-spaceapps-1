extends Node
# The films of the game. main.gd starts them and calls update() every frame.
#   intro    - the President talks to you on the rocket pad, boards his rocket and lifts off
#   party    - the happy ending: after the rocket lands, New Hope throws a welcome party
#   collapse - the sad ending: the camera glides from right to left while everything stops working
# Change the lines in INTRO_TALK and PARTY_TALK to change what people say.

const ActorScript = preload("res://scripts/actor.gd")
const WorldData = preload("res://scripts/world_data.gd")

const PAD_POS := Vector2(760, 790)          # where the rocket stands (same as in main.gd)
const INTRO_VIEW := Vector2(760, 880)       # where the camera looks in the opening scene
const PARTY_VIEW := Vector2(760, 760)       # where the camera looks when the party starts (the landing view in main.gd)
const YOU := "You"

# "{sols}" becomes the number of sols the President is away, "{president}" his name.
const INTRO_TALK := [
	["{president}", "Good morning, Operator! Big news: hundreds of new settlers are getting ready to move from Earth to our town, New Hope."],
	["You", "New settlers? That is wonderful! When will they get here?"],
	["{president}", "I am flying to Earth to welcome them and bring them here safely. The trip there and back takes {sols} sols. A 'sol' is a day on Mars, a little longer than a day on Earth."],
	["You", "{sols} sols is a long time. Who looks after New Hope while you are away?"],
	["{president}", "You do! While I am away, YOU are in charge: the energy, the oxygen, the food and every repair."],
	["You", "Me? In charge of the whole town? I will do my best, Mr. President!"],
	["Pilot", "The rocket is ready, Mr. President. We can lift off as soon as you are on board."],
	["{president}", "Remember: there is never enough power for everything, so every choice has a cost. Think first, then choose. See you in {sols} sols, Operator!"],
]

const PARTY_TALK := [
	["{president}", "New Hope, meet your new neighbours! And new neighbours, meet the Operator who kept this town alive for {sols} sols."],
	["New settlers", "Three cheers for the Operator! Hip hip... HOORAY!"],
	["Ada, Mars News", "This is Ada for Mars News: it is the best party on the whole planet. It is also the only party on the planet!"],
	["Farmer Tom", "Potato soup for everyone! And potato cake. And potato juice. We have a LOT of potatoes."],
]

# What the top of the screen says in the sad ending, for each way to lose.
const COLLAPSE_LINES := {
	"oxygen": "The oxygen ran out, so everyone moved into the emergency shelter.",
	"hunger": "The food ran out, so everyone moved into the emergency shelter.",
	"cold": "The freezing nights were too much, so everyone moved into the emergency shelter.",
	"radiation": "There was too much radiation, so everyone moved into the emergency shelter.",
	"debris": "The storm hit too hard, so everyone moved into the emergency shelter.",
}
const COLLAPSE_SECONDS := 14.0     # how long the camera takes to glide across the map
const COLLAPSE_ZOOM := 0.5         # zoomed out, so you see a lot of the colony at once

const PARTY_COLORS := [Color(1.0, 0.35, 0.35), Color(1.0, 0.8, 0.25), Color(0.4, 0.9, 0.5), Color(0.4, 0.7, 1.0), Color(0.85, 0.5, 1.0), Color(1.0, 0.6, 0.85)]

var main
var active := false            # true while the intro or the sad ending plays: the game rules wait
var mode := ""                 # "intro" or "collapse"
var stage := ""
var t := 0.0                   # seconds since the film started
var stage_t := 0.0             # seconds since this part of the film started

# intro
var president
var pilot
var count_shown := -1

# party
var party_t := 0.0
var party_stage := ""
var party_stage_t := 0.0
var dancers: Array = []        # everyone who dances: {"actor", "phase", "spin"}
var bits: Array = []           # fireworks and confetti: {"node", "vel", "life", "gravity", "sway"}
var burst_timer := 0.0
var confetti_timer := 0.0
var bursts := 0

# collapse
var collapse_done := Callable()
var falling: Array = []        # every building and machine: {"m", "x", "delay", "tilt", "at", "hit"}
var smoke: Array = []
var sky_from := Color(1, 1, 1)
var last_crash := -9.0


func setup(p_main) -> void:
	main = p_main


func _fill(text: String) -> String:
	return text.replace("{sols}", str(Game.TOTAL_SOLS)).replace("{president}", str(main.PRESIDENT))


func _set_stage(s: String) -> void:
	stage = s
	stage_t = 0.0


func _actor(sheet: String, at: Vector2):
	var a = ActorScript.new()
	main.world.add_child(a)
	a.setup_actor(sheet)
	a.position = at
	return a


func _walk(a, to: Vector2, speed: float, delta: float) -> bool:
	# one step towards a place; true when the actor is there
	var gap: Vector2 = to - a.position
	if gap.length() <= 4.0:
		a.show_frame(0)
		return true
	a.position = a.position.move_toward(to, speed * delta)
	a.animate(gap.normalized(), delta)
	return false


func update(delta: float) -> void:
	if not active:
		return
	t += delta
	stage_t += delta
	if mode == "intro":
		_update_intro(delta)
	elif mode == "collapse":
		_update_collapse(delta)


func skip() -> void:
	# ESC: jump to the end of the film
	if not active:
		return
	if mode == "intro":
		_end_intro()
	elif mode == "collapse":
		_end_collapse()


# =====================================================================
#  THE OPENING: the President says goodbye and lifts off
# =====================================================================

func start_intro() -> void:
	active = true
	mode = "intro"
	t = 0.0
	_set_stage("arrive")
	var p = main.player
	p.in_vehicle = true                # stops the keyboard from moving the player
	p.position = PAD_POS + Vector2(-64, 214)
	president = _actor("president", PAD_POS + Vector2(46, 200))
	pilot = _actor("town6", PAD_POS + Vector2(130, 150))
	p.face(president.position - p.position)
	p.show_frame(0)
	president.face(p.position - president.position)
	president.show_frame(0)
	pilot.face(p.position - pilot.position)
	pilot.show_frame(0)
	Game.player_pos = p.position
	# the rocket stands ready on its pad
	main._make_rocket()
	main.rocket.position = PAD_POS
	main.rocket_flame.visible = false
	main.cam.position_smoothing_enabled = false
	main.cam.position = INTRO_VIEW
	main.hud.start_cinematic()
	main.hud.set_hint("ESC: skip the film")
	main.hud.set_caption("New Hope, Mars. The year 3030.")
	main.hud.fade_in()
	main.learn.layer.visible = false


func _update_intro(delta: float) -> void:
	var p = main.player
	Game.player_pos = p.position
	main._update_dust(delta)
	if stage == "arrive":
		if stage_t >= 1.6:
			_set_stage("talk")
			main.hud.set_caption("")
			for line in INTRO_TALK:
				main._say(_fill(str(line[0])), _fill(str(line[1])))
	elif stage == "talk":
		if not main.dialog_open:
			_set_stage("board")
			main.rocket_door.visible = true
			Sfx.play("door")
			main.hud.set_caption("The President boards his rocket.")
	elif stage == "board":
		# the pilot goes first, the President follows
		var door: Vector2 = PAD_POS + Vector2(0, 14)
		var pilot_in: bool = _walk(pilot, door, 150.0, delta)
		if pilot_in:
			pilot.modulate.a = maxf(0.0, pilot.modulate.a - delta * 3.0)
		var president_in := false
		if stage_t > 0.8:
			president_in = _walk(president, door, 120.0, delta)
			if president_in:
				president.modulate.a = maxf(0.0, president.modulate.a - delta * 3.0)
		p.face(president.position - p.position)
		p.show_frame(0)
		if pilot_in and president_in and president.modulate.a <= 0.0 and pilot.modulate.a <= 0.0:
			_set_stage("count")
			count_shown = -1
			main.rocket_door.visible = false
			Sfx.play("door", 0.9)
			p.face(Vector2(0, -1))
			p.show_frame(0)
	elif stage == "count":
		var left: int = 3 - int(stage_t)
		if left != count_shown and left > 0:
			count_shown = left
			main.hud.set_caption("%d..." % left)
			Sfx.play("ui_move", 0.8)
		if stage_t >= 3.0:
			_set_stage("liftoff")
			main.rocket_flame.visible = true
			Sfx.play("rocket")
			main._make_dust()
			main.hud.set_caption("Lift-off! The President is on his way to Earth.")
	elif stage == "liftoff":
		var f: float = clampf(stage_t / 5.5, 0.0, 1.0)
		main.rocket.position = PAD_POS + Vector2(0, -1500.0 * pow(f, 2.3))
		main.rocket_flame.scale = Vector2(1.0, 0.9 + 0.5 * absf(sin(t * 30.0)))
		# the ground shakes at first, then the camera follows the rocket a little way up
		var shake: float = 4.0 * clampf(1.0 - stage_t / 2.0, 0.0, 1.0)
		main.cam.position = INTRO_VIEW + Vector2(randf_range(-shake, shake), randf_range(-shake, shake) - 260.0 * smoothstep(0.0, 1.0, f))
		if f >= 1.0:
			_set_stage("wave")
			main.hud.set_caption("Now New Hope is in your hands. Good luck, Operator!")
	elif stage == "wave":
		main.cam.position = INTRO_VIEW + Vector2(0, -260.0 * (1.0 - smoothstep(0.0, 1.6, stage_t)))
		if stage_t >= 2.6:
			_end_intro()


func _end_intro() -> void:
	# tidy up and hand the colony over to the player
	main.dialog_queue.clear()
	main.dialog_open = false
	main.hud.hide_dialog()
	Game.paused = false
	for a in [president, pilot]:
		if a != null and is_instance_valid(a):
			a.queue_free()
	president = null
	pilot = null
	if main.rocket != null and is_instance_valid(main.rocket):
		main.rocket.queue_free()
	main.rocket = null
	for d in main.dust_puffs:
		d["node"].queue_free()
	main.dust_puffs.clear()
	var p = main.player
	p.in_vehicle = false
	p.position = WorldData.PLAYER_START
	p.face(Vector2(0, 1))
	p.show_frame(0)
	Game.player_pos = p.position
	main.cam.position = p.position + Vector2(0, -40)
	main.cam.position_smoothing_enabled = true
	main.cam.reset_smoothing()
	main.hud.end_cinematic()
	main.hud.fade_in()
	main.learn.layer.visible = true
	active = false
	mode = ""
	main._after_intro()


# =====================================================================
#  THE HAPPY ENDING: a welcome party on the rocket pad
#  (main.gd lands the rocket first, then calls start_party and update_party)
# =====================================================================

func start_party() -> void:
	party_t = 0.0
	party_stage = "dance"
	party_stage_t = 0.0
	burst_timer = 0.3
	main.hud.fade_in()
	main.hud.set_caption("Welcome party! All of New Hope celebrates its new neighbours.")
	Sfx.play("success")

	# the colonists you know come over to the pad, in two rows behind you
	var guests := []
	for n in main.npcs:
		if n.role == "vendor":
			continue
		guests.append(n)
	for i in guests.size():
		var n = guests[i]
		var row: int = i % 2
		var place: float = float(i / 2) - float((guests.size() + 1) / 2 - 1) / 2.0
		n.position = Vector2(760.0 + place * 76.0 + float(row) * 38.0, 1076.0 + float(row) * 34.0)
		n.position.x = clampf(n.position.x, 520.0, 1010.0)
		n.visible = true
		n.set_process(false)           # they stop their normal walking and looking
		n.set_alert(false)
		n.set_bubble("")
		n.name_tag.visible = false     # no name signs at the party: the picture stays tidy
		n.face(Vector2(0, -1))
		n.show_frame(0)
		dancers.append({"actor": n, "phase": randf() * TAU, "spin": randf_range(0.5, 1.4)})
	for a in main.arrivals:
		a["actor"].visible = true
		a["actor"].modulate.a = 1.0
		dancers.append({"actor": a["actor"], "phase": randf() * TAU, "spin": randf_range(0.5, 1.4)})
	dancers.append({"actor": main.player, "phase": 0.0, "spin": 0.9})

	# two food stalls beside the pad and a string of flags across it
	_prop("stall_a", Vector2(1150, 850))
	_prop("stall_c", Vector2(1130, 1040))
	_flags(Vector2(452, 842), Vector2(1068, 842))


func _prop(asset: String, at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/world/%s.png" % asset)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(2, 2)
	s.offset = Vector2(0, -float(s.texture.get_height()) / 2.0)
	s.position = at
	main.world.add_child(s)


func _flags(from: Vector2, to: Vector2) -> void:
	# two poles with a sagging string of little coloured flags between them
	var holder := Node2D.new()
	holder.z_index = 4
	main.world.add_child(holder)
	for pole_at in [from, to]:
		var pole := ColorRect.new()
		pole.color = Color(0.3, 0.26, 0.3)
		pole.position = pole_at + Vector2(-3, 0)
		pole.size = Vector2(6, 150)
		pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pole)
	var rope := Line2D.new()
	rope.width = 3.0
	rope.default_color = Color(0.95, 0.95, 0.9)
	holder.add_child(rope)
	var count := 22
	for i in count + 1:
		var k: float = float(i) / float(count)
		var at: Vector2 = from.lerp(to, k) + Vector2(0, sin(k * PI) * 46.0)
		rope.add_point(at)
		if i == 0 or i == count:
			continue
		var flag := Polygon2D.new()
		flag.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(0, 20)])
		flag.color = PARTY_COLORS[i % PARTY_COLORS.size()]
		flag.position = at
		holder.add_child(flag)


func update_party(delta: float) -> bool:
	# returns true when the party film is over
	party_t += delta
	party_stage_t += delta
	# the camera moves down a little, so the whole crowd is in the picture
	main.cam.position = PARTY_VIEW.lerp(PARTY_VIEW + Vector2(0, 110), smoothstep(0.0, 1.5, party_t))

	# everyone hops, and now and then turns around on the spot
	for d in dancers:
		var a = d["actor"]
		if not is_instance_valid(a):
			continue
		var beat: float = party_t * 7.0 + float(d["phase"])
		a.body.position.y = -absf(sin(beat)) * 11.0
		var turn: int = int(party_t * float(d["spin"]) + float(d["phase"])) % 4
		a.dir8 = [4, 2, 4, 6][turn]
		a.show_frame(0)

	# fireworks above the rocket and confetti everywhere
	burst_timer -= delta
	if burst_timer <= 0.0:
		burst_timer = 0.55
		if party_stage == "finale":
			burst_timer = 0.3
		_firework(Vector2(randf_range(330.0, 1190.0), randf_range(500.0, 780.0)))
	confetti_timer -= delta
	if confetti_timer <= 0.0 and bits.size() < 220:
		confetti_timer = 0.04
		_confetti()
	_update_bits(delta)

	if party_stage == "dance" and party_stage_t >= 4.5:
		party_stage = "talk"
		party_stage_t = 0.0
		main.hud.set_caption("")
		for line in PARTY_TALK:
			main._say(_fill(str(line[0])), _fill(str(line[1])))
	elif party_stage == "talk" and not main.dialog_open:
		party_stage = "finale"
		party_stage_t = 0.0
		main.hud.set_caption("New Hope has a bright future. Thank you, Operator!")
	elif party_stage == "finale" and party_stage_t >= 5.5:
		return true
	return false


func _bit(at: Vector2, size: float, color: Color) -> Polygon2D:
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(-size, -size), Vector2(size, -size), Vector2(size, size), Vector2(-size, size)])
	b.color = color
	b.position = at
	b.z_index = 8
	main.world.add_child(b)
	return b


func _firework(at: Vector2) -> void:
	bursts += 1
	if bursts % 2 == 0:
		Sfx.play("coin", randf_range(0.8, 1.3), -6.0)
	var color: Color = PARTY_COLORS[randi() % PARTY_COLORS.size()]
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		var speed: float = randf_range(120.0, 230.0)
		var node: Polygon2D = _bit(at, 4.0, color)
		bits.append({"node": node, "vel": Vector2(cos(a), sin(a)) * speed, "life": 1.1, "full": 1.1, "gravity": 170.0, "sway": 0.0})


func _confetti() -> void:
	var view: Vector2 = main.cam.position
	var at := Vector2(view.x + randf_range(-760.0, 760.0), view.y - 440.0)
	var node: Polygon2D = _bit(at, 3.5, PARTY_COLORS[randi() % PARTY_COLORS.size()])
	bits.append({"node": node, "vel": Vector2(0.0, randf_range(110.0, 190.0)), "life": 5.0, "full": 5.0, "gravity": 0.0, "sway": randf_range(2.0, 5.0)})


func _update_bits(delta: float) -> void:
	var keep := []
	for b in bits:
		var node: Polygon2D = b["node"]
		var vel: Vector2 = b["vel"]
		vel.y += float(b["gravity"]) * delta
		b["vel"] = vel
		b["life"] = float(b["life"]) - delta
		node.position += vel * delta
		if float(b["sway"]) > 0.0:
			node.position.x += sin(party_t * float(b["sway"]) + node.position.y * 0.02) * 40.0 * delta
			node.rotation += delta * 4.0
		node.color.a = clampf(float(b["life"]) / float(b["full"]) * 2.0, 0.0, 1.0)
		if float(b["life"]) <= 0.0:
			node.queue_free()
		else:
			keep.append(b)
	bits = keep


# =====================================================================
#  THE SAD ENDING: the camera glides from right to left over the colony
#  while the machines and buildings stop working one after another
# =====================================================================

func start_collapse(reason: String, done: Callable) -> void:
	active = true
	mode = "collapse"
	t = 0.0
	_set_stage("pan")
	collapse_done = done
	Sfx.stop_loops()
	Sfx.play("power_down")
	main.details.lights_out = true

	# everyone is safe in the shelter, so nobody is outside
	var p = main.player
	p.in_vehicle = true
	p.visible = false
	for n in main.npcs:
		n.visible = false
		n.set_process(false)
	for n in main.towns:
		n.visible = false
		n.set_process(false)
	for v in main.trucks:
		v.mode = "parked"

	falling.clear()
	for m in main.things:
		if str(m.tid).begins_with("rock_") or not m.built:
			continue
		var lean: float = randf_range(0.07, 0.2)
		if randf() < 0.5:
			lean = -lean
		falling.append({"m": m, "delay": randf_range(0.0, 0.6), "tilt": lean, "at": -1.0, "hit": false})

	sky_from = main.sky.color
	main.cam.position_smoothing_enabled = false
	main.cam.zoom = Vector2.ONE * COLLAPSE_ZOOM
	main.hud.start_cinematic()
	main.hud.set_hint("ESC: skip the film")
	main.hud.set_caption(str(COLLAPSE_LINES.get(reason, "The colony could not keep going, so everyone moved into the emergency shelter.")))
	main.hud.fade_in()
	_place_collapse_camera(0.0)


func _place_collapse_camera(f: float) -> void:
	# from the right side of the map to the left, drifting gently up and down to show more
	var size: Vector2 = WorldData.WORLD_SIZE
	var half: float = 640.0 / COLLAPSE_ZOOM
	var x: float = lerpf(size.x - half, half, f)
	var y: float = size.y / 2.0 + sin(f * TAU) * 420.0
	main.cam.position = Vector2(x, y)


func _update_collapse(delta: float) -> void:
	var f: float = clampf(t / COLLAPSE_SECONDS, 0.0, 1.0)
	_place_collapse_camera(f)
	main.sky.color = sky_from.lerp(Color(0.62, 0.5, 0.52), clampf(t / 3.0, 0.0, 1.0))

	# a line sweeps over the map from right to left, a little ahead of the middle of the
	# picture: whatever it passes stops working
	var half: float = 640.0 / COLLAPSE_ZOOM
	var sweep: float = main.cam.position.x + lerpf(half, -half, clampf(f * 1.18, 0.0, 1.0))
	for c in falling:
		var m = c["m"]
		if float(c["at"]) < 0.0:
			if m.position.x >= sweep:
				c["at"] = t + float(c["delay"])
			continue
		var k: float = t - float(c["at"])
		if k < 0.0:
			continue
		if not c["hit"]:
			c["hit"] = true
			_knock_out(m)
		if k < 0.45:
			# it shakes first...
			m.sprite.position = Vector2(randf_range(-3.0, 3.0), 0.0)
		else:
			# ...then it leans over, sinks a little and goes dark
			var g: float = clampf((k - 0.45) / 0.7, 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - g, 2.0)
			m.sprite.position = Vector2(0.0, 10.0 * e)
			m.sprite.rotation = float(c["tilt"]) * e
			m.sprite.modulate = Color(1, 1, 1).lerp(Color(0.5, 0.44, 0.46), e)
	_update_smoke(delta)

	if f > 0.9:
		main.hud.set_caption("New Hope can be rebuilt. Try again, Operator!")
	elif f > 0.62:
		main.hud.set_caption("Everyone is safe in the emergency shelter. Help is on the way.")
	elif f > 0.3:
		main.hud.set_caption("Without power and care, the machines stop one by one.")
	if t >= COLLAPSE_SECONDS + 1.6:
		_end_collapse()


func _knock_out(m) -> void:
	m.broken = true
	m.is_on = false
	m.refresh()
	m.sprite.modulate = Color(1, 1, 1)
	m.badge.visible = false
	m.name_label.visible = false
	if t - last_crash > 0.4:
		last_crash = t
		Sfx.play("breakdown", randf_range(0.8, 1.2), -4.0)
	# dust and smoke rise from it
	var high: float = float(m.art_h)
	for i in 4:
		var puff := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in 10:
			var a: float = TAU * float(j) / 10.0
			pts.append(Vector2(cos(a) * 16.0, sin(a) * 11.0))
		puff.polygon = pts
		var grey: float = randf_range(0.3, 0.5)
		puff.color = Color(grey + 0.1, grey, grey, 0.75)
		puff.position = m.position + Vector2(randf_range(-0.3, 0.3) * high, -randf_range(0.2, 0.7) * high)
		puff.z_index = 5
		main.world.add_child(puff)
		smoke.append({"node": puff, "vel": Vector2(randf_range(-22.0, 22.0), randf_range(-70.0, -35.0)), "life": randf_range(1.6, 2.6), "full": 2.6})


func _update_smoke(delta: float) -> void:
	var keep := []
	for s in smoke:
		var node: Polygon2D = s["node"]
		var vel: Vector2 = s["vel"]
		s["life"] = float(s["life"]) - delta
		node.position += vel * delta
		node.scale += Vector2(0.9, 0.9) * delta
		node.color.a = clampf(float(s["life"]) / float(s["full"]), 0.0, 1.0) * 0.75
		if float(s["life"]) <= 0.0:
			node.queue_free()
		else:
			keep.append(s)
	smoke = keep


func _end_collapse() -> void:
	if not active:
		return
	active = false
	mode = ""
	if collapse_done.is_valid():
		collapse_done.call()
