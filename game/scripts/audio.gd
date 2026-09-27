extends Node

## Sfx (autoload): every sound effect is synthesized at startup.
##
## MUSIC is a live jazz combo built as a SAMPLER: instruments (upright bass, Rhodes,
## tenor sax, vibes, brass section, ride, brushes, kick, snare) are rendered once,
## then a swing sequencer triggers them as notes through a Music bus with reverb,
## tape echo and stereo spread (Godot's mixer does the heavy lifting).
## Harmony: a circle-of-fifths turnaround. The lead improvises ORIGINAL blues phrases.
##
## DROP-IN SONGS: put licensed audio in res://audio/music/ and it replaces the combo.
##   <mode>.ogg / .mp3 / .wav   modes: menu hub bar alley casino moon boss gacha victory
##   theme.ogg (or .mp3/.wav) is used as a fallback for menu, hub, gacha and victory.

const MIX_RATE = 22050.0
const POOL_SIZE = 14
const MPOOL_SIZE = 30

var sounds: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _last_play: Dictionary = {}

# --- music ---
var inst: Dictionary = {}
var _mpool: Array = []
var _mpool_i: int = 0
var _file_player: AudioStreamPlayer
var _using_file: bool = false
var _file_path: String = ""
var _mode: String = ""
var _bpm: float = 100.0
var _energy: int = 0
var _genre: String = "swing"
var _lead: String = "sax"
var _tick: int = 0
var _bar: int = 0
var _tick_acc: float = 0.0
var _last_us: int = 0
var _phrase_bars: int = 0
var _rest_bars: int = 1
var _last_note: int = 69
var _lead_busy: int = 0
var _music_bus: int = 0
var _delay_fx: AudioEffectDelay
var _riffs: Array = []

const QUAL = {"m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7b5": [0, 3, 6, 10], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9]}

# Each genre: chords [root midi, quality], grid (12 = swung triplets, 16 = straight 16ths), lead scale
const GENRES = {
	"swing": {"grid": 12, "prog": [[45, "m7"], [50, "m7"], [43, "7"], [48, "maj7"], [41, "maj7"], [47, "m7b5"], [40, "7"], [45, "m7"]],
		"scale": [57, 60, 62, 63, 64, 67, 69, 72, 74, 75, 76, 79, 81]},
	"bebop": {"grid": 12, "prog": [[48, "m7"], [48, "m7"], [41, "m7"], [41, "m7"], [50, "m7b5"], [43, "7"], [48, "m7"], [43, "7"]],
		"scale": [60, 63, 65, 66, 67, 70, 72, 75, 77, 78, 79]},
	"shout": {"grid": 12, "prog": [[45, "m7"], [50, "7"], [43, "7"], [48, "6"], [41, "maj7"], [47, "m7b5"], [40, "7"], [45, "m6"]],
		"scale": [57, 60, 62, 63, 64, 67, 69, 72, 74, 75, 76, 79, 81]},
	"ballad": {"grid": 12, "prog": [[41, "maj7"], [50, "m7"], [43, "m7"], [48, "7"], [45, "m7"], [50, "7"], [43, "m7"], [48, "7"]],
		"scale": [60, 62, 65, 67, 69, 72, 74, 77, 79]},
	"bossa": {"grid": 16, "prog": [[50, "m7"], [43, "7"], [48, "maj7"], [48, "maj7"], [48, "m7"], [41, "7"], [46, "maj7"], [45, "7"]],
		"scale": [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]},
	"mambo": {"grid": 16, "prog": [[45, "m7"], [50, "7"], [45, "m7"], [50, "7"], [41, "maj7"], [40, "7"], [45, "m7"], [40, "7"]],
		"scale": [57, 59, 60, 62, 64, 65, 68, 69, 71, 72, 74, 76]},
	"exotica": {"grid": 16, "prog": [[41, "maj7"], [51, "maj7"], [49, "maj7"], [48, "7"], [41, "maj7"], [51, "maj7"], [46, "m7"], [48, "7"]],
		"scale": [60, 62, 65, 67, 69, 71, 72, 74, 77, 79, 81]},
}

# Every place in the game gets its own genre.  energy: 0 lounge, 1 fight, 2 boss
const MODES = {
	"menu": {"genre": "ballad", "bpm": 72.0, "energy": 0, "lead": "vibes"},
	"hub": {"genre": "swing", "bpm": 108.0, "energy": 0, "lead": "sax"},
	"bar": {"genre": "swing", "bpm": 142.0, "energy": 1, "lead": "sax"},
	"alley": {"genre": "bebop", "bpm": 178.0, "energy": 1, "lead": "sax"},
	"casino": {"genre": "mambo", "bpm": 118.0, "energy": 1, "lead": "brass"},
	"moon": {"genre": "exotica", "bpm": 96.0, "energy": 1, "lead": "theremin"},
	"boss": {"genre": "shout", "bpm": 178.0, "energy": 2, "lead": "brass"},
	"shop": {"genre": "bossa", "bpm": 134.0, "energy": 0, "lead": "sax"},
	"rest": {"genre": "ballad", "bpm": 68.0, "energy": 0, "lead": "sax"},
	"jackpot": {"genre": "mambo", "bpm": 124.0, "energy": 1, "lead": "brass"},
	"gacha": {"genre": "mambo", "bpm": 112.0, "energy": 0, "lead": "vibes"},
	"victory": {"genre": "shout", "bpm": 150.0, "energy": 2, "lead": "brass"},
	"quiet": {"genre": "ballad", "bpm": 60.0, "energy": -1, "lead": "vibes"},
	# jukebox picks for the lounge
	"t_bossa": {"genre": "bossa", "bpm": 128.0, "energy": 0, "lead": "vibes"},
	"t_mambo": {"genre": "mambo", "bpm": 116.0, "energy": 1, "lead": "brass"},
	"t_exotica": {"genre": "exotica", "bpm": 90.0, "energy": 0, "lead": "theremin"},
	"t_bebop": {"genre": "bebop", "bpm": 184.0, "energy": 1, "lead": "sax"},
	"t_ballad": {"genre": "ballad", "bpm": 66.0, "energy": 0, "lead": "sax"},
	"t_shout": {"genre": "shout", "bpm": 172.0, "energy": 2, "lead": "brass"},
}

