# Technology Stack

**Target**: ForeverCommsVoice 0.2.2-beta, ForeverGroupComms 0.3.4-beta, ForeverGuildComms 0.6.3-beta
**Analysis date**: 2026-10-25T02:30:00Z
**Target commit**: `a64ac2a`

## Programming Languages

| Language | Version | Usage |
| --- | --- | --- |
| Lua | **5.1** | All 25 shipped modules and all 28 harnesses. The dialect the WoW client embeds. 5.2+ constructs are forbidden in shipped code *and* in harnesses |
| XML | — | Two `Bindings.xml` files declaring six keybindings with inline Lua handler bodies |
| Python | 3 | Five build and verification tools under `tools/`. Not shipped to users |
| PowerShell | 5.1+ | Four Windows installers plus two launcher scripts. Not shipped into `AddOns/` |
| Batch | — | `.cmd` shims using `-NoProfile -ExecutionPolicy Bypass` |

## Frameworks

**None.** No Ace3, no AceAddon, no AceConfig, no AceDB, no embedded libraries, no
`Libs/` directory, no `embeds.xml`, and no `externals` block in any `.pkgmeta`.

The addons use the WoW client's own API directly: `CreateFrame`, the `Settings` canvas
API with an `InterfaceOptions_AddCategory` fallback, `C_Timer`, `StaticPopupDialogs` and
`MenuUtil`.

## Platform

| Item | Value |
| --- | --- |
| Target client | WoW Forever 1.60.1 |
| Interface number | `16001`, identical in all three TOCs |
| Addon loader | Blizzard TOC manifests, one per package |
| Keybindings | `Bindings.xml`, auto-loaded from the addon root and deliberately absent from every TOC |
| Persistence | Blizzard SavedVariables — 4 tables across 3 owners |

## Optional integrations

| Integration | Mechanism | Hardness |
| --- | --- | --- |
| Titan Panel | `## OptionalDeps: Titan` plus a runtime `LibStub("LibDataBroker-1.1", true)` probe | **Optional.** Both addons work fully without it. Titan's own LibDataBroker copy is used; nothing is vendored |
| Blizzard `MenuUtil` | Feature-probed before use; falls back to opening the Settings panel | Optional |
| `C_PartyInfo.DoReadyCheck` | Probed, with a bare `DoReadyCheck` fallback | Optional |
| `C_QuestLog` | Probed, with a legacy `GetQuestLogTitle` branch | Optional |

The only hard dependency anywhere is `## Dependencies: ForeverCommsVoice` in both
consumer TOCs. It guarantees presence, not version.

## Build Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| BigWigsMods/packager | `@v2` | **The authoritative release path for GitHub.** Runs in Actions; reads the root `.pkgmeta` |
| `tools/package.py` | in-repo | Local mirror of the above, reading the **same** root `.pkgmeta`. Cross-checks the TOC manifest against the `.pkgmeta` exclusions and refuses to build if they disagree |
| `package.ps1` / `package.cmd` | in-repo | Windows launchers over `tools/package.py`, deliberately not a second implementation |
| GitHub Actions | — | One root workflow; three nested per-package workflows retained for the standalone-repository case |

There is no compile step. Lua ships as source.

## Testing Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| Lua interpreter | **5.1.5** | Runs every harness. Located at `~/tools/lua-5.1.5/lua5.1.exe` on this machine; CI installs `lua5.1` from apt |
| Lua `assert` | stdlib | The entire assertion mechanism across all 28 harnesses. No test framework |
| `tools/run_tests.py` | in-repo | Discovers and runs every harness, each with its package folder as the working directory. Refuses an explicitly requested interpreter that is not 5.1 rather than silently substituting |
| `tools/fault_inject.py` | in-repo | Mutation check. Reverts one real guard at a time and asserts the relevant harness fails. 28 of 28 caught |
| **luacheck** | **1.2.0** | Static analysis, configured by the root `.luacheckrc`. Standalone Windows binary; no LuaRocks and no C compiler needed |
| `tools/check_bigwigs_bundle.py` | in-repo | Release gate: archive structure, runtime completeness, version consistency |
| `tools/verify_package.py` | in-repo | Verifies the `--source` archives |

Python tools use explicit `check()` helpers that raise a dedicated error rather than bare
`assert`, so `python -O` cannot skip a release check. This was verified by fault injection.

## Verified execution state

| Layer | Available | Executed | Result |
| --- | --- | --- | --- |
| **Lua harnesses** | Yes — 5.1.5 | **Yes** | **Exit 0. PASSED: 28, FAILED: 0, TOTAL: 28** |
| **Mutation check** | Yes | **Yes** | **Exit 0. 28 of 28 injected faults caught** |
| **luacheck** | Yes — 1.2.0 | **Yes** | 29 warnings, **0 errors**, 53 files |
| `tools/package.py` | Yes | **Yes** | Exit 0 — 33-entry bundle |
| `tools/check_bigwigs_bundle.py` | Yes | **Yes** | **Exit 0** |
| `tools/verify_package.py` | Yes | **Yes** | **Exit 0** |
| BigWigs release path | **No** | No | `BigWigsMods/packager@v2` is a GitHub Action and cannot run locally. The local mirror was run instead |
| **Live WoW Forever client** | **No** | **No** | **Nothing in this bundle has ever been loaded by the client it targets** |

## Notable constraints

- **Lua 5.1 only.** `load(string)` is 5.2+; harnesses use `local compile = loadstring or load`.
  LuaJIT is accepted by the runner with a warning, and `ffi`/`bit`/`jit`/`goto` are forbidden
  even in harnesses so a test cannot come to depend on a superset.
- **`math.randomseed` does not exist in the WoW client**, which seeds the RNG itself at
  startup. Both shuffle sites are deliberately unseeded and carry a comment saying so.
  The offline harnesses therefore run from a fixed seed, which the shuffle tests rely on.
- **Chat messages are capped in bytes, not characters.** Three UTF-8-safe 250-byte clamps
  exist, one per package, all asserted together by `bytelimit.lua`.
- **No addon-to-addon comms in GuildComms.** GroupComms' quest sync is the only
  `C_ChatInfo.SendAddonMessage` user, under the 15-byte prefix `ForeverGrpComms`.
