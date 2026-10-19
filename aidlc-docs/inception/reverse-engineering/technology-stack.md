# Technology Stack

**Analysis date**: 2026-10-19T09:52:22Z

## Programming Languages

| Language | Version | Usage |
| --- | --- | --- |
| Lua | 5.1 — the dialect the WoW client embeds | All 22 shipped modules, 3,395 lines, plus all 13 offline harnesses, 995 lines. No LuaJIT extension is used anywhere: no `ffi`, `bit`, `jit`, `table.new` or `goto` |
| XML | WoW `Bindings.xml` schema | 2 files, 23 lines. Six opt-in keybindings whose handler bodies are one-line Lua calls into the addon globals. Auto-loaded from each addon root and deliberately absent from the TOCs |
| TOC | WoW addon manifest | 3 files, 46 lines. Metadata plus the ordered module list |
| PowerShell | 5.1+, Desktop edition | 4 installers, 940 lines. The three per-addon installers parse their own TOC and copy only declared files; the combined installer stages all three folders with backup and rollback |
| Batch | cmd | 4 launchers, 105 lines. Each invokes PowerShell with `-NoProfile -ExecutionPolicy Bypass` for that process only |
| YAML | GitHub Actions | 3 workflow files, 54 lines |
| Markdown | — | 5 shipped or repository docs: three addon READMEs, GuildComms `PACKAGING.md`, and a 2-line root `README.md` |

## Frameworks

**None.** There is no application framework, no UI framework, no test framework, no
dependency injection container and no module loader. Specifically:

| Would-be framework | What is used instead |
| --- | --- |
| Addon framework such as Ace3 | The addon vararg plus one shared table per package. `local _, A = ...` |
| Library distribution such as LibStub-embedded libs | A plain global, `_G.ForeverCommsVoice`, declared as a TOC `## Dependencies:` entry |
| UI framework | Direct `CreateFrame` calls against Blizzard templates, with file-local `Label`/`Button`/`Check` constructors and a list of refresh closures |
| Test framework | `assert` from the standard library. Each harness dies on the first failure and prints a `PASSED: ...` line otherwise |
| Scheduler | `C_Timer.After` and `C_Timer.NewTicker`, always paired with a boolean latch or a serial counter. No `OnUpdate` script anywhere |
| Serialization library | One hand-rolled pipe-delimited format in `ForeverGroupComms/Quests.lua` |
| Localization framework | Hand-curated offline tables in `ForeverCommsVoice`. There is no `AceLocale`, no `.lua` locale files and no runtime translation service |

## Runtime platform

| Component | Detail |
| --- | --- |
| Host | World of Warcraft: Forever, client 1.60.1 |
| Interface version | `16001`, identical in all three TOCs |
| Client folder | `_classic_beta_` |
| Install target | `_classic_beta_\Interface\AddOns\<AddonName>` |
| Persistence | Client-managed SavedVariables: `ForeverCommsVoiceCharDB`, `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB`, `ForeverGroupCommsDB` |
| Transport | `SendChatMessage` for guild and group chat; `C_ChatInfo.SendAddonMessage` with prefix `ForeverGrpComms` for GroupComms quest sync |

### Client APIs consumed

| Area | APIs |
| --- | --- |
| Identity | `UnitGUID`, `UnitName`, `GetUnitName`, `UnitFullName`, `UnitClass`, `UnitRace`, `UnitLevel`, `UnitExists`, `UnitCanAttack` |
| Guild | `IsInGuild`, `GetGuildInfo`, `GetNumGuildMembers`, `GetGuildRosterInfo`, `C_GuildInfo.GuildRoster`, `ERR_GUILD_JOIN_S` |
| Group | `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `GetNumSubgroupMembers`, `UnitGroupRolesAssigned`, `UnitIsGroupLeader`, `UnitIsGroupAssistant`, `LE_PARTY_CATEGORY_INSTANCE` |
| Group actions | `C_PartyInfo.DoReadyCheck` with a `DoReadyCheck` fallback, `SetRaidTarget` with a `SetRaidTargetIcon` fallback, `InCombatLockdown` |
| Quests | `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `IsQuestFlaggedCompleted`, `IsPushableQuest`, `SetSelectedQuest`, `GetSelectedQuest`, `GetLogIndexForQuestID`, `GetTitleForQuestID`; legacy `GetNumQuestLogEntries`, `GetQuestLogTitle`, `SelectQuestLogEntry`; `QuestLogPushQuest` |
| Addon comms | `C_ChatInfo.RegisterAddonMessagePrefix`, `C_ChatInfo.SendAddonMessage` |
| Trade skills | `C_TradeSkillUI.GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeItemLink`, `GetProfessionChildSkillLineID`, `GetProfessionInfoBySkillLineID` |
| Zone and inventory | `C_Map.GetBestMapForUnit`, `GetRealZoneText`, `GetInventoryItemID` |
| UI | `CreateFrame`, `BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `UIRadioButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate`, `StaticPopupDialogs`, `StaticPopup_Show`, `ToggleCharacter`, `ChatFrame_OpenChat`, `DEFAULT_CHAT_FRAME` |
| Settings | `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterAddOnCategory`, `Settings.OpenToCategory`, with `InterfaceOptions_AddCategory` and `InterfaceOptionsFrame_OpenToCategory` fallbacks |
| Menus | `MenuUtil.CreateContextMenu` and the node API `CreateTitle`/`CreateButton`/`CreateCheckbox`/`CreateRadio`/`CreateDivider` |
| Misc | `GetTime`, `C_Timer.After`, `C_Timer.NewTicker`, `PlaySound`, `SOUNDKIT.TELL_MESSAGE`, `IsShiftKeyDown`, `wipe`, `date`, `LibStub` |

Every one of these is feature-detected at the call site, because the Forever client is a
beta that may add or omit APIs.

## Infrastructure

**None.** No cloud resources, no containers, no databases, no queues, no load balancers,
no VPC. The only persistence is the client's own SavedVariables files and the only
network traffic is the game client's own protocol.

## Build Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| None for compilation | — | Lua is interpreted by the client. There is no build step at all |
| BigWigsMods/packager | `@v2` action | Produces a distributable ZIP on a `v*` tag, driven by `.pkgmeta`. Recognises the Forever game type from `## Interface: 16001` without a `-g` override |
| GitHub Actions | `actions/checkout@v4` with `fetch-depth: 0` | Hosts the packager. Three workflow files exist, one per package subdirectory |
| Git | — | `.gitattributes` pins `eol=lf` repository-wide so a Windows clone with `core.autocrlf=true` does not churn the sources |

