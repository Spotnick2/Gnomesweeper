-- #17: a new guild best, shown to addon users as a toast (docs/SOCIAL.md, "The toast").
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUILD = "Gnomeregan Exiles"
local T = 1790000000
local function from(sender, msg) WoW.fire("CHAT_MSG_ADDON", "GSWEEP", msg, "GUILD", sender, "", 0, 0, "", 0) end
local function N(cat, cs) return "1\tN\t" .. cat .. "=" .. cs .. "@" .. T end
local function B(cat, cs) return "1\tB\t" .. cat .. "=" .. cs .. "@" .. T end
local function card() return Gnomesweeper.Toast._test.card() end
local function shown() return Gnomesweeper.Toast.IsShown() and card().text:GetText() or nil end
-- The toast stays until it's clicked (owner): this is the click.
local function dismiss() card()._scripts.OnMouseUp(card()) end

-- Logged in, queried, heard the guild, and past the replies' window: toasts can show.
local function synced(db)
    loadAddon({ db = db })
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)                                     -- the login query
    from("Ann Gear", B("expert:area", 9000))             -- the guild heard
    WoW.advance(70)                                      -- the replies' whole window
    return Gnomesweeper.Social
end

do  -- not synced yet: no toast
    loadAddon()
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), nil, "just after login, before hearing the guild: no toast (it knows too little)")
    from("Ann Gear", B("expert:area", 9000))
    WoW.advance(10)
    from("Cal Bolt", N("expert:area", 7000))
    eq(shown(), nil, "a B heard, but within the replies' window: still no toast")
end

do  -- silence never counts; but in a guild where nobody has a time yet, the first N does (review of #66)
    loadAddon()
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(200)
    eq(Gnomesweeper.Social._test.synced(GUILD .. "-Forever"), false, "silence, however long: not synced")
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), "Bob Cog cleared Expert in 01:20.0, a new guild best!",
        "a guild where nobody had a time (no B): the first N, after the window, is a guild best")
end

do  -- ...but not within the window
    loadAddon()
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(30)
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), nil, "an N within the replies' window: not yet (replies may still come)")
end

do  -- synced: a strictly faster N toasts
    local S = synced()
    from("Bob Cog", N("expert:area", 8412))
    eq(shown(), "Bob Cog cleared Expert in 01:24.1, a new guild best!", "a guildmate's new guild best: a toast")
    local c = card()
    eq(c:GetParent(), UIParent, "...on UIParent: whether the board is open or not")
    eq(c._strata, "FULLSCREEN_DIALOG", "...in the board's strata (review of #66: under it, it hid behind the board)")
    check(c:GetFrameLevel() >= 200, "...and above it")
    eq(c.face._texture, Gnomesweeper.Skin.TEXTURES.faceWon, "...with her laughing face")
    WoW.advance(600)
    check(shown() ~= nil, "it stays, however long (owner: no timeout)")
    dismiss()
    eq(shown(), nil, "...until it's clicked")
    eq(Gnomesweeper.Window.win, nil, "(the game window was never built)")
end

do  -- what doesn't toast
    local S = synced()
    from("Bob Cog", N("expert:area", 9500))
    eq(shown(), nil, "slower than the guild's best: no toast")
    from("Bob Cog", N("expert:area", 9000))
    eq(shown(), nil, "a tie: no toast (strictly faster only)")
    from("Bob Cog", B("expert:area", 100))
    eq(shown(), nil, "a B never toasts (a sync reply, not a moment)")
    from("Fizzle Sprocketwhistle", N("expert:area", 100))
    eq(shown(), nil, "our own echo never toasts us")
    S.RecordWin("beginner:area", 20)
    from("Bob Cog", N("beginner:area", 2500))
    eq(shown(), nil, "slower than OUR best in that category: no toast (ours count)")
end

do  -- a tie isn't even queued (non-records would crowd real ones out of the 3 places)
    local S = synced()
    from("Cal Bolt", N("expert:area", 7000))            -- on screen: the next would have to wait
    from("Dee Nut", N("expert:area", 7000))             -- a tie with it
    eq(#S._test.queue(), 0, "a tie, arriving while one shows: not queued")
end

do  -- the queue: one at a time, the next after; a click puts one away
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))
    from("Cal Bolt", N("expert:area", 7000))
    check(shown():find("Bob Cog", 1, true) ~= nil, "two arrive: the first shows")
    dismiss()
    check(shown() and shown():find("Cal Bolt", 1, true) ~= nil, "a click puts it away, and the next shows")
    dismiss()
    eq(shown(), nil, "...then nothing")
end

