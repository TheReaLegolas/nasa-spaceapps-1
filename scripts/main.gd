extends Node2D
# The colony game. Builds the world from world_data.gd and runs all the rules.

const WorldData = preload("res://scripts/world_data.gd")
const MachineScript = preload("res://scripts/machine.gd")
const PlayerScript = preload("res://scripts/player.gd")
const NpcScript = preload("res://scripts/npc.gd")
const VehicleScript = preload("res://scripts/vehicle.gd")
const HudScript = preload("res://scripts/hud.gd")

const DAY_END := 110.0            # seconds of daylight in each sol; the rest is night

# ---------------- balance numbers (all "per second"). Change these to tune the game.
const START_ENERGY := 70.0
const START_OXYGEN := 80.0
const START_PARTS := 3
const PANEL_POWER := 0.26         # energy one clean, working solar panel makes in full sun
const TURBINE_POWER := 0.10       # energy one wind turbine makes, day and night
const DUSTY_FACTOR := 0.5         # a dusty panel only makes this share of its energy
const CABLE_FACTOR := 0.5         # share of the energy that arrives while the power line is broken
const STORM_SUN := 0.3            # how much sunlight gets through a dust storm
const STORM_WIND := 2.0           # turbines spin faster in a storm
const BASE_USE := 0.08            # energy the colony always uses
const OXY_USE := 0.55             # energy used by the oxygen machine
const OXY_MAKE := 0.50            # oxygen made by the oxygen machine
const FARM_OXYGEN := 0.06         # oxygen made by the greenhouse plants
const BREATHING := 0.20           # oxygen the colonists breathe
const AIR_LEAK := 0.30            # oxygen lost through each hole in a home
const HEAT_USE := 0.60            # energy used by the heater
const SHIELD_USE := 0.90          # energy used by the radiation shield
const ROVER_USE := 0.15           # energy used while driving a rover
const BATTERY_LEAK := 0.40        # energy lost while the battery is broken
const COLD_DAMAGE := 0.30         # health lost at night with the heater off
const RAD_DAMAGE := 1.0           # health lost in a radiation storm with the shield off
const HEALTH_REGEN := 0.14        # health that comes back when you are safe
const STORM_SECONDS := 35.0
const DEBRIS_HIT := 8.0           # health lost when flying debris hits you
const WORKSHOP_COST := 25.0       # energy needed to build one spare part in the workshop
const PANEL_COST := 2             # spare parts to build a solar panel
const TURBINE_COST := 3           # spare parts to build a wind turbine
const ORE_SECONDS := 55.0         # how long a miner needs to dig one ore
const ORE_MAX := 3                # the most ore one miner can hold
const WARN_SECONDS := 25.0        # how early Mars News warns about storms
const NIGHT_FLARES := 3           # how many nights get a solar flare
const NIGHT_FAULTS := 3           # how many other nights get a breakdown

# which kind of problem a broken machine counts as
const BROKEN_KIND := {
	"panel": "panels", "battery": "battery", "relay": "cable", "antenna": "antenna",
	"drill": "drill", "oxygen": "oxy", "farm": "farm",
}

# where to find each colonist (used in the news banner)
const PLACES := {
	"nova": "the solar field (west)", "ada": "the command center", "bo": "the mine (north-east)",
	"sam": "the habitat dome (south)", "tom": "the farm (south-west)",
	"mira": "the workshop (south-east)", "leo": "the oxygen machine (east)",
}

# Every kind of problem: who notices it, who knows how to fix it, and what they say.
const FAULTS := {
	"panels": {
		"reporter": "nova", "expert": "mira", "also": "dust",
		"report": "The storm smashed some of our solar panels! A broken panel makes no energy at all.",
		"how": "A broken panel needs 1 spare part. Stand next to it and hold E. Spare parts are made from ore: collect ore from the miners at the mine.",
		"again": "You know what to do: repair each one with a spare part.",
		"task": "Repair the broken solar panels",
	},
	"dust": {
		"reporter": "nova", "expert": "mira", "also": "",
		"report": "The storm left our solar panels covered in dust! A dusty panel only makes half its energy.",
		"how": "Dust blocks the sunlight. NASA's Mars rovers have lost power the same way. Wipe each panel clean: hold E next to it. It costs no spare parts, only time.",
		"again": "Wipe each panel clean: hold E next to it. It costs nothing but time.",
		"task": "Wipe the dust off the solar panels",
	},
	"battery": {
		"reporter": "nova", "expert": "mira", "also": "",
		"report": "The battery is leaking energy! If we do nothing, it will be empty before the night is over.",
		"how": "A leaking battery wastes energy all the time. Repair it with 1 spare part: hold E next to the battery in the solar field.",
		"again": "Repair the battery with 1 spare part.",
		"task": "Repair the leaking battery",
	},
	"cable": {
		"reporter": "ada", "expert": "mira", "also": "",
		"report": "The lights keep flickering! Something must be wrong with the power line from the solar field.",
		"how": "The power line carries energy from the solar field to the colony. While it is broken, only half of the energy arrives. Repair the power line pole near the battery with 1 spare part.",
		"again": "Repair the power line pole near the battery with 1 spare part.",
		"task": "Repair the power line",
	},
	"antenna": {
		"reporter": "ada", "expert": "mira", "also": "",
		"report": "I cannot broadcast! The antenna is broken, so there are no storm warnings and your map is dark.",
		"how": "The antenna sends the news and the map signal. It stands right next to the command center. Repair it with 1 spare part.",
		"again": "Repair the antenna next to the command center with 1 spare part.",
		"task": "Repair the antenna",
	},
	"drill": {
		"reporter": "bo", "expert": "mira", "also": "",
		"report": "The mine drill is jammed! We cannot dig any ore until it is fixed.",
		"how": "No drill means no ore, and no ore means no new spare parts. Repair the drill at the mine with 1 spare part.",
		"again": "Repair the drill with 1 spare part and we will get back to digging.",
		"task": "Repair the mine drill",
	},
	"oxy": {
		"reporter": "sam", "expert": "leo", "also": "",
		"report": "People are getting dizzy. The oxygen machine has stopped working!",
		"how": "The oxygen machine turns Mars air into air we can breathe. Repair it with 1 spare part, then check that it is switched ON.",
		"again": "Repair the oxygen machine with 1 spare part, then check that it is ON.",
		"task": "Repair the oxygen machine",
	},
	"leak": {
		"reporter": "sam", "expert": "leo", "also": "",
		"report": "A meteorite hit a home! Air is leaking out.",
		"how": "Mars has very thin air, so small space rocks reach the ground. Air escapes through the hole and our oxygen drops faster. Seal the hole with 1 spare part: hold E next to the damaged building.",
		"again": "Seal the hole with 1 spare part before we lose too much air.",
		"task": "Seal the air leak",
	},
	"farm": {
		"reporter": "tom", "expert": "leo", "also": "",
		"report": "The grow lights in the greenhouse went out! The plants cannot grow in the dark.",
		"how": "Plants take in the air we breathe out and give back oxygen. Without light they stop. Repair the greenhouse with 1 spare part to get that extra oxygen back.",
		"again": "Repair the greenhouse with 1 spare part.",
		"task": "Repair the greenhouse lights",
	},
}

