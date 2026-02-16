//! String methods module - string method implementations.
//!
//! This module provides all string methods:
//! - `upper`, `lower` - case conversion
//! - `strip`, `lstrip`, `rstrip` - whitespace trimming
//! - `split`, `join` - splitting and joining
//! - `find`, `replace`, `count`, `contains` - searching
//! - `startswith`, `endswith` - prefix/suffix checking

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const RuntimeError = runtime.RuntimeError;

/// Calls a string method by name.
///
/// Parameters:
/// - allocator: Memory allocator for string operations
/// - s: The string to operate on
/// - method: Name of the method to call
/// - args: Arguments to pass to the method
///
/// Returns the result of the method call or an error.
pub fn callStringMethod(
    allocator: std.mem.Allocator,
    s: []const u8,
    method: []const u8,
    args: []Value,
) RuntimeError!Value {
    if (std.mem.eql(u8, method, "upper")) {
        return upper(allocator, s, args);
    } else if (std.mem.eql(u8, method, "lower")) {
        return lower(allocator, s, args);
    } else if (std.mem.eql(u8, method, "strip")) {
        return strip(s, args);
    } else if (std.mem.eql(u8, method, "lstrip")) {
        return lstrip(s, args);
    } else if (std.mem.eql(u8, method, "rstrip")) {
        return rstrip(s, args);
    } else if (std.mem.eql(u8, method, "split")) {
        return split(allocator, s, args);
    } else if (std.mem.eql(u8, method, "join")) {
        return join(allocator, s, args);
    } else if (std.mem.eql(u8, method, "find")) {
        return find(s, args);
    } else if (std.mem.eql(u8, method, "replace")) {
        return replace(allocator, s, args);
    } else if (std.mem.eql(u8, method, "startswith")) {
        return startswith(s, args);
    } else if (std.mem.eql(u8, method, "endswith")) {
        return endswith(s, args);
    } else if (std.mem.eql(u8, method, "count")) {
        return count(s, args);
    } else if (std.mem.eql(u8, method, "contains")) {
        return contains(s, args);
    } else {
        return RuntimeError.UnsupportedOperation;
    }
}

/// Converts string to uppercase.
fn upper(allocator: std.mem.Allocator, s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const result = allocator.alloc(u8, s.len) catch return RuntimeError.OutOfMemory;
    for (s, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }
    return .{ .string = result };
}

/// Converts string to lowercase.
fn lower(allocator: std.mem.Allocator, s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const result = allocator.alloc(u8, s.len) catch return RuntimeError.OutOfMemory;
    for (s, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }
    return .{ .string = result };
}

/// Strips whitespace from both ends.
fn strip(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    return .{ .string = trimmed };
}

/// Strips whitespace from the start.
fn lstrip(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const trimmed = std.mem.trimStart(u8, s, " \t\r\n");
    return .{ .string = trimmed };
}

/// Strips whitespace from the end.
fn rstrip(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const trimmed = std.mem.trimEnd(u8, s, " \t\r\n");
    return .{ .string = trimmed };
}

/// Splits string by separator.
fn split(allocator: std.mem.Allocator, s: []const u8, args: []Value) RuntimeError!Value {
    const sep: []const u8 = if (args.len > 0) blk: {
        if (args[0] != .string) return RuntimeError.TypeError;
        break :blk args[0].string;
    } else " ";

    const list = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
    list.* = Value.List.init(allocator);

    var iter = std.mem.splitSequence(u8, s, sep);
    while (iter.next()) |part| {
        if (args.len == 0 and part.len == 0) continue;
        list.items.append(list.allocator, .{ .string = part }) catch return RuntimeError.OutOfMemory;
    }

    return .{ .list = list };
}

/// Joins a list of strings with this string as separator.
fn join(allocator: std.mem.Allocator, s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .list) return RuntimeError.TypeError;
    const items = args[0].list.items.items;

    var total_len: usize = 0;
    for (items, 0..) |item, i| {
        if (item != .string) return RuntimeError.TypeError;
        total_len += item.string.len;
        if (i > 0) total_len += s.len;
    }

    const result = allocator.alloc(u8, total_len) catch return RuntimeError.OutOfMemory;
    var pos: usize = 0;
    for (items, 0..) |item, i| {
        if (i > 0) {
            @memcpy(result[pos .. pos + s.len], s);
            pos += s.len;
        }
        @memcpy(result[pos .. pos + item.string.len], item.string);
        pos += item.string.len;
    }

    return .{ .string = result };
}

