extends RefCounted
## Light sets (design: "Robot Fighting · Art Study: Diagnostic Noir"). Every place lights the robots
## and people in it with one set; changing a place's mood means changing these values, never redrawing.
##   key:  the main light's colour (the light edge on every plate)
##   from: where the key light comes from, across the screen: -1 = from the left, +1 = from the right,
##         0 = straight above (the shadow then falls on the bottom of each plate)
##   rim:  a thin coloured edge on the side away from the key light (alpha 0 = none)
##   amb:  how much darker a shadow face is than the paint (0.3 = 70% bright; never past 0.55)
## Paint stays true: the lit face is always the paint itself.

const SETS := {
	# part icons, menus, anything with no place
	"neutral": {"key": Color(1.0, 0.96, 0.88), "from": -0.55, "rim": Color(0.62, 0.84, 1.0, 0.0), "amb": 0.3},
	# Gus's bay: the warm work lamp over the gantry, cold city light from the window
	"bay": {"key": Color(1.0, 0.8, 0.45), "from": -0.35, "rim": Color(0.37, 0.83, 1.0, 0.75), "amb": 0.34},
	# fights until each venue gets its own set (1.51 / 1.52): cold floodlights, a warm rim
	"fight": {"key": Color(0.9, 0.94, 1.0), "from": -0.35, "rim": Color(1.0, 0.6, 0.3, 0.55), "amb": 0.32},
	# the Scrap Heap ring (1.57): a low orange sun from the right over the junk piles, a cold work
	# light rim from the floodlight on the crane
	"scrap_ring": {"key": Color(1.0, 0.72, 0.42), "from": 0.55, "rim": Color(0.55, 0.78, 1.0, 0.6), "amb": 0.36},
	# (1.59) every venue lights its robots its own way
	"regional_hall": {"key": Color(0.95, 0.97, 1.0), "from": 0.0, "rim": Color(1.0, 0.75, 0.4, 0.45), "amb": 0.32},
	"regional_final": {"key": Color(1.0, 0.94, 0.82), "from": -0.3, "rim": Color(1.0, 0.38, 0.32, 0.6), "amb": 0.34},
	"champ_arena": {"key": Color(0.85, 0.92, 1.0), "from": 0.3, "rim": Color(0.35, 0.62, 1.0, 0.8), "amb": 0.35},
	"champ_gala": {"key": Color(1.0, 0.86, 0.6), "from": -0.2, "rim": Color(0.95, 0.28, 0.32, 0.6), "amb": 0.35},
	"fish_market": {"key": Color(1.0, 0.9, 0.65), "from": 0.0, "rim": Color(0.4, 0.82, 0.85, 0.55), "amb": 0.34},
	"docks": {"key": Color(1.0, 0.8, 0.5), "from": -0.5, "rim": Color(0.5, 0.7, 1.0, 0.65), "amb": 0.36},
	"cannery": {"key": Color(1.0, 0.82, 0.5), "from": 0.4, "rim": Color(1.0, 0.42, 0.3, 0.5), "amb": 0.35},
	"test_track": {"key": Color(1.0, 1.0, 1.0), "from": 0.0, "rim": Color(1.0, 0.85, 0.3, 0.4), "amb": 0.28},
	"harbor": {"key": Color(1.0, 0.72, 0.45), "from": 0.6, "rim": Color(0.68, 0.48, 1.0, 0.65), "amb": 0.34},
	"substation": {"key": Color(0.68, 0.92, 1.0), "from": -0.4, "rim": Color(0.3, 0.82, 1.0, 0.8), "amb": 0.4},
	"steelworks": {"key": Color(1.0, 0.62, 0.32), "from": 0.6, "rim": Color(1.0, 0.45, 0.15, 0.6), "amb": 0.38},
	"rooftop": {"key": Color(0.82, 0.88, 1.0), "from": 0.6, "rim": Color(1.0, 0.3, 0.3, 0.45), "amb": 0.4},
	"dry_dock": {"key": Color(0.95, 0.9, 0.8), "from": -0.5, "rim": Color(0.6, 0.76, 0.92, 0.5), "amb": 0.36},
	# (1.60) places outside Gus's building, for the people in them (the rooms get theirs in 1.61)
	"pub": {"key": Color(1.0, 0.76, 0.42), "from": -0.45, "rim": Color(1.0, 0.3, 0.45, 0.65), "amb": 0.36},
	"shop": {"key": Color(0.88, 0.94, 1.0), "from": 0.0, "rim": Color(0.35, 0.65, 1.0, 0.6), "amb": 0.32},
	"brass": {"key": Color(1.0, 0.78, 0.45), "from": -0.4, "rim": Color(0.5, 0.75, 0.9, 0.4), "amb": 0.36},   # (1.98) gaslight in the Brassworks shop
	"scrap": {"key": Color(1.0, 0.7, 0.42), "from": 0.6, "rim": Color(0.62, 0.48, 0.95, 0.55), "amb": 0.36},
	"phone": {"key": Color(0.72, 0.86, 1.0), "from": 0.25, "rim": Color(1.0, 0.75, 0.45, 0.45), "amb": 0.42},
	# (1.62) the opening: OVERLORD's red night, the cold empty room after the fall
	"overlord": {"key": Color(1.0, 0.4, 0.38), "from": 0.0, "rim": Color(1.0, 0.58, 0.3, 0.6), "amb": 0.42},
	"fall": {"key": Color(0.75, 0.82, 0.95), "from": -0.5, "rim": Color(0.5, 0.6, 0.8, 0.4), "amb": 0.42},
	# (1.64) the opening's outdoor shots: moonlight over the city, the stadium's floodlit front, dusk on the road
	"city": {"key": Color(0.78, 0.85, 1.0), "from": 0.6, "rim": Color(1.0, 0.6, 0.35, 0.5), "amb": 0.42},
	"stadium_ext": {"key": Color(1.0, 0.88, 0.65), "from": 0.0, "rim": Color(0.4, 0.6, 1.0, 0.5), "amb": 0.36},
	"road": {"key": Color(1.0, 0.75, 0.55), "from": 0.45, "rim": Color(0.55, 0.6, 1.0, 0.55), "amb": 0.4},
	"main_event": {"key": Color(1.0, 1.0, 1.0), "from": 0.0, "rim": Color(1.0, 0.25, 0.55, 0.75), "amb": 0.36},
}


static func get_set(name: String) -> Dictionary:
	return SETS.get(name, SETS["neutral"])
