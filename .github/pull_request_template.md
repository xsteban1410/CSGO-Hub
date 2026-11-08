## What this adds or changes

<!-- One item per pull request. Name it: mode, plugin, pack or map, and its id. -->

## Checklist

- [ ] The item is in `items/<id>/` with an `item.toml`, and its `version` went up if it already existed.
- [ ] Name and description in English and Spanish (`en`, `es`), also in every plugin phrase.
- [ ] Only source and text: no `.smx`, `.so`, binaries, scripts or downloaded files.
- [ ] Plugins: every admin command uses `RegAdminCmd` with a permission from [CONTRIBUTING](../CONTRIBUTING.md#permissions); convars a mode sets are put back in `CSLS_OnModeReset`.
- [ ] Nothing contacts the network, writes outside SourceMod's `data/`, or is meant for servers with VAC.
- [ ] `preview.png` is 16:9 and under 300 KB.
- [ ] License compatible with GPL-3.0 and you can share the content.

## How I tried it

<!-- The mode you played, the commands you ran, against bots or with people. Say what you could not try. -->
