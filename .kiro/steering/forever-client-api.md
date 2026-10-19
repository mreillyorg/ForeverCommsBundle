---
inclusion: fileMatch
fileMatchPattern: '*.lua'
---

# WoW: Forever client and API constraints

Target client: **World of Warcraft: Forever**, game version 1.60.1, TOC
`## Interface: 16001` in all three packages. Beta opened 2026-09-17; the beta AddOns path
on this machine is `World of Warcraft\_classic_beta_\Interface\AddOns\`.

## The single most important fact

Forever is **not** the Classic Era client. It runs on the modern (Mainline) UI
architecture — Forever and Midnight are two game types in the same code family, and
Forever exposes the large majority of the 12.1.5-era API. Practical consequences:

- Write against **modern namespaced APIs** (`C_Timer`, `C_Map`, `C_GuildInfo`,
  `C_TradeSkillUI`, `C_QuestLog`, `C_PartyInfo`, `C_ChatInfo`, `C_Container`, `Settings`),
  not Vanilla-era equivalents. Classic-only patterns (`GuildRoster()`,
  `SetMapToCurrentZone`, `GetContainerItemInfo` as a global, XML-driven
  `InterfaceOptions_AddCategory`) are the wrong target. Where a legacy fallback is kept it
  is deliberate and paired with the modern path — `Quests.lua` supports both
  `C_QuestLog.GetInfo` and `GetQuestLogTitle`, and `Core.lua` falls back from
  `C_PartyInfo.DoReadyCheck` to `DoReadyCheck` and from `SetRaidTarget` to
  `SetRaidTargetIcon`.
- The **Midnight addon disarmament rules, including secret values, are active in
  Forever.** APIs that expose combat-relevant state can return secret values that addon
  code cannot inspect, and arithmetic or comparison on a secret errors. Stay out of
  combat data entirely (see the product non-goals) and never assume a returned number is
  a plain number if it comes from a unit/combat API. This is why GroupComms reads
  *assigned* roles and levels and nothing about performance.
- Game *content* is Vanilla 1–60: item IDs, zones, professions, and classes are
  Vanilla-era. Hence Guild Tabard `5976` and the nine-class `A.classRoles` table.

Sources, rephrased for compliance with licensing restrictions:
[Patch 1.60.1 API changes notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes),
[Blizzard on Midnight addon changes](https://news.blizzard.com/en-us/article/24244638/how-midnights-upcoming-game-changes-will-impact-combat-addons),
[Forever addon overview](https://teamoverpowered.com/forever/guides/addons/).

## Chat and messaging restrictions

- `SendChatMessage` to `"SAY"`, `"YELL"`, and `"EMOTE"` requires a hardware event when
  called from addon code outside instances. The channels this bundle uses — `"GUILD"` in
  GuildComms and `"PARTY"` / `"RAID"` / `"INSTANCE_CHAT"` in GroupComms — are not under
  that restriction. Do not move automatic messages to the hardware-event channel types.
- Resolve the group channel through `A:GroupChannel()` rather than hardcoding one;
  `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` must be feature-detected before use.
- Chat payloads are capped. Keep the existing 250-byte clamp, and keep it UTF-8 aware —
  translated strings routinely reach the cap and a naive `sub(1, 250)` can split a
  multibyte character. Each package has its own implementation (`V:Format`,
  `A:ChatLimit`, `A:Trim`); do not add a fourth.

## Addon messaging

Only `ForeverGroupComms` uses it. Constraints that shape the existing protocol:

- Prefixes are capped at **16 bytes**. `ForeverGrpComms` is 15 — keep any new prefix under
  the limit and comment the count.
- Register with `C_ChatInfo.RegisterAddonMessagePrefix` behind a `pcall`, and treat a
  non-zero/non-true result as "not ready" rather than assuming success.
- Addon messages share the chat throughput budget and can be dropped under load. The
  protocol therefore paces sends (one per 1.15s), chunks payloads, carries explicit
  `part`/`total` for reassembly, and expires incomplete reassembly state after 60
  seconds instead of waiting forever.
- **Trial accounts cannot send addon messages.** Quest sync must degrade to "unknown"
  rows rather than erroring or claiming a peer lacks a quest.
- Delivery is not guaranteed and arrival order is not guaranteed. Never treat silence as
  a negative answer — the same reasoning as the ready-check tally.
- Everything inbound is untrusted. See `guild-chat-safety.md` for the full validation
  order; the client-level point is that a peer's addon message is the only data in this
  bundle that does not originate from the local client or Blizzard.

## Identity

Creature/vehicle/pet/object GUIDs now carry obfuscated server and spawn ID portions.
They stay stable and unique within a session, so GUID equality for identity (what
`A:IsSelf` does with the player GUID, and what GroupComms' level check does across two
roster scans) is fine; never parse or compare GUID fragments to infer layer or realm.

`GetUnitName("player", true)` is not reliably populated before `PLAYER_LOGIN`. GuildComms
initializes on `PLAYER_LOGIN` and is safe; GroupComms and Voice initialize on
`ADDON_LOADED`, so any identity read there needs a fallback and must be re-derived later
(`A:ScanRoster` recomputes `playerKey` on every call).

## Beta volatility — code defensively

Blizzard is still changing this client, and the Forever default frames have already been
reskinned and reorganized once. Therefore:

- Feature-detect before every call to a Blizzard API or global, including ones you
  believe exist. The codebase already does this for `C_GuildInfo`, `C_TradeSkillUI`,
  `C_Map`, `C_QuestLog`, `C_PartyInfo`, `C_ChatInfo`, `GetInventoryItemID`, `PlaySound`,
  `SOUNDKIT`, `ToggleCharacter`, `Settings`, `MenuUtil`, `LibStub` and
  `QuestLogPushQuest`.
- Degrade gracefully with an `A:Print` note instead of erroring. Existing examples:
  `A:BuildOptions` when the Settings API is missing, `A:OpenTitanMenu` falling back to
  the Settings page when `MenuUtil` is absent, and every "this client does not expose…"
  message in GroupComms' `Core.lua`.
- Do not anchor to or reskin Blizzard's Forever unit frames or minimap header; they are
  moving targets.
- `Forever` is accepted as an alias for `Camelot` in TOC suffixes, the `[Game]` variable,
  and game-type folder lookup. If multi-client support is ever needed, prefer the
  `## AllowLoadGameType` directive over duplicating TOC files.
