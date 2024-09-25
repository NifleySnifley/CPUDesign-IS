#include <stdint.h>
// #define F_CPU 73421978
#include "soc_io.h"
#include "soc_core.h"
#include <string.h>

#define VRAM ((uint8_t*)(0x10000))

void write_word(char* word, int x, int y) {
	int start_idx = y * 80 + x;
	int len = strlen(word);
	for (int i = 0; i < len; ++i) {
		VRAM[start_idx + i] = word[i];
	}
}

static char* hello = "Hello";
static char* world = "World";

int main() {
	for (int i = 0; i < 2400; ++i) {
		VRAM[i] = '!' + (uint8_t)(i % 80);
		// VRAM[i] = (i & 1) ? 'l' : 'd';
	}

	while (1) {
		PARALLEL_IO_B[0] = 0xAA;
		write_word(hello, 0, 20);
		delay_ms(1000);
		// asm("ebreak");
		PARALLEL_IO_B[0] = 0x55;
		write_word(world, 0, 20);
		PARALLEL_IO_B[1] = 0b1111;
		delay_ms(1000);
		// asm("ebreak");
	}

	return 0;
}