# ForeverGuildComms — module reference

**Version 0.6.3-beta.** The guild social layer. Requires
[ForeverCommsVoice](ForeverCommsVoice-Modules), which ships with every download.

Files load in this order:

| File | Responsible for |
| --- | --- |
| `Core.lua` | Settings, the send queue, duplicate suppression, the event dispatcher |
| `VoiceBridge.lua` | The one connection to the shared wording library |
| `Roster.lua` | Watching the guild roster for logins, joins and level-ups |
| `Alerts.lua` | Reading guild chat for crafting and group requests |
| `Tabard.lua` | Capital-city tabard reminders |
| `UI.lua` | The alerts window and the Ask-for-Help composer |
| `Options.lua` | The Settings panel |
| `TitanMenu.lua` | The Titan Panel right-click menu |
| `Broker.lua` | The Titan Panel / LibDataBroker indicator |
| `Bindings.xml` | Three optional keybindings |

---

## Core.lua

Everything that controls **whether and when** a message reaches guild chat.

### Automatic or Verify

`Guild greetings and congratulations` has two modes:

- **Automatic** (default) — greetings, welcomes and congratulations post on their own,
  spaced apart by the queue.
- **Verify with a click** — each one is staged in the
  [review queue](ForeverCommsVoice-Modules#queuelua) and nothing posts until you tick it.

Switching **Verify → Automatic does not approve anything.** Messages already waiting stay
waiting; you are told they are still there. Switching **Automatic → Verify** while a
message is sitting in the spacing delay captures it into the review list instead of letting
it post.

### Timing

| Setting | Range | Default | What it controls |
| --- | --- | --- | --- |
| Automatic message spacing | 3–120 s | 6 | minimum gap between **automatic** guild messages |
| Login greeting cooldown | 0–3600 s | 300 | wait before greeting the **same** guildmate again; 0 greets on every detected login |

Approved messages are not subject to the automatic spacing — a click is consent. They do
get a two-second floor, so clicking rapidly through a backlog cannot post several lines to
guild chat in the same instant. A click that arrives too soon prints a short wait notice
and **leaves the message queued**, so you simply click again.

### The guards on every automatic message

No automatic message leaves this addon without all of the following:

1. The addon is enabled and you are in a guild.
2. That specific feature is switched on.
3. **You are excluded.** Your own character is matched by GUID first, then by name and by
   realm-qualified name. A character name is never shortened beyond stripping an explicit
   `-Realm` suffix, because two guildmates can share a first name.
4. **It is not a duplicate.** Each message type has its own cooldown: logins use your login
   greeting cooldown, joins 5 minutes, level-ups 30 minutes, private alerts 2 minutes.
5. **It goes through the spacing queue.** Direct sends are reserved for buttons you press
   yourself.
6. **The guild is re-checked at send time.** A message queued for one guild is discarded
   rather than posted if you have since left or changed guild.

The duplicate-suppression history is pruned automatically — kept for the longest supported
cooldown, swept at most once a minute while messages are arriving and every five minutes
during a quiet session — so a long play session does not grow it without limit.

### Also here

- `/fgc` and `/guildcomms` and all their subcommands. See
  [Slash Commands and Keybindings](Slash-Commands-and-Keybindings).
- The single event dispatcher. Fourteen events are registered in one place, and none of
  them is acted on until the addon has finished initialising.
- The one writer for settings, shared by the Settings panel and the Titan menu, so a change
  made in either is immediately reflected in the other and timing values obey the same
  limits whichever one you used.
- Which roles your class can offer in the Ask-for-Help window.
- A refusal to load at all if ForeverCommsVoice is missing. The whole message layer is
  delegated to the library, so failing loudly with one clear message is better than running
  half-configured.

---

## VoiceBridge.lua

The only connection to the shared library. It forwards requests for language, accent and
race data, and turns a request for a guild message into a render call that passes three
things along: your custom template for that message type (if you edited one), whether
wording variation is on, and whether this is a preview rather than a real message.

The preview flag is why the text in Settings and in the Ask-for-Help window is the text
that gets sent — a preview does not consume a wording choice.

You never interact with this file directly. It exists so that the rest of Guild Comms did
not have to be rewritten when the wording moved into a separate addon.

---

## Roster.lua

Watches the guild roster and decides who to greet.

**The first roster read is a baseline.** After login, a `/reload`, or a guild change, the
addon records who is online and **sends nothing**. Missing an early transition is preferred
over greeting everyone at once.

| Message | Fires when |
| --- | --- |
| Login greeting | a member goes **offline → online** after the baseline |
| New member welcome | the game's own localized guild-join message names someone new |
| Level congratulations | a member who was **already online** gains a level, with a real previous level recorded |

A newly seen member never produces a level message — there is no previous level to compare
against. Your own level-up never produces anything.

**Suspicious roster reads are discarded, not acted on.** A read of zero members is ignored,
and so is one that collapses to under 70% of the known member count in a guild of more than
ten. The guild roster cache can be briefly incomplete, and acting on that would mean a
burst of greetings for people who never logged out.

**On a guild change**, anything queued or waiting for review is cleared and the roster
state is reset, so text written for your old guild cannot leak into your new one.

The roster is polled at most once every 30 seconds, plus a one-minute ticker. The addon
does not re-read it on every roster event the game fires.

New-member detection is built from the game's own localized guild-join message, not from a
hardcoded English sentence, so it works on a non-English client.

---

## Alerts.lua

Reads **guild chat only** and raises **private** alerts. Nothing here ever posts to guild
chat or whispers anyone.

### Crafting requests

Open each crafting profession once to cache the recipes you know. After that, a guild-chat
message needs **both** of these to raise an alert:

- an explicit request phrase — `WTB`, `can anyone craft`, `looking for crafter`,
  `who can make`, and similar; and
- an exact match against a recipe name or its output item name in your cache.

Colour codes and hyperlinks are stripped before matching, keeping the visible item name, so
a linked item matches the same way typed text does.

An alert is **not** a promise you can make the thing. It matches what you have learned, not
whether you have the materials, the tools, or the bag space.

### Group requests

Watches for `LFG`, `LFM`, `LF2M`, `looking for group`, `need a tank` and similar. A message
already treated as a crafting request will not also raise a group alert. The matching is
text-based, so an ambiguous `LF` message may occasionally trigger it.

### What an alert does

It prints to your chat frame, optionally plays a sound, and goes into the alerts window
(newest first, up to 30, duplicates suppressed for two minutes). The window has a
**Whisper** button, which **opens your chat box with `/w name` filled in** — it does not
send anything.

### The recipe cache

Stored per character and rebuilt for whichever profession window you have open. Use
`/fgc recipes` for the cached count and `/fgc clearrecipes` after unlearning a profession.

**One known limitation:** the cache is keyed by profession name, read through the client's
profession API. If this beta client does not expose that API, every scan falls back to a
single bucket, so opening a second profession **overwrites** the first instead of adding to
it. The symptom is a count from `/fgc recipes` that drops after you open another
profession. Workaround: reopen whichever profession you most want matched, or clear and
rescan.

---

## Tabard.lua

Reminds you about your guild tabard. **It never equips or unequips anything** — the most it
does is open your character panel for you.

- **Entering a capital city** without the Guild Tabard equipped: asks whether to open your
  character equipment. At most one reminder per uninterrupted city stay.
- **Leaving a city** while wearing it: optionally asks whether to open your equipment to
  take it off. Off by default.

Cities are detected by map ID with a zone-name fallback. The check runs about a second after
a zone change and about three seconds after login, and the login check can still prompt even
if a zone check already ran — an earlier check never masks it.

Currently recognises the original Guild Tabard (item 5976) and the nine capital-city zones.
Other tabard items and localized capital names can be added later.

---

## UI.lua

Two windows, both movable.

### Alerts window — `/fgc` or `/fgc alerts`

Seven alerts per page with Prev / Next paging, showing the time, kind, sender and message.
Per row: **Whisper** (opens your chat box, does not send). Along the bottom: **Clear**,
**Ask for Help**, and **Review (n)** which opens the shared review queue.

### Ask Guild for Help — `/fgc request`

Composes **one** explicit guild message that is sent only when you press **Send to Guild**.

- **Activity** — free text, e.g. a dungeon, raid or quest name.
- **Activity type** — cycles Dungeon / Raid / Quest.
- **My roles** — Tank / Healer / DPS. Roles your class cannot fill are shown disabled.
- **Roles you want to recruit** — none selected means any role.
- **Preview** — exactly what will be sent, in your language and accent.

The draft is locked to what the preview shows, so a redraw or a reopened Settings page
cannot quietly change the wording between reading it and sending it. Changing the activity,
roles or language makes a new draft; reopening the window starts a fresh wording choice.

Sending is limited to one request every 20 seconds, and an empty activity is refused.

### The review queue

Guild Comms no longer has its own approval window. `/fgc verify` opens the
[shared review queue](ForeverCommsVoice-Modules#queuelua) that it shares with Group Comms.

---

## Options.lua

**Settings → AddOns → Forever Guild Comms**, a single scrolling page. Sections, in order:

1. **General** — enable the addon.
2. **Outgoing guild messages** — Automatic / Verify, the three greeting toggles, wording
   variation, and the two timing fields with a **Use default** button each.
3. **Private guild requests** — crafting alerts, group alerts, alert sound, and whether the
   review list opens by itself when a message is staged.
4. **Guild tabard** — the two reminders.
5. **Languages & accents (this character)** — language, race filter, accent, strength, and a
   live preview. These are the shared Forever Comms Voice settings; editing them here is
   the same as editing them under `/fcv`.
6. **Custom messages** — editable templates for the four built-in messages, each with its
   default shown and a **Use default** button.
7. **Quick actions** — Alerts, Ask for help, Rescan profession.

Every control writes through the same settings path the Titan menu uses, so the two can
never disagree.

### Custom templates

| Message | Default | Variables |
| --- | --- | --- |
| Login greeting | `Welcome back, {name}!` | `{name}`, `{level}` |
| New member welcome | `Welcome to the guild, {name}!` | `{name}` |
| Level congratulations | `Congratulations on level {level}, {name}!` | `{name}`, `{level}` |
| Ask for Help | `[LFG] {type}: {activity}. I can fill: {myroles}. Looking for: {needed}. Whisper me!` | `{type}`, `{activity}`, `{myroles}`, `{needed}`, `{name}` |

Editing a field opts that message out of translation, accents and wording variation — your
text is used exactly as written. Press **Use default** to restore the built-in wording and
re-enable all three.

### Restore Defaults

Restores this addon's own settings, with two deliberate exceptions:

- **Your outgoing mode is kept.** Resetting it would silently return you to posting to
  guild chat without confirmation, and restoring defaults is not consent to that.
- **The shared language and accent are left alone**, because they belong to Forever Comms
  Voice and are shared with Group Comms. Change those with `/fcv`.

---

## TitanMenu.lua

**Right-click Guild Comms on the Titan bar** for a nested menu:

- **Enable addon**
- **Outgoing guild messages** — sending mode, the three greeting toggles, wording variation,
  and preset submenus for spacing (3, 6, 10, 15, 30, 60, 120 s) and login cooldown (off, 60,
  300, 600, 900, 1800, 3600 s), each with **Reset to default**
- **Private guild requests** — crafting, group, alert sound
- **Languages & accents (this character)** — language, accent, race filter, strength
- **Guild tabard** — the two reminders
- **Quick actions** — review pending, show alerts, ask for help, rescan profession
- **Open Review Panel**, **Edit custom messages in Settings…**, **Open full Settings…**

Menu and Settings page read and write the same values. A menu change refreshes the Settings
controls immediately; reopening the menu shows anything you changed in Settings. Custom
message text is **never** edited inside the menu — the shortcut opens Settings and scrolls
to the editor. Picking a timing preset changes only that one setting, and an exact custom
value such as 17 seconds set in Settings is not reset by opening the menu.

If the client does not provide Blizzard's nested-menu API, right-click opens the Settings
page instead and tells you why.

---

## Broker.lua

The optional Titan Panel / LibDataBroker indicator. If no data broker is present this does
nothing at all and the rest of the addon is unaffected — nothing is bundled and nothing is
required.

**Text:** online / total guild members, alert count, and a review count when messages are
waiting.

| Click | Action |
| --- | --- |
| Left | review queue if messages are pending, otherwise the alerts window |
| Shift + left | Ask for Help |
| Right | the nested menu |

The tooltip adds your current outgoing mode and a reminder of the click actions.

---

## Bindings.xml

Three optional keybindings under **Options → Key Bindings → AddOns → Forever Guild Comms**.
Nothing is bound by default.

| Binding | Action |
| --- | --- |
| Open guild alerts | shows the private alerts window |
| Ask guild for help | opens the request composer — **never sends**; you still press Send |
| Rescan open profession | refreshes the recipe cache for the profession window you have open, or tells you to open one |

This file is loaded automatically from the addon folder and is deliberately **not** listed
in the `.toc`. You need to reload or restart after installing for the commands to register,
and a full restart may be needed before they appear in the Key Bindings panel.
