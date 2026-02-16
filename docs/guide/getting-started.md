# Getting Started

ZPy is a Python-like language interpreter written in Zig. This guide will help you get up and running quickly.

## What is ZPy?

ZPy is a lightweight scripting language that offers:

- **Python-like syntax** - Familiar and easy to learn
- **Fast execution** - Built with Zig, no garbage collection
- **Standalone executables** - Compile scripts to native binaries
- **Embeddable** - Use as a scripting engine in your Zig projects

## Quick Start

### 1. Build ZPy

```bash
git clone https://github.com/shishtpal/zpy.git
cd zpy
zig build
```

### 2. Run Your First Script

Create a file `hello.zpy`:

```python
name = "ZPy"
version = 0.1
print("Welcome to", name, "version", version)
```

Run it:

```bash
./zig-out/bin/zpy hello.zpy
```

### 3. Try the REPL

Start an interactive session:

```bash
./zig-out/bin/zpy
```

```
ZPy 0.1.0
>>> x = 10
>>> y = 20
>>> print(x + y)
30
>>> exit()
```

## Next Steps

- [Installation](/guide/installation) - Detailed installation instructions
- [Compiling Scripts](/guide/compiling) - Create standalone executables
- [Language Syntax](/language/syntax) - Learn the language
