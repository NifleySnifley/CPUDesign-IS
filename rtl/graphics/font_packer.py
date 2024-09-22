from bdfparser import Font
from PIL import Image
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("input")
parser.add_argument("output")
parser.add_argument("-f", "--format", choices=["bin", "hex", "raw"], default="bin")
args = parser.parse_args()

font = Font(args.input)
print(
    f"This font's global size is "
    f"{font.headers['fbbx']} x {font.headers['fbby']} (pixel), "
    f"it contains {len(font)} glyphs."
)
HEIGHT = font.headers["fbby"]


outlines = []

for ci in range(256):
    g = font.glyph(chr(ci))
    if g is not None:
        rows = g.draw().todata(5)  # Get data as integers
        outlines += rows
    else:
        for h in range(HEIGHT):
            outlines.append(0)

if args.format == "bin":
    with open(args.output, "w") as f:
        f.writelines([bin(r)[2:].rjust(8, "0") + "\n" for r in outlines])
