extends RefCounted
## Fight venues and crowds. Any arena can host any crowd: story fights use them in story
## order, cups and quick fights mix and match them at random.
##
## Each arena draws its own backdrop and floor and sets the ring colors.
## Each crowd has its own people (size, colors, hats, props) and its own way of cheering.

const I18n = preload("res://i18n.gd")
const ARENAS := {
	"fish_market": {"name": "The Fish Market Pit", "sky": ["#0d1a1f", "#16303a"], "floor": "#2a3a3e", "rope": "#c0392b", "post": "#7f8c8d", "light": "#ffe7a0"},
	"docks": {"name": "Dock 9 Arena", "sky": ["#05070f", "#141c33"], "floor": "#4a3a2a", "rope": "#f39c12", "post": "#34495e", "light": "#fff2c0"},
	"cannery": {"name": "The Cannery", "sky": ["#1c0f0c", "#3a1f18"], "floor": "#3b3b3b", "rope": "#bdc3c7", "post": "#8e5c3c", "light": "#ffd27a"},
	"test_track": {"name": "Kane Dynamics Test Track", "sky": ["#7d858f", "#aab1b9"], "floor": "#5a6068", "rope": "#e0b84a", "post": "#1a1a2e", "light": "#ffffff"},
	"harbor": {"name": "Harbor Lights Arena", "sky": ["#2b1640", "#e8734a"], "floor": "#5d4632", "rope": "#ecf0f1", "post": "#2c3e50", "light": "#ffd27a"},
	"substation": {"name": "The Substation", "sky": ["#05060a", "#0d1424"], "floor": "#22262e", "rope": "#00d2ff", "post": "#3a3f4a", "light": "#9fe8ff"},
	"steelworks": {"name": "Steelworks Dome", "sky": ["#1a0a05", "#4a1e0a"], "floor": "#262222", "rope": "#e67e22", "post": "#555555", "light": "#ffb060"},
	"rooftop": {"name": "Kane Tower Rooftop", "sky": ["#020309", "#14183a"], "floor": "#3a3d44", "rope": "#e0b84a", "post": "#1a1a2e", "light": "#e8f0ff"},
	"dry_dock": {"name": "The Old Dry Dock", "sky": ["#1b2024", "#3d464c"], "floor": "#4a443c", "rope": "#a04020", "post": "#6d5c4a", "light": "#f0e0c0"},
	"main_event": {"name": "Kane Arena: Main Event", "sky": ["#07040f", "#1a0c2e"], "floor": "#1c1c26", "rope": "#ff2e63", "post": "#e0b84a", "light": "#ffffff"},
	# career venues: the further you get, the richer the place
	"scrap_ring": {"name": "The Scrap Heap Ring", "sky": ["#2a1a12", "#6b4a2e"], "floor": "#4a3d30", "rope": "#8c8c8c", "post": "#6b3a1e", "light": "#ffcf7a", "ring": "junk"},
	"regional_hall": {"name": "Port Ferrum Sports Hall", "sky": ["#1d2430", "#34404f"], "floor": "#6a5a44", "rope": "#d63a3a", "post": "#2c3e50", "light": "#fff4d6"},
	"regional_final": {"name": "Port Ferrum Regional: Final", "sky": ["#141a2a", "#2d3550"], "floor": "#5a4a38", "rope": "#e0b84a", "post": "#1f2a44", "light": "#ffffff"},
	"champ_arena": {"name": "Titanium Championship Arena", "sky": ["#0a0d1a", "#1c2340"], "floor": "#20242e", "rope": "#3a7bd5", "post": "#c0c6d0", "light": "#e8f0ff"},
	"champ_gala": {"name": "The Kane Grand Hall", "sky": ["#1a0608", "#3d0f18"], "floor": "#2a1a14", "rope": "#b0182e", "post": "#e0c070", "light": "#fff0c8", "ring": "gold"},
}
const STORY_ARENAS := ["fish_market", "docks", "cannery", "test_track", "harbor", "substation", "steelworks", "rooftop", "dry_dock", "main_event"]

# count: how many people. sizes: body scale range. sat/val: color ranges. hat: what they wear.
# bounce: how wild they cheer. idle: how much they move when nothing happens.
const CROWDS := {
	"fishmongers": {"name": "Fishmongers", "count": 34, "sizes": [0.95, 1.1], "sat": [0.2, 0.4], "val": [0.3, 0.5], "hat": "sou'wester", "bounce": 0.8, "idle": 1.0},
	"dockers": {"name": "Dock Crews", "count": 52, "sizes": [1.0, 1.2], "sat": [0.3, 0.6], "val": [0.3, 0.5], "hat": "hardhat", "bounce": 1.0, "idle": 1.5},
	"punks": {"name": "Scrap Punks", "count": 60, "sizes": [0.9, 1.05], "sat": [0.7, 1.0], "val": [0.5, 0.85], "hat": "mohawk", "bounce": 1.6, "idle": 4.0},
	"suits": {"name": "Kane Executives", "count": 40, "sizes": [0.95, 1.05], "sat": [0.0, 0.1], "val": [0.15, 0.3], "hat": "suit", "bounce": 0.35, "idle": 0.4},
	"families": {"name": "Weekend Families", "count": 64, "sizes": [0.6, 1.1], "sat": [0.4, 0.7], "val": [0.5, 0.8], "hat": "balloon", "bounce": 1.1, "idle": 2.0},
	"robots": {"name": "Robot Spectators", "count": 48, "sizes": [0.85, 1.15], "sat": [0.05, 0.3], "val": [0.4, 0.7], "hat": "robot", "bounce": 0.7, "idle": 0.0},
	"ravers": {"name": "Ravers", "count": 70, "sizes": [0.9, 1.05], "sat": [0.8, 1.0], "val": [0.6, 1.0], "hat": "glowstick", "bounce": 1.8, "idle": 5.0},
	"bikers": {"name": "Bolt-Throwing Bikers", "count": 46, "sizes": [1.05, 1.25], "sat": [0.1, 0.3], "val": [0.15, 0.35], "hat": "helmet", "bounce": 1.3, "idle": 1.5},
	"fans": {"name": "Echo Fan Club", "count": 66, "sizes": [0.9, 1.1], "sat": [0.5, 0.8], "val": [0.45, 0.75], "hat": "sign", "bounce": 1.4, "idle": 2.5},
	"packed": {"name": "Sold-Out Crowd", "count": 110, "sizes": [0.8, 1.0], "sat": [0.2, 0.6], "val": [0.25, 0.6], "hat": "phone", "bounce": 1.2, "idle": 1.5},
	# career crowds
	"scrappers": {"name": "Scrapyard Workers", "count": 44, "sizes": [0.95, 1.15], "sat": [0.15, 0.35], "val": [0.3, 0.5], "hat": "overalls", "bounce": 1.3, "idle": 1.5, "piles": true},
	"locals": {"name": "Port Ferrum Locals", "count": 60, "sizes": [0.8, 1.1], "sat": [0.35, 0.65], "val": [0.45, 0.75], "hat": "casual", "bounce": 1.1, "idle": 1.8},
	"final_night": {"name": "Final-Night Crowd", "count": 74, "sizes": [0.9, 1.05], "sat": [0.25, 0.5], "val": [0.3, 0.55], "hat": "smart", "bounce": 1.0, "idle": 1.2},
	"champ_fans": {"name": "Championship Fans", "count": 92, "sizes": [0.85, 1.05], "sat": [0.5, 0.8], "val": [0.4, 0.7], "hat": "scarf", "bounce": 1.4, "idle": 2.0},
	"high_society": {"name": "High Society", "count": 56, "sizes": [0.95, 1.05], "sat": [0.0, 0.12], "val": [0.08, 0.2], "hat": "tophat", "bounce": 0.4, "idle": 0.5},
}
const STORY_CROWDS := ["fishmongers", "dockers", "punks", "suits", "families", "ravers", "bikers", "robots", "fans", "packed"]
const CAREER_ARENAS := ["scrap_ring", "regional_hall", "regional_final", "champ_arena", "champ_gala"]
const CAREER_CROWDS := ["scrappers", "locals", "final_night", "champ_fans", "high_society"]


