#!/usr/bin/env bash
# Stages Kiss intensity for tools/pack.gd: devanon's 0.7.1 files from original/ (byte for byte, the
# two .glb models raw, as kiss_model.gd reads them) into build/kiss_intensity/stage/. Its .gdignore
# keeps the editor from importing the models there. Run before ./build_packs.sh kiss_intensity.
set -eu
MOD="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(dirname "$(dirname "$MOD")")/build/kiss_intensity/stage"
mkdir -p "$STAGE"
# Overwrites in place (no deletes). The copy of original/mod.json (0.7.1) is ignored: pack.gd
# packs mods/kiss_intensity/mod.json and skips the stage's.
cp -r "$MOD/original/." "$STAGE/"
touch "$STAGE/.gdignore"
echo "staged $(find "$STAGE" -type f ! -name .gdignore | wc -l) files in $STAGE"
