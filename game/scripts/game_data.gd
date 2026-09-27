extends Node

## GameData (autoload)
## Persistent meta-progression, the Upgrade Board, hat generation and run state.

enum Rarity { COMMON, RARE, LEGENDARY }

const RARITY_WEIGHTS = [70, 20, 10]
const CHROMA_CHANCE = 0.02
const SAVE_PATH = "user://save_v2.json"
const OLD_SAVE_PATH = "user://save.json"

const MATERIALS = {
	Rarity.COMMON: [["cardboard", 5], ["straw", 6], ["tweed", 7], ["pinstripe", 8]],
	Rarity.RARE: [["felt", 15], ["leather", 18], ["copper", 16]],
	Rarity.LEGENDARY: [["titanium", 30], ["velvet", 28], ["patent_leather", 35]]
}
const BANDS = {
	Rarity.COMMON: ["cotton", "houndstooth", "pearl_strand"],
	Rarity.RARE: ["silk", "spiked", "velvet_ribbon", "brass_rivet"],
	Rarity.LEGENDARY: ["dynamo", "chrono", "neon_magenta"]
}
const ADDONS = {
	Rarity.COMMON: ["paperclip", "feather", "horseshoe"],
	Rarity.RARE: ["playing_card", "matchstick", "harmonica", "poker_chip"],
	Rarity.LEGENDARY: ["fuzzy_dice", "golden_coin", "bullet_casing"]
}

# --- HAT NAMES: built from the parts, flavoured by the hat's grade ---
# Material sets the mood, band sets the attitude, add-on is the calling card, grade is the billing.
const MAT_WORDS = {
	"cardboard": ["Two-Bit", "Shoebox", "Dime-Store", "Paper-Moon", "Bargain-Bin"],
	"straw": ["Boardwalk", "Sunday", "Seaside", "Summer-Wind", "Porch-Light"],
	"tweed": ["Gumshoe", "Backstreet", "Foggy", "Rain-Slick", "Alleyway"],
	"pinstripe": ["Wiseguy", "Speakeasy", "Hush-Money", "Pinstripe", "Racket"],
	"felt": ["Smoky", "Backroom", "Last-Call", "Blue-Smoke", "Cigarette"],
	"leather": ["Road-Worn", "Hard-Luck", "Highway", "Outlaw", "Dust-Bowl"],
	"copper": ["Copper", "Penny-Ante", "Brass-Band", "Trumpet", "Spark-Plug"],
	"titanium": ["Iron", "Titan", "Atomic", "Rocket", "Steel-Toed"],
	"velvet": ["Velvet", "Moonlit", "Starlit", "Silver-Screen", "Crushed-Velvet"],
	"patent_leather": ["Midnight", "Black-Tie", "After-Hours", "Tuxedo", "Top-Shelf"],
}
const BAND_NOUNS = {
	"cotton": ["Stitch", "Patchwork", "Hand-Me-Down"], "houndstooth": ["Checkmate", "Houndstooth", "Double Down"],
	"pearl_strand": ["Pearls", "Oyster", "Moonpearl"], "silk": ["Satin", "Smoke Ring", "Silk Road"],
	"spiked": ["Brass Knuckle", "Switchblade", "Thorn"], "velvet_ribbon": ["Ribbon", "Bow Tie", "Curtain Call"],
	"brass_rivet": ["Rivet", "Boilerplate", "Horn Section"], "dynamo": ["Thunder", "Live Wire", "Voltage"],
	"chrono": ["Clockwork", "Overtime", "Tick-Tock"], "neon_magenta": ["Neon", "Marquee", "Afterglow"],
}
const BAND_ADJ = {
	"cotton": "Easygoing", "houndstooth": "Checkered", "pearl_strand": "Pearly", "silk": "Silver-Tongued",
	"spiked": "Brass-Knuckle", "velvet_ribbon": "Ribboned", "brass_rivet": "Riveting", "dynamo": "Live-Wire",
	"chrono": "Clockwork", "neon_magenta": "Neon-Lit",
}
const ADDON_WORDS = {
	"paperclip": ["Loose-Change", "Office-Hours"], "feather": ["Featherweight", "Free-Bird"], "horseshoe": ["Lucky", "Long-Odds"],
	"playing_card": ["Wildcard", "Ace-High"], "matchstick": ["Slow-Burn", "Firestarter"], "harmonica": ["Lonesome", "Blues-Harp"],
	"poker_chip": ["All-In", "Blue-Chip"], "fuzzy_dice": ["Snake-Eyes", "Lucky-Seven"], "golden_coin": ["Double-Eagle", "Heads-Up"],
	"bullet_casing": ["Hair-Trigger", "Last-Round"],
}
const GRADE_NOUNS = [
	["Hustler", "Busker", "Stagehand", "Hopeful", "Bellhop", "Long Shot", "Understudy", "Shoeshine"],
	["Crooner", "Heartbreaker", "Racketeer", "Night Owl", "Hepcat", "Troubadour", "Sweet Talker", "Sharpshooter"],
	["Headliner", "Showstopper", "Bandleader", "High Roller", "Torch Singer", "Maestro", "Kingpin", "Big Shot"],
	["Legend", "Main Event", "Crown Jewel", "Moonshot", "Chairman", "Grand Finale", "Standing Ovation", "Last Word"],
]
const NAME_PLACES = ["Rust Row", "Basin Street", "the Blue Note", "Luna City", "the Late Show", "Neon Alley", "the Dark Side", "the Midnight Set", "the Back Room", "Tranquility"]

