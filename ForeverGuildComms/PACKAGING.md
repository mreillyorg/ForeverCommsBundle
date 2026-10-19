# Packaging ForeverGuildComms 0.5.1-beta

See the suite's root `PACKAGING.md` for current instructions.

**Offline Windows:** extract the full suite and run `package.cmd` or `package.ps1`.
**Offline Python:** `python tools/package.py --output dist`.
**Suite GitHub repository:** workflow MUST be at `<repo>/.github/workflows/package.yml`, not in this addon subfolder. The suite root workflow packages all three addons.
**Separate GuildComms repository:** the `.github/workflows/package.yml` inside this directory is usable when this directory's **contents** are the repository root, and runs BigWigsMods/packager on pushed tags. `VoiceBridge.lua` requires the separately installed ForeverCommsVoice 0.1.1-beta.

The manual `ForeverGuildComms-0.5.1-beta.zip` produced by the suite builder includes `ForeverCommsVoice/` and the common Windows installer. The packager's standalone runtime ZIP relies on users installing the Voice dependency separately.

`Media/Icon.tga` is shipped for the in-game AddOns icon and `Media/ProjectIcon.png` is provided for external project artwork. Neither installing nor creating archives touches SavedVariables.
