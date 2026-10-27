# Forever Comms

All three addons — ForeverCommsVoice, ForeverGuildComms and ForeverGroupComms — share one
version number and are released together. Each addon's own README carries its full
history, including the per-addon numbering used before 0.7.0-beta.

This file is the release notes the packager publishes. It is deliberately not shipped
inside the addon archive.

## 0.7.2-beta

**Fixes the release archive.** The 0.7.1-beta download contained a spurious fourth
top-level folder, `ForeverCommsBundle/`, holding nothing but a generated `CHANGELOG.md`.
Extracting it into `Interface\AddOns` left a stray folder that is not an addon.

The cause: the packager generates its changelog inside the package directory, then removes
that directory after lifting the three addon folders to the top level — but only if it is
empty. The generated file kept it alive. The project now supplies this changelog instead
of having one generated, and excludes it from the copied files, so the package directory
really is empty and is removed as intended.

**No addon changed.** Every file the game loads is identical to 0.7.1-beta. No setting,
message, window, command or keybinding differs, and no saved settings are renamed or
removed. If you already extracted 0.7.1-beta you can simply delete the stray
`ForeverCommsBundle` folder; nothing depended on it.

The local build now refuses to run if the changelog configuration is broken — no manual
changelog declared, the named file missing, or the file not excluded from the copy — so
this class of fault no longer waits for CI to catch it.

## 0.7.1-beta

Restricted the release archive to the three addon folders, so project files — development
documentation, lint and git configuration, `LICENSE`, `run-tests.cmd` — can no longer be
swept into a download. No addon changed.

This release is superseded by 0.7.2-beta, which fixes the stray folder described above.

## 0.7.0-beta

**The three addons were given one shared version number.** They had been versioned
separately, reaching ForeverCommsVoice 0.2.3-beta, ForeverGuildComms 0.6.4-beta and
ForeverGroupComms 0.3.5-beta. Since they are built, tested, bundled and installed
together, three numbers only ever answered "which version do I have?" with a question.

ForeverCommsVoice jumping from 0.2.3-beta to 0.7.0-beta was therefore a renumbering, not a
rewrite. The same applies to ForeverGroupComms. No addon behaviour changed.

Also fixed the automated build, which installed the Lua linter under the wrong package
name, so the checks meant to gate a release could not run for 0.6.4-beta.

## 0.6.4-beta

The last release under per-package numbering: ForeverCommsVoice 0.2.3-beta,
ForeverGuildComms 0.6.4-beta, ForeverGroupComms 0.3.5-beta. See each addon's README for
what changed in it.
