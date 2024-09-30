import math, random


def b(i, n=32):
    bl = bin(i & (2**n - 1))[2:]
    return bl.rjust(n, "0")


def divide_unsigned(dividend: int, divisor: int, NBITS=5) -> tuple[int, int]:
    # print(f"{b(divisor, NBITS)}|{b(dividend,NBITS)}")

    divisor <<= NBITS - 1
    remainder = dividend
    quotient = 0

    for bit in range(0, NBITS):
        # print(f"{b(remainder, NBITS)} - {b(divisor, NBITS)}")
        if divisor <= remainder:
            remainder = (remainder - divisor) & 0xFFFFFFFF
            quotient = (quotient << 1) | 1
        else:
            remainder = remainder
            quotient = quotient << 1

        divisor >>= 1

    return quotient & 0xFFFFFFFF, remainder


def divide_signed(dividend: int, divisor: int, NBITS=5) -> tuple[int, int]:
    dividend_u = abs(dividend)
    divisor_u = abs(divisor)
    quo, rem = divide_unsigned(dividend_u, divisor_u, NBITS=NBITS)

    quo_sign = 1 if ((dividend > 0) == (divisor > 0) or divisor == 0) else -1
    rem_sign = -1 if dividend < 0 else 1

    return (quo_sign * quo, rem_sign * rem)


def mod_real(a, b):
    modans = abs(a) % abs(b)
    return modans if a >= 0 else -modans


def ideal_ans(a: int, b: int):
    if b == 0:
        return (0xFFFFFFFF, a)
    else:
        return (math.trunc(a / b), mod_real(a, b))


for it in range(1000000):
    a = random.randint(-2147483648, 2147483647)
    b = random.randint(-2147483648, 2147483647)
    ans = ideal_ans(a, b)
    res = divide_signed(a, b, NBITS=32)
    # print(a, b, res, ans)
    assert ans == res

# test(173, -4, N=32)
