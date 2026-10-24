# AI-DLC State Tracking

## Project Information
- **Project Name**: ForeverCommsBundle — Forever Comms Voice **0.2.1-beta**, Forever Group
  Comms **0.3.3-beta**, Forever Guild Comms **0.6.2-beta**
- **Project Type**: Brownfield, multi-package
- **Start Date**: 2026-10-18T23:45:00Z
- **Current Stage**: INCEPTION - Reverse Engineering (sixth rerun complete, awaiting user approval)

## Workspace State
- **Existing Code**: Yes
- **Programming Languages**: Lua 5.1 (addons), XML (key bindings), **Python 3 (release
  tooling, new)**, PowerShell and Batch (installers and Windows builder), YAML (CI)
- **Build System**: None for the addons. **Two equivalent offline release builders**,
  `tools/package.py` and `package.ps1`, plus `tools/verify_package.py`, driven by an
  active root-level GitHub Actions workflow. No external packager on the suite path
- **Project Structure**: Monorepo with three flat World of Warcraft addon packages,
  22 shipped modules, plus root-level build and install tooling
- **Reverse Engineering Needed**: Completed seven times; artifacts current as of 2026-10-19T13:30:00Z
- **Workspace Root**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`

## Packages

| Package | Version | Type | Modules | Lines | Methods | Harnesses | SavedVariables |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ForeverCommsVoice` | 0.2.1-beta | Shared library | 9 | 1,207 | 35 | 4 | `ForeverCommsVoiceCharDB` |
| `ForeverGuildComms` | 0.6.2-beta | Application | 9 | 1,491 | 65 | 11 | `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB` |
| `ForeverGroupComms` | 0.3.3-beta | Application | 7 | 1,108 | 52 | 2 | `ForeverGroupCommsDB` |

Both applications declare `## Dependencies: ForeverCommsVoice`. The library depends on
neither, and is now the **sole writer** of the shared voice profile.

## Code Location Rules
- **Application Code**: Workspace root, inside the three package folders (NEVER in aidlc-docs/)
- **Build and install tooling**: repository root — `tools/`, `install/`, `package.ps1`,
  `package.cmd`, `.github/workflows/`
- **Documentation**: aidlc-docs/ only
- **Project-specific constraints**:
  - Each addon folder must be named exactly after its addon, with a matching
    `<Addon>.toc` inside it, and source files stay flat.
  - `Bindings.xml` ships from the addon root in GuildComms and GroupComms and must **not**
    be listed in either TOC.
  - All three TOCs must declare `## IconTexture:` pointing at their own
    `Media\Icon`; the builders and the installer validate this exactly.
  - `ForeverCommsVoice` must install before either consumer. As of 0.5.1/0.2.1 this is
    enforced by construction: every consumer archive bundles the library, and the
    installer prepends it to any consumer-only selection.

## Git State at Analysis Time
- `HEAD` = `76ca527` "Add three-addon Forever Comms bundle with shared voice library",
  equal to `origin/main`
- Previous history: `a35a168` "Initial commit" (`.gitignore`, `LICENSE`, `README.md` only)
- Working tree at analysis time: **44 changed paths uncommitted** — the remediation work
  this pass analysed

## Extension Configuration
Not yet determined. Extension opt-in questions are presented during Requirements
Analysis, which has not run. Only the three `*.opt-in.md` files were loaded at workflow
start; no full extension rule file has been loaded, so no extension rule was enforced or
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
- [x] Reverse Engineering - **Fifth rerun** completed 2026-10-19T11:30:00Z against the
      0.1.1 / 0.2.1 / 0.5.1 remediation release - awaiting approval
- [ ] Requirements Analysis - Not started (user has scoped all six runs to end after Reverse Engineering)
- [ ] User Stories - Not assessed
- [ ] Workflow Planning - Not started
- [ ] Application Design - Not assessed
- [ ] Units Generation - Not assessed

### CONSTRUCTION
- [ ] Not started

### OPERATIONS
- [ ] Placeholder stage

## Reverse Engineering Status
- [x] Reverse Engineering - Fifth rerun completed on 2026-10-19T11:30:00Z
- **Artifacts Location**: `aidlc-docs/inception/reverse-engineering/`
- **Artifacts target**: the 0.1.1 / 0.2.1 / 0.5.1 remediation release. Four artifacts
  updated in place, five regenerated.
- **Change span covered**: the five fixes requested after the fourth rerun, plus two
  extras — the replacement of the release pipeline with two offline builders and a
  verifier behind a root workflow; the collapse of four installers into one real installer
  plus three shims that enforce dependency order; three patch version bumps with three
  drift locations deleted; the restored Expressive trailing-period conversion; the
  isolation of GuildComms' Restore Defaults from the shared voice profile; the delegation
  of `A:SetVoiceOption` to `V:SetOption`; and new icon assets for Voice and GroupComms.

## Reverse Engineering History

