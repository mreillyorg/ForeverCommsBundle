# Code Quality Assessment

**Analysis target**: `ForeverCommsBundle` — ForeverCommsVoice 0.1.1-beta,
ForeverGroupComms 0.2.1-beta, ForeverGuildComms 0.5.1-beta
**Supersedes**: the 0.5.0/0.2.0/0.1.0 pass of 2026-10-19T09:52:22Z (commit `76ca527`)
**Analysis date**: 2026-10-19T11:30:00Z

## Summary

This is a remediation release and a strong one. The previous pass found that the library
extraction itself was well executed while everything around it — packaging, installers,
version strings, documentation — had been left at the old single-addon layout. This span
addressed that, and did it with more rigour than the recommendations asked for.

**Seven of the previous pass's seven pre-commit and correctness items are resolved or
substantially resolved, and three of them were solved better than recommended:**

- Packaging was not relocated; it was **replaced**. A self-contained Python builder
  (`tools/package.py`) and a PowerShell equivalent (`package.ps1`) now produce four
  archives with no external packager, no network and no secrets, driven by a real
  root-level workflow. The recommendation was to move three BigWigs workflows to the root
  and prefix tags per package; this design makes one unprefixed `v*` tag *correct* again
  by releasing the suite as a unit.
- The installers were not just taught to *detect* the dependency. The three per-addon
  installers became 13-line shims over one shared installer that **auto-prepends
  ForeverCommsVoice and installs in dependency order**, so the failure mode is now
  impossible rather than merely reported.
- Version drift was not only fixed, it was **reduced at the source**. The `.ps1` banner
  lines and `INSTALL-README.txt` version headings were removed entirely, taking the
  per-package drift surface from seven locations to four, and `tools/verify_package.py`
  now asserts each TOC version appears in that package's README.

**Both functional defects are fixed, each with a purpose-built regression test**, and the
tests are the kind that would have failed against the previous code:

- The Expressive trailing-period conversion is restored in `V:Render`, and
  `integration.lua` asserts both halves — a terminal `.` becomes `!` on `nightelf`, a
  terminal `!` doubles on `australian` — plus that a custom template ending in `.` is
  left alone.
- GuildComms' Restore Defaults no longer touches the shared profile, and `settings.lua`
  proves it by loading **ForeverGroupComms** into the same harness, capturing its rendered
  greeting, running `panel.OnDefault()`, and asserting the group output and all four
  shared values are byte-identical afterwards. That is a cross-package regression test for
  a cross-package bug.

**I verified the packaging work by executing it**, which was not possible for the Lua
layer. Python 3 is present on this machine: `tools/package.py` built all four archives,
`tools/verify_package.py` passed all five of its assertion groups, `--runtime` mode
produced correct reduced archives, and I independently confirmed with my own archive
inspection that `ForeverGuildComms-0.5.1-beta.zip` contains 17 `ForeverCommsVoice/`
members, the shared installer, and `Bindings.xml`. This is the first pass in the project's
history where any part of the build was actually run rather than read.

**The weak point is unchanged and is now isolated.** The 13 Lua harnesses still do not run
anywhere automatically, two of three packages still have no syntax check, and four modules
are still loaded by no harness. CI now builds and verifies *packaging*, so the gap is
narrower and more obviously shaped: the infrastructure to run things in CI exists, and the
Lua suite simply is not wired into it.

One genuine new defect was introduced: the three `install/INSTALL-README.txt` files and
the three installer shims were generated from one template without special-casing the
library, so ForeverCommsVoice's copies tell the user it depends on itself.

## Status of the Previous Recommendations

### Before the first commit (items 1-7)

