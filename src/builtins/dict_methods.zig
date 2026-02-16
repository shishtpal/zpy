//! Dict methods module - dictionary method implementations.
//!
//! This module provides all dictionary methods:
//! - `get`, `keys`, `values`, `items` - accessors
//! - `clear`, `update`, `pop` - modification

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const valuesEqual = runtime.valuesEqual;
const RuntimeError = runtime.RuntimeError;

/// Calls a dict method by name.
///
/// Parameters:
/// - allocator: Memory allocator for dict operations
/// - dict: The dictionary to operate on
/// - method: Name of the method to call
/// - args: Arguments to pass to the method
///
/// Returns the result of the method call or an error.
pub fn callDictMethod(
    allocator: std.mem.Allocator,
    dict: *Value.Dict,
    method: []const u8,
    args: []Value,
) RuntimeError!Value {
    if (std.mem.eql(u8, method, "get")) {
        return get(dict, args);
    } else if (std.mem.eql(u8, method, "keys")) {
        return keys(allocator, dict, args);
    } else if (std.mem.eql(u8, method, "values")) {
        return values(allocator, dict, args);
    } else if (std.mem.eql(u8, method, "items")) {
        return items(allocator, dict, args);
    } else if (std.mem.eql(u8, method, "clear")) {
        return clear(dict, args);
    } else if (std.mem.eql(u8, method, "update")) {
        return update(dict, args);
    } else if (std.mem.eql(u8, method, "pop")) {
        return pop(dict, args);
    } else {
        return RuntimeError.UnsupportedOperation;
    }
}

/// Gets a value by key with optional default.
fn get(dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len < 1 or args.len > 2) return RuntimeError.BuiltinError;
    if (dict.get(args[0])) |val| return val;
    if (args.len == 2) return args[1];
    return .none;
}

/// Returns a list of all keys.
fn keys(allocator: std.mem.Allocator, dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const list = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
    list.* = Value.List.init(allocator);
    for (dict.keys.items) |key| {
        list.items.append(list.allocator, key) catch return RuntimeError.OutOfMemory;
    }
    return .{ .list = list };
}

/// Returns a list of all values.
fn values(allocator: std.mem.Allocator, dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const list = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
    list.* = Value.List.init(allocator);
    for (dict.values.items) |val| {
        list.items.append(list.allocator, val) catch return RuntimeError.OutOfMemory;
    }
    return .{ .list = list };
}

/// Returns a list of key-value pairs.
fn items(allocator: std.mem.Allocator, dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const list = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
    list.* = Value.List.init(allocator);
    for (dict.keys.items, 0..) |key, i| {
        const pair = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
        pair.* = Value.List.init(allocator);
        pair.items.append(pair.allocator, key) catch return RuntimeError.OutOfMemory;
        pair.items.append(pair.allocator, dict.values.items[i]) catch return RuntimeError.OutOfMemory;
        list.items.append(list.allocator, .{ .list = pair }) catch return RuntimeError.OutOfMemory;
    }
    return .{ .list = list };
}

/// Clears all key-value pairs.
fn clear(dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    dict.keys.items.len = 0;
    dict.values.items.len = 0;
    return .none;
}

/// Updates the dict with another dict's key-value pairs.
fn update(dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .dict) return RuntimeError.TypeError;
    const other = args[0].dict;
    for (other.keys.items, 0..) |key, i| {
        dict.set(key, other.values.items[i]) catch return RuntimeError.OutOfMemory;
    }
    return .none;
}

/// Removes and returns a value by key.
fn pop(dict: *Value.Dict, args: []Value) RuntimeError!Value {
    if (args.len < 1 or args.len > 2) return RuntimeError.BuiltinError;
    for (dict.keys.items, 0..) |key, i| {
        if (valuesEqual(key, args[0])) {
            const val = dict.values.items[i];
            var j = i;
            while (j + 1 < dict.keys.items.len) : (j += 1) {
                dict.keys.items[j] = dict.keys.items[j + 1];
                dict.values.items[j] = dict.values.items[j + 1];
            }
            dict.keys.items.len -= 1;
            dict.values.items.len -= 1;
            return val;
        }
    }
    if (args.len == 2) return args[1];
    return RuntimeError.KeyNotFound;
}

// ============================================================================
// Tests
// ============================================================================

test "dict_methods: get" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dict = Value.Dict.init(alloc);
    try dict.set(.{ .string = "key" }, .{ .integer = 42 });

    var args = [_]Value{.{ .string = "key" }};
    const result = try callDictMethod(alloc, &dict, "get", &args);
    try std.testing.expectEqual(@as(i64, 42), result.integer);
}

test "dict_methods: get with default" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dict = Value.Dict.init(alloc);

    var args = [_]Value{ .{ .string = "missing" }, .{ .integer = 99 } };
    const result = try callDictMethod(alloc, &dict, "get", &args);
    try std.testing.expectEqual(@as(i64, 99), result.integer);
}

test "dict_methods: keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dict = Value.Dict.init(alloc);
    try dict.set(.{ .string = "a" }, .{ .integer = 1 });
    try dict.set(.{ .string = "b" }, .{ .integer = 2 });

    const result = try callDictMethod(alloc, &dict, "keys", &[_]Value{});
    try std.testing.expectEqual(@as(usize, 2), result.list.items.items.len);
}

test "dict_methods: clear" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dict = Value.Dict.init(alloc);
    try dict.set(.{ .string = "key" }, .{ .integer = 42 });

    _ = try callDictMethod(alloc, &dict, "clear", &[_]Value{});
    try std.testing.expectEqual(@as(usize, 0), dict.keys.items.len);
}
