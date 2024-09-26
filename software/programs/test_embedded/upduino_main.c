#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

int main() {
	uint8_t* buffer = malloc(8);

	for (int j = 0; j < 8; j++)
		buffer[j] = 1 << j;

	PARALLEL_IO_B[0] = 0x00;
	PARALLEL_IO_B[1] = 0b1111;

	// puts("Hello World!");

	print("Hello World\n");
	print("TEST :)\n");

	int i = 0;
	while (1) {
		i = (i == 7) ? 0 : (i + 1);
		PARALLEL_IO_B[0] = buffer[i];
		delay_ms(100);

		// Super turbo-inefficient delay for simulator
		// uint32_t c = 0xFFFFF;
		// while (c--) { __asm__("nop"); }
	}

	return 0;
}