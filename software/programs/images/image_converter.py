#! /usr/bin/env python3
from pathlib import Path
from PIL.Image import Resampling
import PIL
import argparse
import os, sys

import PIL.Image

DEFAULT_WIDTH=(640//8)
DEFAULT_HEIGHT=(480//8)

def image_to_c(image_path: Path, c_name=None, width=DEFAULT_WIDTH, height=DEFAULT_HEIGHT) -> str:
    img = PIL.Image.open(image_path)
    img = img.resize((width, height), resample=Resampling.BICUBIC).convert("RGB")
    
    if (c_name is None):
        c_name = image_path.stem
    
    arr = []
    for y in range(0, img.height):
        for x in range(0, img.width):
            idx = y * img.width + x
            r, g, b = img.getpixel((x,y))
            arr.append(
                round(r/(255/3)) | 
                (round(g/(255/3)) << 2) |
                (round(b/(255/3)) << 4)
            ) 
    datastr = "{" + ', '.join([str(i) for i in arr]) + "}"
    return f"""#include <stdint.h>
uint8_t {c_name}_data[{len(arr)}] = {datastr};
#define {c_name}_width {width}
#define {c_name}_height {height}"""

if __name__ == "__main__":
    scriptdir = Path(__file__).resolve().parent
    builddir = scriptdir / "build"
    if not builddir.is_dir():
        os.mkdir(builddir)
        
    if len(sys.argv) < 2:
        print("Error, must specify input files!")
        exit(1)
        
    infiles = [Path(f) for f in sys.argv[1:]]

    for f in infiles:
        name = f.stem
        outfile = builddir / f"{name}.h"
        fdata = image_to_c(f)
        with open(outfile, 'w') as fd:
            fd.write(fdata);
        