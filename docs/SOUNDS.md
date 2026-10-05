# Sounds and music

Gnomeregan sounds the client already has, played by **sound kit ID** (`PlaySound(kit, "SFX")`) or
**file ID** (`PlayMusic(fileID)`). Nothing ships as `.ogg` unless the client lacks it.

**What's known (porting guide, Stakeout probe on 69977):** `PlaySoundFile` **refuses built-in
game-file paths**, while sound kit IDs and file IDs play. `PlaySound`, `PlayMusic`, `StopMusic`,
`StopSound` and `C_Sound.PlaySound` are all in the 70170 dump.

**Source:** Retail Wowhead's sound database (2026-10-02). Wowhead's Forever sound database is
empty. Forever runs on Retail's data (its icon list includes 11.1 art), so these kits are
*probably* present. **None of them has been played on Forever yet**; the probe (#9) does that.
Low kit IDs (under ~8000) are vanilla-era sounds.

**Wired (#9, #22, `Sounds.lua`):** reveal 1115, flag 856 / unflag 857 (Blizzard's own UI clicks from
`SOUNDKIT`), wipe 7517 then 1038 (0.7 s later), win 6131, new game 4779, music 53189. **Pick by ear
with `/gsweep sounds`**: it plays every candidate below, 3 s apart, then the music, and saves what
the client said (`GnomesweeperDB.soundProbe`); swap the picks in `Sounds.KITS`.

**Measured in game** (owner, 1.60.1.70205, 2026-10-03, PR #42): **the music (53189), the bomb (7517)
then the gnome's death (1038), and the win (6131: a "hurray" and "Congratulations") all play.**
`PlayMusic` honours the game's Music toggle: with music off in the game's sound settings it is
silent. **`/gsweep sounds`** (same day, all 16 candidates): **13 play**; the three Cataclysm-era
Operation: Gnomeregan kits are **refused** (`willPlay` false): 17484, 17487, 17569. `PlayMusic(53189)`
returns true. **Closing the board stops ours and the zone's music comes back** (owner). Not yet
measured: whether the track loops.

**The owner's picks after listening** (2026-10-03): the clicks are fine ("a normal mouse click");
the **wipe cry and a greeting follow the character's sex** (`UnitSex`: 3278 / 3272 after the bomb,
5925 / 5931 on the first open of a session); an **alert when the clock passes your best** (once a
game): **kit 8456**, the owner's pick (a PvP warning; after auditioning 4574 `IG_PVP_UPDATE` and
25477, the battleground countdown); the new game: **kit 4935 `GnomeRoboArmFidget01Fidget02`** (its
file is 566083; the owner found the kit ID in Classic's data), a gnomish arm, in place of the big red
button 4779 that "doesn't sound like much". **A new personal best** (#10): the fanfare **878**
`IG_QUEST_LIST_COMPLETE` (provisional; `/gsweep sounds` auditions 31578, 63971, 73277), then the
gnome's cheer a second later, and with the fireworks **8569** (the owner's pick). The API can't list the client's sound kits (they are game data,
`SoundKit.db2`, not functions): candidates come from Wowhead names, confirmed by `/gsweep sounds`.
The owner once heard the zone's music and ours together; the music log is in place to catch when.

## Effects (#9)

`PlaySound(kit, "SFX")` is the global; `C_Sound.PlaySound(kit, uiSoundSubType, ...)` takes a
**`UISoundSubType` enum** second, not a channel string. Don't mix them up.

| Moment | Kit | Name | Notes |
|---|---|---|---|
| **Wipe: the mine goes off** | **7517** | `GnomeBomBotDeath` | The Walking Bomb's own death sound (file 569559, "MoltenBlastImpact"). |
| Wipe, bigger | 17484 | `Event_Operation_Gnomergan_Explosion` | Cataclysm-era event, file 567321 |
| **Wipe: a gnome's last words** | **1038** | `GnomeDeath` | **The owner's pick.** One file: 550358 `GnomeDeathA`. Plays right after the bomb: **sequence it** (a measured delay or `C_Sound.PlaySound`'s finish callback), since two immediate `PlaySound` calls overlap. |
| Wipe, alternatives | 3278 / 3272 | `GnomeMaleFinalDeath` / `GnomeFemaleMainDeath1` | Maybe to match the face's sex when the face is the player |
| Wipe: the villain gloats | 17569–17572 | `OG_Thermaplugg_Event01..04` | Mekgineer Thermaplugg's lines |
| Alarm (the Alarm-a-bomb) | 18871 / 12889 | `AlarmClockWarning1` / `3` | Or 10571 `Fel Reaver Alarm` for a bigger one |
| **Field cleared** | **2847** (was 6122) | the female gnome's `/cheer`, with Tally cheering on the panel (owner, #21). EmotesTextSound: CHEER (emote 21), Gnome (race 7), SexID 1 = female (2835 is the male); 6122 was her `/congratulate` | A gnome literally says "congratulations"; **a female gnome** (owner, 2026-10-04: the mascot is a she). Found in the game's `EmotesTextSound` table (wago.tools, classic era): CONGRATULATE (emote 26), Gnome (race 7) is male **6131** (`Gnome Male Vocal 18`, the first pick) and female **6122**. Every race's line is there, a reliable way to find an emote's voice |
| Field cleared, fanfare | 17487 | `Event-GnomereganEventComplete` | |
| New game (the face click) | 4779 / 15252 | `G_ButtonBigRed` / `UL_Gnomewing_ButtonBigRed_Close` | **Mimiron's big red button** (Ulduar) |
| Window opens | 5925 / 5931 | `GnomeMaleZanyNPCGreetings` / `GnomeFemaleNerdyNPCGreetings` | Once per session, not every open |
| Reveal / flag | `SOUNDKIT.*` UI clicks | — | Pick quiet UI ticks from `SOUNDKIT` in `wow-ui-source`; these fire constantly, so keep them subtle and optional |
| Ticking fuse (a near-done board?) | 232397 / 362580 | `FX_fuse_loop` / `Reuse_Explosions_Goblin_Precast_..._Ticking_Clicky` | An idea only |

## Music (#22)

Gnomeregan's zone music while a game is on screen, with a **mute button** in the title bar.

| Track | File ID | Kit |
|---|---|---|
| `gnomeragon01-zone` | **53189** | in `MUS_Gnomeregan` (22756) and `MUS_GatesofGnomeregan` (22746) |
| `gnomeragon02-zone` | **53190** | the same kits |
| `gnomeregan_event_intro`, `_B` … `_E`, `_complete` | 369058, 369053–369057, 369055 | Operation: Gnomeregan (Cataclysm-era). Optional, livelier. |

- `PlayMusic(53189)` replaces the zone music until `StopMusic()`. Unmeasured on Forever:
  - whether it takes a file ID;
  - whether it honours the Music toggle and volume;
  - whether `StopMusic` hands back the zone music;
  - how long a track runs and what happens at its end (there's no "finished" event for
    `PlayMusic`, so alternating tracks needs a timer from the measured length).
- **Off by default**, or on only after the player first unmutes. The setting is saved; the mute
  button and the settings panel (#8) change the same value.
- **One eligibility check** (window shown, not muted, not in combat) gates every start: no start on
  opening or unmuting during combat, and a pending track timer can't restart the music after a hide,
  mute or combat start. `StopMusic()` only if this addon started the music (it's the client's
  shared music, not our handle). Start with one track.
- Music stops when the window closes and when the player enters combat (it's their zone's music
  being replaced).
