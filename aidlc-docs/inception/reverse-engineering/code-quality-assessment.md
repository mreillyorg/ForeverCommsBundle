# Code Quality Assessment

**Analysis target**: `ForeverCommsBundle` — ForeverCommsVoice 0.1.0-beta,
ForeverGroupComms 0.2.0-beta, ForeverGuildComms 0.5.0-beta
**Supersedes**: the single-package 0.4.3-beta pass of 2026-10-19T03:20:00Z
**Analysis date**: 2026-10-19T09:52:22Z

## Summary

This is the largest structural change in the project's history and the first one that is
not primarily about adding behaviour. 465 lines of language, accent, race and variant data
left ForeverGuildComms for a new shared addon, GuildComms picked up a 26-line adapter in
their place, and a second 978-line application addon arrived that reuses the extracted
library. Shipped Lua across the workspace went from 2,022 lines in one package to 3,395
across three.

**The extraction itself is well executed.** The library is genuinely independent: it
registers no chat or combat events, never sends anything, and owns the shared profile
behind a small API. `VoiceBridge.lua` is the right shape for the job — by aliasing the
old field names onto `A`, it let `Options.lua` and `TitanMenu.lua` through unmodified,
which is why a change of this size shows up as a 26-line new file rather than a diff
across nine. The two consumers made deliberately *opposite* dependency choices and both
are defensible: GuildComms hard-fails because its whole message layer is delegated;
GroupComms keeps an English fallback because that same fallback is the user-facing
`useSharedVoice` opt-out.

**The weak points are all at the seams, not in the code.** Three concerns dominate:

1. **Release packaging is now non-functional.** Three `package.yml` files and three
   `.pkgmeta` files are positioned for a repository whose root is an addon folder. The
   root has no `.github` directory, so no workflow will fire on a tag. On top of that, all
   three listen on an unprefixed `v*` while the packages sit at three different versions.
2. **The per-addon installers do not know about the new hard dependency.** Neither
   contains the string `ForeverCommsVoice`. A user who runs `Install-ForeverGuildComms`
   over an existing 0.4.3 install gets a GuildComms that will not load.
3. **Nine version strings are stale**, and verification coverage got *less* even
   though test lines grew — the new packages ship 1,838 lines of source behind two
   harnesses, and neither has a syntax check.

There is also one genuine, undocumented behaviour regression hidden in the extraction: the
Expressive accent strength lost its trailing-period-to-exclamation conversion. Details
below.

Finally, all eight steering files in `.kiro/steering/` still describe a single flat addon
called Forever Guild Comms. They are now the least accurate documentation in the
repository.

## Status of the Previous Recommendations

| # | 0.4.3 recommendation | Status |
| --- | --- | --- |
| 1 | Add a test job, or a runner script, that runs every harness and checks the version strings | **Not done, and now materially worse.** The suite grew to 13 harnesses across three packages, the version strings grew to roughly 25 locations of which 9 are stale, and the three workflows that would have hosted the job cannot execute at all. Fourth consecutive pass as the top item |
| 2 | Add the two new harnesses to `.kiro/steering/testing.md` | **Not done, and overtaken.** The document still says "nine offline Lua harnesses", still lists `Languages.lua`/`Accents.lua`/`RaceProfiles.lua` as GuildComms modules, and still names `Tabard.lua` as the module with no harness. It now needs a rewrite for three packages, not an addendum |
| 3 | Confirm the tabard fix in a live client | **Unknown.** No evidence either way. `Tabard.lua` is byte-unchanged and `tests/tabard_dedup.lua` still passes it as written |
| 4 | Make `OnDefault` preserve `outgoingMode` and voice settings, and remove its duplicated line | **Not done, and the blast radius grew.** See "New findings" #4 — `A.char.voice` is now the *same table object* as the shared profile, so GuildComms' Restore Defaults silently resets the voice settings GroupComms is using |
| 5 | Derive `tests/syntax.lua`'s module list from the TOC | **Not done.** The list was correctly hand-updated to the new 9 modules, which is exactly the maintenance cost the recommendation was about. Two new packages now have no syntax harness at all |
| 6 | Assert that `.pkgmeta` does not exclude `Bindings.xml` | **Not done.** No test references `.pkgmeta`. GroupComms now also ships a `Bindings.xml` with the same unasserted invariant |
| 7 | Key approval rows by a monotonic id | **Not done.** `row.entryIndex` still positional in GuildComms. GroupComms repeated the pattern — its suggestion rows close over a fixed loop index `i` |
| 8 | Drive `UpdateApprovalsUI` in a harness | **Not done.** No harness references `UpdateApprovalsUI`, `alertRows` or `approvalRows`. `variations.lua` drives `UI.lua`'s request path only |
| 9 | Note in the README that `randomizeMessages` changes existing wording on upgrade | **Not done** |
| 10 | Seed `math.random`, or comment that seeding is intentionally omitted | **Not done**, and there are now two unseeded shuffle bags in two packages |
| 11 | Test the approval backlog cap, a 3-4 byte `ChatLimit` case, and the `expressive` punctuation branch | **Not done.** `voice.lua` sets Expressive and asserts the flair prefix appears, but nothing asserts the punctuation branch — which is how the regression in "New findings" #1 went unnoticed |
| 12 | Add a floor between consecutive approvals | **Not done** in GuildComms. **Addressed by analogy in GroupComms**, whose `A:Send` enforces a 2-second floor on *every* post including an approved suggestion |
| 13 | Add `.luacheckrc` | **Not done.** No `.luacheckrc`, `selene.toml` or `stylua.toml` anywhere in the workspace |
| 14 | Clarify that Subtle applies no flair prefix | **Partly.** `V:Render` now carries a comment explaining the guild/group flair asymmetry, but the Settings label is unchanged |
| 15 | Make the review window's auto-show optional | **Not done** in GuildComms. GroupComms deliberately avoids the problem — `A:Stage` prints a notification and never force-shows a window |
| 16 | Comment that `pendingMessages` holds records | **Not done** |
| 17 | Note the profession-name fallback in README limitations | **Not done** |
| 18 | Move the README keybindings section below the byline | **Not done** |
| 19 | Extract `A:CanFillRole`, reuse `fillDefaults` in `OnDefault` | **Not done.** No `CanFillRole` exists |

