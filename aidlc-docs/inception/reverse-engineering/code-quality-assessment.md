# Code Quality Assessment

**Analysis target**: ForeverCommsVoice 0.2.2-beta, ForeverGroupComms 0.3.4-beta,
ForeverGuildComms 0.6.3-beta
**Analysis date**: 2026-10-25T04:00:00Z
**Target commit**: `f7f7bab`
**Diff baseline**: `57f7cdc`, spanning commits `8166b8b`, `6cf2f38`, `a64ac2a`
**Supersedes**: the `57f7cdc` pass of 2026-10-19T13:30:00Z

## Headline

The previous pass opened with "the bundle is now in a worse verified state than it was
one commit ago." That is no longer true in any respect. The suite is green, the
assertions have been shown to bite, a linter exists, every shipped module is loaded by a
harness, and the release gate checks every version location on both paths.

The remaining risk has not moved at all: **nothing has been run against a live Forever
client.** Offline confidence is now high and live confidence is still zero, and no
further harness work changes that.

## Verification performed

Executed, not inferred. Re-run after the follow-up work this pass prompted, so the figures
here describe the current working tree rather than `f7f7bab` alone; the per-commit
snapshot is in `reverse-engineering-timestamp.md`.

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 0 — PASSED: 28, FAILED: 0, TOTAL: 28** |
| `python tools/fault_inject.py` | **Exit 0 — 37 of 37 injected faults caught** |
| `luacheck .` (1.2.0) | **Exit 0 — 0 warnings, 0 errors, 53 files** |
| Archive leak check | No `wiki/`, audit, results or tooling content in the bundle |
| `python tools/package.py` | Exit 0 — 33-entry bundle |
| `python tools/check_bigwigs_bundle.py` | **Exit 0** — all three packages version-consistent |
| `python tools/package.py --source` | Exit 0 |
| `python tools/verify_package.py` | **Exit 0** |
| `SetScript("OnUpdate"` sweep, 25 modules | **Zero** |
| Modules loaded by no harness | **Zero** |
| `git ls-files --eol`, working tree vs `eol=lf` | 6 sources at `w/crlf` — **fixed**, now zero |

## Test Coverage

- **Overall**: **Good, and verified rather than asserted.** 28 harnesses, 4,363 lines,
  **109% of shipped Lua** (3,993 lines). Every one of the 25 shipped modules is loaded by
  at least one harness.
- **Unit / module tests**: offline Lua harnesses driving real modules against mocked WoW
  globals. No framework; plain `assert` with explanatory messages.
- **Integration tests**: `ForeverCommsVoice/tests/integration.lua` loads all three
  packages; `parity.lua` and `bytelimit.lua` assert cross-package invariants; eight
  GuildComms harnesses load the Voice source.
- **Mutation testing**: `tools/fault_inject.py` reverts one real guard at a time and
  confirms the harness that should notice does fail. **37 of 37.**

### Per package

| Package | Harnesses | Lines | Shipped lines | Ratio |
| --- | --- | --- | --- | --- |
| ForeverCommsVoice | 8 | 1,137 | 1,242 | 92% |
| ForeverGuildComms | 13 | 1,512 | 1,585 | 95% |
| ForeverGroupComms | 7 | 1,714 | 1,166 | **147%** |

GroupComms exceeds 100% because its quest-sync protocol is the only code in the bundle
that parses another player's data, and `protocol.lua` spends 273 lines on roughly 50
malformed and hostile payloads.

### What the mutation check revealed about the tests themselves

Four assertions passed while the behaviour they claimed to protect was removed, and were
rewritten. This is recorded because it is the most useful quality signal in this pass:

| Weak assertion | Why it did not bite |
| --- | --- |
| Non-roster sender rejection | Checked one peer key; a stranger's packet lands under its own key. Now asserts the whole peer table is empty |
| Outbox cancellation token | `ClearQuestPeers` also empties the queue, so the callback found nothing to send either way. Now bumps the token alone against a full queue |
| Hidden alert row forgetting its whisper target | Only checked rows that had never been populated. Now fills page 1, pages forward, and checks the vacated rows |
| Auto-skip field validation | Aimed at the wrong function; the options field is guarded by `SetQueueOption`, not `GetQueueSettings` |

## Code Quality Indicators

- **Linting**: **Configured, clean, and enforced by CI.** Root `.luacheckrc`,
  `std = lua51`, 28 declared writable globals, 58 read-only client APIs, `self = false`,
  and `global = false` for the mock-installing harnesses. **0 warnings and 0 errors across
  53 files**, down from 29 warnings. The workflow runs it through
  `tools/check_lua_quality.py` and fails the build on any warning, so the clean state is
  now held rather than merely achieved.
