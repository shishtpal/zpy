//! Multiprocessing methods module - process-based multiprocessing built-in implementations.
//!
//! This module provides multiprocessing built-ins similar to Python's multiprocessing/subprocess:
//! - Process execution: `mp_run`, `mp_run_code`
//! - Process management: `mp_spawn`, `mp_wait`, `mp_poll`, `mp_kill`
//! - System info: `mp_cpu_count`
//! - Timing: `mp_sleep`

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const MpBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a multiprocessing built-in function by name.
pub fn getMpBuiltin(name: []const u8) ?MpBuiltinFn {
    const builtins = std.StaticStringMap(MpBuiltinFn).initComptime(.{
        .{ "mp_run", mpRun },
        .{ "mp_run_code", mpRunCode },
        .{ "mp_spawn", mpSpawn },
        .{ "mp_wait", mpWait },
        .{ "mp_poll", mpPoll },
        .{ "mp_kill", mpKill },
        .{ "mp_cpu_count", mpCpuCount },
        .{ "mp_sleep", mpSleep },
    });
    return builtins.get(name);
}

// ============================================================================
// Global State for Process Handle Table
// ============================================================================

const ChildState = struct {
    child: std.process.Child,
};

var next_handle: i64 = 1;
var children: ?std.AutoHashMap(i64, ChildState) = null;

fn getChildren(allocator: std.mem.Allocator) *std.AutoHashMap(i64, ChildState) {
    if (children == null) {
        children = std.AutoHashMap(i64, ChildState).init(allocator);
    }
    return &children.?;
}

// ============================================================================
// Helper: Build result dict from process output
// ============================================================================

fn buildResultDict(allocator: std.mem.Allocator, term: std.process.Child.Term, stdout_data: []const u8, stderr_data: []const u8) BuiltinError!Value {
    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    const ok_key = Value{ .string = allocator.dupe(u8, "ok") catch return BuiltinError.OutOfMemory };
    const exit_key = Value{ .string = allocator.dupe(u8, "exit_code") catch return BuiltinError.OutOfMemory };
    const stdout_key = Value{ .string = allocator.dupe(u8, "stdout") catch return BuiltinError.OutOfMemory };
    const stderr_key = Value{ .string = allocator.dupe(u8, "stderr") catch return BuiltinError.OutOfMemory };
    const output_key = Value{ .string = allocator.dupe(u8, "output") catch return BuiltinError.OutOfMemory };

    const exit_code: i64 = switch (term) {
        .exited => |code| @intCast(code),
        .signal => |sig| -@as(i64, @intCast(@intFromEnum(sig))),
        .stopped => |code| -@as(i64, @intCast(code)),
        .unknown => |code| -@as(i64, @intCast(code)),
    };

    const ok = exit_code == 0;

    dict.set(ok_key, .{ .boolean = ok }) catch return BuiltinError.OutOfMemory;
    dict.set(exit_key, .{ .integer = exit_code }) catch return BuiltinError.OutOfMemory;
    dict.set(stdout_key, .{ .string = allocator.dupe(u8, stdout_data) catch return BuiltinError.OutOfMemory }) catch return BuiltinError.OutOfMemory;
    dict.set(stderr_key, .{ .string = allocator.dupe(u8, stderr_data) catch return BuiltinError.OutOfMemory }) catch return BuiltinError.OutOfMemory;

    const output = blk: {
        if (stderr_data.len > 0 and stdout_data.len > 0) {
            var combined: std.ArrayList(u8) = .empty;
            combined.appendSlice(allocator, stdout_data) catch return BuiltinError.OutOfMemory;
            combined.appendSlice(allocator, stderr_data) catch return BuiltinError.OutOfMemory;
            break :blk combined.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;
        } else if (stderr_data.len > 0) {
            break :blk allocator.dupe(u8, stderr_data) catch return BuiltinError.OutOfMemory;
        } else {
            break :blk allocator.dupe(u8, stdout_data) catch return BuiltinError.OutOfMemory;
        }
    };
    dict.set(output_key, .{ .string = output }) catch return BuiltinError.OutOfMemory;

    return .{ .dict = dict };
}

// ============================================================================
// Helper: Get self executable path
// ============================================================================

fn getSelfExePath(allocator: std.mem.Allocator, io: std.Io) ?[:0]u8 {
    return std.process.executablePathAlloc(io, allocator) catch return null;
}

// ============================================================================
// Process Execution
// ============================================================================

