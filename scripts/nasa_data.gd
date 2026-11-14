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
# MARS WEATHER - NOT YET REAL RECORDS.
# These are sample values inside the range the Curiosity rover measures in
# Gale Crater. Replace them with real rows from the Curiosity REMS feed
#   https://mars.nasa.gov/rss/api/?feed=weather&category=msl&feedtype=json
# (fields: sol, terrestrial_date, min_temp, max_temp) and then set
# WEATHER_VERIFIED to true. The end screen credit changes automatically.
# ---------------------------------------------------------------------------
const WEATHER_VERIFIED := false
const WEATHER := [
	{"sol": 0, "date": "", "min": -71, "max": -5},
	{"sol": 0, "date": "", "min": -73, "max": -8},
	{"sol": 0, "date": "", "min": -75, "max": -4},
	{"sol": 0, "date": "", "min": -70, "max": -10},
	{"sol": 0, "date": "", "min": -78, "max": -7},
	{"sol": 0, "date": "", "min": -72, "max": -3},
	{"sol": 0, "date": "", "min": -76, "max": -11},
	{"sol": 0, "date": "", "min": -74, "max": -6},
	{"sol": 0, "date": "", "min": -79, "max": -9},
	{"sol": 0, "date": "", "min": -69, "max": -2},
	{"sol": 0, "date": "", "min": -77, "max": -12},
	{"sol": 0, "date": "", "min": -72, "max": -6},
]
