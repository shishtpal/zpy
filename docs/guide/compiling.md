# Compiling Scripts

ZPy can compile scripts to standalone native executables. This allows you to distribute your programs without requiring ZPy to be installed on the target machine.

## Compilation Modes

### `--compile` (Quick)

Creates a `.zig` file that references the interpreter source. Use this for development and testing.

```bash
zpy --compile script.zpy
zig build-exe script.zig -O ReleaseSmall
```

**Requirements:**
- Must run from the ZPy project directory (where `src/` exists)
- Or set `ZPY_HOME` environment variable

### `--standalone` (Portable)

Creates a complete portable package with embedded interpreter source.

```bash
zpy --standalone script.zpy
cd script_standalone
zig build-exe script.zig -O ReleaseSmall
```

**Requirements:**
- None - works from any directory

## ZPY_HOME Environment Variable

Setting `ZPY_HOME` enables compilation from any directory:

```bash
# Linux/macOS
export ZPY_HOME=/path/to/zpy

# Windows PowerShell
$env:ZPY_HOME = "D:\path\to\zpy"
```

### Behavior Matrix

| Mode | `ZPY_HOME` | Behavior |
|------|------------|----------|
| `--compile` | Not set | Creates `.zig` in current dir (must be in ZPy project) |
| `--compile` | Set | Creates `.zig` in `ZPY_HOME` directory |
| `--standalone` | Not set | Copies `src/` from current directory |
| `--standalone` | Set | Copies `src/` from `ZPY_HOME` |

## Output Name

Use `-o` or `--output` to specify the output name:

```bash
zpy --compile script.zpy -o myapp
# Creates: myapp.zig

zpy --standalone script.zpy -o myapp
# Creates: myapp_standalone/
```

## Optimizing Binary Size

For minimal binary size:

```bash
zig build-exe script.zig -O ReleaseSmall -fstrip -fsingle-threaded
```

| Flag | Effect |
|------|--------|
| `-O ReleaseSmall` | Optimize for size |
| `-fstrip` | Remove debug symbols |
| `-fsingle-threaded` | Single-threaded runtime |

## Distribution

For standalone packages, distribute the entire folder:

```bash
# Create archive
zip -r myapp.zip myapp_standalone/

# Recipients build with:
unzip myapp.zip
cd myapp_standalone
zig build-exe myapp.zig -O ReleaseSmall
```

## Example Session

```bash
$ zpy --standalone hello.zpy
Copying interpreter source from current directory...

Created standalone package: hello_standalone/
  hello.zig - Your compiled script
  src/     - Interpreter source

To compile:
  cd hello_standalone
  zig build-exe hello.zig -O ReleaseSmall

$ cd hello_standalone
$ zig build-exe hello.zig -O ReleaseSmall
$ ./hello
Welcome to ZPy version 0.1
```
