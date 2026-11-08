# Contributing to CSGO-Hub

One pull request adds or changes **one item**. Everything in the repo is in English, except the `es` texts.

## An item

```text
items/<id>/
  item.toml                    what it is (required)
  preview.png                  16:9, under 300 KB
  cfg/modo_<mode>.cfg          mode rules (mode items)
  modes/<mode>.toml            mode metadata: name, category, maps
  plugin/<name>/<name>.sp      SourceMod plugin source
  plugin/<name>/translations/<name>.phrases.txt
  data/*.cfg|*.txt             copied to addons/sourcemod/configs
```

`item.toml`:

```toml
id = "zombies"                 # = the folder name: a-z, 0-9, - and _
kind = "mode"                  # mode | plugin | pack | map
version = "1.0.0"              # raise it on every change, or the app will not update
api = 1                        # CSLS_API of game/plugin/include/csls.inc
min_engine = ""                # lowest app version, when you need something new
author = "you"
license = "GPL-3.0-or-later"
name = { en = "Zombies", es = "Zombis" }
description = { en = "...", es = "..." }
requires = ["modos_zombies"]   # installed with it
tags = ["pve"]                 # a mode's category goes here too
preview = "preview.png"
changes = { en = "...", es = "..." }  # what this version changed; required when you raise the version
```

Only these file types are accepted: `toml cfg sp inc txt md png jpg jpeg webp`. No `.smx`, `.so`, binaries,
scripts, links or hidden files: the app refuses the whole item.

## Modes

A mode is a cfg of `cvar value` lines, checked like a mode imported in the app:

- no `exec`, `alias`, `rcon`, `quit`, `map`, `changelevel`, `sv_password`, `sm_*` or other commands that
  change the server; no `;` or quotes inside values;
- rule blocks (`modo_regla_N`) only from the closed catalog;
- `modo_*` convars of the engine (`modo_t_arma`, `modo_ct_vida`...) need nothing else. A convar of your own
  plugin must be put back in `CSLS_OnModeReset` (see below), or it leaks into the next mode;
- the metadata (`modes/<id>.toml`) follows the ones already here: `category`, `name`, `description`, and
  `game_type`/`game_mode`, `map_prefixes`, `default_map`, `options` when needed.

Do not rename an existing mode id or `modo_*` convar: players' presets and tasks use them.

## Plugins

Plugins are compiled on the player's PC against `#include <csls>`, the engine API:

```sourcepawn
#include <csls>

public void CSLS_OnModeReset()          // before every mode: put your convars back
{
    g_MyConvar.RestoreDefault();
}

public void CSLS_OnEquip(int client) {} // after the engine gave the mode's weapons
public Action CSLS_OnPlaceHuman(int client) { return Plugin_Continue; } // Plugin_Handled keeps a human on their side
// CSLS_Exempt(client, seconds): tell the anticheat you are moving this player's aim or speed on purpose
```

Rules:

- **Source only**, GPL-compatible, and yours to share.
- **No network** (sockets, HTTP extensions), no extensions, no writing outside SourceMod's `data/` folder, and
  no `ServerCommand` built from text a player typed.
- **Permissions**: every command that is not for everyone is `RegAdminCmd` with one of these flags. The app's
  roles grant them:

  | Permission | Flag | For |
  |---|---|---|
  | `console` | `ADMFLAG_RCON`, `ADMFLAG_CVAR` | `sm_rcon`, `sm_cvar` |
  | `kick` / `ban` | `ADMFLAG_KICK` / `ADMFLAG_BAN`, `ADMFLAG_UNBAN` | |
  | `map` | `ADMFLAG_CHANGEMAP` | |
  | `slay` | `ADMFLAG_SLAY` | teleport, slap, slay |
  | `chat` | `ADMFLAG_CHAT` | |
  | `cheats` | `ADMFLAG_CUSTOM1` | aimbot, wallhack, noclip, god, health |
  | `bots` | `ADMFLAG_CUSTOM2` | bot control |

- Cheat-like tools call `CSLS_Exempt` so the anticheat does not punish them, and are never usable without
  their permission.
- Messages go through a translations file with `en` and `es` for every phrase.
- Name the plugin after the item when you can. Engine names (`modos`, `csls_*`) are refused.

## Testing before the pull request

```sh
# from a CSGO-Server checkout, built with cargo build
./target/debug/csgo-legacy-server hub check ../CSGO-Hub/items/<id>
python3 tools/lint.py ../CSGO-Server
tools/compile.sh ../CSGO-Server /tmp/sm

# try it on your server: copy the item where the app installs them, then deploy and start it
cp -r items/<id> ~/.local/share/csgo-legacy-server/hub/
csgo-legacy-server deploy && csgo-legacy-server start <mode>
```

From CSGO-Server's `go/`, `go run ./cmd/testkit -root .. full <mode>` checks that the game type is right and
bots move and respawn. It does not prove how the mode plays: say in the pull request what you played.

`tools/make_preview.py items/<id>` draws a plain preview from the item's name; a screenshot is better.

## Review

CI must be green. The maintainer reads every line of a plugin before merging, since it runs on other people's
servers. A change to an existing item raises its `version` and says what changed in `changes`; CI checks both. Breaking the engine API needs a new `api` and
a CSGO-Server release first.
