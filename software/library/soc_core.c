#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <soc_core.h>
#include <stdbool.h>

extern int _heap_start;

// Heap management stub
void* _sbrk(int incr) {
	static unsigned char* heap = NULL;
	unsigned char* prev_heap;

	if (heap == NULL) {
		heap = (unsigned char*)&_heap_start;
	}

	prev_heap = heap;
	heap += incr;
	// print("Sbrk: ");
	// print_integer((uint32_t)heap % 100000);
	// print("\n");

	return prev_heap;
}

#pragma GCC push_options
#pragma GCC optimize ("O0")
void delay_ms(uint32_t ms) {
	register uint32_t cyc_delay = ms * CYC_PER_MS;
	while (cyc_delay > 0) --cyc_delay;
}

#pragma GCC pop_options