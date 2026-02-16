const std = @import("std");
const token_mod = @import("../token/mod.zig");
const Token = token_mod.Token;
const TokenType = token_mod.TokenType;
const ast = @import("../ast/mod.zig");
const Expr = ast.Expr;
const Stmt = ast.Stmt;

pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedIdentifier,
    ExpectedColon,
    UnterminatedBlock,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: []const Token,
    pos: usize,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    fn alloc(self: *Parser) std.mem.Allocator {
        return self.arena.allocator();
    }

    fn createExpr(self: *Parser, expr: Expr) !*Expr {
        const ptr = try self.alloc().create(Expr);
        ptr.* = expr;
        return ptr;
    }

    fn createStmt(self: *Parser, stmt: Stmt) !*Stmt {
        const ptr = try self.alloc().create(Stmt);
        ptr.* = stmt;
        return ptr;
    }

    pub fn parse(self: *Parser) ![]*Stmt {
        var statements: std.ArrayList(*Stmt) = .empty;

        while (!self.isAtEnd()) {
            self.skipNewlines();
            if (self.isAtEnd()) break;

            if (self.parseStatement()) |stmt| {
                try statements.append(self.alloc(), stmt);
            } else |_| {
                // Skip to next line on error
                self.synchronize();
            }
        }

        return statements.toOwnedSlice(self.alloc());
    }

    fn parseStatement(self: *Parser) ParseError!*Stmt {
        self.skipNewlines();

        return switch (self.peek().type) {
            .kw_if => self.parseIfStatement(),
            .kw_while => self.parseWhileStatement(),
            .kw_for => self.parseForStatement(),
            .kw_break => self.parseBreakStatement(),
            .kw_continue => self.parseContinueStatement(),
            .kw_def => self.parseFunctionDef(),
            .kw_return => self.parseReturnStatement(),
            .kw_del => self.parseDelStatement(),
            .kw_pass => self.parsePassStatement(),
            else => self.parseExpressionStatement(),
        };
    }

    fn parseIfStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'if'

        const condition = try self.parseExpression();

        if (self.peek().type != .colon) {
            return ParseError.ExpectedColon;
        }
        _ = self.advance(); // consume ':'

        const then_branch = try self.parseBlock();

        // Parse elif branches
        var elifs: std.ArrayList(Stmt.IfStmt.ElifBranch) = .empty;
        while (self.peek().type == .kw_elif) {
            _ = self.advance(); // consume 'elif'
            const elif_cond = try self.parseExpression();
            if (self.peek().type != .colon) {
                return ParseError.ExpectedColon;
            }
            _ = self.advance();
            const elif_body = try self.parseBlock();
            try elifs.append(self.alloc(), .{ .condition = elif_cond, .body = elif_body });
        }

        // Parse else branch
        var else_branch: ?*Stmt = null;
        if (self.peek().type == .kw_else) {
            _ = self.advance(); // consume 'else'
            if (self.peek().type != .colon) {
                return ParseError.ExpectedColon;
            }
            _ = self.advance();
            else_branch = try self.parseBlock();
        }

        return self.createStmt(.{ .if_stmt = .{
            .condition = condition,
            .then_branch = then_branch,
            .elif_branches = try elifs.toOwnedSlice(self.alloc()),
            .else_branch = else_branch,
        } });
    }

    fn parseWhileStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'while'

        const condition = try self.parseExpression();

        if (self.peek().type != .colon) {
            return ParseError.ExpectedColon;
        }
        _ = self.advance();

        const body = try self.parseBlock();

        return self.createStmt(.{ .while_stmt = .{
            .condition = condition,
            .body = body,
        } });
    }

    fn parseForStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'for'

        if (self.peek().type != .identifier) {
            return ParseError.ExpectedIdentifier;
        }
        const var_name = self.advance().lexeme;

        if (self.peek().type != .kw_in) {
            return ParseError.UnexpectedToken;
        }
        _ = self.advance(); // consume 'in'

        const iterable = try self.parseExpression();

        if (self.peek().type != .colon) {
            return ParseError.ExpectedColon;
        }
        _ = self.advance();

        const body = try self.parseBlock();

        return self.createStmt(.{ .for_stmt = .{
            .variable = var_name,
            .iterable = iterable,
            .body = body,
        } });
    }

    fn parseBreakStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'break'
        self.skipNewlines();
        return self.createStmt(.break_stmt);
    }

    fn parseContinueStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'continue'
        self.skipNewlines();
        return self.createStmt(.continue_stmt);
    }

    fn parseFunctionDef(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'def'

        // Function name
        if (self.peek().type != .identifier) {
            return ParseError.ExpectedIdentifier;
        }
        const name = self.advance().lexeme;

        // Parameter list
        if (self.peek().type != .lparen) {
            return ParseError.UnexpectedToken;
        }
        _ = self.advance(); // consume '('

        var params: std.ArrayList([]const u8) = .empty;

        if (self.peek().type != .rparen) {
            if (self.peek().type != .identifier) {
                return ParseError.ExpectedIdentifier;
            }
            try params.append(self.alloc(), self.advance().lexeme);

            while (self.peek().type == .comma) {
                _ = self.advance(); // consume ','
                if (self.peek().type != .identifier) {
                    return ParseError.ExpectedIdentifier;
                }
                try params.append(self.alloc(), self.advance().lexeme);
            }
        }

        if (self.peek().type != .rparen) {
            return ParseError.UnexpectedToken;
        }
        _ = self.advance(); // consume ')'

        // Colon
        if (self.peek().type != .colon) {
            return ParseError.ExpectedColon;
        }
        _ = self.advance(); // consume ':'

        // Function body
        const body = try self.parseBlock();

        return self.createStmt(.{ .func_def = .{
            .name = name,
            .params = try params.toOwnedSlice(self.alloc()),
            .body = body,
        } });
    }

    fn parseReturnStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'return'

        // Optional return value
        var value: ?*Expr = null;
        if (self.peek().type != .newline and self.peek().type != .semicolon and self.peek().type != .eof and self.peek().type != .dedent) {
            value = try self.parseExpression();
        }

        self.skipNewlines();
        return self.createStmt(.{ .return_stmt = .{
            .value = value,
        } });
    }

    fn parseDelStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'del'

        // Parse the target expression (must be an index expression)
        const target = try self.parseExpression();

        // Verify it's an index expression
        if (target.* != .index) {
            return ParseError.UnexpectedToken;
        }

        self.skipNewlines();
        return self.createStmt(.{ .del_stmt = .{
            .object = target.index.object,
            .index = target.index.index,
        } });
    }

    fn parsePassStatement(self: *Parser) ParseError!*Stmt {
        _ = self.advance(); // consume 'pass'
        self.skipNewlines();
        return self.createStmt(.pass_stmt);
    }

    fn parseBlock(self: *Parser) ParseError!*Stmt {
        self.skipNewlines();

        if (self.peek().type != .indent) {
            // Single statement on same line or error
            return self.parseStatement();
        }

        _ = self.advance(); // consume INDENT

        var statements: std.ArrayList(*Stmt) = .empty;

        while (!self.isAtEnd() and self.peek().type != .dedent) {
            self.skipNewlines();
            if (self.isAtEnd() or self.peek().type == .dedent) break;

            if (self.parseStatement()) |stmt| {
                try statements.append(self.alloc(), stmt);
            } else |_| {
                self.synchronize();
            }
        }

        if (self.peek().type == .dedent) {
            _ = self.advance(); // consume DEDENT
        }

        return self.createStmt(.{ .block = .{
            .statements = try statements.toOwnedSlice(self.alloc()),
        } });
    }

    fn parseExpressionStatement(self: *Parser) ParseError!*Stmt {
        const expr = try self.parseExpression();

        // Check for assignment
        if (self.peek().type == .eq) {
            _ = self.advance(); // consume '='
            const value = try self.parseExpression();

            // Simple variable assignment
            if (expr.* == .identifier) {
                return self.createStmt(.{ .assignment = .{
                    .name = expr.identifier,
                    .value = value,
                } });
            }

            // Index assignment: list[i] = value
            if (expr.* == .index) {
                return self.createStmt(.{ .index_assign = .{
                    .object = expr.index.object,
                    .index = expr.index.index,
                    .value = value,
                } });
            }
        }

        // Check for augmented assignment (+=, -=, *=, /=, %=)
        const aug_op = self.peek().type;
        if (aug_op == .plus_eq or aug_op == .minus_eq or aug_op == .star_eq or
            aug_op == .slash_eq or aug_op == .percent_eq)
        {
            const op = self.advance(); // consume the augmented operator
            const value = try self.parseExpression();

            // Only valid for identifiers (variable names)
            if (expr.* == .identifier) {
                return self.createStmt(.{ .aug_assign = .{
                    .name = expr.identifier,
                    .op = op,
                    .value = value,
                } });
            }
        }

        self.skipNewlines();
        return self.createStmt(.{ .expr_stmt = expr });
    }

    // Expression parsing with precedence climbing
    fn parseExpression(self: *Parser) ParseError!*Expr {
        return self.parseOr();
    }

    fn parseOr(self: *Parser) ParseError!*Expr {
        var left = try self.parseAnd();

        while (self.peek().type == .kw_or) {
            const op = self.advance();
            const right = try self.parseAnd();
            left = try self.createExpr(.{ .binary = .{
                .left = left,
                .op = op,
                .right = right,
            } });
        }
        return left;
    }

    fn parseAnd(self: *Parser) ParseError!*Expr {
        var left = try self.parseNot();

        while (self.peek().type == .kw_and) {
            const op = self.advance();
            const right = try self.parseNot();
            left = try self.createExpr(.{ .binary = .{
                .left = left,
                .op = op,
                .right = right,
            } });
        }
        return left;
    }

    fn parseNot(self: *Parser) ParseError!*Expr {
        if (self.peek().type == .kw_not) {
            const op = self.advance();
            const operand = try self.parseNot();
            return self.createExpr(.{ .unary = .{
                .op = op,
                .operand = operand,
            } });
        }
        return self.parseComparison();
    }

    fn parseComparison(self: *Parser) ParseError!*Expr {
        var left = try self.parseAddSub();

        while (true) {
            const t = self.peek().type;
            if (t == .eq_eq or t == .not_eq or t == .lt or t == .gt or t == .lt_eq or t == .gt_eq) {
                const op = self.advance();
                const right = try self.parseAddSub();
                left = try self.createExpr(.{ .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                } });
            } else if (t == .kw_in) {
                _ = self.advance(); // consume 'in'
                const right = try self.parseAddSub();
                left = try self.createExpr(.{ .membership = .{
                    .value = left,
                    .collection = right,
                    .negated = false,
                } });
            } else if (t == .kw_not and self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].type == .kw_in) {
                _ = self.advance(); // consume 'not'
                _ = self.advance(); // consume 'in'
                const right = try self.parseAddSub();
                left = try self.createExpr(.{ .membership = .{
                    .value = left,
                    .collection = right,
                    .negated = true,
                } });
            } else {
                break;
            }
        }
        return left;
    }

    fn parseAddSub(self: *Parser) ParseError!*Expr {
        var left = try self.parseMulDiv();

        while (self.peek().type == .plus or self.peek().type == .minus) {
            const op = self.advance();
            const right = try self.parseMulDiv();
            left = try self.createExpr(.{ .binary = .{
                .left = left,
                .op = op,
                .right = right,
            } });
        }
        return left;
    }

    fn parseMulDiv(self: *Parser) ParseError!*Expr {
        var left = try self.parseUnary();

        while (self.peek().type == .star or self.peek().type == .slash or self.peek().type == .percent) {
            const op = self.advance();
            const right = try self.parseUnary();
            left = try self.createExpr(.{ .binary = .{
                .left = left,
                .op = op,
                .right = right,
            } });
        }
        return left;
    }

    fn parseUnary(self: *Parser) ParseError!*Expr {
        if (self.peek().type == .minus) {
            const op = self.advance();
            const operand = try self.parseUnary();
            return self.createExpr(.{ .unary = .{
                .op = op,
                .operand = operand,
            } });
        }
        return self.parsePostfix();
    }

    fn parsePostfix(self: *Parser) ParseError!*Expr {
        var expr = try self.parsePrimary();

        while (true) {
            if (self.peek().type == .lbracket) {
                _ = self.advance(); // consume '['
                const index = try self.parseExpression();
                if (self.peek().type != .rbracket) {
                    return ParseError.UnexpectedToken;
                }
                _ = self.advance(); // consume ']'
                expr = try self.createExpr(.{ .index = .{
                    .object = expr,
                    .index = index,
                } });
            } else if (self.peek().type == .lparen and expr.* == .identifier) {
                // Function call
                _ = self.advance(); // consume '('
                var args: std.ArrayList(*Expr) = .empty;

                if (self.peek().type != .rparen) {
                    try args.append(self.alloc(), try self.parseExpression());
                    while (self.peek().type == .comma) {
                        _ = self.advance();
                        try args.append(self.alloc(), try self.parseExpression());
                    }
                }

                if (self.peek().type != .rparen) {
                    return ParseError.UnexpectedToken;
                }
                _ = self.advance(); // consume ')'

                expr = try self.createExpr(.{ .call = .{
                    .callee = expr.identifier,
                    .args = try args.toOwnedSlice(self.alloc()),
                } });
            } else if (self.peek().type == .dot) {
                _ = self.advance(); // consume '.'
                if (self.peek().type != .identifier) {
                    return ParseError.ExpectedIdentifier;
                }
                const method_name = self.advance().lexeme;

                if (self.peek().type == .lparen) {
                    _ = self.advance(); // consume '('
                    var args: std.ArrayList(*Expr) = .empty;

                    if (self.peek().type != .rparen) {
                        try args.append(self.alloc(), try self.parseExpression());
                        while (self.peek().type == .comma) {
                            _ = self.advance();
                            try args.append(self.alloc(), try self.parseExpression());
                        }
                    }

                    if (self.peek().type != .rparen) {
                        return ParseError.UnexpectedToken;
                    }
                    _ = self.advance(); // consume ')'

                    expr = try self.createExpr(.{ .method_call = .{
                        .object = expr,
                        .method = method_name,
                        .args = try args.toOwnedSlice(self.alloc()),
                    } });
                } else {
                    return ParseError.UnexpectedToken;
                }
            } else {
                break;
            }
        }
        return expr;
    }

    fn parsePrimary(self: *Parser) ParseError!*Expr {
        const tok = self.peek();

        switch (tok.type) {
            .integer => {
                _ = self.advance();
                const value = std.fmt.parseInt(i64, tok.lexeme, 10) catch 0;
                return self.createExpr(.{ .integer = value });
            },
            .float => {
                _ = self.advance();
                const value = std.fmt.parseFloat(f64, tok.lexeme) catch 0.0;
                return self.createExpr(.{ .float = value });
            },
            .string => {
                _ = self.advance();
                const s = tok.lexeme;
                const content = if (s.len >= 2) s[1 .. s.len - 1] else s;
                const processed = try self.processEscapes(content);
                return self.createExpr(.{ .string = processed });
            },
            .kw_true => {
                _ = self.advance();
                return self.createExpr(.{ .boolean = true });
            },
            .kw_false => {
                _ = self.advance();
                return self.createExpr(.{ .boolean = false });
            },
            .kw_none => {
                _ = self.advance();
                return self.createExpr(.none);
            },
            .identifier => {
                _ = self.advance();
                return self.createExpr(.{ .identifier = tok.lexeme });
            },
            .lparen => {
                _ = self.advance(); // consume '('
                const expr = try self.parseExpression();
                if (self.peek().type != .rparen) {
                    return ParseError.UnexpectedToken;
                }
                _ = self.advance(); // consume ')'
                return expr;
            },
            .lbracket => {
                return self.parseList();
            },
            .lbrace => {
                return self.parseDict();
            },
            else => {
                return ParseError.ExpectedExpression;
            },
        }
    }

    fn parseList(self: *Parser) ParseError!*Expr {
        _ = self.advance(); // consume '['

        var elements: std.ArrayList(*Expr) = .empty;

        if (self.peek().type != .rbracket) {
            try elements.append(self.alloc(), try self.parseExpression());
            while (self.peek().type == .comma) {
                _ = self.advance();
                if (self.peek().type == .rbracket) break; // trailing comma
                try elements.append(self.alloc(), try self.parseExpression());
            }
        }

        if (self.peek().type != .rbracket) {
            return ParseError.UnexpectedToken;
        }
        _ = self.advance(); // consume ']'

        return self.createExpr(.{ .list = .{
            .elements = try elements.toOwnedSlice(self.alloc()),
        } });
    }

    fn parseDict(self: *Parser) ParseError!*Expr {
        _ = self.advance(); // consume '{'

        var keys: std.ArrayList(*Expr) = .empty;
        var values: std.ArrayList(*Expr) = .empty;

        if (self.peek().type != .rbrace) {
            // Parse first key-value pair
            try keys.append(self.alloc(), try self.parseExpression());
            if (self.peek().type != .colon) {
                return ParseError.ExpectedColon;
            }
            _ = self.advance();
            try values.append(self.alloc(), try self.parseExpression());

            while (self.peek().type == .comma) {
                _ = self.advance();
                if (self.peek().type == .rbrace) break; // trailing comma
                try keys.append(self.alloc(), try self.parseExpression());
                if (self.peek().type != .colon) {
                    return ParseError.ExpectedColon;
                }
                _ = self.advance();
                try values.append(self.alloc(), try self.parseExpression());
            }
        }

        if (self.peek().type != .rbrace) {
            return ParseError.UnexpectedToken;
        }
        _ = self.advance(); // consume '}'

        return self.createExpr(.{ .dict = .{
            .keys = try keys.toOwnedSlice(self.alloc()),
            .values = try values.toOwnedSlice(self.alloc()),
        } });
    }

    fn skipNewlines(self: *Parser) void {
        while (self.peek().type == .newline or self.peek().type == .semicolon) {
            _ = self.advance();
        }
    }

    fn synchronize(self: *Parser) void {
        while (!self.isAtEnd()) {
            if (self.peek().type == .newline or self.peek().type == .semicolon) {
                _ = self.advance();
                return;
            }
            const t = self.peek().type;
            if (t == .kw_if or t == .kw_while or t == .kw_for) {
                return;
            }
            _ = self.advance();
        }
    }

    fn peek(self: *Parser) Token {
        if (self.pos >= self.tokens.len) {
            return Token.init(.eof, "", 0, 0);
        }
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) Token {
        const tok = self.peek();
        if (self.pos < self.tokens.len) {
            self.pos += 1;
        }
        return tok;
    }

    fn isAtEnd(self: *Parser) bool {
        return self.peek().type == .eof;
    }

    fn processEscapes(self: *Parser, input: []const u8) ParseError![]const u8 {
        if (std.mem.indexOfScalar(u8, input, '\\') == null) {
            return input;
        }

        var buf = self.alloc().alloc(u8, input.len) catch return ParseError.OutOfMemory;
        var out: usize = 0;
        var i: usize = 0;

        while (i < input.len) {
            if (input[i] == '\\' and i + 1 < input.len) {
                const c = input[i + 1];
                buf[out] = switch (c) {
                    'n' => 0x0A,
                    't' => 0x09,
                    'r' => 0x0D,
                    '\\' => '\\',
                    '"' => '"',
                    '\'' => '\'',
                    '0' => 0x00,
                    else => c,
                };
                out += 1;
                i += 2;
            } else {
                buf[out] = input[i];
                out += 1;
                i += 1;
            }
        }

        return buf[0..out];
    }
};