do  -- rechecked when shown: one overtaken while it waited is dropped
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))              -- on screen
    from("Cal Bolt", N("expert:area", 7000))             -- waits
    from("Dee Nut", N("expert:area", 6000))              -- waits, and beats Cal
    dismiss()
    check(shown() and shown():find("Dee Nut", 1, true) ~= nil, "Cal's, overtaken by Dee's while it waited, is dropped: Dee's shows")
end

do  -- at most 3 waiting: the oldest go
    local S = synced()
    from("A A", N("expert:area", 8900))
    for i, name in ipairs({ "B B", "C C", "D D", "E E" }) do from(name, N("intermediate:area", 9000 - i * 100)) end
    eq(#S._test.queue(), Gnomesweeper.Social.TOAST_QUEUE, "at most " .. Gnomesweeper.Social.TOAST_QUEUE .. " wait")
end

do  -- combat: none shows in a fight; one showing goes, and comes back after
    local S = synced()
    WoW.inCombat = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), nil, "in combat: no toast")
    WoW.inCombat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    check(shown() and shown():find("Bob Cog", 1, true) ~= nil, "...it shows when the fight ends")
    WoW.inCombat = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    eq(shown(), nil, "a fight starting while one shows: it goes at once")
    WoW.advance(10)
    WoW.inCombat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    check(shown() and shown():find("Bob Cog", 1, true) ~= nil, "...and comes back after")
end

do  -- the setting
    local S = synced({ guildToasts = false })
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), nil, "the setting off: no toast")
    eq(GnomesweeperDB.guildToasts, false, "(saved off)")
    Gnomesweeper.Options.Set("guildToasts", true)
    from("Cal Bolt", N("expert:area", 7000))
    check(shown() ~= nil, "on again: toasts show")
    from("Dee Nut", N("expert:area", 6000))              -- waiting
    Gnomesweeper.Options.Set("guildToasts", false)
    eq(shown(), nil, "turning it off puts the one showing away")
    eq(#S._test.queue(), 0, "...and clears those waiting")
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    check(page.controls.guildToasts and page.controls.guildToasts.check, "the settings page has the switch")
end

do  -- defaults on
    loadAddon()
    eq(GnomesweeperDB.guildToasts, true, "toasts are on by default")
end

do  -- a guild change clears them
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))
    from("Cal Bolt", N("expert:area", 7000))
    WoW.guild = "Another Guild"
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    eq(shown(), nil, "a guild change puts the toast away")
    eq(#S._test.queue(), 0, "...and the old guild's waiting ones go")
end

do  -- in French
    loadAddon({ locale = "frFR" })
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    from("Ann Gear", B("expert:area", 9000))
    WoW.advance(70)
    from("Bob Cog", N("expert:area", 8412))
    eq(shown(), "Bob Cog\194\160: Expert en 01:24,1, nouveau record de guilde\194\160!", "in French: the decimal comma and French spacing")
end

----------------------------------------------------------------------------
-- The review of #66
----------------------------------------------------------------------------
do  -- above the open board
    local S = synced({ seenFaceTip = true })
    WoW.slash("/gsweep")
    from("Bob Cog", N("expert:area", 8000))
    local w = Gnomesweeper.Window.win
    eq(card()._strata, w._strata, "with the board open: the same strata as the board")
    check(card():GetFrameLevel() > w:GetFrameLevel() + 31, "...above everything in it (the list is at +30, the pointer +31)")
end

do  -- the first-click rule is named when it's the single safe tile
    local S = synced()
    from("Bob Cog", N("beginner:cell", 2000))
    eq(shown(), "Bob Cog cleared Beginner (one safe tile) in 00:20.0, a new guild best!",
        "a best under the single-safe-tile rule says so (each rule keeps its own bests)")
end

do  -- a guild known only for a moment isn't a guild change
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))
    from("Cal Bolt", N("expert:area", 7000))
    WoW.guildLoading = true                              -- in the guild, name not loaded (a zone change)
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    WoW.guildLoading = nil
    check(shown() ~= nil, "a moment without the guild's name doesn't put the toast away")
    eq(#S._test.queue(), 1, "...nor the waiting one")
end

do  -- combat from the events: the API lagging behind the end of a fight doesn't strand toasts
    local S = synced()
    WoW.inCombat = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    from("Bob Cog", N("expert:area", 8000))
    WoW.fire("PLAYER_REGEN_ENABLED")                     -- the fight's over, the API still says combat
    check(shown() ~= nil, "the fight's end shows it, whatever the API says a moment later")
    WoW.inCombat = false
end

do  -- the cap holds when a fight interrupts one, and the interrupted one is kept
    local S = synced()
    from("A A", N("expert:area", 8900))                 -- on screen
    from("B B", N("intermediate:area", 8900))
    from("C C", N("intermediate:area", 8800))
    from("D D", N("intermediate:area", 8700))
    WoW.fire("PLAYER_REGEN_DISABLED")                    -- A goes back to the queue
    eq(#S._test.queue(), Gnomesweeper.Social.TOAST_QUEUE, "a fight putting one back: still at most " .. Gnomesweeper.Social.TOAST_QUEUE)
    eq(S._test.queue()[1].key, "A A-Forever", "...the interrupted one kept, an unseen one dropped")
    from("E E", N("beginner:area", 900))
    eq(S._test.queue()[1].key, "A A-Forever", "...and still kept when another arrives in the fight")
    WoW.fire("PLAYER_REGEN_ENABLED")
end

do  -- damaged saved data: no error
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))
    from("Cal Bolt", N("expert:area", 7000))             -- waiting
    GnomesweeperDB.social.guilds = 42                    -- a number: indexing it errors (a string would not)
    local ok = pcall(dismiss)                             -- the click: the next is rechecked
    check(ok, "a damaged cache when the next toast is rechecked: no Lua error")
