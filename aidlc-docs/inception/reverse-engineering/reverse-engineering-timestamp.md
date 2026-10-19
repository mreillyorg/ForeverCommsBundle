# Reverse Engineering Metadata

**Analysis Date**: 2026-10-19T09:52:22Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: `ForeverCommsBundle` monorepo — ForeverCommsVoice 0.1.0-beta,
ForeverGroupComms 0.2.0-beta, ForeverGuildComms 0.5.0-beta
**Run**: 5th reverse-engineering pass; **first multi-package pass**
**Supersedes**: the single-package 0.4.3-beta pass of 2026-10-19T03:20:00Z
**Trigger**: Explicit user request, before the first commit of the bundle restructure

## Artifacts Generated

- [x] `business-overview.md`
- [x] `architecture.md`
- [x] `code-structure.md`
- [x] `api-documentation.md`
- [x] `component-inventory.md`
- [x] `technology-stack.md`
- [x] `dependencies.md`
- [x] `code-quality-assessment.md`
- [x] `reverse-engineering-timestamp.md`

All nine regenerated from scratch. None was carried over from the previous pass; the
previous pass targeted a workspace whose root was a single addon folder, which is no
longer true of any part of this repository.

## Total Files Analyzed

**68 project files**, excluding `aidlc-docs/` and `.kiro/aws-aidlc-rule-details/`.

| Category | Count | Depth |
| --- | --- | --- |
| Shipped Lua modules | 22 | Read in full |
| TOC manifests | 3 | Read in full |
| `Bindings.xml` | 2 | Read in full |
| Offline harnesses | 13 | 3 read in full; 10 inspected for module-loading, assertions and coverage |
| Markdown docs | 6 | Read in full: 3 addon READMEs, `PACKAGING.md`, root `README.md`, plus 2 steering files |
| `.pkgmeta` | 3 | Read in full |
| GitHub workflows | 3 | Read in full |
| Installers | 8 | Root `.ps1` read in full; the three per-addon `.ps1`/`.cmd` pairs and three `INSTALL-README.txt` inspected for version strings, file-selection logic and dependency handling |
| Git config | 3 | `.gitattributes`, root `.gitignore`, GuildComms `.gitignore` |
| Media assets | 2 | Existence and size verified only |

Additionally consulted: all 8 files in `.kiro/steering/` (2 read in full, 6 scanned for
staleness against the new structure), and the AI-DLC rule detail files required by the
workflow.

## Measurements taken

| Metric | Voice | Guild | Group | Bundle |
| --- | --- | --- | --- | --- |
| Shipped Lua modules | 7 | 9 | 6 | 22 |
| Shipped Lua lines | 860 | 1,557 | 978 | 3,395 |
| Public methods | 18 | 64 | 47 | 129 |
| Registered events | 1 | 14 | 10 | 25 |
| Event dispatchers | 1 | 1 | 1 | 3 |
| Offline harnesses | 1 | 11 | 1 | 13 |
| Harness lines | 64 | 826 | 105 | 995 |
| Modules no harness loads | 1 | 0 | 3 | 4 |
| SavedVariables tables | 1 | 2 | 1 | 4 |

All counts were derived mechanically from the TOC file lists rather than by hand: module
lists parsed from each `.toc`, line counts via `Measure-Object -Line`, method counts via a
`function <NS>:<Name>` pattern match per module.

## Comparison across all five passes

| Metric | 0.1.0 | 0.2.0 | 0.4.1 | 0.4.3 | Bundle |
| --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 1 | 1 | **3** |
| Shipped Lua modules | 7 | 7 | 11 | 12 | **22** |
| Shipped Lua lines | 882 | 1,097 | 1,733 | 2,022 | **3,395** |
| Public methods | 38 | 45 | 62 | 64 | **129** |
| Business transactions | 9 | 10 | 13 | 14 | **37** |
| Offline harnesses | 1 | 4 | 9 | 11 | **13** |
| Test % of shipped Lua | 8% | 19% | 34% | 40% | **29%** |
| Modules with no harness | 6 | 3 | 1 | 0 | **4** |
| SavedVariables tables | 2 | 2 | 2 | 2 | **4** |
| Event dispatchers | 1 | 1 | 1 | 1 | **3** |
| Inbound untrusted-data paths | 0 | 0 | 0 | 0 | **1** |

