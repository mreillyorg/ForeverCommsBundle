# Forever Group Comms 0.7.0-beta

A companion to **ForeverGuildComms** using the shared **ForeverCommsVoice** addon, written for **WoW Forever 1.60.1 (Interface 16001)**.
Author: Michael Reilly.

## Features

- Quiet by default: party/group greetings and level congratulations are **review-to-send** unless you turn on the optional automatic settings.
- Rotating quick messages for role verification, pulling, mana breaks, regrouping, healer checks, skull focus, moon crowd control, interrupts and quest reminders.
- Real ready checks (leader or raid assistant) using the game's `C_PartyInfo.DoReadyCheck` when available.
- Manual skull or moon markers on your selected hostile unit (leader/raid assistant).
- Reads **assigned** party/raid roles, warns privately when party roles are unassigned or when tank/healer counts need checking. Does not infer someone's preferred spec or change their role.
- On group changes, privately prompts you to check quest sharing.
- Optional addon-to-addon quest log comparison: active quest IDs only, plus completion checks against your *own* log for quests another player has revealed. No automatic quest sharing, quest acceptance, abandoning, or turn-ins.
- Quest comparison distinguishes: **missing**, **already has**, **completed**, and **unknown**. Switch view to see quests others have that you lack, and click **Ask** to request a share.
- Sharing a selected quest is a **manual** button and asks WoW to share with the group; the game validates eligibility. It does not silently send every quest.
- Keybindings, Settings > AddOns options, optional Titan Panel / LibDataBroker data source, and `/fgp` slash commands.
- Independent group behaviour settings: `ForeverGroupCommsDB`. Shared language settings live in ForeverCommsVoice, without changing existing guild custom templates.

## Installation

Extract the ZIP to your WoW Forever `_classic_beta_\\Interface\\AddOns` folder, leaving:

`Interface\\AddOns\\ForeverGroupComms\\ForeverGroupComms.toc`

Or run `ForeverGroupComms\\install\\Install-ForeverGroupComms.cmd` after extracting the ZIP. In-game: `/reload`, then `/fgp`. To compare quests: `/fgp quests`. To configure: Settings > AddOns > Forever Group Comms.

## Commands

`/fgp` opens quick actions. Additional commands:

- `/fgp quests`: quest comparison
- `/fgp roles`: **send** role check to group
- `/fgp ready`: initiate a native ready check (leader/assistant)
- `/fgp skull`, `/fgp moon`: mark selected hostile target
- `/fgp pull`, `/fgp mana`, `/fgp regroup`, `/fgp heal`, `/fgp cc`, `/fgp interrupt`: **send** coordination messages
- `/fgp sync`: rebroadcast your active quest list to other users of this addon
- `/fgp settings`: Settings page

## Quest status and limitations

With compatible peers running ForeverGroupComms and quest sync enabled:

* **Missing:** peer's recently reported active quests exclude the quest AND a direct peer completion response says it hasn't already been finished.
* **Already has:** peer includes it in the current active quest log.
* **Completed:** peer reports having completed it, using `C_QuestLog.IsQuestFlaggedCompleted` for only quest IDs you are comparing.
* **Unknown:** no complete recent peer data, for example the other player isn't running ForeverGroupComms, is still syncing, or has disabled quest sync.

The quest-sharing button uses WoW's own push API, which shares with the **group**, not an individually selected player. Shareability and eligibility are separate: even a shareable quest may be declined by the game for some players.

Forever Quest Share is a separate project with a richer quest UI and additional Questie interoperability. This first version does **not** use that addon's private protocol and does not claim that a party member running Questie alone is synced.

## Development

This is a separately maintained companion addon updated for ForeverCommsVoice. It reuses the overall UI/quick-action conventions, not the guild chat transport or persistence. The WoW APIs need a live in-game smoke test; the archive is a beta and has not been tested against the live server.

