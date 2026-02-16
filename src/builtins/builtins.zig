const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const valuesEqual = runtime.valuesEqual;
const file_methods = @import("file_methods.zig");
const json_methods = @import("json_methods.zig");
const csv_methods = @import("csv_methods.zig");
const yaml_methods = @import("yaml_methods.zig");
const http_methods = @import("http_methods.zig");
const os_methods = @import("os_methods.zig");

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const BuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

pub fn getBuiltin(name: []const u8) ?BuiltinFn {
    // Check file system built-ins
    if (file_methods.getFileBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    // Check JSON built-ins
    if (json_methods.getJsonBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    // Check CSV built-ins
    if (csv_methods.getCsvBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    // Check YAML built-ins
    if (yaml_methods.getYamlBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    // Check HTTP built-ins
    if (http_methods.getHttpBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    // Check OS built-ins
    if (os_methods.getOsBuiltin(name)) |fn_ptr| {
        return @ptrCast(fn_ptr);
    }

    const builtins = std.StaticStringMap(BuiltinFn).initComptime(.{
        .{ "print", builtinPrint },
        .{ "len", builtinLen },
        .{ "input", builtinInput },
        .{ "int", builtinInt },
        .{ "float", builtinFloat },
        .{ "str", builtinStr },
        .{ "bool", builtinBool },
        .{ "range", builtinRange },
        .{ "append", builtinAppend },
        .{ "keys", builtinKeys },
        .{ "values", builtinValues },
        .{ "type", builtinType },
        .{ "abs", builtinAbs },
        .{ "min", builtinMin },
        .{ "max", builtinMax },
        .{ "sum", builtinSum },
        .{ "pop", builtinPop },
        .{ "insert", builtinInsert },
        .{ "delete", builtinDelete },
        .{ "sorted", builtinSorted },
        .{ "reversed", builtinReversed },
        .{ "enumerate", builtinEnumerate },
        .{ "zip", builtinZip },
        .{ "chr", builtinChr },
        .{ "ord", builtinOrd },
        .{ "hex", builtinHex },
        .{ "slice", builtinSlice },
    });
    return builtins.get(name);
}

fn builtinPrint(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    for (args, 0..) |arg, i| {
        if (i > 0) std.debug.print(" ", .{});
        const s = arg.toString(allocator) catch return BuiltinError.OutOfMemory;
        defer allocator.free(s);
        std.debug.print("{s}", .{s});
    }
    std.debug.print("\n", .{});
    return .none;
}

fn builtinLen(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return switch (args[0]) {
        .string => |s| .{ .integer = @intCast(s.len) },
        .list => |l| .{ .integer = @intCast(l.items.items.len) },
        .dict => |d| .{ .integer = @intCast(d.keys.items.len) },
        else => BuiltinError.TypeError,
    };
}

fn builtinInput(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    // Print prompt if provided
    if (args.len > 0) {
        if (args[0] != .string) return BuiltinError.TypeError;
        std.debug.print("{s}", .{args[0].string});
    }

    // Note: input() is not fully supported in this simple interpreter
    // It would require passing the Io context through
    return .{ .string = "" };
}

fn builtinInt(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return switch (args[0]) {
        .integer => args[0],
        .float => |f| .{ .integer = @intFromFloat(f) },
        .string => |s| blk: {
            const trimmed = std.mem.trim(u8, s, " \t\r\n");
            break :blk .{ .integer = std.fmt.parseInt(i64, trimmed, 10) catch return BuiltinError.ValueError };
        },
        .boolean => |b| .{ .integer = if (b) 1 else 0 },
        else => BuiltinError.TypeError,
    };
}

fn builtinFloat(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return switch (args[0]) {
        .integer => |i| .{ .float = @floatFromInt(i) },
        .float => args[0],
        .string => |s| blk: {
            const trimmed = std.mem.trim(u8, s, " \t\r\n");
            break :blk .{ .float = std.fmt.parseFloat(f64, trimmed) catch return BuiltinError.ValueError };
        },
        else => BuiltinError.TypeError,
    };
}

fn builtinStr(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const s = args[0].toString(allocator) catch return BuiltinError.OutOfMemory;
    return .{ .string = s };
}

fn builtinBool(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return .{ .boolean = args[0].isTruthy() };
}

fn builtinRange(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 3) return BuiltinError.WrongArgCount;

    var start: i64 = 0;
    var end: i64 = 0;
    var step: i64 = 1;

    if (args.len == 1) {
        if (args[0] != .integer) return BuiltinError.TypeError;
        end = args[0].integer;
    } else if (args.len == 2) {
        if (args[0] != .integer or args[1] != .integer) return BuiltinError.TypeError;
        start = args[0].integer;
        end = args[1].integer;
    } else {
        if (args[0] != .integer or args[1] != .integer or args[2] != .integer) return BuiltinError.TypeError;
        start = args[0].integer;
        end = args[1].integer;
        step = args[2].integer;
        if (step == 0) return BuiltinError.ValueError;
    }

    const list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    list.* = Value.List.init(allocator);

    var i = start;
    if (step > 0) {
        while (i < end) : (i += step) {
            list.items.append(allocator, .{ .integer = i }) catch return BuiltinError.OutOfMemory;
        }
    } else {
        while (i > end) : (i += step) {
            list.items.append(allocator, .{ .integer = i }) catch return BuiltinError.OutOfMemory;
        }
    }

    return .{ .list = list };
}

fn builtinAppend(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;

    const list = args[0].list;
    list.items.append(list.allocator, args[1]) catch return BuiltinError.OutOfMemory;
    return .none;
}

fn builtinKeys(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .dict) return BuiltinError.TypeError;

    const list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    list.* = Value.List.init(allocator);

    for (args[0].dict.keys.items) |key| {
        list.items.append(allocator, key) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = list };
}

fn builtinValues(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .dict) return BuiltinError.TypeError;

    const list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    list.* = Value.List.init(allocator);

    for (args[0].dict.values.items) |val| {
        list.items.append(allocator, val) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = list };
}

fn builtinType(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return .{ .string = args[0].typeName() };
}

fn builtinAbs(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return switch (args[0]) {
        .integer => |i| .{ .integer = if (i < 0) -i else i },
        .float => |f| .{ .float = @abs(f) },
        else => BuiltinError.TypeError,
    };
}

fn builtinMin(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len == 1) {
        if (args[0] != .list) return BuiltinError.TypeError;
        const items = args[0].list.items.items;
        if (items.len == 0) return BuiltinError.ValueError;
        var result = items[0];
        for (items[1..]) |item| {
            if (valueLessThan(item, result)) result = item;
        }
        return result;
    } else if (args.len == 2) {
        return if (valueLessThan(args[1], args[0])) args[1] else args[0];
    }
    return BuiltinError.WrongArgCount;
}

fn builtinMax(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len == 1) {
        if (args[0] != .list) return BuiltinError.TypeError;
        const items = args[0].list.items.items;
        if (items.len == 0) return BuiltinError.ValueError;
        var result = items[0];
        for (items[1..]) |item| {
            if (valueLessThan(result, item)) result = item;
        }
        return result;
    } else if (args.len == 2) {
        return if (valueLessThan(args[0], args[1])) args[1] else args[0];
    }
    return BuiltinError.WrongArgCount;
}

