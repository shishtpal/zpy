//! File methods module - file system built-in implementations.
//!
//! This module provides all file system built-ins:
//! - `file_read`, `file_write`, `file_append`, `file_delete`, `file_exists` - file operations
//! - `dir_list`, `dir_create`, `dir_exists` - directory operations

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const FileBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a file built-in function by name.
pub fn getFileBuiltin(name: []const u8) ?FileBuiltinFn {
    const builtins = std.StaticStringMap(FileBuiltinFn).initComptime(.{
        .{ "file_read", fileRead },
        .{ "file_write", fileWrite },
        .{ "file_append", fileAppend },
        .{ "file_delete", fileDelete },
        .{ "file_exists", fileExists },
        .{ "dir_list", dirList },
        .{ "dir_create", dirCreate },
        .{ "dir_exists", dirExists },
    });
    return builtins.get(name);
}

// ============================================================================
// File Operations
// ============================================================================

/// file_read(path) - Read file contents as string
fn fileRead(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(io, path, .{}) catch return .none;
    defer file.close(io);

    const stat = file.stat(io) catch return .none;
    const file_size: usize = @intCast(stat.size);

    const content = allocator.alloc(u8, file_size) catch return BuiltinError.OutOfMemory;
    _ = file.readPositional(io, &[_][]u8{content}, 0) catch {
        allocator.free(content);
        return .none;
    };

    return .{ .string = content };
}

/// file_write(path, content) - Write content to file (creates or overwrites)
fn fileWrite(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const content = args[1].string;
    const cwd = std.Io.Dir.cwd();

    const file = cwd.createFile(io, path, .{}) catch return .{ .boolean = false };
    defer file.close(io);

    // Cast away const for writePositional (safe - we're only reading)
    const mutable_content: []u8 = @constCast(content);
    _ = file.writePositional(io, &[_][]u8{mutable_content}, 0) catch return .{ .boolean = false };
    return .none;
}

/// file_append(path, content) - Append content to file
fn fileAppend(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const content = args[1].string;
    const cwd = std.Io.Dir.cwd();

    // Cast away const for writePositional (safe - we're only reading)
    const mutable_content: []u8 = @constCast(content);

    // Open for appending (write-only, seek to end)
    const file = cwd.openFile(io, path, .{ .mode = .write_only }) catch {
        // If file doesn't exist, create it
        const new_file = cwd.createFile(io, path, .{}) catch return .{ .boolean = false };
        defer new_file.close(io);
        _ = new_file.writePositional(io, &[_][]u8{mutable_content}, 0) catch return .{ .boolean = false };
        return .none;
    };
    defer file.close(io);

    // Get current file size and write at that position (append)
    const stat = file.stat(io) catch return .{ .boolean = false };
    _ = file.writePositional(io, &[_][]u8{mutable_content}, stat.size) catch return .{ .boolean = false };
    return .none;
}

/// file_delete(path) - Delete a file, returns true on success
fn fileDelete(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    cwd.deleteFile(io, path) catch return .{ .boolean = false };
    return .{ .boolean = true };
}

/// file_exists(path) - Check if file exists
fn fileExists(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(io, path, .{}) catch return .{ .boolean = false };
    file.close(io);
    return .{ .boolean = true };
}

// ============================================================================
// Directory Operations
// ============================================================================

/// dir_list(path) - List directory contents
fn dirList(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    const dir = cwd.openDir(io, path, .{ .iterate = true }) catch return .{ .list = blk: {
        const empty_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
        empty_list.* = Value.List.init(allocator);
        break :blk empty_list;
    } };
    defer dir.close(io);

    const list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    list.* = Value.List.init(allocator);

    var iter = dir.iterate();
    while (iter.next(io) catch null) |entry| {
        const name = allocator.dupe(u8, entry.name) catch return BuiltinError.OutOfMemory;
        list.items.append(allocator, .{ .string = name }) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = list };
}

/// dir_create(path) - Create a directory
fn dirCreate(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    cwd.createDir(io, path, .default_dir) catch return .{ .boolean = false };
    return .none;
}

/// dir_exists(path) - Check if directory exists
fn dirExists(args: []Value, _: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const path = args[0].string;
    const cwd = std.Io.Dir.cwd();

    const dir = cwd.openDir(io, path, .{}) catch return .{ .boolean = false };
    dir.close(io);
    return .{ .boolean = true };
}
