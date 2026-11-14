extends Node2D
# The colony game. Builds the world in code and runs all the rules.

const MachineScript = preload("res://scripts/machine.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")

const WORLD_SIZE := Vector2(2240, 1472)
const DAY_END := 110.0            # seconds of daylight in each sol; the rest is night

# ---------------- balance numbers (all "per second"). Change these to tune the game.
const START_ENERGY := 70.0
const START_OXYGEN := 80.0
const START_PARTS := 3
const PANEL_POWER := 0.26         # energy one working solar panel makes in full sun
const BASE_USE := 0.08            # energy the colony always uses
const OXY_USE := 0.55             # energy used by the oxygen machine
const OXY_MAKE := 0.50            # oxygen made by the oxygen machine
const BREATHING := 0.20           # oxygen the colonists breathe
const HEAT_USE := 0.60            # energy used by the heater
const SHIELD_USE := 0.90          # energy used by the radiation shield
const COLD_DAMAGE := 0.35         # health lost at night with the heater off
const RAD_DAMAGE := 1.0           # health lost in a radiation storm with the shield off
const HEALTH_REGEN := 0.12        # health that comes back when you are safe
const BATTERY_LEAK := 0.40        # energy lost while the battery is broken
const AIR_LEAK := 0.45            # oxygen lost while the dome is leaking
const STORM_SUN := 0.3            # how much sunlight gets through a dust storm
const STORM_SECONDS := 35.0
const SCRAP_HIT := 8.0            # health lost when flying scrap hits you
const WORKSHOP_COST := 25.0       # energy needed to build one spare part

# where each picture's feet are, and how tall it really is (fractions of the image)
const SPRITE_INFO := {
	"solar_panel": [0.34, 0.69], "dome": [0.5, 1.0], "workshop": [0.5, 1.0],
	"shield_off": [0.41, 0.84], "oxygen_machine": [0.34, 0.69], "heater": [0.34, 0.69],
	"battery": [0.44, 0.88], "command_center": [0.5, 1.0], "antenna": [0.38, 0.75],
	"lamp": [0.28, 0.56], "npc": [0.19, 0.38], "rock": [0.26, 0.5],
	"scrap_pile": [0.28, 0.55], "truck": [0.25, 0.5], "rover": [0.28, 0.56],
}

var energy := START_ENERGY
var oxygen := START_OXYGEN
var health := 100.0
var parts := START_PARTS
var net_power := 0.0

var sol := 0                      # 0 means the first sol
var sol_time := 0.0
var elapsed := 0.0
var paused := true
var game_over := false
var night_announced := false
var low_oxygen_warned := false
var low_energy_warned := false

var world: Node2D
var player
var hud
var sky: CanvasModulate
var machines: Array = []          # everything solid; shared with the player
var panels: Array = []
var oxy_machine
var heater
var shield
var battery
var dome
var workshop

var events: Array = []
var today := {}
var weather_start := 0
var storm_left := 0.0
var storm_dir := 1.0
var storm_alpha := 0.0
var scrap_timer := 0.0
var flying: Array = []
var flare_left := 0.0
var flare_text := ""
var hit_cooldown := 0.0

var dialog_queue: Array = []
var dialog_open := false
var hold_target = null
var hold_time := 0.0
var task_timer := 0.0

var stats := {
	"cold": 0.0, "radiation": 0.0, "scrap": 0.0, "blackout": 0.0,
	"repairs": 0, "parts_used": 0, "parts_built": 0, "scrap_collected": 0,
	"lowest_oxygen": 100.0,
}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_world()
	_schedule_events()
	weather_start = rng.randi() % Game.weather().size()
	_start_sol(0)
	_update_hud()


# =====================================================================
#  BUILDING THE WORLD
# =====================================================================

