#! /usr/bin/env python
import argparse
from pathlib import Path


def load_file(name):
    ftype = Path(name).suffix
    input_data = bytes()
    if ftype == ".bin":
        with open(name, "rb") as f:
            input_data = f.read()
    elif ftype == ".hex":
        with open(name, "r") as f:
            words = [
                int(line.strip(), 16).to_bytes(4, "little") for line in f.readlines()
            ]
            for w in words:
                input_data += w
    elif ftype == ".txt":
        with open(name, "r") as f:
            words = [
                int(line.strip(), 2).to_bytes(4, "little") for line in f.readlines()
            ]
            for w in words:
                input_data += w
    return input_data


if __name__ == "__main__":
    SECTOR_SIZE = 256

    parser = argparse.ArgumentParser(
        "create_flash_image.py", "input_file [-f bin hex raw] output_file"
    )
    parser.add_argument("input", type=str)
    parser.add_argument("-f", "--format", choices=["hex", "bin", "raw"], default="raw")
    parser.add_argument("output", type=str)

    args = parser.parse_args()

    input_data = load_file(args.input)

    n_sectors = len(input_data) // SECTOR_SIZE + 1
    n_bytes = len(input_data)
    output_data = (
        n_sectors.to_bytes(4, "little")
        + n_bytes.to_bytes(4, "little")
        + bytes([0xFF for b in range(SECTOR_SIZE - 8)])
        + input_data
    )
    # disparity = len(output_data) % SECTOR_SIZE
    # output_data += bytes([0xFF for i in range(SECTOR_SIZE - disparity)])

    with open(args.output, "wb") as fo:
        print(f"writing {n_sectors+1} sectors to {args.output}")

        fo.write(output_data)
        fo.flush()