/// mp_run(script_path, args_list?) -> dict
/// Spawns self_exe with script_path as a child process, captures stdout/stderr.
/// Returns dict with keys: "ok", "exit_code", "stdout", "stderr".
fn mpRun(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const script_path = args[0].string;

    const self_exe = getSelfExePath(allocator, io) orelse return BuiltinError.ValueError;
    defer allocator.free(self_exe);

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    argv_list.append(allocator, self_exe) catch return BuiltinError.OutOfMemory;
    argv_list.append(allocator, script_path) catch return BuiltinError.OutOfMemory;

    if (args.len == 2) {
        if (args[1] != .list) return BuiltinError.TypeError;
        const extra_args = args[1].list;
        for (extra_args.items.items) |item| {
            if (item != .string) return BuiltinError.TypeError;
            argv_list.append(allocator, item.string) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = std.process.run(allocator, io, .{
        .argv = argv_list.items,
    }) catch return BuiltinError.ValueError;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return buildResultDict(allocator, result.term, result.stdout, result.stderr);
}

/// mp_run_code(code_string, args_list?) -> dict
/// Spawns self_exe with -c "code_string" as a child process, captures stdout/stderr.
/// Returns dict with keys: "ok", "exit_code", "stdout", "stderr".
fn mpRunCode(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const code_string = args[0].string;

    const self_exe = getSelfExePath(allocator, io) orelse return BuiltinError.ValueError;
    defer allocator.free(self_exe);

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    argv_list.append(allocator, self_exe) catch return BuiltinError.OutOfMemory;
    argv_list.append(allocator, "-c") catch return BuiltinError.OutOfMemory;
    argv_list.append(allocator, code_string) catch return BuiltinError.OutOfMemory;

    if (args.len == 2) {
        if (args[1] != .list) return BuiltinError.TypeError;
        const extra_args = args[1].list;
        for (extra_args.items.items) |item| {
            if (item != .string) return BuiltinError.TypeError;
            argv_list.append(allocator, item.string) catch return BuiltinError.OutOfMemory;
        }
    }

    const result = std.process.run(allocator, io, .{
        .argv = argv_list.items,
    }) catch return BuiltinError.ValueError;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return buildResultDict(allocator, result.term, result.stdout, result.stderr);
}

// ============================================================================
// Process Management
// ============================================================================

/// mp_spawn(script_path) -> int
/// Spawns a child process running the script, returns integer handle.
/// stdout/stderr are inherited (not captured).
fn mpSpawn(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const script_path = args[0].string;

    const self_exe = getSelfExePath(allocator, io) orelse return BuiltinError.ValueError;
    defer allocator.free(self_exe);

    const self_exe_owned = allocator.dupe(u8, self_exe) catch return BuiltinError.OutOfMemory;

    const argv: []const []const u8 = allocator.dupe([]const u8, &.{ self_exe_owned, script_path }) catch return BuiltinError.OutOfMemory;

    var child = std.process.spawn(io, .{
        .argv = argv,
    }) catch return BuiltinError.ValueError;

    const handle = next_handle;
    next_handle += 1;

    const table = getChildren(allocator);
    table.put(handle, .{ .child = child }) catch {
        child.kill(io);
        return BuiltinError.OutOfMemory;
    };

    return .{ .integer = handle };
}

/// mp_wait(handle) -> int
/// Blocks until child exits, returns exit code as integer.
/// Cleans up handle from table.
fn mpWait(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;
    const table = getChildren(allocator);

    var entry = table.fetchRemove(handle) orelse return BuiltinError.ValueError;
    var child = &entry.value.child;

    const term = child.wait(io) catch return BuiltinError.ValueError;

    const exit_code: i64 = switch (term) {
        .exited => |code| @intCast(code),
        .signal => |sig| -@as(i64, @intCast(@intFromEnum(sig))),
        .stopped => |code| -@as(i64, @intCast(code)),
        .unknown => |code| -@as(i64, @intCast(code)),
    };

    return .{ .integer = exit_code };
}

/// mp_poll(handle) -> int or none
/// Checks if child has finished. Returns none if still running, exit code if finished.
/// Note: True non-blocking poll is not available in Zig 0.16 Io API.
/// This always returns none (still running) as a safe fallback; use mp_wait to block.
fn mpPoll(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;
    const table = getChildren(allocator);

    if (!table.contains(handle)) return BuiltinError.ValueError;

    return .none;
}

/// mp_kill(handle) -> bool
/// Terminates the child process. Returns true on success, false on failure.
fn mpKill(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const handle = args[0].integer;
    const table = getChildren(allocator);

    var entry = table.fetchRemove(handle) orelse return .{ .boolean = false };
    var child = &entry.value.child;

    child.kill(io);

    return .{ .boolean = true };
}

// ============================================================================
// System Info
// ============================================================================

/// mp_cpu_count() -> int
/// Returns the number of logical CPUs available.
fn mpCpuCount(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;

    const count = std.Thread.getCpuCount() catch return .{ .integer = 1 };
    return .{ .integer = @intCast(count) };
}

// ============================================================================
// Timing
// ============================================================================

/// mp_sleep(milliseconds) -> none
/// Sleeps for the given duration in milliseconds.
fn mpSleep(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;

    const ms = args[0].integer;
    if (ms < 0) return BuiltinError.ValueError;

    const duration = std.Io.Duration.fromMilliseconds(ms);
    io.sleep(duration, .real) catch {};

    return .none;
}