func _build_world() -> void:
	var dirt := ColorRect.new()
	dirt.color = Color(0.72, 0.38, 0.26)
	dirt.size = WORLD_SIZE
	dirt.z_index = -11
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dirt)

	var ground := Sprite2D.new()
	ground.texture = load("res://assets/world/ground.png")
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(Vector2.ZERO, WORLD_SIZE)
	ground.z_index = -10
	add_child(ground)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	sky = CanvasModulate.new()
	add_child(sky)

	# --- solar field (left side)
	for p in [Vector2(380, 520), Vector2(560, 520), Vector2(740, 520), Vector2(380, 720), Vector2(560, 720), Vector2(740, 720)]:
		var panel = _spawn("panel", "Solar panel", "solar_panel", p, 1.2, 44.0)
		panel.name_label.visible = false
		panels.append(panel)
	battery = _spawn("battery", "Battery", "battery", Vector2(560, 960), 1.1, 54.0)

	# --- centre
	_spawn("decor", "", "command_center", Vector2(1120, 470), 1.7, 92.0)
	_spawn("decor", "", "antenna", Vector2(1290, 400), 1.3, 22.0)
	dome = _spawn("dome", "Habitat dome", "dome", Vector2(1160, 1010), 1.6, 84.0)
	heater = _spawn("heater", "Heater", "heater", Vector2(900, 1080), 1.6, 44.0)
	heater.switchable = true

	# --- right side
	oxy_machine = _spawn("oxygen", "Oxygen machine", "oxygen_machine", Vector2(1580, 560), 1.6, 44.0)
	oxy_machine.switchable = true
	oxy_machine.is_on = true
	shield = _spawn("shield", "Radiation shield", "shield_off", Vector2(1760, 900), 1.7, 42.0, "shield_on")
	shield.switchable = true
	workshop = _spawn("workshop", "Workshop", "workshop", Vector2(1500, 1220), 1.5, 62.0)
	_spawn("decor", "", "truck", Vector2(1330, 1290), 1.3, 34.0)
	_spawn("decor", "", "rover", Vector2(930, 380), 1.3, 36.0)
	for p in [Vector2(960, 620), Vector2(1280, 620), Vector2(700, 900), Vector2(1420, 940)]:
		_spawn("decor", "", "lamp", p, 1.2, 12.0)

	for m in [heater, oxy_machine, shield]:
		m.refresh()

	# --- colonists
	_spawn_npc("Ada (Mars News)", "journalist", "npc_journalist", Vector2(1270, 560))
	_spawn_npc("Engineer Mira", "engineer", "npc_engineer", Vector2(640, 850))
	_spawn_npc("Dr. Sam", "doctor", "npc_doctor", Vector2(1330, 1060))
	_spawn_npc("Scientist Leo", "scientist", "npc_scientist", Vector2(1700, 650))

	# --- scrap you can collect, and rocks
	_spawn_scrap(Vector2(900, 250))
	_spawn_scrap(Vector2(1900, 1250))
	var rocks := ["rock_a", "rock_b", "rock_c", "rock_d"]
	for i in 26:
		var spot := _free_spot(Rect2(80, 150, WORLD_SIZE.x - 160, WORLD_SIZE.y - 220))
		if spot == Vector2.ZERO:
			continue
		_spawn("decor", "", rocks[i % rocks.size()], spot, rng.randf_range(0.8, 1.2), 24.0)

	# --- the player
	player = PlayerScript.new()
	player.position = Vector2(1120, 700)
	player.world_size = WORLD_SIZE
	player.obstacles = machines
	world.add_child(player)
	player.setup(Game.character)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x)
	cam.limit_bottom = int(WORLD_SIZE.y)
	cam.position = Vector2(0, -40)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()

	hud = HudScript.new()
	add_child(hud)


func _spawn(kind: String, title: String, asset: String, pos: Vector2, size_scale: float, radius: float, on_asset: String = ""):
	var key := asset
	if asset.begins_with("npc"):
		key = "npc"
	elif asset.begins_with("rock"):
		key = "rock"
	var info: Array = SPRITE_INFO.get(key, [0.42, 0.84])
	var on_path := ""
	if on_asset != "":
		on_path = "res://assets/world/%s.png" % on_asset
	var m = MachineScript.new()
	m.position = pos
	world.add_child(m)
	m.setup(kind, title, "res://assets/world/%s.png" % asset, size_scale, radius, on_path, float(info[0]), float(info[1]))
	machines.append(m)
	return m


