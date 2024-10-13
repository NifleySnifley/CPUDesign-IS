#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

int main() {
	while (1) {
		PARALLEL_IO_B[0] = 1;
		delay_ms(100);
		PARALLEL_IO_B[0] = 0;
		delay_ms(100);
	}

	return 0;
}