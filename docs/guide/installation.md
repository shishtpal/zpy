# Installation

## Requirements

- **Zig 0.14+** - ZPy uses the latest Zig standard library

## Building from Source

### Clone the Repository

```bash
git clone https://github.com/shishtpal/zpy.git
cd zpy
```

### Build

```bash
zig build
```

The executable will be at `zig-out/bin/zpy`.

### Run Tests

```bash
zig build test
```

## Installation Options

### Add to PATH (Linux/macOS)

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export PATH="$PATH:/path/to/zpy/zig-out/bin"
```

### Add to PATH (Windows)

```powershell
# Add to your PowerShell profile
$env:PATH += ";D:\path\to\zpy\zig-out\bin"
```

Or add to System Environment Variables via Windows Settings.

### Set ZPY_HOME (Optional)

Set `ZPY_HOME` to enable compilation from any directory:

```bash
# Linux/macOS
export ZPY_HOME=/path/to/zpy

# Windows PowerShell
$env:ZPY_HOME = "D:\path\to\zpy"
```

## Verify Installation

```bash
zpy --version
# Output: ZPy 0.1.0
```

## Development Build

For development with debug symbols:

```bash
zig build -Doptimize=Debug
```
