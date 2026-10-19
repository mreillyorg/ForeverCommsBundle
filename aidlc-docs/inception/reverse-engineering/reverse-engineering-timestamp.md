# Reverse Engineering Metadata

**Analysis Date**: 2026-10-19T11:30:00Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: ForeverCommsVoice 0.1.1-beta, ForeverGroupComms 0.2.1-beta,
ForeverGuildComms 0.5.1-beta
**Run**: 6th reverse-engineering pass; 2nd multi-package pass
**Supersedes**: the pass of 2026-10-19T09:52:22Z, which describes commit `76ca527`
**Trigger**: Explicit user rerun request
**Diff baseline**: commit `76ca527`

## Artifacts Generated

- [x] `business-overview.md` — updated
- [x] `architecture.md` — updated
- [x] `code-structure.md` — updated
- [x] `api-documentation.md` — updated
- [x] `component-inventory.md` — regenerated
- [x] `technology-stack.md` — regenerated
- [x] `dependencies.md` — regenerated
- [x] `code-quality-assessment.md` — regenerated
- [x] `reverse-engineering-timestamp.md` — regenerated

Four artifacts were updated in place rather than rewritten, because the architecture,
module responsibilities, business transactions and wire protocol are unchanged. The four
regenerated ones are those the span materially rewrote: the component and dependency
inventories gained a build-and-release layer, the technology stack gained a language, and
the quality assessment is largely a verification report.

## Change scope

Verified before regenerating, per the practice established in run 4. The source is **not**
unchanged this time — the working tree held substantial work this session did not author,
which proved to be the five fixes requested earlier plus two extras.

| Area | Change |
| --- | --- |
| Lua source | 5 files, net -7 lines. Both functional fixes plus the `SetVoiceOption` delegation and two icon wirings |
| Harnesses | 3 files, +34 lines. Two new regression blocks, one path correction |
| TOCs | All 3. Version bumps; `IconTexture` added to Voice and GroupComms |
| Installers | All 5 rewritten. One real installer plus three 13-line shims |
| Build tooling | New: root workflow, 2 Python tools, `package.ps1`, `package.cmd` |
| Assets | New: `Media/Icon.tga` and `Media/ProjectIcon.png` for Voice and GroupComms |
| Docs | New root `README.md` and `PACKAGING.md`; `ForeverGuildComms/PACKAGING.md` reduced 91 → 8 lines; all 3 addon READMEs and all 3 `INSTALL-README.txt` rewritten |
| Workflows | All 3 nested ones normalised and annotated as standalone-only |

## Total Files Analyzed

**72 project files**, excluding `aidlc-docs/` and `.kiro/aws-aidlc-rule-details/`.

| Category | Count | Depth |
| --- | --- | --- |
| Shipped Lua modules | 22 | 5 changed files read as diffs; the rest carried from the previous pass |
| TOC manifests | 3 | Diffs read in full |
| Offline harnesses | 13 | 3 changed read as diffs; `variations.lua` and `syntax.lua` re-read in full |
| Build and release tooling | 7 | `tools/package.py`, `tools/verify_package.py`, `package.ps1`, `package.cmd`, root `package.yml`, and the 3 nested workflow diffs — all read in full |
| Installers | 8 | The shared installer and one shim read in full; the others diffed |
| Markdown docs | 7 | Root `README.md`, root `PACKAGING.md`, `ForeverGuildComms/PACKAGING.md` and all 3 `INSTALL-README.txt` read in full |
| `.pkgmeta` | 3 | Diffs read in full |
| Media assets | 6 | Size and MD5 checked; not opened |
| Git state | — | `log`, `status --porcelain`, scoped `diff --stat` and targeted `diff` |

## Verification Performed

**This is the first pass in which part of the build was executed rather than read.**
Python 3 is present on this machine; Lua is not.

| Action | Result |
| --- | --- |
| `python tools/package.py --output dist` | Exit 0. 19 / 51 / 36 / 75 files across four archives |
| `python tools/verify_package.py dist` | Exit 0. Five PASS groups, including the source-fact group asserting both Lua fixes |
| `python tools/package.py --output dist-runtime --runtime` | Exit 0. 9 / 21 / 18 / 30 files |
| Independent inspection, GuildComms source ZIP | 32 `ForeverGuildComms/`, **17 `ForeverCommsVoice/`**, 2 `install/` members. Voice TOC, shared installer and `Bindings.xml` all present |
| Independent inspection, GuildComms runtime ZIP | Exactly 21 members: both packages' TOC-listed modules, both `Media/Icon.tga`, `Bindings.xml`. No tests, installers, docs or `ProjectIcon.png` |
| Icon assets | 3 distinct `Icon.tga` by MD5 at 64 KB each; 3 `ProjectIcon.png` at 192 / 213 / 481 KB |
| Version sweep | Consistent at 0.1.1 / 0.2.1 / 0.5.1 across TOC, `Core.lua`, README title, README banner and both installer `.cmd` lines |
| Cleanup | `dist/` and `dist-runtime/` removed |

