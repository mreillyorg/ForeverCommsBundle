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

-- Shared namespace state must be declared in exactly one file. Every module here binds
-- the same table from the addon vararg, so a second `X.field = {}` in a later-loading
-- file silently replaces the first rather than adding to it. MessageVariants.lua carried
-- such a duplicate of messageVariantBags; nothing could catch it at runtime, because the
-- replacement happens at load before anything writes a bag. Asserted on source text for
-- that reason. Matches a declaration only: an indexed write like `t.field[k] = v` has a
-- `[` where this pattern requires `=`.
-- Comments are stripped before matching, or the prose explaining this rule would trip
-- it. Dropping everything after `--` can only ever hide a declaration, never invent one,
-- so the failure mode is a loud "found 0" rather than a silent pass.
local function codeOnly(source)
    local lines = {}
    for raw in source:gmatch("[^\r\n]+") do lines[#lines + 1] = raw:gsub("%-%-.*$", "") end
    return table.concat(lines, "\n")
end

-- Field, and the one module that owns its declaration. Core.lua holds the state the
-- addon mutates; the data modules own their own banks, which is why this is a map rather
-- than a blanket "everything in Core.lua" rule.
local owners = {
    {"messageVariantBags", "Core.lua"},
    {"catalogs", "Core.lua"},
    {"accents", "Accents.lua"},
    {"languages", "Languages.lua"},
    {"languageByID", "Languages.lua"},
}
for _, pair in ipairs(owners) do
    local field, owner = pair[1], pair[2]
    local sites = {}
    for _, filename in ipairs(modules) do
        local handle = assert(io.open(base .. filename, "r"), "cannot open " .. filename)
        local source = handle:read("*a")
        handle:close()
        if codeOnly(source):find("%.".. field .."%s*=%s*{") then
            sites[#sites + 1] = filename
        end
    end
    assert(#sites == 1, field .. " must be declared in exactly one module, found " ..
        #sites .. ": " .. table.concat(sites, ", "))
    assert(sites[1] == owner, field .. " should be declared in " .. owner .. ", not " ..
        sites[1])
end

print("PASSED: all " .. #modules .. " TOC-listed files compile, " ..
    #owners .. " shared fields declared once by their owning module")
