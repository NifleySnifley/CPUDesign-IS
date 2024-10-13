#include <stdint.h>
#include <soc_core.h>
#include <soc_io.h>

int main() {

	for (int fg = 0; fg < 64; ++fg) {
		int x = fg % 8;
		int y = fg / 8;
		int place = x + y * SCREENBUFFER_COLS;
		SCREENBUFFER_B[place] = 3;
		COLORBUFFER_W[place] = COLOR_FG(fg) | COLOR_BG(0);
	}

	while (1) {
		PARALLEL_IO_B[0] = 0xAA;
		delay_ms(500);
		PARALLEL_IO_B[0] = 0x55;
		delay_ms(500);
	}

	return 0;
}