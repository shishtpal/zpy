//! REPL module - Read-Eval-Print Loop implementation.
//!
//! This module provides:
//! - `runRepl` - interactive REPL loop
//! - `runCodeWithResult` - execute code and print result

const std = @import("std");
const builtin = @import("builtin");
const Lexer = @import("lexer/mod.zig").Lexer;
const Parser = @import("parser/mod.zig").Parser;
const Interpreter = @import("interpreter/mod.zig").Interpreter;
const runtime = @import("runtime/mod.zig");
const Environment = runtime.Environment;
const runtimeErrorMessage = runtime.runtimeErrorMessage;
const parseErrorMessage = runtime.parseErrorMessage;

/// Runs the interactive REPL.
///
/// Parameters:
/// - allocator: Memory allocator
/// - io: I/O context (used for HTTP/network operations)
/// - version: Version string to display
pub fn runRepl(allocator: std.mem.Allocator, io: std.Io, version: []const u8) !void {
    var env = Environment.init(allocator);
    defer env.deinit();

    // Print welcome message
    std.debug.print("ZPy {s} - Interactive REPL\n", .{version});
    std.debug.print("Type 'exit' or press Ctrl+C to quit\n\n", .{});

    var multiline_buf: std.ArrayList(u8) = .empty;
    defer multiline_buf.deinit(allocator);

    var in_multiline = false;

    // Line buffer for reading input
    var line_buf: [4096]u8 = undefined;

    // Main REPL loop
    while (true) {
        // Print prompt
        const prompt = if (in_multiline) "... " else ">>> ";
        std.debug.print("{s}", .{prompt});

        // Read a line from stdin
        const raw_line = readLineNative(&line_buf) orelse break;

        // Trim carriage return (Windows \r\n) and trailing whitespace
        var line_end = raw_line.len;
        while (line_end > 0 and (raw_line[line_end - 1] == '\r' or raw_line[line_end - 1] == '\n' or raw_line[line_end - 1] == ' ' or raw_line[line_end - 1] == '\t')) {
            line_end -= 1;
        }
        const raw_trimmed = raw_line[0..line_end];
        const line = std.mem.trim(u8, raw_trimmed, " \t");

        // Check for exit command
        if (std.mem.eql(u8, line, "exit") or std.mem.eql(u8, line, "quit")) {
            break;
        }

        // Check if line ends with colon (start of block)
        if (line.len > 0 and line[line.len - 1] == ':') {
            try multiline_buf.appendSlice(allocator, line);
            try multiline_buf.append(allocator, '\n');
            in_multiline = true;
            continue;
        }

        if (in_multiline) {
            // In multiline mode
            const indent = countLeadingSpaces(raw_trimmed);

            if (line.len == 0) {
                // Empty line - submit the block
                const source = allocator.dupe(u8, multiline_buf.items) catch continue;
                if (source.len > 0) {
                    try runCodeWithResult(allocator, &env, source, io);
                }
                multiline_buf.clearRetainingCapacity();
                in_multiline = false;
            } else if (indent == 0) {
                // Non-indented line ends the block
                const source = allocator.dupe(u8, multiline_buf.items) catch continue;
                if (source.len > 0) {
                    try runCodeWithResult(allocator, &env, source, io);
                }
                multiline_buf.clearRetainingCapacity();
                in_multiline = false;

                // Process this line as a new statement
                if (line.len > 0) {
                    const line_copy = allocator.dupe(u8, line) catch continue;
                    try runCodeWithResult(allocator, &env, line_copy, io);
                }
            } else {
                // Indented line - add to block (preserve indentation)
                try multiline_buf.appendSlice(allocator, raw_trimmed);
                try multiline_buf.append(allocator, '\n');
            }
        } else {
            // Single line statement
            if (line.len > 0) {
                const line_copy = allocator.dupe(u8, line) catch continue;
                try runCodeWithResult(allocator, &env, line_copy, io);
            }
        }
    }

    std.debug.print("Goodbye!\n", .{});
}