## Where a league fight happens: scrap league in the junk ring, the Regional in the sports hall
## (dressed up for the final), the Championship in the big arena, and its semifinals and
## final in the Grand Hall in front of the money.
static func career_venue(stage: String, round_name: String) -> Array:
	if round_name.begins_with("LAST") or round_name.ends_with("SEMIFINAL"):
		# playoff nights get the big venue of the division
		match stage:
			"rust", "iron":
				return ["regional_final", "final_night"]
			"steel":
				return ["champ_gala", "high_society"]
	match stage:
		"open", "scrap":
			return ["scrap_ring", "scrappers"]
		"rust":
			return ["regional_hall", "locals"]
		"iron":
			return ["champ_arena", "champ_fans"]
		"steel":
			if round_name == "League round 24/24":
				return ["champ_gala", "high_society"]
			return ["champ_arena", "champ_fans"]
		"title":
			return ["champ_gala", "high_society"]
		"regional":
			if round_name == "FINAL" or round_name == "BRONZE MATCH":
				return ["regional_final", "final_night"]
			return ["regional_hall", "locals"]
		"championship":
			if round_name == "SEMIFINAL" or round_name == "FINAL" or round_name == "BRONZE MATCH" or round_name == "League round 24/24":
				return ["champ_gala", "high_society"]
			return ["champ_arena", "champ_fans"]
	return ["main_event", "packed"]


## Scrap piles the scrapyard crowd stands on (height above the row's floor at x).
## Font size that fits a (translated) sign text into its board.
static func fit(text: String, width: float, size: int) -> int:
	var s := size
	while s > 9 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width - 6.0:
		s -= 1
	return s


static func pile_bump(x: float, w: float, row: int) -> float:
	var h := 0.0
	var centers := [0.06, 0.27, 0.5, 0.72, 0.94]
	var tall := [46.0, 30.0, 18.0, 34.0, 50.0]
	for k in 5:
		var c: float = (centers[k] + row * 0.07) * w
		var d := (x - c) / (w * 0.11)
		h = maxf(h, tall[k] * (1.0 - row * 0.2) * exp(-d * d))
	return h


## [arena id, crowd id] for a fight. Story: in story order. Otherwise random (seeded so a cup stays the same).
static func pick(mode: String, index: int, seed_value: int) -> Array:
	if mode == "story" or mode == "exhibition":
		var k := clampi(index, 0, STORY_ARENAS.size() - 1)
		return [STORY_ARENAS[k], STORY_CROWDS[k]]
	var rng := RandomNumberGenerator.new()
	if mode == "circuit":
		rng.seed = seed_value * 31 + index * 7 + 3
	else:
		rng.randomize()
	return [ARENAS.keys()[rng.randi() % ARENAS.size()], CROWDS.keys()[rng.randi() % CROWDS.size()]]


static func make_crowd(id: String, screen: Vector2) -> Array:
	var c: Dictionary = CROWDS[id]
	var out: Array = []
	var n: int = c["count"]
	for k in n:
		var hue := randf()
		if c["hat"] == "sign":
			hue = 0.3
		out.append({"x": randf() * screen.x, "row": k % 3, "phase": randf() * TAU,
				"size": randf_range(c["sizes"][0], c["sizes"][1]),
				"color": Color.from_hsv(hue, randf_range(c["sat"][0], c["sat"][1]), randf_range(c["val"][0], c["val"][1])),
				"prop": Color.from_hsv(randf(), 0.8, 1.0)})
	out.sort_custom(func(a, b): return a["row"] < b["row"])
	return out


# ---------------------------------------------------------------- drawing

static func col(a: Dictionary, k: String) -> Color:
	return Color(a[k])


