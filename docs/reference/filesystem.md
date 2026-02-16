# File System Built-ins

ZPy provides built-in functions for file system operations.

> **Note:** For additional OS utilities (working directory, path operations, environment variables, etc.), see [OS Module](/reference/os).

## Special Variables

### `__file__`

The path of the currently running script.

```python
print("Running from:", __file__)
# Output: Running from: ./examples/script.zpy
```

### `__dir__`

The directory containing the currently running script. Use this to reference files relative to the script's location.

```python
# Read a file next to the script
content = file_read(__dir__ + "/data.txt")
```

This is especially useful when running scripts from different directories:

```bash
# Both of these work correctly now:
zpy ./examples/script.zpy
cd examples && zpy script.zpy
```

## File Operations

### file_read(path)

Reads the contents of a file. Returns `none` if the file doesn't exist.

```python
content = file_read("data.txt")
if content:
    print(content)
else:
    print("File not found or empty")
```

### file_write(path, content)

Writes content to a file. Creates the file if it doesn't exist, overwrites if it does.

```python
file_write("output.txt", "Hello, World!")
```

### file_append(path, content)

Appends content to the end of a file. Creates the file if it doesn't exist.

```python
file_append("log.txt", "New log entry\n")
```

### file_delete(path)

Deletes a file. Returns `true` on success, `false` on failure.

```python
if file_delete("temp.txt"):
    print("File deleted")
else:
    print("Could not delete file")
```

### file_exists(path)

Checks if a file exists. Returns `true` or `false`.

```python
if file_exists("config.txt"):
    config = file_read("config.txt")
```

## Directory Operations

### dir_list(path)

Returns a list of filenames in a directory.

```python
files = dir_list(".")
for f in files:
    print(f)
```

### dir_create(path)

Creates a directory.

```python
dir_create("new_folder")
```

### dir_exists(path)

Checks if a directory exists. Returns `true` or `false`.

```python
if dir_exists("data"):
    files = dir_list("data")
```

## Example: Log File

```python
# Write initial log
file_write("app.log", "=== Application Started ===\n")

# Append entries
file_append("app.log", "User logged in\n")
file_append("app.log", "Processing data...\n")
file_append("app.log", "Done!\n")

# Read and display
log = file_read("app.log")
print(log)
```

## Example: Configuration

```python
# Check for config file
config_file = "config.txt"

if file_exists(config_file):
    # Read existing config
    config = file_read(config_file)
    print("Loaded config:", config)
else:
    # Create default config
    file_write(config_file, "theme=dark\nlang=en\n")
    print("Created default config")
```

## Example: Directory Processing

```python
# List all files in a directory
dir_path = "data"

if dir_exists(dir_path):
    files = dir_list(dir_path)
    print("Found", len(files), "files:")
    for f in files:
        print("  -", f)
else:
    print("Directory not found:", dir_path)
    dir_create(dir_path)
    print("Created directory:", dir_path)
```

## Summary Table

| Function | Description | Returns |
|----------|-------------|---------|
| `file_read(path)` | Read file contents | string or none |
| `file_write(path, content)` | Write to file | none |
| `file_append(path, content)` | Append to file | none |
| `file_delete(path)` | Delete file | bool |
| `file_exists(path)` | Check if file exists | bool |
| `dir_list(path)` | List directory contents | list |
| `dir_create(path)` | Create directory | none |
| `dir_exists(path)` | Check if directory exists | bool |
