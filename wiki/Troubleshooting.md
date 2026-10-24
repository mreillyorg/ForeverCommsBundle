# Troubleshooting

Most reports turn out to be one of the deliberate safeguards doing its job. Check here
before assuming something is broken.

## Nothing loads

**"ForeverGuildComms requires ForeverCommsVoice"** or the same for Group Comms, and that
addon does nothing at all.

Forever Comms Voice is missing, disabled in the AddOns list, or failed to load. Both
applications refuse to run without it rather than half-working, because their entire
message layer lives in the library. Install the bundle, or enable
`ForeverCommsVoice` in the character-select AddOns list, then restart.

## Forever Comms Voice is not in Settings → AddOns

Fixed in 0.2.2-beta; the panel now registers as soon as the addon loads. On an older
version, `/fcv` registers and opens it.

## No greeting when a guildmate logs in

Work through these in order:

1. **Was this the first roster read?** After login, a `/reload`, or a guild change, the first
   read is a baseline that sends nothing. This is intentional — missing an early transition
   is better than greeting everyone at once.
2. **Is the login cooldown still running?** Default 300 seconds per guildmate. `/fgc status`
   shows your current mode; the cooldown is in Settings.
3. **Are you in Verify mode?** Then it is waiting for a click. `/fgc verify`.
4. **Is the message still in the spacing queue?** Automatic sends are spaced by at least
   `max(3, your spacing setting)` seconds.
5. **Was the roster read discarded?** A read of zero members, or one that collapses to under
   70% of the known count in a guild of more than ten, is thrown away rather than acted on.

The guild roster is not a live feed. Someone who levels or logs in while their roster entry
is not observed as online may simply not be seen, and the addon polls at most once a minute
on purpose.

## No level congratulations for a guildmate

Congratulations require the member to have been **already online** on both reads, with a
real previous level recorded, and a strictly higher new level. A guildmate you are seeing
for the first time never produces one — there is nothing to compare against.

Your own level-up never produces a message. That is a product decision, not a bug.

## I levelled and nothing was sent

Correct. Neither addon congratulates you on your own level-up.

## Approved messages are going out slowly

By design. Clicking through a backlog used to post several lines to guild chat in the same
instant, so approvals are spaced at least two seconds apart. A click that arrives too soon
prints a wait notice and **leaves the message queued** — click again.

## A message disappeared from the review list without being sent

One of three things:

- **Auto-skip expired.** The countdown starts when the message is staged and runs while the
  window is hidden. A timeout never sends; it discards. Raise or disable the timeout under
  `/fcv` (0 = never).
- **It went stale.** You changed guild, or the group roster changed. A message written for
  one audience is dropped rather than retargeted.
- **You logged out or reloaded.** The queue is never saved. This is what guarantees that
  nothing from a previous session can post into a new one.

## The review list keeps popping up

Turn off **Open queue when a message is added** under `/fcv`. Guild Comms has its own
equivalent toggle for the fallback window, but when the shared queue is installed the `/fcv`
setting is the one that applies. You can always reach the list with `/fcv queue`,
`/fgc verify` or `/fgp queue`.

## Craft alerts never fire

Both conditions must hold: the message needs an explicit request phrase **and** an exact
match on a recipe or output item name you have cached.

- Open each crafting profession once to populate the cache, then check `/fgc recipes`.
- **Known limitation:** the cache is keyed by profession name read through the client's
  profession API. If this beta client does not expose it, every scan falls back to a single
  bucket, so opening a second profession **overwrites** the first. The symptom is a
  `/fgc recipes` count that *drops* after opening another profession. Workaround: reopen the
  profession you most want matched, or `/fgc clearrecipes` and rescan.
- After unlearning a profession, `/fgc clearrecipes` and rescan to drop stale names.

An alert means you know the recipe — not that you have the materials, tools or bag space.

## Group quick actions do nothing

They need an actual party or raid. Outside a group the panel says so and the actions report
that rather than acting.

Ready checks and target marks additionally need **leader**, or **raid assistant** in a raid,
and you must be out of combat. Marking needs a selected hostile target. If the client does
not expose the relevant API you get a message rather than an error.

## Quest comparison shows Unknown for everyone

**Unknown means no current data**, not "they are missing it". Causes, in rough order of
likelihood:

- the other player is not running Forever Group Comms;
- they have quest sync off, or you do;
- the exchange is still in progress — packets are paced at about one per 1.15 seconds;
- their data has expired. Peer data is good for five minutes.

`/fgp sync` or **Refresh / sync** forces a rebroadcast. Note that an **unchanged** quest log
is not resent within four minutes — the game fires a quest-log update on every kill count,
and resending on each one would flood the channel.

Someone running a different quest addon is not synced with this one. There is no shared
protocol.

## "Quest log too large for group sync"

Your active quest list does not fit in the packet budget (12 chunks). The addon refuses and
tells you rather than silently sending a truncated list that would read as missing quests.

## Sharing a quest did nothing

**Share** asks WoW's own quest-push function, which shares with the **whole group**, not a
chosen player, and the game decides eligibility. A quest marked shareable can still be
declined for individual players. The addon never accepts, abandons or turns in anything.

## The ready check says people are "unconfirmed"

Deliberate wording. A member who produced no confirmation event is reported as unconfirmed,
because an absent response is not proof that someone clicked "Not ready". The tally is
private and is never announced to chat.

## The Titan indicator is missing

It needs LibDataBroker, which Titan Panel embeds. Nothing is bundled and nothing is
required: with no data broker present the indicator simply does not appear and every other
feature works. Enable the **Guild Comms** / **Group Comms** plugin in Titan's configuration.

## Right-clicking the Titan button opens Settings instead of a menu

The nested menu needs Blizzard's context-menu API. When it is unavailable, both addons fall
back to opening the Settings page and tell you why.

## Keybindings are not in the Key Bindings panel

The bindings file is loaded automatically from the addon folder and is deliberately not in
the `.toc`. Restart the client — a `/reload` is not always enough for the Key Bindings panel
to pick up new commands.

## My custom message is not being translated

That is the rule: editing a template opts it out of translation, accents and wording
variation, so your exact text — including item links and `{variables}` — is used. Press
**Use default** on that field to restore the built-in wording and re-enable all three.

## Expressive changed the punctuation of my group greetings

Intended. Accent strength reaches group greetings, welcomes and level congratulations as
well as guild messages. It never touches a coordination or combat call: `Focus skull first,
please.` keeps its full stop at every strength, because an instruction has to stay plain to
be followed under pressure. The full table is in
[the accent strength section](ForeverCommsVoice-Modules#accent-strength).

## Restore Defaults did not reset my language

Correct. The language and accent belong to Forever Comms Voice and are shared by both
applications, so neither addon's Restore Defaults touches them. Change them with `/fcv`.

Guild Comms also keeps your outgoing mode through Restore Defaults, so restoring defaults
cannot silently return you to posting to guild chat without confirmation.

## Reporting a problem

Enable Lua errors, reproduce the problem, then collect:

```text
/console scriptErrors 1
/reload
/dump select(4, GetBuildInfo())
```

Include the **exact** Lua error text, what you were doing or what event occurred, the client
build from the `/dump` above, the three addon versions, and whether Titan Panel is
installed.

Useful state commands: `/fgc status` for guild counts, review count and outgoing mode;
`/fgc recipes` for the cached recipe count; the Group Comms Titan status submenu for roster,
roles, channel, quest-sync state and pending reviews.

**Nothing in this bundle has been run against a live Forever server.** Behaviour reports
from a real client are genuinely useful.
