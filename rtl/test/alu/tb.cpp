#include <check.h>
#include <verilated.h>
#include <stdint.h>
#include "obj_dir/Valu.h"
#include "check.h"

int N_FUZZES = 100000;

void clock(Valu* dut) {
	dut->clk = 0;
	dut->eval();
	dut->clk = 1;
	dut->eval();
}

void reset(Valu* dut) {
	dut->ready = 0;
	dut->rst = 0;
	clock(dut);
	dut->rst = 1;
	clock(dut);
	clock(dut);
	dut->rst = 0;
}

uint32_t exec_instr(Valu* dut, uint32_t a, uint32_t b, uint32_t funct3, uint32_t funct7) {
	dut->in1 = a;
	dut->in2 = b;
	dut->funct3 = funct3 & 0b111;
	dut->funct7 = funct7 & 0b1111111;
	dut->is_imm = 0;
	dut->ready = 1;
	dut->eval();
	while (!dut->ready) {
		clock(dut);
	}
	return dut->out;
}

START_TEST(test_add) {
	Valu* dut = new Valu;
	reset(dut);

	for (int n = 0; n < N_FUZZES; ++n) {

	}

	delete dut;
	// ck_assert(false);
} END_TEST;

Suite* test_suite(void) {
	Suite* s;
	TCase* tc_core;

	s = suite_create("ALU");

	TCase* tc_instr = tcase_create("Basic Operands");
	tcase_add_test(tc_instr, test_add);

	suite_add_tcase(s, tc_instr);

	return s;
}

int main(void) {
	int number_failed;
	Suite* s;
	SRunner* sr;

	s = test_suite();
	sr = srunner_create(s);

	srunner_run_all(sr, CK_NORMAL);
	number_failed = srunner_ntests_failed(sr);
	srunner_free(sr);
	return (number_failed == 0) ? 0 : 1;
}