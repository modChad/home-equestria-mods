# Kissing

- **Version:** 1.0.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop (hold K) and VR (lean in)

Kiss a pony without carrying her first. Before, the game's kiss only started once your mouth touched her face, which standing up only really happened while she was in your arms.

## How it works

- **Desktop:** face a pony within about 1.5 m and hold **K**. She turns to you, steps closer and reaches up to your lips. Let go of K before your lips meet and she stops.
- **VR:** lean in until your mouth is close to her lips (about 8 cm) for a moment. Draw back to end a light kiss. The game's own X button kiss still works too.
- **How deep:** the game's own rules decide. If she welcomes it, she kisses you back; hold the kiss for 0.6 s and it turns deep, and she keeps it going by herself for a while (press K again, or X in VR, to end it). If she doesn't welcome it, she turns her face away, and trying again straight after may earn a buck. Fillies and colts, or a young player, only ever get a kiss on the forehead.
- **Remembered:** ponies within 10 m who saw it remember it (at most once every 3 minutes per pony), so they may bring it up. The kissed pony's own memory of it is the game's.

## Install

Put `kissing-v1.0.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Build from source

Copy `main.gd`, `mod.json` and this README into `res://mods/kissing/` in the game project, then run `mods/build_packs.sh kissing`.

## Things to know

- Works at every pony size. At Hoers size she lowers her front to you, forelegs bending under her, and bows her neck down; once your lips meet she stops stepping in, so her chest doesn't walk into you.
- Carried ponies are left to the game's own bridal kiss.
- If her lips can't reach yours within 4 s (something in the way, or she can't get closer), the kiss is given up.
