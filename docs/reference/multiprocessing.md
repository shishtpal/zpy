# Multiprocessing Module

ZPy provides a multiprocessing module for spawning and managing child processes that run ZPy scripts, similar to Python's `multiprocessing` module.

## Process Execution

### mp_run(script_path, args_list?)

Spawns a new ZPy interpreter process to run a script. Captures stdout and stderr.

Returns a dictionary with:
- `ok`: `true` if exit code is 0
- `exit_code`: the exit code (negative for signals)
- `stdout`: captured stdout output
- `stderr`: captured stderr output
- `output`: combined stdout and stderr

```python
# Run a script
result = mp_run("worker.zpy")
print("Exit code:", result["exit_code"])
print("Output:", result["output"])

# Run with arguments
result = mp_run("process.zpy", ["arg1", "arg2"])
```

### mp_run_code(code_string, args_list?)

Spawns a new ZPy interpreter to run inline code. Useful for parallel computations.

Returns the same dictionary format as `mp_run`.

```python
# Run inline code
result = mp_run_code("print(2 + 3)")
print(result["output"])  # "5\n"

# Run computation
result = mp_run_code("x = 10 * 10\nprint(x)")
print(result["output"])  # "100\n"

# Error handling
result = mp_run_code("x = 1 / 0")
print(result["ok"])       # false
print(result["output"])   # error message
```

## Process Management

### mp_spawn(script_path)

Spawns a child process running a ZPy script. Returns an integer handle for management.

Unlike `mp_run`, this doesn't wait for completion - stdout/stderr are inherited (not captured).

```python
# Spawn a background process
handle = mp_spawn("background_task.zpy")
print("Spawned process:", handle)
```

### mp_wait(handle)

Blocks until the child process exits. Returns the exit code. Removes the handle.

```python
handle = mp_spawn("worker.zpy")
# ... do other work ...
exit_code = mp_wait(handle)
print("Worker exited with code:", exit_code)
```

### mp_poll(handle)

Checks if a process has finished. Returns `none` if still running, or the exit code if finished.

**Note:** Due to Zig 0.16 Io API limitations, this always returns `none` (still running). Use `mp_wait` to block until completion.

```python
handle = mp_spawn("worker.zpy")
result = mp_poll(handle)
if result == none:
    print("Still running, use mp_wait to block")
```

### mp_kill(handle)

Terminates the child process. Returns `true` on success, `false` on failure. Removes the handle.

```python
handle = mp_spawn("long_running.zpy")
# Need to stop it
if mp_kill(handle):
    print("Process killed")
```

## System Info

### mp_cpu_count()

Returns the number of logical CPUs available.

```python
cpus = mp_cpu_count()
print("CPU count:", cpus)  # e.g., 8
```

## Timing

### mp_sleep(milliseconds)

Sleeps for the specified duration in milliseconds.

```python
print("Starting...")
mp_sleep(1000)  # Sleep 1 second
print("Done!")
```

## Cleanup

### mp_deinit()

Cleans up global process table state. Optional - the OS will clean up on process exit.

```python
# After you're done with all multiprocessing operations
mp_deinit()
```

## Example: Parallel Computation

```python
# Run multiple computations in parallel
results = []

# Spawn multiple workers
handles = []
for i in range(4):
    code = "print(" + str(i) + " * 2)"
    handle = mp_spawn("-c", code)  # Note: this is conceptual
    append(handles, handle)

# Wait for all
for h in handles:
    exit_code = mp_wait(h)
    print("Worker exited:", exit_code)
```

## Example: Script Runner

```python
# Run a script and check results
def run_script(path):
    result = mp_run(path)
    if result["ok"]:
        print("Success!")
        print("Output:", result["output"])
    else:
        print("Failed with code:", result["exit_code"])
        print("Error:", result["stderr"])
    return result

run_script("worker.zpy")
```

## Example: Background Task

```python
# Start a background task and do other work
handle = mp_spawn("background.zpy")

# Do other work while background runs
for i in range(10):
    print("Main process working...", i)
    mp_sleep(100)

# Wait for background to finish
exit_code = mp_wait(handle)
print("Background task exited with:", exit_code)
```

## Summary Table

| Function | Description | Returns |
|----------|-------------|---------|
| `mp_run(script, args?)` | Run script in subprocess | dict |
| `mp_run_code(code, args?)` | Run inline code in subprocess | dict |
| `mp_spawn(script)` | Spawn background process | int |
| `mp_wait(handle)` | Wait for process to exit | int |
| `mp_poll(handle)` | Check if finished (limited) | int or none |
| `mp_kill(handle)` | Terminate process | bool |
| `mp_cpu_count()` | Get CPU count | int |
| `mp_sleep(ms)` | Sleep milliseconds | none |
| `mp_deinit()` | Clean up global state | none |

## Comparison with Subprocess Module

| Feature | Multiprocessing | Subprocess |
|---------|-----------------|------------|
| Run ZPy scripts | Yes (dedicated) | Via shell |
| Run external commands | No | Yes |
| Capture output | `mp_run`, `mp_run_code` | `proc_run`, `proc_shell` |
| Background processes | `mp_spawn` | `proc_open` |
| Parallel execution | Manual spawning | `proc_run_all` |
| Pipe between processes | No | `proc_pipe` |
| Interactive I/O | No | Yes |