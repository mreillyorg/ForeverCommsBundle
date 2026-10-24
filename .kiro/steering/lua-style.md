---
inclusion: fileMatch
fileMatchPattern: '*.lua'
---

# Lua style for this bundle

Match the existing files. All three packages are plain Lua 5.1 (the WoW runtime) with no
build step, no transpiler and no external libraries. The style is identical across
packages on purpose — someone who can read one should be able to read the others.

## Formatting

- 4 spaces, no tabs. No trailing whitespace. Keep lines under ~100 characters.
- No blank line between short related functions; the existing files pack
  `function A:Foo() ... end` definitions back to back.
- Single-statement bodies may stay on one line when it reads cleanly:
  `if not name then return false end`.
- Table constructors use `{key=value, other=value}` (no spaces around `=`) for compact
  data, and one entry per line for `A.defaults`-style config.
- Uniform data literals may exceed the line guide when wrapping would hurt readability —
  `Accents.lua`'s `register(...)` rows, `MessageVariants.lua`'s variant banks and
  `GroupPhrases.lua`'s catalogs are the accepted precedent.
- Use `..` with surrounding spaces for concatenation.

## Naming

- `A` for an application namespace, `V` for the library namespace. Methods `PascalCase`
  (`A:QueueGuild`, `V:Render`), state and locals `camelCase` (`self.rosterReady`,
  `local newMember`).
- SavedVariables, one set per package:

  | Table | Scope | Accessed as |
  | --- | --- | --- |
  | `ForeverCommsVoiceCharDB` | per character | `V.char.voice` |
  | `ForeverGuildCommsDB` | account | `A.db` |
  | `ForeverGuildCommsCharDB` | per character | `A.char` |
  | `ForeverGroupCommsDB` | account | `A.db` |

- Prefixes stay per package: GuildComms frames and popup keys use `FGC_` / `FGC`
  (`FGCAlertsFrame`, `FGC_TABARD_CITY`), bindings `FGC_*` under header
  `FOREVERGUILDCOMMS`, slash `/fgc` + `/guildcomms`. GroupComms uses full-name frames
  (`ForeverGroupCommsPanel`), bindings `FGROUP_*` under `FOREVERGROUPCOMMS`, slash `/fgp`
  + `/forevergroup`. Voice creates no named frames; slash `/fcv` + `/commsvoice`.
- Table keys for names always go through that package's `A:Key(name)` (lowercased,
  trimmed, whitespace collapsed) so lookups are consistent.
- Addon-message prefix: `ForeverGrpComms`, 15 bytes. The client limit is 16 — keep any
  new prefix under it and comment the byte count, as `Quests.lua` does.

## Required idioms

- **Gate every chat-facing behavior**, each package with its own gate:
  `A:CanUse()` in GuildComms (enabled flag + `IsInGuild()`), `A:CanChat()` in GroupComms
  (enabled flag + `activeGroup` + `SendChatMessage` exists). The library has no gate
  because it never sends.
- **One send call site per package.** `A:SendGuild` in GuildComms and `A:Send` in
  GroupComms are the only places `SendChatMessage` appears. Route everything through them.
- **Type-check external data.** Roster levels, chat messages, Blizzard globals and
  anything from another player are validated before use (`type(message) ~= "string"`,
  `type(previous.level) == "number"`, the integrality and range checks in `parseIDs`).
- **Feature-detect every API** before calling it, because this is a beta client:
  ```lua
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  local fn = (C_PartyInfo and C_PartyInfo.DoReadyCheck) or DoReadyCheck
  ```
- **Wrap protected calls that can error** in `pcall` and report via `A:Print` —
  `SendChatMessage`, `SendAddonMessage`, `RegisterAddonMessagePrefix`, `DoReadyCheck`,
  `SetRaidTarget`, `QuestLogPushQuest`, and every `C_QuestLog` lookup.
- **Debounce/schedule with `C_Timer.After` plus a boolean latch** — the
  `ScheduleRecipeScan` / `ScheduleTabardCheck` / `baselineTimer` / `DrainQueue` /
  `FlushPackets` pattern — so repeated events collapse into one run.
- **Invalidate deferred work with a serial or epoch**, not by hoping. Capture the counter
  in the closure, compare when the timer fires, return if it moved. Existing counters:
  `groupSerial`, `rosterRequest`, `syncSeq`, `outboxToken`, `questEpoch`. Add one rather
  than letting a stale callback act on fresh state.
- **Bound every cache.** Nothing may grow for the life of a session. `eventsSeen` is
  pruned at the maximum *supported* cooldown (not the configured one) with an
  activity-throttled sweep plus an idle ticker; GroupComms sweeps `seen` at 1200s and
  `questParts` at 60s; lists are capped (`alerts` 30, `pendingApprovals` 30,
  `approvals` 12, `addonOutbox` 60, `notifications` at `maxNotifications`).
