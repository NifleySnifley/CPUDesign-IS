#include <soc_io.h>
#include <soc_core.h>

uint8_t buffer[256];

void flash_read_sector(int sector) {
    spi_set_hw_cs(true);

    spi_transfer_highspeed(0x03); // Read command
    spi_transfer_highspeed((sector >> 8) & 0xFF); // bits 23 to 16
    spi_transfer_highspeed(sector & 0xFF);        // bits 15 to 8
    spi_transfer_highspeed(0); // No LSB because page covers all LSB
    spi_transfer_highspeed(0); // No LSB because page covers all LSB

    for (int i = 0; i < 256; ++i) {
        buffer[i] = spi_transfer_highspeed(0xFF);
    }

    spi_set_hw_cs(false);
}

int main() {
    SPI_CONTROL = 1 << 2;
    flash_read_sector(0);

    while (1) {
        for (int i = 0; i < 256; i++) {
            PARALLEL_IO_B[0] = buffer[i];
            delay_ms(100);
        }

        // PARALLEL_IO_B[0] = buffer[1];
        // delay_ms(500);
    }


    return 0;
}