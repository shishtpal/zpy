const std = @import("std");
const ast = @import("../ast/mod.zig");
const Expr = ast.Expr;
const Stmt = ast.Stmt;
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const valuesEqual = runtime.valuesEqual;
const Environment = runtime.Environment;
const RuntimeError = runtime.RuntimeError;
const ControlFlow = runtime.ControlFlow;
const builtins = @import("../builtins/mod.zig");
const TokenType = @import("../token/mod.zig").TokenType;
const ops = @import("operations.zig");

pub const Interpreter = struct {
    env: *Environment,
    allocator: std.mem.Allocator,
    io: std.Io,
    control_flow: ControlFlow,
    return_value: Value,

    pub fn init(allocator: std.mem.Allocator, env: *Environment, io: std.Io) Interpreter {
        return .{
            .env = env,
            .allocator = allocator,
            .io = io,
            .control_flow = .normal,
            .return_value = .none,
        };
    }

    pub fn execute(self: *Interpreter, statements: []*Stmt) RuntimeError!void {
        for (statements) |stmt| {
            try self.executeStmt(stmt);
            if (self.control_flow != .normal) break;
        }
    }

    fn executeStmt(self: *Interpreter, stmt: *Stmt) RuntimeError!void {
        switch (stmt.*) {
            .expr_stmt => |expr| {
                _ = try self.evaluate(expr);
            },
            .assignment => |a| {
                const value = try self.evaluate(a.value);
                _ = self.env.assign(a.name, value);
            },
            .index_assign => |ia| {
                const obj = try self.evaluate(ia.object);
                const idx = try self.evaluate(ia.index);
                const value = try self.evaluate(ia.value);

                switch (obj) {
                    .list => |l| {
                        if (idx != .integer) return RuntimeError.TypeError;
                        var i = idx.integer;
                        const length: i64 = @intCast(l.items.items.len);
                        if (i < 0) i = length + i;
                        if (i < 0 or i >= length) {
                            return RuntimeError.IndexOutOfBounds;
                        }
                        l.items.items[@intCast(i)] = value;
                    },
                    .dict => |d| {
                        d.set(idx, value) catch return RuntimeError.OutOfMemory;
                    },
                    else => return RuntimeError.TypeError,
                }
            },
            .aug_assign => |aa| {
                // Get current value
                const current = self.env.get(aa.name) orelse return RuntimeError.UndefinedVariable;
                const rhs = try self.evaluate(aa.value);

                // Compute new value based on operator
                const new_value = switch (aa.op.type) {
                    .plus_eq => try ops.add(self.allocator, current, rhs),
                    .minus_eq => try ops.subtract(current, rhs),
                    .star_eq => try ops.multiply(self.allocator, current, rhs),
                    .slash_eq => try ops.divide(current, rhs),
                    .percent_eq => try ops.modulo(current, rhs),
                    else => return RuntimeError.UnsupportedOperation,
                };

                _ = self.env.assign(aa.name, new_value);
            },
            .if_stmt => |i| {
                const cond = try self.evaluate(i.condition);
                if (cond.isTruthy()) {
                    try self.executeStmt(i.then_branch);
                } else {
                    var executed = false;
                    for (i.elif_branches) |elif| {
                        const elif_cond = try self.evaluate(elif.condition);
                        if (elif_cond.isTruthy()) {
                            try self.executeStmt(elif.body);
                            executed = true;
                            break;
                        }
                    }
                    if (!executed) {
                        if (i.else_branch) |else_b| {
                            try self.executeStmt(else_b);
                        }
                    }
                }
            },
            .while_stmt => |w| {
                while (true) {
                    const cond = try self.evaluate(w.condition);
                    if (!cond.isTruthy()) break;

                    try self.executeStmt(w.body);

                    if (self.control_flow == .break_loop) {
                        self.control_flow = .normal;
                        break;
                    }
                    if (self.control_flow == .continue_loop) {
                        self.control_flow = .normal;
                    }
                }
            },
            .for_stmt => |f| {
                const iterable = try self.evaluate(f.iterable);

                switch (iterable) {
                    .list => |l| {
                        for (l.items.items) |item| {
                            _ = self.env.assign(f.variable, item);
                            try self.executeStmt(f.body);

                            if (self.control_flow == .break_loop) {
                                self.control_flow = .normal;
                                break;
                            }
                            if (self.control_flow == .continue_loop) {
                                self.control_flow = .normal;
                            }
                        }
                    },
                    .string => |s| {
                        for (s) |c| {
                            const char_str = self.allocator.alloc(u8, 1) catch return RuntimeError.OutOfMemory;
                            char_str[0] = c;
                            _ = self.env.assign(f.variable, .{ .string = char_str });
                            try self.executeStmt(f.body);

                            if (self.control_flow == .break_loop) {
                                self.control_flow = .normal;
                                break;
                            }
                            if (self.control_flow == .continue_loop) {
                                self.control_flow = .normal;
                            }
                        }
                    },
                    .dict => |d| {
                        // Iterate over keys
                        for (d.keys.items) |key| {
                            _ = self.env.assign(f.variable, key);
                            try self.executeStmt(f.body);

                            if (self.control_flow == .break_loop) {
                                self.control_flow = .normal;
                                break;
                            }
                            if (self.control_flow == .continue_loop) {
                                self.control_flow = .normal;
                            }
                        }
                    },
                    else => return RuntimeError.TypeError,
                }
            },
            .break_stmt => {
                self.control_flow = .break_loop;
            },
            .continue_stmt => {
                self.control_flow = .continue_loop;
            },
            .block => |b| {
                for (b.statements) |s| {
                    try self.executeStmt(s);
                    if (self.control_flow != .normal) break;
                }
            },
            .func_def => |fd| {
                // Create function value and store in environment
                const func = self.allocator.create(Value.Function) catch return RuntimeError.OutOfMemory;
                func.* = .{
                    .name = fd.name,
                    .params = fd.params,
                    .body = fd.body,
                };
                _ = self.env.assign(fd.name, .{ .function = func });
            },
            .del_stmt => |ds| {
                const obj = try self.evaluate(ds.object);
                const idx = try self.evaluate(ds.index);

                switch (obj) {
                    .list => |l| {
                        if (idx != .integer) return RuntimeError.TypeError;
                        var i = idx.integer;
                        const length: i64 = @intCast(l.items.items.len);
                        if (i < 0) i = length + i;
                        if (i < 0 or i >= length) return RuntimeError.IndexOutOfBounds;
                        const uidx: usize = @intCast(i);
                        var j = uidx;
                        while (j + 1 < l.items.items.len) : (j += 1) {
                            l.items.items[j] = l.items.items[j + 1];
                        }
                        l.items.items.len -= 1;
                    },
                    .dict => |d| {
                        for (d.keys.items, 0..) |key, i| {
                            if (valuesEqual(key, idx)) {
                                var j = i;
                                while (j + 1 < d.keys.items.len) : (j += 1) {
                                    d.keys.items[j] = d.keys.items[j + 1];
                                    d.values.items[j] = d.values.items[j + 1];
                                }
                                d.keys.items.len -= 1;
                                d.values.items.len -= 1;
                                return;
                            }
                        }
                        return RuntimeError.KeyNotFound;
                    },
                    else => return RuntimeError.TypeError,
                }
            },
            .pass_stmt => {},
            .return_stmt => |rs| {
                if (rs.value) |expr| {
                    self.return_value = try self.evaluate(expr);
                } else {
                    self.return_value = .none;
                }
                self.control_flow = .return_value;
            },
        }
    }

    pub fn evaluate(self: *Interpreter, expr: *Expr) RuntimeError!Value {
        return switch (expr.*) {
            .integer => |i| .{ .integer = i },
            .float => |f| .{ .float = f },
            .string => |s| .{ .string = s },
            .boolean => |b| .{ .boolean = b },
            .none => .none,
            .identifier => |name| self.env.get(name) orelse RuntimeError.UndefinedVariable,
            .binary => |bin| try self.evalBinary(bin),
            .unary => |un| try self.evalUnary(un),
            .call => |c| try self.evalCall(c),
            .index => |idx| try self.evalIndex(idx),
            .list => |l| try self.evalList(l),
            .dict => |d| try self.evalDict(d),
            .method_call => |mc| try self.evalMethodCall(mc),
            .membership => |m| try self.evalMembership(m),
        };
    }

    fn evalBinary(self: *Interpreter, bin: Expr.Binary) RuntimeError!Value {
        const left = try self.evaluate(bin.left);
        const right = try self.evaluate(bin.right);

        return switch (bin.op.type) {
            .plus => ops.add(self.allocator, left, right),
            .minus => ops.subtract(left, right),
            .star => ops.multiply(self.allocator, left, right),
            .star_star => ops.power(left, right),
            .slash => ops.divide(left, right),
            .percent => ops.modulo(left, right),
            .eq_eq => .{ .boolean = valuesEqual(left, right) },
            .not_eq => .{ .boolean = !valuesEqual(left, right) },
            .lt => ops.compare(left, right, .lt),
            .gt => ops.compare(left, right, .gt),
            .lt_eq => ops.compare(left, right, .lt_eq),
            .gt_eq => ops.compare(left, right, .gt_eq),
            .kw_and => .{ .boolean = left.isTruthy() and right.isTruthy() },
            .kw_or => .{ .boolean = left.isTruthy() or right.isTruthy() },
            else => RuntimeError.UnsupportedOperation,
        };
    }

    fn evalUnary(self: *Interpreter, un: Expr.Unary) RuntimeError!Value {
        const operand = try self.evaluate(un.operand);

        return switch (un.op.type) {
            .minus => blk: {
                if (operand == .integer) break :blk .{ .integer = -operand.integer };
                if (operand == .float) break :blk .{ .float = -operand.float };
                break :blk RuntimeError.TypeError;
            },
            .kw_not => .{ .boolean = !operand.isTruthy() },
            else => RuntimeError.UnsupportedOperation,
        };
    }

    fn evalCall(self: *Interpreter, call: Expr.Call) RuntimeError!Value {
        // Check built-ins first
        if (builtins.getBuiltin(call.callee)) |builtin_fn| {
            var args = self.allocator.alloc(Value, call.args.len) catch return RuntimeError.OutOfMemory;
            defer self.allocator.free(args);

            for (call.args, 0..) |arg, i| {
                args[i] = try self.evaluate(arg);
            }

            return builtin_fn(args, self.allocator, self.io) catch RuntimeError.BuiltinError;
        }

        // Check user-defined functions
        const func_val = self.env.get(call.callee) orelse return RuntimeError.UndefinedVariable;
        if (func_val != .function) return RuntimeError.TypeError;

        const func = func_val.function;

        // Evaluate arguments
        var args = self.allocator.alloc(Value, call.args.len) catch return RuntimeError.OutOfMemory;
        defer self.allocator.free(args);

        for (call.args, 0..) |arg, i| {
            args[i] = try self.evaluate(arg);
        }

        // Create new environment for function scope
        var func_env = Environment.initWithParent(self.allocator, self.env);
        defer func_env.deinit();

        // Bind parameters to arguments
        for (func.params, 0..) |param, i| {
            const arg_val = if (i < args.len) args[i] else Value{ .none = {} };
            func_env.define(param, arg_val) catch return RuntimeError.OutOfMemory;
        }

        // Save current state and execute function
        const saved_env = self.env;
        const saved_control_flow = self.control_flow;
        self.env = &func_env;
        self.control_flow = .normal;

        self.executeStmt(func.body) catch |err| {
            self.env = saved_env;
            self.control_flow = saved_control_flow;
            return err;
        };

        // Get return value
        const result = if (self.control_flow == .return_value) self.return_value else Value{ .none = {} };

        // Restore state
        self.env = saved_env;
        self.control_flow = saved_control_flow;
        self.return_value = .none;

        return result;
    }

    fn evalIndex(self: *Interpreter, idx: Expr.Index) RuntimeError!Value {
        const obj = try self.evaluate(idx.object);
        const index = try self.evaluate(idx.index);

        switch (obj) {
            .list => |l| {
                if (index != .integer) return RuntimeError.TypeError;
                var i = index.integer;
                const length: i64 = @intCast(l.items.items.len);
                if (i < 0) i = length + i;
                if (i < 0 or i >= length) {
                    return RuntimeError.IndexOutOfBounds;
                }
                return l.items.items[@intCast(i)];
            },
            .string => |s| {
                if (index != .integer) return RuntimeError.TypeError;
                var i = index.integer;
                const length: i64 = @intCast(s.len);
                if (i < 0) i = length + i;
                if (i < 0 or i >= length) {
                    return RuntimeError.IndexOutOfBounds;
                }
                const char_str = self.allocator.alloc(u8, 1) catch return RuntimeError.OutOfMemory;
                char_str[0] = s[@intCast(i)];
                return .{ .string = char_str };
            },
            .dict => |d| {
                return d.get(index) orelse RuntimeError.KeyNotFound;
            },
            else => return RuntimeError.TypeError,
        }
    }

    fn evalList(self: *Interpreter, list: Expr.List) RuntimeError!Value {
        const result = self.allocator.create(Value.List) catch return RuntimeError.OutOfMemory;
        result.* = Value.List.init(self.allocator);

        for (list.elements) |elem| {
            const val = try self.evaluate(elem);
            result.items.append(result.allocator, val) catch return RuntimeError.OutOfMemory;
        }

        return .{ .list = result };
    }

    fn evalDict(self: *Interpreter, dict: Expr.Dict) RuntimeError!Value {
        const result = self.allocator.create(Value.Dict) catch return RuntimeError.OutOfMemory;
        result.* = Value.Dict.init(self.allocator);

        for (dict.keys, 0..) |key_expr, i| {
            const key = try self.evaluate(key_expr);
            const val = try self.evaluate(dict.values[i]);
            result.set(key, val) catch return RuntimeError.OutOfMemory;
        }

        return .{ .dict = result };
    }

    fn evalMembership(self: *Interpreter, m: Expr.Membership) RuntimeError!Value {
        const val = try self.evaluate(m.value);
        const collection = try self.evaluate(m.collection);

        const found = switch (collection) {
            .list => |l| blk: {
                for (l.items.items) |item| {
                    if (valuesEqual(val, item)) break :blk true;
                }
                break :blk false;
            },
            .string => |s| blk: {
                if (val != .string) return RuntimeError.TypeError;
                if (val.string.len == 0) break :blk true;
                if (std.mem.indexOf(u8, s, val.string)) |_| break :blk true;
                break :blk false;
            },
            .dict => |d| blk: {
                for (d.keys.items) |key| {
                    if (valuesEqual(val, key)) break :blk true;
                }
                break :blk false;
            },
            else => return RuntimeError.TypeError,
        };

        return .{ .boolean = if (m.negated) !found else found };
    }

    fn evalMethodCall(self: *Interpreter, mc: Expr.MethodCall) RuntimeError!Value {
        const obj = try self.evaluate(mc.object);

        var args = self.allocator.alloc(Value, mc.args.len) catch return RuntimeError.OutOfMemory;
        defer self.allocator.free(args);
        for (mc.args, 0..) |arg, i| {
            args[i] = try self.evaluate(arg);
        }

        return switch (obj) {
            .string => |s| builtins.callStringMethod(self.allocator, s, mc.method, args),
            .list => |l| builtins.callListMethod(self.allocator, l, mc.method, args),
            .dict => |d| builtins.callDictMethod(self.allocator, d, mc.method, args),
            else => RuntimeError.UnsupportedOperation,
        };
    }
};
