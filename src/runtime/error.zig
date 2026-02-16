//! Error module - unified error types for the interpreter.
//!
//! This module provides all error types used across the interpreter:
//! - `RuntimeError` - errors that occur during execution
//! - `ParseError` - errors that occur during parsing
//! - `LexerError` - errors that occur during tokenization

/// Runtime errors that can occur during interpretation.
pub const RuntimeError = error{
    UndefinedVariable,
    TypeError,
    DivisionByZero,
    IndexOutOfBounds,
    KeyNotFound,
    BreakOutsideLoop,
    ContinueOutsideLoop,
    UnsupportedOperation,
    OutOfMemory,
    BuiltinError,
};

/// Parse errors that can occur during parsing.
pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedIdentifier,
    ExpectedColon,
    UnterminatedBlock,
    OutOfMemory,
};

/// Lexer errors that can occur during tokenization.
pub const LexerError = error{
    UnterminatedString,
    InvalidCharacter,
    OutOfMemory,
};

/// Control flow states for loop and function handling.
pub const ControlFlow = enum {
    normal,
    break_loop,
    continue_loop,
    return_value,
};

/// Returns a human-readable message for a runtime error.
pub fn runtimeErrorMessage(err: anyerror) []const u8 {
    return switch (err) {
        RuntimeError.UndefinedVariable => "Undefined variable",
        RuntimeError.TypeError => "Type error - incompatible types for operation",
        RuntimeError.DivisionByZero => "Division by zero",
        RuntimeError.IndexOutOfBounds => "Index out of bounds",
        RuntimeError.KeyNotFound => "Key not found in dictionary",
        RuntimeError.BreakOutsideLoop => "Break statement outside of loop",
        RuntimeError.ContinueOutsideLoop => "Continue statement outside of loop",
        RuntimeError.UnsupportedOperation => "Unsupported operation",
        RuntimeError.OutOfMemory => "Out of memory",
        RuntimeError.BuiltinError => "Error in built-in function",
        else => "Unknown runtime error",
    };
}

/// Returns a human-readable message for a parse error.
pub fn parseErrorMessage(err: anyerror) []const u8 {
    return switch (err) {
        ParseError.UnexpectedToken => "Unexpected token",
        ParseError.ExpectedExpression => "Expected an expression",
        ParseError.ExpectedIdentifier => "Expected an identifier",
        ParseError.ExpectedColon => "Expected ':'",
        ParseError.UnterminatedBlock => "Unterminated block",
        ParseError.OutOfMemory => "Out of memory",
        else => "Unknown parse error",
    };
}
