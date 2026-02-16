---
layout: home

hero:
  name: "ZPy"
  text: "Python-like language in Zig"
  tagline: Fast, lightweight, and embeddable scripting language
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/shishtpal/zpy

features:
  - icon: ⚡
    title: Fast
    details: Built with Zig for maximum performance. No garbage collection pauses.
  - icon: 🐍
    title: Python-like Syntax
    details: Familiar syntax inspired by Python. Easy to learn and use.
  - icon: 📦
    title: Embeddable
    details: Compile scripts to standalone executables or embed in your Zig projects.
  - icon: 🔧
    title: Simple
    details: Minimal dependencies. Easy to build and distribute.
---

## Quick Start

```bash
# Clone and build
git clone https://github.com/shishtpal/zpy.git
cd zpy
zig build

# Run a script
./zig-out/bin/zpy script.zpy

# Start interactive REPL
./zig-out/bin/zpy
```

## Example

```python
# Define a function
def greet(name):
    print("Hello,", name)

# Call it
greet("World")

# Lists and loops
numbers = [1, 2, 3, 4, 5]
for n in numbers:
    print(n * 2)
```
