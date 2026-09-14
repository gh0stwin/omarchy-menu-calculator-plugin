# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

- `Calculator.js` is a QML `.pragma library` module, but it runs verbatim under node once that first line is stripped — `test/calculator.test.js` is the regression harness that does exactly that (`node test/calculator.test.js`, no QML host needed). Keep its display-precision expectations in step with `formatValue()` and the README's usage table.

- `manifest.json`'s `author` is informational metadata: neither Omarchy's `bin/omarchy-plugin-validate` nor `PluginRegistry.qml` (checked against basecamp/omarchy) consumes it, and no schema defines an array form — the accepted multi-author shape is one string, original author first (`"Koen Hendriks, gh0stwin"`). Any manifest change is validated by sparsely cloning basecamp/omarchy and running `bash bin/omarchy-plugin-validate <worktree>` (exit 0).

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
