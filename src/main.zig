//! ZPy - A Python-like language interpreter written in Zig.
//!
//! This is the main entry point that orchestrates the interpreter components.

const std = @import("std");
const cli = @import("cli.zig");
const repl = @import("repl.zig");
const utils = @import("utils/mod.zig");
const compiler = @import("compiler.zig");
const Lexer = @import("lexer/mod.zig").Lexer;
const Parser = @import("parser/mod.zig").Parser;
const Interpreter = @import("interpreter/mod.zig").Interpreter;
const runtime = @import("runtime/mod.zig");
const Environment = runtime.Environment;
const ast = @import("ast/mod.zig");

// Re-export version for other modules
pub const VERSION = cli.VERSION;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.skip(); // Skip program name

    // Parse command-line arguments
    const parse_result = cli.parseArgs(allocator, &args_iter) catch |err| {
        if (err == error.UnknownOption or err == error.MissingArgument) {
            return;
        }
        return err;
    };
    const options = parse_result.options;
    defer if (parse_result.owned_code) |c| allocator.free(c);

    // Handle help and version
    if (options.show_help) {
        cli.printHelp();
        return;
    }

    if (options.show_version) {
        std.debug.print("ZPy {s}\n", .{VERSION});
        return;
    }

    // Handle --compile option
    if (options.compile_script) {
        if (options.file_path) |path| {
            try compiler.compileToFile(allocator, io, init.environ_map, path, options.output_name, options.standalone);
            return;
        } else {
            std.debug.print("Error: --compile requires a script file\n\n", .{});
            cli.printUsage();
            return;
        }
    }

    // Execute code string if provided
    if (options.execute_code) |code| {
        if (options.dump_tokens) {
            try dumpTokens(allocator, code);
            return;
        }
        if (options.dump_ast) {
            try dumpAst(allocator, code);
            return;
        }
        try runCode(allocator, code, io);
        return;
    }

    // Run file if provided
    if (options.file_path) |path| {
        const source = try utils.readFile(io, allocator, path) orelse return;
        defer allocator.free(source);

        if (options.dump_tokens) {
            try dumpTokens(allocator, source);
            return;
        }
        if (options.dump_ast) {
            try dumpAst(allocator, source);
            return;
        }

        // Get absolute path and directory for __file__ and __dir__
        // For now, just use the provided path and get its directory
        const script_dir = std.fs.path.dirname(path) orelse ".";
        const abs_path = path; // Use the provided path as-is for now

        try runCodeWithFile(allocator, source, io, abs_path, script_dir);
        if (options.run_repl) {
            std.debug.print("\n--- Entering REPL ---\n", .{});
            try repl.runRepl(allocator, io, VERSION);
        }
        return;
    }

    // Default: start REPL
    try repl.runRepl(allocator, io, VERSION);
}

// ============================================================================
// Code Execution
// ============================================================================

fn runCode(allocator: std.mem.Allocator, source: []const u8, io: std.Io) !void {
    return runCodeWithFile(allocator, source, io, "", "");
}

fn runCodeWithFile(allocator: std.mem.Allocator, source: []const u8, io: std.Io, file_path: []const u8, script_dir: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env = Environment.init(alloc);
    defer env.deinit();

    // Set __file__ and __dir__ variables if running from a file
    if (file_path.len > 0) {
        const file_path_copy = arena.allocator().dupe(u8, file_path) catch return;
        _ = env.assign("__file__", .{ .string = file_path_copy });
    }
    if (script_dir.len > 0) {
        const script_dir_copy = arena.allocator().dupe(u8, script_dir) catch return;
        _ = env.assign("__dir__", .{ .string = script_dir_copy });
    }

    var lexer = Lexer.init(alloc, source);
    defer lexer.deinit();

    var tokens = lexer.tokenize(alloc) catch |err| {
        std.debug.print("\x1b[31mLexer error:\x1b[0m {}\n", .{err});
        return;
    };
    defer tokens.deinit(alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    const statements = parser.parse() catch |err| {
        std.debug.print("\x1b[31mParse error:\x1b[0m {s}\n", .{runtime.parseErrorMessage(err)});
        return;
    };

    var interpreter = Interpreter.init(alloc, &env, io);
    interpreter.execute(statements) catch |err| {
        std.debug.print("\x1b[31mRuntime error:\x1b[0m {s}\n", .{runtime.runtimeErrorMessage(err)});
    };
}

// ============================================================================
// Debug Utilities
// ============================================================================

fn dumpTokens(allocator: std.mem.Allocator, source: []const u8) !void {
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    std.debug.print("=== Tokens ===\n", .{});
    while (true) {
        const tok = lexer.nextToken();
        std.debug.print("{}\n", .{tok});
        if (tok.type == .eof) break;
    }
}

fn dumpAst(allocator: std.mem.Allocator, source: []const u8) !void {
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    var tokens = try lexer.tokenize(allocator);
    defer tokens.deinit(allocator);

    var parser = Parser.init(allocator, tokens.items);
    defer parser.deinit();

    const statements = parser.parse() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };

    std.debug.print("=== AST ===\n", .{});
    for (statements, 0..) |stmt, i| {
        std.debug.print("[{d}] ", .{i});
        printStmt(stmt, 0);
    }
}

