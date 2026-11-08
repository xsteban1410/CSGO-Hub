# Security

Hub items run on people's servers, so treat a problem in one as a security issue.

## Reporting

Use [GitHub's private vulnerability reporting](https://github.com/xsteban1410/CSGO-Hub/security/advisories/new)
for anything that lets an item, or a player on a server running it, do more than it should: run commands,
bypass a permission, read or write files, or reach the network. Do not open a public issue for it.

## What protects players

- Only items merged into `main` after review and a green CI are published.
- The app checks each download against the SHA-256 in the index, refuses files outside the allowed types and
  paths, validates every mode cfg like an imported mode, and refuses plugins named like the engine's.
- Plugins come as source and are compiled on the player's PC. No compiled plugin or extension is accepted.
- Admin tools only work for roles that have their permission, and roles with the server console need a
  password typed in game (`sm_login`), because SteamIDs can be faked on a server with `-insecure`.

What none of this can do is prove that a plugin's code is harmless: that is what the review is for.
If an item turns out to be harmful it is removed from `main`, which removes it from the index.