## Everything behind the crowd.
static func draw_backdrop(ci: CanvasItem, id: String, screen: Vector2, floor_y: float, t: float, off: Vector2) -> void:
	var a: Dictionary = ARENAS[id]
	var top := Color(a["sky"][0])
	var bot := Color(a["sky"][1])
	var bands := 8
	for k in bands:
		var y0 := floor_y * k / bands
		ci.draw_rect(Rect2(0, y0, screen.x, floor_y / bands + 1), top.lerp(bot, float(k) / (bands - 1)))
	var w := screen.x
	var o := off * 0.15
	match id:
		"fish_market":
			for k in 9:   # striped awnings
				var x := w * k / 8.0
				for s in 4:
					var cc := Color(0.75, 0.2, 0.2) if s % 2 == 0 else Color(0.9, 0.9, 0.85)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x + s * w / 32.0, 0), Vector2(x + (s + 1) * w / 32.0, 0), Vector2(x + (s + 0.5) * w / 32.0, 40)]) , cc.darkened(0.35))
			for k in 6:   # hanging lamps
				var x := w * (k + 0.5) / 6.0
				var sw := sin(t * 1.3 + k) * 6.0
				ci.draw_line(Vector2(x, 0) + o, Vector2(x + sw, 70) + o, Color(0.2, 0.2, 0.2), 2.0)
				ci.draw_circle(Vector2(x + sw, 76) + o, 9.0, Color(1.0, 0.9, 0.6))
				ci.draw_circle(Vector2(x + sw, 76) + o, 26.0, Color(1.0, 0.9, 0.6, 0.12))
			for side in [0.02, 0.86]:   # fish crates
				for k in 3:
					ci.draw_rect(Rect2(w * side + k * 30.0, floor_y - 200 + k * 10.0, 60, 40), Color(0.45, 0.33, 0.2))
		"docks":
			for k in 40:
				ci.draw_circle(Vector2(fmod(k * 137.0, w), fmod(k * 71.0, 120.0) + 6), 1.5, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 2.0 + k)))
			var cols := [Color(0.7, 0.25, 0.15), Color(0.15, 0.4, 0.6), Color(0.2, 0.5, 0.25), Color(0.8, 0.6, 0.15)]
			for k in 10:
				var x := k * w / 9.0 - 40.0
				var h := 60.0 + (k % 3) * 34.0
				var c: Color = cols[k % 4]
				ci.draw_rect(Rect2(x, floor_y - 160 - h, w / 9.0 - 6, h), c.darkened(0.45))
				for r in 6:
					ci.draw_line(Vector2(x + 8 + r * 14, floor_y - 160 - h + 6), Vector2(x + 8 + r * 14, floor_y - 166), c.darkened(0.6), 2.0)
			ci.draw_line(Vector2(w * 0.8, 150) + o, Vector2(w * 0.8, 0), Color(0.15, 0.15, 0.2), 10.0)   # crane
			ci.draw_line(Vector2(w * 0.55, 20) + o, Vector2(w * 0.95, 20) + o, Color(0.15, 0.15, 0.2), 8.0)
			ci.draw_circle(Vector2(w * 0.6, 20) + o, 5.0, Color(1, 0.2, 0.2, 0.5 + 0.5 * sin(t * 3.0)))
		"cannery":
			for row in 10:   # brick wall
				for k in 22:
					var bx := k * 70.0 - (35.0 if row % 2 == 1 else 0.0)
					ci.draw_rect(Rect2(bx, row * 22.0, 66, 19), Color(0.42, 0.2, 0.15).darkened(0.25 + 0.1 * ((k + row) % 3)))
			for k in 4:   # can pyramid
				for j in 4 - k:
					var cx := w * 0.12 + j * 34.0 + k * 17.0
					ci.draw_rect(Rect2(cx, floor_y - 210 - k * 38.0, 30, 36), Color(0.75, 0.75, 0.8))
					ci.draw_rect(Rect2(cx, floor_y - 200 - k * 38.0, 30, 14), Color(0.85, 0.3, 0.2))
			var belt_y := 70.0
			ci.draw_rect(Rect2(0, belt_y, w, 14), Color(0.15, 0.15, 0.15))
			for k in 30:
				ci.draw_rect(Rect2(fmod(k * 60.0 + t * 80.0, w + 60.0) - 60.0, belt_y - 22, 18, 22), Color(0.7, 0.7, 0.75))
		"test_track":
			for k in 24:   # hazard stripes
				var x := k * w / 20.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, 118), Vector2(x + 30, 118), Vector2(x + 10, 138), Vector2(x - 20, 138)]), Color(0.95, 0.75, 0.1))
			ci.draw_rect(Rect2(0, 116, w, 2), Color(0.1, 0.1, 0.1))
			ci.draw_rect(Rect2(0, 138, w, 2), Color(0.1, 0.1, 0.1))
			ci.draw_circle(Vector2(w * 0.5, 30) + o, 22.0, Color(0.1, 0.1, 0.18))
			ci.draw_arc(Vector2(w * 0.5, 30) + o, 22.0, 0, TAU, 32, Color(0.88, 0.72, 0.29), 3.0)
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 20, 40) + o, I18n.t("K"), HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color(0.88, 0.72, 0.29))
			for k in 4:
				var x := w * (0.1 + k * 0.27)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 0), Vector2(x + 10, 0), Vector2(x + 90, floor_y), Vector2(x - 90, floor_y)]), Color(1, 1, 1, 0.06))
		"harbor":
			ci.draw_circle(Vector2(w * 0.7, floor_y * 0.55), 50.0, Color(1.0, 0.75, 0.4, 0.8))   # sun
			ci.draw_rect(Rect2(0, floor_y * 0.55, w, floor_y * 0.45), Color(0.15, 0.2, 0.35))   # sea
			for k in 12:
				var y := floor_y * 0.58 + k * 9.0
				ci.draw_line(Vector2(fmod(k * 97.0 + t * 20.0, w), y), Vector2(fmod(k * 97.0 + t * 20.0, w) + 60, y), Color(1.0, 0.7, 0.4, 0.35), 2.0)
			ci.draw_rect(Rect2(w * 0.12, floor_y * 0.3, 20, floor_y * 0.27), Color(0.9, 0.9, 0.9))   # lighthouse
			ci.draw_rect(Rect2(w * 0.12, floor_y * 0.38, 20, 10), Color(0.8, 0.2, 0.2))
			var beam := sin(t * 0.8)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12 + 10, floor_y * 0.3), Vector2(w * 0.12 + 10 + beam * 400, floor_y * 0.24), Vector2(w * 0.12 + 10 + beam * 400, floor_y * 0.36)]), Color(1, 1, 0.8, 0.15))
			for k in 30:   # string lights
				var x := w * k / 29.0
				var y := 20.0 + sin(float(k) / 29.0 * PI * 3.0) * 12.0
				ci.draw_circle(Vector2(x, y) + o, 4.0, Color.from_hsv(fmod(k * 0.17, 1.0), 0.6, 1.0, 0.6 + 0.4 * sin(t * 4.0 + k)))
		"substation":
			for k in 3:   # pylons
				var x := w * (0.15 + k * 0.35)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 40, floor_y - 150), Vector2(x - 6, 10), Vector2(x + 6, 10), Vector2(x + 40, floor_y - 150)]), Color(0.12, 0.13, 0.16))
				ci.draw_line(Vector2(x - 50, 40), Vector2(x + 50, 40), Color(0.12, 0.13, 0.16), 6.0)
			for k in 2:
				ci.draw_line(Vector2(0, 38 + k * 6), Vector2(w, 46 + k * 6), Color(0.05, 0.05, 0.06), 2.0)
			for k in 4:   # transformers
				ci.draw_rect(Rect2(w * (0.05 + k * 0.25), floor_y - 230, 70, 60), Color(0.25, 0.28, 0.25))
				for f in 5:
					ci.draw_line(Vector2(w * (0.05 + k * 0.25) + 8 + f * 12, floor_y - 226), Vector2(w * (0.05 + k * 0.25) + 8 + f * 12, floor_y - 174), Color(0.18, 0.2, 0.18), 3.0)
			if fmod(t, 2.3) < 0.15:   # arcing spark
				var x := w * (0.15 + (int(t) % 3) * 0.35)
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(Vector2(x - 40 + k * 14 + randf_range(-6, 6), 40 + randf_range(-10, 10)))
				ci.draw_polyline(pts, Color(0.7, 0.95, 1.0), 3.0)
				ci.draw_circle(Vector2(x, 40), 40.0, Color(0.5, 0.9, 1.0, 0.15))
		"steelworks":
			ci.draw_arc(Vector2(w * 0.5, floor_y + 200), w * 0.7, PI, TAU, 40, Color(0.25, 0.12, 0.06), 20.0)   # dome ribs
			for k in 7:
				var a0 := PI + PI * (k + 1) / 8.0
				ci.draw_line(Vector2(w * 0.5, floor_y + 200), Vector2(w * 0.5, floor_y + 200) + Vector2(cos(a0), sin(a0)) * w * 0.7, Color(0.22, 0.1, 0.05), 6.0)
			for side in [0.05, 0.82]:   # molten vats
				ci.draw_rect(Rect2(w * side, floor_y - 250, 110, 70), Color(0.2, 0.2, 0.2))
				ci.draw_rect(Rect2(w * side + 6, floor_y - 250, 98, 12), Color(1.0, 0.5 + 0.2 * sin(t * 6.0), 0.1))
				ci.draw_circle(Vector2(w * side + 55, floor_y - 260), 60.0, Color(1.0, 0.5, 0.1, 0.12))
			for k in 12:   # falling sparks
				var x := fmod(k * 113.0, w)
				var y := fmod(t * 180.0 + k * 53.0, floor_y)
				ci.draw_circle(Vector2(x, y), 2.0, Color(1.0, 0.7, 0.2, 0.8))
		"rooftop":
			ci.draw_circle(Vector2(w * 0.82, 50), 26.0, Color(0.95, 0.95, 0.85))   # moon
			ci.draw_circle(Vector2(w * 0.82 + 10, 44), 24.0, Color(0.02, 0.03, 0.09).lerp(Color(0.08, 0.09, 0.22), 0.3))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var x := 0.0
			while x < w:   # skyline
				var bw := rng.randf_range(50, 110)
				var bh := rng.randf_range(80, 230)
				ci.draw_rect(Rect2(x, floor_y - 150 - bh, bw - 4, bh), Color(0.06, 0.07, 0.14))
				for wy in int(bh / 18.0):
					for wx in int(bw / 16.0):
						if rng.randf() < 0.3:
							ci.draw_rect(Rect2(x + 4 + wx * 16, floor_y - 145 - bh + wy * 18, 7, 9), Color(1.0, 0.85, 0.5, 0.6))
				x += bw
			ci.draw_circle(Vector2(w * 0.1, 30), 4.0, Color(1, 0.1, 0.1, 0.5 + 0.5 * sin(t * 3.0)))
		"dry_dock":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.45, floor_y - 160), Vector2(w * 0.5, 10), Vector2(w * 1.05, 10), Vector2(w * 1.05, floor_y - 160)]), Color(0.35, 0.18, 0.1))   # ship hull
			for k in 8:
				ci.draw_line(Vector2(w * 0.5 + k * 70, 20), Vector2(w * 0.47 + k * 70, floor_y - 170), Color(0.28, 0.14, 0.08), 3.0)
			for k in 12:
				ci.draw_circle(Vector2(w * 0.55 + k * 45, 60), 5.0, Color(0.2, 0.1, 0.06))   # rivets
			ci.draw_line(Vector2(w * 0.18, floor_y - 150) + o, Vector2(w * 0.18, 0), Color(0.45, 0.35, 0.15), 12.0)   # the old crane
			ci.draw_line(Vector2(w * 0.05, 30) + o, Vector2(w * 0.4, 30) + o, Color(0.45, 0.35, 0.15), 9.0)
			ci.draw_line(Vector2(w * 0.32, 30) + o, Vector2(w * 0.32, 100 + sin(t) * 6.0) + o, Color(0.2, 0.2, 0.2), 2.0)
			for k in 3:   # fog
				ci.draw_rect(Rect2(0, floor_y - 260 + k * 40, w, 30), Color(0.8, 0.85, 0.9, 0.04))
		"scrap_ring":
			ci.draw_circle(Vector2(w * 0.78, floor_y * 0.32), 40.0, Color(1.0, 0.6, 0.3, 0.55))   # hazy sun
			for k in 7:   # far piles of dead robots
				var cx := w * (k / 6.0) + sin(k * 2.3) * 40.0
				var hw := 140.0 + (k % 3) * 50.0
				var ph := 120.0 + (k % 4) * 35.0
				var base := floor_y - 140.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - hw, base), Vector2(cx - hw * 0.4, base - ph * 0.8),
						Vector2(cx - hw * 0.1, base - ph), Vector2(cx + hw * 0.3, base - ph * 0.85), Vector2(cx + hw, base)]), Color(0.17, 0.12, 0.1))
				ci.draw_line(Vector2(cx - hw * 0.2, base - ph * 0.9), Vector2(cx - hw * 0.35, base - ph * 1.25), Color(0.2, 0.15, 0.12), 9.0)   # an arm sticking out
				ci.draw_circle(Vector2(cx + hw * 0.15, base - ph * 0.92), 14.0, Color(0.21, 0.16, 0.13))   # a dead head
				ci.draw_rect(Rect2(cx + hw * 0.08, base - ph * 0.94, 14, 3), Color(0.35, 0.1, 0.05))
			# the crane with its magnet and a wreck hanging off it
			ci.draw_line(Vector2(w * 0.12, floor_y - 160) + o, Vector2(w * 0.12, 10) + o, Color(0.55, 0.42, 0.12), 10.0)
			ci.draw_line(Vector2(w * 0.04, 18) + o, Vector2(w * 0.42, 18) + o, Color(0.55, 0.42, 0.12), 8.0)
			var sw := sin(t * 0.7) * 8.0
			ci.draw_line(Vector2(w * 0.36, 18) + o, Vector2(w * 0.36 + sw, 70) + o, Color(0.15, 0.15, 0.15), 2.0)
			ci.draw_rect(Rect2(Vector2(w * 0.36 + sw - 22, 70) + o, Vector2(44, 10)), Color(0.3, 0.3, 0.32))
			ci.draw_rect(Rect2(Vector2(w * 0.36 + sw - 16, 80) + o, Vector2(32, 26)), Color(0.4, 0.28, 0.2))
			ci.draw_line(Vector2(w * 0.36 + sw - 10, 106) + o, Vector2(w * 0.36 + sw - 16, 128) + o, Color(0.35, 0.25, 0.18), 6.0)
			# a string of bare bulbs between two poles
			for k in 18:
				var x := w * (0.45 + k * 0.03)
				var y := 26.0 + sin(float(k) / 17.0 * PI) * 22.0
				ci.draw_circle(Vector2(x, y) + o, 3.5, Color(1.0, 0.85, 0.5, 0.55 + 0.45 * sin(t * 2.0 + k * 1.7)))
			ci.draw_rect(Rect2(w * 0.62, 104, 150, 34), Color(0.35, 0.36, 0.33))   # hand-painted sign on tin
			for k in 6:
				ci.draw_line(Vector2(w * 0.62 + k * 25, 104), Vector2(w * 0.62 + k * 25, 138), Color(0.28, 0.29, 0.27), 2.0)
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.62, 128), I18n.t("SCRAP RING"), HORIZONTAL_ALIGNMENT_CENTER, 150, fit(I18n.t("SCRAP RING"), 150, 20), Color(0.85, 0.25, 0.15))
		"regional_hall", "regional_final":
			var fin := id == "regional_final"
			ci.draw_rect(Rect2(0, 0, w, floor_y * 0.12), Color(0.12, 0.14, 0.18))
			for k in 8:   # high windows and roof beams
				var x := w * (k + 0.5) / 8.0
				ci.draw_rect(Rect2(x - 34, 26, 68, 40), Color(0.35, 0.45, 0.6, 0.35 if not fin else 0.15))
				ci.draw_line(Vector2(x - 34, 46), Vector2(x + 34, 46), Color(0.12, 0.14, 0.18), 3.0)
				ci.draw_line(Vector2(x, 26), Vector2(x, 66), Color(0.12, 0.14, 0.18), 3.0)
			ci.draw_rect(Rect2(w * 0.3, 118, w * 0.4, 28), Color(0.12, 0.25, 0.55) if not fin else Color(0.55, 0.1, 0.12))
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.3, 139), I18n.t("PORT FERRUM REGIONAL") if not fin else I18n.t("REGIONAL FINAL"), HORIZONTAL_ALIGNMENT_CENTER, w * 0.4, fit(I18n.t("PORT FERRUM REGIONAL") if not fin else I18n.t("REGIONAL FINAL"), w * 0.4, 20), Color(1, 1, 1) if not fin else Color(1.0, 0.85, 0.4))
			ci.draw_rect(Rect2(w * 0.05, 114, 90, 34), Color(0.05, 0.05, 0.05))   # the hall's scoreboard clock
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.05, 139), "%02d:%02d" % [int(t / 60.0) % 60, int(t) % 60], HORIZONTAL_ALIGNMENT_CENTER, 90, 22, Color(1.0, 0.3, 0.2))
			if fin:
				for k in 26:   # bunting
					var x := w * k / 25.0
					var y := 14.0 + sin(float(k) / 25.0 * PI * 2.0) * 6.0
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + w / 25.0, y), Vector2(x + w / 50.0, y + 16)]), [Color(0.85, 0.2, 0.2), Color(1, 1, 1), Color(0.2, 0.4, 0.85)][k % 3])
				for k in 2:   # spotlights
					var bx := w * (0.2 + k * 0.6)
					var sway := sin(t * 0.7 + k * 2.0) * 120.0
					ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 6, 0), Vector2(bx + 6, 0), Vector2(bx + sway + 60, floor_y), Vector2(bx + sway - 60, floor_y)]), Color(1, 1, 0.9, 0.07))
				ci.draw_rect(Rect2(w * 0.86, 76, 40, 6), Color(0.3, 0.2, 0.1))   # the trophy on its stand
				ci.draw_rect(Rect2(w * 0.86 + 14, 50, 12, 26), Color(0.9, 0.75, 0.3))
				ci.draw_circle(Vector2(w * 0.86 + 20, 48), 12.0, Color(0.95, 0.8, 0.35))
				ci.draw_circle(Vector2(w * 0.86 + 20, 50), 26.0, Color(1.0, 0.9, 0.5, 0.12 + 0.05 * sin(t * 3.0)))
		"champ_arena":
			for k in 3:   # lighting truss
				ci.draw_line(Vector2(0, 12 + k * 8), Vector2(w, 12 + k * 8), Color(0.3, 0.32, 0.38), 2.0)
			for k in 16:
				var x := w * (k + 0.5) / 16.0
				ci.draw_line(Vector2(x - 8, 12), Vector2(x + 8, 28), Color(0.3, 0.32, 0.38), 2.0)
				ci.draw_circle(Vector2(x, 34), 5.0, Color.from_hsv(fmod(k * 0.13 + t * 0.1, 1.0), 0.5, 1.0, 0.8))
			for side in [0.04, 0.72]:   # big screens
				var sc := Rect2(w * side, 104, w * 0.2, 40)
				ci.draw_rect(sc.grow(4), Color(0.08, 0.08, 0.1))
				ci.draw_rect(sc, Color(0.05, 0.1, 0.25))
				ci.draw_string(ThemeDB.fallback_font, sc.position + Vector2(0, 27), I18n.t("TITANIUM CHAMPIONSHIP"), HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, fit(I18n.t("TITANIUM CHAMPIONSHIP"), sc.size.x, 20), Color(0.4, 0.75, 1.0))
			# LED ribbon board scrolling round the arena
			ci.draw_rect(Rect2(0, 148, w, 18), Color(0.02, 0.02, 0.05))
			var msg := "  KANE DYNAMICS  *  CHAMPIONSHIP SEASON  *  PORT FERRUM  *"
			var mx := fmod(-t * 90.0, 520.0)
			while mx < w:
				ci.draw_string(ThemeDB.fallback_font, Vector2(mx, 163), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.25))
				mx += 520.0
			for k in 3:
				var bx := w * (0.2 + k * 0.3)
				var sway := sin(t * 0.8 + k * 1.9) * 160.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 6, 0), Vector2(bx + 6, 0), Vector2(bx + sway + 60, floor_y), Vector2(bx + sway - 60, floor_y)]), Color(0.6, 0.8, 1.0, 0.06))
		"champ_gala":
			for k in 14:   # velvet curtain folds
				var x := w * k / 14.0
				ci.draw_rect(Rect2(x, 0, w / 28.0, floor_y), Color(0.42, 0.06, 0.1))
			ci.draw_rect(Rect2(0, 0, w, 20), Color(0.55, 0.42, 0.15))   # gold pelmet
			for k in 20:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(w * k / 20.0, 20), Vector2(w * (k + 1) / 20.0, 20), Vector2(w * (k + 0.5) / 20.0, 34)]), Color(0.75, 0.6, 0.22))
			for side in [0.08, 0.92]:   # marble columns
				ci.draw_rect(Rect2(w * side - 18, 34, 36, floor_y - 34), Color(0.82, 0.8, 0.76))
				ci.draw_rect(Rect2(w * side - 24, 34, 48, 10), Color(0.75, 0.6, 0.25))
				for k in 3:
					ci.draw_line(Vector2(w * side - 10 + k * 10, 46), Vector2(w * side - 10 + k * 10, floor_y), Color(0.7, 0.68, 0.64), 2.0)
			for k in 3:   # chandeliers
				var cx := w * (0.25 + k * 0.25)
				ci.draw_line(Vector2(cx, 34), Vector2(cx, 56), Color(0.75, 0.6, 0.22), 2.0)
				ci.draw_arc(Vector2(cx, 56), 30.0, 0.0, PI, 12, Color(0.85, 0.7, 0.3), 3.0)
				ci.draw_circle(Vector2(cx, 70), 40.0, Color(1.0, 0.9, 0.6, 0.1))
				for j in 7:
					var ang := PI * j / 6.0
					var p := Vector2(cx, 56) + Vector2(cos(ang), sin(ang)) * 30.0
					ci.draw_circle(p, 3.0, Color(1.0, 0.95, 0.75, 0.6 + 0.4 * sin(t * 4.0 + j + k * 3)))
			ci.draw_rect(Rect2(w * 0.32, 118, w * 0.36, 28), Color(0.12, 0.04, 0.06))   # gold-lettered banner
			ci.draw_rect(Rect2(w * 0.32, 118, w * 0.36, 28), Color(0.85, 0.7, 0.3), false, 2.0)
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.32, 138), I18n.t("THE TITANIUM CHAMPIONSHIP"), HORIZONTAL_ALIGNMENT_CENTER, w * 0.36, fit(I18n.t("THE TITANIUM CHAMPIONSHIP"), w * 0.36, 18), Color(0.95, 0.8, 0.4))
		"main_event":
			var sc := Rect2(w * 0.38, 96, w * 0.24, 46)   # jumbotron
			ci.draw_rect(sc.grow(5), Color(0.1, 0.1, 0.12))
			ci.draw_rect(sc, Color(0.05, 0.08, 0.2))
			ci.draw_string(ThemeDB.fallback_font, sc.position + Vector2(0, 33), I18n.t("MAIN EVENT"), HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, fit(I18n.t("MAIN EVENT"), sc.size.x, 24), Color.from_hsv(fmod(t * 0.2, 1.0), 0.6, 1.0))
			for k in 4:   # sweeping spotlights
				var bx := w * (0.1 + k * 0.27)
				var sway := sin(t * 0.9 + k * 1.7) * 220.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, 0), Vector2(bx + 8, 0), Vector2(bx + sway + 70, floor_y), Vector2(bx + sway - 70, floor_y)]), Color.from_hsv(k * 0.25, 0.4, 1.0, 0.08))
			for side in [0.04, 0.96]:   # pyro
				var fh := 40.0 + sin(t * 9.0 + side * 10.0) * 14.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(w * side - 14, floor_y - 200), Vector2(w * side, floor_y - 200 - fh), Vector2(w * side + 14, floor_y - 200)]), Color(1.0, 0.55, 0.1, 0.8))


