# AI-DLC State Tracking

## Project Information
- **Project Name**: ForeverCommsBundle — Forever Comms Voice **0.1.0-beta**, Forever Group
  Comms **0.2.0-beta**, Forever Guild Comms **0.5.0-beta**
- **Project Type**: Brownfield, multi-package
- **Start Date**: 2026-10-18T23:45:00Z
- **Current Stage**: INCEPTION - Reverse Engineering (fourth rerun complete, awaiting user approval)

## Workspace State
- **Existing Code**: Yes
- **Programming Languages**: Lua 5.1 (addons), XML (key bindings), PowerShell and Batch
  (installers), YAML (packaging workflows)
- **Build System**: None for compilation; BigWigsMods/packager intended on a `v*` tag but
  **currently inert** — see below
- **Project Structure**: **Monorepo with three flat World of Warcraft addon packages**,
  22 shipped modules total. Changed this pass from a single flat addon
- **Reverse Engineering Needed**: Completed five times; artifacts current as of 2026-10-19T09:52:22Z
- **Workspace Root**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`

## Packages

| Package | Version | Type | Modules | Lines | Methods | Harnesses | SavedVariables |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ForeverCommsVoice` | 0.1.0-beta | Shared library | 7 | 860 | 18 | 1 | `ForeverCommsVoiceCharDB` |
| `ForeverGuildComms` | 0.5.0-beta | Application | 9 | 1,557 | 64 | 11 | `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB` |
| `ForeverGroupComms` | 0.2.0-beta | Application | 6 | 978 | 47 | 1 | `ForeverGroupCommsDB` |

Both applications declare `## Dependencies: ForeverCommsVoice`. The library depends on
neither.

## Code Location Rules
- **Application Code**: Workspace root, inside the three package folders (NEVER in aidlc-docs/)
- **Documentation**: aidlc-docs/ only
- **Project-specific constraints**:
  - Each addon folder must be named exactly after its addon, with a matching
    `<Addon>.toc` inside it, and source files stay flat.
  - `Bindings.xml` ships from the addon root in GuildComms and GroupComms and must **not**
    be listed in either TOC.
  - `ForeverCommsVoice` must install before either consumer; both refuse to load without it.

## Git State at Analysis Time
- `HEAD` = `a35a168` "Initial commit", equal to `origin/main`
- Remote: `git@github.com:mreillyorg/ForeverCommsBundle.git`
- Staged: `.gitattributes` only
- Untracked: `.kiro/`, `ForeverCommsVoice/`, `ForeverGroupComms/`, `ForeverGuildComms/`,
  `aidlc-docs/`, `install/`
- **The entire restructure is uncommitted.** This pass was explicitly requested before the
  first commit.

## Extension Configuration
Not yet determined. Extension opt-in questions are presented during Requirements
Analysis, which has not run. Only the three `*.opt-in.md` files were loaded at workflow
start; no full extension rule files have been loaded, so no extension rule was enforced
or evaluated during Reverse Engineering.

| Extension | Enabled | Decided At |
| --- | --- | --- |
| security/baseline | Undecided | - |
| resiliency/baseline | Undecided | - |
| testing/property-based | Undecided | - |

## Stage Progress

### INCEPTION
- [x] Workspace Detection - Completed 2026-10-18T23:45:00Z - Brownfield
- [x] Workspace Detection - Re-run 2026-10-19T09:52:22Z - Brownfield, now multi-package
- [x] Reverse Engineering - Completed 2026-10-18T23:52:00Z against 0.1.0-beta
- [x] Reverse Engineering - Rerun completed 2026-10-19T00:52:00Z against 0.2.0-beta
- [x] Reverse Engineering - Second rerun completed 2026-10-19T02:40:00Z against 0.4.1-beta
- [x] Reverse Engineering - Third rerun completed 2026-10-19T03:20:00Z against 0.4.3-beta
- [x] Reverse Engineering - **Fourth rerun** completed 2026-10-19T09:52:22Z against the
      three-package bundle - awaiting approval
- [ ] Requirements Analysis - Not started (user has scoped all five runs to end after Reverse Engineering)
- [ ] User Stories - Not assessed
- [ ] Workflow Planning - Not started
- [ ] Application Design - Not assessed
- [ ] Units Generation - Not assessed

### CONSTRUCTION
- [ ] Not started

### OPERATIONS
- [ ] Placeholder stage

## Reverse Engineering Status
- [x] Reverse Engineering - Fourth rerun completed on 2026-10-19T09:52:22Z
- **Artifacts Location**: `aidlc-docs/inception/reverse-engineering/`
- **Artifacts target**: the three-package bundle. All nine regenerated from scratch rather
  than amended, because the previous set described a workspace root that was itself an
  addon folder.
- **Change span covered**: the extraction of `Languages.lua`, `Accents.lua`,
  `RaceProfiles.lua` and `MessageVariants.lua` out of ForeverGuildComms into the new
  `ForeverCommsVoice` library; the new `VoiceBridge.lua` adapter; the `Render` pipeline
  with scoped catalogs; the entirely new `ForeverGroupComms` addon including its quest-sync
  protocol; the rework of eight GuildComms harnesses for the cross-package layout; and the
  new combined root installer.

## Reverse Engineering History

