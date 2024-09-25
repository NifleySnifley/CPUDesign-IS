#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <time.h>

#include "rv32i_simulator.h"
#include <SDL2/SDL.h>

#include <pthread.h>
#include <getopt.h>
#include <signal.h>
#include <sys/time.h>

#define LEDS_ADDR 0xf000

#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480
#define FONT_HEIGHT 16
#define FONT_WIDTH 8
#define SCREEN_ROWS (SCREEN_HEIGHT/FONT_HEIGHT)
#define SCREEN_COLS (SCREEN_WIDTH/FONT_WIDTH)
#define SCREENBUFFER_BASE_ADDR 0x10000
#define SCREENBUFFER_SIZE_B (SCREEN_ROWS*SCREEN_COLS)
#define FONTRAM_BASE_ADDR 0x20000
#define FONTRAM_SIZE_B (256*16)
#define FONTRAM_INITFILE "build/font.bin"

#define VGA_SCALE 2

static volatile bool EXIT = false;
static bool enable_leds = false;
static bool enable_vga = false;
static bool enable_buttons = false;

void set_pixel(SDL_Surface* surface, int x, int y, Uint32 pixel) {
	uint32_t* const target_pixel = (uint32_t*)((uint8_t*)surface->pixels
		+ y * surface->pitch
		+ x * surface->format->BytesPerPixel);
	*target_pixel = pixel;
}

void* sdl_window_thread_fn(void* arg) {
	rv_simulator_t* sim = (rv_simulator_t*)arg;

	const int LED_SIZE = 32;

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


	SDL_Window* led_window, * vga_window;

	if (enable_leds)
		led_window = SDL_CreateWindow("LED Matrix",
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			LED_SIZE * 8, LED_SIZE * 4,
			SDL_WINDOW_SHOWN);

	if (enable_vga)
		vga_window = SDL_CreateWindow("VGA Display",
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			SCREEN_WIDTH * VGA_SCALE, SCREEN_HEIGHT * VGA_SCALE,
			SDL_WINDOW_SHOWN);

	if (!vga_window || !led_window) {
		printf("Windows could not be created!\n"
			"SDL_Error: %s\n", SDL_GetError());
	}

	SDL_Renderer* led_renderer;
	if (enable_leds) led_renderer = SDL_CreateRenderer(led_window, -1, SDL_RENDERER_ACCELERATED);

	printf("Opened GUI\n");

	SDL_Rect led_rect;
	uint8_t led_state[4] = { 0 };
	led_rect.w = LED_SIZE;
	led_rect.h = LED_SIZE;

	SDL_Surface* character_bitmap = SDL_CreateRGBSurface(0, FONT_WIDTH, FONT_HEIGHT, 32, 0, 0, 0, 0);
	SDL_Surface* vga_surface;

	if (enable_vga) vga_surface = SDL_GetWindowSurface(vga_window);

	// Event loop
	while (!EXIT) {
		SDL_Event e;
		// TODO: This is not working
		if (SDL_PollEvent(&e)) {
			if (e.type == SDL_QUIT) {
				EXIT = true;
			}
		}

		if (enable_leds) {
			SDL_SetRenderDrawColor(led_renderer, 0xFF, 0xFF, 0xFF, 0xFF);
			SDL_RenderClear(led_renderer);

			uint8_t led_row = rv_simulator_read_byte(sim, 0xf000);
			uint8_t led_row_select = rv_simulator_read_byte(sim, 0xf001);

			for (int r = 0; r < 4; ++r) {
				if (led_row_select & (1 << r))
					led_state[r] = led_row;


				for (int i = 0; i < 8; ++i) {
					led_rect.x = LED_SIZE * i;
					led_rect.y = LED_SIZE * r;
					if ((led_state[r] >> i) & 1) {
						SDL_SetRenderDrawColor(led_renderer, 0xFF, 0x00, 0x00, 0xFF);
					} else {
						SDL_SetRenderDrawColor(led_renderer, 0x00, 0x00, 0x00, 0xFF);
					}
					SDL_RenderFillRect(led_renderer, &led_rect);
				}
			}

			SDL_RenderPresent(led_renderer);
		}

		//////////////////// VGA //////////////////

		if (enable_vga) {
			for (int idx = 0; idx < (SCREEN_COLS * SCREEN_ROWS); ++idx) {
				int row = idx / SCREEN_COLS;
				int col = idx % SCREEN_COLS;

				uint8_t ch = rv_simulator_read_byte(sim, SCREENBUFFER_BASE_ADDR + idx);
				if (ch == 0) continue;

				for (int r = 0; r < FONT_HEIGHT; ++r) {
					uint8_t rowbin = rv_simulator_read_byte(sim, FONTRAM_BASE_ADDR + FONT_HEIGHT * ch + r);
					for (int c = 0; c < FONT_WIDTH; ++c) {
						set_pixel(character_bitmap, c, r, rowbin & (0x80 >> c) ? 0xFFFFFFFF : 0xFF000000);
					}
				}

				SDL_Rect dest;
				dest.x = col * FONT_WIDTH * VGA_SCALE;
				dest.y = row * FONT_HEIGHT * VGA_SCALE;
				dest.w = FONT_WIDTH * VGA_SCALE;
				dest.h = FONT_HEIGHT * VGA_SCALE;
				SDL_BlitScaled(character_bitmap, NULL, vga_surface, &dest);
			}

			SDL_UpdateWindowSurface(vga_window);
		}
	}

	if (enable_vga) SDL_FreeSurface(vga_surface);
	if (enable_vga) SDL_FreeSurface(character_bitmap);

	EXIT = true;
	if (enable_leds) SDL_DestroyRenderer(led_renderer);


	if (enable_leds) SDL_DestroyWindow(led_window);
	if (enable_vga) SDL_DestroyWindow(vga_window);

	SDL_Quit();
}