# --- GRADES: a hat is graded by ALL of its parts, not its single best one ---
const GRADES = ["C", "B", "A", "S"]
const GRADE_COLORS = [Color(0.72, 0.72, 0.75), Color(0.35, 0.7, 1.0), Color(0.8, 0.45, 1.0), Color(1.0, 0.75, 0.2)]

# --- THE UNDERSTUDIES: the Back Room crew, a handful of T-1Ns who all learned the act. Whoever wears the hat IS Ol' Tin Eyes. ---
const PERF_FIRST = ["Rivet", "Cog", "Sprocket", "Dynamo", "Piston", "Tinny", "Crank", "Coil", "Ratchet", "Axle", "Widget", "Gizmo", "Solder", "Flywheel", "Chrome", "Spark", "Bolt", "Gasket", "Valve", "Dials"]
const PERF_LAST = ["Fontaine", "Bellamy", "Marlowe", "Beaumont", "Sinclair", "Delacroix", "Starling", "Velour", "Sterling", "Holloway", "Castellano", "Lafayette", "Quartermain", "Sorrento", "Laramie", "Vance", "Moonbeam", "Kincaid", "Rousseau", "Delgado"]
const MAX_HISTORY = 40

# ---------------------------------------------------------------------------
# THE UPGRADE BOARD (Johnny Upgrade style)
# Every node reveals its children once bought. Costs climb per level.
# cur: "rp" = Rhythm Points, "rec" = Gold Records (boss drops)
# ---------------------------------------------------------------------------
const BOARD = [
	{"id": "chassis", "name": "Wind-Up Chassis", "desc": "Your trusty tin body. Everything grows from here.", "pos": Vector2(0, 0), "max": 1, "cost": 0, "growth": 1.0, "cur": "rp", "parent": "", "cat": "core"},

	# --- OFFENSE (right) ---
	{"id": "dmg1", "name": "Servo Knuckles", "desc": "+8% damage with everything.", "pos": Vector2(2, 0), "max": 5, "cost": 12, "growth": 1.6, "cur": "rp", "parent": "chassis", "cat": "off"},
	{"id": "atkspd", "name": "Swing Tempo", "desc": "+6% attack speed.", "pos": Vector2(3, -1), "max": 5, "cost": 25, "growth": 1.6, "cur": "rp", "parent": "dmg1", "cat": "off"},
	{"id": "crit", "name": "Sharp Suit", "desc": "+3% critical hit chance.", "pos": Vector2(3, 1), "max": 5, "cost": 30, "growth": 1.6, "cur": "rp", "parent": "dmg1", "cat": "off"},
	{"id": "unlock_encore", "name": "Encore!", "desc": "UNLOCK: Encore rewards appear in runs. They level up your boons.", "pos": Vector2(4, 0), "max": 1, "cost": 60, "growth": 1.0, "cur": "rp", "parent": "dmg1", "cat": "off"},
	{"id": "special_dmg", "name": "Brass Section", "desc": "+10% Special damage.", "pos": Vector2(4, -2), "max": 5, "cost": 35, "growth": 1.6, "cur": "rp", "parent": "atkspd", "cat": "off"},
	{"id": "cast_dmg", "name": "Big Finish", "desc": "+12% Showstopper (Cast) damage.", "pos": Vector2(5, -3), "max": 5, "cost": 50, "growth": 1.65, "cur": "rp", "parent": "special_dmg", "cat": "off"},
	{"id": "first_strike", "name": "Opening Number", "desc": "+25% damage to enemies at full health.", "pos": Vector2(5, -1), "max": 3, "cost": 90, "growth": 1.9, "cur": "rp", "parent": "special_dmg", "cat": "off"},
	{"id": "critdmg", "name": "Knockout Punch", "desc": "+15% critical hit damage.", "pos": Vector2(4, 2), "max": 4, "cost": 70, "growth": 1.8, "cur": "rp", "parent": "crit", "cat": "off"},
	{"id": "boss_dmg", "name": "Showstopper", "desc": "+10% damage to bosses and elites.", "pos": Vector2(5, 3), "max": 3, "cost": 1, "growth": 1.6, "cur": "rec", "parent": "critdmg", "cat": "off"},

	# --- DEFENSE (left) ---
	{"id": "hp1", "name": "Reinforced Plating", "desc": "+12 max health.", "pos": Vector2(-2, 0), "max": 8, "cost": 10, "growth": 1.45, "cur": "rp", "parent": "chassis", "cat": "def"},
	{"id": "armor", "name": "Tin Suit", "desc": "Take 4% less damage.", "pos": Vector2(-3, -1), "max": 5, "cost": 30, "growth": 1.6, "cur": "rp", "parent": "hp1", "cat": "def"},
	{"id": "regen", "name": "Oil Change", "desc": "Heal 3 HP whenever you clear a room.", "pos": Vector2(-3, 1), "max": 5, "cost": 22, "growth": 1.5, "cur": "rp", "parent": "hp1", "cat": "def"},
	{"id": "hp2", "name": "Heavy Chassis", "desc": "+25 max health.", "pos": Vector2(-4, 0), "max": 5, "cost": 140, "growth": 1.6, "cur": "rp", "parent": "hp1", "cat": "def"},
	{"id": "dodge", "name": "Two-Step", "desc": "+3% chance to dodge any hit.", "pos": Vector2(-4, -2), "max": 5, "cost": 45, "growth": 1.6, "cur": "rp", "parent": "armor", "cat": "def"},
	{"id": "defiance", "name": "Curtain Call", "desc": "+1 revive per run (come back at 40% HP).", "pos": Vector2(-5, -1), "max": 3, "cost": 2, "growth": 1.5, "cur": "rec", "parent": "armor", "cat": "def"},
	{"id": "heal_bonus", "name": "Stiff Drink", "desc": "+20% healing from all sources.", "pos": Vector2(-4, 2), "max": 3, "cost": 40, "growth": 1.7, "cur": "rp", "parent": "regen", "cat": "def"},
	{"id": "start_shield", "name": "Opening Night", "desc": "Start every room with a shield that blocks one hit.", "pos": Vector2(-5, 3), "max": 1, "cost": 260, "growth": 1.0, "cur": "rp", "parent": "heal_bonus", "cat": "def"},

	# --- MOBILITY (up) ---
	{"id": "spd1", "name": "Chassis Oil", "desc": "+5% move speed.", "pos": Vector2(0, -2), "max": 5, "cost": 12, "growth": 1.5, "cur": "rp", "parent": "chassis", "cat": "mob"},
	{"id": "dash_cd", "name": "Quick Step", "desc": "-8% dash recharge time.", "pos": Vector2(-1, -3), "max": 4, "cost": 30, "growth": 1.6, "cur": "rp", "parent": "spd1", "cat": "mob"},
	{"id": "dash_charge", "name": "Double Time", "desc": "+1 dash charge.", "pos": Vector2(1, -3), "max": 2, "cost": 120, "growth": 3.0, "cur": "rp", "parent": "spd1", "cat": "mob"},
	{"id": "dash_dmg", "name": "Shoulder Check", "desc": "Dashing through enemies deals 15 damage per level.", "pos": Vector2(-2, -4), "max": 3, "cost": 55, "growth": 1.8, "cur": "rp", "parent": "dash_cd", "cat": "mob"},
	{"id": "magnet", "name": "Magnetic Soles", "desc": "+40% pickup magnet range.", "pos": Vector2(0, -4), "max": 3, "cost": 18, "growth": 1.6, "cur": "rp", "parent": "dash_cd", "cat": "mob"},
	{"id": "cast_cd", "name": "Quick Change", "desc": "-8% Showstopper cooldown.", "pos": Vector2(2, -4), "max": 5, "cost": 45, "growth": 1.6, "cur": "rp", "parent": "dash_charge", "cat": "mob"},
	{"id": "special_cd", "name": "Sleight of Hand", "desc": "-7% Special cooldown.", "pos": Vector2(1, -5), "max": 5, "cost": 40, "growth": 1.6, "cur": "rp", "parent": "magnet", "cat": "mob"},

	# --- FORTUNE (down) ---
	{"id": "rp_gain", "name": "Tip Jar", "desc": "+10% Rhythm Points from enemies.", "pos": Vector2(0, 2), "max": 8, "cost": 15, "growth": 1.5, "cur": "rp", "parent": "chassis", "cat": "luck"},
	{"id": "rolls", "name": "Extra Quarter", "desc": "+1 FREE Hat Roll after every run.", "pos": Vector2(-1, 3), "max": 3, "cost": 60, "growth": 2.2, "cur": "rp", "parent": "rp_gain", "cat": "luck"},
	{"id": "luck", "name": "Loaded Dice", "desc": "Rare and Legendary hat traits roll more often.", "pos": Vector2(1, 3), "max": 5, "cost": 50, "growth": 1.7, "cur": "rp", "parent": "rp_gain", "cat": "luck"},
	{"id": "unlock_shop", "name": "Speakeasy Password", "desc": "UNLOCK: Speakeasy shops appear. Spend Chips on boons and drinks.", "pos": Vector2(0, 4), "max": 1, "cost": 35, "growth": 1.0, "cur": "rp", "parent": "rp_gain", "cat": "luck"},
	{"id": "haggle", "name": "Sweet Talker", "desc": "Paid Hat Rolls cost 15% less.", "pos": Vector2(-3, 3), "max": 3, "cost": 70, "growth": 1.8, "cur": "rp", "parent": "rolls", "cat": "luck"},
	{"id": "tip_tokens", "name": "Stage Presence", "desc": "+1 Stage Token after every run (spend in the Dressing Room).", "pos": Vector2(-4, 4), "max": 3, "cost": 90, "growth": 1.9, "cur": "rp", "parent": "haggle", "cat": "luck"},
	{"id": "roster", "name": "Bigger Wardrobe", "desc": "+1 Hat Roster slot.", "pos": Vector2(-2, 4), "max": 4, "cost": 80, "growth": 1.9, "cur": "rp", "parent": "rolls", "cat": "luck"},
	{"id": "boon_rarity", "name": "Lucky Charm", "desc": "Boons are more often Rare, Epic or Heroic.", "pos": Vector2(2, 4), "max": 5, "cost": 40, "growth": 1.6, "cur": "rp", "parent": "luck", "cat": "luck"},
	{"id": "chroma", "name": "Disco Ball", "desc": "+1% chance for Chroma hats.", "pos": Vector2(1, 5), "max": 5, "cost": 100, "growth": 1.6, "cur": "rp", "parent": "luck", "cat": "luck"},
	{"id": "unlock_jackpot", "name": "High Roller", "desc": "UNLOCK: Jackpot rooms. Gamble chips or health for big prizes.", "pos": Vector2(-1, 5), "max": 1, "cost": 90, "growth": 1.0, "cur": "rp", "parent": "unlock_shop", "cat": "luck"},
	{"id": "shop_discount", "name": "Regular's Discount", "desc": "-10% Speakeasy prices.", "pos": Vector2(0, 6), "max": 3, "cost": 40, "growth": 1.6, "cur": "rp", "parent": "unlock_shop", "cat": "luck"},
	{"id": "reroll", "name": "Second Take", "desc": "+1 boon reroll per run (press R on a boon screen).", "pos": Vector2(3, 5), "max": 3, "cost": 70, "growth": 1.9, "cur": "rp", "parent": "boon_rarity", "cat": "luck"},
	{"id": "calibration", "name": "Calibration", "desc": "+15% bonus stats from your hat.", "pos": Vector2(-3, 5), "max": 5, "cost": 60, "growth": 1.7, "cur": "rp", "parent": "roster", "cat": "luck"},
	{"id": "pocket_change", "name": "Pocket Change", "desc": "Start each run with +20 Chips.", "pos": Vector2(-2, 6), "max": 5, "cost": 30, "growth": 1.5, "cur": "rp", "parent": "unlock_jackpot", "cat": "luck"},
	{"id": "start_boon", "name": "Warm-Up Act", "desc": "Begin every run with a free boon.", "pos": Vector2(3, 6), "max": 1, "cost": 3, "growth": 1.0, "cur": "rec", "parent": "reroll", "cat": "luck"},
]

