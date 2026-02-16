//! Interpreter module - executes AST nodes to produce values.
//!
//! The interpreter uses tree-walking evaluation:
//! - Evaluates expressions to produce values
//! - Executes statements for side effects
//! - Handles control flow (break, continue, return)
//! - Supports user-defined functions

pub const Interpreter = @import("interpreter.zig").Interpreter;
pub const RuntimeError = @import("../runtime/mod.zig").RuntimeError;
pub const ControlFlow = @import("../runtime/mod.zig").ControlFlow;
