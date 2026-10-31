class_name Builds
extends RefCounted
## Everyone who can step into the arena: bodies, swords, fighting stats and AI temperament, plus the
## story, the training drills and the saved progress.
##
## Stats are multipliers around 1.0. tough/guard divide incoming damage/posture, startup scales how
## long wind-ups take, kick scales every kick, link is the bonus to cuts on someone just kicked.

const SKILLS := ["blade", "kick", "footwork", "guard", "vigor"]
const MAX_LEVEL := 5
const SKILL_INFO := {
	"blade": {"title": "BLADE", "effect": "Cuts deal 6% more per rank", "goal": "Land %d cuts", "base": 3, "per": 2},
	"kick": {"title": "KICK", "effect": "Kicks hit 12% harder and start sooner per rank", "goal": "Land %d kicks", "base": 3, "per": 2},
	"footwork": {"title": "FOOTWORK", "effect": "Move 4% faster, dash for less per rank", "goal": "Dash away from %d attacks", "base": 2, "per": 1},
	"guard": {"title": "GUARD", "effect": "Longer parry, 6% sturdier guard per rank", "goal": "Parry %d blows", "base": 1, "per": 1},
	"vigor": {"title": "VIGOR", "effect": "Take 7% less damage, recover stamina faster per rank", "goal": "Sweep or break a guard %d times", "base": 1, "per": 1},
}

const HERO := {
	"id": "maren", "name": "MAREN", "body": "woman", "scale": 0.933, "width": 1.07, "head": 0.97,
	"blade": 94.0, "blade_w": 1.05, "sori": 5.0, "hurt": 12.5,
	"cloth": [["hair", "crown", 8, 6.5, 1.2, 0.3, -0.28, 4.6, 1.3, "main"],
		["hair2", "crown2", 6, 6.5, 1.6, 0.34, -0.2, 3.4, 0.9, "main"],
		["lock", "temple", 3, 4.2, 0.8, 0.45, 0.02, 1.3, 0.4, "main"],
		["wrap", "hip", 5, 8.0, 1.0, 0.4, -0.12, 5.5, 1.2, "main"]],
	"extras": ["hair_cap"],
	"stats": {"speed": 1.06, "atk": 0.95, "kick": 1.6, "brk": 0.95, "tough": 0.95, "guard": 0.95, "startup": 0.95,
		"stam": 1.05, "parry": 0.0, "link": 1.3, "kick_lines": true},
	"ai": {"skill": 0.0, "aggr": 0.6, "kick": 0.7, "parry": 1.0},
}

const MEN := [
	{"id": "ronin", "name": "THE RONIN", "body": "man", "scale": 0.99, "width": 1.0, "head": 1.0,
		"blade": 100.0, "blade_w": 1.1, "sori": 5.0, "hurt": 14.0, "blurb": "Balanced. Tests everything, excels at nothing.",
		"cloth": [["wrap", "hip", 4, 7.0, 1.0, 0.45, -0.1, 4.5, 1.6, "main"]], "extras": ["topknot"],
		"stats": {"speed": 1.0, "atk": 1.0, "kick": 0.7, "brk": 1.0, "tough": 1.0, "guard": 1.0, "startup": 1.0,
			"stam": 1.0, "parry": 0.0, "link": 1.0, "kick_lines": false},
		"ai": {"skill": -0.08, "aggr": 0.6, "kick": 0.15, "parry": 1.0}},
	{"id": "needle", "name": "THE NEEDLE", "body": "man", "scale": 0.96, "width": 0.88, "head": 1.0,
		"blade": 78.0, "blade_w": 0.8, "sori": 1.0, "hurt": 12.5, "blurb": "Quick and frail. Short blade, relentless pressure.",
		"cloth": [["hair", "crown", 4, 6.5, 1.5, 0.35, -0.12, 3.2, 1.0, "main"]], "extras": [],
		"stats": {"speed": 1.18, "atk": 0.82, "kick": 0.7, "brk": 0.7, "tough": 0.8, "guard": 0.85, "startup": 0.8,
			"stam": 1.2, "parry": 0.0, "link": 1.0, "kick_lines": false},
		"ai": {"skill": -0.04, "aggr": 0.95, "kick": 0.1, "parry": 0.6}},
	{"id": "warden", "name": "THE WARDEN", "body": "man", "scale": 1.0, "width": 1.06, "head": 1.0,
		"blade": 104.0, "blade_w": 1.2, "sori": 3.0, "hurt": 14.5, "blurb": "A wall that parries. Kick his legs, not his sword.",
		"cloth": [["hair", "crown", 5, 7.0, 1.0, 0.4, -0.08, 4.0, 1.4, "main"]], "extras": ["beard"],
		"stats": {"speed": 0.94, "atk": 0.95, "kick": 0.8, "brk": 1.0, "tough": 1.05, "guard": 1.3, "startup": 1.0,
			"stam": 1.0, "parry": 3.0, "link": 1.0, "kick_lines": false},
		"ai": {"skill": 0.04, "aggr": 0.3, "kick": 0.1, "parry": 1.7}},
	{"id": "ox", "name": "THE OX", "body": "man", "scale": 1.06, "width": 1.28, "head": 1.02,
		"blade": 128.0, "blade_w": 1.75, "sori": 3.0, "hurt": 18.0, "blurb": "Huge and slow. One clean hit is half your life.",
		"cloth": [], "extras": ["beard"],
		"stats": {"speed": 0.82, "atk": 1.3, "kick": 1.0, "brk": 1.35, "tough": 1.35, "guard": 1.25, "startup": 1.18,
			"stam": 0.85, "parry": 0.0, "link": 1.0, "kick_lines": false},
		"ai": {"skill": 0.0, "aggr": 0.45, "kick": 0.2, "parry": 0.5}},
	{"id": "king", "name": "THE DROWNED KING", "body": "man", "scale": 1.03, "width": 1.12, "head": 1.0,
		"blade": 112.0, "blade_w": 1.35, "sori": 6.0, "hurt": 15.5, "blurb": "Better than you at everything but your legs.",
		"cloth": [["cape", "shoulder", 6, 12.0, 1.1, 0.42, -0.3, 7.0, 11.0, "back"],
			["hair", "crown", 5, 7.0, 1.2, 0.35, -0.1, 3.6, 1.0, "main"]], "extras": ["crown", "beard"],
		"stats": {"speed": 1.02, "atk": 1.15, "kick": 1.0, "brk": 1.15, "tough": 1.2, "guard": 1.15, "startup": 0.95,
			"stam": 1.1, "parry": 1.0, "link": 1.0, "kick_lines": false},
		"ai": {"skill": 0.1, "aggr": 0.7, "kick": 0.25, "parry": 1.2}},
]

