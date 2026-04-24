# Privacy Policy — KV-TabFinder

_Last updated: 2026-04-24_

KV-TabFinder is a macOS menu-bar utility that helps you search and
jump to tabs that are already open in your own browsers.

## What data the app collects

**None.** The app does not collect, store, transmit, sell, or share
any personal information or usage data. There are no accounts, no
analytics, no crash reporters, no advertising identifiers, and no
telemetry of any kind.

## What the app reads locally

To build the list of open tabs, the app uses Apple's standard
scripting APIs (AppleScript via `com.apple.security.scripting-targets`)
to ask the following browsers, only while they are running, for the
titles and URLs of their currently open tabs:

- Safari, Google Chrome, Chromium, The Browser Company's Arc, Brave,
  Microsoft Edge, Vivaldi, Opera.

This information:

- never leaves your Mac;
- is held in memory only while the search window is visible and is
  discarded as soon as you dismiss it;
- is not written to disk, not uploaded anywhere, not shared with any
  third party.

When you activate a result, the app simply brings the corresponding
browser window/tab to the front. It does not read the contents of
web pages.

## Network activity

The app makes no network connections of its own.

## Children

The app is rated 4+ and contains no user-generated content, ads, or
external links other than those already open in your browser.

## Changes

If this policy ever changes, the updated version will be published
at the same URL.

## Contact

Questions or concerns: open an issue at
<https://github.com/slava-konashkov/KV-TabFinder/issues> or email
`slava@konashkov.com`.
