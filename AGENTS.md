# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

- `Calculator.js` is a QML `.pragma library` module, but it runs verbatim under node once that first line is stripped — `test/calculator.test.js` is the regression harness that does exactly that (`node test/calculator.test.js`, no QML host needed). Keep its display-precision expectations in step with `formatValue()` and the README's usage table.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
