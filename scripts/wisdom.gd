extends Node
# The Shop of Wisdom: here you pay with what you know.
#
# After an expert has explained a "?" find (scripts/learn.gd), Professor Quill at the
# Shop of Wisdom asks one question about it, with three answers to choose from.
# The expert never says the answer itself: the expert teaches the basic facts, and the
# player has to work the answer out from them. A right answer wins a prize (free).
#   first try right   -> the whole prize and two stars in the notebook
#   wrong             -> a hint, and one more try (the wrong answer is crossed out)
#   second try right  -> half the prize and one star
#   wrong again       -> Professor Quill explains the answer; no prize
#
# Everything about a question is in data/learn_items.json, next to the item it belongs to:
#   "soru"      the question                       "siklar"   the three answers
#   "dogru"     which answer is right (0, 1 or 2)  "ipucu"    the hint after a wrong answer
#   "aciklama"  why the right answer is right      "bilgi"    the line added to the notebook
#   "odul"      the prize: its name ("ad") and what it gives ("kazanc": energy, oxygen,
#               food, health or parts)
# An item without "soru" simply has no question.

const LearnScript = preload("res://scripts/learn.gd")

const KEEPER := "quill"                    # the id of Professor Quill in world_data.gd
const MAX_TRIES := 2
const SHOW_SECONDS := 1.1                  # how long the chosen answer stays green or red
const PURPLE := Color(0.46, 0.31, 0.77)
const PURPLE_DARK := Color(0.3, 0.19, 0.56)
const PAPER := Color(0.99, 0.96, 0.87)
const INK := Color(0.14, 0.14, 0.2)
const GOLD := Color(1.0, 0.85, 0.4)


# The sandy square in front of the shop and the path to the road, painted on the ground.
class Forecourt extends Node2D:
	var shop := Vector2.ZERO           # where the shop touches the ground
	var road_x := 3944.0               # the right edge of the road the path leads to

	func _draw() -> void:
		var court := Rect2(shop.x - 184.0, shop.y - 6.0, 322.0, 92.0)
		var path := Rect2(road_x - 4.0, shop.y + 22.0, court.position.x - road_x + 40.0, 40.0)
		# edges first, then the tops, so the path and the square join without a line
		for box in [path, court]:
			var edge := StyleBoxFlat.new()
			edge.bg_color = Color(0.8, 0.52, 0.36)
			edge.set_corner_radius_all(26)
			draw_style_box(edge, (box as Rect2).grow(6.0))
		for box in [path, court]:
			var top := StyleBoxFlat.new()
			top.bg_color = Color(0.92, 0.71, 0.53)
			top.set_corner_radius_all(22)
			draw_style_box(top, box as Rect2)


var main
var done := {}                 # item id -> stars won (2, 1 or 0) for questions that are finished
var tries := {}                # item id -> how many wrong answers so far
var crossed := {}              # item id -> the wrong answers that were already tried
var welcomed := false          # Professor Quill only explains the shop the first time

var quiz_open := false
var quiz_item: Dictionary = {}
var options: Array = []        # the three answers on the screen: {"text", "right", "tried"}
var sel := 0
var open_time := 0.0
var showing := -1.0            # seconds left of showing green or red; below 0 means: still choosing
var picked := -1

var layer: CanvasLayer
var root: Control
var title_sub: Label
var question: Label
var photo
var photo_pic: TextureRect
var photo_name: Label
var buttons: Array = []
var prize: Label
var bold: FontVariation


func setup(p_main) -> void:
	main = p_main
	_build_forecourt()
	_build_ui()


func _learn():
	return main.learn


func _id(item: Dictionary) -> String:
	return str(item["id"])


func _text(item: Dictionary, key: String) -> String:
	return str(_learn()._tr(item, key))


func _keeper():
	return main.npc_by_id.get(KEEPER)


# ---------------------------------------------------------------------
#  Which questions are waiting
# ---------------------------------------------------------------------

func has_question(item: Dictionary) -> bool:
	return item.has("soru") and item.has("siklar") and item.has("dogru")


func waiting() -> Array:
	# the items an expert has explained, whose question has not been finished yet
	var list := []
	if _learn() == null:
		return list
	for item in _learn().items:
		if has_question(item) and _learn().state[_id(item)] == "learned" and not done.has(_id(item)):
			list.append(item)
	return list


func stars(item: Dictionary) -> int:
	# 2 or 1 for a prize, 0 for "explained, no prize", -1 while the question is still open
	return int(done.get(_id(item), -1))


func prizes() -> int:
	var n := 0
	for id in done:
		if int(done[id]) > 0:
			n += 1
	return n


func total() -> int:
	var n := 0
	if _learn() != null:
		for item in _learn().items:
			if has_question(item):
				n += 1
	return n