**Zero of the nineteen were resolved this span**, and two were partly addressed by the new
addon choosing a better pattern rather than by a change to the old one. This is the first
pass in the project's history with no closures, which is unsurprising for a restructure
release — but items 1, 2 and 4 all got harder rather than staying still.

## Test Coverage

- **Overall**: Fair, down from Good. Thirteen harnesses, 995 lines, 29% of shipped Lua
  (previously 40% of a smaller codebase).
- **This rating comes from reading the harnesses, not running them.** `lua`, `lua5.1`,
  `luajit`, `texlua` and `lua54` were all probed; none is on PATH. **No harness was
  executed during this pass and none of the thirteen is reported as passing.** The
  project's own testing rule requires stating this plainly.

### Per-package coverage

| Package | Modules | Modules a harness loads | Harnesses | Test lines | Test % of source |
| --- | --- | --- | --- | --- | --- |
| ForeverCommsVoice | 7 | 6 of 7 | 1 | 64 | 7% |
| ForeverGuildComms | 9 | 9 of 9 | 11 | 826 | 53% |
| ForeverGroupComms | 6 | 3 of 6 | 1 | 105 | 11% |

**The project lost its "every module is covered" property**, which it had held for exactly
one pass. Four of twenty-two modules are now loaded by no harness:

| Uncovered module | Lines | Consequence |
| --- | --- | --- |
| `ForeverCommsVoice/Options.lua` | 76 | The `/fcv` panel, `V:SetOption`'s only UI caller, and the library's only event frame |
| `ForeverGroupComms/UI.lua` | 175 | Both windows, including the quest comparison rendering and the suggestion rows |
| `ForeverGroupComms/Options.lua` | 64 | All eight settings toggles and the `questSync` enable-triggers-sync side effect |
| `ForeverGroupComms/Broker.lua` | 27 | The LDB object |

**Neither new package has a syntax harness.** GuildComms' `tests/syntax.lua` compiles its
nine modules and nothing else, so a parse error in any of the thirteen Voice or GroupComms
files would reach a user. This is the cheapest gap on the list: the harness is six lines
and has no dependencies.

### What the new harnesses do well

**`ForeverCommsVoice/tests/integration.lua` is the most valuable 64 lines in the
repository.** It is the only test that loads all three addons, and it verifies exactly the
things the extraction put at risk:

- `MigrateLegacy` adopts a legacy guild profile once and sets the latch, and a second call
  with the same legacy table does **not** overwrite a subsequent shared edit. That is the
  migration's whole contract.
- Both render paths produce interpolated output from one shared profile, and both adapters
  are exercised against the real `ForeverGroupComms/Core.lua` and
  `ForeverGuildComms/Core.lua` + `VoiceBridge.lua` rather than against reimplementations.
- An item hyperlink survives a custom template, and a quest link survives a group `request`
  template.
- Role text is not transformed, and `group/skull` is asserted *equal* to the unaccented
  English string — encoding "combat directives stay understandable" as a test rather than a
  comment.
- `useSharedVoice = false` restores the exact original English wording, which is the
  documented opt-out contract.
- A language change invalidates an incompatible accent to `auto`, and an unknown race
  reduces the accent list to exactly the two safe entries.
- Non-repeating shuffle draws in both scopes.

It also, incidentally, guards the most dangerous latent coupling in the bundle. It copies
`B.defaults.templates` into `B.db.templates` and then asserts the rendered login greeting
is still translated — which only holds if GuildComms' default template strings are
byte-identical to Voice's `V.defaults.templates`. If those two duplicated tables ever
drift, every user's unmodified template would be treated as custom and translation would
silently stop for everyone. The invariant is covered, but **implicitly**; a reader would
not know that assertion is load-bearing.

