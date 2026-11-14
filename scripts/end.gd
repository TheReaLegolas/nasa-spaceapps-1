extends Control
# End screen: did the colony survive, what happened, and what to try next time.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r: Dictionary = Game.result
	var won: bool = r.get("won", false)
	var reason := str(r.get("reason", ""))
	var stats: Dictionary = r.get("stats", {})

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.13, 0.1) if won else Color(0.14, 0.07, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var headline := "THE COLONY SURVIVED!"
	var color := Color(0.55, 1.0, 0.6)
	if not won:
		headline = "MISSION OVER"
		color = Color(1.0, 0.6, 0.45)
	_label(headline, 58, color, Vector2(0, 36), Vector2(1280, 76))

	var summary := ""
	if won:
		summary = "You kept New Hope alive for all %d sols. Great work, Operator!" % Game.TOTAL_SOLS
	elif reason == "oxygen":
		summary = "The colony ran out of oxygen on sol %d. Everyone had to leave in the escape rocket. They are safe, and you can try again!" % (int(r.get("sols", 0)) + 1)
	else:
		summary = "You got too hurt to keep working on sol %d. The doctor is looking after you. You can try again!" % (int(r.get("sols", 0)) + 1)
	_label(summary, 24, Color(1, 1, 1), Vector2(140, 120), Vector2(1000, 70))

	var lines := PackedStringArray()
	lines.append("Repairs made: %d      Spare parts used: %d" % [int(stats.get("repairs", 0)), int(stats.get("parts_used", 0))])
	lines.append("Scrap piles collected: %d      Parts built in the workshop: %d" % [int(stats.get("scrap_collected", 0)), int(stats.get("parts_built", 0))])
	lines.append("Health lost to cold nights: %d      to radiation: %d      to flying scrap: %d" % [int(stats.get("cold", 0.0)), int(stats.get("radiation", 0.0)), int(stats.get("scrap", 0.0))])
	lines.append("Lowest oxygen level: %d%%      Time with no power: %d seconds" % [int(stats.get("lowest_oxygen", 0.0)), int(stats.get("blackout", 0.0))])
	_label("\n".join(lines), 20, Color(0.9, 0.9, 0.9), Vector2(140, 205), Vector2(1000, 130))

	_label("WHAT IF...?", 24, Color(1.0, 0.85, 0.5), Vector2(140, 345), Vector2(1000, 34))
	_label(_what_if(won, reason, stats), 22, Color(1, 1, 1), Vector2(140, 380), Vector2(1000, 90))

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.position = Vector2(515, 490)
	again.size = Vector2(250, 60)
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(_on_again)
	add_child(again)

	_label("Every game has different storms and breakdowns. Try a new plan!", 18, Color(0.8, 0.8, 0.8), Vector2(0, 558), Vector2(1280, 28))
	_label(Game.credits_text(), 15, Color(0.65, 0.7, 0.75), Vector2(140, 600), Vector2(1000, 100))


func _what_if(won: bool, reason: String, stats: Dictionary) -> String:
	var cold := float(stats.get("cold", 0.0))
	var radiation := float(stats.get("radiation", 0.0))
	var scrap := float(stats.get("scrap", 0.0))
	var blackout := float(stats.get("blackout", 0.0))

	if not won and reason == "oxygen":
		if blackout > 20.0:
			return "The battery ran empty, so the oxygen machine stopped. What if you had switched the shield or heater off sooner, to save energy for making air?"
		return "What if you had kept the oxygen machine running more, and repaired it or the dome as soon as they broke?"
	if cold >= radiation and cold >= scrap and cold > 5.0:
		return "Cold nights cost you the most health. What if you had filled the battery during the day, so the heater could run all night?"
	if radiation >= cold and radiation >= scrap and radiation > 5.0:
		return "Radiation cost you the most health. What if you had switched the shield on during solar flares, and turned something else off to pay for it?"
	if scrap > 5.0:
		return "Flying scrap hit you a lot. What if you had waited for the dust storm to pass before repairing the panels?"
	if blackout > 10.0:
		return "The colony lost power for a while. What if you had repaired the solar panels first, or used the workshop less?"
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