## Lounge jukebox catalogue: [mode, title, genre blurb]
const TRACKS = [
	["hub", "Rust Row Swing", "Mid-tempo swing, the house sound"],
	["t_bossa", "Bossa for Bots", "Speakeasy bossa nova"],
	["t_mambo", "Tin Can Mambo", "Casino mambo with cowbell"],
	["t_exotica", "Moonbase Lullaby", "Space-age exotica, theremin lead"],
	["t_bebop", "Alley Cat Bebop", "Fast, minor, noir"],
	["t_ballad", "Last Call Ballad", "Slow torch song, brushes"],
	["t_shout", "Boss Shout Chorus", "Full big band, brass up front"],
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	for i in range(MPOOL_SIZE):
		var mp = AudioStreamPlayer.new()
		mp.process_mode = Node.PROCESS_MODE_ALWAYS
		mp.bus = "Music"
		add_child(mp)
		_mpool.append(mp)
	_file_player = AudioStreamPlayer.new()
	_file_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_file_player.bus = "Music"
	add_child(_file_player)
	_build_sounds()
	_build_instruments()
	set_music("menu")
	_apply_volume()

func _setup_buses():
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
		var comp = AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(idx, comp)
		var rev = AudioEffectReverb.new()
		rev.room_size = 0.55
		rev.damping = 0.55
		rev.spread = 0.9
		rev.wet = 0.16
		rev.dry = 1.0
		rev.predelay_msec = 25.0
		AudioServer.add_bus_effect(idx, rev)
	_music_bus = AudioServer.get_bus_index("Music")
	for side in [["MusicL", -0.45], ["MusicR", 0.45]]:
		if AudioServer.get_bus_index(side[0]) == -1:
			var j = AudioServer.bus_count
			AudioServer.add_bus(j)
			AudioServer.set_bus_name(j, side[0])
			AudioServer.set_bus_send(j, "Music")
			var pan = AudioEffectPanner.new()
			pan.pan = side[1]
			AudioServer.add_bus_effect(j, pan)
	if AudioServer.get_bus_index("MusicEcho") == -1:
		var k = AudioServer.bus_count
		AudioServer.add_bus(k)
		AudioServer.set_bus_name(k, "MusicEcho")
		AudioServer.set_bus_send(k, "Music")
		_delay_fx = AudioEffectDelay.new()
		_delay_fx.dry = 1.0
		_delay_fx.tap1_active = true
		_delay_fx.tap1_level_db = -9.0
		_delay_fx.tap1_pan = 0.4
		_delay_fx.tap2_active = true
		_delay_fx.tap2_level_db = -14.0
		_delay_fx.tap2_pan = -0.4
		_delay_fx.feedback_active = false
		AudioServer.add_bus_effect(k, _delay_fx)

func _apply_volume():
	if _music_bus >= 0 and _music_bus < AudioServer.bus_count:
		AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(0.0001, GameData.music_volume * 0.8)))

# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------
func play(sname: String, pitch: float = 1.0, vol_db: float = 0.0):
	if not sounds.has(sname):
		return
	var now = Time.get_ticks_msec()
	if _last_play.has(sname) and now - int(_last_play[sname]) < 35:
		return
	_last_play[sname] = now
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = sounds[sname]
	p.pitch_scale = maxf(0.05, pitch * randf_range(0.95, 1.05))
	p.volume_db = vol_db + linear_to_db(maxf(0.0001, GameData.sfx_volume))
	p.play()