- **Strict dialect parse**: `tools/check_lua_quality.py` compiles **every** `.lua` file
  with `luac5.1 -p`. This is broader than the three syntax harnesses, which derive their
  file lists from the TOCs and therefore cannot cover a file that is not listed.
- **Code Style**: Consistent. 4-space indent, `A`/`V` namespace, `PascalCase` methods,
  `camelCase` state, guarded cross-file calls, `C_Timer` for all periodic work.
- **Documentation**: **Good.** Four READMEs with version-stamped release notes, two
  `PACKAGING.md`, nine steering files, a 9-page user wiki, and a 46-item ledger in
  `SUGGESTED-CHANGES.md` that records the decision and reasoning for every item
  including the one that was rejected.

## Previous findings — disposition

All ten headline findings from the `57f7cdc` pass:

| # | Finding | Disposition |
| --- | --- | --- |
| 1 | Suite red, 3 of 17 fail | **Fixed.** 28/28 pass |
| 2 | Queue harnesses resolve from the suite root | **Fixed.** Both derive `base` from `arg[0]` |
| 3 | `keybindings.lua` 5.1 fix reverted | **Fixed.** `local compile = loadstring or load` |
| 4 | CI no longer runs the harnesses | **Fixed.** Workflow installs `lua5.1` then runs `run_tests.py` before packaging |
| 5 | Both 0.5.1 regression tests deleted | **Fixed.** Restored and fault-injected |
| 6 | Seven stale version strings; the check retired | **Fixed.** 11 strings corrected; check ported into `check_bigwigs_bundle.py` and widened from 2 to 4 locations |
| 7 | Release pipeline replaced; four tools orphaned | **Fixed.** `tools/package.py` rewritten to read the same root `.pkgmeta` BigWigs reads; `package.ps1` reduced to a launcher |
| 8 | The queue itself is good work | **Still true.** Unchanged except `OnUpdate` → ticker |
| 9 | `Queue.lua` uses `OnUpdate` | **Fixed.** `C_Timer.NewTicker(0.5)`; zero `OnUpdate` in the bundle |
| 10 | Steering stale | **Fixed.** All eight addon steering files rewritten |

The previous "Carried forward unchanged" list, 13 entries:

| Entry | Disposition |
| --- | --- |
| `OnDefault` resets `outgoingMode`, copies one level deep | **Fixed** — preserves mode, uses `A:FillDefaults` |
| No floor between consecutive approvals | **Fixed** — `A.approvalFloorSeconds = 2` |
| Duplicated role-availability logic | **Fixed** — `A:CanFillRole` |
| `pendingMessages` holds records without a comment | **Fixed** |
| Profession-name fallback undocumented | **Fixed** — README limitations |
| Subtle's absent flair unexplained | **Fixed** — labels and README |
| No `.luacheckrc` | **Fixed** |
| `V:VoiceText` / `V:ChooseMessageTemplate` dead | **Fixed** — removed |
| `V:Render` undivided | **Fixed** — split into per-scope resolvers |
| Installer texts self-referential | **Fixed** |
| `math.random` unseeded | **Withdrawn as incorrect.** `math.randomseed` does not exist in the WoW client, which seeds the RNG itself at startup; a seed call would error at load. Both call sites now carry a comment saying so |
| `A.GetActivityType` is a dot-called closure | **Fixed** — state promoted to `A.activityTypes` / `A.activityType` in `Core.lua`, `A:GetActivityType` is now a real method, and the cycling is covered offline for the first time |
| `A.messageVariantBags` is unbounded | **Reframed and fixed.** "Unbounded" was the wrong diagnosis — see below. The real defect was stale bags, now reset on every accepted option write |

### Raised and closed in this span

| # | Item | Disposition |
| --- | --- | --- |
| 45 | Should the consumers embed the library under `Libs/` with LibStub? | **Rejected and recorded**, so it is not re-litigated. The library declares SavedVariables, which an embedded library cannot; see `dependencies.md` |
| 46 | Both consumers should refuse to load without the library, from `Core.lua` | **Done.** GroupComms had no check and degraded silently; GuildComms checked from `VoiceBridge.lua`, by which point `Core.lua` had published the namespace and created the dispatcher, so the addon half-ran. Both now refuse at the first statement. Covered by regression blocks in `verify.lua` and `safety.lua` and three fault-injection entries |

The previous `57f7cdc` assessment listed GroupComms' silent degradation as acceptable
because every library call was guarded. That was wrong in a way the guards hid: the
*fallback* approval path re-renders rather than replaying captured text, so what the
player approved and what was sent could differ. Guarding every call site is not the same
as the degraded state being correct.

### Closed in this span, externally

