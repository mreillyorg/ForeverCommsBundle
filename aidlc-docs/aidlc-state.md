# AI-DLC State Tracking

## Project Information
- **Project Name**: ForeverCommsBundle — Forever Comms Voice **0.2.2-beta**, Forever Group
  Comms **0.3.4-beta**, Forever Guild Comms **0.6.3-beta**
- **Project Type**: Brownfield, multi-package
- **Start Date**: 2026-10-18T23:45:00Z
- **Current Stage**: INCEPTION - Reverse Engineering (tenth pass complete, awaiting user approval)

## Workspace State
- **Existing Code**: Yes
- **Programming Languages**: Lua 5.1 (addons and harnesses), XML (key bindings),
  Python 3 (test runner, builders, verifiers, mutation checker), PowerShell and Batch
  (installers and launchers), YAML (CI)
- **Build System**: None for the addons; Lua ships as source. **BigWigsMods/packager `@v2`
  is the authoritative release path**, driven by the root `.pkgmeta`;
  `tools/package.py` is a local mirror reading the same `.pkgmeta`, so the two cannot
  disagree about what ships
- **Project Structure**: Monorepo with three flat World of Warcraft addon packages,
  25 shipped modules, plus root-level build, lint and install tooling
- **Reverse Engineering Needed**: Completed eight times; artifacts current as of
  2026-10-25T04:00:00Z against commit `f7f7bab`
- **Workspace Root**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`

## Packages

| Package | Version | Type | Modules | Lines | Methods | Harnesses | SavedVariables |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ForeverCommsVoice` | 0.2.2-beta | Shared library | 9 | 1,221 | 33 | 8 | `ForeverCommsVoiceCharDB` |
| `ForeverGuildComms` | 0.6.3-beta | Application | 9 | 1,580 | 67 | 13 | `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB` |
| `ForeverGroupComms` | 0.3.4-beta | Application | 7 | 1,166 | 53 | 7 | `ForeverGroupCommsDB` |

Measured at `f7f7bab`, like the rest of this document. The follow-up work on the two code
smells added 21 lines and one method to Voice (`V:ResetVariantBags`) and 5 lines and one
method to GuildComms (`A:GetActivityType`), with 84 and 22 harness lines respectively.
GroupComms' Lua was untouched.

That work, and a patch bump of all three versions to Voice **0.2.3-beta**, GuildComms
**0.6.4-beta** and GroupComms **0.3.5-beta**, were **committed and released externally**:
`c0f2f5b` "kiro fixes" then `33e5f30` "all staged for v0.6.4-beta", tagged and pushed as
**`v0.6.4-beta`**. GroupComms was bumped despite having no behavioural change, because its
README names the required library version in two places and that reference had to move;
its shipped diff is two version strings and its release note says so.

**HEAD has since moved to `fc94ccc` "fixing github action"**, which is one line in
`.github/workflows/package.yml` and is **not yet pushed**. It corrects the Ubuntu package
name for the linter: `apt-get install luacheck` could never succeed, because the Ubuntu
source package `luacheck` ships its binary as **`lua-check`** (confirmed against the
universe pool, which carries `lua-check_1.2.0-1_all.deb`, the same 1.2.0 used locally).
With `set -euo pipefail` that step aborts the job, so the automated checks for the
`v0.6.4-beta` tag could not have run.

GuildComms was briefly set to **0.6.5-beta** for that purpose, then superseded before it
was ever committed or tagged. **All three packages are now synchronised at 0.7.0-beta** in
the working tree, uncommitted, via `tools/bump_version.py --sync --minor`: the three
separate version lines (Voice 0.2.3-beta, GuildComms 0.6.4-beta, GroupComms 0.3.5-beta)
collapsed onto one number taken from the highest and rolled once. The minor bump marks the
scheme change, not a feature — the complete shipped diff against the released
`v0.6.4-beta` is **six lines, all version strings**, verified with
`git diff v0.6.4-beta -- "*/*.lua" "*/*.toc" "*/Bindings.xml"`.

`check_bigwigs_bundle.py` passes all three and the bundle is
`ForeverCommsBundle-0.7.0-beta.zip` at 33 entries. Release notes were written into all four
READMEs; the never-published 0.6.5-beta notes were folded into the 0.7.0-beta entry rather
than left describing a version nobody could download.

Both applications declare `## Dependencies: ForeverCommsVoice`. The library depends on
neither and is the **sole writer** of the shared voice profile.

