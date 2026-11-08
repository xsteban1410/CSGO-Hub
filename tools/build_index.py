#!/usr/bin/env python3
"""Builds the published hub: index.json, one zip per item and the previews, into a folder for GitHub Pages.
usage: tools/build_index.py <out dir> [base url]
Zips are reproducible (sorted names, fixed dates), so the same item always gives the same SHA-256."""
import hashlib, html, json, pathlib, shutil, sys, tomllib, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FORMAT = 1  # the app's hub::API

def zip_item(src: pathlib.Path, dest: pathlib.Path):
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(p for p in src.rglob('*') if p.is_file()):
            info = zipfile.ZipInfo(f.relative_to(src).as_posix(), date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, f.read_bytes())

def main():
    out = pathlib.Path(sys.argv[1])
    base = (sys.argv[2] if len(sys.argv) > 2 else 'https://xsteban1410.github.io/CSGO-Hub').rstrip('/')
    shutil.rmtree(out, ignore_errors=True)
    (out / 'items').mkdir(parents=True)
    (out / 'previews').mkdir()
    entries = []
    for d in sorted(p for p in (ROOT / 'items').iterdir() if (p / 'item.toml').is_file()):
        it = tomllib.loads((d / 'item.toml').read_text())
        stem = f"{it['id']}-{it['version']}"
        z = out / 'items' / f'{stem}.zip'
        zip_item(d, z)
        e = dict(it)
        e['archive'] = f'{base}/items/{stem}.zip'
        e['sha256'] = hashlib.sha256(z.read_bytes()).hexdigest()
        e['size'] = z.stat().st_size
        e['has_code'] = (d / 'plugin').is_dir()
        e['preview_url'] = ''
        if it.get('preview'):
            ext = pathlib.Path(it['preview']).suffix
            shutil.copy(d / it['preview'], out / 'previews' / f'{stem}{ext}')
            e['preview_url'] = f'{base}/previews/{stem}{ext}'
        entries.append(e)
    (out / 'index.json').write_text(json.dumps({'format': FORMAT, 'items': entries}, ensure_ascii=False, indent=1))
    esc = lambda v: html.escape(str(v))
    rows = ''.join(f"<li><b>{esc(e['name']['en'])}</b> <code>{esc(e['id'])}</code> {esc(e['kind'])} {esc(e['version'])}</li>" for e in entries)
    (out / 'index.html').write_text(
        '<!doctype html><meta charset="utf-8"><title>CSGO-Hub</title>'
        '<h1>CSGO-Hub</h1><p>Install these from the CS:GO Legacy Server app (Hub tab) or with '
        '<code>csgo-legacy-server hub install &lt;id&gt;</code>. Source: '
        '<a href="https://github.com/xsteban1410/CSGO-Hub">github.com/xsteban1410/CSGO-Hub</a>.</p>'
        f'<ul>{rows}</ul>')
    print(f'{len(entries)} items -> {out}')

main()
