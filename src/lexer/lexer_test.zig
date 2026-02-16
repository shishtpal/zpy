//! Lexer tests - comprehensive test suite for the lexer.

const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("../token/mod.zig").TokenType;

// ============================================================================
// Basic Token Tests
// ============================================================================

test "lexer: tokenize integer" {
    var lexer = Lexer.init(std.testing.allocator, "42");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer, tok.type);
    try std.testing.expectEqualStrings("42", tok.lexeme);
}

test "lexer: tokenize negative integer" {
    var lexer = Lexer.init(std.testing.allocator, "-123");
    defer lexer.deinit();

    const tok1 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.minus, tok1.type);

    const tok2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer, tok2.type);
    try std.testing.expectEqualStrings("123", tok2.lexeme);
}

test "lexer: tokenize float" {
    var lexer = Lexer.init(std.testing.allocator, "3.14");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.float, tok.type);
    try std.testing.expectEqualStrings("3.14", tok.lexeme);
}

test "lexer: tokenize string double quote" {
    var lexer = Lexer.init(std.testing.allocator, "\"hello\"");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, tok.type);
    try std.testing.expectEqualStrings("\"hello\"", tok.lexeme);
}

test "lexer: tokenize string single quote" {
    var lexer = Lexer.init(std.testing.allocator, "'world'");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, tok.type);
    try std.testing.expectEqualStrings("'world'", tok.lexeme);
}

test "lexer: tokenize identifier" {
    var lexer = Lexer.init(std.testing.allocator, "my_variable");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.identifier, tok.type);
    try std.testing.expectEqualStrings("my_variable", tok.lexeme);
}

// ============================================================================
// Keyword Tests
// ============================================================================

test "lexer: tokenize keyword true" {
    var lexer = Lexer.init(std.testing.allocator, "true");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_true, tok.type);
}

test "lexer: tokenize keyword false" {
    var lexer = Lexer.init(std.testing.allocator, "false");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_false, tok.type);
}

test "lexer: tokenize keyword if" {
    var lexer = Lexer.init(std.testing.allocator, "if");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_if, tok.type);
}

test "lexer: tokenize keyword while" {
    var lexer = Lexer.init(std.testing.allocator, "while");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_while, tok.type);
}

test "lexer: tokenize keyword for" {
    var lexer = Lexer.init(std.testing.allocator, "for");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_for, tok.type);
}

test "lexer: tokenize keyword def" {
    var lexer = Lexer.init(std.testing.allocator, "def");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_def, tok.type);
}

test "lexer: tokenize keyword return" {
    var lexer = Lexer.init(std.testing.allocator, "return");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_return, tok.type);
}

// ============================================================================
// Operator Tests
// ============================================================================

test "lexer: tokenize plus" {
    var lexer = Lexer.init(std.testing.allocator, "+");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.plus, tok.type);
}

test "lexer: tokenize minus" {
    var lexer = Lexer.init(std.testing.allocator, "-");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.minus, tok.type);
}

test "lexer: tokenize star" {
    var lexer = Lexer.init(std.testing.allocator, "*");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.star, tok.type);
}

test "lexer: tokenize slash" {
    var lexer = Lexer.init(std.testing.allocator, "/");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.slash, tok.type);
}

test "lexer: tokenize percent" {
    var lexer = Lexer.init(std.testing.allocator, "%");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.percent, tok.type);
}

test "lexer: tokenize plus equals" {
    var lexer = Lexer.init(std.testing.allocator, "+=");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.plus_eq, tok.type);
}

test "lexer: tokenize minus equals" {
    var lexer = Lexer.init(std.testing.allocator, "-=");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.minus_eq, tok.type);
}

test "lexer: tokenize comparison operators" {
    var lexer = Lexer.init(std.testing.allocator, "== != < > <= >=");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.eq_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.not_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lt, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.gt, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lt_eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.gt_eq, lexer.nextToken().type);
}

// ============================================================================
// Delimiter Tests
// ============================================================================

test "lexer: tokenize delimiters" {
    var lexer = Lexer.init(std.testing.allocator, "()[]{}:,.");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.lparen, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.rparen, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lbracket, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.rbracket, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lbrace, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.rbrace, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.dot, lexer.nextToken().type);
}

// ============================================================================
// Indentation Tests
// ============================================================================

test "lexer: tokenize indent" {
    var lexer = Lexer.init(std.testing.allocator, "if true:\n    print(1)");
    defer lexer.deinit();

    // if
    try std.testing.expectEqual(TokenType.kw_if, lexer.nextToken().type);
    // true
    try std.testing.expectEqual(TokenType.kw_true, lexer.nextToken().type);
    // :
    try std.testing.expectEqual(TokenType.colon, lexer.nextToken().type);
    // newline
    try std.testing.expectEqual(TokenType.newline, lexer.nextToken().type);
    // indent
    try std.testing.expectEqual(TokenType.indent, lexer.nextToken().type);
}

test "lexer: tokenize dedent" {
    var lexer = Lexer.init(std.testing.allocator, "if true:\n    print(1)\nprint(2)");
    defer lexer.deinit();

    // Skip to after indent
    _ = lexer.nextToken(); // if
    _ = lexer.nextToken(); // true
    _ = lexer.nextToken(); // :
    _ = lexer.nextToken(); // newline
    _ = lexer.nextToken(); // indent
    _ = lexer.nextToken(); // print
    _ = lexer.nextToken(); // (
    _ = lexer.nextToken(); // 1
    _ = lexer.nextToken(); // )
    _ = lexer.nextToken(); // newline
    // dedent
    try std.testing.expectEqual(TokenType.dedent, lexer.nextToken().type);
}

// ============================================================================
// Comment Tests
// ============================================================================

test "lexer: skip single line comment" {
    var lexer = Lexer.init(std.testing.allocator, "# This is a comment\n42");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.newline, tok.type);

    const tok2 = lexer.nextToken();
    try std.testing.expectEqual(TokenType.integer, tok2.type);
}

// ============================================================================
// Multiple Tokens Tests
// ============================================================================

test "lexer: tokenize expression" {
    var lexer = Lexer.init(std.testing.allocator, "1 + 2 * 3");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.integer, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.plus, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.integer, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.star, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.integer, lexer.nextToken().type);
}

test "lexer: tokenize function call" {
    var lexer = Lexer.init(std.testing.allocator, "print(\"hello\", 42)");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.lparen, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.string, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.comma, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.integer, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.rparen, lexer.nextToken().type);
}

test "lexer: tokenize assignment" {
    var lexer = Lexer.init(std.testing.allocator, "x = 10");
    defer lexer.deinit();

    try std.testing.expectEqual(TokenType.identifier, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.eq, lexer.nextToken().type);
    try std.testing.expectEqual(TokenType.integer, lexer.nextToken().type);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "lexer: empty input" {
    var lexer = Lexer.init(std.testing.allocator, "");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.eof, tok.type);
}

test "lexer: whitespace only" {
    var lexer = Lexer.init(std.testing.allocator, "   \t\n");
    defer lexer.deinit();

    const tok = lexer.nextToken();
    try std.testing.expectEqual(TokenType.newline, tok.type);
}

test "lexer: tokenize all" {
    var lexer = Lexer.init(std.testing.allocator, "1 + 2");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(std.testing.allocator);
    defer tokens.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), tokens.items.len); // 1, +, 2, eof
}