| # | Recommendation | Status |
| --- | --- | --- |
| 1 | Move packaging to the repository root with a job per package and prefixed tags | **RESOLVED, by replacement.** A root `.github/workflows/package.yml` (30 lines) runs `tools/package.py` then `tools/verify_package.py`, uploads all four ZIPs as a workflow artifact, and on a tag attaches them to a GitHub Release with the built-in token. BigWigs is no longer on the suite path. The three nested workflows are retained, normalised to the same shape, and each now carries a header comment stating it is active **only** when that addon's contents are a standalone repository root. The tag-namespace problem dissolved: one `v*` tag now releases the suite, and per-addon versions live in the ZIP filenames |
| 2 | Make the per-addon installers detect, warn about, and ideally install the dependency | **RESOLVED, beyond the recommendation.** `install/Install-ForeverComms.ps1` grew to 153 lines and takes an `-Addons` parameter; the three per-addon `.ps1` files are now 13-line shims that delegate to it. The shared installer prepends `ForeverCommsVoice` whenever a consumer is selected and reorders to canonical dependency order, so a Voice-less install cannot be produced. It also now derives the file list from each TOC, adds `Media/Icon.tga` only when `IconTexture` is declared and validates the path, adds `Bindings.xml` when present, stages and validates everything before touching the destination, backs up to `Interface/AddOnBackups` **outside** `AddOns`, and rolls back on failure. `Set-StrictMode -Version 2.0` is set |
| 3 | Add a test job that runs all 13 harnesses and checks every version string | **RESOLVED after this pass, in a follow-up change.** The version half was already done. The test half now exists: `tools/run_tests.py` is a single runner used by both CI and developers, and `.github/workflows/package.yml` installs Lua 5.1 and runs it **before** packaging, so a failing harness stops the build. Closes the recommendation that had been top of the list for five consecutive passes. See "Follow-up: test automation" below |
| 4 | Fix the nine stale version strings, and bump GuildComms' README title and PACKAGING.md | **RESOLVED.** All three packages bumped to 0.1.1 / 0.2.1 / 0.5.1 and consistent across TOC, `Core.lua`, README title, a new README "Current release" banner line, and both installer `.cmd` lines. `ForeverGuildComms/PACKAGING.md` shrank from 91 lines to an 8-line pointer at the new root `PACKAGING.md`, which removed the stale module list. Remaining older version numbers in the GuildComms README are historical changelog headings and are correct as history |
| 5 | Add `tests/syntax.lua` to Voice and GroupComms, deriving the list from the TOC | **Not done.** Still 13 harnesses; only GuildComms has a syntax check, so 13 of 22 modules have no compile guard |
| 6 | Write a real root `README.md` | **RESOLVED.** 24 lines: a three-row package table with versions and purposes, a four-step install sequence that states Voice is installed first, a "Changes since the first shared-engine beta" list, a pointer to `PACKAGING.md`, and a closing note that an in-game Windows install check is still needed |
| 7 | Add `.release/` to the root `.gitignore` | **Not done**, and now largely moot: the suite path no longer uses BigWigs, so `.release/` is not produced at the root. The new `dist/` output is covered incidentally because the root `.gitignore` already ignores `*.zip` |

### Correctness (items 8-13)

| # | Recommendation | Status |
| --- | --- | --- |
| 8 | Restore the Expressive trailing-period conversion and assert it | **RESOLVED with a regression test.** `V:Render` now reproduces the legacy branch in full, with a comment recording that it runs *before* placeholder substitution so a player or quest name is never altered — which matches where the legacy `A:VoiceText` did it. `integration.lua` adds eight assertions covering the period case, the doubled-exclamation case, and custom-template immunity |
| 9 | Make `OnDefault` leave the shared voice profile alone | **RESOLVED for the shared profile, with a cross-package regression test.** The `for key, value in pairs(A.voiceDefaults)` line is gone, replaced by a three-line comment explaining that `A.char.voice` points at the profile GroupComms also uses. The duplicated `UpdateRequestPreview` call — carried since 0.4.1 — is gone too. **Still open:** the generic `for k, value in pairs(A.defaults)` loop continues to reset `outgoingMode` to `automatic`, so Restore Defaults can still silently re-enable unattended public messaging, and it still copies one level deep |
| 10 | Give the shared profile one writer | **RESOLVED.** `A:SetVoiceOption` went from 27 lines of independent validation to a 7-line delegation to `V:SetOption`, with a comment stating the library owns validation, mutation and dependent UI refresh. The duplicate validator is deleted. Behaviour is preserved because `V:SetOption` already performed the accent re-validation and already probed `_G.ForeverGuildComms` for `RefreshOptions` and `UpdateRequestPreview`; the delegation adds `UpdateBroker` |
| 11 | Test the GroupComms chat-safety rails | **Not done** |
| 12 | Test `parseIDs` and the `OnAddonMessage` header rejections | **Not done.** Still the most consequential untested code in the bundle |
| 13 | Test the `questSync` opt-out and the outbox bounds | **Not done** |

### Maintainability (items 14-25)