func wants(npc) -> bool:
	return npc.npc_id == KEEPER and not waiting().is_empty()


func mark_alerts() -> void:
	var k = _keeper()
	if k != null and not waiting().is_empty():
		k.set_alert(true)


func tasks() -> Array:
	var t := []
	var k = _keeper()
	if k != null and not waiting().is_empty():
		t.append("Wisdom: answer %s's question (!)" % str(k.npc_name))
	return t


func idle_lines() -> Array:
	if not welcomed:
		return [
			"Welcome to the Shop of Wisdom! Here you do not pay with money. You pay with what you know.",
			"Find a ? on the map and let an expert explain it. Then come to me: I ask one question about it, and a right answer wins a prize.",
		]
	if total() > 0 and done.size() >= total():
		return ["You have answered every question I had. You are a real space expert now!"]
	return ["No new question right now. Find a ? on the map, let an expert explain it, and come back!"]


func on_learned(item: Dictionary) -> void:
	# an expert has just explained something: tell the player where the question is
	var k = _keeper()
	if k == null or not has_question(item):
		return
	main.hud.show_banner("A QUESTION AT THE SHOP OF WISDOM", "%s has a question about the %s. Think about what you just learned: a right answer wins a prize! Follow the ! on your %s." % [str(k.npc_name), _learn().item_name(item), main._map_word()], 11.0)


# ---------------------------------------------------------------------
#  Talking to Professor Quill
# ---------------------------------------------------------------------

func talk(npc) -> bool:
	# true if Professor Quill had a question to ask
	if npc.npc_id != KEEPER:
		return false
	var list: Array = waiting()
	if list.is_empty():
		return false
	var item: Dictionary = list[0]
	if not welcomed:
		welcomed = true
		main._say(npc.npc_name, "Welcome to the Shop of Wisdom! Here you do not pay with money. You pay with what you know.")
	if int(tries.get(_id(item), 0)) == 0:
		main._say(npc.npc_name, "I hear %s told you about the %s. I will not ask you to repeat it. I want to see what you can work out from it!" % [_learn()._who(item), _learn().item_name(item)])
	else:
		main._say(npc.npc_name, "Back for another try? Good! Thinking twice is what clever people do. Here is my question once more.")
	main.after_dialog.append(_open_quiz.bind(item))
	return true


func _gain(item: Dictionary, whole: bool) -> Dictionary:
	# what the prize gives; on the second try it is half (rounded up)
	var out := {}
	var odul: Dictionary = item.get("odul", {})
	var kazanc: Dictionary = odul.get("kazanc", {})
	for key in kazanc:
		var v: int = int(kazanc[key])
		if not whole:
			v = int(ceil(float(v) / 2.0))
		out[str(key)] = v
	return out


func _prize_name(item: Dictionary) -> String:
	var odul: Dictionary = item.get("odul", {})
	if odul.has("ad"):
		return str(_learn()._tr(odul, "ad"))
	return "a prize"


# ---------------------------------------------------------------------
#  The question on the screen
# ---------------------------------------------------------------------

func _open_quiz(item: Dictionary) -> void:
	quiz_item = item
	var id: String = _id(item)
	var texts: Array = _learn()._tr(item, "siklar")
	var right: int = int(item["dogru"])
	var gone: Array = crossed.get(id, [])
	options = []
	for i in texts.size():
		options.append({"text": str(texts[i]), "right": i == right, "tried": gone.has(str(texts[i]))})
	options.shuffle()                  # the right answer is in a different place every time
	sel = 0
	for i in options.size():
		if not options[i]["tried"]:
			sel = i
			break
	quiz_open = true
	open_time = 0.0
	showing = -1.0
	picked = -1
	Game.paused = true

	title_sub.text = "A question about the %s" % _learn().item_name(item)
	question.text = _text(item, "soru")
	photo_pic.texture = _learn()._picture(item)
	photo_name.text = _learn().item_name(item)
	var whole: bool = int(tries.get(id, 0)) == 0
	var line: String = "Prize for the right answer: %s  (%s)" % [_prize_name(item), main._effects_text(_gain(item, whole))]
	if not whole:
		line = "Second try, so the prize is smaller: %s  (%s)" % [_prize_name(item), main._effects_text(_gain(item, false))]
	prize.text = line
	_paint()
	root.visible = true
	Sfx.play("paper")