fn valueLessThan(a: Value, b: Value) bool {
    if (a == .integer and b == .integer) return a.integer < b.integer;
    if (a == .float and b == .float) return a.float < b.float;
    if (a == .integer and b == .float) return @as(f64, @floatFromInt(a.integer)) < b.float;
    if (a == .float and b == .integer) return a.float < @as(f64, @floatFromInt(b.integer));
    return false;
}

fn builtinSum(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    const items = args[0].list.items.items;
    var int_sum: i64 = 0;
    var has_float = false;
    var float_sum: f64 = 0.0;
    for (items) |item| {
        switch (item) {
            .integer => |i| {
                int_sum += i;
                float_sum += @floatFromInt(i);
            },
            .float => |f| {
                has_float = true;
                float_sum += f;
            },
            else => return BuiltinError.TypeError,
        }
    }
    if (has_float) return .{ .float = float_sum };
    return .{ .integer = int_sum };
}

fn builtinPop(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    const list = args[0].list;
    const items = list.items.items;
    if (items.len == 0) return BuiltinError.ValueError;

    var idx: i64 = @intCast(items.len - 1);
    if (args.len == 2) {
        if (args[1] != .integer) return BuiltinError.TypeError;
        idx = args[1].integer;
        if (idx < 0) idx += @intCast(items.len);
        if (idx < 0 or idx >= @as(i64, @intCast(items.len))) return BuiltinError.ValueError;
    }

    const uidx: usize = @intCast(idx);
    const result = items[uidx];
    _ = list.items.orderedRemove(uidx);
    return result;
}

fn builtinInsert(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 3) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    if (args[1] != .integer) return BuiltinError.TypeError;
    const list = args[0].list;
    var idx = args[1].integer;
    const len: i64 = @intCast(list.items.items.len);
    if (idx < 0) idx += len;
    if (idx < 0) idx = 0;
    if (idx > len) idx = len;
    const uidx: usize = @intCast(idx);

    list.items.append(list.allocator, .none) catch return BuiltinError.OutOfMemory;
    const slice = list.items.items;
    var i: usize = slice.len - 1;
    while (i > uidx) : (i -= 1) {
        slice[i] = slice[i - 1];
    }
    slice[uidx] = args[2];
    return .none;
}

