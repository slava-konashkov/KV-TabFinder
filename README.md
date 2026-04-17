# KV-TabFinder

Spotlight-style browser tab search for macOS. Press a global hotkey → get a fuzzy-searchable list of every tab open in Safari, Chrome, Chromium, Arc, Brave, Edge, Vivaldi, or Opera → hit Enter to jump to it.

**Sandboxed, App Store-ready.**

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project: `brew install xcodegen`

## First build

```bash
brew install xcodegen          # one-time
xcodegen                       # generates KV-TabFinder.xcodeproj from project.yml
open KV-TabFinder.xcodeproj
```

In Xcode:

1. Select the `KV-TabFinder` target → **Signing & Capabilities** → pick your team.
2. Verify that **App Sandbox** is on and the `KV-TabFinder.entitlements` file is in use.
3. Press **⌘R** to run.
4. The menu-bar magnifying glass appears; press **⌥⇥** to open search.

First time you hit the hotkey, macOS will ask permission for each browser KV-TabFinder tries to read from (*"KV-TabFinder wants to control Safari/Chrome/…"*). Approve them. If you refuse later, re-enable in **System Settings → Privacy & Security → Automation**.

## Usage

| Action | Shortcut |
|---|---|
| Open search (default) | ⌥⇥ |
| Next / previous result | ↓ / ↑ |
| Jump to tab | ↩ (Enter) |
| Close panel | ⎋ (Escape) |

Change the shortcut in **Menu bar icon → Preferences…**.

## Architecture

- `Hotkey/` — Carbon `RegisterEventHotKey` wrapper (sandbox-safe, no Accessibility permission needed).
- `Browsers/` — AppleScript-based tab providers. Chromium-family browsers share one script parameterised by bundle ID.
- `Search/` — fuzzy matcher with match-index highlights.
- `UI/` — `NSPanel` floating window hosting a SwiftUI search view.
- `Settings/` — Settings scene + menu bar menu.
- `Permissions/` — detects `errAEEventNotPermitted` and guides the user to Automation settings.

## Debugging / logs

Логи пишутся в unified logging (os.Logger) под subsystem `com.konashkov.KV-TabFinder`.

В терминале — стрим в реальном времени:

```bash
log stream --style compact --predicate 'subsystem == "com.konashkov.KV-TabFinder"'
```

Последние 5 минут:

```bash
log show --style compact --predicate 'subsystem == "com.konashkov.KV-TabFinder"' --last 5m
```

В Console.app: поле фильтра → `subsystem:com.konashkov.KV-TabFinder`.

Категории: `app`, `hotkey`, `panel`, `aggregator`, `provider`, `applescript`.

## Known limitations

- **Firefox is not supported.** Firefox doesn't expose tab titles via AppleScript.
- **Chrome Incognito tabs** are not returned — this is Chrome's own AppleScript policy.
- The first access of each browser pops a system permission prompt (one-time).

## Mac App Store distribution

Sandbox is on and the `scripting-targets` entitlement explicitly lists the eight supported browser bundle IDs. In App Review, explain that AppleScript is used only to read tab titles/URLs and to activate the user-selected tab — no page content is accessed.

## Tests

`⌘U` in Xcode. Tests cover `FuzzyMatcher`, `HotkeyCombo` (encode/decode + display), and `TabAggregator` with fake providers.
