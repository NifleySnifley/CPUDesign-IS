#include <soc_io.h>
#include <soc_core.h>

uint8_t buffer[256];

void flash_read_sector(int sector) {
    spi_set_hw_cs(true);

    spi_transfer(0x03); // Read command
    spi_transfer((sector >> 8) & 0xFF); // bits 23 to 16
    spi_transfer(sector & 0xFF);        // bits 15 to 8
    spi_transfer(0); // No LSB because page covers all LSB

    for (int i = 0; i < 256; ++i) {
        buffer[i] = spi_transfer(0xFF);
    }

    spi_set_hw_cs(false);
}

int main() {
    SPI_CONTROL = 0;
    flash_read_sector(0);

    uint32_t* n_pages = (uint32_t*)&buffer[0];
    uint32_t* n_bytes = (uint32_t*)&buffer[4];

    while (1) {
        // PARALLEL_IO_B[0] = 0xAA;
        // delay_ms(500);
        // PARALLEL_IO_B[0] = *n_pages;
        // delay_ms(500);
        // PARALLEL_IO_B[0] = *n_bytes;
        // delay_ms(500);
        for (int i = 0; i < 256; ++i) {
            PARALLEL_IO_B[0] = buffer[i];
            delay_ms(100);
        }
    }


    return 0;
}