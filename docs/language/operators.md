# Operators

ZPy supports various operators for computations and comparisons.

## Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `1 + 2` → `3` |
| `-` | Subtraction | `5 - 3` → `2` |
| `*` | Multiplication | `4 * 3` → `12` |
| `/` | Division | `10 / 4` → `2.5` |
| `%` | Modulo | `10 % 3` → `1` |

```python
a = 10 + 5     # 15
b = 10 - 3     # 7
c = 4 * 5      # 20
d = 15 / 4     # 3.75
e = 17 % 5     # 2
```

## Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `5 == 5` → `true` |
| `!=` | Not equal | `5 != 3` → `true` |
| `<` | Less than | `3 < 5` → `true` |
| `>` | Greater than | `5 > 3` → `true` |
| `<=` | Less or equal | `3 <= 3` → `true` |
| `>=` | Greater or equal | `5 >= 5` → `true` |

```python
x = 10
x == 10    # true
x != 5     # true
x < 20     # true
x > 5      # true
x <= 10    # true
x >= 10    # true
```

## Logical Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `and` | Logical AND | `true and false` → `false` |
| `or` | Logical OR | `true or false` → `true` |
| `not` | Logical NOT | `not true` → `false` |

```python
a = true
b = false

a and b    # false
a or b     # true
not a      # false
not b      # true
```

## Assignment Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Assign | `x = 5` |
| `+=` | Add and assign | `x += 3` |
| `-=` | Subtract and assign | `x -= 2` |
| `*=` | Multiply and assign | `x *= 2` |
| `/=` | Divide and assign | `x /= 2` |
| `%=` | Modulo and assign | `x %= 3` |

```python
x = 10
x += 5     # x = 15
x -= 3     # x = 12
x *= 2     # x = 24
x /= 4     # x = 6.0
x %= 4     # x = 2.0
```

## String Operations

```python
# Concatenation
greeting = "Hello" + " " + "World"

# In expressions
name = "ZPy"
msg = "Welcome to " + name
```

## List Operations

```python
# Indexing
items = [1, 2, 3, 4, 5]
first = items[0]     # 1

# Assignment
items[0] = 10        # [10, 2, 3, 4, 5]
```

## Operator Precedence

From highest to lowest:

1. Parentheses `()`
2. Multiplication, Division, Modulo `*`, `/`, `%`
3. Addition, Subtraction `+`, `-`
4. Comparison `==`, `!=`, `<`, `>`, `<=`, `>=`
5. Logical NOT `not`
6. Logical AND `and`
7. Logical OR `or`

```python
result = 2 + 3 * 4      # 14 (not 20)
result = (2 + 3) * 4    # 20
```
