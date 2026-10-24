# ForeverGroupComms — module reference

**Version 0.3.4-beta.** The party, dungeon and raid layer. Requires
[ForeverCommsVoice](ForeverCommsVoice-Modules), which ships with every download.

> **Quiet by default.** Greetings, welcomes and level congratulations are staged for a
> click, not posted automatically. The automatic settings exist, but they are off until you
> turn them on.

Files load in this order:

| File | Responsible for |
| --- | --- |
| `Core.lua` | Settings, the channel choice, sending, staging, ready checks and target marks |
| `Roster.lua` | Watching the group for joins and level-ups; roles; ready-check tally |
| `Quests.lua` | The quest-comparison protocol and quest sharing |
| `UI.lua` | The group panel and the quest comparison window |
| `Options.lua` | The Settings panel |
| `TitanMenu.lua` | The Titan Panel right-click menu |
| `Broker.lua` | The Titan Panel / LibDataBroker indicator |
| `Bindings.xml` | Three optional keybindings |

---

## Core.lua

Everything that controls **whether and when** a message reaches group chat.

### Where messages go

The destination is resolved for you, in this order: **instance chat**, then **raid**, then
**party**. There is no setting for it and no fallback to guild or any public channel. If
you are not in a group, nothing sends.

### The guards on every message

Every post, including one you approved with a click, requires all of:

1. The addon is enabled, you are in a group, and the client can send chat.
2. A resolved destination channel.
3. **At least two seconds since the last post.** There is no unthrottled path. If you are
   too quick you are told to wait, and the message stays queued so you can click again.
4. **You are excluded** before any welcome or congratulation.
5. **It is not a duplicate.** New-group greetings and member welcomes are suppressed for 30
   seconds, level congratulations for 3 minutes, private notifications for 90 seconds.

### Staging

