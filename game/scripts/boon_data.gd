extends RefCounted

## BoonData: static tables for Patrons (Hades-style gods), boons, hat kits and hat mods.
## Usage: const BoonData = preload("res://scripts/boon_data.gd")

const RARITY_NAMES = ["Common", "Rare", "Epic", "Heroic", "Duo", "Legendary"]
const RARITY_COLORS = [Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.3, 0.3), Color(0.75, 1.0, 0.35), Color(1.0, 0.6, 0.1)]
const RARITY_MULT = [1.0, 1.5, 2.0, 2.5, 1.0, 1.0]
## Boons stack with each other; taking one you already own levels it up, up to this cap.
const MAX_LEVEL = 3

# The Headliners: outsiders who made it to the Moon WITHOUT an empire hat.
# Strays, stokers and dark-side dreamers. Each wears headwear they made themselves,
# because the empires can't sell you what you make yourself. They love an underdog.
const PATRONS = {
	"luna": {"name": "Lady Luna", "title": "The Dark-Side Moth", "color": Color(0.55, 0.8, 1.0), "glyph": "☾", "status": "Chill",
		"species": "Moth-woman from the far side of the Moon", "from": "DARK-SIDE CRATERS",
		"story": "Grew up on the dark side, where no empire ever built a stage. She sang to empty craters until the cold itself learned to listen. Her headpiece is a crescent pin she filed out of a meteorite.",
		"lines": ["Keep it cool, darling. I sang to rocks for ten years. You'll do fine.", "No spotlight on the dark side. So I learned to glow.", "Slow and sweet, sugar. Let 'em shiver."]},
	"baron": {"name": "The Brass Baron", "title": "Stoker Turned Horn King", "color": Color(1.0, 0.55, 0.15), "glyph": "♨", "status": "Burn",
		"species": "Fire salamander from the Rust Row boiler rooms", "from": "RUST ROW BOILER ROOMS",
		"story": "Shovelled coal in the same factories that built you. He blew his first notes through a busted steam pipe. \"Baron\" is a joke title he gave himself, and now even the empires have to use it. Still wears his sooty stoker's cap.",
		"lines": ["I stoked boilers under your factory, kid. Now let's turn up the heat!", "They said a lizard can't play brass. Look who's the Baron now.", "Blow the roof off this joint!"]},
	"fortuna": {"name": "Madame Fortuna", "title": "The Stray Who Beat the House", "color": Color(0.3, 1.0, 0.55), "glyph": "♣", "status": "Crit",
		"species": "Black cat, alley card dealer", "from": "BACK-ALLEY CARD GAMES",
		"story": "A stray who dealt cards behind the Neon Alley dumpsters for fish heads. She's spent eight of her nine lives and won everything else, including a stake in the Moon's biggest casino. The green dealer's visor is the one she wore in the alley.",
		"lines": ["Eight lives down, tin man. I only bet on sure things now. Like you.", "The house always wins. Tonight, YOU'RE the house.", "Let it ride, sugar."]},
	"ivory": {"name": "The Ivory Ghost", "title": "The Eel of the Eighty-Eights", "color": Color(0.8, 0.6, 1.0), "glyph": "♪", "status": "Zap",
		"species": "Albino electric eel from Saturn's rings", "from": "A FLOODED SPEAKEASY",
		"story": "Washed down from Saturn's rings into a flooded speakeasy with one waterlogged piano. Every note he played sparked. The empires called him a hazard, so he played louder. He built his fishbowl helmet out of the bar's old punch bowl.",
		"lines": ["Every note strikes twice when you're made of lightning.", "They called me a fire hazard. I called it a light show.", "A little spark, a little swing."]},
	"bruno": {"name": "Big Bass Bruno", "title": "The Gentle Giant of the Low End", "color": Color(1.0, 0.3, 0.35), "glyph": "♜", "status": "Shock",
		"species": "Rhino, ex-piano mover", "from": "TENEMENT STAIRWELLS",
		"story": "Spent twenty years hauling other people's pianos up tenement stairs. One day he kept the upright bass. He knocks rooms flat without trying and apologises every time. His mother knitted the beanie.",
		"lines": ["I carried pianos for the big names. Now I carry the band. Let's go, pal.", "Knock 'em back to the cheap seats. Gently.", "Walk it like the bass line: one step at a time."]},
}

