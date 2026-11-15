extends Node
# "Explore and learn": on some sols a "?" appears on the map. The player picks it up,
# finds a real space tool, carries it to the colonist who knows about it, and that
# colonist explains it. Then it is added to the Discovery Notebook (N key).
#
# Everything about the items comes from data/learn_items.json. To add an item, add one
# entry to that file and put its picture in assets/learn. Nothing here needs to change.

const NpcScript = preload("res://scripts/npc.gd")
const WorldData = preload("res://scripts/world_data.gd")

const DATA_PATH := "res://data/learn_items.json"
const ART_DIR := "res://assets/learn/"
const LANG := "en"                 # the game is in English; the "tr" texts stay in the file as a spare
const FREE_AFTER := 20.0           # the "?" never appears in the first seconds of a sol
const LATEST := 150.0              # if the player is busy all day, it appears at this time anyway
const EXTRA_WARNING := 60.0        # how much earlier flares are announced once the detector is known
const GOLD := Color(1.0, 0.85, 0.4)
# places where a "?" can appear
const SPOTS := [Vector2(2100, 800), Vector2(3900, 3000), Vector2(5000, 2700), Vector2(1200, 1300), Vector2(700, 2700), Vector2(1500, 2700), Vector2(2100, 3400)]
# picture sheets for the extra experts (colonists that the items need and the colony did not have yet)
const SHEETS := ["town2", "town4", "town6", "town1", "town3", "town5"]


# The "?" on the ground.
class Find extends Node2D:
	var what := "learn"
	var title := "?"
	var mark: Sprite2D
	var t := 0.0

	func _ready() -> void:
		mark = Sprite2D.new()
		mark.texture = load("res://assets/learn/learn_question.png")
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.hframes = 2
		mark.scale = Vector2(3, 3)
		mark.offset = Vector2(0, -12)
		add_child(mark)
		z_index = 4

	func _process(delta: float) -> void:
		# a two-frame bounce
		t += delta
		mark.frame = int(t / 0.35) % 2


var main
var items: Array = []              # the entries of the JSON file
var state := {}                    # item id -> "hidden", "out", "carried", "learned" or "missed"
var teachers := {}                 # item id -> the colonist who explains it
var today = null                   # the item that can appear this sol (or null)
var find: Find = null              # the "?" lying on the map right now
var find_item: Dictionary = {}
var book_open := false

var layer: CanvasLayer
var button: Button
var carry_icon: TextureRect
var book: Panel
var book_title: Label
var cells: Array = []              # one dictionary of controls for each box in the notebook


func setup(p_main) -> void:
	main = p_main
	_load_items()
	_find_teachers()
	_build_ui()
	_refresh_ui()


