# Code Quality Assessment

**Analysis target**: ForeverCommsVoice 0.2.1-beta, ForeverGroupComms 0.3.3-beta,
ForeverGuildComms 0.6.2-beta
**Supersedes**: the 0.1.1/0.2.1/0.5.1 pass of 2026-10-19T11:30:00Z (commit `62c3853`)
**Analysis date**: 2026-10-19T13:30:00Z
**Diff baseline**: `62c3853`, spanning commits `63222ea` and `57f7cdc`

## Summary

Two things happened in this span and they pull in opposite directions.

**The feature work is good.** A shared click-to-send review queue was added to the library
(`Queue.lua` + `QueueUI.lua`, 284 lines, 17 methods), and both consumers now delegate their
review backlogs to it instead of each maintaining one. GroupComms gained a Titan menu,
reaching parity with GuildComms. Common styling moved into the shared package, which is why
GuildComms' `UI.lua` *shrank* by 87 lines while gaining capability. The queue itself is
carefully built: explicitly transient with a comment explaining why callbacks and
session-scoped guild identities must not survive a reload, bounded at 100 entries, expiry
re-checked before an approving click can resurrect a stale item, `pcall` around the
consumer's send callback, and a `"stale"` reason contract so a consumer can tell the queue
to drop an item it can no longer honour.

**The verification work from the previous two commits was substantially undone**, and the
result is that the bundle is now in a worse verified state than it was one commit ago.

I ran the suite rather than reading it. **It is red: 3 of 17 harnesses fail.**

| Failing harness | Cause |
| --- | --- |
| `ForeverCommsVoice/tests/queue.lua` | Resolves modules from the **suite root** (`local root="ForeverCommsVoice/"`), the opposite of the convention every other harness uses |
| `ForeverCommsVoice/tests/queue_ui.lua` | Same |
| `ForeverGuildComms/tests/keybindings.lua` | The `load`/`loadstring` fix was reverted, so it again cannot run on Lua 5.1 |

And three guards were removed:

- **CI no longer runs the Lua harnesses.** The root workflow was rewritten around
  BigWigsMods/packager and the `run_tests.py` step is gone — regressing the recommendation
  that had been top of this list for five passes, one commit after it was closed.
- **Both 0.5.1 regression tests were deleted.** The Expressive block in `integration.lua`
  and the cross-package Restore Defaults block in `settings.lua` are gone. **All three
  underlying code fixes survive** — verified individually — but they are now unguarded.
- **`verify_package.py`'s version check is no longer run**, and the drift it prevented has
  already reappeared. I confirmed this by running it: it fails with
  `ForeverGuildComms/README.md does not mention version 0.6.2-beta`. The guard and the
  problem it guards against were removed and returned in the same commit.

This is the clearest example so far of why the recurring top recommendation matters. Every
failure above is one a CI test step would have caught before the commit landed.

## Verification Performed

| Action | Result |
| --- | --- |
| `python tools/run_tests.py` | **Exit 1. PASSED: 14, FAILED: 3, TOTAL: 17** |
| Checked each 0.5.1 fix in source | All three present: terminal-period conversion at `Core.lua:175-180`, the `panel.OnDefault` comment and absent voice reset at `Options.lua:268-276`, the `engine:SetOption` delegation at `Core.lua:332-336` |
| Searched for the deleted regression blocks | 0 references to the Expressive assertions in `integration.lua`; 0 to the shared-profile assertions in `settings.lua` |
| `python tools/verify_package.py` | **Exit 1**, failing on the GuildComms README version drift — the check CI no longer runs |
| Version sweep across TOC / `Core.lua` / README / installer `.cmd` | 7 stale strings, enumerated below |
| Mechanical re-measurement | 25 modules, 3,806 shipped lines, 152 methods, 17 harnesses, 1,215 test lines |
| `SetScript("OnUpdate"` search | Exactly one, `Queue.lua:70` — the only one in the bundle |

**Not verified**: the BigWigs packaging path. `BigWigsMods/packager@v2` is a GitHub Action
and cannot run locally, so unlike the previous span's offline builders I could not execute
the release pipeline. `tools/check_bigwigs_bundle.py` was read but not run, because it
requires a `.release/` directory the packager produces. Nothing has been tested against a
live Forever client.