# The Tailor. Not a Headliner: the one who MAKES the hats.
const TAILOR = {"name": "Lady Loom", "title": "The Hatmaker in the Rafters", "color": Color(0.95, 0.78, 0.5), "glyph": "✂", "status": "Hat Mods",
	"species": "Eight-armed spider hatmaker", "from": "THE BLUE NOTE RAFTERS",
	"story": "She's lived in the Blue Note's rafters longer than the building has had a roof. Eight arms, no patience, the finest stitching in the solar system. She sewed THE hat out of scraps lifted from every empire's cutting-room floor, and she's the one who dropped it on a stagehand. Every hat in the Hat-O-Matic comes off her loom.",
	"lines": ["A little nip, a little tuck. Now THAT'S a hat.", "I dropped that hat on purpose, dearie. Don't make me regret it.", "Eight arms and not one of them has time for a crooked brim.", "The empires SELL hats. I MAKE them. There's a difference.", "Hold still. I've stitched on moving targets before, but I'd rather not."]}

## Headliner OR the Tailor, by id ("tailor").
static func character(pid: String) -> Dictionary:
	if pid == "tailor":
		return TAILOR
	return PATRONS.get(pid, {})

# slot: attack / special / cast / dash / passive / duo
# base: value at Common, Lv1. {v} is replaced with the scaled value.
const BOONS = {
	# ---- LADY LUNA (Chill) ----
	"luna_attack": {"patron": "luna", "slot": "attack", "name": "Moonlit Jab", "desc": "Attack deals +{v}% damage and inflicts Chill.", "base": 20.0},
	"luna_special": {"patron": "luna", "slot": "special", "name": "Crescent Toss", "desc": "Special deals +{v}% damage and inflicts Chill.", "base": 35.0},
	"luna_cast": {"patron": "luna", "slot": "cast", "name": "Eclipse", "desc": "Showstopper deals +{v}% damage and inflicts 3 Chill.", "base": 40.0},
	"luna_dash": {"patron": "luna", "slot": "dash", "name": "Moonwalk", "desc": "Dash leaves frost that deals {v} damage and Chills.", "base": 3.4},
	"luna_cold": {"patron": "luna", "slot": "passive", "name": "Cold Shoulder", "desc": "Chilled enemies take +{v}% damage.", "base": 12.0},
	"luna_full": {"patron": "luna", "slot": "passive", "name": "Full Moon", "desc": "+{v} max health.", "base": 20.0},
	"luna_blue": {"patron": "luna", "slot": "passive", "name": "Blue Moon", "desc": "Enemies at 5 Chill freeze solid for {v}s.", "base": 1.2, "needs": "luna"},

	# ---- THE BRASS BARON (Burn) ----
	"baron_attack": {"patron": "baron", "slot": "attack", "name": "Hot Lick", "desc": "Attack inflicts Burn for {v} damage/sec.", "base": 6.0},
	"baron_special": {"patron": "baron", "slot": "special", "name": "Blaring Solo", "desc": "Special inflicts Burn for {v} damage/sec.", "base": 12.0},
	"baron_cast": {"patron": "baron", "slot": "cast", "name": "Brass Blast", "desc": "Showstopper inflicts Burn for {v} damage/sec.", "base": 20.0},
	"baron_dash": {"patron": "baron", "slot": "dash", "name": "Blazing Exit", "desc": "Dash leaves a fire trail that Burns for {v}/sec.", "base": 2.7},
	"baron_five": {"patron": "baron", "slot": "passive", "name": "Five-Alarm", "desc": "Burn deals +{v}% damage.", "base": 30.0},
	"baron_streak": {"patron": "baron", "slot": "passive", "name": "Hot Streak", "desc": "Burning enemies explode on death for {v} damage.", "base": 25.0, "needs": "baron"},
	"baron_warm": {"patron": "baron", "slot": "passive", "name": "Warm Up", "desc": "+{v}% attack speed.", "base": 10.0},

	# ---- MADAME FORTUNA (Crit) ----
	"fortuna_attack": {"patron": "fortuna", "slot": "attack", "name": "Lucky Strike", "desc": "Attack has +{v}% critical chance.", "base": 12.0},
	"fortuna_special": {"patron": "fortuna", "slot": "special", "name": "All In", "desc": "Special has +{v}% critical chance.", "base": 20.0},
	"fortuna_cast": {"patron": "fortuna", "slot": "cast", "name": "Jackpot", "desc": "Showstopper has +{v}% critical chance.", "base": 30.0},
	"fortuna_dash": {"patron": "fortuna", "slot": "dash", "name": "Hedge Bet", "desc": "Your first hit after a dash deals +{v}% damage and has +33% crit chance.", "base": 13.0},
	"fortuna_tip": {"patron": "fortuna", "slot": "passive", "name": "Tip Money", "desc": "+{v}% Rhythm Points and Chips.", "base": 20.0},
	"fortuna_double": {"patron": "fortuna", "slot": "passive", "name": "Double Down", "desc": "Critical hits deal +{v}% damage.", "base": 30.0, "needs": "fortuna"},
	"fortuna_seven": {"patron": "fortuna", "slot": "passive", "name": "Lucky Seven", "desc": "{v}% chance to dodge any hit.", "base": 7.0},

	# ---- THE IVORY GHOST (Zap / chain) ----
	"ivory_attack": {"patron": "ivory", "slot": "attack", "name": "Arpeggio", "desc": "Attack zaps a nearby foe for {v} damage.", "base": 8.0},
	"ivory_special": {"patron": "ivory", "slot": "special", "name": "Glissando", "desc": "Special zaps up to 3 foes for {v} damage.", "base": 14.0},
	"ivory_cast": {"patron": "ivory", "slot": "cast", "name": "Crescendo", "desc": "Showstopper zaps every foe in the room for {v}.", "base": 22.0},
	"ivory_dash": {"patron": "ivory", "slot": "dash", "name": "Grace Note", "desc": "Dashing zaps the nearest foe for {v} damage.", "base": 5.0},
	"ivory_sustain": {"patron": "ivory", "slot": "passive", "name": "Sustain Pedal", "desc": "Zaps jump to {v} extra foes.", "base": 1.0, "needs": "ivory", "int": true},
	"ivory_high": {"patron": "ivory", "slot": "passive", "name": "High Note", "desc": "Zap damage +{v}%.", "base": 30.0},
	"ivory_stacc": {"patron": "ivory", "slot": "passive", "name": "Staccato", "desc": "Special recharges {v}% faster.", "base": 12.0},

	# ---- BIG BASS BRUNO (Knockback / shockwave) ----
	"bruno_attack": {"patron": "bruno", "slot": "attack", "name": "Heavy Groove", "desc": "Attack deals +{v}% damage with huge knockback.", "base": 25.0},
	"bruno_special": {"patron": "bruno", "slot": "special", "name": "Slap Bass", "desc": "Special hits cause a shockwave for {v} damage.", "base": 16.0},
	"bruno_cast": {"patron": "bruno", "slot": "cast", "name": "Drop the Bass", "desc": "Showstopper radius and damage +{v}%.", "base": 25.0},
	"bruno_dash": {"patron": "bruno", "slot": "dash", "name": "Bass Drop", "desc": "Dash ends in a shockwave for {v} damage.", "base": 5.4},
	"bruno_walk": {"patron": "bruno", "slot": "passive", "name": "Walking Bass", "desc": "+{v}% move speed.", "base": 8.0},
	"bruno_low": {"patron": "bruno", "slot": "passive", "name": "Low End", "desc": "+{v}% damage to bosses and elites.", "base": 20.0},
	"bruno_skin": {"patron": "bruno", "slot": "passive", "name": "Thick Skin", "desc": "Take {v}% less damage.", "base": 8.0},

	# ---- LEGENDARY BOONS (need 2 boons from that Headliner first) ----
	"luna_legend": {"patron": "luna", "slot": "legend", "name": "Dark Side of the Moon", "desc": "Chilled foes that die burst into frost: {v} damage and 2 Chill to everything nearby.", "base": 30.0},
	"baron_legend": {"patron": "baron", "slot": "legend", "name": "Wildfire", "desc": "Burning foes that die spread their Burn to every foe nearby, flaring for {v} damage.", "base": 20.0},
	"fortuna_legend": {"patron": "fortuna", "slot": "legend", "name": "Ninth Life", "desc": "Once per room, a lethal hit leaves you at {v}% health instead.", "base": 30.0},
	"ivory_legend": {"patron": "ivory", "slot": "legend", "name": "Thunderstorm Sonata", "desc": "Every 3rd Attack calls lightning down on the nearest foe for {v} damage.", "base": 35.0},
	"bruno_legend": {"patron": "bruno", "slot": "legend", "name": "Aftershock", "desc": "Your Showstopper echoes: two more expanding shockwaves for {v} damage each.", "base": 30.0},

	# ---- DUO BOONS (need boons from both patrons) ----
	"duo_steam": {"patron": "luna", "patron2": "baron", "slot": "duo", "name": "Steam Room", "desc": "Burn deals +{v}% damage to Chilled enemies.", "base": 60.0},
	"duo_circuit": {"patron": "fortuna", "patron2": "ivory", "slot": "duo", "name": "Lucky Circuit", "desc": "Zaps have a {v}% chance to crit.", "base": 25.0},
	"duo_boom": {"patron": "bruno", "patron2": "baron", "slot": "duo", "name": "Brass Boom", "desc": "Shockwaves inflict Burn for {v}/sec.", "base": 10.0},
	"duo_sonata": {"patron": "luna", "patron2": "ivory", "slot": "duo", "name": "Moonlight Sonata", "desc": "Zaps inflict Chill and deal +{v}% to Chilled foes.", "base": 30.0},
	"duo_bouncer": {"patron": "fortuna", "patron2": "bruno", "slot": "duo", "name": "Bouncer's Cut", "desc": "Critical hits cause a shockwave for {v} damage.", "base": 15.0},
	"duo_cabaret": {"patron": "luna", "patron2": "fortuna", "slot": "duo", "name": "Cabaret Moon", "desc": "+{v}% critical chance against Chilled foes.", "base": 20.0},
}

