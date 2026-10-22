# Halo — PRD

Oct 22, 2026 · @Patrick

## TL;DR

**Halo turns the iPad next to your Mac into a calm, always-on companion surface.** One space, six modes: a quiet clock, a trackpad, a live view of your Mac, your AI agents, your launchers and your controls. Inspired by Orbit, but with one big difference: Halo knows what you're doing and brings forward the right mode on its own, instead of making you tab between them.

_"Halo" is a working name._

## Problem

**People who work all day on a Mac lose focus every time they leave their work window to check on something else.** Is the agent done? Why is the fan spinning? Where's that tab I always open? Each check is a Cmd-Tab, a menu bar squint or a hunt through windows, and each one breaks flow.

Meanwhile, many of these same people have an iPad sitting idle on the desk. It's a large, bright, multitouch screen doing nothing.

The cost is highest for people running AI coding agents. Agents now work for minutes at a time, then stop and wait for approval. If you don't notice, the agent sits idle; if you keep checking, you never focus. Neither outcome is acceptable.

## Where we beat Orbit

Orbit proves the idea works and nails the mood: warm, quiet, premium. We keep that bar and fix what holds it back.

| Orbit today                                    | Halo                                                                                                                      |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| You switch modes by hand                       | Modes come forward on their own (agent needs you → Agents; you pick up a trackpad gesture → Trackpad), always overridable |
| Agents list is read-only; tap jumps to the Mac | Approve, deny or quick-reply to an agent right from the iPad                                                              |
| One agent tool (Codex)                         | Claude Code, Codex and Cursor from day one                                                                                |
| Metrics are numbers at a glance                | Metrics with a 10-minute trend and "what's eating it" (top process)                                                       |
| Favourites + dock only                         | Adds Deck: a grid of one-tap actions (shortcuts, scripts, media, Do Not Disturb)                                          |
| Mixed French and English strings in the UI     | Fully localised, one language at a time                                                                                   |

## Success metrics

The headline metric is **hours connected per active user per day**: if Halo is good, the iPad stays on and paired all day. Every feature request gets checked against these targets (proposed, to confirm after beta).

| Metric                                             | Target at launch            |
| -------------------------------------------------- | --------------------------- |
| Hours connected per active user per day            | 4 h median                  |
| Day-30 retention                                   | 40%                         |
| First pairing completed                            | 95% of installs, under 60 s |
| Trackpad input latency, iPad to Mac                | under 20 ms at p95          |
| Agent actions taken on iPad (approve, deny, reply) | 10 per agent user per week  |
| Crash-free sessions                                | 99.8%                       |

## Principles

- **Quiet by default.** Halo is furniture, not a notification centre. Motion is slow, colour is warm, nothing blinks unless you need to act.
- **Readable from arm's length.** Every mode has one hero number or action you can read without leaning in.
- **Instant or it doesn't ship.** A touch that lands late feels broken. Latency is a feature with its own budget.
- **It comes to you.** Halo surfaces the right mode when context changes, and gets out of the way when it doesn't.
- **No settings maze.** Sensible defaults; customisation lives in long-press, not in a preferences tree.

Design works from functional prototypes on a real iPad, not static mocks. Engineering and design shape each mode together before it's built.

## Scope: six modes for v1

Each mode solves one job. The goal is described here; the exact UI is for design and engineering to shape together.

| Mode         | The job                               | Must have                                                      | Beyond Orbit                                                                   |
| ------------ | ------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Zen**      | Keep a calm presence on the desk      | Large clock, date, next calendar event                         | Dims with the room; slides into night mode on a schedule                       |
| **Trackpad** | Control the Mac from a bigger surface | Move, click, scroll, standard macOS multi-finger gestures      | Custom gestures mapped to shortcuts; Apple Pencil for precise pointing         |
| **Pulse**    | Know your Mac is healthy at a glance  | CPU, memory, free storage, network                             | 10-minute sparkline per metric; top process when something spikes              |
| **Agents**   | Keep agents moving without switching  | Running and waiting conversations, tap to bring forward on Mac | Approve or deny tool requests, quick replies, gentle chime when an agent waits |
| **Launch**   | Open what you use most                | Dock of Mac apps, web favourites, brightness and volume        | Favourites sync from the Mac's browser bookmarks folder                        |
| **Deck**     | Run your everyday actions in one tap  | Grid of buttons for Shortcuts, scripts, media, Do Not Disturb  | New in Halo; Orbit has no equivalent                                           |

A persistent status strip (connected Mac, CPU, RAM, disk, network) sits at the top of every mode, as in Orbit.

## Non-goals

- **Not a second display.** No screen mirroring or window extension; Sidecar already does that.
- **No Windows, Android or iPhone** in v1. Mac + iPad only.
- **No remote use over the internet.** Same network or USB-C cable only.
- **Not a full agent client.** No writing long prompts or reviewing diffs on the iPad; that work stays on the Mac.
- **No widget marketplace or third-party plugins** in v1.

## Technical shape and risks

**Two apps: a native iPad app that draws and senses touch, and a small Mac helper that does everything else.** Keeping logic on the Mac keeps the iPad thin and makes every mode work the same way.

&#91;embedded content: Halo architecture · iPad app, local link, Mac helper\]

The agent adapters are the least certain part, so they get the first spike.

| Risk                                                           | Why it matters                      | Mitigation                                                         |
| -------------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------ |
| Agent tools lack a stable way to read state or approve actions | Agents is our main edge over Orbit  | Week-1 spike; ship read-only for any tool we can't approve safely  |
| Input control isn't allowed in the Mac App Store               | Trackpad needs Accessibility access | Ship the helper as a notarised direct download                     |
| Latency on busy Wi-Fi                                          | Trackpad feels broken above \~20 ms | Peer-to-peer link, USB-C fallback, latency readout in debug builds |
| Always-on screen burn-in and battery                           | Users unplug and churn              | Pixel shift in Zen, auto-dim, designed for use while charging      |
| A nearby device controlling a Mac                              | Trust is everything here            | One-time pairing code, end-to-end encryption, paired iPads only    |

## Milestones and appetite

**We work in fixed six-week cycles and cut scope, not time.** Each cycle starts with a shaping session where design and engineering agree on boundaries before anyone builds.

&#91;embedded content: Milestones · three cycles, one gate, launch\]

If the latency gate fails in December, cycle 2 becomes a transport rewrite: a slow trackpad sinks the whole product. The beta needs 200 testers and 50% day-14 retention before launch.

## Open questions

- [ ] Pricing: one-time purchase, subscription, or free with a paid Agents and Deck tier?
- [ ] Which agent tools expose a reliable way to read state and approve actions? Engineering to spike Claude Code, Codex and Cursor in week 1.
- [ ] How aggressive should auto-switching be? Needs testing with 10+ daily users before we pick defaults.
- [ ] Does the Mac helper ship outside the Mac App Store (input control likely requires it)?
- [ ] Do we support older iPads, or iPadOS 18+ and Apple Pencil 2 or later only?
