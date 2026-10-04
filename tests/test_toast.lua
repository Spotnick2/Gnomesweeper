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

do  -- silence never counts
    loadAddon()
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(200)
    from("Bob Cog", N("expert:area", 8000))
    eq(shown(), nil, "no B ever heard: never synced, however long (silence proves nothing)")
end

do  -- synced: a strictly faster N toasts
    local S = synced()
    from("Bob Cog", N("expert:area", 8412))
    eq(shown(), "Bob Cog cleared Expert in 01:24.1, a new guild best!", "a guildmate's new guild best: a toast")
    local c = card()
    eq(c:GetParent(), UIParent, "...on UIParent: whether the board is open or not")
    eq(c._strata, "DIALOG", "...over the game's own frames")
    eq(c.face._texture, Gnomesweeper.Skin.TEXTURES.faceWon, "...with her laughing face")
    WoW.advance(Gnomesweeper.Toast.SHOW + 0.1)
    eq(shown(), nil, "it goes after " .. Gnomesweeper.Toast.SHOW .. " s")
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
    card()._scripts.OnMouseUp(card())
    check(shown() and shown():find("Cal Bolt", 1, true) ~= nil, "a click puts it away, and the next shows")
    WoW.advance(Gnomesweeper.Toast.SHOW + 0.1)
    eq(shown(), nil, "...then nothing")
end

do  -- rechecked when shown: one overtaken while it waited is dropped
    local S = synced()
    from("Bob Cog", N("expert:area", 8000))              -- on screen
    from("Cal Bolt", N("expert:area", 7000))             -- waits
    from("Dee Nut", N("expert:area", 6000))              -- waits, and beats Cal
    WoW.advance(Gnomesweeper.Toast.SHOW + 0.1)
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

done("test_toast")