| # | Item | Disposition |
| --- | --- | --- |
| 43 | The 29 luacheck warnings | **Closed.** Now 0 warnings, 0 errors across 53 files |
| 44 | luacheck in CI | **Closed.** Enforced through `tools/check_lua_quality.py`, which fails the build on any warning |

Neither change altered behaviour: the lint pass was 48 insertions against 48 deletions,
and the suite stayed at 28/28 with the mutation check at 31/31 throughout.

## Technical Debt

**Two items remain in the ledger, and both need a live client.** For the first time in ten
passes there is no open work that can be done offline.

| # | Item | Effort | Note |
| --- | --- | --- | --- |
| 41 | Confirm the tabard login-ordering fix in-game | Low | Needs a live client |
| 42 | Walk the 32-step in-game checklist | Medium | Needs a live client |
| 43 | ~~Clear the 29 luacheck warnings~~ | — | **Closed externally.** Cleared by `eec9635` and `f7f7bab`: 48 insertions against 48 deletions, renaming shadowing parameters and removing unused locals. No behaviour change; suite and mutation check both still pass |
| 44 | ~~Add a luacheck step to the workflow~~ | — | **Closed externally.** `ae17bfa` added `tools/check_lua_quality.py` and the workflow now runs it as "Enforce Lua 5.1 syntax, tests and zero-warning lint" |

### One documentation defect found this pass

`LUA51-AUDIT.md` states as its starting point that the repository "already had `lua5.1`,
`luac5.1 -p`, Lua 5.1 harnesses and `luacheck --max-warnings 0`" in
`.github/workflows/package.yml`. That is not what the baseline contained.
`git show b712070:.github/workflows/package.yml` has only `lua5.1` and the harness step —
no `luacheck`, no `luac`, no `--max-warnings` anywhere in the file.

The effect is that the document *understates* its own contribution: adding the linter to
CI is the main achievement of this span, and a future reader would instead conclude it had
been there beforehand. Its other caveat — "No claim is made that the 29 historical
luacheck warnings have been resolved" — is also now stale; they are resolved, measured at
zero.

Two minor observations alongside it:

- `LUA51-AUDIT.md` and `Lua51-Test-Results.txt` are **not** named in the `.pkgmeta` ignore
  list. The built archive demonstrably excludes them, because `move-folders` ships only
  the three addon directories, but that is behaviour rather than an explicit exclusion.
  `wiki` *is* explicitly ignored.
- `Lua51-Test-Results.txt` is a committed 189-line test transcript. It will go stale the
  moment the suite changes, and nothing checks it.

### One tooling defect found and fixed this pass

`tools/fault_inject.py` restored each mutated source through `pathlib.Path.write_text`,
which opens in text mode and therefore translates `\n` to `os.linesep` — CRLF on this
machine. Every run silently rewrote the line endings of the files it touched, against the
`* text=auto eol=lf` policy in `.gitattributes`. `git ls-files --eol` showed six shipped
sources at `i/lf w/crlf attr/text eol=lf`: `ForeverCommsVoice/Core.lua`,
`ForeverGroupComms/Core.lua`, `ForeverGroupComms/TitanMenu.lua`,
`ForeverGroupComms/UI.lua`, `ForeverGuildComms/Core.lua` and
`ForeverGuildComms/VoiceBridge.lua`.

The committed blobs were never affected — the index is LF throughout, and `git diff`
reported the files as unchanged because check-in normalisation makes a CRLF working file
compare equal to an LF blob. The visible symptom was the opposite of useful: `git status`
listed files as modified while `git diff --numstat` showed no content for them at all.

Both halves are now fixed:

- Read and restore go through `newline=""`, so a restore is byte for byte.
- Multi-line fault anchors are rewritten to the newline the target file actually uses.
  Without this, byte-exact reading made two anchors miss in CRLF files and the run
  reported `31 - 2 = 29 / 29 caught` plus two skips, which reads like success. Masking an
  uncovered fault as a skipped one is the more dangerous failure of the two.

The working tree was then re-checked-out to LF. Measured after the repair: zero `w/crlf`
files, luacheck 0 warnings / 0 errors in 53 files, suite 28/28, mutation check 31/31, and
a repeat injection run leaves the tree clean.

### Both carried-forward code smells are now closed

Each had been reported for several passes as a style nit. Looking at them properly, one
had a cause worth fixing and the other had been diagnosed wrongly.

**`A.GetActivityType` was not merely called with the wrong sigil.** It was
`self.GetActivityType = function() return types[currentType] end`, closing over two
locals of `A:BuildRequestUI` that the cycling button mutates. Converting the call sites to
`:` would have satisfied the finding and fixed nothing. The state moved to
`A.activityTypes` and `A.activityType` in `Core.lua`, declared with the rest of the
up-front state, and `A:GetActivityType` is now an ordinary method.

