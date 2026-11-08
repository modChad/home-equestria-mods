extends CanvasLayer
## Fishing: desktop-only prompts. A centre "Bite!" call and a tension bar while a fish is on.
## VR gets haptics and a floating "!" instead (feedback.gd); nothing here shows in a headset.
const FONT := preload("res://world/ui/fonts/PonyvilleMedium.ttf")
var _call: Label
var _sub: Label
var _bar_back: ColorRect
var _bar: ColorRect
var _call_time := -1.0
var _tension := -1.0
var _card: PanelContainer
var _card_name: Label
var _card_size: Label
var _card_best: Label
var _card_keys: Label
var _card_time := -1.0

func _ready() -> void:
	layer = 6
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_call = _label(64, Color("ffd34d")); root.add_child(_call)
	_sub = _label(26, Color("fff6dc")); root.add_child(_sub)
	_bar_back = ColorRect.new(); _bar_back.color = Color(0.1, 0.08, 0.06, .55); root.add_child(_bar_back)
	_bar = ColorRect.new(); _bar_back.add_child(_bar)
	_card = PanelContainer.new(); _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.99, 0.95, 0.85, .94); sb.border_color = Color("8a5a32")
	sb.set_border_width_all(3); sb.set_corner_radius_all(14); sb.content_margin_left = 22; sb.content_margin_right = 22
	sb.content_margin_top = 12; sb.content_margin_bottom = 14; _card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER; _card.add_child(box)
	_card_name = _plain(40, Color("4a2c18")); box.add_child(_card_name)
	_card_size = _plain(26, Color("6b4a2e")); box.add_child(_card_size)
	_card_best = _plain(22, Color("c0702a")); box.add_child(_card_best)
	_card_keys = _plain(20, Color("5a4636")); box.add_child(_card_keys)
	root.add_child(_card)
	_hide_all()

func _plain(size: int, colour: Color) -> Label:
	var l := Label.new(); l.add_theme_font_override("font", FONT); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The catch card: species, size, a best-ever note, and what to press.
func card(fish_name: String, length_m: float, best_note: String) -> void:
	_card_name.text = fish_name
	_card_size.text = "%d cm" % roundi(length_m * 100.0)
	_card_best.text = best_note; _card_best.visible = not best_note.is_empty()
	_card_keys.text = "[LMB] Keep   ·   [RMB] Release"
	_card.visible = true; _card_time = 0.0

func clear_card() -> void:
	_card.visible = false; _card_time = -1.0

func _label(size: int, colour: Color) -> Label:
	var l := Label.new(); l.add_theme_font_override("font", FONT); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour); l.add_theme_color_override("font_outline_color", Color("3a2616"))
	l.add_theme_constant_override("outline_size", 10 if size > 40 else 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _hide_all() -> void:
	_call.visible = false; _sub.visible = false; _bar_back.visible = false
	if _card != null: _card.visible = false

## "Bite!" with a pop-in; text under it says what to press.
func bite(sub_text := "Click to hook") -> void:
	_call.text = "Bite!"; _sub.text = sub_text; _call_time = 0.0
	_call.visible = true; _sub.visible = true

func clear_call() -> void:
	_call_time = -1.0; _call.visible = false; _sub.visible = false

## 0..1, or < 0 to hide.
func tension(value: float) -> void:
	_tension = value; _bar_back.visible = value >= 0.0

func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	if _call_time >= 0.0:
		_call_time += delta
		# Pop in, then a gentle pulse so it reads as urgent without flashing.
		var pop := minf(_call_time / .12, 1.0)
		var pulse := 1.0 + .06 * sin(_call_time * 9.0)
		_call.scale = Vector2.ONE * lerpf(1.6, 1.0, pop) * pulse
		_call.size = Vector2(size.x, 80); _call.pivot_offset = _call.size * .5
		_call.position = Vector2(0, size.y * .5 - 150)
		_sub.size = Vector2(size.x, 40); _sub.position = Vector2(0, size.y * .5 - 78)
	if _card_time >= 0.0:
		_card_time += delta
		_card.reset_size()
		var pop := minf(_card_time / .18, 1.0)
		_card.pivot_offset = _card.size * .5
		_card.scale = Vector2.ONE * lerpf(.6, 1.0, 1.0 - pow(1.0 - pop, 3.0))
		_card.position = Vector2(size.x * .5 - _card.size.x * .5, size.y * .88 - _card.size.y * .5)
	if _tension >= 0.0:
		var w := 260.0; var h := 14.0
		_bar_back.size = Vector2(w, h); _bar_back.position = Vector2((size.x - w) * .5, size.y * .74)
		_bar.size = Vector2((w - 4) * clampf(_tension, 0, 1), h - 4); _bar.position = Vector2(2, 2)
		_bar.color = Color("7ccf6a").lerp(Color("e8b13c"), smoothstep(.3, .6, _tension)).lerp(Color("e0503a"), smoothstep(.65, .9, _tension))
