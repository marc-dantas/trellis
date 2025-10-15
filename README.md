# Trellis

Trellis is a simple and powerful templating engine.

It uses a clean and readable syntax to define templates and inherit from them, allowing for flexible and maintainable content generation.

Trellis is meant for HTML content but can be used as any text generator (Markdown, plain, [Gemini's Gemtext](https://en.wikipedia.org/wiki/Gemini_(protocol)), or any other).

## Getting started

Trellis is written in [Lua programming language](https://lua.org/) and is shipped as a script.

> **NOTE**: For now, trellis is nothing more than a prototype and I'm also creating it **for my own use**.
> This piece of software has no warranty, so use it at **YOUR OWN RISK**!

### Dependencies
Trellis does not have any dependencies apart from the Lua interpreter or [LuaJIT](https://luajit.org/).

### Usage
To use trellis you need to execute the script at the `src` folder in this repository:

- Windows
```console
> lua src\trellis.lua
```
- Linux/Mac
```console
$ chmod +x src/trellis.lua
$ ./src/trellis.lua # or lua src/trellis.lua
```

## Examples
For a demonstration of how Trellis works, please see the [examples](./examples) folder.