func _spawn_npc(title: String, role: String, asset: String, pos: Vector2) -> void:
	var m = _spawn("npc", title, asset, pos, 1.7, 16.0)
	m.role = role


func _spawn_scrap(pos: Vector2) -> void:
	_spawn("scrap", "Scrap pile", "scrap_pile", pos, 0.9, 26.0)


func _free_spot(area: Rect2) -> Vector2:
	# a random place that is not on top of anything; Vector2.ZERO if none found
	for attempt in 40:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var ok := true
		for m in machines:
			if p.distance_to(m.position) < m.radius + 120.0:
				ok = false
				break
		if ok and p.distance_to(Vector2(1120, 700)) < 170.0:
			ok = false
		if ok and player != null and p.distance_to(player.position) < 170.0:
			ok = false
		if ok:
			return p
	return Vector2.ZERO


# =====================================================================
#  THE PLAN FOR THIS GAME (different every time you play)
# =====================================================================

func _schedule_events() -> void:
	events.clear()
	var flare_list: Array = Game.flares().duplicate()
	flare_list.shuffle()
	var flare_i := 0

	# Sol 1 always has the big dust storm from the story.
	events.append(_event(0, 50.0, "dust", 3))

	var pool := ["dust", "oxy_fault", "battery_fault", "air_leak", "flare", "dust", "air_leak", "oxy_fault"]
	pool.shuffle()
	for s in range(1, Game.TOTAL_SOLS):
		var first: String = pool[(s - 1) % pool.size()]
		if s == 1:
			first = "flare"     # teach the shield early, in daylight
		var ev := _event(s, rng.randf_range(25.0, 80.0), first, rng.randi_range(1, 2))
		if first == "flare":
			ev["flare"] = flare_list[flare_i % flare_list.size()]
			flare_i += 1
		events.append(ev)

		# some sols also get a night problem; sol 3 always gets a night flare
		if s == 2 or (s >= 3 and rng.randf() < 0.6):
			var options := ["flare", "oxy_fault", "air_leak", "battery_fault"]
			var second: String = options[rng.randi() % options.size()]
			if s == 2:
				second = "flare"
			if second != first:
				var ev2 := _event(s, rng.randf_range(DAY_END + 8.0, Game.SOL_SECONDS - 48.0), second, 1)
				if second == "flare":
					ev2["flare"] = flare_list[flare_i % flare_list.size()]
					flare_i += 1
				events.append(ev2)


func _event(on_sol: int, at: float, type: String, breaks: int) -> Dictionary:
	return {"sol": on_sol, "t": at, "type": type, "breaks": breaks, "warned": false, "done": false, "flare": {}}


func _start_sol(i: int) -> void:
	sol = i
	sol_time = 0.0
	night_announced = false
	var w: Array = Game.weather()
	today = w[(weather_start + i) % w.size()]

	var dust := false
	var flare_day := false
	var flare_night := false
	for ev in events:
		if ev["sol"] != i:
			continue
		if ev["type"] == "dust":
			dust = true
		elif ev["type"] == "flare":
			if ev["t"] >= DAY_END:
				flare_night = true
			else:
				flare_day = true

	if i == 0:
		_say("Mission Control", "Welcome, Operator! You run the Mars colony New Hope. A day on Mars is called a 'sol'. Keep everyone alive for %d sols." % Game.TOTAL_SOLS)
		_say("Mission Control", "Watch your three bars. ENERGY comes from the solar panels. OXYGEN is the air everyone breathes. HEALTH is how you feel. If oxygen or health runs out, the mission ends.")
		_say("Mission Control", "Machines use energy, and there is never enough for everything. Walk to a machine and press E to switch it on or off. Every choice has a cost!")

	var report := "Good morning, New Hope! Sol %d of %d. Today's high is %d C. Tonight's low is %d C, so you will need the heater." % [i + 1, Game.TOTAL_SOLS, int(today["max"]), int(today["min"])]
	_say("Ada, Mars News", report)
	if dust:
		_say("Ada, Mars News", "Warning: a DUST STORM is coming today. Dust blocks the sunlight, so the solar panels make less energy. The wind can break panels and throw scrap metal around. Stay out of its way!")
	if flare_day:
		_say("Ada, Mars News", "Warning: the Sun is stormy. A SOLAR FLARE could hit today. Radiation is invisible energy that can make people sick. The radiation shield protects us, but it uses a lot of energy.")
	if flare_night:
		_say("Ada, Mars News", "Warning: a SOLAR FLARE is expected TONIGHT. Dr. Sam says: turn the shield on! Engineer Mira says: the battery cannot run the shield, the heater and the oxygen machine all night. You must choose.")


