//! Compiler module - compiles ZPy scripts to standalone executables.
//!
//! Usage:
//!   zpy --compile script.zpy -o output_name
//!   zpy --standalone script.zpy
//!
//! This creates output_name.zig which can be compiled with:
//!   zig build-exe output_name.zig -O ReleaseSmall

const std = @import("std");

/// Generates a Zig file that imports interpreter from ZPY_HOME or relative path.
pub fn bundleScript(
    allocator: std.mem.Allocator,
    script: []const u8,
    zpy_home: ?[]const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    // Write header
    try output.appendSlice(allocator,
        \\//! Bundled ZPy script
        \\//! Compile with: zig build-exe thisfile.zig -O ReleaseSmall
        \\
        \\const std = @import("std");
        \\
        \\// Embedded script source
        \\const SCRIPT =
    );

    // Embed script as multiline string literal
    var line_iter = std.mem.splitScalar(u8, script, '\n');
    while (line_iter.next()) |line| {
        try output.appendSlice(allocator, "\n    \\\\");
        for (line) |c| {
            switch (c) {
                '\r' => {}, // Skip carriage returns
                else => try output.append(allocator, c),
            }
        }
    }
    try output.appendSlice(allocator, "\n;\n\n");

    // Determine import path (convert backslashes to forward slashes for Zig)
    var path_buf: [512]u8 = undefined;
    const import_prefix = if (zpy_home) |home|
        toForwardSlash(home, &path_buf)
    else
        "";

    // Write imports with path prefix
    try output.appendSlice(allocator, "// Import interpreter modules\n");
    try output.appendSlice(allocator, "const Lexer = @import(\"");
    try output.appendSlice(allocator, import_prefix);
    try output.appendSlice(allocator, "src/lexer/mod.zig\").Lexer;\n");
    try output.appendSlice(allocator, "const Parser = @import(\"");
    try output.appendSlice(allocator, import_prefix);
    try output.appendSlice(allocator, "src/parser/mod.zig\").Parser;\n");
    try output.appendSlice(allocator, "const Interpreter = @import(\"");
    try output.appendSlice(allocator, import_prefix);
    try output.appendSlice(allocator, "src/interpreter/mod.zig\").Interpreter;\n");
    try output.appendSlice(allocator, "const Environment = @import(\"");
    try output.appendSlice(allocator, import_prefix);
    try output.appendSlice(allocator, "src/runtime/mod.zig\").Environment;\n");
    try output.appendSlice(allocator,
        \\
        \\pub fn main(init: std.process.Init) !void {
        \\    const allocator = init.gpa;
        \\
        \\    var env = Environment.init(allocator);
        \\    defer env.deinit();
        \\
        \\    var lexer = Lexer.init(allocator, SCRIPT);
        \\    defer lexer.deinit();
        \\
        \\    var tokens = lexer.tokenize(allocator) catch |err| {
        \\        std.debug.print("Lexer error: {}\n", .{err});
        \\        return;
        \\    };
        \\    defer tokens.deinit(allocator);
        \\
        \\    var parser = Parser.init(allocator, tokens.items);
        \\    defer parser.deinit();
        \\
        \\    const statements = parser.parse() catch |err| {
        \\        std.debug.print("Parse error: {}\n", .{err});
        \\        return;
        \\    };
        \\
        \\    var interpreter = Interpreter.init(allocator, &env);
        \\    interpreter.execute(statements) catch |err| {
        \\        std.debug.print("Runtime error: {}\n", .{err});
        \\    };
        \\}
        \\
    );

    return output.toOwnedSlice(allocator);
}

