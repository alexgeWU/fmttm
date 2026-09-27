extends RefCounted

## WorldData: biomes, enemy archetypes and bosses.
## Usage: const WorldData = preload("res://scripts/world_data.gd")

const BIOMES = [
	{
		"id": "bar", "name": "The Smoky Bar", "sub": "Rust Row's biggest stage. The Bowler Brotherhood runs the door.",
		"rooms": 4, "boss": "big_sal",
		"ambient": Color(0.62, 0.55, 0.5), "music": "bar",
		"floor_a": Color(0.23, 0.14, 0.09), "floor_b": Color(0.27, 0.17, 0.1),
		"wall": Color(0.14, 0.08, 0.06), "accent": Color(1.0, 0.72, 0.35),
		"light": Color(1.0, 0.7, 0.4),
		"pool": [["barfly", 5, 0], ["bouncer", 4, 0], ["paparazzi", 3, 1], ["bottler", 3, 2]],
		"elite": "bouncer",
	},
	{
		"id": "alley", "name": "The Neon Alley", "sub": "The smuggler's road to the launch pads. Trilby Syndicate turf.",
		"rooms": 4, "boss": "getaway_car",
		"ambient": Color(0.42, 0.45, 0.62), "music": "alley",
		"floor_a": Color(0.11, 0.12, 0.17), "floor_b": Color(0.13, 0.14, 0.2),
		"wall": Color(0.2, 0.1, 0.12), "accent": Color(1.0, 0.25, 0.75),
		"light": Color(1.0, 0.3, 0.85),
		"pool": [["street_rat", 5, 0], ["alley_cat", 4, 0], ["paparazzi", 2, 0], ["sax_ghoul", 3, 1], ["firebug", 3, 2]],
		"elite": "alley_cat",
	},
	{
		"id": "casino", "name": "The Grand Casino", "sub": "The Silver Dollar, in orbit. Top Hat Records runs the house.",
		"rooms": 4, "boss": "big_band",
		"ambient": Color(0.6, 0.5, 0.48), "music": "casino",
		"floor_a": Color(0.36, 0.05, 0.08), "floor_b": Color(0.42, 0.07, 0.1),
		"wall": Color(0.16, 0.1, 0.04), "accent": Color(1.0, 0.82, 0.3),
		"light": Color(1.0, 0.85, 0.5),
		"pool": [["card_sharp", 4, 0], ["loaded_die", 3, 0], ["slot_bot", 2, 1], ["conductor", 2, 1], ["pit_boss", 2, 2]],
		"elite": "pit_boss",
	},
	{
		"id": "moon", "name": "The Moon", "sub": "Luna City. The Lunar Hat Empire's stage. Break a leg, Tin Eyes.",
		"rooms": 4, "boss": "moon_man",
		"ambient": Color(0.5, 0.55, 0.7), "music": "moon",
		"floor_a": Color(0.42, 0.43, 0.48), "floor_b": Color(0.47, 0.48, 0.53),
		"wall": Color(0.02, 0.02, 0.06), "accent": Color(0.7, 0.85, 1.0),
		"light": Color(0.75, 0.85, 1.0),
		"pool": [["star_sprite", 4, 0], ["moon_rock", 3, 0], ["comet", 3, 0], ["satellite", 2, 0]],
		"elite": "moon_rock",
	},
]

