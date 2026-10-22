# Contributing to Halo

Thanks for wanting to make Halo better. Bug reports, ideas, new widgets and polish are all welcome.

## Getting set up

1. Install **Xcode 26 or later** and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Run `xcodegen generate`, then `open Halo.xcodeproj`.
3. Set your own team: change `DEVELOPMENT_TEAM` (and the bundle IDs, if you like) in `project.yml`, then run `xcodegen generate` again. Bonjour only works for signed builds, so pairing needs a real team.
4. Run **HaloMac**, then **HaloPad** on an iPad on the same Wi-Fi, and pair from the Mac's menu bar.

The Xcode project is generated from `project.yml` and isn't committed. Change `project.yml`, never the project, and that includes Info.plist keys and entitlements: Xcode's Signing & Capabilities edits are lost on the next `xcodegen generate`.

Read **[AGENTS.md](AGENTS.md)** before a bigger change. It's the architecture, the design language and the rules that keep Halo fast and safe, in one place.

## Trying things without a Mac

DEBUG builds of the iPad app take launch arguments that fill every widget with sample data:

```sh
xcrun simctl launch booted dk.patrickjak.halo.pad -HaloDemo 0              # page 0 of the showcase layout
xcrun simctl launch booted dk.patrickjak.halo.pad -HaloDemo 0 -HaloDemoEmpty    # the first-launch hello
xcrun simctl launch booted dk.patrickjak.halo.pad -HaloDemo 1 -HaloFrame 1210x834   # exact 11-inch landscape
```

## Easy first contributions

- **A new widget.** Add a `WidgetKind` (title, summary, symbol, the sizes it comes in) in `Packages/HaloKit/Sources/HaloDashboard`, then a view in `Apps/HaloPad/Sources/Widgets`. Check it at its smallest and largest size.
- **A new Deck action.** Built-ins live in `DeckCatalog` in `Packages/HaloKit/Sources/HaloDesktop`.
- **Another agent tool.** Add an `AgentAdapter` and a `HookConfiguration` case, with tests built from the tool's documented hook payloads.

## Ground rules

- **Local and private.** Nothing leaves the local network: no analytics, telemetry or cloud APIs.
- **Fast.** The trackpad has a 20 ms budget from touch to pointer. Never put the main actor, logging or heavy work on that path.
- **Safe.** Agent hooks fail open, and approvals only ever come from a paired iPad or the Mac itself.
- **Quiet.** Slow, eased motion; nothing blinks unless it needs you. Status is never colour alone.
- **Match the style.** Swift 6 with strict concurrency, SwiftUI and Observation, Swift Testing, comments that explain *why*.

## Pull requests

- Keep each one to one thing, and say what it changes and how you tried it.
- Include a screenshot for anything visible.
- Make sure `swift test --package-path Packages/HaloKit` passes and both schemes build.

By contributing you agree that your work is shared under the project's [MIT License](LICENSE). Please follow the [code of conduct](CODE_OF_CONDUCT.md).
