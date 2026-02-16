# HTTP Built-ins

ZPy provides built-in functions for making HTTP requests.

## Functions

### http_get(url, headers?, timeout?)

Make a GET request.

```python
response = http_get("https://api.example.com/data")
print(response["status"])  # 200
print(response["body"])    # Response content
```

### http_post(url, body?, headers?, timeout?)

Make a POST request.

```python
body = '{"name": "Alice"}'
response = http_post("https://api.example.com/users", body)
print(response["status"])
```

### http_put(url, body?, headers?, timeout?)

Make a PUT request.

```python
body = '{"name": "Alice Updated"}'
response = http_put("https://api.example.com/users/1", body)
```

### http_delete(url, headers?, timeout?)

Make a DELETE request.

```python
response = http_delete("https://api.example.com/users/1")
if response["status"] == 200:
    print("User deleted")
```

### http_request(method, url, body?, headers?, timeout?)

Make a generic HTTP request with any method.

```python
# OPTIONS request
response = http_request("OPTIONS", "https://api.example.com/")

# PATCH request
response = http_request("PATCH", "https://api.example.com/users/1", '{"status": "active"}')
```

**Supported methods:** GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, TRACE, CONNECT

### http_download(url, path, timeout?)

Download a file to the specified path.

```python
success = http_download("https://example.com/file.zip", __dir__ + "/file.zip")
if success:
    print("Download complete")
```

### http_upload(url, path, headers?, timeout?)

Upload a file from the specified path.

```python
response = http_upload("https://api.example.com/upload", __dir__ + "/document.pdf")
print(response["status"])
```

## Response Format

All request functions return a dict with:

```python
{
    "status": 200,      # HTTP status code (0 on error)
    "body": "...",      # Response body as string
    "error": "..."      # Error name (only on failure)
}
```

## Examples

### JSON API

```python
# GET JSON data
response = http_get("https://api.example.com/users")
if response["status"] == 200:
    users = json_parse(response["body"])
    for user in users:
        print(user["name"])

# POST JSON data
user_data = json_stringify({"name": "Alice", "email": "alice@example.com"})
response = http_post("https://api.example.com/users", user_data)
```

### Error Handling

```python
response = http_get("https://api.example.com/data")
if response["status"] == 0:
    print("Request failed:", response["error"])
elif response["status"] >= 400:
    print("HTTP error:", response["status"])
else:
    data = json_parse(response["body"])
```

### Download with Progress

```python
url = "https://example.com/large-file.zip"
path = __dir__ + "/downloads/file.zip"

print("Downloading...")
if http_download(url, path):
    print("Download complete:", path)
else:
    print("Download failed")
```

## Parameters

- `url`: Full URL including scheme (http:// or https://)
- `body`: Request body as string (for POST, PUT, PATCH)
- `headers`: Dict of custom headers
- `timeout`: Timeout in seconds (default: 30, not yet implemented)

## Custom Headers

Pass a dict of headers as the headers parameter:

```python
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer token123",
    "X-Custom-Header": "value"
}

response = http_get("https://api.example.com/data", headers)
response = http_post("https://api.example.com/data", body, headers)
```

## Notes

- HTTPS is supported with TLS
- Redirects are followed automatically (up to 3)
- Response body is always returned as string
- For binary data, use `http_download`
