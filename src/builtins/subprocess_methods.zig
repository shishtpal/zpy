//! Subprocess methods module - Python-like subprocess built-in implementations.
//!
//! This module provides subprocess built-ins similar to Python's subprocess module:
//!
//! Blocking execution:
//! - `proc_run(cmd_list, input?)` - Run command, capture output, return result dict
//! - `proc_shell(cmd_string, input?)` - Run shell command string
//!
//! Non-blocking (Popen-like):
//! - `proc_open(cmd_list, options?)` - Spawn process, return handle
//! - `proc_write(handle, data)` - Write to process stdin
//! - `proc_read(handle)` - Read all from process stdout
//! - `proc_communicate(handle, input?)` - Send input, read output, wait
//! - `proc_wait(handle)` - Wait for process to exit
//! - `proc_kill(handle)` - Terminate process
//! - `proc_pid(handle)` - Get process ID
//! - `proc_close(handle)` - Close handle and clean up resources
//!
//! Parallel execution:
//! - `proc_run_all(cmd_lists)` - Run multiple commands in parallel
//! - `proc_pipe(cmd1, cmd2)` - Pipe output of cmd1 into cmd2
//!
//! Utility:
//! - `proc_cpu_count()` - Get logical CPU count
//! - `proc_sleep(ms)` - Sleep for milliseconds
//!
//! Resource Management:
//! - Call `proc_deinit()` to clean up global state (optional, called automatically on exit)

const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const process_utils = @import("process_utils.zig");

pub const BuiltinError = process_utils.BuiltinError;

pub const SubprocessBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

pub fn getSubprocessBuiltin(name: []const u8) ?SubprocessBuiltinFn {
    const builtins_map = std.StaticStringMap(SubprocessBuiltinFn).initComptime(.{
        // Blocking execution
        .{ "proc_run", procRun },
        .{ "proc_shell", procShell },
        // Non-blocking
        .{ "proc_open", procOpen },
        .{ "proc_write", procWrite },
        .{ "proc_read", procRead },
        .{ "proc_communicate", procCommunicate },
        .{ "proc_wait", procWait },
        .{ "proc_kill", procKill },
        .{ "proc_pid", procPid },
        .{ "proc_close", procClose },
        // Parallel
        .{ "proc_run_all", procRunAll },
        .{ "proc_pipe", procPipe },
        // Utility
        .{ "proc_cpu_count", procCpuCount },
        .{ "proc_sleep", procSleep },
        // Cleanup
        .{ "proc_deinit", procDeinit },
    });
    return builtins_map.get(name);
}

// ============================================================================
// Process Handle Table
// // ============================================================================

const StdIoMode = enum { pipe, inherit, ignore };

const ProcState = struct {
    child: std.process.Child,
    stdin_mode: StdIoMode,
    stdout_mode: StdIoMode,
    stderr_mode: StdIoMode,
    stdin_closed: bool,
    stdout_closed: bool,
    stderr_closed: bool,
    waited: bool,
    term: ?std.process.Child.Term,
};

var proc_next_handle: i64 = 1;
var proc_table: ?std.AutoHashMap(i64, ProcState) = null;

fn getProcTable(allocator: std.mem.Allocator) *std.AutoHashMap(i64, ProcState) {
    if (proc_table == null) {
        proc_table = std.AutoHashMap(i64, ProcState).init(allocator);
    }
    return &proc_table.?;
}

/// Clean up global process table state.
/// Call this to release resources when done with subprocess operations.
/// This is optional - the OS will clean up on process exit.
pub fn procDeinit(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;

    if (proc_table) |*table| {
        // Note: We don't kill running processes here - that's proc_close's job
        table.deinit();
        proc_table = null;
    }
    proc_next_handle = 1;

    return .none;
}

// ============================================================================
// Helpers
// ============================================================================

fn parseStdIoOption(val: Value) StdIoMode {
    if (val == .string) {
        if (std.mem.eql(u8, val.string, "pipe")) return .pipe;
        if (std.mem.eql(u8, val.string, "ignore")) return .ignore;
    }
    return .inherit;
}

fn stdIoToSpawn(mode: StdIoMode) std.process.SpawnOptions.StdIo {
    return switch (mode) {
        .pipe => .pipe,
        .inherit => .inherit,
        .ignore => .ignore,
    };
}