/// Generates a standalone package: .zig file + src/ directory copy.
pub fn bundleStandalone(
    allocator: std.mem.Allocator,
    script: []const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    // Write header
    try output.appendSlice(allocator,
        \\//! Standalone ZPy script - fully self-contained
        \\//! Compile with: zig build-exe thisfile.zig -O ReleaseSmall
        \\//!
        \\//! This package includes the src/ directory with the interpreter.
        \\
        \\const std = @import("std");
        \\
        \\// Embedded script source
        \\const SCRIPT =
    );

    // Embed script as multiline string literal
    var line_iter = std.mem.splitScalar(u8, script, '\n');
    while (line_iter.next()) |line| {
        try output.appendSlice(allocator, "\n    \\\\");
        for (line) |c| {
            switch (c) {
                '\r' => {}, // Skip carriage returns
                else => try output.append(allocator, c),
            }
        }
    }
    try output.appendSlice(allocator, "\n;\n\n");

    // Write imports - use relative path to the copied src/ directory
    try output.appendSlice(allocator,
        \\// Import interpreter modules (from bundled src/ directory)
        \\const Lexer = @import("src/lexer/mod.zig").Lexer;
        \\const Parser = @import("src/parser/mod.zig").Parser;
        \\const Interpreter = @import("src/interpreter/mod.zig").Interpreter;
        \\const Environment = @import("src/runtime/mod.zig").Environment;
        \\
        \\pub fn main(init: std.process.Init) !void {
        \\    const allocator = init.gpa;
        \\
        \\    var env = Environment.init(allocator);
        \\    defer env.deinit();
        \\
        \\    var lexer = Lexer.init(allocator, SCRIPT);
        \\    defer lexer.deinit();
        \\
        \\    var tokens = lexer.tokenize(allocator) catch |err| {
        \\        std.debug.print("Lexer error: {}\n", .{err});
        \\        return;
        \\    };
        \\    defer tokens.deinit(allocator);
        \\
        \\    var parser = Parser.init(allocator, tokens.items);
        \\    defer parser.deinit();
        \\
        \\    const statements = parser.parse() catch |err| {
        \\        std.debug.print("Parse error: {}\n", .{err});
        \\        return;
        \\    };
        \\
        \\    var interpreter = Interpreter.init(allocator, &env);
        \\    interpreter.execute(statements) catch |err| {
        \\        std.debug.print("Runtime error: {}\n", .{err});
        \\    };
        \\}
        \\
    );

    return output.toOwnedSlice(allocator);
}

/// Converts backslashes to forward slashes for Zig compatibility.
fn toForwardSlash(path: []const u8, buf: []u8) []const u8 {
    if (path.len > buf.len) return path;
    for (path, 0..) |c, i| {
        buf[i] = if (c == '\\') '/' else c;
    }
    // Ensure trailing slash
    const len = path.len;
    if (len > 0 and buf[len - 1] != '/') {
        if (len < buf.len) {
            buf[len] = '/';
            return buf[0 .. len + 1];
        }
    }
    return buf[0..len];
}

/// Recursively copies a directory.
fn copyDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    src_dir: std.Io.Dir,
    src_path: []const u8,
    dest_dir: std.Io.Dir,
    dest_path: []const u8,
) !void {
    // Create destination directory
    dest_dir.createDir(io, dest_path, .default_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Open source directory
    const src = src_dir.openDir(io, src_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error: Could not open source directory '{s}': {}\n", .{ src_path, err });
        return err;
    };
    defer src.close(io);

    // Open destination directory
    const dest = dest_dir.openDir(io, dest_path, .{}) catch |err| {
        std.debug.print("Error: Could not open destination directory '{s}': {}\n", .{ dest_path, err });
        return err;
    };
    defer dest.close(io);

    // Iterate and copy
    var iter = src.iterate();
    while (try iter.next(io)) |entry| {
        const entry_src = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ src_path, entry.name });
        defer allocator.free(entry_src);
        const entry_dest = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_path, entry.name });
        defer allocator.free(entry_dest);

        switch (entry.kind) {
            .file => {
                src_dir.copyFile(entry_src, dest_dir, entry_dest, io, .{}) catch |err| {
                    std.debug.print("Warning: Could not copy '{s}': {}\n", .{ entry_src, err });
                };
            },
            .directory => {
                try copyDir(allocator, io, src_dir, entry_src, dest_dir, entry_dest);
            },
            else => {},
        }
    }
}

/// Gets ZPY_HOME from environment, returns null if not set.
fn getZpyHome(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map) ?[]const u8 {
    const key = "ZPY_HOME";
    if (environ_map.get(key)) |value| {
        // Duplicate to ensure consistent lifetime
        return allocator.dupe(u8, value) catch return null;
    }
    return null;
}

