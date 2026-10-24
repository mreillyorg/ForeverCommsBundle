# Reverse Engineering Metadata

**Analysis Date**: 2026-10-19T13:30:00Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: ForeverCommsVoice 0.2.1-beta, ForeverGroupComms 0.3.3-beta,
ForeverGuildComms 0.6.2-beta
**Run**: 7th reverse-engineering pass; 3rd multi-package pass
**Supersedes**: the pass of 2026-10-19T11:30:00Z, which describes commit `62c3853`
**Trigger**: Explicit user request
**Diff baseline**: `62c3853`, spanning two commits — `63222ea` (test automation) and
`57f7cdc` (queue, Titan menu, BigWigs packaging)

## Artifacts Generated

- [x] `code-quality-assessment.md` — regenerated
- [x] `component-inventory.md` — regenerated
- [x] `reverse-engineering-timestamp.md` — regenerated
- [x] `architecture.md` — updated
- [x] `code-structure.md` — updated
- [x] `api-documentation.md` — updated
- [x] `dependencies.md` — updated
- [x] `technology-stack.md` — updated
- [x] `business-overview.md` — updated

## Change scope

Verified before regenerating. **The baseline had moved further than expected**: the user's
request followed my own test-automation commit, but `HEAD` had since advanced to a second,
larger commit that was not part of this session.

| Commit | Content |
| --- | --- |
| `63222ea` | Test automation: `tools/run_tests.py`, CI test step, three TOC-derived syntax harnesses, the `keybindings.lua` 5.1 fix, `verify_package.py` cleanup |
| `57f7cdc` | **Not from this session.** Shared review queue, GroupComms Titan menu, common styling, BigWigs packaging via a root `.pkgmeta`. **Reverts much of `63222ea`** |

| Area | Change across the span |
| --- | --- |
| New shared modules | `ForeverCommsVoice/Queue.lua` 148, `QueueUI.lua` 136 |
| New consumer module | `ForeverGroupComms/TitanMenu.lua` 114 |
| Shrunk by consolidation | `ForeverGuildComms/UI.lua` −87 |
| New harnesses | `queue.lua` 89, `queue_ui.lua` 65, plus 3 syntax harnesses |
| Release pipeline | Replaced twice: offline Python builders, then BigWigs via root `.pkgmeta` + `check_bigwigs_bundle.py` |
| Versions | Voice 0.1.1→0.2.1, GroupComms 0.2.1→0.3.3, GuildComms 0.5.1→0.6.2 |

## Total Files Analyzed

**84 project files**, excluding `aidlc-docs/` and `.kiro/aws-aidlc-rule-details/`.

| Category | Count | Depth |
| --- | --- | --- |
| Shipped Lua modules | 25 | `Queue.lua` read in full; the 13 changed modules read as diffs; method counts measured across all 25 |
| TOC manifests | 3 | Diffs read in full |
| Offline harnesses | 17 | The 2 new queue harnesses and 3 syntax harnesses read; the reverted ones diffed |
| Release tooling | 8 | Root `.pkgmeta`, `check_bigwigs_bundle.py`, the root workflow and all 3 nested workflow diffs read in full |
| Markdown docs | 7 | Version-swept; `PACKAGING.md` and root `README.md` diffs read |
| Steering | 9 | Checked for staleness against the replaced pipeline |
| Git state | — | `log`, scoped `diff --stat` at two baselines, targeted `diff` |

## Verification Performed

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 1 — PASSED: 14, FAILED: 3, TOTAL: 17** |
| Each 0.5.1 fix located in source | All three present and intact |
| Search for the deleted regression blocks | 0 references in `integration.lua`; 0 in `settings.lua` |
| `python tools/verify_package.py` | **Exit 1** — `ForeverGuildComms/README.md does not mention version 0.6.2-beta` |
| Version sweep across TOC / `Core.lua` / README / installer `.cmd` | 7 stale strings |
| `SetScript("OnUpdate"` search across all 25 modules | Exactly one, `Queue.lua:70` |
| Queue integration points mapped | `V:Enqueue` called from both consumers' `Core.lua`; `V:PendingCount` from GroupComms `TitanMenu`/`UI` and GuildComms `Core` |
| Mechanical re-measurement | 25 modules, 3,806 lines, 152 methods, 17 harnesses, 1,215 test lines |

