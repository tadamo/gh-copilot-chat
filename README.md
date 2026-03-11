# GH Copilot Chat

A lightweight native macOS app that wraps [GitHub Copilot Chat](https://github.com/copilot) in a dedicated desktop window with full menu support and native macOS integration.

![GH Copilot Chat](gh-copilot-chat.png)

## Requirements

- macOS 12.0 or later
- Xcode Command Line Tools (provides `swiftc`)

If you don't have the command line tools installed:

```sh
xcode-select --install
```

## Getting Started

### Build

```sh
./build.sh
```

This compiles `GHCopilotChat.swift` and produces a `GH Copilot Chat.app` bundle in the current directory.

### Install (optional)

```sh
cp -r 'GH Copilot Chat.app' /Applications/
```

### Run

```sh
open 'GH Copilot Chat.app'
```

> **First launch:** macOS Gatekeeper will block an unsigned app. Right-click the app and choose **Open**, then confirm in the dialog.

## Features

- Loads `https://github.com/copilot` on startup
- External (non-GitHub) links open in your default browser
- Back/forward navigation with swipe gestures and History menu
- Zoom controls (Cmd +/−/0)
- Find in page (Cmd+F)
- Print support
- Page load progress bar
- Window position is remembered between launches

## Development

The entire app is a single Swift file — `GHCopilotChat.swift`. No external dependencies, package manager, or Xcode project required. Edit the file and re-run `./build.sh` to rebuild.

## License

MIT
