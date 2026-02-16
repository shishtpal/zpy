//! Parser module - parses tokens into an Abstract Syntax Tree.
//!
//! The parser uses recursive descent parsing with:
//! - Precedence climbing for expressions
//! - Python-style indentation-based blocks
//! - Error recovery for better error messages

pub const Parser = @import("parser.zig").Parser;
pub const ParseError = @import("parser.zig").ParseError;
