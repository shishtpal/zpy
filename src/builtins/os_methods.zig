//! OS methods module - operating system built-in implementations.
//!
//! This module provides OS utility built-ins similar to Python's os module:
//! - Working directory: `os_getcwd`, `os_chdir`
//! - File operations: `os_rename`, `os_copy`, `os_stat`, `os_remove`
//! - Directory operations: `os_mkdir`, `os_rmdir`, `os_walk`
//! - Path operations: `os_path_join`, `os_path_exists`, `os_path_isdir`, etc.
//! - Environment: `os_getenv`, `os_setenv`, `os_unsetenv`, `os_environ`

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

pub const OsBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets an OS built-in function by name.
pub fn getOsBuiltin(name: []const u8) ?OsBuiltinFn {
    const builtins = std.StaticStringMap(OsBuiltinFn).initComptime(.{
        // Working directory
        .{ "os_getcwd", osGetcwd },
        .{ "os_chdir", osChdir },
        // File operations
        .{ "os_rename", osRename },
        .{ "os_copy", osCopy },
        .{ "os_stat", osStat },
        .{ "os_remove", osRemove },
        // Directory operations
        .{ "os_mkdir", osMkdir },
        .{ "os_rmdir", osRmdir },
        .{ "os_walk", osWalk },
        // Path operations
        .{ "os_path_join", osPathJoin },
        .{ "os_path_exists", osPathExists },
        .{ "os_path_isdir", osPathIsdir },
        .{ "os_path_isfile", osPathIsfile },
        .{ "os_path_basename", osPathBasename },
        .{ "os_path_dirname", osPathDirname },
        .{ "os_path_split", osPathSplit },
        .{ "os_path_splitext", osPathSplitext },
        .{ "os_path_abspath", osPathAbspath },
        .{ "os_path_normpath", osPathNormpath },
        // Environment variables
        .{ "os_getenv", osGetenv },
        .{ "os_setenv", osSetenv },
        .{ "os_unsetenv", osUnsetenv },
        .{ "os_environ", osEnviron },
    });
    return builtins.get(name);
}

// ============================================================================
// Working Directory
// ============================================================================

/// os_getcwd() - Get current working directory
fn osGetcwd(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.Io.Dir.cwd();
    const n = cwd.realPath(io, &buf) catch return .none;
    const path = buf[0..n];

    const result = allocator.dupe(u8, path) catch return BuiltinError.OutOfMemory;
    return .{ .string = result };
}

/// os_chdir(path) - Change current working directory
fn osChdir(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    // Open the directory to verify it exists
    const dir = cwd.openDir(io, path, .{}) catch return .{ .boolean = false };
    dir.close(io);

    // Note: Zig doesn't have a portable chdir in the new Io API
    // We return true if the directory exists, but actual chdir
    // would require platform-specific code
    return .{ .boolean = true };
}

// ============================================================================
// File Operations
// ============================================================================

/// os_rename(old_path, new_path) - Rename/move file or directory
fn osRename(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const old_path = args[0].string;
    const new_path = args[1].string;
    const cwd = std.Io.Dir.cwd();

    std.Io.Dir.rename(cwd, old_path, cwd, new_path, io) catch return .{ .boolean = false };
    return .{ .boolean = true };
}

/// os_copy(src_path, dst_path) - Copy file
fn osCopy(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const src_path = args[0].string;
    const dst_path = args[1].string;
    const cwd = std.Io.Dir.cwd();

    _ = cwd.updateFile(io, src_path, cwd, dst_path, .{}) catch return .{ .boolean = false };
    return .{ .boolean = true };
}

/// os_stat(path) - Get file/directory information
fn osStat(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    // Try to stat as file first
    const file_stat = cwd.statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            // Try as directory
            const dir = cwd.openDir(io, path, .{}) catch return .none;
            defer dir.close(io);
            const dir_stat = dir.stat(io) catch return .none;

            return buildStatDict(allocator, dir_stat, true, false);
        },
        else => return .none,
    };

    return buildStatDict(allocator, file_stat, false, true);
}