| Run | Date | Target | Trigger | Outcome |
| --- | --- | --- | --- | --- |
| 1 | 2026-10-18T23:52Z | 0.1.0-beta | First brownfield pass | 9 artifacts; gate never answered |
| 2 | 2026-10-19T00:52Z | 0.2.0-beta | Explicit rerun; artifacts stale | 3 of 15 findings resolved |
| 3 | 2026-10-19T02:40Z | 0.4.1-beta | Explicit rerun; three releases stale | 6 of 17 resolved, 1 half |
| 4 | 2026-10-19T03:20Z | 0.4.3-beta | Explicit rerun; verified real change first | 3 of 19 resolved, incl. both findings first raised against 0.1.0 |
| 5 | 2026-10-19T09:52Z | Bundle (3 packages) | Explicit rerun before first commit; library extraction + new addon | **0 of 19 resolved**; 11 new findings; first multi-package pass |

## Project Growth Across Passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle |
| --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | **22** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | **3,395** |
| Public methods | 38 | 45 | 62 | 64 | **129** |
| Business transactions | 9 | 10 | 13 | 14 | **37** |
| Offline harnesses | 1 | 4 | 9 | 11 | **13** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | **29%** |
| Modules with no harness | 6 | 3 | 1 | **0** | **4** |
| Event dispatchers | 1 | 1 | 1 | 1 | **3** |
| Inbound untrusted-data paths | 0 | 0 | 0 | 0 | **1** |

## Notes

- The user has scoped every run to end after Reverse Engineering, so the workflow stops at
  the approval gate rather than auto-advancing to Requirements Analysis.
- **The extraction itself is well executed.** The library registers no chat or combat
  events and sends nothing; `VoiceBridge.lua` is 26 lines and aliases the moved data tables
  onto the old field names, which is why `Options.lua` and `TitanMenu.lua` needed no edits;
  GroupComms genuinely reuses all 8 languages and 29 accents rather than reimplementing
  them.
- **Three pre-commit blockers**, all in plumbing rather than code:
  1. All three `package.yml` files and all three `.pkgmeta` files are positioned for a
     repository whose root is an addon folder. GitHub Actions reads workflows only from the
     checkout root, which has no `.github` directory, so **no tag-driven packaging will
     run for any package**. All three also listen on an unprefixed `v*` while the packages
     sit at 0.1.0, 0.2.0 and 0.5.0.
  2. **Neither per-addon installer mentions `ForeverCommsVoice`.** An existing GuildComms
     user who updates with the familiar installer gets an addon the client refuses to load.
     The combined root installer is correct, but nothing steers a returning user to it.
  3. **Nine stale version strings.** GroupComms' installer trio still says 0.1.0;
     GuildComms' README title, `PACKAGING.md`, installer `.cmd` and `INSTALL-README.txt`
     still say 0.4.3 or 0.4.2. `PACKAGING.md` additionally lists four modules that were
     moved out.
- **One functional regression**: Expressive accent strength lost its
  trailing-period-to-exclamation conversion when the behaviour was reimplemented in
  `V:Render` instead of moved. It affects `nightelf`, `tauren`, `forsaken`, `bloodelf` and
  `draenei`, and the original code survives only in the now-dead `V:VoiceText`. Two-line fix.
- **New cross-addon side effect**: `A.char.voice` and `ForeverCommsVoiceCharDB.voice` are
  the same table object at runtime, so GuildComms' Restore Defaults silently resets the
  voice profile GroupComms is using and leaves Voice's own panel stale.
- **Verification coverage regressed** despite test lines growing. 4 of 22 modules are
  loaded by no harness (`Voice/Options.lua`, `Group/UI.lua`, `Group/Options.lua`,
  `Group/Broker.lua`), and **13 of 22 have no compile check** because only GuildComms has a
  syntax harness. Test share of source fell from 40% to 29%. The project held the
  "every module covered" property for exactly one pass.
- **Best new asset**: `ForeverCommsVoice/tests/integration.lua`, 64 lines, the only harness
  that loads all three addons. It verifies the migration latch in both directions, both
  render paths against the real adapters, link preservation, the `useSharedVoice` opt-out,
  accent invalidation on language change, and — implicitly — that GuildComms' and Voice's
  duplicated default template tables are still identical.
- **First inbound untrusted-data path in the project's history**, and it is handled well:
  GroupComms' quest protocol applies eleven distinct validations before storing an ID,
  discloses only active quest IDs, answers completion queries only for IDs a peer already
  revealed, bounds all reassembly state, and uses an epoch rule so a stale reply cannot
  produce a false claim that another player lacks a quest.
- **All eight `.kiro/steering/` files describe a single flat addon** and are now the least
  accurate documentation in the repository. `testing.md` says "nine harnesses" and names
  modules that moved; `structure.md` gives a seven-row table for one package;
  `product.md`'s unscoped "no addon-to-addon comms" non-goal now reads as contradicting
  GroupComms' headline feature, because the rule predates the second addon.
- **Top recommendation unchanged for a fourth consecutive pass**: nothing runs the
  harnesses or checks the version strings. It would have caught four of the seven
  pre-commit items on its own, and the suite it would run has tripled in scope since the
  recommendation was first made.
- No code was executed in any of the five runs; no Lua interpreter is installed on this
  machine. None of the 13 harnesses is reported as passing.