# ---------------------------------------------------------------------------
# HAT KITS: the band is your Attack, the add-on is your Special,
# the material is your Showstopper (Cast).
# ---------------------------------------------------------------------------
const BAND_KITS = {
	"cotton": {"name": "Snap Jab", "desc": "Quick 3-hit jab combo.", "style": "melee", "dmg": 1.0, "range": 64.0, "arc": 110.0, "rate": 0.26, "combo": 3, "finisher": ""},
	"houndstooth": {"name": "Checkered Flurry", "desc": "Blazing 4-hit flurry, short reach.", "style": "melee", "dmg": 0.72, "range": 56.0, "arc": 100.0, "rate": 0.17, "combo": 4, "finisher": ""},
	"pearl_strand": {"name": "Pearl Shot", "desc": "Flick pearls at range.", "style": "shot", "dmg": 0.8, "speed": 640.0, "rate": 0.3, "pierce": 0, "count": 1},
	"silk": {"name": "Silk Sweep", "desc": "Wide 180 degree sweeps.", "style": "melee", "dmg": 1.1, "range": 78.0, "arc": 180.0, "rate": 0.36, "combo": 3, "finisher": ""},
	"spiked": {"name": "Spike Spin", "desc": "Combo ends in a 360 degree spin.", "style": "melee", "dmg": 1.15, "range": 70.0, "arc": 120.0, "rate": 0.34, "combo": 3, "finisher": "spin"},
	"velvet_ribbon": {"name": "Velvet Lash", "desc": "Long, narrow whip strikes.", "style": "melee", "dmg": 1.05, "range": 118.0, "arc": 55.0, "rate": 0.33, "combo": 3, "finisher": ""},
	"brass_rivet": {"name": "Rivet Punch", "desc": "Slow, crushing haymakers.", "style": "melee", "dmg": 1.9, "range": 62.0, "arc": 90.0, "rate": 0.5, "combo": 2, "finisher": "knock"},
	"dynamo": {"name": "Dynamo Bolt", "desc": "Piercing electric bolts.", "style": "shot", "dmg": 0.95, "speed": 820.0, "rate": 0.32, "pierce": 2, "count": 1},
	"chrono": {"name": "Tick-Tock", "desc": "3rd hit stops time on the target.", "style": "melee", "dmg": 1.2, "range": 72.0, "arc": 120.0, "rate": 0.3, "combo": 3, "finisher": "stun"},
	"neon_magenta": {"name": "Neon Rattle", "desc": "Rapid-fire neon darts.", "style": "shot", "dmg": 0.55, "speed": 920.0, "rate": 0.13, "pierce": 0, "count": 1},
}

