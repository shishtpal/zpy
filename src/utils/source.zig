//! Source utilities module - file reading and source code handling.
//!
//! This module provides:
//! - `readFile` - read source code from a file

const std = @import("std");

/// Reads the contents of a file.
///
/// Parameters:
/// - io: I/O context
/// - allocator: Memory allocator for the file contents
/// - path: Path to the file
///
/// Returns the file contents or null if the file couldn't be read.
pub fn readFile(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !?[]u8 {
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch |err| {
        std.debug.print("Error: Could not open file '{s}': {}\n", .{ path, err });
        return null;
    };
    defer file.close(io);

    // Get file size and read contents
    const stat = try file.stat(io);
    const file_size: usize = @intCast(stat.size);

    const source = try allocator.alloc(u8, file_size);

    // Read using positional read
    _ = try file.readPositional(io, &[_][]u8{source}, 0);

    return source;
}

// ============================================================================
// Tests
// ============================================================================

test "utils: readFile non-existent" {
    const result = try readFile(undefined, std.testing.allocator, "nonexistent_file.zpy");
    try std.testing.expect(result == null);
}
