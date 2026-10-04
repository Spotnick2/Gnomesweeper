# Social: guild best times, guild-best toasts, friends

The plan for #15 (the guild's best times), #17 (a new guild best, shown as a toast to addon
users) and #16 (friends). Decided with the owner on 2026-10-04:

- the social side comes before the 3D models;
- **no guild chat lines at all**, only hidden addon messages;
- the guild sees **each character's own** times (not the account's best);
- a toast **only for a new guild best**, **anywhere on screen**, **never in combat**, and only
  once this client has heard the guild's times since login.

Revised after two adversarial passes (Codex, 2026-10-04). The first: the per-account scores
problem, a 257-byte packet the first draft allowed, replies starving late joiners, sender
identity, the exact grammar, one eligibility rule everywhere, honest toasts, merge order. The
second: "synced" unlocking before the replies' window closed, seeding by name without the realm,
a tie toasting, and an epoch of ten zeros.

Read first: the porting guide's "Addon-to-addon transports", and AltStable's measured
messaging (`..\AltStable\docs\SYNC-DISCOVERY.md`, `..\AltStable\Core.lua`'s send path).
Measured there on this client:

- `C_ChatInfo.SendAddonMessage` returns an `Enum.SendAddonMessageResult`. **ChatThrottleLib**
  (v32) paces sends, retries `AddonMessageThrottle`, and raises on a message over 255 bytes.
  Its 800 B/s and 4 KB burst are the library's settings, not measured server quotas.
- **An addon whisper to an offline character prints a visible system error line.** Whispers don't
  cross factions. Battle.net game data does, arrives **unordered**, and has been measured between
  two accounts under one Battle.net account.
- The sender of `CHAT_MSG_ADDON` carries the surname, for a whisper (porting guide) and for the
  guild (phase 0, below: no realm, and `Ambiguate` changes nothing).

## Phases

**Status:** phase 0 measured (#62); phase 1 built (#15), to measure with a guildmate.

0. **Measure** (`/gsweep guildprobe`, one character in a guild is enough: the server echoes a
   guild addon message to its sender). What the `GUILD` sender looks like (name, surname, realm),
   what `Ambiguate(sender, "none")` returns for it, and the send's result code. This fixes the
   member identity below before any of it is saved.
1. **#15, the guild's best times:** the per-character bests, the protocol (`Q`, `B`, `N`), the
   cache, the Guild tab. Live updates (`N`) are in phase 1: the tab stays current.
2. **#17, the toast**, on phase 1's `N`.
3. **#16, friends:** the same messages over other transports, plus discovery. Only after 1 and 2
   are measured in game.

Each phase is its own PR; phase 1 ships alone.

## Whose times: the per-character bests

`GnomesweeperDB.scores` stays exactly as it is (the "You" tab, account-wide, a contract). The
guild needs each **character's** own times, which it doesn't keep: `Scores.Won` only replaces
the account's best. So a new store, kept from now on:

- **Every eligible win** updates the winning character's own best in its category, whatever
  the account best did.
- **Eligible** (one rule, used everywhere: what is sent, what is ranked, what a toast compares):
  the time in whole centiseconds, `cs = floor(time * 100)`, from **100** (1 s: a first click
  that clears the board at 0 s is a real best for the "You" tab, but not one to rank a guild by)
  to **9,999,999** (about 27 hours: a bound for the wire, not a rule of the game; 999 s is only the
  clock's display).
- **Seeded once:** an existing account record whose `name` is this character's full name **and**
  whose `realm` is this character's realm becomes its first entry (two same-named characters on
  different realms must not inherit each other's record). Other characters' past wins can't be split out after the fact; they start
  when this ships.
- **Reset best times** clears these too. It can't retract copies peers already hold (their caches
  forget a member after 30 days of silence).

## The wire format (v1)

One prefix, **`GSWEEP`**, registered at load (`C_ChatInfo.RegisterAddonMessagePrefix`; the
result is checked). A message is fields separated by a tab:

```
1\t<type>[\t<record>...]
```

**The grammar, exactly:**

- Split on every tab, **keeping empty fields** (an empty required field is malformed).
- Field 1, the version, is `1`. Any other version: the message is ignored whole. The version is
  bumped only for a change a v1 client would misread.
- Field 2, the type: `Q`, `B` or `N`. An unknown type is ignored. A new kind of data is a new type,
  never new fields in `B`.
- A **record** is `<category>=<cs>@<at>`:
  - `category`: one of the six (`beginner:area` ... `expert:cell`, Scores' own);
  - `cs`: decimal digits only, no sign or leading zero, 100 to 9999999;
  - `at`: decimal digits only, 1000000000 to 9999999999 (an epoch from 2001 to 2286; ten digits,
    so no leading zero).
- **`Q`** has no records. **`N`** has exactly one. **`B`** has 1 to 6, every remaining field is a
  record, and a category twice is malformed. (In v1, `B`'s grammar can't grow: anything new is a
  new type.)
- **No names in the payload:** the member is who the transport says sent it (below). A peer can't
  speak for another guildmate, and there's no name to bound or to sanitise.
- **The bound:** the longest legal `B` (all six categories, the largest `cs`, a 10-digit `at`) is
  **205 bytes** (computed), under 255 with room to spare. Asserted in tests at those values, and the
  encoder checks the final length before it sends.
- **Validated whole before anything is stored:** one bad field drops the whole message, silently.
  Anti-cheat stays out of scope: a well-formed time is shown as reported.

| Type | Sent | Records |
|---|---|---|
| `Q` (query) | Once per session at login (the first `PLAYER_ENTERING_WORLD`, after 5 s), and when the Guild tab opens if this guild wasn't queried in the last 5 minutes. **At most one per 60 s.** | none |
| `B` (bests) | In reply to a `Q` (see replies). Only with at least one eligible best. | this character's bests |
| `N` (new best) | When a win improves this character's own best in a category. | that one |

**Replies are deferred and coalesced, never dropped.** On a `Q`, if no reply is pending, one is
scheduled for `max(now + 1..6 s, last reply + 60 s + 1..6 s)`. A `Q` that arrives while one is
pending changes nothing (no new timer, the deadline doesn't move). So a late joiner always gets
an answer, at worst a minute later, and 50 queries cost one reply each, not one per query.

**Sending** goes through ChatThrottleLib (copied from AltStable's `Libs\`, credited), `BULK` for
`Q` and `B`, `NORMAL` for `N`, else a direct `SendAddonMessage`. Never when not in a guild. The
result code is read (a throttled or failed send is logged, not assumed delivered).

**Receiving:** `CHAT_MSG_ADDON`, prefix `GSWEEP`, channel `GUILD` (anything else is ignored in
phases 1 and 2). Our own echo is recognised by identity and dropped.

## Identity

**Measured (phase 0, 70205, 2026-10-03; `/gsweep guildprobe` on Kaleid Sumner in Parse Partout):**

| Asked | Answer |
|---|---|
| `RegisterAddonMessagePrefix("GSWEEP")`, `SendAddonMessage(..., "GUILD")` | `0`, `0` (success) |
| The echo's `CHAT_MSG_ADDON` sender (and target) | `"Kaleid Sumner"`: the full name, surname included, **no realm** |
| `Ambiguate(sender, "none" / "short" / "guild" / "mail")` | `"Kaleid Sumner"` every time: a no-op here |
| `UnitName("player")`, `UnitFullName("player")` | `"Kaleid", "Sumner"` both: the second answer is the **surname**, not a realm |
| `GetRealmName()`, `GetNormalizedRealmName()` | `"Classic Beta PvE"`, `"ClassicBetaPvE"` |
| `GetGuildInfo("player")` | `"Parse Partout", "Veteran", 4, "ClassicBetaPvE2"`: the 4th is the **guild's realm, not ours** |

So:

- **The member key** is the sender as received, with `"-" .. GetNormalizedRealmName()` added when
  it carries no realm: `"Kaleid Sumner-ClassicBetaPvE"`. A sender that already carries a `-Realm`
  (a guildmate from another realm, presumably: **unmeasured**, only one character tested) is kept
  as it is. `Ambiguate` is not used (a no-op here).
- **Our own key** is built the same way from `API.PlayerFullName()` and `GetNormalizedRealmName()`,
  so our echo matches it and is dropped, and our alts in the guild match their own keys.
- **The guild key** is the guild's name and **its own** realm (`GetGuildInfo`'s 4th answer, ours
  when it's nil): `"Parse Partout-ClassicBetaPvE2"`.
- **The display name** is the key without its realm when that realm is ours. No casefolding (names
  are UTF-8; Lua's `lower` is byte-wise), and names are never split on spaces (the surname).

## The cache (`GnomesweeperDB.social`, a new field: the saved-data contract)

```lua
GnomesweeperDB.social = {
    version = 1,
    mine = {                                  -- our characters' own bests (the store above)
        [memberKey] = { ["expert:area"] = { cs = 8412, at = 1791234567 }, ... },
    },
    guilds = {
        [guildKey] = {                        -- the guild's name and our realm; renames leave an old bucket to expire
            [memberKey] = { seen = <local epoch>, bests = { [category] = { cs =, at = } } },
        },
    },
}
```

- **Merging** keeps, per member and category, the **better** of what's held and what arrived, by
  one order everywhere: `(cs, at, memberKey)`, lower first. A slower or older message arriving
  later never replaces a faster one; a category missing from a `B` deletes nothing.
- **`seen` is our clock** when the message arrived, never the peer's `at`.
- A member not heard from in **30 days** is dropped at login. Buckets for guilds this character
  isn't in are kept (it may come back) but never shown.
- **What the tab shows is the guildmates heard recently**, not a verified roster.
- Reading never creates the table (as `Scores`): opening Best times without a guild leaves the
  SavedVariables alone.

## The Guild tab (phase 1)

Best times gets two tabs: **You** (today's panel) and **Guild**. Per difficulty, under the
current game's first-click rule: the guild's best (time, who, when), the next two, and **your
character's rank** ("you: 4th"). Times to the tenth when two shown would read the same second.
"No guild" / "No guildmate has shared a time yet" when empty. Opening it sends a `Q` if this guild
wasn't queried in 5 minutes. Localized (#36).

## The toast (phase 2, #17)

- **Synced first:** a guild counts as heard once, since login, **a valid `B` has arrived and 70 s
  have passed since our `Q`** (the replies' whole window: a reply can take up to ~66 s, deferred
  past a cool-down). Silence never counts: a guildmate with the addon but no best sends no `B`, so
  silence proves nothing. Before that, no toasts: a client that just logged in knows too little to
  call anything a guild best. (Best effort, not proof: there's no roster of who has the addon.)
- **When:** a received `N` whose time is **strictly faster** (lower `cs`) than **every** record known
  for that category, the guild's and this character's own. The full order `(cs, at, memberKey)`
  ranks, but a tie never toasts. Only `N`: `B` (sync) never toasts. Our own win never toasts us (the
  overlay celebrates it).
- **Rechecked when shown:** a queued toast that something better has overtaken is dropped.
- **What:** a glass card near the top of the screen for 6 s, on `UIParent` (board open or not):
  the mascot's face and « Fizzle cleared Expert in 01:24, a new guild best! ». A click dismisses it.
- **Never in combat:** one arriving in combat waits; **one showing when a fight starts is hidden
  at once** and comes back after. Several queue, at most 3 (older ones dropped).
- **A setting**, "Guild best toasts", on by default. Turning it off, or a guild change, clears the
  queue. Its event frame is independent of the (lazily built) game window.

## Guild changes

The guild key is captured when a reply or a toast is scheduled; when it fires, a different guild
(or none) cancels it. `PLAYER_GUILD_UPDATE` clears pending replies, the toast queue and the
"synced" state.

## Friends (phase 3, #16, sketch only)

The same messages by **whisper** to WoW friends and by **`C_BattleNet.SendGameData`** to Battle.net
friends (and same-account licences, measured by AltStable) playing Forever. Discovery without spam:
only friends shown online, at most once a session each, presence rechecked at send time; a race
(they log off as it leaves) can still print the error line, rarely. Designed once 1 and 2 are
measured.

## Load (with coalesced replies)

50 addon users logging in within a minute: about 50 `Q` and 50 `B`, about 12 KB in all, spread
by the jitter. Each online user receives about 100 messages. The guild's size only multiplies the
server's fan-out, not what anyone sends.

## Testing

- **Pure, every global forbidden:** the wire (`Social.lua`'s encoder and parser): round trips; the
  205-byte bound at the longest legal values; every malformed case (empty fields, signs, leading
  zeros, out-of-range numbers, a 9-digit epoch, duplicate categories, an unknown category,
  records on a `Q`, two on an `N`) dropped whole; unknown versions and types. The cache: merging
  by the order (an old `B` after a fast `N`), missing categories, pruning, ranks, ties.
- **Through the stub:** crafted `CHAT_MSG_ADDON` events, every send recorded. Replies: deferred and
  coalesced (staggered logins during the cool-down). Per-character bests (two characters, the
  account best set by the other). Toasts: synced first, records only, not `B`, not ourselves, not
  ties, combat (arriving in it, and starting while one shows), the setting, a guild change.
- **In game:** phase 0 alone; then two players with the addon in one guild (a guildmate, or the
  owner's second account guilded): the sync after login, a new best reaching the other side, the
  toast, nothing in chat, no error lines.

## Out of scope

Anti-cheat; an authoritative guild record (it would need far more machinery); cross-guild or
global boards; a history of past records; achievements.
