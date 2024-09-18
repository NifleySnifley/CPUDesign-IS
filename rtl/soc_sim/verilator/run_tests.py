#!/usr/bin/env python3

import os
from pathlib import Path
import subprocess
import pathlib
import tempfile
import re

script_dir = Path(__file__).resolve().parent
debugdir = script_dir/"debug"
if (not debugdir.is_dir()): os.mkdir(debugdir)
cosimulator_file = script_dir / "obj_dir/Vsoc_sim"

def dissasemble(data: bytes) -> str:
	binfile =tempfile.mktemp(".bin")

	with open(binfile, "wb") as bf:
		bf.write(data)
		bf.flush()

	dis = subprocess.check_output(["riscv32-unknown-elf-objdump", "-m","riscv","-b","binary","-Mno-aliases", "-D","--no-addresses", "--no-show-raw-insn", binfile])

	os.remove(binfile)
	strout = dis.decode('ascii').split("<.data>:\n")[1]

	return [line.strip().replace("\t", " ") for line in strout.splitlines()]

def annotate(stdout: str, program: bytes) -> str:
	def dis_insn(addr):
		return dissasemble(bytes([program[addr+i] for i in range(4)]))[0]
	def repfn(m: re.Match[str]) -> str:
		return f"(pc={m.group(1)}, sim_pc={m.group(2)}) >>> \x1b[3mdut:{dis_insn(int(m.group(1)))}, sim:{dis_insn(int(m.group(2)))}\x1b[0m"
	return re.sub(r"\(pc=([0-9a-f]+), sim_pc=([0-9a-f]+)\)", repfn, stdout)

print("Assembling test programs... ", end='', flush=True)
tests_dir = script_dir/"../../../software/simulator/test"
err = subprocess.call(["python3", "assembletests.py"], cwd=tests_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if (err):
    print("Error assembling tests")
    exit(1)
print("done!")

tests_binary_dir = tests_dir/"build"

successes = []
fails = []
fail_insns = []

W = 10
tests = tests_binary_dir.glob("*.bin")
for test in tests:
	testname = test.stem

	stdoutfile = tempfile.mktemp("out")
	debugfile = debugdir/f"{testname}.vcd"

	testdata = bytes()
	with open(test, 'rb') as f:
		testdata = f.read()

	result = 0
	with open(stdoutfile, 'w') as f:
		result = subprocess.call([cosimulator_file, "-e", '-v',"-q", "-be", "-t", debugfile, test], stdout=f, stderr=subprocess.DEVNULL)
	
	stdout = ""
	with open(stdoutfile, 'r') as f:
		stdout = f.read()

	success = result == 0
	print(f"{testname} ".ljust(W, '-') + '', '\x1b[32mPASS\x1b[0m' if success else '\x1b[31mFAIL\x1b[0m')
	if (not success):
		stdout = annotate(stdout,testdata)
		print(stdout, end='', flush=True)
		bad_insn = re.findall(r"Instruction failed \(pc=([0-9a-f]+)\): ([0-9a-f]+)", stdout)[0]
		dissasembly = dissasemble(bytes.fromhex(bad_insn[1].rjust(8,'0'))[::-1])[0]
		insn = dissasembly.split()[0]
		fail_insns.append(insn)
		print(f">>> Failed instruction dissassembly: {dissasembly}")
		print(f">>> Dumped VCD trace to {debugfile}")
		print()
		fails.append(testname)
	else:
		successes.append(testname)

	os.remove(stdoutfile)

print()
ntests =len(successes) + len(fails)
print(f"Ran {ntests} tests, {ntests-len(successes)} failed ({100*len(successes)/ntests:.2f}% passed)")
print(f"Tests passed: {', '.join(successes)}")
print(f"Tests failed: {', '.join(fails)}")
print()
print(f"Specific instructions failed: {', '.join(set(fail_insns))}")