- Treat any API behavior not verified in a live client as unverified, and say so in that
  package's README limitations section rather than claiming it works. Nothing in this
  bundle has been run against a live server.

## Taint and protected code

Addon code is tainted. Never call protected functions or modify protected frames from a
non-hardware-event path, never `loadstring` user input, and keep all gear, invite,
targeting, and quest-acceptance actions in the player's hands (see product non-goals).
Securely-templated buttons are the only acceptable route if a protected action is ever
genuinely required.

The actions that come closest to the line are all explicitly gated: `DoReadyCheck` and
`SetRaidTarget` require leader/assistant rank plus an `InCombatLockdown` check, and
`QuestLogPushQuest` runs only from a button press, restores the previously selected quest
afterwards, and lets the game decide eligibility.

## Cross-addon loading

`## Dependencies: ForeverCommsVoice` means the client will not load the dependent addon if
the library is missing or disabled. That check verifies **presence, not version** — there
is no version negotiation, so a contract change in `V:Render` must land in all three
packages together. `## OptionalDeps: Titan` only affects load order; always still probe
with `LibStub("LibDataBroker-1.1", true)`.

## Reporting a client-side bug

Capture: the exact Lua error with `/console scriptErrors 1` then `/reload`, the event
that triggered it, which of the three addons raised it, and the build from
`/dump select(4, GetBuildInfo())`.
