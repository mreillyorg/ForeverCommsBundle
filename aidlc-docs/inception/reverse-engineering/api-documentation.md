# API Documentation

**Analysis date**: 2026-10-19T09:52:22Z

## REST APIs

None. The bundle has no network surface, no HTTP client and no server component.

## Public cross-addon API

This is the one genuinely public contract in the project: the surface
`ForeverCommsVoice` exposes to its two consumers. Everything else is internal to a single
addon.

### `_G.ForeverCommsVoice`

| Method | Signature | Contract |
| --- | --- | --- |
| `V:Render` | `(scope, kind, vars, options) -> string` | **The primary entry point.** Returns final, interpolated, byte-clamped text. `scope` is `"guild"` or `"group"`; `kind` is a key within that catalog. `options.custom` is a consuming addon's user-authored template and, when it differs from the English base, is used verbatim with no translation or accent. `options.random = false` disables variation; `options.preview = true` renders without consuming a shuffle-bag draw. `options.fallback` is used when the scope or kind is unknown |
| `V:GetSettings` | `() -> table` | Lazily creates and normalizes `ForeverCommsVoiceCharDB.voice`, caches it on `V.char.voice`, returns it |
| `V:MigrateLegacy` | `(legacy) -> table` | One-time adoption of a consuming addon's old per-character voice table, latched by `ForeverCommsVoiceCharDB.migratedFromGuild`. Re-validates the accent afterwards and falls back to `"auto"` |
| `V:SetOption` | `(key, value) -> boolean` | Validates, writes, re-validates the accent when language or race filter changes, then refreshes its own panel and probes `_G.ForeverGuildComms` for `RefreshOptions` and `UpdateRequestPreview` |
| `V:ValidateOption` | `(key, value) -> boolean` | Pure validation against `voiceDefaults`, `languageByID` and the accent list |
| `V:RegisterCatalog` | `(scope, catalog) -> boolean` | Registers a language-keyed template table under a scope name. Called twice by `GroupPhrases.lua` |
| `V:GetAvailableAccents` | `() -> array` | `{{id, label}, ...}` beginning with `auto` and `none`, filtered by the selected language and optionally by race |
| `V:ResolveAccent` | `() -> accent or nil` | The accent record actually in force, resolving `auto` through `raceAccents` and returning nil for `none` or an ineligible selection |
| `V:GetPlayerRace` | `() -> string` | `UnitRace("player")` token, with a substring probe that maps a Skyborne race to `"Skyborne"` |
| `V:LocalizeRoleText` | `(roles, fallback) -> string` | Slash-joined localized role names in `roleOrder`, or the localized fallback label |
| `V:LocalizeActivityType` | `(kind) -> string` | Localized `Dungeon`/`Raid`/`Quest` |
| `V:Format` | `(template, vars) -> string` | `{name}`-style interpolation; unknown placeholders are left literal. Clamps to 250 bytes without splitting a UTF-8 character |
| `V:Pick` | `(scope, kind, language, accent, base, additional, randomized) -> string` | Shuffle-bag selection among `base` plus deduplicated `additional` |
| `V:ChooseMessageTemplate` | `(kind, language, accent, base) -> string` | The older guild-only shuffle bag, still called through `VoiceBridge` |
| `V:BuildOptions` / `V:OpenOptions` / `V:RefreshOptions` | `()` | Settings panel lifecycle |
| `V:VoiceText` | `(kind, vars, preview) -> string` | **Legacy and unreachable inside the library.** Reads `self.db`, which the library never assigns, so it returns `""`. Retained verbatim from the pre-extraction GuildComms module |

### Documented usage, from `ForeverCommsVoice/README.md`

```lua
local V = _G.ForeverCommsVoice
local message = V:Render("group", "pull", nil, {random=true})
local welcome = V:Render("guild", "join", {name="Rosa"},
    {custom=ForeverGuildCommsDB.templates.join, random=true})
```

