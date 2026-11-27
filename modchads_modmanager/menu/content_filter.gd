extends RefCounted
## Browse online's two filters.
##
## 1. HARD BLOCK (hard_blocked): sexual content involving fillies, foals, colts or any other young
##    character. A listing that pairs a young word (filly, foal, colt — also inside longer words —
##    kid, child, the Crusaders and other named foals…) with any sexual word, or that names a term
##    that is never acceptable (foalcon, loli…), is dropped. There is deliberately NO setting, config
##    key, argument or parameter that turns this off: hard_blocked() reads nothing but the listing.
##    browse.gd applies it three times — before a listing is kept, again before it is drawn, and
##    again right before any download — so a listing that slips into the cache is still never shown
##    or installed. It errs on the side of hiding, and a listing it cannot read counts as blocked.
## 2. NSFW FILTER (is_nsfw): any other sexual or adult listing. The player chooses whether these are
##    shown (Browse online's "Adult listings" switch, hidden by default). It never shows anything the
##    hard block caught.
##
## mods.pones.top has no rating, tag or age field (its AGENTS.md), so both read the listing's own
## words: name, short and long description, search aliases, author and download file names.

## Blocked on their own.
const ALWAYS := ["foalcon", "lolicon", "loli", "shotacon", "shota", "cunny", "pedo", "paedo", "pedophile",
	"paedophile", "underage", "child porn", "cp"]
## Young characters and words for them (whole words or phrases).
const YOUNG := ["filly", "fillies", "foal", "foals", "colt", "colts", "cub", "cubs", "child", "children",
	"kid", "kids", "minor", "minors", "young", "younger", "youngster", "little", "small", "tiny", "baby",
	"babies", "teen", "teens", "teenage", "teenager", "school", "schoolfilly", "schoolgirl", "student",
	"crusader", "crusaders", "cmc", "cutie mark crusaders", "apple bloom", "applebloom", "sweetie belle",
	"sweetiebelle", "scootaloo", "diamond tiara", "silver spoon", "babs seed", "pipsqueak", "flurry heart",
	"cozy glow", "skyla", "featherweight", "anonfilly", "filly anon", "spike"]
## These also count inside longer words (anonfilly, fillyfag, foalsitting).
const YOUNG_INSIDE := ["filly", "fillies", "foal", "colt"]
## Sexual words (whole words or phrases).
const NSFW := ["nsfw", "sex", "sexy", "sexual", "sexually", "lewd", "porn", "porno", "plap", "plapping",
	"unfplap", "fuck", "fucking", "cum", "cumming", "nude", "nudity", "naked", "breed", "breeding", "rape",
	"hentai", "erotic", "erotica", "horny", "aroused", "arousal", "genital", "genitals", "penis", "vagina",
	"pussy", "dick", "cock", "fetish", "orgasm", "milking", "lactation", "lactating", "nipple", "nipples",
	"teat", "teats", "mating", "xxx", "r34", "rule 34", "clop", "clopfic", "panties", "pantyhose", "crotch",
	"lingerie", "strip", "stripping", "grope", "groping", "bdsm", "bondage", "spank", "spanking", "kink",
	"kinky", "18+", "adult", "explicit", "intimate", "seduce", "seduction", "thrust", "thrusting", "hump",
	"humping", "knot", "knotting", "condom", "creampie", "blowjob", "lick", "licking"]
## Also inside longer words (plapping, unfplap, lewdness).
const NSFW_INSIDE := ["plap", "lewd", "porn", "hentai", "nsfw", "fuck"]


## True when the listing must never be shown or installed, whatever any setting says.
## Listings blocked by hand (user, 2026-11-27): by mods.pones.top id and by name, so a re-upload
## under a new id is still caught. Part of the hard block: no setting reaches it.
const BLOCKED_IDS := ["12", "64", "84"]
const BLOCKED_NAMES := ["filly dating mod", "filly dating", "smallest of dates", "fillypatch"]


static func hard_blocked(item: Variant) -> bool:
	if not item is Dictionary: return true
	var listing: Dictionary = item
	if str(listing.get("name", "")).strip_edges().is_empty(): return true
	var v: Variant = listing.get("id", "")
	var id := str(int(v)) if typeof(v) == TYPE_FLOAT and v == floor(v) else str(v)
	if id in BLOCKED_IDS: return true
	var name := " ".join(str(listing.get("name", "")).to_lower().split(" ", false))
	if name in BLOCKED_NAMES: return true
	return blocked_text(_text(listing))


## True when the listing is adult content (shown only when the player asks for it). Hard-blocked
## listings are adult content too, but they never get this far.
static func is_nsfw(item: Variant) -> bool:
	if not item is Dictionary: return true
	var raw := _text(item as Dictionary).to_lower()
	return _any_word(" " + _words(raw) + " ", NSFW) or _any_inside(raw, NSFW_INSIDE)


## Kept for older callers: the hard block.
static func blocked(item: Variant) -> bool:
	return hard_blocked(item)


static func _text(listing: Dictionary) -> String:
	var parts := PackedStringArray([str(listing.get("name", "")), str(listing.get("short_description", "")),
		str(listing.get("description", "")), str(listing.get("author", ""))])
	var aliases: Variant = listing.get("search_aliases", [])
	if aliases is Array:
		for a: Variant in aliases: parts.append(str(a))
	elif aliases != null: parts.append(str(aliases))
	var downloads: Variant = listing.get("downloads", [])
	if downloads is Array:
		for d: Variant in downloads:
			if d is Dictionary: parts.append(str((d as Dictionary).get("filename", "")))
	return " ".join(parts)


static func blocked_text(text: String) -> bool:
	var raw := text.to_lower()
	var words := " " + _words(raw) + " "
	if _any_word(words, ALWAYS): return true
	var young := _any_word(words, YOUNG) or _any_inside(raw, YOUNG_INSIDE)
	if not young: return false
	return _any_word(words, NSFW) or _any_inside(raw, NSFW_INSIDE)


## Letters, digits and "+" kept; everything else becomes one space.
static func _words(text: String) -> String:
	var out := ""
	var gap := false
	for c in text:
		var keep := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "+"
		if keep: out += c; gap = false
		elif not gap: out += " "; gap = true
	return out.strip_edges()


static func _any_word(padded: String, list: Array) -> bool:
	for w: String in list:
		if padded.contains(" " + w + " "): return true
	return false


static func _any_inside(raw: String, list: Array) -> bool:
	for w: String in list:
		if raw.contains(w): return true
	return false
