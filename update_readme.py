#!/usr/bin/env python3
"""Keeps the Mods table in .github/README.md in step with the built packs.

For each mod folder with a mod.json (not dinnerbone, nor one marked "private": true), finds its pack in release_packs/
(<folder with _ as ->-v<version>.pck) and sets that row's Version and Download cells. A mod
with a pack but no row gets a new row, its "What it does" taken from mod.json. The hand-written
"What it does" text of existing rows is left alone. Run by build_packs.sh after each build:
    ./update_readme.py
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
README = os.path.join(HERE, ".github", "README.md")
PACKS = "release_packs"
RAW = "https://github.com/modChad/home-equestria-mods/raw/main/" + PACKS + "/"
SKIP = {"dinnerbone", PACKS}


def mods():
    out = {}
    for d in sorted(os.listdir(HERE)):
        manifest = os.path.join(HERE, d, "mod.json")
        if d in SKIP or d.startswith(".") or not os.path.isfile(manifest): continue
        with open(manifest) as f: m = json.load(f)
        if m.get("private"): continue   # debug tools and the like: not in the public table
        out[d] = m
    return out


def link_for(folder):
    for name in ("README.md", "Readme.md", "readme.md", "README.txt", "Readme.txt"):
        if os.path.isfile(os.path.join(HERE, folder, name)): return "../" + folder + "/" + name
    return "../" + folder + "/"


def main():
    with open(README) as f: text = f.read()
    lines = text.split("\n")
    try: head = next(i for i, l in enumerate(lines) if l.startswith("| Mod |"))
    except StopIteration: sys.exit("update_readme: no '| Mod |' table in " + README)
    end = head + 2
    while end < len(lines) and lines[end].startswith("|"): end += 1
    rows = lines[head + 2:end]
    found = mods()
    seen = set()
    changed = []
    for i, row in enumerate(rows):
        cells = row.split(" | ")
        m = re.search(r"\]\((?:\.\./)?([^/)]+)/", cells[0])
        folder = m.group(1) if m else None
        if folder not in found: continue
        seen.add(folder)
        version = found[folder].get("version", "")
        pack = "%s-v%s.pck" % (folder.replace("_", "-"), version)
        if not os.path.isfile(os.path.join(HERE, PACKS, pack)):
            print("update_readme: no %s/%s yet; %s row left as it was" % (PACKS, pack, folder)); continue
        cells[1] = version
        cells[2] = "[%s](%s%s)" % (pack, RAW, pack)
        new = " | ".join(cells)
        if new != row: rows[i] = new; changed.append(folder)
    for folder, manifest in found.items():
        if folder in seen: continue
        version = manifest.get("version", "")
        pack = "%s-v%s.pck" % (folder.replace("_", "-"), version)
        if not os.path.isfile(os.path.join(HERE, PACKS, pack)): continue
        what = manifest.get("description", "").replace("|", "/").strip()
        rows.append("| [%s](%s) | %s | [%s](%s%s) | %s |" % (manifest.get("name", folder), link_for(folder), version, pack, RAW, pack, what))
        changed.append(folder + " (new row)")
    if not changed:
        print("update_readme: .github/README.md already up to date"); return
    lines[head + 2:end] = rows
    with open(README, "w") as f: f.write("\n".join(lines))
    print("update_readme: updated " + ", ".join(changed))


if __name__ == "__main__": main()
