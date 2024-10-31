#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

uint8_t* HUB75_COLOR_B = ((uint8_t*)0x81000000);
uint32_t* HUB75_COLOR_W = ((uint32_t*)0x81000000);
#define HUB75_CTL *((uint32_t*)(0x81000000 + 64*64*4*2))

int main() {
	// for (int i = 0; i < 64 * 64 * 2; ++i) {
	// 	HUB75_COLOR_W[i] = i;
	// }

	while (1) {
		PARALLEL_IO_B[0] = 1;
		delay_ms(500);
		PARALLEL_IO_B[0] = 0;
		delay_ms(500);
		// delay_ms(1000);
	}

	return 0;
}