## Code Location Rules
- **Application Code**: Workspace root, inside the three package folders (NEVER in aidlc-docs/)
- **Build, lint and install tooling**: repository root — `tools/`, `install/`,
  `package.ps1`, `package.cmd`, `run-tests.cmd`, `.luacheckrc`, `.pkgmeta`,
  `.github/workflows/`
- **Documentation**: aidlc-docs/ only
- **Project-specific constraints**:
  - Each addon folder must be named exactly after its addon, with a matching
    `<Addon>.toc` inside it, and source files stay flat.
  - `Bindings.xml` ships from the addon root in GuildComms and GroupComms and must **not**
    be listed in either TOC.
  - All three TOCs must declare `## IconTexture:` pointing at their own `Media\Icon`;
    the builders and the installer validate this exactly.
  - `ForeverCommsVoice` must install before either consumer. Enforced by construction:
    every consumer archive bundles the library, and the combined installer prepends it to
    any consumer-only selection.
  - **Four version locations move together per package**: the TOC, `Core.lua`, the README
    title and the installer `.cmd`. `tools/check_bigwigs_bundle.py` asserts all four on
    both the CI and local paths.

## Git State at Analysis Time
This block had been left describing the **eighth** pass (`HEAD` = `a64ac2a`) and was
simply wrong for the tenth. Corrected, and brought up to the current state:

- Tenth pass analysed `HEAD` = `f7f7bab` "fixes found from the quality checks", then equal
  to `origin/main`. Working tree clean at that point.
- Baseline for that pass: `b712070`, spanning five commits — `05970d1`, `c8a0e30`,
  `ae17bfa`, `eec9635`, `f7f7bab` — 40 files changed, 2,269 insertions, 244 deletions,
  12 added, 28 modified.
- **Since then, externally**: `1794300` "removing accidental files", `c0f2f5b`
  "kiro fixes" and `33e5f30` "all staged for v0.6.4-beta", the last tagged and pushed as
  **`v0.6.4-beta`**. `33e5f30` is `origin/main`.
- **Current `HEAD` = `fc94ccc` "fixing github action"** — one line in
  `.github/workflows/package.yml`, committed but **not pushed**, one ahead of upstream.
- Working tree now: GuildComms bumped to **0.6.5-beta** and not committed. Nothing else
  is modified.
- Recent history: `f7f7bab` → `1794300` → `c0f2f5b` → `33e5f30` (tag `v0.6.4-beta`) →
  `fc94ccc`

## Extension Configuration
Not yet determined. Extension opt-in questions are presented during Requirements
Analysis, which has not run. Only the `*.opt-in.md` files were loaded at workflow start;
no full extension rule file has been loaded, so no extension rule was enforced or
evaluated during Reverse Engineering.

| Extension | Enabled | Decided At |
| --- | --- | --- |
| security/baseline | Undecided | - |
| resiliency/baseline | Undecided | - |
| testing/property-based | Undecided | - |

## Stage Progress

### INCEPTION
- [x] Workspace Detection - Completed 2026-10-18T23:45:00Z - Brownfield
- [x] Workspace Detection - Re-run 2026-10-19T09:52:22Z - Brownfield, multi-package
- [x] Reverse Engineering - Completed 2026-10-18T23:52:00Z against 0.1.0-beta
- [x] Reverse Engineering - Rerun completed 2026-10-19T00:52:00Z against 0.2.0-beta
- [x] Reverse Engineering - Second rerun completed 2026-10-19T02:40:00Z against 0.4.1-beta
- [x] Reverse Engineering - Third rerun completed 2026-10-19T03:20:00Z against 0.4.3-beta
- [x] Reverse Engineering - Fourth rerun completed 2026-10-19T09:52:22Z against the bundle
- [x] Reverse Engineering - Fifth rerun completed 2026-10-19T11:30:00Z against the
      0.1.1 / 0.2.1 / 0.5.1 remediation release
- [x] Reverse Engineering - Sixth rerun completed 2026-10-19T13:30:00Z against `57f7cdc`
- [x] Reverse Engineering - Seventh rerun completed 2026-10-25T02:30:00Z against `a64ac2a`
- [x] Reverse Engineering - Eighth rerun completed 2026-10-25T03:10:00Z against `b712070`
- [x] Reverse Engineering - **Ninth rerun** completed 2026-10-25T04:00:00Z against
      `f7f7bab` (0.2.2 / 0.6.3 / 0.3.4, unchanged) - awaiting approval
- [ ] Requirements Analysis - Not started (user has scoped every run to end after Reverse Engineering)
- [ ] User Stories - Not assessed
- [ ] Workflow Planning - Not started
- [ ] Application Design - Not assessed
- [ ] Units Generation - Not assessed

