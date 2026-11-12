# Typing Lock

- **Version:** 1.0.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop (VR attempted, not tested)

While you type in any text box (the Enter chat, the ` console, search fields), every game hotkey is switched off and Anon stays exactly where he is. Typing "Wait" no longer walks you forward, and typing "quick" no longer gets you up from a bed, a seat or the grass.

## What it changes

- All key bindings for movement, jump, sprint, crouch, get up (Q), push-to-talk and the other game actions are paused while a text box has focus. Typing, Backspace, the arrow keys, Enter and Esc still work in the box.
- Movement stays locked the whole time you type, even if something else tries to unlock it.
- Your keys come back the moment you finish typing (Enter, Esc or clicking away). Nothing is changed in your saved key bindings.
- Menus and the main menu are left alone.

## Install

Put `typing-lock-v1.0.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Things to know

- A mod that reads raw keys without checking for an open text box can still react to them. Anything bound through the game's key settings is covered.
- In VR, walking is also paused while a text box (the panel keyboard) has focus.
