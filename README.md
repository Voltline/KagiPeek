# KagiPeek
A lightweight macOS utility for shortcuts visualization.

## MVP Features
- Global keyboard listening via `CGEventTap` (`flagsChanged` / `keyDown` / `keyUp`)
- Modifier state machine (`cmd` / `opt` / `ctrl` / `shift`)
- Prefix-based shortcut indexing with Trie
- Real-time candidate query and console logging
- Floating overlay panel (`NSPanel`) for shortcut hints

## Architecture
`GlobalKeyListener -> ModifierStateMachine -> ShortcutTrie -> KeyPrefixEngine -> OverlayPanel`

## Run Notes
1. Open the project in Xcode and run the app.
2. Grant Accessibility permission when macOS prompts.
3. Hold modifier keys (for example `cmd` or `cmd+opt`) to trigger overlay and candidate list.

## Important Permissions
- Global key listening needs Accessibility permission.
- App Sandbox is disabled in this project to allow global event tap in MVP mode.
