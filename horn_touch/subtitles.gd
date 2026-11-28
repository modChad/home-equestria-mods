extends CanvasLayer
## Horn Touch: clear subtitles just above the hotbar while Anon is dazed, since the blur makes the
## ponies' own speech bubbles hard to read. A 2D layer, so the daze (a 3D quad) never covers it.
## Desktop only: a CanvasLayer doesn't reach a headset.
const BOTTOM := 96.0 # Pixels from the bottom of the screen: just over the hotbar.
var _label: RichTextLabel
var _panel: PanelContainer
var _tween: Tween


func _ready() -> void:
	layer = 110
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, .62)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16; box.content_margin_right = 16
	box.content_margin_top = 8; box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(560, 0)
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_font_size_override("bold_font_size", 22)
	_label.add_theme_color_override("default_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.modulate.a = 0.0
	get_viewport().size_changed.connect(_place)


func say(speaker: String, text: String, color: Color) -> void:
	var line := text.strip_edges()
	if line.is_empty(): return
	_label.text = "[b][color=#%s]%s:[/color][/b] %s" % [color.to_html(false), speaker.replace("[", "("), line.replace("[", "(")]
	_place.call_deferred()
	if _tween != null: _tween.kill()
	_panel.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(clampf(2.5 + line.length() * .06, 3.0, 12.0))
	_tween.tween_property(_panel, "modulate:a", 0.0, .6)


func _place() -> void:
	if not is_instance_valid(_panel): return
	var screen := get_viewport().get_visible_rect().size
	_label.custom_minimum_size.x = minf(720.0, screen.x * .7)
	_panel.reset_size()
	_panel.position = Vector2((screen.x - _panel.size.x) * .5, screen.y - BOTTOM - _panel.size.y)
