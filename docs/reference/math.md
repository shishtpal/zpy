# Math Module

ZPy provides a `math` module with mathematical functions and constants, similar to Python's `math` module.

## Constants

| Function | Value | Description |
|----------|-------|-------------|
| `math_pi()` | 3.14159... | π (pi) |
| `math_e()` | 2.71828... | Euler's number |
| `math_tau()` | 6.28318... | τ (tau = 2π) |
| `math_inf()` | inf | Positive infinity |
| `math_nan()` | nan | Not a Number |

```python
print(math_pi())  # 3.141592653589793
print(math_e())   # 2.718281828459045
print(math_tau()) # 6.283185307179586
```

## Power and Logarithmic Functions

### math_sqrt(x)

Returns the square root of x.

```python
print(math_sqrt(16))   # 4.0
print(math_sqrt(2))    # 1.4142135623730951
```

### math_cbrt(x)

Returns the cube root of x.

```python
print(math_cbrt(27))   # 3.0
print(math_cbrt(8))    # 2.0
```

### math_exp(x)

Returns e raised to the power of x.

```python
print(math_exp(1))     # 2.7182818284590455
print(math_exp(0))     # 1.0
```

### math_expm1(x)

Returns e^x - 1. More accurate than `math_exp(x) - 1` for small x.

```python
print(math_expm1(0))   # 0.0
print(math_expm1(1))   # 1.7182818284590453
```

### math_log(x)

Returns the natural logarithm of x.

```python
print(math_log(math_e()))  # 1.0
print(math_log(1))         # 0.0
```

### math_log2(x)

Returns the base-2 logarithm of x.

```python
print(math_log2(8))    # 3.0
print(math_log2(1024)) # 10.0
```

### math_log10(x)

Returns the base-10 logarithm of x.

```python
print(math_log10(100)) # 2.0
print(math_log10(1000))# 3.0
```

### math_log1p(x)

Returns ln(1 + x). More accurate than `math_log(1 + x)` for small x.

```python
print(math_log1p(0))   # 0.0
print(math_log1p(1))   # 0.6931471805599453
```

## Trigonometric Functions

All trigonometric functions use radians.

### math_sin(x), math_cos(x), math_tan(x)

```python
print(math_sin(math_pi() / 2))  # 1.0
print(math_cos(0))              # 1.0
print(math_tan(math_pi() / 4))  # 1.0
```

### math_asin(x), math_acos(x), math_atan(x)

Inverse trigonometric functions. Return values in radians.

```python
print(math_asin(1))   # 1.5707963267948966 (π/2)
print(math_acos(0))   # 1.5707963267948966 (π/2)
print(math_atan(1))   # 0.7853981633974483 (π/4)
```

### math_atan2(y, x)

Returns the arc tangent of y/x in radians, using the signs of both arguments to determine the quadrant.

```python
print(math_atan2(1, 1))   # 0.7853981633974483 (π/4)
print(math_atan2(1, -1))  # 2.356194490192345 (3π/4)
```

## Hyperbolic Functions

### math_sinh(x), math_cosh(x), math_tanh(x)

```python
print(math_sinh(0))   # 0.0
print(math_cosh(0))   # 1.0
print(math_tanh(0))   # 0.0
```

### math_asinh(x), math_acosh(x), math_atanh(x)

Inverse hyperbolic functions.

```python
print(math_asinh(0))  # 0.0
print(math_acosh(1))  # 0.0
print(math_atanh(0))  # 0.0
```

## Rounding Functions

### math_floor(x)

Returns the largest integer less than or equal to x.

```python
print(math_floor(3.7))   # 3.0
print(math_floor(-3.2))  # -4.0
```

### math_ceil(x)

Returns the smallest integer greater than or equal to x.

```python
print(math_ceil(3.2))    # 4.0
print(math_ceil(-3.7))   # -3.0
```

### math_round(x)

Returns x rounded to the nearest integer.

```python
print(math_round(3.5))   # 4.0
print(math_round(3.4))   # 3.0
```

### math_trunc(x)

Returns x with the fractional part removed.

```python
print(math_trunc(3.9))   # 3.0
print(math_trunc(-3.9))  # -3.0
```

## Utility Functions

### math_fabs(x)

Returns the absolute value of x as a float.

```python
print(math_fabs(-5))     # 5.0
print(math_fabs(-3.14))  # 3.14
```

> **Note:** The builtin `abs(x)` returns int for int input, float for float input. `math_fabs` always returns float.

### math_fmod(x, y)

Returns the remainder of x / y.

```python
print(math_fmod(10, 3))  # 1.0
print(math_fmod(7, 2.5)) # 2.0
```

### math_modf(x)

Returns a list `[fractional, integer]` containing the fractional and integer parts of x.

```python
result = math_modf(3.14)
print(result[0])  # 0.14 (fractional)
print(result[1])  # 3.0 (integer)
```

### math_copysign(x, y)

Returns x with the sign of y.

```python
print(math_copysign(5, -1))   # -5.0
print(math_copysign(-5, 1))   # 5.0
```

### math_hypot(x, y)

Returns the Euclidean distance sqrt(x² + y²).

```python
print(math_hypot(3, 4))  # 5.0
print(math_hypot(5, 12)) # 13.0
```

## Example: Calculate Distance

```python
# Distance between two points
def distance(x1, y1, x2, y2):
    dx = x2 - x1
    dy = y2 - y1
    return math_hypot(dx, dy)

print(distance(0, 0, 3, 4))  # 5.0
```

## Example: Degrees to Radians

```python
def degrees_to_radians(degrees):
    return degrees * math_pi() / 180

print(math_sin(degrees_to_radians(90)))  # 1.0
```

## Summary Table

| Function | Description |
|----------|-------------|
| `math_sqrt(x)` | Square root |
| `math_cbrt(x)` | Cube root |
| `math_exp(x)` | e^x |
| `math_expm1(x)` | e^x - 1 |
| `math_log(x)` | Natural log |
| `math_log2(x)` | Base-2 log |
| `math_log10(x)` | Base-10 log |
| `math_log1p(x)` | ln(1+x) |
| `math_sin(x)` | Sine |
| `math_cos(x)` | Cosine |
| `math_tan(x)` | Tangent |
| `math_asin(x)` | Arc sine |
| `math_acos(x)` | Arc cosine |
| `math_atan(x)` | Arc tangent |
| `math_atan2(y, x)` | Arc tangent of y/x |
| `math_sinh(x)` | Hyperbolic sine |
| `math_cosh(x)` | Hyperbolic cosine |
| `math_tanh(x)` | Hyperbolic tangent |
| `math_asinh(x)` | Inverse hyperbolic sine |
| `math_acosh(x)` | Inverse hyperbolic cosine |
| `math_atanh(x)` | Inverse hyperbolic tangent |
| `math_floor(x)` | Round down |
| `math_ceil(x)` | Round up |
| `math_round(x)` | Round to nearest |
| `math_trunc(x)` | Truncate |
| `math_fabs(x)` | Absolute value (float) |
| `math_fmod(x, y)` | Remainder |
| `math_modf(x)` | Fractional and integer parts |
| `math_copysign(x, y)` | Copy sign |
| `math_hypot(x, y)` | Euclidean distance |
| `math_pi()` | π constant |
| `math_e()` | e constant |
| `math_tau()` | τ constant |
| `math_inf()` | Infinity |
| `math_nan()` | NaN |
