---
inclusion: auto
name: testing
description: How to run the thirteen offline Lua harnesses across the three Forever Comms packages, which modules they cover, and the in-game verification checklist. Use when running tests, adding tests, verifying addon behavior, or before releasing.
---

# Testing

Verification is a two-layer process: **thirteen offline Lua harnesses** spread across three
packages for logic, and a manual in-game pass for anything that needs a real client.

**There is no test framework and no test automation in CI.** `assert` from the standard
library is the entire mechanism: each harness dies on the first failure and prints a
`PASSED: ...` summary otherwise. The three `.github/workflows/package.yml` files only
*package* a release, and — because they sit in package subdirectories rather than at the
repository root — they currently do not run at all. Running the harnesses is a manual
step, so run them before tagging.

## Run the suite

Run each harness **from its own package root**. The GuildComms harnesses derive their base
path from `arg[0]`, GroupComms' takes the root as `arg[1]` with a `.` default, and Voice's
derives from `arg[0]` — but `ForeverGuildComms/tests/icon.lua` uses plain relative paths
and *must* have the package root as the working directory.

```powershell
# ForeverCommsVoice  (1 harness) - cwd: ForeverCommsVoice
lua5.1.exe tests\integration.lua

# ForeverGuildComms  (11 harnesses) - cwd: ForeverGuildComms
lua5.1.exe tests\syntax.lua
lua5.1.exe tests\smoke.lua
lua5.1.exe tests\verify.lua
lua5.1.exe tests\settings.lua
lua5.1.exe tests\timing.lua
lua5.1.exe tests\titanmenu.lua
lua5.1.exe tests\voice.lua
lua5.1.exe tests\variations.lua
lua5.1.exe tests\tabard_dedup.lua
lua5.1.exe tests\keybindings.lua
lua5.1.exe tests\icon.lua

# ForeverGroupComms  (1 harness) - cwd: ForeverGroupComms
lua5.1.exe tests\smoke.lua
```

### Harnesses cross package boundaries — run the whole suite

This is new since the voice extraction and it is the most important operational fact here:

- **Eight of the eleven GuildComms harnesses load the `ForeverCommsVoice` source**, by
  `os.getenv("FOREVER_VOICE_PATH")` or the relative fallback `../ForeverCommsVoice/`.
  They load six Voice modules, publish `_G.ForeverCommsVoice`, then load
  `VoiceBridge.lua`.
- **`ForeverCommsVoice/tests/integration.lua` loads all three packages**, reaching
  sideways into `../ForeverGroupComms/Core.lua` and `../ForeverGuildComms/Core.lua` +
  `VoiceBridge.lua`.

Therefore: a change to the library can break a consumer's suite, and the suite only works
in the bundle checkout layout. A package extracted and tested on its own will fail to
load. `FOREVER_VOICE_PATH` is the only override, and there is no equivalent for the two
sibling paths in Voice's harness. **Always run all thirteen, not just the package you
touched.**

## Offline harnesses

Thirteen files, none listed in a TOC and none shipped.

### ForeverCommsVoice

| Harness | Loads | What it locks down |
| --- | --- | --- |
| `integration.lua` | **all three packages**: Voice x6, GroupComms `Core`, GuildComms `Core` + `VoiceBridge` | The extraction's whole contract. `MigrateLegacy` adopts a legacy guild profile once and sets the latch, and a second call does **not** overwrite a later shared edit. Both render paths produce interpolated output from one shared profile, through the real adapters. An item hyperlink survives a custom guild template and a quest link survives a group `request`. Role text is not transformed. `group/skull` is asserted **equal** to the unaccented English string, encoding "combat directives stay understandable" as a test. `useSharedVoice = false` restores the exact original English wording. A language change invalidates an incompatible accent to `auto`. An unknown race reduces the accent list to exactly the two safe entries. Non-repeating shuffle draws in both scopes. **It also implicitly guards the duplicated default-template tables** — it copies GuildComms' defaults into `db.templates` and still expects a translated greeting, which only holds while both halves are byte-identical |

### ForeverGuildComms