/// Finds the first occurrence of a substring.
fn find(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .string) return RuntimeError.TypeError;
    if (std.mem.indexOf(u8, s, args[0].string)) |idx| {
        return .{ .integer = @intCast(idx) };
    }
    return .{ .integer = -1 };
}

/// Replaces all occurrences of a substring.
fn replace(allocator: std.mem.Allocator, s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 2 or args[0] != .string or args[1] != .string) return RuntimeError.TypeError;
    const old = args[0].string;
    const new = args[1].string;

    var match_count: usize = 0;
    var search_pos: usize = 0;
    while (search_pos <= s.len) {
        if (std.mem.indexOfPos(u8, s, search_pos, old)) |idx| {
            match_count += 1;
            search_pos = idx + old.len;
        } else break;
    }

    if (match_count == 0) return .{ .string = s };

    const new_len = s.len - (match_count * old.len) + (match_count * new.len);
    const result = allocator.alloc(u8, new_len) catch return RuntimeError.OutOfMemory;
    var src_pos: usize = 0;
    var dst_pos: usize = 0;
    while (src_pos <= s.len) {
        if (std.mem.indexOfPos(u8, s, src_pos, old)) |idx| {
            const chunk_len = idx - src_pos;
            @memcpy(result[dst_pos .. dst_pos + chunk_len], s[src_pos..idx]);
            dst_pos += chunk_len;
            @memcpy(result[dst_pos .. dst_pos + new.len], new);
            dst_pos += new.len;
            src_pos = idx + old.len;
        } else {
            const remaining = s.len - src_pos;
            @memcpy(result[dst_pos .. dst_pos + remaining], s[src_pos..]);
            break;
        }
    }

    return .{ .string = result };
}

/// Checks if string starts with prefix.
fn startswith(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .string) return RuntimeError.TypeError;
    return .{ .boolean = std.mem.startsWith(u8, s, args[0].string) };
}

/// Checks if string ends with suffix.
fn endswith(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .string) return RuntimeError.TypeError;
    return .{ .boolean = std.mem.endsWith(u8, s, args[0].string) };
}

/// Counts occurrences of a substring.
fn count(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .string) return RuntimeError.TypeError;
    const needle = args[0].string;
    if (needle.len == 0) return .{ .integer = @as(i64, @intCast(s.len + 1)) };
    var cnt: i64 = 0;
    var pos: usize = 0;
    while (pos <= s.len) {
        if (std.mem.indexOfPos(u8, s, pos, needle)) |idx| {
            cnt += 1;
            pos = idx + needle.len;
        } else break;
    }
    return .{ .integer = cnt };
}

/// Checks if string contains a substring.
fn contains(s: []const u8, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .string) return RuntimeError.TypeError;
    return .{ .boolean = std.mem.indexOf(u8, s, args[0].string) != null };
}

// ============================================================================
// Tests
// ============================================================================

test "string_methods: upper" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try callStringMethod(alloc, "hello", "upper", &[_]Value{});
    try std.testing.expectEqualStrings("HELLO", result.string);
}

test "string_methods: lower" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try callStringMethod(alloc, "HELLO", "lower", &[_]Value{});
    try std.testing.expectEqualStrings("hello", result.string);
}

test "string_methods: strip" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try callStringMethod(alloc, "  hello  ", "strip", &[_]Value{});
    try std.testing.expectEqualStrings("hello", result.string);
}

test "string_methods: split" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = [_]Value{.{ .string = "," }};
    const result = try callStringMethod(alloc, "a,b,c", "split", &args);
    try std.testing.expectEqual(@as(usize, 3), result.list.items.items.len);
}

test "string_methods: find" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = [_]Value{.{ .string = "world" }};
    const result = try callStringMethod(alloc, "hello world", "find", &args);
    try std.testing.expectEqual(@as(i64, 6), result.integer);
}

test "string_methods: startswith" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = [_]Value{.{ .string = "hello" }};
    const result = try callStringMethod(alloc, "hello world", "startswith", &args);
    try std.testing.expect(result.boolean);
}

test "string_methods: contains" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var args = [_]Value{.{ .string = "world" }};
    const result = try callStringMethod(alloc, "hello world", "contains", &args);
    try std.testing.expect(result.boolean);
}
