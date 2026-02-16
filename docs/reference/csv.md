# CSV Built-ins

ZPy provides built-in functions for CSV parsing and serialization.

## Functions

### csv_parse(string, delimiter?, has_header?)

Parse a CSV string into a list.

**Parameters:**
- `string`: CSV content to parse
- `delimiter`: Field delimiter (default: `,`)
- `has_header`: Whether first row is headers (default: `true`)

**With headers (default):** Returns list of dicts

```python
csv_text = "name,age\nAlice,30\nBob,25"
data = csv_parse(csv_text)
# Result: [{"name": "Alice", "age": "30"}, {"name": "Bob", "age": "25"}]

print(data[0]["name"])  # Alice
```

**Without headers:** Returns list of lists

```python
csv_text = "a,b,c\n1,2,3"
data = csv_parse(csv_text, ",", false)
# Result: [["a", "b", "c"], ["1", "2", "3"]]
```

**Custom delimiter:**

```python
csv_text = "name;age\nAlice;30"
data = csv_parse(csv_text, ";")
```

### csv_stringify(data, delimiter?)

Convert a list to CSV string.

**Parameters:**
- `data`: List of dicts or list of lists
- `delimiter`: Field delimiter (default: `,`)

**From dicts (includes headers):**

```python
records = [
    {"name": "Alice", "age": "30"},
    {"name": "Bob", "age": "25"}
]
csv_text = csv_stringify(records)
# Result:
# name,age
# Alice,30
# Bob,25
```

**From lists (no headers):**

```python
rows = [["a", "b", "c"], ["1", "2", "3"]]
csv_text = csv_stringify(rows)
# Result:
# a,b,c
# 1,2,3
```

## Examples

### Read CSV File

```python
content = file_read(__dir__ + "/data.csv")
data = csv_parse(content)

for row in data:
    print(row["name"], row["email"])
```

### Write CSV File

```python
users = [
    {"id": "1", "name": "Alice"},
    {"id": "2", "name": "Bob"}
]

csv_text = csv_stringify(users)
file_write(__dir__ + "/users.csv", csv_text)
```

### Process and Transform

```python
# Read CSV
content = file_read("input.csv")
data = csv_parse(content)

# Transform
processed = []
for row in data:
    processed = processed + [{
        "full_name": row["first"] + " " + row["last"],
        "email": row["email"]
    }]

# Write result
file_write("output.csv", csv_stringify(processed))
```

## Notes

- All parsed values are strings (CSV doesn't preserve types)
- Quoted fields and escaped quotes are handled correctly
- Empty lines are skipped
