---
inclusion: auto
name: structure
description: Monorepo layout, per-package TOC load order, the shared-namespace module pattern, cross-file and cross-package call rules, the single event dispatcher per addon, and checklists for adding a module, adding wording to ForeverCommsVoice, or adding a fourth package. Use when creating or moving a source file, editing a TOC file list, wiring a new event, adding a feature to ForeverGuildComms, ForeverGroupComms or ForeverCommsVoice, or asking how the three packages fit together.
---

# Project structure and module pattern

Monorepo with **three sibling addon packages**. Each package is a flat folder with no
subdirectories for source. Every folder name must stay exactly the addon name, with a
matching `<Addon>.toc` inside it.

```text
ForeverCommsBundle-Development/
  .gitattributes  .gitignore  LICENSE  README.md
  install/                     combined three-addon installer
  ForeverCommsVoice/           shared library, 7 modules
  ForeverGuildComms/           guild addon, 9 modules + Bindings.xml + Media/
  ForeverGroupComms/           group addon, 6 modules + Bindings.xml
  aidlc-docs/  .kiro/          documentation and steering; never loaded by the client
```

Per package: `<Addon>.toc`, the flat `.lua` files, `tests/`, `install/`, `.pkgmeta`,
`README.md`. `tests/` and `install/` are never listed in a TOC.

## Load order (as listed in each TOC — order matters)

### ForeverCommsVoice — namespace `V`, no dependencies

| File | Responsibility |
| --- | --- |
| `Core.lua` | Publishes `_G.ForeverCommsVoice`. Defaults, profile read/normalize (`GetSettings`), `MigrateLegacy`, option validation and writing, catalog registry, `Format`, `Pick`, `Render` |
| `Languages.lua` | 8 languages, `languageByID`, guild `localeTemplates`, role and activity labels |
| `Accents.lua` | 29 accent phrasebooks via a file-local `register` helper, plus `accentOrder` |
| `RaceProfiles.lua` | `raceAccents`, `GetPlayerRace`, `GetAvailableAccents`, `ResolveAccent`, localized role/activity text |
| `MessageVariants.lua` | Guild `localeVariants` and `accentVariants` banks |
| `GroupPhrases.lua` | Group catalog for 8 languages, `groupAccentVariants`, **and the two `RegisterCatalog` calls that wire both scopes** |
| `Options.lua` | `/fcv` Settings panel, `RefreshOptions`, **and this package's only event frame** |

### ForeverGuildComms — namespace `A`, requires Voice

| File | Responsibility |
| --- | --- |
| `Core.lua` | Shared table, defaults, timing clamps, helpers (`Print`/`Key`/`IsSelf`/`ChatLimit`/`Format`/`CommsText`/`CanUse`/`Now`/`IsDuplicate`), guild send queue, verify backlog, option writers, SavedVariables init, `/fgc`, the single event frame |
| `VoiceBridge.lua` | The **only** coupling to the library. Hard-fails if absent; aliases Voice's data tables onto `A`; forwards six methods; rewrites `VoiceText` as `V:Render("guild", ...)` |
| `Roster.lua` | Guild roster read/baseline/diff, login + level-up messages, guild-join system message parsing |
| `Alerts.lua` | Guild chat parsing, craft/group detection, recipe cache scan, private alert list |
| `Tabard.lua` | City detection, tabard checks, `StaticPopupDialogs` |
| `UI.lua` | Alerts window, Verify window, Ask-for-Help window, fingerprinted draft, preview and send |
| `Options.lua` | Scrolling Settings canvas panel |
| `TitanMenu.lua` | Nested `MenuUtil` context menu |
| `Broker.lua` | Optional LibDataBroker data object |

`Bindings.xml` ships from the addon root and is **deliberately not in the TOC** — the
client auto-loads it.

### ForeverGroupComms — namespace `A`, requires Voice

| File | Responsibility |
| --- | --- |
| `Core.lua` | Shared table, defaults, the English `variants` fallback, helpers (`Print`/`Key`/`Trim`/`IsSelf`/`Now`/`IsDuplicate`), `Render`, `GroupChannel`, `Send`, `Stage`/`Approve`, `Quick`, rank checks, ready check, target marking, `/fgp`, the single event frame |
| `Roster.lua` | Group roster scan, `groupSerial`, role counts/summary/issues, greeting and level decisions, ready-check tally |
| `Quests.lua` | `Q`/`R` addon protocol, packetize/parse, paced outbox, both comparison directions, manual share |
| `UI.lua` | Main panel with quick actions, quest comparison window |
| `Options.lua` | Settings canvas panel from a declarative option table |
| `Broker.lua` | Optional LibDataBroker data object |

`Bindings.xml` ships from the addon root and is **not** in the TOC.

## Module pattern

Every file starts by capturing the addon vararg into its package's shared table:

```lua
local _, A = ...          -- Core.lua uses: local ADDON, A = ...
local _, V = ...          -- ForeverCommsVoice files use V
```

- One shared namespace per package, published from `Core.lua` as
  `_G.ForeverCommsVoice` / `_G.ForeverGuildComms` / `_G.ForeverGroupComms`. No other
  global is created except the `SLASH_*` / `SlashCmdList` entries, the
  `BINDING_HEADER_*` / `BINDING_NAME_*` labels, and named frames
  (`ForeverGuildCommsOptionsPanel`, `FGCAlertsFrame`, `FGCApprovalsFrame`,
  `FGCRequestFrame`, `ForeverGroupCommsPanel`, `ForeverGroupCommsQuests`). Voice creates
  no named frames.
