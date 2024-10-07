#include <stdint.h>
#include <soc_core.h>
#include <soc_io.h>

int main() {

	while (1) {
		PARALLEL_IO_B[0] = 0xAA;
		delay_ms(500);
		PARALLEL_IO_B[0] = 0x55;
		delay_ms(500);
	}

	return 0;
}