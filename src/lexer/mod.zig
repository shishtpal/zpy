//! Lexer module - tokenizes source code into a stream of tokens.
//!
//! The lexer handles:
//! - Python-style indentation (INDENT/DEDENT tokens)
//! - Keywords, identifiers, and literals
//! - String escape sequences
//! - Comments (ignored)

pub const Lexer = @import("lexer.zig").Lexer;