# --- PERSISTENT STATE ---
var rhythm_points: int = 0
var gold_records: int = 0
var roster: Array = []
var equipped_hat_index: int = 0
var board: Dictionary = {"chassis": 1}
## Set when a run ends; the Back Room plays the changing-of-the-understudy once, then clears it.
var swap_pending: String = ""
var stats: Dictionary = {"runs": 0, "wins": 0, "deaths": 0, "kills": 0, "best_depth": 0, "bosses": 0}
var last_killer: String = ""
var pending_rolls: int = 0
var last_run: Dictionary = {}
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var tut: Dictionary = {}
var tokens: int = 0
var rolls_bought: int = 0
var skins_owned: Array = ["classic"]
var skin_id: String = "classic"
var hub_track: String = "hub"
var history: Array = []
var last_win: Dictionary = {}

const ROLL_PRICES = [50, 250, 500, 1000, 2000]

# Robot paint jobs, bought with Stage Tokens in the Dressing Room.
const SKINS = [
	{"id": "classic", "name": "Navy Classic", "desc": "Standard issue. Clean, sharp, forgettable.", "cost": 0,
		"body": Color(0.16, 0.2, 0.38), "head": Color(0.74, 0.77, 0.84), "eye": Color(0.5, 1.7, 2.2), "tie": Color(0.85, 0.12, 0.2), "limb": Color(0.55, 0.58, 0.65)},
	{"id": "rust", "name": "Rust Row Original", "desc": "Straight off the scrap line. Wear your roots.", "cost": 3,
		"body": Color(0.45, 0.22, 0.1), "head": Color(0.62, 0.45, 0.32), "eye": Color(1.8, 0.9, 0.3), "tie": Color(0.2, 0.5, 0.3), "limb": Color(0.5, 0.35, 0.25)},
	{"id": "mint", "name": "Mint Condition", "desc": "Never been dented. Yet.", "cost": 5,
		"body": Color(0.3, 0.62, 0.55), "head": Color(0.88, 0.94, 0.9), "eye": Color(0.4, 1.3, 1.9), "tie": Color(0.95, 0.9, 0.8), "limb": Color(0.7, 0.75, 0.72)},
	{"id": "tux", "name": "White Tuxedo", "desc": "For opening night at the Silver Dollar.", "cost": 6,
		"body": Color(0.9, 0.9, 0.87), "head": Color(0.8, 0.82, 0.86), "eye": Color(0.4, 1.2, 2.2), "tie": Color(0.05, 0.05, 0.06), "limb": Color(0.7, 0.7, 0.72)},
	{"id": "neon", "name": "Neon Nights", "desc": "Glows like the Alley after a rainstorm.", "cost": 8,
		"body": Color(0.12, 0.04, 0.18), "head": Color(0.3, 0.2, 0.4), "eye": Color(2.2, 0.4, 1.8), "tie": Color(0.3, 1.6, 2.0), "limb": Color(0.35, 0.25, 0.45)},
	{"id": "chrome", "name": "Chrome Crooner", "desc": "Polished to a mirror shine. Blinding under a spotlight.", "cost": 9,
		"body": Color(0.72, 0.77, 0.85), "head": Color(0.95, 0.97, 1.0), "eye": Color(0.3, 1.4, 2.4), "tie": Color(0.1, 0.2, 0.6), "limb": Color(0.85, 0.88, 0.95)},
	{"id": "casino", "name": "High Roller", "desc": "Red velvet and gold trim. The house hates it.", "cost": 10,
		"body": Color(0.6, 0.05, 0.1), "head": Color(0.85, 0.75, 0.55), "eye": Color(2.2, 1.7, 0.6), "tie": Color(1.4, 1.1, 0.4), "limb": Color(0.8, 0.65, 0.3)},
	{"id": "moon", "name": "Moonlight Serenade", "desc": "Pale blue, like the side of the Moon nobody sings about.", "cost": 12,
		"body": Color(0.25, 0.3, 0.48), "head": Color(0.86, 0.9, 1.0), "eye": Color(1.6, 1.6, 2.2), "tie": Color(1.4, 1.3, 0.6), "limb": Color(0.6, 0.65, 0.8)},
	{"id": "gold", "name": "Gold Record", "desc": "Only for robots who've gone platinum. Or saved up.", "cost": 15,
		"body": Color(0.85, 0.62, 0.18), "head": Color(1.1, 0.9, 0.45), "eye": Color(2.2, 1.6, 0.6), "tie": Color(0.5, 0.05, 0.1), "limb": Color(0.9, 0.7, 0.3)},
	{"id": "ghost", "name": "Ivory Phantom", "desc": "Half there. Haunts the high notes.", "cost": 18,
		"body": Color(0.85, 0.8, 1.0, 0.55), "head": Color(0.95, 0.92, 1.0, 0.6), "eye": Color(1.2, 0.9, 2.2), "tie": Color(0.6, 0.4, 1.4), "limb": Color(0.85, 0.8, 1.0, 0.5)},
]

