# Kissing

- **Version:** 1.2.8
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

## Into your arms (1.2.0)

In a deep kiss with a pony you're dating, engaged or married to, she rears up on her hind legs, forelegs folded, then rests them over your shoulders and kneads gently while you kiss. When the kiss ends she drops back down. A small pony (Canon size) can't reach a standing Anon's shoulders, so you stay bent to her. At Hoers size she bows down to you instead. The rise was keyframed in Blender on the game's own rig.

## Less clipping (1.2.1)

Her face now stays a few centimetres off your eyes (her neck turns her head back if her skull or nose gets too close), and if her neck or chest comes too close to you she backs up instead of walking in. Fixes the camera ending up inside her head or body, mostly at bigger sizes and during the rear.

## Canon size fix (1.2.2)

At Canon size her forehead and mane went through the camera during normal kisses and the rear. She now keeps her head further off your eyes.

## Rear at Canon (1.2.3)

At Canon size she now rests her forehooves on your chest instead of your shoulders, so you no longer bend down into her neck and chest.

## Rear toggle (1.2.4)

Press **Shift+K** to turn rearing kisses on or off. A message confirms it, and the choice is remembered.

## Fixes (1.2.5)

- Her muzzle (the bridge of her nose) is now kept off your eyes too, not just her skull and nose tip. Fixes clipping in normal kisses at Canon and JRHNBR sizes.
- You no longer stay bent after a kiss: she steps back further, and you straighten up within 2.5 s regardless.

## Fix (1.2.6)

When you bend down to her, your body now crouches with your view instead of staying upright, so the camera no longer sinks into your own chest.

## Head tilt (1.2.7)

She tilts her head to one side as she kisses you (a random side each kiss), so her forehead passes beside your eyes instead of into them.

## Horn Glow (1.2.8)

With the Horn Glow mod, a unicorn's build-up lights the glow around her horn (and its hum) instead of the round disc of light.

## Install

Put `kissing-v1.2.8.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Build from source

Copy this folder into `res://mods/kissing/` in the game project, then run `mods/build_packs.sh kissing`.

## Things to know

- Works at every pony size. At Hoers size she lowers her front to you, forelegs bending under her, and bows her neck down; once your lips meet she stops stepping in, so her chest doesn't walk into you.
- Carried ponies are left to the game's own bridal kiss.
- If her lips can't reach yours within 4 s (something in the way, or she can't get closer), the kiss is given up.
