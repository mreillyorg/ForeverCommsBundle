# Technology Stack

**Analysis date**: 2026-10-19T11:30:00Z
**Target**: ForeverCommsVoice 0.1.1-beta, ForeverGroupComms 0.2.1-beta, ForeverGuildComms 0.5.1-beta

## Programming Languages

| Language | Version | Usage |
| --- | --- | --- |
| Lua | 5.1 — the dialect the WoW client embeds | All 22 shipped modules, 3,388 lines, plus all 13 offline harnesses, 1,029 lines. No LuaJIT extension is used anywhere: no `ffi`, `bit`, `jit`, `table.new` or `goto` |
| **Python** | **3.12 in CI; 3.x standard library only** | **New this span.** `tools/package.py` (97 lines) and `tools/verify_package.py` (52 lines). Zero third-party packages — `argparse`, `pathlib`, `re`, `sys`, `zipfile` |
| PowerShell | 5.1+, Desktop edition | 5 scripts, 317 lines. `install/Install-ForeverComms.ps1` (153) is the one real installer; three 13-line per-addon shims delegate to it; `package.ps1` (72) is the offline Windows builder |
| XML | WoW `Bindings.xml` schema | 2 files, 23 lines. Six opt-in keybindings whose handler bodies are one-line Lua calls into the addon globals. Auto-loaded from each addon root and deliberately absent from the TOCs |
| TOC | WoW addon manifest | 3 files, 48 lines. Metadata plus the ordered module list. All three now declare `## IconTexture:` |
| Batch | cmd | 5 launchers, 136 lines. Each invokes PowerShell with `-NoProfile -ExecutionPolicy Bypass` for that process only |
| YAML | GitHub Actions | 4 workflow files, 87 lines — one active at the repository root, three retained per package for the standalone case |
| Markdown | — | 7 docs: three addon READMEs, root `README.md`, root `PACKAGING.md`, the 8-line `ForeverGuildComms/PACKAGING.md` pointer, plus three `INSTALL-README.txt` |

## Frameworks

**None.** No application framework, no UI framework, no test framework, no dependency
injection container, no module loader, and — as of this span — **no external packager**.

| Would-be framework | What is used instead |
| --- | --- |
| Addon framework such as Ace3 | The addon vararg plus one shared table per package. `local _, A = ...` |
| Library distribution such as LibStub-embedded libs | A plain global, `_G.ForeverCommsVoice`, declared as a TOC `## Dependencies:` entry and physically bundled into each consumer's release archive |
| UI framework | Direct `CreateFrame` calls against Blizzard templates, with file-local constructors and a list of refresh closures |
| Test framework | `assert` from the standard library. Each harness dies on the first failure and prints a `PASSED: ...` line otherwise. `verify_package.py` likewise uses bare `assert` |
| Build / release framework | Two hand-written offline builders. BigWigsMods/packager is retained only for the standalone-repository path |
| Scheduler | `C_Timer.After` and `C_Timer.NewTicker`, always paired with a boolean latch or a serial counter. No `OnUpdate` script anywhere |
| Serialization library | One hand-rolled pipe-delimited format in `ForeverGroupComms/Quests.lua` |
| Localization framework | Hand-curated offline tables in `ForeverCommsVoice`. No `AceLocale`, no locale files, no runtime translation service |

## Runtime platform

| Component | Detail |
| --- | --- |
| Host | World of Warcraft: Forever, client 1.60.1 |
| Interface version | `16001`, identical in all three TOCs |
| Client folder | `_classic_beta_` |
| Install target | `_classic_beta_\Interface\AddOns\<AddonName>` |
| Backup target | `_classic_beta_\Interface\AddOnBackups\` — deliberately outside `AddOns` so a backup cannot load as a stray addon |
| Persistence | Client-managed SavedVariables: `ForeverCommsVoiceCharDB`, `ForeverGuildCommsDB`, `ForeverGuildCommsCharDB`, `ForeverGroupCommsDB`. Never read, written or copied by any installer or builder |
| Transport | `SendChatMessage` for guild and group chat; `C_ChatInfo.SendAddonMessage` with prefix `ForeverGrpComms` for GroupComms quest sync |

### Client APIs consumed

Unchanged this span. Identity, guild, group, group actions, quests, addon comms, trade
skills, zone and inventory, UI, Settings, menus and timers — every call feature-detected
at the call site, with `pcall` around anything protected that can error. See
`api-documentation.md` for the full list.

## Infrastructure

**None.** No cloud resources, no containers, no databases, no queues. The only persistence
is the client's own SavedVariables files and the only network traffic is the game client's
own protocol.

## Build Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| None for compilation | — | Lua is interpreted by the client. There is still no compile step for the addons |
| **Python 3** | 3.12 in CI, any 3.x locally | **The primary release builder.** `tools/package.py --output dist` produces four archives; `--runtime` produces reduced addon-manager archives. Standard library only |
| **PowerShell 5.1** | Desktop | **The documented Windows release builder.** `package.cmd` → `package.ps1`, using `System.IO.Compression`. Equivalent contract, no `--runtime` mode |
| GitHub Actions | `actions/checkout@v4`, `actions/setup-python@v5`, `actions/upload-artifact@v4`, `gh` CLI | Hosts the suite build. Uses only the built-in `GITHUB_TOKEN` with `contents: write` |
| BigWigsMods/packager | `@v2` action | **Retained only for the standalone-repository path.** Not on the suite release path |
| Git | — | `.gitattributes` pins `eol=lf` repository-wide |

### What the builders validate before producing an archive

This is new and is the reason packaging is now a quality gate rather than a zip step.
Both builders refuse to build on any of:

- a missing TOC, or a TOC with no `## Version:` line
- a TOC entry not matching `^[A-Za-z0-9_-]+\.(lua|xml)$` — no paths, no traversal
- a TOC entry naming a file that does not exist, or a duplicate entry
- an `## IconTexture:` value other than that package's expected
  `Interface\AddOns\<Addon>\Media\Icon`
