const std = @import("std");
const Token = @import("../token/mod.zig").Token;

// Forward declaration for recursive types
pub const Expr = union(enum) {
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    none,
    identifier: []const u8,
    binary: Binary,
    unary: Unary,
    call: Call,
    index: Index,
    list: List,
    dict: Dict,
    method_call: MethodCall,
    membership: Membership,

    pub const Membership = struct {
        value: *Expr,
        collection: *Expr,
        negated: bool, // true for "not in"
    };

    pub const MethodCall = struct {
        object: *Expr,
        method: []const u8,
        args: []*Expr,
    };

    pub const Binary = struct {
        left: *Expr,
        op: Token,
        right: *Expr,
    };

    pub const Unary = struct {
        op: Token,
        operand: *Expr,
    };

    pub const Call = struct {
        callee: []const u8,
        args: []*Expr,
    };

    pub const Index = struct {
        object: *Expr,
        index: *Expr,
    };

    pub const List = struct {
        elements: []*Expr,
    };

    pub const Dict = struct {
        keys: []*Expr,
        values: []*Expr,
    };
};

pub const Stmt = union(enum) {
    expr_stmt: *Expr,
    assignment: Assignment,
    index_assign: IndexAssign,
    aug_assign: AugAssign,
    del_stmt: DelStmt,
    pass_stmt,
    if_stmt: IfStmt,
    while_stmt: WhileStmt,
    for_stmt: ForStmt,
    break_stmt,
    continue_stmt,
    block: Block,
    func_def: FuncDef,
    return_stmt: ReturnStmt,

    pub const Assignment = struct {
        name: []const u8,
        value: *Expr,
    };

    pub const IndexAssign = struct {
        object: *Expr,
        index: *Expr,
        value: *Expr,
    };

    pub const DelStmt = struct {
        object: *Expr,
        index: *Expr,
    };

    pub const AugAssign = struct {
        name: []const u8,
        op: Token, // The augmented operator (+=, -=, etc.)
        value: *Expr,
    };

    pub const IfStmt = struct {
        condition: *Expr,
        then_branch: *Stmt,
        elif_branches: []ElifBranch,
        else_branch: ?*Stmt,

        pub const ElifBranch = struct {
            condition: *Expr,
            body: *Stmt,
        };
    };

    pub const WhileStmt = struct {
        condition: *Expr,
        body: *Stmt,
    };

    pub const ForStmt = struct {
        variable: []const u8,
        iterable: *Expr,
        body: *Stmt,
    };

    pub const Block = struct {
        statements: []*Stmt,
    };

    pub const FuncDef = struct {
        name: []const u8,
        params: []const []const u8,
        body: *Stmt,
    };

    pub const ReturnStmt = struct {
        value: ?*Expr,
    };
};

// AST node allocator helper
pub const AstAllocator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AstAllocator {
        return .{ .allocator = allocator };
    }

    pub fn createExpr(self: *AstAllocator, expr: Expr) !*Expr {
        const ptr = try self.allocator.create(Expr);
        ptr.* = expr;
        return ptr;
    }

    pub fn createStmt(self: *AstAllocator, stmt: Stmt) !*Stmt {
        const ptr = try self.allocator.create(Stmt);
        ptr.* = stmt;
        return ptr;
    }

    pub fn allocExprs(self: *AstAllocator, count: usize) ![]*Expr {
        return try self.allocator.alloc(*Expr, count);
    }

    pub fn allocStmts(self: *AstAllocator, count: usize) ![]*Stmt {
        return try self.allocator.alloc(*Stmt, count);
    }

    pub fn allocElifBranches(self: *AstAllocator, count: usize) ![]Stmt.IfStmt.ElifBranch {
        return try self.allocator.alloc(Stmt.IfStmt.ElifBranch, count);
    }
};