# --- RUN STATE (reset each run) ---
var run: Dictionary = {}

var _hitstop_active: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_inputs()
	load_game()
	ensure_starter_hat()

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _bind(action: String, keys: Array):
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for k in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _setup_inputs():
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("attack", [KEY_J, KEY_Z])
	_bind("special", [KEY_K, KEY_X])
	_bind("cast", [KEY_L, KEY_C])
	_bind("dash", [KEY_SPACE, KEY_SHIFT])
	_bind("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER])
	_bind("pause", [KEY_ESCAPE])
	_bind("boon_list", [KEY_TAB])
	_bind("reroll", [KEY_R])
	_bind("debug_rp", [KEY_F9])
	# Shift+Q = give up (debug)
	if InputMap.has_action("skip_round"):
		InputMap.action_erase_events("skip_round")
	else:
		InputMap.add_action("skip_round")
	var q = InputEventKey.new()
	q.physical_keycode = KEY_Q
	q.shift_pressed = true
	InputMap.action_add_event("skip_round", q)

func _unhandled_input(event):
	if event.is_action_pressed("debug_rp"):
		rhythm_points += 500
		gold_records += 2
		save_game()
		print("[DEBUG] +500 RP, +2 Gold Records")

# ---------------------------------------------------------------------------
# HITSTOP
# ---------------------------------------------------------------------------
func hitstop(duration: float = 0.05, scale_val: float = 0.05):
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = scale_val
	var t = get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_active = false
	)