With **Automatically greet** and **Automatically congratulate** off — the defaults — a
greeting, welcome or congratulation is written, shown to you, and held in the
[shared review queue](ForeverCommsVoice-Modules#queuelua) until you tick it.

**The text is captured at the moment it is staged.** What you read is what is sent; the
wording is never re-rolled between reviewing and sending. Each suggestion is also stamped
with the group it was written for, and a suggestion whose group has since changed is refused
and removed rather than posted to the wrong party. Staging notifies you; it does not force a
window open.

### Coordination calls

Twelve quick actions, each sent only when you click or type the command: check roles, ready
check, pull, mana break, regroup, wait for healer, focus skull, CC moon, interrupts, quest
reminder, mark skull, mark moon.

### Ready checks and target marks

Both are real game actions, not chat messages, and both require:

- **Leader**, or **raid assistant** in a raid. You are told plainly if you lack the rank.
- **Out of combat.**
- The relevant API actually being present in this client build. If it is missing you get a
  message, not an error.

Marking also requires a selected **hostile** target.

### Private notifications

Role alerts, the quest-sharing reminder and the ready-check tally print to your own chat
frame and go into a private list (20 entries by default). None of them is posted to group
chat.

Also here: `/fgp` and `/forevergroup` and their subcommands, and the single event
dispatcher that registers all ten events and ignores them until initialisation has
finished. Like Guild Comms, this addon refuses to load without ForeverCommsVoice rather
than running half-configured.

---

## Roster.lua

Watches the group and decides what to suggest.

| Message | Fires when |
| --- | --- |
| Greeting | you join a group that you were not in before |
| Welcome | someone new appears in a group you are already in |
| Level congratulations | a member who was already present gains a level |

Level congratulations additionally require the member's character to be the **same character
across both scans** and real levels on both sides, so a swap in the roster cannot be
misread as someone levelling.

**The first scan after login is silent**, as is the one after a world change. Every other
scan can speak, and that is deliberate — it has to be able to justify sending.

**Any change to who is in the group** bumps the group's identity stamp, clears staged
suggestions, drops this addon's entries from the shared review queue, and discards quest
data from the previous group. Clicks are preserved only while the exact roster is stable.

### Roles

Roles are read as **assigned** — whatever the group has actually set. An unrecognised value
is treated as unassigned. The addon never infers a spec and never changes anyone's role.

The private role double-check reports unassigned roles, and in a party, a tank or healer
count that is not exactly one. In a raid it reports only unassigned roles. The summary names
each member and their role; for a large raid it switches to counts so it stays readable.

### The ready-check tally

Private, and never announced to chat. When a ready check finishes you get a count of ready,
not ready, and **unconfirmed**.

**Unconfirmed is not a refusal.** A member who produced no confirmation event is reported as
unconfirmed, and the message says so, because absence of a response is not evidence that
someone declined.

---

## Quests.lua

The quest comparison. This is the only place in the bundle that accepts data from another
player, and it is deliberately narrow.

### What is exchanged

- **Outbound: active quest IDs only.** No quest titles, no objective progress, no completion
  history is ever volunteered.
- **A completion reply answers only the quest IDs the asking player already told you about.**
  Nothing else in your history is disclosed.
- Both directions require **quest sync enabled** and an actual group.

### What you see — `/fgp quests`

**Your quests** view, one row per quest in your log:

| Status | Meaning |
| --- | --- |
| **Missing** | the other player's active quests do not include it **and** their completion reply says they have not finished it |
| **Already has** | it is in their current active quest log |
| **Completed** | they report having finished it |
| **Unknown** | no current data — they are not running this addon, are still syncing, or have quest sync off |

Each row also shows whether the game considers the quest shareable. **Share** asks WoW's own
quest-push function, which shares with the **group**, not a chosen individual, and the game
validates eligibility — a shareable quest can still be declined for some players.

**Switch view** shows quests other members have that you do not, with **Ask**, which posts a
polite request naming the quest. It does not accept anything and nothing is accepted on your
behalf. Quests you have already turned in are left out.

### The rules that keep it honest

- **An unchanged quest log is never resent.** The game fires a quest-log update on every kill
  count, so the addon compares a signature of your quest IDs and skips a rebroadcast within
  four minutes. `/fgp sync` forces one.
- **Packets are paced** at roughly one per 1.15 seconds, capped at 60 queued and 12 chunks.
  An oversized quest log is reported to you rather than silently truncated.
- **Everything inbound is validated** before any of it is stored: the sender must be in your
  current group and not you, the channel must be a group or whisper channel, the header and
  protocol version must match, every number must be a whole number in range, and the quest
  ID list must parse as digits.
- **Stale replies are dropped.** A completion reply is accepted only if it answers the quest
  list you most recently sent, and an older advertisement from a peer is ignored. This is
  what stops an out-of-date reply from producing a false "this player is missing the quest".
- **Nothing from the wire is acted on.** It is never executed, never used as a pattern or a
  format string, and never triggers an action. Quest **titles** in the window come from your
  own client's quest lookups and player **names** from your own group scan — never from the
  data another player sent.
- Peer data expires after five minutes, which is when a row falls back to **Unknown**.

Turning quest sync off stops both sending and receiving.

---

## UI.lua

Two windows, both movable.

### Group panel — `/fgp`

- A header with the member count and which channel messages will use.
- **Twelve quick actions**, in two columns: Check roles, Ready check, Pull when ready, Mana
  break, Regroup, Wait for healer, Focus skull, CC moon, Interrupts, Quest reminder, Mark
  skull target, Mark moon target. Each sends or acts on click.
- The current role summary, with anything worth double-checking called out.
- A count of group messages waiting, and **Review message queue** to open the shared list.
- **Compare quests**, **Settings**, **Recheck roles**.

Outside a group the panel says so, and the quick actions report that you need a group rather
than doing anything.

### Quest comparison — `/fgp quests`

Nine rows per page with paging, a per-row status line, a **Share** (or **Ask**) button, a
**Switch view** toggle, and **Refresh / sync** to request fresh data. The header explains
what Missing and Unknown mean, because the difference matters.

---

## Options.lua

**Settings → AddOns → Forever Group Comms**. Eight toggles:

| Setting | Default | Notes |
| --- | --- | --- |
| Enable Forever Group Comms | on | off stops messages and private notifications |
| Automatically greet new groups and members | **off** | off means each greeting is staged for a click |
| Automatically congratulate level-ups | **off** | off means each congratulation is staged for a click |
| Use ForeverCommsVoice for group messages | on | off restores the original English wording |
| Rotate built-in messages | on | avoids the same wording twice in a row |
| Private role double-check alerts | on | never changes anyone's role |
| Private quest-sharing reminder | on | a private nudge on roster changes, not a group message |
| Share active quest IDs with other Group Comms users | on | both players need it on for full detection |

Plus **Configure shared language and accent**, which opens the Forever Comms Voice panel.

The panel re-reads your saved settings every time it is opened, so a change made from the
Titan menu or a slash command is displayed correctly.

**Restore Defaults** restores this addon's own settings and **leaves the shared language and
accent alone** — those belong to Forever Comms Voice and are shared with Guild Comms, so
resetting them here would quietly change how both addons speak. Change them with `/fcv`.

---

## TitanMenu.lua

**Right-click Group Comms on the Titan bar** for a nested menu:

- **Enable addon**
- **Group status** — a live snapshot: member count, channel, role counts, whether ready
  checks and marking are available to you, pending review count, quest-sync state, plus
  Review roles / Compare quests / Open Review Panel
- **Greetings & congratulations** — the two automatic toggles, wording variation, shared
  voice, and send-now actions for the greeting and the quest reminder
- **Dungeon coordination** — all nine chat calls
- **Target marking** — skull and moon, disabled unless you have the rank
- **Quest sharing & checks** — quest sync, private reminders, private role alerts, compare,
  refresh, send reminder
- **Quick actions** — review panel, group panel, review roles, compare quests
- **Open Review Panel**, **Open group panel**, **Settings…**, **Voice & queue settings…**

Actions that need a group or leader rank are shown disabled when they do not apply. If the
client does not provide Blizzard's nested-menu API, right-click opens Settings instead.

---

## Broker.lua

The optional Titan Panel / LibDataBroker indicator. Absent a data broker it does nothing and
the rest of the addon is unaffected.

**Text:** group size and the number of messages waiting for review, or just `Group Comms`
when you are solo.

| Click | Action |
| --- | --- |
| Left | the group panel |
| Shift + left | the quest comparison window |
| Right | the nested menu |

The tooltip shows group size, role counts, quest-sync state and the pending review count.

---

## Bindings.xml

Three optional keybindings under **Options → Key Bindings → AddOns → Forever Group Comms**.
Nothing is bound by default.

| Binding | Action |
| --- | --- |
| Open Group Comms | toggles the group panel |
| Review group roles | **sends** the role-check message to your group |
| Review group quests | opens the quest comparison window |

Note that **Review group roles sends a message** — it is the same action as the Check roles
button. The other two only open windows.

This file is loaded automatically from the addon folder and is deliberately **not** listed
in the `.toc`. Reload or restart after installing for the commands to register.
