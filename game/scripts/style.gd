extends Node

## Style (autoload): fonts, the art-deco UI theme, palette and shared textures.

const GOLD = Color(0.95, 0.76, 0.35)
const GOLD_DIM = Color(0.55, 0.42, 0.2)
const CREAM = Color(0.96, 0.91, 0.8)
const INK = Color(0.06, 0.05, 0.08)
const NAVY = Color(0.08, 0.09, 0.16)
const CRIMSON = Color(0.85, 0.15, 0.22)
const MUTED = Color(0.6, 0.56, 0.52)

var font_body: Font
var font_title: Font
var font_mono: Font
var theme: Theme
var light_tex: Texture2D
var soft_tex: Texture2D

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fb = SystemFont.new()
	fb.font_names = PackedStringArray(["Futura", "Avenir Next", "Gill Sans", "Helvetica Neue", "Arial", "sans-serif"])
	fb.font_weight = 500
	font_body = fb
	var ft = SystemFont.new()
	ft.font_names = PackedStringArray(["Didot", "Bodoni 72", "Playfair Display", "Georgia", "Times New Roman", "serif"])
	ft.font_weight = 700
	font_title = ft
	var fm = SystemFont.new()
	fm.font_names = PackedStringArray(["Futura", "Avenir Next Condensed", "Arial Narrow", "sans-serif"])
	fm.font_weight = 700
	font_mono = fm
	theme = _make_theme()
	light_tex = _make_radial(256, 1.0)
	soft_tex = _make_radial(128, 2.0)

func _make_radial(size_px: int, falloff: float) -> Texture2D:
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	if falloff > 1.5:
		g.add_point(0.35, Color(1, 1, 1, 0.45))
	else:
		g.add_point(0.5, Color(1, 1, 1, 0.3))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.width = size_px
	t.height = size_px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

func _box(bg: Color, border: Color, bw: int, radius: int = 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

func _make_theme() -> Theme:
	var th = Theme.new()
	th.default_font = font_body
	th.default_font_size = 20
	var normal = _box(Color(0.1, 0.08, 0.1, 0.96), GOLD_DIM, 2)
	var hover = _box(Color(0.17, 0.12, 0.12, 0.98), GOLD, 2)
	var pressed = _box(Color(0.3, 0.2, 0.1, 1.0), GOLD, 3)
	var disabled = _box(Color(0.07, 0.07, 0.08, 0.9), Color(0.25, 0.23, 0.22), 2)
	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.85, 0.45)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(7)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_color("font_color", "Button", CREAM)
	th.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	th.set_color("font_focus_color", "Button", Color(1, 0.9, 0.6))
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", Color(0.42, 0.4, 0.38))
	th.set_color("font_color", "Label", CREAM)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	th.set_constant("shadow_offset_x", "Label", 2)
	th.set_constant("shadow_offset_y", "Label", 2)
	var panel = _box(Color(0.07, 0.06, 0.08, 0.97), GOLD_DIM, 2, 10)
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	return th

func button(text: String, min_size: Vector2 = Vector2(260, 56), font_size: int = 22) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_entered.connect(func(): Sfx.play("tick", 1.0, -6.0))
	return b

func label(text: String, font_size: int = 20, color: Color = CREAM, title: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", font_title)
	return l

func panel_box(bg: Color, border: Color, bw: int = 2, radius: int = 10) -> StyleBoxFlat:
	return _box(bg, border, bw, radius)