func _close() -> void:
	quiz_open = false
	root.visible = false


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 70
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _paint() -> void:
	# colours of the three answers: chosen, crossed out, right or wrong
	for i in buttons.size():
		var b: Button = buttons[i]["button"]
		var tag: Label = buttons[i]["tag"]
		if i >= options.size():
			b.visible = false
			continue
		var o: Dictionary = options[i]
		b.visible = true
		b.text = str(o["text"])
		var bg := Color(1, 1, 1)
		var border := Color(0.62, 0.58, 0.72)
		var width := 2
		var ink := INK
		var tag_bg := PURPLE
		if o["tried"]:
			b.text = str(o["text"]) + "   (not this one)"
			bg = Color(0.9, 0.88, 0.86)
			ink = Color(0.55, 0.53, 0.55)
			tag_bg = Color(0.62, 0.6, 0.64)
		elif showing >= 0.0 and i == picked:
			width = 5
			if o["right"]:
				bg = Color(0.74, 0.94, 0.74)
				border = Color(0.15, 0.55, 0.2)
				tag_bg = Color(0.15, 0.55, 0.2)
			else:
				bg = Color(0.99, 0.78, 0.74)
				border = Color(0.75, 0.18, 0.15)
				tag_bg = Color(0.75, 0.18, 0.15)
		elif showing < 0.0 and i == sel:
			bg = Color(1.0, 0.95, 0.72)
			border = Color(0.85, 0.6, 0.1)
			width = 5
		var sb: StyleBoxFlat = _box(bg, border, width)
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(state_name, sb)
		for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(colour_name, ink)
		var ts := StyleBoxFlat.new()
		ts.bg_color = tag_bg
		ts.set_corner_radius_all(20)
		tag.add_theme_stylebox_override("normal", ts)


func _move(step: int) -> void:
	if showing >= 0.0:
		return
	var n: int = options.size()
	var i: int = sel
	for k in n:
		i = (i + step + n) % n
		if not options[i]["tried"]:
			break
	if i != sel:
		sel = i
		Sfx.play("ui_move")
		_paint()


func _choose(i: int) -> void:
	if not quiz_open or showing >= 0.0 or i < 0 or i >= options.size():
		return
	if options[i]["tried"]:
		return
	sel = i
	picked = i
	showing = SHOW_SECONDS
	if options[i]["right"]:
		Sfx.play("success")
	else:
		Sfx.play("switch_off")
	_paint()


func _on_button(i: int) -> void:
	# a click that was meant for the talk before must not pick an answer by accident
	if open_time > 0.5:
		_choose(i)


func _on_hover(i: int) -> void:
	if quiz_open and showing < 0.0 and i < options.size() and not options[i]["tried"] and i != sel:
		sel = i
		_paint()


func _process(delta: float) -> void:
	if not quiz_open:
		return
	open_time += delta
	if showing >= 0.0:
		showing -= delta
		if showing < 0.0:
			_answered()


func _answered() -> void:
	# the green or red has been shown: now Professor Quill says what it means
	var item: Dictionary = quiz_item
	var id: String = _id(item)
	var o: Dictionary = options[picked]
	var k = _keeper()
	var who: String = "Professor Quill"
	if k != null:
		who = str(k.npc_name)
	_close()
	if o["right"]:
		var first: bool = int(tries.get(id, 0)) == 0
		if first:
			done[id] = 2
			main._say(who, "Correct! " + _text(item, "aciklama"))
			main._say(who, "Nobody told you that answer: you worked it out yourself. Here is your prize: %s!" % _prize_name(item))
		else:
			done[id] = 1
			main._say(who, "Yes, now you have it! " + _text(item, "aciklama"))
			main._say(who, "It was your second try, so the prize is a little smaller. Here you are: %s!" % _prize_name(item))
		main.after_dialog.append(_give.bind(item, _gain(item, first)))
	else:
		tries[id] = int(tries.get(id, 0)) + 1
		if not crossed.has(id):
			crossed[id] = []
		crossed[id].append(str(o["text"]))
		if int(tries[id]) >= MAX_TRIES:
			done[id] = 0
			var answer := ""
			for other in options:
				if other["right"]:
					answer = str(other["text"])
			main._say(who, "Good try! The answer was: \"%s\"." % answer)
			main._say(who, _text(item, "aciklama"))
			main._say(who, "No prize this time. But now you know it, and that is worth a lot. I wrote it in your notebook!")
			main.after_dialog.append(_note.bind(item))
		else:
			var expert: String = str(_learn()._who(item))
			main._say(who, _text(item, "ipucu").replace("{expert}", expert))
			main._say(who, "Take your time. Talk to me again when you are ready for one more try.")
	main._refresh_quests()


func _note(item: Dictionary) -> void:
	# the notebook has something new: the red arrow points at it
	_learn().unread = true
	_learn().fresh[_id(item)] = true
	_learn()._refresh_ui()
	main._refresh_quests()


