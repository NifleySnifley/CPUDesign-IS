#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"
#include <memory.h>
#include <math.h>

#define MANDEL_ITER 127
#define MANDEL_XMIN -2.00f
#define MANDEL_XMAX 0.47f
#define MANDEL_YMIN -1.12
#define MANDEL_YMAX 1.12
#define MANDEL_BOUND 2
int mandelbrot(float x0, float y0) {
	float x = 0.f, y = 0.f;
	int iter = 0;
	while (iter < MANDEL_ITER && (x * x + y * y < MANDEL_BOUND * MANDEL_BOUND)) {
		float xtmp = x * x - y * y + x0;
		y = 2 * x * y + y0;
		x = xtmp;
		iter++;
	}

	return iter;
}

uint32_t rgb(uint8_t r, uint8_t g, uint8_t b) {
	return r | (g << 8) | (b << 16);
}

volatile uint8_t* HUB75_COLOR_B = ((uint8_t*)0x81000000);
volatile uint32_t* HUB75_COLOR_W = ((uint32_t*)0x81000000);
volatile uint32_t* HUB75_CTL = ((uint32_t*)(0x81000000 + 64 * 64 * 4 * 2));

int main() {
	// Clear all buffers
	memset(HUB75_COLOR_W, 0, sizeof(uint32_t) * 64 * 64 * 2);

	for (int x = 0; x < 64; ++x) {
		for (int y = 0; y < 64; ++y) {
			int i = x * 64 + y;
			uint8_t mandel = mandelbrot(
				(x * (MANDEL_XMAX - MANDEL_XMIN)) / 64.0 + MANDEL_XMIN,
				(y * (MANDEL_YMAX - MANDEL_YMIN)) / 64.0 + MANDEL_YMIN
			);
			HUB75_COLOR_W[i] = rgb(0, mandel, 0);
			HUB75_COLOR_W[i + 64 * 64] = rgb(mandel, 0, 0);
		}
	}

	while (1) {
		PARALLEL_IO_B[0] = 1;
		*HUB75_CTL = 1;
		delay_ms(500);
		PARALLEL_IO_B[0] = 0;
		*HUB75_CTL = 0;
		delay_ms(500);
	}

	return 0;
}