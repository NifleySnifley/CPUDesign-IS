#include <stdint.h>
#include "soc_io.h"
#include "soc_core.h"

int main() {
	int i = 0;

	for (int j = 0; j < 8; j++)
		SPRAM[24576 + j] = 1 << j;

	PARALLEL_IO_B[0] = 0x00;

	while (1) {
		i = (i == 7) ? 0 : (i + 1);
		PARALLEL_IO_B[0] = SPRAM[24576 + i];
		delay_ms(100);
	}

	return 0;
}