## Scope and limitations

- **The 13 Lua harnesses were not run.** `lua`, `lua5.1`, `luajit`, `texlua` and `lua54`
  are all absent from PATH. **None is reported as passing**, including the two regression
  tests added this span — their correctness is asserted from reading them.
- **`package.ps1` was not executed.** The Python builder covers the same contract and is
  what CI runs. This leaves the documented Windows path unverified; recorded as a finding.
- **No in-game verification.** All three packages remain beta and nothing has been tested
  against a live Forever client. Client-specific behaviour — race IDs, `MenuUtil`,
  `C_PartyInfo.DoReadyCheck`, `QuestLogPushQuest`, addon-message delivery, the real
  `PLAYER_ENTERING_WORLD` ordering, and whether the new `IconTexture` entries render —
  remains unverified.
- **Behaviour claims about the Lua fixes come from reading the diffs**, cross-checked
  against the pre-extraction implementation still present in `V:VoiceText`.
- **Media assets were not opened**; existence, size and hash only.

## Metrics

| Metric | Voice | Guild | Group | Bundle | Δ |
| --- | --- | --- | --- | --- | --- |
| Shipped Lua modules | 7 | 9 | 6 | 22 | — |
| Shipped Lua lines | 872 | 1,534 | 982 | 3,388 | -7 |
| Public methods | 18 | 64 | 47 | 129 | — |
| Registered events | 1 | 14 | 10 | 25 | — |
| Offline harnesses | 1 | 11 | 1 | 13 | — |
| Harness lines | 79 | 845 | 105 | 1,029 | +34 |
| Modules no harness loads | 1 | 0 | 3 | 4 | — |
| SavedVariables tables | 1 | 2 | 1 | 4 | — |
| `Media/Icon.tga` | 1 | 1 | 1 | 3 | +2 |

All counts derived mechanically: module lists parsed from each `.toc`, line counts via
`Measure-Object -Line`, method counts via a `function <NS>:<Name>` pattern match.

## Comparison across all six passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle | This pass |
| --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | 3 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | 22 | **22** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | 3,395 | **3,388** |
| Public methods | 38 | 45 | 62 | 64 | 129 | **129** |
| Offline harnesses | 1 | 4 | 9 | 11 | 13 | **13** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | 29% | **30%** |
| Modules with no harness | 6 | 3 | 1 | 0 | 4 | **4** |
| Active CI workflows | 1 | 1 | 1 | 1 | **0** | **1** |
| Build steps verified by CI | 0 | 0 | 0 | 0 | 0 | **5** |
| Recommendations resolved | — | 3/15 | 6/17 | 3/19 | **0/19** | **10/25** |

## Headline findings

1. **All five user-requested fixes are addressed; four are fully closed.** Packaging,
   installers, version strings and the Expressive regression are done. Restore Defaults is
   fixed for the shared profile and still resets `outgoingMode`.
2. **Three fixes are better than what was recommended.** Packaging was replaced rather than
   relocated, so one unprefixed `v*` tag is now correct. The installer makes a
   dependency-less install unreachable rather than warning about it. Version drift was
   reduced by *deleting* three of the seven locations, then asserting the rest in CI.
3. **Both functional defects have purpose-built regression tests**, and `settings.lua`'s is
   a genuine cross-package test — it loads ForeverGroupComms, runs GuildComms' Restore
   Defaults, and asserts the group output and the shared table's object identity are
   unchanged.
4. **Packaging is now a quality gate, and I verified it by running it.** Both builders
   validate TOC entries, icon paths, dependency declarations and archive member safety
   before producing anything, and `verify_package.py` re-opens every archive.
5. **CI exists for the first time since the restructure** — and runs five verification
   steps — but still does not run the 13 Lua harnesses. Fifth consecutive pass as the top
   recommendation, now with the job slot available.
6. **Ten of twenty-five prior recommendations resolved**, one partly, after a pass with
   zero closures.
7. **One new defect**: the three `INSTALL-README.txt` files and three installer shims were
   template-generated without special-casing the library, so ForeverCommsVoice's copies
   tell the user it depends on itself.
8. **Two new maintainability risks**: two packager implementations with only the
   less-used one verified, and a release verifier that greps Lua source text and
   indentation.
9. **The Expressive fix also changed group-scope behaviour**, because the restored branch
   sits in a flair block shared by both scopes. Undocumented and untested for group.
10. **Three "Known deviation" blocks in the steering files are now stale**, since this
    span closed all three deviations they describe.