const ADDON_KITS = {
	"paperclip": {"name": "Paperclip Toss", "desc": "A bent clip that hits hard.", "kind": "proj", "dmg": 2.0, "cd": 1.5, "count": 1, "spread": 0.0, "speed": 600.0, "pierce": 1, "look": "clip"},
	"feather": {"name": "Feather Darts", "desc": "Three swift darts.", "kind": "proj", "dmg": 1.0, "cd": 1.6, "count": 3, "spread": 0.22, "speed": 760.0, "pierce": 0, "look": "feather"},
	"horseshoe": {"name": "Horseshoe 'Rang", "desc": "Boomerang that pierces everything.", "kind": "boomerang", "dmg": 1.6, "cd": 2.2, "speed": 560.0, "look": "horseshoe"},
	"playing_card": {"name": "Card Fan", "desc": "A fan of five razor cards.", "kind": "proj", "dmg": 0.9, "cd": 2.0, "count": 5, "spread": 0.18, "speed": 640.0, "pierce": 0, "look": "card"},
	"matchstick": {"name": "Molotov Match", "desc": "Lob a flame that leaves fire.", "kind": "lob_fire", "dmg": 1.3, "cd": 3.0, "look": "match"},
	"harmonica": {"name": "Blues Blast", "desc": "A cone of sound that shoves foes.", "kind": "cone", "dmg": 1.5, "cd": 2.4, "look": "wave"},
	"poker_chip": {"name": "Chip Ricochet", "desc": "Bounces between up to 4 foes.", "kind": "ricochet", "dmg": 1.4, "cd": 2.2, "speed": 700.0, "look": "chip"},
	"fuzzy_dice": {"name": "Roll the Dice", "desc": "Two dice. Damage is 1 to 6 times luck.", "kind": "dice", "dmg": 0.6, "cd": 2.0, "speed": 580.0, "look": "dice"},
	"golden_coin": {"name": "Coin Flip", "desc": "Piercing coin. Kills drop bonus RP.", "kind": "proj", "dmg": 2.5, "cd": 2.4, "count": 1, "spread": 0.0, "speed": 900.0, "pierce": 99, "look": "coin"},
	"bullet_casing": {"name": "Tommy Burst", "desc": "Six-shot burst of lead.", "kind": "burst", "dmg": 0.6, "cd": 2.6, "count": 6, "speed": 950.0, "look": "bullet"},
}