# =====================================================================
#  EVERY FRAME
# =====================================================================

func _process(delta: float) -> void:
	if game_over:
		return
	player.frozen = paused
	if not paused:
		_simulate(delta)
		if game_over:
			return
		_update_flying(delta)
		_update_hold(delta)
	_update_look(delta)
	_update_hud()


func _sun() -> float:
	if sol_time < 10.0:
		return sol_time / 10.0
	if sol_time < DAY_END - 15.0:
		return 1.0
	if sol_time < DAY_END:
		return (DAY_END - sol_time) / 15.0
	return 0.0


func _is_night() -> bool:
	return sol_time >= DAY_END


func _broken_panels() -> int:
	var n := 0
	for p in panels:
		if p.broken:
			n += 1
	return n


func _simulate(delta: float) -> void:
	elapsed += delta
	sol_time += delta
	if sol_time >= Game.SOL_SECONDS:
		if sol + 1 >= Game.TOTAL_SOLS:
			_finish(true, "")
			return
		_start_sol(sol + 1)
		return

	_run_events()

	if _is_night() and not night_announced:
		night_announced = true
		hud.show_banner("NIGHT FALLS", "No sunlight means no solar energy. It will drop to %d C. Turn the heater ON to stay warm." % int(today["min"]), 10.0)

	# ---- energy
	var dust := 1.0
	if storm_left > 0.0:
		dust = STORM_SUN
	var gain := float(panels.size() - _broken_panels()) * PANEL_POWER * _sun() * dust
	var use := BASE_USE
	if oxy_machine.works():
		use += OXY_USE
	if heater.works():
		use += HEAT_USE
	if shield.works():
		use += SHIELD_USE
	if battery.broken:
		use += BATTERY_LEAK
	net_power = gain - use
	energy = clampf(energy + net_power * delta, 0.0, 100.0)

	if energy <= 0.0:
		stats["blackout"] += delta
		var any_on := false
		for m in [oxy_machine, heater, shield]:
			if m.is_on:
				m.is_on = false
				m.refresh()
				any_on = true
		if any_on:
			hud.show_banner("POWER OUT!", "The battery is empty, so every machine switched off. Fix the solar panels or wait for sunlight, then switch the machines back on.", 11.0)

	# ---- oxygen
	var air := -BREATHING
	if oxy_machine.works():
		air += OXY_MAKE
	if dome.broken:
		air -= AIR_LEAK
	oxygen = clampf(oxygen + air * delta, 0.0, 100.0)
	if oxygen < float(stats["lowest_oxygen"]):
		stats["lowest_oxygen"] = oxygen

	# ---- health
	var in_danger := false
	if flare_left > 0.0 and not shield.works():
		health -= RAD_DAMAGE * delta
		stats["radiation"] += RAD_DAMAGE * delta
		in_danger = true
	if _is_night() and not heater.works():
		var cold := COLD_DAMAGE * clampf(-float(today["min"]) / 75.0, 0.6, 1.4)
		health -= cold * delta
		stats["cold"] += cold * delta
		in_danger = true
	if not in_danger:
		health = minf(100.0, health + HEALTH_REGEN * delta)

	# ---- storms running out
	if storm_left > 0.0:
		storm_left -= delta
		if storm_left <= 0.0:
			_end_storm()
	if flare_left > 0.0:
		flare_left -= delta
		if flare_left <= 0.0:
			hud.show_banner("ALL CLEAR", "The radiation storm is over. You can switch the shield OFF to save energy.", 8.0)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)

	# ---- warnings
	if oxygen < 25.0 and not low_oxygen_warned:
		low_oxygen_warned = true
		hud.show_banner("OXYGEN IS LOW", "Make sure the oxygen machine is ON and working, and check the dome for leaks.", 9.0)
	elif oxygen > 40.0:
		low_oxygen_warned = false
	if energy < 15.0 and energy > 0.0 and not low_energy_warned:
		low_energy_warned = true
		hud.show_banner("BATTERY IS LOW", "Switch off something you do not need right now, or everything will shut down.", 9.0)
	elif energy > 30.0:
		low_energy_warned = false

	if oxygen <= 0.0:
		_finish(false, "oxygen")
	elif health <= 0.0:
		_finish(false, "health")


