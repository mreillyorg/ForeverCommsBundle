# System Architecture

**Target**: ForeverCommsVoice 0.2.2-beta, ForeverGroupComms 0.3.4-beta, ForeverGuildComms 0.6.3-beta
**Analysis date**: 2026-10-25T02:30:00Z
**Target commit**: `a64ac2a`

## System Overview

Three World of Warcraft addons shipped from one repository as a bundle. One is a shared
library; the other two are applications that depend on it. Everything runs in-process
inside the WoW client. There is no server, no network service beyond the game's own chat
transport, and no persistence other than Blizzard's SavedVariables files.

The architectural spine is a **single shared library with two consumers**, where the
library owns two cross-cutting capabilities that would otherwise be duplicated: how a
message is *worded*, and the backlog of messages *awaiting a click*. Both consumers own
when and whether a message is delivered; the library never sends anything.

## Architecture Diagram

```mermaid
graph TB
    subgraph Client["WoW Forever 1.60.1 client, Interface 16001"]
        subgraph VoicePkg["ForeverCommsVoice 0.2.2-beta - 9 modules, 1221 lines"]
            VCore["Core.lua<br/>profile, SetOption, Format, Pick, Render"]
            VData["Languages / Accents / RaceProfiles<br/>MessageVariants / GroupPhrases"]
            VQueue["Queue.lua<br/>shared review backlog, cap 100"]
            VQueueUI["QueueUI.lua<br/>movable overlay"]
            VOpts["Options.lua<br/>canvas panel + ADDON_LOADED frame"]
        end
        subgraph GuildPkg["ForeverGuildComms 0.6.3-beta - 9 modules, 1560 lines"]
            GCore["Core.lua<br/>send queue, approvals, dispatcher"]
            GRoster["Roster.lua"]
            GAlerts["Alerts.lua"]
            GTabard["Tabard.lua"]
            GUI["UI.lua"]
            GExtras["Options / TitanMenu / Broker / VoiceBridge"]
        end
        subgraph GroupPkg["ForeverGroupComms 0.3.4-beta - 7 modules, 1146 lines"]
            PCore["Core.lua<br/>send funnel, staging, dispatcher"]
            PRoster["Roster.lua"]
            PQuests["Quests.lua<br/>addon-message protocol"]
            PUI["UI.lua"]
            PExtras["Options / TitanMenu / Broker"]
        end
        SV[("SavedVariables<br/>4 tables")]
        Chat{{"Guild / Party / Raid chat<br/>+ addon messages"}}
    end
    Titan["Titan Panel + LibDataBroker<br/>optional, runtime probe"]

    GCore --> VCore
    GCore --> VQueue
    PCore --> VCore
    PCore --> VQueue
    VCore --> VData
    VQueue --> VQueueUI
    GCore --> Chat
    PCore --> Chat
    PQuests --> Chat
    VCore --> SV
    GCore --> SV
    PCore --> SV
    GExtras -.-> Titan
    PExtras -.-> Titan
```

## Component Descriptions

### ForeverCommsVoice

- **Purpose**: own every decision about how an addon-generated message is worded, and own
  the single backlog of messages awaiting user approval.
- **Responsibilities**: the per-character voice profile and its sole validating writer;
  8 languages; 29 accent phrasebooks; the race-to-accent map; the guild and group phrase
  catalogs; shuffle bags; the `V:Render` pipeline with per-scope resolvers; the 250-byte
  UTF-8 clamp; the review queue with its 100-entry bound, per-record expiry and movable
  overlay.
- **Dependencies**: none. It is the root of the dependency graph.
- **Type**: Shared library / Models.
- **Does not**: send chat, read chat, register for combat or roster events, or take any
  automatic action. Consumers own delivery.

### ForeverGuildComms

- **Purpose**: the guild-facing social layer.
- **Responsibilities**: roster diffing for login and level transitions; the guild send
  queue with spacing; automatic-versus-review delivery; the approval backlog and its
  floor; private craft and LFG alerts parsed from guild chat only; the learned-recipe
  cache; tabard reminders; the Ask-for-Help composer; a nested Titan menu; three
  keybindings.
- **Dependencies**: `ForeverCommsVoice` (hard, via TOC). Titan/LibDataBroker (optional).
- **Type**: Application.

### ForeverGroupComms

- **Purpose**: the party and dungeon layer.
- **Responsibilities**: group scanning and `groupSerial` identity stamping; greetings and
  level congratulations staged for review; coordination calls; native ready checks with a
  private response tally; target marking behind a rank gate; the bidirectional quest
  comparison protocol with its paced outbox; manual quest sharing; a nested Titan menu;
  three keybindings.
- **Dependencies**: `ForeverCommsVoice` (hard, via TOC). Titan/LibDataBroker (optional).
- **Type**: Application.

