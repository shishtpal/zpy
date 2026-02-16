//! CLI module - command-line interface handling.
//!
//! This module provides:
//! - `CliOptions` - parsed command-line options
//! - `parseArgs` - argument parsing function
//! - `printHelp`, `printUsage` - help display functions

const std = @import("std");

/// The interpreter version string.
pub const VERSION = "0.1.0";

/// Parsed command-line options.
pub const CliOptions = struct {
    show_help: bool = false,
    show_version: bool = false,
    run_repl: bool = false,
    execute_code: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
    dump_tokens: bool = false,
    dump_ast: bool = false,
    compile_script: bool = false,
    output_name: ?[]const u8 = null,
    standalone: bool = false, // Embed interpreter for true portability
};

/// Result of parsing arguments.
pub const ParseResult = struct {
    options: CliOptions,
    owned_code: ?[]const u8 = null,
};

/// Parses command-line arguments into CliOptions.
///
/// Parameters:
/// - allocator: Memory allocator for string duplication
/// - args_iter: Argument iterator (already past program name)
///
/// Returns the parsed options and any owned memory that needs to be freed.
pub fn parseArgs(
    allocator: std.mem.Allocator,
    args_iter: anytype,
) !ParseResult {
    var options = CliOptions{};
    var owned_code: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            options.show_help = true;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            options.show_version = true;
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interactive")) {
            options.run_repl = true;
        } else if (std.mem.eql(u8, arg, "--tokens")) {
            options.dump_tokens = true;
        } else if (std.mem.eql(u8, arg, "--ast")) {
            options.dump_ast = true;
        } else if (std.mem.eql(u8, arg, "--compile")) {
            options.compile_script = true;
        } else if (std.mem.eql(u8, arg, "--standalone")) {
            options.standalone = true;
            options.compile_script = true; // --standalone implies --compile
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            // Next argument is the output name
            if (args_iter.next()) |out_name| {
                options.output_name = out_name;
            } else {
                std.debug.print("Error: --output requires an argument\n\n", .{});
                printUsage();
                return error.MissingArgument;
            }
        } else if (std.mem.startsWith(u8, arg, "-o=")) {
            options.output_name = arg[3..];
        } else if (std.mem.startsWith(u8, arg, "--output=")) {
            options.output_name = arg[9..];
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--code")) {
            // Next argument is the code to execute
            if (args_iter.next()) |code| {
                owned_code = try allocator.dupe(u8, code);
                options.execute_code = owned_code;
            } else {
                std.debug.print("Error: --code requires an argument\n\n", .{});
                printUsage();
                return error.MissingArgument;
            }
        } else if (std.mem.startsWith(u8, arg, "-c=")) {
            // Handle -c="code" syntax
            owned_code = try allocator.dupe(u8, arg[3..]);
            options.execute_code = owned_code;
        } else if (std.mem.startsWith(u8, arg, "--code=")) {
            // Handle --code="code" syntax
            owned_code = try allocator.dupe(u8, arg[7..]);
            options.execute_code = owned_code;
        } else if (std.mem.eql(u8, arg, "repl")) {
            options.run_repl = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            // Positional argument - treat as file path
            options.file_path = arg;
        } else {
            std.debug.print("Error: Unknown option '{s}'\n\n", .{arg});
            printUsage();
            return error.UnknownOption;
        }
    }

    return .{
        .options = options,
        .owned_code = owned_code,
    };
}

/// Prints a brief usage message.
pub fn printUsage() void {
    std.debug.print("Usage: zpy [options] [file]\n", .{});
    std.debug.print("Try 'zpy --help' for more information.\n", .{});
}

/// Prints the full help message.
pub fn printHelp() void {
    std.debug.print(
        \\ZPy {s} - A Python-like language interpreter written in Zig
        \\
        \\USAGE:
        \\    zpy [OPTIONS] [FILE]
        \\
        \\OPTIONS:
        \\    -h, --help           Show this help message
        \\    -v, --version        Show version information
        \\    -i, --interactive    Run file then enter REPL
        \\    -c, --code <CODE>    Execute code string and exit
        \\    --tokens             Dump tokens (for debugging)
        \\    --ast                Dump AST (for debugging)
        \\    --compile            Compile script to .zig file (needs src/ nearby)
        \\    --standalone         Create portable package with embedded interpreter
        \\    -o, --output <NAME>  Output name for compiled executable
        \\    repl                 Start interactive REPL
        \\
        \\EXAMPLES:
        \\    zpy script.zpy              Run a ZPy script
        \\    zpy                         Start interactive REPL
        \\    zpy repl                    Start interactive REPL
        \\    zpy -c "print(1 + 2)"       Execute code string
        \\    zpy -i script.zpy           Run script then enter REPL
        \\    zpy --tokens script.zpy     Show tokens for script
        \\    zpy --ast script.zpy        Show AST for script
        \\    zpy --compile script.zpy    Create script.zig (run in ZPy dir)
        \\    zpy --standalone script.zpy Create portable script_standalone/
        \\
        \\COMPILING TO EXECUTABLE:
        \\    # Quick compile (must run in ZPy project directory):
        \\    zpy --compile script.zpy
        \\    zig build-exe script.zig -O ReleaseSmall
        \\
        \\    # Portable compile (self-contained, works anywhere):
        \\    zpy --standalone script.zpy
        \\    cd script_standalone
        \\    zig build-exe script.zig -O ReleaseSmall
        \\
        \\ENVIRONMENT:
        \\    ZPY_HOME    If set, --compile outputs to this directory
        \\
        \\LANGUAGE FEATURES:
        \\    Data Types: int, float, string, bool, none, list, dict, function
        \\    Control Flow: if/elif/else, while, for-in, break, continue, return
        \\    Operators: +, -, *, /, %, ==, !=, <, >, <=, >=, and, or, not
        \\    Assignment: =, +=, -=, *=, /=, %=
        \\    Built-ins: print, len, int, float, str, bool, range, append,
        \\               keys, values, type
        \\    Functions: def name(params): body
        \\
    , .{VERSION});
}

// ============================================================================
// Tests
// ============================================================================

test "cli: parse help flag" {
    var args = [_][]const u8{ "--help" };
    var iter = std.process.Args.Iterator.fromSlice(&args);

    const result = try parseArgs(std.testing.allocator, &iter);
    try std.testing.expect(result.options.show_help);
    try std.testing.expect(!result.options.show_version);
}

test "cli: parse version flag" {
    var args = [_][]const u8{ "-v" };
    var iter = std.process.Args.Iterator.fromSlice(&args);

    const result = try parseArgs(std.testing.allocator, &iter);
    try std.testing.expect(result.options.show_version);
    try std.testing.expect(!result.options.show_help);
}

test "cli: parse file path" {
    var args = [_][]const u8{ "script.zpy" };
    var iter = std.process.Args.Iterator.fromSlice(&args);

    const result = try parseArgs(std.testing.allocator, &iter);
    try std.testing.expectEqualStrings("script.zpy", result.options.file_path.?);
}
