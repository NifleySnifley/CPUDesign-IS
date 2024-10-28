#ifndef SOC_CORE_H
#define SOC_CORE_H

#include <stdint.h>

#ifndef F_CPU
#define F_CPU 12000000
#endif

#ifndef CPU_PIPELINED
// 2 instructions per loop cycle, roughly 4.5 cycles per instruction (9/2)
#define CYC_PER_MS (F_CPU / ((1000 * 2 * 9) / 2))
#else
// About 5 cycles per loop (rough estimate)
// F_CPU/5 loops per second
// TODO: Verify with 'scope
#define CYC_PER_MS (F_CPU / (5 * 1000))
#endif

#define SPRAM_BASE ((uint32_t*)0xf0000000)
#define SPRAM_SIZE_B 131072

void delay_ms(uint32_t ms);

#endif