/// Creates a standalone executable from a ZPy script.
pub fn compileToFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    script_path: []const u8,
    output_name: ?[]const u8,
    standalone: bool,
) !void {
    // Read the script
    const cwd = std.Io.Dir.cwd();
    const script_file = cwd.openFile(io, script_path, .{}) catch |err| {
        std.debug.print("Error: Could not open script '{s}': {}\n", .{ script_path, err });
        return err;
    };
    defer script_file.close(io);

    const stat = try script_file.stat(io);
    const file_size: usize = @intCast(stat.size);
    const script = try allocator.alloc(u8, file_size);
    defer allocator.free(script);

    _ = try script_file.readPositional(io, &[_][]u8{script}, 0);

    // Determine output name
    const script_name = std.fs.path.stem(script_path);
    const out_name = output_name orelse script_name;

    // Get ZPY_HOME if set (used by both modes)
    const zpy_home = getZpyHome(allocator, environ_map);
    defer if (zpy_home) |home| allocator.free(home);

    if (standalone) {
        // Create output directory
        const out_dir_name = try std.fmt.allocPrint(allocator, "{s}_standalone", .{out_name});
        defer allocator.free(out_dir_name);

        cwd.createDir(io, out_dir_name, .default_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Error: Could not create output directory '{s}': {}\n", .{ out_dir_name, err });
                return err;
            }
        };

        // Determine source directory for src/
        const src_root_dir: std.Io.Dir = if (zpy_home) |home|
            cwd.openDir(io, home, .{}) catch |err| {
                std.debug.print("Error: Could not open ZPY_HOME directory '{s}': {}\n", .{ home, err });
                return err;
            }
        else
            cwd;
        defer if (zpy_home) |_| src_root_dir.close(io);

        // Copy src/ directory to output
        if (zpy_home) |home| {
            std.debug.print("Copying interpreter source from ZPY_HOME ({s})...\n", .{home});
        } else {
            std.debug.print("Copying interpreter source from current directory...\n", .{});
        }
        const dest_src_path = try std.fmt.allocPrint(allocator, "{s}/src", .{out_dir_name});
        defer allocator.free(dest_src_path);

        try copyDir(allocator, io, src_root_dir, "src", cwd, dest_src_path);

        // Generate bundled source
        const bundled = try bundleStandalone(allocator, script);
        defer allocator.free(bundled);

        // Write to file
        const out_filename = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ out_dir_name, out_name });
        defer allocator.free(out_filename);

        const out_file = cwd.createFile(io, out_filename, .{}) catch |err| {
            std.debug.print("Error: Could not create output file '{s}': {}\n", .{ out_filename, err });
            return err;
        };
        defer out_file.close(io);

        _ = try out_file.writePositional(io, &[_][]u8{bundled}, 0);

        std.debug.print("\nCreated standalone package: {s}/\n", .{out_dir_name});
        std.debug.print("  {s}.zig - Your compiled script\n", .{out_name});
        std.debug.print("  src/     - Interpreter source\n", .{});
        std.debug.print("\nTo compile:\n", .{});
        std.debug.print("  cd {s}\n", .{out_dir_name});
        std.debug.print("  zig build-exe {s}.zig -O ReleaseSmall\n", .{out_name});
        std.debug.print("\nFor a smaller binary:\n", .{});
        std.debug.print("  zig build-exe {s}.zig -O ReleaseSmall -fstrip -fsingle-threaded\n", .{out_name});
        std.debug.print("\nTo distribute: zip or copy the entire {s}/ folder\n", .{out_dir_name});
    } else {

        // Zig doesn't allow absolute path imports, so we use relative paths
        // and generate the file in the current directory (or ZPY_HOME if set)
        const output_dir: []const u8 = if (zpy_home) |home| home else "";

        // Generate bundled source (with relative paths)
        const bundled = try bundleScript(allocator, script, null);
        defer allocator.free(bundled);

        // Determine output path
        const out_filename = if (output_dir.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ output_dir, out_name })
        else
            try std.fmt.allocPrint(allocator, "{s}.zig", .{out_name});
        defer allocator.free(out_filename);

        // Write to file
        const out_file = cwd.createFile(io, out_filename, .{}) catch |err| {
            std.debug.print("Error: Could not create output file '{s}': {}\n", .{ out_filename, err });
            return err;
        };
        defer out_file.close(io);

        _ = try out_file.writePositional(io, &[_][]u8{bundled}, 0);

        std.debug.print("Created: {s}\n", .{out_filename});
        std.debug.print("\nTo compile to executable:\n", .{});
        std.debug.print("  zig build-exe {s} -O ReleaseSmall\n", .{out_filename});
        std.debug.print("\nFor a smaller binary:\n", .{});
        std.debug.print("  zig build-exe {s} -O ReleaseSmall -fstrip -fsingle-threaded\n", .{out_filename});

        if (zpy_home) |_| {
            std.debug.print("\nNote: Output written to ZPY_HOME directory.\n", .{});
            std.debug.print("      The .zig file uses relative paths to src/.\n", .{});
        } else {
            std.debug.print("\nNote: This file must be in the ZPy project directory (next to src/).\n", .{});
            std.debug.print("      For a portable package, use: zpy --standalone {s}\n", .{script_path});
        }
    }
}
