import random

def b(n):
    return bin(n)[2:]

# def longdiv_bin(dividend, divisor):
#     result = 0

#     for bit_idx in range(32)[::-1]:
#         d = (divisor << bit_idx)
#         result <<= 1
#         if (dividend > d):
#             result |= 1
#             dividend -= d
        

#     remainder = dividend
#     return result, remainder

def longdiv_bin(dividend, divisor):
    remainder = 0
    quotient = 0

    # tb = 1<<32
    for _bi in range(32):
        remainder = (remainder<<1) | (1 if dividend&(1<<31) else 0)

        if (remainder >= divisor):
            remainder -= divisor
            quotient |= 1

        dividend <<= 1
        quotient <<= 1

        
    return quotient>>1, remainder

def mul_bin(a, b):
    result = 0

    while (a != 0):
        if (a&1):
            result += b
        a >>= 1
        b <<= 1
    return result


print(longdiv_bin(13, 3), (13//3,13%3))
# print(mul_bin(123, 4))


for t in range(1000):
    a,b = random.randint(0, 2**32-1), random.randint(1, 2**32-1)
    div, mod = longdiv_bin(a,b)
    assert (a//b) == div
    assert (a%b) == mod

    prod = mul_bin(a,b)
    assert a*b == prod