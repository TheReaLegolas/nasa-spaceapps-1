extends RefCounted
# Real data embedded in the game, so it works offline in a browser.

# ---------------------------------------------------------------------------
# SOLAR FLARES - REAL records from NASA's DONKI space weather database
# (Space Weather Database Of Notifications, Knowledge, Information),
# https://kauai.ccmc.gsfc.nasa.gov/DONKI/
# "cls" is the flare class. X is the strongest kind, M is medium.
# ---------------------------------------------------------------------------
const FLARES := [
	{"date": "2026-01-18", "cls": "X1.9"},
	{"date": "2026-02-01", "cls": "X1.0"},
	{"date": "2026-02-01", "cls": "X8.1"},
	{"date": "2026-02-02", "cls": "X2.8"},
	{"date": "2026-02-02", "cls": "X1.6"},
	{"date": "2026-02-04", "cls": "X4.2"},
	{"date": "2026-03-30", "cls": "X1.4"},
	{"date": "2026-04-24", "cls": "X2.4"},
	{"date": "2026-04-24", "cls": "X2.5"},
	{"date": "2026-06-03", "cls": "M7.7"},
	{"date": "2026-07-04", "cls": "X1.3"},
	{"date": "2026-01-11", "cls": "M3.3"},
	{"date": "2026-02-25", "cls": "M2.3"},
]

# ---------------------------------------------------------------------------
# MARS WEATHER - REAL measurements from NASA's Curiosity rover in Gale Crater
# (REMS weather station), taken from the public feed
#   https://mars.nasa.gov/rss/api/?feed=weather&category=msl&feedtype=json
# "sol" is the rover's own day count, "date" the day on Earth,
# "min" and "max" the lowest and highest air temperature of that sol in Celsius.
# ---------------------------------------------------------------------------
const WEATHER_VERIFIED := true
const WEATHER := [
	{"sol": 4995, "date": "2026-08-25", "min": -71, "max": -5},
	{"sol": 4994, "date": "2026-08-24", "min": -70, "max": -7},
	{"sol": 4993, "date": "2026-08-23", "min": -70, "max": -6},
	{"sol": 4992, "date": "2026-08-22", "min": -69, "max": -6},
	{"sol": 4991, "date": "2026-08-21", "min": -69, "max": -11},
	{"sol": 4990, "date": "2026-08-20", "min": -72, "max": -8},
	{"sol": 4989, "date": "2026-08-19", "min": -72, "max": -6},
	{"sol": 4988, "date": "2026-08-18", "min": -70, "max": -10},
	{"sol": 4987, "date": "2026-08-17", "min": -70, "max": -9},
	{"sol": 4986, "date": "2026-08-16", "min": -71, "max": -9},
	{"sol": 4985, "date": "2026-08-15", "min": -70, "max": -6},
	{"sol": 4984, "date": "2026-08-14", "min": -71, "max": -6},
	{"sol": 4983, "date": "2026-08-13", "min": -70, "max": -4},
	{"sol": 4982, "date": "2026-08-12", "min": -69, "max": -6},
	{"sol": 4981, "date": "2026-08-11", "min": -69, "max": -8},
	{"sol": 4980, "date": "2026-08-09", "min": -78, "max": -7},
]

# The coldest nights Curiosity measured in the same Mars year (winter in Gale Crater).
# The game uses them for its "freezing nights", when the colony needs the heater.
const COLD_NIGHTS := [
	{"sol": 4852, "date": "2026-03-31", "min": -100, "max": 0},
	{"sol": 4844, "date": "2026-03-23", "min": -100, "max": -1},
	{"sol": 4792, "date": "2026-01-28", "min": -100, "max": 4},
	{"sol": 4781, "date": "2026-01-17", "min": -100, "max": 6},
]