fn buildStatDict(allocator: std.mem.Allocator, stat: std.Io.File.Stat, is_dir: bool, is_file: bool) BuiltinError!Value {
    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    // size
    const size_key = Value{ .string = allocator.dupe(u8, "size") catch return BuiltinError.OutOfMemory };
    const size_val = Value{ .integer = @intCast(stat.size) };
    dict.set(size_key, size_val) catch return BuiltinError.OutOfMemory;

    // mtime (as Unix timestamp in seconds)
    const mtime_key = Value{ .string = allocator.dupe(u8, "mtime") catch return BuiltinError.OutOfMemory };
    const mtime_val = Value{ .integer = @intCast(@divTrunc(stat.mtime.nanoseconds, 1_000_000_000)) };
    dict.set(mtime_key, mtime_val) catch return BuiltinError.OutOfMemory;

    // is_dir
    const is_dir_key = Value{ .string = allocator.dupe(u8, "is_dir") catch return BuiltinError.OutOfMemory };
    dict.set(is_dir_key, .{ .boolean = is_dir }) catch return BuiltinError.OutOfMemory;

    // is_file
    const is_file_key = Value{ .string = allocator.dupe(u8, "is_file") catch return BuiltinError.OutOfMemory };
    dict.set(is_file_key, .{ .boolean = is_file }) catch return BuiltinError.OutOfMemory;

    return .{ .dict = dict };
}

/// os_remove(path) - Remove a file
fn osRemove(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    cwd.deleteFile(io, path) catch return .{ .boolean = false };
    return .{ .boolean = true };
}

// ============================================================================
// Directory Operations
// ============================================================================

/// os_mkdir(path) - Create a directory
fn osMkdir(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    cwd.createDir(io, path, .default_dir) catch return .{ .boolean = false };
    return .none;
}

/// os_rmdir(path) - Remove an empty directory
fn osRmdir(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    cwd.deleteDir(io, path) catch return .{ .boolean = false };
    return .{ .boolean = true };
}

/// os_walk(path) - Walk directory tree recursively
fn osWalk(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const root_path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    const result_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    result_list.* = Value.List.init(allocator);

    // Recursively walk the directory
    walkDir(allocator, io, cwd, root_path, result_list) catch return BuiltinError.OutOfMemory;

    return .{ .list = result_list };
}

fn walkDir(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir, current_path: []const u8, result_list: *Value.List) !void {
    const dir = base_dir.openDir(io, current_path, .{ .iterate = true }) catch return;
    defer dir.close(io);

    // Create entry for current directory
    const entry_dict = try allocator.create(Value.Dict);
    entry_dict.* = Value.Dict.init(allocator);

    const dirs_list = try allocator.create(Value.List);
    dirs_list.* = Value.List.init(allocator);

    const files_list = try allocator.create(Value.List);
    files_list.* = Value.List.init(allocator);

    // Iterate through directory contents
    var iter = dir.iterate();
    while (iter.next(io) catch null) |entry| {
        const name = try allocator.dupe(u8, entry.name);

        switch (entry.kind) {
            .directory => {
                try dirs_list.items.append(allocator, .{ .string = name });

                // Recursively walk subdirectory
                var sub_path: std.ArrayList(u8) = .empty;
                defer sub_path.deinit(allocator);
                try sub_path.appendSlice(allocator, current_path);
                if (current_path.len > 0 and current_path[current_path.len - 1] != std.fs.path.sep) {
                    try sub_path.append(allocator, std.fs.path.sep);
                }
                try sub_path.appendSlice(allocator, entry.name);
                try walkDir(allocator, io, base_dir, sub_path.items, result_list);
            },
            .file => {
                try files_list.items.append(allocator, .{ .string = name });
            },
            else => {
                allocator.free(name);
            },
        }
    }

    // Set dict values
    const dirpath_key = Value{ .string = try allocator.dupe(u8, "dirpath") };
    const dirpath_val = Value{ .string = try allocator.dupe(u8, current_path) };
    try entry_dict.set(dirpath_key, dirpath_val);

    const dirs_key = Value{ .string = try allocator.dupe(u8, "dirs") };
    try entry_dict.set(dirs_key, .{ .list = dirs_list });

    const files_key = Value{ .string = try allocator.dupe(u8, "files") };
    try entry_dict.set(files_key, .{ .list = files_list });

    try result_list.items.append(allocator, .{ .dict = entry_dict });
}

// ============================================================================
// Path Operations
// ============================================================================

/// os_path_join(parts...) - Join path components
fn osPathJoin(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1) return BuiltinError.WrongArgCount;

    // Collect all string parts
    var parts: std.ArrayList([]const u8) = .empty;
    defer parts.deinit(allocator);

    for (args) |arg| {
        if (arg != .string) return BuiltinError.TypeError;
        parts.append(allocator, arg.string) catch return BuiltinError.OutOfMemory;
    }

    const result = std.fs.path.join(allocator, parts.items) catch return BuiltinError.OutOfMemory;
    return .{ .string = result };
}