fn printStmt(stmt: *ast.Stmt, indent: usize) void {
    printIndent(indent);
    switch (stmt.*) {
        .expr_stmt => |e| {
            std.debug.print("ExprStmt: ", .{});
            printExpr(e);
            std.debug.print("\n", .{});
        },
        .assignment => |a| {
            std.debug.print("Assign: {s} = ", .{a.name});
            printExpr(a.value);
            std.debug.print("\n", .{});
        },
        .index_assign => |ia| {
            std.debug.print("IndexAssign: ", .{});
            printExpr(ia.object);
            std.debug.print("[", .{});
            printExpr(ia.index);
            std.debug.print("] = ", .{});
            printExpr(ia.value);
            std.debug.print("\n", .{});
        },
        .aug_assign => |aa| {
            std.debug.print("AugAssign: {s} {s} ", .{ aa.name, aa.op.lexeme });
            printExpr(aa.value);
            std.debug.print("\n", .{});
        },
        .if_stmt => |i| {
            std.debug.print("If: ", .{});
            printExpr(i.condition);
            std.debug.print("\n", .{});
            printStmt(i.then_branch, indent + 2);
            for (i.elif_branches) |elif| {
                printIndent(indent);
                std.debug.print("Elif: ", .{});
                printExpr(elif.condition);
                std.debug.print("\n", .{});
                printStmt(elif.body, indent + 2);
            }
            if (i.else_branch) |else_b| {
                printIndent(indent);
                std.debug.print("Else:\n", .{});
                printStmt(else_b, indent + 2);
            }
        },
        .while_stmt => |w| {
            std.debug.print("While: ", .{});
            printExpr(w.condition);
            std.debug.print("\n", .{});
            printStmt(w.body, indent + 2);
        },
        .for_stmt => |f| {
            std.debug.print("For: {s} in ", .{f.variable});
            printExpr(f.iterable);
            std.debug.print("\n", .{});
            printStmt(f.body, indent + 2);
        },
        .break_stmt => std.debug.print("Break\n", .{}),
        .continue_stmt => std.debug.print("Continue\n", .{}),
        .block => |b| {
            std.debug.print("Block:\n", .{});
            for (b.statements) |s| {
                printStmt(s, indent + 2);
            }
        },
        .func_def => |fd| {
            std.debug.print("FuncDef: {s}(", .{fd.name});
            for (fd.params, 0..) |p, pi| {
                if (pi > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{p});
            }
            std.debug.print(")\n", .{});
            printStmt(fd.body, indent + 2);
        },
        .return_stmt => |rs| {
            std.debug.print("Return: ", .{});
            if (rs.value) |v| {
                printExpr(v);
            } else {
                std.debug.print("none", .{});
            }
            std.debug.print("\n", .{});
        },
        .del_stmt => |ds| {
            std.debug.print("Del: ", .{});
            printExpr(ds.object);
            std.debug.print("[", .{});
            printExpr(ds.index);
            std.debug.print("]\n", .{});
        },
        .pass_stmt => {
            std.debug.print("Pass\n", .{});
        },
    }
}

fn printExpr(expr: *ast.Expr) void {
    switch (expr.*) {
        .integer => |i| std.debug.print("{d}", .{i}),
        .float => |f| std.debug.print("{d}", .{f}),
        .string => |s| std.debug.print("\"{s}\"", .{s}),
        .boolean => |b| std.debug.print("{s}", .{if (b) "true" else "false"}),
        .none => std.debug.print("none", .{}),
        .identifier => |name| std.debug.print("{s}", .{name}),
        .binary => |bin| {
            std.debug.print("(", .{});
            printExpr(bin.left);
            std.debug.print(" {s} ", .{bin.op.lexeme});
            printExpr(bin.right);
            std.debug.print(")", .{});
        },
        .unary => |un| {
            std.debug.print("({s} ", .{un.op.lexeme});
            printExpr(un.operand);
            std.debug.print(")", .{});
        },
        .call => |c| {
            std.debug.print("{s}(", .{c.callee});
            for (c.args, 0..) |arg, i| {
                if (i > 0) std.debug.print(", ", .{});
                printExpr(arg);
            }
            std.debug.print(")", .{});
        },
        .index => |idx| {
            printExpr(idx.object);
            std.debug.print("[", .{});
            printExpr(idx.index);
            std.debug.print("]", .{});
        },
        .list => |l| {
            std.debug.print("[", .{});
            for (l.elements, 0..) |elem, i| {
                if (i > 0) std.debug.print(", ", .{});
                printExpr(elem);
            }
            std.debug.print("]", .{});
        },
        .dict => |d| {
            std.debug.print("{{", .{});
            for (d.keys, 0..) |key, i| {
                if (i > 0) std.debug.print(", ", .{});
                printExpr(key);
                std.debug.print(": ", .{});
                printExpr(d.values[i]);
            }
            std.debug.print("}}", .{});
        },
        .method_call => |mc| {
            printExpr(mc.object);
            std.debug.print(".{s}(", .{mc.method});
            for (mc.args, 0..) |arg, i| {
                if (i > 0) std.debug.print(", ", .{});
                printExpr(arg);
            }
            std.debug.print(")", .{});
        },
        .membership => |m| {
            printExpr(m.value);
            if (m.negated) {
                std.debug.print(" not in ", .{});
            } else {
                std.debug.print(" in ", .{});
            }
            printExpr(m.collection);
        },
    }
}

fn printIndent(indent: usize) void {
    for (0..indent) |_| {
        std.debug.print(" ", .{});
    }
}
