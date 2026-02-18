//! Main test file - runs all tests for the ZPy interpreter.

const std = @import("std");

// Re-export all tests from submodules
test {
    std.testing.refAllDecls(@import("lexer/lexer.zig"));
    std.testing.refAllDecls(@import("token/token.zig"));
    std.testing.refAllDecls(@import("ast/ast.zig"));
    std.testing.refAllDecls(@import("parser/parser.zig"));
    std.testing.refAllDecls(@import("runtime/value.zig"));
    std.testing.refAllDecls(@import("runtime/environment.zig"));
    std.testing.refAllDecls(@import("interpreter/interpreter.zig"));
    std.testing.refAllDecls(@import("interpreter/operations.zig"));
    std.testing.refAllDecls(@import("builtins/builtins.zig"));
    std.testing.refAllDecls(@import("builtins/string_methods.zig"));
    std.testing.refAllDecls(@import("builtins/list_methods.zig"));
    std.testing.refAllDecls(@import("builtins/dict_methods.zig"));
    std.testing.refAllDecls(@import("builtins/subprocess_methods.zig"));
    std.testing.refAllDecls(@import("builtins/process_utils.zig"));
}

// ============================================================================
// Lexer Tests
// ============================================================================

test "lexer: tokenize integer" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "42");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer, tok.type);
    try std.testing.expectEqualStrings("42", tok.lexeme);
}

test "lexer: tokenize float" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "3.14");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.float, tok.type);
    try std.testing.expectEqualStrings("3.14", tok.lexeme);
}

test "lexer: tokenize string" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "\"hello\"");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, tok.type);
    try std.testing.expectEqualStrings("\"hello\"", tok.lexeme);
}

test "lexer: tokenize keywords" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "if while for def return true false none");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.kw_if, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_while, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_for, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_def, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_return, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_true, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_false, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_none, lexer.nextToken().type);
}

test "lexer: tokenize operators" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "+ - * / % == != < > <= >=");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.plus, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.minus, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.star, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.slash, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.percent, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.eq_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.not_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lt, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.gt, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lt_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.gt_eq, lexer.nextToken().type);
}

test "lexer: tokenize indent/dedent" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const TokenType = @import("token/token.zig").TokenType;

    var lexer = Lexer.init(std.testing.allocator, "if true:\n    print(1)\nprint(2)");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.kw_if, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.kw_true, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.newline, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.indent, lexer.nextToken().type);
}

// ============================================================================
// Interpreter Tests
// ============================================================================

test "interpreter: integer arithmetic" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    var lexer = Lexer.init(alloc, "result = 5 + 3 * 2");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 11), result.integer);
}

test "interpreter: string concatenation" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    var lexer = Lexer.init(alloc, "result = \"hello\" + \" world\"");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqualStrings("hello world", result.string);
}

test "interpreter: comparison operators" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    var lexer = Lexer.init(alloc, "result = 5 < 10");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expect(result.boolean);
}

test "interpreter: if statement" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\if true:
        \\    result = 1
        \\else:
        \\    result = 2
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 1), result.integer);
}

test "interpreter: while loop" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\i = 0
        \\while i < 5:
        \\    i = i + 1
        \\result = i
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 5), result.integer);
}

test "interpreter: function definition and call" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\def add(a, b):
        \\    return a + b
        \\result = add(3, 4)
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 7), result.integer);
}

test "interpreter: factorial" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\def factorial(n):
        \\    if n <= 1:
        \\        return 1
        \\    return n * factorial(n - 1)
        \\result = factorial(5)
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 120), result.integer);
}

test "interpreter: list operations" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\x = [1, 2, 3]
        \\x.append(4)
        \\result = len(x)
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 4), result.integer);
}

test "interpreter: string methods" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source = "result = \"hello\".upper()";

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqualStrings("HELLO", result.string);
}

test "interpreter: for loop with range" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    const source =
        \\sum = 0
        \\for i in range(5):
        \\    sum = sum + i
        \\result = sum
    ;

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(alloc);
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(alloc, &env, undefined);
    try interpreter.execute(statements);

    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 10), result.integer); // 0+1+2+3+4 = 10
}
