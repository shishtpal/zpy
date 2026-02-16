# REPL

The ZPy REPL (Read-Eval-Print Loop) provides an interactive environment for experimenting with ZPy code.

## Starting the REPL

```bash
# Start REPL directly
zpy

# Or explicitly
zpy repl

# Or with -i flag
zpy -i
```

## REPL Features

### Multi-line Input

The REPL automatically detects incomplete statements and continues on the next line:

```
>>> def greet(name):
...     print("Hello,", name)
...
>>> greet("World")
Hello, World
```

### Run File Then REPL

Use `-i` to run a script and then enter the REPL:

```bash
zpy -i script.zpy
```

This is useful for debugging - you can inspect variables after the script runs:

```
# script.zpy
x = 10
y = 20

$ zpy -i script.zpy
Script executed. Entering REPL...
>>> x
10
>>> y
20
>>> x + y
30
```

## REPL Commands

| Command | Description |
|---------|-------------|
| `exit()` | Exit the REPL |
| `Ctrl+C` | Cancel current input |
| `Ctrl+D` | Exit REPL (Unix) |

## Tips

### Quick Calculations

```
>>> 2 ** 10
1024
>>> 100 / 7
14.285714285714286
```

### Test Functions

```
>>> def factorial(n):
...     if n <= 1:
...         return 1
...     return n * factorial(n - 1)
...
>>> factorial(5)
120
>>> factorial(10)
3628800
```

### Inspect Values

```
>>> items = [1, 2, 3, 4, 5]
>>> len(items)
5
>>> type(items)
list
```
