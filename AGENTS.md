# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. Read `docs/PRD.md` first — it is the source of truth for *what* we build and *why*.

## What Halo is

Halo turns the iPad next to a Mac into a calm, always-on companion surface. The person arranges **pages of widgets** (clock, now playing, brightness, volume, processor, memory, storage, network, agents, trackpad, deck) beneath a status bar, with the Mac's Dock pinned at the bottom. The backdrop is the Mac's own wallpaper, or the album artwork while music plays, blurred. When an agent starts needing the person, Halo brings forward the first page with the Agents widget.

This deliberately departs from the PRD's fixed six modes: the modes became widgets the person places where they like.

Two apps:

- **HaloPad** (iPadOS) — thin. Draws UI and senses touch. No business logic that the Mac could own.
- **HaloMac** ("Halo Helper", macOS menu bar app) — does everything else: system metrics, agent adapters (Claude Code, Codex, Cursor), input injection, launchers, Deck actions, transport.

They talk over a local peer-to-peer link (Bonjour `_halo._tcp`, USB-C fallback). Never over the internet.

## Repo layout (monorepo)

```
Halo/
├── AGENTS.md              ← you are here
├── project.yml            ← XcodeGen spec (source of truth for the Xcode project)
├── Halo.xcodeproj         ← GENERATED — do not edit by hand, do not commit
├── Apps/
│   ├── HaloPad/           ← iPad app (SwiftUI)
│   │   ├── Sources/
│   │   └── Resources/
│   ├── HaloMac/           ← Mac helper (SwiftUI MenuBarExtra, LSUIElement)
│   │   ├── Sources/
│   │   └── Resources/
│   └── HaloHook/          ← `halo-hook` CLI, embedded in the helper at Contents/MacOS
├── Packages/
│   └── HaloKit/           ← shared Swift package used by the apps
│       ├── Sources/HaloCore/        models (Mode, SystemMetrics, AgentSession, ApprovalRequest), ModeSuggester
│       ├── Sources/HaloProtocol/    iPad ⇄ Mac wire messages (MacMessage, PadMessage)
│       ├── Sources/HaloHookBridge/  halo-hook ⇄ helper Unix socket (client, server, paths)
│       ├── Sources/HaloAgents/      tool adapters, AgentSessionStore, AgentCoordinator, HookInstaller
│       ├── Sources/HaloTransport/   pairing, encrypted channels, Bonjour discovery, Keychain pairings
│       ├── Sources/HaloMetrics/     macOS-only CPU, memory, storage, network and per-app sampling
│       ├── Sources/HaloTrackpad/    pure gesture interpreter: touches in, PointerEvents out
│       ├── Sources/HaloInput/       macOS-only: plays PointerEvents as CGEvents (needs Accessibility)
│       ├── Sources/HaloDashboard/   pure model for pages of widgets on a 12×8 grid, with layout ops
│       ├── Sources/HaloDesktop/     macOS-only: wallpaper, Dock apps, Music/Spotify, volume, brightness, Deck, calendar
│       └── Tests/
└── docs/
    ├── PRD.md
    └── spikes/            ← research write-ups (e.g. agent-adapters.md)
```

Rule of thumb: if both apps need it, it goes in `Packages/HaloKit`. Platform-specific code (AppKit, CGEvent, IOKit, UIKit) stays in the app. New shared areas (e.g. `HaloTransport`, `HaloAgents`) become new targets in `HaloKit`, not new top-level folders.

## Setup & commands

Requirements: Xcode 27+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate                     # (re)create Halo.xcodeproj — run after adding/removing files or editing project.yml
open Halo.xcodeproj

# Shared package tests (fast, no simulator)
swift test --package-path Packages/HaloKit