Two things improved beyond consistency. `A:RequestText` had been protected from the method
being nil before the frame was built only by `A:UpdateRequestPreview` checking
`self.requestPreview` — a *different* field that happens to be assigned in the same
function, so the guard was correct by co-location rather than by design. And
`tests/variations.lua` had to stub the method, because a harness cannot reach state closed
over inside a frame builder; it now drives the real one. The cycling arithmetic was
covered by nothing at all before this, and is now asserted over two full laps plus an
out-of-range fallback.

**`A.messageVariantBags` was not an unbounded-growth problem.** The signature is
`scope:kind:language:accent`, but language and accent come from the player's current voice
profile, so exactly one of each is live at any instant. Growth is `scope × kind` for the
active profile, plus one family per profile change in a session — not the product of four
dimensions, and each entry is a small table holding an index array. The previous
description, "bounded by data shape, not by code", framed a memory risk that does not
exist.

The real defect was **staleness**: change language or accent and every bag under the old
signature is dead, never read again and never freed. `V:ResetVariantBags` now runs on any
*accepted* `V:SetOption` write. Resetting on every accepted key rather than just language
and accent is deliberate — `raceFilter` can reassign the accent, and `accentStrength`
changes how a selection renders, so enumerating the keys that matter is a rule with edge
cases while "any accepted write" has none. The cost is at most one repeated wording,
because a bag is anti-repetition state and never correctness. A refused write leaves the
bags alone, which is asserted separately.

Rejected: an LRU or an entry cap. Both add more machinery than the state they would
manage, and a cap would silently drop the `bag.last` anti-repeat guarantee at the moment
it fired.

## Patterns and Anti-patterns

### Good Patterns

- **One event dispatcher per addon**, with an `if not A.initialized then return end` gate
  and guarded routing to module methods.
- **Serial and epoch invalidation.** `groupSerial` stamps every staged group message and
  queued addon packet; `questEpoch` scopes completion replies. Both reject work that
  belongs to a group the player has left.
- **Single validating writer per setting.** `V:SetOption` owns the shared voice profile;
  `A:SetOption` owns GuildComms' settings. Settings panels and Titan menus both route
  through them rather than writing `db` directly.
- **Refuse rather than truncate at a bound.** The 60-entry outbox, the 12-chunk packet
  limit and the 30-entry approval list all decline work instead of silently shedding it;
  the two queues that do shed drop the oldest and never invoke its callback.
- **Fail closed on a missing API or dependency.** `A:CanManageGroup` denies when
  `UnitIsGroupLeader`/`UnitIsGroupAssistant` are absent rather than assuming permission.
  Both consumers' `Core.lua` refuse to load at all when `_G.ForeverCommsVoice` is unset,
  as the first statement, so the addon goes inert rather than running degraded. The
  degraded mode was shown to be *incorrect* and not merely reduced: the fallback approval
  path re-renders instead of replaying the text the player reviewed.
- **Explanatory comments at the point of decision**, including comments that record a
  *withdrawn* finding so it is not re-raised and "fixed" into a defect.

### Anti-patterns

- ~~**`A.GetActivityType` as a dot-called closure.**~~ **Fixed** — state promoted to the
  namespace, now an ordinary method.
- ~~**`A.messageVariantBags` unpruned.** Bounded by data shape, not by code.~~
  **Withdrawn as mis-stated, and the real defect fixed.** Growth was never the product of
  the four signature dimensions, because language and accent are single-valued per
  profile. The defect was stale bags surviving a profile change; they are now reset on any
  accepted option write.
- **Voice's event dispatcher lives in `Options.lua`, not `Core.lua`,** unlike the other
  two packages, and that file creates two bare frames. A known deviation recorded in
  `structure.md` rather than an accident, but it is where the `ADDON_LOADED` defect hid.
- **Three copies of the 250-byte UTF-8 clamp** (`V:Format`, `A:ChatLimit`, `A:Trim`).
  Deliberate, because each package must work if the library is absent — and now all three
  are asserted together by `bytelimit.lua`, which is the mitigation.
- **Two duplicated message tables** (GuildComms defaults vs the library's English guild
  catalog; GroupComms `variants` vs `groupTemplates.en`). Also deliberate for the same
  reason, and now asserted entry-by-entry by `parity.lua`.

## Overall

**Fair-to-good, and for the first time genuinely verified offline.** The gap between what
the documentation claims and what the code does has closed: the release gate runs on both
paths, the steering matches the code, and the ledger records every decision including the
rejected one. The honest limit is unchanged — this is beta software that has never been
loaded by the client it targets.