func _give(item: Dictionary, gain: Dictionary) -> void:
	main._apply_effects(gain)
	Sfx.play("coin")
	main.hud.toast("Prize from the Shop of Wisdom: %s!   %s" % [_prize_name(item), main._effects_text(gain)])
	_note(item)


func _unhandled_input(event: InputEvent) -> void:
	if not quiz_open:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("move_down"):
		_move(1)
	elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
		_choose(0)
	elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
		_choose(1)
	elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
		_choose(2)
	elif event.is_action_pressed("interact") and open_time > 0.5:
		_choose(sel)
	# while the question is open, no key reaches the rest of the game
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------
#  Building what you see
# ---------------------------------------------------------------------

func _build_forecourt() -> void:
	var shop = main.by_id.get("wisdom")
	if shop == null:
		return
	var court := Forecourt.new()
	court.shop = shop.position
	court.z_index = -8             # on the ground: above the ground pictures, under everything else
	main.add_child(court)


func _label(parent: Node, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2, wrap: bool = false) -> Label:
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
	layer.layer = 12
	add_child(layer)
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7

	root = Control.new()
	root.size = Vector2(1280, 720)
	root.visible = false
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.62)
	dim.size = Vector2(1280, 720)
	root.add_child(dim)

	# a sheet of paper in a purple frame, like the sign of the shop
	var card := Panel.new()
	card.position = Vector2(150, 50)
	card.size = Vector2(980, 620)
	var cs := StyleBoxFlat.new()
	cs.bg_color = PAPER
	cs.border_color = PURPLE_DARK
	cs.set_border_width_all(6)
	cs.set_corner_radius_all(20)
	card.add_theme_stylebox_override("panel", cs)
	root.add_child(card)

	var band := Panel.new()
	band.position = Vector2(6, 6)
	band.size = Vector2(968, 84)
	var bs := StyleBoxFlat.new()
	bs.bg_color = PURPLE
	bs.corner_radius_top_left = 14
	bs.corner_radius_top_right = 14
	band.add_theme_stylebox_override("panel", bs)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	var book = LearnScript.BookIcon.new()
	book.position = Vector2(22, 12)
	book.size = Vector2(84, 60)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(book)
	var title := _label(band, "SHOP OF WISDOM", 34, Color(1, 1, 1), Vector2(124, 4), Vector2(700, 46))
	title.add_theme_font_override("font", bold)
	title_sub = _label(band, "", 19, GOLD, Vector2(126, 48), Vector2(820, 28))

	# left: Professor Quill and the thing the question is about
	var face := TextureRect.new()
	var cut := AtlasTexture.new()
	cut.atlas = load("res://assets/chars/sage.png")
	cut.region = Rect2(0, 5 * 48, 32, 48)          # standing still, looking at you
	face.texture = cut
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = Vector2(54, 96)
	face.size = Vector2(128, 192)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(face)
	var k = _keeper()
	var keeper_name := "Professor Quill"
	if k != null:
		keeper_name = str(k.npc_name)
	var who := _label(card, keeper_name, 17, PURPLE_DARK, Vector2(18, 290), Vector2(200, 24))
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_override("font", bold)

	photo = LearnScript.Photo.new()
	photo.found = true
	photo.size = Vector2(112, 112)
	photo.pivot_offset = photo.size / 2.0
	photo.position = Vector2(62, 346)
	photo.rotation = -0.05
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(photo)
	photo_pic = TextureRect.new()
	photo_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo_pic.stretch_mode = TextureRect.STRETCH_SCALE
	photo_pic.position = Vector2(8, 8)
	photo_pic.size = Vector2(96, 96)
	photo_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(photo_pic)
	photo_name = _label(card, "", 16, INK, Vector2(18, 470), Vector2(200, 48), true)
	photo_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# right: the question and the three answers
	question = _label(card, "", 25, INK, Vector2(246, 104), Vector2(706, 112), true)
	question.add_theme_font_override("font", bold)
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i in 3:
		var b := Button.new()
		b.position = Vector2(246, 228 + i * 84)
		b.size = Vector2(706, 72)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 21)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_on_button.bind(i))
		b.mouse_entered.connect(_on_hover.bind(i))
		card.add_child(b)
		var tag := _label(b, ["A", "B", "C"][i], 24, Color(1, 1, 1), Vector2(16, 16), Vector2(40, 40))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_override("font", bold)
		buttons.append({"button": b, "tag": tag})

	prize = _label(card, "", 18, PURPLE_DARK, Vector2(246, 486), Vector2(706, 52), true)
	prize.add_theme_font_override("font", bold)
	var how := _label(card, "Click an answer.     Keyboard: W / S or the arrow keys to choose, SPACE to answer (or press 1, 2, 3)", 15, Color(0.45, 0.43, 0.5), Vector2(20, 578), Vector2(940, 24))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
