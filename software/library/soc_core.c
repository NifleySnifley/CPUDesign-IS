#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <soc_core.h>
#include <soc_io.h>

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

	return prev_heap;
}

int stdout_row = 0;
int stdout_col = 0;

int print(char* data) {
	int size = strlen(data);

	// Tread all handles as STDOUT
	for (int count = 0; count < size; count++) {
		int stdout_idx = stdout_row * SCREENBUFFER_COLS + stdout_col;
		char c = data[count];

		if (c == '\r') {
			stdout_col = 0; // Start of line
		} else if (c == '\n') {
			stdout_col = 0; // Start of line
			stdout_row = (stdout_row + 1) % SCREENBUFFER_ROWS;
		} else {
			SCREENBUFFER_B[stdout_idx] = c;
			stdout_col++;
		}

		if (stdout_col >= SCREENBUFFER_COLS) {
			stdout_col = 0;
			stdout_row = (stdout_row + 1) % SCREENBUFFER_ROWS;
		}
	}

	return size;
}

void delay_ms(uint32_t ms) {
	register uint32_t cyc_delay = ms * CYC_PER_MS;
	while (cyc_delay > 0) --cyc_delay;
}