| Harness | Loads | What it locks down |
| --- | --- | --- |
| `syntax.lua` | all 9 GuildComms modules, runs none | Every shipped file in **this package** compiles. Cheapest possible guard against shipping a parse error. The module list is hand-maintained and duplicates the TOC |
| `smoke.lua` | Voice x6, Guild `Core`, `VoiceBridge`, `Roster`, `Alerts` | The player's own level-up produces **no** message; another member's offline → online produces one greeting; another member's level increase while online produces one congratulation; the localized guild-join line produces one welcome and the player's own join does not; a craft request naming a cached recipe alerts, an LFG line alerts, and the player's own guild chat does not; only learned, non-disabled recipes enter the cache |
| `verify.lua` | Voice x6, Guild `Core`, `VoiceBridge` | The whole approval workflow against the **real** queue and backlog: Verify mode never auto-sends; dedup applies in Verify mode too; Send posts exactly one message; Dismiss never sends; **switching back to Automatic does not release staged messages**; **switching to Verify during the spacing delay captures an in-flight message**; a message cannot cross a guild boundary; `ClearApprovals` empties the backlog; Automatic still sends without a click; `SendChatMessage` is only ever called with `"GUILD"` |
| `settings.lua` | Guild `Core`, Voice x6, `VoiceBridge`, Guild `Options` | SavedVariables migration: a custom template survives, blank and whitespace-only templates are refilled from defaults, a missing template is filled, `outgoingMode` defaults to `automatic`. Plus the options widgets: two radios with Automatic preselected, four Use default buttons, and both radios switching the mode |
| `timing.lua` | Guild `Core`, Voice x6, `VoiceBridge` | The **exact** computed queue delay for successive sends, the per-member login cooldown in both directions, and `loginCooldown = 0` allowing repeat greetings |
| `titanmenu.lua` | Guild `Core`, Voice x6, `VoiceBridge`, `Options`, `TitanMenu`, `Broker` | The LibDataBroker data object and the entire nested menu tree, by faking both the frame API and the `MenuUtil` node API, then walking the generated tree and invoking its callbacks |
| `voice.lua` | Voice x6, Guild `Core`, `VoiceBridge` | Language selection and translation through the bridge; race filtering (a filtered-out accent cannot be set); an incompatible accent resets to `auto` when the language changes; **a customized template overrides translation and preserves item links**; localized role and activity labels; unknown races fall back to `auto`/`none` only; invalid values are rejected; UTF-8 truncation never splits a multibyte character |
| `variations.lua` | Voice x6, Guild `Core`, `VoiceBridge`, `UI` | Loops **every language** and every kind, drawing twice the bag size and asserting no repeat within a bank, no adjacent repeat, no unfilled placeholder, and that activity and level values survive. Then loops **all 29 accents** asserting each has variants for all four kinds — a missing entry is a failure, not a silent fallback. Then the non-consuming Settings preview, the custom-template override with a real hyperlink, the disabled setting, and the preview/send stability contract including that reopening the composer advances the wording |
| `tabard_dedup.lua` | Guild `Core`, `Tabard` — **the only GuildComms harness needing no Voice** | Reproduces the original login-ordering race: asserts the scheduled delay is 1.2s, fires it, confirms it initialises `wasInCity` *without* prompting, then asserts `CheckTabard(true)` still prompts. Continues through per-stay deduplication, city exit with the tabard on, re-entry without it, and the reverse ordering. Second half covers the dedup cache: retention across a cooldown increase, the 60-second sweep throttle, full drainage, re-admission after expiry, disposal of malformed and future-dated values, and the 300-second idle ticker |
| `keybindings.lua` | Guild `Core`, `Alerts`, plus the real `Bindings.xml` | Reads `Bindings.xml`, `load()`s each embedded handler, and executes the real binding code. Asserts the bindings are opt-in (**no `default=` attribute**), unique, and correctly categorised; that the actions open the intended windows; that the recipe rescan reports both outcomes; and that **no path sends a guild message**. Also covers the disabled-addon and pre-initialisation cases |
| `icon.lua` | nothing; reads files as text. **Requires cwd = package root** | The icon path stays consistent across the TOC `## IconTexture`, `Broker.lua`, `Options.lua` and the installer, and both textures exist at a plausible size |

### ForeverGroupComms

