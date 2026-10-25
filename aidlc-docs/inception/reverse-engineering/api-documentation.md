# API Documentation

**Target**: ForeverCommsVoice 0.2.2-beta, ForeverGroupComms 0.3.4-beta, ForeverGuildComms 0.6.3-beta
**Analysis date**: 2026-10-25T04:00:00Z
**Target commit**: `f7f7bab`

## REST APIs

**None.** This is a WoW addon bundle. There is no HTTP surface, no socket, and no cloud
service. The only inter-process communication is the game's own chat transport.

## Internal APIs

### ForeverCommsVoice — the shared library (34 methods)

Published as `_G.ForeverCommsVoice`. This is the only cross-package API contract in the
bundle, so a change here is a change to both consumers.

#### `Core.lua` — wording and the voice profile

| Method | Purpose |
| --- | --- |
| `V:Print(message)` | Tagged console output |
| `V:GetSettings()` | The per-character voice profile, normalized and clamped on every read |
| `V:MigrateLegacy(legacy)` | One-time adoption of GuildComms' old profile, latched by `migratedFromGuild` |
| `V:ValidateOption(key, value)` | Whether a profile write is acceptable |
| `V:SetOption(key, value)` | **The sole writer of the shared profile.** Validates, writes, refreshes dependents. Returns `true` on success |
| `V:RegisterCatalog(scope, catalog)` | Register a phrase catalog under `"guild"` or `"group"` |
| `V:Format(template, vars)` | Substitute `{name}`-style placeholders, then clamp to 250 bytes on a UTF-8 boundary |
| `V:Pick(scope, kind, language, accent, base, additional, randomized)` | Shuffle-bag selection; exhausts a bank before repeating and avoids consecutive duplicates |
| `V:Render(scope, kind, vars, options)` | **The main entry point.** Dispatches to a per-scope resolver, picks a template, applies flair and the Expressive punctuation rule, substitutes and clamps |

**`V:Render` options contract** — the part a consumer depends on:

| Field | Meaning |
| --- | --- |
| `custom` | A user-authored template. If it differs from the English catalog base it is treated as a user edit and returned **untransformed** |
| `random` | `false` pins the first template; otherwise the shuffle bag is consulted |
| `preview` | `true` renders without consuming a shuffle choice |
| `fallback` | Used when the scope or kind is unknown |

#### `Queue.lua` — the shared review backlog

| Method | Purpose |
| --- | --- |
| `V:GetQueueSettings()` | Persisted queue settings, each clamped on read |
| `V:SetQueueOption(key, value)` | Validating writer for queue settings |
| `V:PendingCount(source)` | Count, optionally filtered to `"guild"` or `"group"` |
| `V:PendingList(source)` | The records, optionally filtered |
| `V:FindQueueItem(id)` | Returns index and item |
| `V:QueueChanged()` | Notify both consumers' UI |
| `V:EnsureQueueTicker()` | Arm the expiry ticker; cancelled when the queue drains |
| `V:Enqueue(data)` | **The producer entry point.** Returns a monotonic id, or nil if rejected |
| `V:Skip(id)` / `V:SkipAll(source)` | Remove without sending |
| `V:Approve(id)` | Invoke the record's callback **only** on an explicit click |
| `V:Expire(timestamp)` | Drop timed-out records. Never sends |

**`V:Enqueue` record contract**:

```lua
V:Enqueue{
    source  = "guild" | "group",   -- required, validated
    kind    = "login",             -- optional label key
    label   = "Login greeting",    -- optional display label
    text    = "Welcome back!",     -- required, non-empty
    send    = function() return true end,  -- required
    timeout = 20,                  -- optional; omit for the user's default
}
```

The producer owns identity re-validation inside `send`. Returning `false, "stale"` tells
the queue to drop the record rather than leave it clickable; returning plain `false`
leaves it queued so the click can be repeated.

#### `QueueUI.lua` and `Options.lua`

`V:BuildQueueUI()`, `V:RefreshQueueCountdowns()`, `V:RefreshQueueUI()`,
`V:ShowQueue(onlyShow)`, `V:RefreshOptions()`, `V:BuildOptions()`, `V:OpenOptions()`.

#### `RaceProfiles.lua`

`A:GetPlayerRace()`, `A:GetAvailableAccents()`, `A:ResolveAccent()`,
`A:LocalizeRoleText(roles, fallback)`, `A:LocalizeActivityType(kind)`.

### ForeverGuildComms (68 methods)

Published as `_G.ForeverGuildComms`. Selected methods; see `code-structure.md` for the
per-module breakdown.

