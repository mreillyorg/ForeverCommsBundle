# Forever Comms Suite 0.5.1-beta

WoW Forever Interface 16001. This bundle contains:

| Addon | Version | Purpose |
| --- | --- | --- |
| ForeverCommsVoice | 0.1.1-beta | Shared character language, translations, accents and race styles |
| ForeverGuildComms | 0.5.1-beta | Guild welcomes, alerts, level messages, crafting and help |
| ForeverGroupComms | 0.2.1-beta | Party/dungeon/raid communication, roles, ready checks, targeting and quest sharing |

## Installation

1. **Extract the complete ZIP** rather than running files from inside the archive.
2. On Windows, run `install/Install-ForeverComms.cmd`. It installs the shared Voice addon **first**, then GuildComms and GroupComms, with backups of existing addon directories under `Interface/AddOnBackups`.
3. Restart WoW Forever to refresh the addon list icons (or `/reload` for Lua changes).
4. Configure your character's shared speaking style through `/fcv`. GuildComms is `/fgc`; GroupComms is `/fgp`.

The installed addon folders go under `_classic_beta_/Interface/AddOns`. SavedVariables under `WTF` are untouched. Individual addon source ZIPs bundle ForeverCommsVoice alongside the selected addon and install both when their individual `.cmd` launcher is run.

## Changes since the first shared-engine beta

- New fantasy-themed project/icon assets for **ForeverCommsVoice** and **ForeverGroupComms**, including WoW `IconTexture` paths.
- Functional **offline source packaging** via `package.cmd` / `package.ps1` (Windows) or `python tools/package.py` (cross-platform), plus an actual root suite GitHub Actions workflow.
- Individual installers explicitly install **ForeverCommsVoice first**; a broken Voice installer dependency on a nonexistent `Bindings.xml` has been removed.
- Current version strings, packaging instructions and bundled source version metadata updated.
- Expressive accent strength once again turns a built-in message's final `.` into `!` (and doubles a final `!`). Custom templates and substitutions are left alone.
- GuildComms' Settings > Restore Defaults resets **only GuildComms preferences**. Shared voice preferences used by GroupComms are not silently overwritten.
- Backup locations moved outside the AddOns folder; installer stages and validates all required runtime files before changes, and attempts rollback on failure.

## Building a release

Read [PACKAGING.md](PACKAGING.md). Local packaging **does not** require GitHub Actions. The root workflow is for a suite stored as one GitHub repository; nested addon workflows are for separate repositories.

These changes were tested with offline simulations, but an in-game Windows install and addon-loading check are still needed.
