//! Socket methods module - Python-like socket built-in implementations.
//!
//! This module provides socket built-ins similar to Python's socket module:
//!
//! Socket creation:
//! - `socket_create(domain?, type?)` - Create a new socket (default: AF_INET, SOCK_STREAM)
//!
//! Client operations:
//! - `socket_connect(sock, host, port)` - Connect to a remote server
//! - `socket_send(sock, data)` - Send data to connected socket
//! - `socket_recv(sock, bufsize?)` - Receive data from connected socket
//!
//! Server operations:
//! - `socket_bind(sock, host, port)` - Bind socket to address
//! - `socket_listen(sock, backlog?)` - Listen for connections
//! - `socket_accept(sock)` - Accept a connection, returns (client_socket, address_dict)
//!
//! Common operations:
//! - `socket_close(sock)` - Close the socket
//! - `socket_settimeout(sock, ms)` - Set timeout in milliseconds
//!
//! Utility functions:
//! - `socket_gethostname()` - Get local hostname
//! - `socket_gethostbyname(name)` - Resolve hostname to IP
//! - `socket_deinit()` - Clean up global socket state
//!
//! Constants:
//! - `socket_AF_INET` - IPv4 address family
//! - `socket_AF_INET6` - IPv6 address family
//! - `socket_SOCK_STREAM` - TCP socket type
//! - `socket_SOCK_DGRAM` - UDP socket type

const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const runtime = @import("../runtime/mod.zig");
const Value = runtime.Value;

pub const BuiltinError = error{
    WrongArgCount,
    TypeError,
    InvalidSocket,
    ConnectionFailed,
    BindFailed,
    ListenFailed,
    AcceptFailed,
    SendFailed,
    RecvFailed,
    DnsFailed,
    SocketClosed,
    Timeout,
    OutOfMemory,
    InvalidAddress,
};

pub const SocketBuiltinFn = *const fn ([]Value, std.mem.Allocator, std.Io) BuiltinError!Value;

pub fn getSocketBuiltin(name: []const u8) ?SocketBuiltinFn {
    const builtins_map = std.StaticStringMap(SocketBuiltinFn).initComptime(.{
        // Socket creation
        .{ "socket_create", socketCreate },
        // Client operations
        .{ "socket_connect", socketConnect },
        .{ "socket_send", socketSend },
        .{ "socket_recv", socketRecv },
        // Server operations
        .{ "socket_bind", socketBind },
        .{ "socket_listen", socketListen },
        .{ "socket_accept", socketAccept },
        // Common operations
        .{ "socket_close", socketClose },
        .{ "socket_settimeout", socketSettimeout },
        // Utility
        .{ "socket_gethostname", socketGethostname },
        .{ "socket_gethostbyname", socketGethostbyname },
        // Cleanup
        .{ "socket_deinit", socketDeinit },
    });
    return builtins_map.get(name);
}

// ============================================================================
// Socket Handle Table
// ============================================================================

/// Socket state stored in the global table
const SocketState = struct {
    /// The network stream (for connected sockets)
    stream: ?std.Io.net.Stream,
    /// The server (for listening sockets)
    server: ?std.Io.net.Server,
    /// Whether this is a server socket
    is_server: bool,
    /// Whether the socket is connected
    is_connected: bool,
    /// Timeout in milliseconds
    timeout_ms: ?u64,
};

var socket_next_handle: i64 = 1;
var socket_table: ?std.AutoHashMap(i64, SocketState) = null;

fn getSocketTable(allocator: std.mem.Allocator) *std.AutoHashMap(i64, SocketState) {
    if (socket_table == null) {
        socket_table = std.AutoHashMap(i64, SocketState).init(allocator);
    }
    return &socket_table.?;
}