- a missing `Media/Icon.tga` or `Media/ProjectIcon.png`
- a consumer package missing `## Dependencies: ForeverCommsVoice`
- an archive member with a leading `/` or a `..` segment
- a source path outside the repository root (PowerShell), or a symlink (Python)

`tools/verify_package.py` then re-opens every produced archive and asserts membership,
dependency bundling, installer presence, and — for the suite archive — that the workflow
is at the repository root. It additionally asserts each TOC version appears in that
package's README, and greps the Lua source to confirm this span's two functional fixes are
present.

## Testing Tools

| Tool | Version | Purpose |
| --- | --- | --- |
| Lua `assert` | stdlib | The entire assertion mechanism across all 13 harnesses |
| Lua 5.1 interpreter | 5.1.5 recommended | How the harnesses are meant to be run. `texlua` appears in some harness comments; `lua5.1.exe` in the steering |
| Python `assert` | stdlib | `tools/verify_package.py`. Note bare `assert` means `python -O` would skip every check |
| Synthetic widget layer | hand-written per harness | A metatable whose `__index` returns real implementations for the widget methods a test needs and a no-op for the rest, with `CreateFrame` recording each widget so the test can find it by template or label. Established by `settings.lua`, extended by `titanmenu.lua` to the `MenuUtil` node API |
| Stub client API | hand-written per harness | Each harness defines only the globals its path touches: `GetTime`, `C_Timer.After` captured into a list, `SendChatMessage` recorded into a traffic log, `UnitRace` made reassignable |

### What was and was not executed in this pass

| Layer | Interpreter present | Executed | Result |
| --- | --- | --- | --- |
| Python build and verify | **Yes** | **Yes** | `tools/package.py` exit 0, four archives; `tools/verify_package.py` exit 0, five PASS groups; `--runtime` exit 0. Archives independently inspected |
| PowerShell build | Yes | No | The Python builder covers the same contract and is what CI runs |
| Lua harnesses | **No** | **No** | `lua`, `lua5.1`, `luajit`, `texlua` and `lua54` are all absent from PATH. **None of the 13 is reported as passing**, including the two regression tests added this span |
| Live client | n/a | No | Nothing has been tested against a live Forever client |

### Harness inventory

| Package | Harness | Loads |
| --- | --- | --- |
| Voice | `integration.lua` | **All three packages.** Voice's six data/logic modules, then GroupComms `Core.lua`, then GuildComms `Core.lua` and `VoiceBridge.lua` |
| Guild | `syntax.lua` | All 9 GuildComms modules, compiled only |
| Guild | `smoke.lua` | Voice x6, then Guild Core, VoiceBridge, Roster, Alerts |
| Guild | `verify.lua` | Voice x6, then Guild Core, VoiceBridge |
| Guild | `settings.lua` | Guild Core, Voice x6, VoiceBridge, Guild Options, **and GroupComms Core** |
| Guild | `timing.lua` | Guild Core, Voice x6, VoiceBridge |
| Guild | `titanmenu.lua` | Guild Core, Voice x6, VoiceBridge, Options, TitanMenu, Broker |
| Guild | `voice.lua` | Voice x6, then Guild Core, VoiceBridge |
| Guild | `variations.lua` | Voice x6, then Guild Core, VoiceBridge, UI |
| Guild | `tabard_dedup.lua` | Guild Core, Tabard — the only GuildComms harness needing no Voice |
| Guild | `keybindings.lua` | Guild Core, Alerts, plus the real `Bindings.xml` |
| Guild | `icon.lua` | No modules; reads the TOC, Broker, Options and **the shared installer at `../install/`** as text. Requires both the package root as cwd and the sibling `install/` directory |
| Group | `smoke.lua` | GroupComms Core, Roster, Quests. Does not load Voice |

Eight GuildComms harnesses resolve the library by `os.getenv("FOREVER_VOICE_PATH")` or
`../ForeverCommsVoice/`. `settings.lua` additionally reaches `../ForeverGroupComms/`, and
`icon.lua` reaches `../install/` — neither with an override. The suite therefore requires
the bundle checkout layout more strongly than before.

## Toolchain gaps

| Capability | Status |
| --- | --- |
| Compiler / type checker | Not applicable to Lua 5.1; none used |
| Linter | None configured for any language. No `.luacheckrc`, `selene.toml`, `stylua.toml`, and nothing for the 149 lines of new Python or 317 of PowerShell |
| Formatter | None. Style is maintained by convention and documented in `.kiro/steering/lua-style.md` |
| Code coverage | None |
| Dependency scanning | Not applicable; zero third-party packages are vendored or installed |
| **CI build and packaging verification** | **Present as of this span.** Builds four archives and runs 5 verification groups on `workflow_dispatch` or a `v*` tag |
| **CI test execution** | **Still absent.** No job runs any of the 13 Lua harnesses. Fifth consecutive pass as the top recommendation, though the job slot now exists |
| Version consistency check | **Present.** The builders read versions from the TOCs, and `verify_package.py` asserts each appears in its README |