# beh: swarm / brute / shooter / lobber / charger / bomber / turret / support / die
const ENEMIES = {
	# --- The Smoky Bar ---
	"barfly": {"name": "Barfly", "hp": 16.0, "speed": 125.0, "dmg": 6.0, "radius": 10.0, "beh": "swarm", "rp": 1, "cost": 1, "fly": true, "color": Color(0.55, 0.75, 0.4), "lore": "Rust Row regulars. Buzz in, bite, buzz off."},
	"bouncer": {"name": "Bouncer", "hp": 95.0, "speed": 72.0, "dmg": 14.0, "radius": 18.0, "beh": "brute", "rp": 4, "cost": 3, "color": Color(0.3, 0.1, 0.12), "lore": "Sal's muscle. Winds up a slam, so get out of the red circle."},
	"paparazzi": {"name": "Paparazzo", "hp": 42.0, "speed": 100.0, "dmg": 9.0, "radius": 13.0, "beh": "shooter", "shot": "flash", "rp": 3, "cost": 2, "color": Color(0.55, 0.45, 0.3), "lore": "Hired flashbulbs who snitch for every empire. The bulb glints right before the shot."},
	"bottler": {"name": "Bottle Tosser", "hp": 55.0, "speed": 60.0, "dmg": 12.0, "radius": 14.0, "beh": "lobber", "rp": 3, "cost": 2, "color": Color(0.85, 0.85, 0.8), "lore": "Serves last call at high speed. Watch for landing circles."},
	# --- The Neon Alley ---
	"street_rat": {"name": "Street Rat", "hp": 20.0, "speed": 150.0, "dmg": 7.0, "radius": 9.0, "beh": "swarm", "rp": 1, "cost": 1, "color": Color(0.45, 0.42, 0.45), "lore": "They run the Alley in packs. Weak, fast, everywhere."},
	"alley_cat": {"name": "Alley Cat", "hp": 48.0, "speed": 110.0, "dmg": 13.0, "radius": 12.0, "beh": "charger", "rp": 3, "cost": 2, "color": Color(0.12, 0.12, 0.14), "lore": "Crouches, glows, then pounces in a straight line. Step aside."},
	"sax_ghoul": {"name": "Sax Phantom", "hp": 70.0, "speed": 70.0, "dmg": 10.0, "radius": 15.0, "beh": "shooter", "shot": "ring", "rp": 4, "cost": 3, "color": Color(0.5, 0.9, 1.0), "lore": "The ghost of a busker who never got his break. Blows rings of notes."},
	"firebug": {"name": "Firebug", "hp": 45.0, "speed": 105.0, "dmg": 20.0, "radius": 13.0, "beh": "bomber", "rp": 3, "cost": 2, "color": Color(1.0, 0.45, 0.1), "lore": "Runs at you, lights up, explodes. Don't let it get close."},
	# --- The Grand Casino ---
	"card_sharp": {"name": "Card Sharp", "hp": 80.0, "speed": 90.0, "dmg": 12.0, "radius": 14.0, "beh": "shooter", "shot": "fan", "rp": 4, "cost": 3, "color": Color(0.1, 0.35, 0.2), "lore": "Top Hat Records' dealers. Throw fans of cards."},
	"loaded_die": {"name": "Loaded Die", "hp": 85.0, "speed": 250.0, "dmg": 14.0, "radius": 16.0, "beh": "die", "rp": 4, "cost": 3, "color": Color(0.95, 0.95, 0.95), "lore": "Bounces off walls, then fires as many shots as it rolls."},
	"slot_bot": {"name": "Slot Bot", "hp": 150.0, "speed": 0.0, "dmg": 10.0, "radius": 20.0, "beh": "turret", "rp": 6, "cost": 4, "color": Color(0.8, 0.15, 0.2), "lore": "Spins up and sprays chips in a spiral. Never moves."},
	"conductor": {"name": "The Conductor", "hp": 90.0, "speed": 85.0, "dmg": 8.0, "radius": 14.0, "beh": "support", "rp": 5, "cost": 3, "color": Color(0.08, 0.08, 0.1), "lore": "Speeds up everyone around him. Take him out first."},
	"pit_boss": {"name": "Pit Boss", "hp": 230.0, "speed": 76.0, "dmg": 20.0, "radius": 22.0, "beh": "brute", "rp": 8, "cost": 5, "color": Color(0.2, 0.2, 0.25), "lore": "The casino's enforcer. A bigger, meaner slam."},
	# --- The Moon ---
	"star_sprite": {"name": "Star Sprite", "hp": 38.0, "speed": 160.0, "dmg": 9.0, "radius": 10.0, "beh": "swarm", "rp": 2, "cost": 1, "fly": true, "color": Color(1.0, 0.95, 0.5), "lore": "Tiny stars on the Chairman's payroll. Dangerous in swarms."},
	"moon_rock": {"name": "Moon Golem", "hp": 180.0, "speed": 62.0, "dmg": 20.0, "radius": 21.0, "beh": "brute", "rp": 7, "cost": 4, "color": Color(0.6, 0.6, 0.66), "lore": "Lunar golems. Slow and heavy."},
	"comet": {"name": "Comet", "hp": 70.0, "speed": 120.0, "dmg": 16.0, "radius": 13.0, "beh": "charger", "rp": 4, "cost": 2, "color": Color(0.5, 0.85, 1.0), "lore": "Charges in a line. Sidestep the tail."},
	"satellite": {"name": "Satellite", "hp": 140.0, "speed": 40.0, "dmg": 12.0, "radius": 18.0, "beh": "turret", "rp": 6, "cost": 4, "fly": true, "color": Color(0.8, 0.8, 0.85), "lore": "Drifts overhead firing bursts. Hard to pin down."},
}