var energy := START_ENERGY
var oxygen := START_OXYGEN
var health := 100.0
var parts := START_PARTS
var net_power := 0.0

var sol := 0                      # 0 means the first sol
var sol_time := 0.0
var elapsed := 0.0
var game_over := false
var night_announced := false
var low_oxygen_warned := false
var low_energy_warned := false
var drive_warn := 0.0

var world: Node2D
var cam: Camera2D
var player
var hud
var sky: CanvasModulate

var solids: Array = []            # everything that blocks the player; shared with player.gd
var things: Array = []            # every building, machine and prop
var by_id := {}
var panels: Array = []            # solar panels that exist (not empty plots)
var turbines: Array = []
var homes: Array = []
var oxy_machine
var heater
var shield
var battery
var relay
var antenna
var drill
var greenhouse
var workshop

var npcs: Array = []              # colonists you can talk to: the named ones and the miners
var npc_by_id := {}
var miners: Array = []
var rovers: Array = []
var trucks: Array = []
var driving = null                # the rover the player is driving, or null

var events: Array = []
var today := {}
var weather_start := 0
var storm_left := 0.0
var storm_dir := 1.0
var storm_alpha := 0.0
var debris_timer := 0.0
var flying: Array = []
var flare_left := 0.0
var flare_text := ""
var hit_cooldown := 0.0

var quests: Array = []            # problems the colony has right now
var learned := {}                 # kinds of problem the player already knows how to fix

var dialog_queue: Array = []
var dialog_open := false
var hold_target = null
var hold_time := 0.0

var stats := {
	"cold": 0.0, "radiation": 0.0, "debris": 0.0, "blackout": 0.0, "driven": 0.0,
	"repairs": 0, "parts_used": 0, "parts_built": 0, "ore": 0, "built": 0, "cleaned": 0,
	"lowest_oxygen": 100.0,
}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	Game.paused = false
	Game.shelter = false
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
	dirt.color = Color(0.78, 0.39, 0.24)
	dirt.size = WorldData.WORLD_SIZE
	dirt.z_index = -11
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dirt)

	# the ground is four big pictures with the roads, paths and fields painted on
	for tile in WorldData.GROUND_TILES:
		var g := Sprite2D.new()
		g.texture = load("res://assets/ground/%s.png" % str(tile[0]))
		g.centered = false
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.scale = Vector2(2, 2)
		g.position = tile[1]
		g.z_index = -10
		add_child(g)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	sky = CanvasModulate.new()
	add_child(sky)

	# --- buildings, machines and props
	for data in WorldData.THINGS:
		var m = MachineScript.new()
		world.add_child(m)
		m.setup(data)
		things.append(m)
		solids.append(m)
		by_id[m.tid] = m
		if m.kind == "panel":
			panels.append(m)
		elif m.kind == "home":
			homes.append(m)
	oxy_machine = by_id["oxygen"]
	heater = by_id["heater"]
	shield = by_id["shield"]
	battery = by_id["battery"]
	relay = by_id["relay"]
	antenna = by_id["antenna"]
	drill = by_id["drill"]
	greenhouse = by_id["greenhouse"]
	workshop = by_id["workshop"]
	oxy_machine.switchable = true
	oxy_machine.is_on = true
	heater.switchable = true
	shield.switchable = true
	for m in [oxy_machine, heater, shield]:
		m.refresh()

	# --- named colonists
	for data in WorldData.NPCS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc(str(data["id"]), str(data["name"]), str(data["role"]), str(data["sheet"]))
		n.position = data["pos"]
		n.solid = true
		npcs.append(n)
		npc_by_id[n.npc_id] = n
		solids.append(n)

	# --- miners
	for data in WorldData.MINERS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc(str(data["id"]), str(data["name"]), "miner", "miner")
		n.start_patrol(data["points"])
		n.ore = 1
		n.set_bubble("ore x1")
		npcs.append(n)
		npc_by_id[n.npc_id] = n
		miners.append(n)

	# --- shopkeepers beside the market stalls (decoration: you cannot talk to them)
	for entry in WorldData.VENDORS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc("", "", "vendor", str(entry[1]))
		n.position = entry[0]
		n.solid = true
		solids.append(n)

	# --- townspeople
	for entry in WorldData.TOWN:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc("", "", "town", str(entry[1]))
		n.start_town(int(entry[0]))

	# --- vehicles
	for spot in WorldData.ROVER_SPOTS:
		var v = VehicleScript.new()
		world.add_child(v)
		v.setup("rover", spot[0])
		v.set_facing(str(spot[1]))
		rovers.append(v)
		solids.append(v)
	for route in WorldData.TRUCK_ROUTES:
		var v = VehicleScript.new()
		world.add_child(v)
		v.setup("truck", route[0])
		v.start_route(route)
		trucks.append(v)
		solids.append(v)

	# --- the player
	player = PlayerScript.new()
	world.add_child(player)
	player.setup_actor(Game.character)
	player.position = WorldData.PLAYER_START
	player.world_size = WorldData.WORLD_SIZE
	player.solids = solids
	Game.player_pos = player.position

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WorldData.WORLD_SIZE.x)
	cam.limit_bottom = int(WorldData.WORLD_SIZE.y)
	cam.position = player.position + Vector2(0, -40)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	add_child(cam)
	cam.make_current()
	cam.reset_smoothing()

	hud = HudScript.new()
	add_child(hud)