# =====================================================================
#  EVENTS
# =====================================================================

func _run_events() -> void:
	for ev in events:
		if ev["sol"] != sol or ev["done"]:
			continue
		var at: float = ev["t"]
		if not ev["warned"] and sol_time >= at - 15.0:
			ev["warned"] = true
			if ev["type"] == "dust":
				hud.show_banner("MARS NEWS: STORM WARNING", "The dust storm arrives in a few seconds. Finish what you are doing and get ready to dodge!", 9.0)
			elif ev["type"] == "flare":
				hud.show_banner("MARS NEWS: RADIATION WARNING", "A solar flare is about to hit. Get to the radiation shield and decide: is it worth the energy?", 9.0)
		if sol_time >= at:
			ev["done"] = true
			_start_event(ev)


func _start_event(ev: Dictionary) -> void:
	var type: String = ev["type"]
	if type == "dust":
		storm_left = STORM_SECONDS
		storm_dir = 1.0 if rng.randf() < 0.5 else -1.0
		scrap_timer = 1.5
		var working := []
		for p in panels:
			if not p.broken:
				working.append(p)
		working.shuffle()
		var count := mini(int(ev["breaks"]), working.size())
		for i in count:
			working[i].broken = true
			working[i].refresh()
		hud.show_banner("DUST STORM!", "%d solar panels are broken! Dodge the flying scrap. Repair a panel by holding E next to it (uses 1 spare part)." % count, 11.0)
	elif type == "flare":
		var rec: Dictionary = ev["flare"]
		var cls := str(rec.get("cls", "X1.0"))
		flare_left = _flare_seconds(cls)
		flare_text = "Class %s flare. NASA recorded a real flare like this on %s." % [cls, str(rec.get("date", ""))]
		hud.show_banner("RADIATION STORM!", "Turn the shield ON or you will lose health. " + flare_text, 12.0)
	elif type == "oxy_fault":
		if not oxy_machine.broken:
			oxy_machine.broken = true
			oxy_machine.refresh()
			hud.show_banner("MACHINE FAILURE", "The oxygen machine has stopped working! Repair it with 1 spare part before the air runs low.", 10.0)
	elif type == "battery_fault":
		if not battery.broken:
			battery.broken = true
			battery.refresh()
			hud.show_banner("BATTERY FAULT", "The battery is leaking energy! Repair it with 1 spare part.", 10.0)
	elif type == "air_leak":
		if not dome.broken:
			dome.broken = true
			dome.refresh()
			hud.show_banner("AIR LEAK", "A crack in the habitat dome is letting oxygen escape! Seal it with 1 spare part.", 10.0)


func _flare_seconds(cls: String) -> float:
	# stronger real flares last longer in the game
	var strength := cls.substr(1).to_float()
	if cls.begins_with("X"):
		return clampf(24.0 + strength * 2.5, 24.0, 45.0)
	return 20.0


func _end_storm() -> void:
	storm_left = 0.0
	var made := 0
	for i in 2:
		var spot := _free_spot(Rect2(300, 300, WORLD_SIZE.x - 600, WORLD_SIZE.y - 500))
		if spot != Vector2.ZERO:
			_spawn_scrap(spot)
			made += 1
	hud.show_banner("THE STORM HAS PASSED", "The wind left %d new scrap piles around the base. Collect them to get spare parts." % made, 9.0)