### CONSTRUCTION
- [ ] Not started

### OPERATIONS
- [ ] Placeholder stage

## Reverse Engineering Status
- [x] Reverse Engineering - Tenth pass completed on 2026-10-25T04:00:00Z
- **Artifacts Location**: `aidlc-docs/inception/reverse-engineering/`
- **Artifacts target**: commit `f7f7bab` — Voice 0.2.2-beta, GuildComms 0.6.3-beta,
  GroupComms 0.3.4-beta. No version changed in this span.
- **Approach**: targeted update. `reverse-engineering-timestamp.md` was rewritten;
  `code-quality-assessment.md`, `technology-stack.md`, `component-inventory.md`,
  `code-structure.md`, `dependencies.md` and `business-overview.md` had the affected
  sections and re-measured figures updated; `architecture.md` and `api-documentation.md`
  needed only their headers, because this span changed quality tooling and documentation
  rather than architecture or the public API.
- **Change span covered**: five commits. Two were this session's output being committed
  (`05970d1`) and a generated user wiki (`c8a0e30`). The other three were **external**:
  `ae17bfa` added `tools/check_lua_quality.py` and rewrote the workflow around it, and
  `eec9635` plus `f7f7bab` cleared all 29 luacheck warnings. Every code metric is
  unchanged — the lint pass was 48 insertions against 48 deletions.
- **Change span covered**: remediation items 1–40 of `SUGGESTED-CHANGES.md` across two
  commits, then a version bump of all three packages with release notes in all four
  READMEs. The span restored the three failing harnesses and the CI test step, restored
  two deleted regression tests, corrected 11 stale version strings and widened the version
  check from two locations to four, rewrote `tools/package.py` as a `.pkgmeta`-driven
  mirror of BigWigs, rewrote all eight addon steering files, removed the bundle's only
  `OnUpdate`, split `V:Render`, deleted dead code, added the approval floor and the
  `reviewAutoShow` setting, implemented GroupComms' canvas callbacks, added `.luacheckrc`
  and `tools/fault_inject.py`, decided and documented the Expressive scope question, and
  added **11 new harnesses**.

## Reverse Engineering History

| Run | Date | Target | Trigger | Outcome |
| --- | --- | --- | --- | --- |
| 1 | 2026-10-18T23:52Z | 0.1.0-beta | First brownfield pass | 9 artifacts; gate never answered |
| 2 | 2026-10-19T00:52Z | 0.2.0-beta | Explicit rerun; artifacts stale | 3 of 15 findings resolved |
| 3 | 2026-10-19T02:40Z | 0.4.1-beta | Explicit rerun; three releases stale | 6 of 17 resolved, 1 half |
| 4 | 2026-10-19T03:20Z | 0.4.3-beta | Explicit rerun; verified real change first | 3 of 19 resolved, incl. both findings first raised against 0.1.0 |
| 5 | 2026-10-19T09:52Z | Bundle (3 packages) | Explicit rerun before first commit | 0 of 19 resolved; 11 new findings; first multi-package pass |
| 6 | 2026-10-19T11:30Z | 0.1.1 / 0.2.1 / 0.5.1 | Explicit rerun after remediation | 10 of 25 resolved, 1 partly. First pass with any build step executed |
| 7 | 2026-10-19T13:30Z | `57f7cdc` | Explicit rerun | 2 of 20 resolved, 1 regressed. **First pass where the suite could be run — and it was red, 3 of 17** |
| 8 | 2026-10-25T02:30Z | `a64ac2a` | Explicit rerun after a staleness check | **40 of 44 resolved.** First pass with a green suite, a linter, zero uncovered modules and mutation-verified assertions |
| 9 | 2026-10-25T03:10Z | `b712070` | Explicit rerun | **42 of 46 resolved.** Targeted update, not a rewrite: the hard library dependency is now enforced at load in both consumers, and embedding the library was considered and rejected on the record |
| 10 | 2026-10-25T04:00Z | `f7f7bab` | Explicit rerun | **45 of 47 resolved.** Items 43 and 44 closed externally: luacheck clean at 0 warnings, and CI now enforces strict 5.1 parsing, the harnesses and zero-warning lint. **Only the two live-client items remain.** One documentation defect found in `LUA51-AUDIT.md`, and one tooling defect found and fixed in `tools/fault_inject.py` (item 47) |

## Project Growth Across Passes

Every column is a commit. The last was the working tree when this pass wrote it and has
since been committed and released as tag `v0.6.4-beta` (`33e5f30`).

