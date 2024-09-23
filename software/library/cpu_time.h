#include <stdint.h>

#define F_CPU 12000000

inline static void delay_ms(uint32_t ms) {
    // 2 instructions per loop cycle, roughly 4 cycles per instruction
    // Correction factor (200/224) found empirically courtesy of 'scope
    register uint32_t cyc_delay = (ms * F_CPU) / ((1000 * 2 * 4 * 224) / 200);
    while (cyc_delay > 0) --cyc_delay;
}
