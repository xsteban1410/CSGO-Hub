#!/usr/bin/env bash
# Compiles every plugin of the hub with the SourceMod build CSGO-Server pins, checked by its SHA-256.
# usage: tools/compile.sh <CSGO-Server checkout> <work dir>
set -euo pipefail
engine=$(realpath "$1")
work=$(realpath -m "$2")
hub=$(realpath "$(dirname "$0")/..")
mkdir -p "$work/out"
read -r base file sha < <(python3 -I -c '
import sys, tomllib
s = tomllib.load(open(sys.argv[1], "rb"))["sourcemod"]
print(s["base"], s["file"], s["sha256"])' "$engine/game/data/pinned.toml")
if [ ! -x "$work/sm/addons/sourcemod/scripting/spcomp" ]; then
    curl -fsSL --retry 5 -o "$work/$file" "$base/$file"
    echo "$sha  $work/$file" | sha256sum -c -
    mkdir -p "$work/sm"
    tar -xzf "$work/$file" -C "$work/sm"
fi
sc="$work/sm/addons/sourcemod/scripting"
failed=0
for src in "$hub"/items/*/plugin/*/*.sp; do
    dir=$(dirname "$src")
    name=$(basename "$src" .sp)
    [ "$(basename "$dir")" = "$name" ] || continue
    if "$sc/spcomp" -i"$sc/include" -i"$engine/game/plugin/include" -i"$dir" "$src" -o"$work/out/$name.smx" > "$work/out/$name.log" 2>&1; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        cat "$work/out/$name.log"
        failed=1
    fi
done
exit $failed
