//! Token module - defines token types and tokenization utilities.
//!
//! This module provides the fundamental building blocks for lexical analysis:
//! - `TokenType` - enum of all token types (keywords, operators, literals, etc.)
//! - `Token` - struct representing a single token with type, lexeme, and position
//! - `lookupKeyword` - function to check if an identifier is a keyword

pub const TokenType = @import("token.zig").TokenType;
pub const Token = @import("token.zig").Token;
pub const lookupKeyword = @import("token.zig").lookupKeyword;
pub const tokenTypeName = @import("token.zig").tokenTypeName;
