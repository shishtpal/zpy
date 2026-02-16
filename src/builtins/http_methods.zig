//! HTTP methods module - HTTP client built-in implementations.
//!
//! This module provides HTTP client built-ins:
//! - `http_get` - GET request
//! - `http_post` - POST request
//! - `http_put` - PUT request
//! - `http_delete` - DELETE request
//! - `http_request` - Generic HTTP request
//! - `http_download` - Download file to path
//! - `http_upload` - Upload file from path

const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;
const http = std.http;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    OutOfMemory,
    ValueError,
};

pub const HttpBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

/// Gets an HTTP built-in function by name.
pub fn getHttpBuiltin(name: []const u8) ?HttpBuiltinFn {
    const builtins = std.StaticStringMap(HttpBuiltinFn).initComptime(.{
        .{ "http_get", httpGet },
        .{ "http_post", httpPost },
        .{ "http_put", httpPut },
        .{ "http_delete", httpDelete },
        .{ "http_request", httpRequest },
        .{ "http_download", httpDownload },
        .{ "http_upload", httpUpload },
    });
    return builtins.get(name);
}

// ============================================================================
// HTTP Operations
// ============================================================================

/// http_get(url, headers?, timeout?) - GET request
fn httpGet(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 3) return BuiltinError.WrongArgCount;
    return doRequest(allocator, io, .GET, args);
}

/// http_post(url, body?, headers?, timeout?) - POST request
fn httpPost(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 4) return BuiltinError.WrongArgCount;
    return doRequest(allocator, io, .POST, args);
}

/// http_put(url, body?, headers?, timeout?) - PUT request
fn httpPut(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 4) return BuiltinError.WrongArgCount;
    return doRequest(allocator, io, .PUT, args);
}

/// http_delete(url, headers?, timeout?) - DELETE request
fn httpDelete(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 3) return BuiltinError.WrongArgCount;
    return doRequest(allocator, io, .DELETE, args);
}

/// http_request(method, url, body?, headers?, timeout?) - Generic HTTP request
fn httpRequest(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 2 or args.len > 5) return BuiltinError.WrongArgCount;
    if (args[0] != .string) return BuiltinError.TypeError;

    const method_str = args[0].string;
    const method = parseMethod(method_str) orelse return BuiltinError.ValueError;

    // Shift args to skip method
    return doRequest(allocator, io, method, args[1..]);
}

/// http_download(url, path, timeout?) - Download file to path
fn httpDownload(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 2 or args.len > 3) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const url = args[0].string;
    const path = args[1].string;

    // Create HTTP client
    var client = http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    // Create output buffer
    var response_buffer: std.Io.Writer.Allocating = .init(allocator);
    defer response_buffer.deinit();

    // Make request
    const result = client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &response_buffer.writer,
    }) catch return .{ .boolean = false };

    if (result.status != .ok) {
        return .{ .boolean = false };
    }

    // Write to file
    const cwd = std.Io.Dir.cwd();
    const file = cwd.createFile(io, path, .{}) catch return .{ .boolean = false };
    defer file.close(io);

    const content: []u8 = @constCast(response_buffer.written());
    _ = file.writePositional(io, &[_][]u8{content}, 0) catch return .{ .boolean = false };

    return .{ .boolean = true };
}

/// http_upload(url, path, headers?, timeout?) - Upload file from path
fn httpUpload(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 2 or args.len > 4) return BuiltinError.WrongArgCount;
    if (args[0] != .string or args[1] != .string) return BuiltinError.TypeError;

    const url = args[0].string;
    const path = args[1].string;

    // Parse optional headers
    var headers_dict: ?*Value.Dict = null;
    if (args.len > 2 and args[2] == .dict) {
        headers_dict = args[2].dict;
    }

    // Convert headers dict to http.Header slice
    var extra_headers: std.ArrayList(http.Header) = .empty;
    defer extra_headers.deinit(allocator);
    if (headers_dict) |hd| {
        for (hd.keys.items, hd.values.items) |key, val| {
            const key_str = if (key == .string) key.string else "";
            const val_str = if (val == .string) val.string else "";
            extra_headers.append(allocator, .{ .name = key_str, .value = val_str }) catch return BuiltinError.OutOfMemory;
        }
    }

    // Read file content
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch return .{ .boolean = false };
    defer file.close(io);

    const stat = file.stat(io) catch return .{ .boolean = false };
    const file_size: usize = @intCast(stat.size);

    const content = allocator.alloc(u8, file_size) catch return BuiltinError.OutOfMemory;
    defer allocator.free(content);
    _ = file.readPositional(io, &[_][]u8{content}, 0) catch return .{ .boolean = false };

    return internalPerformRequest(allocator, io, .POST, url, content, extra_headers.items);
}

// ============================================================================
// Helper Functions
// ============================================================================

fn doRequest(allocator: std.mem.Allocator, io: std.Io, method: http.Method, args: []Value) BuiltinError!Value {
    if (args[0] != .string) return BuiltinError.TypeError;

    const url = args[0].string;

    // Parse optional body and headers based on method
    var payload: ?[]const u8 = null;
    var headers_dict: ?*Value.Dict = null;
    var arg_idx: usize = 1;

    // For POST/PUT/PATCH, second arg is body
    if (method == .POST or method == .PUT or method == .PATCH) {
        if (args.len > arg_idx) {
            if (args[arg_idx] == .string) {
                payload = args[arg_idx].string;
            }
            arg_idx += 1;
        }
    }

    // Next arg is headers dict
    if (args.len > arg_idx and args[arg_idx] == .dict) {
        headers_dict = args[arg_idx].dict;
    }

    // Convert headers dict to http.Header slice
    var extra_headers: std.ArrayList(http.Header) = .empty;
    defer extra_headers.deinit(allocator);
    if (headers_dict) |hd| {
        for (hd.keys.items, hd.values.items) |key, val| {
            const key_str = if (key == .string) key.string else "";
            const val_str = if (val == .string) val.string else "";
            extra_headers.append(allocator, .{ .name = key_str, .value = val_str }) catch return BuiltinError.OutOfMemory;
        }
    }

    return internalPerformRequest(allocator, io, method, url, payload, extra_headers.items);
}

