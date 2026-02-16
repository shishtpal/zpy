//! Runtime module - defines runtime values, variable scoping, and error types.
//!
//! This module provides:
//! - `Value` - union type for all runtime values (int, float, string, list, dict, function, etc.)
//! - `Environment` - variable scoping with parent chain support
//! - `valuesEqual` - value equality comparison
//! - `RuntimeError`, `ParseError`, `LexerError` - error types
//! - `ControlFlow` - control flow states

pub const Value = @import("value.zig").Value;
pub const valuesEqual = @import("value.zig").valuesEqual;
pub const Environment = @import("environment.zig").Environment;
pub const RuntimeError = @import("error.zig").RuntimeError;
pub const ParseError = @import("error.zig").ParseError;
pub const LexerError = @import("error.zig").LexerError;
pub const ControlFlow = @import("error.zig").ControlFlow;
pub const runtimeErrorMessage = @import("error.zig").runtimeErrorMessage;
pub const parseErrorMessage = @import("error.zig").parseErrorMessage;
