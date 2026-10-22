# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. Read `docs/PRD.md` first — it is the source of truth for *what* we build and *why*.

## What Halo is

Halo turns the iPad next to a Mac into a calm, always-on companion surface with six modes — **Zen, Trackpad, Pulse, Agents, Launch, Deck** — and a persistent status strip. Halo brings the right mode forward on its own (e.g. an agent needs approval → Agents), always overridable by the user.

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
│   └── HaloMac/           ← Mac helper (SwiftUI MenuBarExtra, LSUIElement)
│       ├── Sources/
│       └── Resources/
├── Packages/
│   └── HaloKit/           ← shared Swift package used by both apps
│       ├── Sources/HaloCore/      models (Mode, SystemMetrics, AgentSession), ModeSuggester
│       ├── Sources/HaloProtocol/  wire messages (MacMessage, PadMessage), coding, service type
│       └── Tests/
└── docs/
    └── PRD.md
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
