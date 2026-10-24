-- luacheck configuration for the Forever Comms bundle.
--
-- Run from the repository root:   luacheck .
-- Install (needs Lua + LuaRocks): luarocks install luacheck
--
-- The WoW client supplies a large global environment that luacheck knows nothing
-- about, so every API the addons touch is declared below. Keeping the list explicit
-- rather than pulling in a community WoW std is deliberate: an unrecognised name is
-- then a real finding (a typo, or an API used without the feature-detect guard that
-- lua-style.md requires) instead of being silently absorbed by a catch-all.

std = "lua51"

-- Line length is a review convention (~100 characters), not a machine rule here. The
-- message/accent data tables are single-line string banks that legitimately run past
-- 300 characters, and flagging them would bury the findings that matter.
max_line_length = false

-- Don't report the implicit `self` of a method that never uses it. Behaviour goes on
-- the namespace as `function A:Thing()` per structure.md, so plenty of methods are
-- namespaced functions that legitimately ignore `self`. This alone was 38 of the 56
-- warnings on the first run, which would have buried everything else.
self = false

exclude_files = {
    ".release",
    "dist",
    ".git",
}

-- Globals the bundle is allowed to create. Everything else assigned at file scope is
-- an accident; structure.md permits only the published namespaces, the SavedVariables
-- tables, the SLASH_/BINDING_ entries and named frames.
globals = {
    -- Published namespaces (Core.lua of each package assigns these)
    "ForeverCommsVoice",
    "ForeverGuildComms",
    "ForeverGroupComms",
    -- SavedVariables, declared in the TOC files
    "ForeverCommsVoiceCharDB",
    "ForeverGuildCommsDB",
    "ForeverGuildCommsCharDB",
    "ForeverGroupCommsDB",
    -- Slash command registration
    "SlashCmdList",
    "SLASH_FOREVERCOMMSVOICE1", "SLASH_FOREVERCOMMSVOICE2",
    "SLASH_FOREVERGUILDCOMMS1", "SLASH_FOREVERGUILDCOMMS2",
    "SLASH_FOREVERGROUPCOMMS1", "SLASH_FOREVERGROUPCOMMS2",
    -- Keybinding labels consumed by Bindings.xml
    "BINDING_HEADER_FOREVERGUILDCOMMS",
    "BINDING_NAME_FGC_OPEN_ALERTS",
    "BINDING_NAME_FGC_ASK_HELP",
    "BINDING_NAME_FGC_RESCAN_PROFESSION",
    "BINDING_HEADER_FOREVERGROUPCOMMS",
    "BINDING_NAME_FGROUP_PANEL",
    "BINDING_NAME_FGROUP_ROLES",
    "BINDING_NAME_FGROUP_QUESTS",
    -- Named frames. CreateFrame writes these into the global table for us, so they are
    -- reads as far as Lua is concerned, but listing them here documents the full set.
    "ForeverCommsVoiceQueueFrame",
    "ForeverCommsVoiceQueueScroll",
    "ForeverGuildCommsOptionsPanel",
    "FGCAlertsFrame",
    "FGCRequestFrame",
    -- Popup dialog registry: we add FGC_/FGROUP_ keys to Blizzard's table.
    "StaticPopupDialogs",
}

read_globals = {
    -- Namespaced API
    "C_ChatInfo",
    "C_GuildInfo",
    "C_Map",
    "C_PartyInfo",
    "C_QuestLog",
    "C_Timer",
    "C_TradeSkillUI",
    -- Frames, UI and settings
    "CreateFrame",
    "UIParent",
    "Settings",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",
    "StaticPopup_Show",
    "MenuUtil",
    "ToggleCharacter",
    "ChatFrame_OpenChat",
    "DEFAULT_CHAT_FRAME",
    "PlaySound",
    "SOUNDKIT",
    -- Guild
    "IsInGuild",
    "GetGuildInfo",
    "GetGuildRosterInfo",
    "GetNumGuildMembers",
    "ERR_GUILD_JOIN_S",
    -- Group and raid
    "IsInGroup",
    "IsInRaid",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "LE_PARTY_CATEGORY_INSTANCE",
    "UnitGroupRolesAssigned",
    "UnitIsGroupLeader",
    "UnitIsGroupAssistant",
    "DoReadyCheck",
    "SetRaidTarget",
    "SetRaidTargetIcon",
    -- Units
    "UnitName",
    "UnitFullName",
    "UnitGUID",
    "UnitLevel",
    "UnitClass",
    "UnitRace",
    "UnitExists",
    "UnitCanAttack",
    "GetUnitName",
    -- Quests
    "GetNumQuestLogEntries",
    "GetQuestLogTitle",
    "SelectQuestLogEntry",
    "QuestLogPushQuest",
    "IsQuestFlaggedCompleted",
    -- Misc client API
    "GetTime",
    "GetRealZoneText",
    "GetInventoryItemID",
    "InCombatLockdown",
    "IsShiftKeyDown",
    "SendChatMessage",
    -- WoW additions to the Lua standard library
    "wipe",
    "date",
    -- Optional, feature-detected at runtime. Must never become a TOC dependency.
    "LibStub",
}

-- Assigned as a whole table rather than via `files[pattern] = ...` so this file also
-- loads under a plain Lua interpreter, which is how the repo sanity-checks it.
files = {
    ["**/tests/*.lua"] = {
        -- The offline harnesses deliberately install stub globals (CreateFrame,
        -- UnitName, the SavedVariables tables, ...) to stand in for the client, so
        -- global warnings here would all be false positives. The rest still applies.
        global = false,
    },
}
