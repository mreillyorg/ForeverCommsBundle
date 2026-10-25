# Reverse Engineering Metadata

**Analysis Date**: 2026-10-25T04:00:00Z
**Analyzer**: AI-DLC
**Workspace**: `c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\Addon-Manual\ForeverCommsBundle-Development`
**Analysis Target**: ForeverCommsVoice 0.2.2-beta, ForeverGuildComms 0.6.3-beta,
ForeverGroupComms 0.3.4-beta
**Target commit**: `f7f7bab` — "fixes found from the quality checks", clean tree, pushed to
`origin/main`
**Run**: 10th reverse-engineering pass; 6th multi-package pass
**Supersedes**: the pass of 2026-10-25T03:10:00Z, which describes commit `b712070`
**Trigger**: Explicit user request
**Diff baseline**: `b712070`, spanning five commits

No version changed in this span. The three packages stay at 0.2.2-beta, 0.6.3-beta and
0.3.4-beta.

## Change scope

| Commit | Content |
| --- | --- |
| `05970d1` | "updating aidlc doco" — committed the ninth pass's artifacts |
| `c8a0e30` | "generated wiki content" — a new `wiki/` directory, 9 files, 1,530 lines |
| `ae17bfa` | **Not from this session.** "Chatgpt added some Lua 5.1 items" — `tools/check_lua_quality.py`, the workflow rewrite, `LUA51-AUDIT.md`, `Lua51-Test-Results.txt` |
| `eec9635` | **Not from this session.** "lua quakity fixes" |
| `f7f7bab` | **Not from this session.** "fixes found from the quality checks" — together with `eec9635`, these cleared all 29 luacheck warnings |

**Span total**: 40 files changed, 2,269 insertions, 244 deletions. 12 files added, 28
modified, none deleted.

| Area | Change across the span |
| --- | --- |
| New quality gate | `tools/check_lua_quality.py` — strict Lua 5.1 parse of every file, then the harnesses, then zero-warning luacheck |
| CI | Two steps replaced by one: "Enforce Lua 5.1 syntax, tests and zero-warning lint". Now installs `luacheck` alongside `lua5.1` |
| Lint | **29 luacheck warnings → 0.** 48 insertions against 48 deletions across 8 shipped modules and 6 harnesses — pure renames of shadowing parameters and removal of unused locals |
| New user docs | `wiki/` with 9 pages: Home, Installation, Settings Reference, Slash Commands and Keybindings, Troubleshooting, three per-addon module pages, and a sidebar |
| New engineering docs | `LUA51-AUDIT.md` (23 lines), `Lua51-Test-Results.txt` (189 lines) |
| `.pkgmeta` | `wiki` added to the ignore list |
| Shipped code size | **Unchanged.** 25 modules, 3,967 lines, 153 methods |

## Artifacts Generated

- [x] `reverse-engineering-timestamp.md` — regenerated
- [x] `code-quality-assessment.md` — updated: lint now clean, items 43 and 44 closed, the new gate, one documentation defect
- [x] `technology-stack.md` — updated: the new tool, the CI change, `luac -p` coverage
- [x] `component-inventory.md` — updated: tooling and documentation inventory, file counts
- [x] `code-structure.md` — updated: build system, root files, `wiki/`
- [x] `dependencies.md` — updated: luacheck is now a CI-required build dependency
- [x] `business-overview.md` — updated: closing metrics
- [x] `architecture.md` — header only; no architectural change in this span
- [x] `api-documentation.md` — header only; the public API surface did not change

## Total Files Analyzed

**124 project files**, counted mechanically, excluding `.git/`, `aidlc-docs/`,
`.kiro/aws-aidlc-rule-details/` and build output. Up from 112 — the 12 added files.

By extension: 53 `.lua`, 26 `.md`, 6 `.py`, 6 `.cmd`, 5 `.ps1`, 4 `.pkgmeta`, 4 `.txt`,
4 `.yml`, 3 `.png`, 3 `.tga`, 3 `.toc`, 2 `.gitignore`, 2 `.xml`, plus `.gitattributes`,
`.luacheckrc` and `LICENSE`.

| Category | Count | Depth this pass |
| --- | --- | --- |
| Shipped Lua modules | 25 | The 8 changed read as diffs; line and method counts re-measured across all 25 |
| Offline harnesses | 28 | The 6 changed read as diffs; line counts re-measured across all 28 |
| Release and quality tooling | 10 | `check_lua_quality.py` read in full; the workflow diff read in full |
| New documentation | 11 | `LUA51-AUDIT.md` read in full; `wiki/` and `Lua51-Test-Results.txt` surveyed |
| `.pkgmeta` | 4 | Root diff read in full; ignore list checked against the built archive |
| Git state | — | `log`, `show --stat`, `diff --name-status`, and `git show b712070:` to verify a claim |

## Verification Performed