| Method | Purpose |
| --- | --- |
| `A:FillDefaults(dest, defaults)` | Recursive backfill, shared by load-time migration and Restore Defaults |
| `A:CanFillRole(role)` | Whether this character's class can offer a role |
| `A:Key(name)` | Lowercase, trim, collapse whitespace. All name keys go through it |
| `A:IsSelf(name, guid)` | GUID first, then the normalized name and realm-qualified variants. Strips only an explicit `-Realm` suffix, never a prefix |
| `A:ChatLimit(text)` | 250-byte clamp on a UTF-8 boundary |
| `A:CommsText(kind, vars, preview)` | The single wording indirection; delegates to the library |
| `A:CanUse()` | Enabled **and** `IsInGuild()`. Gates every guild-facing behaviour |
| `A:IsDuplicate(key, cooldown)` | Deduplication with periodic pruning |
| `A:SendGuild(message)` | The one send call site; `pcall` around `SendChatMessage` |
| `A:QueueGuild(message, key, cooldown)` | Dedup, then either stage for review or enqueue for spaced automatic sending |
| `A:StageApproval(entry)` | Hand to the shared queue capturing guild and text; falls back to a local 30-entry list |
| `A:ApprovalThrottled()` | The 2-second floor between explicit approvals |
| `A:ApproveMessage(index)` / `A:DismissMessage(index)` / `A:ClearApprovals()` | Fallback-list approval actions |
| `A:DrainQueue()` | Spaced automatic sending, re-checking guild and mode before each send |
| `A:SetOption(key, value)` | Validating writer shared by Settings and the Titan menu |
| `A:SetVoiceOption(key, value)` | Delegates to `V:SetOption`; the library stays the sole profile writer |
| `A:RunQuickAction(action)` | Single entry point for keybindings and the Titan menu |
| `A:AcceptRoster(members, count, online, baseline)` | The diff. `baseline = true` writes state and sends nothing |
| `A:OnRosterEvent(event)` | Guild-change reset, baseline scheduling, and the suspicious-read guard |
| `A:OnGuildChat(message, sender)` | Guild-chat-only alert parsing, self-excluded |
| `A:UpdateAlertsUI()` | Re-bind the 7 fixed rows to the current page |

### ForeverGroupComms (53 methods)

Published as `_G.ForeverGroupComms`.

| Method | Purpose |
| --- | --- |
| `A:Trim(text)` | 250-byte clamp on a UTF-8 boundary |
| `A:Render(kind, vars)` | Library wording, or the local English bank when `useSharedVoice` is off |
| `A:GroupChannel()` | `INSTANCE_CHAT`, `RAID` or `PARTY`; nil when ungrouped |
| `A:Notify(message, key)` | Private notification with optional dedup and a capped backlog |
| `A:CanChat()` | Enabled, grouped, and `SendChatMessage` present |
| `A:SendPrepared(message, serial)` | **The single send funnel.** Enforces `CanChat`, the serial check, and the 2-second floor. Returns `false, "stale"` on a serial mismatch |
| `A:Stage(kind, vars, desc)` | Capture the rendered text and serial, hand to the shared queue, fall back to a 12-entry list |
| `A:Approve(index)` | Fallback-list approval with a serial check |
| `A:CanManageGroup()` | Leader, or raid assistant in a raid. **Denies when the API is absent** |
| `A:ReadyCheck()` / `A:MarkTarget(index)` | Rank-gated, combat-gated, feature-probed |
| `A:ScanRoster(silent)` | Group scan; bumps `groupSerial` on an identity change and purges staged work |
| `A:OnReadyCheckEvent(event, ...)` | Private response tally; never announces results |

#### `Quests.lua` — the addon-message protocol

| Method | Purpose |
| --- | --- |
| `A:InitializeQuestSync()` | Register the prefix; sets `questCommsReady` |
| `A:ClearQuestPeers()` | Wipe peer state and **bump `outboxToken`**, cancelling queued packets |
| `A:QueuePacket(message, channel, target)` | Enqueue under the 60-entry bound, stamped with `groupSerial` |
| `A:FlushPackets()` | One packet per 1.15 seconds, re-checking token, serial, grouping and `questSync` at send time |
| `A:BroadcastQuests(force)` | Advertise active quest ids; skips an unchanged log inside 240 seconds; refuses past 12 chunks |
| `A:ReplyCompletions(sender, epoch, ids)` | Answer **only** the ids the peer disclosed |
| `A:OnAddonMessage(prefix, message, channel, sender)` | Inbound validation and reassembly |
| `A:QuestRows()` / `A:OtherQuestRows()` | Comparison rows in both directions |
| `A:ShareQuest(id)` / `A:RequestQuest(id)` | Manual, click-driven only |

