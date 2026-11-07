#!/usr/bin/env python3
"""Shrinks the AI-generated art (Figma AI, original fictional characters and
scenes) from tools/.cache/art_raw into app-sized WebP files:
  assets/portraits/<group>_<f|m>.webp   320 x 320
  assets/scenes/<name>.webp             768 x 432
Raw files stay out of the app (tools/ is excluded from exports)."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RAW = os.path.join(HERE, ".cache", "art_raw")

for kind, size in (("portraits", (320, 320)), ("scenes", (768, 432))):
    out_dir = os.path.join(ROOT, "assets", kind)
    os.makedirs(out_dir, exist_ok=True)
    for f in sorted(os.listdir(os.path.join(RAW, kind))):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(RAW, kind, f)).convert("RGB")
        w, h = im.size
        tw, th = size
        # Cover-crop to the target aspect, then resize.
        scale = max(tw / w, th / h)
        im = im.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        l = (im.width - tw) // 2
        t = (im.height - th) // 2
        im = im.crop((l, t, l + tw, t + th))
        dst = os.path.join(out_dir, f.replace(".png", ".webp"))
        im.save(dst, "WEBP", quality=82, method=6)
        print(dst, os.path.getsize(dst) // 1024, "KB")
