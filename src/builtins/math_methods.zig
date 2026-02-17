//! Math methods module - mathematical function implementations.
//!
//! This module provides math built-ins similar to Python's math module:
//! - Power/log: `math_sqrt`, `math_cbrt`, `math_exp`, `math_log`, etc.
//! - Trig: `math_sin`, `math_cos`, `math_tan`, `math_asin`, etc.
//! - Hyperbolic: `math_sinh`, `math_cosh`, `math_tanh`, etc.
//! - Rounding: `math_floor`, `math_ceil`, `math_round`, `math_trunc`
//! - Utility: `math_fabs`, `math_fmod`, `math_hypot`, etc.
//!
//! Note: Power operation is available via `**` operator (e.g., `2 ** 3 = 8`).
//! Note: `abs(x)` builtin already exists; `math_fabs` always returns float.

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const MathBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets a math built-in function by name.
pub fn getMathBuiltin(name: []const u8) ?MathBuiltinFn {
    const builtins = std.StaticStringMap(MathBuiltinFn).initComptime(.{
        // Power and logarithmic
        .{ "math_sqrt", mathSqrt },
        .{ "math_cbrt", mathCbrt },
        .{ "math_exp", mathExp },
        .{ "math_expm1", mathExpm1 },
        .{ "math_log", mathLog },
        .{ "math_log2", mathLog2 },
        .{ "math_log10", mathLog10 },
        .{ "math_log1p", mathLog1p },
        // Trigonometric
        .{ "math_sin", mathSin },
        .{ "math_cos", mathCos },
        .{ "math_tan", mathTan },
        .{ "math_asin", mathAsin },
        .{ "math_acos", mathAcos },
        .{ "math_atan", mathAtan },
        .{ "math_atan2", mathAtan2 },
        // Hyperbolic
        .{ "math_sinh", mathSinh },
        .{ "math_cosh", mathCosh },
        .{ "math_tanh", mathTanh },
        .{ "math_asinh", mathAsinh },
        .{ "math_acosh", mathAcosh },
        .{ "math_atanh", mathAtanh },
        // Rounding
        .{ "math_floor", mathFloor },
        .{ "math_ceil", mathCeil },
        .{ "math_round", mathRound },
        .{ "math_trunc", mathTrunc },
        // Utility
        .{ "math_fabs", mathFabs },
        .{ "math_fmod", mathFmod },
        .{ "math_modf", mathModf },
        .{ "math_copysign", mathCopysign },
        .{ "math_hypot", mathHypot },
        // Constants
        .{ "math_pi", mathPi },
        .{ "math_e", mathE },
        .{ "math_tau", mathTau },
        .{ "math_inf", mathInf },
        .{ "math_nan", mathNan },
    });
    return builtins.get(name);
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Convert a Value to f64 for math operations
fn toFloat(val: Value) ?f64 {
    return switch (val) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => null,
    };
}

// ============================================================================
// Power and Logarithmic Functions
// ============================================================================

/// math_sqrt(x) - Square root
fn mathSqrt(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.sqrt(x) };
}

/// math_cbrt(x) - Cube root
fn mathCbrt(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.cbrt(x) };
}

/// math_exp(x) - e raised to power x
fn mathExp(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @exp(x) };
}

/// math_expm1(x) - e^x - 1
fn mathExpm1(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.expm1(x) };
}

/// math_log(x) - Natural logarithm
fn mathLog(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @log(x) };
}

/// math_log2(x) - Base-2 logarithm
fn mathLog2(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.log2(x) };
}

/// math_log10(x) - Base-10 logarithm
fn mathLog10(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.log10(x) };
}

/// math_log1p(x) - ln(1 + x)
fn mathLog1p(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.log1p(x) };
}

// ============================================================================
// Trigonometric Functions
// ============================================================================

/// math_sin(x) - Sine (radians)
fn mathSin(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @sin(x) };
}

