#!/usr/bin/env bash
# Builds each mod's .pck into mods/release_packs/ as <name>-v<version>.pck, the name being the mod's
# folder with _ as - and the version from its mod.json (mods/idle_life 1.2.0 ->
# mods/release_packs/idle-life-v1.2.0.pck). A pack of the same name there is replaced.
#   ./build_packs.sh                     every mod here
#   ./build_packs.sh grooming teleport   just these
# The game's build tool packs every file in a mod's folder, so any .pck still in it (older
# packs) is set aside in mods/.build_aside/ while the new one builds and put back afterwards.
# Afterwards update_readme.py brings .github/README.md's download table up to date.
set -u
MODS="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$MODS")"
OUT="$MODS/release_packs"
GODOT="${GODOT:-$PROJECT/tools/godot-4.5/Godot_v4.5-stable_linux.x86_64}"
ASIDE="$MODS/.build_aside"
mkdir -p "$OUT"
if [ $# -gt 0 ]; then ids=("$@"); else
	ids=(); for f in "$MODS"/*/mod.json; do id="$(basename "$(dirname "$f")")"; [ "$id" = dinnerbone ] || ids+=("$id"); done
fi
failed=0
for id in "${ids[@]}"; do
	manifest="$MODS/$id/mod.json"
	version="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
	if [ -z "$version" ]; then echo "FAILED  $id (no version in $id/mod.json)"; failed=1; continue; fi
	name="${id//_/-}-v$version.pck"
	# Older packs out of the mod's folder while it builds.
	mkdir -p "$ASIDE/$id"
	moved=()
	for old in "$MODS/$id"/*.pck; do
		[ -e "$old" ] || continue
		if mv "$old" "$ASIDE/$id/"; then moved+=("$(basename "$old")"); else echo "FAILED  $id (cannot move $(basename "$old") out of the way)"; failed=1; continue 2; fi
	done
	if "$GODOT" --headless --xr-mode off --path "$PROJECT" --script res://tools/modding/build_mod.gd -- "$id" --out "$OUT/$name" 2>&1 | grep -q '^MOD_BUILT'; then
		echo "built   mods/release_packs/$name"
	else
		echo "FAILED  $id (run the build_mod.gd command by hand to see why)"; failed=1
	fi
	for old in "${moved[@]}"; do mv "$ASIDE/$id/$old" "$MODS/$id/$old"; done
	rmdir "$ASIDE/$id" 2>/dev/null
done
rmdir "$ASIDE" 2>/dev/null
# The download table in .github/README.md, to match the packs now in release_packs/.
if command -v python3 >/dev/null; then python3 "$MODS/update_readme.py" || failed=1
else echo "python3 not found: update .github/README.md's Mods table by hand"; fi
exit $failed