**`ForeverGroupComms/tests/smoke.lua` is dense and well chosen for a single harness.** It
drives the full `Q`/`R` round trip through the real timer queue, then asserts the three
classifications separately — a peer's active quest shows as *shared*, a quest absent from a
peer's log with a completion reply shows as *missing*, and a non-addon party member shows
as *unknown*. It then bumps `questEpoch` and asserts the previously-missing quest reverts
to unknown, which is the precise guard against claiming someone lacks a quest based on a
stale reply. The reverse comparison is covered too, including that an already-completed
quest is suppressed.

### Remaining coverage gaps, ranked

1. **No CI runs any of this**, and the three workflows that might have cannot fire.
2. **No syntax harness for 13 of the 22 modules.**
3. **Four modules, 342 lines, loaded by nothing.**
4. **The GroupComms chat-safety rails are untested**: the 2-second `A:Send` floor, the
   `groupSerial` rejection in `A:Approve`, the `CanManageGroup` gates on ready checks and
   target marks, and `Notify`'s dedup.
5. **The `questSync` opt-out is untested.** `smoke.lua` runs with it on throughout; nothing
   asserts that turning it off stops `QueuePacket`, `FlushPackets` and `BroadcastQuests`.
6. **The outbox bounds are untested**: the 60-entry cap, the 1.15-second pacing, the
   12-chunk refusal, and `outboxToken` cancellation.
7. **`parseIDs` rejection cases are untested.** The validation is careful — oversize,
   leading/trailing/doubled commas, non-digits, out-of-range IDs — and none of it is
   asserted. For the only parser in the project that reads data from another player, this
   is the most consequential untested code in the bundle.
8. **The approvals and alerts window rendering** is still undriven *(carried)*.
9. **The 30-entry approval backlog cap** is still untested *(carried)*.
10. **`A:IsSelf` realm handling and the suspicious-roster-read guard** remain untested,
    carried since 0.1.0.
11. **`A:ChatLimit` is still tested only on a two-byte character** *(carried)*, and there
    are now three copies of that algorithm, two of them untested.
12. **The Expressive punctuation branch** *(carried)* — see finding #1.

## Code Quality Indicators

- **Linting**: none. Still no `.luacheckrc`. `.gitattributes` holds line endings
  repository-wide, though its header comment still reads "Line-ending policy for Forever
  Guild Comms".
- **Code Style**: consistent, and impressively so across a package boundary. All three
  packages use the same `local _, A = ...` opening, the same `function A:Name()` method
  style, the same up-front state declaration, the same guarded cross-module calls, the
  same single-dispatcher pattern, and the same `C_Timer.After` + latch idiom. A reader who
  knows one package can read the other two. Voice's `Options.lua` and GroupComms' modules
  are more compact than GuildComms' — fewer blank lines, more one-line bodies — but within
  the documented house style.
- **Documentation**: mixed, and this is the weakest indicator this pass.
  - *Good*: `ForeverCommsVoice/README.md` is a clean library README with a real API
    example and an honest migration section. `ForeverGroupComms/README.md` is unusually
    candid — it states plainly that quest sharing uses WoW's push API and shares with the
    group rather than an individual, that shareability and eligibility are different
    things, that a Questie-only party member is not synced, and that the archive has not
    been tested against a live server.
  - *Bad*: `ForeverGuildComms/README.md` has a 0.5.0 section appended to a document whose
    title, install instructions and "Build and tests" section all still say 0.4.3. The
    build section lists six harnesses; there are eleven. `PACKAGING.md` is worse — it
    states the version is 0.4.3 and its repository-layout block lists `Languages.lua`,
    `Accents.lua`, `RaceProfiles.lua` and `MessageVariants.lua` as files that must exist at
    the root, all four of which were moved out.
  - *Worst*: the root `README.md` is two lines. A monorepo with three interdependent
    packages, an installation order requirement and four installers has no bundle-level
    documentation at all.
  - *Comments* remain the project's strength and the new code upholds it. The best new
    ones: "15 bytes; WoW prefix limit is 16"; "QUEST_LOG_UPDATE also fires for kill counts:
    never resend unchanged logs on every objective tick"; "A lack of READY_CHECK_CONFIRM is
    not proof the member clicked Not ready"; "Only accept a completion reply to our most
    recently advertised log"; "Preserve clicks only when the exact roster is stable; no old
    group sends"; and "Avoid repeating a racial catchphrase already present in a curated
    party template". Each explains a decision, not a line.
- **Error handling**: good, and the new code is the most defensive in the project.
  `pcall` wraps every protected call in GroupComms — the ready check, the target mark, the
  addon send, the prefix registration, four separate `C_QuestLog` calls and the quest push.
  Every quest-log read supports both the modern and legacy API. `parseIDs` validates
  format, length, range and integrality before trusting a single byte from another player.
- **Global hygiene**: clean. Three addon globals, three `SLASH_*` pairs, the binding label
  globals, and named frames. No `getglobal`, no `loadstring` in shipped code.
- **Control flow**: good. `A:ScanRoster` is the densest new function — roster read,
  identity diff, serial bump, three message decisions and three private-alert decisions in
  one body — but each block is short and guarded. `V:Render` is the one function that is
  genuinely hard to follow; see finding #2.

## Technical Debt

### New findings

#### 1. Expressive accent strength silently lost its punctuation conversion
**Severity: low behaviour regression, undocumented, untested.**

