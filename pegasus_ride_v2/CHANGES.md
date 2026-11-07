# Pegasus Ride: what changed and why

## 2.2.1

Fixes for problems found while playing 2.2.0.

### Bigger pony sizes: she got stuck in the air
- **What happened:** at the JRHNBR, Same height and Hoers sizes she stopped mid-flight and the log
  filled with "stuck for 5 s - lifting her clear" every few seconds. Canon size was fine.
- **Why:** the game's own flight looks for anything in her way in a ball around her chest, and only
  ignores her own body. That ball grows with her size, so at the bigger sizes it takes in her
  rider. Anon's main body was already switched off while riding, but his hands and anything he
  holds were not, so she treated him as an obstacle. The mod's own bridge-and-roof check also
  started its rays at fixed heights that sit inside her body at those sizes, and it re-routed her
  on every frame it hit something.
- **Change:** all of Anon's colliders (hands, held things) are switched off while he rides and put
  back when he gets off. The mod's obstacle check now ignores her and Anon, scales with her size,
  and waits 1.5 s after a re-route before trying another.
- **If it still happens:** the stuck warning now also gives her size, the flight state and the
  reason the game gives for stopping, which pins down the cause.

### She picked you up again after landing
- **What happened:** after a flight ended, she would sometimes put you back on her back a little
  later, without you pressing N.
- **Why:** two things together. The mod listens to everything you say, and any sentence with
  "explore", "cruise" or "fly around" mounted you on the nearest winged friend; "let's explore the
  town" was enough. And while you ride, the mod gives her AI a note saying she is carrying you, but
  nothing replaced that note when you got off, so she went on believing you were on her back, kept
  talking about flying and invited the very words that re-mounted you.
- **Change:** getting on by voice now needs you to ask for a ride in so many words ("fly", "ride",
  "your back", "take me up", ...), and is not possible for 30 s after landing. N still mounts you at
  once. When you get off, her note is replaced with one saying the flight is over and not to offer
  again unless you ask.

### English throughout
- **Why:** the log messages and code comments were mostly in German.
- **Change:** all of them are English now. The spoken keywords "erkunde" and "kreise" still work
  alongside the English ones.

## 2.2.0

Adapted for Home: Equestria 0.3.0-maredev.

### Celestia and Luna can carry you
- **Why:** the seat was a fixed height (0.66 x her size above her feet), tuned on Rainbow Dash.
  Celestia's body stands about 30 cm taller at the same size, so her rider sat inside her.
- **Change:** the seat is measured from each pony's own body: the top of her back over the middle
  of it, found once per pony and followed as she moves. It fits any pony and any size setting.

### The friendship requirement works
- **Why:** the readme asked for friendship 60, the code asked for 20, and then it allowed the ride
  whatever the result, so any pegasus, even a stranger, would carry you.
- **Change:** she must be your Friend or closer (the game's own bond stages: Friend, close friend,
  dating, engaged, married). If the mod can't find the relationship system it still allows every
  winged pony, as before.

### Quieter log
- **Why:** a flight report was printed every second.
- **Change:** off by default; `DIAG_FLIGHT` at the top of `main.gd` turns it back on.

### Version labels
- **Why:** mod.json said 1.4.0 and game 0.1.0 while the readme said 2.1.0.
- **Change:** both now give the same version, for game 0.3.0-maredev.

## Known limits
- Princess open wings don't fit their bodies perfectly yet (a game bug), so their wings may look a
  little off in flight.
- VR is untested. Full rides at the bigger sizes and on the princesses were not tested in the
  game world, only the seat and a stand-in flight.