# =====================================================================
#  THE PLAN FOR THIS GAME (different every time you play)
# =====================================================================

func _schedule_events() -> void:
	events.clear()
	var flare_list: Array = Game.flares().duplicate()
	flare_list.shuffle()
	var flare_i := 0

	# Sol 1 always has the big dust storm from the story.
	events.append(_event(0, 60.0, "dust", 3))

	# Every kind of breakdown happens at least once, in a different order each game.
	var pool := ["oxy", "battery", "leak", "cable", "drill", "antenna", "farm", "dust", "dust"]
	pool.shuffle()
	for s in range(1, Game.TOTAL_SOLS):
		var first: String = pool[(s - 1) % pool.size()]
		var day_at: float = rng.randf_range(30.0, 85.0)
		if s == 1:
			# the second sol also teaches the shield, in daylight
			var day_flare: Dictionary = _event(s, 38.0, "flare", 0)
			day_flare["flare"] = flare_list[flare_i % flare_list.size()]
			flare_i += 1
			events.append(day_flare)
			day_at = rng.randf_range(84.0, 96.0)
		events.append(_event(s, day_at, first, rng.randi_range(1, 2)))

	# Some nights bring a solar flare, some a breakdown.
	var night_sols := []
	for s in range(2, Game.TOTAL_SOLS):
		night_sols.append(s)
	night_sols.shuffle()
	var night_kinds := ["oxy", "battery", "leak", "cable", "drill", "farm"]
	for i in night_sols.size():
		var ns: int = night_sols[i]
		var night_at: float = rng.randf_range(DAY_END + 8.0, Game.SOL_SECONDS - 50.0)
		if i < NIGHT_FLARES:
			var night_flare: Dictionary = _event(ns, night_at, "flare", 0)
			night_flare["flare"] = flare_list[flare_i % flare_list.size()]
			flare_i += 1
			events.append(night_flare)
		elif i < NIGHT_FLARES + NIGHT_FAULTS:
			var pick: String = night_kinds[rng.randi() % night_kinds.size()]
			events.append(_event(ns, night_at, pick, 1))


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
		_say("Mission Control", "Watch your bars. ENERGY comes from solar panels and wind turbines. OXYGEN is the air everyone breathes. HEALTH is the long bar at the top. If oxygen or health runs out, the mission ends.")
		_say("Mission Control", "Machines use energy, and there is never enough for everything. Walk to a machine and press E to switch it on or off. Every choice has a cost!")
		_say("Mission Control", "When a colonist needs you, a ! appears on the map in the corner. Go and talk to them. Miners dig ore at the mine: collect it to get spare parts. The rovers parked by the roads are faster than walking: press E to drive one.")

	var report: String = "Good morning, New Hope! Sol %d of %d. Today's high is %d C. Tonight's low is %d C, so you will need the heater." % [i + 1, Game.TOTAL_SOLS, int(today["max"]), int(today["min"])]
	_say("Ada, Mars News", report)
	if antenna.broken:
		_say("Ada, Mars News", "...crackle... The antenna is broken, so I cannot see what the weather will do today. Stay alert!")
		return
	if dust:
		_say("Ada, Mars News", "Warning: a DUST STORM is coming today. Dust blocks the sunlight, so solar panels make less energy. The wind can break panels and throw debris around. Stay out of its way, or wait inside a rover!")
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
	Game.paused = dialog_open
	if not Game.paused:
		_drive(delta)
		_simulate(delta)
		if game_over:
			return
		_update_flying(delta)
		_update_hold(delta)
	Game.player_pos = player.position
	Game.shelter = _is_night() or storm_left > 0.0 or flare_left > 0.0
	cam.position = player.position + Vector2(0, -40)
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


func _count_broken_panels() -> int:
	var n := 0
	for p in panels:
		if p.broken:
			n += 1
	return n