| Harness | Loads | What it locks down |
| --- | --- | --- |
| `smoke.lua` | GroupComms `Core`, `Roster`, `Quests`. Does **not** load Voice | Roster scan and role reading; `RoleSummary` naming and `RoleIssues` finding no problem in a valid party; a native ready check and a target mark reaching the stubbed APIs; a role check sending; a party member's level increase producing exactly one **staged suggestion** rather than a send. Then the full `Q`/`R` round trip through the real timer queue, asserting all three classifications separately — a peer's active quest shows as *shared*, a quest absent from a peer's log plus a completion reply shows as *missing*, and a non-addon member shows as *unknown*. Then bumps `questEpoch` and asserts the previously-missing quest reverts to *unknown*, which is the guard against a stale reply producing a false claim. Then the reverse comparison, including that an already-completed quest is suppressed, and that `RequestQuest` sends |

## Module coverage

**Four of the twenty-two shipped modules are loaded by no harness.** The project briefly
held full coverage before the restructure; closing these is the current priority.

| Package | Covered | Loaded but not driven | No harness loads it |
| --- | --- | --- | --- |
| Voice | `Core`, `Languages`, `Accents`, `RaceProfiles`, `MessageVariants`, `GroupPhrases` | — | **`Options.lua`** |
| GuildComms | `Core`, `VoiceBridge`, `Roster`, `Alerts`, `Tabard`, `Options`, `TitanMenu`, `Broker`, `Bindings.xml` | `UI.lua` — `variations.lua` drives the request path, but `UpdateAlertsUI` and `UpdateApprovalsUI` paging and row binding are untouched | — |
| GroupComms | `Core`, `Roster`, `Quests` | — | **`UI.lua`**, **`Options.lua`**, **`Broker.lua`** |

**Only GuildComms has a syntax harness**, so 13 of 22 modules have no compile check at
all. Adding `tests/syntax.lua` to Voice and GroupComms is six lines each with no
dependencies and is the cheapest coverage win available.

### Which modules are loadable offline

All of them. Frame-dependent modules are reachable by supplying a **synthetic widget
layer**: a metatable whose `__index` returns a real implementation for the handful of
methods the test cares about (`SetText`, `GetText`, `SetChecked`, `GetChecked`,
`SetScript`, `HasFocus`, `CreateFontString`) and a no-op for everything else, with
`CreateFrame` recording each widget so the test can find it afterwards by template name or
label text. GuildComms' `settings.lua` established the pattern and `titanmenu.lua` extends
it to the `MenuUtil` node API. Reuse it rather than inventing a second approach when
covering GroupComms' `UI.lua` and `Options.lua`.

### Known untested paths, ranked

1. Nothing in CI runs any of this, and the three packaging workflows cannot fire.
2. No syntax harness for Voice or GroupComms.
3. The four uncovered modules above.
4. **GroupComms' chat-safety rails**: the 2-second `A:Send` floor, the `groupSerial`
   rejection in `A:Approve`, the `CanManageGroup` gates on ready checks and target marks,
   and `A:Notify`'s dedup.
5. **The `questSync` opt-out.** `smoke.lua` runs with it on throughout; nothing asserts
   that turning it off stops `QueuePacket`, `FlushPackets` and `BroadcastQuests`.
6. **The outbox bounds**: the 60-entry cap, the 1.15-second pacing, the 12-chunk refusal,
   and `outboxToken` cancellation.
7. **`parseIDs` rejection cases.** The only parser reading another player's data has no
   negative tests — no oversize payload, no leading/trailing/doubled comma, no non-digit,
   no out-of-range ID.
8. GuildComms' approvals and alerts window rendering.
9. GuildComms' 30-entry approval backlog cap, including that it drops the oldest.
10. `A:IsSelf` realm handling, and the suspicious-roster-read guard.
11. The byte clamp on a three- or four-byte UTF-8 sequence. Three copies exist, two
    untested.
12. The Expressive punctuation branch. `voice.lua` sets Expressive and checks the flair
    prefix only, which is how a dropped branch there went unnoticed.
13. That the duplicated tables match: GroupComms' `variants` against
    `groupTemplates.en`, and GuildComms' `defaults.templates` against
    `V.defaults.templates`. The second is guarded only implicitly today.

## Interpreter

Use **Lua 5.1**, the version the WoW client embeds. LuaJIT 2.1 works too but is a
superset — it adds `ffi`, `bit`, `jit`, `table.new`, and `goto`, none of which exist in
game — so never let test code depend on those. Do not use Lua 5.4 (available as
`winget install DEVCOM.Lua`); its integer/float split and relocated `unpack` diverge from
the client. Some harness comments say `texlua`, which also works.