const MAT_KITS = {
	"cardboard": {"name": "Cardboard Crash", "desc": "Hat slam shockwave.", "radius": 150.0, "dmg": 3.0, "cd": 10.0, "extra": ""},
	"straw": {"name": "Hay Tornado", "desc": "Slam that pulls foes in.", "radius": 175.0, "dmg": 2.3, "cd": 9.0, "extra": "pull"},
	"tweed": {"name": "Tweed Thunder", "desc": "Slam that stuns for 1s.", "radius": 185.0, "dmg": 2.6, "cd": 10.0, "extra": "stun"},
	"pinstripe": {"name": "Pinstripe Hit", "desc": "Slam with +25% crit chance.", "radius": 160.0, "dmg": 3.4, "cd": 10.0, "extra": "crit"},
	"felt": {"name": "Felt Finale", "desc": "Slam that heals you 8 HP.", "radius": 200.0, "dmg": 3.0, "cd": 11.0, "extra": "heal"},
	"leather": {"name": "Leather Stomp", "desc": "Huge slam, massive knockback.", "radius": 220.0, "dmg": 3.2, "cd": 11.0, "extra": "knock"},
	"copper": {"name": "Copper Coil", "desc": "Slam that zaps everyone hit.", "radius": 200.0, "dmg": 2.6, "cd": 10.0, "extra": "zap"},
	"titanium": {"name": "Titanium Drop", "desc": "Crushing slam + 1.5s invulnerability.", "radius": 180.0, "dmg": 5.0, "cd": 12.0, "extra": "invuln"},
	"velvet": {"name": "Velvet Curtain", "desc": "Enormous slam that Chills.", "radius": 260.0, "dmg": 2.8, "cd": 11.0, "extra": "chill"},
	"patent_leather": {"name": "Spotlight", "desc": "Blinding slam that Burns.", "radius": 240.0, "dmg": 4.0, "cd": 12.0, "extra": "burn"},
}

