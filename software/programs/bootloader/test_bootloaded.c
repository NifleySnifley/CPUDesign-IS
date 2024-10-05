#include <stdint.h>
#include <soc_core.h>
#include <soc_io.h>

int main() {
	PARALLEL_IO_B[0] = 0xAA;

	while (1) {
		PARALLEL_IO_B[0] = ~PARALLEL_IO_B[0];
		delay_ms(500);
	}

	return 0;
}