/// math_cos(x) - Cosine (radians)
fn mathCos(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @cos(x) };
}

/// math_tan(x) - Tangent (radians)
fn mathTan(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @tan(x) };
}

/// math_asin(x) - Arc sine
fn mathAsin(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.asin(x) };
}

/// math_acos(x) - Arc cosine
fn mathAcos(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.acos(x) };
}

/// math_atan(x) - Arc tangent
fn mathAtan(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.atan(x) };
}

/// math_atan2(y, x) - Arc tangent of y/x
fn mathAtan2(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    const y = toFloat(args[0]) orelse return BuiltinError.TypeError;
    const x = toFloat(args[1]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.atan2(y, x) };
}

// ============================================================================
// Hyperbolic Functions
// ============================================================================

/// math_sinh(x) - Hyperbolic sine
fn mathSinh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.sinh(x) };
}

/// math_cosh(x) - Hyperbolic cosine
fn mathCosh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.cosh(x) };
}

/// math_tanh(x) - Hyperbolic tangent
fn mathTanh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.tanh(x) };
}

/// math_asinh(x) - Inverse hyperbolic sine
fn mathAsinh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.asinh(x) };
}

/// math_acosh(x) - Inverse hyperbolic cosine
fn mathAcosh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.acosh(x) };
}

/// math_atanh(x) - Inverse hyperbolic tangent
fn mathAtanh(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.atanh(x) };
}

// ============================================================================
// Rounding Functions
// ============================================================================

/// math_floor(x) - Round down to nearest integer
fn mathFloor(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @floor(x) };
}

/// math_ceil(x) - Round up to nearest integer
fn mathCeil(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @ceil(x) };
}

/// math_round(x) - Round to nearest integer
fn mathRound(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @round(x) };
}

/// math_trunc(x) - Truncate to integer (remove fractional part)
fn mathTrunc(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @trunc(x) };
}

// ============================================================================
// Utility Functions
// ============================================================================

/// math_fabs(x) - Absolute value (always returns float)
fn mathFabs(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    return .{ .float = @abs(x) };
}

/// math_fmod(x, y) - Remainder of x/y
fn mathFmod(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    const y = toFloat(args[1]) orelse return BuiltinError.TypeError;
    if (y == 0.0) return BuiltinError.ValueError;
    return .{ .float = @mod(x, y) };
}

/// math_modf(x) - Return [fractional, integer] parts
fn mathModf(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;

    const int_part: f64 = @trunc(x);
    const frac_part: f64 = x - int_part;

    const result_list = allocator.create(Value.List) catch return BuiltinError.OutOfMemory;
    result_list.* = Value.List.init(allocator);
    result_list.items.append(allocator, .{ .float = frac_part }) catch return BuiltinError.OutOfMemory;
    result_list.items.append(allocator, .{ .float = int_part }) catch return BuiltinError.OutOfMemory;

    return .{ .list = result_list };
}

/// math_copysign(x, y) - Return x with sign of y
fn mathCopysign(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    const y = toFloat(args[1]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.copysign(x, y) };
}

/// math_hypot(x, y) - Euclidean distance sqrt(x^2 + y^2)
fn mathHypot(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;
    const x = toFloat(args[0]) orelse return BuiltinError.TypeError;
    const y = toFloat(args[1]) orelse return BuiltinError.TypeError;
    return .{ .float = std.math.hypot(x, y) };
}

// ============================================================================
// Constants
// ============================================================================

/// math_pi() - Returns π (pi)
fn mathPi(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .float = std.math.pi };
}

/// math_e() - Returns e (Euler's number)
fn mathE(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .float = std.math.e };
}

/// math_tau() - Returns τ (tau = 2π)
fn mathTau(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .float = std.math.tau };
}

/// math_inf() - Returns positive infinity
fn mathInf(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .float = std.math.inf(f64) };
}

/// math_nan() - Returns NaN
fn mathNan(args: []Value, _: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    return .{ .float = std.math.nan(f64) };
}
