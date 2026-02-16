# Compiling ZPy Scripts to Executables

ZPy supports two compilation modes for creating standalone executables from your scripts.

## Compilation Modes

### `--compile` (Quick, Local)

Creates a `.zig` file that references the interpreter source via relative paths.

- **Output**: `{name}.zig` in current directory (or `ZPY_HOME` if set)
- **Requirement**: Must compile from ZPy project directory (where `src/` exists)
- **Use case**: Development, quick testing

```bash
zpy --compile script.zpy
zig build-exe script.zig -O ReleaseSmall
```

### `--standalone` (Portable, Self-Contained)

Creates a complete portable package with embedded interpreter source.

- **Output**: `{name}_standalone/` folder containing:
  - `{name}.zig` - your compiled script
  - `src/` - interpreter source copy
- **Requirement**: None - works from any directory
- **Use case**: Distribution, deployment

```bash
zpy --standalone script.zpy
cd script_standalone
zig build-exe script.zig -O ReleaseSmall
```

## Environment Variable

### `ZPY_HOME`

Optional. Points to your ZPy installation directory.

| Mode | `ZPY_HOME` | Behavior |
|------|------------|----------|
| `--compile` | Not set | Creates `.zig` in current dir (must be in ZPy project) |
| `--compile` | Set | Creates `.zig` in `ZPY_HOME` directory |
| `--standalone` | Not set | Copies `src/` from current directory |
| `--standalone` | Set | Copies `src/` from `ZPY_HOME` |

**Setup (optional):**
```bash
# Linux/macOS
export ZPY_HOME=/path/to/zpy

# Windows PowerShell
$env:ZPY_HOME = "D:\path\to\zpy"

# Windows CMD
set ZPY_HOME=D:\path\to\zpy
```

**Usage from anywhere:**
```bash
zpy --standalone /any/path/to/script.zpy
# Creates script_standalone/ in current directory
```

## Example

### Step 1: Compile to Zig

```log
> zpy --standalone hello.zpy
Copying interpreter source from current directory...

Created standalone package: hello_standalone/
  hello.zig - Your compiled script
  src/     - Interpreter source

To compile:
  cd hello_standalone
  zig build-exe hello.zig -O ReleaseSmall
```

### Step 2: Build Executable

```log
> cd hello_standalone
> zig build-exe hello.zig -O ReleaseSmall
> ./hello.exe
Welcome to ZPy version 0.1
```

## Distribution

For `--standalone` mode, distribute the entire `{name}_standalone/` folder:

```bash
# Create distributable archive
zip -r myapp.zip myapp_standalone/

# Recipients can build with:
unzip myapp.zip
cd myapp_standalone
zig build-exe myapp.zig -O ReleaseSmall
```

## Smaller Binaries

For minimal binary size:
```bash
zig build-exe script.zig -O ReleaseSmall -fstrip -fsingle-threaded
```
