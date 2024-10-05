#include <string.h>
#include "soc_io.h"
#include "soc_core.h"
#include <stdbool.h>
#include <stdint.h>

int stdout_row = 0;
int stdout_col = 0;

void printchar(char c) {
	int stdout_idx = stdout_row * SCREENBUFFER_COLS + stdout_col;

	if (c == '\r') {
		stdout_col = 0; // Start of line
	} else if (c == '\n') {
		stdout_col = 0; // Start of line
		stdout_row = (stdout_row + 1) % SCREENBUFFER_ROWS;
	} else {
		SCREENBUFFER_B[stdout_idx] = c;
		stdout_col++;
	}

	if (stdout_col >= SCREENBUFFER_COLS) {
		stdout_col = 0;
		stdout_row = (stdout_row + 1) % SCREENBUFFER_ROWS;
	}
}

int printn(char* data, int n) {
	for (int count = 0; count < n; count++) {
		printchar(data[count]);
	}

	return n;
}

int print(char* data) {
	return printn(data, strlen(data));
}

int print_integer(int number) {
	bool neg = number < 0;
	if (neg) number *= -1;

	int n = 10;
	char str[11]; // Assuming 32 bit int

	do {
		int digit = number % 10;
		str[n--] = '0' + digit;
		number /= 10;
	} while (number > 0);

	if (neg)
		str[n--] = '-';
	printn(&str[n + 1], 11 - n);
	return n;
}

uint8_t spi_transfer(uint8_t data) {
	SPI_DATA_TX = data;
	SPI_CONTROL = SPI_CONTROL | 1; // Set TX bit
	// Wait for TX done
	while ((SPI_STATUS & 1) == 0) {
		asm("nop");
	}
	uint8_t rx = SPI_DATA_RX;
	SPI_CONTROL = SPI_CONTROL & (~1); // Clear TX bit
	return rx; // Could maybe just return SPI_DATA_RX but just makin sure
}

#define SPI_CONTROL_CLKDIV_MASK (0xFFFFFFFF ^ 0b11)
// Returns output SPI clock frequency
uint32_t spi_set_clkdiv(uint32_t clkdiv) {
	SPI_CONTROL = (SPI_CONTROL & ~SPI_CONTROL_CLKDIV_MASK) | (clkdiv << 2);
	return F_CPU / clkdiv;
}

void _reg_word_set_bit(volatile uint32_t* reg, uint32_t bit, bool state) {
	if (bit < 32) {
		uint32_t oe_v = *reg;
		uint32_t pin = 1 << bit;
		if (state)
			oe_v |= (pin);
		else
			oe_v &= (~pin);
		*reg = oe_v;
	}
}

void gpio_set_output(uint32_t gpio_n, bool output_enable) {
	_reg_word_set_bit(&GPIO_OE, gpio_n, output_enable);
}

void gpio_set_level(uint32_t gpio_n, bool level) {
	_reg_word_set_bit(&GPIO_OV, gpio_n, level);
}

bool gpio_get_level(uint32_t gpio_n) {
	if (gpio_n < 32) {
		return (GPIO_IV >> gpio_n) & 1;
	} else {
		return false;
	}
}