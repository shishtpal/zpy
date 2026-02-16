//! Builtins module - provides built-in functions and methods.
//!
//! Built-in functions:
//! - `print`, `len`, `input` - I/O operations
//! - `int`, `float`, `str`, `bool` - type conversions
//! - `range`, `enumerate`, `zip` - iteration helpers
//! - `min`, `max`, `sum`, `abs` - math operations
//! - `sorted`, `reversed` - sequence operations
//! - And more...
//!
//! Method handlers:
//! - `callStringMethod` - string method dispatcher
//! - `callListMethod` - list method dispatcher
//! - `callDictMethod` - dict method dispatcher

pub const BuiltinError = @import("builtins.zig").BuiltinError;
pub const BuiltinFn = @import("builtins.zig").BuiltinFn;
pub const getBuiltin = @import("builtins.zig").getBuiltin;

pub const callStringMethod = @import("string_methods.zig").callStringMethod;
pub const callListMethod = @import("list_methods.zig").callListMethod;
pub const callDictMethod = @import("dict_methods.zig").callDictMethod;