func _count_dusty_panels() -> int:
	var n := 0
	for p in panels:
		if p.dusty and not p.broken:
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
	var sun: float = _sun()
	var storm: bool = storm_left > 0.0
	var gain: float = 0.0
	for p in panels:
		if p.broken:
			continue
		var out: float = PANEL_POWER * sun
		if storm:
			out *= STORM_SUN
		if p.dusty:
			out *= DUSTY_FACTOR
		gain += out
	var wind: float = TURBINE_POWER
	if storm:
		wind *= STORM_WIND
	gain += wind * float(turbines.size())
	if relay.broken:
		gain *= CABLE_FACTOR
	var use: float = BASE_USE
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
			hud.show_banner("POWER OUT!", "The battery is empty, so every machine switched off. Fix or build solar panels, or wait for sunlight, then switch the machines back on.", 11.0)

	# ---- oxygen
	var air: float = -BREATHING
	if oxy_machine.works():
		air += OXY_MAKE
	if not greenhouse.broken:
		air += FARM_OXYGEN
	for h in homes:
		if h.leaking:
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
		var cold: float = COLD_DAMAGE * clampf(-float(today["min"]) / 75.0, 0.6, 1.4)
		health -= cold * delta
		stats["cold"] += cold * delta
		in_danger = true
	if not in_danger:
		health = minf(100.0, health + HEALTH_REGEN * delta)

	# ---- miners dig ore while the drill works
	if not drill.broken:
		for mn in miners:
			if mn.ore < ORE_MAX:
				mn.ore_timer += delta
				if mn.ore_timer >= ORE_SECONDS:
					mn.ore_timer = 0.0
					mn.ore += 1
					mn.set_bubble("ore x%d" % mn.ore)

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
	drive_warn = maxf(0.0, drive_warn - delta)

	# ---- warnings
	if oxygen < 25.0 and not low_oxygen_warned:
		low_oxygen_warned = true
		hud.show_banner("OXYGEN IS LOW", "Make sure the oxygen machine is ON and working, and listen to anyone with a ! over their head.", 9.0)
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
#  STORMS, FLARES AND BREAKDOWNS
# =====================================================================

func _run_events() -> void:
	for ev in events:
		if ev["sol"] != sol or ev["done"]:
			continue
		var at: float = ev["t"]
		if not ev["warned"] and sol_time >= at - WARN_SECONDS:
			ev["warned"] = true
			if not antenna.broken:
				if ev["type"] == "dust":
					hud.show_banner("MARS NEWS: STORM WARNING", "A dust storm arrives very soon. Finish what you are doing and get ready to dodge, or wait inside a rover!", 10.0)
				elif ev["type"] == "flare":
					hud.show_banner("MARS NEWS: RADIATION WARNING", "A solar flare is about to hit. Get to the radiation shield in the east and decide: is it worth the energy?", 10.0)
		if sol_time >= at:
			ev["done"] = true
			_start_event(ev)


func _start_event(ev: Dictionary) -> void:
	var type: String = ev["type"]
	if type == "dust":
		_start_storm(int(ev["breaks"]))
	elif type == "flare":
		var rec: Dictionary = ev["flare"]
		var cls: String = str(rec.get("cls", "X1.0"))
		flare_left = _flare_seconds(cls)
		flare_text = "Class %s flare. NASA recorded a real flare like this on %s." % [cls, str(rec.get("date", ""))]
		hud.show_banner("RADIATION STORM!", "Turn the shield ON or you will lose health. " + flare_text, 12.0)
	elif type == "leak":
		_meteorite()
	else:
		_break_machine(type)


func _flare_seconds(cls: String) -> float:
	# stronger real flares last longer in the game
	var strength: float = cls.substr(1).to_float()
	if cls.begins_with("X"):
		return clampf(24.0 + strength * 2.5, 24.0, 45.0)
	return 20.0


func _start_storm(breaks: int) -> void:
	storm_left = STORM_SECONDS
	if rng.randf() < 0.5:
		storm_dir = 1.0
	else:
		storm_dir = -1.0
	debris_timer = 1.5
	for t in turbines:
		t.anim_speed = 16.0
	var working := []
	for p in panels:
		if not p.broken:
			working.append(p)
	working.shuffle()
	var count: int = mini(breaks, working.size())
	var hit := []
	for i in count:
		var p2 = working[i]
		p2.broken = true
		p2.refresh()
		hit.append(p2)
	hud.show_banner("DUST STORM!", "The wind is throwing debris around. Dodge it, or wait inside a rover until the storm has passed.", 9.0)
	_start_fault("panels", hit, "DUST STORM!", "The wind is throwing debris around: dodge it, or wait inside a rover.")


func _end_storm() -> void:
	storm_left = 0.0
	for t in turbines:
		t.anim_speed = 6.0
	var dusted := []
	for p in panels:
		if not p.broken and not p.dusty:
			p.dusty = true
			p.refresh()
			dusted.append(p)
	hud.show_banner("THE STORM HAS PASSED", "The air is clear again.", 6.0)
	_start_fault("dust", dusted, "THE STORM HAS PASSED", "")


func _meteorite() -> void:
	var options := []
	for h in homes:
		if not h.leaking:
			options.append(h)
	if options.is_empty():
		return
	var target = options[rng.randi() % options.size()]
	target.leaking = true
	target.refresh()
	_start_fault("leak", [target], "METEORITE!", "A rock from space just hit the colony.")


