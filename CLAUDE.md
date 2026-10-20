# Project rules

## Design documents and feature workflow

- `docs/game-design.md`: the full game vision (MVP and beyond), kept high level. Answers *what* and *why*.
- `docs/technical-design.md`: project-wide conventions, architecture and technical decisions.
- `docs/roadmap.md`: MVP definition, build order and status of every feature, plus the idea backlog.
- `docs/features/NNN-name.md`: one spec per feature, copied from `docs/features/_template.md`.
  Numbers are permanent IDs (zero-padded, never reused or renumbered); build order lives in the roadmap.

Every fact lives in one place: status and order only in the roadmap, never in the game design doc.
The game design doc's tables have a **Feature** column that links to the feature spec (`—` until one exists).

An idea moves through the docs like this:

1. It comes up mid-feature: add one line to the roadmap's idea backlog.
2. It becomes part of the vision: add it to `docs/game-design.md` with `—` in its Feature column.
3. It gets scheduled: give it a number, create its file in `docs/features/`, add it to the roadmap,
   and replace the `—` with a link to the spec.

Work on one feature at a time, the first unfinished one in the roadmap. When a feature's work is done,
check off its requirements, set its status in both the feature file and the roadmap, and record any
project-wide decisions in `docs/technical-design.md`. New ideas that come up mid-feature go into the
roadmap's idea backlog, not into the current feature.

## Keep keyboard and gamepad controls in sync

Whenever a control is added or changed, decide its keyboard/mouse and its gamepad binding at the same time,
including hold or toggle behaviour, and update both in the Controls table in `docs/game-design.md` in the same
change. When asking the user about a control, ask about both devices together. Never leave one device's
binding missing or out of date.

## Keep `.gitignore` up to date

Whenever a change introduces files or directories that should not be committed, update
`.gitignore` in the same change. Do not leave it for later.

This includes, for example:

- Build output and generated artifacts (e.g. `dist/`, `build/`, `*.egg-info/`).
- Dependency and cache directories (e.g. `node_modules/`, `.venv/`, `__pycache__/`, `.pytest_cache/`).
- Local environment and secret files (e.g. `.env`, `*.local`, credentials, keys).
- Logs, temp files, coverage reports, and local databases.
- Editor/OS files and tool-specific local state (e.g. `.idea/`, `.vscode/` local settings, `.DS_Store`,
  `Thumbs.db`, `.claude/settings.local.json`).

Before committing, check `git status` for untracked files that should be ignored and add patterns for
them. Prefer general patterns over listing individual files, and group entries under short comment
headers. If `.gitignore` does not exist yet, create it.
