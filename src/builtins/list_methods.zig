//! List methods module - list method implementations.
//!
//! This module provides all list methods:
//! - `append`, `pop`, `insert`, `remove` - element manipulation
//! - `reverse`, `clear`, `copy`, `extend` - list operations
//! - `index`, `count` - searching

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const valuesEqual = runtime.valuesEqual;
const RuntimeError = runtime.RuntimeError;

/// Calls a list method by name.
///
/// Parameters:
/// - allocator: Memory allocator for list operations
/// - list: The list to operate on
/// - method: Name of the method to call
/// - args: Arguments to pass to the method
///
/// Returns the result of the method call or an error.
pub fn callListMethod(
    allocator: std.mem.Allocator,
    list: *Value.List,
    method: []const u8,
    args: []Value,
) RuntimeError!Value {
    if (std.mem.eql(u8, method, "append")) {
        return append(list, args);
    } else if (std.mem.eql(u8, method, "pop")) {
        return pop(list, args);
    } else if (std.mem.eql(u8, method, "insert")) {
        return insert(list, args);
    } else if (std.mem.eql(u8, method, "remove")) {
        return remove(list, args);
    } else if (std.mem.eql(u8, method, "reverse")) {
        return reverse(list, args);
    } else if (std.mem.eql(u8, method, "clear")) {
        return clear(list, args);
    } else if (std.mem.eql(u8, method, "index")) {
        return index(list, args);
    } else if (std.mem.eql(u8, method, "count")) {
        return count(list, args);
    } else if (std.mem.eql(u8, method, "copy")) {
        return copy(allocator, list, args);
    } else if (std.mem.eql(u8, method, "extend")) {
        return extend(list, args);
    } else {
        return RuntimeError.UnsupportedOperation;
    }
}

/// Appends an element to the end of the list.
fn append(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 1) return RuntimeError.BuiltinError;
    list.items.append(list.allocator, args[0]) catch return RuntimeError.OutOfMemory;
    return .none;
}

/// Removes and returns an element from the list.
fn pop(list: *Value.List, args: []Value) RuntimeError!Value {
    if (list.items.items.len == 0) return RuntimeError.IndexOutOfBounds;
    if (args.len == 0) {
        return list.items.pop() orelse return RuntimeError.IndexOutOfBounds;
    } else if (args.len == 1 and args[0] == .integer) {
        var idx = args[0].integer;
        const length: i64 = @intCast(list.items.items.len);
        if (idx < 0) idx = length + idx;
        if (idx < 0 or idx >= length) return RuntimeError.IndexOutOfBounds;
        const uidx: usize = @intCast(idx);
        const val = list.items.items[uidx];
        var i = uidx;
        while (i + 1 < list.items.items.len) : (i += 1) {
            list.items.items[i] = list.items.items[i + 1];
        }
        list.items.items.len -= 1;
        return val;
    } else {
        return RuntimeError.BuiltinError;
    }
}

/// Inserts an element at a specific index.
fn insert(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 2 or args[0] != .integer) return RuntimeError.BuiltinError;
    var idx = args[0].integer;
    const length: i64 = @intCast(list.items.items.len);
    if (idx < 0) idx = length + idx;
    if (idx < 0) idx = 0;
    if (idx > length) idx = length;
    list.items.append(list.allocator, args[1]) catch return RuntimeError.OutOfMemory;
    const uidx: usize = @intCast(idx);
    var i = list.items.items.len - 1;
    while (i > uidx) : (i -= 1) {
        list.items.items[i] = list.items.items[i - 1];
    }
    list.items.items[uidx] = args[1];
    return .none;
}

/// Removes the first occurrence of a value.
fn remove(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 1) return RuntimeError.BuiltinError;
    for (list.items.items, 0..) |item, i| {
        if (valuesEqual(item, args[0])) {
            var j = i;
            while (j + 1 < list.items.items.len) : (j += 1) {
                list.items.items[j] = list.items.items[j + 1];
            }
            list.items.items.len -= 1;
            return .none;
        }
    }
    return RuntimeError.KeyNotFound;
}

/// Reverses the list in place.
fn reverse(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    std.mem.reverse(Value, list.items.items);
    return .none;
}

/// Clears all elements from the list.
fn clear(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    list.items.items.len = 0;
    return .none;
}

/// Returns the index of the first occurrence of a value.
fn index(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 1) return RuntimeError.BuiltinError;
    for (list.items.items, 0..) |item, i| {
        if (valuesEqual(item, args[0])) {
            return .{ .integer = @intCast(i) };
        }
    }
    return .{ .integer = -1 };
}

/// Counts occurrences of a value in the list.
fn count(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 1) return RuntimeError.BuiltinError;
    var cnt: i64 = 0;
    for (list.items.items) |item| {
        if (valuesEqual(item, args[0])) cnt += 1;
    }
    return .{ .integer = cnt };
}

/// Creates a shallow copy of the list.
fn copy(allocator: std.mem.Allocator, list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 0) return RuntimeError.BuiltinError;
    const new_list = allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
    new_list.* = Value.List.init(allocator);
    for (list.items.items) |item| {
        new_list.items.append(new_list.allocator, item) catch return RuntimeError.OutOfMemory;
    }
    return .{ .list = new_list };
}

/// Extends the list with elements from another list.
fn extend(list: *Value.List, args: []Value) RuntimeError!Value {
    if (args.len != 1 or args[0] != .list) return RuntimeError.TypeError;
    for (args[0].list.items.items) |item| {
        list.items.append(list.allocator, item) catch return RuntimeError.OutOfMemory;
    }
    return .none;
}

// ============================================================================
// Tests
// ============================================================================

test "list_methods: append" {
    var list = Value.List.init(std.testing.allocator);
    defer list.deinit();
    list.items.append(list.allocator, .{ .integer = 1 }) catch {};

    var args = [_]Value{.{ .integer = 2 }};
    _ = try callListMethod(std.testing.allocator, &list, "append", &args);
    try std.testing.expectEqual(@as(usize, 2), list.items.items.len);
}

test "list_methods: pop" {
    var list = Value.List.init(std.testing.allocator);
    defer list.deinit();
    list.items.append(list.allocator, .{ .integer = 1 }) catch {};
    list.items.append(list.allocator, .{ .integer = 2 }) catch {};

    const result = try callListMethod(std.testing.allocator, &list, "pop", &[_]Value{});
    try std.testing.expectEqual(@as(i64, 2), result.integer);
    try std.testing.expectEqual(@as(usize, 1), list.items.items.len);
}

test "list_methods: reverse" {
    var list = Value.List.init(std.testing.allocator);
    defer list.deinit();
    list.items.append(list.allocator, .{ .integer = 1 }) catch {};
    list.items.append(list.allocator, .{ .integer = 2 }) catch {};
    list.items.append(list.allocator, .{ .integer = 3 }) catch {};

    _ = try callListMethod(std.testing.allocator, &list, "reverse", &[_]Value{});
    try std.testing.expectEqual(@as(i64, 3), list.items.items[0].integer);
    try std.testing.expectEqual(@as(i64, 1), list.items.items[2].integer);
}

test "list_methods: count" {
    var list = Value.List.init(std.testing.allocator);
    defer list.deinit();
    list.items.append(list.allocator, .{ .integer = 1 }) catch {};
    list.items.append(list.allocator, .{ .integer = 2 }) catch {};
    list.items.append(list.allocator, .{ .integer = 1 }) catch {};

    var args = [_]Value{.{ .integer = 1 }};
    const result = try callListMethod(std.testing.allocator, &list, "count", &args);
    try std.testing.expectEqual(@as(i64, 2), result.integer);
}
