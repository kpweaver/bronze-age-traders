from __future__ import annotations

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "tilesets" / "CGA8x8thick_mask.png"
OUT = ROOT / "assets" / "tilesets" / "CGA8x8thick_mask_centered.png"
CELL = 8
COLS = 16

# CP437 / ASCII glyph slots we want to normalize more carefully.
TARGETS = {
    46,   # .
    7,    # bullet, used in previews
}


def recenter_cell(cell: Image.Image) -> Image.Image:
    bbox = cell.getbbox()
    if bbox is None:
        return cell.copy()
    glyph_w = bbox[2] - bbox[0]
    glyph_h = bbox[3] - bbox[1]
    glyph = cell.crop(bbox)
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    dx = (CELL - glyph_w) // 2
    dy = (CELL - glyph_h) // 2
    out.paste(glyph, (dx, dy), glyph)
    return out


def main() -> None:
    atlas = Image.open(SRC).convert("RGBA")
    out = atlas.copy()
    for idx in TARGETS:
        col = idx % COLS
        row = idx // COLS
        x0 = col * CELL
        y0 = row * CELL
        cell = atlas.crop((x0, y0, x0 + CELL, y0 + CELL))
        centered = recenter_cell(cell)
        out.paste(Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0)), (x0, y0))
        out.paste(centered, (x0, y0), centered)
    out.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