The library never sends chat, never takes an action on the player's behalf and never
changes what the player types. Delivery timing belongs entirely to the consumer.

## Internal APIs

### ForeverGuildComms — `_G.ForeverGuildComms`, 64 methods

#### Core.lua — 27 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:NormalizeTiming` | `(key, value, fallback) -> number or nil` | Clamp and round a timing value to `timingLimits`; rejects NaN and infinities |
| `A:Print` | `(s)` | Tagged chat-frame output |
| `A:Key` | `(name) -> string` | Lowercase, trim, collapse whitespace. All name-keyed lookups go through this |
| `A:IsSelf` | `(name, guid) -> boolean` | GUID first, then the normalized name, `selfKeys`, and a single explicit `-Realm` strip. Never shortens a character name further |
| `A:ChatLimit` | `(text) -> string` | UTF-8-safe 250-byte clamp |
| `A:Format` | `(template, vars) -> string` | Interpolate then clamp |
| `A:CommsText` | `(kind, vars, preview) -> string` | Prefers `VoiceText` when present, else the raw template. The one seam that makes the voice layer optional |
| `A:CanUse` | `() -> boolean` | `db.enabled and IsInGuild()`. The precondition for every guild-facing behaviour |
| `A:Now` | `() -> number` | `GetTime()` or 0 |
| `A:PruneEventsSeen` | `(now)` | Drop dedup keys older than 3600s, throttled to once per 60s |
| `A:IsDuplicate` | `(key, cooldown) -> boolean` | Prune, then test and record |
| `A:SendGuild` | `(message) -> boolean` | The **only** `SendChatMessage` call site. Re-checks `CanUse`, clamps, wraps in `pcall` |
| `A:QueueGuild` | `(message, key, cooldown)` | The required path for every automatic message: dedup, build an entry stamped with the current guild, then stage or enqueue |
| `A:StageApproval` | `(entry)` | Append to the verify backlog, capped at 30 oldest-first |
| `A:ApproveMessage` | `(index)` | Explicit send. Discards the entry if the guild changed; never schedules a delayed send after a click |
| `A:DismissMessage` | `(index)` | Discard without sending |
| `A:ClearApprovals` | `()` | Wipe the backlog |
| `A:DrainQueue` | `()` | Latched timer enforcing `max(3, messageSpacing)` between automatic sends; re-checks guild identity and mode inside the callback |
| `A:RoleText` | `(roles, noneText) -> string` | Untranslated role join, used for custom templates |
| `A:RefreshOptions` | `()` | Invoke the Settings panel's refresh closure list |
| `A:SetOption` | `(key, value) -> boolean` | The single settings writer for Settings and the Titan menu. Validates by key class; templates are deliberately rejected here |
| `A:VoiceOptionLabel` | `(key, id) -> string` | Display label for a voice value |
| `A:SetVoiceOption` | `(key, value) -> boolean` | Validate and write a shared voice value, re-validate the accent, refresh both panels and the help preview |
| `A:VoiceChoices` | `(key) -> array` | Choice list for a voice cycler |
| `A:RunQuickAction` | `(action)` | `alerts`, `help`, `rescan`. None of them sends guild chat |
| `A:OpenSettings` | `(section)` | Open the panel, optionally deferring a scroll to the messages or languages anchor |
| `A:Initialize` | `()` | SavedVariables creation and migration, timing normalization, the one-time Voice migration, identity capture, class role defaults, module construction, the 300s prune ticker, the 3-second login tabard check, the broker probe |

#### VoiceBridge.lua — 7 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:GetPlayerRace` | `() -> string` | Forward to `V` |
| `A:GetAvailableAccents` | `() -> array` | Forward to `V` |
| `A:ResolveAccent` | `() -> accent or nil` | Forward to `V` |
| `A:VoiceText` | `(kind, vars, preview) -> string` | `V:Render("guild", kind, vars, {custom=db.templates[kind], random=db.randomizeMessages == true, preview=preview})`. The whole translation of GuildComms' old contract into the library's |
| `A:LocalizeRoleText` | `(roles, fallback) -> string` | Forward to `V` |
| `A:LocalizeActivityType` | `(kind) -> string` | Forward to `V` |
| `A:ChooseMessageTemplate` | `(kind, language, accent, base) -> string` | Forward to `V` |

