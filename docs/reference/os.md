# OS Module

ZPy provides an `os` module with operating system utilities similar to Python's `os` module.

## Working Directory

### os_getcwd()

Returns the current working directory as a string.

```python
cwd = os_getcwd()
print("Current directory:", cwd)
# Output: Current directory: D:\projects\myapp
```

### os_chdir(path)

Changes the current working directory. Returns `true` if successful, `false` otherwise.

```python
if os_chdir("/tmp"):
    print("Changed to /tmp")
```

## File Operations

### os_rename(old_path, new_path)

Renames or moves a file or directory. Returns `true` on success.

```python
os_rename("old.txt", "new.txt")
os_rename("folder1", "folder2")  # Works for directories too
```

### os_copy(src_path, dst_path)

Copies a file. Returns `true` on success.

```python
os_copy("source.txt", "backup.txt")
```

### os_stat(path)

Returns a dictionary with file/directory information.

```python
info = os_stat("data.txt")
print("Size:", info["size"])        # Size in bytes
print("Modified:", info["mtime"])   # Unix timestamp
print("Is directory:", info["is_dir"])
print("Is file:", info["is_file"])
```

### os_remove(path)

Removes a file. Returns `true` on success.

```python
os_remove("temp.txt")
```

## Directory Operations

### os_mkdir(path)

Creates a directory. Returns `none` on success.

```python
os_mkdir("new_folder")
```

### os_rmdir(path)

Removes an empty directory. Returns `true` on success.

```python
os_rmdir("empty_folder")
```

### os_walk(path)

Recursively walks a directory tree. Returns a list of dictionaries, each containing:
- `dirpath`: the current directory path
- `dirs`: list of subdirectory names
- `files`: list of file names

```python
for entry in os_walk("."):
    print("Directory:", entry["dirpath"])
    print("  Subdirs:", entry["dirs"])
    print("  Files:", entry["files"])
```

## Path Operations

### os_path_join(parts...)

Joins path components into a single path. Handles separators correctly for the platform.

```python
path = os_path_join("folder", "subfolder", "file.txt")
# On Windows: "folder\subfolder\file.txt"
# On Unix: "folder/subfolder/file.txt"
```

### os_path_exists(path)

Returns `true` if the path exists (file or directory).

```python
if os_path_exists("config.json"):
    print("Config found")
```

### os_path_isdir(path)

Returns `true` if the path is a directory.

```python
if os_path_isdir("data"):
    files = dir_list("data")
```

### os_path_isfile(path)

Returns `true` if the path is a file.

```python
if os_path_isfile("readme.txt"):
    content = file_read("readme.txt")
```

### os_path_basename(path)

Returns the filename portion of a path.

```python
name = os_path_basename("/home/user/docs/file.txt")
print(name)  # "file.txt"
```

### os_path_dirname(path)

Returns the directory portion of a path.

```python
dir = os_path_dirname("/home/user/docs/file.txt")
print(dir)  # "/home/user/docs"
```

### os_path_split(path)

Returns a list `[dirname, basename]`.

```python
parts = os_path_split("/home/user/file.txt")
print(parts[0])  # "/home/user"
print(parts[1])  # "file.txt"
```

### os_path_splitext(path)

Splits a path into root and extension. Returns a list `[root, extension]`.

```python
parts = os_path_splitext("document.pdf")
print(parts[0])  # "document"
print(parts[1])  # ".pdf"
```

### os_path_abspath(path)

Converts a relative path to an absolute path.

```python
abs_path = os_path_abspath("../data/file.txt")
print(abs_path)  # "D:\projects\data\file.txt" (example)
```

### os_path_normpath(path)

Normalizes a path by removing redundant separators and `.`/`..` references.

```python
path = os_path_normpath("folder/../folder/./file.txt")
print(path)  # "folder/file.txt"
```

## Environment Variables

### os_getenv(name)

Gets an environment variable. Returns `none` if not set.

```python
path = os_getenv("PATH")
home = os_getenv("HOME")
if path:
    print("PATH:", path)
```

### os_setenv(name, value)

Sets an environment variable. Returns `true` on success.

```python
os_setenv("MY_VAR", "my_value")
```

### os_unsetenv(name)

Removes an environment variable. Returns `true` on success.

```python
os_unsetenv("MY_VAR")
```

### os_environ()

Returns all environment variables as a dictionary.

```python
env = os_environ()
for key in keys(env):
    print(key, "=", env[key])
```

## Example: File Search

```python
# Find all .txt files in a directory tree
def find_txt_files(root):
    results = []
    for entry in os_walk(root):
        for f in entry["files"]:
            parts = os_path_splitext(f)
            if parts[1] == ".txt":
                full_path = os_path_join(entry["dirpath"], f)
                append(results, full_path)
    return results

files = find_txt_files(".")
print("Found", len(files), "text files")
```

## Example: Backup Script

```python
# Backup files to a timestamped directory
import json

timestamp = "2024-01-15_10-30"
backup_dir = os_path_join("backups", timestamp)

os_mkdir("backups")
os_mkdir(backup_dir)

# Copy all JSON files
for f in dir_list("."):
    if os_path_isfile(f):
        parts = os_path_splitext(f)
        if parts[1] == ".json":
            dest = os_path_join(backup_dir, f)
            os_copy(f, dest)
            print("Backed up:", f)
```

## Summary Table

| Function | Description | Returns |
|----------|-------------|---------|
| `os_getcwd()` | Get current directory | string |
| `os_chdir(path)` | Change directory | bool |
| `os_rename(old, new)` | Rename/move file or directory | bool |
| `os_copy(src, dst)` | Copy file | bool |
| `os_stat(path)` | Get file info | dict |
| `os_remove(path)` | Delete file | bool |
| `os_mkdir(path)` | Create directory | none |
| `os_rmdir(path)` | Remove empty directory | bool |
| `os_walk(path)` | Walk directory tree | list |
| `os_path_join(...)` | Join path parts | string |
| `os_path_exists(path)` | Check if path exists | bool |
| `os_path_isdir(path)` | Check if directory | bool |
| `os_path_isfile(path)` | Check if file | bool |
| `os_path_basename(path)` | Get filename | string |
| `os_path_dirname(path)` | Get directory | string |
| `os_path_split(path)` | Split path | list |
| `os_path_splitext(path)` | Split extension | list |
| `os_path_abspath(path)` | Get absolute path | string |
| `os_path_normpath(path)` | Normalize path | string |
| `os_getenv(name)` | Get env variable | string or none |
| `os_setenv(name, val)` | Set env variable | bool |
| `os_unsetenv(name)` | Remove env variable | bool |
| `os_environ()` | Get all env variables | dict |
