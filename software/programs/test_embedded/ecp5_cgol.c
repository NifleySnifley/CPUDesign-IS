#include <soc_core.h>
#include <soc_io.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#define CELL_COLS HUB75_MATRIX_WIDTH
#define CELL_ROWS HUB75_MATRIX_HEIGHT

typedef struct lifemap_t {
	bool states[CELL_ROWS * CELL_COLS];
} lifemap_t;

int cell_i(int X, int Y) {
	if (X < 0) X += CELL_COLS;
	if (X >= CELL_COLS) X -= CELL_COLS;
	if (Y < 0) Y += CELL_ROWS;
	if (Y >= CELL_ROWS) Y -= CELL_ROWS;
	return Y * CELL_COLS + X;
}

// Y is 0 at top, increases down
// X is 0 at left, increases right
bool get_cell(lifemap_t* map, int X, int Y) {
	return map->states[cell_i(X, Y)];
}

void set_cell(lifemap_t* map, int X, int Y, bool state) {
	map->states[cell_i(X, Y)] = state;
}

int count_neighbors(lifemap_t* map, int X, int Y) {
	return \
		(int)get_cell(map, X - 1, Y - 1) +
		(int)get_cell(map, X - 1, Y + 0) +
		(int)get_cell(map, X - 1, Y + 1) +
		(int)get_cell(map, X + 0, Y - 1) +
		(int)get_cell(map, X + 0, Y + 1) +
		(int)get_cell(map, X + 1, Y - 1) +
		(int)get_cell(map, X + 1, Y + 0) +
		(int)get_cell(map, X + 1, Y + 1);
}

int main() {
	lifemap_t* current, * next;
	current = calloc(1, sizeof(lifemap_t));
	next = calloc(1, sizeof(lifemap_t));

	// Starting is fun...
	// set_cell(current, 10, 4, 1);
	// set_cell(current, 11, 4, 1);
	// set_cell(current, 12, 4, 1);
	// set_cell(current, 12, 3, 1);
	// set_cell(current, 11, 2, 1);

	// // Blinker
	// set_cell(current, 20, 21, 1);
	// set_cell(current, 20, 22, 1);
	// set_cell(current, 20, 23, 1);
	int visible_buf = 0;

	for (int iter = 0; ; ++iter) {
		stdout_row = SCREENBUFFER_ROWS - 1;
		stdout_col = 0;

		// print("Step: ");
		// print_integer(iter);

		// Update the screen with current
		for (int x = 0; x < CELL_COLS; ++x) {
			for (int y = 0; y < CELL_ROWS; ++y) {
				bool cell = get_cell(current, x, y);
				hub75_set_pixel(x, y, 1 - visible_buf, (hub75_color_t) {
					.r = cell ? 64 : 0,
						.g = cell ? 64 : 0,
						.b = cell ? 64 : 0,
				});
			}
		}
		// Swap buffers
		visible_buf = 1 - visible_buf;
		hub75_select_buffer(visible_buf);
		// delay_ms(50);


		PARALLEL_IO_B[0] = 0x55;
		// asm("ebreak");

		// HOLDING IS MORE FUN!!!
		set_cell(current, 10, 4, 1);
		set_cell(current, 11, 4, 1);
		set_cell(current, 12, 4, 1);
		set_cell(current, 12, 3, 1);
		set_cell(current, 11, 2, 1);

		// Blinker
		set_cell(current, 20, 21, 1);
		set_cell(current, 20, 22, 1);
		set_cell(current, 20, 23, 1);

		// Update next with current state
		for (int y = 0; y < CELL_ROWS; ++y) {
			for (int x = 0; x < CELL_COLS; ++x) {
				int n = count_neighbors(current, x, y);

				if (get_cell(current, x, y)) {
					// If alive, 2 or 3 works
					set_cell(next, x, y, (n == 2) || (n == 3));
				} else {
					// If dead, only 3
					set_cell(next, x, y, (n == 3));
				}
			}
		}

		// Swap buffers
		lifemap_t* prev = current;
		current = next;
		next = prev;

		if (iter > 10000)
			memset(current, 0, sizeof(*current));

		PARALLEL_IO_B[0] = 0xAA;
	}

	return 0;
}