The module also aliases eight Voice data tables onto `A` — `voiceDefaults`, `languages`,
`languageByID`, `localeTemplates`, `localeRoleNames`, `localeActivityTypes`, `accents`,
`accentOrder`, `raceAccents`, `localeVariants`, `accentVariants`, `messageVariantBags` —
so `Options.lua` and `TitanMenu.lua` required no changes.

#### Roster.lua — 7 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:RequestRoster` | `(force)` | `C_GuildInfo.GuildRoster()` behind a 30-second throttle |
| `A:ReadRoster` | `() -> members, count, online` | Normalized snapshot keyed by `A:Key(name)` |
| `A:AcceptRoster` | `(members, count, online, baseline)` | The diff. Level congratulations need online-to-online plus a numeric prior level above zero plus a strictly higher new level; login greetings need offline-to-online. A baseline read sends nothing |
| `A:CaptureBaseline` | `()` | First read; retries in 4 seconds on a zero count |
| `A:OnRosterEvent` | `(event)` | Guild-change reset that wipes the pending queue and clears approvals, baseline deferral, and the incomplete-read guard: reject a count of zero or, above 10 known members, a count below 70% of the known total |
| `A:OnSystemGuildJoin` | `(message)` | Pattern built from the localized `ERR_GUILD_JOIN_S` with Lua metacharacters escaped |
| `A:SetupRoster` | `()` | Immediate and 5-second reads, then a 60-second request ticker |

#### Alerts.lua — 5 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:AddAlert` | `(kind, sender, text)` | Private only: 120-second dedup, push onto a 30-entry list, print locally, optional sound, refresh UI and broker |
| `A:ScheduleRecipeScan` | `()` | 0.5-second debounce |
| `A:ScanRecipes` | `() -> boolean` | Fresh cache for the open profession; learned, non-disabled, non-gathering recipes with names of at least 4 characters |
| `A:MatchCraft` | `(lower) -> string or nil` | Requires both an explicit request phrase and an exact cached recipe or output name |
| `A:OnGuildChat` | `(message, sender)` | Drops self, cleans escapes, then craft and group matching. Group alerts are suppressed when the line already matched a craft request |

#### Tabard.lua — 2 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:CheckTabard` | `(initial)` | Transition state machine. A login check can still prompt after an earlier zone check initialized `wasInCity`; `tabardCityPrompted` enforces at most one prompt per city stay |
| `A:ScheduleTabardCheck` | `()` | 1.2-second latched debounce |

#### UI.lua — 11 methods

`A:BuildUI`, `A:UpdateAlertsUI`, `A:ShowAlerts`, `A:BuildApprovalsUI`,
`A:UpdateApprovalsUI`, `A:ShowApprovals`, `A:BuildRequestUI`, `A:RequestText`,
`A:UpdateRequestPreview`, `A:ShowRequest`, `A:SendHelpRequest`.

`A:RequestText` is the notable one: it builds a fingerprint from the template, the
randomize flag, all four voice values and all five interpolated variables, and reuses the
cached draft unless the fingerprint changed — so Send posts exactly the previewed
wording. `A:SendHelpRequest` calls `SendGuild` directly after an explicit click and
enforces one request per 20 seconds.

#### Options.lua, TitanMenu.lua, Broker.lua — 5 methods

`A:BuildOptions`; `A:PopulateTitanMenu`, `A:OpenTitanMenu`; `A:TryBroker`,
`A:UpdateBroker`.

### ForeverGroupComms — `_G.ForeverGroupComms`, 47 methods