Executed, not inferred. An external commit reverted much of this project's work once
before, so state was established by running things rather than reading them.

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 0 — PASSED: 28, FAILED: 0, TOTAL: 28** |
| `python tools/fault_inject.py` | **Exit 0 — 31 of 31 injected faults caught** |
| `luacheck .` (1.2.0) | **Exit 0 — 0 warnings, 0 errors in 53 files.** Was 29 warnings |
| `python tools/package.py` | Exit 0 — `ForeverCommsBundle-0.6.3-beta.zip`, 33 entries |
| Archive leak check | **No `wiki/`, `LUA51-AUDIT.md`, `Lua51-Test-Results.txt` or `tools/` content in the bundle.** Top-level dirs are exactly the three addons |
| `python tools/check_bigwigs_bundle.py` | **Exit 0** |
| `python tools/package.py --source` | Exit 0 |
| `python tools/verify_package.py` | **Exit 0** |
| `check_lua_quality.py` still runs the harnesses? | **Yes** — confirmed by reading it; it invokes `tools/run_tests.py` by subprocess |
| `git show b712070:.github/workflows/package.yml` | Confirmed the workflow had **no** luacheck, `luac` or `--max-warnings` at the baseline |
| `SetScript("OnUpdate"` across all 25 modules | **Zero** |

**Not verified**: the BigWigs release path, a GitHub Action that cannot run locally; the
local mirror was run instead. **Nothing in this bundle has been executed against a live
Forever client.** True of every pass to date.

## Metrics

| Metric | Voice | Guild | Group | Bundle | Δ vs `b712070` |
| --- | --- | --- | --- | --- | --- |
| Version | 0.2.2-beta | 0.6.3-beta | 0.3.4-beta | — | — |
| Shipped Lua modules | 9 | 9 | 7 | **25** | — |
| Shipped Lua lines | 1,221 | 1,580 | 1,166 | **3,967** | — |
| Public methods | 33 | 67 | 53 | **153** | — |
| Offline harnesses | 8 | 13 | 7 | **28** | — |
| Harness lines | 1,053 | 1,490 | 1,714 | **4,257** | — |
| Harnesses failing | 0 | 0 | 0 | **0** | — |
| **luacheck warnings** | — | — | — | **0** | **−29** |
| Injected faults caught | — | — | — | **31 / 31** | — |
| SavedVariables tables | 1 | 2 | 1 | **4** | — |

Every code metric is unchanged. The span's work was quality tooling, lint cleanliness and
documentation.

### Follow-up after this pass, uncommitted

The tables above and below measure `f7f7bab` and are left that way, so each column still
describes a state that can be checked out. The pass then closed item 47 and both
carried-forward code smells, which moved these figures in the working tree:

| Metric | `f7f7bab` | Working tree | Δ |
| --- | --- | --- | --- |
| Shipped Lua lines | 3,967 | **3,993** | +26 |
| Public methods | 153 | **155** | +2 |
| Harness lines | 4,257 | **4,363** | +106 |
| Test % of shipped Lua | 107% | **109%** | +2 |
| Injected faults caught | 31 / 31 | **37 / 37** | +6 |
| Shipped Lua modules | 25 | 25 | — |
| Offline harnesses | 28 | 28 | — |

The two new methods are `V:ResetVariantBags` and `A:GetActivityType`. No new files, so the
project file count stays at 124. GroupComms is untouched.

## Comparison across all ten passes

| Metric | 0.1.0 | 0.4.3 | Bundle | 0.x.1 | `57f7cdc` | `a64ac2a` | `b712070` | **`f7f7bab`** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Packages | 1 | 1 | 3 | 3 | 3 | 3 | 3 | **3** |
| Shipped Lua modules | 7 | 12 | 22 | 22 | 25 | 25 | 25 | **25** |
| Shipped Lua lines | 882 | 2,022 | 3,395 | 3,388 | 3,806 | 3,927 | 3,967 | **3,967** |
| Public methods | 38 | 64 | 129 | 129 | 152 | 153 | 153 | **153** |
| Offline harnesses | 1 | 11 | 13 | 13 | 17 | 28 | 28 | **28** |
| Test % of shipped Lua | 8% | 40% | 29% | 30% | 32% | 105% | 107% | **107%** |
| Modules with no harness | 6 | 0 | 4 | 4 | 5 | 0 | 0 | **0** |
| Suite passing | n/a | n/a | not run | not run | NO — 3/17 | YES | YES | **YES — 28/28** |
| Faults caught | — | — | — | — | — | 28/28 | 31/31 | **31/31** |
| luacheck warnings | n/a | n/a | n/a | n/a | n/a | 29 | 29 | **0** |
| CI runs harnesses | No | No | No | Yes | No | Yes | Yes | **Yes** |
| CI runs the linter | No | No | No | No | No | No | No | **Yes** |
| Strict 5.1 parse in CI | No | No | No | No | No | No | No | **Yes** |
| Recommendations resolved | — | 3/19 | 0/19 | 10/25 | 2/20 | 40/44 | 42/46 | **44/46** |

