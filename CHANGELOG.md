# Changelog

## Unreleased

- **Personal bests.** Each difficulty keeps your best time (shared by all your characters, with the one who set it). A win says "New personal best!" or shows the best to beat, the difficulty list shows your best times, and its tooltip says how many games you've won.
- **Best times** (the trophy in the title bar, or `/gsweep scores`): every difficulty's best, who set it and when, and how many games you've won, at any time.
- The result line at the bottom no longer runs under the Play again / Try again button on Beginner.
- A new look: one glass style for the window, the buttons and the board. The tiles are a calmer, darker glass, the flag is a red pennant, and the gnome from the logo is your reset button, with a ring that changes with the game (sparkles when you clear the field, soot when you blow it).
- The difficulties wear WoW's item colours: Beginner is green, Intermediate blue, Expert purple. The list now says how big each board is and how many mines it has.
- The detonated tile gets a starburst behind the bomb, so you can find it without relying on red.
- "View board" on the result lets you look at a finished board; Play again or Try again stays at the bottom.
- The footer explains middle-click ("Clear around number"), and the **?** beside it says exactly when it works.
- `/gsweep scale 0.5` to `1.5` resizes the window (it never grows past your screen).

- A cleared field and a wipe each get their overlay ("Field cleared!" with your time and Play again; "Boom. Full wipe." with Try again), and the gnome face in the corner changes with the game. Click an overlay to put it away and look at the board.
- The game is playable: `/gsweep` opens the board. Left-click reveals, right-click flags, and left+right or middle-click on a number opens its neighbours when the flags match.

- Project initialised: glass window material, slash commands (`/gsweep`, `/gnomesweeper`, `/minewipe`). Not playable yet.
