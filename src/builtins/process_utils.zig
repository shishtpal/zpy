//! Shared process utilities for mp_methods and subprocess_methods modules.
//!
//! This module provides common functionality for process management:
//! - Exit code extraction from termination status
//! - Result dictionary building
//! - Process cleanup helpers
//! - CPU count and sleep utilities

const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

// Windows API for getting process ID from handle
extern "kernel32" fn GetProcessId(Process: std.os.windows.HANDLE) callconv(.winapi) std.os.windows.DWORD;

// ============================================================================
// Exit Code Extraction
// ============================================================================

/// Extract exit code from process termination status.
/// Returns positive exit code for normal exit, negative for signal/stop/unknown.
pub fn extractTermExitCode(term: std.process.Child.Term) i64 {
    return switch (term) {
        .exited => |code| @intCast(code),
        .signal => |sig| -@as(i64, @intCast(@intFromEnum(sig))),
        .stopped => |code| -@as(i64, @intCast(code)),
        .unknown => |code| -@as(i64, @intCast(code)),
    };
}

// ============================================================================
// Result Dictionary Building
// ============================================================================

/// Build a result dictionary with ok, exit_code, stdout, stderr, output keys.
/// This is used by both mp_methods and subprocess_methods for consistent results.
pub fn buildResultDict(
    allocator: std.mem.Allocator,
    term: std.process.Child.Term,
    stdout_data: []const u8,
    stderr_data: []const u8,
) BuiltinError!Value {
    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    const exit_code = extractTermExitCode(term);
    const ok = exit_code == 0;

    try setDictKey(allocator, dict, "ok", .{ .boolean = ok });
    try setDictKey(allocator, dict, "exit_code", .{ .integer = exit_code });
    try setDictKey(allocator, dict, "stdout", .{ .string = allocator.dupe(u8, stdout_data) catch return BuiltinError.OutOfMemory });
    try setDictKey(allocator, dict, "stderr", .{ .string = allocator.dupe(u8, stderr_data) catch return BuiltinError.OutOfMemory });

    // Combine stdout and stderr for "output" field
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
    try setDictKey(allocator, dict, "output", .{ .string = output });

    return .{ .dict = dict };
}

/// Helper to set a string key in a dict with proper memory allocation.
pub fn setDictKey(allocator: std.mem.Allocator, dict: *Value.Dict, key: []const u8, val: Value) BuiltinError!void {
    const k = Value{ .string = allocator.dupe(u8, key) catch return BuiltinError.OutOfMemory };
    dict.set(k, val) catch return BuiltinError.OutOfMemory;
}

// ============================================================================
// Process Cleanup
// ============================================================================

/// Close all pipes and kill the process if still running.
pub fn cleanupChild(child: *std.process.Child, io: std.Io) void {
    if (child.stdin) |f| {
        f.close(io);
        child.stdin = null;
    }
    if (child.stdout) |f| {
        f.close(io);
        child.stdout = null;
    }
    if (child.stderr) |f| {
        f.close(io);
        child.stderr = null;
    }
    if (child.id != null) {
        child.kill(io);
    }
}

/// Close all pipes without killing the process.
/// Use this when you want to release resources but let the process continue.
pub fn closeChildPipes(child: *std.process.Child, io: std.Io) void {
    if (child.stdin) |f| {
        f.close(io);
        child.stdin = null;
    }
    if (child.stdout) |f| {
        f.close(io);
        child.stdout = null;
    }
    if (child.stderr) |f| {
        f.close(io);
        child.stderr = null;
    }
}

// ============================================================================
// System Utilities
// ============================================================================

/// Get the number of logical CPUs available.
pub fn cpuCount() i64 {
    const count = std.Thread.getCpuCount() catch return 1;
    return @intCast(count);
}

/// Sleep for the specified duration in milliseconds.
pub fn sleepMs(io: std.Io, ms: i64) void {
    if (ms < 0) return;
    io.sleep(.{ .nanoseconds = @intCast(ms * std.time.ns_per_ms) }, .real) catch {};
}

/// Get process ID from a child process handle.
/// Returns null if the process has no ID or on Windows if GetProcessId fails.
pub fn getProcessId(child: *const std.process.Child) ?i64 {
    if (child.id) |id| {
        if (native_os == .windows) {
            const pid = GetProcessId(id);
            if (pid != 0) return @intCast(pid);
            return null;
        } else {
            return @intCast(id);
        }
    }
    return null;
}

// ============================================================================
// File Reading
// ============================================================================

/// Read all data from a file until EOF.
pub fn readAllFromFile(allocator: std.mem.Allocator, file: std.Io.File, io: std.Io) BuiltinError![]u8 {
    var result: std.ArrayList(u8) = .empty;
    var buf: [8192]u8 = undefined;

    while (true) {
        const n = file.readStreaming(io, &.{&buf}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return BuiltinError.ValueError,
        };
        if (n == 0) break;
        result.appendSlice(allocator, buf[0..n]) catch return BuiltinError.OutOfMemory;
    }

    return result.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory;
}

// ============================================================================
// Argument Conversion
// ============================================================================

/// Convert a ZPy list of strings to an argv array.
pub fn valueListToArgv(allocator: std.mem.Allocator, list: *Value.List) BuiltinError!std.ArrayList([]const u8) {
    var argv: std.ArrayList([]const u8) = .empty;
    for (list.items.items) |item| {
        if (item != .string) {
            argv.deinit(allocator);
            return BuiltinError.TypeError;
        }
        argv.append(allocator, item.string) catch {
            argv.deinit(allocator);
            return BuiltinError.OutOfMemory;
        };
    }
    return argv;
}
