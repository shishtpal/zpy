const std = @import("std");

pub const TokenType = enum {
    // Literals
    integer,
    float,
    string,
    identifier,

    // Keywords
    kw_true,
    kw_false,
    kw_none,
    kw_if,
    kw_elif,
    kw_else,
    kw_while,
    kw_for,
    kw_in,
    kw_break,
    kw_continue,
    kw_and,
    kw_or,
    kw_not,
    kw_def,
    kw_return,
    kw_del,
    kw_pass,

    // Operators
    plus, // +
    minus, // -
    star, // *
    slash, // /
    percent, // %
    eq, // =
    eq_eq, // ==
    not_eq, // !=
    lt, // <
    gt, // >
    lt_eq, // <=
    gt_eq, // >=
    plus_eq, // +=
    minus_eq, // -=
    star_eq, // *=
    slash_eq, // /=
    percent_eq, // %=

    // Delimiters
    lparen, // (
    rparen, // )
    lbracket, // [
    rbracket, // ]
    lbrace, // {
    rbrace, // }
    comma, // ,
    colon, // :
    dot, // .
    semicolon, // ;

    // Indentation
    newline,
    indent,
    dedent,

    // Special
    eof,
    invalid,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,

    pub fn init(token_type: TokenType, lexeme: []const u8, line: usize, column: usize) Token {
        return .{
            .type = token_type,
            .lexeme = lexeme,
            .line = line,
            .column = column,
        };
    }

    pub fn format(
        self: Token,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}, \"{s}\", {}:{})", .{
            @tagName(self.type),
            self.lexeme,
            self.line,
            self.column,
        });
    }
};

// Keyword lookup
pub fn lookupKeyword(ident: []const u8) ?TokenType {
    const keywords = std.StaticStringMap(TokenType).initComptime(.{
        .{ "true", .kw_true },
        .{ "false", .kw_false },
        .{ "none", .kw_none },
        .{ "if", .kw_if },
        .{ "elif", .kw_elif },
        .{ "else", .kw_else },
        .{ "while", .kw_while },
        .{ "for", .kw_for },
        .{ "in", .kw_in },
        .{ "break", .kw_break },
        .{ "continue", .kw_continue },
        .{ "and", .kw_and },
        .{ "or", .kw_or },
        .{ "not", .kw_not },
        .{ "def", .kw_def },
        .{ "return", .kw_return },
        .{ "del", .kw_del },
        .{ "pass", .kw_pass },
    });
    return keywords.get(ident);
}

pub fn tokenTypeName(t: TokenType) []const u8 {
    return @tagName(t);
}