#### Core.lua — 20 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:Now` | `() -> number` | `GetTime()` or 0 |
| `A:Print` | `(s)` | Tagged `DEFAULT_CHAT_FRAME` output |
| `A:Key` | `(n) -> string` | Same normalization contract as GuildComms |
| `A:Trim` | `(text) -> string` | UTF-8-safe 250-byte clamp |
| `A:Render` | `(kind, vars) -> string` | Shared-voice branch when `useSharedVoice` and the global are both present, passing `fallback = variants[kind][1]`; otherwise the local English rotation with a one-step anti-repeat |
| `A:GroupChannel` | `() -> string or nil` | `INSTANCE_CHAT`, `RAID` or `PARTY`; nil when ungrouped |
| `A:SameGroup` | `(name) -> boolean` | Roster membership test |
| `A:IsSelf` | `(name) -> boolean` | Normalized comparison against `playerKey` |
| `A:IsDuplicate` | `(key, seconds) -> boolean` | Inline sweep of entries older than 1200s, throttled to 60s, then test and record |
| `A:Notify` | `(message, key)` | Private only: 90-second dedup, push onto a list bounded by `maxNotifications`, print, refresh |
| `A:CanChat` | `() -> boolean` | `db.enabled and activeGroup and SendChatMessage` |
| `A:Send` | `(kind, vars) -> boolean` | The **only** `SendChatMessage` call site. Renders, enforces a 2-second floor since the last send, `pcall`s the send |
| `A:Stage` | `(kind, vars, desc)` | Queue a suggestion stamped with `groupSerial`, capped at 12 oldest-first, and notify |
| `A:Approve` | `(index)` | Explicit send; discards a suggestion whose serial no longer matches |
| `A:Quick` | `(kind) -> boolean` | Dispatch for keybindings, buttons and slash commands |
| `A:CanManageGroup` | `() -> boolean` | Leader, or raid assistant in a raid |
| `A:ReadyCheck` | `()` | Rank check, combat check, `C_PartyInfo.DoReadyCheck` or `DoReadyCheck`, `pcall` |
| `A:MarkTarget` | `(index)` | Rank check, target exists, target hostile, combat check, `SetRaidTarget` or `SetRaidTargetIcon`, `pcall` |
| `A:OpenSettings` | `()` | Settings category or the panel |
| `A:Initialize` | `()` | SavedVariables creation with per-key type repair, `maxNotifications` clamped to 5..40, identity capture, quest-sync init, options, first roster scan, broker probe |

#### Roster.lua — 6 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:ScanRoster` | `(silent)` | Enumerate units, read assigned roles and levels, detect identity change, bump `groupSerial` and wipe suggestions and quest peers when it changes, then decide greetings, welcomes and congratulations. A `silent` call suppresses all messaging |
| `A:RoleCounts` | `() -> table` | Tank, healer, damager, none |
| `A:RoleSummary` | `() -> string` | Role-sorted `Name Role` list, collapsing to counts above 160 characters |
| `A:RoleIssues` | `() -> array` | Unassigned roles always; in a non-raid party, a tank or healer count other than one |
| `A:ReviewRoles` | `(quiet)` | Private notification keyed by `groupSerial` |
| `A:OnReadyCheckEvent` | `(event, ...)` | Private tally. Records confirmations against the current serial and reports ready, not-ready and unconfirmed counts, explicitly stating that unconfirmed is not proof of a negative answer |

#### Quests.lua — 12 methods

