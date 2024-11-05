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

#define LEDS_ADDR 0x80000000

#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480
#define FONT_HEIGHT 16
#define FONT_WIDTH 8
#define SCREEN_ROWS (SCREEN_HEIGHT/FONT_HEIGHT)
#define SCREEN_COLS (SCREEN_WIDTH/FONT_WIDTH)
#define SCREENBUFFER_BASE_ADDR 0x82000000
#define SCREENBUFFER_SIZE_B (SCREEN_ROWS*SCREEN_COLS)
#define COLORBUFFER_BASE_ADDR (SCREENBUFFER_BASE_ADDR + SCREENBUFFER_SIZE_B)
#define COLORBUFFER_SIZE_B (SCREEN_ROWS*SCREEN_COLS * 4)
#define FONTRAM_BASE_ADDR 0x90000000 // FIXME: This doesn't really exist, get rid of it
#define FONTRAM_SIZE_B (256*16)

#define VGA_SCALE 1

#define HUB75_SCALE 8
#define HUB75_BASE_ADDR 0x81000000
#define HUB75_ROWS 64
#define HUB75_COLS 64
#define HUB75_BUFWORDS (HUB75_ROWS * HUB75_COLS)
#define HUB75_BUFFERS 2
// 1 extra for control
#define HUB75_CONTROL_ADDR (HUB75_BASE_ADDR + (HUB75_WORDS-1) * 4)
#define HUB75_WORDS (HUB75_BUFWORDS * HUB75_BUFFERS + 1)

static volatile bool EXIT = false;
static bool enable_leds = false;
static bool enable_vga = false;
static bool emulate_bootloader = false;
bool enable_hub75 = false;
const char* fontfile = "build/font.bin";

void set_pixel(SDL_Surface* surface, int x, int y, Uint32 pixel) {
	uint32_t* const target_pixel = (uint32_t*)((uint8_t*)surface->pixels
		+ y * surface->pitch
		+ x * surface->format->BytesPerPixel);
	*target_pixel = pixel;
}

typedef union argb32 {
	struct {
		uint8_t b, g, r, a;
	};
	uint32_t value;
} rgba32;