- **Guard the clock.** `GetTime` can jump across a reload, so dedup tests use
  `now >= seenAt` and sweeps discard future-dated entries.
- **Clamp user text to 250 bytes without splitting a UTF-8 character.** Three equivalent
  implementations exist, one per package: `V:Format`, `A:ChatLimit`, `A:Trim`. Use the one
  belonging to the package you are editing; do not add a fourth. Edit boxes also use
  `SetMaxLetters`.
- Escape Lua pattern characters when building patterns from Blizzard localized globals
  (see the `ERR_GUILD_JOIN_S` handling in GuildComms' `Roster.lua`). Prefer
  `string.find(haystack, needle, 1, true)` for plain substring tests.
- Use `wipe(t)` for clearing tables, `table.insert`/`table.remove` for list edits.
  Assigning `nil` to the current key inside a `pairs` loop is permitted and is how the
  sweeps work.

## Shared-library rules

- The library renders text. It must never register an event, start a timer, or send
  anything. Keep `Core.lua`'s surface to profile access, validation, catalogs and
  rendering.
- Reach it through `_G.ForeverCommsVoice` at call time, never a load-time local in a
  feature file.
- **The shared profile has one owner.** Prefer `V:SetOption` over writing
  `V.char.voice[key]` or `A.char.voice[key]` directly: `A.char.voice` and
  `ForeverCommsVoiceCharDB.voice` are the **same table object** at runtime, so a direct
  write in one addon silently changes the other's behavior and leaves the library's panel
  stale.
- Duplicated data across the package boundary — GuildComms' `defaults.templates` against
  `V.defaults.templates`, GroupComms' `variants` against `groupTemplates.en` — is
  load-bearing. `V:Render`'s custom-template check compares against the library's English
  base, so if the two default tables drift, every user's unmodified template is treated
  as custom and translation silently stops. Change both halves together and keep the
  assertions in `ForeverCommsVoice/tests/integration.lua` honest.

## Comments

Sparse and explanatory — comment *why* a guard exists, not what a line does. Existing
examples worth matching: the realm-suffix note in `A:IsSelf`, the incomplete-roster guard
in `OnRosterEvent`, the item-5976 note in `Tabard.lua`, the retention-window rationale
above `A.eventRetentionSeconds`, `"15 bytes; WoW prefix limit is 16"`,
`"QUEST_LOG_UPDATE also fires for kill counts"`, `"A lack of READY_CHECK_CONFIRM is not
proof the member clicked Not ready"`, and `"The Send button must send exactly the wording
shown in the preview"`. Keep that density.

### Withdrawn findings get a comment at the code site

When a review finding turns out to be **wrong** and the code is correct as written, the
withdrawal has to be recorded *in the code*, not only in a ledger or an assessment
document. A reviewer or a reverse-engineering pass derives findings by reading source; if
the source carries no marker, the same wrong finding gets raised again, and the second
time someone may "fix" it.

A docs-only record does not close the loop. Recording it in three places —
`SUGGESTED-CHANGES.md`, the assessment document, and an `Avoid` entry here — still left
the two `math.random` call sites unannotated, which was a real gap until comments were
added at both. The pattern to follow:

1. A comment at each affected site saying what is correct and what not to change. One
   site carries the reasoning; the others cross-reference it rather than repeat it.
2. A pointer from that comment to the decision record, so the evidence is findable.
3. An `Avoid` entry here if the mistake generalizes beyond those sites.

`V:Pick` in `ForeverCommsVoice/Core.lua` is the worked example.

## Avoid

- New globals, `getglobal`, string keys built by concatenating unnormalized names.
- `OnUpdate` scripts for periodic work; use `C_Timer.After` / `C_Timer.NewTicker`.
- `/run`-style string loading, `loadstring`, or anything that would taint protected code.
- Deep nesting; prefer early `return` guards, as the existing handlers do.
- LuaJIT-only features (`ffi`, `bit`, `jit`, `table.new`, `goto`) in shipped code **or in
  harnesses** — the client is 5.1 and a harness must not come to depend on a superset.
- A second implementation of something the bundle already has once: the byte clamp, the
  shuffle bag, and the name-normalizer all already exist. Reuse within the package, and
  across packages reuse via the library rather than copying.
- Behavior reimplemented rather than moved when relocating code between packages. Diff
  the old and new implementations line by line; a dropped branch that no test covers is
  how the Expressive punctuation rule went missing during the voice extraction.
- `math.randomseed`, in shipped code or harnesses. It **does not exist in the WoW
  client**, which seeds the RNG itself at startup, so a seed call errors at load. The two
  shuffle sites (`V:Pick` in ForeverCommsVoice `Core.lua`, `math.random(#list)` in
  ForeverGroupComms `Core.lua`) are correct as written. Running the offline suite *will*
  show the same shuffle order every time, because plain Lua 5.1 defaults to seed 1 — that
  is the harness, not the game, and tests depend on it. Do not "fix" it.
