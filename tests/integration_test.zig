//! Integration tests - full program execution tests.

const std = @import("std");
const Lexer = @import("../src/lexer/lexer.zig").Lexer;
const Parser = @import("../src/parser/parser.zig").Parser;
const Interpreter = @import("../src/interpreter/interpreter.zig").Interpreter;
const Environment = @import("../src/runtime/environment.zig").Environment;
const Value = @import("../src/runtime/value.zig").Value;

/// Helper to run source code and get a variable's value.
fn runAndGet(allocator: std.mem.Allocator, source: []const u8, var_name: []const u8) ?Value {
    var env = Environment.init(allocator);
    defer env.deinit();

    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    var tokens = lexer.tokenize(allocator) catch return null;
    defer tokens.deinit(allocator);

    var parser = Parser.init(allocator, tokens.items);
    defer parser.deinit();

    const statements = parser.parse() catch return null;

    var interpreter = Interpreter.init(allocator, &env);
    interpreter.execute(statements) catch return null;

    return env.get(var_name);
}

// ============================================================================
// Fibonacci Tests
// ============================================================================

test "integration: fibonacci" {
    const source =
        \\def fib(n):
        \\    if n <= 1:
        \\        return n
        \\    return fib(n - 1) + fib(n - 2)
        \\result = fib(10)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 55), result.?.integer);
}

// ============================================================================
// Factorial Tests
// ============================================================================

test "integration: factorial" {
    const source =
        \\def factorial(n):
        \\    if n <= 1:
        \\        return 1
        \\    return n * factorial(n - 1)
        \\result = factorial(7)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 5040), result.?.integer);
}

// ============================================================================
// FizzBuzz Tests
// ============================================================================

test "integration: fizzbuzz" {
    const source =
        \\def fizzbuzz(n):
        \\    if n % 15 == 0:
        \\        return "fizzbuzz"
        \\    elif n % 3 == 0:
        \\        return "fizz"
        \\    elif n % 5 == 0:
        \\        return "buzz"
        \\    else:
        \\        return str(n)
        \\result = fizzbuzz(15)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("fizzbuzz", result.?.string);
}

// ============================================================================
// Sum of List Tests
// ============================================================================

test "integration: sum list" {
    const source =
        \\def sum_list(lst):
        \\    total = 0
        \\    for x in lst:
        \\        total = total + x
        \\    return total
        \\result = sum_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 55), result.?.integer);
}

// ============================================================================
// String Processing Tests
// ============================================================================

test "integration: reverse string" {
    const source =
        \\def reverse(s):
        \\    chars = list(s)
        \\    chars.reverse()
        \\    return "".join(chars)
        \\result = reverse("hello")
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("olleh", result.?.string);
}

// ============================================================================
// List Processing Tests
// ============================================================================

test "integration: filter even" {
    const source =
        \\def filter_even(lst):
        \\    result = []
        \\    for x in lst:
        \\        if x % 2 == 0:
        \\            result.append(x)
        \\    return result
        \\evens = filter_even([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        \\result = len(evens)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 5), result.?.integer);
}

// ============================================================================
// Prime Number Tests
// ============================================================================

test "integration: is prime" {
    const source =
        \\def is_prime(n):
        \\    if n < 2:
        \\        return false
        \\    i = 2
        \\    while i * i <= n:
        \\        if n % i == 0:
        \\            return false
        \\        i = i + 1
        \\    return true
        \\result = is_prime(17)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.boolean);
}

test "integration: not prime" {
    const source =
        \\def is_prime(n):
        \\    if n < 2:
        \\        return false
        \\    i = 2
        \\    while i * i <= n:
        \\        if n % i == 0:
        \\            return false
        \\        i = i + 1
        \\    return true
        \\result = is_prime(15)
    ;

    const result = runAndGet(std.testing.allocator, source, "result");
    try std.testing.expect(result != null);
    try std.testing.expect(!result.?.boolean);
}