## Status of the Previous Recommendations

| # | Recommendation | Status |
| --- | --- | --- |
| ~~prev 1~~ | Run the 13 Lua harnesses in CI | **REGRESSED.** Closed in `63222ea`, removed in `57f7cdc`. The root workflow no longer has a test step. Sixth consecutive pass as the top item |
| 1 | Add `tests/syntax.lua` to Voice and GroupComms | **RESOLVED and partly kept.** Both exist and both derive their module list from the TOC — GroupComms' also compiles `Bindings.xml` handlers. However **GuildComms' was reverted** to its hand-maintained nine-element list, losing TOC derivation and binding coverage. Net: 2 of 3 in the intended form |
| 2 | Fix the three ForeverCommsVoice installer texts | **Not done.** Still states the library depends on itself |
| 4 | Decide the Expressive scope question | **Not done**, and now worse: the test that pinned the guild-scope behaviour was deleted, so neither scope is asserted |
| 5 | Make `package.cmd` prefer the Python builder, or verify the PowerShell build | **Moot and superseded.** Neither builder is on the CI path any more; both are orphaned. See new finding #4 |
| 6 | Make `OnDefault` preserve `outgoingMode` | **Not done** |
| 7 | Refresh the stale steering "Known deviation" blocks and the version-location count | **RESOLVED in `63222ea`**, but the steering has gone stale again in a different way. See new finding #6 |
| 8-10 | Test GroupComms chat-safety rails, `parseIDs` rejections, the `questSync` opt-out | **Not done** |
| 11 | Add `.luacheckrc` | **Not done** |
| 12 | Delete `V:VoiceText` and `V:ChooseMessageTemplate` | **Not done** |
| ~~13~~ | Clean up `verify_package.py` | **RESOLVED in `63222ea`** — and the file is now unused by CI |
| 14 | Harnesses for GroupComms `UI.lua` and `Options.lua` | **Not done.** Both changed this span and remain loaded by nothing |
| 15 | Assert the duplicated template tables match | **Not done** |
| 16 | Split `V:Render` into scope-specific resolvers | **Not done** |
| 17 | Key approval and suggestion rows by a monotonic id | **RESOLVED incidentally, and well.** The shared queue assigns `V.reviewNextID` monotonically and all operations key on `item.id` via `V:FindQueueItem`. Both consumers' positional row binding is replaced by the shared implementation |
| 18 | Drive `UpdateApprovalsUI` in a harness | **Partly.** `queue_ui.lua` exercises the shared list UI with a frame mock — but it does not currently run |
| 19-20 | Confirm the tabard fix in-game; remaining trivial items | **Not done** |

## Test Coverage

- **Overall**: Poor-to-fair, and **unverified** — the suite does not pass and nothing runs
  it automatically. 17 harnesses, 1,215 lines, 32% of shipped Lua.
- Per package: Voice 4 harnesses / 243 lines; GuildComms 11 / 828; GroupComms 2 / 144.

### Module coverage

| Package | Covered | No harness loads it |
| --- | --- | --- |
| Voice | `Core`, `Languages`, `Accents`, `RaceProfiles`, `MessageVariants`, `GroupPhrases`, and via the two queue harnesses `Queue`, `QueueUI` — **but those two harnesses fail** | **`Options.lua`** |
| GuildComms | all 9 | — |
| GroupComms | `Core`, `Roster`, `Quests` | **`UI.lua`**, **`Options.lua`**, **`Broker.lua`**, **`TitanMenu.lua`** |

GroupComms gained `TitanMenu.lua` (114 lines, 4 methods) with no harness, taking its
uncovered count from three modules to four. GuildComms' equivalent has had a dedicated
harness since 0.4.1, so this is a parity gap in testing as well as a parity gain in
features.

### The two new queue harnesses are good tests that cannot run

`queue.lua` (89 lines) and `queue_ui.lua` (65 lines) are worth keeping. `queue.lua` covers
the options gate, enqueue validation, expiry, the approve-after-expiry race, and the
`OnUpdate` watcher by capturing the registered handler. `queue_ui.lua` mocks the frame API
to exercise the shared list.

