
# ChatGPT Dark

ChatGPT Dark is a small macOS helper that forces the official ChatGPT macOS app to use Dark Aqua at runtime.


## Quick Start

1. Open the DMG.
2. Drag `ChatGPT Dark.app` into the `Applications` folder.
3. Launch `ChatGPT Dark` from `/Applications`.
4. It will register itself as a login item and quietly watch for all ChatGPT launches. ( See note below )
5. If System Integrity Protection (SIP) is enabled, follow the on-screen instructions to disable it in Recovery Mode.
6. Open ChatGPT normally. Developer Access Tools will prompt you for your password, then the helper should apply dark mode.

## Important Note

To selectively choose when to force dark mode, remove it from autostarting (System Settings > General > Login Items & Extensions) and open ChatGPT Dark when needed.


----------------------------------------------------------------


## What This App Does

The official ChatGPT macOS app does not expose a normal setting for forcing the full macOS Dark Aqua appearance. ChatGPT Dark works around that by attaching to the running app process and overriding appearance-related Objective-C behavior at runtime.

## Why Disabling SIP Is Required

This project uses runtime instrumentation. On modern macOS, System Integrity Protection blocks the attach/injection model this helper relies on. If SIP is enabled, the helper cannot do its job.

## Disclaimer

Use this project at your own risk. It is meant as a personal utility for advanced macOS users, not as a supported or endorsed extension of the ChatGPT app.
