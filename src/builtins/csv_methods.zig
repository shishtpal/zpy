//! CSV methods module - CSV parsing and serialization built-ins.
//!
//! This module provides CSV built-ins:
//! - `csv_parse` - Parse CSV string to list of dicts (with headers) or list of lists
//! - `csv_stringify` - Convert list to CSV string

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const CsvBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a CSV built-in function by name.
pub fn getCsvBuiltin(name: []const u8) ?CsvBuiltinFn {
    const builtins = std.StaticStringMap(CsvBuiltinFn).initComptime(.{
        .{ "csv_parse", csvParse },
        .{ "csv_stringify", csvStringify },
    });
    return builtins.get(name);
}

// ============================================================================
// CSV Operations
// ============================================================================

/// csv_parse(string, delimiter?, has_header?) - Parse CSV string to list
/// Default: delimiter=",", has_header=true
/// With headers: returns list of dicts [{col1: val, col2: val}, ...]
/// Without headers: returns list of lists [[val, val], ...]
fn csvParse(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 3) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const csv_str = args[0].string;
    const delimiter: u8 = if (args.len >= 2 and args[1] == .string and args[1].string.len > 0)
        args[1].string[0]
    else
        ',';
    const has_header: bool = if (args.len >= 3)
        if (args[2] == .boolean) args[2].boolean else true
    else
        true;

    // Parse CSV into rows
    var rows: std.ArrayList([]const u8) = .empty;
    defer rows.deinit(allocator);

    var line_start: usize = 0;
    for (csv_str, 0..) |c, i| {
        if (c == '\n' or c == '\r') {
            if (i > line_start) {
                rows.append(allocator, csv_str[line_start..i]) catch return BuiltinError.OutOfMemory;
            }
            line_start = i + 1;
            // Handle \r\n
            if (c == '\r' and i + 1 < csv_str.len and csv_str[i + 1] == '\n') {
                line_start = i + 2;
            }
        }
    }
    // Last line without newline
    if (line_start < csv_str.len) {
        rows.append(allocator, csv_str[line_start..]) catch return BuiltinError.OutOfMemory;
    }

    if (rows.items.len == 0) {
        const empty_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
        empty_list.* = Value.List.init(allocator);
        return .{ .list = empty_list };
    }

    // Parse header row if needed
    var headers: ?[][]const u8 = null;
    var data_start: usize = 0;

    if (has_header and rows.items.len > 0) {
        headers = parseRow(allocator, rows.items[0], delimiter) catch return BuiltinError.OutOfMemory;
        data_start = 1;
    }

    // Create result list
    const result = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    result.* = Value.List.init(allocator);

    // Parse data rows
    for (rows.items[data_start..]) |row| {
        const fields = parseRow(allocator, row, delimiter) catch return BuiltinError.OutOfMemory;

        if (headers) |hdrs| {
            // Create dict for this row
            const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
            dict.* = Value.Dict.init(allocator);

            for (hdrs, 0..) |header, i| {
                const key = Value{ .string = allocator.dupe(u8, header) catch return BuiltinError.OutOfMemory };
                const val = if (i < fields.len)
                    Value{ .string = allocator.dupe(u8, fields[i]) catch return BuiltinError.OutOfMemory }
                else
                    Value{ .string = "" };
                dict.set(key, val) catch return BuiltinError.OutOfMemory;
            }

            result.items.append(allocator, .{ .dict = dict }) catch return BuiltinError.OutOfMemory;
        } else {
            // Create list for this row
            const row_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
            row_list.* = Value.List.init(allocator);

            for (fields) |field| {
                const val = Value{ .string = allocator.dupe(u8, field) catch return BuiltinError.OutOfMemory };
                row_list.items.append(allocator, val) catch return BuiltinError.OutOfMemory;
            }

            result.items.append(allocator, .{ .list = row_list }) catch return BuiltinError.OutOfMemory;
        }
    }

    return .{ .list = result };
}