| Metric | 0.1.0 | 0.4.3 | Bundle | 0.x.1 | `57f7cdc` | `a64ac2a` | `b712070` | `f7f7bab` | `v0.6.4-beta` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 3 | 3 | 3 | 3 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 12 | 22 | 22 | 25 | 25 | 25 | 25 | **25** |
| Shipped Lua lines | 882 | 2,022 | 3,395 | 3,388 | 3,806 | 3,927 | 3,967 | 3,967 | **3,993** |
| Public methods | 38 | 64 | 129 | 129 | 152 | 153 | 153 | 153 | **155** |
| Offline harnesses | 1 | 11 | 13 | 13 | 17 | 28 | 28 | 28 | **28** |
| Harness lines | 72 | 816 | 1,029 | 1,215 | 1,215 | 4,138 | 4,257 | 4,257 | **4,363** |
| Test % of shipped Lua | 8% | 40% | 29% | 30% | 32% | 105% | 107% | 107% | **109%** |
| Modules with no harness | 6 | 0 | 4 | 4 | 5 | 0 | 0 | 0 | **0** |
| Suite passing | n/a | n/a | not run | not run | NO — 3/17 | YES | YES | YES | **YES — 28/28** |
| luacheck warnings | n/a | n/a | n/a | n/a | n/a | 29 | 29 | 0 | **0** |
| Assertions mutation-verified | No | No | No | No | No | 28/28 | 31/31 | 31/31 | **37/37** |
| Active CI workflows | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | **1** |
| CI runs the harnesses | No | No | No | Yes | No | Yes | Yes | **Yes** |
| CI runs the linter | No | No | No | No | No | No | No | **Yes** |
| CI strict-parses all Lua | No | No | No | No | No | No | No | **Yes** |

## Notes

- The user has scoped every run to end after Reverse Engineering, so the workflow stops at
  the approval gate rather than auto-advancing to Requirements Analysis.
- **This pass was triggered by a staleness check, not by new work.** The user asked
  whether reverse engineering was up to date; it was not, and the drift was measured
  before anything was regenerated. All nine artifacts were rewritten rather than updated
  in place, because the previous pass's findings had all been closed and a reader would
  otherwise have taken the opposite of the truth from them.
- **Every finding from the previous pass is closed.** All ten headline items plus ten of
  the thirteen "carried forward unchanged" entries. One entry — `math.random` is unseeded
  — was **withdrawn as incorrect**: `math.randomseed` does not exist in the WoW client,
  which seeds the RNG itself at startup, so a seed call would have errored at load. The
  withdrawal is recorded at both call sites in code, in the ledger, in the assessment
  artifact and as an `Avoid` entry in `lua-style.md`, because a docs-only record would
  have let a source-reading pass raise it a third time.
- **The suite is green and the assertions have been shown to bite.** 28 of 28 harnesses
  pass, and `tools/fault_inject.py` reverts one real guard at a time and confirms the
  harness that should notice does fail: 28 of 28. Four assertions initially passed while
  the behaviour they guarded was removed, and were strengthened — that is the single most
  useful quality result in this pass and is tabled in `code-quality-assessment.md`.
- **Coverage is complete at the module level** for the first time: all 25 shipped modules
  are loaded by at least one harness, against five uncovered last pass.
- **A linter now exists**: root `.luacheckrc`, 0 errors across 53 files. Writing it found
  a live defect — `ForeverCommsVoice/Options.lua` gated `ADDON_LOADED` on a bare `ADDON`,
  nil outside `Core.lua`, so the Voice Settings panel was never registered until the user
  typed `/fcv`. Fixed and regression-tested in `tests/options.lua`.
- **Two user-facing settings were added** and both default to existing behaviour:
  GuildComms `reviewAutoShow` (on) and a 2-second floor between approvals. Release notes
  were added to all four READMEs after the bump, since neither had been documented.
- **Still open — four ledger items**: 41 confirm the tabard login-ordering fix in-game;
  42 walk the 32-step in-game checklist; 43 clear or deliberately silence the 29 cosmetic
  luacheck warnings; 44 add a luacheck step to the workflow.
- **Closed since, as items 48 and 49 — the two carried-forward code smells:**
  `A.GetActivityType` was a dot-called closure (`ForeverGuildComms/UI.lua:145`), and
  `A.messageVariantBags` is unbounded (`ForeverCommsVoice/Core.lua:14`).
- **The largest risk is unchanged and is not a code risk.** Nothing in this bundle has
  ever been loaded by the client it targets. Offline confidence is now high; live
  confidence is still zero. Items 41 and 42 are the only ones that address it, and no
  further harness work can.

