//! Operations module - arithmetic and logical operations on values.
//!
//! This module provides:
//! - Arithmetic operations: add, subtract, multiply, divide, modulo
//! - Comparison operations: compare (lt, gt, le, ge)
//! - Type conversion: toFloat

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const RuntimeError = runtime.RuntimeError;
const TokenType = @import("../token/mod.zig").TokenType;

/// Adds two values together.
///
/// Supported types:
/// - integer + integer = integer
/// - float + float = float (or mixed int/float)
/// - string + string = string (concatenation)
///
/// Returns TypeError for incompatible types.
pub fn add(allocator: std.mem.Allocator, left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        return .{ .integer = left.integer + right.integer };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        return .{ .float = l + r };
    }
    if (left == .string and right == .string) {
        // String concatenation
        const new_len = left.string.len + right.string.len;
        const result = allocator.alloc(u8, new_len) catch return RuntimeError.OutOfMemory;
        @memcpy(result[0..left.string.len], left.string);
        @memcpy(result[left.string.len..], right.string);
        return .{ .string = result };
    }
    return RuntimeError.TypeError;
}

/// Subtracts two values.
///
/// Supported types:
/// - integer - integer = integer
/// - float - float = float (or mixed int/float)
///
/// Returns TypeError for incompatible types.
pub fn subtract(left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        return .{ .integer = left.integer - right.integer };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        return .{ .float = l - r };
    }
    return RuntimeError.TypeError;
}

/// Multiplies two values.
///
/// Supported types:
/// - integer * integer = integer
/// - float * float = float (or mixed int/float)
/// - string * integer = string (repetition)
/// - integer * string = string (repetition)
///
/// Returns TypeError for incompatible types.
pub fn multiply(allocator: std.mem.Allocator, left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        return .{ .integer = left.integer * right.integer };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        return .{ .float = l * r };
    }
    // String repetition: "abc" * 3 or 3 * "abc"
    if (left == .string and right == .integer) {
        const count = right.integer;
        if (count <= 0) return .{ .string = "" };
        const s = left.string;
        const n: usize = @intCast(count);
        const result = allocator.alloc(u8, s.len * n) catch return RuntimeError.OutOfMemory;
        for (0..n) |i| {
            @memcpy(result[i * s.len .. (i + 1) * s.len], s);
        }
        return .{ .string = result };
    }
    if (left == .integer and right == .string) {
        const count = left.integer;
        if (count <= 0) return .{ .string = "" };
        const s = right.string;
        const n: usize = @intCast(count);
        const result = allocator.alloc(u8, s.len * n) catch return RuntimeError.OutOfMemory;
        for (0..n) |i| {
            @memcpy(result[i * s.len .. (i + 1) * s.len], s);
        }
        return .{ .string = result };
    }
    return RuntimeError.TypeError;
}

/// Divides two values.
///
/// Supported types:
/// - integer / integer = integer (truncated division)
/// - float / float = float (or mixed int/float)
///
/// Returns DivisionByZero if right operand is zero.
/// Returns TypeError for incompatible types.
pub fn divide(left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        if (right.integer == 0) return RuntimeError.DivisionByZero;
        return .{ .integer = @divTrunc(left.integer, right.integer) };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        if (r == 0.0) return RuntimeError.DivisionByZero;
        return .{ .float = l / r };
    }
    return RuntimeError.TypeError;
}

/// Computes modulo of two values.
///
/// Supported types:
/// - integer % integer = integer
///
/// Returns DivisionByZero if right operand is zero.
/// Returns TypeError for incompatible types.
pub fn modulo(left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        if (right.integer == 0) return RuntimeError.DivisionByZero;
        return .{ .integer = @mod(left.integer, right.integer) };
    }
    return RuntimeError.TypeError;
}

/// Computes power (exponentiation) of two values.
///
/// Supported types:
/// - integer ** integer = integer (for non-negative exponents)
/// - integer ** integer = float (for negative exponents)
/// - float ** float = float (or mixed int/float)
///
/// Returns TypeError for incompatible types.
pub fn power(left: Value, right: Value) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        const base = left.integer;
        const exp = right.integer;

        // Handle negative exponents -> float result
        if (exp < 0) {
            const base_f: f64 = @floatFromInt(base);
            const exp_f: f64 = @floatFromInt(exp);
            return .{ .float = std.math.pow(f64, base_f, exp_f) };
        }

        // Non-negative exponents -> integer result
        // std.math.powi returns error on overflow
        const result = std.math.powi(i64, base, exp) catch return RuntimeError.Overflow;
        return .{ .integer = result };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        return .{ .float = std.math.pow(f64, l, r) };
    }
    return RuntimeError.TypeError;
}