func reset_time():
	Engine.time_scale = 1.0
	_hitstop_active = false

# ---------------------------------------------------------------------------
# UPGRADE BOARD
# ---------------------------------------------------------------------------
func lvl(id: String) -> int:
	return int(board.get(id, 0))

func board_node(id: String) -> Dictionary:
	for n in BOARD:
		if n["id"] == id:
			return n
	return {}

func board_cost(id: String) -> int:
	var n = board_node(id)
	if n.is_empty():
		return 0
	var l = lvl(id)
	return int(round(float(n["cost"]) * pow(float(n["growth"]), float(l))))

## 0 = hidden, 1 = teaser (shown as ???), 2 = revealed
func board_visibility(id: String) -> int:
	var n = board_node(id)
	if n.is_empty():
		return 0
	if n["parent"] == "":
		return 2
	if lvl(n["parent"]) > 0:
		return 2
	var p = board_node(n["parent"])
	if not p.is_empty() and (p["parent"] == "" or lvl(p["parent"]) > 0):
		return 1
	return 0

func board_can_buy(id: String) -> bool:
	var n = board_node(id)
	if n.is_empty():
		return false
	if board_visibility(id) < 2:
		return false
	if lvl(id) >= int(n["max"]):
		return false
	var cost = board_cost(id)
	if n["cur"] == "rec":
		return gold_records >= cost
	return rhythm_points >= cost