uint8_t hub75_colorcorrect(uint8_t colorin) {
	return (uint8_t)(255.f * sqrtf((float)colorin / 255.f));
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


	SDL_Window* led_window, * vga_window, * hub75_window;

	if (enable_leds)
		led_window = SDL_CreateWindow("LED Bar",
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			LED_SIZE * 8, LED_SIZE * 3,
			SDL_WINDOW_SHOWN);

	if (enable_vga)
		vga_window = SDL_CreateWindow("VGA Display",
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			SCREEN_WIDTH * VGA_SCALE, SCREEN_HEIGHT * VGA_SCALE,
			SDL_WINDOW_SHOWN);

	if (enable_hub75)
		hub75_window = SDL_CreateWindow("HUB75 Matrix",
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			HUB75_COLS * HUB75_SCALE, HUB75_ROWS * HUB75_SCALE,
			SDL_WINDOW_SHOWN);

	if ((!vga_window && enable_vga) || (!led_window && enable_leds) || (!hub75_window && enable_hub75)) {
		printf("Windows could not be created!\n"
			"SDL_Error: %s\n", SDL_GetError());
	}

	SDL_Renderer* led_renderer;
	if (enable_leds) led_renderer = SDL_CreateRenderer(led_window, -1, SDL_RENDERER_ACCELERATED);

	SDL_Renderer* hub75_renderer;
	if (enable_hub75) hub75_renderer = SDL_CreateRenderer(hub75_window, -1, SDL_RENDERER_ACCELERATED);

	printf("Opened GUI\n");

	SDL_Rect led_rect;
	led_rect.w = LED_SIZE - 2;
	led_rect.h = LED_SIZE * 3;

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
			SDL_SetRenderDrawColor(led_renderer, 0x00, 0x00, 0x00, 0xFF);
			SDL_RenderClear(led_renderer);

			uint8_t led_row = rv_simulator_read_byte(sim, LEDS_ADDR);
			// uint8_t led_row_select = rv_simulator_read_byte(sim, 0xf001);
			for (int i = 0; i < 8; ++i) {
				led_rect.x = LED_SIZE * i + 1;
				led_rect.y = 0;
				if ((led_row >> i) & 1) {
					SDL_SetRenderDrawColor(led_renderer, 0x00, 0x80, 0x00, 0xFF);
				} else {
					SDL_SetRenderDrawColor(led_renderer, 0x00, 0x00, 0x00, 0xFF);
				}
				SDL_RenderFillRect(led_renderer, &led_rect);
			}


			SDL_RenderPresent(led_renderer);
		}

		if (enable_hub75) {
			SDL_SetRenderDrawColor(hub75_renderer, 0x00, 0x00, 0x00, 0xFF);
			SDL_RenderClear(hub75_renderer);

			uint8_t buffer_select = rv_simulator_read_byte(sim, HUB75_CONTROL_ADDR);

			for (int row = 0; row < HUB75_ROWS; ++row) {
				for (int col = 0; col < HUB75_COLS; ++col) {
					// Rotated 90deg CW to match reality
					int x = HUB75_ROWS - 1 - row;
					int y = col;

					int pixel_index = x * HUB75_ROWS + y + buffer_select * HUB75_ROWS * HUB75_COLS;
					uint8_t red = rv_simulator_read_byte(sim, HUB75_BASE_ADDR + 4 * pixel_index + 0);
					uint8_t green = rv_simulator_read_byte(sim, HUB75_BASE_ADDR + 4 * pixel_index + 1);
					uint8_t blue = rv_simulator_read_byte(sim, HUB75_BASE_ADDR + 4 * pixel_index + 2);
					// uint8_t led_row_select = rv_simulator_read_byte(sim, 0xf001);
					for (int i = 0; i < 8; ++i) {
						led_rect.x = HUB75_SCALE * row;
						led_rect.y = HUB75_SCALE * col;

						SDL_SetRenderDrawColor(hub75_renderer, hub75_colorcorrect(red * 2), hub75_colorcorrect(green * 2), hub75_colorcorrect(blue * 2), 0xFF);

						SDL_RenderFillRect(hub75_renderer, &led_rect);
					}
				}
			}

			SDL_RenderPresent(hub75_renderer);
		}

		//////////////////// VGA //////////////////

		if (enable_vga) {
			for (int idx = 0; idx < (SCREEN_COLS * SCREEN_ROWS); ++idx) {
				int row = idx / SCREEN_COLS;
				int col = idx % SCREEN_COLS;

				uint8_t ch = rv_simulator_read_byte(sim, SCREENBUFFER_BASE_ADDR + idx);
				// if (ch == 0) continue;

				for (int r = 0; r < FONT_HEIGHT; ++r) {
					uint8_t rowbin = rv_simulator_read_byte(sim, FONTRAM_BASE_ADDR + FONT_HEIGHT * ch + r);
					for (int c = 0; c < FONT_WIDTH; ++c) {
						int col_addr = COLORBUFFER_BASE_ADDR + idx * 4;
						uint16_t color = 0; // White FG, black BG
						color |= rv_simulator_read_byte(sim, col_addr + 0);
						color |= rv_simulator_read_byte(sim, col_addr + 1) << 8;

						uint8_t color_fg = (color & 0x3F);
						uint8_t color_bg = ((color >> 6) & 0x3F);
						rgba32 fg = {
							.a = 0xFF,
							.r = ((color_fg >> 0) & 0b11) * 85,
							.g = ((color_fg >> 2) & 0b11) * 85,
							.b = ((color_fg >> 4) & 0b11) * 85,
						};
						rgba32 bg = {
							.a = 0xFF,
							.r = ((color_bg >> 0) & 0b11) * 85,
							.g = ((color_bg >> 2) & 0b11) * 85,
							.b = ((color_bg >> 4) & 0b11) * 85,
						};
						set_pixel(character_bitmap, c, r, rowbin & (0x80 >> c) ? fg.value : bg.value);
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
	if (enable_hub75) SDL_DestroyRenderer(hub75_renderer);


	if (enable_leds) SDL_DestroyWindow(led_window);
	if (enable_vga) SDL_DestroyWindow(vga_window);
	if (enable_hub75) SDL_DestroyWindow(hub75_window);

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
	while ((opt = getopt(argc, argv, "lvbf:Bh")) != -1) {
		switch (opt) {
			case 'l':
				enable_leds = true;
				break;
			case 'v':
				enable_vga = true;
				break;
			case 'h':
				enable_hub75 = true;
				break;
			case 'b':
				emulate_bootloader = true;
				break;
			case 'f':
				fontfile = optarg;
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
	rv_simulator_segmented_memory_add_segment(memory, 0, 128000 * 4, "Main Memory", false);
	rv_simulator_segmented_memory_add_segment(memory, LEDS_ADDR, 4, "Parallel IO", false);
	rv_simulator_segmented_memory_add_segment(memory, 0xf0000000, 131072, "SPRAM", false);
	if (enable_vga) {
		// TODO: Fix addressing of this
		rv_simulator_segmented_memory_add_segment(memory, SCREENBUFFER_BASE_ADDR, SCREENBUFFER_SIZE_B, "Character Screenbuffer", false);
		rv_simulator_segmented_memory_add_segment(memory, COLORBUFFER_BASE_ADDR, COLORBUFFER_SIZE_B, "Character Colorbuffer", false);
		rv_simulator_segmented_memory_add_segment(memory, FONTRAM_BASE_ADDR, FONTRAM_SIZE_B, "Font RAM", false);
	}
	if (enable_hub75)
		rv_simulator_segmented_memory_add_segment(memory, HUB75_BASE_ADDR, HUB75_WORDS * 4, "HUB75 Buffers & Control", false);

	if (emulate_bootloader) {
		int nmem = rv_simulator_load_memory_from_file(&sim, program_filename, FILETYPE_AUTO, 0xf0000000);
		printf("Loaded %d bytes into SPRAM (bootloaded)\n", nmem);
		sim.pc = 0xf0000000;
	} else {
		int nmem = rv_simulator_load_memory_from_file(&sim, program_filename, FILETYPE_AUTO, 0);
		printf("Loaded %d bytes into main memory\n", nmem);
	}

	if (enable_vga) {
		for (int i = 0; i < SCREEN_ROWS * SCREEN_COLS;++i) {
			int addr = COLORBUFFER_BASE_ADDR + i * 4;
			uint16_t color = 0b000000111111; // White FG, black BG
			rv_simulator_write_byte(&sim, addr + 0, color & 0x3F);
			rv_simulator_write_byte(&sim, addr + 1, (color >> 6) & 0x3F);
		}

		int nmem = rv_simulator_load_memory_from_file(&sim, fontfile, FILETYPE_AUTO, FONTRAM_BASE_ADDR);
		printf("Loaded %d bytes into font RAM\n", nmem);
	}

	pthread_t sdl_thread_handle;

	if (enable_leds | enable_vga | enable_hub75)
		pthread_create(&sdl_thread_handle, NULL, sdl_window_thread_fn, (void*)&sim);

	uint64_t instruction = 0;

	// Profiling for the simulator
	struct timeval tv;
	gettimeofday(&tv, NULL);
	uint64_t last_micros = 1000000 * tv.tv_sec + tv.tv_usec;

	// int debug_array[40][30] = { 0 };

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

		if (status == -1) {
			printf("Breakpoint @ PC=%x, (%lu instructions so far)\n", sim.pc, instruction);

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
						// case 'd':
						// 	for (int y = 0; y < 30; ++y) {
						// 		for (int x = 0; x < 40; ++x) {
						// 			printf("%d", debug_array[x][y]);
						// 		}
						// 		printf("\n");
						// 	}
					default:
						break;
				}
			}
		} else if (status == -2) {
			// Ecall

			// debug_array[sim.x[29]][sim.x[30]] = sim.x[31];
			// printf("Debug: %d, %d, %d\n", sim.x[29], sim.x[30], sim.x[31]);
		}
	}

	EXIT = true;
	if (enable_leds | enable_vga | enable_hub75)
		pthread_join(sdl_thread_handle, NULL);

	rv_simulator_deinit(&sim);
	printf("Cleaned up simulator!\n");

	return 0;
}