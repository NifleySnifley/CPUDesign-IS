#include <check.h>
#include "rv32i_simulator.h"
#include <stdio.h>

void sim_run(rv_simulator_t* sim) {
    sim->x[1] = (uint32_t)-1; // Set RA
    sim->x[2] = 0x1800; // Set PC
    sim->pc = 0;

    while (sim->pc != (uint32_t)-1) {
        rv_simulator_step(sim);
    }
}

rv_simulator_t make_simulator(const char* code_filename) {
    rv_simulator_t sim;

    rv_simulator_init(&sim);
    rv_simulator_init_monolithic_memory(&sim, 0x2000);
    rv_simulator_load_memory_from_file(&sim, code_filename, FILETYPE_AUTO, 0);

    return sim;
}

bool test_rv_test(char* testname) {
    char code_filename[64] = { 0 };
    strncpy(code_filename, "./build/", sizeof(code_filename));
    int strrem = sizeof(code_filename) - strlen(code_filename) - 1;
    strncat(code_filename, testname, strrem);
    strrem -= strlen(testname);
    strncat(code_filename, ".bin", strrem);

    rv_simulator_t sim;
    rv_simulator_init(&sim);
    rv_simulator_init_monolithic_memory(&sim, 0x2000);
    rv_simulator_load_memory_from_file(&sim, code_filename, FILETYPE_AUTO, 0);
    sim.x[1] = (uint32_t)-1;
    sim.x[2] = 0x1800;

    int ret;
    while ((ret = rv_simulator_step(&sim)) == 0) {}

    // Breakpoint, not error, a0 stores success/fail
    return ret == -1 && sim.a0 == 1;
}

#define INSTR_TEST(name) START_TEST(test_ ## name) \
{\
ck_assert(test_rv_test(#name));\
} END_TEST \

INSTR_TEST(addi);
INSTR_TEST(add);
INSTR_TEST(andi);
INSTR_TEST(and);
INSTR_TEST(auipc);
INSTR_TEST(beq);
INSTR_TEST(bge);
INSTR_TEST(bgeu);
INSTR_TEST(blt);
INSTR_TEST(bltu);
INSTR_TEST(bne);
INSTR_TEST(jalr);
INSTR_TEST(jal);
INSTR_TEST(j);
INSTR_TEST(lb);
INSTR_TEST(lbu);
INSTR_TEST(lh);
INSTR_TEST(lhu);
INSTR_TEST(lui);
INSTR_TEST(lw);
INSTR_TEST(ori);
INSTR_TEST(or );
INSTR_TEST(sb);
INSTR_TEST(sh);
INSTR_TEST(simple);
INSTR_TEST(slli);
INSTR_TEST(sll);
INSTR_TEST(slti);
INSTR_TEST(slt);
INSTR_TEST(srai);
INSTR_TEST(sra);
INSTR_TEST(srli);
INSTR_TEST(srl);
INSTR_TEST(sub);
INSTR_TEST(sw);
INSTR_TEST(xori);
INSTR_TEST(xor);
INSTR_TEST(mul);
INSTR_TEST(mulh);
INSTR_TEST(mulhu);
INSTR_TEST(mulhsu);
INSTR_TEST(rem);
INSTR_TEST(remu);
INSTR_TEST(div);
INSTR_TEST(divu);

Suite* test_suite(void) {
    Suite* s;
    TCase* tc_core;

    s = suite_create("Simulator");

    TCase* tc_instr = tcase_create("Instructions");
    tcase_add_test(tc_instr, test_add);

    tcase_add_test(tc_instr, test_addi);
    tcase_add_test(tc_instr, test_add);
    tcase_add_test(tc_instr, test_andi);
    tcase_add_test(tc_instr, test_and);
    tcase_add_test(tc_instr, test_auipc);
    tcase_add_test(tc_instr, test_beq);
    tcase_add_test(tc_instr, test_bge);
    tcase_add_test(tc_instr, test_bgeu);
    tcase_add_test(tc_instr, test_blt);
    tcase_add_test(tc_instr, test_bltu);
    tcase_add_test(tc_instr, test_bne);
    tcase_add_test(tc_instr, test_jalr);
    tcase_add_test(tc_instr, test_jal);
    tcase_add_test(tc_instr, test_j);
    tcase_add_test(tc_instr, test_lb);
    tcase_add_test(tc_instr, test_lbu);
    tcase_add_test(tc_instr, test_lh);
    tcase_add_test(tc_instr, test_lhu);
    tcase_add_test(tc_instr, test_lui);
    tcase_add_test(tc_instr, test_lw);
    tcase_add_test(tc_instr, test_ori);
    tcase_add_test(tc_instr, test_or);
    tcase_add_test(tc_instr, test_sb);
    tcase_add_test(tc_instr, test_sh);
    tcase_add_test(tc_instr, test_simple);
    tcase_add_test(tc_instr, test_slli);
    tcase_add_test(tc_instr, test_sll);
    tcase_add_test(tc_instr, test_slti);
    tcase_add_test(tc_instr, test_slt);
    tcase_add_test(tc_instr, test_srai);
    tcase_add_test(tc_instr, test_sra);
    tcase_add_test(tc_instr, test_srli);
    tcase_add_test(tc_instr, test_srl);
    tcase_add_test(tc_instr, test_sub);
    tcase_add_test(tc_instr, test_sw);
    tcase_add_test(tc_instr, test_xori);
    tcase_add_test(tc_instr, test_xor);
    tcase_add_test(tc_instr, test_mul);
    tcase_add_test(tc_instr, test_mulh);
    tcase_add_test(tc_instr, test_mulhu);
    tcase_add_test(tc_instr, test_mulhsu);
    tcase_add_test(tc_instr, test_rem);
    tcase_add_test(tc_instr, test_remu);
    tcase_add_test(tc_instr, test_div);
    tcase_add_test(tc_instr, test_divu);

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