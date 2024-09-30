#include <soc_core.h>
#include <soc_io.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#define CELL_COLS (SCREENBUFFER_COLS)
#define CELL_ROWS (SCREENBUFFER_ROWS*2)

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
inline bool get_cell(lifemap_t* map, int X, int Y) {
	return map->states[cell_i(X, Y)];
}

inline void set_cell(lifemap_t* map, int X, int Y, bool state) {
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
	register uint32_t dbg_1 asm("x29");
	register uint32_t dbg_2 asm("x30");
	register uint32_t dbg_3 asm("x31");

	lifemap_t* current, * next;
	current = malloc(sizeof(lifemap_t));
	next = malloc(sizeof(lifemap_t));

	// Small glider
	set_cell(current, 10, 4, 1);
	set_cell(current, 11, 4, 1);
	set_cell(current, 12, 4, 1);
	set_cell(current, 12, 3, 1);
	set_cell(current, 11, 2, 1);

	// Blinker
	set_cell(current, 20, 21, 1);
	set_cell(current, 20, 22, 1);
	set_cell(current, 20, 23, 1);


	while (1) {
		// Update the screen with current
		for (int x = 0; x < CELL_COLS; ++x) {
			for (int y_2 = 0; y_2 < CELL_ROWS / 2; ++y_2) {
				uint8_t high = get_cell(current, x, y_2 * 2);
				uint8_t low = get_cell(current, x, y_2 * 2 + 1);
				SCREENBUFFER_B[x + y_2 * SCREENBUFFER_COLS] = (high | (low << 1));
			}
		}

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
	}

	return 0;
}