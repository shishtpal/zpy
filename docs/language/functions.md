# Functions

Functions in ZPy are defined using the `def` keyword.

## Basic Functions

```python
def greet():
    print("Hello, World!")

greet()  # Hello, World!
```

## Parameters

```python
def greet(name):
    print("Hello,", name)

greet("Alice")  # Hello, Alice
greet("Bob")    # Hello, Bob
```

### Multiple Parameters

```python
def add(a, b):
    return a + b

result = add(3, 5)  # 8
```

### Default Parameters

Not yet supported.

## Return Values

Use `return` to return a value:

```python
def square(x):
    return x * x

result = square(5)  # 25
```

### Early Return

```python
def abs(x):
    if x < 0:
        return -x
    return x

abs(-5)   # 5
abs(5)    # 5
```

### Multiple Return Values

Not yet supported directly. Use a list instead:

```python
def minmax(items):
    return [min(items), max(items)]

bounds = minmax([3, 1, 4, 1, 5])
# bounds[0] = 1, bounds[1] = 5
```

## No Return Value

Functions without `return` return `none`:

```python
def log(message):
    print("[LOG]", message)

result = log("test")  # Prints message
# result is none
```

## Recursion

Functions can call themselves:

```python
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

factorial(5)  # 120
factorial(10) # 3628800
```

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

fibonacci(10)  # 55
```

## Closures

Functions can capture variables from outer scope:

```python
def make_counter():
    count = 0
    def counter():
        count = count + 1  # Note: may not work as expected
        return count
    return counter

# Note: Full closure support is limited
```

## Higher-Order Functions

Functions can be passed as values (limited support):

```python
def apply(func, x):
    return func(x)

def double(x):
    return x * 2

apply(double, 5)  # 10
```

## Examples

### Utility Functions

```python
def clamp(value, min_val, max_val):
    if value < min_val:
        return min_val
    if value > max_val:
        return max_val
    return value

clamp(5, 0, 10)   # 5
clamp(-5, 0, 10)  # 0
clamp(15, 0, 10)  # 10
```

### String Functions

```python
def repeat(s, n):
    result = ""
    for i in range(n):
        result = result + s
    return result

repeat("ab", 3)  # "ababab"
```

### List Functions

```python
def sum_list(items):
    total = 0
    for item in items:
        total += item
    return total

sum_list([1, 2, 3, 4, 5])  # 15
```
