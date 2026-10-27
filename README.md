# Forever Comms: Three-Addon Bundle

For **WoW Forever 1.60.1**. Author: Michael Reilly.

This bundle contains:

- **ForeverCommsVoice 0.7.2-beta**: shared 8-language text, 29 curated accent/RP voice profiles, per-character voice preferences and one-time GuildComms settings migration.
- **ForeverGuildComms 0.7.2-beta**: existing guild alerts, welcome/levels/help, keybindings and custom templates; `VoiceBridge.lua` now calls the shared library.
- **ForeverGroupComms 0.7.2-beta**: party/raid greetings, roles, pull/CC instructions, ready checks, markers, quest synchronisation and translated group communication.

## Install on Windows

1. Extract this entire ZIP, keeping the three addon folders and the `install` folder together.
2. Run `install\Install-ForeverComms.cmd` and select the WoW Forever `_classic_beta_` folder if prompted. (Or run the PowerShell file with `-GamePath`.)
3. Reload/restart WoW. Go to Settings > AddOns > Forever Comms Voice, or type `/fcv` to set your shared voice. GuildComms: `/fgc`; GroupComms: `/fgp`.

The installer stages all three addons before modifying the current installation, backs up previous addon directories under `AddOns\AddOnBackups`, and attempts a rollback on failure. It does not alter your existing `WTF` SavedVariables.

## Manual installation

Copy the **three** addon directories directly into `_classic_beta_\Interface\AddOns`. The game expects `ForeverCommsVoice\ForeverCommsVoice.toc`, etc. The updated GuildComms and GroupComms declare `ForeverCommsVoice` as a **required** dependency; without it neither addon will load. The three individual ZIPs are also provided for addon-manager use.

## Compatibility / beta limits

The voice library changes **only addon-generated messages**, never arbitrary typed chat. Settings are stored per character, and migrated legacy voice preferences from GuildComms are copied **once**. Guild custom templates remain unaltered. Group quest syncing is unaffected by the shared voice engine. Offline tests ran; UI behavior and messaging require confirmation in the actual WoW Forever client.

## Shared message review queue (0.6.1-beta)

ForeverCommsVoice owns one movable, scrollable approval window for both addons.
GuildComms in **Verify with a click** mode sends its greetings and level congratulations to this queue, replacing the old Guild-only approval window. GroupComms sends its staged group greetings and level suggestions to the same queue, replacing the small suggestion list on the Group panel. Automatic Guild/Group sending modes and manual quick-action buttons retain their prior behaviour.

Open the queue using **`/fcv queue`**, **`/fgc verify`**, or **`/fgp queue`**. A checkbox beside each message immediately attempts to send it through its original addon, or **Skip** removes it without sending. Successful handling removes a record and immediately reveals the next one. A failed send stays pending; a stale guild/group entry is skipped rather than retargeted.

Settings > AddOns > **Forever Comms Voice** configures **1–10 visible rows**, **Guild/Group text vs icons**, **auto-skip seconds (0–3600; 0 disables)** and **auto-open on new messages**. The list scrolls using the scrollbar or mouse wheel; drag the titlebar to move it. Position and display settings are saved per character.

**Safety:** The timer starts when each record is staged, even while the window is hidden or the entry is scrolled out of sight. A timeout *never* sends chat: it silently skips that record. Producers may override the default timeout per record via `Enqueue{timeout=seconds}`. Pending callbacks exist in memory only, so logging out/reloading discards pending messages; no old group or guild message can leak into another session. The queue holds up to 100 transient records and drops the oldest if full.


Queue presentation: a compact, movable, scrollable floating overlay (not a normal Blizzard window). Fresh character defaults are **2 visible rows** and **20 seconds** auto-skip; existing saved queue preferences remain unchanged. `/fcv queue` opens the overlay.

## Titan Panel menus (0.6.2-beta)