## Headline findings

1. **Items 43 and 44 are both closed, externally.** With item 47 raised and fixed in this
   pass the ledger is at **45 of 47**, and the only two remaining — 41 and 42 — both
   require a live client. For the first time there is no open work that can be done
   offline.
2. **The linter is clean.** 29 warnings → **0 warnings, 0 errors across 53 files**,
   achieved by 48 insertions against 48 deletions: shadowing parameters renamed and unused
   locals removed, with no behaviour change. Suite and mutation check both still pass.
3. **CI now enforces three gates in one step.** `tools/check_lua_quality.py` strict-parses
   every `.lua` with `luac -p`, runs the existing harnesses, then demands a zero-warning
   luacheck. It resolves *and validates* its three executables, rejecting LuaJIT or any
   non-5.1 banner rather than silently substituting.
4. **`luac -p` is genuinely new coverage.** It parses **every** `.lua` file, including ones
   no harness loads and files absent from any TOC. The three syntax harnesses are
   TOC-driven and therefore cannot cover a file that is not listed.
5. **The harnesses survived the workflow rewrite.** The explicit `run_tests.py` step
   disappeared from the workflow, which is the regression this project has suffered before;
   verified by reading the new tool that it still invokes `run_tests.py` by subprocess.
6. **A 9-page `wiki/` was added and correctly excluded from the archive.** `.pkgmeta` lists
   `wiki` in its ignore block, and the rebuilt bundle is still 33 entries with no wiki,
   audit, results or tooling content.
7. **One documentation defect: `LUA51-AUDIT.md` misstates its own starting point.** It
   claims the repository "already had `lua5.1`, `luac5.1 -p`, Lua 5.1 harnesses and
   `luacheck --max-warnings 0`" in the workflow. `git show b712070:.github/workflows/package.yml`
   shows only `lua5.1` and the harnesses — no luacheck, no `luac`, no `--max-warnings`. The
   document understates its own contribution, and a reader would conclude the linter had
   been in CI before this span when adding it is the span's main achievement. Its other
   caveat, that no claim is made about the 29 warnings being resolved, is also now stale.
8. **Two minor observations.** `LUA51-AUDIT.md` and `Lua51-Test-Results.txt` are not named
   in the `.pkgmeta` ignore list; the archive excludes them because `move-folders` ships
   only the three addon directories, so this is behaviour rather than an explicit
   exclusion. And `Lua51-Test-Results.txt` is a committed 189-line test transcript, which
   goes stale the moment the suite changes.
9. **One tooling defect, found and fixed (item 47).** `tools/fault_inject.py` restored each
    mutated source through `pathlib.Path.write_text`, which translates `\n` to `os.linesep`
    — CRLF here — so every run silently rewrote line endings against `* text=auto eol=lf`.
    `git ls-files --eol` found six shipped sources at `i/lf w/crlf attr/text eol=lf`.
    Committed blobs were never affected and `git diff` reported nothing, because check-in
    normalisation makes a CRLF working file compare equal to an LF blob; the only symptom
    was `git status` listing modifications with an empty diff. Restoring byte-exact then
    made two multi-line anchors miss, reporting "caught 29 / 29, 2 skipped" — an uncovered
    fault disguised as a skip, the worse of the two failures — so anchors are now matched
    against the newline the target file actually uses. Tree re-checked-out to LF; zero
    `w/crlf` files remain, lint and suite unchanged, and a repeat run leaves the tree clean.
10. **Both carried-forward code smells are now closed, and one of them had been diagnosed
    wrongly.** `A.GetActivityType` was not merely called with the wrong sigil: it closed
    over two locals of `A:BuildRequestUI`, so fixing the call sites alone would have
    changed nothing. The state moved to `A.activityTypes` / `A.activityType` in `Core.lua`
    and the method is now ordinary, which also removed an ordering dependency and let
    `tests/variations.lua` drive the real method instead of a stub — the cycling
    arithmetic had been covered by nothing. `A.messageVariantBags` was never an unbounded
    -growth problem: language and accent are single-valued per profile, so growth is
    `scope × kind` plus one family per profile change, not the product of four dimensions.
    The real defect was stale bags surviving a profile change, now cleared by
    `V:ResetVariantBags` on any accepted option write. An LRU and an entry cap were both
    rejected as more machinery than the state they would manage. Note the lint pass had
    removed a *different* unused local in the same function, `typeBtn`, which is easy to
    mistake for the first finding.
11. **The largest risk is unchanged and is not a code risk.** Nothing in this bundle has
    ever been loaded by the client it targets. Items 41 and 42 are the only ones that
    address it, and they are now the *only* open items.