func board_buy(id: String) -> bool:
	if not board_can_buy(id):
		return false
	var n = board_node(id)
	var cost = board_cost(id)
	if n["cur"] == "rec":
		gold_records -= cost
	else:
		rhythm_points -= cost
	board[id] = lvl(id) + 1
	save_game()
	return true

func board_total_levels() -> int:
	var t = 0
	for k in board.keys():
		t += int(board[k])
	return t

func board_max_levels() -> int:
	var t = 0
	for n in BOARD:
		t += int(n["max"])
	return t

func max_roster() -> int:
	return 3 + lvl("roster")

## Free Hat Rolls granted after each run.
func hat_rolls() -> int:
	return lvl("rolls")

## Price of the next PAID roll. Climbs each time you buy one; resets after every run.
func roll_cost() -> int:
	var base = 0
	if rolls_bought < ROLL_PRICES.size():
		base = ROLL_PRICES[rolls_bought]
	else:
		base = 2000 * (rolls_bought - 3)
	return int(round(float(base) * (1.0 - 0.15 * lvl("haggle"))))

func can_roll() -> bool:
	return pending_rolls > 0 or rhythm_points >= roll_cost()

## Spends a free roll if you have one, otherwise pays RP. Returns false if you can't afford it.
func consume_roll() -> bool:
	if pending_rolls > 0:
		pending_rolls -= 1
	elif rhythm_points >= roll_cost():
		rhythm_points -= roll_cost()
		rolls_bought += 1
	else:
		return false
	save_game()
	return true

func roll_label() -> String:
	if pending_rolls > 0:
		return "FREE (%d left)" % pending_rolls
	return "%d RP" % roll_cost()

func skin() -> Dictionary:
	for s in SKINS:
		if s["id"] == skin_id:
			return s
	return SKINS[0]


# ---------------------------------------------------------------------------
# HATS
# ---------------------------------------------------------------------------
func ensure_starter_hat():
	if roster.is_empty():
		var starter = {
			"material": "cardboard", "material_rarity": 0,
			"brim_material": "cardboard", "brim_rarity": 0,
			"band": "cotton", "band_rarity": 0,
			"addon": "paperclip", "addon_rarity": 0,
			"is_chroma": false, "total_stats": 10.0, "highest_rarity": 0,
			"name": "Cardboard Cutout", "name_v3": true
		}
		roster.append(starter)
		equipped_hat_index = 0
	if equipped_hat_index < 0 or equipped_hat_index >= roster.size():
		equipped_hat_index = 0

func get_equipped_hat() -> Dictionary:
	if equipped_hat_index >= 0 and equipped_hat_index < roster.size():
		return roster[equipped_hat_index]
	return {}

func roll_rarity() -> int:
	var luck_shift = lvl("luck") * 5
	var c_weight = maxi(10, RARITY_WEIGHTS[0] - luck_shift * 2)
	var r_weight = RARITY_WEIGHTS[1] + luck_shift
	var l_weight = RARITY_WEIGHTS[2] + luck_shift
	var total = c_weight + r_weight + l_weight
	var roll = randi() % total
	if roll < c_weight:
		return Rarity.COMMON
	elif roll < c_weight + r_weight:
		return Rarity.RARE
	return Rarity.LEGENDARY

func generate_hat() -> Dictionary:
	var mat_r = roll_rarity()
	var brim_r = roll_rarity()
	var band_r = roll_rarity()
	var addon_r = roll_rarity()

	var mat = MATERIALS[mat_r].pick_random()
	var brim_mat = MATERIALS[brim_r].pick_random()
	var band = BANDS[band_r].pick_random()
	var addon = ADDONS[addon_r].pick_random()

	var chroma_chance = CHROMA_CHANCE + lvl("chroma") * 0.01
	var is_chroma = randf() < chroma_chance
	var base_stats = float(mat[1] + brim_mat[1])
	var mult = 1.0 + (randf_range(0.5, 1.0) if is_chroma else 0.0)

	var hat = {
		"material": mat[0], "material_rarity": mat_r,
		"brim_material": brim_mat[0], "brim_rarity": brim_r,
		"band": band, "band_rarity": band_r,
		"addon": addon, "addon_rarity": addon_r,
		"is_chroma": is_chroma,
		"total_stats": base_stats * mult,
		"highest_rarity": maxi(maxi(mat_r, brim_r), maxi(band_r, addon_r))
	}
	hat["name"] = _make_hat_name(hat)
	hat["name_v3"] = true
	return hat

