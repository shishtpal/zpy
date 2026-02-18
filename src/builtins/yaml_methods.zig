//! YAML methods module - YAML parsing and serialization built-ins.
//!
//! This module provides YAML built-ins:
//! - `yaml_parse` - Parse YAML string to ZPy value
//! - `yaml_parse_all` - Parse multi-document YAML to list
//! - `yaml_stringify` - Convert ZPy value to YAML string
//!
//! Supported YAML features:
//! - Scalars: strings, numbers, booleans, null
//! - Sequences (lists) using `- ` prefix
//! - Mappings (dicts) using `key: value`
//! - Nested structures via indentation
//! - Comments (`#`)
//! - Multi-document support (`---`)
//! - Anchors and aliases (`&anchor`, `*alias`)

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const YamlBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a YAML built-in function by name.
pub fn getYamlBuiltin(name: []const u8) ?YamlBuiltinFn {
    const builtins = std.StaticStringMap(YamlBuiltinFn).initComptime(.{
        .{ "yaml_parse", yamlParse },
        .{ "yaml_parse_all", yamlParseAll },
        .{ "yaml_stringify", yamlStringify },
    });
    return builtins.get(name);
}

// ============================================================================
// YAML Operations
// ============================================================================

/// yaml_parse(string) - Parse YAML string to ZPy value
/// If multi-document, returns the first document only
fn yamlParse(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    var parser = YamlParser.init(allocator, args[0].string);
    return parser.parseDocument() catch BuiltinError.ValueError;
}

/// yaml_parse_all(string) - Parse multi-document YAML to list
fn yamlParseAll(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    var parser = YamlParser.init(allocator, args[0].string);
    return parser.parseAllDocuments() catch BuiltinError.ValueError;
}

/// yaml_stringify(value) - Convert ZPy value to YAML string
fn yamlStringify(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    stringifyValue(allocator, &output, args[0], 0) catch return BuiltinError.OutOfMemory;

    return .{ .string = output.toOwnedSlice(allocator) catch return BuiltinError.OutOfMemory };
}

// ============================================================================
// YAML Parser
// ============================================================================

const YamlParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    pos: usize,
    anchors: std.StringHashMap(Value),

    fn init(allocator: std.mem.Allocator, source: []const u8) YamlParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .anchors = std.StringHashMap(Value).init(allocator),
        };
    }

    const ParseError = error{OutOfMemory};

    fn parseAllDocuments(self: *YamlParser) ParseError!Value {
        const list = try self.allocator.create(Value.List);
        list.* = Value.List.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            // Check for document separator
            if (self.startsWith("---")) {
                self.pos += 3;
                self.skipToEndOfLine();
            }

            // Parse document
            const doc = try self.parseValue(0);
            try list.items.append(self.allocator, doc);

            self.skipWhitespaceAndComments();
        }

        return .{ .list = list };
    }

    fn parseDocument(self: *YamlParser) ParseError!Value {
        self.skipWhitespaceAndComments();

        // Skip document start marker if present
        if (self.startsWith("---")) {
            self.pos += 3;
            self.skipToEndOfLine();
        }

        return self.parseValue(0);
    }

    fn parseValue(self: *YamlParser, indent: usize) ParseError!Value {
        self.skipWhitespaceAndComments();
        if (self.pos >= self.source.len) return .none;

        // Check for anchor definition
        var anchor_name: ?[]const u8 = null;
        if (self.peek() == '&') {
            self.pos += 1;
            anchor_name = self.readWord();
            self.skipSpaces();
        }

        // Check for alias reference
        if (self.peek() == '*') {
            self.pos += 1;
            const alias = self.readWord();
            if (self.anchors.get(alias)) |val| {
                return val;
            }
            return .none;
        }

        // Determine type based on first character
        const current_indent = self.currentIndent();
        if (current_indent < indent and !self.isAtLineStart()) {
            return .none;
        }

        var value: Value = undefined;

        if (self.peek() == '-' and self.peekAt(1) == ' ') {
            // List
            value = try self.parseList(current_indent);
        } else if (self.isKeyValueLine()) {
            // Mapping
            value = try self.parseMapping(current_indent);
        } else {
            // Scalar
            value = try self.parseScalar();
        }

        // Store anchor if defined
        if (anchor_name) |name| {
            try self.anchors.put(name, value);
        }

        return value;
    }

    fn parseList(self: *YamlParser, base_indent: usize) ParseError!Value {
        const list = try self.allocator.create(Value.List);
        list.* = Value.List.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const current_indent = self.currentIndent();
            if (current_indent < base_indent) break;
            if (current_indent > base_indent) break;

            if (self.peek() != '-') break;
            self.pos += 1; // Skip '-'

            if (self.peek() == ' ') {
                self.pos += 1; // Skip space after '-'
            }

            // Check what follows the '- '
            if (self.peek() == '\n' or self.peek() == '\r' or self.pos >= self.source.len) {
                // Multi-line nested value
                self.skipToEndOfLine();
                const item = try self.parseValue(base_indent + 2);
                try list.items.append(self.allocator, item);
            } else if (self.isKeyValueLine()) {
                // Inline mapping
                const item = try self.parseMapping(self.currentIndent());
                try list.items.append(self.allocator, item);
                self.skipToEndOfLine();
            } else {
                // Inline scalar
                const item = try self.parseScalar();
                try list.items.append(self.allocator, item);
                self.skipToEndOfLine();
            }
        }

        return .{ .list = list };
    }

    fn parseMapping(self: *YamlParser, base_indent: usize) ParseError!Value {
        const dict = try self.allocator.create(Value.Dict);
        dict.* = Value.Dict.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.source.len) break;

            const current_indent = self.currentIndent();
            if (current_indent < base_indent) break;
            if (current_indent > base_indent and dict.keys.items.len > 0) break;

            if (!self.isKeyValueLine()) break;

            // Parse key
            const key_str = self.readUntilColon();
            const key = Value{ .string = try self.allocator.dupe(u8, key_str) };

            // Skip colon and space
            if (self.peek() == ':') self.pos += 1;
            self.skipSpaces();

            // Parse value
            var val: Value = undefined;
            if (self.peek() == '\n' or self.peek() == '\r' or self.pos >= self.source.len) {
                // Value on next line(s)
                self.skipToEndOfLine();
                self.skipWhitespaceAndComments();
                val = try self.parseValue(base_indent + 2);
            } else {
                // Value on same line
                val = try self.parseScalar();
            }

            try dict.set(key, val);
            self.skipToEndOfLine();
        }

        return .{ .dict = dict };
    }

    fn parseScalar(self: *YamlParser) ParseError!Value {
        const start = self.pos;

        // Read until end of line or comment
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n' or c == '\r' or c == '#') break;
            self.pos += 1;
        }

        var value = std.mem.trim(u8, self.source[start..self.pos], " \t");

        // Handle quoted strings
        if (value.len >= 2) {
            if ((value[0] == '"' and value[value.len - 1] == '"') or
                (value[0] == '\'' and value[value.len - 1] == '\''))
            {
                value = value[1 .. value.len - 1];
                return .{ .string = try self.allocator.dupe(u8, value) };
            }
        }

        // Check for special values
        if (std.mem.eql(u8, value, "null") or std.mem.eql(u8, value, "~") or value.len == 0) {
            return .none;
        }
        if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes") or std.mem.eql(u8, value, "on")) {
            return .{ .boolean = true };
        }
        if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "no") or std.mem.eql(u8, value, "off")) {
            return .{ .boolean = false };
        }

        // Try to parse as number
        if (std.fmt.parseInt(i64, value, 10)) |i| {
            return .{ .integer = i };
        } else |_| {}

        if (std.fmt.parseFloat(f64, value)) |f| {
            return .{ .float = f };
        } else |_| {}

        // Return as string
        return .{ .string = try self.allocator.dupe(u8, value) };
    }

    // Helper functions
    fn peek(self: *YamlParser) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }

    fn peekAt(self: *YamlParser, offset: usize) u8 {
        if (self.pos + offset >= self.source.len) return 0;
        return self.source[self.pos + offset];
    }

    fn startsWith(self: *YamlParser, prefix: []const u8) bool {
        if (self.pos + prefix.len > self.source.len) return false;
        return std.mem.eql(u8, self.source[self.pos..][0..prefix.len], prefix);
    }

    fn skipSpaces(self: *YamlParser) void {
        while (self.pos < self.source.len and (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) {
            self.pos += 1;
        }
    }

    fn skipToEndOfLine(self: *YamlParser) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) self.pos += 1; // Skip newline
    }

    fn skipWhitespaceAndComments(self: *YamlParser) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                self.pos += 1;
            } else if (c == '#') {
                self.skipToEndOfLine();
            } else {
                break;
            }
        }
    }

    fn currentIndent(self: *YamlParser) usize {
        // Find start of current line
        var line_start = self.pos;
        while (line_start > 0 and self.source[line_start - 1] != '\n') {
            line_start -= 1;
        }

        // Count spaces
        var indent: usize = 0;
        var i = line_start;
        while (i < self.source.len and self.source[i] == ' ') {
            indent += 1;
            i += 1;
        }
        return indent;
    }

    fn isAtLineStart(self: *YamlParser) bool {
        if (self.pos == 0) return true;
        return self.source[self.pos - 1] == '\n';
    }

    fn isKeyValueLine(self: *YamlParser) bool {
        var i = self.pos;
        while (i < self.source.len) {
            const c = self.source[i];
            if (c == ':') {
                // Check if followed by space, newline, or EOF
                if (i + 1 >= self.source.len) return true;
                const next = self.source[i + 1];
                return next == ' ' or next == '\n' or next == '\r';
            }
            if (c == '\n' or c == '\r' or c == '#') return false;
            i += 1;
        }
        return false;
    }

    fn readWord(self: *YamlParser) []const u8 {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == ':' or c == '#') break;
            self.pos += 1;
        }
        return self.source[start..self.pos];
    }

    fn readUntilColon(self: *YamlParser) []const u8 {
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] != ':') {
            self.pos += 1;
        }
        return std.mem.trim(u8, self.source[start..self.pos], " \t");
    }
};