# The Tailor (like Daedalus): permanent-for-this-run hat tweaks
const HAT_MODS = {
	"wide_brim": {"name": "Wider Brim", "desc": "Attack range +30%."},
	"quick_stitch": {"name": "Quick Stitch", "desc": "Attack speed +20%."},
	"deep_pockets": {"name": "Deep Pockets", "desc": "Special recharges 30% faster."},
	"loaded_lining": {"name": "Loaded Lining", "desc": "Special damage +50%."},
	"grand_finale": {"name": "Grand Finale", "desc": "Showstopper radius +35%."},
	"encore_band": {"name": "Encore Band", "desc": "Showstopper recharges 35% faster."},
	"steel_toe": {"name": "Steel Toes", "desc": "Dashing through foes deals 25 damage."},
	"silk_lining": {"name": "Silk Lining", "desc": "+1 dash charge."},
	"lucky_label": {"name": "Lucky Label", "desc": "+10% critical chance."},
	"heavy_crown": {"name": "Heavy Crown", "desc": "Attack damage +30%."},
}

static func boon_value(id: String, rarity: int, level: int) -> float:
	var b = BOONS.get(id, {})
	if b.is_empty():
		return 0.0
	var base = float(b["base"])
	var v = base * RARITY_MULT[clampi(rarity, 0, 5)] * (1.0 + 0.6 * float(level - 1))
	if b.get("int", false):
		return float(maxi(1, int(round(base + float(level - 1) * 0.5 + (1.0 if rarity >= 2 else 0.0)))))
	if id == "luna_blue":
		return snappedf(v, 0.1)
	return float(round(v))

static func boon_desc(id: String, rarity: int, level: int) -> String:
	var b = BOONS.get(id, {})
	if b.is_empty():
		return ""
	var v = boon_value(id, rarity, level)
	var vs = ""
	if absf(v - round(v)) > 0.01:
		vs = "%.1f" % v
	else:
		vs = str(int(v))
	return String(b["desc"]).replace("{v}", vs)

static func roll_boon_rarity(luck_level: int) -> int:
	var shift = luck_level * 5
	var w = [maxi(15, 58 - shift * 2), 28 + shift, 11 + int(shift * 0.6), 3 + int(shift * 0.4)]
	var total = 0
	for x in w:
		total += x
	var r = randi() % total
	var acc = 0
	for i in range(4):
		acc += w[i]
		if r < acc:
			return i
	return 0

static func owned_ids(owned: Array) -> Array:
	var ids = []
	for o in owned:
		ids.append(o["id"])
	return ids

static func has_patron(owned: Array, patron: String) -> bool:
	for o in owned:
		var b = BOONS.get(o["id"], {})
		if b.get("patron", "") == patron or b.get("patron2", "") == patron:
			return true
	return false

