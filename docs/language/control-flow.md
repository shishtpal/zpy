# Control Flow

ZPy provides standard control flow constructs for conditional execution and looping.

## Conditionals

### if Statement

```python
if x > 0:
    print("positive")
```

### if-else Statement

```python
if x > 0:
    print("positive")
else:
    print("not positive")
```

### if-elif-else Statement

```python
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")
```

Multiple `elif` branches:

```python
if score >= 90:
    grade = "A"
elif score >= 80:
    grade = "B"
elif score >= 70:
    grade = "C"
elif score >= 60:
    grade = "D"
else:
    grade = "F"
```

## Loops

### while Loop

```python
# Basic while loop
count = 0
while count < 5:
    print(count)
    count += 1

# With break
while true:
    response = get_input()
    if response == "quit":
        break
    process(response)

# With continue
i = 0
while i < 10:
    i += 1
    if i % 2 == 0:
        continue
    print(i)  # Prints odd numbers only
```

### for Loop

Iterate over sequences:

```python
# List iteration
items = [1, 2, 3, 4, 5]
for item in items:
    print(item)

# Range iteration
for i in range(5):
    print(i)  # 0, 1, 2, 3, 4

# Range with start
for i in range(2, 6):
    print(i)  # 2, 3, 4, 5

# Range with step
for i in range(0, 10, 2):
    print(i)  # 0, 2, 4, 6, 8

# Dictionary iteration
person = {"name": "Alice", "age": 30}
for key in keys(person):
    print(key, person[key])
```

### break and continue

```python
# break - exit loop early
for i in range(10):
    if i == 5:
        break
    print(i)  # 0, 1, 2, 3, 4

# continue - skip iteration
for i in range(10):
    if i % 2 == 0:
        continue
    print(i)  # 1, 3, 5, 7, 9
```

## pass Statement

`pass` is a null operation - it does nothing. Use it as a placeholder:

```python
def placeholder():
    pass

if x > 0:
    pass  # Handle positive case
else:
    print("not positive")
```

## del Statement

Remove items from lists or dictionaries:

```python
# Remove from list by index
items = [1, 2, 3, 4, 5]
del items[2]      # items is now [1, 2, 4, 5]

# Remove from dict by key
data = {"a": 1, "b": 2}
del data["b"]     # data is now {"a": 1}
```

## Nested Control Flow

```python
# Nested loops
for i in range(3):
    for j in range(3):
        print(i, j)

# Nested conditionals
for x in range(-2, 3):
    if x > 0:
        print(x, "is positive")
    elif x < 0:
        print(x, "is negative")
    else:
        print(x, "is zero")
```

## Early Return

Use `return` to exit a function early:

```python
def find_index(items, target):
    for i in range(len(items)):
        if items[i] == target:
            return i
    return -1
```
