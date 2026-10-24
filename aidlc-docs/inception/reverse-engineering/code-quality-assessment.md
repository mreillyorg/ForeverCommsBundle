# Code Quality Assessment

**Analysis target**: ForeverCommsVoice 0.2.2-beta, ForeverGroupComms 0.3.4-beta,
ForeverGuildComms 0.6.3-beta
**Analysis date**: 2026-10-25T02:30:00Z
**Target commit**: `a64ac2a`
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

Executed, not inferred.

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 0 — PASSED: 28, FAILED: 0, TOTAL: 28** |
| `python tools/fault_inject.py` | **Exit 0 — 28 of 28 injected faults caught** |
| `luacheck .` (1.2.0) | 29 warnings, **0 errors**, 53 files |
| `python tools/package.py` | Exit 0 — 33-entry bundle |
| `python tools/check_bigwigs_bundle.py` | **Exit 0** — all three packages version-consistent |
| `python tools/package.py --source` | Exit 0 |
| `python tools/verify_package.py` | **Exit 0** |
| `SetScript("OnUpdate"` sweep, 25 modules | **Zero** |
| Modules loaded by no harness | **Zero** |

## Test Coverage

- **Overall**: **Good, and verified rather than asserted.** 28 harnesses, 4,138 lines,
  **105% of shipped Lua** (3,927 lines). Every one of the 25 shipped modules is loaded by
  at least one harness.
- **Unit / module tests**: offline Lua harnesses driving real modules against mocked WoW
  globals. No framework; plain `assert` with explanatory messages.
- **Integration tests**: `ForeverCommsVoice/tests/integration.lua` loads all three
  packages; `parity.lua` and `bytelimit.lua` assert cross-package invariants; eight
  GuildComms harnesses load the Voice source.
- **Mutation testing**: `tools/fault_inject.py` reverts one real guard at a time and
  confirms the harness that should notice does fail. **28 of 28.**

### Per package

| Package | Harnesses | Lines | Shipped lines | Ratio |
| --- | --- | --- | --- | --- |
| ForeverCommsVoice | 8 | 1,053 | 1,221 | 86% |
| ForeverGuildComms | 13 | 1,439 | 1,560 | 92% |
| ForeverGroupComms | 7 | 1,646 | 1,146 | **144%** |

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

- **Linting**: **Configured.** Root `.luacheckrc`, `std = lua51`, 28 declared writable
  globals, 58 read-only client APIs, `self = false`, and `global = false` for the
  mock-installing harnesses. 0 errors. Not yet wired into CI — item 44.
- **Code Style**: Consistent. 4-space indent, `A`/`V` namespace, `PascalCase` methods,
  `camelCase` state, guarded cross-file calls, `C_Timer` for all periodic work.
- **Documentation**: **Good.** Four READMEs with version-stamped release notes, two
  `PACKAGING.md`, nine steering files, and a 44-item remediation ledger in
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
| `A.GetActivityType` is a dot-called closure | **Open** — `ForeverGuildComms/UI.lua:145` |
| `A.messageVariantBags` is unbounded | **Open** — `ForeverCommsVoice/Core.lua:14` |

## Technical Debt

Four items remain in the ledger, plus the two carried-forward smells above.

| # | Item | Effort | Note |
| --- | --- | --- | --- |
| 41 | Confirm the tabard login-ordering fix in-game | Low | Needs a live client |
| 42 | Walk the 32-step in-game checklist | Medium | Needs a live client |
| 43 | Clear or deliberately silence the 29 luacheck warnings | Low | 15 are widget handlers whose `function(self)` shadows the method's `self`; 14 are unused arguments and locals |
| 44 | Add a luacheck step to the workflow | Trivial | Depends on deciding whether warnings fail the build |

Two code smells, neither a defect:

- **`A.GetActivityType`** (`ForeverGuildComms/UI.lua:145`) is assigned as a closure on the
  namespace and called with `.` rather than `:`. It works, but it is the only method in
  the bundle shaped that way.
- **`A.messageVariantBags`** (`ForeverCommsVoice/Core.lua:14`) grows one entry per
  `scope:kind:language:accent` signature and is never pruned. Bounded in practice by the
  product of those four dimensions, so it cannot grow without limit, but nothing enforces
  it.

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
- **Fail closed on a missing API.** `A:CanManageGroup` denies when
  `UnitIsGroupLeader`/`UnitIsGroupAssistant` are absent rather than assuming permission.
- **Explanatory comments at the point of decision**, including comments that record a
  *withdrawn* finding so it is not re-raised and "fixed" into a defect.

### Anti-patterns

- **`A.GetActivityType` as a dot-called closure.** Inconsistent with every other method.
- **`A.messageVariantBags` unpruned.** Bounded by data shape, not by code.
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
