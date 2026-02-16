# Built-in Functions

ZPy provides the following built-in functions.

> **Note:** For file system operations, see [File System](/reference/filesystem).

## Output

### print(values...)

Prints values to stdout, separated by spaces.

```python
print("Hello, World!")
print(1, 2, 3)           # 1 2 3
print("x =", 5)          # x = 5
```

## Type Functions

### type(value)

Returns the type name as a string.

```python
type(42)        # "int"
type(3.14)      # "float"
type("hello")   # "string"
type(true)      # "bool"
type(none)      # "none"
type([1, 2])    # "list"
type({"a": 1})  # "dict"
```

### len(value)

Returns the length of a string, list, or dictionary.

```python
len("hello")        # 5
len([1, 2, 3])      # 3
len({"a": 1, "b": 2})  # 2
```

## Type Conversion

### int(value)

Converts a value to an integer.

```python
int("42")       # 42
int(3.7)        # 3
int(true)       # 1
int(false)      # 0
```

### float(value)

Converts a value to a float.

```python
float("3.14")   # 3.14
float(42)       # 42.0
```

### str(value)

Converts a value to a string.

```python
str(42)         # "42"
str(3.14)       # "3.14"
str(true)       # "true"
str([1, 2])     # "[1, 2]"
```

### bool(value)

Converts a value to a boolean.

```python
bool(1)         # true
bool(0)         # false
bool("")        # false
bool("text")    # true
bool([])        # false
bool([1])       # true
```

## List Functions

### append(list, value)

Appends a value to the end of a list.

```python
items = [1, 2, 3]
append(items, 4)
# items is now [1, 2, 3, 4]
```

### delete(list, index) / delete(dict, key)

Removes an item from a list by index, or a key from a dictionary.

```python
# List
items = [1, 2, 3, 4]
delete(items, 1)   # items is now [1, 3, 4]

# Dictionary
data = {"a": 1, "b": 2}
delete(data, "a")  # data is now {"b": 2}
```

## Dictionary Functions

### keys(dict)

Returns a list of keys in the dictionary.

```python
person = {"name": "Alice", "age": 30}
keys(person)  # ["name", "age"]
```

### values(dict)

Returns a list of values in the dictionary.

```python
person = {"name": "Alice", "age": 30}
values(person)  # ["Alice", 30]
```

## Iteration

### range(stop)

Returns an iterator from 0 to stop-1.

```python
for i in range(5):
    print(i)  # 0, 1, 2, 3, 4
```

### range(start, stop)

Returns an iterator from start to stop-1.

```python
for i in range(2, 6):
    print(i)  # 2, 3, 4, 5
```

### range(start, stop, step)

Returns an iterator with a custom step.

```python
for i in range(0, 10, 2):
    print(i)  # 0, 2, 4, 6, 8

for i in range(10, 0, -1):
    print(i)  # 10, 9, 8, ..., 1
```

## Summary Table

| Function | Description |
|----------|-------------|
| `print(...)` | Print values to stdout |
| `type(x)` | Get type name |
| `len(x)` | Get length |
| `int(x)` | Convert to integer |
| `float(x)` | Convert to float |
| `str(x)` | Convert to string |
| `bool(x)` | Convert to boolean |
| `append(list, val)` | Append to list |
| `delete(list, idx)` | Remove item at index from list |
| `delete(dict, key)` | Remove key from dictionary |
| `keys(dict)` | Get dictionary keys |
| `values(dict)` | Get dictionary values |
| `range(...)` | Create number iterator |
