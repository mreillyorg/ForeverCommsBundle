# Reverse Engineering Metadata

**Analysis Date**: 2026-10-25T02:30:00Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: ForeverCommsVoice 0.2.2-beta, ForeverGuildComms 0.6.3-beta,
ForeverGroupComms 0.3.4-beta
**Target commit**: `a64ac2a` — "3rd round of Kiro changes", clean tree, pushed to `origin/main`
**Run**: 8th reverse-engineering pass; 4th multi-package pass
**Supersedes**: the pass of 2026-10-19T13:30:00Z, which describes commit `57f7cdc`
**Trigger**: Explicit user request
**Diff baseline**: `57f7cdc`, spanning three commits — `8166b8b`, `6cf2f38`, `a64ac2a`

## Artifacts Generated

- [x] `reverse-engineering-timestamp.md` — regenerated
- [x] `code-quality-assessment.md` — regenerated
- [x] `component-inventory.md` — regenerated
- [x] `architecture.md` — regenerated
- [x] `code-structure.md` — regenerated
- [x] `api-documentation.md` — regenerated
- [x] `dependencies.md` — regenerated
- [x] `technology-stack.md` — regenerated
- [x] `business-overview.md` — regenerated

## Change scope

| Commit | Content |
| --- | --- |
| `8166b8b` | Remediation items 1–15: the three failing harnesses fixed, the CI test step restored, two deleted regression tests restored, 11 stale version strings corrected, the version check ported into `check_bigwigs_bundle.py` and widened to four locations, `tools/package.py` rewritten as a `.pkgmeta`-driven mirror of BigWigs, all eight steering files rewritten |
| `6cf2f38` | Remediation items 16–40: `OnUpdate` removed, `V:Render` split, dead code deleted, `A:FillDefaults` / `A:CanFillRole` extracted, the approval floor and `reviewAutoShow` added, GroupComms canvas callbacks implemented, `.luacheckrc` added, the Expressive scope decided and documented, and **11 new harnesses** |
| `a64ac2a` | Version bump of all three packages across the four canonical locations each, plus release notes in all four READMEs |

**Span total**: 67 files changed, 5,244 insertions, 1,202 deletions. 14 files added,
53 modified. No files deleted.

| Area | Change across the span |
| --- | --- |
| New harnesses | 11 — `bytelimit`, `expressive`, `options`, `parity` (Voice); `alertsui`, `roster` (Guild); `outbox`, `protocol`, `safety`, `titanmenu`, `ui` (Group) |
| New tooling | `.luacheckrc`, `tools/fault_inject.py` |
| New tracking | `SUGGESTED-CHANGES.md` — 44-item remediation ledger |
| New settings | GuildComms `reviewAutoShow`, `A.approvalFloorSeconds` |
| Removed | `V:VoiceText`, `V:ChooseMessageTemplate`, the `VoiceBridge` forwarder, the only `OnUpdate` |
| Versions | Voice 0.2.1→0.2.2, GuildComms 0.6.2→0.6.3, GroupComms 0.3.3→0.3.4 |

## Total Files Analyzed

**112 project files**, counted mechanically, excluding `.git/`, `aidlc-docs/`,
`.kiro/aws-aidlc-rule-details/` and build output.

By extension: 53 `.lua`, 16 `.md`, 6 `.cmd`, 5 `.ps1`, 5 `.py`, 4 `.pkgmeta`, 4 `.yml`,
3 `.png`, 3 `.tga`, 3 `.toc`, 3 `.txt`, 2 `.xml`, 2 `.gitignore`, plus `.gitattributes`,
`.luacheckrc` and `LICENSE`.

| Category | Count | Depth |
| --- | --- | --- |
| Shipped Lua modules | 25 | Method counts measured across all 25; the 11 changed modules read as diffs |
| Offline harnesses | 28 | All 11 authored this span read in full; the 17 pre-existing diffed |
| TOC manifests | 3 | Read in full for module list, version and metadata |
| Release tooling | 9 | `tools/*.py` ×5, `package.ps1`/`.cmd`, `run-tests.cmd`, root `.pkgmeta` |
| Linter config | 1 | `.luacheckrc` read in full and executed |
| Workflows | 4 | Root plus three nested, read for step order |
| Markdown docs | 8 | Version-swept; all four READMEs and both `PACKAGING.md` diffs read |
| Steering | 9 | Checked against current code |
| Installers | 11 | Four `.ps1`, four `.cmd`, three `INSTALL-README.txt` |
| Binary assets | 6 | Three `Media/Icon.tga`, three `ProjectIcon.png`; presence only |
| Git state | — | `log`, `diff --stat`/`--name-status` at the baseline, targeted diffs |

## Verification Performed