## Fought in this order: opponent id, stage, and the card shown before the duel.
const STORY := [
	{"opp": "ronin", "stage": 0, "title": "I  ·  THE HOLLOW GATE",
		"text": ["The sea took the city and left its men with nothing but swords.", "Maren comes back for the Gate. A hired ronin is paid to keep it shut.", "He has never fought anyone who fights with her legs."]},
	{"opp": "needle", "stage": 1, "title": "II  ·  THE DUNE MONOLITH",
		"text": ["Past the Gate, the seabed is desert.", "The Needle has killed nine challengers before they finished drawing.", "He is faster than her. So she must take away his footing."]},
	{"opp": "warden", "stage": 0, "title": "III  ·  THE WARDEN'S VOW",
		"text": ["The old warden trained her, and swore to stop her.", "No blade has passed his guard in thirty years.", "So she will not use a blade first."]},
	{"opp": "ox", "stage": 1, "title": "IV  ·  THE OX",
		"text": ["The King's executioner stands a head taller than any man alive.", "She cannot block that sword for long.", "Every tree falls from the bottom."]},
	{"opp": "king", "stage": 0, "title": "V  ·  THE DROWNED KING",
		"text": ["He sold the city to the sea to rule what was left.", "Everyone he ever sent has failed.", "She takes up her guard, and he finally stands."]},
]
const STORY_END := ["The King falls, and for the first time in an age the water stills.", "Maren plants her sword in the sand and walks up out of the sunken world.", "Nobody follows. There is nobody left who could."]


static func man_by_id(id: String) -> Dictionary:
	for b: Dictionary in MEN:
		if b["id"] == id:
			return b
	return MEN[0]


## The hero's stats with her trained ranks applied.
static func hero_stats(levels: Dictionary) -> Dictionary:
	var s: Dictionary = (HERO["stats"] as Dictionary).duplicate()
	s["atk"] = float(s["atk"]) * (1.0 + 0.06 * int(levels.get("blade", 0)))
	s["kick"] = float(s["kick"]) * (1.0 + 0.12 * int(levels.get("kick", 0)))
	s["kick_startup"] = 1.0 - 0.05 * int(levels.get("kick", 0))
	s["speed"] = float(s["speed"]) * (1.0 + 0.04 * int(levels.get("footwork", 0)))
	s["dash_cost"] = 1.0 - 0.08 * int(levels.get("footwork", 0))
	s["guard"] = float(s["guard"]) * (1.0 + 0.06 * int(levels.get("guard", 0)))
	s["parry"] = float(s["parry"]) + 0.6 * int(levels.get("guard", 0))
	s["tough"] = float(s["tough"]) * (1.0 + 0.07 * int(levels.get("vigor", 0)))
	s["stam"] = float(s["stam"]) * (1.0 + 0.06 * int(levels.get("vigor", 0)))
	return s


static func drill_goal(skill: String, level: int) -> int:
	var info: Dictionary = SKILL_INFO[skill]
	return int(info["base"]) + int(info["per"]) * level


# ---------------------------------------------------------------- saved progress

static func load_progress(path: String) -> Dictionary:
	var out := {"levels": {}, "chapter": 0}
	for k: String in SKILLS:
		out["levels"][k] = 0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	for k: String in SKILLS:
		out["levels"][k] = clampi(int(cfg.get_value("levels", k, 0)), 0, MAX_LEVEL)
	out["chapter"] = clampi(int(cfg.get_value("story", "chapter", 0)), 0, STORY.size())
	return out


static func save_progress(path: String, progress: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k: String in SKILLS:
		cfg.set_value("levels", k, progress["levels"][k])
	cfg.set_value("story", "chapter", progress["chapter"])
	cfg.save(path)