// ============================================================================
// YAML Stringifier
// ============================================================================

fn stringifyValue(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: Value, indent: usize) !void {
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
            // Check if quoting is needed
            var needs_quotes = false;
            for (s) |c| {
                if (c == ':' or c == '#' or c == '\n' or c == '"' or c == '\'') {
                    needs_quotes = true;
                    break;
                }
            }
            if (needs_quotes) {
                try output.append(allocator, '"');
                for (s) |c| {
                    if (c == '"') {
                        try output.appendSlice(allocator, "\\\"");
                    } else if (c == '\n') {
                        try output.appendSlice(allocator, "\\n");
                    } else {
                        try output.append(allocator, c);
                    }
                }
                try output.append(allocator, '"');
            } else {
                try output.appendSlice(allocator, s);
            }
        },
        .list => |l| {
            if (l.items.items.len == 0) {
                try output.appendSlice(allocator, "[]");
            } else {
                for (l.items.items, 0..) |item, i| {
                    if (i > 0 or indent > 0) {
                        try output.append(allocator, '\n');
                        try appendIndent(allocator, output, indent);
                    }
                    try output.appendSlice(allocator, "- ");
                    try stringifyValue(allocator, output, item, indent + 2);
                }
            }
        },
        .dict => |d| {
            if (d.keys.items.len == 0) {
                try output.appendSlice(allocator, "{}");
            } else {
                for (d.keys.items, 0..) |key, i| {
                    if (i > 0 or indent > 0) {
                        try output.append(allocator, '\n');
                        try appendIndent(allocator, output, indent);
                    }
                    // Write key
                    const key_str = if (key == .string) key.string else blk: {
                        const s = try key.toString(allocator);
                        break :blk s;
                    };
                    try output.appendSlice(allocator, key_str);
                    try output.appendSlice(allocator, ": ");

                    // Write value
                    const val = d.values.items[i];
                    if (val == .list or val == .dict) {
                        try stringifyValue(allocator, output, val, indent + 2);
                    } else {
                        try stringifyValue(allocator, output, val, 0);
                    }
                }
            }
        },
        .function => try output.appendSlice(allocator, "null"),
        .socket => try output.appendSlice(allocator, "null"),
    }
}

fn appendIndent(allocator: std.mem.Allocator, output: *std.ArrayList(u8), indent: usize) !void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try output.append(allocator, ' ');
    }
}
