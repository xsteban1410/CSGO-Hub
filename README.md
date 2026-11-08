# CSGO-Hub

Game modes, plugins and packs for [CS:GO Legacy Server](https://github.com/xsteban1410/CSGO-Server).
The app comes without game modes: you pick them here, from its **Hub** tab or the CLI.

```sh
csgo-legacy-server hub list              # what there is; * = installed
csgo-legacy-server hub install pack-all  # every mode
csgo-legacy-server hub install zombies   # one mode, with the plugin it needs
csgo-legacy-server hub update            # newer versions of what you have
csgo-legacy-server hub remove zombies
```

Nothing here is built into the app, so a mode can change without a new app release: merge it here and the
app sees it the next time it opens the hub.

## What there is

| Kind | What it is | Examples |
|---|---|---|
| `mode` | A game mode: `cfg/modo_<id>.cfg` and `modes/<id>.toml`, sometimes needing a plugin | `competitivo`, `zombies`, `awp` |
| `plugin` | SourceMod plugin source, compiled on your PC | `skins`, `aimbot`, `modos_zombies` |
| `pack` | A list of other items | `pack-valve`, `pack-all`, `pack-admin` |
| `map` | Workshop maps by id | |

### Admin tools

For players with a role that has the permission (Players → Admins in the app, or `csgo-legacy-server admins`):

| Command | Item | Permission |
|---|---|---|
| `!am [player]` aimbot | `aimbot` | `cheats` |
| `!wh [player]` wallhack | `wallhack` | `cheats` |
| `!nc [player]` noclip, `!god [player]` | `noclip-god` | `cheats` |
| `!respawn [player]`, `!hp <player> <health>` | `respawn-hp` | `cheats` |
| `!tp <player>`, `!bring <player>` | `teleport` | `slay` |
| `!bots` menu | `bots-menu` | `bots` |

These only work on your own server, which always runs with `-insecure` (no VAC). They are not for, and do not
work on, official or VAC-secured servers.

## How it gets to the app

1. A pull request adds or changes `items/<id>/`.
2. CI checks it with the app's own validator (`csgo-legacy-server hub check`), lints it and compiles every
   plugin with the SourceMod build the app installs.
3. The maintainer reviews it. Only what is merged into `main` is published.
4. CI publishes `index.json`, one zip per item and the previews to
   [GitHub Pages](https://xsteban1410.github.io/CSGO-Hub/).
5. The app downloads the zip, checks its SHA-256 against the index, checks the files again, and compiles the
   plugins locally. Nothing compiled is ever downloaded.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md): the format of an item, the rules, and how to test it before the
pull request. Security problems go by [SECURITY.md](SECURITY.md), not in an issue.

Everything here is GPL-3.0-or-later unless an item says otherwise in its `license`.
