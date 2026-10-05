class_name Arena
extends RefCounted
## Fight venues and crowds. Any arena can host any crowd: story fights use them in story
## order, cups and quick fights mix and match them at random.
##
## Each arena draws its own backdrop and floor and sets the ring colors.
## Each crowd has its own people (size, colors, hats, props) and its own way of cheering.

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
	"main_event": {"name": "Kane Arena - Main Event", "sky": ["#07040f", "#1a0c2e"], "floor": "#1c1c26", "rope": "#ff2e63", "post": "#e0b84a", "light": "#ffffff"},
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
}
const STORY_CROWDS := ["fishmongers", "dockers", "punks", "suits", "families", "ravers", "bikers", "robots", "fans", "packed"]


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
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 20, 40) + o, "K", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color(0.88, 0.72, 0.29))
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
		"main_event":
			var sc := Rect2(w * 0.38, 96, w * 0.24, 46)   # jumbotron
			ci.draw_rect(sc.grow(5), Color(0.1, 0.1, 0.12))
			ci.draw_rect(sc, Color(0.05, 0.08, 0.2))
			ci.draw_string(ThemeDB.fallback_font, sc.position + Vector2(0, 33), "MAIN EVENT", HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 24, Color.from_hsv(fmod(t * 0.2, 1.0), 0.6, 1.0))
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
	for p in crowd:
		var row: int = p["row"]
		var s: float = p["size"]
		var y: float = top + row * 34.0 + 20.0 + (1.0 - s) * 30.0
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
		ci.draw_rect(Rect2(pos.x - 13 * s, pos.y + 6 * s, 26 * s, 40 * s), colr.darkened(0.2))
		ci.draw_circle(pos, hr, colr.lerp(Color(0.85, 0.7, 0.55), 0.35) if hat != "suit" else Color(0.75, 0.62, 0.5).darkened(0.25 * (2 - row)))
		var dim := 1.0 - 0.25 * (2 - row)
		var pc: Color = (p["prop"] as Color) * Color(dim, dim, dim)
		var arm_up := cheer > 0.5 and int(p["phase"] * 10) % 3 == 0
		match hat:
			"sou'wester":
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-hr * 1.4, -hr * 0.3), pos + Vector2(0, -hr * 1.3), pos + Vector2(hr * 1.4, -hr * 0.3)]), Color(0.9, 0.75, 0.1) * Color(dim, dim, dim))
			"hardhat":
				ci.draw_arc(pos + Vector2(0, -hr * 0.2), hr, PI, TAU, 10, Color(1.0, 0.6, 0.1) * Color(dim, dim, dim), hr * 0.8)
			"mohawk":
				for k in 4:
					ci.draw_line(pos + Vector2(-4 + k * 3, -hr * 0.8), pos + Vector2(-4 + k * 3, -hr * 1.8), pc, 2.5)
			"suit":
				ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-4, hr), pos + Vector2(4, hr), pos + Vector2(0, hr + 14)]), Color(0.9, 0.9, 0.9) * Color(dim, dim, dim))
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
				ci.draw_circle(pos, hr * 1.15, Color(0.12, 0.12, 0.14) * Color(dim, dim, dim))
				ci.draw_rect(Rect2(pos.x - hr * 0.2, pos.y - hr * 0.3, hr * 1.2, hr * 0.5), Color(0.5, 0.7, 0.9, 0.6))
			"sign":
				if int(p["phase"] * 7) % 3 == 0:
					var sp := pos + Vector2(-16, -46 + (b * 0.5))
					ci.draw_line(pos + Vector2(0, 6), sp + Vector2(16, 20), Color(0.5, 0.4, 0.3), 2.0)
					ci.draw_rect(Rect2(sp, Vector2(32, 20)), Color(0.95, 0.95, 0.9) * Color(dim, dim, dim))
					ci.draw_rect(Rect2(sp + Vector2(4, 7), Vector2(24, 6)), Color(0.3, 0.85, 0.3))
			"phone":
				if int(p["phase"] * 9) % 3 == 0:
					ci.draw_circle(pos + Vector2(12, -18), 2.5, Color(1, 1, 0.9, 0.6 + 0.4 * sin(t * 3.0 + p["phase"])))
		if arm_up:
			ci.draw_line(pos + Vector2(8, 10), pos + Vector2(16, -14 + b * 0.5), colr, 5.0)


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
			ci.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, floor_y + 92) + off, "H", HORIZONTAL_ALIGNMENT_CENTER, 80, 40, Color(0.95, 0.8, 0.2, 0.7))
		"main_event":
			ci.draw_set_transform(Vector2(w * 0.5, floor_y + 70) + off, 0.0, Vector2(1.0, 0.3))
			ci.draw_circle(Vector2.ZERO, 200.0, Color(1.0, 0.18, 0.4, 0.18))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dry_dock":
			for k in 6:
				ci.draw_circle(Vector2(w * (0.08 + k * 0.17), floor_y + 30 + (k % 3) * 30) + off, 12.0, fc.darkened(0.25))
	ci.draw_line(Vector2(0, floor_y) + off, Vector2(w, floor_y) + off, fc.lightened(0.35), 3.0)