/// delete(list, index) - Remove item at index from list
/// delete(dict, key) - Remove key from dict
fn builtinDelete(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;

    switch (args[0]) {
        .list => |list| {
            if (args[1] != .integer) return BuiltinError.TypeError;
            const items = list.items.items;
            var idx = args[1].integer;
            const len: i64 = @intCast(items.len);
            if (idx < 0) idx += len;
            if (idx < 0 or idx >= len) return BuiltinError.ValueError;
            const uidx: usize = @intCast(idx);
            _ = list.items.orderedRemove(uidx);
        },
        .dict => |dict| {
            const key = args[1];
            for (dict.keys.items, 0..) |k, i| {
                if (valuesEqual(k, key)) {
                    _ = dict.keys.orderedRemove(i);
                    _ = dict.values.orderedRemove(i);
                    return .none;
                }
            }
            return BuiltinError.ValueError; // Key not found
        },
        else => return BuiltinError.TypeError,
    }
    return .none;
}

fn builtinSorted(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    const src = args[0].list.items.items;

    const new_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    new_list.* = Value.List.init(allocator);

    for (src) |item| {
        if (item != .integer) return BuiltinError.TypeError;
        new_list.items.append(allocator, item) catch return BuiltinError.OutOfMemory;
    }

    const slice = new_list.items.items;
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        const key = slice[i];
        var j: usize = i;
        while (j > 0 and slice[j - 1].integer > key.integer) : (j -= 1) {
            slice[j] = slice[j - 1];
        }
        slice[j] = key;
    }

    return .{ .list = new_list };
}

fn builtinReversed(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    const src = args[0].list.items.items;

    const new_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    new_list.* = Value.List.init(allocator);

    var i: usize = src.len;
    while (i > 0) {
        i -= 1;
        new_list.items.append(allocator, src[i]) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = new_list };
}

fn builtinEnumerate(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;
    const src = args[0].list.items.items;

    const outer = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    outer.* = Value.List.init(allocator);

    for (src, 0..) |item, i| {
        const inner = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
        inner.* = Value.List.init(allocator);
        inner.items.append(allocator, .{ .integer = @intCast(i) }) catch return BuiltinError.OutOfMemory;
        inner.items.append(allocator, item) catch return BuiltinError.OutOfMemory;
        outer.items.append(allocator, .{ .list = inner }) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = outer };
}

fn builtinZip(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list or args[1] != .list) return BuiltinError.TypeError;
    const a = args[0].list.items.items;
    const b = args[1].list.items.items;
    const len = @min(a.len, b.len);

    const outer = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    outer.* = Value.List.init(allocator);

    for (0..len) |i| {
        const inner = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
        inner.* = Value.List.init(allocator);
        inner.items.append(allocator, a[i]) catch return BuiltinError.OutOfMemory;
        inner.items.append(allocator, b[i]) catch return BuiltinError.OutOfMemory;
        outer.items.append(allocator, .{ .list = inner }) catch return BuiltinError.OutOfMemory;
    }

    return .{ .list = outer };
}

fn builtinChr(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;
    const code = args[0].integer;
    if (code < 0 or code > 127) return BuiltinError.ValueError;
    const buf = allocator.alloc(u8, 1) catch return BuiltinError.OutOfMemory;
    buf[0] = @intCast(code);
    return .{ .string = buf };
}

fn builtinOrd(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;
    const s = args[0].string;
    if (s.len == 0) return BuiltinError.ValueError;
    return .{ .integer = @intCast(s[0]) };
}

fn builtinHex(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .integer) return BuiltinError.TypeError;
    const val = args[0].integer;
    const s = std.fmt.allocPrint(allocator, "0x{x}", .{val}) catch return BuiltinError.OutOfMemory;
    return .{ .string = s };
}

fn builtinSlice(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 3) return BuiltinError.WrongArgCount;
    if (args[1] != .integer or args[2] != .integer) return BuiltinError.TypeError;

    var start = args[1].integer;
    var end = args[2].integer;

    switch (args[0]) {
        .string => |s| {
            const slen: i64 = @intCast(s.len);
            if (start < 0) start += slen;
            if (end < 0) end += slen;
            if (start < 0) start = 0;
            if (end < 0) end = 0;
            if (start > slen) start = slen;
            if (end > slen) end = slen;
            if (start >= end) {
                const empty = allocator.alloc(u8, 0) catch return BuiltinError.OutOfMemory;
                return .{ .string = empty };
            }
            const ustart: usize = @intCast(start);
            const uend: usize = @intCast(end);
            const result = allocator.alloc(u8, uend - ustart) catch return BuiltinError.OutOfMemory;
            @memcpy(result, s[ustart..uend]);
            return .{ .string = result };
        },
        .list => |l| {
            const items = l.items.items;
            const llen: i64 = @intCast(items.len);
            if (start < 0) start += llen;
            if (end < 0) end += llen;
            if (start < 0) start = 0;
            if (end < 0) end = 0;
            if (start > llen) start = llen;
            if (end > llen) end = llen;

            const new_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
            new_list.* = Value.List.init(allocator);

            if (start < end) {
                const ustart: usize = @intCast(start);
                const uend: usize = @intCast(end);
                for (items[ustart..uend]) |item| {
                    new_list.items.append(allocator, item) catch return BuiltinError.OutOfMemory;
                }
            }

            return .{ .list = new_list };
        },
        else => return BuiltinError.TypeError,
    }
}