The pre-extraction `A:VoiceText` ended an Expressive message like this:

```lua
text = accent.flair .. text
if text:sub(-1) == "!" then text = text .. "!"
elseif text:sub(-1) == "." then text = text:sub(1, -2) .. "!" end
```

`V:Render` kept only the first branch:

```lua
if voice.accentStrength == "expressive" and template:sub(-1)=="!" then template=template.."!" end
```

The period-to-exclamation conversion is gone. It affected every accent whose templates end
in a full stop — `nightelf`, `tauren`, `forsaken`, `bloodelf`, `draenei` — so on those
voices Expressive is now indistinguishable from Moderate. The old code still exists,
verbatim, in the now-dead `V:VoiceText`, which is presumably how it was lost: the behaviour
was reimplemented in `Render` rather than moved. Nothing asserts it, which is carried
recommendation #11.

#### 2. `V:Render` carries the complexity the extraction was meant to remove
**Severity: medium maintainability.**

`Render` is 55 lines handling two scopes with different accent semantics, two variant bank
shapes, a custom-template short circuit, a preview flag, a randomize flag and a flair rule
with a compound condition relying on `and`/`or` precedence:

```lua
if accent and accent.flair and (scope == "guild" and kind ~= "help"
    or scope == "group" and (kind == "greet" or kind == "welcome" or kind == "level")) then
```

That parses correctly, and a three-line comment explains the intent, but it is the one
place in the bundle where the comment is doing load-bearing work for the reader. Two
scope-specific resolver functions behind a thin `Render` would read better and would make
finding #1 the kind of thing a diff shows.

#### 3. Two shuffle-bag implementations of the same algorithm
**Severity: low duplication.**

`V:Pick` in `Core.lua` and `V:ChooseMessageTemplate` in `MessageVariants.lua` implement
identical logic — Fisher-Yates, position cursor, count-change invalidation, cross-bag
`last` guard — differing only in how they build the candidate list and compute the
signature. Both write into the same `V.messageVariantBags` table using **different
signature formats**: `Pick` uses `scope:kind:language:accent` and `ChooseMessageTemplate`
uses `kind:language:accent`. They cannot currently collide, because the only caller of
`ChooseMessageTemplate` is `VoiceBridge`'s forwarder, which no GuildComms code path
reaches now that `VoiceText` routes through `Render`. So the second implementation is
reachable only by a consumer calling `A:ChooseMessageTemplate` directly — which nothing
does. It is dead weight with a namespace-collision hazard attached.

#### 4. GuildComms' Restore Defaults now resets the *shared* voice profile
**Severity: medium, and a strict escalation of carried item #4.**

`A:Initialize` assigns `self.char.voice = voiceEngine:MigrateLegacy(self.char.voice)`, and
`MigrateLegacy` returns `ForeverCommsVoiceCharDB.voice` itself. `ForeverGuildCommsCharDB.voice`
and `ForeverCommsVoiceCharDB.voice` are therefore **the same table object** at runtime.
Consequences:

- `panel.OnDefault` does `for key, value in pairs(A.voiceDefaults) do A.char.voice[key] = value end`.
  Clicking Restore Defaults on the GuildComms Settings page now resets the language and
  accent that GroupComms is using, with no prompt. It also bypasses `V:SetOption`, so
  Voice's own panel is not refreshed and will display stale values until reopened.
- `A:SetVoiceOption` writes the shared table directly for the same reason. It does validate
  and it does call `V:RefreshOptions()`, so this one is correct — but it means the shared
  profile now has **two writers with two independently implemented validators**,
  `V:ValidateOption` and the `if key ==` ladder in `A:SetVoiceOption`. They agree today.
  Nothing keeps them agreeing.
- The client serializes each SavedVariables file separately, so the shared reference is
  written into *both* files on logout and becomes two tables again on load.
  `migratedFromGuild` means the GuildComms copy is then ignored forever, so behaviour
  converges — but a stale duplicate of the voice settings is persisted into
  `ForeverGuildCommsCharDB` indefinitely and never cleaned up.

#### 5. Release packaging is broken by the restructure
**Severity: high, and the reason this matters before the first commit.**

- Three `.github/workflows/package.yml` files live in package subdirectories. GitHub
  Actions reads workflows only from `.github/workflows` at the repository root, and the
  root has no `.github` directory. **No workflow will run on a tag push.**
- The three `.pkgmeta` files are likewise positioned for a checkout whose root is an addon
  folder. GuildComms' even says so in a comment: "Place this file at the GitHub repository
  root, next to ForeverGuildComms.toc".
- All three workflows trigger on `v*`, and the packages are at 0.1.0, 0.2.0 and 0.5.0. Even
  relocated, one unprefixed tag namespace cannot express three product versions.
- `PACKAGING.md` documents the old single-addon-at-root layout as a requirement, so the
  only packaging documentation in the repository now actively describes the wrong thing.
- The root `.gitignore` is a generic Lua template. It does not ignore `.release/`, which the
  BigWigs packager writes, so a local `release.sh -d` run would show up as untracked
  output. GuildComms' own `.gitignore` does ignore it, for its subtree only.

