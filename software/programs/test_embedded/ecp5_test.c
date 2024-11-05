#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

uint8_t* HUB75_COLOR_B = ((uint8_t*)0x81000000);
uint32_t* HUB75_COLOR_W = ((uint32_t*)0x81000000);
#define HUB75_CTL *((uint32_t*)(0x81000000 + 64*64*4*2))

int main() {
	uint8_t brightness = 0;

	while (1) {
		PARALLEL_IO_B[0] = 1;
		delay_ms(10);
		PARALLEL_IO_B[0] = 0;
		delay_ms(10);
		// for (int i = 0; i < 64 * 64 * 2; ++i) {
		// 	HUB75_COLOR_W[i] = (brightness) << 8 | (255 - brightness) | ((i > 64 * 32) ? (100 << 16) | 0);
		// }
		for (int x = 0; x < 64; ++x) {
			for (int y = 0; y < 64; ++y) {
				int i = x * 64 + y;
				HUB75_COLOR_W[i] = x ^ y;
				// uint32_t v = (x < 32) ? (255) : (0);
				// HUB75_COLOR_W[i] = v;
				// HUB75_COLOR_W[i] = brightness;
			}
		}
		brightness++;
		// delay_ms(1000);
	}

	return 0;
}