Their only problem is the working directory. They open `ForeverCommsVoice/Core.lua`,
which resolves from the **suite root**, while every other harness in the project — and the
runner, and `testing.md` — uses the **package root**. The header comment says so
explicitly: `Run from the suite root: texlua ForeverCommsVoice/tests/queue.lua`. Two
conventions now coexist and neither file can satisfy both.

The fix is small: adopt the established preamble
(`arg[0]:match("^(.*[/\\])tests[/\\]queue%.lua$") or "./"`) and drop the `root` prefix.

### Remaining untested paths, ranked

1. **Nothing runs the suite automatically**, and the suite is red.
2. **The two 0.5.1 fixes are unguarded** after their regression tests were deleted.
3. **`keybindings.lua` cannot execute**, so the "no keybinding path sends a guild message"
   assertion is again assumed rather than tested.
4. GroupComms' `TitanMenu.lua`, `UI.lua`, `Options.lua`, `Broker.lua` and Voice's
   `Options.lua` — five modules, 468 lines, loaded by nothing.
5. GroupComms' chat-safety rails; `parseIDs` and `OnAddonMessage` rejections; the
   `questSync` opt-out.
6. The BigWigs packaging path, which cannot be exercised locally at all.
7. The duplicated template tables.

## Code Quality Indicators

- **Linting**: none, for any language. Now also covering 284 lines of new Lua and a third
  Python tool.
- **Code Style**: the new Lua is consistent with the house style and `Queue.lua` is
  notably tidy — file-local `now()` and `integer()` helpers, validation separated from
  mutation, early returns. One rule is broken; see new finding #1.
- **Documentation**: the per-package READMEs gained accurate "Shared review queue"
  sections, and the root `README.md` and `PACKAGING.md` describe the new BigWigs path. But
  three README version numbers are stale and `PACKAGING.md` now documents **two**
  mutually exclusive release paths without saying which is authoritative — it still
  describes `tools/package.py` as the build command while the workflow uses BigWigs.
- **Error handling**: good. `Queue.lua` validates every enqueue field, clamps all numeric
  settings through one `integer()` helper with NaN and infinity guards, `pcall`s the
  consumer callback, and treats a non-`true` return as a failed send rather than assuming
  success. `check_bigwigs_bundle.py` fails loudly with specific messages.
- **Global hygiene**: clean.

## Technical Debt

### New findings

#### 1. `Queue.lua` drives expiry from an `OnUpdate` handler
**Severity: low functional, direct steering violation.**

```lua
watcher:SetScript("OnUpdate",function(_,dt)
    if #V.reviewQueue==0 then return end
    elapsed=elapsed+(dt or 0)
    if elapsed>=0.5 then ... end
end)
```

`.kiro/steering/lua-style.md` lists under **Avoid**: "`OnUpdate` scripts for periodic
work; use `C_Timer.After` / `C_Timer.NewTicker`". This is the only `OnUpdate` in the
bundle, and the rest of the project uses `C_Timer` consistently — including for the
GuildComms queue drain, the roster ticker and the event-cache prune.

The implementation is defensive about it: an early return when the queue is empty and a
0.5-second throttle. But `C_Timer.NewTicker(0.5, ...)` does the same job, matches the
convention, and does not run a function on every frame. The one thing `OnUpdate` offers
here — sub-second countdown refresh — is also achievable with a ticker.

#### 2. Two harness working-directory conventions now coexist
**Severity: medium. The direct cause of 2 of the 3 failures.**

Covered above. Worth noting the structural point: the project had one convention, the
runner and steering both encode it, and the new harnesses adopted a different one. Because
nothing ran the suite in CI, this shipped.

#### 3. Reverted verification work
**Severity: medium-high. The main concern of this pass.**

| Reverted | Consequence |
| --- | --- |
| `run_tests.py` step in the root workflow | Nothing automatically runs the harnesses. Sixth pass as the top item |
| Expressive block in `integration.lua` | The restored terminal-period behaviour is unguarded |
| Restore Defaults block in `settings.lua` | The cross-package isolation is unguarded; a future `OnDefault` edit could silently reset GroupComms' voice again |
| `loadstring or load` in `keybindings.lua` | That harness cannot execute at all |
| TOC derivation in GuildComms' `syntax.lua` | Back to a hand-maintained list, and `Bindings.xml` handlers are no longer compile-checked |

