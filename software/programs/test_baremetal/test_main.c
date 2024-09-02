int main();
#include <stdint.h>

void __attribute__((section(".text.boot"))) _start() {
	// __asm__("addi sp,zero,200");
	main();
}

#define ANS_MEM (*((int32_t*)0x1100))

// Optimized shift-mult
uint32_t mul(uint32_t a, uint32_t b) {
	uint32_t tmp = 0;

	if (b > a) {
		tmp = a;
		a = b;
		b = tmp;
		tmp = 0;
	}

	while (b != 0) {
		if (b & 1) tmp += a;
		a <<= 1;
		b >>= 1;
	}
	return tmp;
}

uint32_t fact(uint32_t n) {
	if (n == 0) {
		return 1;
	} else {
		uint32_t flow = fact(n - 1);
		return mul(n, flow);
	}
}

int main() {
	uint32_t ans = fact(10);

	ANS_MEM = ans;

	// __asm__("ebreak");

	return 1;
}