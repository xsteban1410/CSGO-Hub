#!/usr/bin/env python3
"""Checks that `csgo-legacy-server hub check` does not: requirements, convar resets and phrases.
usage: tools/lint.py <CSGO-Server checkout>"""
import pathlib, re, sys, tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
engine = pathlib.Path(sys.argv[1])
problems = []
items = {d.name: tomllib.loads((d / 'item.toml').read_text()) for d in sorted((ROOT / 'items').iterdir()) if (d / 'item.toml').is_file()}

# convars the engine resets before each mode
base = set(re.findall(r'(?m)^\s*(modo_[a-z0-9_]+)\s', (engine / 'game/cfg/modo_base.cfg').read_text()))
engine_src = '\n'.join(p.read_text() for p in (engine / 'game/plugin').rglob('*.sp'))
engine_cvars = set(re.findall(r'CreateConVar\("([a-z0-9_]+)"', engine_src)) | set(re.findall(r'"modo_%s_([a-z]+)"', engine_src))
engine_cvars |= {f'modo_{t}_{k}' for t in ('t', 'ct') for k in ('quitar', 'arma', 'pistola', 'objeto', 'vida', 'velocidad', 'color')}

def closure(id, seen=None):
    seen = seen if seen is not None else set()
    for r in items.get(id, {}).get('requires', []):
        if r not in seen:
            seen.add(r)
            closure(r, seen)
    return seen

def plugin_sources(id):
    return list((ROOT / 'items' / id / 'plugin').glob('*/*.sp'))

for id, it in items.items():
    for r in it.get('requires', []):
        if r not in items:
            problems.append(f'{id}: requires {r}, which is not in the hub')
    if id in closure(id):
        problems.append(f'{id}: requires itself through {sorted(closure(id))}')
    for k in ('en', 'es'):
        if not it.get('name', {}).get(k) or not it.get('description', {}).get(k):
            problems.append(f'{id}: name.{k} and description.{k} are required')

    # a mode's switches must be undone before the next mode: by modo_base.cfg or by the plugin that owns them
    owned = set()
    for dep in closure(id) | {id}:
        for s in plugin_sources(dep):
            text = s.read_text()
            if 'CSLS_OnModeReset' in text:
                owned |= set(re.findall(r'CreateConVar\("([a-z0-9_]+)"', text))
    for cfg in (ROOT / 'items' / id / 'cfg').glob('modo_*.cfg'):
        for n, line in enumerate(cfg.read_text().splitlines(), 1):
            f = line.split()
            if not f or f[0].startswith('//'):
                continue
            cv = f[0]
            if (cv.startswith('modo_') or cv.startswith('skins_')) and cv not in base and cv not in owned and cv not in engine_cvars:
                problems.append(f'{id}: cfg/{cfg.name}:{n}: {cv} is not reset by the engine or by a required plugin (CSLS_OnModeReset)')

    # every phrase a plugin names exists in its translations, in English and Spanish
    for s in plugin_sources(id):
        tr = s.parent / 'translations'
        text = '\n'.join(p.read_text() for p in tr.glob('*.phrases.txt'))
        # a phrase block closes on a line of its own: "#format" values hold braces too
        blocks = dict(re.findall(r'(?ms)^\s*"([a-z_0-9]+)"\s*\n\s*\{\n(.*?)\n\s*\}\s*$', text))
        for k, body in blocks.items():
            for lang in ('"en"', '"es"'):
                if lang not in body:
                    problems.append(f'{id}: phrase {k} has no {lang} text')
        src = s.read_text()
        used = set(re.findall(r'"%[tT]",\s*(?:[^"]*\?\s*)?"([a-z_0-9]+)"(?:\s*:\s*"([a-z_0-9]+)")?', src))
        for pair in used:
            for k in pair:
                if k and k not in blocks:
                    problems.append(f'{id}: {s.name} uses phrase {k}, missing from its translations')

for p in problems:
    print(p)
print(f'{len(items)} items, {len(problems)} problems')
sys.exit(1 if problems else 0)
