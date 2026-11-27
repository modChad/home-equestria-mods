# modChads modManager

- **Version:** 1.1.0
- **Author:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev
- **Works on:** desktop (VR attempted, not tested)

A better **Settings → Mods**, in the game's own colours and fonts.

## Reload game

At the right of the tab bar: **Reload game** saves the open world and restarts the game at the **main menu** (press twice). It lights up when mod changes are waiting. The list under it can load straight **into your last save** or a chosen one instead. This replaces the Mod Reloader mod, which is retired: remove `mod-reloader-v1.0.0.pck` from your mods folder.

## Installed

- **Search** by name, author or description, and **sort** A–Z, on first, or by author.
- **Filters:** All, On, Off, Needs restart, Has settings, Included, Added by you, each with a count.
- **Compact rows:** name, version and author with badges, a one-line description and an Off | On switch. The arrow opens the full description, the game's notes and the list of game files a mod replaces.
- **Restart notice** naming the mods that change at the next start.
- **One A–Z list** of every mod, yours and the ones that come with the game alike; those wear an "Included" badge, and the Included / Added by you filters split them.
- **All on / All off** for the mods shown (scenario mods are left out).
- **Settings** button on mods that add their own page to the settings sidebar, such as Flowing Manes.

## Problems

This tab appears only when something is wrong (Installed shows a "See what's wrong" notice too). One card per problem, in plain words, with what to do and buttons that do it (show the mod in Installed, switch it off, open the mods folder, look for an update). When mods.pones.top lists a newer version, the card offers **Update** — only for a `.pck` downloaded from GitHub whose security check found nothing; otherwise it says why and links the listing's page:

- a mod held back because it was made for an older game and replaces game files,
- a mod that could not be loaded, whose code does not run, or that needs another mod,
- an older copy of a mod you have twice,
- a scenario mod held back because another one is on,
- a mod that replaces core game scripts (saving and loading),
- two mods that are on replacing the same game file (only the one that loads last takes effect).

## Browse online

- The listings at [mods.pones.top](https://mods.pones.top/), newest first, with **newer versions of mods you have** at the top. Search, and filter by Updates for my mods, Not installed, Security check passed or Highest rated.
- Each listing shows its version, author, the site's security check result and whether you have it.
- **Install** (press twice) downloads the mod's `.pck` into your mods folder; it loads the next time the game starts. One-click installs and updates only download a `.pck` from **GitHub** whose security check found nothing; anything else (another host, a `.zip`, findings) shows why and links the listing's page instead.
- **Downloads from u.pone.rs** (off by default): press **Allow** twice to also allow one-click installs from u.pone.rs and of listings whose security check had findings. **Stop** turns it off. Red-flagged listings and the content block are never allowed.
- **Hard block, no switch:** listings with sexual content involving fillies, foals, colts or any other young character are never shown and can't be installed from this menu, whatever any setting says. It's checked when the list arrives, again before anything is drawn and again before any download. The site has no age or adult tag, so the menu reads each listing's own text and errs on the side of hiding.
- **Adult listings (18+):** other adult or sexual listings are hidden by default; the switch at the bottom of the tab shows them. It never shows anything the hard block caught.
- Listings the site's security check red-flags are hidden too.
- The list is fetched when you open the tab (at most every 10 minutes) or press Refresh; it never polls.

## Install

Put `modchads-modmanager-v1.1.0.pck` in the game's `mods` folder, switch it on in **Settings → Mods** and restart the game.

## Things to know

- It changes only the Mods tab of the settings page (it extends `world/ui/settings_page.gd`), so a game update to that page may need a new version.
- Mods can run code on your computer. Listings are posted by players and are not checked by the game's developer.

## Changes

- **1.1.0** (2026-11-27): renamed to modChads modManager (settings reset); optional u.pone.rs downloads switch; Open page links fixed (`/mod/37`, not `/mod/37.0`); GitHub `/blob/` download links are fetched as `/raw/`, and release-page links (`/releases/tag/<tag>`) as that release's `.pck`.
- **1.0.0** (2026-11-26): first release.
