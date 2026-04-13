from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FONT_PATH = ROOT / "assets" / "fonts" / "Px437_IBM_BIOS.ttf"
OUT_PATH = ROOT / "assets" / "fonts" / "Px437_IBM_BIOS_cp437_8x8_atlas.png"

CELL_W = 8
CELL_H = 8
COLS = 16
ROWS = 16

# CP437's first 32 codepoints and DEL are graphical in DOS text mode but not in
# Python's cp437 codec, so we map them explicitly.
SPECIAL_CP437 = {
    0: " ",
    1: "☺",
    2: "☻",
    3: "♥",
    4: "♦",
    5: "♣",
    6: "♠",
    7: "•",
    8: "◘",
    9: "○",
    10: "◙",
    11: "♂",
    12: "♀",
    13: "♪",
    14: "♫",
    15: "☼",
    16: "►",
    17: "◄",
    18: "↕",
    19: "‼",
    20: "¶",
    21: "§",
    22: "▬",
    23: "↨",
    24: "↑",
    25: "↓",
    26: "→",
    27: "←",
    28: "∟",
    29: "↔",
    30: "▲",
    31: "▼",
    127: "⌂",
}


def cp437_char(code: int) -> str:
    if code in SPECIAL_CP437:
        return SPECIAL_CP437[code]
    return bytes([code]).decode("cp437")


def main() -> None:
    atlas = Image.new("RGBA", (COLS * CELL_W, ROWS * CELL_H), (0, 0, 0, 0))
    font = ImageFont.truetype(str(FONT_PATH), size=8)

    for code in range(256):
        ch = cp437_char(code)
        if not ch or ch in {"\x00", "\r", "\n", "\t"}:
            continue

        cell = Image.new("L", (CELL_W, CELL_H), 0)
        draw = ImageDraw.Draw(cell)
        bbox = draw.textbbox((0, 0), ch, font=font)
        if bbox is None:
            continue

        glyph_w = bbox[2] - bbox[0]
        glyph_h = bbox[3] - bbox[1]
        draw_x = ((CELL_W - glyph_w) // 2) - bbox[0]
        draw_y = ((CELL_H - glyph_h) // 2) - bbox[1]
        draw.text((draw_x, draw_y), ch, fill=255, font=font)

        rgba_cell = Image.new("RGBA", (CELL_W, CELL_H), (255, 255, 255, 0))
        px = cell.load()
        out = rgba_cell.load()
        for y in range(CELL_H):
            for x in range(CELL_W):
                alpha = 255 if px[x, y] >= 24 else 0
                out[x, y] = (255, 255, 255, alpha)

        col = code % COLS
        row = code // COLS
        atlas.paste(rgba_cell, (col * CELL_W, row * CELL_H))

    atlas.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
