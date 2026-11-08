# CSGO-Hub
Content for CS:GO Legacy Server: game modes, SourceMod plugins and packs, installed by the app from GitHub Pages.
The engine (app, CLI, core, engine plugins) lives in ~/CSGO-Server (github.com/xsteban1410/CSGO-Server).

## Layout
- `items/<id>/item.toml` + content; format and rules in `CONTRIBUTING.md`. One pull request = one item.
- `tools/lint.py <engine>`, `tools/compile.sh <engine> <work>`, `tools/build_index.py <out>`, `tools/make_preview.py`.
- `engine.toml`: the CSGO-Server ref CI checks against (validator, `csls.inc`, pinned SourceMod).
- CI (`.github/workflows/ci.yml`) checks every PR; pushes to `main` publish to Pages.

## How we work
- Everything in English; Spanish only in `es` texts. Do not rename mode ids or `modo_*` convars.
- Raise `version` in `item.toml` on every change to an item, or the app will not update it.
- Before saying an item works: `csgo-legacy-server hub check`, `tools/lint.py`, `tools/compile.sh`; to play it,
  copy it to `~/.local/share/csgo-legacy-server/hub/` and `deploy`. Say what was not played.
- Rules in `.claude/rules/` always apply.

## Git
- Claude may commit and push here (the user's permission). `type(item): what changed`, e.g. `feat(zombies): ...`.
  `Co-Authored-By` only on the last commit of a task. Never force-push.