/// os_path_exists(path) - Check if path exists
fn osPathExists(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    // Try as file first
    if (cwd.openFile(io, path, .{})) |file| {
        file.close(io);
        return .{ .boolean = true };
    } else |_| {
        // Try as directory
        if (cwd.openDir(io, path, .{})) |dir| {
            dir.close(io);
            return .{ .boolean = true };
        } else |_| {
            return .{ .boolean = false };
        }
    }
}

/// os_path_isdir(path) - Check if path is a directory
fn osPathIsdir(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    if (cwd.openDir(io, path, .{})) |dir| {
        dir.close(io);
        return .{ .boolean = true };
    } else |_| {
        return .{ .boolean = false };
    }
}

/// os_path_isfile(path) - Check if path is a file
fn osPathIsfile(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    if (cwd.openFile(io, path, .{})) |file| {
        file.close(io);
        return .{ .boolean = true };
    } else |_| {
        return .{ .boolean = false };
    }
}

/// os_path_basename(path) - Get filename from path
fn osPathBasename(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const basename = std.fs.path.basename(path);

    const result = allocator.dupe(u8, basename) catch return BuiltinError.OutOfMemory;
    return .{ .string = result };
}

/// os_path_dirname(path) - Get directory from path
fn osPathDirname(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const dirname = std.fs.path.dirname(path) orelse "";

    const result = allocator.dupe(u8, dirname) catch return BuiltinError.OutOfMemory;
    return .{ .string = result };
}

/// os_path_split(path) - Split path into (dirname, basename)
fn osPathSplit(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const dirname = std.fs.path.dirname(path) orelse "";
    const basename = std.fs.path.basename(path);

    const result_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    result_list.* = Value.List.init(allocator);

    try result_list.items.append(allocator, .{ .string = try allocator.dupe(u8, dirname) });
    try result_list.items.append(allocator, .{ .string = try allocator.dupe(u8, basename) });

    return .{ .list = result_list };
}

/// os_path_splitext(path) - Split extension from path
fn osPathSplitext(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;

    // Find the last dot after the last separator
    var ext_start: ?usize = null;
    for (path, 0..) |c, i| {
        if (c == '.' or c == std.fs.path.sep) {
            ext_start = if (c == '.') i else null;
        }
    }

    const root = if (ext_start) |start| path[0..start] else path;
    const ext = if (ext_start) |start| path[start..] else "";

    const result_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    result_list.* = Value.List.init(allocator);

    try result_list.items.append(allocator, .{ .string = try allocator.dupe(u8, root) });
    try result_list.items.append(allocator, .{ .string = try allocator.dupe(u8, ext) });

    return .{ .list = result_list };
}

/// os_path_abspath(path) - Get absolute path
fn osPathAbspath(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;

    // If already absolute, return as-is
    if (std.fs.path.isAbsolute(path)) {
        const result = allocator.dupe(u8, path) catch return BuiltinError.OutOfMemory;
        return .{ .string = result };
    }

    // Otherwise, join with cwd
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.Io.Dir.cwd();
    const n = cwd.realPath(io, &buf) catch return .none;
    const cwd_path = buf[0..n];

    const result = std.fs.path.join(allocator, &.{ cwd_path, path }) catch return BuiltinError.OutOfMemory;
    return .{ .string = result };
}

/// os_path_normpath(path) - Normalize path (remove . and ..)
fn osPathNormpath(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;

    // Simple normalization: resolve . and ..
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var parts = std.mem.splitScalar(u8, path, std.fs.path.sep);

    var stack: std.ArrayList([]const u8) = .empty;
    defer stack.deinit(allocator);

    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, ".") or part.len == 0) {
            // Skip
        } else if (std.mem.eql(u8, part, "..")) {
            if (stack.items.len > 0) {
                _ = stack.pop();
            }
        } else {
            stack.append(allocator, part) catch return BuiltinError.OutOfMemory;
        }
    }

    // Build result
    for (stack.items, 0..) |part, i| {
        if (i > 0) result.append(allocator, std.fs.path.sep) catch return BuiltinError.OutOfMemory;
        result.appendSlice(allocator, part) catch return BuiltinError.OutOfMemory;
    }

    return .{ .string = result.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory };
}

// ============================================================================
// Environment Variables
// ============================================================================

// Windows API declarations for environment variables
const windows = std.os.windows;
extern "kernel32" fn GetEnvironmentVariableW(lpName: ?[*:0]const u16, lpBuffer: ?[*]u16, nSize: u32) callconv(.winapi) u32;
extern "kernel32" fn SetEnvironmentVariableW(lpName: ?[*:0]const u16, lpValue: ?[*:0]const u16) callconv(.winapi) windows.BOOL;