func _break_machine(fault: String) -> void:
	var m = null
	if fault == "oxy":
		m = oxy_machine
	elif fault == "battery":
		m = battery
	elif fault == "cable":
		m = relay
	elif fault == "drill":
		m = drill
	elif fault == "antenna":
		m = antenna
	elif fault == "farm":
		m = greenhouse
	if m == null:
		return
	if m.broken:
		return
	m.broken = true
	m.refresh()
	if fault == "antenna":
		_start_fault(fault, [m], "NO SIGNAL!", "The map and the storm warnings are down.")
	else:
		_start_fault(fault, [m], "", "")


# ---------------------------------------------------------------------
#  Problems and the "!" chain
#  stage 0: the colonist who noticed has a "!"      (talk to them)
#  stage 1: the expert has a "!"                    (only the first time for each kind of problem)
#  stage 2: the broken things are marked on the map (go and fix them)
# ---------------------------------------------------------------------

func _has_fault(m, fault: String) -> bool:
	if fault == "dust":
		return m.dusty
	if fault == "leak":
		return m.leaking
	return m.broken and str(BROKEN_KIND.get(m.kind, "")) == fault


func _fault_of(m) -> String:
	# the kind of problem this thing has right now ("" if none)
	if m.broken:
		return str(BROKEN_KIND.get(m.kind, ""))
	if m.leaking:
		return "leak"
	if m.dusty:
		return "dust"
	return ""


func _knows_fix(fault: String) -> bool:
	if learned.has(fault):
		return true
	for q in quests:
		if q["kind"] == fault and q["stage"] == 2:
			return true
	return false


func _start_fault(fault: String, targets: Array, title: String, lead: String) -> void:
	if targets.is_empty():
		return
	for q in quests:
		if q["kind"] == fault:
			for m in targets:
				if not q["targets"].has(m):
					q["targets"].append(m)
			_refresh_quests()
			return
	quests.append({"kind": fault, "targets": targets, "stage": 0})
	_refresh_quests()
	var f: Dictionary = FAULTS[fault]
	var who = npc_by_id[f["reporter"]]
	var head: String = title
	if head == "":
		head = "SOMEONE NEEDS YOU"
	var where: String = str(PLACES.get(who.npc_id, "the colony"))
	var text: String = "%s at %s has something to tell you." % [who.npc_name, where]
	if not antenna.broken:
		text += " Follow the ! on your map."
	if lead != "":
		text = lead + " " + text
	hud.show_banner(head, text, 11.0)


func _refresh_quests() -> void:
	# forget what has been fixed, then put the "!" over the right heads
	var keep := []
	for q in quests:
		var left := []
		for m in q["targets"]:
			if is_instance_valid(m) and _has_fault(m, str(q["kind"])):
				left.append(m)
		q["targets"] = left
		if not left.is_empty():
			keep.append(q)
	quests = keep
	for n in npcs:
		n.set_alert(false)
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0:
			npc_by_id[f["reporter"]].set_alert(true)
		elif q["stage"] == 1:
			npc_by_id[f["expert"]].set_alert(true)


func _npc_has_quest(npc) -> bool:
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0 and f["reporter"] == npc.npc_id:
			return true
		if q["stage"] == 1 and f["expert"] == npc.npc_id:
			return true
	return false


func _report_text(q: Dictionary) -> String:
	var f: Dictionary = FAULTS[q["kind"]]
	if q["kind"] == "leak":
		var names := PackedStringArray()
		for m in q["targets"]:
			names.append(str(m.title))
		return "A meteorite hit %s! Air is leaking out, so our oxygen drops faster." % " and ".join(names)
	return str(f["report"])


func _talk(npc) -> void:
	var said := false
	for q in quests:
		var fault: String = q["kind"]
		var f: Dictionary = FAULTS[fault]
		if q["stage"] == 0 and f["reporter"] == npc.npc_id:
			said = true
			_say(npc.npc_name, _report_text(q))
			if learned.has(fault):
				_say(npc.npc_name, str(f["again"]) + " I marked it on your map.")
				q["stage"] = 2
			else:
				var expert = npc_by_id[f["expert"]]
				var where: String = str(PLACES.get(expert.npc_id, "the colony"))
				_say(npc.npc_name, "I do not know how to fix it. Ask %s at %s! Follow the ! on your map." % [expert.npc_name, where])
				q["stage"] = 1
		elif q["stage"] == 1 and f["expert"] == npc.npc_id:
			said = true
			if learned.has(fault):
				_say(npc.npc_name, "And you already know this one. " + str(f["again"]))
			else:
				_say(npc.npc_name, str(f["how"]))
			learned[fault] = true
			var also: String = str(f["also"])
			if also != "" and not learned.has(also):
				var f2: Dictionary = FAULTS[also]
				_say(npc.npc_name, "One more thing. " + str(f2["how"]))
				learned[also] = true
			_say(npc.npc_name, "I marked it on your map. Good luck!")
			q["stage"] = 2
	if not said:
		if npc.role == "miner" and npc.ore > 0:
			_collect_ore(npc)
		else:
			for line in _npc_lines(npc):
				_say(npc.npc_name, line)
	_refresh_quests()


func _collect_ore(npc) -> void:
	var n: int = npc.ore
	parts += n
	stats["ore"] += n
	npc.ore = 0
	npc.ore_timer = 0.0
	npc.set_bubble("")
	if n == 1:
		hud.toast("+1 spare part from %s" % npc.npc_name)
	else:
		hud.toast("+%d spare parts from %s" % [n, npc.npc_name])