/// Clean up global socket table state.
fn socketDeinit(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;
    _ = allocator; // Used for table but we don't need it here

    if (socket_table) |*table| {
        table.deinit();
        socket_table = null;
    }
    socket_next_handle = 1;
    return .none;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Create a result dict with ok=true and data
fn makeOkResult(allocator: std.mem.Allocator, data: struct {
    handle: ?i64 = null,
    ip: ?[]const u8 = null,
    port: ?i64 = null,
    bytes_sent: ?i64 = null,
    bytes_received: ?i64 = null,
    data: ?[]const u8 = null,
}) BuiltinError!Value {
    var dict = try allocator.create(Value.Dict);
    dict.* = Value.Dict.init(allocator);

    try dict.set(.{ .string = "ok" }, .{ .boolean = true });

    if (data.handle) |h| {
        try dict.set(.{ .string = "handle" }, .{ .integer = h });
    }
    if (data.ip) |ip| {
        try dict.set(.{ .string = "ip" }, .{ .string = ip });
    }
    if (data.port) |p| {
        try dict.set(.{ .string = "port" }, .{ .integer = p });
    }
    if (data.bytes_sent) |b| {
        try dict.set(.{ .string = "bytes_sent" }, .{ .integer = b });
    }
    if (data.bytes_received) |b| {
        try dict.set(.{ .string = "bytes_received" }, .{ .integer = b });
    }
    if (data.data) |d| {
        try dict.set(.{ .string = "data" }, .{ .string = d });
    }

    return .{ .dict = dict };
}

/// Create an error result dict
fn makeErrorResult(allocator: std.mem.Allocator, err_msg: []const u8) BuiltinError!Value {
    var dict = try allocator.create(Value.Dict);
    dict.* = Value.Dict.init(allocator);

    try dict.set(.{ .string = "ok" }, .{ .boolean = false });
    try dict.set(.{ .string = "error" }, .{ .string = err_msg });

    return .{ .dict = dict };
}

/// Get HostName for connection (handles localhost specially)
fn getHostName(host: []const u8) std.Io.net.HostName {
    // Handle common hostnames
    if (std.mem.eql(u8, host, "localhost")) {
        return .{ .bytes = "127.0.0.1" };
    }
    return .{ .bytes = host };
}

/// Parse IP address for local binding (not DNS resolution)
fn parseBindAddress(host: []const u8, port: u16) ?std.Io.net.IpAddress {
    // Handle common hostnames
    const resolved_host: []const u8 = if (std.mem.eql(u8, host, "localhost"))
        "127.0.0.1"
    else
        host;

    // Parse as IP address
    return std.Io.net.IpAddress.parse(resolved_host, port) catch null;
}

// ============================================================================
// Socket Built-in Functions
// ============================================================================

/// Create a new socket.
/// Usage: socket_create(domain?, type?)
/// Returns: socket handle (integer)
fn socketCreate(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len > 2) return BuiltinError.WrongArgCount;

    // Just return a new handle - actual socket creation happens on connect/bind
    const handle = socket_next_handle;
    socket_next_handle += 1;

    // Initialize empty state
    try getSocketTable(allocator).put(handle, .{
        .stream = null,
        .server = null,
        .is_server = false,
        .is_connected = false,
        .timeout_ms = null,
    });

    return .{ .integer = handle };
}

/// Connect to a remote server.
/// Usage: socket_connect(sock, host, port)
/// Returns: result dict with ok=true on success
fn socketConnect(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 3) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const host = switch (args[1]) {
        .string => |s| s,
        else => return BuiltinError.TypeError,
    };

    const port: u16 = switch (args[2]) {
        .integer => |i| @intCast(i),
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    // Use HostName.connect for proper DNS resolution and async connection
    const hostname = getHostName(host);
    const stream = hostname.connect(io, port, .{ .mode = .stream }) catch |err| {
        // Provide detailed error message
        const err_msg = switch (err) {
            error.ConnectionRefused => "Connection refused",
            error.ConnectionResetByPeer => "Connection reset by peer",
            error.NetworkUnreachable => "Network unreachable",
            error.HostUnreachable => "Host unreachable",
            error.Timeout => "Connection timed out",
            error.AccessDenied => "Access denied (firewall?)",
            error.AddressUnavailable => "Address unavailable",
            error.WouldBlock => "Would block",
            error.Canceled => "Connection canceled",
            error.ConnectionPending => "Connection pending",
            error.NetworkDown => "Network down",
            error.NameServerFailure => "DNS lookup failed",
            error.UnknownHostName => "Unknown hostname",
            else => "Connection failed",
        };
        return makeErrorResult(allocator, err_msg);
    };

    state.* = .{
        .stream = stream,
        .server = null,
        .is_server = false,
        .is_connected = true,
        .timeout_ms = state.timeout_ms,
    };

    return try makeOkResult(allocator, .{});
}