Getting 5.1.5 on Windows: no package manager carries it, so take the
[LuaBinaries](https://luabinaries.sourceforge.net/) `lua-5.1.5_Win64_bin.zip` from the
SourceForge *Tools Executables* folder for 5.1.5 and unzip it somewhere on PATH. Keep
`lua5.1.dll` and the bundled `Microsoft.VC80.CRT\` folder next to `lua5.1.exe`; the
executable is a vc8 build and will not start without them. The binary is named
`lua5.1.exe`, not `lua.exe`.

**No interpreter is currently installed on this machine** — `lua`, `lua5.1`, `luajit`,
`texlua` and `lua54` are all absent from PATH. If no interpreter is available, **say so
explicitly rather than reporting the suite as passing.** Reading a harness is not running
it.

## Adding tests

When changing roster diffing, chat parsing, either send path, the approval backlog, the
quest protocol, the voice layer, templates, settings validation, or the recipe scan,
extend the matching harness in the same style:

- **Put the test in the package that owns the behavior.** Cross-package behavior —
  migration, the render contract, the `useSharedVoice` opt-out — belongs in
  `ForeverCommsVoice/tests/integration.lua`.
- Stub only what the new path touches.
- Pass the addon name explicitly to `loadfile(...)(name, table)`. `A` means a different
  table in each package.
- When a harness needs the library, follow the existing preamble: resolve
  `FOREVER_VOICE_PATH` or `../ForeverCommsVoice/`, load the six Voice modules into one
  table, assign `_G.ForeverCommsVoice`, then load the consumer. If the test touches the
  shared profile, also wire `_G.ForeverCommsVoiceCharDB` as `variations.lua` does.
- Assert both the positive case **and** the "must not fire" case. Every existing harness
  does this, and for addons that write to shared channels the negative assertion is the
  valuable one.
- Where a timer is involved, capture the `C_Timer.After` callback into a list instead of
  running it, so the test fires it deliberately. Keep the `delay` argument if the timing
  itself matters — that is how `timing.lua` verifies the spacing arithmetic and how
  GroupComms' `smoke.lua` drains the quest outbox.
- For anything reading peer data, assert the **rejections**, not just the happy path.
- Prefer testing the real artifact over a reimplementation. `keybindings.lua` loads and
  executes the actual `Bindings.xml`; `icon.lua` reads the actual TOC and installer.
- Add any new module to that package's `tests/syntax.lua`.
- Keep the final `print` summary accurate.

## In-game verification

Enable Lua errors first: `/console scriptErrors 1` then `/reload`.

### Bundle and dependency

1. Install all three addons with `install\Install-ForeverComms.cmd`. Confirm all three
   appear in the AddOns list and that `/fgc`, `/fgp` and `/fcv` all respond.
2. Disable **ForeverCommsVoice** in the character select AddOns list and reload. Confirm
   the client refuses to load GuildComms and GroupComms rather than erroring at runtime.
   Re-enable it.
3. On the first login after upgrading from GuildComms 0.4.x, confirm the existing
   per-character language and accent appear in `/fcv`. Change them there, `/reload`, and
   confirm the change persisted and was not overwritten by the old guild setting.

### ForeverCommsVoice

4. In `/fcv`, pick a non-English language and confirm both GuildComms' Settings preview and
   GroupComms' quick actions use it. Toggle the race filter and confirm the accent list
   narrows. Try Subtle, Moderate and Expressive on an accent whose templates end in a full
   stop and confirm the three are actually distinguishable.
5. Turn off **Use ForeverCommsVoice for group messages** in GroupComms and confirm group
   quick actions revert to the original English wording while GuildComms is unaffected.

### ForeverGuildComms

6. Set **Verify with a click** while setting up, customize templates, then enable greetings
   one at a time.
7. Another member logs in → one greeting appears in the private review window. Nothing
   should post before you click Send. Your own login → nothing.
8. A member joins → one welcome in review. Try a **Use default** button in Settings.
9. Another member levels while online → one congratulation. Level your own character →
   **nothing sent**.
10. Switch back to **Automatic** and confirm future messages send without a click while
    *previously pending* messages still require approval or dismissal.
11. Adjust **Automatic message spacing** and **Login greeting cooldown** in Settings and
    again from the Titan menu presets; confirm both surfaces agree and that out-of-range
    typed values are clamped.
12. Open each profession, check `/fgc recipes`, then have a guildmate request a known
    output by name.
13. Have a member post `LFG Deadmines` or `LF healer for quest` → private alert with a
    working Whisper button.
14. `/fgc request`, check the preview, then Send; confirm the 20-second rate limit and that
    the sent text matches the preview exactly.
15. Enter and leave a capital city with and without the tabard, with exit reminders both
    off and on. Confirm one reminder per city stay, including right after login.
16. **Edit a template** and confirm your text is used verbatim, untranslated and
    un-accented, and that an item link in it survives intact.
17. Enable **Vary built-in message wording**, trigger several greetings, and confirm the
    wording rotates without repeating before the bank is exhausted.
18. **Key bindings**: assign all three under Options → Key Bindings → AddOns → Forever
    Guild Comms. Confirm no key is bound by default, that **Ask guild for help** opens the
    composer without sending, and that **Rescan open profession** reports honestly both
    with and without a profession window open. A client restart may be needed before the
    bindings appear.
19. **Restore Defaults** on the GuildComms Settings page: confirm what it does and does not
    reset, specifically `outgoingMode` and the shared `/fcv` profile.
20. `/fgc status` and a `/reload`, both in a guild and while guildless, to confirm nothing
    leaks from the baseline or a guild change.

### ForeverGroupComms

21. Join a party. Confirm a greeting appears as a **suggestion** rather than a send, and
    that clicking Send posts to `PARTY`. Enable `autoGreeting` and confirm the difference.
22. Have a member join mid-run → one welcome suggestion. Leave and rejoin a *different*
    party and confirm the old suggestion is discarded rather than sendable.
23. Have a member level while grouped → one congratulation suggestion. Level yourself →
    **nothing**.
24. `/fgp roles` sends a role check. With an unassigned role, confirm the **private** role
    alert appears and that it never changes anyone's role.
25. `/fgp ready` as leader, then as a non-leader → confirm the rank refusal. Confirm the
    response tally is private and labels non-responders as *unconfirmed*, not "not ready".
26. `/fgp skull` and `/fgp moon` on a hostile target as leader, then with no target, with a
    friendly target, and as a non-leader → four distinct honest messages.
27. Fire several coordination calls in quick succession and confirm the 2-second floor.
28. `/fgp quests` with another ForeverGroupComms user: confirm *missing*, *has*, *completed*
    and *unknown* all appear correctly, and that a member **without** the addon shows as
    unknown rather than missing. Switch the view and confirm the reverse comparison.
29. Click **Share** on a shareable quest and confirm the game's own dialog appears, that
    your quest log selection is restored afterwards, and that a non-shareable quest is
    refused with the game's reasoning.
30. Turn **questSync** off and confirm no further addon traffic and that rows degrade to
    unknown. Turn it back on and confirm a resync.
31. Raid-only: confirm `INSTANCE_CHAT` is used inside an instance group and that raid
    assistants can mark and ready-check.

### Both indicators

32. With Titan Panel installed, verify left / shift-left / right click on both brokers and
    walk GuildComms' nested menu. Then confirm all three addons still load with Titan
    disabled.

Record anything unverified in that package's README limitations section. The READMEs are
part of the deliverable, not an afterthought.

## Before tagging a release

The tag triggers packaging, not testing. Do this first:

1. **All thirteen harnesses run and print `PASSED`** — all of them, not just the package
   being released, because the suite spans package boundaries.
2. All seven version-string locations match for that package, plus `PACKAGING.md` for
   GuildComms. See `release-packaging.md`.
3. Every shipped `.lua` file is in its TOC in the right load order, and `Bindings.xml` is
   **not** (the client auto-loads it from the addon root).
4. `.pkgmeta` still does not exclude `Bindings.xml` or `Media/Icon.tga`.
5. `## Dependencies` and `## OptionalDeps` are still correct, and any change to the
   `V:Render` contract has been applied to all three packages.
6. READMEs reflect the code, and the root `README.md` still describes the bundle.
7. The in-game checklist has been walked, or the gaps are written down as limitations.