func _update_flying(delta: float) -> void:
	if storm_left > 0.0:
		scrap_timer -= delta
		if scrap_timer <= 0.0:
			scrap_timer = rng.randf_range(0.5, 0.9)
			_throw_scrap()

	var keep := []
	for f in flying:
		var node: Node2D = f["node"]
		var vel: Vector2 = f["vel"]
		node.position += vel * delta
		var shard: Polygon2D = f["shard"]
		shard.rotation += float(f["spin"]) * delta
		var gone := absf(node.position.x - player.position.x) > 950.0
		if not gone and hit_cooldown <= 0.0 and node.position.distance_to(player.position) < 30.0:
			health -= SCRAP_HIT
			stats["scrap"] += SCRAP_HIT
			hit_cooldown = 1.0
			hold_target = null
			player.knock = Vector2(signf(vel.x) * 260.0, 0)
			hud.flash_hurt()
			gone = true
		if gone:
			node.queue_free()
		else:
			keep.append(f)
	flying = keep


func _throw_scrap() -> void:
	var node := Node2D.new()
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([Vector2(-14, -6), Vector2(4, -12), Vector2(15, -2), Vector2(8, 10), Vector2(-10, 9)])
	shard.color = Color(0.62, 0.64, 0.68)
	shard.position = Vector2(0, -28)
	node.add_child(shard)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(-14, -6), Vector2(4, -12), Vector2(0, -3)])
	edge.color = Color(0.85, 0.87, 0.9)
	shard.add_child(edge)
	node.position = Vector2(player.position.x - storm_dir * 740.0, player.position.y + rng.randf_range(-320.0, 320.0))
	world.add_child(node)
	flying.append({
		"node": node,
		"shard": shard,
		"vel": Vector2(storm_dir * rng.randf_range(300.0, 420.0), rng.randf_range(-40.0, 40.0)),
		"spin": rng.randf_range(-8.0, 8.0),
	})


# =====================================================================
#  USING THINGS (the E key)
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_over or not event.is_action_pressed("interact"):
		return
	if dialog_open:
		_next_dialog()
		return
	var m = _find_target()
	if m == null:
		return
	var act := _action_for(m)
	if act["mode"] == "press":
		_do_press(m)
	elif act["mode"] == "hold":
		hold_target = m
		hold_time = 0.0


func _find_target():
	var best = null
	var best_d := 99999.0
	for m in machines:
		if m.kind == "decor":
			continue
		var d: float = player.position.distance_to(m.collider_center()) - m.radius
		if d < 60.0 and d < best_d:
			best = m
			best_d = d
	return best


func _action_for(m) -> Dictionary:
	# what pressing E would do to this thing right now
	var kind: String = m.kind
	if kind == "npc":
		return {"text": "Press E: talk to %s" % m.title, "mode": "press", "secs": 0.0}
	if kind == "scrap":
		return {"text": "Hold E: collect scrap (+1 spare part)", "mode": "hold", "secs": 1.5}
	if kind == "workshop":
		if energy >= WORKSHOP_COST + 5.0:
			return {"text": "Press E: build 1 spare part (costs %d energy)" % int(WORKSHOP_COST), "mode": "press", "secs": 0.0}
		return {"text": "Workshop: not enough energy to build a spare part", "mode": "none", "secs": 0.0}
	if m.broken:
		if parts <= 0:
			return {"text": "%s is broken, but you have no spare parts! Find scrap or use the workshop." % m.title, "mode": "none", "secs": 0.0}
		return {"text": "Hold E: repair %s (uses 1 spare part)" % m.title, "mode": "hold", "secs": 2.2}
	if m.switchable:
		if m.is_on:
			return {"text": "Press E: switch %s OFF (saves energy)" % m.title, "mode": "press", "secs": 0.0}
		if energy < 3.0:
			return {"text": "%s: no power! The battery is empty." % m.title, "mode": "none", "secs": 0.0}
		return {"text": "Press E: switch %s ON (uses energy)" % m.title, "mode": "press", "secs": 0.0}
	if kind == "panel":
		return {"text": "Solar panel: turns sunlight into energy", "mode": "none", "secs": 0.0}
	if kind == "battery":
		return {"text": "Battery: stores energy for the night", "mode": "none", "secs": 0.0}
	if kind == "dome":
		return {"text": "Habitat dome: everyone lives and breathes in here", "mode": "none", "secs": 0.0}
	return {"text": "", "mode": "none", "secs": 0.0}


