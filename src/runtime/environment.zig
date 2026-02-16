const std = @import("std");
const Value = @import("value.zig").Value;

pub const Environment = struct {
    values: std.StringHashMap(Value),
    parent: ?*Environment,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Environment {
        return .{
            .values = std.StringHashMap(Value).init(allocator),
            .parent = null,
            .allocator = allocator,
        };
    }

    pub fn initWithParent(allocator: std.mem.Allocator, parent: *Environment) Environment {
        return .{
            .values = std.StringHashMap(Value).init(allocator),
            .parent = parent,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Environment) void {
        // Free all owned keys
        var it = self.values.keyIterator();
        while (it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        self.values.deinit();
    }

    pub fn define(self: *Environment, name: []const u8, value: Value) !void {
        // Check if key already exists - if so, just update value
        if (self.values.getPtr(name)) |val_ptr| {
            val_ptr.* = value;
            return;
        }
        // Duplicate the key so we own it
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        try self.values.put(owned_name, value);
    }

    pub fn get(self: *Environment, name: []const u8) ?Value {
        if (self.values.get(name)) |v| {
            return v;
        }
        if (self.parent) |p| {
            return p.get(name);
        }
        return null;
    }

    pub fn assign(self: *Environment, name: []const u8, value: Value) bool {
        // Try to find existing key and update value
        if (self.values.getPtr(name)) |val_ptr| {
            val_ptr.* = value;
            return true;
        }
        if (self.parent) |p| {
            return p.assign(name, value);
        }
        // Variable doesn't exist - define it in current scope
        self.define(name, value) catch return false;
        return true;
    }

    pub fn remove(self: *Environment, name: []const u8) bool {
        const kv = self.values.fetchRemove(name);
        if (kv) |entry| {
            // Free the owned key
            self.allocator.free(entry.key);
            return true;
        }
        if (self.parent) |p| {
            return p.remove(name);
        }
        return false;
    }
};
