#!/usr/bin/env python3

# Designed to interface with an arduino running the (super convenient) spi-flash-programmer sketch
# Which can be found at https://github.com/nfd/spi-flash-programmer/tree/master

import time
import serial
import argparse
from tqdm import tqdm
from pathlib import Path
import binascii
import subprocess
from create_flash_image import load_file

COMMAND_HELLO = ">"
COMMAND_HELP = "?"
COMMAND_BUFFER_CRC = "h"
COMMAND_BUFFER_LOAD = "l"
COMMAND_BUFFER_STORE = "s"
COMMAND_FLASH_READ = "r"
COMMAND_FLASH_WRITE = "w"
COMMAND_FLASH_ERASE_SECTOR = "k"
COMMAND_FLASH_ERASE_ALL = "n"
COMMAND_WRITE_PROTECTION_ENABLE = "p"
COMMAND_WRITE_PROTECTION_DISABLE = "u"
COMMAND_WRITE_PROTECTION_CHECK = "x"
COMMAND_STATUS_REGISTER_READ = "y"
COMMAND_ID_REGISTER_READ = "i"
COMMAND_ERROR = "!"
COMMAND_SET_CS = "*"
COMMAND_SET_OUTPUT = "o"

CHIP_N_SECTORS = 512
CHIP_SECTOR_SIZE = 4096
CHIP_PAGE_SIZE = 256

PORT = None


def transact(cmd: str, argument: bytes, wait=None, waitct=1, timeout=0.1):
    global PORT
    if wait is None:
        wait = cmd
    PORT.read_all()
    PORT.write(cmd.encode("ascii"))
    PORT.write(argument)
    PORT.flush()
    time.sleep(0.01)

    response = bytearray()

    while waitct:
        content = PORT.readall()
        if content is not None and len(content):
            # print(content)
            for ch in content:
                # print(ch)
                if chr(ch) == wait:
                    waitct -= 1
                    if waitct == 0:
                        return response
                else:
                    response.append(ch)

    return response


def cmd_version(args):
    print(transact(COMMAND_HELLO, bytes(), waitct=2).decode("ascii"), end="")


def cmd_id(args):
    print(
        f"Chip ID: {transact(COMMAND_ID_REGISTER_READ, bytes(), waitct=1).decode('ascii')}"
    )


def cmd_status(args):
    print(
        f"Chip Status: {transact(COMMAND_STATUS_REGISTER_READ, bytes(), waitct=1).decode('ascii')}"
    )


def cmd_erase(args):
    start = args.start
    end = args.end
    for s in tqdm(range(start, end + 1)):
        arg = hex(s)[2:].rjust(8, "0")
        transact(COMMAND_FLASH_ERASE_SECTOR, arg.encode("ascii"))


def cmd_program(args):
    data = load_file(args.input)
    disparity = len(data) % CHIP_PAGE_SIZE
    data += bytes([0xFF for i in range(CHIP_PAGE_SIZE - disparity)])

    # print(data)
    transact(COMMAND_WRITE_PROTECTION_DISABLE, bytes())
    offset = args.offset_page
    n_pages = len(data) // CHIP_PAGE_SIZE

    n_sectors = len(data) // CHIP_SECTOR_SIZE
    base_sector = (offset * CHIP_PAGE_SIZE) // CHIP_SECTOR_SIZE

    if args.erase:
        print(f"Erasing sectors {base_sector} to {base_sector+n_sectors}")
        for s in tqdm(range(base_sector, base_sector + n_sectors + 1)):
            arg = hex(s)[2:].rjust(8, "0")
            transact(COMMAND_FLASH_ERASE_SECTOR, arg.encode("ascii"))

    print(f"Programming pages {offset} to {offset+n_pages-1}")
    for p in tqdm(range(0, n_pages)):
        buf = data[p * CHIP_PAGE_SIZE : (p + 1) * CHIP_PAGE_SIZE].hex()
        transact(
            COMMAND_BUFFER_STORE,
            buf.encode("ascii"),
        )
        transact(COMMAND_FLASH_WRITE, hex(p + offset)[2:].rjust(8, "0").encode("ascii"))


def cmd_read(args):
    start = args.start
    end = args.end
    data = bytes()
    for p in tqdm(range(start, end + 1)):
        transact(COMMAND_FLASH_READ, hex(p)[2:].rjust(8, "0").encode("ascii"))
        res = transact(COMMAND_BUFFER_LOAD, bytes())
        data += bytes.fromhex(res.decode("ascii"))

    if args.output is None:
        # Do a nice dump with XXD
        with subprocess.Popen(["xxd"], stdin=subprocess.PIPE) as proc:
            proc.stdin.write(data)
            proc.stdin.close()
    else:
        with open(args.output, "wb") as f:
            f.write(data)
            f.flush()


def cmd_verify(args):
    data = load_file(args.input)
    disparity = len(data) % CHIP_PAGE_SIZE
    data += bytes([0xFF for i in range(CHIP_PAGE_SIZE - disparity)])
    npages = len(data) // CHIP_PAGE_SIZE

    data_flash = bytes()
    for p in tqdm(range(args.offset_page, args.offset_page + npages)):
        transact(COMMAND_FLASH_READ, hex(p)[2:].rjust(8, "0").encode("ascii"))
        res = transact(COMMAND_BUFFER_LOAD, bytes())
        data_flash += bytes.fromhex(res.decode("ascii"))

    if data == data_flash:
        print("successfully verified")
    else:
        print("error! data mismatch")


if __name__ == "__main__":
    parser = argparse.ArgumentParser("flash_programmer")
    parser.add_argument("-p", "--port", default="/dev/ttyACM0")
    parser.add_argument("-b", "--baud", type=int, default=115200)
    subparsers = parser.add_subparsers(required=True)

    parser_version = subparsers.add_parser("version")
    parser_version.set_defaults(func=cmd_version)

    parser_erase = subparsers.add_parser("erase")
    parser_erase.add_argument("-s", "--start", type=int, default=0)
    parser_erase.add_argument("-e", "--end", type=int, default=(CHIP_N_SECTORS - 1))
    parser_erase.set_defaults(func=cmd_erase)

    parser_read = subparsers.add_parser("read")
    parser_read.add_argument("-s", "--start", type=int, default=0)
    parser_read.add_argument("-e", "--end", type=int, default=0)
    parser_read.add_argument("-o", "--output", type=str, required=False)
    parser_read.set_defaults(func=cmd_read)

    parser_verify = subparsers.add_parser("verify")
    parser_verify.add_argument("-o", "--offset-page", type=int, default=0)
    parser_verify.add_argument("input", type=str)
    parser_verify.set_defaults(func=cmd_verify)

    parser_program = subparsers.add_parser("program")
    parser_program.add_argument("-o", "--offset-page", type=int, default=0)
    parser_program.add_argument("-e", "--erase", action="store_true")
    parser_program.add_argument("input", type=str)
    parser_program.set_defaults(func=cmd_program)

    subparsers.add_parser("id").set_defaults(func=cmd_id)
    subparsers.add_parser("status").set_defaults(func=cmd_status)

    args = parser.parse_args()
    PORT = serial.Serial(args.port, args.baud, timeout=0)
    if PORT is None:
        print(f"Error opening port {args.port}")
    PORT.flush()

    args.func(args)

    PORT.close()
