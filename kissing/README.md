# Kissing

- **Version:** 1.1.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop (hold K) and VR (lean in)

Kiss a pony without carrying her first. Before, the game's kiss only started once your mouth touched her face, which standing up only really happened while she was in your arms.

## How it works

- **Desktop:** face a pony within about 1.5 m and hold **K**. She turns to you, steps closer and reaches up to your lips. Let go of K before your lips meet and she stops.
- **VR:** lean in until your mouth is close to her lips (about 8 cm) for a moment. Draw back to end a light kiss. The game's own X button kiss still works too.
- **How deep:** the game's own rules decide. If she welcomes it, she kisses you back; hold the kiss for 0.6 s and it turns deep, and she keeps it going by herself for a while (press K again, or X in VR, to end it). If she doesn't welcome it, she turns her face away, and trying again straight after may earn a buck. Fillies and colts, or a young player, only ever get a kiss on the forehead.
- **Remembered:** ponies within 10 m who saw it remember it (at most once every 3 minutes per pony), so they may bring it up. The kissed pony's own memory of it is the game's.

## Her feelings build (1.1.0)

Instead of the game's loud magic flare every second, a pony's excitement now builds up and shows the way her kind shows it. It rises through a kiss (faster once it turns deep), up to a peak set by your bond: acquaintance 35%, friend 50%, close friend 70%, dating 85%, engaged 95%, married 100%. Long head scratches and the AI's excited moments build it more slowly. Once it's over it holds a moment, then fades over a few seconds.

- **Unicorns and alicorns:** the horn glows faintly at first, then brighter, with sparkles, breathing in a pulse that quickens; a soft magic hum rises with it. No cast sounds.
- **Pegasi and alicorns:** once the game has spread her wings and her feelings run past about half, a fine tremble runs through them, with a ripple now and then, stronger as it builds.
- **Earth ponies:** she grows fidgety: rocking her weight, swishing her tail, flicking her ears and tapping a forehoof.

After a kiss she steps back out of your face, and you stand up again once there's room.

## Install

Put `kissing-v1.1.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Build from source

Copy `main.gd`, `mod.json` and this README into `res://mods/kissing/` in the game project, then run `mods/build_packs.sh kissing`.

## Things to know

- Works at every pony size. At Hoers size she lowers her front to you, forelegs bending under her, and bows her neck down; once your lips meet she stops stepping in, so her chest doesn't walk into you.
- Carried ponies are left to the game's own bridal kiss.
- If her lips can't reach yours within 4 s (something in the way, or she can't get closer), the kiss is given up.