fn internalPerformRequest(
    allocator: std.mem.Allocator,
    io: std.Io,
    method: http.Method,
    url_str: []const u8,
    payload: ?[]const u8,
    extra_headers: []const http.Header,
) BuiltinError!Value {
    const uri = std.Uri.parse(url_str) catch return BuiltinError.ValueError;

    var client = http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    var req = client.request(method, uri, .{
        .extra_headers = extra_headers,
    }) catch |err| return buildErrorDict(allocator, err);
    defer req.deinit();

    if (payload) |p| {
        req.transfer_encoding = .{ .content_length = p.len };
        var body = req.sendBodyUnflushed(&.{}) catch |err| return buildErrorDict(allocator, err);
        body.writer.writeAll(p) catch |err| return buildErrorDict(allocator, err);
        body.end() catch |err| return buildErrorDict(allocator, err);
        req.connection.?.flush() catch |err| return buildErrorDict(allocator, err);
    } else {
        req.sendBodiless() catch |err| return buildErrorDict(allocator, err);
    }

    var redirect_buffer: [8192]u8 = undefined;
    var response = req.receiveHead(&redirect_buffer) catch |err| return buildErrorDict(allocator, err);

    const head_bytes = allocator.dupe(u8, response.head.bytes) catch return BuiltinError.OutOfMemory;
    defer allocator.free(head_bytes);

    var response_buffer: std.Io.Writer.Allocating = .init(allocator);
    defer response_buffer.deinit();

    var transfer_buffer: [1024]u8 = undefined;
    var decompress: http.Decompress = undefined;

    // Use a sufficient buffer for decompression window
    const decompress_buffer = allocator.alloc(u8, 256 * 1024) catch return BuiltinError.OutOfMemory;
    defer allocator.free(decompress_buffer);

    const body_reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buffer);
    _ = body_reader.streamRemaining(&response_buffer.writer) catch |err| return buildErrorDict(allocator, err);

    return buildResponseDict(allocator, response.head.status, head_bytes, response_buffer.written());
}

fn buildResponseDict(allocator: std.mem.Allocator, status: http.Status, head_bytes: []const u8, body: []const u8) BuiltinError!Value {
    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    // Add status
    const status_key = Value{ .string = allocator.dupe(u8, "status") catch return BuiltinError.OutOfMemory };
    const status_val = Value{ .integer = @intFromEnum(status) };
    dict.set(status_key, status_val) catch return BuiltinError.OutOfMemory;

    // Add headers
    const headers_dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    headers_dict.* = Value.Dict.init(allocator);

    var it = std.mem.splitSequence(u8, head_bytes, "\r\n");
    _ = it.next(); // Skip status line
    while (it.next()) |line| {
        if (line.len == 0) break;
        if (std.mem.indexOfScalar(u8, line, ':')) |colon_idx| {
            const name = std.mem.trim(u8, line[0..colon_idx], " \t");
            const value = std.mem.trim(u8, line[colon_idx + 1 ..], " \t");

            const n = allocator.dupe(u8, name) catch return BuiltinError.OutOfMemory;
            const v = allocator.dupe(u8, value) catch return BuiltinError.OutOfMemory;
            headers_dict.set(.{ .string = n }, .{ .string = v }) catch return BuiltinError.OutOfMemory;
        }
    }

    const headers_key = Value{ .string = allocator.dupe(u8, "headers") catch return BuiltinError.OutOfMemory };
    dict.set(headers_key, .{ .dict = headers_dict }) catch return BuiltinError.OutOfMemory;

    // Add body
    const body_key = Value{ .string = allocator.dupe(u8, "body") catch return BuiltinError.OutOfMemory };
    const body_val = Value{ .string = allocator.dupe(u8, body) catch return BuiltinError.OutOfMemory };
    dict.set(body_key, body_val) catch return BuiltinError.OutOfMemory;

    return .{ .dict = dict };
}

fn buildErrorDict(allocator: std.mem.Allocator, err: anyerror) BuiltinError!Value {
    const dict = allocator.create(Value.Dict) catch return BuiltinError.OutOfMemory;
    dict.* = Value.Dict.init(allocator);

    // Add status (0 for error)
    const status_key = Value{ .string = allocator.dupe(u8, "status") catch return BuiltinError.OutOfMemory };
    const status_val = Value{ .integer = 0 };
    dict.set(status_key, status_val) catch return BuiltinError.OutOfMemory;

    // Add error message
    const error_key = Value{ .string = allocator.dupe(u8, "error") catch return BuiltinError.OutOfMemory };
    const error_val = Value{ .string = allocator.dupe(u8, @errorName(err)) catch return BuiltinError.OutOfMemory };
    dict.set(error_key, error_val) catch return BuiltinError.OutOfMemory;

    return .{ .dict = dict };
}

fn parseMethod(method: []const u8) ?http.Method {
    const methods = std.StaticStringMap(http.Method).initComptime(.{
        .{ "GET", .GET },
        .{ "POST", .POST },
        .{ "PUT", .PUT },
        .{ "DELETE", .DELETE },
        .{ "PATCH", .PATCH },
        .{ "HEAD", .HEAD },
        .{ "OPTIONS", .OPTIONS },
        .{ "TRACE", .TRACE },
        .{ "CONNECT", .CONNECT },
    });
    return methods.get(method);
}
