# Socket Module

ZPy provides a socket module for network programming, similar to Python's `socket` module. It supports TCP client/server communication with a simple handle-based API.

## Socket Creation

### socket_create(domain?, type?)

Creates a new socket and returns an integer handle. The domain and type parameters are optional (defaults to IPv4 TCP).

```python
# Create a TCP socket
sock = socket_create()
print("Socket handle:", sock)  # 1

# Domain and type are optional placeholders for future expansion
sock = socket_create()
```

## Client Operations

### socket_connect(sock, host, port)

Connects to a remote server. Supports both IP addresses and hostnames (DNS resolution).

Returns a dictionary with:
- `ok`: `true` on success, `false` on failure
- `error`: error message (only if `ok` is `false`)

```python
sock = socket_create()
result = socket_connect(sock, "example.com", 80)
if result["ok"]:
    print("Connected!")
else:
    print("Failed:", result["error"])

# Connect using IP address
sock = socket_create()
result = socket_connect(sock, "93.184.216.34", 80)
```

### socket_send(sock, data)

Sends data to a connected socket.

Returns a dictionary with:
- `ok`: `true` on success
- `bytes_sent`: number of bytes sent
- `error`: error message (only if `ok` is `false`)

```python
sock = socket_create()
socket_connect(sock, "example.com", 80)

# Send HTTP request
request = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
result = socket_send(sock, request)
print("Sent", result["bytes_sent"], "bytes")
```

### socket_recv(sock, bufsize?)

Receives data from a connected socket. Default buffer size is 4096 bytes.

Returns a dictionary with:
- `ok`: `true` on success
- `data`: the received data as a string
- `bytes_received`: number of bytes received
- `error`: error message (only if `ok` is `false`)

```python
sock = socket_create()
socket_connect(sock, "example.com", 80)
socket_send(sock, "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")

# Receive response
result = socket_recv(sock, 8192)
if result["ok"]:
    print("Received", result["bytes_received"], "bytes")
    print(result["data"])
else:
    print("Error:", result["error"])
```

## Server Operations

### socket_bind(sock, host, port)

Binds a socket to an address and starts listening for connections. This combines `bind()` and `listen()` for simplicity.

Use `"0.0.0.0"` to listen on all interfaces, or `"127.0.0.1"` for localhost only.

Returns a dictionary with:
- `ok`: `true` on success
- `error`: error message (only if `ok` is `false`)

```python
server = socket_create()
result = socket_bind(server, "0.0.0.0", 8080)
if result["ok"]:
    print("Server listening on port 8080")
else:
    print("Bind failed:", result["error"])
```

### socket_listen(sock, backlog?)

Marks the socket as listening for connections. This is a no-op since `socket_bind` already starts listening, but is provided for API compatibility.

```python
server = socket_create()
socket_bind(server, "0.0.0.0", 8080)
socket_listen(server, 5)  # Optional, backlog is ignored
```

### socket_accept(sock)

Accepts an incoming connection on a listening socket. Blocks until a client connects.

Returns a list with two elements:
- `[0]`: client socket handle (integer)
- `[1]`: address dictionary with `ip` and `port` keys

```python
server = socket_create()
socket_bind(server, "0.0.0.0", 8080)

print("Waiting for connection...")
result = socket_accept(server)
client_sock = result[0]
client_addr = result[1]
print("Client connected from", client_addr["ip"])

# Communicate with client
socket_send(client_sock, "Hello, client!")
socket_close(client_sock)
```

## Common Operations

### socket_close(sock)

Closes a socket and releases its resources.

```python
sock = socket_create()
socket_connect(sock, "example.com", 80)
# ... do communication ...
socket_close(sock)
```

### socket_settimeout(sock, ms)

Sets the timeout for socket operations in milliseconds. Pass `none` or `0` to disable timeout.

**Note:** Timeout functionality is stored but may not be fully enforced in the current implementation.

```python
sock = socket_create()
socket_settimeout(sock, 5000)  # 5 second timeout
socket_connect(sock, "example.com", 80)

# Disable timeout
socket_settimeout(sock, none)
```

## Utility Functions

### socket_gethostname()

Returns the local hostname. On Windows, returns `"localhost"` as a fallback.

```python
hostname = socket_gethostname()
print("Hostname:", hostname)
```

### socket_gethostbyname(name)

Resolves a hostname to an IP address using DNS.