## Returns up to `count` offers: [{id, rarity, upgrade?, level}]
## Offers mix NEW boons (they stack with what you have) and LEVEL-UPS of boons you own.
static func offer_boons(patron: String, owned: Array, luck_level: int, count: int = 3) -> Array:
	var lv = {}
	var rar = {}
	var owned_slots = {}
	for o in owned:
		lv[o["id"]] = int(o["level"])
		rar[o["id"]] = int(o["rarity"])
		owned_slots[String(BOONS.get(o["id"], {}).get("slot", ""))] = true
	var fresh_slot = []
	var fresh_passive = []
	var upgrades = []
	var duos = []
	var legends = []
	for id in BOONS.keys():
		var b = BOONS[id]
		if b["slot"] == "legend":
			if b["patron"] != patron:
				continue
			if lv.has(id):
				if int(lv[id]) < MAX_LEVEL:
					upgrades.append(id)
			elif count_patron(owned, patron) >= 2:
				legends.append(id)
			continue
		if b["slot"] == "duo":
			if (b["patron"] == patron or b["patron2"] == patron) and has_patron(owned, b["patron"]) and has_patron(owned, b["patron2"]):
				if not lv.has(id):
					duos.append(id)
				elif int(lv[id]) < MAX_LEVEL:
					upgrades.append(id)
			continue
		if b["patron"] != patron:
			continue
		if lv.has(id):
			if int(lv[id]) < MAX_LEVEL:
				upgrades.append(id)
			continue
		if b.has("needs") and not has_patron(owned, String(b["needs"])):
			continue
		if b["slot"] == "passive":
			fresh_passive.append(id)
		else:
			fresh_slot.append(id)
	fresh_slot.shuffle()
	fresh_passive.shuffle()
	upgrades.shuffle()
	duos.shuffle()
	var picks = []
	var used = {}
	if not legends.is_empty() and randf() < 0.4:
		picks.append({"id": legends[0], "rarity": 5, "upgrade": false, "level": 1})
		used[legends[0]] = true
	if not duos.is_empty() and randf() < 0.45:
		picks.append({"id": duos[0], "rarity": 4, "upgrade": false, "level": 1})
		used[duos[0]] = true
	# a boon for a slot you haven't powered yet
	for id in fresh_slot:
		if not owned_slots.has(BOONS[id]["slot"]):
			picks.append({"id": id, "rarity": roll_boon_rarity(luck_level), "upgrade": false, "level": 1})
			used[id] = true
			break
	# a level-up of something you already love
	if not upgrades.is_empty() and randf() < 0.65:
		var uid = upgrades[0]
		picks.append({"id": uid, "rarity": int(rar[uid]), "upgrade": true, "level": int(lv[uid]) + 1})
		used[uid] = true
	var pool = []
	for id in fresh_slot:
		if not used.has(id):
			pool.append(id)
	for id in fresh_passive:
		pool.append(id)
	for id in upgrades:
		if not used.has(id):
			pool.append(id)
	pool.shuffle()
	for id in pool:
		if picks.size() >= count:
			break
		if lv.has(id):
			picks.append({"id": id, "rarity": int(rar[id]), "upgrade": true, "level": int(lv[id]) + 1})
		else:
			picks.append({"id": id, "rarity": roll_boon_rarity(luck_level), "upgrade": false, "level": 1})
	picks = picks.slice(0, count)
	picks.shuffle()
	return picks

## How many (non-duo) boons you own from one Headliner.
static func count_patron(owned: Array, patron: String) -> int:
	var n = 0
	for o in owned:
		var b = BOONS.get(o["id"], {})
		if b.get("patron", "") == patron and b.get("slot", "") != "duo":
			n += 1
	return n

static func slot_label(slot: String) -> String:
	match slot:
		"legend": return "LEGENDARY"
		"attack": return "ATTACK"
		"special": return "SPECIAL"
		"cast": return "SHOWSTOPPER"
		"dash": return "DASH"
		"passive": return "PASSIVE"
		"duo": return "DUO"
	return slot.to_upper()

static func patron_color(id: String) -> Color:
	var b = BOONS.get(id, {})
	var p = PATRONS.get(b.get("patron", ""), {})
	return p.get("color", Color.WHITE)