/// csv_stringify(data, delimiter?) - Convert list to CSV string
fn csvStringify(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;
    if (args[0] != .list) return BuiltinError.TypeError;

    const data = args[0].list;
    const delimiter: u8 = if (args.len >= 2 and args[1] == .string and args[1].string.len > 0)
        args[1].string[0]
    else
        ',';

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    // Check if first item is dict (has headers) or list
    if (data.items.items.len > 0 and data.items.items[0] == .dict) {
        // Get headers from first dict
        const first_dict = data.items.items[0].dict;
        
        // Write header row
        for (first_dict.keys.items, 0..) |key, i| {
            if (i > 0) output.append(allocator, delimiter) catch return BuiltinError.OutOfMemory;
            const key_str = if (key == .string) key.string else blk: {
                const s = key.toString(allocator) catch return BuiltinError.OutOfMemory;
                break :blk s;
            };
            writeCsvField(&output, allocator, key_str) catch return BuiltinError.OutOfMemory;
        }
        output.append(allocator, '\n') catch return BuiltinError.OutOfMemory;

        // Write data rows
        for (data.items.items) |item| {
            if (item != .dict) continue;
            const dict = item.dict;

            for (first_dict.keys.items, 0..) |key, i| {
                if (i > 0) output.append(allocator, delimiter) catch return BuiltinError.OutOfMemory;
                const val = dict.get(key) orelse .none;
                const val_str = val.toString(allocator) catch return BuiltinError.OutOfMemory;
                defer allocator.free(val_str);
                writeCsvField(&output, allocator, val_str) catch return BuiltinError.OutOfMemory;
            }
            output.append(allocator, '\n') catch return BuiltinError.OutOfMemory;
        }
    } else {
        // Write rows as lists
        for (data.items.items) |item| {
            if (item != .list) continue;
            const row = item.list;

            for (row.items.items, 0..) |cell, i| {
                if (i > 0) output.append(allocator, delimiter) catch return BuiltinError.OutOfMemory;
                const cell_str = cell.toString(allocator) catch return BuiltinError.OutOfMemory;
                defer allocator.free(cell_str);
                writeCsvField(&output, allocator, cell_str) catch return BuiltinError.OutOfMemory;
            }
            output.append(allocator, '\n') catch return BuiltinError.OutOfMemory;
        }
    }

    return .{ .string = output.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory };
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Parse a single CSV row into fields
fn parseRow(allocator: std.mem.Allocator, row: []const u8, delimiter: u8) ![][]const u8 {
    var fields: std.ArrayList([]const u8) = .empty;
    errdefer fields.deinit(allocator);

    var in_quotes = false;
    var field_start: usize = 0;
    var i: usize = 0;

    while (i < row.len) : (i += 1) {
        const c = row[i];

        if (c == '"') {
            // Check for escaped quote
            if (in_quotes and i + 1 < row.len and row[i + 1] == '"') {
                i += 1; // Skip escaped quote
            } else {
                in_quotes = !in_quotes;
            }
        } else if (c == delimiter and !in_quotes) {
            const field = extractField(row[field_start..i]);
            try fields.append(allocator, field);
            field_start = i + 1;
        }
    }

    // Last field
    const field = extractField(row[field_start..]);
    try fields.append(allocator, field);

    return fields.toOwnedSlice(allocator);
}

/// Extract field value, removing surrounding quotes and unescaping
fn extractField(raw: []const u8) []const u8 {
    var field = raw;

    // Trim whitespace
    while (field.len > 0 and (field[0] == ' ' or field[0] == '\t')) {
        field = field[1..];
    }
    while (field.len > 0 and (field[field.len - 1] == ' ' or field[field.len - 1] == '\t')) {
        field = field[0 .. field.len - 1];
    }

    // Remove surrounding quotes
    if (field.len >= 2 and field[0] == '"' and field[field.len - 1] == '"') {
        field = field[1 .. field.len - 1];
    }

    return field;
}

/// Write a field to CSV output, quoting if necessary
fn writeCsvField(output: *std.ArrayList(u8), allocator: std.mem.Allocator, field: []const u8) !void {
    // Check if quoting is needed
    var needs_quotes = false;
    for (field) |c| {
        if (c == ',' or c == '"' or c == '\n' or c == '\r') {
            needs_quotes = true;
            break;
        }
    }

    if (needs_quotes) {
        try output.append(allocator, '"');
        for (field) |c| {
            if (c == '"') {
                try output.appendSlice(allocator, "\"\"");
            } else {
                try output.append(allocator, c);
            }
        }
        try output.append(allocator, '"');
    } else {
        try output.appendSlice(allocator, field);
    }
}
