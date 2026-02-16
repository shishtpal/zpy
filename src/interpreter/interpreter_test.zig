//! Interpreter tests - comprehensive test suite for the interpreter.

const std = @import("std");
const Lexer = @import("../lexer/mod.zig").Lexer;
const Parser = @import("../parser/mod.zig").Parser;
const Interpreter = @import("interpreter.zig").Interpreter;
const runtime = @import("../runtime/mod.zig");
const Environment = runtime.Environment;
const Value = runtime.Value;

/// Helper to run source code and return the last value from the environment.
fn runSource(allocator: std.mem.Allocator, source: []const u8) !Value {
    var env = Environment.init(allocator);
    defer env.deinit();

    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(allocator);
    defer tokens.deinit(allocator);

    var parser = Parser.init(allocator, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(allocator, &env);
    try interpreter.execute(statements);

    // Return the value of 'result' variable if it exists
    if (env.get("result")) |val| {
        return val;
    }
    return Value.none;
}

/// Helper to expect a specific integer result.
fn expectIntResult(source: []const u8, expected: i64) !void {
    const result = try runSource(std.testing.allocator, source);
    try std.testing.expectEqual(expected, result.integer);
}

/// Helper to expect a specific float result.
fn expectFloatResult(source: []const u8, expected: f64) !void {
    const result = try runSource(std.testing.allocator, source);
    try std.testing.expectApproxEqAbs(expected, result.float, 0.0001);
}

/// Helper to expect a specific boolean result.
fn expectBoolResult(source: []const u8, expected: bool) !void {
    const result = try runSource(std.testing.allocator, source);
    try std.testing.expectEqual(expected, result.boolean);
}

/// Helper to expect a specific string result.
fn expectStringResult(source: []const u8, expected: []const u8) !void {
    const result = try runSource(std.testing.allocator, source);
    try std.testing.expectEqualStrings(expected, result.string);
}

// ============================================================================
// Arithmetic Tests
// ============================================================================

test "interpreter: integer addition" {
    try expectIntResult("result = 5 + 3", 8);
}

test "interpreter: integer subtraction" {
    try expectIntResult("result = 10 - 4", 6);
}

test "interpreter: integer multiplication" {
    try expectIntResult("result = 6 * 7", 42);
}

test "interpreter: integer division" {
    try expectIntResult("result = 15 / 4", 3); // truncated
}

test "interpreter: integer modulo" {
    try expectIntResult("result = 17 % 5", 2);
}

test "interpreter: float addition" {
    try expectFloatResult("result = 3.5 + 2.5", 6.0);
}

test "interpreter: mixed int float" {
    try expectFloatResult("result = 5 + 2.5", 7.5);
}

test "interpreter: negative numbers" {
    try expectIntResult("result = -5 + 3", -2);
}

test "interpreter: operator precedence" {
    try expectIntResult("result = 2 + 3 * 4", 14);
}

test "interpreter: parentheses" {
    try expectIntResult("result = (2 + 3) * 4", 20);
}

// ============================================================================
// String Tests
// ============================================================================

test "interpreter: string concatenation" {
    try expectStringResult("result = \"hello\" + \" world\"", "hello world");
}

test "interpreter: string repetition" {
    try expectStringResult("result = \"ab\" * 3", "ababab");
}

test "interpreter: string reverse repetition" {
    try expectStringResult("result = 3 * \"x\"", "xxx");
}

// ============================================================================
// Comparison Tests
// ============================================================================

test "interpreter: less than true" {
    try expectBoolResult("result = 3 < 5", true);
}

test "interpreter: less than false" {
    try expectBoolResult("result = 5 < 3", false);
}

test "interpreter: greater than" {
    try expectBoolResult("result = 5 > 3", true);
}

test "interpreter: less than or equal" {
    try expectBoolResult("result = 5 <= 5", true);
}

test "interpreter: greater than or equal" {
    try expectBoolResult("result = 5 >= 6", false);
}

test "interpreter: equality" {
    try expectBoolResult("result = 5 == 5", true);
}

test "interpreter: inequality" {
    try expectBoolResult("result = 5 != 3", true);
}

test "interpreter: string comparison" {
    try expectBoolResult("result = \"apple\" < \"banana\"", true);
}

// ============================================================================
// Logical Tests
// ============================================================================

test "interpreter: and true" {
    try expectBoolResult("result = true and true", true);
}

test "interpreter: and false" {
    try expectBoolResult("result = true and false", false);
}

test "interpreter: or true" {
    try expectBoolResult("result = false or true", true);
}

test "interpreter: or false" {
    try expectBoolResult("result = false or false", false);
}

test "interpreter: not true" {
    try expectBoolResult("result = not false", true);
}

test "interpreter: not false" {
    try expectBoolResult("result = not true", false);
}

// ============================================================================
// Variable Tests
// ============================================================================

test "interpreter: variable assignment" {
    try expectIntResult("x = 42\nresult = x", 42);
}

test "interpreter: variable reassignment" {
    try expectIntResult("x = 10\nx = 20\nresult = x", 20);
}

test "interpreter: augmented assignment plus" {
    try expectIntResult("x = 10\nx += 5\nresult = x", 15);
}

test "interpreter: augmented assignment minus" {
    try expectIntResult("x = 10\nx -= 3\nresult = x", 7);
}

test "interpreter: augmented assignment multiply" {
    try expectIntResult("x = 10\nx *= 2\nresult = x", 20);
}

// ============================================================================
// Control Flow Tests
// ============================================================================

test "interpreter: if true branch" {
    try expectIntResult(
        \\if true:
        \\    result = 1
        \\else:
        \\    result = 2
    , 1);
}

test "interpreter: if else branch" {
    try expectIntResult(
        \\if false:
        \\    result = 1
        \\else:
        \\    result = 2
    , 2);
}

test "interpreter: if elif" {
    try expectIntResult(
        \\x = 2
        \\if x == 1:
        \\    result = 1
        \\elif x == 2:
        \\    result = 2
        \\else:
        \\    result = 3
    , 2);
}

test "interpreter: while loop" {
    try expectIntResult(
        \\i = 0
        \\while i < 5:
        \\    i = i + 1
        \\result = i
    , 5);
}

test "interpreter: while break" {
    try expectIntResult(
        \\i = 0
        \\while true:
        \\    i = i + 1
        \\    if i >= 3:
        \\        break
        \\result = i
    , 3);
}

test "interpreter: while continue" {
    try expectIntResult(
        \\i = 0
        \\sum = 0
        \\while i < 5:
        \\    i = i + 1
        \\    if i == 3:
        \\        continue
        \\    sum = sum + i
        \\result = sum
    , 12); // 1 + 2 + 4 + 5 = 12
}

test "interpreter: for loop range" {
    try expectIntResult(
        \\sum = 0
        \\for i in range(5):
        \\    sum = sum + i
        \\result = sum
    , 10); // 0 + 1 + 2 + 3 + 4 = 10
}

test "interpreter: for loop list" {
    try expectIntResult(
        \\sum = 0
        \\for x in [1, 2, 3, 4, 5]:
        \\    sum = sum + x
        \\result = sum
    , 15);
}

// ============================================================================
// Function Tests
// ============================================================================

test "interpreter: function definition and call" {
    try expectIntResult(
        \\def add(a, b):
        \\    return a + b
        \\result = add(3, 4)
    , 7);
}

test "interpreter: function no return" {
    try expectIntResult(
        \\x = 0
        \\def set_x(val):
        \\    x = val
        \\set_x(42)
        \\result = x
    , 42);
}

test "interpreter: nested function calls" {
    try expectIntResult(
        \\def double(x):
        \\    return x * 2
        \\def triple(x):
        \\    return x * 3
        \\result = double(triple(5))
    , 30);
}

test "interpreter: recursion" {
    try expectIntResult(
        \\def factorial(n):
        \\    if n <= 1:
        \\        return 1
        \\    return n * factorial(n - 1)
        \\result = factorial(5)
    , 120);
}

// ============================================================================
// List Tests
// ============================================================================

test "interpreter: list literal" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    var lexer = Lexer.init(std.testing.allocator, "result = [1, 2, 3]");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(std.testing.allocator);
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(std.testing.allocator, &env);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(usize, 3), result.list.items.items.len);
}