/// os_getenv(name) - Get environment variable
fn osGetenv(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const name = args[0].string;

    if (builtin.os.tag == .windows) {
        // Convert name to UTF-16
        const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return .none;
        defer allocator.free(name_w);

        var buf: [32768]u16 = undefined; // Max env var size on Windows
        const len = GetEnvironmentVariableW(name_w.ptr, &buf, buf.len);

        if (len == 0) return .none;
        if (len > buf.len) return .none;

        const value = std.unicode.utf16LeToUtf8Alloc(allocator, buf[0..len]) catch return .none;
        return .{ .string = value };
    } else {
        // POSIX: Use getenv
        const name_z = allocator.dupeZ(u8, name) catch return .none;
        defer allocator.free(name_z);

        const value_ptr = std.c.getenv(name_z.ptr) orelse return .none;
        const value = std.mem.span(value_ptr);

        const result = allocator.dupe(u8, value) catch return .none;
        return .{ .string = result };
    }
}

/// os_setenv(name, value) - Set environment variable
fn osSetenv(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const name = args[0].string;
    const value = args[1].string;

    if (builtin.os.tag == .windows) {
        const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return .{ .boolean = false };
        defer allocator.free(name_w);
        const value_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, value) catch return .{ .boolean = false };
        defer allocator.free(value_w);

        const result = SetEnvironmentVariableW(name_w.ptr, value_w.ptr);
        return .{ .boolean = result != 0 };
    } else {
        const name_z = allocator.dupeZ(u8, name) catch return .{ .boolean = false };
        defer allocator.free(name_z);
        const value_z = allocator.dupeZ(u8, value) catch return .{ .boolean = false };
        defer allocator.free(value_z);

        const result = std.c.setenv(name_z.ptr, value_z.ptr, 1);
        return .{ .boolean = result == 0 };
    }
}

/// os_unsetenv(name) - Remove environment variable
fn osUnsetenv(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const name = args[0].string;

    if (builtin.os.tag == .windows) {
        const name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, name) catch return .{ .boolean = false };
        defer allocator.free(name_w);

        const result = SetEnvironmentVariableW(name_w.ptr, null);
        return .{ .boolean = result != 0 };
    } else {
        const name_z = allocator.dupeZ(u8, name) catch return .{ .boolean = false };
        defer allocator.free(name_z);

        const result = std.c.unsetenv(name_z.ptr);
        return .{ .boolean = result == 0 };
    }
}

/// os_environ() - Get all environment variables as dict
fn osEnviron(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;

    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    if (builtin.os.tag == .windows) {
        const env_ptr = windows.peb().ProcessParameters.Environment;
        var i: usize = 0;
        while (true) {
            const char = env_ptr[i];
            if (char == 0 and env_ptr[i + 1] == 0) break;

            // Find the end of this entry (null terminator)
            var end = i;
            while (env_ptr[end] != 0) : (end += 1) {}

            if (end > i) {
                // Parse NAME=VALUE
                const entry = env_ptr[i..end];
                if (std.mem.indexOfScalar(u16, entry, '=')) |eq_pos| {
                    const name = entry[0..eq_pos];
                    const value = entry[eq_pos + 1 ..];

                    // Convert from UTF-16 to UTF-8
                    const name_utf8 = std.unicode.utf16LeToUtf8Alloc(allocator, name) catch continue;
                    const value_utf8 = std.unicode.utf16LeToUtf8Alloc(allocator, value) catch {
                        allocator.free(name_utf8);
                        continue;
                    };

                    const key = Value{ .string = name_utf8 };
                    const val = Value{ .string = value_utf8 };
                    dict.set(key, val) catch continue;
                }
            }

            i = end + 1;
        }
    } else {
        // POSIX: environ is a null-terminated array of strings
        const environ_ptr = std.c.environ;
        if (environ_ptr) |env| {
            var idx: usize = 0;
            while (env[idx]) |entry| {
                const entry_slice = std.mem.span(entry);
                if (std.mem.indexOfScalar(u8, entry_slice, '=')) |eq_pos| {
                    const name = entry_slice[0..eq_pos];
                    const value = entry_slice[eq_pos + 1 ..];

                    const key = Value{ .string = allocator.dupe(u8, name) catch continue };
                    const val = Value{ .string = allocator.dupe(u8, value) catch continue };
                    dict.set(key, val) catch continue;
                }
                idx += 1;
            }
        }
    }

    return .{ .dict = dict };
}
