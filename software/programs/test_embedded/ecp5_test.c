#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

int main() {
	while (1) {
		PARALLEL_IO_B[0] = 1;
		asm("nop");
		asm("nop");
		asm("nop");
		// delay_ms(1000);
		PARALLEL_IO_B[0] = 0;
		// asm("nop");
		// asm("nop");
		// asm("nop");
		// delay_ms(1000);
		// delay_ms(1000);
	}

	return 0;
}