# Subprocess Module

ZPy provides a subprocess module for process execution and management, similar to Python's `subprocess` module.

## Blocking Execution

### proc_run(cmd_list, input?)

Runs a command (list of strings) and waits for it to complete. Optionally sends input to stdin.

Returns a dictionary with:
- `ok`: `true` if exit code is 0
- `exit_code`: the exit code (negative for signals)
- `stdout`: captured stdout output
- `stderr`: captured stderr output
- `output`: combined stdout and stderr

```python
# Run a simple command
result = proc_run(["cmd.exe", "/C", "echo hello"])
print(result["ok"])        # true
print(result["stdout"])    # "hello\n"

# Run with input
result = proc_run(["findstr", "test"], "test line\nother line\n")
print(result["stdout"])    # "test line\n"
```

### proc_shell(cmd_string, input?)

Runs a shell command string. On Windows uses `cmd.exe /C`, on POSIX uses `/bin/sh -c`.

Returns the same dictionary format as `proc_run`.

```python
# Run a shell command
result = proc_shell("echo hello from shell")
print(result["stdout"])    # "hello from shell\n"

# Directory listing
result = proc_shell("dir /b *.txt")
print(result["stdout"])    # list of .txt files

# With input
result = proc_shell("findstr hello", "hello world\ngoodbye\n")
print(result["stdout"])    # "hello world\n"
```

## Non-blocking (Popen-like)

### proc_open(cmd_list, options?)

Spawns a process and returns an integer handle for interaction.

Options dictionary can specify:
- `"stdin"`: `"pipe"`, `"inherit"`, or `"ignore"` (default: `"pipe"`)
- `"stdout"`: `"pipe"`, `"inherit"`, or `"ignore"` (default: `"pipe"`)
- `"stderr"`: `"pipe"`, `"inherit"`, or `"ignore"` (default: `"pipe"`)

```python
# Open with default options (all pipes)
handle = proc_open(["cmd.exe", "/C", "findstr test"])
print("Handle:", handle)  # 1

# Open with custom options
handle = proc_open(["myprogram"], {"stdout": "pipe", "stderr": "inherit"})
```

### proc_write(handle, data)

Writes data to the process stdin. Returns number of bytes written, or -1 on error.

```python
handle = proc_open(["cmd.exe", "/C", "findstr test"])
proc_write(handle, "test line 1\n")
proc_write(handle, "test line 2\n")
```

### proc_read(handle)

Reads all data from process stdout until EOF. Closes the stdout pipe after reading.

```python
handle = proc_open(["cmd.exe", "/C", "echo line1 & echo line2"])
output = proc_read(handle)
print(output)  # "line1\nline2\n"
```

### proc_communicate(handle, input?)

Sends input to stdin (if provided), closes stdin, reads all stdout/stderr, and waits for process to exit. Removes the handle from the process table.

Returns the same dictionary format as `proc_run`.

```python
handle = proc_open(["cmd.exe", "/C", "findstr test"])
proc_write(handle, "test line 1\n")
proc_write(handle, "other line\n")
result = proc_communicate(handle)
print(result["stdout"])  # "test line 1\n"
```

### proc_wait(handle)

Waits for process to exit and returns the exit code. Removes the handle.

```python
handle = proc_open(["cmd.exe", "/C", "echo done"])
output = proc_read(handle)
exit_code = proc_wait(handle)
print("Exit code:", exit_code)  # 0
```

### proc_kill(handle)

Terminates the process. Returns `true` on success. Removes the handle.

```python
handle = proc_open(["cmd.exe", "/C", "pause"])
proc_kill(handle)  # Forcefully terminate
```

### proc_pid(handle)

Returns the process ID, or `none` if unavailable.

```python
handle = proc_open(["cmd.exe", "/C", "echo test"])
pid = proc_pid(handle)
print("PID:", pid)  # e.g., 12345
proc_close(handle)
```

### proc_close(handle)

Closes a process handle and cleans up resources. **This will kill the process if still running.** Use `proc_wait` first if you want to wait for graceful exit.

```python
handle = proc_open(["cmd.exe", "/C", "echo test"])
proc_close(handle)  # Clean up (kills if still running)
```

## Parallel Execution

### proc_run_all(cmd_lists)

Runs multiple commands in parallel, waits for all to complete. Returns a list of result dictionaries.

Each item in `cmd_lists` should be a list of strings (a command).

```python
cmds = [
    ["cmd.exe", "/C", "echo process 1"],
    ["cmd.exe", "/C", "echo process 2"],
    ["cmd.exe", "/C", "echo process 3"]
]
results = proc_run_all(cmds)
print("Got", len(results), "results")
for i, r in enumerate(results):
    print("Process", i + 1, "stdout:", r["stdout"])
```

### proc_pipe(cmd1, cmd2)

Pipes stdout of cmd1 into stdin of cmd2. Returns result dictionary for cmd2.

```python
# Pipe: echo | findstr
cmd1 = ["cmd.exe", "/C", "echo apple pie & echo banana split"]
cmd2 = ["findstr", "apple"]
result = proc_pipe(cmd1, cmd2)
print(result["stdout"])  # "apple pie\n"
```

## Utility

### proc_cpu_count()

Returns the number of logical CPUs available.

```python
cpus = proc_cpu_count()
print("CPU count:", cpus)  # e.g., 8
```

### proc_sleep(milliseconds)

Sleeps for the specified duration in milliseconds.

```python
print("Starting...")
proc_sleep(1000)  # Sleep 1 second
print("Done!")
```

### proc_deinit()

Cleans up global process table state. Optional - the OS will clean up on process exit.

```python
# After you're done with all subprocess operations
proc_deinit()
```

## Example: Interactive Process

```python
# Interactive process communication
handle = proc_open(["cmd.exe", "/C", "findstr test"])

# Send multiple lines
proc_write(handle, "test line 1\n")
proc_write(handle, "other line\n")
proc_write(handle, "test line 2\n")

# Get results
result = proc_communicate(handle)
print("Matched lines:")
print(result["stdout"])
```

## Example: Parallel File Processing

```python
# Process multiple files in parallel
files = ["file1.txt", "file2.txt", "file3.txt"]
cmds = []
for f in files:
    append(cmds, ["cmd.exe", "/C", "type " + f])

results = proc_run_all(cmds)
for i, r in enumerate(results):
    if r["ok"]:
        print(files[i], "contents:", r["stdout"][:50])
    else:
        print(files[i], "failed")
```

## Summary Table

| Function | Description | Returns |
|----------|-------------|---------|
| `proc_run(cmd, input?)` | Run command, capture output | dict |
| `proc_shell(cmd, input?)` | Run shell command | dict |
| `proc_open(cmd, opts?)` | Spawn process, get handle | int |
| `proc_write(handle, data)` | Write to stdin | int |
| `proc_read(handle)` | Read all stdout | string |
| `proc_communicate(handle, input?)` | Send input, read output, wait | dict |
| `proc_wait(handle)` | Wait for exit | int |
| `proc_kill(handle)` | Terminate process | bool |
| `proc_pid(handle)` | Get process ID | int or none |
| `proc_close(handle)` | Clean up handle | none |
| `proc_run_all(cmds)` | Run commands in parallel | list |
| `proc_pipe(cmd1, cmd2)` | Pipe between commands | dict |
| `proc_cpu_count()` | Get CPU count | int |
| `proc_sleep(ms)` | Sleep milliseconds | none |
| `proc_deinit()` | Clean up global state | none |