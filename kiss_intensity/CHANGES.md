# Kiss intensity: changes by modChad

Kiss intensity is **devanon's** mod (bundled with the game as 0.7.1). modChad changed nothing in
how it works.

## 0.7.3 (2026-11-27)

- Version bump only (0.7.2 → 0.7.3), so modManager shows it as newer. Same files as 0.7.2.

## 0.7.2 (2026-11-27)

- `mod.json` only: `"depends": {"kissing": "=1.2.11"}` → `{"kissing": ">=1.2.11"}`, version
  0.7.1 → 0.7.2, and the description's "For Kissing 1.2.11" → "For Kissing 1.2.11 and newer".
- Why: the exact pin switched Kiss intensity off with Kissing 1.2.12 and later, although nothing
  it hooks in Kissing (`_start`, `_rearing`, `_kisser`, the feelings node's `level`) changed.
- Every other file is devanon's 0.7.1 byte for byte (`original/`, taken from the game's
  `mods/bundled/kiss_intensity.pck`, sha256 77c82b34…). In the mods folder, 0.7.2 and later supersede the
  bundled 0.7.1 (the game loads the higher version of the same mod id).
