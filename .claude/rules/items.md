# Items

- Only the file types `CONTRIBUTING.md` lists. Never add `.smx`, `.so`, binaries, scripts or downloads.
- Mode cfgs: only `cvar value` lines that `CfgDoc::validate` accepts (no exec, alias, rcon, sm_*, `;`, quotes).
- Plugin convars a mode sets are put back in `CSLS_OnModeReset`; `tools/lint.py` fails otherwise.
- Admin commands use `RegAdminCmd` with a permission flag from the table in `CONTRIBUTING.md`, never
  `RegConsoleCmd` plus a manual check. Cheat-like tools call `CSLS_Exempt`.
- No network, no extensions, no `ServerCommand` with player-typed text, no files outside SourceMod `data/`.
- Every phrase has `en` and `es`. Every item has `name` and `description` in both.
- A change to `game/plugin/include/csls.inc` belongs to CSGO-Server first; then move `engine.toml`.