| Run | Date | Target | Trigger | Outcome |
| --- | --- | --- | --- | --- |
| 1 | 2026-10-18T23:52Z | 0.1.0-beta | First brownfield pass | 9 artifacts; gate never answered |
| 2 | 2026-10-19T00:52Z | 0.2.0-beta | Explicit rerun; artifacts stale | 3 of 15 findings resolved |
| 3 | 2026-10-19T02:40Z | 0.4.1-beta | Explicit rerun; three releases stale | 6 of 17 resolved, 1 half |
| 4 | 2026-10-19T03:20Z | 0.4.3-beta | Explicit rerun; verified real change first | 3 of 19 resolved, incl. both findings first raised against 0.1.0 |
| 5 | 2026-10-19T09:52Z | Bundle (3 packages) | Explicit rerun before first commit | 0 of 19 resolved; 11 new findings; first multi-package pass |
| 6 | 2026-10-19T11:30Z | 0.1.1 / 0.2.1 / 0.5.1 | Explicit rerun after remediation | **10 of 25 resolved, 1 partly.** First pass with any build step executed |

## Project Growth Across Passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | 0.x.1 |
| --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | **22** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | **3,388** |
| Public methods | 38 | 45 | 62 | 64 | 129 | **129** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | **13** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | **30%** |
| Modules with no harness | 6 | 3 | 1 | **0** | 4 | **4** |
| Active CI workflows | 1 | 1 | 1 | 1 | **0** | **1** |
| Build steps verified by CI | 0 | 0 | 0 | 0 | 0 | **5** |

## Notes

- The user has scoped every run to end after Reverse Engineering, so the workflow stops at
  the approval gate rather than auto-advancing to Requirements Analysis.
- **This was a remediation release and a successful one.** All five fixes requested after
  the fourth rerun are addressed; four are fully closed. Ten of the previous pass's
  twenty-five recommendations are resolved after a pass with zero closures.
- **Three fixes exceeded their recommendation.** Packaging was *replaced* rather than
  relocated, which also dissolved the tag-namespace problem — one `v*` tag now releases
  the suite and per-addon versions live in the archive filenames. The installer makes a
  dependency-less install *unreachable* rather than warning about it. Version drift was
  reduced by **deleting** three of the seven per-package locations, then asserting the
  remainder in CI.
- **Both functional defects have purpose-built regression tests.** `integration.lua`
  pins the Expressive contract from both directions and asserts a custom template ending
  in a period is untouched. `settings.lua` loads **ForeverGroupComms** into the GuildComms
  harness, runs `panel.OnDefault()`, and asserts the group output plus the shared table's
  **object identity** are unchanged — a cross-package test for a cross-package bug.
- **First pass with any build step executed.** Python 3 is installed, so
  `tools/package.py`, `--runtime` mode and `tools/verify_package.py` were all run and all
  passed, and the archives were independently inspected: the GuildComms source ZIP carries
  17 `ForeverCommsVoice/` members and the runtime ZIP contains exactly the 21-file runtime
  set. Build output was removed afterwards.
- **TEST AUTOMATION CLOSED in a follow-up change after this pass.** A Lua 5.1.5 install
  was located at `C:\Users\mreillyorg\tools\lua-5.1.5\lua5.1.exe` — already on the User
  PATH, invisible only because the agent shell held a stale environment. The suite ran for
  the first time in the project's history: **12 of 13 passed.** The single failure was a
  latent harness defect, not an install problem: `tests/keybindings.lua` used
  `load(string)`, which is Lua 5.2+ semantics, so **that harness had never executed on any
  pass** — its assertion that no keybinding path sends a guild message had been assumed
  since 0.4.1. Fixed as `loadstring or load`; the suite is now **13 of 13**. Added
  `tools/run_tests.py` as the single runner for CI and developers, wired it into
  `.github/workflows/package.yml` ahead of packaging so behaviour failures stop a release,
  and deleted the Lua source greps from `tools/verify_package.py` since the harnesses now
  assert those facts properly. Exit codes 0 / 1 / 2 were each verified deliberately.
  This closes the recommendation that had been top of the list for five consecutive passes
  and the last of the fourth rerun's seven pre-commit items.
- **Top recommendation is now the cheapest item on the list** for the first time in six
  passes: add `tests/syntax.lua` to Voice and GroupComms, six lines each, which the runner
  will pick up automatically since it discovers harnesses from the directory.
- Nothing has been tested against a live Forever client; all three packages remain beta.
- **One new defect**: the three `INSTALL-README.txt` files and three installer shims were
  template-generated without special-casing the library, so ForeverCommsVoice's copies
  state that it depends on itself. User-facing text only; the install path is correct.
- **Two new maintainability risks**: `tools/package.py` and `package.ps1` are two
  implementations of one contract and only the Python one is exercised by CI, while
  `package.cmd` — the documented Windows entry point — runs the PowerShell one; and
  `tools/verify_package.py` asserts the exact text and indentation of
  `panel.OnDefault`, so a benign refactor fails the build with a packaging error.
- **One behaviour change rode along undocumented**: the restored Expressive punctuation
  branch sits in a flair block shared by both scopes, so group `greet`/`welcome`/`level`
  messages now also convert a terminal period. Only guild scope is asserted.
- **Still open from the previous pass**: `OnDefault` resets `outgoingMode`; no syntax
  harness for Voice or GroupComms, leaving 13 of 22 modules without a compile guard; four
  modules loaded by no harness; `parseIDs` and the `OnAddonMessage` rejections untested;
  the `questSync` opt-out untested; no `.luacheckrc`; positional row binding in both
  packages; `V:VoiceText` and `V:ChooseMessageTemplate` dead; `V:Render` undivided.
- **Housekeeping owed**: three "Known deviation" blocks in `.kiro/steering/` are now stale
  because this span closed all three, and `release-packaging.md` still says seven version
  locations move together where there are now four.