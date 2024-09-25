#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vbw_textmode_gpu.h"
#include "obj_dir/Vbw_textmode_gpu___024root.h"
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>
#include <unistd.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
// #include "obj_dir/"

#define MAX_SIM_TIME 10000
vluint64_t sim_time = 0;

#define VGA_SCALE 2

#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480
#define FONT_HEIGHT 16
#define FONT_WIDTH 8
#define SCREEN_ROWS (SCREEN_HEIGHT/FONT_HEIGHT)
#define SCREEN_COLS (SCREEN_WIDTH/FONT_WIDTH)
#define SCREENBUFFER_BASE_ADDR 0x10000
#define SCREENBUFFER_SIZE_B (SCREEN_ROWS*SCREEN_COLS)
// #define FONTRAM_BASE_ADDR 0x20000
// #define FONTRAM_SIZE_B (256*16)
// #define FONTRAM_INITFILE "build/font.bin"

static bool EXIT = false;

static bool PIXELS[SCREEN_WIDTH][SCREEN_HEIGHT] = { 0 };

void signal_handler(int signum) {
	EXIT = 1;
}

void set_pixel(SDL_Surface* surface, int x, int y, Uint32 pixel) {
	uint32_t* const target_pixel = (uint32_t*)((uint8_t*)surface->pixels
		+ y * surface->pitch
		+ x * surface->format->BytesPerPixel);
	*target_pixel = pixel;
}

static Vbw_textmode_gpu* dut;

void* vga_thread(void* arg) {
	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		printf("SDL could not be initialized!\n"
			"SDL_Error: %s\n", SDL_GetError());
		return 0;
	}


	// Disable compositor bypass
	if (!SDL_SetHint(SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR, "0")) {
		printf("SDL can not disable compositor bypass!\n");
		return 0;
	}


	SDL_Window* vga_window;

	vga_window = SDL_CreateWindow("VGA Display",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		SCREEN_WIDTH * VGA_SCALE, SCREEN_HEIGHT * VGA_SCALE,
		SDL_WINDOW_SHOWN);

	if (!vga_window) {
		printf("Windows could not be created!\n"
			"SDL_Error: %s\n", SDL_GetError());
	}

	printf("Opened GUI\n");


	SDL_Surface* vga_surface = SDL_GetWindowSurface(vga_window);

	// Event loop
	while (!EXIT) {
		SDL_Event e;

		if (SDL_PollEvent(&e)) {
			if (e.type == SDL_QUIT) {
				EXIT = true;
				break;
			} else if (e.type == SDL_MOUSEBUTTONDOWN) {
				int px, py;
				SDL_GetMouseState(&px, &py);
				px /= VGA_SCALE;
				py /= VGA_SCALE;
				printf("Clicked pixel: (%d, %d)\n", px, py);
			}
		}

		//////////////////// VGA //////////////////

		// int xc = VGA_SCALE * dut->rootp->bw_textmode_gpu__DOT__x;
		// int yc = VGA_SCALE * dut->rootp->bw_textmode_gpu__DOT__y;
		// bool vid = dut->video;

		// if ((xc >= 0 && xc < SCREEN_WIDTH * VGA_SCALE) && (yc >= 0 && yc < SCREEN_HEIGHT * VGA_SCALE)) {
		// 	for (int xo = 0; xo < VGA_SCALE; ++xo) {
		// 		for (int yo = 0; yo < VGA_SCALE; ++yo) {

		// 			set_pixel(vga_surface, xc + xo, yc + yo, vid ? 0xFFFFFFFF : 0xFF000000);
		// 		}
		// 	}
		// }

		for (int x = 0; x < SCREEN_WIDTH; ++x) {
			for (int y = 0; y < SCREEN_HEIGHT; ++y) {
				for (int xo = 0; xo < VGA_SCALE; ++xo) {
					for (int yo = 0; yo < VGA_SCALE; ++yo) {
						set_pixel(vga_surface, x * VGA_SCALE + xo, y * VGA_SCALE + yo, PIXELS[x][y] ? 0xFFFFFFFF : 0xFF000000);
					}
				}
			}
		}

		SDL_UpdateWindowSurface(vga_window);
	}



	SDL_FreeSurface(vga_surface);

	SDL_DestroyWindow(vga_window);

	SDL_Quit();

	return NULL;
}


int main(int argc, char** argv, char** env) {
	dut = new Vbw_textmode_gpu;
	Verilated::traceEverOn(true);
	VerilatedVcdC* m_trace = new VerilatedVcdC;
	dut->trace(m_trace, 5);
	m_trace->open("bw_textmode_gpu.vcd");

	signal(SIGINT, signal_handler);

	pthread_t sdl_thread_handle;
	pthread_create(&sdl_thread_handle, NULL, vga_thread, NULL);

	// Reset
	while (sim_time < 10) {
		dut->rst = sim_time < 5;
		dut->clk ^= 1;
		dut->eval();
		m_trace->dump(sim_time);
		sim_time++;
	}

	for (int i = 0; i < 2400 / 4; ++i) {
		dut->rootp->bw_textmode_gpu__DOT__screenbuffer[i] = ('!' + (uint8_t)((i * 4) % 80)) << 0 |
			('!' + (uint8_t)((i * 4 + 1) % 80)) << 8 |
			('!' + (uint8_t)((i * 4 + 2) % 80)) << 16 |
			('!' + (uint8_t)((i * 4 + 3) % 80)) << 24;
	}

	// for (int i = 0; i < 2400; ++i) {
	// 	dut->rootp->bw_textmode_gpu__DOT__screenbuffer[i] = ('!' + (uint8_t)(i % 80));
	// }

	constexpr vluint64_t MAX_FRAMES = 10;
	vluint64_t nframes = 0;
	bool last_vsync = 0;

	while (!EXIT) {
		if (nframes < MAX_FRAMES) {
			dut->clk = 0;
			dut->clk_12MHz = 0;
			dut->eval();
			m_trace->dump(sim_time++);
			dut->clk = 1;
			dut->clk_12MHz = 1;
			dut->eval();
			m_trace->dump(sim_time++);
		}

		int x = dut->rootp->bw_textmode_gpu__DOT__x;
		int y = dut->rootp->bw_textmode_gpu__DOT__y;
		if ((x >= 0 && x < SCREEN_WIDTH) && (y >= 0 && y < SCREEN_HEIGHT * VGA_SCALE)) {
			PIXELS[x][y] = dut->video;
		}

		if ((dut->vsync != last_vsync) && (dut->vsync)) {
			// printf("Frame done! Press any key to continue.\n");
			// getchar();
			nframes++;
		}
		last_vsync = dut->vsync;
	}

	m_trace->close();

	EXIT = 1;
	pthread_join(sdl_thread_handle, NULL);

	delete dut;
	exit(EXIT_SUCCESS);
}