**Current state of the build toolchain**: the three workflows and three `.pkgmeta` files
are all positioned for a repository whose root *is* an addon folder, which was true
before this restructure and is not true now. GitHub Actions reads workflows only from
`.github/workflows` at the checkout root, and this repository root has no `.github`
directory, so none of the three will run on a tag push. See
`code-quality-assessment.md`.

## Testing Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| Lua `assert` | stdlib | The entire assertion mechanism across all 13 harnesses |
| Lua 5.1 interpreter | 5.1.5 recommended | How the harnesses are meant to be run. `texlua` appears in the GroupComms and Voice harness comments; `lua5.1.exe` in the GuildComms steering |
| Synthetic widget layer | hand-written per harness | A metatable whose `__index` returns real implementations for the handful of widget methods a test needs and a no-op for the rest, with `CreateFrame` recording each widget so the test can find it by template or label. Established by `settings.lua`, extended by `titanmenu.lua` to the MenuUtil node API |
| Stub client API | hand-written per harness | Each harness defines only the globals its path touches: `GetTime`, `C_Timer.After` captured into a list, `SendChatMessage` recorded into a traffic log, `UnitRace` made reassignable, and so on |

**No interpreter is installed on this machine.** `lua`, `lua5.1`, `luajit`, `texlua` and
`lua54` were all probed and none is on PATH. No harness was executed during this pass and
none of the 13 is reported as passing. Reading a harness is not running it.

### Harness inventory

| Package | Harness | Loads |
| --- | --- | --- |
| Voice | `integration.lua` | **All three addons.** Voice's six data/logic modules, then GroupComms `Core.lua`, then GuildComms `Core.lua` and `VoiceBridge.lua` |
| Guild | `syntax.lua` | All 9 GuildComms modules, compiled only, none executed |
| Guild | `smoke.lua` | Voice x6, then Guild Core, VoiceBridge, Roster, Alerts |
| Guild | `verify.lua` | Voice x6, then Guild Core, VoiceBridge |
| Guild | `settings.lua` | Guild Core, Voice x6, VoiceBridge, Guild Options |
| Guild | `timing.lua` | Guild Core, Voice x6, VoiceBridge |
| Guild | `titanmenu.lua` | Guild Core, Voice x6, VoiceBridge, Options, TitanMenu, Broker |
| Guild | `voice.lua` | Voice x6, then Guild Core, VoiceBridge |
| Guild | `variations.lua` | Voice x6, then Guild Core, VoiceBridge, UI |
| Guild | `tabard_dedup.lua` | Guild Core, Tabard. The only GuildComms harness that needs no Voice |
| Guild | `keybindings.lua` | Guild Core, Alerts, plus the real `Bindings.xml` parsed and executed |
| Guild | `icon.lua` | No modules; reads the TOC, Broker, Options and installer as text |
| Group | `smoke.lua` | GroupComms Core, Roster, Quests. Does **not** load Voice |

Eight GuildComms harnesses resolve the sibling library by relative path with an
environment override: `os.getenv("FOREVER_VOICE_PATH")` or `../ForeverCommsVoice/`. They
therefore require the bundle checkout layout and will fail if a package is extracted and
tested in isolation.

## Toolchain gaps

| Capability | Status |
| --- | --- |
| Compiler / type checker | Not applicable to Lua 5.1; none used |
| Linter | None configured. No `.luacheckrc`, no `selene.toml`, no `stylua.toml` |
| Formatter | None. Style is maintained by convention and documented in `.kiro/steering/lua-style.md` |
| Code coverage | None |
| Dependency scanning | Not applicable; zero third-party packages are vendored |
| CI test execution | None. The three workflows package on a tag and run no tests. This has been the top recommendation for four consecutive passes |
| Version consistency check | None. Nine version strings across the three packages are currently stale |