/// Read a line from stdin using native OS calls.
/// Returns null on EOF or error.
fn readLineNative(buf: []u8) ?[]u8 {
    if (builtin.os.tag == .windows) {
        return readLineWindows(buf);
    } else {
        return readLinePosix(buf);
    }
}

/// Read a line on Windows using NtReadFile.
/// Reads byte-by-byte to properly handle line boundaries.
fn readLineWindows(buf: []u8) ?[]u8 {
    const windows = std.os.windows;
    const ntdll = windows.ntdll;

    // Get stdin handle from PEB
    const stdin_handle = windows.peb().ProcessParameters.hStdInput;

    // Read byte by byte until we hit a newline
    var pos: usize = 0;
    while (pos < buf.len) {
        var io_status: windows.IO_STATUS_BLOCK = undefined;

        const status = ntdll.NtReadFile(
            stdin_handle,
            null, // Event
            null, // ApcRoutine
            null, // ApcContext
            &io_status,
            @ptrCast(&buf[pos]),
            1, // Read one byte at a time
            null, // ByteOffset
            null, // Key
        );

        if (status != .SUCCESS) {
            if (pos == 0) return null;
            return buf[0..pos];
        }

        const bytes_read: usize = @intCast(io_status.Information);
        if (bytes_read == 0) {
            // EOF
            if (pos == 0) return null;
            return buf[0..pos];
        }

        // Check for newline - stop here
        if (buf[pos] == '\n') {
            return buf[0 .. pos + 1];
        }

        pos += 1;
    }

    // Buffer full
    return buf[0..pos];
}

/// Read a line on POSIX using read syscall.
fn readLinePosix(buf: []u8) ?[]u8 {
    var pos: usize = 0;
    while (pos < buf.len) {
        const result = std.posix.read(std.posix.STDIN_FILENO, buf[pos..][0..1]) catch return null;
        if (result == 0) {
            // EOF
            if (pos == 0) return null;
            return buf[0..pos];
        }

        if (buf[pos] == '\n') {
            return buf[0 .. pos + 1];
        }
        pos += 1;
    }
    return buf[0..pos];
}

/// Counts leading spaces in a line.
fn countLeadingSpaces(line: []const u8) usize {
    var cnt: usize = 0;
    for (line) |c| {
        if (c == ' ') {
            cnt += 1;
        } else if (c == '\t') {
            cnt += 4;
        } else {
            break;
        }
    }
    return cnt;
}

/// Executes code and prints the result or error.
/// Note: In REPL mode, we intentionally don't free the lexer/parser output
/// because function definitions need to persist (they reference AST nodes).
/// This causes memory to accumulate during the REPL session, but it's freed
/// when the REPL exits.
pub fn runCodeWithResult(allocator: std.mem.Allocator, env: *Environment, source: []const u8, io: std.Io) !void {
    if (source.len == 0) return;

    var lexer = Lexer.init(allocator, source);
    // Note: NOT calling lexer.deinit() - tokens need to persist for functions

    var tokens = lexer.tokenize(allocator) catch |err| {
        std.debug.print("\x1b[31mLexer error:\x1b[0m {}\n", .{err});
        return;
    };
    // Note: NOT calling tokens.deinit() - needed for function bodies

    var parser = Parser.init(allocator, tokens.items);
    // Note: NOT calling parser.deinit() - AST nodes needed for functions

    const statements = parser.parse() catch |err| {
        std.debug.print("\x1b[31mParse error:\x1b[0m {s}\n", .{parseErrorMessage(err)});
        return;
    };

    var interpreter = Interpreter.init(allocator, env, io);
    interpreter.execute(statements) catch |err| {
        std.debug.print("\x1b[31mRuntime error:\x1b[0m {s}\n", .{runtimeErrorMessage(err)});
    };
}