| Method | Signature | Purpose |
| --- | --- | --- |
| `A:InitializeQuestSync` | `()` | `pcall` the prefix registration, record `questCommsReady`, seed the local quest snapshot |
| `A:ClearQuestPeers` | `()` | Wipe peers, reassembly state and the outbox; bump `outboxToken` to cancel in-flight work |
| `A:QueuePacket` | `(message, channel, target)` | Enqueue behind the ready, grouped and `questSync` gates; outbox capped at 60 |
| `A:FlushPackets` | `()` | One send per 1.15 seconds, re-checking serial, grouping and the setting inside the timer |
| `A:ScheduleQuestSync` | `(force)` | 2.5s forced, 4s otherwise, invalidated by `syncSeq` |
| `A:BroadcastQuests` | `(force)` | Signature suppression: an unchanged sorted ID list is not resent within 240 seconds. Bumps `questEpoch` and invalidates stored peer completions |
| `A:ReplyCompletions` | `(sender, epoch, ids)` | Whispered `R` packets covering **only the IDs the peer disclosed** |
| `A:OnAddonMessage` | `(prefix, message, channel, sender)` | Validate prefix, group membership and channel; parse and bound-check the header; reassemble; accept `Q` only if not older than the stored epoch and `R` only for the current local epoch |
| `A:QuestRows` | `() -> array` | Per-quest classification into missing, has, completed and unknown, sorted by missing then unknown |
| `A:ShareQuest` | `(id)` | Combat check, log presence check, pushable check, select-and-restore around `QuestLogPushQuest`, all `pcall`ed |
| `A:OtherQuestRows` | `() -> array` | Reverse comparison: peers' active quests absent from the local log, suppressing those already flagged completed |
| `A:RequestQuest` | `(id)` | Verify the quest is still in the reverse list, then send a chat request naming it |

#### UI.lua, Options.lua, Broker.lua — 9 methods

`A:BuildPanel`, `A:RefreshUI`, `A:ShowPanel`, `A:BuildQuests`, `A:RefreshQuestUI`,
`A:ShowQuests`; `A:BuildOptions`; `A:TryBroker`, `A:UpdateBroker`.

## Slash commands and bindings

| Addon | Commands | Keybindings |
| --- | --- | --- |
| Voice | `/fcv`, `/commsvoice` — opens the shared voice panel | none |
| GuildComms | `/fgc`, `/guildcomms` with `options`, `request`/`help`, `alerts`, `verify`/`review`, `recipes`, `clearrecipes`, `status`; bare input opens alerts | `FGC_OPEN_ALERTS`, `FGC_ASK_HELP`, `FGC_RESCAN_PROFESSION` |
| GroupComms | `/fgp`, `/forevergroup` with `open`, `quests`/`quest`, `roles`, `ready`, `skull`, `moon`, `pull`, `mana`, `regroup`, `heal`, `cc`, `interrupt`, `sync`, `settings` | `FGROUP_PANEL`, `FGROUP_ROLES`, `FGROUP_QUESTS` |

No binding has a `default=` attribute; all six are opt-in. Both `Bindings.xml` files are
loaded automatically from their addon root and are deliberately absent from the TOCs.

## Wire protocol — GroupComms quest sync

The only serialized format in the project.

```text
Prefix:  ForeverGrpComms          (15 bytes; the WoW limit is 16)
Packet:  <kind>|<proto>|<epoch>|<part>|<total>|<csv>
  kind   Q = sender's active quest IDs, broadcast to the group
         R = responder's completed IDs, whispered back to the asker
  proto  "1"
  epoch  1 .. 100000000, integer
  part   1 .. total
  total  1 .. 12
  csv    comma-separated integers, 1 .. 99999999, max 230 bytes,
         no leading/trailing/doubled commas, digits and commas only
```

Chunking targets 205 bytes of payload per packet and refuses to send more than 12
chunks, printing "Quest log too large for group sync" instead.

**Validation applied to every inbound packet**, in order: prefix match, message is a
string, the client is grouped, sender is not self, sender is in the current roster,
channel is one of `PARTY`/`RAID`/`INSTANCE_CHAT`/`WHISPER`, header matches the pattern,
protocol equals `"1"`, every numeric field is an integer within range, `part <= total`,
the CSV parses, the reassembly `total` matches, and finally the epoch rule — a `Q` older
than the stored peer epoch is dropped and an `R` is accepted only when it equals the
local `questEpoch`.