Returns the IP address as a string, or a dictionary with `ok: false` and an error message on failure.

```python
# Resolve hostname
ip = socket_gethostbyname("example.com")
print("IP:", ip)

# If already an IP, returns it unchanged
ip = socket_gethostbyname("127.0.0.1")
print("IP:", ip)  # "127.0.0.1"
```

## Cleanup

### socket_deinit()

Cleans up global socket table state. Optional - the OS will clean up on process exit.

```python
# After you're done with all socket operations
socket_deinit()
```

## Example: Simple HTTP Client

```python
# Fetch a webpage using raw sockets
def http_get(host, path):
    sock = socket_create()
    
    result = socket_connect(sock, host, 80)
    if not result["ok"]:
        print("Connection failed:", result["error"])
        return none
    
    # Send HTTP request
    request = "GET " + path + " HTTP/1.1\r\n"
    request = request + "Host: " + host + "\r\n"
    request = request + "Connection: close\r\n\r\n"
    socket_send(sock, request)
    
    # Receive response
    response = ""
    while true:
        result = socket_recv(sock, 4096)
        if not result["ok"]:
            break
        response = response + result["data"]
    
    socket_close(sock)
    return response

# Usage
html = http_get("example.com", "/")
print(html)
```

## Example: Echo Server

```python
# Simple echo server
def echo_server(port):
    server = socket_create()
    result = socket_bind(server, "0.0.0.0", port)
    
    if not result["ok"]:
        print("Failed to bind:", result["error"])
        return
    
    print("Echo server listening on port", port)
    
    while true:
        # Accept client
        conn = socket_accept(server)
        client = conn[0]
        addr = conn[1]
        print("Client connected from", addr["ip"])
        
        # Echo loop
        while true:
            result = socket_recv(client, 1024)
            if not result["ok"]:
                break
            
            data = result["data"]
            print("Received:", data)
            socket_send(client, data)
        
        socket_close(client)
        print("Client disconnected")

echo_server(9000)
```

## Example: Chat Client

```python
# Simple chat client
def chat_client(server_host, server_port):
    sock = socket_create()
    
    result = socket_connect(sock, server_host, server_port)
    if not result["ok"]:
        print("Could not connect:", result["error"])
        return
    
    print("Connected to chat server!")
    
    # Send a message
    socket_send(sock, "Hello from ZPy!\n")
    
    # Receive response
    result = socket_recv(sock)
    if result["ok"]:
        print("Server says:", result["data"])
    
    socket_close(sock)

chat_client("localhost", 9000)
```

## Summary Table

| Function | Description | Returns |
|----------|-------------|---------|
| `socket_create()` | Create a new socket | int |
| `socket_connect(sock, host, port)` | Connect to server | dict |
| `socket_send(sock, data)` | Send data | dict |
| `socket_recv(sock, bufsize?)` | Receive data | dict |
| `socket_bind(sock, host, port)` | Bind and listen | dict |
| `socket_listen(sock, backlog?)` | Mark as listening | dict |
| `socket_accept(sock)` | Accept connection | list |
| `socket_close(sock)` | Close socket | none |
| `socket_settimeout(sock, ms)` | Set timeout | none |
| `socket_gethostname()` | Get local hostname | string |
| `socket_gethostbyname(name)` | DNS lookup | string or dict |
| `socket_deinit()` | Clean up global state | none |

## Comparison with Python

| Python | ZPy | Notes |
|--------|-----|-------|
| `socket.socket()` | `socket_create()` | Returns handle instead of object |
| `sock.connect((host, port))` | `socket_connect(sock, host, port)` | Tuple vs separate args |
| `sock.send(data)` | `socket_send(sock, data)` | Returns dict with status |
| `sock.recv(bufsize)` | `socket_recv(sock, bufsize?)` | Returns dict with data |
| `sock.bind((host, port))` | `socket_bind(sock, host, port)` | Also starts listening |
| `sock.listen(backlog)` | `socket_listen(sock, backlog?)` | No-op (bind listens) |
| `sock.accept()` | `socket_accept(sock)` | Returns list instead of tuple |
| `sock.close()` | `socket_close(sock)` | Same behavior |
| `sock.settimeout(sec)` | `socket_settimeout(sock, ms)` | Milliseconds vs seconds |
| `socket.gethostname()` | `socket_gethostname()` | Same behavior |
| `socket.gethostbyname(name)` | `socket_gethostbyname(name)` | Same behavior |