func _npc_lines(npc) -> Array:
	var lines := []
	var role: String = npc.role
	if role == "engineer":
		lines.append("I fix things and I can teach you how. When somebody has a problem, a ! shows over their head and on your map.")
		lines.append("Tip: you can build more solar panels and wind turbines on the empty plots in the solar field. Panels are strong by day. Turbines are weak, but they also work at night and in dust storms.")
		lines.append("Out of spare parts? Collect ore from the miners, or press E at my workshop to build one. But the workshop uses a lot of energy!")
	elif role == "doctor":
		if flare_left > 0.0 and not shield.works():
			lines.append("Radiation storm! Please turn the shield ON. Radiation can make everyone sick, even though we cannot see or feel it.")
		elif _is_night() and not heater.works():
			lines.append("It is %d C outside tonight! Without the heater we lose health. Please switch it on." % int(today["min"]))
		else:
			lines.append("Earth has thick air and a magnetic field that block most space radiation. Mars does not, so we need a shield when the Sun is stormy.")
		lines.append("If your health is low, stay safe for a while: keep warm and shielded, and it slowly comes back.")
	elif role == "scientist":
		lines.append("The air on Mars is mostly carbon dioxide, which we cannot breathe. Our oxygen machine turns it into oxygen, like NASA's MOXIE experiment on the Perseverance rover.")
		lines.append("Making oxygen needs a lot of electricity. If the battery is low at night, you can switch the machine off for a while, but watch the oxygen bar!")
		lines.append("Did you know? A sol, a day on Mars, is about 40 minutes longer than a day on Earth.")
	elif role == "journalist":
		lines.append("This is Ada with Mars News. Sol %d of %d. Today's high is %d C and tonight's low is %d C." % [sol + 1, Game.TOTAL_SOLS, int(today["max"]), int(today["min"])])
		if storm_left > 0.0:
			lines.append("A dust storm is blowing right now. Watch out for flying debris!")
		elif flare_left > 0.0:
			lines.append("A radiation storm is hitting us right now. " + flare_text)
		else:
			lines.append("I will warn everyone when a storm is on its way. Watch for my news flashes at the top of the screen.")
	elif role == "technician":
		lines.append("I look after the solar field. %d panels and %d wind turbines are making energy for us." % [panels.size() - _count_broken_panels(), turbines.size()])
		lines.append("See the empty plots with a + sign? Stand on one and hold E to build. A solar panel costs %d spare parts and a wind turbine costs %d." % [PANEL_COST, TURBINE_COST])
	elif role == "farmer":
		lines.append("Plants are amazing: they take in the air we breathe out and give back oxygen. My greenhouse adds a little oxygen all the time.")
		lines.append("On Mars the soil has no food for plants, so we feed them ourselves, and the grow lights give them light when the Sun is weak.")
	elif role == "miner":
		lines.append("Still digging! Come back in a little while and I will have ore for you.")
		lines.append("Ore is rock with metal inside. We turn it into spare parts for repairs and for building.")
	else:
		lines.append("Hello, Operator!")
	return lines


# =====================================================================
#  FLYING DEBRIS
# =====================================================================

func _update_flying(delta: float) -> void:
	if storm_left > 0.0:
		debris_timer -= delta
		if debris_timer <= 0.0:
			debris_timer = rng.randf_range(0.5, 0.9)
			_throw_debris()

	var keep := []
	for piece in flying:
		var node: Node2D = piece["node"]
		var vel: Vector2 = piece["vel"]
		var shard: Polygon2D = piece["shard"]
		node.position += vel * delta
		shard.rotation += float(piece["spin"]) * delta
		var gone: bool = absf(node.position.x - player.position.x) > 950.0
		if not gone and driving == null and hit_cooldown <= 0.0 and node.position.distance_to(player.position) < 30.0:
			health -= DEBRIS_HIT
			stats["debris"] += DEBRIS_HIT
			hit_cooldown = 1.0
			hold_target = null
			player.knock = Vector2(signf(vel.x) * 260.0, 0.0)
			hud.flash_hurt()
			gone = true
		if gone:
			node.queue_free()
		else:
			keep.append(piece)
	flying = keep


func _throw_debris() -> void:
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
#  DRIVING
# =====================================================================

func _enter_rover(v) -> void:
	driving = v
	v.mode = "driven"
	player.in_vehicle = true
	player.visible = false
	player.position = v.position
	hold_target = null
	hud.toast("Driving! Arrow keys to steer, E to get out.")


func _exit_rover() -> void:
	var v = driving
	var offsets := [Vector2(0, 76), Vector2(0, -70), Vector2(104, 12), Vector2(-104, 12), Vector2(96, 76), Vector2(-96, 76), Vector2(0, 120)]
	var chosen: Vector2 = v.position + Vector2(0, 76)
	for o in offsets:
		var p: Vector2 = v.position + o
		if _spot_free(p):
			chosen = p
			break
	driving = null
	v.mode = "parked"
	player.in_vehicle = false
	player.visible = true
	player.position = chosen


func _spot_free(p: Vector2) -> bool:
	if p.x < 40.0 or p.y < 110.0 or p.x > WorldData.WORLD_SIZE.x - 40.0 or p.y > WorldData.WORLD_SIZE.y - 30.0:
		return false
	for s in solids:
		if not is_instance_valid(s):
			continue
		if not s.solid:
			continue
		var box: Rect2 = s.get_col()
		if box.grow(20.0).has_point(p):
			return false
	return true


func _drive(delta: float) -> void:
	if driving == null:
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.01:
		if energy <= 1.0:
			if drive_warn <= 0.0:
				drive_warn = 2.5
				hud.toast("The battery is empty: the rover cannot move!")
		else:
			# Trucks stop when the rover is in front of them, and the rover may pass a truck
			# (blocking it would jam the road when the two meet head-on).
			var moved: bool = driving.drive(dir, delta)
			if moved:
				energy = maxf(0.0, energy - ROVER_USE * delta)
				stats["driven"] += delta
	player.position = driving.position


