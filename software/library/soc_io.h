#ifndef SOC_IO_H
#define SOC_IO_H

#include <stdint.h>
#include "stdbool.h"

#define PARALLEL_IO *((volatile uint32_t*)0xf000)
#define PARALLEL_IO_B ((volatile uint8_t*)0xf000)
#define PARALLEL_IO_SIZE 4

#define GPIO_W ((volatile uint32_t*)0xA000)
#define GPIO_OE GPIO_W[0]
#define GPIO_OV GPIO_W[1]
#define GPIO_IV GPIO_W[2]

#define SPI_W ((volatile uint32_t*)0xD000)
#define SPI_B ((volatile uint8_t*)0xD000)
#define SPI_STATUS SPI_W[0]
#define SPI_CONTROL SPI_W[0]
#define SPI_DATA_TX SPI_B[8]
#define SPI_DATA_RX SPI_B[9]

#define SCREENBUFFER_B ((volatile uint8_t*)0x10000)
#define SCREENBUFFER_COLS 80
#define SCREENBUFFER_ROWS 30
#define SCREENBUFFER_SIZE (SCREENBUFFER_COLS*SCREENBUFFER_ROWS)

extern int stdout_row;
extern int stdout_col;

void printchar(char c);
int print(char* data);
int printn(char* data, int n);
int print_integer(int number);

void _reg_word_set_bit(volatile uint32_t* reg, uint32_t bit, bool state);

uint8_t spi_transfer(uint8_t data);
// Returns output SPI clock frequency
uint32_t spi_set_clkdiv(uint32_t clkdiv);

void gpio_set_output(uint32_t gpio_n, bool output_enable);
void gpio_set_level(uint32_t gpio_n, bool level);
bool gpio_get_level(uint32_t gpio_n);

#endif