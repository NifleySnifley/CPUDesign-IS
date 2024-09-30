#include <soc_core.h>
#include <soc_io.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#define CELL_COLS (SCREENBUFFER_COLS / 2)
#define CELL_ROWS (SCREENBUFFER_ROWS)

typedef struct lifemap_t {
	// uint8_t cell_states[(CELL_COLS / 8) * CELL_ROWS];
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
// For each byte-state, 0th bit is the furthest LEFT
bool get_cell(lifemap_t* map, int X, int Y) {
	int idx = cell_i(X, Y);
	return map->states[idx];
}

void set_cell(lifemap_t* map, int X, int Y, bool state) {
	int idx = cell_i(X, Y);
	map->states[idx] = state;
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
	current = malloc(sizeof(lifemap_t));
	next = malloc(sizeof(lifemap_t));

	set_cell(current, 5, 5, 1);
	set_cell(current, 5, 6, 1);
	set_cell(current, 5, 7, 1);

	set_cell(current, 10, 1, 1);
	set_cell(current, 11, 1, 1);
	set_cell(current, 12, 1, 1);

	while (1) {
		// Update next with current state
		for (int y = 0; y < CELL_ROWS; ++y) {
			for (int x = 0; x < CELL_COLS; ++x) {
				int n = count_neighbors(current, x, y);

				if (get_cell(current, x, y)) {
					set_cell(next, x, y, (n == 2) || (n == 3));
				} else {
					set_cell(next, x, y, (n == 3));
				}
			}
		}

		// Swap next and current;
		lifemap_t* tmp = current;
		current = next;
		next = tmp;

		// Update the screen with current
		for (int x = 0; x < CELL_COLS; ++x) {
			for (int y = 0; y < CELL_ROWS; ++y) {
				int sbuf_idx = x * 2 + y * SCREENBUFFER_COLS;
				bool on = get_cell(current, x, y);

				SCREENBUFFER_B[sbuf_idx] = on ? 3 : 0;
				SCREENBUFFER_B[sbuf_idx + 1] = on ? 3 : 0;
			}
		}

		delay_ms(1000);
	}

	return 0;
}