#### 6. The per-addon installers do not know about the hard dependency
**Severity: high user-facing.**

`Install-ForeverGuildComms.ps1` and `Install-ForeverGroupComms.ps1` contain no reference to
`ForeverCommsVoice`. Each parses only its own TOC and copies only the files listed there
plus `Bindings.xml` and, for GuildComms, `Media\Icon.tga`. Neither checks whether the
dependency is present, warns, or offers to install it. `ForeverGuildComms/INSTALL-README.txt`
and the README's numbered install steps are both unchanged and do not mention it.

The failure is concrete: an existing 0.4.3 user who updates with the familiar installer
gets GuildComms 0.5.0 without Voice, and the client refuses to load it. The mitigations
that *do* exist — the combined root installer, Voice's own `INSTALL-README.txt` advising
"Install ForeverCommsVoice before ForeverGuildComms / ForeverGroupComms", and the README's
appended 0.5.0 section — all sit on paths a returning user is unlikely to take.

#### 7. Nine stale version strings across three packages
**Severity: medium.**

| Package | TOC | Core.lua | README | PACKAGING | installer `.cmd` | installer `.ps1` | INSTALL-README |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Voice | 0.1.0 | 0.1.0 | 0.1.0 | n/a | 0.1.0 | 0.1.0 | — |
| GroupComms | 0.2.0 | 0.2.0 | 0.2.0 | n/a | **0.1.0** | **0.1.0** | **0.1.0** |
| GuildComms | 0.5.0 | 0.5.0 | **0.4.3** | **0.4.3** | **0.4.2** | **0.4.3** | **0.4.3** |

Voice is internally consistent. GroupComms' installer trio was never bumped from 0.1.0.
GuildComms has five stale locations, and its `.cmd` was already a release behind before
this change. The steering rule says three places move together; there are now seven per
package, and nothing checks them.

#### 8. Steering is now the least accurate documentation in the repository
**Severity: medium, affects future work on this project.**

All eight files in `.kiro/steering/` describe a single flat addon:

- `structure.md` gives a seven-row module table for `ForeverGuildComms` and states
  "Flat addon folder, no subdirectories for source" and "`tests/smoke.lua` is an offline
  harness" — there are now three packages, 22 modules and 13 harnesses.
- `testing.md` says "nine offline Lua harnesses", lists `Languages.lua`/`Accents.lua`/
  `RaceProfiles.lua` as GuildComms modules, and names `Tabard.lua` as the one module no
  harness loads. All three statements are now wrong.
- `release-packaging.md` describes one TOC, one set of SavedVariables and "three places"
  for the version.
- `product.md` lists "No addon-to-addon comms (`C_ChatInfo.SendAddonMessage`) unless the
  user asks for it" as an unscoped non-goal. GroupComms' quest sync is exactly that, as a
  headline feature. The constraint is still correct *for GuildComms* and the rule simply
  predates the second addon, but as written it reads as a violation.
- `guild-chat-safety.md` and `ui-frames.md` are GuildComms-specific and have no GroupComms
  equivalent, even though GroupComms now writes to a shared channel and builds frames.

#### 9. English group phrases are duplicated across the package boundary
**Severity: low, deliberate, untested.**

`ForeverGroupComms/Core.lua`'s `A.variants` and `ForeverCommsVoice/GroupPhrases.lua`'s
`groupTemplates.en` hold the same 13 phrase lists, verbatim. The duplication is the
mechanism behind `useSharedVoice`, so it is intentional. But `integration.lua` asserts the
opt-out restores *one specific string* (`"Hello everyone!"`), not that the two tables
match, so the remaining 12 kinds can drift silently in either direction.

#### 10. Dead code left behind by the extraction
**Severity: low.**

- `V:VoiceText` in `RaceProfiles.lua` (~40 lines) reads `self.db`, which the library never
  assigns, so it returns `""` immediately. It is the pre-extraction GuildComms method moved
  wholesale. It is also where the lost Expressive punctuation logic still lives.
- `A:CommsText`'s fallback branch, `return self:Format(self.db.templates[kind], vars)`, is
  unreachable in a real client now that `VoiceText` is guaranteed by the hard dependency.
  It remains useful to two harnesses, which is a reasonable justification, but the comment
  above it still describes "optional stripped-down installs" that can no longer exist.
- `V:ChooseMessageTemplate` is reachable only through a forwarder nothing calls — see
  finding #3.

#### 11. Smaller observations

- **`GroupComms` initializes on `ADDON_LOADED`, not `PLAYER_LOGIN`.** `A:Initialize` calls
  `GetUnitName("player", true)` at that point, which is not reliably populated that early.
  The code handles an empty result with a fallback and `ScanRoster` re-derives `playerKey`
  on every call, so it self-heals — but the first `ScanRoster(true)` is `silent`, so no
  message can be mis-sent. Benign, worth a comment.
- **GroupComms' suggestion rows close over a fixed index.** `A:Approve(i)` and the Dismiss
  handler both use the loop variable `i`, repeating the positional-binding pattern that is
  carried recommendation #7.
