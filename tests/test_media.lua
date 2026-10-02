-- Every texture in Media/ is a valid game texture. WoW wants power-of-two sizes
-- and TGAs it can read; a bad conversion (a stray size, a truncated file, a
-- compressed or 24-bit TGA the client may not take) otherwise shows up in game
-- as a green square, and nothing else would notice.
--
-- Uncompressed true-colour, 32 bits with 8 alpha bits: the header Tools/*.py write.
dofile("tests/harness.lua")

local function pow2(n)
    if n < 1 then return false end
    while n > 1 do
        if n % 2 ~= 0 then return false end
        n = n / 2
    end
    return true
end

local windows = package.config:sub(1, 1) == "\\"
local list = io.popen(windows and 'dir /b "Media\\*.tga" 2>nul' or "ls Media/*.tga 2>/dev/null")
local n = 0
for line in list:lines() do
    local name = line:gsub("^Media/", "")
    n = n + 1
    local f = assert(io.open("Media/" .. name, "rb"))
    local data = f:read("*a")
    f:close()
    check(#data >= 18, name .. ": has a TGA header")
    local function byte(i) return data:byte(i) or -1 end
    local w, h = byte(13) + 256 * byte(14), byte(15) + 256 * byte(16)
    eq(byte(1), 0, name .. ": no image id")
    eq(byte(2), 0, name .. ": no colour map")
    eq(byte(3), 2, name .. ": uncompressed true-colour")
    eq(byte(17), 32, name .. ": 32 bits per pixel")
    eq(byte(18), 8, name .. ": 8 alpha bits, bottom-left origin")
    check(pow2(w) and pow2(h), name .. ": power-of-two size (" .. w .. "x" .. h .. ")")
    check(w <= 1024 and h <= 1024, name .. ": no larger than 1024 (" .. w .. "x" .. h .. ")")
    eq(#data, 18 + w * h * 4, name .. ": the file is exactly header + pixels (not truncated)")
end
list:close()
check(n >= 19, "found the textures in Media/ (" .. n .. ")")

done("test_media")