test "interpreter: list index" {
    try expectIntResult("result = [10, 20, 30][1]", 20);
}

test "interpreter: list negative index" {
    try expectIntResult("result = [10, 20, 30][-1]", 30);
}

test "interpreter: list append" {
    try expectIntResult(
        \\x = [1, 2]
        \\x.append(3)
        \\result = len(x)
    , 3);
}

// ============================================================================
// Dict Tests
// ============================================================================

test "interpreter: dict literal" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    var lexer = Lexer.init(std.testing.allocator, "result = {\"a\": 1, \"b\": 2}");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(std.testing.allocator);
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(std.testing.allocator, &env);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(usize, 2), result.dict.keys.items.len);
}

test "interpreter: dict access" {
    try expectIntResult("result = {\"x\": 10, \"y\": 20}[\"y\"]", 20);
}

// ============================================================================
// Built-in Tests
// ============================================================================

test "interpreter: len string" {
    try expectIntResult("result = len(\"hello\")", 5);
}

test "interpreter: len list" {
    try expectIntResult("result = len([1, 2, 3, 4])", 4);
}

test "interpreter: range single arg" {
    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    var lexer = Lexer.init(std.testing.allocator, "result = range(5)");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(std.testing.allocator);
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(std.testing.allocator, &env);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(usize, 5), result.list.items.items.len);
}

test "interpreter: type function" {
    try expectStringResult("result = type(42)", "int");
    try expectStringResult("result = type(3.14)", "float");
    try expectStringResult("result = type(\"hello\")", "string");
    try expectStringResult("result = type(true)", "bool");
}