## Data Models

### Wire format — quest sync

```text
KIND|PROTOCOL|EPOCH|PART|TOTAL|CSV
```

| Field | Rule |
| --- | --- |
| `KIND` | Exactly `Q` (advertisement) or `R` (completion reply) |
| `PROTOCOL` | Exactly `1` |
| `EPOCH` | Integer 1–100000000 |
| `PART` | Integer, 1 ≤ PART ≤ TOTAL |
| `TOTAL` | Integer 1–12 |
| `CSV` | Digits and single commas only, ≤ 230 bytes, each id 1–99999999. Empty is **valid** and means "no active quests" |

**Inbound validation order**, every step a rejection: prefix equality → body is a string
→ grouped → sender resolves, is not self, and **is in the current roster** → channel in
`PARTY`/`RAID`/`INSTANCE_CHAT`/`WHISPER` → header matches → protocol equals `1` →
numeric ranges → integrality → payload parses → reassembly `total` agrees → all parts
present. For `Q`, an older epoch is dropped; for `R`, the epoch must equal the local
`questEpoch` exactly.

Nothing from the wire is ever used as a name or compiled into a pattern. Peer names come
from the roster; quest titles come from local `C_QuestLog` lookups.

### SavedVariables

Four tables, three owners. No package writes another's table.

#### `ForeverCommsVoiceCharDB` (per character)

```lua
{
    voice = {language="en", accent="none", raceFilter=true, accentStrength="subtle"},
    queue = {visibleRows=2, autoSkipSeconds=20, sourceDisplay="text",
             showOnNew=true, x=0, y=0},
    migratedFromGuild = true,   -- latch; set once by MigrateLegacy
}
```

- **Validation**: `language` must exist in `languageByID` or resets to `en`;
  `accentStrength` must be `subtle`/`moderate`/`expressive`; `raceFilter` must be boolean;
  `accent` must appear in `GetAvailableAccents()` or falls back to `auto`. Queue fields are
  clamped on every read — `visibleRows` 1–10, `autoSkipSeconds` 0–3600, `sourceDisplay`
  to `text`/`icon`, position to ±10000.
- **Note**: `A.char.voice` in GuildComms and this `voice` table are the **same object** at
  runtime. Route every change through `V:SetOption`.

#### `ForeverGuildCommsDB` (account-wide)

Behaviour settings and custom templates, including `outgoingMode` (`"automatic"` or
`"verify"`), `greetLogin`, `greetJoin`, `congratulateLevel`, `craftingAlerts`,
`groupAlerts`, `randomizeMessages`, **`reviewAutoShow`** (new in 0.6.3-beta),
`loginCooldown`, `messageSpacing`, and `templates` for the four guild message kinds.

- **Migration**: `fillDefaults` backfills missing keys recursively on load; timing values
  are clamped by `A:NormalizeTiming`; `outgoingMode` is forced to a known value.

#### `ForeverGuildCommsCharDB` (per character)

`recipes` (keyed by profession name), `myRoles`, `needRoles`, and the legacy `voice`
table retained only so the migration latch can ignore it.

#### `ForeverGroupCommsDB` (account-wide)

`enabled`, `autoGreeting`, `autoLevel`, `privateRoleAlerts`, `privateQuestReminder`,
`questSync`, `randomMessages`, `useSharedVoice`, `maxNotifications`.

- **Migration**: `copyDefaults` plus a per-key `type()` check in `Initialize` repairs a
  wrong-typed stored value; `maxNotifications` is clamped to 5–40.

### Transient in-memory records

| Record | Shape | Bound |
| --- | --- | --- |
| Review queue item | `{id, source, kind, label, text, send, created, timeout, expiresAt}` | 100, oldest dropped |
| GuildComms pending message | `{text, kind, guild, time}` | Unbounded list, drained with spacing |
| GuildComms approval | same shape as above | 30, oldest dropped |
| GuildComms alert | `{kind, sender, text, time}` | 30, oldest dropped |
| GroupComms approval | `{kind, vars, text, serial}` | 12, oldest dropped |
| Addon outbox entry | `{message, channel, target, serial}` | 60, **refused** past the bound |
| Quest peer | `{epoch, active, completed, completionEpoch, when}` | One per roster member, 300-second TTL |
| Reassembly state | `{total, pieces, when}` | 60-second TTL, pruned at most once a minute |

**Nothing transient is persisted.** Queue contents hold a live callback and a
session-specific identity, so a reload discards them by design — which is why no stale
message can reach a new guild or group.
