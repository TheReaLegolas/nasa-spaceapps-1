extends Control
# End screen: did the colony survive, what happened, and what to try next time.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r: Dictionary = Game.result
	var won: bool = r.get("won", false)
	var reason: String = str(r.get("reason", ""))
	var stats: Dictionary = r.get("stats", {})

	var bg := ColorRect.new()
	if won:
		bg.color = Color(0.07, 0.13, 0.1)
	else:
		bg.color = Color(0.14, 0.07, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var headline: String = "THE COLONY SURVIVED!"
	var color := Color(0.55, 1.0, 0.6)
	if not won:
		headline = "MISSION OVER"
		color = Color(1.0, 0.6, 0.45)
	_label(headline, 58, color, Vector2(0, 30), Vector2(1280, 76))

	var summary: String = ""
	var sol_number: int = int(r.get("sols", 0)) + 1
	if won:
		summary = "You kept New Hope alive for all %d sols. Great work, Operator!" % Game.TOTAL_SOLS
	elif reason == "oxygen":
		summary = "The colony ran out of oxygen on sol %d. Everyone left in the rocket and is safe. You can try again!" % sol_number
	else:
		summary = "You got too hurt to keep working on sol %d. The doctor is looking after you. You can try again!" % sol_number
	_label(summary, 24, Color(1, 1, 1), Vector2(140, 112), Vector2(1000, 70))

	var lines := PackedStringArray()
	lines.append("Repairs made: %d      Panels wiped clean: %d      Spare parts used: %d" % [int(stats.get("repairs", 0)), int(stats.get("cleaned", 0)), int(stats.get("parts_used", 0))])
	lines.append("Ore collected from miners: %d      Parts built in the workshop: %d      Things you built: %d" % [int(stats.get("ore", 0)), int(stats.get("parts_built", 0)), int(stats.get("built", 0))])
	lines.append("The colony ended with %d solar panels and %d wind turbines." % [int(r.get("panels", 0)), int(r.get("turbines", 0))])
	lines.append("Health lost to cold nights: %d      to radiation: %d      to flying debris: %d" % [int(stats.get("cold", 0.0)), int(stats.get("radiation", 0.0)), int(stats.get("debris", 0.0))])
	lines.append("Lowest oxygen level: %d%%      Time with no power: %d seconds" % [int(stats.get("lowest_oxygen", 0.0)), int(stats.get("blackout", 0.0))])
	_label("\n".join(lines), 19, Color(0.9, 0.9, 0.9), Vector2(90, 190), Vector2(1100, 150))

	_label("WHAT IF...?", 24, Color(1.0, 0.85, 0.5), Vector2(140, 350), Vector2(1000, 34))
	_label(_what_if(won, reason, stats, r), 22, Color(1, 1, 1), Vector2(140, 384), Vector2(1000, 90))

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.position = Vector2(515, 492)
	again.size = Vector2(250, 60)
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(_on_again)
	add_child(again)

	_label("Every game has different storms and breakdowns. Try a new plan!", 18, Color(0.8, 0.8, 0.8), Vector2(0, 560), Vector2(1280, 28))
	_label(Game.credits_text(), 15, Color(0.65, 0.7, 0.75), Vector2(140, 600), Vector2(1000, 100))


func _what_if(won: bool, reason: String, stats: Dictionary, r: Dictionary) -> String:
	var cold: float = float(stats.get("cold", 0.0))
	var radiation: float = float(stats.get("radiation", 0.0))
	var debris: float = float(stats.get("debris", 0.0))
	var blackout: float = float(stats.get("blackout", 0.0))
	var built: int = int(stats.get("built", 0))

	if not won and reason == "oxygen":
		if blackout > 20.0:
			return "The battery ran empty, so the oxygen machine stopped. What if you had built more solar panels or a wind turbine, or switched the shield or heater off sooner?"
		return "What if you had kept the oxygen machine running more, and fixed air leaks as soon as someone told you about them?"
	if cold >= radiation and cold >= debris and cold > 5.0:
		return "Cold nights cost you the most health. What if you had built a wind turbine? It makes energy at night, when the heater needs it."
	if radiation >= cold and radiation >= debris and radiation > 5.0:
		return "Radiation cost you the most health. What if you had switched the shield on during solar flares, and turned something else off to pay for it?"
	if debris > 5.0:
		return "Flying debris hit you a lot. What if you had waited inside a rover until the dust storm had passed?"
	if blackout > 10.0:
		return "The colony lost power for a while. What if you had repaired and cleaned the solar panels first, or used the workshop less?"
	if built == 0:
		return "You never built anything new. What if you had spent some spare parts on extra solar panels or a wind turbine?"
	return "You hardly lost any health! Can you do it again while using fewer spare parts?"


func _label(text: String, font_size: int, color: Color, pos: Vector2, box: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)


func _on_again() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