func _make_hat_name(hat: Dictionary) -> String:
	var mat = String(hat.get("material", "felt"))
	var band = String(hat.get("band", "cotton"))
	var addon = String(hat.get("addon", "paperclip"))
	var g = hat_grade_index(hat)
	var mw = String(MAT_WORDS.get(mat, ["Dapper"]).pick_random())
	var bn = String(BAND_NOUNS.get(band, ["Stitch"]).pick_random())
	var aw = String(ADDON_WORDS.get(addon, ["Lucky"]).pick_random())
	var noun = String(GRADE_NOUNS[g].pick_random())
	var n = ""
	var r = randf()
	if r < 0.22:
		n = "%s %s" % [mw, noun]                                   # Last-Call Crooner
	elif r < 0.40:
		n = "The %s %s" % [BAND_ADJ.get(band, "Dapper"), noun]     # The Live-Wire Maestro
	elif r < 0.58:
		n = "%s %s" % [mw, bn]                                     # Midnight Thunder
	elif r < 0.76:
		n = "%s %s" % [aw, noun]                                   # Snake-Eyes Kingpin
	else:
		n = "The %s of %s" % [noun, NAME_PLACES.pick_random()]      # The Duke of Basin Street
	if g == 3 and not n.contains(" of ") and n.length() < 22 and randf() < 0.5:
		n += " of the Moon"
	if hat.get("is_chroma", false):
		n = ("The Prismatic " + n.substr(4)) if n.begins_with("The ") else ("Prismatic " + n)
	return n

## Grade points: each part is 0 (common), 1 (rare) or 2 (legendary). Chroma adds 2.
func hat_points(hat: Dictionary) -> int:
	var p = int(hat.get("material_rarity", 0)) + int(hat.get("brim_rarity", 0)) + int(hat.get("band_rarity", 0)) + int(hat.get("addon_rarity", 0))
	if hat.get("is_chroma", false):
		p += 2
	return p

## 0 = C, 1 = B, 2 = A, 3 = S
func hat_grade_index(hat: Dictionary) -> int:
	var p = hat_points(hat)
	if p >= 6:
		return 3
	if p >= 4:
		return 2
	if p >= 2:
		return 1
	return 0

func hat_grade(hat: Dictionary) -> String:
	return GRADES[hat_grade_index(hat)]

func hat_grade_color(hat: Dictionary) -> Color:
	if hat.get("is_chroma", false):
		return Color(1.0, 0.6, 0.95)
	return GRADE_COLORS[hat_grade_index(hat)]

func hat_grade_label(hat: Dictionary) -> String:
	var l = "%s-GRADE" % hat_grade(hat)
	if hat.get("is_chroma", false):
		l = "CHROMA  " + l
	return l

func performer_at(i: int) -> String:
	var k = maxi(0, i)
	return "%s %s" % [PERF_FIRST[k % PERF_FIRST.size()], PERF_LAST[(k * 7 + int(k / PERF_FIRST.size()) * 3) % PERF_LAST.size()]]

## The understudy wearing the hat. In a run, offset 0 = tonight's star.
## Between runs, offset 1 = whoever is up next.
func performer(offset: int = 0) -> String:
	return performer_at(int(stats.get("runs", 0)) - 1 + offset)

## Kept for older call sites.
func unit_name(offset: int = 0) -> String:
	return performer(offset)

func hat_name(hat: Dictionary) -> String:
	if hat.has("name"):
		return String(hat["name"])
	return String(hat.get("material", "felt")).capitalize() + " Hat"

func hat_power_pct(hat: Dictionary) -> float:
	# Bonus % damage granted by a hat
	return float(hat.get("total_stats", 0.0)) * 0.6 * (1.0 + lvl("calibration") * 0.15)

func hat_bonus_hp(hat: Dictionary) -> int:
	var mr = int(hat.get("material_rarity", 0))
	var br = int(hat.get("brim_rarity", 0))
	var v = 5 + mr * 10 + br * 5
	if hat.get("is_chroma", false):
		v += 15
	return int(v * (1.0 + lvl("calibration") * 0.15))

func scrap_value(hat: Dictionary) -> int:
	var v = 5 + int(float(hat.get("total_stats", 0.0)) * 0.8) + hat_grade_index(hat) * 20
	if hat.get("is_chroma", false):
		v += 60
	return v

func get_rarity_color(r: int) -> Color:
	match r:
		Rarity.COMMON: return Color(0.72, 0.72, 0.75)
		Rarity.RARE: return Color(0.35, 0.6, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.65, 0.1)
	return Color.WHITE

func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
	return "?"

# ---------------------------------------------------------------------------
# RUN
# ---------------------------------------------------------------------------
func new_run():
	run = {
		"biome": 0,
		"room": 0,
		"depth": 0,
		"hp": -1.0,
		"bonus_max_hp": 0,
		"chips": 25 + 20 * lvl("pocket_change"),
		"rp": 0,
		"records": 0,
		"kills": 0,
		"bosses": 0,
		"boons": [],
		"mods": [],
		"rerolls": lvl("reroll"),
		"defiance": lvl("defiance"),
		"won": false,
		"time": 0.0,
		"shop_seen_in_biome": false,
		"hat": get_equipped_hat().duplicate(true),
	}
	stats["runs"] = int(stats.get("runs", 0)) + 1

