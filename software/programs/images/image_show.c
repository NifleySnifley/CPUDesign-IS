#include <soc_core.h>
#include <soc_io.h>
#include "monarch.h"
#include "peppers3.h"
#include "baboon.h"
#include "jellybeans.h"

void show_image(uint8_t* image_data) {
    for (int x = 0; x < SCREENBUFFER_COLS; ++x) {
        for (int y_2 = 0; y_2 < SCREENBUFFER_ROWS; ++y_2) {
            int idx_top = (y_2 * 2 + 0) * SCREENBUFFER_COLS + x;
            int idx_bot = (y_2 * 2 + 1) * SCREENBUFFER_COLS + x;

            COLORBUFFER_W[x + y_2 * SCREENBUFFER_COLS] = COLOR_FG(image_data[idx_top]) | COLOR_BG(image_data[idx_bot]);
        }
    }
}

int main() {
    for (int x = 0; x < SCREENBUFFER_COLS; ++x) {
        for (int y_2 = 0; y_2 < SCREENBUFFER_ROWS; ++y_2) {
            SCREENBUFFER_B[x + y_2 * SCREENBUFFER_COLS] = 1; // Top fg, bottom bg
        }
    }

    while (1) {
        // asm("ebreak");
        show_image(peppers3_data);
        // asm("ebreak");
        delay_ms(1000);
        show_image(monarch_data);
        delay_ms(1000);
        show_image(jellybeans_data);
        delay_ms(1000);
        show_image(baboon_data);
        delay_ms(1000);
    }
    return 0;
}