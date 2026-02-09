#!/usr/bin/env python3
"""Extract Lottie JSON from .lottie (ZIP) files."""
import zipfile, os, json, shutil

download_dir = os.path.dirname(os.path.abspath(__file__))
output_dir = os.path.join(download_dir, "extracted")
os.makedirs(output_dir, exist_ok=True)

for f in sorted(os.listdir(download_dir)):
    if not f.endswith(".lottie"):
        continue
    name = f.replace(".lottie", "")
    path = os.path.join(download_dir, f)

    try:
        with zipfile.ZipFile(path, "r") as z:
            contents = z.namelist()
            json_files = [n for n in contents if n.endswith(".json") and "manifest" not in n.lower()]
            manifest_files = [n for n in contents if "manifest" in n.lower()]

            print(f"\n📦 {f} ({os.path.getsize(path)//1024}KB)")
            print(f"   Contents: {contents}")

            if json_files:
                json_name = json_files[0]
                z.extract(json_name, output_dir)
                extracted_path = os.path.join(output_dir, json_name)
                final_path = os.path.join(output_dir, f"{name}.json")
                # handle subdirectories
                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                shutil.move(extracted_path, final_path)

                with open(final_path) as jf:
                    data = json.load(jf)
                w = data.get("w", "?")
                h = data.get("h", "?")
                fr = data.get("fr", "?")
                op = data.get("op", "?")
                layers = len(data.get("layers", []))
                assets = len(data.get("assets", []))
                size_kb = os.path.getsize(final_path) // 1024
                duration = round(op / fr, 1) if isinstance(fr, (int, float)) and fr > 0 else "?"
                print(f"   ✅ {name}.json ({size_kb}KB) {w}x{h} {fr}fps {op}frames {layers}layers {assets}assets {duration}s")
            elif manifest_files:
                with z.open(manifest_files[0]) as mf:
                    manifest = json.load(mf)
                # Try to find animation in manifest
                anims = manifest.get("animations", [])
                if anims:
                    anim_id = anims[0].get("id", "")
                    # Look for the animation data file
                    for entry in contents:
                        if anim_id in entry and entry.endswith(".json"):
                            z.extract(entry, output_dir)
                            extracted_path = os.path.join(output_dir, entry)
                            final_path = os.path.join(output_dir, f"{name}.json")
                            shutil.move(extracted_path, final_path)
                            with open(final_path) as jf:
                                data = json.load(jf)
                            w = data.get("w", "?")
                            h = data.get("h", "?")
                            fr = data.get("fr", "?")
                            op = data.get("op", "?")
                            layers = len(data.get("layers", []))
                            size_kb = os.path.getsize(final_path) // 1024
                            duration = round(op / fr, 1) if isinstance(fr, (int, float)) and fr > 0 else "?"
                            print(f"   ✅ {name}.json ({size_kb}KB) {w}x{h} {fr}fps {op}frames {layers}layers {duration}s")
                            break
                    else:
                        print(f"   ⚠️  Manifest found but no matching animation file")
                        print(f"   Manifest: {json.dumps(manifest, indent=2)[:500]}")
                else:
                    print(f"   ⚠️  No animations in manifest")
            else:
                print(f"   ❌ No JSON files found in archive")
    except zipfile.BadZipFile:
        try:
            with open(path) as jf:
                data = json.load(jf)
            final_path = os.path.join(output_dir, f"{name}.json")
            shutil.copy(path, final_path)
            print(f"\n📄 {f} is raw JSON → {name}.json")
        except Exception:
            print(f"\n❌ {f} — not a valid ZIP or JSON")

# Clean up empty dirs
for d in os.listdir(output_dir):
    dp = os.path.join(output_dir, d)
    if os.path.isdir(dp):
        try:
            os.rmdir(dp)
        except OSError:
            pass

print(f"\n\n📁 Extracted files in {output_dir}:")
for f in sorted(os.listdir(output_dir)):
    if f.endswith(".json"):
        size = os.path.getsize(os.path.join(output_dir, f)) // 1024
        print(f"   {f} ({size}KB)")