# =====================================================================
#  USING THINGS (the E key)
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_over or not event.is_action_pressed("interact"):
		return
	if dialog_open:
		_next_dialog()
		return
	if driving != null:
		_exit_rover()
		return
	var t = _find_target()
	if t == null:
		return
	var act: Dictionary = _action_for(t)
	if act["mode"] == "press":
		_do_press(t)
	elif act["mode"] == "hold":
		hold_target = t
		hold_time = 0.0


func _rect_dist(box: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0)
	var dy: float = maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


func _is_interactive(m) -> bool:
	if m.kind == "decor":
		return false
	if m.kind == "home":
		return m.leaking
	return true


func _find_target():
	# the nearest thing, colonist or rover within reach (or null)
	var best = null
	var best_d: float = 70.0
	var p: Vector2 = player.position
	for n in npcs:
		var dn: float = p.distance_to(n.position) - 26.0
		if dn < best_d:
			best = n
			best_d = dn
	for v in rovers:
		if v.mode != "parked":
			continue
		var box: Rect2 = v.get_col()
		var dv: float = _rect_dist(box, p)
		if dv < best_d:
			best = v
			best_d = dv
	for m in things:
		if not _is_interactive(m):
			continue
		var dm: float = m.dist_to(p)
		if dm < best_d:
			best = m
			best_d = dm
	return best


func _act(text: String, mode: String, secs: float) -> Dictionary:
	return {"text": text, "mode": mode, "secs": secs}


func _action_for(t) -> Dictionary:
	# what pressing E would do to this thing right now
	var what: String = t.what
	if what == "npc":
		if t.role == "miner" and t.ore > 0 and not _npc_has_quest(t):
			return _act("Press E: take %d ore from %s" % [t.ore, t.npc_name], "press", 0.0)
		return _act("Press E: talk to %s" % t.npc_name, "press", 0.0)
	if what == "vehicle":
		return _act("Press E: drive the rover (it stays on the roads and uses a little energy)", "press", 0.0)

	var kind: String = t.kind
	if kind == "plot_solar":
		if parts >= PANEL_COST:
			return _act("Hold E: build a solar panel here (costs %d spare parts)" % PANEL_COST, "hold", 3.0)
		return _act("Empty plot: you need %d spare parts to build a solar panel here" % PANEL_COST, "none", 0.0)
	if kind == "plot_wind":
		if parts >= TURBINE_COST:
			return _act("Hold E: build a wind turbine here (costs %d spare parts)" % TURBINE_COST, "hold", 3.0)
		return _act("Empty plot: you need %d spare parts to build a wind turbine here" % TURBINE_COST, "none", 0.0)

	var fault: String = _fault_of(t)
	if fault != "":
		if not _knows_fix(fault):
			return _act("Something is wrong here. Follow the ! on your map to find out what to do.", "none", 0.0)
		if fault == "dust":
			return _act("Hold E: wipe the dust off this solar panel", "hold", 1.5)
		if parts <= 0:
			return _act("This needs 1 spare part, but you have none! Collect ore from the miners or use the workshop.", "none", 0.0)
		if fault == "leak":
			return _act("Hold E: seal the hole in %s (uses 1 spare part)" % t.title, "hold", 2.4)
		return _act("Hold E: repair the %s (uses 1 spare part)" % str(t.title).to_lower(), "hold", 2.4)

	if kind == "workshop":
		if energy >= WORKSHOP_COST + 5.0:
			return _act("Press E: build 1 spare part (costs %d energy)" % int(WORKSHOP_COST), "press", 0.0)
		return _act("Workshop: not enough energy to build a spare part", "none", 0.0)
	if t.switchable:
		if t.is_on:
			return _act("Press E: switch the %s OFF (saves energy)" % str(t.title).to_lower(), "press", 0.0)
		if energy < 3.0:
			return _act("No power! The battery is empty.", "none", 0.0)
		return _act("Press E: switch the %s ON (uses energy)" % str(t.title).to_lower(), "press", 0.0)
	if kind == "panel":
		return _act("Solar panel: turns sunlight into energy", "none", 0.0)
	if kind == "turbine":
		return _act("Wind turbine: makes a little energy day and night, even in a dust storm", "none", 0.0)
	if kind == "battery":
		return _act("Battery: stores energy for the night", "none", 0.0)
	if kind == "relay":
		return _act("Power line: carries energy from the solar field to the colony", "none", 0.0)
	if kind == "antenna":
		return _act("Antenna: sends the news and the map signal", "none", 0.0)
	if kind == "drill":
		return _act("Mine drill: digs up ore for spare parts", "none", 0.0)
	if kind == "farm":
		return _act("Greenhouse: the plants make a little extra oxygen", "none", 0.0)
	return _act("", "none", 0.0)


func _do_press(t) -> void:
	if t.what == "npc":
		_talk(t)
	elif t.what == "vehicle":
		_enter_rover(t)
	elif t.kind == "workshop":
		energy -= WORKSHOP_COST
		parts += 1
		stats["parts_built"] += 1
		hud.toast("+1 spare part (it cost %d energy)" % int(WORKSHOP_COST))
	elif t.switchable:
		t.is_on = not t.is_on
		t.refresh()