fn buildShellArgv(allocator: std.mem.Allocator, cmd_string: []const u8) BuiltinError!std.ArrayList([]const u8) {
    var argv: std.ArrayList([]const u8) = .empty;
    if (native_os == .windows) {
        argv.append(allocator, "cmd.exe") catch return BuiltinError.OutOfMemory;
        argv.append(allocator, "/C") catch return BuiltinError.OutOfMemory;
    } else {
        argv.append(allocator, "/bin/sh") catch return BuiltinError.OutOfMemory;
        argv.append(allocator, "-c") catch return BuiltinError.OutOfMemory;
    }
    argv.append(allocator, cmd_string) catch return BuiltinError.OutOfMemory;
    return argv;
}

fn communicateInternal(
    allocator: std.mem.Allocator,
    io: std.Io,
    child: *std.process.Child,
    stdin_data: ?[]const u8,
    stdin_mode: StdIoMode,
    stdout_mode: StdIoMode,
    stderr_mode: StdIoMode,
) BuiltinError!struct { term: std.process.Child.Term, stdout: []u8, stderr: []u8 } {
    // Handle stdin
    if (stdin_mode == .pipe) {
        if (child.stdin) |stdin_file| {
            if (stdin_data) |data| {
                // Write stdin data, ignoring errors (process may have closed stdin)
                stdin_file.writeStreamingAll(io, data) catch {};
            }
            stdin_file.close(io);
            child.stdin = null;
        }
    }

    var stdout_data: []u8 = &.{};
    var stderr_data: []u8 = &.{};

    // Read stdout and stderr
    if (stdout_mode == .pipe and stderr_mode == .pipe) {
        if (child.stdout) |stdout_file| {
            if (child.stderr) |stderr_file| {
                var multi_reader_buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
                var multi_reader: std.Io.File.MultiReader = undefined;
                multi_reader.init(allocator, io, multi_reader_buffer.toStreams(), &.{ stdout_file, stderr_file });
                defer multi_reader.deinit();

                while (multi_reader.fill(4096, .none)) |_| {} else |err| switch (err) {
                    error.EndOfStream => {},
                    else => {},
                }

                multi_reader.checkAnyError() catch {};

                stdout_data = multi_reader.toOwnedSlice(0) catch &.{};
                stderr_data = multi_reader.toOwnedSlice(1) catch &.{};

                child.stdout = null;
                child.stderr = null;
            }
        }
    } else {
        if (stdout_mode == .pipe) {
            if (child.stdout) |stdout_file| {
                stdout_data = process_utils.readAllFromFile(allocator, stdout_file, io) catch &.{};
                stdout_file.close(io);
                child.stdout = null;
            }
        }
        if (stderr_mode == .pipe) {
            if (child.stderr) |stderr_file| {
                stderr_data = process_utils.readAllFromFile(allocator, stderr_file, io) catch &.{};
                stderr_file.close(io);
                child.stderr = null;
            }
        }
    }

    const term = child.wait(io) catch return BuiltinError.ValueError;

    return .{ .term = term, .stdout = stdout_data, .stderr = stderr_data };
}

// ============================================================================
// Blocking Execution
// ============================================================================

