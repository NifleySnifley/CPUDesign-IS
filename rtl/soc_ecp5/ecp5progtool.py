#!/usr/bin/env python3

from pathlib import Path
import subprocess
import os
import sys
import tempfile as tf
import shutil
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=str)
    # TODO: Implement
    parser.add_argument("-f", "--flash", action="store_true")
    args = parser.parse_args()
        
    progfile = Path(args.input).absolute()
    
    scriptdir = Path(__file__).resolve().parent.absolute()
    builddir = scriptdir/"build"
    bitstream_in = builddir/"soc_ecp5.config"
    
    tmpdir = Path(tf.mkdtemp("ecp5progtool"))
    
    def exit_fail():
        shutil.rmtree(tmpdir)
        exit(1)
        
    os.chdir(scriptdir)
    if not (builddir.is_dir() and bitstream_in.is_file()):
        print("Error, please build the base bitstream first by running `make`")
        exit_fail()
        
    if not (progfile.is_file() and progfile.suffix == ".hex"):
        print("Error, invalid program file, please specify a proper `.hex` file to be programmed")
        exit_fail()
    
    if (subprocess.call(["ecpbram", "-f", builddir / "phony.hex", "-t", progfile, "-i", bitstream_in, "-o", tmpdir / "loaded.config"]) != 0):
        print("Error replacing BRAM contents.")
        exit_fail()
        
    if (subprocess.call(["ecppack", "--compress", "--input", tmpdir / "loaded.config", "--bit", tmpdir / "loaded.bit"]) != 0):
        print("Error packing bitstream.")
        exit_fail()
        
    if (subprocess.call(["ecpprog", "-S", tmpdir / "loaded.bit"]) != 0):
        print("Error programming.")
        exit_fail()
        
    shutil.rmtree(tmpdir)
    
    # ecpbram -f ./build/phony.hex -t $2 -i $1 -o ./build/loaded.config
    # ecppack --compress --input ./build/loaded.config --bit ./build/loaded.bit
    # echo "Loaded Firmware $2 into bitstream $1"
    # ecpprog -S ./build/loaded.bit