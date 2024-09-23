#include <stdint.h>
#include "led_matrix.h"
#include "cpu_time.h"

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

void __attribute__((section(".text.start"))) _start() {
	// TODO: This is REALLY sketchy!!! Loading stack pointer is iffy at best...
	// FIXME: Add a bus device for SPRAM on the ice40, and throw the stack pointer somewhere in there!
	__asm__("li sp,0x1000");
	main();
}