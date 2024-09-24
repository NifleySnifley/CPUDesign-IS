#include <stdint.h>
#define F_CPU 73421978
#include "led_matrix.h"
#include "cpu_time.h"
#include <string.h>

#define VRAM(i) *((uint8_t*)(0x8000+i))

void write_word(char* word, int x, int y) {
	int start_idx = y * 80 + x;
	int len = strlen(word);
	for (int i = 0; i < len; ++i) {
		VRAM(start_idx + i) = word[i];
	}
}

static char* hello = "Hello";
static char* world = "World";

int main() {
	for (int i = 0; i < 256; ++i) {
		VRAM(i) = (uint8_t)i;
	}

	while (1) {
		delay_ms(1000);
		LED_MATRIX_PIXELS = 0xAA;
		write_word(hello, 0, 20);
		delay_ms(1000);
		LED_MATRIX_PIXELS = 0x55;
		write_word(world, 0, 20);
		LED_MATRIX_ROW_SEL = 0b1111;
		// asm("ebreak");
	}

	return 0;
}