/// Send data to a connected socket.
/// Usage: socket_send(sock, data)
/// Returns: result dict with bytes_sent count
fn socketSend(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const data = switch (args[1]) {
        .string => |s| s,
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    const stream = state.stream orelse return makeErrorResult(allocator, "Socket not connected");

    // Write data using Stream writer
    var write_buffer: [4096]u8 = undefined;
    var writer = stream.writer(io, &write_buffer);
    writer.interface.writeAll(data) catch {
        return makeErrorResult(allocator, "Send failed");
    };
    writer.interface.flush() catch {
        return makeErrorResult(allocator, "Flush failed");
    };

    return try makeOkResult(allocator, .{ .bytes_sent = @as(i64, @intCast(data.len)) });
}

/// Receive data from a connected socket.
/// Usage: socket_recv(sock, bufsize?)
/// Returns: result dict with data and bytes_received count
fn socketRecv(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const bufsize: usize = if (args.len > 1)
        switch (args[1]) {
            .integer => |i| @intCast(i),
            else => return BuiltinError.TypeError,
        }
    else
        4096;

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    const stream = state.stream orelse return makeErrorResult(allocator, "Socket not connected");

    // Read using Stream reader with readVec
    var read_buffer: [8192]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);

    // Allocate output buffer
    var buf = try allocator.alloc(u8, bufsize);
    defer allocator.free(buf);

    // Use readVec to read into buffer
    var buf_slices: [1][]u8 = .{buf};
    const bytes_read = reader.interface.readVec(&buf_slices) catch {
        return makeErrorResult(allocator, "Receive failed");
    };

    if (bytes_read == 0) {
        return makeErrorResult(allocator, "Connection closed");
    }

    // Copy received data
    const data = try allocator.dupe(u8, buf[0..bytes_read]);

    return try makeOkResult(allocator, .{
        .data = data,
        .bytes_received = @as(i64, @intCast(bytes_read)),
    });
}

/// Bind socket to an address and listen (combined operation for simplicity).
/// Usage: socket_bind(sock, host, port)
/// Returns: result dict with ok=true on success
fn socketBind(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 3) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const host = switch (args[1]) {
        .string => |s| s,
        else => return BuiltinError.TypeError,
    };

    const port: u16 = switch (args[2]) {
        .integer => |i| @intCast(i),
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    // Parse bind address (must be IP, not hostname)
    const address = parseBindAddress(host, port) orelse {
        return makeErrorResult(allocator, "Invalid bind address (use IP like 0.0.0.0 or 127.0.0.1)");
    };

    // Listen on the address (combines bind + listen)
    const server = std.Io.net.IpAddress.listen(address, io, .{
        .reuse_address = true,
    }) catch {
        return makeErrorResult(allocator, "Bind/listen failed");
    };

    state.* = .{
        .stream = null,
        .server = server,
        .is_server = true,
        .is_connected = false,
        .timeout_ms = state.timeout_ms,
    };

    return try makeOkResult(allocator, .{});
}

/// Listen for connections (no-op since bind already listens).
/// Usage: socket_listen(sock, backlog?)
/// Returns: result dict with ok=true on success
fn socketListen(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len < 1 or args.len > 2) return BuiltinError.WrongArgCount;

    const table = getSocketTable(allocator);

    // Check if handle exists
    if (args[0] != .integer) return BuiltinError.TypeError;
    const handle = args[0].integer;
    _ = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    return try makeOkResult(allocator, .{});
}

/// Accept a connection on a listening socket.
/// Usage: socket_accept(sock)
/// Returns: list [client_handle, address_dict]
fn socketAccept(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    const server = state.server orelse return makeErrorResult(allocator, "Socket not listening");

    // Accept connection using low-level io vtable
    const client_stream = io.vtable.netAccept(io.userdata, server.socket.handle) catch {
        return makeErrorResult(allocator, "Accept failed");
    };

    // Create new handle for client
    const client_handle = socket_next_handle;
    socket_next_handle += 1;

    try table.put(client_handle, .{
        .stream = client_stream,
        .server = null,
        .is_server = false,
        .is_connected = true,
        .timeout_ms = null,
    });

    // Create address dict (we don't have remote address info from netAccept directly)
    var addr_dict = try allocator.create(Value.Dict);
    addr_dict.* = Value.Dict.init(allocator);
    try addr_dict.set(.{ .string = "ip" }, .{ .string = try allocator.dupe(u8, "unknown") });
    try addr_dict.set(.{ .string = "port" }, .{ .integer = 0 });

    // Create result list [client_handle, address_dict]
    var result_list = try allocator.create(Value.List);
    result_list.* = Value.List.init(allocator);
    try result_list.items.append(allocator, .{ .integer = client_handle });
    try result_list.items.append(allocator, .{ .dict = addr_dict });

    return .{ .list = result_list };
}