- Public behavior goes on the namespace as methods: `function A:Thing() ... end`, called
  as `self:Thing()` or `A:Thing()`.
- File-local helpers stay `local function` and are not exposed (e.g. `cleanChat`,
  `inMajorCity`, `fillDefaults`, `MakeLabel`, `normalize`, `register`, `partyUnits`,
  `packetize`, `parseIDs`, `currentQuests`).
- State lives on the namespace and is declared up front with a safe initial value
  (`A.roster = {}`, `A.rosterReady = false`, `A.notifications, A.approvals = {}, {}`, …),
  so later files never index nil.
- **`A` means a different table in each package.** This is why the harnesses pass the
  addon name explicitly to `loadfile(...)(name, table)`.

## Cross-file calls must be guarded

Later modules are optional from `Core.lua`'s point of view. Call across files with an
existence check, as `A:Initialize` and the event handlers do:

```lua
if self.BuildUI then self:BuildUI() end
if A.OnGuildChat then A:OnGuildChat(...) end
if self.ScheduleQuestSync then self:ScheduleQuestSync(true) end
```

Two intra-package exceptions are intentional, both relying on the TOC's load-order
guarantee: `GroupPhrases.lua` calls `V:RegisterCatalog` at file scope, and
`Languages.lua` reads `A.defaults.templates` at file scope.

## Cross-package calls

- Reach the library through the **global**, never by capturing a local at load time in a
  feature file: `_G.ForeverCommsVoice`.
- **GuildComms** does this in exactly one place, `VoiceBridge.lua`, which hard-fails with
  `error("ForeverGuildComms requires ForeverCommsVoice")` if the global is missing. Its
  whole message layer is delegated, so a silent fallback would be worse than a load
  failure. Do not add a second cross-package call site elsewhere in the package — extend
  the bridge.
- **GroupComms** calls `V:Render("group", ...)` from `Core.lua` and `V:OpenOptions()` from
  `Options.lua`, both tolerating absence. Its `A:Render` falls back to the local
  `A.variants` English table when the global is missing **or** `db.useSharedVoice` is
  off — the same branch serves both, because the fallback *is* the user-facing opt-out.
- The library may probe a consumer, but only optionally and never for data:
  `V:SetOption` refreshes `_G.ForeverGuildComms`'s panel if present.
- **No version negotiation exists.** If you change `V:Render`'s options contract, update
  both consumers in the same change.

## Events

There is exactly **one** `CreateFrame("Frame")` event dispatcher per package. New events
get registered there and routed to a guarded module method. Do not create additional
event frames in feature files.

| Package | Dispatcher location | Events | Init trigger | Gate |
| --- | --- | --- | --- | --- |
| Voice | bottom of `Options.lua` | 1 | `ADDON_LOADED` for own name | sets `V.initialized` |
| GuildComms | bottom of `Core.lua` | 14 | `PLAYER_LOGIN` | `if not A.initialized then return end` |
| GroupComms | bottom of `Core.lua` | 10 | `ADDON_LOADED` for own name | `if not A.initialized then return end` |

## New feature checklist

### Adding to an existing package

1. Add the file to that package's TOC in the correct position (after `Core.lua`; in
   GuildComms, after `VoiceBridge.lua` if it needs rendered text).
2. Start it with `local _, A = ...` (or `V`) and declare its state on the namespace.
3. Add any default settings to `A.defaults` in that package's `Core.lua`. GuildComms'
   `fillDefaults` backfills recursively; GroupComms' `copyDefaults` plus the per-key type
   check in `Initialize` does the equivalent.
4. Register new events in that package's existing dispatcher and dispatch with a guard.
5. Expose the feature through that package's `Options.lua`, and if relevant a `/fgc`,
   `/fgp` or `/fcv` subcommand, a Titan menu entry (GuildComms), and a `Bindings.xml`
   action routed through `A:RunQuickAction` / `A:Quick`.
6. Add or extend the matching harness in that package's `tests/`, and add the file to
   `tests/syntax.lua` if the package has one.
7. Update that package's `README.md` (features, commands, limitations) and the root
   `README.md` if the bundle's shape changed.

### Adding wording to the shared library

1. New **data** goes in the matching data module — a language in `Languages.lua`, an
   accent in `Accents.lua` via `register`, group phrasing in `GroupPhrases.lua`, variant
   banks in `MessageVariants.lua`.
2. A new **message kind** must be added to every language in that scope's catalog, with
   English as the base. `tests/variations.lua` treats a missing accent entry as a failure,
   so fill them all.
3. A new **scope** is registered with `V:RegisterCatalog` from the data module, not
   hardcoded in `Render`.
4. Never add a send path, an event registration or a timer to the library.
5. Extend `ForeverCommsVoice/tests/integration.lua`, which is the only harness that loads
   all three packages.

### Adding a fourth package

Mirror the existing shape: flat folder named after the addon, `Core.lua` first with the
namespace and dispatcher, its own SavedVariables, its own `tests/` and `install/`, its own
`.pkgmeta`, a `## Dependencies: ForeverCommsVoice` line if it renders messages, and an
entry in the combined root installer's `$names` array.
