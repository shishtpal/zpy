# CLI Reference

Complete reference for the ZPy command-line interface.

## Usage

```bash
zpy [OPTIONS] [FILE]
```

## Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version information |
| `-i, --interactive` | Run file then enter REPL |
| `-c, --code <CODE>` | Execute code string and exit |
| `--tokens` | Dump tokens (for debugging) |
| `--ast` | Dump AST (for debugging) |
| `--compile` | Compile script to .zig file |
| `--standalone` | Create portable package |
| `-o, --output <NAME>` | Output name for compiled executable |
| `repl` | Start interactive REPL |

## Commands

### Run a Script

```bash
zpy script.zpy
```

### Start REPL

```bash
zpy           # Start REPL
zpy repl      # Explicit REPL command
```

### Execute Code String

```bash
zpy -c "print(1 + 2)"
zpy --code "print('Hello')"
```

### Run Script Then REPL

```bash
zpy -i script.zpy
```

Useful for debugging - script runs, then you can inspect variables interactively.

## Compilation

### Quick Compile

```bash
zpy --compile script.zpy
zig build-exe script.zig -O ReleaseSmall
```

Creates a `.zig` file that references the interpreter. Must run from ZPy project directory.

### Portable Package

```bash
zpy --standalone script.zpy
cd script_standalone
zig build-exe script.zig -O ReleaseSmall
```

Creates a self-contained folder with embedded interpreter source.

### Custom Output Name

```bash
zpy --compile script.zpy -o myapp
zpy --standalone script.zpy -o myapp
```

## Debugging

### Dump Tokens

```bash
zpy --tokens script.zpy
```

Shows the token stream from the lexer:

```
TOKEN: { type: NAME, value: 'x', line: 1 }
TOKEN: { type: EQUAL, value: '=', line: 1 }
TOKEN: { type: NUMBER, value: '10', line: 1 }
TOKEN: { type: EOF, value: '', line: 1 }
```

### Dump AST

```bash
zpy --ast script.zpy
```

Shows the abstract syntax tree:

```
Program
└── VarDecl { name: 'x', value: Number(10) }
```

## Environment Variables

### ZPY_HOME

Points to the ZPy installation directory.

```bash
# Linux/macOS
export ZPY_HOME=/path/to/zpy

# Windows PowerShell
$env:ZPY_HOME = "D:\path\to\zpy"
```

**Effects:**

| Mode | ZPY_HOME Set | Behavior |
|------|--------------|----------|
| `--compile` | No | Output to current dir (must be in ZPy project) |
| `--compile` | Yes | Output to ZPY_HOME directory |
| `--standalone` | No | Copy src/ from current directory |
| `--standalone` | Yes | Copy src/ from ZPY_HOME |

## Examples

### Basic Usage

```bash
# Run a script
zpy hello.zpy

# Quick calculation
zpy -c "print(2 ** 10)"

# Interactive exploration
zpy -i data_processing.zpy
```

### Development

```bash
# Debug tokenization
zpy --tokens script.zpy

# Debug parsing
zpy --ast script.zpy

# Test in REPL
zpy -c "def test(): return 42" -i
```

### Distribution

```bash
# Create portable package
zpy --standalone myapp.zpy -o myapp
cd myapp_standalone
zig build-exe myapp.zig -O ReleaseSmall -fstrip -fsingle-threaded

# Distribute the entire myapp_standalone/ folder
```
