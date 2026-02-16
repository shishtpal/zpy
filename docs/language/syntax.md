# Syntax

ZPy uses Python-like syntax that is easy to read and write.

## Comments

```python
# This is a single-line comment

# Comments can appear anywhere
x = 10  # inline comment
```

## Variables

Variables are dynamically typed and don't need declarations:

```python
name = "ZPy"        # string
version = 0.1       # float
count = 42          # int
active = true       # bool
items = [1, 2, 3]   # list
data = {"a": 1}     # dict
```

## Indentation

Like Python, ZPy uses indentation to define blocks:

```python
if x > 0:
    print("positive")
    if x > 10:
        print("large")
```

Use 4 spaces per indentation level (recommended).

## Statements

Multiple statements on separate lines:

```python
x = 1
y = 2
z = x + y
```

Statements can be separated by newlines (no semicolons needed).

## Identifiers

Valid identifiers:
- Start with a letter or underscore
- Can contain letters, digits, and underscores
- Case-sensitive

```python
my_var = 1
MyVar = 2      # different from my_var
_private = 3
```

## Reserved Words

```
and       break    continue  def      elif
else      false    for       if       in
len       none     not       or       pass
range     return   true      while
```

## Expressions

```python
# Arithmetic
x = 1 + 2 * 3      # 7
y = (1 + 2) * 3    # 9

# String concatenation
msg = "Hello" + " " + "World"

# List access
items = [1, 2, 3]
first = items[0]   # 1

# Dict access
data = {"name": "ZPy"}
name = data["name"]
```

## Next Steps

- [Data Types](/language/types) - Learn about available types
- [Operators](/language/operators) - Operators and expressions
- [Control Flow](/language/control-flow) - Conditionals and loops