| # | Recommendation | Status |
| --- | --- | --- |
| 14 | Rewrite `.kiro/steering/` for the bundle | **RESOLVED** in commit `76ca527`. All eight addon steering files were rewritten per package, `product.md`'s addon-comms non-goal was scoped to GuildComms, `testing.md` was rewritten for 13 harnesses, and `structure.md` / `lua-style.md` were moved off always-included. Three target-state rules the code did not yet meet were marked as explicit "Known deviation" blocks — **all three of those deviations are now closed by this span**, so those blocks are themselves stale and should be removed |
| 15 | Delete `V:VoiceText` and `V:ChooseMessageTemplate` plus its forwarder | **Not done.** `V:VoiceText` remains unreachable dead code. Note it is no longer the *only* copy of the Expressive logic now that `Render` has it back, so deleting it is now purely a cleanup with no risk of losing behaviour |
| 16 | Split `V:Render` into scope-specific resolvers | **Not done**, and `Render` grew by 8 lines |
| 17 | Assert that the duplicated tables match | **Not done** for the template tables. `verify_package.py` added a different and useful version-consistency assertion, but nothing compares `GroupComms.variants` to `groupTemplates.en` or `GuildComms.defaults.templates` to `V.defaults.templates` |
| 18 | Add harnesses for GroupComms `UI.lua` and `Options.lua` | **Not done** |
| 19 | Add `.luacheckrc` | **Not done** |
| 20 | Key approval and suggestion rows by a monotonic id | **Not done** |
| 21 | Drive `UpdateApprovalsUI` in a harness | **Not done** |
| 22 | Give GroupComms its own broker icon and `IconTexture` | **RESOLVED, and extended to Voice.** Both packages gained a distinct `Media/Icon.tga` (64 KB each) and `Media/ProjectIcon.png` (192 KB and 213 KB), an `## IconTexture:` TOC line, and a 40x40 project icon on their Settings panels. GroupComms' broker moved off `INV_Misc_QuestionMark` to its own texture. All three `Icon.tga` files are distinct artwork, confirmed by hash |
| 23 | Make the combined installer copy only loadable files | **RESOLVED.** `Get-RuntimeFiles` parses the TOC, rejects unsafe or duplicate entries, and copies only the manifest plus the conditional icon and `Bindings.xml`. `tests/` and `install/` no longer reach `AddOns/` |
| 24 | Confirm the tabard fix in a live client | **Unknown.** `Tabard.lua` remains byte-unchanged |
| 25 | Remaining trivial carried items | **Not done.** `math.random` still unseeded; the `randomizeMessages` upgrade note is still absent; no floor between consecutive approvals; the review window still auto-shows; Subtle's absent flair is still unexplained in the label; `pendingMessages` still uncommented; the profession-name fallback is still undocumented; the README keybindings section still precedes the byline; no `A:CanFillRole`; `.pkgmeta`/`Bindings.xml` still unasserted by a Lua harness, though `verify_package.py` now asserts `Bindings.xml` reaches the runtime archives |

**Tally: 10 resolved, 1 partly, 14 open.** Against the five items the user explicitly
asked for, all five are addressed and four are fully closed; the fifth (Restore Defaults)
is closed for the shared profile and still open for `outgoingMode`.

## Verification Performed

This section exists because the previous four passes could only read.

| Action | Result |
| --- | --- |
| `python tools/package.py --output dist` | Exit 0. Built `ForeverCommsVoice-0.1.1-beta.zip` (19 files), `ForeverGuildComms-0.5.1-beta.zip` (51), `ForeverGroupComms-0.2.1-beta.zip` (36), `ForeverComms-Bundle-0.5.1-beta.zip` (75) |
| `python tools/verify_package.py dist` | Exit 0. Five PASS lines: the four archives plus the source-fact group covering restore-defaults isolation, Expressive punctuation and installer dependency references |
| `python tools/package.py --output dist-runtime --runtime` | Exit 0. 9 / 21 / 18 / 30 files |
| Independent archive inspection of the GuildComms source ZIP | 32 `ForeverGuildComms/` members, **17 `ForeverCommsVoice/` members**, 2 `install/` members. `ForeverCommsVoice/ForeverCommsVoice.toc`, `install/Install-ForeverComms.ps1` and `ForeverGuildComms/Bindings.xml` all present |
| Independent inspection of the runtime GuildComms ZIP | Exactly 21 members: both packages' TOC-listed modules, both `Media/Icon.tga`, `Bindings.xml`. No tests, no installers, no docs, no `ProjectIcon.png` |
| Icon asset check | Three distinct `Icon.tga` files by MD5, 64 KB each; three `ProjectIcon.png` at 192 / 213 / 481 KB. Real artwork, not placeholders |
| Version sweep across all packages and docs | Consistent at 0.1.1 / 0.2.1 / 0.5.1. Remaining older numbers are historical changelog headings |
| `dist/` and `dist-runtime/` | Removed after verification |

**Not verified at the time of this pass**: the 13 Lua harnesses, because no interpreter
was on PATH. **This was resolved immediately afterwards** — see the follow-up section
below. Nothing has been tested against a live Forever client.

## Follow-up: test automation

Recorded here because it closes this pass's top recommendation and invalidates the
"nothing is verified behaviourally" conclusion above.

