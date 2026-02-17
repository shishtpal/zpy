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
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `**` (power)
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `and`, `or`, `not`
- Assignment: `=`, `+=`, `-=`, `*=`, `/=`, `%=`
- Indexing: `list[0]`, `dict["key"]`

### Built-in Functions
- `print(value)` - output to console
- `len(collection)` - get length
- `int(value)`, `float(value)`, `str(value)`, `bool(value)` - type conversion
- `range(start, end)` - generate number sequence
- `append(list, value)` - add to list
- `delete(list, index)`, `delete(dict, key)` - remove items
- `keys(dict)`, `values(dict)` - dict operations
- `type(value)` - get type name

### File System
- `file_read(path)`, `file_write(path, content)`, `file_append(path, content)`
- `file_delete(path)`, `file_exists(path)`
- `dir_list(path)`, `dir_create(path)`, `dir_exists(path)`

### OS Module
- Working directory: `os_getcwd()`, `os_chdir(path)`
- File ops: `os_rename()`, `os_copy()`, `os_stat()`, `os_remove()`
- Directory ops: `os_mkdir()`, `os_rmdir()`, `os_walk()`
- Path ops: `os_path_join()`, `os_path_exists()`, `os_path_isdir()`, etc.
- Environment: `os_getenv()`, `os_setenv()`, `os_environ()`

### Data Formats
- JSON: `json_parse()`, `json_stringify()`
- CSV: `csv_parse()`, `csv_stringify()`
- YAML: `yaml_parse()`, `yaml_stringify()`

### HTTP Client
- `http_get(url)`, `http_post(url, body)`, `http_request(url, options)`

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

# Power operator
print(2 ** 10)  # 1024

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

# File operations
file_write("test.txt", "Hello, World!")
content = file_read("test.txt")
print(content)

# HTTP request
response = http_get("https://api.github.com")
print(response)
```

## Architecture

ZPy uses a tree-walking interpreter architecture:

1. **Lexer** - Tokenizes source code, handles Python-style indentation (INDENT/DEDENT tokens)
2. **Parser** - Recursive descent parser producing an AST
3. **Interpreter** - Directly evaluates the AST

## License

MIT