### Added by the ninth pass

- **The hard library dependency is now enforced at load in both consumers**, as the first
  statement of each `Core.lua` (item 46). GroupComms previously had no check and degraded
  silently; GuildComms checked from `VoiceBridge.lua`, the second TOC file, by which point
  the namespace was published and the dispatcher created, so `ADDON_LOADED` still reached
  `A:Initialize()` and the addon half-ran.
- **This corrects the eighth pass**, which listed GroupComms' degradation as acceptable
  because every library call was guarded. Guarding every call site is not the same as the
  degraded state being correct: the fallback approval path calls `A:Send(kind, vars)` and
  **re-renders** instead of replaying the captured text, so with `randomMessages` on the
  message sent could differ from the one the player reviewed.
- **Embedding the library under `Libs/` was considered and rejected on the record** as
  item 45, so it is not re-litigated. The blocking reason is that `ForeverCommsVoice`
  declares SavedVariables and an embedded library cannot.
- **14 harnesses needed a library stub or a load-order fix**, which is the real cost of
  item 46 and reveals that none of them had been modelling the shipped reality: every one
  loaded a consumer's `Core.lua` with no library present, a state the TOC dependency makes
  impossible in game.
- Mutation coverage grew with the change rather than after it: 28 → **31 of 31** caught at
  the time of that pass; 37 of 37 after the tenth pass's follow-up work.

### Added by the tenth pass

- **Items 43 and 44 are closed, externally**, and the pass raised and fixed item 47,
  taking the ledger to **45 of 47**. Only 41 and 42 remain and both need a live client, so
  for the first time in ten passes there is no open work that can be done offline.
- **One tooling defect found and fixed (item 47).** `tools/fault_inject.py` restored
  mutated sources through `pathlib.Path.write_text`, which translates `\n` to CRLF on
  Windows, so every run rewrote line endings against `* text=auto eol=lf`. Six shipped
  sources sat at `i/lf w/crlf` — committed blobs unaffected, and `git diff` silent because
  check-in normalisation makes a CRLF working file compare equal to an LF blob, which is
  why the symptom was `git status` reporting modifications with an empty diff. Restoring
  byte-exact then turned two multi-line anchors into silent skips, so anchors are now
  matched against the file's real newline. Working tree re-checked-out to LF; zero
  `w/crlf` files remain and a repeat injection run leaves the tree clean.
- **luacheck is clean and enforced**: 29 warnings → **0 warnings, 0 errors across 53
  files**, achieved by 48 insertions against 48 deletions with no behaviour change. CI now
  runs `tools/check_lua_quality.py`, which strict-parses every `.lua` with `luac5.1 -p`,
  runs the existing harnesses, then demands a zero-warning lint.
- **`luac -p` is genuinely new coverage.** It parses every `.lua` file, including ones no
  harness loads and files absent from any TOC, which the TOC-driven syntax harnesses
  cannot reach.
- **Verified the harnesses survived the workflow rewrite.** The explicit `run_tests.py`
  step disappeared from the workflow — this project's most-repeated regression — but the
  new tool invokes it by subprocess, confirmed by reading the tool.
- **A 9-page `wiki/` was added** (1,530 lines) and `.pkgmeta` correctly excludes it; the
  rebuilt archive is still 33 entries with no wiki, audit, results or tooling leakage.
- **One documentation defect**: `LUA51-AUDIT.md` claims the repository already had
  `luac5.1 -p` and `luacheck --max-warnings 0` in the workflow at the baseline. It did not
  — verified with `git show b712070:.github/workflows/package.yml`, which has only
  `lua5.1` and the harness step. The document understates its own contribution.
- **Both carried-forward code smells are now closed, as ledger items 48 and 49**, and one
  had been diagnosed wrongly. `A.GetActivityType` closed over two locals of
  `A:BuildRequestUI`, so converting the call sites alone would have fixed nothing; the
  state moved to `A.activityTypes` / `A.activityType` in `Core.lua`, which also removed an
  ordering dependency and let `tests/variations.lua` drop its stub and drive the real
  method — the cycling arithmetic had been covered by nothing. `A.messageVariantBags` was
  never an unbounded-growth problem, because language and accent are single-valued per
  profile; the defect was stale bags surviving a profile change, now cleared by
  `V:ResetVariantBags` on any accepted option write. An LRU and an entry cap were both
  rejected. Six new fault-injection entries cover the two fixes, taking the mutation check
  to **37 of 37**.