/// Compares two values.
///
/// Supported types:
/// - integer comparisons
/// - float comparisons (or mixed int/float)
/// - string comparisons (lexicographic)
///
/// Returns a boolean value.
/// Returns TypeError for incompatible types.
pub fn compare(left: Value, right: Value, op: TokenType) RuntimeError!Value {
    if (left == .integer and right == .integer) {
        const result = switch (op) {
            .lt => left.integer < right.integer,
            .gt => left.integer > right.integer,
            .lt_eq => left.integer <= right.integer,
            .gt_eq => left.integer >= right.integer,
            else => false,
        };
        return .{ .boolean = result };
    }
    if (left == .float or right == .float) {
        const l = toFloat(left) orelse return RuntimeError.TypeError;
        const r = toFloat(right) orelse return RuntimeError.TypeError;
        const result = switch (op) {
            .lt => l < r,
            .gt => l > r,
            .lt_eq => l <= r,
            .gt_eq => l >= r,
            else => false,
        };
        return .{ .boolean = result };
    }
    if (left == .string and right == .string) {
        const cmp = std.mem.order(u8, left.string, right.string);
        const result = switch (op) {
            .lt => cmp == .lt,
            .gt => cmp == .gt,
            .lt_eq => cmp != .gt,
            .gt_eq => cmp != .lt,
            else => false,
        };
        return .{ .boolean = result };
    }
    return RuntimeError.TypeError;
}

/// Converts a value to float for mixed arithmetic.
///
/// Returns null if the value is not numeric.
pub fn toFloat(v: Value) ?f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => null,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "operations: add integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try add(alloc, .{ .integer = 5 }, .{ .integer = 3 });
    try std.testing.expectEqual(@as(i64, 8), result.integer);
}

test "operations: add floats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try add(alloc, .{ .float = 5.5 }, .{ .float = 3.5 });
    try std.testing.expectApproxEqAbs(@as(f64, 9.0), result.float, 0.0001);
}

test "operations: add mixed int float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try add(alloc, .{ .integer = 5 }, .{ .float = 3.5 });
    try std.testing.expectApproxEqAbs(@as(f64, 8.5), result.float, 0.0001);
}

test "operations: add strings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try add(alloc, .{ .string = "hello" }, .{ .string = " world" });
    try std.testing.expectEqualStrings("hello world", result.string);
}

test "operations: subtract integers" {
    const result = try subtract(.{ .integer = 10 }, .{ .integer = 3 });
    try std.testing.expectEqual(@as(i64, 7), result.integer);
}

test "operations: multiply integers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try multiply(alloc, .{ .integer = 4 }, .{ .integer = 5 });
    try std.testing.expectEqual(@as(i64, 20), result.integer);
}

test "operations: multiply string by integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = try multiply(alloc, .{ .string = "ab" }, .{ .integer = 3 });
    try std.testing.expectEqualStrings("ababab", result.string);
}

test "operations: divide integers" {
    const result = try divide(.{ .integer = 10 }, .{ .integer = 3 });
    try std.testing.expectEqual(@as(i64, 3), result.integer); // truncated
}

test "operations: divide by zero" {
    const result = divide(.{ .integer = 10 }, .{ .integer = 0 });
    try std.testing.expectError(RuntimeError.DivisionByZero, result);
}

test "operations: modulo" {
    const result = try modulo(.{ .integer = 10 }, .{ .integer = 3 });
    try std.testing.expectEqual(@as(i64, 1), result.integer);
}

test "operations: compare integers less than" {
    const result = try compare(.{ .integer = 5 }, .{ .integer = 10 }, .lt);
    try std.testing.expect(result.boolean);
}

test "operations: compare strings" {
    const result = try compare(.{ .string = "apple" }, .{ .string = "banana" }, .lt);
    try std.testing.expect(result.boolean);
}

test "operations: toFloat from integer" {
    const result = toFloat(.{ .integer = 42 });
    try std.testing.expectEqual(@as(f64, 42.0), result);
}

test "operations: toFloat from float" {
    const result = toFloat(.{ .float = 3.14 });
    try std.testing.expectEqual(@as(f64, 3.14), result);
}

test "operations: toFloat from string returns null" {
    const result = toFloat(.{ .string = "hello" });
    try std.testing.expect(result == null);
}
