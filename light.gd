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
}


static func get_set(name: String) -> Dictionary:
	return SETS.get(name, SETS["neutral"])
