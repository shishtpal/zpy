# ZPy

A simple Python-like interpreter written in Zig.

## Features

### Data Types
- `int` - 64-bit integers
- `float` - 64-bit floating point numbers
- `string` - UTF-8 strings
- `bool` - `true` / `false`
- `none` - null value
- `list` - dynamic arrays `[1, 2, 3]`
- `dict` - hash maps `{"key": value}`

### Control Flow
- `if` / `elif` / `else` conditionals
- `while` loops
- `for x in collection` loops
- `break` / `continue` statements

### Operators
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `and`, `or`, `not`
- Assignment: `=`
- Indexing: `list[0]`, `dict["key"]`

### Built-in Functions
- `print(value)` - output to console
- `len(collection)` - get length
- `int(value)`, `float(value)`, `str(value)`, `bool(value)` - type conversion
- `range(start, end)` - generate number sequence
- `append(list, value)` - add to list
- `keys(dict)`, `values(dict)` - dict operations
- `type(value)` - get type name

## Building

Requires Zig 0.16.0 or later.

```bash
zig build
```

## Usage

### Run a file
```bash
zig build run -- examples/hello.zpy
```

### Start REPL
```bash
zig build run
```

## Example

```python
# Variables
name = "ZPy"
count = 10

# Lists
numbers = [1, 2, 3, 4, 5]
print("Numbers:", numbers)

# Conditionals
if count > 5:
    print("Large")
else:
    print("Small")

# Loops
for n in numbers:
    print(n * n)

# While with break
i = 0
while true:
    i = i + 1
    if i > 3:
        break
    print(i)
```

## Architecture

ZPy uses a tree-walking interpreter architecture:

1. **Lexer** - Tokenizes source code, handles Python-style indentation (INDENT/DEDENT tokens)
2. **Parser** - Recursive descent parser producing an AST
3. **Interpreter** - Directly evaluates the AST

## License

MIT