The code fixes themselves all survive. The risk is specifically that nothing now detects
their regression — which is exactly the state that let the Expressive conversion go missing
during the original extraction.

#### 4. Four release tools are orphaned while still being documented
**Severity: medium.**

CI now runs BigWigs plus `check_bigwigs_bundle.py`. Still present and still documented:
`tools/package.py` (97 lines), `tools/verify_package.py` (89), `package.ps1` (72),
`package.cmd` (11), `run-tests.cmd` (15), `tools/run_tests.py` (120). `PACKAGING.md` line 5
still instructs the reader to build with `package.cmd` or `python tools/package.py`, while
the workflow does neither.

The previous pass flagged "two implementations of one contract" as a drift risk. There are
now **three** release paths — BigWigs via root `.pkgmeta`, the Python builder, and the
PowerShell builder — and only the first is exercised. Either retire the offline builders or
state plainly which path is authoritative and which is a convenience.

#### 5. Seven stale version strings, and the check that caught them is no longer run
**Severity: medium.**

| Location | Voice | GuildComms | GroupComms |
| --- | --- | --- | --- |
| TOC | 0.2.1 | 0.6.2 | 0.3.3 |
| `Core.lua` | **0.2.0** | 0.6.2 | 0.3.3 |
| README title | 0.2.1 | **0.6.1** | **0.3.1** |
| installer `.cmd` x2 lines | **0.1.1** | **0.5.1** | **0.2.1** |

Plus `ForeverGuildComms/README.md` still says "Requires ForeverCommsVoice 0.1.0-beta",
four Voice releases out of date.

The notable part is the sequencing. `verify_package.py` asserts the TOC version appears in
that package's README. It was added specifically to stop this drift, it was removed from CI
in the same commit that introduced the drift, and running it now reproduces the failure
exactly. The installer `.cmd` files were already the worst-maintained location before this
span and are now one to four releases behind.

#### 6. Steering is stale again, in the opposite direction
**Severity: medium.**

`testing.md` now asserts things that are no longer true: that CI runs
`python tools/run_tests.py` before packaging, and that the expected result is
`PASSED: 13   FAILED: 0`. `release-packaging.md` describes `tools/package.py` as "**The
builder CI runs**" and gives a table of the offline pipeline as the implementation. Both
were accurate at `63222ea` and were invalidated by `57f7cdc`.

The interpreter section added last span is still correct and is the most useful part of
`testing.md`; it should survive any rewrite.

#### 7. Smaller observations

- **`V:Print` is defined at the bottom of `Queue.lua`.** It is a general helper and every
  other package keeps `Print` in `Core.lua`. Voice had none before, so a feature module now
  owns a core helper.
- **The queue persists UI position but is documented as transient.** The header comment
  says "Never persisted", which is true of `reviewQueue` itself, but `GetQueueSettings`
  stores `visibleRows`, `autoSkipSeconds`, `sourceDisplay`, `showOnNew`, `x` and `y` in
  `ForeverCommsVoiceCharDB.queue`. The distinction is correct in code but the comment
  reads as covering the whole module.
- **`autoSkipSeconds` defaults to 20 and silently discards messages.** A queued greeting
  disappears after 20 seconds unless clicked. That is a defensible anti-spam default and
  `0` disables it, but it is a new way for a message to be dropped without the user acting,
  and the READMEs do not call out the default.
- **The root `.pkgmeta` uses `move-folders`** to lift three addons out of a
  `ForeverCommsBundle/` wrapper. `check_bigwigs_bundle.py` asserts the result has exactly
  the three expected top-level folders, which is the right guard for that technique.
- **`check_bigwigs_bundle.py` raises `SystemExit` with messages rather than using the
  `check()` pattern** introduced in `verify_package.py` last span. Functionally fine,
  stylistically divergent from its sibling.
- **GroupComms' `Options.lua` lost 4 lines** and still implements none of the three
  Settings canvas callbacks, so it remains the one panel that can display stale values.

### Carried forward unchanged