# Build the apps from the CLI
xcodebuild -project Halo.xcodeproj -scheme HaloPad -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -project Halo.xcodeproj -scheme HaloMac build
```

Always run `xcodegen generate` after adding files — the `.xcodeproj` is not committed and will not pick them up otherwise. Never edit `project.pbxproj` directly; change `project.yml`.

## Agents pipeline

Agent tools call `halo-hook <tool>` from their hook config. It relays stdin over a Unix socket to the helper's `AgentCoordinator`, which goes adapter → `AgentEvent` → `AgentSessionStore`. Permission requests are held open for `AgentCoordinator.defaultApprovalWindow`. See `docs/spikes/agent-adapters.md` for each tool's protocol.

- `halo-hook` stays logic-free and **must fail open**: if anything goes wrong, it prints nothing and exits 0.
- A new tool gets a new `AgentAdapter` plus a `HookConfiguration.for(_:)` case, and tests built from the tool's documented payloads.
- Never gate a tool call Halo can't answer properly. Tools without a "needs approval" hook ship read-only.
- `HookInstaller` edits the user's real config files. Keep edits idempotent and surgical, and never overwrite a file it can't parse.
- When testing locally, the helper repoints `~/Library/Application Support/Halo/bin/halo-hook` at whichever build launched last.

## iPad ⇄ Mac link

- **Pairing** (`PairingSession`) is Bluetooth-style numeric comparison over X25519: the responder commits to its nonce first, both screens show a 6-digit code, and *both* people confirm. The pairing service (`_halo-pair._tcp`) is only advertised while the Mac's pairing window is open.
- **Paired links** (`_halo._tcp`) use TLS 1.2 `ECDHE_PSK_WITH_CHACHA20_POLY1305`, keyed by each pairing's 256-bit secret. Network.framework has no external-PSK TLS 1.3, so don't "upgrade" this without testing. Unpaired devices fail the handshake.
- **Pairings** live in the Keychain (`KeychainPairedDeviceStore`), this device only. Never log or persist secrets anywhere else.
- **Framing:** `NetworkChannel` sends length-prefixed JSON frames. Send through `MessageOutbox` from synchronous code so messages keep their order. Cancelling a reading task closes the channel.
- The Mac sends a `snapshot()` to every new connection so iPads start in sync. The iPad keeps no state the Mac doesn't own.
- `ModeSuggester` is edge-triggered: it reacts when an agent *starts* needing you.

## Design language (iPad)

The look is Apple-native and quiet. Match it in new work:

- **Backdrop:** `Backdrop` blurs the wallpaper or artwork once, off the main actor, at 320 px, then only transforms the result. Never live-blur per frame.
- **Type:** white ink at `ink` / `inkSecondary` / `inkTertiary` (see `Theme.swift`). Hero numbers use `Font.hero` (SF Thin, monospaced digits). Small labels use `eyebrowStyle()`.
- **Glass:** Liquid Glass (`glassEffect`, `.buttonStyle(.glass)`) for anything you touch: sliders, buttons, the trackpad, the Dock. Information sits directly on the backdrop.
- **Colour:** `attention` (amber) means "needs you" and `progress` (green) means "working". Always pair them with an icon or words.
- **Motion:** slow and eased (`Animation.halo`). The Home Screen wiggle in edit mode is the one exception.
- **Adaptive widgets:** every widget reads its own size and adds detail as it grows (a trend, progress, a stacked layout). Check new widgets at their minimum and maximum size.
- iPadOS 26 ignores orientation locks for resizable apps, so pages must work in portrait too.

## Widgets and pages

- **Adding a widget:** add a `WidgetKind` case (title, summary, symbol, size limits) in `HaloDashboard`, then a view in `Apps/HaloPad/Sources/Widgets`, routed in `WidgetView`.
- **Removing a kind is safe:** `DashboardPage` decodes leniently and skips unknown kinds.
- **Layout rules** live in `DashboardPage` (add, move, resize, collisions) and are unit-tested. Views only translate gestures through `GridGeometry`.
- **Touch ownership:** a widget that owns its touches (the trackpad) sets `DashboardStore.isWidgetCapturingTouches`, so the pager stops paging.

## Desktop features (Mac)

`DesktopFeed` polls media and controls once a second, only while an iPad is connected. Wallpaper, Dock, Deck and calendar refresh every 20 s. It sends only meaningful changes, and every new iPad gets a full snapshot.

- **Music and Spotify** use AppleScript (Automation consent per app; `com.apple.security.automation.apple-events`). Scripts check `is running` first, so polling never launches a player.
- **Brightness** uses private DisplayServices via `dlsym`. It only works on built-in and Apple displays; other monitors report "unavailable".
- **Deck:** built-ins, every Shortcut (`shortcuts list` / `run`), and executables in `~/Library/Application Support/Halo/Scripts`. macOS has no API for Do Not Disturb; a Shortcut using "Set Focus" covers it.
- **Calendar** uses EventKit (`com.apple.security.personal-information.calendars`).

## Pulse

- The helper samples every 2 s (`MetricsMonitor`) and keeps a 10-minute `MetricsHistory`, which seeds each iPad on connect.
- Per-app culprits come from libproc, and only while CPU or memory spikes (`SystemMetrics.*Threshold`). Helper processes fold into the `.app` they ship in.
- Charts follow the `dataviz` skill: stat tiles with a recessive single-series sparkline, a meter for ratios against a limit, and status shown with icon + words, never colour alone. Render a chart and look at it before calling it done.

## Previewing on the iPad

DEBUG builds accept `-HaloDemo [page index]`, which fills every widget with rendered `DemoData` (a wallpaper, artwork, icons, agents and more) and needs no Mac. Add `-HaloDemoEditing` to open in edit mode, and `-HaloLandscape` to request landscape. Use it for screenshots and design passes:

```sh
xcrun simctl launch booted dk.patrickjak.halo.pad -HaloDemo 2 -HaloDemoEditing
```

## Trackpad and the latency budget

The PRD budget is **< 20 ms p95, iPad touch to Mac pointer**. Treat every change on this path as performance work.

- **iPad:** `TouchSurfaceView` reads raw touches (no gesture recognizers, since they wait before deciding) → `TrackpadInterpreter` → `PadMessage.pointer`. The interpreter is pure and takes timestamps from its caller. Add a test for any new gesture.
- **Mac:** `PadLink.receive` is `@concurrent`, so pointer events reach `InputInjector` and pings are answered without touching the main actor. Never route pointer events through `onMessage`.
- **Measuring:** `LatencyProbe` pings once a second on the same connection. Debug builds show the estimated one-way p50/p95 in Trackpad mode, amber when over budget. Check it before and after changes.
- **Wire format:** pointer events stay JSON (~8 µs, 67 bytes). `PointerEncodingTests` guards this. Go binary only if that test says so.
- **Mac limitations:** there's no public API to synthesise magnify gestures, so pinch maps to ⌘= / ⌘−, and three-finger swipes map to the ⌃-arrow shortcuts for spaces, Mission Control and App Exposé. Posting events needs Accessibility (`InputAccess`).

## Troubleshooting

- **The iPad can't find the Mac / `Listener failed: -65555: NoAuth`.** Bonjour refused to advertise. Check these in order:
  1. **Not sandboxed.** The helper must never have App Sandbox. Don't add it under Signing & Capabilities, and regenerate with `xcodegen generate` if someone did. A sandboxed helper also shows a red warning in its menu.
  2. **Run from a standard location.** mDNSResponder only trusts `NSBonjourServices` from apps it can read via LaunchServices (`/Applications`, `~/Applications`). Debug builds install to `~/Applications/Halo Helper.app` for this reason. A copy run from DerivedData or `/tmp` fails with "Info.plist(NSBonjourServices) does not allow".
  3. **Signed by the team** (`DEVELOPMENT_TEAM` in `project.yml`). Ad-hoc builds are refused.
  4. **Local Network allowed** for *Halo Helper* (System Settings › Privacy & Security › Local Network) and for *Halo* on the iPad. Both apps detect this (`Error.isLocalNetworkDenied`) and link to Settings.
- **Reading the logs:** in zsh, `log` is a shell builtin, so use `/usr/bin/log show --predicate 'subsystem == "app.halo"'`. For Bonjour trust errors, filter on `process == "mDNSResponder"`.
- `Unable to obtain a task name port right for pid …` is AppKit asking about WindowServer. It's harmless and not ours.
- **The pointer doesn't move.** Allow *Halo Helper* under System Settings › Privacy & Security › Accessibility. A rebuilt app with a new signature may need to be re-added.
- Both devices must be on the same network, or close enough for peer-to-peer Wi-Fi.

## Tech conventions

- **Swift 6**, strict concurrency `complete`. No `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why.
- **SwiftUI** + **Observation** (`@Observable`), not `ObservableObject`/Combine. UI models are `@MainActor`.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`) for new tests, not XCTest.
- Targets: iPadOS 26.0+, macOS 26.0+. No availability checks for older OSes.
- Networking: `Network.framework`. No third-party dependencies without discussing first.
- Wire protocol is `Codable` enums in `HaloProtocol`. Bump `haloProtocolVersion` on any breaking change. Keep messages small — trackpad events are latency-critical.
- Keep logic pure and testable in `HaloCore` (e.g. `ModeSuggester` is a pure function of state).

## Product principles that affect code

From the PRD — treat these as requirements, not taste:

- **Quiet by default.** Slow, eased motion (~0.4–0.8 s). Warm colours, dark UI. Nothing blinks unless the user must act.
- **Readable from arm's length.** Each mode has one hero number/action in large type.
- **Instant or it doesn't ship.** Trackpad input budget is **< 20 ms p95** iPad → Mac. Never block the input path with JSON-heavy work, logging, or main-thread hops you don't need.
- **It comes to you.** Auto-switching goes through `ModeSuggester`; a manual pick always wins.
- **No settings maze.** Customisation via long-press, not preference screens.
- **Fully localised**, one language at a time — no hardcoded mixed-language strings. Use String Catalogs.
- **Always-on screen.** Zen needs pixel shift and auto-dim to avoid burn-in.

## Security & distribution

- Pairing: one-time pairing code, end-to-end encryption, paired iPads only. Never accept input events from an unpaired peer.
- The Mac helper is **not sandboxed** (needs Accessibility for input injection) and ships **only** as a **notarised direct download** with Hardened Runtime. It will never be on the Mac App Store, so App Store sandbox rules do not apply.
- Agent adapters that can't approve actions safely ship **read-only** (`AgentSession.canApprove = false`).

## Non-goals (don't build these)

Screen mirroring / second display, Windows/Android/iPhone, remote use over the internet, a full agent client (long prompts, diff review), plugins or widget marketplace.

## Working agreements

- **Always use the provided skills.** Before starting a task, check which skills are available (e.g. in `.claude/skills/`, `.agents/skills/`, or those your harness lists) and use every one that fits the task. Follow a skill's instructions instead of improvising your own approach.
- Commit after every change/feature with a clear message. Small, focused commits.
- Don't commit `Halo.xcodeproj`, `.build/`, `DerivedData/`, or `xcuserdata/`.
- Run `swift test --package-path Packages/HaloKit` and build both schemes before committing.
- When something in the PRD is ambiguous (see its *Open questions*), ask rather than guess.
