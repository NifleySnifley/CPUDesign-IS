int main();
#include <stdint.h>

void __attribute__((section(".text.boot"))) _start() {
	// __asm__("addi sp,zero,200");
	main();
}

#define ANS_MEM (*((int32_t*)0x1100))

// This is big time stupid, but it works!!!
uint32_t mul(uint32_t a, uint32_t b) {
	uint32_t ans = 0;
	for (int i = 0; i < a; ++i) {
		ans += b;
	}
	return ans;
}

uint32_t fact(uint32_t n) {
	if (n == 0) {
		return 1;
	} else {
		uint32_t flow = fact(n - 1);
		return mul(n, flow);
		// return n * flow;
	}
}

int main() {
	uint32_t ans = fact(10);

	ANS_MEM = ans;

	__asm__("ebreak");

	return 1;
}