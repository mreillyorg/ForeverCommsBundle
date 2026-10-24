# AI-DLC State Tracking

## Project Information
- **Project Name**: ForeverCommsBundle — Forever Comms Voice **0.2.2-beta**, Forever Group
  Comms **0.3.4-beta**, Forever Guild Comms **0.6.3-beta**
- **Project Type**: Brownfield, multi-package
- **Start Date**: 2026-10-18T23:45:00Z
- **Current Stage**: INCEPTION - Reverse Engineering (eighth pass complete, awaiting user approval)

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
  2026-10-25T02:30:00Z against commit `a64ac2a`
- **Workspace Root**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`

## Packages

| Package | Version | Type | Modules | Lines | Methods | Harnesses | SavedVariables |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ForeverCommsVoice` | 0.2.2-beta | Shared library | 9 | 1,221 | 33 | 8 | `ForeverCommsVoiceCharDB` |
| `ForeverGuildComms` | 0.6.3-beta | Application | 9 | 1,560 | 67 | 13 | `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB` |
| `ForeverGroupComms` | 0.3.4-beta | Application | 7 | 1,146 | 53 | 7 | `ForeverGroupCommsDB` |

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
- `HEAD` = `a64ac2a` "3rd round of Kiro changes", equal to `origin/main` and pushed
- Working tree at analysis time: **clean**
- Baseline for this pass: `57f7cdc`, spanning three commits — `8166b8b`, `6cf2f38`,
  `a64ac2a` — 67 files changed, 5,244 insertions, 1,202 deletions, 14 added, 53 modified
- Recent history: `63222ea` → `57f7cdc` → `8166b8b` → `6cf2f38` → `a64ac2a`

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
- [x] Reverse Engineering - **Seventh rerun** completed 2026-10-25T02:30:00Z against
      `a64ac2a` (0.2.2 / 0.6.3 / 0.3.4) - awaiting approval
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
- [x] Reverse Engineering - Eighth pass completed on 2026-10-25T02:30:00Z
- **Artifacts Location**: `aidlc-docs/inception/reverse-engineering/`
- **Artifacts target**: commit `a64ac2a` — Voice 0.2.2-beta, GuildComms 0.6.3-beta,
  GroupComms 0.3.4-beta. **All nine artifacts regenerated**, because every one of them
  described a state that had been inverted rather than merely aged.
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

## Project Growth Across Passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | 0.x.1 | `57f7cdc` | `a64ac2a` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | 22 | 25 | **25** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | 3,388 | 3,806 | **3,927** |
| Public methods | 38 | 45 | 62 | 64 | 129 | 129 | 152 | **153** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | 13 | 17 | **28** |
| Harness lines | 72 | 207 | 589 | 816 | 1,029 | 1,215 | 1,215 | **4,138** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | 30% | 32% | **105%** |
| Modules with no harness | 6 | 3 | 1 | 0 | 4 | 4 | 5 | **0** |
| Suite passing | n/a | n/a | n/a | n/a | not run | not run | NO — 3/17 | **YES — 28/28** |
| Linter configured | No | No | No | No | No | No | No | **Yes — 0 errors** |
| Assertions mutation-verified | No | No | No | No | No | No | No | **Yes — 28/28** |
| Active CI workflows | 1 | 1 | 1 | 1 | 0 | 1 | 1 | **1** |
| CI runs the harnesses | No | No | No | No | No | Yes | No | **Yes** |

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
- **Still open — two carried-forward code smells**, neither a defect:
  `A.GetActivityType` is a dot-called closure (`ForeverGuildComms/UI.lua:145`), and
  `A.messageVariantBags` is unbounded (`ForeverCommsVoice/Core.lua:14`).
- **The largest risk is unchanged and is not a code risk.** Nothing in this bundle has
  ever been loaded by the client it targets. Offline confidence is now high; live
  confidence is still zero. Items 41 and 42 are the only ones that address it, and no
  further harness work can.
