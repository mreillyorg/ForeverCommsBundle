-- Compile every shipped Lua file, without running it. Cheapest guard against
-- shipping a parse error. Run from the addon root: lua5.1 tests/syntax.lua
-- The module list is read from the TOC rather than duplicated here, so a file
-- added to the TOC is compile-checked automatically. A hand-maintained list was
-- the earlier form and it silently stopped covering new modules.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]syntax%.lua$")) or "./"
local TOC = "ForeverGuildComms.toc"

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

-- Bindings.xml ships from the addon root and is deliberately absent from the
-- TOC, so the TOC loop above cannot cover it. Compile its embedded handlers.
local compile = loadstring or load
local bindings = io.open(base .. "Bindings.xml", "r")
local handlers = 0
if bindings then
    local xml = bindings:read("*a")
    bindings:close()
    for name, body in xml:gmatch('<Binding%s+name="([^"]+)"[^>]*>(.-)</Binding>') do
        assert(compile(body, "binding " .. name), "Lua syntax error in binding " .. name)
        handlers = handlers + 1
    end
    assert(handlers > 0, "Bindings.xml present but declares no bindings")
end
print("PASSED: all " .. #modules .. " TOC-listed files and " .. handlers .. " bindings compile")