func _synth(layers: Array, dur: float) -> AudioStreamWAV:
	var n = int(dur * MIX_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var cnt = layers.size()
	var a_st = PackedFloat32Array()
	var a_ln = PackedFloat32Array()
	var a_f0 = PackedFloat32Array()
	var a_f1 = PackedFloat32Array()
	var a_amp = PackedFloat32Array()
	var a_att = PackedFloat32Array()
	var a_dec = PackedFloat32Array()
	var a_lpk = PackedFloat32Array()
	var a_w = PackedInt32Array()
	var a_ph = PackedFloat32Array()
	var a_lp = PackedFloat32Array()
	var wave_ids = {"sine": 0, "square": 1, "saw": 2, "tri": 3, "noise": 4, "hiss": 5}
	for l in layers:
		a_st.append(float(l.get("start", 0.0)))
		a_ln.append(float(l.get("len", dur)))
		var f0 = float(l.get("f0", 440.0))
		a_f0.append(f0)
		a_f1.append(float(l.get("f1", f0)))
		a_amp.append(float(l.get("amp", 0.3)))
		a_att.append(float(l.get("att", 0.004)))
		a_dec.append(float(l.get("dec", 8.0)))
		a_lpk.append(float(l.get("lp", 1.0)))
		a_w.append(int(wave_ids.get(String(l.get("w", "sine")), 0)))
		a_ph.append(0.0)
		a_lp.append(0.0)
	for i in range(n):
		var t = float(i) / MIX_RATE
		var s = 0.0
		for li in range(cnt):
			var st = a_st[li]
			if t < st:
				continue
			var lt = t - st
			var ln = a_ln[li]
			if lt > ln:
				continue
			var f = lerpf(a_f0[li], a_f1[li], lt / ln)
			var ph = a_ph[li] + f / MIX_RATE
			if ph >= 1.0:
				ph -= 1.0
			a_ph[li] = ph
			var v = 0.0
			match a_w[li]:
				0: v = sin(ph * TAU)
				1: v = 1.0 if ph < 0.5 else -1.0
				2: v = ph * 2.0 - 1.0
				3: v = 4.0 * absf(ph - 0.5) - 1.0
				4:
					var nz = randf() * 2.0 - 1.0
					a_lp[li] = a_lp[li] + (nz - a_lp[li]) * a_lpk[li]
					v = a_lp[li]
				5:
					var nz2 = randf() * 2.0 - 1.0
					a_lp[li] = a_lp[li] + (nz2 - a_lp[li]) * 0.35
					v = nz2 - a_lp[li]
			var env = minf(1.0, lt / a_att[li]) * exp(-lt * a_dec[li])
			s += v * env * a_amp[li]
		s = clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func _build_sounds():
	sounds["swing"] = _synth([
		{"w": "noise", "lp": 0.25, "amp": 0.45, "dec": 22.0, "att": 0.02},
		{"w": "sine", "f0": 320.0, "f1": 160.0, "amp": 0.12, "dec": 25.0}], 0.14)
	sounds["hit"] = _synth([
		{"w": "square", "f0": 200.0, "f1": 60.0, "amp": 0.28, "dec": 28.0, "len": 0.1},
		{"w": "noise", "lp": 0.6, "amp": 0.4, "dec": 45.0}], 0.13)
	sounds["crit"] = _synth([
		{"w": "square", "f0": 240.0, "f1": 60.0, "amp": 0.28, "dec": 25.0, "len": 0.1},
		{"w": "noise", "lp": 0.7, "amp": 0.4, "dec": 40.0},
		{"w": "sine", "f0": 1320.0, "f1": 1250.0, "amp": 0.3, "dec": 9.0, "start": 0.02}], 0.35)
	sounds["hurt"] = _synth([
		{"w": "saw", "f0": 320.0, "f1": 90.0, "amp": 0.35, "dec": 9.0},
		{"w": "noise", "lp": 0.4, "amp": 0.3, "dec": 20.0}], 0.3)
	sounds["dash"] = _synth([
		{"w": "noise", "lp": 0.35, "amp": 0.35, "dec": 14.0, "att": 0.03},
		{"w": "sine", "f0": 220.0, "f1": 520.0, "amp": 0.12, "dec": 14.0}], 0.2)
	sounds["coin"] = _synth([
		{"w": "sine", "f0": 1319.0, "amp": 0.22, "dec": 22.0},
		{"w": "sine", "f0": 1760.0, "amp": 0.22, "dec": 16.0, "start": 0.05}], 0.25)
	sounds["chip"] = _synth([
		{"w": "square", "f0": 950.0, "amp": 0.12, "dec": 45.0},
		{"w": "hiss", "amp": 0.3, "dec": 60.0},
		{"w": "square", "f0": 1250.0, "amp": 0.1, "dec": 45.0, "start": 0.04}], 0.12)
	sounds["door"] = _synth([
		{"w": "noise", "lp": 0.08, "amp": 0.6, "dec": 4.0, "att": 0.1},
		{"w": "sine", "f0": 180.0, "f1": 90.0, "amp": 0.25, "dec": 5.0}], 0.6)
	sounds["boon"] = _synth([
		{"w": "sine", "f0": 523.0, "amp": 0.22, "dec": 5.0},
		{"w": "sine", "f0": 659.0, "amp": 0.22, "dec": 5.0, "start": 0.07},
		{"w": "sine", "f0": 784.0, "amp": 0.22, "dec": 5.0, "start": 0.14},
		{"w": "sine", "f0": 1047.0, "amp": 0.25, "dec": 3.5, "start": 0.21},
		{"w": "hiss", "amp": 0.08, "dec": 3.0, "start": 0.21}], 1.0)
	sounds["buy"] = _synth([
		{"w": "hiss", "amp": 0.35, "dec": 25.0},
		{"w": "sine", "f0": 1568.0, "amp": 0.25, "dec": 7.0, "start": 0.08},
		{"w": "sine", "f0": 2093.0, "amp": 0.2, "dec": 6.0, "start": 0.12}], 0.6)
	sounds["error"] = _synth([
		{"w": "square", "f0": 140.0, "amp": 0.2, "dec": 10.0},
		{"w": "square", "f0": 110.0, "amp": 0.2, "dec": 10.0, "start": 0.09}], 0.25)
	sounds["tick"] = _synth([
		{"w": "square", "f0": 1400.0, "amp": 0.1, "dec": 90.0}], 0.03)
	sounds["select"] = _synth([
		{"w": "sine", "f0": 660.0, "f1": 990.0, "amp": 0.25, "dec": 18.0}], 0.12)
	sounds["slot_stop"] = _synth([
		{"w": "square", "f0": 200.0, "f1": 120.0, "amp": 0.25, "dec": 25.0},
		{"w": "noise", "lp": 0.3, "amp": 0.35, "dec": 30.0}], 0.15)
	sounds["jackpot"] = _synth([
		{"w": "sine", "f0": 1047.0, "amp": 0.2, "dec": 3.0},
		{"w": "sine", "f0": 1319.0, "amp": 0.2, "dec": 3.0, "start": 0.1},
		{"w": "sine", "f0": 1568.0, "amp": 0.2, "dec": 3.0, "start": 0.2},
		{"w": "sine", "f0": 2093.0, "amp": 0.22, "dec": 2.0, "start": 0.3},
		{"w": "hiss", "amp": 0.12, "dec": 2.0, "start": 0.3}], 1.4)
	sounds["explode"] = _synth([
		{"w": "noise", "lp": 0.12, "amp": 0.75, "dec": 6.0},
		{"w": "sine", "f0": 90.0, "f1": 30.0, "amp": 0.6, "dec": 6.0}], 0.7)
	sounds["shoot"] = _synth([
		{"w": "square", "f0": 900.0, "f1": 300.0, "amp": 0.12, "dec": 30.0}], 0.08)
	sounds["eshoot"] = _synth([
		{"w": "saw", "f0": 520.0, "f1": 260.0, "amp": 0.14, "dec": 22.0}], 0.1)
	sounds["flash"] = _synth([
		{"w": "hiss", "amp": 0.3, "dec": 18.0},
		{"w": "sine", "f0": 2400.0, "f1": 1700.0, "amp": 0.14, "dec": 16.0}], 0.18)
	sounds["spawn"] = _synth([
		{"w": "sine", "f0": 200.0, "f1": 620.0, "amp": 0.16, "dec": 6.0, "att": 0.05},
		{"w": "hiss", "amp": 0.06, "dec": 8.0}], 0.35)
	sounds["roar"] = _synth([
		{"w": "saw", "f0": 95.0, "f1": 55.0, "amp": 0.35, "dec": 2.0, "att": 0.1},
		{"w": "saw", "f0": 97.0, "f1": 57.0, "amp": 0.3, "dec": 2.0, "att": 0.1},
		{"w": "noise", "lp": 0.15, "amp": 0.3, "dec": 2.5, "att": 0.1}], 1.2)
	sounds["levelup"] = _synth([
		{"w": "square", "f0": 523.0, "amp": 0.1, "dec": 10.0},
		{"w": "square", "f0": 659.0, "amp": 0.1, "dec": 10.0, "start": 0.06},
		{"w": "square", "f0": 784.0, "amp": 0.1, "dec": 10.0, "start": 0.12},
		{"w": "sine", "f0": 1047.0, "amp": 0.25, "dec": 5.0, "start": 0.18}], 0.6)
	sounds["death"] = _synth([
		{"w": "saw", "f0": 420.0, "f1": 55.0, "amp": 0.3, "dec": 2.0},
		{"w": "noise", "lp": 0.1, "amp": 0.25, "dec": 3.0}], 1.3)
	sounds["slam"] = _synth([
		{"w": "noise", "lp": 0.1, "amp": 0.7, "dec": 8.0},
		{"w": "sine", "f0": 75.0, "f1": 32.0, "amp": 0.75, "dec": 7.0}], 0.55)
	sounds["zap"] = _synth([
		{"w": "square", "f0": 1600.0, "f1": 700.0, "amp": 0.12, "dec": 18.0},
		{"w": "hiss", "amp": 0.25, "dec": 22.0}], 0.14)
	sounds["freeze"] = _synth([
		{"w": "sine", "f0": 2000.0, "f1": 2700.0, "amp": 0.14, "dec": 8.0},
		{"w": "hiss", "amp": 0.2, "dec": 10.0}], 0.35)
	sounds["burn"] = _synth([
		{"w": "noise", "lp": 0.45, "amp": 0.22, "dec": 14.0, "att": 0.02}], 0.2)
	sounds["heal"] = _synth([
		{"w": "sine", "f0": 523.0, "f1": 784.0, "amp": 0.22, "dec": 4.0},
		{"w": "sine", "f0": 784.0, "f1": 1047.0, "amp": 0.14, "dec": 4.0, "start": 0.08}], 0.55)
	sounds["horn"] = _synth([
		{"w": "square", "f0": 311.0, "amp": 0.14, "dec": 2.5, "att": 0.02},
		{"w": "square", "f0": 392.0, "amp": 0.14, "dec": 2.5, "att": 0.02}], 0.55)
	sounds["cast"] = _synth([
		{"w": "sine", "f0": 120.0, "f1": 420.0, "amp": 0.2, "dec": 3.0, "att": 0.05},
		{"w": "noise", "lp": 0.2, "amp": 0.25, "dec": 5.0, "att": 0.08}], 0.3)
	sounds["lever"] = _synth([
		{"w": "noise", "lp": 0.3, "amp": 0.35, "dec": 12.0},
		{"w": "square", "f0": 110.0, "f1": 80.0, "amp": 0.2, "dec": 10.0},
		{"w": "square", "f0": 160.0, "amp": 0.15, "dec": 30.0, "start": 0.15}], 0.3)
	sounds["glass"] = _synth([
		{"w": "hiss", "amp": 0.4, "dec": 16.0},
		{"w": "sine", "f0": 3100.0, "amp": 0.12, "dec": 14.0},
		{"w": "sine", "f0": 4200.0, "amp": 0.1, "dec": 18.0, "start": 0.03}], 0.3)
	sounds["shield"] = _synth([
		{"w": "tri", "f0": 880.0, "f1": 440.0, "amp": 0.25, "dec": 9.0},
		{"w": "hiss", "amp": 0.15, "dec": 12.0}], 0.3)
	# Headliner entrance stings (and Lady Loom's scissors)
	sounds["sting_luna"] = _synth([
		{"w": "sine", "f0": 2093.0, "amp": 0.16, "dec": 3.0},
		{"w": "sine", "f0": 1568.0, "amp": 0.16, "dec": 3.0, "start": 0.12},
		{"w": "sine", "f0": 1319.0, "amp": 0.16, "dec": 3.0, "start": 0.24},
		{"w": "sine", "f0": 988.0, "amp": 0.18, "dec": 2.0, "start": 0.36},
		{"w": "hiss", "amp": 0.06, "dec": 2.0}], 1.2)
	sounds["sting_baron"] = _synth([
		{"w": "saw", "f0": 233.0, "amp": 0.16, "dec": 2.5, "att": 0.03},
		{"w": "saw", "f0": 294.0, "amp": 0.14, "dec": 2.5, "att": 0.03},
		{"w": "saw", "f0": 349.0, "amp": 0.14, "dec": 2.5, "att": 0.03},
		{"w": "saw", "f0": 466.0, "f1": 470.0, "amp": 0.12, "dec": 2.0, "att": 0.03, "start": 0.18},
		{"w": "noise", "lp": 0.4, "amp": 0.18, "dec": 5.0}], 1.0)
	sounds["sting_fortuna"] = _synth([
		{"w": "hiss", "amp": 0.3, "dec": 30.0},
		{"w": "hiss", "amp": 0.25, "dec": 30.0, "start": 0.08},
		{"w": "hiss", "amp": 0.2, "dec": 30.0, "start": 0.16},
		{"w": "sine", "f0": 1760.0, "amp": 0.18, "dec": 4.0, "start": 0.24},
		{"w": "sine", "f0": 2217.0, "amp": 0.15, "dec": 4.0, "start": 0.3}], 1.0)
	sounds["sting_ivory"] = _synth([
		{"w": "square", "f0": 523.0, "amp": 0.08, "dec": 8.0},
		{"w": "square", "f0": 659.0, "amp": 0.08, "dec": 8.0, "start": 0.06},
		{"w": "square", "f0": 784.0, "amp": 0.08, "dec": 8.0, "start": 0.12},
		{"w": "square", "f0": 1047.0, "amp": 0.08, "dec": 6.0, "start": 0.18},
		{"w": "hiss", "amp": 0.3, "dec": 14.0, "start": 0.2}], 0.9)
	sounds["sting_bruno"] = _synth([
		{"w": "sine", "f0": 82.0, "f1": 55.0, "amp": 0.6, "dec": 3.0},
		{"w": "sine", "f0": 110.0, "f1": 82.0, "amp": 0.35, "dec": 3.0, "start": 0.25},
		{"w": "noise", "lp": 0.1, "amp": 0.3, "dec": 6.0}], 1.0)
	sounds["sting_tailor"] = _synth([
		{"w": "hiss", "amp": 0.35, "dec": 60.0},
		{"w": "square", "f0": 3000.0, "amp": 0.06, "dec": 60.0},
		{"w": "hiss", "amp": 0.35, "dec": 60.0, "start": 0.14},
		{"w": "square", "f0": 3200.0, "amp": 0.06, "dec": 60.0, "start": 0.14},
		{"w": "sine", "f0": 880.0, "f1": 1320.0, "amp": 0.12, "dec": 5.0, "start": 0.28}], 0.8)
	sounds["whoosh_up"] = _synth([
		{"w": "noise", "lp": 0.2, "amp": 0.4, "dec": 1.0, "att": 0.35},
		{"w": "sine", "f0": 200.0, "f1": 900.0, "amp": 0.1, "dec": 1.0, "att": 0.3}], 0.45)

# ---------------------------------------------------------------------------
# INSTRUMENT SAMPLES (rendered once)
# ---------------------------------------------------------------------------
func _build_instruments():
	inst["bass"] = _instr("bass", 1.0, 110.0)
	inst["rhodes"] = _instr("rhodes", 2.2, 220.0)
	inst["sax"] = _instr("sax", 0.36, 440.0)
	inst["sax_long"] = _instr("sax", 1.1, 440.0)
	inst["vibes"] = _instr("vibes", 1.8, 440.0)
	inst["vibes_long"] = inst["vibes"]
	inst["brass"] = _instr("brass", 0.32, 440.0)
	inst["brass_long"] = _instr("brass", 0.9, 440.0)
	inst["theremin"] = _instr("theremin", 0.7, 440.0)
	inst["theremin_long"] = _instr("theremin", 1.6, 440.0)
	inst["guitar"] = _pluck(1.4, 220.0)
	inst["ride"] = _instr("ride", 0.9, 1.0)
	inst["hat"] = _instr("hat", 0.07, 1.0)
	inst["kick"] = _instr("kick", 0.35, 1.0)
	inst["snare"] = _instr("snare", 0.28, 190.0)
	inst["brush"] = _instr("brush", 0.4, 1.0)
	inst["rim"] = _instr("rim", 0.08, 1.0)
	inst["bell"] = _instr("bell", 0.25, 1.0)
	inst["conga"] = _instr("conga", 0.35, 210.0)
	inst["shaker"] = _instr("shaker", 0.09, 1.0)

## Karplus-Strong plucked string (nylon guitar for the bossa)
func _pluck(dur: float, f: float) -> AudioStreamWAV:
	var n = int(dur * MIX_RATE)
	var period = maxi(2, int(MIX_RATE / f))
	var ring = PackedFloat32Array()
	ring.resize(period)
	for i in range(period):
		ring[i] = randf() * 2.0 - 1.0
	var data = PackedByteArray()
	data.resize(n * 2)
	var idx = 0
	var prev = 0.0
	for i in range(n):
		var cur = ring[idx]
		var nxt = ring[(idx + 1) % period]
		var v = (cur + nxt) * 0.5 * 0.996
		ring[idx] = v
		idx = (idx + 1) % period
		var s = (cur * 0.7 + prev * 0.3) * 0.55
		prev = cur
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func _instr(kind: String, dur: float, f: float) -> AudioStreamWAV:
	var n = int(dur * MIX_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var ph = 0.0
	var ph2 = 0.0
	var ph3 = 0.0
	var lp = 0.0
	var lp2 = 0.0
	var nlp = 0.0
	for i in range(n):
		var t = float(i) / MIX_RATE
		var s = 0.0
		match kind:
			"bass":
				ph = fmod(ph + f / MIX_RATE, 1.0)
				var e = minf(1.0, t / 0.004) * exp(-t * 3.0)
				var bright = exp(-t * 10.0)
				var raw = sin(ph * TAU) + (0.55 * sin(ph * TAU * 2.0) + 0.28 * sin(ph * TAU * 3.0) + 0.12 * sin(ph * TAU * 4.0)) * bright
				var click = (randf() * 2.0 - 1.0) * exp(-t * 260.0) * 0.35
				s = (raw * 0.55 + click) * e
			"rhodes":
				ph = fmod(ph + f / MIX_RATE, 1.0)
				var e2 = minf(1.0, t / 0.003) * exp(-t * 1.5)
				var tine = sin(ph * TAU * 7.0) * exp(-t * 14.0) * 0.3
				var trem = 0.86 + 0.14 * sin(t * TAU * 4.5)
				s = (sin(ph * TAU) + 0.22 * sin(ph * TAU * 2.0) * exp(-t * 3.0) + tine) * e2 * trem * 0.5
			"sax":
				var vib = 1.0 + 0.008 * sin(t * TAU * 5.4) * clampf((t - 0.1) * 5.0, 0.0, 1.0)
				ph = fmod(ph + f * vib / MIX_RATE, 1.0)
				var e3 = minf(1.0, t / 0.03)
				var rel = dur - 0.09
				if t > rel:
					e3 *= maxf(0.0, 1.0 - (t - rel) / 0.09)
				e3 *= 0.82 + 0.18 * exp(-t * 7.0)
				var raw2 = (ph * 2.0 - 1.0) * 0.6 + (1.0 if ph < 0.5 else -1.0) * 0.4
				var cut = 0.05 + 0.16 * e3
				lp += (raw2 - lp) * cut
				lp2 += (lp - lp2) * minf(1.0, cut * 1.4)
				var breath = (randf() * 2.0 - 1.0) * 0.05 * e3
				s = (lp2 * 1.9 + breath) * e3 * 0.5
			"vibes":
				ph = fmod(ph + f / MIX_RATE, 1.0)
				var e4 = minf(1.0, t / 0.002) * exp(-t * 1.5)
				var trem2 = 0.7 + 0.3 * sin(t * TAU * 5.8)
				s = (sin(ph * TAU) + 0.2 * sin(ph * TAU * 4.0) * exp(-t * 6.0) + 0.07 * sin(ph * TAU * 10.0) * exp(-t * 25.0)) * e4 * trem2 * 0.5
			"theremin":
				var vib2 = 1.0 + 0.018 * sin(t * TAU * 6.2) * clampf(t * 3.0, 0.0, 1.0)
				ph = fmod(ph + f * vib2 / MIX_RATE, 1.0)
				var e6 = minf(1.0, t / 0.12)
				var rel3 = dur - 0.2
				if t > rel3:
					e6 *= maxf(0.0, 1.0 - (t - rel3) / 0.2)
				s = (sin(ph * TAU) + 0.12 * sin(ph * TAU * 2.0)) * e6 * 0.45
			"brass":
				ph = fmod(ph + f / MIX_RATE, 1.0)
				ph2 = fmod(ph2 + f * 1.007 / MIX_RATE, 1.0)
				ph3 = fmod(ph3 + f * 0.993 / MIX_RATE, 1.0)
				var e5 = minf(1.0, t / 0.018)
				var rel2 = dur - 0.08
				if t > rel2:
					e5 *= maxf(0.0, 1.0 - (t - rel2) / 0.08)
				e5 *= 0.7 + 0.3 * exp(-t * 9.0)
				var raw3 = ((ph * 2.0 - 1.0) + (ph2 * 2.0 - 1.0) + (ph3 * 2.0 - 1.0)) / 3.0
				lp += (raw3 - lp) * (0.1 + 0.35 * e5 * exp(-t * 3.0))
				s = lp * e5 * 0.85
			"ride":
				ph = fmod(ph + 3150.0 / MIX_RATE, 1.0)
				ph2 = fmod(ph2 + 4230.0 / MIX_RATE, 1.0)
				ph3 = fmod(ph3 + 5370.0 / MIX_RATE, 1.0)
				var nz = randf() * 2.0 - 1.0
				nlp += (nz - nlp) * 0.4
				var hiss = nz - nlp
				var metal = ((1.0 if ph < 0.5 else -1.0) + (1.0 if ph2 < 0.5 else -1.0) + (1.0 if ph3 < 0.5 else -1.0)) * 0.12
				s = (metal + hiss * 0.55) * exp(-t * 4.5) * minf(1.0, t / 0.001) * 0.35
			"hat":
				var nz2 = randf() * 2.0 - 1.0
				nlp += (nz2 - nlp) * 0.5
				s = (nz2 - nlp) * exp(-t * 70.0) * 0.5
			"kick":
				var fk = 45.0 + 80.0 * exp(-t * 32.0)
				ph = fmod(ph + fk / MIX_RATE, 1.0)
				s = sin(ph * TAU) * exp(-t * 9.0) * 0.9
			"snare":
				ph = fmod(ph + f / MIX_RATE, 1.0)
				var nz3 = randf() * 2.0 - 1.0
				nlp += (nz3 - nlp) * 0.55
				s = (nlp * 0.8 + sin(ph * TAU) * 0.4 * exp(-t * 25.0)) * exp(-t * 15.0) * 0.6
			"brush":
				var nz4 = randf() * 2.0 - 1.0
				nlp += (nz4 - nlp) * 0.35
				var eb = minf(1.0, t / 0.05) * exp(-maxf(0.0, t - 0.05) * 9.0)
				s = (nz4 - nlp * 0.5) * eb * 0.28
			"rim":
				ph = fmod(ph + 1700.0 / MIX_RATE, 1.0)
				s = (sin(ph * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * exp(-t * 90.0) * 0.6
			"bell":
				ph = fmod(ph + 540.0 / MIX_RATE, 1.0)
				ph2 = fmod(ph2 + 800.0 / MIX_RATE, 1.0)
				var sq = (1.0 if ph < 0.5 else -1.0) + (1.0 if ph2 < 0.5 else -1.0)
				lp += (sq - lp) * 0.3
				s = lp * exp(-t * 16.0) * 0.28
			"conga":
				var fc = f * (1.0 + 0.6 * exp(-t * 40.0))
				ph = fmod(ph + fc / MIX_RATE, 1.0)
				s = (sin(ph * TAU) + (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 60.0)) * exp(-t * 11.0) * 0.6
			"shaker":
				var nz5 = randf() * 2.0 - 1.0
				nlp += (nz5 - nlp) * 0.6
				s = (nz5 - nlp) * minf(1.0, t / 0.015) * exp(-t * 45.0) * 0.35
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func _note(key: String, midi_rel: float, db: float, bus: String = "Music"):
	if not inst.has(key):
		return
	var p: AudioStreamPlayer = _mpool[_mpool_i]
	_mpool_i = (_mpool_i + 1) % MPOOL_SIZE
	p.stream = inst[key]
	var rel = midi_rel
	while rel > 24.0:
		rel -= 12.0
	while rel < -24.0:
		rel += 12.0
	p.pitch_scale = pow(2.0, rel / 12.0)
	p.volume_db = db
	p.bus = bus
	p.play()

# ---------------------------------------------------------------------------
# MODES & DROP-IN FILES
# ---------------------------------------------------------------------------
func current_mode() -> String:
	return _mode

func set_music(mode: String):
	if mode == _mode:
		return
	_mode = mode
	var m = MODES.get(mode, MODES["hub"])
	_genre = String(m["genre"])
	_bpm = float(m["bpm"])
	_energy = int(m["energy"])
	_lead = String(m["lead"])
	_phrase_bars = 0
	_rest_bars = 1
	_tick = 0
	_bar = 0
	if _delay_fx:
		var beat_ms = 60000.0 / _bpm
		_delay_fx.tap1_delay_ms = beat_ms * (0.667 if _grid() == 12 else 0.75)
		_delay_fx.tap2_delay_ms = beat_ms * (1.333 if _grid() == 12 else 1.5)
	_try_file(mode)
	if _energy >= 2 and not _using_file:
		for iv in [0, 4, 7, 10]:
			_note("brass_long", float(-9 + iv), -4.0, "MusicEcho")
		_note("kick", 0.0, 0.0)
		_note("ride", -2.0, -2.0)

## A short solo from one of the house band (lobby performers).
func riff(kind: String):
	_riffs.clear()
	match kind:
		"bass":
			var run = [0, 3, 5, 7, 10, 12, 10, 7, 5, 0]
			for i in range(run.size()):
				_riffs.append({"at": i * 0.13, "key": "bass", "rel": float(run[i]), "db": -1.0, "bus": "Music"})
		"drums":
			var times = [0.0, 0.11, 0.2, 0.28, 0.35, 0.42, 0.48, 0.54]
			for i in range(times.size()):
				_riffs.append({"at": times[i], "key": "snare", "rel": float(i) * 0.6, "db": -8.0 + i, "bus": "MusicL"})
			_riffs.append({"at": 0.62, "key": "kick", "rel": 0.0, "db": 0.0, "bus": "Music"})
			_riffs.append({"at": 0.62, "key": "ride", "rel": -3.0, "db": -1.0, "bus": "MusicR"})
		"piano":
			var arp = [3, 7, 10, 14, 15, 19, 22, 27]
			for i in range(arp.size()):
				_riffs.append({"at": i * 0.07, "key": "rhodes", "rel": float(arp[i]), "db": -6.0, "bus": "MusicEcho"})
			for iv in [3, 10, 14, 19]:
				_riffs.append({"at": 0.66, "key": "rhodes", "rel": float(iv), "db": -8.0, "bus": "MusicL"})

func _grid() -> int:
	return int(GENRES[_genre]["grid"])

func _find_file(mode: String) -> String:
	for ext in ["ogg", "mp3", "wav"]:
		var p = "res://audio/music/%s.%s" % [mode, ext]
		if ResourceLoader.exists(p):
			return p
	if mode in ["menu", "hub", "gacha", "victory"]:
		for ext2 in ["ogg", "mp3", "wav"]:
			var p2 = "res://audio/music/theme.%s" % ext2
			if ResourceLoader.exists(p2):
				return p2
	return ""

func has_file_for(mode: String) -> bool:
	return _find_file(mode) != ""

func _try_file(mode: String):
	var path = _find_file(mode)
	if path == "":
		if _using_file:
			_file_player.stop()
		_using_file = false
		_file_path = ""
		return
	if _using_file and path == _file_path:
		return
	var st = load(path)
	if st == null:
		_using_file = false
		return
	if st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * float(st.mix_rate))
	elif "loop" in st:
		st.loop = true
	_file_player.stream = st
	_file_player.play()
	_file_path = path
	_using_file = true

# ---------------------------------------------------------------------------
# SEQUENCER (real-time clock, so hit-stop and pause don't wobble the band)
# ---------------------------------------------------------------------------
func _process(_delta):
	_apply_volume()
	var now = Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
	var dt = float(now - _last_us) / 1000000.0
	_last_us = now
	if not _riffs.is_empty():
		var keep = []
		for r in _riffs:
			r["at"] = float(r["at"]) - dt
			if float(r["at"]) <= 0.0:
				_note(String(r["key"]), float(r["rel"]), float(r["db"]), String(r["bus"]))
			else:
				keep.append(r)
		_riffs = keep
	if _using_file or _energy < 0:
		return
	var tick_dur = (60.0 / _bpm * 4.0) / float(_grid())
	_tick_acc += dt
	if _tick_acc > tick_dur * 6.0:
		_tick_acc = tick_dur
	while _tick_acc >= tick_dur:
		_tick_acc -= tick_dur
		_on_tick()

func _on_tick():
	var g = GENRES[_genre]
	var prog: Array = g["prog"]
	var grid = int(g["grid"])
	var t = _tick
	if t == 0:
		_phrase_step()
	var chord = prog[_bar % prog.size()]
	var root: int = chord[0]
	var tones: Array = QUAL[chord[1]]
	var next_root: int = prog[(_bar + 1) % prog.size()][0]
	var last_bar = _bar == prog.size() - 1
	match _genre:
		"swing", "bebop", "shout":
			_swing(t, root, tones, next_root, last_bar)
		"ballad":
			_ballad(t, root, tones)
		"bossa":
			_bossa(t, root, tones, next_root)
		"mambo":
			_mambo(t, root, tones, next_root, last_bar)
		"exotica":
			_exotica(t, root, tones)
	_lead_tick(t, root, tones, g["scale"], grid)
	_tick += 1
	if _tick >= grid:
		_tick = 0
		_bar = (_bar + 1) % prog.size()

func _bass_note(n: int, db: float):
	var m = n
	while m > 55:
		m -= 12
	while m < 36:
		m += 12
	_note("bass", float(m - 45), db)

func _chord(root: int, tones: Array, db: float, key: String = "rhodes", bus: String = "MusicL", extra9: bool = false):
	var base_n = root + 12
	while base_n < 52:
		base_n += 12
	var voicing = [tones[1], tones[3], tones[2] + 12]
	if extra9:
		voicing.append(14)
	var ref = 57 if key == "rhodes" else 45
	if key == "guitar":
		ref = 57
	for iv in voicing:
		_note(key, float(base_n + int(iv) - ref), db, bus)

# --- SWING / BEBOP / SHOUT (12 swung ticks per bar) ---
func _swing(t: int, root: int, tones: Array, next_root: int, last_bar: bool):
	var lounge = _energy == 0
	var boss = _energy >= 2
	var bop = _genre == "bebop"
	if t % 3 == 0:
		var beat = int(t / 3.0)
		var n = root
		match beat:
			1: n = root + int(tones[1]) if randf() < 0.6 else root + int(tones[2])
			2: n = root + int(tones[2]) if randf() < 0.6 else root + int(tones[3]) - 12
			3: n = next_root + (1 if randf() < 0.5 else -1)
		_bass_note(n, -3.0 if beat == 0 else -5.0)
	elif t % 3 == 2 and randf() < (0.08 if lounge else (0.3 if bop else 0.15)):
		_bass_note(root + 12, -12.0)
	var ride_db = -15.0 if lounge else -11.0
	if t == 0 or t == 3 or t == 6 or t == 9:
		_note("ride", randf_range(-0.3, 0.3), ride_db, "MusicR")
	elif (t == 5 or t == 11) and randf() < 0.92:
		_note("ride", 0.0, ride_db - 4.0, "MusicR")
	if t == 3 or t == 9:
		if lounge:
			_note("brush", 0.0, -8.0, "MusicL")
		else:
			_note("hat", 0.0, -9.0, "MusicL")
	if not lounge:
		if t % 3 == 0:
			_note("kick", 0.0, -8.0 if t != 0 else -4.0)
		if boss:
			if t == 3 or t == 9:
				_note("snare", 0.0, -3.0)
		elif (t == 5 or t == 8 or t == 11 or (bop and t == 2)) and randf() < (0.4 if bop else 0.22):
			_note("snare", 0.0, -11.0, "MusicL")
		if last_bar and t >= 6:
			if randf() < 0.75:
				_note("snare", randf_range(-1.0, 1.0), -6.0 - float(11 - t))
			if t == 11:
				_note("kick", 0.0, -3.0)
	var comp_hit = false
	if lounge:
		comp_hit = (t == 0 and randf() < 0.75) or (t == 5 and randf() < 0.4) or (t == 8 and randf() < 0.15)
	else:
		comp_hit = t == 0 or t == 5 or (t == 11 and randf() < 0.3)
	if comp_hit:
		_chord(root, tones, -13.0 if lounge else -14.0, "rhodes", "MusicL", randf() < 0.4)
	if _lead == "brass" and not lounge:
		var stab = (t == 5 and (_bar % 2 == 1)) or (boss and t == 0 and _bar % 4 == 0) or (boss and t == 8 and _bar % 2 == 0)
		if stab:
			for iv2 in [tones[1], tones[2], tones[3]]:
				_note("brass", float(root + 24 + int(iv2) - 69), -11.0, "MusicR")

# --- BALLAD (slow, brushes, half-note bass) ---
func _ballad(t: int, root: int, tones: Array):
	if t == 0:
		_bass_note(root, -4.0)
		_chord(root, tones, -12.0, "rhodes", "MusicL", true)
	elif t == 6:
		_bass_note(root + int(tones[2]), -7.0)
		if randf() < 0.5:
			_chord(root, tones, -16.0, "rhodes", "MusicL")
	if t % 3 == 0:
		_note("brush", 0.0, -12.0 if (t == 3 or t == 9) else -16.0, "MusicL")
	if (t == 3 or t == 9) and randf() < 0.6:
		_note("ride", 0.5, -20.0, "MusicR")

# --- BOSSA NOVA (straight 16ths) ---
func _bossa(t: int, root: int, tones: Array, next_root: int):
	match t:
		0: _bass_note(root, -4.0)
		6: _bass_note(root + int(tones[2]), -7.0)
		8: _bass_note(root + int(tones[2]), -6.0)
		14: _bass_note(next_root, -8.0)
	if t == 0 or t == 6 or t == 8 or t == 14:
		_note("kick", 0.0, -14.0 if t != 0 else -11.0)
	var clave = [0, 6, 12] if _bar % 2 == 0 else [4, 10]
	if t in clave:
		_note("rim", 0.0, -9.0, "MusicR")
	if t % 2 == 0:
		_note("shaker", 0.0, -12.0 if t % 4 == 2 else -16.0, "MusicR")
	if t in [0, 3, 6, 10, 12] and randf() < 0.85:
		_chord(root, tones, -13.0, "guitar", "MusicL", true)

# --- MAMBO (clave, cowbell, congas, montuno) ---
func _mambo(t: int, root: int, tones: Array, next_root: int, last_bar: bool):
	var clave = [4, 8] if _bar % 2 == 0 else [0, 6, 12]
	if t in clave:
		_note("rim", 0.0, -7.0, "MusicR")
	if t % 2 == 0 and _energy >= 1:
		_note("bell", 0.0, -10.0 if t % 4 == 0 else -15.0, "MusicR")
	# conga tumbao: open tones on the "and" of 2 and 4
	if t == 6 or t == 14:
		_note("conga", 0.0, -6.0, "MusicL")
		_note("conga", 5.0, -9.0, "MusicL")
	elif t == 4 or t == 12:
		_note("conga", 3.0, -11.0, "MusicL")
	# bass tumbao: anticipated
	if t == 6:
		_bass_note(root + int(tones[2]), -5.0)
	elif t == 12:
		_bass_note(next_root, -4.0)
	if t == 0 and _energy >= 1:
		_note("kick", 0.0, -9.0)
	# piano montuno (single-note syncopated pattern)
	var pat = {0: 0, 3: 2, 4: 1, 6: 2, 8: 3, 11: 2, 12: 1, 14: 2}
	if pat.has(t):
		var iv = int(tones[int(pat[t])])
		var n = root + 24 + iv
		if t == 8:
			n = root + 36
		_note("rhodes", float(n - 57), -12.0, "MusicL")
	if _lead == "brass" and _energy >= 1 and (t == 6 or t == 14) and _bar % 2 == 1:
		for iv2 in [tones[1], tones[2], tones[3]]:
			_note("brass", float(root + 24 + int(iv2) - 69), -12.0, "MusicR")
	if last_bar and t >= 8 and t % 2 == 0:
		_note("conga", float(t - 8), -7.0)

# --- EXOTICA / SPACE-AGE (vibes arps, soft hand drums) ---
func _exotica(t: int, root: int, tones: Array):
	if t == 0:
		_bass_note(root, -5.0)
		_chord(root, tones, -17.0, "rhodes", "MusicL", true)
		if _bar % 2 == 0:
			_note("ride", 7.0, -18.0, "MusicR")
	elif t == 8:
		_bass_note(root + int(tones[2]), -8.0)
	if t % 2 == 0:
		var arp = [0, 1, 2, 3, 2, 1, 3, 2]
		var iv = int(tones[arp[int(t / 2.0) % arp.size()]])
		_note("vibes", float(root + 24 + iv - 69), -15.0, "MusicEcho")
	if t in [3, 6, 11, 14]:
		_note("conga", 2.0 if t % 2 == 1 else 7.0, -13.0, "MusicL")
	if t % 4 == 2:
		_note("shaker", 0.0, -18.0, "MusicR")

# ---------------------------------------------------------------------------
# LEAD IMPROVISER (original phrases on each genre's scale)
# ---------------------------------------------------------------------------
func _phrase_step():
	if _phrase_bars > 0:
		_phrase_bars -= 1
		if _phrase_bars == 0:
			_rest_bars = randi_range(1, 2)
	elif _rest_bars > 0:
		_rest_bars -= 1
		if _rest_bars == 0:
			_phrase_bars = randi_range(1, 3)
			_last_note = [64, 67, 69, 72].pick_random()

func _lead_tick(t: int, root: int, tones: Array, scale: Array, grid: int):
	if _lead_busy > 0:
		_lead_busy -= 1
		return
	if _phrase_bars <= 0:
		return
	var on_eighth = (t % 3 == 0 or t % 3 == 2) if grid == 12 else (t % 2 == 0)
	if not on_eighth:
		return
	var downbeat = (t % 3 == 0) if grid == 12 else (t % 4 == 0)
	var dens = 0.62
	var long_p = 0.1
	match _genre:
		"ballad":
			dens = 0.35
			long_p = 0.45
		"exotica":
			dens = 0.3
			long_p = 0.55
		"bossa":
			dens = 0.45
			long_p = 0.25
		"bebop":
			dens = 0.78
			long_p = 0.05
		"mambo":
			dens = 0.55
			long_p = 0.15
	if _energy == 0:
		dens *= 0.85
	if randf() > dens:
		return
	var cands = scale.duplicate()
	for iv in tones:
		for o in [12, 24, 36]:
			var cn = root + int(iv) + o
			if cn >= 57 and cn <= 81:
				cands.append(cn)
	var target = _last_note + randi_range(-4, 4)
	if randf() < 0.12:
		target = _last_note + [-7, 7, -5, 5].pick_random()
	target = clampi(target, 58, 80)
	var best = cands[0]
	var bd = 999
	for c in cands:
		var d = absi(int(c) - target)
		var is_ct = false
		for iv2 in tones:
			if (int(c) - root - int(iv2)) % 12 == 0:
				is_ct = true
		if downbeat and not is_ct:
			d += 2
		if d < bd:
			bd = d
			best = c
	_last_note = int(best)
	var ending = _phrase_bars == 1 and t >= int(grid * 0.66)
	var long_note = ending or randf() < long_p
	var key = _lead
	if long_note:
		key = _lead + "_long"
		_lead_busy = 4 if grid == 12 else 5
	elif randf() < 0.3:
		_lead_busy = 1
	var db = -7.0 if downbeat else -9.5
	if _lead == "vibes":
		db -= 2.0
	elif _lead == "theremin":
		db -= 1.0
	_note(key, float(_last_note - 69), db, "MusicEcho")