func _do_press(m) -> void:
	if m.kind == "npc":
		for line in _npc_lines(m.role):
			_say(m.title, line)
	elif m.kind == "workshop":
		energy -= WORKSHOP_COST
		parts += 1
		stats["parts_built"] += 1
		hud.show_banner("WORKSHOP", "You built 1 spare part. It cost %d energy. Was it worth it?" % int(WORKSHOP_COST), 6.0)
	elif m.switchable:
		m.is_on = not m.is_on
		m.refresh()


func _update_hold(delta: float) -> void:
	if hold_target == null:
		return
	if not is_instance_valid(hold_target) or not Input.is_action_pressed("interact") or _find_target() != hold_target:
		hold_target = null
		return
	var act := _action_for(hold_target)
	if act["mode"] != "hold":
		hold_target = null
		return
	hold_time += delta
	if hold_time >= float(act["secs"]):
		var m = hold_target
		hold_target = null
		_finish_hold(m)


func _finish_hold(m) -> void:
	if m.kind == "scrap":
		parts += 1
		stats["scrap_collected"] += 1
		machines.erase(m)
		m.queue_free()
	elif m.broken and parts > 0:
		parts -= 1
		stats["parts_used"] += 1
		stats["repairs"] += 1
		m.broken = false
		m.refresh()


# =====================================================================
#  TALKING
# =====================================================================

func _say(speaker: String, text: String) -> void:
	dialog_queue.append([speaker, text])
	if not dialog_open:
		_next_dialog()


func _next_dialog() -> void:
	if dialog_queue.is_empty():
		dialog_open = false
		paused = false
		hud.hide_dialog()
		return
	var d: Array = dialog_queue.pop_front()
	dialog_open = true
	paused = true
	hold_target = null
	hud.show_dialog(str(d[0]), str(d[1]))


func _npc_lines(role: String) -> Array:
	var lines := []
	var broken := _broken_panels()
	if role == "engineer":
		if broken > 0:
			lines.append("%d solar panels are broken. Each repair uses 1 spare part, and we have %d. Fewer panels means less energy, so I would fix them first." % [broken, parts])
		if battery.broken:
			lines.append("The battery is leaking energy. Please repair it, or we will run out of power tonight.")
		if flare_left > 0.0 or _is_night():
			lines.append("Careful with the battery! The shield, the heater and the oxygen machine cannot all run for long. Switch off what you need least.")
		if lines.is_empty():
			lines.append("Solar panels turn sunlight into electricity. At night they make nothing, so try to fill the battery before sunset.")
		lines.append("Out of spare parts? Collect scrap piles, or build a part in the workshop. But the workshop uses a lot of energy!")
	elif role == "doctor":
		if flare_left > 0.0 and not shield.works():
			lines.append("Radiation storm! Please turn the shield ON. Radiation can make everyone sick, even though we cannot see or feel it.")
		elif _is_night() and not heater.works():
			lines.append("It is %d C outside tonight! Without the heater we lose health. Please switch it on." % int(today["min"]))
		else:
			lines.append("Earth has thick air and a magnetic field that block most space radiation. Mars does not, so we need a shield when the Sun is stormy.")
		lines.append("If your health is low, stay safe for a while: keep warm and shielded, and it slowly comes back.")
	elif role == "scientist":
		if oxy_machine.broken:
			lines.append("The oxygen machine is broken! Repair it with a spare part, or the air will slowly run out.")
		elif dome.broken:
			lines.append("Air is leaking from the dome. Seal the crack with a spare part!")
		else:
			lines.append("The air on Mars is mostly carbon dioxide, which we cannot breathe. Our oxygen machine turns it into oxygen, like NASA's MOXIE experiment on the Perseverance rover.")
		lines.append("Making oxygen needs a lot of electricity. If the battery is low at night, you can switch the machine off for a while, but watch the oxygen bar!")
		lines.append("Did you know? A sol, a day on Mars, is about 40 minutes longer than a day on Earth.")
	elif role == "journalist":
		lines.append("This is Ada with Mars News. Sol %d of %d. Today's high is %d C and tonight's low is %d C." % [sol + 1, Game.TOTAL_SOLS, int(today["max"]), int(today["min"])])
		if storm_left > 0.0:
			lines.append("A dust storm is blowing right now. Watch out for flying scrap!")
		elif flare_left > 0.0:
			lines.append("A radiation storm is hitting us right now. " + flare_text)
		else:
			lines.append("I will warn everyone when a storm is on its way. Listen for my news flashes at the top of the screen.")
	return lines


