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
| **Field cleared** | **6131** | `Gnome Male Vocal 18 (Congratulations)` | A gnome literally says "congratulations" |
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