const BOSSES = {
	"big_sal": {"name": "BIG SAL", "title": "Boss of the Bowler Brotherhood", "hp": 900.0, "rec": 1,
		"empire": "The Bowler Brotherhood", "home": "The Smoky Bar",
		"lore": "Sal owns every stage door on Rust Row. Robots sweep, robots fetch, robots never sing. Not on his watch.",
		"quote": "\"Tin cans don't headline, pal. Grab a broom.\"",
		"tip": "TELLS: red circle = slam.  Glowing lane = bull rush.  Make him hit a wall, then punish."},
	"getaway_car": {"name": "THE GETAWAY", "title": "Wheels of the Trilby Syndicate", "hp": 1400.0, "rec": 2,
		"empire": "The Trilby Syndicate", "home": "The Neon Alley",
		"lore": "The Syndicate smuggles knock-off hats up the Neon Alley to the launch pads. Their '52 sedan runs anybody off the road who won't pay the toll.",
		"quote": "\"Nobody rides the rocket without paying the toll!\"",
		"tip": "TELLS: headlight lane = it's about to floor it.  You can dash straight through bullets."},
	"big_band": {"name": "THE BIG BAND", "title": "House Band of Top Hat Records", "hp": 2000.0, "rec": 3,
		"empire": "Top Hat Records", "home": "The Grand Casino",
		"lore": "The Silver Dollar casino orbits halfway to the Moon. Top Hat Records owns the joint, and its Jukebox only plays their hits. Want passage? Beat the house.",
		"quote": "\"THIS JOINT ONLY PLAYS OUR SONGS.\"",
		"tip": "TELLS: it never moves.  Glowing lanes blast after a beat.  Weave through the note gaps."},
	"moon_man": {"name": "THE MAN IN THE MOON", "title": "The Chairman of the Lunar Hat Empire", "hp": 3000.0, "rec": 5,
		"empire": "The Lunar Hat Empire", "home": "The Moon",
		"lore": "He wears the tallest hat in the sky and decides who headlines the Moon. Every hat empire answers to him. No robot has ever played his stage.",
		"quote": "\"A robot? On MY stage? Let's hear you sing, tin man.\"",
		"tip": "TELLS: floor shadows are meteors.  Beams fire down their lane after the warning."},
}

const WORLD_LORE = [
	["RUST ROW, EARTH", "Down in Rust Row, the factories stamp out wind-up robots by the thousand. Cheap, loyal, built to sweep stages and carry drinks. Nobody asks what they dream about."],
	["THE MOON", "Up above, the Moon glitters like a casino chip. Luna City is where legends play, and every stage up there is owned by the HAT EMPIRES: rich cartels who decide who gets a spotlight by who wears their hats."],
	["THE RULE", "Robots don't wear hats. Robots don't sing. That was the rule, until a hat fell from the rafters of the Blue Note and landed on a stagehand named Rivet Fontaine."],
	["THE HATMAKER", "Up in the Blue Note's rafters lives Lady Loom, an eight-armed spider hatmaker with the finest stitching in the solar system. She sewed THE hat out of scraps lifted from every empire's cutting-room floor, and she dropped it on that stagehand on purpose. Every hat in the Hat-O-Matic comes off her loom, and in Tailor rooms she drops down on a thread to re-stitch yours."],
	["THE BACK ROOM", "By night the Blue Note belongs to the hat empires' acts: hats on, robots out. After closing, the robots who sweep the floors lock the doors and take the stage themselves. That's the Back Room, the only stage on Earth where a robot can play. The house band, Slim, Ruby Rimshot and Doc, plays hatless, because hats are what the empires sell. Only THE hat goes on the road."],
	["THE UNDERSTUDIES", "Ol' Tin Eyes isn't one robot. It's the act. Rivet Fontaine was the first to wear the hat. Most T-1Ns on Rust Row are happy to sweep, but a small crew in the Back Room dreams of the big stages, and every one of them learned the songs, the steps and the swagger. They work as one: whoever wears the hat IS Ol' Tin Eyes. When one takes a bow, the next understudy steps into the hat and the show goes on. The band in the lounge keeps the stage warm for whoever's next."],
	["THE ROUTE", "Four stops, four hat empires: the Bowler Brotherhood's Smoky Bar, the Trilby Syndicate's Neon Alley, Top Hat Records' Grand Casino and the Lunar Hat Empire's Moon. Every stop plays the same: 4 rooms, then the boss."],
	["THE HEADLINERS", "Nobody handed them a hat either. A moth-woman who sang to empty craters on the Moon's dark side. A salamander who stoked Rust Row's boilers. A stray cat who dealt cards behind the Alley dumpsters. An electric eel who washed down from Saturn into a flooded speakeasy. A rhino who hauled other people's pianos. They clawed their way to the Moon without an empire, and they love an underdog. Win their favor mid-show and they'll lend you their tricks."],
]

