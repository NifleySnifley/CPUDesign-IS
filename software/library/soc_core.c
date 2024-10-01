#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <soc_core.h>
#include <soc_io.h>
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

int stdout_row = 0;
int stdout_col = 0;

void printchar(char c) {
	int stdout_idx = stdout_row * SCREENBUFFER_COLS + stdout_col;

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

int printn(char* data, int n) {
	for (int count = 0; count < n; count++) {
		printchar(data[count]);
	}

	return n;
}

int print(char* data) {
	return printn(data, strlen(data));
}

int print_integer(int number) {
	bool neg = number < 0;
	if (neg) number *= -1;

	int n = 10;
	char str[11]; // Assuming 32 bit int

	do {
		int digit = number % 10;
		str[n--] = '0' + digit;
		number /= 10;
	} while (number > 0);

	if (neg)
		str[n--] = '-';
	printn(&str[n + 1], 11 - n);
	return n;
}

#pragma GCC push_options
#pragma GCC optimize ("O0")
void delay_ms(uint32_t ms) {
	register uint32_t cyc_delay = ms * CYC_PER_MS;
	while (cyc_delay > 0) --cyc_delay;
}
#pragma GCC pop_options