- **`A:SameGroup` is defined and never called.**
- **GroupComms ships no icon.** `Broker.lua` uses `INV_Misc_QuestionMark` and the TOC has no
  `IconTexture`, while GuildComms has a custom emblem. Cosmetic inconsistency in a bundle.
- **GroupComms' `README.md` mentions `CF_API_KEY`** while GuildComms' workflow uses
  `CF_API_TOKEN`. The two workflow files genuinely differ in env var names.
- **The combined root installer copies whole folders recursively**, so `tests/`,
  `install/`, `.github/` and the READMEs all land in `AddOns/`. The per-addon installers
  deliberately copy only loadable files, and GuildComms' README advertises that precision.
  The combined path quietly abandons it. Harmless to the client, inconsistent with the
  documented behaviour.
- **`A.messageVariantBags` remains the only unbounded structure** *(carried)*, now shared
  by two consumers and two implementations.
- **`math.random` is still unseeded** in both bags *(carried)*.

### Carried forward unchanged

Every item in the 0.4.3 "carried forward" list still stands: `OnDefault`'s silent resets,
shallow copy and duplicated `UpdateRequestPreview` line; positional approval-row binding;
no rate limit between approvals; `ShowApprovals` firing on every staged message; the
unasserted `.pkgmeta`/`Bindings.xml` invariant; `A.GetActivityType` as a dot-called
closure; duplicated role-availability logic in `A:Initialize` and `BuildRequestUI`;
`pendingMessages` holding records without a comment; the undocumented profession-name
fallback; Subtle's absent flair prefix; no `.luacheckrc`; and the orphaned README byline.

## Patterns and Anti-patterns

### Good Patterns

New this span:

- **A library extraction that leaves the consumer unchanged.** Aliasing the moved data
  tables onto the consumer's namespace meant 285 lines of `Options.lua` and 115 of
  `TitanMenu.lua` needed no edits. The adapter absorbed the whole change.
- **A library with no event registrations and no send path.** The clearest possible
  statement of the boundary: Voice decides *what* a message says and nothing about when or
  whether it is delivered.
- **Two consumers, two deliberate dependency strengths**, each matching what the consumer
  would lose. Hard-fail where the whole feature is delegated, soft fallback where the
  fallback doubles as a user-facing opt-out.
- **A scoped catalog registry.** One render pipeline serving guild and party messages,
  registered by the data module rather than hardcoded in the engine.
- **Serial and epoch invalidation of deferred work, applied consistently.** Five
  independent counters — `groupSerial`, `rosterRequest`, `syncSeq`, `outboxToken`,
  `questEpoch` — each guarding a specific class of stale action. The `questEpoch` rule is
  the sharpest: a completion reply is accepted only for the currently advertised log, so a
  late reply can never produce a false "this player is missing the quest".
- **Minimum disclosure in a peer protocol.** Only active quest IDs are broadcast; no
  titles, no objectives, no history. A completion answer covers only the IDs the asker
  already revealed, so the protocol never volunteers what it was not asked.
- **Validating peer input before trusting any of it.** `parseIDs` and the header checks in
  `OnAddonMessage` apply eleven distinct validations — prefix, grouping, roster membership,
  channel whitelist, pattern, protocol, integrality, ranges, `part <= total`, CSV shape,
  epoch rule — before a single ID is stored.
- **Signature suppression on a chatty event.** `QUEST_LOG_UPDATE` fires on kill counts;
  broadcasting only when the sorted ID list actually changed, with a 240-second
  rebroadcast window, turns a potential packet storm into near-silence.
- **A paced outbox.** One addon message per 1.15 seconds, capped at 60 queued, with a
  12-chunk refusal that reports honestly rather than truncating.
- **Honest reporting of what cannot be known.** The ready-check tally labels unconfirmed
  members as unconfirmed and says so in the message text; the quest UI distinguishes
  "missing" from "unknown" and explains the difference on the panel.
- **Refusing to infer.** GroupComms reads *assigned* roles and never guesses a spec, never
  changes a role, and says so in the Settings hint.
- **Quiet defaults for anything that posts.** `autoGreeting` and `autoLevel` both default
  to `false`, so a fresh install stages everything for a click.
- **A floor on every send, not just automatic ones.** GroupComms' `A:Send` applies its
  2-second gap to approved suggestions too — the gap GuildComms still has.
- **Suppressing a doubled catchphrase.** `V:Render` checks whether a curated group accent
  template already opens with the flair before prepending it, avoiding "By the forge! By
  the forge!".
- **Restoring selection state around a mutating API.** `A:ShareQuest` records the selected
  quest, selects the target, pushes, then restores — so sharing does not leave the player's
  quest log on a different entry.

Carried forward intact: the single event dispatcher, `A:CanUse` as a universal gate,
`QueueGuild` as the only automatic send path with `SendGuild` as the only call site,
baseline-before-diffing, GUID-first self-exclusion, pattern-escaped localized globals,
debounce-with-latch, bounded caches with two sweep triggers, clock-regression guards,
fingerprinted draft caching, the non-consuming preview path, feature detection at every
call site, and tests that encode the bug rather than only the fix.

### Anti-patterns

- **Automated release with no automated verification**, now compounded by **automated
  release that cannot run at all**.