**Disclosure limits**: only active quest IDs are broadcast. No titles, no objective
progress, no completion history is volunteered. A completion reply answers only the IDs
the asking peer already disclosed.

## Data Models

### `ForeverCommsVoiceCharDB` — per character

```lua
{
    voice = {language="en", accent="none", raceFilter=true, accentStrength="subtle"},
    migratedFromGuild = true,   -- latch; set once by MigrateLegacy
}
```
- **Validation**: `language` must exist in `languageByID` or resets to `en`;
  `accentStrength` must be `subtle`/`moderate`/`expressive`; `raceFilter` must be
  boolean; `accent` must be a string and must appear in `GetAvailableAccents()` or falls
  back to `auto`.

### `ForeverGuildCommsDB` — account wide

```lua
{
    enabled=true, outgoingMode="automatic",
    greetLogin=true, greetJoin=true, congratulateLevel=true,
    randomizeMessages=true,
    craftingAlerts=true, groupAlerts=true,
    tabardInCity=true, tabardOnExit=false,
    loginCooldown=300, messageSpacing=6, alertsSound=false,
    templates = {login=..., join=..., level=..., help=...},
}
```
- **Validation**: `fillDefaults` backfills recursively; `outgoingMode` is forced to
  `automatic` unless exactly `verify`; blank or whitespace-only templates are refilled;
  both timing keys pass `NormalizeTiming` on load. `messageSpacing` is clamped to 3..120
  and `loginCooldown` to 0..3600.

### `ForeverGuildCommsCharDB` — per character

```lua
{
    voice = {...},            -- legacy; migrated into ForeverCommsVoiceCharDB
    recipes = {["Profession"] = {["lowercase name"] = "Display Name"}},
    myRoles = {tank=bool, healer=bool, damage=bool},
    needRoles = {tank=bool, healer=bool, damage=bool},
}
```
- **Relationships**: `myRoles` is seeded from `classRoles[playerClass]`; `recipes` feeds
  `MatchCraft`. The `voice` subtable is read once by `MigrateLegacy` and then superseded
  by the shared table.

### `ForeverGroupCommsDB` — account wide

```lua
{
    enabled=true, autoGreeting=false, autoLevel=false,
    privateRoleAlerts=true, privateQuestReminder=true,
    questSync=true, randomMessages=true, useSharedVoice=true,
    maxNotifications=20,
}
```
- **Validation**: missing keys copied from defaults; any key whose stored **type** does
  not match the default's type is reset; `maxNotifications` clamped to 5..40 and floored.
- **Note on defaults**: the two settings that would post to chat without a click —
  `autoGreeting` and `autoLevel` — both default to `false`. `questSync` defaults to
  `true`, which enables the addon message exchange on first load.

### Runtime-only state

| Addon | Field | Shape | Bound |
| --- | --- | --- | --- |
| Voice | `messageVariantBags` | signature to `{order, position, count, last}` | unbounded, session-local |
| Voice | `catalogs` | scope to language-keyed table | 2 entries |
| Guild | `eventsSeen` | dedup key to timestamp | pruned at 3600s |
| Guild | `alerts` | newest-first list | 30 |
| Guild | `pendingApprovals` | oldest-first list | 30 |
| Guild | `pendingMessages` | FIFO queue | unbounded in principle; drained on a timer and wiped on guild change |
| Guild | `roster` | key to `{name, level, online, guid}` | guild size |
| Guild | `requestDraft` | `{fingerprint, text}` | 1 |
| Group | `seen` | dedup key to timestamp | pruned at 1200s |
| Group | `notifications` | newest-first list | `maxNotifications`, 5..40 |
| Group | `approvals` | oldest-first list | 12 |
| Group | `roster` | key to `{name, key, guid, token, role, level}` | group size |
| Group | `questPeers` | key to `{epoch, active, completed, completionEpoch, when}` | group size, 300s TTL |
| Group | `questParts` | token to `{total, pieces, when}` | pruned at 60s |
| Group | `addonOutbox` | FIFO queue | 60 |
