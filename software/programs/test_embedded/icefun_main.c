#include <stdint.h>
#include "soc_io.h"
#include "soc_core.h"

#define LED_MATRIX_ROW_SEL PARALLEL_IO_B[1]
#define LED_MATRIX_PIXELS PARALLEL_IO_B[0]

int main() {
	int i = 0;

	while (1) {
		int change = (i / 500) & 1;

		i++;
		LED_MATRIX_ROW_SEL = 1 << (i & 0b11);
		LED_MATRIX_PIXELS = 0x55 << ((i + change) & 1);
		delay_ms(1);
	}

	return 0;
}