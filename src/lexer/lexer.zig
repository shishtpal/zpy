const std = @import("std");
const token = @import("../token/mod.zig");
const Token = token.Token;
const TokenType = token.TokenType;

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    column: usize,
    indent_stack: std.ArrayList(usize),
    pending_dedents: usize,
    at_line_start: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        var indent_stack: std.ArrayList(usize) = .empty;
        indent_stack.append(allocator, 0) catch {};
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .column = 1,
            .indent_stack = indent_stack,
            .pending_dedents = 0,
            .at_line_start = true,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.indent_stack.deinit(self.allocator);
    }

    pub fn nextToken(self: *Lexer) Token {
        // Emit pending dedents first
        if (self.pending_dedents > 0) {
            self.pending_dedents -= 1;
            return Token.init(.dedent, "", self.line, self.column);
        }

        // Handle indentation at line start
        if (self.at_line_start) {
            self.at_line_start = false;
            const indent = self.countIndent();

            const current_indent = self.indent_stack.getLast();

            if (indent > current_indent) {
                self.indent_stack.append(self.allocator, indent) catch {};
                return Token.init(.indent, "", self.line, self.column);
            } else if (indent < current_indent) {
                // Count how many dedents we need
                while (self.indent_stack.items.len > 1 and
                    self.indent_stack.getLast() > indent)
                {
                    _ = self.indent_stack.pop();
                    self.pending_dedents += 1;
                }
                if (self.pending_dedents > 0) {
                    self.pending_dedents -= 1;
                    return Token.init(.dedent, "", self.line, self.column);
                }
            }
        }

        self.skipWhitespace();

        if (self.isAtEnd()) {
            // Emit remaining dedents at EOF
            if (self.indent_stack.items.len > 1) {
                _ = self.indent_stack.pop();
                return Token.init(.dedent, "", self.line, self.column);
            }
            return Token.init(.eof, "", self.line, self.column);
        }

        const c = self.peek();

        // Skip comments
        if (c == '#') {
            self.skipComment();
            return self.nextToken();
        }

        // Newline
        if (c == '\n') {
            self.advance();
            self.line += 1;
            self.column = 1;
            self.at_line_start = true;
            return Token.init(.newline, "\\n", self.line - 1, 1);
        }

        // Skip carriage return
        if (c == '\r') {
            self.advance();
            return self.nextToken();
        }

        // Numbers
        if (std.ascii.isDigit(c)) {
            return self.scanNumber();
        }

        // Strings
        if (c == '"' or c == '\'') {
            return self.scanString();
        }

        // Identifiers and keywords
        if (std.ascii.isAlphabetic(c) or c == '_') {
            return self.scanIdentifier();
        }

        // Operators and delimiters
        return self.scanOperator();
    }

    fn countIndent(self: *Lexer) usize {
        var indent: usize = 0;
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == ' ') {
                indent += 1;
                self.advance();
            } else if (c == '\t') {
                indent += 4; // Tab = 4 spaces
                self.advance();
            } else if (c == '\n' or c == '\r') {
                // Empty line - reset and skip
                indent = 0;
                if (c == '\r') self.advance();
                if (!self.isAtEnd() and self.peek() == '\n') self.advance();
                self.line += 1;
                self.column = 1;
            } else if (c == '#') {
                // Comment line - skip to newline
                self.skipComment();
                if (!self.isAtEnd() and self.peek() == '\n') {
                    self.advance();
                    self.line += 1;
                    self.column = 1;
                }
                indent = 0;
            } else {
                break;
            }
        }
        return indent;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == ' ' or c == '\t' or c == '\r') {
                self.advance();
            } else {
                break;
            }
        }
    }

    fn skipComment(self: *Lexer) void {
        while (!self.isAtEnd() and self.peek() != '\n') {
            self.advance();
        }
    }

    fn scanNumber(self: *Lexer) Token {
        const start = self.pos;
        const start_col = self.column;
        var is_float = false;

        while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
            self.advance();
        }

        // Check for decimal point
        if (!self.isAtEnd() and self.peek() == '.' and
            self.pos + 1 < self.source.len and std.ascii.isDigit(self.source[self.pos + 1]))
        {
            is_float = true;
            self.advance(); // consume '.'
            while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                self.advance();
            }
        }

        const lexeme = self.source[start..self.pos];
        return Token.init(
            if (is_float) .float else .integer,
            lexeme,
            self.line,
            start_col,
        );
    }

    fn scanString(self: *Lexer) Token {
        const quote = self.peek();
        const start = self.pos;
        const start_col = self.column;
        self.advance(); // consume opening quote

        while (!self.isAtEnd() and self.peek() != quote) {
            if (self.peek() == '\n') {
                // Unterminated string
                break;
            }
            if (self.peek() == '\\' and self.pos + 1 < self.source.len) {
                self.advance(); // skip backslash
            }
            self.advance();
        }

        if (!self.isAtEnd() and self.peek() == quote) {
            self.advance(); // consume closing quote
        }

        const lexeme = self.source[start..self.pos];
        return Token.init(.string, lexeme, self.line, start_col);
    }

    fn scanIdentifier(self: *Lexer) Token {
        const start = self.pos;
        const start_col = self.column;

        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
            self.advance();
        }

        const lexeme = self.source[start..self.pos];

        // Check if it's a keyword
        const token_type = token.lookupKeyword(lexeme) orelse .identifier;
        return Token.init(token_type, lexeme, self.line, start_col);
    }

    fn scanOperator(self: *Lexer) Token {
        const start_col = self.column;
        const start = self.pos;
        const c = self.peek();
        self.advance();

        const token_type: TokenType = switch (c) {
            '+' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .plus_eq;
                }
                break :blk .plus;
            },
            '-' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .minus_eq;
                }
                break :blk .minus;
            },
            '*' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .star_eq;
                }
                break :blk .star;
            },
            '/' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .slash_eq;
                }
                break :blk .slash;
            },
            '%' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .percent_eq;
                }
                break :blk .percent;
            },
            '(' => .lparen,
            ')' => .rparen,
            '[' => .lbracket,
            ']' => .rbracket,
            '{' => .lbrace,
            '}' => .rbrace,
            ',' => .comma,
            ':' => .colon,
            '=' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .eq_eq;
                }
                break :blk .eq;
            },
            '!' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .not_eq;
                }
                break :blk .invalid;
            },
            '<' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .lt_eq;
                }
                break :blk .lt;
            },
            '>' => blk: {
                if (!self.isAtEnd() and self.peek() == '=') {
                    self.advance();
                    break :blk .gt_eq;
                }
                break :blk .gt;
            },
            '.' => .dot,
            ';' => .semicolon,
            else => .invalid,
        };

        return Token.init(token_type, self.source[start..self.pos], self.line, start_col);
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn advance(self: *Lexer) void {
        if (!self.isAtEnd()) {
            self.pos += 1;
            self.column += 1;
        }
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    // Tokenize entire source into array
    pub fn tokenize(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
        var tokens: std.ArrayList(Token) = .empty;
        while (true) {
            const tok = self.nextToken();
            try tokens.append(allocator, tok);
            if (tok.type == .eof) break;
        }
        return tokens;
    }
};