Everything below was executed, not inferred.

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 0 — PASSED: 28, FAILED: 0, TOTAL: 28** |
| `luacheck .` (1.2.0) | **Exit 1 — 29 warnings, 0 errors in 53 files.** Nonzero is luacheck's warning status |
| `python tools/fault_inject.py` | **Exit 0 — 28 of 28 injected faults caught** |
| `python tools/package.py` | Exit 0 — `ForeverCommsBundle-0.6.3-beta.zip`, 33 entries |
| `python tools/check_bigwigs_bundle.py` | **Exit 0** — version consistent across all four locations for all three packages |
| `python tools/package.py --source` | Exit 0 — four source archives |
| `python tools/verify_package.py` | **Exit 0** |
| Mechanical re-measurement | 25 modules, 3,927 lines, 153 methods, 28 harnesses, 4,138 test lines |
| `SetScript("OnUpdate"` across all 25 modules | **Zero** |
| Modules loaded by no harness | **Zero** |
| Working tree / sync | Clean; `main` level with `origin/main`; HEAD contained in `origin/main` |

**Not verified**: the BigWigs release path itself. `BigWigsMods/packager@v2` is a GitHub
Action and cannot run locally; `tools/package.py` mirrors it from the same root
`.pkgmeta` and was run instead. **Nothing in this bundle has been executed against a
live Forever client.** That remains true of every pass to date.

## Metrics

| Metric | Voice | Guild | Group | Bundle | Δ vs `57f7cdc` |
| --- | --- | --- | --- | --- | --- |
| Version | 0.2.2-beta | 0.6.3-beta | 0.3.4-beta | — | all bumped |
| Shipped Lua modules | 9 | 9 | 7 | **25** | — |
| Shipped Lua lines | 1,221 | 1,560 | 1,146 | **3,927** | +121 |
| Public methods | 33 | 67 | 53 | **153** | +1 |
| Offline harnesses | 8 | 13 | 7 | **28** | **+11** |
| Harness lines | 1,053 | 1,439 | 1,646 | **4,138** | **+2,923** |
| Harnesses failing | 0 | 0 | 0 | **0** | **−3** |
| Modules no harness loads | 0 | 0 | 0 | **0** | **−5** |
| Events / dispatchers | 1 / 1 | 14 / 1 | 10 / 1 | 25 / 3 | — |
| SavedVariables tables | 1 | 2 | 1 | **4** | — |

Test lines are now **105%** of shipped Lua, up from 32%.

## Comparison across all eight passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | 0.x.1 | `57f7cdc` | **This pass** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | 22 | 25 | **25** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | 3,388 | 3,806 | **3,927** |
| Public methods | 38 | 45 | 62 | 64 | 129 | 129 | 152 | **153** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | 13 | 17 | **28** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | 30% | 32% | **105%** |
| Modules with no harness | 6 | 3 | 1 | 0 | 4 | 4 | 5 | **0** |
| Suite passing | n/a | n/a | n/a | n/a | not run | not run | **NO — 3/17 fail** | **YES — 28/28** |
| Linter configured | No | No | No | No | No | No | No | **Yes — 0 errors** |
| CI runs the harnesses | No | No | No | No | No | Yes | **No — regressed** | **Yes** |
| Recommendations resolved | — | 3/15 | 6/17 | 3/19 | 0/19 | 10/25 | 2/20 | **40/44** |

This is the first pass where the suite is green, a linter exists, and the test assertions
have themselves been verified to fail when the behaviour they guard is removed.

## Headline findings

1. **Every finding from the previous pass is closed.** All ten of its headline items were
   either fixed or, in one case, withdrawn as incorrect. Section "Previous findings" in
   `code-quality-assessment.md` records each with its disposition.
2. **The suite is green and meaningfully so.** 28 of 28 harnesses pass, and
   `tools/fault_inject.py` confirms 28 of 28 deliberately injected faults are caught.
   Four assertions were initially too weak to notice their fault and were strengthened.
3. **Coverage is complete at the module level.** Every one of the 25 shipped modules is
   loaded by at least one harness; the previous pass had five that were loaded by none.
4. **A linter now exists and the codebase is clean under it.** `.luacheckrc` declares the
   28 globals the bundle may create and 58 read-only client APIs. 0 errors; the 29
   warnings are cosmetic and enumerated as item 43.
5. **Writing the linter config found a live defect.** `ForeverCommsVoice/Options.lua`
   gated `ADDON_LOADED` on a bare `ADDON`, nil outside `Core.lua`, so the Voice Settings
   panel was never registered until the user typed `/fcv`. Fixed and regression-tested.
6. **The release gate now checks four version locations per package** and runs on both
   the CI and local paths. All three packages pass at the bumped versions.
7. **Two carried-forward code smells remain open**: `A.GetActivityType` is a dot-called
   closure (`ForeverGuildComms/UI.lua:145`), and `A.messageVariantBags` is unbounded
   (`ForeverCommsVoice/Core.lua:14`). Neither is a defect; both are noted for a future pass.
8. **The in-game checklist has still never been walked.** No part of this bundle has run
   against a live Forever server. Offline confidence is now high; live confidence is
   unchanged at zero. This is the single largest remaining risk and no amount of harness
   work addresses it.