## Data Flow

### Staged guild greeting, reviewed and sent

```mermaid
sequenceDiagram
    participant Client as WoW client
    participant Guild as ForeverGuildComms
    participant Voice as ForeverCommsVoice
    participant User
    Client->>Guild: GUILD_ROSTER_UPDATE
    Guild->>Guild: ReadRoster, discard a suspicious read
    Guild->>Guild: AcceptRoster, diff offline to online
    Guild->>Voice: CommsText("login", vars)
    Voice-->>Guild: worded message, byte clamped
    Guild->>Guild: QueueGuild, dedup by key and cooldown
    Guild->>Voice: Enqueue, capturing guild and text
    Voice-->>User: review overlay shows the exact text
    User->>Voice: click Send
    Voice->>Guild: invoke the captured send callback
    Guild->>Guild: re-check CanUse, guild identity, approval floor
    Guild->>Client: SendChatMessage via pcall
```

### Quest comparison between two addon users

```mermaid
sequenceDiagram
    participant A as Player A
    participant Client as WoW client
    participant B as Player B
    A->>A: QUEST_LOG_UPDATE, debounced
    A->>A: BroadcastQuests, skip if unchanged under 240s
    A->>A: packetize, refuse past 12 chunks
    A->>Client: outbox, one packet per 1.15s
    Client->>B: Q|1|epoch|part|total|ids
    B->>B: validate prefix, sender in roster, channel, header, payload
    B->>B: reassemble, then record peer active set
    B->>Client: R|1|epoch|part|total|completed ids
    Client->>A: completion reply
    A->>A: accept only if epoch matches the current advertisement
    A->>A: QuestRows, shared / missing / completed / unknown
```

## Integration Points

- **External APIs**: none. No HTTP, no sockets, no cloud services.
- **Databases**: none. Four Blizzard SavedVariables tables, serialized by the client.
- **Third-party Services**: none at runtime. GitHub Actions and BigWigsMods/packager
  participate only at release time.
- **Game transport**: `SendChatMessage` for the three chat channel families, and
  `C_ChatInfo.SendAddonMessage` under the 15-byte prefix `ForeverGrpComms` for quest sync
  only.

## Event architecture

**One dispatcher per addon.** Each registers its events on a single frame, gates on
`if not A.initialized then return end`, and routes to module methods through existence
checks so a module can be absent.

| Addon | Dispatcher location | Events | Init trigger |
| --- | --- | --- | --- |
| ForeverCommsVoice | `Options.lua`, bottom | 1 — `ADDON_LOADED` | `ADDON_LOADED` matching `V.name` |
| ForeverGuildComms | `Core.lua`, bottom | 14 | `PLAYER_LOGIN` |
| ForeverGroupComms | `Core.lua`, bottom | 10 | `ADDON_LOADED` matching the vararg |

Voice's dispatcher living in `Options.lua` rather than `Core.lua` is a known deviation
from the project's own structure rule, recorded in `.kiro/steering/structure.md`. It is
also where the `ADDON_LOADED` registration defect fixed this span had been hiding: the
handler compared the event's addon name against a bare `ADDON`, which is nil in any file
following the `local _, V = ...` pattern, so the Settings panel was never registered
until the user ran `/fcv`.

## Infrastructure Components

- **CDK Stacks**: none.
- **Deployment Model**: file copy into `Interface\AddOns`. Four installers — one combined
  at the repository root plus one per package — parse their own TOC, copy only listed
  loadable files plus `Bindings.xml` and GuildComms' icon, back up what they replace under
  `Interface\AddOnBackups`, and never touch WTF or SavedVariables. The combined installer
  prepends `ForeverCommsVoice` to any selection naming a consumer, so a dependency-less
  install is unreachable rather than merely warned about.
- **Networking**: none.

## Architectural invariants

These are the properties the design depends on, and all of them are now asserted by
harnesses:

1. **The library never sends.** It words messages and holds a backlog; consumers deliver.
2. **One validating writer per setting.** `V:SetOption` owns the shared profile;
   `A:SetOption` owns GuildComms' settings. Panels and menus route through them.
3. **The shared voice profile has exactly one owner.** `A.char.voice` and
   `ForeverCommsVoiceCharDB.voice` are the same table at runtime, so neither consumer may
   write it directly — including from Restore Defaults.
4. **Identity is stamped, then re-checked at send time.** `groupSerial` for groups,
   the guild name for guilds. A message staged for one group or guild can never reach
   another.
5. **Bounds refuse rather than corrupt.** Caps decline work or drop the oldest, and a
   dropped entry's callback is never invoked.
6. **A missing client API denies.** Rank checks and feature probes fail closed.