# =====================================================================
#  SCREEN
# =====================================================================

func _update_look(delta: float) -> void:
	var night_color := Color(0.42, 0.46, 0.78)
	sky.color = night_color.lerp(Color(1, 1, 1), _sun())
	var target := 0.0
	if storm_left > 0.0:
		target = 0.3
	storm_alpha = move_toward(storm_alpha, target, delta * 0.4)
	var flare_alpha := 0.0
	if flare_left > 0.0:
		flare_alpha = 0.13 + 0.06 * sin(elapsed * 5.0)
	hud.set_weather(storm_alpha, flare_alpha)


func _tasks() -> Array:
	var t := []
	var broken := _broken_panels()
	if flare_left > 0.0 and not shield.works():
		t.append("RADIATION! Turn the shield ON")
	if storm_left > 0.0:
		t.append("Dust storm: dodge the flying scrap")
	if dome.broken:
		t.append("Seal the air leak in the dome")
	if oxy_machine.broken:
		t.append("Repair the oxygen machine")
	if battery.broken:
		t.append("Repair the leaking battery")
	if broken > 0:
		t.append("Repair solar panels (%d broken)" % broken)
	if _is_night() and not heater.works():
		t.append("It is night: turn the heater ON")
	if not oxy_machine.broken and not oxy_machine.is_on and oxygen < 40.0:
		t.append("Oxygen is low: turn the oxygen machine ON")
	if t.is_empty():
		if _is_night():
			t.append("All systems OK. Hold on until sunrise!")
		else:
			t.append("All systems OK. Fill the battery before night.")
	return t


func _update_hud() -> void:
	hud.set_bars(energy, oxygen, health)
	hud.set_parts(parts)
	hud.set_power(net_power)
	hud.set_switches("Oxygen: %s    Heater: %s    Shield: %s" % [_state(oxy_machine), _state(heater), _state(shield)])

	var left := maxf(0.0, Game.SOL_SECONDS * Game.TOTAL_SOLS - elapsed)
	var part_of_day := "Night" if _is_night() else "Day"
	hud.set_clock("Sol %d of %d  -  %s" % [sol + 1, Game.TOTAL_SOLS, part_of_day], "Time left  %02d:%02d" % [int(left) / 60, int(left) % 60])
	hud.set_tasks(_tasks())

	if dialog_open:
		hud.set_prompt("")
		hud.set_hold(-1.0)
		return
	var m = _find_target()
	if m == null:
		hud.set_prompt("")
	else:
		hud.set_prompt(str(_action_for(m)["text"]))
	if hold_target != null and is_instance_valid(hold_target):
		hud.set_hold(hold_time / maxf(0.1, float(_action_for(hold_target)["secs"])))
	else:
		hud.set_hold(-1.0)


func _state(m) -> String:
	if m.broken:
		return "BROKEN"
	return "ON" if m.is_on else "OFF"


# =====================================================================
#  THE END
# =====================================================================

func _finish(won: bool, reason: String) -> void:
	game_over = true
	Game.result = {
		"won": won,
		"reason": reason,
		"sols": sol + (1 if won else 0),
		"seconds": elapsed,
		"energy": energy,
		"oxygen": oxygen,
		"health": health,
		"parts": parts,
		"stats": stats,
	}
	get_tree().change_scene_to_file("res://scenes/end.tscn")