func _update_hold(delta: float) -> void:
	if hold_target == null:
		return
	if not is_instance_valid(hold_target) or not Input.is_action_pressed("interact") or _find_target() != hold_target:
		hold_target = null
		return
	var act: Dictionary = _action_for(hold_target)
	if act["mode"] != "hold":
		hold_target = null
		return
	hold_time += delta
	if hold_time >= float(act["secs"]):
		var t = hold_target
		hold_target = null
		_finish_hold(t)


func _finish_hold(t) -> void:
	var kind: String = t.kind
	if kind == "plot_solar":
		if parts < PANEL_COST:
			return
		parts -= PANEL_COST
		stats["parts_used"] += PANEL_COST
		stats["built"] += 1
		t.convert_to("panel", "solar_panel", "Solar panel", Rect2(t.position.x - 75.0, t.position.y - 66.0, 150.0, 60.0))
		panels.append(t)
		hud.toast("You built a solar panel: more energy by day!")
		return
	if kind == "plot_wind":
		if parts < TURBINE_COST:
			return
		parts -= TURBINE_COST
		stats["parts_used"] += TURBINE_COST
		stats["built"] += 1
		t.convert_to("turbine", "wind_turbine_0", "Wind turbine", Rect2(t.position.x - 30.0, t.position.y - 46.0, 60.0, 40.0))
		if storm_left > 0.0:
			t.anim_speed = 16.0
		turbines.append(t)
		hud.toast("You built a wind turbine: a little energy day and night!")
		return

	var fault: String = _fault_of(t)
	if fault == "":
		return
	if fault == "dust":
		t.dusty = false
		stats["cleaned"] += 1
	else:
		if parts <= 0:
			return
		parts -= 1
		stats["parts_used"] += 1
		stats["repairs"] += 1
		if fault == "leak":
			t.leaking = false
		else:
			t.broken = false
	t.refresh()
	_refresh_quests()


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
		Game.paused = false
		hud.hide_dialog()
		return
	var d: Array = dialog_queue.pop_front()
	dialog_open = true
	Game.paused = true
	hold_target = null
	hud.show_dialog(str(d[0]), str(d[1]))


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
	if flare_left > 0.0 and not shield.works():
		t.append("RADIATION! Turn the shield ON")
	if storm_left > 0.0:
		t.append("Dust storm: dodge the debris")
	if _is_night() and not heater.works():
		t.append("Night: turn the heater ON")
	if not oxy_machine.broken and not oxy_machine.is_on and oxygen < 40.0:
		t.append("Oxygen is low: turn the oxygen machine ON")
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0:
			t.append("Talk to %s (!)" % npc_by_id[f["reporter"]].npc_name)
		elif q["stage"] == 1:
			t.append("Ask %s how to fix it (!)" % npc_by_id[f["expert"]].npc_name)
		else:
			var n: int = q["targets"].size()
			if n > 1:
				t.append("%s (%d left)" % [str(f["task"]), n])
			else:
				t.append(str(f["task"]))
	if t.is_empty():
		if _is_night():
			t.append("All systems OK. Hold on until sunrise!")
		else:
			t.append("All systems OK. Fill the battery before night, or build something.")
	return t


func _state(m) -> String:
	if m.broken:
		return "BROKEN"
	if m.is_on:
		return "ON"
	return "OFF"


func _update_hud() -> void:
	hud.set_bars(energy, oxygen, health)
	hud.set_parts(parts)
	hud.set_power(net_power)
	hud.set_switches("Oxygen: %s    Heater: %s    Shield: %s" % [_state(oxy_machine), _state(heater), _state(shield)])

	var left: float = maxf(0.0, Game.SOL_SECONDS * float(Game.TOTAL_SOLS) - elapsed)
	var secs: int = int(left)
	var part_of_day: String = "Day"
	if _is_night():
		part_of_day = "Night"
	hud.set_clock("Sol %d of %d  -  %s        Time left  %02d:%02d" % [sol + 1, Game.TOTAL_SOLS, part_of_day, secs / 60, secs % 60])
	hud.set_tasks(_tasks())

	# marks on the minimap
	var marks := []
	for n in npcs:
		if n.alert.visible:
			marks.append([n.position, "alert"])
	for q in quests:
		if q["stage"] == 2:
			for m in q["targets"]:
				if is_instance_valid(m):
					marks.append([m.position, "fix"])
	for v in rovers:
		if v != driving:
			marks.append([v.position, "rover"])
	hud.set_minimap(player.position, marks, antenna.broken)

	if dialog_open:
		hud.set_prompt("")
		hud.set_hold(-1.0)
		return
	if driving != null:
		hud.set_prompt("Press E: get out of the rover")
		hud.set_hold(-1.0)
		return
	var t = _find_target()
	if t == null:
		hud.set_prompt("")
	else:
		hud.set_prompt(str(_action_for(t)["text"]))
	if hold_target != null and is_instance_valid(hold_target):
		hud.set_hold(hold_time / maxf(0.1, float(_action_for(hold_target)["secs"])))
	else:
		hud.set_hold(-1.0)


# =====================================================================
#  THE END
# =====================================================================

func _finish(won: bool, reason: String) -> void:
	game_over = true
	Game.paused = false
	var sols_done: int = sol
	if won:
		sols_done = sol + 1
	Game.result = {
		"won": won,
		"reason": reason,
		"sols": sols_done,
		"seconds": elapsed,
		"energy": energy,
		"oxygen": oxygen,
		"health": health,
		"parts": parts,
		"panels": panels.size(),
		"turbines": turbines.size(),
		"stats": stats,
	}
	get_tree().change_scene_to_file("res://scenes/end.tscn")