- **Build and packaging configuration left at the old repository layout** after the layout
  changed, with the documentation describing the old layout as a requirement.
- **A hard dependency introduced without updating the installation path that creates it.**
- **Version strings duplicated across seven locations per package with no check.**
- **Steering and documentation describing a structure that no longer exists.**
- **Behaviour reimplemented rather than moved during an extraction**, dropping a branch
  that no test covered.
- **Two implementations of one algorithm sharing one state table under two key formats.**
- **A shared mutable table with two writers and two independent validators.**
- **A generic defaults handler resetting another addon's settings.**
- **Positional index binding between a UI row and a mutable list**, now in two packages.
- **Verbatim data duplication across a package boundary** with only a single-string
  assertion guarding it.
- **Dead code retained after an extraction**, including the only copy of a behaviour that
  was supposed to survive it.

## Security Posture

Still sound overall, but the surface genuinely widened for the first time, and that
deserves a clear statement.

### What did not change
No network surface, no HTTP, no file I/O outside SavedVariables, no credential handling,
no `loadstring` in shipped code, no vendored libraries, no taint-risking string execution.
All gear, invite, role, targeting and quest-acceptance actions remain in the player's
hands. GuildComms still has no addon-to-addon messaging and still reads only
`CHAT_MSG_GUILD`.

### What is new
**GroupComms accepts data from other players.** `A:OnAddonMessage` is the first inbound
untrusted-data path in the project. The handling is careful:

| Control | Implementation |
| --- | --- |
| Source restriction | Sender must not be self **and** must be in the current roster. An unrelated whisper from a stranger cannot inject a row |
| Channel restriction | `PARTY`, `RAID`, `INSTANCE_CHAT` or `WHISPER` only |
| Format restriction | Fixed six-field pipe pattern; protocol string must equal `"1"` |
| Numeric hardening | Every field bounded and checked for integrality, so `1e9` or `1.5` is rejected |
| Payload restriction | `parseIDs` rejects anything that is not digits and single commas, caps at 230 bytes, and bounds each ID to 1..99999999 |
| Memory bounds | Reassembly state expires after 60 seconds and is swept; peers expire after 300; the outbox caps at 60 |
| Replay and staleness | A `Q` older than the stored peer epoch is dropped; an `R` is accepted only for the current local epoch |
| Interpretation | IDs are only ever compared numerically and passed to `C_QuestLog` lookups. Nothing from the wire is concatenated into a pattern, executed, or rendered as a format string |

The one value from a peer that reaches the UI is a **quest title**, and it is obtained
locally from `C_QuestLog.GetTitleForQuestID` rather than taken from the packet. Peer
*names* reach the UI, but they come from the local roster scan, not from the message body.

**Residual observations**, none of them a defect:
- `questSync` defaults to `true`, so the exchange is on after a fresh install. It is
  disclosed in the Settings hint and the README, and the data disclosed is minimal, but it
  is the one default in the bundle that turns on outbound traffic without a click.
- A malicious party member could advertise fabricated quest IDs. The worst outcome is a
  misleading row in the comparison window and, if the player clicks Ask, a chat message
  naming a quest. There is no action taken on the data.
- The `pairs`-with-`nil`-assignment pattern in the three sweep loops is explicitly
  permitted in Lua for the current key, so it is correct rather than accidentally working.

## Recommendations

Ordered by value relative to effort. *(carried)* marks items from the 0.4.3 list.

### Before the first commit