A Lua 5.1.5 install was located at `C:\Users\mreillyorg\tools\lua-5.1.5\lua5.1.exe` —
LuaBinaries vc8, with `lua5.1.dll` and `Microsoft.VC80.CRT\` correctly alongside it. It
was already on the User PATH; it was invisible only because the agent shell inherited a
stale environment, since a PATH change reaches only newly created processes.

**The suite was then run for the first time in the project's history: 12 of 13 passed.**

**The single failure was a latent defect in a harness, not in the install.**
`tests/keybindings.lua:26` used `load(body, chunkname)`, which is Lua 5.2+ semantics; in
5.1 `load` takes a *function* and the string form is `loadstring`. It was the only 5.2+
construct in the suite. The implication is the significant part: **`keybindings.lua` had
never executed on any pass.** Its assertions — that the bindings are opt-in, that the
actions open the intended windows, and that **no keybinding path sends a guild message** —
had been assumed since 0.4.1, not tested. Shipped code was unaffected; this was test-only.

Fixed as `local compile = loadstring or load`, correct on 5.1, LuaJIT and 5.2+, matching
the project's feature-detection idiom. **The suite is now 13 of 13.**

Three changes followed:

| Change | Detail |
| --- | --- |
| `tools/run_tests.py` | One runner for CI and developers. Discovers harnesses from each package's `tests/` directory rather than a hand-maintained list, puts `syntax.lua` first, runs each with its own package folder as cwd, and resolves an interpreter from `--lua`, `$LUA51`, PATH, then known installs. Rejects anything not reporting Lua 5.1 or LuaJIT, so a 5.3/5.4 install on PATH is skipped rather than silently used. An **explicitly requested** interpreter that is unusable is a hard error rather than being silently replaced |
| `.github/workflows/package.yml` | Installs plain `lua5.1` — deliberately not LuaJIT, which is a superset — and runs the suite **before** building. Behaviour failures now stop a release |
| `tools/verify_package.py` | The Lua source greps are gone. It no longer splits `panel.OnDefault` on text and indentation to prove a fix is present, because `settings.lua` and `integration.lua` assert that properly and CI runs them first. Bare `assert` replaced with an explicit `check()` so `python -O` cannot skip the checks, and a `__main__` guard added — closing new findings #4 and the smaller observations about it |

Exit codes were verified deliberately, since a runner that silently passes is worse than
none: 0 when all pass, 1 with the harness named when one fails (verified with a temporary
failing harness, since removed), 2 and a diagnostic when no usable interpreter is found.

`package.ps1` was also run this time and verified: it produces four archives with member
counts identical to the Python builder (19 / 51 / 36 / 77), and `verify_package.py` passes
against its output. That partially mitigates new finding #3 — the PowerShell path is no
longer unverified, though CI still exercises only the Python one.

## Test Coverage

- **Overall**: Fair, trending up. Thirteen harnesses, 1,029 lines, **30%** of shipped Lua
  (was 29%). Test code grew 34 lines while shipped code shrank 7.
- Per package: Voice 1 harness / 79 lines; GuildComms 11 / 845; GroupComms 1 / 105.

### The two new regression tests are the best work in this span

**`integration.lua` +15 lines.** Eight assertions that pin the Expressive contract from
both directions: on `nightelf` (a period-terminated accent) the rendered login must
contain `Keeper!` and must **not** contain `Keeper.`; on `australian` the result must end
in `!!`; and a custom template `"Custom greeting, {name}."` must come back exactly as
`"Custom greeting, Keeper."`. That last one is the important one — it proves the
restoration did not leak into user-authored text. The block also restores the prior voice
state afterwards so it does not perturb the assertions that follow, which several
harnesses in this project are careless about.

**`settings.lua` +21 lines.** A cross-package regression test for a cross-package bug. It
sets the shared profile to Spanish / `mexican` / expressive through `V:SetOption`, loads
the real `ForeverGroupComms/Core.lua` into the same harness, captures `G:Render("greet")`,
flips a GuildComms setting, calls `panel.OnDefault()`, then asserts four things: the
GuildComms setting was restored, the shared profile is still the **same table object**
from both `V:GetSettings()` and `A.char.voice`, GroupComms' rendered greeting is
byte-identical, and all three shared values survived. Asserting object identity as well as
value equality is the right call here, because the bug was precisely that the two names
refer to one table.

### Module coverage — unchanged at 4 uncovered

| Package | Covered | Loaded but not driven | No harness loads it |
| --- | --- | --- | --- |
| Voice | `Core`, `Languages`, `Accents`, `RaceProfiles`, `MessageVariants`, `GroupPhrases` | — | **`Options.lua`** |
| GuildComms | all 9 plus `Bindings.xml` | `UI.lua` partially | — |
| GroupComms | `Core`, `Roster`, `Quests` | — | **`UI.lua`**, **`Options.lua`**, **`Broker.lua`** |

`GroupComms/Core.lua` is now loaded by two harnesses in two different packages, which is
a small structural improvement. `Broker.lua` changed this span (the icon) and is still
loaded by nothing.

### Remaining untested paths, ranked

1. **No CI job runs the 13 Lua harnesses.** The job slot now exists.
2. **No syntax harness for Voice or GroupComms** — 13 of 22 modules have no compile guard.
3. The four uncovered modules above.
4. GroupComms' chat-safety rails: the 2-second `Send` floor, `groupSerial` rejection in
   `Approve`, the `CanManageGroup` gates, `Notify` dedup.
5. `parseIDs` and `OnAddonMessage` rejection cases.
6. The `questSync` opt-out and the outbox bounds.
7. **Expressive punctuation for `group` scope.** The restored branch now also fires for
   group `greet` / `welcome` / `level`; only guild scope is asserted. See new finding #2.
8. `package.ps1`. Two implementations of the packager exist and only the Python one is
   executed by CI or by `verify_package.py` — yet `package.cmd`, the documented Windows
   entry point, invokes the PowerShell one.
9. GuildComms' approvals and alerts window rendering.
10. The 30-entry approval backlog cap.
11. `A:IsSelf` realm handling and the suspicious-roster-read guard.
12. The byte clamp on a 3- or 4-byte UTF-8 sequence.
13. The duplicated template tables.

## Code Quality Indicators

- **Linting**: none. Still no `.luacheckrc`, `selene.toml` or `stylua.toml`. Python and
  PowerShell are likewise unlinted, which now matters slightly more since there are
  250 lines of new Python and 225 of new PowerShell on the release path.
- **Code Style**: consistent, and the new code upholds it. The Lua diffs are small and in
  the house idiom. `tools/package.py` is clean, flat, dependency-free standard library
  only, with a module docstring stating the invocation and the dependency-bundling
  behaviour. `install/Install-ForeverComms.ps1` is the strongest of the new files: named
  functions, strict mode, validation separated from mutation, and a staged-then-move
  strategy with an explicit rollback block.
- **Documentation**: much improved and now the right shape. The root `README.md` and root
  `PACKAGING.md` are new and accurate; `ForeverGuildComms/PACKAGING.md` correctly became
  a pointer rather than being left to drift. Each addon README gained a "Current release"
  banner line, which is also the string `verify_package.py` checks. `PACKAGING.md`
  explicitly distinguishes the suite-repository layout from three standalone repositories
  and states that the nested workflows are not discovered in the suite case — the exact
  misconception that caused the previous pass's finding.
- **Error handling**: good and extended. `tools/package.py` wraps `main` and reports
  `OSError` / `ValueError` as a single-line failure with exit 1. Both builders refuse
  unsafe archive members, unsafe TOC entries, absolute paths and `..` segments. The
  installer validates every manifest before changing a file.
- **Global hygiene**: unchanged and clean.

### Observation: the fixes were again made defensively rather than minimally

Consistent with the 0.4.3 span, each fix went wider than required:

| Fix | Minimal version | What was done |
| --- | --- | --- |
| Packaging | Move three workflows to the root | Replaced the external packager on the suite path with two offline builders, added a verifier that also asserts source-level facts about the other fixes, and kept the nested workflows for the standalone case with a comment explaining when they apply |
| Installer dependency | Detect and warn | Made the dependency-less install unreachable by construction, and simultaneously fixed the combined installer's over-copying and moved backups outside `AddOns` |
| Version strings | Update nine strings | Updated them, then **deleted three of the locations** so there is less to drift, and added a CI assertion for the rest |
| Restore Defaults | Delete one line | Deleted it, documented why in a comment aimed at the next reader, removed the long-carried duplicate statement, and added a cross-package regression test |
| One writer for the profile | Route through `V:SetOption` | Did that and deleted the 20-line duplicate validator rather than leaving it unreachable |

The version-string reduction is the most interesting. Removing a place a value can be
stated is strictly better than adding a check that it is stated consistently, and the
change did both.

## Technical Debt

### New findings

#### 1. The ForeverCommsVoice installer documentation is self-referential nonsense
**Severity: low impact, high visibility. The one clear defect introduced this span.**

The three `install/INSTALL-README.txt` files and three installer shims were generated from
a single template with the addon name substituted, and the library case was not
special-cased. `ForeverCommsVoice/install/INSTALL-README.txt` therefore says:

- "This addon uses ForeverCommsVoice for shared translations and accents."
- "The individual downloadable ZIP includes ForeverCommsVoice as a sibling addon."
- "The installer installs/updates ForeverCommsVoice first, then **ForeverCommsVoice**."
- "Manual install: copy BOTH ForeverCommsVoice and **ForeverCommsVoice** folders"

And `Install-ForeverCommsVoice.ps1` prints:

> `ForeverCommsVoice uses ForeverCommsVoice for its shared language/accent settings.`

Every statement is wrong for the library: it has no dependency, its ZIP bundles no
sibling, and there is one folder to copy. The functional path is correct — the shim passes
`-Addons @('ForeverCommsVoice')` and the shared installer does the right thing — so this
is purely user-facing text. It is also the first thing a user reads when installing the
addon the other two depend on.

#### 2. Expressive punctuation now also applies to group messages
**Severity: low, undocumented, untested.**

The restored branch sits inside `V:Render`'s shared flair block, which runs for
`scope == "guild"` with `kind ~= "help"` **or** `scope == "group"` with kind in
`greet` / `welcome` / `level`. Legacy GuildComms behaviour is reproduced faithfully, but
group messages gain punctuation rewriting they never had — at Expressive, the `tauren`
group greeting "Walk in peace, companions." becomes "...companions!", and similarly for
`nightelf`, `forsaken`, `bloodelf` and `draenei`.

This is probably desirable and is certainly consistent, but the README describes the
change as restoring behaviour for "built-in, accented guild messages", and
`integration.lua` asserts guild scope only. Either scope the branch to guild or document
and test the group case.

#### 3. Two implementations of the packager, only one of them verified
**Severity: medium maintainability.**

`tools/package.py` (97 lines) and `package.ps1` (72 lines) implement the same contract:
the same three addons, the same four archive names, the same TOC validation, the same
dependency bundling, the same "suite version tracks GuildComms" rule. They will drift.
They already differ in one visible way — `package.ps1` has no `--runtime` mode — and
`PACKAGING.md` documents that asymmetry rather than resolving it.

The risk is pointed: CI runs the Python builder and `verify_package.py` validates the
Python builder's output, while `package.cmd` — the entry point `PACKAGING.md` tells
Windows users to double-click — runs the **PowerShell** one. The unverified path is the
one most users will take. Running `verify_package.py` against a `package.ps1` build, or
having `package.ps1` shell out to Python when it is available, would close this.

#### 4. `verify_package.py` asserts Lua source text
**Severity: low, and a deliberate trade.**

To guard the two functional fixes, the packaging verifier greps source:

```python
default_handler = settings.split('function panel.OnDefault()', 1)[1].split('\n    end', 1)[0]
assert 'A.char.voice[key] =' not in default_handler
assert 'template:sub(-1) == "."' in (ROOT / 'ForeverCommsVoice/Core.lua').read_text()
```

This is effective — it is the only automated guard either fix has, given the Lua suite
runs nowhere — but it couples release packaging to the exact text and indentation of two
Lua functions. A benign rename or reindent of `panel.OnDefault` fails the build with a
packaging error. The `split('\n    end', 1)` boundary in particular assumes four-space
indentation of the closing `end`. Worth a comment saying so, and worth retiring once the
Lua harnesses run in CI, since both facts are already asserted there properly.

#### 5. `tests/icon.lua` now reaches outside its package with no override
**Severity: low.**

It changed from reading `install/Install-ForeverGuildComms.ps1` to
`../install/Install-ForeverComms.ps1`, which is correct since the icon-copying logic
moved to the shared installer. But it adds a second cross-package path dependency to the
harness suite, and unlike the Voice path — which honours `FOREVER_VOICE_PATH` — this one
is hardcoded. `icon.lua` already required the package root as its working directory; it
now additionally requires the sibling `install/` directory, so it cannot run against a
standalone extraction of the GuildComms package at all.

#### 6. The suite version silently tracks GuildComms
Both builders set the bundle archive version from `versions['ForeverGuildComms']`, with
the comment "Bump the suite with GuildComms' release number; no stale hardcoded versions".
Avoiding a fourth hardcoded version is the right instinct, and `PACKAGING.md` states the
behaviour. But it means a release containing only a Voice fix would still be named for
GuildComms' unchanged version, and `verify_package.py` would pass. Recorded as a
documented design choice, not a defect.

#### 7. Smaller observations

- **The three steering "Known deviation" blocks are now stale.** `ui-frames.md`,
  `release-packaging.md` and the installer note were written against the previous state;
  all three deviations are closed. `release-packaging.md` also still says seven version
  locations move together, where there are now four.
- **`verify_package.py` has no `if __name__ == '__main__'` guard** and runs its assertions
  at import time, unlike `package.py`. Fine as a script, inconsistent with its sibling.
- **Bare `assert` in a verification tool** means `python -O` silently skips every check.
  Low risk given CI invokes it plainly.
- **`A:SetVoiceOption` now returns `false` when the library is missing**, where the old
  code would have operated on a local table. Correct, and unreachable given the hard
  dependency, but it means the method's failure now has two distinct causes — invalid
  value, or no library — with no way for a caller to tell them apart. No current caller
  cares.
- **GroupComms' Settings panel gained a project icon but still implements none of the
  three canvas callbacks**, so it remains the one panel that can show stale values if
  anything else ever writes its settings.

### Carried forward unchanged

`OnDefault` still resets `outgoingMode` and still copies one level deep. Positional row
binding in both packages. No floor between consecutive approvals. `ShowApprovals` fires on
every staged message. `A.GetActivityType` is a dot-called closure. Duplicated
role-availability logic. `pendingMessages` holds records without a comment. The
profession-name fallback is undocumented. Subtle's absent flair is unexplained. No
`.luacheckrc`. `V:VoiceText` and `V:ChooseMessageTemplate` are dead. `V:Render` is still
one dense function. `A.messageVariantBags` is unbounded. `math.random` is unseeded.

## Patterns and Anti-patterns

### Good Patterns

New this span:

- **A build tool with no dependencies.** Standard-library Python and `System.IO.Compression`
  PowerShell, no packager install, no network, no secrets, no account. The suite can be
  packaged from an extracted ZIP on a machine with nothing installed, which is exactly the
  distribution model this project uses.
- **Validation inside the builder, not beside it.** `manifest()` refuses a missing version,
  a wrong `IconTexture` path, an unsafe TOC entry, a missing runtime file, a missing
  dependency declaration and a missing project icon. A broken release fails to build
  rather than shipping.
- **Making the failure mode unreachable instead of reporting it.** The installer prepends
  the dependency rather than warning about its absence.
- **Deleting places a value can be stated.** Three version locations removed, then an
  assertion added for the rest.
- **A cross-package regression test for a cross-package bug.** `settings.lua` loads the
  other consumer and asserts its output is unchanged, including object identity of the
  shared table.
- **Asserting the fix did not leak.** The Expressive test checks a custom template ending
  in a period is untouched, not just that the accented one changed.
- **Recording the reason in the code the next reader will edit.** Both Lua fixes left a
  comment stating the rule rather than describing the change: "Restore Defaults belongs to
  GuildComms, NOT ForeverCommsVoice", and "ForeverCommsVoice owns validation, mutations,
  and dependent UI refresh."
- **Retaining the alternative path with its applicability stated.** The nested BigWigs
  workflows were kept and each gained a one-line header saying it is active only in a
  standalone repository — so the next reader does not repeat the previous pass's
  diagnosis.
- **A runtime/source archive split.** `--runtime` produces addon-manager archives with no
  installer, tests or promotional art, verified to contain exactly the runtime set.

Carried forward intact: the single event dispatcher per package, `CanUse`/`CanChat` as
universal gates, one send call site per package, baseline-before-diffing, GUID-first
self-exclusion, serial and epoch invalidation, bounded caches with two sweep triggers,
minimum disclosure in the peer protocol, inbound validation before trust, fingerprinted
draft caching, the non-consuming preview path, feature detection at every call site, and
tests that encode the bug rather than only the fix.

### Anti-patterns

- **Two implementations of one build contract**, with CI verifying only the one most users
  will not run.
- **A release verifier coupled to Lua source text and indentation.**
- **Template-generated user documentation without a special case for the odd member**, so
  the library's installer tells users it depends on itself.
- **Automated release with no automated *behavioural* verification.** Packaging is now
  checked in CI; the 13 Lua harnesses still are not.
- **Known-deviation notes left in steering after the deviations were fixed.**
- **A generic defaults handler resetting a safety-relevant setting** — narrowed this span,
  not eliminated.
- Positional index binding between a UI row and a mutable list, in two packages.
- Dead code retained after an extraction.

## Security Posture

Unchanged in substance, with a modest new surface that is handled well.

### What did not change
No network surface in the addons, no credential handling, no file I/O outside
SavedVariables, no `loadstring` in shipped code, no vendored libraries. All gear, invite,
role, targeting and quest-acceptance actions remain in the player's hands. GuildComms
still has no addon-to-addon messaging and still reads only `CHAT_MSG_GUILD`. GroupComms'
quest protocol is unmodified this span, including all eleven inbound validations, the
minimum-disclosure rule and the epoch guard.

### New surface: the build and install tooling
This is developer-side rather than player-side, and the controls are appropriate:

| Control | Implementation |
| --- | --- |
| Archive path confinement | Python rejects any member containing `..` or a leading `/`; PowerShell rejects any source path not under the repository root |
| Symlink handling | `source_files` skips symlinks, so a link cannot pull a file in from outside the tree |
| TOC entry allow-list | Both builders and the installer require `^[A-Za-z0-9_-]+\.(lua|xml)$`, so a TOC cannot name a path, a traversal or an executable |
| Icon path validation | The declared `IconTexture` must match the expected per-addon path exactly, case-insensitively |
| Install staging | Everything is validated and staged in a temp directory before the destination is touched, with rollback on failure |
| Backup placement | `Interface/AddOnBackups`, deliberately outside `AddOns`, so a backup cannot be loaded as a stray addon |
| SavedVariables | Never read, written or copied by any installer or builder |
| Secrets | The suite workflow uses only the built-in `GITHUB_TOKEN` with `contents: write`. No third-party token is required or referenced on the suite path |

Two observations, neither a defect: the installer runs `Remove-Item -Recurse -Force` on a
target directory during rollback, which is correct for restoring a backup but is the most
destructive line in the repository, and it is reached only in the failure branch after a
successful `Move-Item` to the backup location. And `-ExecutionPolicy Bypass` in the `.cmd`
launchers remains scoped to that process only.

## Recommendations

Ordered by value relative to effort. *(carried)* marks items from the previous list.

| # | Recommendation | Effort | Rationale |
| --- | --- | --- | --- |
| ~~1~~ | ~~Add a step to the root workflow that runs all 13 Lua harnesses~~ | Low | **DONE in the follow-up above.** Closes the item that had been top of the list for five consecutive passes, and the last of the fourth rerun's seven pre-commit items. It also retired recommendation 13's subject matter by letting the verifier drop its Lua source greps |
| 1 | Add `tests/syntax.lua` to Voice and GroupComms *(carried, was #5)* | Low | **Now the top item.** 13 of 22 modules have no compile guard, and the runner would pick the new harnesses up automatically since it discovers them from the directory. Six lines each, no dependencies |
| 2 | Fix the three ForeverCommsVoice installer texts | Trivial | Self-referential nonsense in the first file a user of the base dependency reads. New finding #1 |
| 4 | Decide the Expressive scope question: either restrict the branch to guild, or document and test the group case | Low | New finding #2. Currently an undocumented behaviour change riding along with a documented restoration |
| 5 | Make `package.cmd` prefer `tools/package.py` when Python is present, or run `verify_package.py` against a `package.ps1` build | Low | New finding #3. The documented Windows path is the unverified one |
| 6 | Make `OnDefault` preserve `outgoingMode`, and use `fillDefaults` instead of a one-level copy *(carried, was #9 and #19)* | Trivial | The remaining half of the Restore Defaults finding. Still able to silently re-enable unattended public messaging |
| 7 | Refresh the three stale "Known deviation" blocks in steering, and correct `release-packaging.md`'s version-location count from seven to four | Trivial | The deviations are fixed; leaving the notes makes the steering wrong in the opposite direction |
| 8 | Test the GroupComms chat-safety rails *(carried, was #11)* | Medium | The safety model of a chat-writing addon is still unasserted |
| 9 | Test `parseIDs` and the `OnAddonMessage` header rejections *(carried, was #12)* | Low | Still the most consequential untested code in the bundle |
| 10 | Test the `questSync` opt-out and the outbox bounds *(carried, was #13)* | Low | An opt-out that is never asserted can silently stop working |
| 11 | Add `.luacheckrc` at the root *(carried, was #19)* | Low | 22 Lua files, plus it would flag the unused `A:SameGroup` |
| 12 | Delete `V:VoiceText` and `V:ChooseMessageTemplate` plus its forwarder *(carried, was #15)* | Low | Now a pure cleanup: the Expressive logic it uniquely held has been restored to `Render` |
| ~~13~~ | ~~Give `verify_package.py` a `__main__` guard, replace bare `assert` with explicit raises, and comment the source-grep coupling~~ | Low | **DONE in the follow-up above**, and better than asked: the source greps were deleted rather than commented, because CI now runs the harnesses that assert those facts properly |
| 14 | Add harnesses for GroupComms `UI.lua` and `Options.lua` *(carried, was #18)* | Medium | 239 lines loaded by nothing, and `Broker.lua` changed this span without a test |
| 15 | Assert the duplicated template tables match *(carried, was #17)* | Low | Both are load-bearing; one is guarded only implicitly |
| 16 | Split `V:Render` into scope-specific resolvers *(carried, was #16)* | Medium | It grew again, and finding #2 is a direct consequence of one shared flair block serving two scopes |
| 17 | Key approval and suggestion rows by a monotonic id *(carried, was #20)* | Low | Same fragile invariant in two packages |
| 18 | Drive `UpdateApprovalsUI` in a harness *(carried, was #21)* | Medium | Part of the authorization path for public messages |
| 19 | Confirm the tabard fix in a live client *(carried, was #24)* | Low | Still never observed against real event ordering |
| 20 | Remaining trivial carried items *(carried, was #25)* | Trivial to Low | Unchanged. None blocking |

### Assessment

**This span closed the gap the previous pass opened.** Ten of twenty-five recommendations
resolved, both functional defects fixed with purpose-built regression tests, and all five
items the user named addressed. More telling than the count is the pattern: three of the
fixes are better than what was recommended, and two of them worked by *removing* the
thing that could go wrong — deleting version locations rather than checking them,
constructing an installer in which a missing dependency is unreachable — rather than
adding a guard around it.

It is also the first pass where I could verify rather than infer. The packaging claims are
not taken on trust: the builder ran, the verifier passed, and I inspected the archives
independently and confirmed the dependency bundling and the runtime/source split.

The one new defect is cosmetic but conspicuous. **The standing weakness is closed.** The
follow-up change found an existing Lua 5.1.5 install, ran the suite for the first time in
the project's history, fixed the one harness that a 5.2-ism had prevented from ever
executing, and wired all 13 into CI ahead of packaging. Both regression tests written this
span now actually run, and the release verifier no longer has to grep Lua source to prove
the fixes are present.

That leaves a materially different risk profile. Behaviour and packaging are both verified
automatically; what remains untested is specific and enumerable rather than
structural — two missing syntax harnesses, four uncovered modules, the GroupComms safety
rails, and the peer-input rejection paths. The top recommendation is now the cheapest one
on the list for the first time in six passes.