end

do  -- the sync window follows the reply timings
    local S = Gnomesweeper.Social
    check(S.SYNC_WINDOW > S.REPLY_GAP + S.JITTER_MAX, "the sync window covers a reply's longest deferral")
end

do  -- the test seam's reset clears the toasts' state
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))
    from("Cal Bolt", N("expert:area", 7000))
    S._test.reset()
    eq(#S._test.queue(), 0, "reset: no queue")
    eq(S._test.synced(GUILD .. "-Forever"), false, "...and not synced")
end

do  -- a real guild change restarts the sync, and asks the new guild (Codex, #66)
    local S = synced()
    WoW.addonSent = {}
    WoW.guild = "Another Guild"
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    local asked = false
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then asked = true end end
    check(asked, "joining another guild: it's asked at once")
    from("Bob Cog", B("expert:area", 9000))
    WoW.advance(10)
    from("Cal Bolt", N("expert:area", 7000))
    eq(shown(), nil, "...and not synced until the replies' window has passed for it")
    WoW.advance(70)
    from("Dee Nut", N("expert:area", 6000))
    check(shown() ~= nil, "...then it toasts")
    -- Back to the first guild: heard afresh, not synced from before.
    dismiss()
    WoW.guild = GUILD
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    eq(S._test.synced(GUILD .. "-Forever"), false, "rejoining a guild: not synced from before")
    from("Eve Spring", N("expert:area", 5000))
    eq(shown(), nil, "...so no toast until it's heard again")
end

do  -- the guild's name gone for a moment when a toast ends: the queue waits, and resumes (Codex, #66)
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))              -- on screen
    from("Cal Bolt", N("expert:area", 7000))             -- waiting
    WoW.guildLoading = true                              -- the name gone for a moment
    dismiss()           -- Bob's ends
    eq(shown(), nil, "(nothing shows while the guild isn't known)")
    eq(#S._test.queue(), 1, "...and the waiting one is kept")
    WoW.guildLoading = nil
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    check(shown() and shown():find("Cal Bolt", 1, true) ~= nil, "the guild known again: it shows")
end

do  -- leaving, then joining: the new guild is asked and synced (Codex, #66 follow-up)
    local S = synced()
    WoW.guild = nil
    WoW.fire("PLAYER_GUILD_UPDATE", "player")            -- left: no guild for a while
    WoW.advance(30)
    WoW.addonSent = {}
    WoW.guild = "Another Guild"
    WoW.fire("PLAYER_GUILD_UPDATE", "player")            -- joined
    local asked = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then asked = asked + 1 end end
    eq(asked, 1, "left, then joined another guild: it's asked")
    WoW.advance(61)                                      -- past the once-a-minute limit
    WoW.fire("PLAYER_GUILD_UPDATE", "player")            -- the roster's next update
    asked = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then asked = asked + 1 end end
    eq(asked, 1, "...once (the roster's updates don't repeat it)")
    from("Bob Cog", B("expert:area", 9000))
    WoW.advance(14)
    from("Cal Bolt", N("expert:area", 7000))
    check(shown() ~= nil, "...and once heard and past its window, it toasts")
    -- Leaving and rejoining the same guild works the same way.
    dismiss()
    WoW.guild = nil
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    WoW.addonSent = {}
    WoW.guild = "Another Guild"
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    asked = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then asked = asked + 1 end end
    eq(asked, 1, "leaving and rejoining the same guild: asked again")
    eq(S._test.synced("Another Guild-Forever"), false, "...and heard afresh, not synced from before")
end

do  -- a slow /reload with no guild event after it: the login query retries (the owner's missing toast)
    loadAddon()
    WoW.guild, WoW.guildLoading = GUILD, true
    WoW.fire("PLAYER_ENTERING_WORLD", false, true)       -- a /reload
    WoW.advance(5.5)
    local q = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then q = q + 1 end end
    eq(q, 0, "(the guild not known yet 5 s after the reload: no query)")
    WoW.guildLoading = nil                               -- known now, and no PLAYER_GUILD_UPDATE follows
    WoW.advance(5.5)
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tQ" then q = q + 1 end end
    eq(q, 1, "the login query retries until the guild is known, without waiting for an event")
    from("Ann Gear", B("expert:area", 9000))
    WoW.advance(75)
    from("Bob Cog", N("expert:area", 8000))
    check(shown() ~= nil, "...so the sync opens and a guild best toasts")
end

do  -- the retries stop: out of a guild, or after a minute
    loadAddon()
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(120)
    eq(#WoW.addonSent, 0, "not in a guild: nothing sent, and no endless retries")
    local tries = 0
    for _, line in ipairs(GnomesweeperDB.socialLog or {}) do if line:find("login query due", 1, true) then tries = tries + 1 end end
    eq(tries, 1, "...one attempt, then it stops (not in a guild)")
end

do  -- the social log: every decision, with its reason
    loadAddon()
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    from("Bob Cog", N("expert:area", 8000))              -- not synced yet
    from("Ann Gear", B("expert:area", 9000))
    WoW.advance(75)
    from("Cal Bolt", N("expert:area", 9500))             -- synced, not faster
    from("Dee Nut", N("expert:area", 7000))              -- a guild best
    local log = table.concat(GnomesweeperDB.socialLog, "\n")
    check(log:find("login (initial true", 1, true) ~= nil, "the log has the login")
    check(log:find("Q to " .. GUILD .. "-Forever (forced): sent", 1, true) ~= nil, "...the query and its result")
    check(log:find("no toast: not synced (heard true, first query", 1, true) ~= nil, "...why an early N didn't toast")
    check(log:find("no toast: expert:area 9500 cs isn't faster than the best known, 8000 cs", 1, true) ~= nil, "...why a slow one didn't")
    check(log:find("toast queued: expert:area 7000 cs", 1, true) ~= nil, "...and the one that did")
    check(#GnomesweeperDB.socialLog <= Gnomesweeper.Social.LOG_KEEP, "at most LOG_KEEP lines")
    WoW.chat = {}
    WoW.slash("/gsweep guildprobe")
    local said = false
    for _, line in ipairs(WoW.chat) do if line:find("toasts: guild", 1, true) and line:find("synced true", 1, true) then said = true end end
    check(said, "/gsweep guildprobe reports the toasts' state")
end

do  -- Reset best times tells the guild: online guildmates forget our times (the owner's reset)
    local S = synced()
    S.RecordWin("expert:area", 84)
    WoW.addonSent = {}
    local page                                           -- the button's path: Options.ResetClick twice
    WoW.fire("PLAYER_LOGIN")
    page = Gnomesweeper.Options._test.page
    page:Show()
    page.reset._scripts.OnClick(page.reset)
    page.reset._scripts.OnClick(page.reset)
    local r = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tR" then r = r + 1 end end
    eq(r, 1, "Reset best times sends one R to the guild")
    eq(next(GnomesweeperDB.social.mine), nil, "...and our own times are gone")
end

do  -- receiving an R: that guildmate's times, and any toast of theirs waiting, go
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))              -- on screen
    from("Cal Bolt", N("intermediate:area", 9000))       -- waiting
    from("Cal Bolt", "1\tR")
    eq(GnomesweeperDB.social.guilds[GUILD .. "-Forever"]["Cal Bolt-Forever"], nil, "an R drops that guildmate's entry")
    eq(#S._test.queue(), 0, "...and their waiting toast")
    check(GnomesweeperDB.social.guilds[GUILD .. "-Forever"]["Bob Cog-Forever"] ~= nil, "...nobody else's")
    local log = table.concat(GnomesweeperDB.socialLog, "\n")
    check(log:find("R from Cal Bolt-Forever", 1, true) ~= nil, "...logged")
end

do  -- the account's other characters send their own R at their next login, once
    local S = synced()
    Gnomesweeper.Social.Reset()                          -- on Fizzle
    local saved = GnomesweeperDB
    WoW.playerName, WoW.playerSurname = "Gizmo", "Cogsworth"   -- another character of the account
    loadAddon({ db = saved })
    WoW.playerName, WoW.playerSurname = "Gizmo", "Cogsworth"
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    local r = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tR" then r = r + 1 end end
    eq(r, 1, "another character of the reset account sends its own R at login")
    loadAddon({ db = GnomesweeperDB })                   -- and again, later
    WoW.playerName, WoW.playerSurname = "Gizmo", "Cogsworth"
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    r = 0
    for _, m in ipairs(WoW.addonSent) do if m.message == "1\tR" then r = r + 1 end end
    eq(r, 0, "...once: not at every login")
end

done("test_toast")