**Not verified**: the BigWigs release path. `BigWigsMods/packager@v2` is a GitHub Action
and cannot run locally, so unlike the previous span's offline builders the pipeline could
not be executed. `tools/check_bigwigs_bundle.py` was read but not run, as it requires the
`.release/` output. Nothing has been tested against a live Forever client.

## Metrics

| Metric | Voice | Guild | Group | Bundle | Δ |
| --- | --- | --- | --- | --- | --- |
| Version | 0.2.1-beta | 0.6.2-beta | 0.3.3-beta | — | all bumped |
| Shipped Lua modules | 9 | 9 | 7 | **25** | +3 |
| Shipped Lua lines | 1,207 | 1,491 | 1,108 | **3,806** | +418 |
| Public methods | 35 | 65 | 52 | **152** | +23 |
| Offline harnesses | 4 | 11 | 2 | **17** | +4 |
| Harness lines | 243 | 828 | 144 | **1,215** | +186 |
| **Harnesses failing** | **2** | **1** | 0 | **3** | +3 |
| Modules no harness loads | 1 | 0 | 4 | **5** | +1 |
| SavedVariables tables | 1 | 2 | 1 | **4** | — |

## Comparison across all seven passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | 0.x.1 | This pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | 22 | **25** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | 3,388 | **3,806** |
| Public methods | 38 | 45 | 62 | 64 | 129 | 129 | **152** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | 13 | **17** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | 30% | **32%** |
| Modules with no harness | 6 | 3 | 1 | 0 | 4 | 4 | **5** |
| **Suite passing** | n/a | n/a | n/a | n/a | not run | not run | **NO — 3 of 17 fail** |
| CI runs the harnesses | No | No | No | No | No | **Yes** | **No — regressed** |
| Recommendations resolved | — | 3/15 | 6/17 | 3/19 | 0/19 | 10/25 | **2/20, 1 regressed** |

This is the first pass where the suite is known to be failing, because it is the first
pass where the suite could be run at all and was not green.

## Headline findings

1. **The suite is red: 3 of 17 harnesses fail.** Verified by execution, not inferred.
2. **The two new queue harnesses resolve paths from the suite root**, the opposite of the
   convention every other harness, the runner and the steering all use. They cannot pass as
   written.
3. **`keybindings.lua`'s Lua 5.1 fix was reverted**, so that harness again cannot execute
   on the mandated interpreter.
4. **CI no longer runs the Lua harnesses.** The step was added in `63222ea` and removed in
   `57f7cdc`. Sixth consecutive pass as the top recommendation.
5. **Both 0.5.1 regression tests were deleted.** All three underlying code fixes survive
   and were individually verified, but they are now unguarded.
6. **Seven stale version strings, and the check that catches them was retired in the same
   commit.** Running `verify_package.py` reproduces the failure exactly.
7. **The release pipeline was replaced a second time**, now BigWigs via a root `.pkgmeta`
   with `move-folders`, leaving four offline release tools orphaned but still documented.
8. **The queue itself is good work**: transient by design with the reason recorded, bounded
   at 100, expiry re-checked before an approving click, `pcall` around the consumer
   callback, a `"stale"` reason contract, and monotonic IDs that incidentally closed a
   finding carried since 0.4.1.
9. **`Queue.lua` uses `OnUpdate`**, the only one in the bundle and a direct violation of
   `lua-style.md`.
10. **Steering is stale in the opposite direction from last pass** — it now claims CI runs
    the harnesses and that the Python builder is the CI path.
