//! AST module - defines Abstract Syntax Tree node types.
//!
//! This module provides:
//! - `Expr` - union type for all expression nodes
//! - `Stmt` - union type for all statement nodes
//! - `AstAllocator` - helper for allocating AST nodes

pub const Expr = @import("ast.zig").Expr;
pub const Stmt = @import("ast.zig").Stmt;
pub const AstAllocator = @import("ast.zig").AstAllocator;