/// Close a socket.
/// Usage: socket_close(sock)
/// Returns: none
fn socketClose(args: []Value, allocator: std.mem.Allocator, io: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.get(handle) orelse return BuiltinError.InvalidSocket;

    // Close the socket using the correct handle path
    if (state.stream) |stream| {
        io.vtable.netClose(io.userdata, &.{stream.socket.handle});
    }
    if (state.server) |server| {
        io.vtable.netClose(io.userdata, &.{server.socket.handle});
    }

    _ = table.remove(handle);

    return .none;
}

/// Set socket timeout.
/// Usage: socket_settimeout(sock, ms)
/// Returns: none
fn socketSettimeout(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 2) return BuiltinError.WrongArgCount;

    const handle: i64 = switch (args[0]) {
        .integer => |i| i,
        else => return BuiltinError.TypeError,
    };

    const timeout_ms: ?u64 = switch (args[1]) {
        .integer => |i| if (i > 0) @intCast(i) else null,
        .none => null,
        else => return BuiltinError.TypeError,
    };

    const table = getSocketTable(allocator);
    const state = table.getPtr(handle) orelse return BuiltinError.InvalidSocket;

    state.timeout_ms = timeout_ms;

    return .none;
}

/// Get local hostname.
/// Usage: socket_gethostname()
/// Returns: hostname string
fn socketGethostname(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 0) return BuiltinError.WrongArgCount;

    // Platform-specific hostname retrieval
    const hostname: []const u8 = if (native_os == .windows)
        // Windows: return localhost as fallback (GetComputerNameA not available in std)
        "localhost"
    else blk: {
        // On POSIX systems, use gethostname
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        break :blk std.posix.gethostname(&buf) catch "unknown";
    };

    const result = allocator.dupe(u8, hostname) catch {
        return BuiltinError.OutOfMemory;
    };

    return .{ .string = result };
}

/// Resolve hostname to IP address.
/// Usage: socket_gethostbyname(name)
/// Returns: IP address string
fn socketGethostbyname(args: []Value, allocator: std.mem.Allocator, _: std.Io) BuiltinError!Value {
    if (args.len != 1) return BuiltinError.WrongArgCount;

    const name = switch (args[0]) {
        .string => |s| s,
        else => return BuiltinError.TypeError,
    };

    // Handle common hostnames
    if (std.mem.eql(u8, name, "localhost")) {
        const result = allocator.dupe(u8, "127.0.0.1") catch {
            return BuiltinError.OutOfMemory;
        };
        return .{ .string = result };
    }

    // Try parsing as IP address - return just the IP without port
    if (std.Io.net.IpAddress.parse(name, 0)) |addr| {
        // Format IP address without port
        var buf: [64]u8 = undefined;
        const ip_str = switch (addr) {
            .ip4 => |ip4| std.fmt.bufPrint(&buf, "{}.{}.{}.{}", .{
                ip4.bytes[0], ip4.bytes[1], ip4.bytes[2], ip4.bytes[3],
            }) catch return BuiltinError.OutOfMemory,
            .ip6 => blk: {
                var writer: std.Io.Writer = .fixed(&buf);
                addr.format(&writer) catch {};
                // IPv6 format is complex, just return as-is for now
                break :blk writer.buffered();
            },
        };
        const result = allocator.dupe(u8, ip_str) catch {
            return BuiltinError.OutOfMemory;
        };
        return .{ .string = result };
    } else |_| {
        // DNS resolution not supported in sync mode
        // User should use IP addresses directly or use http_* functions for web requests
        return makeErrorResult(allocator, "DNS not supported - use IP address directly");
    }
}
