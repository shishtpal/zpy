# JSON Built-ins

ZPy provides built-in functions for JSON parsing and serialization.

## Functions

### json_parse(string)

Parse a JSON string into a ZPy value.

```python
data = json_parse('{"name": "Alice", "age": 30}')
print(data["name"])  # Alice
print(data["age"])   # 30
```

**Type Mapping:**

| JSON | ZPy |
|------|-----|
| `null` | `none` |
| `true/false` | `bool` |
| `number (int)` | `integer` |
| `number (float)` | `float` |
| `string` | `string` |
| `array` | `list` |
| `object` | `dict` |

### json_stringify(value, indent?)

Convert a ZPy value to a JSON string.

```python
obj = {"name": "Bob", "active": true}
json_text = json_stringify(obj)
print(json_text)  # {"name":"Bob","active":true}

# Pretty print with 2-space indent
pretty = json_stringify(obj, 2)
print(pretty)  # {"name": "Bob", "active": true}
```

**Parameters:**
- `value`: Any ZPy value to serialize
- `indent`: Optional number of spaces for indentation (default: minified)

## Examples

### Parse API Response

```python
response_text = '{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}'
data = json_parse(response_text)

for user in data["users"]:
    print(user["id"], user["name"])
```

### Build and Serialize Config

```python
config = {
    "debug": true,
    "port": 8080,
    "allowed_hosts": ["localhost", "127.0.0.1"]
}

# Save to file
file_write("config.json", json_stringify(config, 2))
```

### Round-Trip

```python
original = {"items": [1, 2, 3], "nested": {"a": 1}}
json_text = json_stringify(original)
parsed = json_parse(json_text)
# parsed is equivalent to original
```

## Error Handling

`json_parse` returns `none` on invalid JSON:

```python
result = json_parse("invalid json")
if result == none:
    print("Failed to parse JSON")
```