func _load_items() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("learn: %s is missing" % DATA_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("learn: %s could not be read" % DATA_PATH)
		return
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
			items.append(entry)
			state[str(entry["id"])] = "hidden"


func _tr(item: Dictionary, key: String):
	# the text of an item in the game's language ("en"), or any other language as a spare
	var v = item.get(key)
	if typeof(v) != TYPE_DICTIONARY:
		return v
	if v.has(LANG):
		return v[LANG]
	for k in v:
		return v[k]
	return ""


func item_name(item: Dictionary) -> String:
	return str(_tr(item, "ad"))


func _picture(item: Dictionary) -> Texture2D:
	var path: String = ART_DIR + str(item.get("sprite", ""))
	if ResourceLoader.exists(path):
		return load(path)
	return load(ART_DIR + "learn_question.png")


func _find_teachers() -> void:
	# a colonist with the right job explains the item; if nobody has that job,
	# a new colonist with that job moves into the town
	var extra := 0
	for item in items:
		var job: String = str(_tr(item, "npc"))
		var who = null
		for n in main.npcs:
			if str(n.role).to_lower() == job.to_lower() and not teachers.values().has(n):
				who = n
				break
		if who == null:
			who = NpcScript.new()
			main.world.add_child(who)
			who.setup_npc("learn_" + str(item["id"]), job, "explorer", SHEETS[extra % SHEETS.size()])
			who.position = _free_place(extra)
			who.solid = true
			main.npcs.append(who)
			main.npc_by_id[who.npc_id] = who
			main.solids.append(who)
			extra += 1
		teachers[str(item["id"])] = who


func _free_place(i: int) -> Vector2:
	# a ring of places around the town square; take the first ones nothing stands on
	var centre := Vector2(3000, 2130)
	var found := 0
	for ring in [330.0, 420.0, 520.0, 640.0]:
		for k in 12:
			var a: float = TAU * float(k) / 12.0 + 0.26
			var p: Vector2 = centre + Vector2(cos(a) * ring * 1.5, sin(a) * ring)
			if not main._spot_free(p):
				continue
			var clear := true
			for n in main.npcs:
				if n.position.distance_to(p) < 170.0:
					clear = false
			for v in WorldData.VENDORS:
				var at: Vector2 = v[0]
				if at.distance_to(p) < 200.0:
					clear = false
			if not clear:
				continue
			if found == i:
				return p
			found += 1
	return centre + Vector2(120.0 * float(i), 0)


# ---------------------------------------------------------------------
#  The day
# ---------------------------------------------------------------------

func on_new_sol(sol_index: int) -> void:
	# yesterday's "?" was only there for one sol
	if find != null:
		state[str(find_item["id"])] = "missed"
		find.queue_free()
		find = null
		find_item = {}
		main.hud.toast("Yesterday's ? is gone. A new sol, a new chance!")
	today = null
	for item in items:
		if int(item.get("gun", 0)) == sol_index + 1 and state[str(item["id"])] == "hidden":
			today = item
			break
	_refresh_ui()


func tick() -> void:
	# called while the game is running: put today's "?" on the map when the player has time
	if today == null or find != null:
		return
	if main.sol_time < FREE_AFTER or main._phase() != "day":
		return
	var busy: bool = not main.quests.is_empty() or not main.decisions.is_empty() or main.storm_left > 0.0 or main.flare_left > 0.0
	if busy and main.sol_time < LATEST:
		return
	_put_out(today)
	today = null


func _put_out(item: Dictionary) -> void:
	var places := SPOTS.duplicate()
	places.shuffle()
	var spot: Vector2 = places[0]
	for p in places:
		if main._spot_free(p) and main.player.position.distance_to(p) > 500.0:
			spot = p
			break
	find = Find.new()
	find.position = spot
	main.world.add_child(find)
	find_item = item
	state[str(item["id"])] = "out"
	main.hud.show_banner("WHAT IS THAT?", "Something from an old space mission is lying out there! Follow the ? on your %s and pick it up before this sol ends." % main._map_word(), 10.0)


func pick_up() -> void:
	if find == null:
		return
	var item: Dictionary = find_item
	state[str(item["id"])] = "carried"
	find.queue_free()
	find = null
	find_item = {}
	Sfx.play("coin")
	main.hud.toast("You found something! Take it to %s to learn what it is." % _who(item))
	main._refresh_quests()
	_refresh_ui()


func _who(item: Dictionary) -> String:
	# "Engineer Mira" for a colonist with a name, "the Pilot" for one known by the job
	var npc = teachers[str(item["id"])]
	if npc.role == "explorer":
		return "the " + str(npc.npc_name)
	return str(npc.npc_name)


func _carried() -> Array:
	var list := []
	for item in items:
		if state[str(item["id"])] == "carried":
			list.append(item)
	return list


func wants(npc) -> bool:
	for item in _carried():
		if teachers[str(item["id"])] == npc:
			return true
	return false


func mark_alerts() -> void:
	for item in _carried():
		teachers[str(item["id"])].set_alert(true)


func talk(npc) -> bool:
	# the colonist explains the thing the player brought; true if there was something to explain
	var said := false
	for item in _carried():
		if teachers[str(item["id"])] != npc:
			continue
		said = true
		for line in _tr(item, "satirlar"):
			main._say(npc.npc_name, str(line))
		state[str(item["id"])] = "learned"
		main.after_dialog.append(_learned.bind(item))
	return said


func _learned(item: Dictionary) -> void:
	Sfx.play("success")
	var n: int = count()
	if n >= items.size():
		main.hud.show_banner("NOTEBOOK COMPLETE!", "You discovered all %d space tools. You are a real space explorer! Press N to read your Discovery Notebook." % items.size(), 12.0)
	else:
		main.hud.toast("New in your notebook: %s (%d of %d). Press N to read it." % [item_name(item), n, items.size()])
	main._refresh_quests()
	_refresh_ui()


func count() -> int:
	var n := 0
	for item in items:
		if state[str(item["id"])] == "learned":
			n += 1
	return n


func knows(id: String) -> bool:
	return str(state.get(id, "")) == "learned"


func tasks() -> Array:
	var t := []
	if find != null:
		t.append("Explore: find the ? on your %s" % main._map_word())
	for item in _carried():
		t.append("Explore: show your find to %s (!)" % _who(item))
	return t


func idle_lines() -> Array:
	return ["Hello, Operator! If you find something from an old space mission, bring it to the right expert. We love explaining!"]


# ---------------------------------------------------------------------
#  The Discovery Notebook
# ---------------------------------------------------------------------

func _style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func _label(parent: Control, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2, wrap: bool = false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = pos
	l.size = box
	l.text = text
	l.size = box
	return l


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 11
	add_child(layer)

	# bottom left: the notebook button, and the thing the player is carrying
	button = Button.new()
	button.position = Vector2(10, 676)
	button.size = Vector2(176, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(Color(0.07, 0.06, 0.1, 0.7), GOLD, 2, 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.17, 0.2, 0.36, 0.9), GOLD, 2, 8))
	button.add_theme_stylebox_override("pressed", _style(Color(0.17, 0.2, 0.36, 0.9), GOLD, 2, 8))
	button.pressed.connect(toggle_book)
	layer.add_child(button)

	carry_icon = TextureRect.new()
	carry_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	carry_icon.stretch_mode = TextureRect.STRETCH_SCALE
	carry_icon.position = Vector2(194, 662)
	carry_icon.size = Vector2(48, 48)
	carry_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(carry_icon)

	book = Panel.new()
	book.position = Vector2(150, 40)
	book.size = Vector2(980, 640)
	book.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.12, 0.97), GOLD, 3, 14))
	book.visible = false
	layer.add_child(book)
	book_title = _label(book, "", 30, GOLD, Vector2(0, 14), Vector2(980, 40))
	book_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(book, "N or ESC to close", 15, Color(0.75, 0.75, 0.75), Vector2(780, 24), Vector2(180, 22))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var cols := 3
	for i in items.size():
		var cell := Panel.new()
		cell.position = Vector2(26 + (i % cols) * 312, 66 + (i / cols) * 196)
		cell.size = Vector2(304, 188)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book.add_child(cell)
		var pic := TextureRect.new()
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.position = Vector2(12, 12)
		pic.size = Vector2(64, 64)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pic)
		var head := _label(cell, "", 19, GOLD, Vector2(86, 10), Vector2(208, 66), true)
		head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var body := _label(cell, "", 16, Color(1, 1, 1), Vector2(12, 82), Vector2(280, 98), true)
		var big := _label(cell, "?", 72, Color(0.5, 0.52, 0.62), Vector2(0, 18), Vector2(304, 100))
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var when := _label(cell, "", 16, Color(0.6, 0.62, 0.72), Vector2(0, 132), Vector2(304, 40))
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cells.append({"cell": cell, "pic": pic, "head": head, "body": body, "big": big, "when": when})

	# where the facts come from
	var rows: int = (items.size() + cols - 1) / cols
	var y: float = 66.0 + float(rows) * 196.0 + 4.0
	_label(book, "SOURCES: these facts come from real space missions", 15, GOLD, Vector2(26, y), Vector2(920, 20))
	var lines := PackedStringArray()
	for item in items:
		lines.append("%s: %s" % [item_name(item), str(item.get("kaynak", ""))])
	var src := _label(book, "\n".join(lines), 12, Color(0.82, 0.84, 0.9), Vector2(26, y + 22.0), Vector2(930, 130))
	src.add_theme_constant_override("line_spacing", 0)
	src.clip_text = true


