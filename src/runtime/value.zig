const std = @import("std");
const ast = @import("../ast/mod.zig");

pub const Value = union(enum) {
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    none,
    list: *List,
    dict: *Dict,
    function: *Function,

    pub const List = struct {
        items: std.ArrayList(Value),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) List {
            return .{ .items = .empty, .allocator = allocator };
        }

        pub fn deinit(self: *List) void {
            self.items.deinit(self.allocator);
        }
    };

    pub const Dict = struct {
        keys: std.ArrayList(Value),
        values: std.ArrayList(Value),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Dict {
            return .{
                .keys = .empty,
                .values = .empty,
                .allocator = allocator,
            };
        }

        pub fn get(self: *Dict, key: Value) ?Value {
            for (self.keys.items, 0..) |k, i| {
                if (valuesEqual(k, key)) {
                    return self.values.items[i];
                }
            }
            return null;
        }

        pub fn set(self: *Dict, key: Value, val: Value) !void {
            for (self.keys.items, 0..) |k, i| {
                if (valuesEqual(k, key)) {
                    self.values.items[i] = val;
                    return;
                }
            }
            try self.keys.append(self.allocator, key);
            try self.values.append(self.allocator, val);
        }
    };

    pub const Function = struct {
        name: []const u8,
        params: []const []const u8,
        body: *ast.Stmt,
    };

    // Convert value to string for printing
    pub fn toString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}),
            .float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}),
            .string => |s| std.fmt.allocPrint(allocator, "{s}", .{s}),
            .boolean => |b| std.fmt.allocPrint(allocator, "{s}", .{if (b) "true" else "false"}),
            .none => std.fmt.allocPrint(allocator, "none", .{}),
            .list => |l| blk: {
                var result: std.ArrayList(u8) = .empty;
                try result.append(allocator, '[');
                for (l.items.items, 0..) |item, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    const s = try item.toString(allocator);
                    defer allocator.free(s);
                    try result.appendSlice(allocator, s);
                }
                try result.append(allocator, ']');
                break :blk result.toOwnedSlice(allocator);
            },
            .dict => |d| blk: {
                var result: std.ArrayList(u8) = .empty;
                try result.append(allocator, '{');
                for (d.keys.items, 0..) |key, i| {
                    if (i > 0) try result.appendSlice(allocator, ", ");
                    const ks = try key.toString(allocator);
                    defer allocator.free(ks);
                    const vs = try d.values.items[i].toString(allocator);
                    defer allocator.free(vs);
                    try result.appendSlice(allocator, ks);
                    try result.appendSlice(allocator, ": ");
                    try result.appendSlice(allocator, vs);
                }
                try result.append(allocator, '}');
                break :blk result.toOwnedSlice(allocator);
            },
            .function => |f| std.fmt.allocPrint(allocator, "<function {s}>", .{f.name}),
        };
    }

    // Check if value is truthy
    pub fn isTruthy(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .none => false,
            .integer => |i| i != 0,
            .float => |f| f != 0.0,
            .string => |s| s.len > 0,
            .list => |l| l.items.items.len > 0,
            .dict => |d| d.keys.items.len > 0,
            .function => true, // Functions are always truthy
        };
    }

    pub fn typeName(self: Value) []const u8 {
        return switch (self) {
            .integer => "int",
            .float => "float",
            .string => "string",
            .boolean => "bool",
            .none => "none",
            .list => "list",
            .dict => "dict",
            .function => "function",
        };
    }
};

pub fn valuesEqual(a: Value, b: Value) bool {
    if (@as(std.meta.Tag(Value), a) != @as(std.meta.Tag(Value), b)) {
        return false;
    }
    return switch (a) {
        .integer => |ai| ai == b.integer,
        .float => |af| af == b.float,
        .string => |as_| std.mem.eql(u8, as_, b.string),
        .boolean => |ab| ab == b.boolean,
        .none => true,
        .list => |al| al == b.list, // Reference equality for lists
        .dict => |ad| ad == b.dict, // Reference equality for dicts
        .function => |af| af == b.function, // Reference equality for functions
    };
}
