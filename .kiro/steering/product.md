# Forever Comms bundle — product context

Three addons for **World of Warcraft: Forever** (client 1.60.1, Interface `16001`),
author Michael Reilly, in one repository (`ForeverCommsBundle`).

| Package | Version | Role |
| --- | --- | --- |
| `ForeverCommsVoice` | 0.1.0-beta | Shared library. Owns wording only — never sends |
| `ForeverGuildComms` | 0.5.0-beta | Guild social layer |
| `ForeverGroupComms` | 0.2.0-beta | Party and dungeon layer |

Both applications declare `## Dependencies: ForeverCommsVoice`. The library depends on
neither.

## What each one does

**ForeverCommsVoice** — one per-character language/accent profile shared by both
applications. 8 curated offline languages, 29 roleplay and regional accent phrasebooks,
a race-to-accent map, guild and group phrase catalogs, and shuffle-bag message variation.
It renders text and nothing else.

**ForeverGuildComms** — greets guildmates on offline → online transitions, welcomes new
members, congratulates level-ups of *other* members, with a choice of automatic delivery
or click-to-send review. Private (self-only) alerts for guild-chat crafting requests
matching cached known recipes and for LFG/LFM requests. Tabard reminders on
entering/leaving capital cities. An "Ask for Help" composer that sends one explicit
request. Optional LibDataBroker/Titan indicator with a nested options menu.

**ForeverGroupComms** — greets new parties and welcomes mid-run joiners, congratulates
group level-ups, all **staged for a click by default**. Coordination calls (pull, mana,
regroup, wait for healer, CC moon, focus skull, interrupts, quest reminder). Native ready
checks and skull/moon target marks, leader or raid assistant only. A private role
double-check. Bidirectional quest-log comparison with other users of the addon, and a
manual quest-share button. Optional LibDataBroker indicator.

## Non-goals — do not implement these

Deliberate product constraints, not missing features. Do not add them without the user
explicitly asking.

### All three packages

- **No automation of player actions.** Never equip, unequip or swap gear; never accept or
  decline invites, never auto-whisper, never auto-reply, never queue for content, never
  accept, abandon or turn in a quest, never change anyone's role. The tabard feature opens
  the character panel; quest sharing asks WoW's own push API after a click; ready checks
  and target marks require rank and an explicit trigger.
- **No congratulations for the player's own level-up.** Headline behavior in both
  applications: `A:IsSelf` + `A:AcceptRoster` in GuildComms, the `key ~= self.playerKey`
  guard in GroupComms' `ScanRoster`.
- **No combat, DPS, threat or encounter features.** The Forever client secrets the data
  and it is outside the bundle's purpose.
- **No hard *third-party* library dependencies.** Titan/LibDataBroker is probed at runtime
  with `LibStub(..., true)` and both applications work fully without it. Nothing is
  vendored. `ForeverCommsVoice` is the one hard dependency and it is first-party.
- **No rewriting of what the player types.** The voice layer only renders addon-generated
  messages. User-authored templates pass through verbatim, including item links and
  `{variables}`.

### ForeverCommsVoice specifically

- **The library never sends, never registers a chat or combat event, and never decides
  when a message is delivered.** Consumers own delivery. Keep it that way — it is what
  makes the library safe to share.
- **No machine translation.** All 8 languages are hand-curated offline tables for
  addon-generated templates only.

### ForeverGuildComms specifically

- **No scanning of channels other than guild chat** for alerts.
- **No addon-to-addon comms.** GuildComms has none and should gain none without a request.

### ForeverGroupComms specifically

- **Addon-to-addon comms are in scope here, and bounded.** The quest-sync protocol is a
  headline feature, gated behind the `questSync` setting. Its limits are product
  constraints: **active quest IDs only** — no titles, no objective progress, no completion
  history volunteered; a completion reply answers **only the IDs the asking peer already
  disclosed**; peer input is validated before any of it is stored; and nothing from the
  wire is ever acted on automatically.
- **No inferring a player's spec or preferred role.** Read *assigned* roles only.
- **No announcing ready-check results to chat.** The tally is private, and an absent
  confirmation is never reported as a refusal.

## Voice of user-facing strings

Plain, short, friendly. Addon-generated messages are templates with `{name}`, `{level}`,
`{type}`, `{activity}`, `{myroles}`, `{needed}`, `{roles}`, `{quest}` placeholders.
GuildComms' four templates are user-editable in Settings; group phrases are not editable.
Prefix console output through each package's own `A:Print` / `V:Print` so everything
carries its addon tag.

Option labels and hints must stay honest about what a feature will and will not do — the
tabard reminder never equips, quest sharing is validated by the game, role alerts never
change a role. Keep default templates, option text and all console output in English;
the 8-language layer covers **addon-generated chat messages only**, not the UI.
