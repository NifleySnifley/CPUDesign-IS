#include <stdint.h>
#include <stdlib.h>
#include "soc_io.h"
#include "soc_core.h"

#define BIT(n) (1<<n)

#define IO_COLOR PARALLEL_IO_B[1]

#define IO_CTL PARALLEL_IO_B[2]
#define ROWSEL(r) (r&0b11111)
#define LATCH BIT(5)
#define OE BIT(6)

#define IO_CLK PARALLEL_IO_B[3]

void led(bool state) {
    PARALLEL_IO_B[0] = state;
}

void writeline() {
    IO_CTL = OE;

    // Clock out data
    for (int px = 0; px < 64; px++) {
        // TODO: Color here!
        IO_COLOR = 0b111111;
        IO_CLK = 0;
        IO_CLK = 1;
    }

    IO_CTL = LATCH | OE;
    IO_CTL = 0;
}

int main() {
    int n = 0;
    while (1) {
        // Write serial data to the line
        writeline();

        // Go through selecting lines
        for (int n = 0; n < 32; ++n) {
            IO_CTL = ROWSEL(n);
            // Wait a very little bit
            for (int i = 0; i < 64; ++i)
                asm("nop");
        }
        PARALLEL_IO_B[0] = 1 - PARALLEL_IO_B[0];

        // TODO: Make pong... or something!
    }

    return 0;
}