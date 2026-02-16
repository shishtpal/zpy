//! JSON methods module - JSON parsing and serialization built-ins.
//!
//! This module provides JSON built-ins:
//! - `json_parse` - Parse JSON string to ZPy value
//! - `json_stringify` - Convert ZPy value to JSON string

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const JsonBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a JSON built-in function by name.
pub fn getJsonBuiltin(name: []const u8) ?JsonBuiltinFn {
    const builtins = std.StaticStringMap(JsonBuiltinFn).initComptime(.{
        .{ "json_parse", jsonParse },
        .{ "json_stringify", jsonStringify },
    });
    return builtins.get(name);
}

// ============================================================================
// JSON Operations
// ============================================================================

/// json_parse(string) - Parse JSON string to ZPy value
fn jsonParse(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const json_str = args[0].string;

    // Parse JSON using std.json
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch {
        return BuiltinError.ValueError;
    };
    defer parsed.deinit();

    // Convert std.json.Value to ZPy Value
    return jsonToZpyValue(allocator, parsed.value) catch BuiltinError.OutOfMemory;
}

/// json_stringify(value, indent?) - Convert ZPy value to JSON string
fn jsonStringify(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;

    const value = args[0];
    const indent: ?usize = if (args.len == 2) blk: {
        if (args[1] == .none) break :blk null;
        if (args[1] != .integer) return BuiltinError.TypeError;
        break :blk @intCast(args[1].integer);
    } else null;

    // Convert ZPy value to JSON string
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    const pretty = indent != null and indent.? > 0;
    stringifyZpyValue(allocator, &output, value, pretty) catch return BuiltinError.OutOfMemory;

    return .{ .string = output.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory };
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Convert std.json.Value to ZPy Value
fn jsonToZpyValue(allocator: std.mem.Allocator, json_val: std.json.Value) !Value {
    return switch (json_val) {
        .null => .none,
        .bool => |b| .{ .boolean = b },
        .integer => |i| .{ .integer = i },
        .float => |f| .{ .float = f },
        .number_string => |s| blk: {
            // Try to parse as integer first, then float
            if (std.fmt.parseInt(i64, s, 10)) |i| {
                break :blk .{ .integer = i };
            } else |_| {
                if (std.fmt.parseFloat(f64, s)) |f| {
                    break :blk .{ .float = f };
                } else |_| {
                    break :blk .{ .string = try allocator.dupe(u8, s) };
                }
            }
        },
        .string => |s| .{ .string = try allocator.dupe(u8, s) },
        .array => |arr| blk: {
            const list = try allocator.create(Value.List);
            list.* = Value.List.init(allocator);
            for (arr.items) |item| {
                const zpy_item = try jsonToZpyValue(allocator, item);
                try list.items.append(allocator, zpy_item);
            }
            break :blk .{ .list = list };
        },
        .object => |obj| blk: {
            const dict = try allocator.create(Value.Dict);
            dict.* = Value.Dict.init(allocator);
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                const key = Value{ .string = try allocator.dupe(u8, entry.key_ptr.*) };
                const val = try jsonToZpyValue(allocator, entry.value_ptr.*);
                try dict.set(key, val);
            }
            break :blk .{ .dict = dict };
        },
    };
}

/// Stringify ZPy Value to JSON
fn stringifyZpyValue(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Value, pretty: bool) !void {
    switch (value) {
        .none => try output.appendSlice(allocator, "null"),
        .boolean => |b| try output.appendSlice(allocator, if (b) "true" else "false"),
        .integer => |i| {
            const str = try std.fmt.allocPrint(allocator, "{d}", .{i});
            defer allocator.free(str);
            try output.appendSlice(allocator, str);
        },
        .float => |f| {
            const str = try std.fmt.allocPrint(allocator, "{d}", .{f});
            defer allocator.free(str);
            try output.appendSlice(allocator, str);
        },
        .string => |s| {
            try output.append(allocator, '"');
            for (s) |c| {
                switch (c) {
                    '"' => try output.appendSlice(allocator, "\\\""),
                    '\\' => try output.appendSlice(allocator, "\\\\"),
                    '\n' => try output.appendSlice(allocator, "\\n"),
                    '\r' => try output.appendSlice(allocator, "\\r"),
                    '\t' => try output.appendSlice(allocator, "\\t"),
                    else => {
                        if (c < 0x20) {
                            const hex = "0123456789abcdef";
                            try output.appendSlice(allocator, "\\u00");
                            try output.append(allocator, hex[c >> 4]);
                            try output.append(allocator, hex[c & 0x0f]);
                        } else {
                            try output.append(allocator, c);
                        }
                    },
                }
            }
            try output.append(allocator, '"');
        },
        .list => |l| {
            try output.append(allocator, '[');
            for (l.items.items, 0..) |item, i| {
                if (i > 0) {
                    try output.append(allocator, ',');
                    if (pretty) try output.append(allocator, ' ');
                }
                try stringifyZpyValue(allocator, output, item, pretty);
            }
            try output.append(allocator, ']');
        },
        .dict => |d| {
            try output.append(allocator, '{');
            for (d.keys.items, 0..) |key, i| {
                if (i > 0) {
                    try output.append(allocator, ',');
                    if (pretty) try output.append(allocator, ' ');
                }
                // Key must be string for valid JSON - convert non-strings
                const key_str: []const u8 = if (key == .string) key.string else blk: {
                    const s = try key.toString(allocator);
                    break :blk s;
                };
                try output.append(allocator, '"');
                try output.appendSlice(allocator, key_str);
                try output.append(allocator, '"');
                try output.appendSlice(allocator, if (pretty) ": " else ":");
                try stringifyZpyValue(allocator, output, d.values.items[i], pretty);
            }
            try output.append(allocator, '}');
        },
        .function => try output.appendSlice(allocator, "null"), // Functions serialize to null
    }
}
