# CSGO-Hub

Modos de juego, plugins y packs para [CS:GO Legacy Server](https://github.com/xsteban1410/CSGO-Server).
La app viene sin modos de juego: los eliges aquí, desde su pestaña **Hub** o la CLI.

```sh
csgo-legacy-server hub list              # lo que hay; * = instalado
csgo-legacy-server hub install pack-all  # todos los modos
csgo-legacy-server hub install zombies   # un modo, con el plugin que necesita
csgo-legacy-server hub update            # versiones nuevas de lo que tienes
csgo-legacy-server hub remove zombies
```

Nada de esto va dentro de la app, así que un modo puede cambiar sin sacar otra versión de la app: se fusiona
aquí y la app lo ve la próxima vez que abre el hub.

## Qué hay

| Tipo | Qué es | Ejemplos |
|---|---|---|
| `mode` | Un modo de juego: `cfg/modo_<id>.cfg` y `modes/<id>.toml`, a veces con un plugin | `competitivo`, `zombies`, `awp` |
| `plugin` | Código fuente de un plugin de SourceMod, compilado en tu PC | `skins`, `aimbot`, `modos_zombies` |
| `pack` | Una lista de otros items | `pack-valve`, `pack-all`, `pack-admin` |
| `map` | Mapas del Workshop por id | |

### Herramientas de admin

Para jugadores con un rol que tenga el permiso (Jugadores → Admins en la app, o `csgo-legacy-server admins`):

| Comando | Item | Permiso |
|---|---|---|
| `!am [jugador]` aimbot | `aimbot` | `cheats` |
| `!wh [jugador]` wallhack | `wallhack` | `cheats` |
| `!nc [jugador]` noclip, `!god [jugador]` | `noclip-god` | `cheats` |
| `!respawn [jugador]`, `!hp <jugador> <vida>` | `respawn-hp` | `cheats` |
| `!tp <jugador>`, `!bring <jugador>` | `teleport` | `slay` |
| Menú `!bots` | `bots-menu` | `bots` |

Solo funcionan en tu propio servidor, que siempre arranca con `-insecure` (sin VAC). No son para servidores
oficiales o con VAC, ni funcionan en ellos.

## Cómo llega a la app

1. Un pull request añade o cambia `items/<id>/`.
2. La CI lo comprueba con el mismo validador de la app (`csgo-legacy-server hub check`), le pasa el lint y
   compila cada plugin con la versión de SourceMod que instala la app.
3. El mantenedor lo revisa. Solo se publica lo fusionado en `main`.
4. La CI publica `index.json`, un zip por item y las previews en
   [GitHub Pages](https://xsteban1410.github.io/CSGO-Hub/).
5. La app descarga el zip, comprueba su SHA-256 con el índice, vuelve a revisar los archivos y compila los
   plugins en local. Nunca se descarga nada compilado.

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md): el formato de un item, las reglas y cómo probarlo antes del pull
request. Los problemas de seguridad van por [SECURITY.md](SECURITY.md), no en un issue.

Todo es GPL-3.0-or-later salvo que un item diga otra cosa en su `license`.