Right-click **Group Comms** for nested Group status, Greetings & congratulations, Dungeon coordination, Target marking, Quest sharing & checks and Quick actions. The status submenu reports live roster and role counts, chat channel, quest-sync state and Group review count. Both **Guild Comms** and **Group Comms** offer a top-level **Open Review Panel** action for the shared ForeverCommsVoice floating queue. Left-click and Shift-click retain their previous GroupComms actions.
## Testing

```text
run-tests.cmd                 (Windows)
python tools/run_tests.py     (any platform)
```

Runs every offline Lua harness across the three addons and prints a pass/fail summary.
Needs Python 3 and a Lua **5.1** interpreter — the dialect the client embeds. No WoW
client required. See `.kiro/steering/testing.md` for how an interpreter is located.

None of it replaces in-game testing. Nothing in this bundle has been run against a live
Forever server, and each addon's README lists what that leaves unverified.

## What changed in 0.7.2-beta

**Fixes the download itself. No addon changed.**

The 0.7.1-beta archive contained a spurious fourth top-level folder,
`ForeverCommsBundle/`, holding nothing but a generated `CHANGELOG.md`. Extracted into
`Interface\AddOns` it left behind a folder that is not an addon. **If you installed
0.7.1-beta, you can simply delete that `ForeverCommsBundle` folder** — nothing used it.

The cause was in the release tooling: the packager generates its changelog inside a
staging folder, then deletes that folder after lifting the three addon folders to the top
level — but only if it is empty. The generated file kept it alive. The project now
supplies its own `CHANGELOG.md` and keeps it out of the copied files, so the staging
folder really is empty and is removed as intended. The local build now fails outright if
that configuration is ever broken again, instead of the fault reaching a release.

Every file the three addons load in the game is identical to 0.7.1-beta — same settings,
messages, windows, commands and keybindings, and no saved settings renamed or removed.

## What changed in 0.7.1-beta

**A packaging change. No addon changed.** The release archive was restricted to the three
addon folders, so project files that have no business in it — the development
documentation, the lint and git configuration, `LICENSE`, `run-tests.cmd` — can no longer
be swept in by the packager.

Superseded by 0.7.2-beta, which fixes the stray folder described above.

## What changed in 0.7.0-beta

**The three addons were given one shared version number.** They had been versioned
separately, reaching ForeverCommsVoice 0.2.3-beta, ForeverGuildComms 0.6.4-beta and
ForeverGroupComms 0.3.5-beta. Since they are built, tested, bundled and installed
together, three numbers only ever answered "which version do I have?" with a question.

ForeverCommsVoice going from 0.2.3-beta to 0.7.0-beta was therefore **not** a rewrite — the
same addon, renumbered to match its siblings. The same applies to ForeverGroupComms. No
addon behaviour changed in that release either.

It also carried one fix invisible from inside the game: the automated build installed the
Lua linter under the wrong package name, so the checks meant to gate a release could not
run for 0.6.4-beta.

Each addon's README carries its own changelog, including the per-addon history from before
the numbers were unified.

## Building a release

**[BigWigsMods/packager](https://github.com/BigWigsMods/packager) is the authoritative
release path**, running in GitHub Actions on a `v*` tag.

To build the same archive locally, without pushing a tag:

```text
package.cmd                   (Windows)
python tools/package.py       (any platform)
```

The local builder reads the **same root `.pkgmeta`** BigWigs reads, so there is one source
of truth for what ships. It writes `.release/ForeverCommsBundle-<version>.zip` and then
validates it with the same `tools/check_bigwigs_bundle.py` that CI runs — three top-level
addon folders, runtime files only, both `Bindings.xml`, no tests, installers or docs. A
green local build means the release archive is correctly shaped.

`python tools/package.py --source` additionally produces the installer-bearing source
archives used for manual Windows installation. BigWigs does not produce those.

Full details, including every build-time validation, are in [PACKAGING.md](PACKAGING.md).
