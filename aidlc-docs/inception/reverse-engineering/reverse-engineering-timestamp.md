# Reverse Engineering Metadata

**Analysis Date**: 2026-10-25T03:10:00Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: ForeverCommsVoice 0.2.2-beta, ForeverGuildComms 0.6.3-beta,
ForeverGroupComms 0.3.4-beta
**Target commit**: `b712070` — "corrections from Kiro found in fixing reverse engineering
bugs", clean tree, pushed to `origin/main`
**Run**: 9th reverse-engineering pass; 5th multi-package pass
**Supersedes**: the pass of 2026-10-25T02:30:00Z, which describes commit `a64ac2a`
**Trigger**: Explicit user request
**Diff baseline**: `a64ac2a`, spanning one commit — `b712070`

No version changed in this span. The three packages stay at 0.2.2-beta, 0.6.3-beta and
0.3.4-beta; the change is behavioural and test-side only.

## Why this pass exists

`b712070` carries two things at once: the artifact regeneration performed by the previous
pass, **and** the code change that pass's findings prompted. So the artifacts committed in
it describe `a64ac2a` while the code around them is one step further on. This pass
resyncs them.

This is a small, targeted delta rather than a rewrite. The previous pass regenerated all
nine artifacts from scratch against `a64ac2a`; re-deriving them wholesale would churn the
documents without improving them. Sections touched by the change were updated and the
metrics re-measured; the rest was verified as still accurate and left alone.

## Artifacts Generated

- [x] `reverse-engineering-timestamp.md` — regenerated
- [x] `dependencies.md` — updated: the dependency is now enforced at load in both consumers
- [x] `code-quality-assessment.md` — updated: verification counts, findings, patterns
- [x] `architecture.md` — updated: architectural invariants and the dispatcher table
- [x] `code-structure.md` — updated: line counts, `VoiceBridge` role, fail-closed pattern
- [x] `component-inventory.md` — updated: line and harness-line counts
- [x] `technology-stack.md` — updated: verification counts
- [x] `business-overview.md` — updated: closing metrics
- [x] `api-documentation.md` — header only; the public API surface did not change

## Change scope

| Commit | Content |
| --- | --- |
| `b712070` | Ledger items 45 and 46. Item 45 records the **rejection** of embedding `ForeverCommsVoice` as a LibStub-style library. Item 46 makes **both** consumers refuse to load when the library is absent, from the first statement of each `Core.lua` |

**Span total**: 31 files changed, 1,551 insertions, 1,202 deletions. The insertion count
is dominated by the previous pass's artifacts; the code change itself is 42 shipped lines
across three files plus 119 harness lines across 14 files.

| Area | Change |
| --- | --- |
| `ForeverGuildComms/Core.lua` | +16 — load-time library guard as the first statement |
| `ForeverGuildComms/VoiceBridge.lua` | +6/−2 — the old `error()` becomes a quiet `return`, since `Core.lua` has already refused |
| `ForeverGroupComms/Core.lua` | +20 — the same guard, previously absent entirely |
| Harnesses | 14 files — a one-line library stub or a load-order fix, because in game the TOC dependency guarantees the library loads first |
| Regression coverage | New blocks in `ForeverGuildComms/tests/verify.lua` and `ForeverGroupComms/tests/safety.lua` |
| `tools/fault_inject.py` | +3 entries, 28 → 31 |

## Total Files Analyzed

**112 project files**, excluding `.git/`, `aidlc-docs/`,
`.kiro/aws-aidlc-rule-details/` and build output. Unchanged from the previous pass; no
file was added or removed in this span.

| Category | Count | Depth this pass |
| --- | --- | --- |
| Shipped Lua modules | 25 | The 3 changed modules read in full; line and method counts re-measured across all 25 |
| Offline harnesses | 28 | The 14 changed read as diffs; the 2 new regression blocks read in full; line counts re-measured across all 28 |
| TOC manifests | 3 | Re-read for version and metadata; unchanged |
| Release tooling | 9 | `fault_inject.py` diff read |
| Markdown docs | 8 | `SUGGESTED-CHANGES.md` items 45 and 46 read in full |
| Git state | — | `log`, `show --stat`, `diff --shortstat` at the baseline |

## Verification Performed

Executed, not inferred.

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 0 — PASSED: 28, FAILED: 0, TOTAL: 28** |
| `python tools/fault_inject.py` | **Exit 0 — 31 of 31 injected faults caught** (28 → 31 this span) |
| `luacheck .` (1.2.0) | **Exit 1 — 29 warnings, 0 errors in 53 files.** Nonzero is luacheck's warning status; the change adds no new warning |
| `python tools/package.py` | Exit 0 — `ForeverCommsBundle-0.6.3-beta.zip`, 33 entries |
| `python tools/check_bigwigs_bundle.py` | **Exit 0** — all three packages version-consistent across four locations |
| `python tools/package.py --source` | Exit 0 |
| `python tools/verify_package.py` | **Exit 0** |
| Library guard present in both `Core.lua` | **Yes**, confirmed by pattern search in both packages |
| `SetScript("OnUpdate"` across all 25 modules | **Zero** |
| Working tree / sync | Clean; `main` level with `origin/main` |