`OnDefault` resets `outgoingMode` and copies one level deep. No floor between consecutive
approvals in GuildComms. `A.GetActivityType` is a dot-called closure. Duplicated
role-availability logic. `pendingMessages` holds records without a comment. The
profession-name fallback is undocumented. Subtle's absent flair is unexplained. No
`.luacheckrc`. `V:VoiceText` and `V:ChooseMessageTemplate` are dead. `V:Render` is
undivided. `A.messageVariantBags` is unbounded. The three
ForeverCommsVoice installer texts are self-referential.

**Withdrawn finding: "`math.random` is unseeded."** This was raised by earlier passes and
is incorrect. `math.randomseed` does not exist in the WoW client, which seeds the RNG
itself at startup ([warcraft.wiki.gg, API:fastrandom](https://warcraft.wiki.gg/wiki/API:fastrandom)),
so there is nothing to seed and a seed call would error at load. Both shuffle sites are
correct as written. The repeating sequence is visible only when running the offline
harnesses, where plain Lua 5.1 defaults to seed 1, and the tests rely on that. Tracked as
item 25 in `SUGGESTED-CHANGES.md`, decided **SKIP**. Do not re-raise it.

Both call sites now carry a comment saying so: `V:Pick` in `ForeverCommsVoice/Core.lua`
holds the reasoning, and the GroupComms site cross-references it. That was the missing
piece — this withdrawal was first recorded only in documents, which would not have
stopped a source-reading pass from filing it a third time. The resulting convention,
"a withdrawn finding gets a comment at the code site", is in the Comments section of
`.kiro/steering/lua-style.md`.

## Patterns and Anti-patterns

### Good Patterns

New this span:

- **A shared capability replacing two parallel implementations.** Both consumers had a
  review backlog; there is now one, in the library, and GuildComms' `UI.lua` got smaller
  as a result. This is the same move as the original voice extraction and it is the right
  instinct.
- **Monotonic IDs for queue items**, closing a finding carried since 0.4.1 as a side
  effect of doing the larger thing properly.
- **Deliberate non-persistence, with the reason recorded.** "callbacks and
  session-specific guild/group identities must not survive login/reload" is exactly the
  kind of comment this project does well.
- **Expiry re-checked at approval time.** `V:Approve` tests `expiresAt` before calling the
  callback, so an expired item cannot be resurrected by a click that overlaps the sweep.
- **A failure contract between library and consumer.** The callback returns `true` for
  sent, and a `"stale"` reason tells the queue to drop an item the consumer can no longer
  honour — so the library never has to know why a guild changed.
- **`pcall` around a callback supplied by another addon**, treating a non-`true` return as
  failure rather than assuming success.
- **One numeric validator for all queue settings**, with NaN and infinity guards, matching
  `A:NormalizeTiming`'s approach in GuildComms.
- **A structural guard for a packaging technique.** `check_bigwigs_bundle.py` asserts the
  `move-folders` result has exactly three top-level folders and no `tests/`, `install/` or
  `.github/` — which is the specific thing that technique can get wrong.

### Anti-patterns

- **Removing a guard in the same change that introduces the problem it guards against**,
  evidenced by the version drift and the retired README check.
- **Deleting regression tests while keeping the fixes they protect.**
- **Committing a red test suite**, possible only because nothing runs it.
- **A second working-directory convention for harnesses** in a project that had one.
- **Three release paths, one exercised, and documentation pointing at an unexercised one.**
- **An `OnUpdate` handler where the project's own rules require `C_Timer`.**
- **Steering describing a pipeline that was replaced one commit later.**
- A generic defaults handler resetting a safety-relevant setting. Positional binding
  elsewhere. Dead code retained.

## Security Posture

Unchanged in substance. No network surface in the addons, no credential handling, no file
I/O outside SavedVariables, no `loadstring` in shipped code, no vendored libraries. All
gear, invite, role, targeting and quest-acceptance actions remain with the player.
GroupComms' quest protocol is untouched this span, including all eleven inbound
validations and the epoch guard.

The new queue does not widen the surface and in one respect narrows it: a message now
requires a click **and** must not have expired, and the consumer re-validates before
sending via its own callback. Three observations, none a defect:

- The queue holds **function references** supplied by other addons and `pcall`s them. That
  is the correct shape, and the deliberate non-persistence means a stale callback cannot
  survive a reload.
- `autoSkipSeconds` introduces time-based discarding of pending messages. For a
  guild-chat addon, silently dropping an unsent message is the safe direction.
- `check_bigwigs_bundle.py` asserts no `tests/`, `install/` or `.github/` content reaches
  a release archive, which is a real supply-chain-shaped check on the packaging output.

## Recommendations

Ordered by value relative to effort.

| # | Recommendation | Effort | Rationale |
| --- | --- | --- | --- |
| 1 | **Get the suite green**: fix `queue.lua` and `queue_ui.lua` to use the package-root preamble, and restore `local compile = loadstring or load` in `keybindings.lua` | Trivial | Three failures, all mechanical. Nothing else on this list is meaningful while the suite is red |
| 2 | **Restore the `run_tests.py` step to the root workflow**, before the BigWigs build | Trivial | Sixth consecutive pass as the top item, and every other finding in this pass is something it would have caught. The step is four lines and the previous version is in `63222ea` if needed |
| 3 | **Restore the two deleted regression tests** | Low | The Expressive and Restore Defaults fixes are live and unguarded. Both tests exist in `63222ea` and can be recovered verbatim |
| 4 | Fix the seven stale version strings, and either re-run `verify_package.py`'s version check in CI or port it into `check_bigwigs_bundle.py` | Low | The drift is already present and the check that catches it is sitting unused in the repository |
| 5 | Decide which release path is authoritative and retire or clearly demote the others | Low | Three paths, one exercised, and `PACKAGING.md` instructs readers to use an unexercised one |
| 6 | Rewrite the CI and release sections of `testing.md` and `release-packaging.md` for the BigWigs pipeline, keeping the interpreter section | Low | Both now assert things that are not true. Keep the interpreter guidance verbatim |
| 7 | Restore TOC derivation and `Bindings.xml` coverage in GuildComms' `syntax.lua` | Trivial | The other two packages have it; GuildComms is the one that most needs it, having the most modules and the only `Bindings.xml` with three handlers |
| 8 | Move `Queue.lua`'s expiry sweep to `C_Timer.NewTicker` | Low | The bundle's only `OnUpdate`, against an explicit project rule |
| 9 | Add a harness for GroupComms' `TitanMenu.lua`, reusing GuildComms' `titanmenu.lua` mock | Medium | New module, zero coverage, and a working mock for the same API already exists |
| 10 | Document `autoSkipSeconds` and its 20-second default in both consumer READMEs | Trivial | A new way for a pending message to disappear without user action |
| 11 | Fix the three ForeverCommsVoice installer texts *(carried)* | Trivial | Still says the library depends on itself |
| 12 | Move `V:Print` from `Queue.lua` to Voice's `Core.lua` | Trivial | A core helper living in a feature module |
| 13 | Harnesses for GroupComms `UI.lua` and `Options.lua`, and Voice `Options.lua` *(carried)* | Medium | Five uncovered modules, 468 lines |
| 14 | Remaining carried items: `OnDefault` and `outgoingMode`; `.luacheckrc`; delete `V:VoiceText`; split `V:Render`; assert the duplicated tables; the Expressive scope question; the trivial documentation items | Trivial to Medium | Unchanged |

### Assessment

**The feature direction is right and the execution of the queue is good.** Consolidating
two review backlogs into one shared, ID-keyed, bounded, expiry-aware implementation is the
same sound instinct as the original voice extraction, and it closed a finding carried since
0.4.1 along the way.

**The engineering discipline around it regressed sharply.** A red suite was committed and
pushed; the test step that would have blocked it was removed in the same commit; two
regression tests protecting live fixes were deleted; a version guard was retired and its
drift reappeared immediately; and the steering now documents a pipeline that no longer
exists.

None of this is hard to repair — recommendations 1 through 3 are a trivial, a four-line and
a recoverable-from-git change respectively, and together they restore the position reached
at `63222ea`. The lesson is narrower than it looks: this project's reviews have repeatedly
found that it writes good code and good tests, and then does not arrange for anything to
run them. The sixth consecutive appearance of that recommendation is no longer a
suggestion about tooling; it is the single thing distinguishing this pass from the last.