func _refresh_ui() -> void:
	if button == null:
		return
	button.text = "NOTEBOOK (N)  %d/%d" % [count(), items.size()]
	book_title.text = "DISCOVERY NOTEBOOK   %d / %d" % [count(), items.size()]
	var held: Array = _carried()
	carry_icon.visible = not held.is_empty()
	if not held.is_empty():
		carry_icon.texture = _picture(held[0])
	for i in cells.size():
		var item: Dictionary = items[i]
		var c: Dictionary = cells[i]
		var st: String = state[str(item["id"])]
		var open: bool = st == "learned"
		c["pic"].visible = open
		c["head"].visible = open
		c["body"].visible = open
		c["big"].visible = not open
		c["when"].visible = not open
		if open:
			c["pic"].texture = _picture(item)
			c["head"].text = item_name(item)
			c["body"].text = str(_tr(item, "ozet"))
			c["cell"].add_theme_stylebox_override("panel", _style(Color(0.17, 0.2, 0.36), GOLD, 2, 12))
		else:
			if st == "missed":
				c["when"].text = "You missed this one on sol %d." % int(item.get("gun", 0))
			elif st == "carried":
				c["when"].text = "You have it! Show it to %s." % _who(item)
			else:
				c["when"].text = "Look for a ? on sol %d." % int(item.get("gun", 0))
			c["cell"].add_theme_stylebox_override("panel", _style(Color(0.12, 0.13, 0.22), Color(0.45, 0.47, 0.58), 2, 12))


func _can_open() -> bool:
	return not (main.game_over or main.cinematic or main.dialog_open or main.choice_open or main.touring)


func toggle_book() -> void:
	if not book_open and not _can_open():
		return
	book_open = not book_open
	book.visible = book_open
	Sfx.play("paper")
	_refresh_ui()


func hide_ui() -> void:
	# the ending film: no buttons on the screen
	book_open = false
	layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if book_open:
		if event.keycode == KEY_N or event.keycode == KEY_ESCAPE or event.is_action_pressed("interact"):
			toggle_book()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_N and _can_open():
		toggle_book()
		get_viewport().set_input_as_handled()