**Not verified**: the BigWigs release path, which is a GitHub Action and cannot run
locally; the local mirror was run instead. **Nothing in this bundle has been executed
against a live Forever client.** True of every pass to date.

## Metrics

| Metric | Voice | Guild | Group | Bundle | Δ vs `a64ac2a` |
| --- | --- | --- | --- | --- | --- |
| Version | 0.2.2-beta | 0.6.3-beta | 0.3.4-beta | — | — |
| Shipped Lua modules | 9 | 9 | 7 | **25** | — |
| Shipped Lua lines | 1,221 | 1,580 | 1,166 | **3,967** | +40 |
| Public methods | 33 | 67 | 53 | **153** | — |
| Offline harnesses | 8 | 13 | 7 | **28** | — |
| Harness lines | 1,053 | 1,490 | 1,714 | **4,257** | +119 |
| Harnesses failing | 0 | 0 | 0 | **0** | — |
| Modules no harness loads | 0 | 0 | 0 | **0** | — |
| Injected faults caught | — | — | — | **31 / 31** | +3 |
| Events / dispatchers | 1 / 1 | 14 / 1 | 10 / 1 | 25 / 3 | — |
| SavedVariables tables | 1 | 2 | 1 | **4** | — |

Test lines are **107%** of shipped Lua, up from 105%.

## Comparison across all nine passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | 0.x.1 | `57f7cdc` | `a64ac2a` | **`b712070`** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | 3 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | 22 | 25 | 25 | **25** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | 3,388 | 3,806 | 3,927 | **3,967** |
| Public methods | 38 | 45 | 62 | 64 | 129 | 129 | 152 | 153 | **153** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | 13 | 17 | 28 | **28** |
| Harness lines | 72 | 207 | 589 | 816 | 1,029 | 1,215 | 1,215 | 4,138 | **4,257** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | 30% | 32% | 105% | **107%** |
| Modules with no harness | 6 | 3 | 1 | 0 | 4 | 4 | 5 | 0 | **0** |
| Suite passing | n/a | n/a | n/a | n/a | not run | not run | NO — 3/17 | YES — 28/28 | **YES — 28/28** |
| Faults caught | — | — | — | — | — | — | — | 28/28 | **31/31** |
| Linter configured | No | No | No | No | No | No | No | Yes | **Yes — 0 errors** |
| CI runs the harnesses | No | No | No | No | No | Yes | No | Yes | **Yes** |
| Recommendations resolved | — | 3/15 | 6/17 | 3/19 | 0/19 | 10/25 | 2/20 | 40/44 | **42/46** |

## Headline findings

1. **The hard library dependency is now enforced at load in both consumers**, as the first
   statement of each `Core.lua`. Previously GroupComms had no such check and degraded
   silently, while GuildComms checked from `VoiceBridge.lua` — the second TOC file — by
   which point the namespace global was published and the event dispatcher created, so
   `ADDON_LOADED` still reached `A:Initialize()` and the addon half-ran before failing at
   render time. Both now go inert with one clear message.
2. **The motivation was a correctness hole, not consistency.** With the library absent,
   GroupComms' `A:Stage` falls back to the local approval list, whose `A:Approve` calls
   `A:Send(kind, vars)` and **re-renders** rather than replaying the captured text. With
   `randomMessages` on, the message sent could differ from the one the player reviewed,
   violating "the Send button must send exactly the wording shown in the preview".
3. **Embedding the library was considered and rejected**, recorded as ledger item 45. The
   blocking reason is that `ForeverCommsVoice` declares SavedVariables, which an embedded
   library cannot do — see `dependencies.md` for the full argument.
4. **Mutation coverage grew with the change rather than after it**: three new fault
   entries, 31 of 31 caught. The regression blocks assert the refusal, the message, that
   nothing is left half-built, and that `VoiceBridge` does not raise a second error.
5. **14 harnesses needed adjusting**, which is the real cost of this change. None of them
   had been modelling the shipped reality: every one loaded a consumer's `Core.lua` with
   no library present, a state the TOC dependency makes impossible in game.
6. **Two carried-forward code smells remain open**, unchanged: `A.GetActivityType` is a
   dot-called closure (`ForeverGuildComms/UI.lua:145`) and `A.messageVariantBags` is
   unbounded (`ForeverCommsVoice/Core.lua:14`).
7. **Four ledger items remain open**: 41 and 42 need a live client, 43 is the 29 cosmetic
   luacheck warnings, 44 is wiring luacheck into CI.
8. **The largest risk is unchanged and is not a code risk.** Nothing in this bundle has
   ever been loaded by the client it targets. Items 41 and 42 are the only ones that
   address it.
