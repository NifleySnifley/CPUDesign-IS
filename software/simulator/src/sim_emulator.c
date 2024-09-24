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

#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480

static volatile bool EXIT = false;

void* leds_window_thread_fn(void* arg) {
	rv_simulator_t* sim = (rv_simulator_t*)arg;

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		printf("SDL could not be initialized!\n"
			"SDL_Error: %s\n", SDL_GetError());
		return 0;
	}

	const int LED_SIZE = 32;

	// Disable compositor bypass
	if (!SDL_SetHint(SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR, "0")) {
		printf("SDL can not disable compositor bypass!\n");
		return 0;
	}

	SDL_Window* window = SDL_CreateWindow("LED Matrix",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		LED_SIZE * 8, LED_SIZE * 4,
		SDL_WINDOW_SHOWN);
	if (!window) {
		printf("Window could not be created!\n"
			"SDL_Error: %s\n", SDL_GetError());
	} else {
		SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
		if (!renderer) {
			printf("Renderer could not be created!\n"
				"SDL_Error: %s\n", SDL_GetError());
		} else {
			printf("Opened LED Matrix GUI\n");

			SDL_Rect squareRect;

			uint8_t led_state[4] = { 0 };

			squareRect.w = LED_SIZE;
			squareRect.h = LED_SIZE;

			// squareRect.x = SCREEN_WIDTH / 2 - squareRect.w / 2;
			squareRect.y = 0;

			// Event loop
			while (!EXIT) {
				SDL_Event e;
				if (SDL_PollEvent(&e)) {
					if (e.type == SDL_QUIT) {
						EXIT = true;
					}
				}

				SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
				SDL_RenderClear(renderer);

				uint8_t led_row = rv_simulator_read_byte(sim, 0xf000);
				uint8_t led_row_select = rv_simulator_read_byte(sim, 0xf001);

				for (int r = 0; r < 4; ++r) {
					if (led_row_select & (1 << r))
						led_state[r] = led_row;


					for (int i = 0; i < 8; ++i) {
						squareRect.x = LED_SIZE * i;
						squareRect.y = LED_SIZE * r;
						if ((led_state[r] >> i) & 1) {
							SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF);
						} else {
							SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
						}
						SDL_RenderFillRect(renderer, &squareRect);
					}
				}

				SDL_RenderPresent(renderer);
			}

			EXIT = true;
			SDL_DestroyRenderer(renderer);
		}

		SDL_DestroyWindow(window);
	}

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

	bool enable_leds = false;
	bool enable_vga = false;
	bool enable_buttons = false;

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
	rv_simulator_segmented_memory_add_segment(memory, 0xf0000000, 16384 * 2 * 4, "SPRAM", false);

	int nmem = rv_simulator_load_memory_from_file(&sim, program_filename);
	printf("Loaded %d bytes into main memory\n", nmem);

	pthread_t led_thread_handle;

	if (enable_leds)
		pthread_create(&led_thread_handle, NULL, leds_window_thread_fn, (void*)&sim);


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

			printf("Press 'c' key to continue, 'r' to print registers, 'm' to print memory, ctrl-C to exit.\n");
			while (1) {
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
	if (enable_leds)
		pthread_join(led_thread_handle, NULL);

	rv_simulator_deinit(&sim);
	printf("Cleaned up simulator!\n");

	return 0;
}