## The crowd itself.
static func draw_crowd(ci: CanvasItem, crowd: Array, id: String, screen: Vector2, t: float, cheer: float, off: Vector2) -> void:
	var c: Dictionary = CROWDS[id]
	var top := screen.y * 0.24
	var hat: String = c["hat"]
	var bounce: float = c["bounce"]
	var idle: float = c["idle"]
	var piles: bool = c.get("piles", false)
	var cur_row := -1
	for p in crowd:
		var row: int = p["row"]
		if piles and row != cur_row:
			if cur_row >= 0:
				draw_pile_row(ci, cur_row, top, screen.x, off)
			cur_row = row
		var s: float = p["size"]
		var y: float = top + row * 34.0 + 20.0 + (1.0 - s) * 30.0
		if piles:
			y -= pile_bump(p["x"], screen.x, row)
		var b := 0.0
		if cheer > 0.0:
			b = -absf(sin(t * 9.0 * (0.8 + bounce * 0.2) + p["phase"])) * 10.0 * bounce * minf(1.0, cheer)
		else:
			b = sin(t * 1.5 + p["phase"]) * idle
		var colr: Color = (p["color"] as Color).darkened(0.25 * (2 - row))
		var pos := Vector2(p["x"], y + b) + off * 0.3
		var hr := 10.0 * s
		if hat == "robot":
			ci.draw_rect(Rect2(pos.x - 13 * s, pos.y + 6 * s, 26 * s, 40 * s), colr.darkened(0.2))
			ci.draw_rect(Rect2(pos.x - hr, pos.y - hr, hr * 2, hr * 1.8), colr)
			ci.draw_rect(Rect2(pos.x - hr * 0.6, pos.y - hr * 0.3, hr * 1.2, 4), Color(0.3, 1.0, 0.5) if int(p["phase"] * 3) % 2 == 0 else Color(1.0, 0.4, 0.2))
			ci.draw_line(pos + Vector2(0, -hr), pos + Vector2(0, -hr - 8), colr, 2.0)
			ci.draw_circle(pos + Vector2(0, -hr - 9), 2.5, Color(1, 0.3, 0.3, 0.5 + 0.5 * sin(t * 5.0 + p["phase"])))
			continue
		var dim := 1.0 - 0.25 * (2 - row)
		var dc := Color(dim, dim, dim)
		var pick := int(p["phase"] * 10.0) % 5   # which variant this person wears
		var body := Rect2(pos.x - 13 * s, pos.y + 6 * s, 26 * s, 40 * s)
		ci.draw_rect(body, colr.darkened(0.2))
		var skin := colr.lerp(Color(0.85, 0.7, 0.55), 0.35)
		if hat in ["suit", "tophat", "smart", "overalls", "casual", "scarf"]:
			skin = [Color(0.93, 0.78, 0.65), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26), Color(0.88, 0.7, 0.55), Color(0.4, 0.27, 0.18)][int(p["phase"] * 7.0) % 5] * dc
		ci.draw_circle(pos, hr, skin)
		var pc: Color = (p["prop"] as Color) * dc
		var arm_up := cheer > 0.5 and int(p["phase"] * 10) % 3 == 0
		match hat:
			"sou'wester":
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-hr * 1.4, -hr * 0.3), pos + Vector2(0, -hr * 1.3), pos + Vector2(hr * 1.4, -hr * 0.3)]), Color(0.9, 0.75, 0.1) * dc)
			"hardhat":
				ci.draw_arc(pos + Vector2(0, -hr * 0.2), hr, PI, TAU, 10, Color(1.0, 0.6, 0.1) * dc, hr * 0.8)
			"mohawk":
				for k in 4:
					ci.draw_line(pos + Vector2(-4 + k * 3, -hr * 0.8), pos + Vector2(-4 + k * 3, -hr * 1.8), pc, 2.5)
			"suit":
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-4, hr), pos + Vector2(4, hr), pos + Vector2(0, hr + 14)]), Color(0.9, 0.9, 0.9) * dc)
			"balloon":
				if int(p["phase"] * 7) % 4 == 0:
					var bp := pos + Vector2(14, -50 + sin(t * 2.0 + p["phase"]) * 4)
					ci.draw_line(pos + Vector2(10, 8), bp, Color(0.8, 0.8, 0.8, 0.6), 1.0)
					ci.draw_circle(bp, 9.0, pc)
			"glowstick":
				var glow := Color.from_hsv(fmod(p["phase"] + t * 0.5, 1.0), 0.9, 1.0, 0.9)
				var a0: float = sin(t * 6.0 + p["phase"]) * 0.8
				ci.draw_line(pos + Vector2(12, 4), pos + Vector2(12, 4) + Vector2(sin(a0), -cos(a0)) * 22.0, glow, 4.0)
			"helmet":
				ci.draw_circle(pos, hr * 1.15, Color(0.12, 0.12, 0.14) * dc)
				ci.draw_rect(Rect2(pos.x - hr * 0.2, pos.y - hr * 0.3, hr * 1.2, hr * 0.5), Color(0.5, 0.7, 0.9, 0.6))
			"sign":
				if int(p["phase"] * 7) % 3 == 0:
					var sp := pos + Vector2(-16, -46 + (b * 0.5))
					ci.draw_line(pos + Vector2(0, 6), sp + Vector2(16, 20), Color(0.5, 0.4, 0.3), 2.0)
					ci.draw_rect(Rect2(sp, Vector2(32, 20)), Color(0.95, 0.95, 0.9) * dc)
					ci.draw_rect(Rect2(sp + Vector2(4, 7), Vector2(24, 6)), Color(0.3, 0.85, 0.3))
			"phone":
				if int(p["phase"] * 9) % 3 == 0:
					ci.draw_circle(pos + Vector2(12, -18), 2.5, Color(1, 1, 0.9, 0.6 + 0.4 * sin(t * 3.0 + p["phase"])))
			"overalls":
				# worn overalls over a work shirt, patched; flat caps, beanies and dirty hard hats
				var denim: Color = [Color(0.25, 0.32, 0.45), Color(0.4, 0.3, 0.2), Color(0.3, 0.33, 0.25)][pick % 3] * dc
				ci.draw_rect(Rect2(body.position + Vector2(4 * s, 10 * s), Vector2(18 * s, 30 * s)), denim)
				ci.draw_line(body.position + Vector2(6 * s, 0), body.position + Vector2(6 * s, 11 * s), denim, 2.5)
				ci.draw_line(body.position + Vector2(20 * s, 0), body.position + Vector2(20 * s, 11 * s), denim, 2.5)
				if pick == 1:
					ci.draw_rect(Rect2(body.position + Vector2(13 * s, 26 * s), Vector2(6 * s, 6 * s)), Color(0.55, 0.4, 0.25) * dc)   # patch
				match pick:
					0:   # flat cap
						ci.draw_arc(pos + Vector2(0, -hr * 0.25), hr, PI, TAU, 8, Color(0.3, 0.27, 0.22) * dc, hr * 0.6)
						ci.draw_line(pos + Vector2(hr * 0.3, -hr * 0.3), pos + Vector2(hr * 1.4, -hr * 0.15), Color(0.25, 0.22, 0.18) * dc, 3.0)
					1, 3:   # beanie
						ci.draw_arc(pos + Vector2(0, -hr * 0.2), hr * 0.95, PI, TAU, 8, (Color(0.5, 0.2, 0.15) if pick == 1 else Color(0.25, 0.3, 0.25)) * dc, hr * 0.7)
					2:   # scuffed hard hat
						ci.draw_arc(pos + Vector2(0, -hr * 0.2), hr, PI, TAU, 10, Color(0.75, 0.6, 0.2) * dc, hr * 0.8)
						ci.draw_circle(pos + Vector2(-hr * 0.3, -hr * 0.7), 1.5, Color(0.3, 0.25, 0.15))
					_:
						ci.draw_arc(pos, hr, PI * 1.1, PI * 1.9, 6, Color(0.2, 0.15, 0.1) * dc, 3.0)   # messy hair
				if pick == 4 and arm_up:
					ci.draw_line(pos + Vector2(16, -14 + b * 0.5), pos + Vector2(22, -26 + b * 0.5), Color(0.6, 0.6, 0.6), 3.0)   # waving a wrench
			"casual":
				# t-shirts and hoodies; some caps
				ci.draw_rect(Rect2(body.position + Vector2(9 * s, 0), Vector2(8 * s, 4 * s)), skin)
				if pick == 0 or pick == 3:
					ci.draw_arc(pos + Vector2(0, -hr * 0.25), hr, PI, TAU, 8, pc, hr * 0.6)
					ci.draw_line(pos + Vector2(0, -hr * 0.4), pos + Vector2(hr * 1.5, -hr * 0.3), pc, 3.0)
				else:
					ci.draw_arc(pos, hr, PI * 1.05, PI * 1.95, 6, [Color(0.15, 0.1, 0.05), Color(0.55, 0.35, 0.15), Color(0.85, 0.75, 0.4)][pick % 3] * dc, 4.0)
			"smart":
				# jackets with open collars; a few ties, a few hats - their best clothes for the final
				ci.draw_colored_polygon(PackedVector2Array([body.position + Vector2(9 * s, 0), body.position + Vector2(17 * s, 0), body.position + Vector2(13 * s, 12 * s)]), Color(0.92, 0.92, 0.88) * dc)
				if pick % 2 == 0:
					ci.draw_line(body.position + Vector2(13 * s, 2 * s), body.position + Vector2(13 * s, 14 * s), pc, 2.5)
				if pick == 1:   # fedora
					ci.draw_rect(Rect2(pos + Vector2(-hr * 1.3, -hr * 0.6), Vector2(hr * 2.6, 3)), Color(0.2, 0.18, 0.15) * dc)
					ci.draw_rect(Rect2(pos + Vector2(-hr * 0.7, -hr * 1.3), Vector2(hr * 1.4, hr * 0.75)), Color(0.25, 0.22, 0.18) * dc)
				else:
					ci.draw_arc(pos, hr, PI * 1.05, PI * 1.95, 6, Color(0.15, 0.1, 0.06) * dc, 3.0)
			"scarf":
				# team scarves held up when it goes off, foam fingers, phones out
				ci.draw_rect(Rect2(pos + Vector2(-hr, hr * 0.7), Vector2(hr * 2, 5)), pc)
				if arm_up and pick % 2 == 0:
					var sp := pos + Vector2(-20, -24 + b * 0.5)
					for k in 5:
						ci.draw_rect(Rect2(sp + Vector2(k * 8, 0), Vector2(8, 7)), pc if k % 2 == 0 else Color(1, 1, 1) * dc)
				elif pick == 3:
					ci.draw_rect(Rect2(pos + Vector2(12, -20 + b * 0.5), Vector2(8, 16)), Color(0.15, 0.55, 1.0) * dc)   # foam finger
				elif pick == 4:
					ci.draw_circle(pos + Vector2(12, -18), 2.5, Color(1, 1, 0.9, 0.6 + 0.4 * sin(t * 3.0 + p["phase"])))
			"tophat":
				# dinner jackets, bow ties, evening gowns, top hats, champagne
				if pick == 2 or pick == 4:
					var gown: Color = [Color(0.55, 0.05, 0.12), Color(0.1, 0.25, 0.45)][int(pick / 3.0)] * dc
					ci.draw_rect(body, gown)
					ci.draw_arc(pos, hr * 1.05, PI * 0.9, PI * 2.1, 8, Color(0.15, 0.08, 0.04) * dc, 4.0)
					ci.draw_circle(pos + Vector2(0, hr + 2), 2.0, Color(0.95, 0.95, 1.0))   # pearls
				else:
					ci.draw_colored_polygon(PackedVector2Array([body.position + Vector2(9 * s, 0), body.position + Vector2(17 * s, 0), body.position + Vector2(13 * s, 14 * s)]), Color(0.95, 0.95, 0.92) * dc)
					ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-4, hr + 1), pos + Vector2(0, hr + 4), pos + Vector2(-4, hr + 7)]), Color(0.05, 0.05, 0.05))   # bow tie
					ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(4, hr + 1), pos + Vector2(0, hr + 4), pos + Vector2(4, hr + 7)]), Color(0.05, 0.05, 0.05))
					if pick == 0:
						ci.draw_rect(Rect2(pos + Vector2(-hr * 1.2, -hr * 0.7), Vector2(hr * 2.4, 3)), Color(0.05, 0.05, 0.06))
						ci.draw_rect(Rect2(pos + Vector2(-hr * 0.7, -hr * 1.9), Vector2(hr * 1.4, hr * 1.25)), Color(0.07, 0.07, 0.08))
					elif pick == 1:
						ci.draw_arc(pos + Vector2(hr * 0.4, -hr * 0.1), 3.0, 0, TAU, 8, Color(0.9, 0.8, 0.4), 1.0)   # monocle
						ci.draw_arc(pos, hr, PI * 1.05, PI * 1.95, 6, Color(0.6, 0.6, 0.62) * dc, 3.0)
					else:
						ci.draw_arc(pos, hr, PI * 1.05, PI * 1.95, 6, Color(0.12, 0.08, 0.05) * dc, 3.0)
				if pick == 3 or pick == 4:   # champagne flute
					var gp := pos + Vector2(14, 0 + (b * 0.3 if cheer > 0.0 else 0.0))
					ci.draw_line(gp + Vector2(0, 8), gp + Vector2(0, -2), Color(0.85, 0.85, 0.9, 0.8), 1.5)
					ci.draw_rect(Rect2(gp + Vector2(-2.5, -12), Vector2(5, 10)), Color(1.0, 0.88, 0.45, 0.85))
		if arm_up:
			ci.draw_line(pos + Vector2(8, 10), pos + Vector2(16, -14 + b * 0.5), colr, 5.0)
	if piles and cur_row >= 0:
		draw_pile_row(ci, cur_row, top, screen.x, off)


