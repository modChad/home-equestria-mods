extends Node
## Russian Ponies: every pony speaks Russian.
##
## Every speech request (solo replies, contacts, group exchanges and ambient chatter) is built from
## system.md plus the expression-tag prompt (world/ai/director_prompts.gd: system_prompt,
## _group_prompt, _ambient_prompt). The game's prompt overrides (world/ai/prompt_overrides.gd) are
## applied to every request in llm_client.gd build_request as plain text replacements, so this mod
## adds two replacements of its own to that table, in memory only:
## - system.md's "Plain conversational English" becomes "Plain conversational Russian";
## - a language note goes in front of the expression-tag prompt, which only speech requests carry
##   (not memory summaries, letters, photo descriptions or the feedback classifier).
## Nothing is written to the player's prompt files. The table is rebuilt whenever the player saves a
## prompt edit, so the rules are checked and put back every second. Switching the mod off takes
## them out again.
##
## Not covered (compiled game code): speech recognition is locked to English; voices are English;
## addressee.gd reads only Latin letters, so Russian names don't pick the listener (gaze and the
## last pony spoken to still do); the walk check and the out-of-character filter read English only.

const OVERRIDES := preload("res://world/ai/prompt_overrides.gd")

const ENGLISH := "Plain conversational English"
const RUSSIAN := "Plain conversational Russian"
## The start of FACE_TAGS.PROMPT (world/ai/pony_dialogue_tags.gd), in every speech request.
const TAGS_START := "Expression tags (optional, sparing, never spoken):"
const NOTE := "LANGUAGE: Russian. Anon speaks Russian, and every word you say aloud is natural, colloquial, spoken Russian, even if he slips into English and even though these rules, your persona, your memories and every note here are written in English. Your persona's example lines show who you are, not your wording: say things the way you would in Russian, with Russian equivalents for your terms of address, catchphrases and speech habits. Use the Russian dub's forms of pony and place names (Твайлайт Спаркл, Понивиль). Only spoken words change: [tags], action names, ids, JSON keys and <brain> notes stay exactly as specified, in English."

var _rules: Array = []


func _ready() -> void:
	_rules = [[ENGLISH, RUSSIAN, null], [TAGS_START, NOTE + "\n" + TAGS_START, null]]
	_install()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_install)
	add_child(timer)
	timer.start()


func _exit_tree() -> void:
	for rule: Array in _rules: OVERRIDES._rules.erase(rule)


## Puts the rules back after the table has been reloaded. They go last, after the player's own
## edits, so an edited sentence is still swapped first.
func _install() -> void:
	OVERRIDES.overrides()  # Loads (and so clears and rebuilds) the table first if it hasn't been yet.
	for rule: Array in _rules:
		if not OVERRIDES._rules.has(rule): OVERRIDES._rules.append(rule)
