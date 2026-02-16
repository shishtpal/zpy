# Data Types

ZPy supports the following built-in data types.

## Primitive Types

### Integer

Arbitrary precision integers:

```python
x = 42
y = -17
big = 999999999999999999999999
```

### Float

64-bit floating point numbers:

```python
pi = 3.14159
e = 2.71828
negative = -1.5
```

### String

Text strings with escape sequences:

```python
name = "ZPy"
message = "Hello, World!"
escaped = "Line 1\nLine 2"
quoted = "She said \"Hello\""
```

### Boolean

True and false values:

```python
active = true
enabled = false
```

### None

Represents absence of value:

```python
result = none

def find_item(list, target):
    for item in list:
        if item == target:
            return item
    return none
```

## Collection Types

### List

Ordered, mutable sequences:

```python
numbers = [1, 2, 3, 4, 5]
mixed = [1, "two", 3.0, true]
empty = []

# Access
first = numbers[0]      # 1
last = numbers[-1]      # 5 (not yet implemented)

# Modify
numbers[0] = 10

# Methods
append(numbers, 6)      # Add element
len(numbers)            # Length

# Removing elements
del numbers[2]          # Remove by index (keyword)
delete(numbers, 1)      # Remove by index (function)
numbers.pop()           # Remove and return last element
numbers.pop(1)          # Remove and return element at index 1
numbers.remove(3)       # Remove first occurrence of value 3
```

### Dictionary

Key-value mappings:

```python
person = {
    "name": "Alice",
    "age": 30,
    "active": true
}

# Access
name = person["name"]   # "Alice"

# Modify
person["age"] = 31

# Add new key
person["city"] = "NYC"

# Removing elements
del person["active"]    # Remove by key (keyword)
delete(person, "city")  # Remove by key (function)
person.pop("age")       # Remove and return value

# Methods
keys(person)            # ["name", "age", "active", "city"]
values(person)          # ["Alice", 31, true, "NYC"]
len(person)             # 4
```

## Type Checking

Use `type()` to check the type of a value:

```python
type(42)        # "int"
type(3.14)      # "float"
type("hello")   # "string"
type(true)      # "bool"
type(none)      # "none"
type([1, 2])    # "list"
type({"a": 1})  # "dict"
```

## Type Conversion

```python
# To int
int("42")       # 42
int(3.7)        # 3

# To float
float("3.14")   # 3.14
float(42)       # 42.0

# To string
str(42)         # "42"
str(3.14)       # "3.14"
str(true)       # "true"

# To bool
bool(1)         # true
bool(0)         # false
bool("")        # false
bool("text")    # true
```