`BigWigsMods/packager` workflow is included for tag-driven GitHub releases; set `CF_API_KEY` only when you create a CurseForge project.

## Shared language/voice engine (0.2.0-beta)

**Requires ForeverCommsVoice 0.7.0-beta.** The addon now calls the shared engine for group/dungeon messages; accents and language are configured per character with `/fcv` or Settings > AddOns > Forever Comms Voice. Eight languages receive curated group/dungeon messages and RP accents flavour casual messages. Combat directives keep a clear meaning.

The shared **Strength** setting reaches group messages, so it is worth knowing where: the catchphrase prefix and the Expressive punctuation change (final `.` becomes `!`, final `!` becomes `!!`) apply to **group greetings, welcomes and level congratulations only**. Every coordination and combat directive — pull, mana break, regroup, wait-for-healer, crowd control, skull focus, interrupts, plus the role check, quest check and quest request — is rendered exactly as written at every strength, full stops intact. See the accent strength section of the [ForeverCommsVoice README](../ForeverCommsVoice/README.md) for the complete table. Disable `Use ForeverCommsVoice for group messages` in GroupComms Settings to restore the original English message rotation. Ready checks, target markers, group roles and quest-sync protocol remain independent of the voice library and are unchanged. Install the three-addon bundle for an easy upgrade; offline tests pass but live-game verification is still needed.

## Shared review queue (v0.3.1-beta)

GroupComms stages **manual-approval greetings and level congratulations** in the common ForeverCommsVoice queue. The Group panel now has one “Review message queue” button instead of its embedded three-row suggestion window. Use `/fgp queue` or `/fcv queue`. Sending still checks the original party/raid identity and retains the two-second group chat spacing guard. Group changes purge outstanding Group-only suggestions without disturbing guild requests. Ready checks, target marking and explicitly clicked quick actions continue to act immediately.

## What changed in 0.7.0-beta

**Requires ForeverCommsVoice 0.7.0-beta**, which is now the same number as this addon --
see below.

**Nothing in the addon changed.** Every file the game loads is identical to 0.3.5-beta
apart from the version number, so if you already run the previous release, updating gains
you nothing but matching numbers. No setting, message, window or command differs, and no
saved settings are renamed or removed.

**The three addons now share one version number.** They were versioned separately --
ForeverCommsVoice at 0.2.3-beta, ForeverGuildComms at 0.6.4-beta and this addon at
0.3.5-beta -- despite being built, tested and installed together. All three now share a
single number, and the minor bump to 0.7.0 marks that change rather than any new feature.

**One real fix, invisible from inside the game.** The automated build installed the Lua
linter under the wrong package name, so the checks meant to gate a release could not run
for the previous one. Corrected; this is the first release built with them passing.

## What changed in 0.3.5-beta

**Requires ForeverCommsVoice 0.7.0-beta.**

**No functional changes to this addon.** The only edits are the version number itself and
this note — no behaviour, setting, message or command is different from 0.3.4-beta. The version moved to keep the bundle aligned and to record
the library requirement above, since ForeverCommsVoice 0.2.3-beta clears its
message-variety shuffle bags when you change a voice setting — which affects group wording
variety the same way it affects guild wording. See the
[ForeverCommsVoice README](../ForeverCommsVoice/README.md).

## What changed in 0.3.4-beta

**Requires ForeverCommsVoice 0.7.0-beta.**

**Fixed: the Settings panel no longer shows stale values.** Its checkboxes kept whatever
they displayed when the panel was first built, so a setting changed from the Titan
right-click menu or a slash command still looked unchanged in Settings. The panel now
re-reads your saved settings every time it is opened.

**Fixed: Restore Defaults is scoped to Group Comms.** It restores this addon's own
settings and leaves the shared language and accent alone — those belong to
ForeverCommsVoice and are shared with Guild Comms, so resetting them here would have
quietly changed how both addons speak. Change them with `/fcv`.

No change to group messages, quest syncing, ready checks or target marking.
