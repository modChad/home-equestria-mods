# Pegasus Ride

Fly through Equestria on the back of any pegasus — to a named place, in
circles, or wherever. A mod for **Home: Equestria 0.3.0-maredev**.

| | |
|---|---|
| Version | 2.2.1 |
| Folder | `res://mods/pegasus_ride_v2/` |
| Entry | `main.gd` |

---

## What's new

See `CHANGES.md` for what changed in each version and why. In short, since 2.1:

- **2.2.1:** no more getting stuck in the air at the bigger pony sizes; no surprise pick-ups after
  landing; everything in English.
- **2.2.0:** Celestia and Luna can carry you (the seat is measured from each pony's back); the
  friendship requirement works (Friend or closer); quieter log.

## Requirements

- A game build with **Settings → Mods**.
- A winged pony within **20 m**: any pegasus, or Princess Celestia or Luna.
- She must be your **Friend** or closer (the game's bond stages: Friend, Good/Close Friend,
  dating, engaged, married). Strangers and acquaintances won't carry you.
  If the mod cannot find the relationship system, it allows every winged pony.

---

## Installing

1. Put `pegasus-ride-v2-v2.2.1.pck` in your mods folder
   (**Settings → Mods → Open mods folder**).
2. Restart the game.
3. The Mods menu must show **"Pegasus Ride 2.2.1 – Anon"**.

**Important:** if an older `pegasus_ride.pck` is still in the folder, remove
it. Two mods listening on `N` trigger each other.

---

## Controls

**Keyboard**

| Key | Action |
|---|---|
| `N` | mount / dismount. In flight: begin the landing |
| `V` | circle over Ponyville |
| `P` | explore — fly to random places |

`N` is a toggle. First press mounts, second press lands.

**VR**

| Input | Action |
|---|---|
| Grip + `B`/`Y` | mount / dismount |

There is no separate VR button for cruising or exploring — name a place, or
ask her.

---

## What you can say

Talk to her normally (`T` push-to-talk, or the chat box). The mod reads the
text and the AI turns it into flight orders.

| Say | Happens |
|---|---|
| a place name — "Canterlot", "Sweet Apple Acres", "to the town hall" | flies there and lands in front of it |
| "**explore**" / "**erkunde**" / "random place" | random destinations, 8 s hover between them |
| "cruise" / "circle" | a wide circle over Ponyville |
| "land" / "stop" | landing approach |

The words `explore`, `erkunde` and `random place` are matched **literally**.
Everything else goes through the AI, which emits action tags:
`[fly_to: <place>]`, `[hover: 77]` (explore), `[circle_over: player]`
(circle), `[land]`.

Bridges, fountains, stages and canal sections are excluded from the
destination list — there is no safe landing spot there.

---

## How flight works

**The flight rig.** A freshly loaded pony has no flight object yet. The mod
creates it before takeoff via `_ensure_flight()`. If it is missing, the mod
says so instead of failing.

**The route.** Takeoff and travel are written **directly** into the flight
controller's route. `pony_flight.request()` is deliberately **not** used: it
refuses while she is held (`Physical interaction`), while her posture is still
changing (`Stand before takeoff`), or while she is already airborne
(`Already flying`).

**The approach** comes in from outside at roughly 45°. There is no vertical
descent over the target and no flat movement at ground level — both led to
flights through house walls.

**The landing spot** is verified. Two conditions must hold:

- the point may be at most 6 m below the ground hit (otherwise it is a bridge
  underside, an awning, or an alley)
- there must be 12 m of clear air above it

Only then does she land.

**No idle timeout.** While hovering and waiting, she stays up for as long as
you like. There is no deadline after which the mod ends the ride by itself.

**Dismounting.** Collision, seating and the navigator are restored. This also
happens on a world change or when the mod is unloaded — otherwise the player
falls through the floor.

---

## Tuning

All values live at the top of `main.gd`.

| Constant | Default | Meaning |
|---|---|---|
| `RANGE` | `20.0` | pegasus search radius |
| `CRUISE_ALT` | `28.0` | **cruise clearance above terrain.** The knob for approach duration |
| `GLIDE_RATIO` | `1.0` | lead-in per metre of descent; 1.0 ≈ 45° |
| `GLIDE_MIN` / `GLIDE_MAX` | `10` / `45` | limits on that lead-in |
| `HEADROOM` | `12.0` | clear air above the landing spot |
| `GROUND_SLACK` | `6.0` | how far below the ground hit a spot may sit |
| `MIN_FRIENDSHIP` | `60.0` | unlock threshold |
| `EXPLORE_PAUSE` | `8.0` | hover between two explore targets |
| `EXPLORE_TRIES` | `6` | attempts per explore hop |
| `CRUISE_RADIUS` | `110.0` | radius of the circular path |
| `BAD_ID` | `bridge, fountain, …` | place names dropped from the list |

**The two knobs you are most likely to need**

| Problem | Value |
|---|---|
| approach takes too long | lower `CRUISE_ALT` (28 → 20) |
| she clips rooftops | raise `CRUISE_ALT`, or set `HEADROOM` to 16 |

---

## Diagnostics

`DIAG_FLIGHT := true` (top of `main.gd`) prints one line every second:

```plaintext
[PegasusRide] FLY mode=cruise to=Canterlot state=cruise route=3 height=312.4 below_cruise=0.0
```

| Value | Meaning |
|---|---|
| `mode` | `hover`, `destination`, `cruise`, `explore`, `explore_pause`, `landing` |
| `state` | the game's flight state: `grounded`, `takeoff`, `cruise`, `landing` |
| `route` | waypoints still to fly |

Further lines on takeoff and for every destination:

```plaintext
[PegasusRide] mounted: rainbow_dash scale=1.35
[PegasusRide] 22 places known
[PegasusRide] GO path=manual to=Canterlot height=312 glide=14 distance=2732
```

---

## Known limits

- **VR untested.**
- **Seat checked on Fluttershy, Celestia and Luna** (measured from each back);
  full rides tested only with Rainbow Dash before 2.2.0.
- **Even short trips climb high.** `CRUISE_ALT` applies to every distance; a
  flight across the street reaches the same altitude as a long journey.
- **The landing spot is searched for, not guaranteed.** If the mod finds
  nothing in six attempts, she stays up and says so.
- **The seated position is set hard.** The player follows the saddle position
  every frame; there is no spring damping.

---

## Building

From the game project, with this folder at `res://mods/pegasus_ride_v2/`:

```
mods/build_packs.sh pegasus_ride_v2
```

That writes `mods/release_packs/pegasus-ride-v2-v2.2.1.pck`.

Check the syntax first:

```powershell
Copy-Item <game>\mods\pegasus_ride_v2\main.gd C:\ModPack\check.gd -Force
godot --headless --path C:\ModPack --check-only --script res://check.gd
```

Important when editing: **never** use `:=` for a property assignment
(`process_physics_priority = 90`, not `:=`). That is exactly what made one
revision fail silently.