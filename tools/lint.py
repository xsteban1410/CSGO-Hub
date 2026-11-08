#!/usr/bin/env python3
"""Checks that `csgo-legacy-server hub check` does not: requirements, convar resets, phrases, and that a changed
item raises its version and says what changed.
usage: tools/lint.py <CSGO-Server checkout> [git ref to compare with, such as origin/main]"""
import pathlib, re, subprocess, sys, tomllib

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

def version(v):
    """'1.2.10' -> (1, 2, 10), as the app compares them; anything else sorts first."""
    try:
        return tuple(int(x) for x in v.split('.'))
    except (AttributeError, ValueError):
        return ()

def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, text=True)

# the app only updates an item whose version went up: a change without it never reaches anyone
against = sys.argv[2] if len(sys.argv) > 2 else ''
if against and git('rev-parse', '--verify', '--quiet', f'{against}^{{commit}}').returncode != 0:
    print(f'cannot compare with {against}: version checks skipped')
    against = ''
if against:
    changed = sorted({p.split('/')[1] for p in git('diff', '--name-only', against, '--', 'items').stdout.split() if p.count('/') >= 2})
    for id in changed:
        if id not in items:
            continue
        old = git('show', f'{against}:items/{id}/item.toml')
        if old.returncode != 0:
            continue  # a new item
        before = tomllib.loads(old.stdout).get('version', '')
        now = items[id].get('version', '')
        if version(now) <= version(before):
            problems.append(f'{id}: changed, so its version must go above {before} (it is {now})')
        elif not all(items[id].get('changes', {}).get(k) for k in ('en', 'es')):
            problems.append(f'{id}: version {now} needs changes.en and changes.es: what this version changed')

for p in problems:
    print(p)
print(f'{len(items)} items, {len(problems)} problems')
sys.exit(1 if problems else 0)