## The junk mound in front of one row of the scrapyard crowd (they stand on it).
static func draw_pile_row(ci: CanvasItem, row: int, top: float, w: float, off: Vector2) -> void:
	var base := top + row * 34.0 + 64.0
	var o := off * 0.3
	var pts := PackedVector2Array()
	var x := -10.0
	while x <= w + 20.0:
		pts.append(Vector2(x, base - pile_bump(x, w, row) + sin(x * 0.13 + row) * 3.0) + o)
		x += 24.0
	pts.append(Vector2(w + 20.0, base + 70.0) + o)
	pts.append(Vector2(-10.0, base + 70.0) + o)
	var shade := 0.6 + row * 0.15
	ci.draw_colored_polygon(pts, Color(0.24, 0.19, 0.15) * Color(shade, shade, shade))
	# bits of dead robots sticking out of the pile
	for k in 9:
		var jx := fmod(k * 151.0 + row * 67.0, w)
		var jy := base - pile_bump(jx, w, row) + 10.0
		var jc := Color(0.38, 0.33, 0.28) * Color(shade, shade, shade)
		match (k + row) % 4:
			0:
				ci.draw_circle(Vector2(jx, jy) + o, 8.0, jc)
				ci.draw_rect(Rect2(Vector2(jx - 5, jy - 2) + o, Vector2(10, 3)), Color(0.15, 0.05, 0.03))
			1:
				ci.draw_line(Vector2(jx, jy) + o, Vector2(jx + 16, jy - 10) + o, jc, 5.0)
				ci.draw_circle(Vector2(jx + 17, jy - 11) + o, 4.0, jc.darkened(0.2))
			2:
				ci.draw_arc(Vector2(jx, jy + 4) + o, 9.0, 0, TAU, 12, Color(0.1, 0.1, 0.1) * Color(shade, shade, shade), 4.0)   # a tire
			_:
				ci.draw_rect(Rect2(Vector2(jx - 10, jy - 4) + o, Vector2(20, 12)), jc.lightened(0.05))


