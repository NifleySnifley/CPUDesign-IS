#ifndef SOC_IO_H
#define SOC_IO_H

#include <stdint.h>
#include "stdbool.h"

#define PARALLEL_IO *((volatile uint32_t*)0x80000000)
#define PARALLEL_IO_B ((volatile uint8_t*)0x80000000)
#define PARALLEL_IO_SIZE 4

#define GPIO_W ((volatile uint32_t*)0xA000)
#define GPIO_OE GPIO_W[0]
#define GPIO_OV GPIO_W[1]
#define GPIO_IV GPIO_W[2]

#define SPI_W ((volatile uint32_t*)0xD000)
#define SPI_B ((volatile uint8_t*)0xD000)
#define SPI_STATUS SPI_W[0]
#define SPI_CONTROL SPI_W[1]
#define SPI_DATA_TX SPI_B[8]
#define SPI_DATA_RX SPI_B[9]

#define SCREENBUFFER_B ((volatile uint8_t*)0x10000)
#define SCREENBUFFER_COLS 80
#define SCREENBUFFER_ROWS 30
#define SCREENBUFFER_SIZE (SCREENBUFFER_COLS*SCREENBUFFER_ROWS)

#define COLORBUFFER_W ((volatile uint32_t*)(0x10000+SCREENBUFFER_SIZE))
#define COLORBUFFER_COLS SCREENBUFFER_COLS
#define COLORBUFFER_ROWS SCREENBUFFER_ROWS
#define COLORBUFFER_SIZE (COLORBUFFER_COLS*COLORBUFFER_ROWS)
#define COLORBUFFER_DEPTH 6

#define COLOR_FG(b) ((uint32_t)(b&0b111111))
#define COLOR_BG(b) ((uint32_t)((b&0b111111) << 6))

#ifndef COLOR_SUPPORTED
#define COLOR_SUPPORTED false
#endif

#ifndef HUB75_MATRIX_WIDTH
#define HUB75_MATRIX_WIDTH 64
#endif

#ifndef HUB75_MATRIX_HEIGHT
#define HUB75_MATRIX_HEIGHT 64
#endif

#ifndef HUB75_N_BUFFERS
#define HUB75_N_BUFFERS 2
#endif

#define HUB75_COLOR_B ((volatile uint8_t*)0x81000000)
#define HUB75_COLOR_W ((volatile uint32_t*)0x81000000)
#define HUB75_CTL *((volatile uint32_t*)(0x81000000 + HUB75_MATRIX_WIDTH * HUB75_MATRIX_HEIGHT * 4 * HUB75_N_BUFFERS))

extern int stdout_row;
extern int stdout_col;

void printchar(char c);
int print(char* data);
int printn(char* data, int n);
int print_integer(int number);

void _reg_word_set_bit(volatile uint32_t* reg, uint32_t bit, bool state);

uint8_t spi_transfer(uint8_t data);
uint8_t spi_transfer_highspeed(uint8_t data);
// Returns output SPI clock frequency
uint32_t spi_set_clkdiv(uint32_t clkdiv);
void spi_set_hw_cs(bool active);

void gpio_set_output(uint32_t gpio_n, bool output_enable);
void gpio_set_level(uint32_t gpio_n, bool level);
bool gpio_get_level(uint32_t gpio_n);

typedef union hub75_color_t {
    uint32_t color;
    struct {
        uint8_t r, g, b;
    };
} hub75_color_t;

void hub75_select_buffer(int n);
void hub75_set_pixel(int x, int y, int buffer, hub75_color_t color);
uint8_t hub75_gamma_correct(int color_7bit);
hub75_color_t hub75_gamma_correct_color(hub75_color_t c);

#endif