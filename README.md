# KV-TabFinder

Spotlight-style browser tab search for macOS. Press a global hotkey → get a fuzzy-searchable list of every tab open in Safari, Chrome, Chromium, Arc, Brave, Edge, Vivaldi, or Opera → hit Enter to jump to it.

Menu-bar only (no Dock icon). Search by title **and** URL. Each Chrome profile renders in its own color so tabs from different Google accounts stay distinguishable.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project: `brew install xcodegen`
- Any Apple ID signed into Xcode (a free Personal Team is enough for local use)

## Build & install

```bash
brew install xcodegen          # one-time
xcodegen                       # generates KV-TabFinder.xcodeproj from project.yml
```

Open in Xcode and pick your Team under the `KV-TabFinder` target → **Signing & Capabilities**. Then from the command line:

```bash
xcodebuild \
  -project KV-TabFinder.xcodeproj \
  -scheme KV-TabFinder \
  -configuration Local \
  -destination 'platform=macOS' \
  build \
  CODE_SIGN_IDENTITY="Apple Development: <your cert>" \
  CODE_SIGN_STYLE=Manual

cp -R \
  ~/Library/Developer/Xcode/DerivedData/KV-TabFinder-*/Build/Products/Local/KV-TabFinder.app \
  /Applications/
```

Launch from `/Applications`. A magnifying glass appears in the menu bar; press **⌥⇥** to open search.

First time you hit the hotkey, macOS asks permission for each browser (*"KV-TabFinder wants to control Google Chrome…"*). Approve. To revisit later: **System Settings → Privacy & Security → Automation**.

### Build configurations

| Config | Sandbox | Hardened Runtime | Use |
|---|---|---|---|
| **Debug**   | off | off | Local development from Xcode (⌘R) |
| **Local**   | off | on  | Installable build for `/Applications` — signed with Apple Development cert, no paid Dev Program needed |
| **Release** | on  | on  | Mac App Store submission — requires paid Apple Developer Program for the `scripting-targets` provisioning profile |

## Usage

| Action | Shortcut |
|---|---|
| Open search (default) | ⌥⇥ |
| Next / previous result | ↓ / ↑ |
| Jump to tab | ↩ |
| Close panel | ⎋ |

Change the shortcut in **Menu bar icon → Settings…**.

## Architecture

- `Hotkey/` — Carbon `RegisterEventHotKey` wrapper (sandbox-safe, no Accessibility permission needed).
- `Browsers/` — AppleScript-based tab providers. Chromium-family browsers share one script parameterised by bundle ID. `ChromeHistoryStore` reads each profile's `History` SQLite (via `?immutable=1`) to resolve window → account.
- `Search/` — fuzzy matcher with match-index highlights; matches against both title and URL.
- `UI/` — `NSPanel` floating window hosting a SwiftUI search view. Arrow keys, Enter and Escape are intercepted at the panel level in `sendEvent(_:)` so the ScrollView never steals them.
- `Settings/` — settings window (plain `NSWindow` + `NSHostingController`, not SwiftUI's `Settings` scene — that doesn't work for `LSUIElement` apps) and menu bar menu.
- `Permissions/` — detects `errAEEventNotPermitted` and guides the user to Automation settings.

## Debugging / logs

Logs go through unified logging (`os.Logger`) under subsystem `com.konashkov.KV-TabFinder`.

Live stream:

```bash
log stream --style compact --predicate 'subsystem == "com.konashkov.KV-TabFinder"'
```

Last 5 minutes:

```bash
log show --style compact --predicate 'subsystem == "com.konashkov.KV-TabFinder"' --last 5m
```

In Console.app: filter → `subsystem:com.konashkov.KV-TabFinder`.

Categories: `app`, `hotkey`, `panel`, `aggregator`, `provider`, `applescript`.

## Known limitations

- **Firefox is not supported.** Firefox doesn't expose tab titles via AppleScript.
- **Chrome Incognito tabs** are not returned — this is Chrome's own AppleScript policy.
- The first access of each browser pops a system permission prompt (one-time).
- Chrome profile detection relies on reading the browser's `History` SQLite files on disk; works in Debug / Local builds only. The sandboxed Release build would need user-granted filesystem access.

## Mac App Store distribution

For App Store submission use the `Release` configuration: sandbox is on and the `scripting-targets` entitlement explicitly lists the eight supported browser bundle IDs. In App Review, explain that AppleScript is used only to read tab titles / URLs and to activate the user-selected tab — no page content is accessed.

## Tests

`⌘U` in Xcode. Tests cover `FuzzyMatcher`, `HotkeyCombo` (encode/decode + display), and `TabAggregator` with fake providers.
