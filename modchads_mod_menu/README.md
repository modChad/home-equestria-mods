# modChad's Mod Menu

- **Version:** 1.0.0
- **Author:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev
- **Works on:** desktop (VR attempted, not tested)

A better **Settings → Mods**, in the game's own colours and fonts.

## Installed

- **Search** by name, author or description, and **sort** A–Z, on first, or by author.
- **Filters:** All, On, Off, Needs restart, Has settings, Problems, Included, Added by you, each with a count.
- **Compact rows:** name, version and author with badges, a one-line description and an Off | On switch. The arrow opens the full description, the game's notes and the list of game files a mod replaces.
- **Restart notice** naming the mods that change at the next start. With Mod Reloader on, its "Reload from last save" button still appears under "Open mods folder".
- **Conflict notice** when two mods that are on replace the same game file (only the one that loads last takes effect).
- **One A–Z list** of every mod, yours and the ones that come with the game alike; those wear an "Included" badge, and the Included / Added by you filters split them.
- **All on / All off** for the mods shown (scenario mods are left out).
- **Settings** button on mods that add their own page to the settings sidebar, such as Flowing Manes.

## Browse online

- The listings at [mods.pones.top](https://mods.pones.top/), newest first, with **newer versions of mods you have** at the top. Search, and filter by Updates for my mods, Not installed, Security check passed or Highest rated.
- Each listing shows its version, author, the site's security check result and whether you have it.
- **Install** (press twice) downloads the mod's `.pck` into your mods folder; it loads the next time the game starts. Listings without a `.pck` download open their page instead.
- **Hard block, no switch:** listings with sexual content involving fillies, foals, colts or any other young character are never shown and can't be installed from this menu, whatever any setting says. It's checked when the list arrives, again before anything is drawn and again before any download. The site has no age or adult tag, so the menu reads each listing's own text and errs on the side of hiding.
- **Adult listings (18+):** other adult or sexual listings are hidden by default; the switch at the bottom of the tab shows them. It never shows anything the hard block caught.
- Listings the site's security check red-flags are hidden too.
- The list is fetched when you open the tab (at most every 10 minutes) or press Refresh; it never polls.

## Install

Put `modchads-mod-menu-v1.0.0.pck` in the game's `mods` folder, switch it on in **Settings → Mods** and restart the game.

## Things to know

- It changes only the Mods tab of the settings page (it extends `world/ui/settings_page.gd`), so a game update to that page may need a new version.
- Mods can run code on your computer. Listings are posted by players and are not checked by the game's developer.