func end_run(won: bool, killer: String):
	swap_pending = "won" if won else "lost"
	rhythm_points += int(run.get("rp", 0))
	gold_records += int(run.get("records", 0))
	stats["kills"] = int(stats.get("kills", 0)) + int(run.get("kills", 0))
	stats["bosses"] = int(stats.get("bosses", 0)) + int(run.get("bosses", 0))
	stats["best_depth"] = maxi(int(stats.get("best_depth", 0)), int(run.get("depth", 0)))
	if won:
		stats["wins"] = int(stats.get("wins", 0)) + 1
	else:
		stats["deaths"] = int(stats.get("deaths", 0)) + 1
	last_killer = killer
	pending_rolls += hat_rolls() + int(run.get("bosses", 0)) + (1 if won else 0)
	rolls_bought = 0
	var tk = 1 + int(int(run.get("depth", 0)) / 4.0) + 2 * int(run.get("bosses", 0)) + (3 if won else 0) + lvl("tip_tokens")
	tokens += tk
	last_run = run.duplicate(true)
	last_run["tokens"] = tk
	# Hall of Fame entry
	var entry = {
		"n": int(stats.get("runs", 0)), "name": performer(0), "won": won, "killer": killer,
		"depth": int(run.get("depth", 0)), "biome": int(run.get("biome", 0)), "room": int(run.get("room", 0)),
		"kills": int(run.get("kills", 0)), "rp": int(run.get("rp", 0)), "bosses": int(run.get("bosses", 0)),
		"time": float(run.get("time", 0.0)), "boons": run.get("boons", []).duplicate(true),
		"hat": run.get("hat", get_equipped_hat()).duplicate(true), "skin": skin_id,
	}
	history.append(entry)
	if won:
		last_win = entry.duplicate(true)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	last_run["won"] = won
	last_run["killer"] = killer
	save_game()

# ---------------------------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------------------------
func save_game():
	var data = {
		"version": 2,
		"rp": rhythm_points, "records": gold_records,
		"roster": roster, "equipped": equipped_hat_index,
		"board": board, "stats": stats,
		"pending_rolls": pending_rolls, "last_killer": last_killer,
		"music_volume": music_volume, "sfx_volume": sfx_volume,
		"tut": tut,
		"tokens": tokens, "rolls_bought": rolls_bought,
		"skins_owned": skins_owned, "skin": skin_id, "hub_track": hub_track,
		"history": history, "last_win": last_win,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game():
	var path = SAVE_PATH
	var legacy = false
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(OLD_SAVE_PATH):
			path = OLD_SAVE_PATH
			legacy = true
		else:
			return
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var d = json.data
	if typeof(d) != TYPE_DICTIONARY:
		return
	rhythm_points = int(d.get("rp", 0))
	equipped_hat_index = int(d.get("equipped", 0))
	roster = []
	for h in d.get("roster", []):
		if typeof(h) == TYPE_DICTIONARY:
			var hat = h
			for k in ["material_rarity", "brim_rarity", "band_rarity", "addon_rarity", "highest_rarity"]:
				hat[k] = int(hat.get(k, 0))
			if not hat.has("brim_material"):
				hat["brim_material"] = hat.get("material", "cardboard")
			if not hat.has("name_v3"):
				if String(hat.get("name", "")) != "Cardboard Cutout":
					hat["name"] = _make_hat_name(hat)
				hat["name_v3"] = true
			roster.append(hat)
	if legacy:
		return
	gold_records = int(d.get("records", 0))
	var b = d.get("board", {})
	board = {"chassis": 1}
	if typeof(b) == TYPE_DICTIONARY:
		for k in b.keys():
			board[String(k)] = int(b[k])
	var s = d.get("stats", {})
	if typeof(s) == TYPE_DICTIONARY:
		for k in s.keys():
			stats[String(k)] = int(s[k])
	pending_rolls = int(d.get("pending_rolls", 0))
	last_killer = String(d.get("last_killer", ""))
	music_volume = float(d.get("music_volume", 0.7))
	sfx_volume = float(d.get("sfx_volume", 0.8))
	tokens = int(d.get("tokens", 0))
	rolls_bought = int(d.get("rolls_bought", 0))
	var so = d.get("skins_owned", ["classic"])
	if typeof(so) == TYPE_ARRAY:
		skins_owned = []
		for x in so:
			skins_owned.append(String(x))
	if not skins_owned.has("classic"):
		skins_owned.append("classic")
	skin_id = String(d.get("skin", "classic"))
	hub_track = String(d.get("hub_track", "hub"))
	var lw = d.get("last_win", {})
	if typeof(lw) == TYPE_DICTIONARY:
		last_win = lw
	var hist = d.get("history", [])
	if typeof(hist) == TYPE_ARRAY:
		history = hist
	var tt = d.get("tut", {})
	if typeof(tt) == TYPE_DICTIONARY:
		tut = tt

## Returns true the FIRST time a tutorial key is asked for (then remembers it).
func tut_once(key: String) -> bool:
	if tut.get(key, false):
		return false
	tut[key] = true
	save_game()
	return true
