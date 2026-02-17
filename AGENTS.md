# AGENTS.md

> Guidance for AI agents working on the ZPy interpreter codebase.

## Project Overview

ZPy is a Python-like language interpreter written in Zig. It supports:
- Data types: int, float, string, bool, none, list, dict, function
- Control flow: if/elif/else, while, for-in, break, continue, return
- Operators: arithmetic (+, -, *, /, %, **), comparison, logical, assignment
- User-defined functions with recursion
- Built-in functions and methods
- File system operations
- OS utilities (path, environment, directory walking)
- Data formats: JSON, CSV, YAML
- HTTP client

## Architecture

```
src/
├── main.zig              # Entry point, orchestrates CLI → execution
├── cli.zig               # CLI argument parsing
├── repl.zig              # REPL implementation
│
├── lexer/
│   ├── mod.zig           # Public interface
│   └── lexer.zig         # Tokenizer (handles Python-style indentation)
│
├── parser/
│   ├── mod.zig           # Public interface
│   └── parser.zig        # Recursive descent parser
│
├── ast/
│   ├── mod.zig           # Public interface
│   └── ast.zig           # AST node types (Expr, Stmt)
│
├── token/
│   ├── mod.zig           # Public interface
│   └── token.zig         # Token types
│
├── runtime/
│   ├── mod.zig           # Public interface
│   ├── value.zig         # Runtime values (Value union)
│   ├── environment.zig   # Variable scoping
│   └── error.zig         # Error types
│
├── interpreter/
│   ├── mod.zig           # Public interface
│   ├── interpreter.zig   # Tree-walking evaluator
│   └── operations.zig    # Arithmetic/logical operations
│
├── builtins/
│   ├── mod.zig           # Public interface
│   ├── builtins.zig      # Built-in functions (print, len, range, etc.)
│   ├── string_methods.zig # String method implementations
│   ├── list_methods.zig  # List method implementations
│   ├── dict_methods.zig  # Dict method implementations
│   ├── file_methods.zig  # File system operations
│   ├── json_methods.zig  # JSON parsing/stringifying
│   ├── csv_methods.zig   # CSV parsing/stringifying
│   ├── yaml_methods.zig  # YAML parsing/stringifying
│   ├── http_methods.zig  # HTTP client
│   └── os_methods.zig    # OS utilities
│
└── utils/
    ├── mod.zig           # Public interface
    └── source.zig        # File reading utilities
```

## Data Flow

```
Source Code
    ↓
Lexer.tokenize() → []Token
    ↓
Parser.parse() → []*Stmt (AST)
    ↓
Interpreter.execute() → Side effects / Values
```

## Key Types

### Value (runtime/value.zig)
```zig
pub const Value = union(enum) {
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    none,
    list: *List,
    dict: *Dict,
    function: *Function,
};
```

### Expr (ast/ast.zig)
Expression nodes: integer, float, string, boolean, none, identifier, binary, unary, call, index, list, dict, method_call, membership

### Stmt (ast/ast.zig)
Statement nodes: expr_stmt, assignment, index_assign, aug_assign, if_stmt, while_stmt, for_stmt, break_stmt, continue_stmt, block, func_def, return_stmt

## Coding Conventions

### Import Pattern
Each module has a `mod.zig` that re-exports public API:
```zig
// src/lexer/mod.zig
pub const Lexer = @import("lexer.zig").Lexer;
```

Import from modules using the mod.zig:
```zig
const Lexer = @import("lexer/mod.zig").Lexer;
```

### Error Handling
Use the unified error types from `runtime/error.zig`:
```zig
const RuntimeError = runtime.RuntimeError;
// RuntimeError.UndefinedVariable, TypeError, DivisionByZero, etc.
```

### Memory Management
- Use arena allocators for parsing (AST nodes freed together)
- Use GPA for runtime values that need individual lifetimes
- Always defer deinit() for allocated resources

### Documentation
- Module-level: `//!` comments in mod.zig files
- Function-level: `///` comments for public functions

## Build Commands

```bash
# Build the interpreter
zig build

# Run the interpreter
zig build run -- script.zpy

# Start REPL
zig build run

# Run all tests (47 tests)
zig build test

# Run integration tests
zig build test-integration
```

## Testing

### Unit Tests
Located in `src/main_test.zig`. Tests cover:
- Lexer: tokenization of literals, keywords, operators, indentation
- Parser: expression and statement parsing
- Interpreter: arithmetic, comparisons, control flow, functions, methods

### Integration Tests
Located in `tests/integration_test.zig`. Tests real programs:
- fibonacci, factorial, fizzbuzz
- list processing, string manipulation
- prime number detection

### Adding Tests
Add tests to `src/main_test.zig` using the pattern:
```zig
test "interpreter: my feature" {
    const Lexer = @import("lexer/lexer.zig").Lexer;
    const Parser = @import("parser/parser.zig").Parser;
    const Interpreter = @import("interpreter/interpreter.zig").Interpreter;
    const Environment = @import("runtime/environment.zig").Environment;

    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    var lexer = Lexer.init(std.testing.allocator, "code here");
    defer lexer.deinit();

    var tokens = try lexer.tokenize(std.testing.allocator);
    defer tokens.deinit(std.testing.allocator);

    var parser = Parser.init(std.testing.allocator, tokens.items);
    defer parser.deinit();

    const statements = try parser.parse();

    var interpreter = Interpreter.init(std.testing.allocator, &env);
    try interpreter.execute(statements);

    // Assert results
    const result = env.get("result").?;
    try std.testing.expectEqual(@as(i64, 42), result.integer);
}
```

## Common Tasks

### Adding a New Built-in Function
1. Add function to `src/builtins/builtins.zig`
2. Register in `getBuiltin()` function
3. Add tests to `src/main_test.zig`

### Adding a New String Method
1. Add method to `src/builtins/string_methods.zig`
2. Add case to `callStringMethod()`
3. Add tests

### Adding a New Statement Type
1. Add node type to `Stmt` union in `ast/ast.zig`
2. Update parser to parse it in `parser/parser.zig`
3. Update interpreter to execute it in `interpreter/interpreter.zig`
4. Add tests

## Known Limitations

1. **No garbage collection**: Values are arena-allocated or leak until process exit
2. **Limited error recovery**: Parser stops at first error
3. **No classes/objects**: Only functions and basic types
4. **No closures**: Functions don't capture environment (intentional simplification)
5. **No async**: Synchronous execution only

## Version

- Zig: 0.16.0 or later
- ZPy: 0.1.0

## File Naming

- `*.zig` - Zig source files
- `*_test.zig` - Test files (though main tests are in main_test.zig)
- `mod.zig` - Module public interface

## When Modifying Code

1. **Run tests after changes**: `zig build test`
2. **Check for memory leaks**: Tests report leaks
3. **Update documentation**: Add `///` comments for new public APIs
4. **Follow existing patterns**: Look at similar code for conventions
5. **Keep modules focused**: Each module should have a single responsibility

## Example: Adding a `abs` Built-in

```zig
// In src/builtins/builtins.zig

fn builtinAbs(args: []Value, _: std.mem.Allocator) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;
    return switch (args[0]) {
        .integer => |i| .{ .integer = if (i < 0) -i else i },
        .float => |f| .{ .float = @abs(f) },
        else => BuiltinError.TypeError,
    };
}

// In getBuiltin():
.{ "abs", builtinAbs },
```

## Contact

For questions about the architecture, refer to:
- `README.md` - User-facing documentation
- `build.zig` - Build configuration
- Individual `mod.zig` files - Module documentation
