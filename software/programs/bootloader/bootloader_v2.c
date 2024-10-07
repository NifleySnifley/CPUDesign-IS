#include <soc_io.h>
#include <soc_core.h>

#define FLASH_CMD_READ 0x03
#define FLASH_N_SECTORS 512
#define FLASH_BYTES_PER_SECTOR 256

void flash_start_read_sector(int sector) {
	spi_transfer_highspeed(0x03); // Read command
	spi_transfer_highspeed((sector >> 8) & 0xFF); // bits 23 to 16
	spi_transfer_highspeed(sector & 0xFF);        // bits 15 to 8
	spi_transfer_highspeed(0); // No LSB because page covers all LSB
	spi_transfer_highspeed(0); // No LSB because page covers all LSB
}

void panic() {
	while (1) {
		// Angry blinky
		PARALLEL_IO_B[1] = 2;
		delay_ms(100);
		PARALLEL_IO_B[1] = 0;
		delay_ms(100);
	}
}

int main() {
	PARALLEL_IO_B[0] = 0;
	PARALLEL_IO_B[1] = 2;
	// Half-speed
	SPI_CONTROL = 0 << 2;

	uint32_t n_bytes = 0;
	uint32_t n_sectors = 0;

	spi_set_hw_cs(true);
	flash_start_read_sector(0);
	n_sectors |= spi_transfer_highspeed(0xFF);
	n_sectors |= spi_transfer_highspeed(0xFF) << 8;
	n_sectors |= spi_transfer_highspeed(0xFF) << 16;
	n_sectors |= spi_transfer_highspeed(0xFF) << 24;

	n_bytes |= spi_transfer_highspeed(0xFF);
	n_bytes |= spi_transfer_highspeed(0xFF) << 8;
	n_bytes |= spi_transfer_highspeed(0xFF) << 16;
	n_bytes |= spi_transfer_highspeed(0xFF) << 24;

	if (n_sectors >= FLASH_N_SECTORS || n_bytes >= (FLASH_BYTES_PER_SECTOR * FLASH_N_SECTORS)) panic();

	for (int i = 0; i < (FLASH_BYTES_PER_SECTOR - 8);++i) spi_transfer_highspeed(0xFF);
	spi_set_hw_cs(false);

	uint8_t* spram_ptr = (uint8_t*)SPRAM_BASE;

	// Read sectors into SPRAM
	for (int si = 0; si < n_sectors; si++) {
		spi_set_hw_cs(true);
		flash_start_read_sector(1 + si);
		for (int b = 0; b < FLASH_BYTES_PER_SECTOR;++b) {
			uint8_t byte = spi_transfer_highspeed(0xFF);
			*(spram_ptr++) = byte;
			if ((--n_bytes) <= 0) break;
		}
		spi_set_hw_cs(false);
	}

	PARALLEL_IO_B[1] = 0;
	// Wheeeee! Jump to SRAM
	asm(
		"li x1, 0xf0000000\n"
		"jr x1"
	);
}