ForeverGuildComms considered alone went from 12 modules and 2,022 lines to 9 modules and
1,557 lines — a net removal of 465 lines, replaced by a 26-line adapter. Its method count
is unchanged at 64, because `VoiceBridge.lua`'s 7 forwarders replace the 7 methods that
left with `RaceProfiles.lua` and `MessageVariants.lua`.

## Scope and limitations of this analysis

- **No code was executed.** No Lua interpreter is installed on this machine: `lua`,
  `lua5.1`, `luajit`, `texlua` and `lua54` were all probed and none is on PATH. **None of
  the 13 harnesses was run and none is reported as passing.** Every statement about test
  coverage in these artifacts comes from reading the harness source.
- **No in-game verification.** All three packages describe themselves as beta and
  untested against a live Forever client. Client-specific behaviour — race IDs, the
  `MenuUtil` node API, `C_PartyInfo.DoReadyCheck`, `QuestLogPushQuest`, addon-message
  delivery semantics and the real `PLAYER_ENTERING_WORLD` ordering — remains unverified.
- **Behaviour claims are derived from source reading**, not from observation. The one
  behaviour regression reported in `code-quality-assessment.md` (the lost Expressive
  punctuation conversion) was identified by comparing the pre-extraction `V:VoiceText`
  against the current `V:Render`, both of which are present in the working tree.
- **Media assets were not opened.** `Media/Icon.tga` and `Media/ProjectIcon.png` were
  confirmed to exist at plausible sizes, 64 KB and 481 KB, and nothing more.
- **The two `Bindings.xml` handler bodies were read but not executed.**

## Repository state at analysis time

```text
HEAD            a35a168  "Initial commit"  (= origin/main)
Branch          main
Remote          git@github.com:mreillyorg/ForeverCommsBundle.git
Staged          .gitattributes
Untracked       .kiro/  ForeverCommsVoice/  ForeverGroupComms/
                ForeverGuildComms/  aidlc-docs/  install/
```

The entire restructure is uncommitted. This pass was requested specifically to refresh the
artifacts before the first real commit, so every finding applies to work that can still be
changed without rewriting history — which is why the seven pre-commit recommendations in
`code-quality-assessment.md` are called out separately.

## Headline findings

1. **The extraction is well executed.** The library registers no events and sends nothing;
   the adapter is 26 lines and let two large consumer modules through unmodified; the two
   consumers chose opposite dependency strengths and both choices fit what they would lose.
2. **Release packaging is non-functional.** Three `package.yml` files and three `.pkgmeta`
   files sit in package subdirectories; GitHub Actions reads workflows only from the
   repository root, which has no `.github` directory. All three also listen on an
   unprefixed `v*` while the packages carry three different versions.
3. **The per-addon installers do not know about the new hard dependency.** Neither contains
   the string `ForeverCommsVoice`. An existing user updating GuildComms the familiar way
   gets an addon the client will refuse to load.
4. **One undocumented behaviour regression**: Expressive accent strength lost its
   trailing-period-to-exclamation conversion, affecting five accents. The original code
   survives only in the now-dead `V:VoiceText`.
5. **GuildComms' Restore Defaults now resets the shared voice profile**, because
   `A.char.voice` and `ForeverCommsVoiceCharDB.voice` are the same table object at runtime.
6. **Verification coverage regressed.** 4 of 22 modules are loaded by no harness, 13 of 22
   have no compile check, and test share of source fell from 40% to 29%.
7. **Nine version strings are stale** across the three packages, and `PACKAGING.md` still
   lists four modules that were moved out.
8. **All eight steering files describe a single flat addon** and are now the least accurate
   documentation in the repository. One of them states an addon-comms non-goal that
   GroupComms' headline feature contradicts, because the rule predates the second addon.
9. **The project gained its first inbound untrusted-data path**, and it is handled well:
   eleven distinct validations, minimum disclosure, bounded reassembly state and an epoch
   rule that prevents a stale reply from producing a false claim about another player.
10. **Zero of the previous nineteen recommendations were closed**, the first pass with no
    closures. Three of them got harder.
