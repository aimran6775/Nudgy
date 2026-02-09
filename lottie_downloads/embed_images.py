#!/usr/bin/env python3
"""Embed external images into pudgy and sleeping_penguin Lottie JSONs."""
import zipfile, os, json, base64

base_dir = os.path.dirname(os.path.abspath(__file__))

for name in ['pudgy', 'sleeping_penguin']:
    lottie_path = os.path.join(base_dir, f'{name}.lottie')
    json_path = os.path.join(base_dir, 'extracted', f'{name}.json')

    with open(json_path) as f:
        data = json.load(f)

    with zipfile.ZipFile(lottie_path, 'r') as z:
        image_files = [n for n in z.namelist() if n.startswith('images/')]
        print(f'\n{name}: {len(image_files)} images, {len(data.get("assets",[]))} assets')

        for asset in data.get('assets', []):
            asset_id = asset.get('id', '')
            p = asset.get('p', '')
            u = asset.get('u', '')

            print(f'  Asset {asset_id}: p={p}, u={u}, e={asset.get("e",0)}')

            possible = f'images/{p}'
            if possible in image_files:
                img_data = z.read(possible)
                ext = os.path.splitext(p)[1].lower()
                if ext == '.webp':
                    mime = 'image/webp'
                elif ext == '.png':
                    mime = 'image/png'
                else:
                    mime = 'image/png'

                b64 = base64.b64encode(img_data).decode()
                asset['u'] = ''
                asset['p'] = f'data:{mime};base64,{b64}'
                asset['e'] = 1
                print(f'    Embedded {possible} ({len(img_data)}B)')
            else:
                print(f'    Image not found: {possible}')
                print(f'    Available: {image_files}')

    out_path = os.path.join(base_dir, 'extracted', f'{name}.json')
    with open(out_path, 'w') as f:
        json.dump(data, f, separators=(',', ':'))

    size = os.path.getsize(out_path) // 1024
    print(f'  Saved {out_path} ({size}KB with embedded images)')
