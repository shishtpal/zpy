# YAML Built-ins

ZPy provides built-in functions for YAML parsing and serialization.

## Functions

### yaml_parse(string)

Parse a YAML string into a ZPy value.

```python
yaml_text = "name: Alice\nage: 30\nactive: true"
data = yaml_parse(yaml_text)
print(data["name"])  # Alice
```

**Supported YAML features:**
- Scalars: strings, numbers, booleans, null
- Sequences (lists) using `- ` prefix
- Mappings (dicts) using `key: value`
- Nested structures via indentation
- Comments (`#`)
- Multi-document support (`---`)
- Anchors and aliases (`&anchor`, `*alias`)

### yaml_parse_all(string)

Parse multi-document YAML into a list.

```python
yaml_multi = """---
name: Doc1
---
name: Doc2
"""
docs = yaml_parse_all(yaml_multi)
print(len(docs))  # 2
print(docs[0]["name"])  # Doc1
```

### yaml_stringify(value)

Convert a ZPy value to YAML string.

```python
obj = {"name": "Bob", "age": 25}
yaml_text = yaml_stringify(obj)
# Result:
# name: Bob
# age: 25
```

## Examples

### Nested Structures

```python
yaml_text = """
user:
  name: Alice
  skills:
    - Python
    - Zig
    - Go
"""
data = yaml_parse(yaml_text)
print(data["user"]["name"])  # Alice
print(data["user"]["skills"])  # ["Python", "Zig", "Go"]
```

### Configuration Files

```python
config_yaml = file_read(__dir__ + "/config.yml")
config = yaml_parse(config_yaml)

print("Debug mode:", config["debug"])
print("Port:", config["server"]["port"])
```

### Anchors and Aliases

```python
yaml_text = """
defaults: &defaults
  timeout: 30
  retries: 3

production:
  <<: *defaults
  debug: false

development:
  <<: *defaults
  debug: true
"""
config = yaml_parse(yaml_text)
```

### Lists

```python
yaml_list = """
- item1
- item2
- item3
"""
items = yaml_parse(yaml_list)
for item in items:
    print(item)
```

### Write YAML File

```python
config = {
    "app": {
        "name": "MyApp",
        "version": "1.0.0"
    },
    "features": ["auth", "api", "admin"]
}

yaml_text = yaml_stringify(config)
file_write("config.yml", yaml_text)
```

## Type Mapping

| YAML | ZPy |
|------|-----|
| `null`, `~` | `none` |
| `true`, `yes`, `on` | `true` |
| `false`, `no`, `off` | `false` |
| Integer | `integer` |
| Float | `float` |
| String | `string` |
| Sequence | `list` |
| Mapping | `dict` |

## Limitations

- Flow style collections (`[a, b]`, `{a: b}`) not supported
- Complex keys not supported
- Tags (`!tag`) not supported