void signal_handler(int signum) {
	EXIT = 1;
}


#define N_INSN_PERF 100000000
int main(int argc, char** argv) {
	RV_SIM_VERBOSE = true;
	char* program_filename = "program.bin";
	signal(SIGINT, signal_handler);

	int opt;
	while ((opt = getopt(argc, argv, "lvb")) != -1) {
		switch (opt) {
			case 'l':
				enable_leds = true;
				break;
			case 'v':
				enable_vga = true;
				break;
			case 'b':
				enable_buttons = true;
				break;
			default:
				fprintf(stderr, "Usage: %s [-v (vga gui) ] [-l (led matrix gui) ] [-b (buttons gui) ] program.bin \n",
					argv[0]);
				exit(EXIT_FAILURE);
		}
	}

	if (optind < argc) {
		program_filename = argv[optind];
	}

	rv_simulator_t sim = { 0 };
	rv_simulator_init(&sim);
	rv_simulator_segmented_memory_t* memory = rv_simulator_init_segmented_memory(&sim);
	rv_simulator_segmented_memory_add_segment(memory, 0, 2048 * 4, "Main Memory", false);
	rv_simulator_segmented_memory_add_segment(memory, 0xf000, 4, "LED Matrix", false);
	rv_simulator_segmented_memory_add_segment(memory, 0xf0000000, 16384, "SPRAM", false);
	rv_simulator_segmented_memory_add_segment(memory, SCREENBUFFER_BASE_ADDR, SCREENBUFFER_SIZE_B, "Character Screenbuffer", false);
	rv_simulator_segmented_memory_add_segment(memory, FONTRAM_BASE_ADDR, FONTRAM_SIZE_B, "Font RAM", false);

	int nmem = rv_simulator_load_memory_from_file(&sim, program_filename, FILETYPE_AUTO, 0);
	printf("Loaded %d bytes into main memory\n", nmem);

	nmem = rv_simulator_load_memory_from_file(&sim, FONTRAM_INITFILE, FILETYPE_AUTO, FONTRAM_BASE_ADDR);
	printf("Loaded %d bytes into font RAM\n", nmem);

	pthread_t sdl_thread_handle;

	if (enable_leds | enable_buttons | enable_vga)
		pthread_create(&sdl_thread_handle, NULL, sdl_window_thread_fn, (void*)&sim);

	uint64_t instruction = 0;

	// Profiling for the simulator
	struct timeval tv;
	gettimeofday(&tv, NULL);
	uint64_t last_micros = 1000000 * tv.tv_sec + tv.tv_usec;

	while (!EXIT) {
		int status = rv_simulator_step(&sim);
		instruction++;

		if ((instruction % N_INSN_PERF) == 0) {
			gettimeofday(&tv, NULL);
			uint64_t micros = 1000000 * tv.tv_sec + tv.tv_usec;
			uint64_t delta_micros = micros - last_micros;
			last_micros = micros;

			double insn_per_second = (((double)N_INSN_PERF) / ((double)delta_micros)) * 1e+6;
			printf(
				"Simulation stats: %lu instructions executed. %f instructions per second (~%f Hz CPU)\n",
				instruction,
				insn_per_second,
				insn_per_second * 4.5
			);
		}

		if (status < 0) {
			printf("Breakpoint @ PC=%x\n", sim.pc);

			printf("Press 'c' key to continue, 'r' to print registers, 'm' to print memory, ctrl-C + return to exit.\n");
			while (!EXIT) {
				char c = getchar();
				if (c == 'c') { break; }
				switch (c) {
					case 'm':
						rv_simulator_pprint_memory(&sim);
						break;
					case 'r':
						rv_simulator_pprint_registers(&sim);
						break;
					default:
						break;
				}
			}
		}
	}

	EXIT = true;
	if (enable_leds | enable_buttons | enable_vga)
		pthread_join(sdl_thread_handle, NULL);

	rv_simulator_deinit(&sim);
	printf("Cleaned up simulator!\n");

	return 0;
}