## The ring floor (in front of the crowd).
static func draw_floor(ci: CanvasItem, id: String, screen: Vector2, floor_y: float, t: float, off: Vector2) -> void:
	var a: Dictionary = ARENAS[id]
	var fc := Color(a["floor"])
	var w := screen.x
	var fh := screen.y - floor_y + 20.0
	ci.draw_rect(Rect2(Vector2(0, floor_y) + off, Vector2(w, fh)), fc)
	match id:
		"docks", "harbor":
			for k in 5:
				ci.draw_line(Vector2(0, floor_y + 14 + k * 26) + off, Vector2(w, floor_y + 14 + k * 26) + off, fc.darkened(0.3), 2.0)
		"fish_market":
			for k in 5:
				ci.draw_set_transform(Vector2(w * (0.1 + k * 0.2), floor_y + 40 + (k % 2) * 50) + off, 0.0, Vector2(1.0, 0.25))
				ci.draw_circle(Vector2.ZERO, 70.0, Color(0.6, 0.8, 0.9, 0.12))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"test_track":
			for k in 3:
				ci.draw_line(Vector2(0, floor_y + 30 + k * 50) + off, Vector2(w, floor_y + 30 + k * 50) + off, Color(1, 1, 1, 0.5), 3.0)
		"substation":
			for k in int(w / 24.0):
				ci.draw_line(Vector2(k * 24.0, floor_y) + off, Vector2(k * 24.0, screen.y) + off, fc.darkened(0.35), 2.0)
		"steelworks":
			for k in 8:
				ci.draw_rect(Rect2(Vector2(k * w / 8.0 + 2, floor_y + 4) + off, Vector2(w / 8.0 - 4, fh)), fc.lightened(0.04 * (k % 2)))
		"rooftop":
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_arc(Vector2.ZERO, 220.0, 0, TAU, 48, Color(0.95, 0.8, 0.2, 0.7), 10.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, floor_y + 92) + off, I18n.t("H"), HORIZONTAL_ALIGNMENT_CENTER, 80, 40, Color(0.95, 0.8, 0.2, 0.7))
		"main_event":
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_circle(Vector2.ZERO, 200.0, Color(1.0, 0.18, 0.4, 0.18))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dry_dock":
			for k in 6:
				ci.draw_circle(Vector2(w * (0.08 + k * 0.17), floor_y + 30 + (k % 3) * 30) + off, 12.0, fc.darkened(0.25))
		"scrap_ring":
			for k in 7:   # oil stains
				ci.draw_set_transform(Vector2(w * (0.07 + k * 0.14), floor_y + 30 + (k % 3) * 34) + off, 0.0, Vector2(1.0, 0.3))
				ci.draw_circle(Vector2.ZERO, 30.0 + (k % 2) * 20.0, Color(0.1, 0.08, 0.06, 0.35))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 26:   # bolts, nuts and bits of robot
				var x := fmod(k * 97.0, w)
				var y := floor_y + 12 + fmod(k * 37.0, 120.0)
				if k % 5 == 0:
					ci.draw_line(Vector2(x, y) + off, Vector2(x + 18, y - 4) + off, Color(0.45, 0.42, 0.38), 4.0)
				else:
					ci.draw_circle(Vector2(x, y) + off, 3.0, Color(0.55, 0.5, 0.42))
		"regional_hall", "regional_final":
			for k in int(w / 60.0) + 1:   # wooden boards
				ci.draw_line(Vector2(k * 60.0, floor_y) + off, Vector2(k * 60.0 - 30.0, screen.y) + off, fc.darkened(0.2), 2.0)
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_arc(Vector2.ZERO, 160.0, 0, TAU, 40, Color(1, 1, 1, 0.35), 5.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"champ_arena":
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_circle(Vector2.ZERO, 220.0, Color(0.25, 0.5, 1.0, 0.12))
			ci.draw_arc(Vector2.ZERO, 220.0, 0, TAU, 48, Color(0.4, 0.7, 1.0, 0.5), 4.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"champ_gala":
			for k in int(w / 80.0) + 1:   # polished checkered marble
				ci.draw_rect(Rect2(Vector2(k * 80.0, floor_y + 4) + off, Vector2(40.0, screen.y - floor_y)), fc.lightened(0.06))
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_arc(Vector2.ZERO, 200.0, 0, TAU, 48, Color(0.85, 0.7, 0.3, 0.8), 6.0)
			ci.draw_arc(Vector2.ZERO, 180.0, 0, TAU, 48, Color(0.85, 0.7, 0.3, 0.4), 2.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, floor_y + 90) + off, I18n.t("K"), HORIZONTAL_ALIGNMENT_CENTER, 80, 40, Color(0.85, 0.7, 0.3, 0.7))
	ci.draw_line(Vector2(0, floor_y) + off, Vector2(w, floor_y) + off, fc.lightened(0.35), 3.0)
