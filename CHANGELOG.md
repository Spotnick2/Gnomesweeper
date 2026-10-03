# Changelog

## v0.1.0-beta

The first beta: Minesweeper in World of Warcraft: Forever, for queues and flight paths.
`/gsweep` (or `/gnomesweeper`, `/minewipe`) to play. Found a bug? Report it on GitHub
(the link is in Options > AddOns > Gnomesweeper > About): it's tested on one setup, so
your reports matter.

**The game**
- **Windows XP's rules**: Beginner 9x9, Intermediate 16x16, Expert 30x16. The first click is always safe and opens an area (or a single safe tile, as in XP: a setting).
- Left-click reveals, right-click flags, middle-click (or left+right) clears around a number once its flags match. Question marks and clearing with a left-click are settings.
- Changing the difficulty mid-game asks first ("Start Expert? This game will be lost."), once you've made progress.
- A cleared field and a wipe each get their result ("Field cleared!" with your time, "Boom. Full wipe."). "See the field" puts it away so you can look at the board; Play again or Try again stays at the bottom.

**Your best times**
- Each difficulty keeps your best time, shared by all your characters (with who set it and when), and how many games you've won. The trophy in the title bar (or `/gsweep scores`) shows them all.
- **The clock warns you**: yellow as you near your best, flashing in the last 3 seconds, red once you're past it, with an alarm.
- **A new personal best** shows your time to the tenth and how much you beat the old one by, with a fanfare and **fireworks** over the board (a setting). **Reset best times** in the settings wipes them (click twice).

**The gnome**
- She's your new-game button, and she reacts: focused while you play, surprised while you hold a tile, laughing when you clear the field, sooty after a wipe. She bounces, shudders, nods, and breathes quietly while you play.
- A new game reshuffles the field in a wave while a gnomish arm whirs; a click skips it.
- A first-launch hint points at her.

**Look and sound**
- Liquid glass, with two looks for the board: **Classic** and **Modern** (ice-blue glass tiles). The difficulties wear WoW's item colours: Beginner green, Intermediate blue, Expert purple.
- **Sounds**: a click for every reveal and flag, the Walking Bomb and a gnome's last words on a wipe (male or female, like your character), a female gnome's "Congratulations" when you clear the field, a hello when you first open the board. The speaker in the title bar mutes them.
- **Gnomeregan's music** while the board is open (off by default): the note in the title bar. It never plays in combat, and your zone's music comes back when you close the board.

**Getting to it**
- **Hide in combat** (on by default): pulling a mob puts the board away, paused, and it comes back when the fight ends (`/gsweep combat`).
- A **minimap button** (left-click plays, right-click opens the settings; hide it in the settings or with `/gsweep minimap`), an entry in the minimap's addon list, and a **key binding** (Key Bindings > Gnomesweeper).
- **Settings** in Options > AddOns > Gnomesweeper (the gear in the title bar, or `/gsweep settings`), with an About page. `/gsweep scale 0.5` to `1.5` resizes the window; it never grows past your screen.
