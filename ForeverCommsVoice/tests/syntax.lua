-- Compile every shipped Lua file, without running it. Cheapest guard against
-- shipping a parse error. Run from the addon root: lua5.1 tests/syntax.lua
-- The module list is read from the TOC rather than duplicated here, so a file
-- added to the TOC is compile-checked automatically.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]syntax%.lua$")) or "./"
local TOC = "ForeverCommsVoice.toc"

local manifest = assert(io.open(base .. TOC, "r"), "cannot open " .. TOC)
local text = manifest:read("*a")
manifest:close()

local modules = {}
for raw in text:gmatch("[^\r\n]+") do
    -- Strip a UTF-8 BOM on the first line and surrounding whitespace.
    local line = raw:gsub("^\239\187\191", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and line:sub(1, 1) ~= "#" then
        assert(line:match("^[%w_%-]+%.lua$") or line:match("^[%w_%-]+%.xml$"),
            "unexpected TOC entry in " .. TOC .. ": " .. line)
        if line:match("%.lua$") then modules[#modules + 1] = line end
    end
end
assert(#modules > 0, TOC .. " lists no Lua modules")

for _, filename in ipairs(modules) do
    local chunk, err = loadfile(base .. filename)
    assert(chunk, "Lua syntax error in " .. filename .. ": " .. tostring(err))
end
print("PASSED: all " .. #modules .. " TOC-listed files compile")
