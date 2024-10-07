#include <stdlib.h>
#include <stdint.h>
#include <qrcodegen.h>
#include <soc_core.h>
#include <soc_io.h>

// Prints the given QR Code to the console.
static void printQr(const uint8_t qrcode[]) {
	int size = qrcodegen_getSize(qrcode);
	// TODO: Use the double pixel format to print more efficiently
	// for (int y = -border; y < size + border; y++) {
	// 	for (int x = -border; x < size + border; x++) {
	// 		print((qrcodegen_getModule(qrcode, x, y) ? pixel : "  "));
	// 	}
	// 	print("\n");
	// }
	// print("\n");

	// stdout_col = 0;
	// stdout_row = 0;
	// for (int y = 0; y < size / 2; ++y) {
	// 	for (int x = 0; x < size; ++x) {
	// 		char c = qrcode[(y * 2) * size + x] ? 1 : 0;
	// 		// if ((y * 2 + 1) < size) {
	// 		// 	c |= qrcode[(y * 2 + 1) * size + x] ? 2 : 0;
	// 		// }
	// 		printchar(c);
	// 	}
	// 	printchar('\n');
	// }

	for (int x = 0; x < size; ++x) {
		for (int y_2 = 0; y_2 < size / 2 + 1; ++y_2) {
			if (y_2 == (size / 2 - 1) && x < (stdout_col - 1)) continue;
			uint8_t high = qrcodegen_getModule(qrcode, x, (y_2 * 2));
			uint8_t low = qrcodegen_getModule(qrcode, x, (y_2 * 2 + 1));
			SCREENBUFFER_B[x + y_2 * SCREENBUFFER_COLS] = (high | (low << 1));
		}
	}
}


int main() {
	const char* text = "https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.youtube.com/watch%3Fv%3DdQw4w9WgXcQ&ved=2ahUKEwjowJTn-vyIAxV5rYkEHXPSCH8QyCl6BAgwEAM&usg=AOvVaw0aHtehaphMhOCAkCydRLZU";                // User-supplied text
	enum qrcodegen_Ecc errCorLvl = qrcodegen_Ecc_LOW;  // Error correction level

	// Make and print the QR Code symbol
	uint8_t qrcode[qrcodegen_BUFFER_LEN_MAX];
	uint8_t tempBuffer[qrcodegen_BUFFER_LEN_MAX];
	bool ok = qrcodegen_encodeText(text, tempBuffer, qrcode, errCorLvl,
		qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX, qrcodegen_Mask_AUTO, true);
	if (ok)
		printQr(qrcode);

	asm("ebreak");

	while (1) {
		PARALLEL_IO_B[0] = 0xAA;
		delay_ms(500);
		PARALLEL_IO_B[0] = 0x55;
		delay_ms(500);
	}
	return 0;
}