/// proc_run(cmd_list, input?) -> dict
/// Run a command (list of strings), optionally send input to stdin.
/// Returns {"ok", "exit_code", "stdout", "stderr", "output"}.
fn procRun(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;

    const cmd_list = args[0].list;
    if (cmd_list.items.items.len == 0) return BuiltinError.ValueError;

    var argv = try process_utils.valueListToArgv(allocator, cmd_list);
    defer argv.deinit(allocator);

    const stdin_data: ?[]const u8 = if (args.len == 2) blk: {
        if (args[1] == .none) break :blk null;
        if (args[1] != .string) return BuiltinError.TypeError;
        break :blk args[1].string;
    } else null;

    const has_stdin = stdin_data != null;

    var child = std.process.spawn(io, .{
        .argv = argv.items,
        .stdin = if (has_stdin) .pipe else .ignore,
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch return BuiltinError.ValueError;

    const result = communicateInternal(
        allocator,
        io,
        &child,
        stdin_data,
        if (has_stdin) .pipe else .ignore,
        .pipe,
        .pipe,
    ) catch {
        process_utils.cleanupChild(&child, io);
        return BuiltinError.ValueError;
    };
    defer if (result.stdout.len > 0) allocator.free(result.stdout);
    defer if (result.stderr.len > 0) allocator.free(result.stderr);

    return process_utils.buildResultDict(allocator, result.term, result.stdout, result.stderr);
}

/// proc_shell(cmd_string, input?) -> dict
/// Run a shell command string. On Windows uses cmd.exe /C, on POSIX uses /bin/sh -c.
/// Returns {"ok", "exit_code", "stdout", "stderr", "output"}.
fn procShell(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    var argv = try buildShellArgv(allocator, args[0].string);
    defer argv.deinit(allocator);

    const stdin_data: ?[]const u8 = if (args.len == 2) blk: {
        if (args[1] == .none) break :blk null;
        if (args[1] != .string) return BuiltinError.TypeError;
        break :blk args[1].string;
    } else null;

    const has_stdin = stdin_data != null;

    var child = std.process.spawn(io, .{
        .argv = argv.items,
        .stdin = if (has_stdin) .pipe else .ignore,
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch return BuiltinError.ValueError;

    const result = communicateInternal(
        allocator,
        io,
        &child,
        stdin_data,
        if (has_stdin) .pipe else .ignore,
        .pipe,
        .pipe,
    ) catch {
        process_utils.cleanupChild(&child, io);
        return BuiltinError.ValueError;
    };
    defer if (result.stdout.len > 0) allocator.free(result.stdout);
    defer if (result.stderr.len > 0) allocator.free(result.stderr);

    return process_utils.buildResultDict(allocator, result.term, result.stdout, result.stderr);
}

// ============================================================================
// Non-blocking (Popen-like)
// ============================================================================

/// proc_open(cmd_list, options?) -> int
/// Spawn a process and return a handle. Options dict can specify:
///   "stdin": "pipe"|"inherit"|"ignore" (default: "pipe")
///   "stdout": "pipe"|"inherit"|"ignore" (default: "pipe")
///   "stderr": "pipe"|"inherit"|"ignore" (default: "pipe")
fn procOpen(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;

    const cmd_list = args[0].list;
    if (cmd_list.items.items.len == 0) return BuiltinError.ValueError;

    var stdin_mode: StdIoMode = .pipe;
    var stdout_mode: StdIoMode = .pipe;
    var stderr_mode: StdIoMode = .pipe;

    if (args.len == 2) {
        if (args[1] != .dict) return BuiltinError.TypeError;
        const opts = args[1].dict;

        const stdin_key = Value{ .string = "stdin" };
        const stdout_key = Value{ .string = "stdout" };
        const stderr_key = Value{ .string = "stderr" };

        if (opts.get(stdin_key)) |v| stdin_mode = parseStdIoOption(v);
        if (opts.get(stdout_key)) |v| stdout_mode = parseStdIoOption(v);
        if (opts.get(stderr_key)) |v| stderr_mode = parseStdIoOption(v);
    }

    var argv = try process_utils.valueListToArgv(allocator, cmd_list);
    defer argv.deinit(allocator);

    var child = std.process.spawn(io, .{
        .argv = argv.items,
        .stdin = stdIoToSpawn(stdin_mode),
        .stdout = stdIoToSpawn(stdout_mode),
        .stderr = stdIoToSpawn(stderr_mode),
    }) catch return BuiltinError.ValueError;

    const handle = proc_next_handle;
    proc_next_handle += 1;

    const table = getProcTable(allocator);
    table.put(handle, .{
        .child = child,
        .stdin_mode = stdin_mode,
        .stdout_mode = stdout_mode,
        .stderr_mode = stderr_mode,
        .stdin_closed = false,
        .stdout_closed = false,
        .stderr_closed = false,
        .waited = false,
        .term = null,
    }) catch {
        process_utils.cleanupChild(&child, io);
        return BuiltinError.OutOfMemory;
    };

    return .{ .integer = handle };
}

/// proc_write(handle, data) -> int
/// Write data string to process stdin. Returns number of bytes written.
/// Returns -1 on error (invalid handle, stdin not piped, or write failed).
fn procWrite(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;
    if (args[1] != .string) return BuiltinError.TypeError;

    const handle = args[0].integer;
    const data = args[1].string;

    const table = getProcTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.ValueError;

    if (state.stdin_mode != .pipe or state.stdin_closed) return BuiltinError.ValueError;

    if (state.child.stdin) |stdin_file| {
        stdin_file.writeStreamingAll(io, data) catch return .{ .integer = -1 };
        return .{ .integer = @intCast(data.len) };
    }

    return BuiltinError.ValueError;
}

/// proc_read(handle) -> string
/// Read all data from process stdout until EOF. Closes the stdout pipe.
fn procRead(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const table = getProcTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.ValueError;

    if (state.stdout_mode != .pipe or state.stdout_closed) return .{ .string = "" };

    if (state.child.stdout) |stdout_file| {
        const data = process_utils.readAllFromFile(allocator, stdout_file, io) catch return .{ .string = "" };
        stdout_file.close(io);
        state.child.stdout = null;
        state.stdout_closed = true;
        return .{ .string = data };
    }

    return .{ .string = "" };
}

/// proc_communicate(handle, input?) -> dict
/// Send input to stdin (if provided), close stdin, read all stdout/stderr,
/// wait for process to exit. Returns result dict. Removes handle.
fn procCommunicate(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const stdin_data: ?[]const u8 = if (args.len == 2) blk: {
        if (args[1] == .none) break :blk null;
        if (args[1] != .string) return BuiltinError.TypeError;
        break :blk args[1].string;
    } else null;

    const table = getProcTable(allocator);
    var entry = table.fetchRemove(handle) orelse return BuiltinError.ValueError;
    var state = &entry.value;

    const result = communicateInternal(
        allocator,
        io,
        &state.child,
        stdin_data,
        state.stdin_mode,
        state.stdout_mode,
        state.stderr_mode,
    ) catch {
        process_utils.cleanupChild(&state.child, io);
        return BuiltinError.ValueError;
    };
    defer if (result.stdout.len > 0) allocator.free(result.stdout);
    defer if (result.stderr.len > 0) allocator.free(result.stderr);

    return process_utils.buildResultDict(allocator, result.term, result.stdout, result.stderr);
}

/// proc_wait(handle) -> int
/// Wait for process to exit. Returns exit code. Removes handle.
fn procWait(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const table = getProcTable(allocator);
    var entry = table.fetchRemove(handle) orelse return BuiltinError.ValueError;
    var state = &entry.value;

    // Close all pipes before waiting
    process_utils.closeChildPipes(&state.child, io);

    const term = state.child.wait(io) catch return BuiltinError.ValueError;
    return .{ .integer = process_utils.extractTermExitCode(term) };
}

/// proc_kill(handle) -> bool
/// Terminate the process. Returns true on success. Removes handle.
fn procKill(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const table = getProcTable(allocator);
    var entry = table.fetchRemove(handle) orelse return .{ .boolean = false };
    var state = &entry.value;

    process_utils.cleanupChild(&state.child, io);
    return .{ .boolean = true };
}

/// proc_pid(handle) -> int or none
/// Get the process ID of a spawned process.
fn procPid(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const table = getProcTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.ValueError;

    if (process_utils.getProcessId(&state.child)) |pid| {
        return .{ .integer = pid };
    }
    return .none;
}

/// proc_close(handle) -> none
/// Close a process handle and clean up resources.
/// This will kill the process if it's still running. Use proc_wait first
/// if you want to wait for graceful exit.
fn procClose(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;

    const table = getProcTable(allocator);
    var entry = table.fetchRemove(handle) orelse return .none;
    var state = &entry.value;

    // Clean up all resources and kill if still running
    process_utils.cleanupChild(&state.child, io);

    return .none;
}

// ============================================================================
// Parallel Execution
// ============================================================================

/// proc_run_all(cmd_lists) -> list[dict]
/// Run multiple commands in parallel, wait for all, return list of result dicts.
/// Each item in cmd_lists should be a list of strings (a command).
fn procRunAll(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;

    const cmd_lists = args[0].list;
    const n = cmd_lists.items.items.len;
    if (n == 0) {
        const empty_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
        empty_list.* = Value.List.init(allocator);
        return .{ .list = empty_list };
    }

    const children = allocator.alloc(std.process.Child, n) catch return BuiltinError.OutOfMemory;
    defer allocator.free(children);

    const argvs = allocator.alloc(std.ArrayList([]const u8), n) catch return BuiltinError.OutOfMemory;
    defer {
        for (argvs) |*a| a.deinit(allocator);
        allocator.free(argvs);
    }

    var spawned: usize = 0;

    for (cmd_lists.items.items, 0..) |cmd_val, i| {
        if (cmd_val != .list) {
            for (children[0..spawned]) |*c| process_utils.cleanupChild(c, io);
            return BuiltinError.TypeError;
        }
        const cmd = cmd_val.list;
        if (cmd.items.items.len == 0) {
            for (children[0..spawned]) |*c| process_utils.cleanupChild(c, io);
            return BuiltinError.ValueError;
        }

        argvs[i] = process_utils.valueListToArgv(allocator, cmd) catch {
            for (children[0..spawned]) |*c| process_utils.cleanupChild(c, io);
            return BuiltinError.OutOfMemory;
        };

        children[i] = std.process.spawn(io, .{
            .argv = argvs[i].items,
            .stdin = .ignore,
            .stdout = .pipe,
            .stderr = .pipe,
        }) catch {
            for (children[0..spawned]) |*c| process_utils.cleanupChild(c, io);
            return BuiltinError.ValueError;
        };
        spawned += 1;
    }

    const results = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    results.* = Value.List.init(allocator);

    for (children[0..spawned]) |*child| {
        const comm_result = communicateInternal(
            allocator,
            io,
            child,
            null,
            .ignore,
            .pipe,
            .pipe,
        ) catch {
            process_utils.cleanupChild(child, io);
            const error_dict = process_utils.buildResultDict(allocator, .{ .unknown = 1 }, "", "process error") catch continue;
            results.items.append(allocator, error_dict) catch {};
            continue;
        };

        defer if (comm_result.stdout.len > 0) allocator.free(comm_result.stdout);
        defer if (comm_result.stderr.len > 0) allocator.free(comm_result.stderr);

        const dict_val = process_utils.buildResultDict(allocator, comm_result.term, comm_result.stdout, comm_result.stderr) catch continue;
        results.items.append(allocator, dict_val) catch {};
    }

    return .{ .list = results };
}

/// proc_pipe(cmd1, cmd2) -> dict
/// Pipe stdout of cmd1 into stdin of cmd2. Returns result dict for cmd2.
/// cmd1 and cmd2 are both lists of strings.
fn procPipe(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list or args[1] != .list) return BuiltinError.TypeError;

    const cmd1_list = args[0].list;
    const cmd2_list = args[1].list;

    if (cmd1_list.items.items.len == 0 or cmd2_list.items.items.len == 0) return BuiltinError.ValueError;

    var argv1 = try process_utils.valueListToArgv(allocator, cmd1_list);
    defer argv1.deinit(allocator);

    var argv2 = try process_utils.valueListToArgv(allocator, cmd2_list);
    defer argv2.deinit(allocator);

    var child1 = std.process.spawn(io, .{
        .argv = argv1.items,
        .stdin = .ignore,
        .stdout = .pipe,
        .stderr = .inherit,
    }) catch return BuiltinError.ValueError;

    var child2 = std.process.spawn(io, .{
        .argv = argv2.items,
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch {
        process_utils.cleanupChild(&child1, io);
        return BuiltinError.ValueError;
    };

    // Transfer data from child1.stdout to child2.stdin
    if (child1.stdout) |stdout1| {
        if (child2.stdin) |stdin2| {
            var buf: [8192]u8 = undefined;
            while (true) {
                const n = stdout1.readStreaming(io, &.{&buf}) catch break;
                if (n == 0) break;
                stdin2.writeStreamingAll(io, buf[0..n]) catch break;
            }
            stdin2.close(io);
            child2.stdin = null;
        }
        stdout1.close(io);
        child1.stdout = null;
    }

    // Wait for child1 (ignore its exit code)
    _ = child1.wait(io) catch {};

    var stdout_data: []u8 = &.{};
    var stderr_data: []u8 = &.{};

    if (child2.stdout) |stdout_file| {
        stdout_data = process_utils.readAllFromFile(allocator, stdout_file, io) catch &.{};
        stdout_file.close(io);
        child2.stdout = null;
    }
    if (child2.stderr) |stderr_file| {
        stderr_data = process_utils.readAllFromFile(allocator, stderr_file, io) catch &.{};
        stderr_file.close(io);
        child2.stderr = null;
    }

    const term2 = child2.wait(io) catch {
        process_utils.cleanupChild(&child2, io);
        return BuiltinError.ValueError;
    };

    defer if (stdout_data.len > 0) allocator.free(stdout_data);
    defer if (stderr_data.len > 0) allocator.free(stderr_data);

    return process_utils.buildResultDict(allocator, term2, stdout_data, stderr_data);
}

// ============================================================================
// Utility
// ============================================================================

/// proc_cpu_count() -> int
fn procCpuCount(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .integer = process_utils.cpuCount() };
}

/// proc_sleep(milliseconds) -> none
fn procSleep(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;
    const ms = args[0].integer;
    if (ms < 0) return BuiltinError.ValueError;
    process_utils.sleepMs(io, ms);
    return .none;
}