const ROOM_INFO = [
	["combat", "Fight Room", "Clear every wave. The reward shown on the door you picked appears when the room is clear."],
	["elite", "Elite Fight", "Tougher enemies with gold crowns. Clearing one tips extra Chips on top of the door's reward."],
	["shop", "The Speakeasy", "Spend Chips on boons, drinks and hat mods. Unlocked by the Speakeasy Password upgrade."],
	["rest", "The Powder Room", "A champagne fountain heals 40% health. Always offered right before a boss."],
	["jackpot", "Jackpot Room", "Pull the slot machine for Chips, RP, a full heal or a Heroic boon. Or bust. Unlocked by High Roller."],
	["boss", "Boss Stage", "A hat empire's champion. Win Gold Records, a pile of Chips, a free Hat Roll and the road to the next area."],
]

const REWARD_INFO = [
	["boon", "Boon", "A Headliner offers 3 powers for this run."],
	["encore", "Encore", "Level up a boon you own. Unlocked by the Encore! upgrade. This run only."],
	["hat_mod", "Lady Loom, the Tailor", "The hatmaker herself drops down from the rafters to re-stitch your hat for this run: longer reach, faster specials, an extra dash and more."],
	["rp", "Rhythm Points", "The permanent currency. Spend it on The Setlist and on Hat Rolls. You keep it all when you fall."],
	["chips", "Chips", "Run-only cash for the Speakeasy and Jackpot rooms. Gone when the run ends."],
	["martini", "Dirty Martini", "+15 max health for the rest of the run."],
	["records", "Gold Record", "Rare permanent currency from bosses, for the Setlist's best upgrades."],
]

# Boss attack callouts: [name, how-to-dodge hint]
const BOSS_ATTACKS = {
	"big_sal": {
		"stomp": ["GROUND POUND", "Leave the red circle, then dodge the bottle caps."],
		"charge": ["BULL RUSH", "Sidestep the lane. If he hits a wall he gets dizzy!"],
		"bottles": ["LAST CALL", "Bottles land on the circles. Keep moving."],
		"backup": ["BOUNCERS!", "He's calling friends. Clear the adds fast."],
		"dizzy": ["DIZZY!", "Free hits. Unload everything!"],
	},
	"getaway_car": {
		"drive": ["FLOOR IT", "Get out of the headlight lane!"],
		"tommy": ["TOMMY GUN", "Bullet fans. Dash through them or circle wide."],
		"horn": ["HONK!", "Leave the circle, then dash the bullet ring."],
		"goons": ["DROP-OFF", "Street rats incoming. Keep them off you."],
		"molotov": ["MOLOTOVS", "Fire pools linger. Don't stand in them."],
	},
	"big_band": {
		"spiral": ["SPIRAL SOLO", "Walk around the jukebox with the spiral, stay in the gaps."],
		"records": ["BROKEN RECORDS", "Records bounce off walls. Watch the rebound."],
		"walls": ["WALL OF SOUND", "Stand clear of the glowing lanes."],
		"rings": ["THREE-RING BRASS", "Expanding rings. Slip through a gap."],
		"encore": ["ENCORE!", "Backup acts join. Take them out quick."],
	},
	"moon_man": {
		"meteors": ["METEOR SHOWER", "Keep moving. Every shadow is a rock."],
		"beam": ["MOONBEAM", "Get out of the lane before it fires."],
		"starfall": ["STARFALL", "Two star rings. Find the gap, then dash."],
		"crescents": ["CRESCENTS", "They home in briefly. Outrun, then sidestep."],
		"summon": ["STARDUST", "Star Sprites swarm. Sweep them up."],
	},
}

const BARTENDER_LINES = [
	"Back already? The stage misses you, pal.",
	"Word is Big Sal hasn't let anybody out since '49.",
	"That hat's doing all the talking. Let it.",
	"The Headliners are watching. Play it cool.",
	"Chips spend in the Speakeasy. Rhythm Points spend here.",
	"You die, you roll. That's showbiz, kid.",
	"They say the moon's got the best acoustics in the universe.",
	"Every hat's got a story. Yours is just starting.",
	"Tip Jar's a smart buy. Money makes the band play.",
	"The Jukebox in the casino? Stay out of its rhythm.",
	"Another understudy in the hat? Suits ya, Tin Eyes.",
	"The show must go on. That's the only rule on Rust Row now.",
	"Tilt that hat, kid. A crooner never wears it straight.",
	"Ring-a-ding, pal! Look at you, all dressed up.",
	"Swing it, don't sling it. Timing's everything.",
	"Big Sal charges like a freight train. Let him kiss the wall.",
	"That getaway car can't turn worth a nickel. Sidestep it.",
	"The Headliners like a performer with style. Mix their favors.",
	"Nobody leaves the Blue Note without an encore.",
]

static func biome(i: int) -> Dictionary:
	return BIOMES[clampi(i, 0, BIOMES.size() - 1)]