| # | Recommendation | Effort | Rationale |
| --- | --- | --- | --- |
| 1 | Move packaging to the repository root: one `.github/workflows/` directory with a job per package, each with its own `--pkgmeta` path, keyed off a prefixed tag such as `voice/v*`, `guild/v*`, `group/v*` | Medium | Tag-driven packaging is currently inert for all three packages. Fixing it before history exists avoids rewriting tags later |
| 2 | Make the per-addon installers detect, warn about, and ideally install `ForeverCommsVoice` | Low | **The highest user-facing risk in the bundle.** An existing GuildComms user following the familiar install path ends up with an addon that will not load |
| 3 | Add a test job that runs all 13 harnesses and checks every version string *(carried, was #1)* | Low | Fourth consecutive pass as the top item, and it would catch recommendations 4, 5 and 6 automatically. The harnesses are pure Lua with no dependencies |
| 4 | Fix the nine stale version strings, and bump GuildComms' `README.md` title and `PACKAGING.md` to 0.5.0 | Low | `PACKAGING.md` additionally lists four files that no longer exist in that package |
| 5 | Add `tests/syntax.lua` to ForeverCommsVoice and ForeverGroupComms, deriving the module list from the TOC *(extends carried #5)* | Low | 13 of 22 modules currently have no compile check. Six lines each, no dependencies |
| 6 | Write a real root `README.md`: the three packages, the dependency, the install order, and the four installers | Low | A monorepo with an installation-order requirement and no bundle documentation |
| 7 | Add `.release/` to the root `.gitignore` | Trivial | The packager's local output directory is currently untracked noise |

### Correctness

| # | Recommendation | Effort | Rationale |
| --- | --- | --- | --- |
| 8 | Restore the Expressive trailing-period-to-exclamation conversion in `V:Render`, and assert it *(relates to carried #11)* | Trivial | An undocumented behaviour regression affecting five accents. The original code is still visible in `V:VoiceText` |
| 9 | Make GuildComms' `OnDefault` leave the shared voice profile alone, or route through `V:SetOption` with a confirmation *(carried, was #4)* | Low | Restore Defaults currently resets another addon's live settings silently and leaves Voice's panel stale |
| 10 | Give the shared profile one writer. Have `A:SetVoiceOption` delegate to `V:SetOption` and delete its duplicate validator | Low | Two independent validators for one table is a divergence waiting to happen |
| 11 | Test the GroupComms chat-safety rails: the 2-second `Send` floor, `groupSerial` rejection in `Approve`, the `CanManageGroup` gates, and `Notify` dedup | Medium | The safety model of a chat-writing addon is currently unasserted |
| 12 | Test `parseIDs` and the `OnAddonMessage` header rejections | Low | The only parser reading data from another player has no negative tests, and negative assertions are the valuable ones here |
| 13 | Test the `questSync` opt-out and the outbox bounds | Low | An opt-out that is never asserted is an opt-out that can silently stop working |

### Maintainability

| # | Recommendation | Effort | Rationale |
| --- | --- | --- | --- |
| 14 | Rewrite `.kiro/steering/` for the bundle: scope `structure.md`, `release-packaging.md`, `guild-chat-safety.md` and `ui-frames.md` per package; rewrite `testing.md` for 13 harnesses across three packages; scope `product.md`'s addon-comms non-goal to GuildComms and add GroupComms' opt-in protocol as a stated capability *(extends carried #2)* | Medium | Steering is now the least accurate documentation in the repository, and it is what guides future work |
| 15 | Delete `V:VoiceText` and `V:ChooseMessageTemplate` plus its forwarder, after recommendation 8 rescues the punctuation logic | Low | Removes ~55 lines of unreachable code and a bag-signature collision hazard |
| 16 | Split `V:Render` into `renderGuild` and `renderGroup` behind a thin dispatcher | Medium | The one function in the bundle whose correctness depends on operator precedence and a comment |
| 17 | Assert that `GroupComms.variants` and `Voice.groupTemplates.en` match, and that `GuildComms.defaults.templates` matches `Voice.defaults.templates` | Low | Both are load-bearing duplications. The second is currently guarded only implicitly, as a side effect of one assertion in `integration.lua` |
| 18 | Add harnesses for `ForeverGroupComms/UI.lua` and `Options.lua`, reusing GuildComms' synthetic widget layer | Medium | 239 lines loaded by nothing, including the `questSync` enable side effect |
| 19 | Add `.luacheckrc` at the root covering all three packages *(carried, was #13)* | Low | Would catch the duplicated `UpdateRequestPreview` line, the unused `A:SameGroup`, and accidental globals across 22 files |
| 20 | Key approval and suggestion rows by a monotonic id in both packages *(carried, was #7)* | Low | Same fragile invariant, now in two places, with the same failure mode: sending the wrong message |
| 21 | Drive `UpdateApprovalsUI` in a harness *(carried, was #8)* | Medium | Part of the authorization path for public messages, and recommendation 20 would be safer behind a test |
| 22 | Give GroupComms its own broker icon and `IconTexture` | Low | Cosmetic, but the bundle currently looks half-finished on the Titan bar |
| 23 | Make the combined root installer copy only loadable files, matching the per-addon installers | Low | It currently ships `tests/`, `install/` and `.github/` into `AddOns/`, contradicting the documented behaviour |
| 24 | Confirm the tabard fix in a live client *(carried, was #3)* | Low | Still never observed against a real event ordering |
| 25 | Remaining carried items: seed `math.random` or comment why not; note that `randomizeMessages` changes existing wording on upgrade; add a floor between consecutive approvals; make the review window's auto-show optional; clarify that Subtle applies no flair; comment that `pendingMessages` holds records; note the profession-name fallback in README limitations; move the README keybindings section below the byline; extract `A:CanFillRole` and reuse `fillDefaults` in `OnDefault`; assert `.pkgmeta` retains `Bindings.xml` — now for two packages; test the approval backlog cap and a 3-4 byte `ChatLimit` case | Trivial to Low | Unchanged from the 0.4.3 list. None blocking |

### Assessment

**The engineering is good; the plumbing is behind.** The extraction is the kind of change
that usually leaves a trail of broken call sites and duplicated state, and this one did
not: the library is clean, the adapter is small, the second consumer genuinely reuses the
work, and the new addon's safety model is the most careful in the project — a minimal-
disclosure protocol with eleven inbound validations and five staleness counters is better
work than the feature strictly required.

What has not kept up is everything around the code. Packaging, installers, version
strings, README titles, steering and test distribution were all correct for a single flat
addon and none of them was revisited. Items 1, 2 and 3 are the ones that matter before this
becomes committed history; item 8 is the only functional regression and it is a two-line
fix. The recurring top recommendation — run the tests automatically — would have caught
four of the seven pre-commit items on its own, and it has now been outstanding for four
passes while the suite it would run tripled in scope.
