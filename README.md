# Legna

A minimalist programming language. The compiler is written in pure ARM64 assembly — zero C dependencies, compiles directly to native machine code.

> [中文版](README_CN.md)

## Highlights

- Pure ARM64 assembly compiler — no libc, no runtime, just syscalls
- Single-pass compilation: source → lexer → parser+codegen → native binary
- Faster than C -O0 on recursive workloads (fib(35): 27% faster)
- Multi-file compilation with `import` and standard library
- Arrays, augmented assignment (`+=` `-=` `*=`), string builtins
- AI-native structured output (JSON Lines via `emit`)
- Multiprocess concurrency with `spawn`/`wait` and pipe IPC

## Quick Start

```bash
make                              # build the compiler
./legnac hello.legna -o hello     # compile
./hello                           # run
```

```legna
legna:
    output "hello, world\n"
```

## A Taste of Legna

```legna
fn fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

legna:
    output fib(35)
    output "\n"
```

```legna
# AI-native structured output (JSON Lines)
legna:
    let fd = open("data.txt", "r")
    let count = 0
    let line = read_line(fd)
    while line != "":
        count = count + 1
        line = read_line(fd)
    close(fd)
    emit "lines" count
    emit "status" "ok"
```

Output:

```json
{"lines":42}
{"status":"ok"}
```

```legna
# multiprocess concurrency
legna:
    let pid = spawn:
        output "child\n"
    wait(pid)
    output "done\n"
```

```legna
# arrays and augmented assignment
legna:
    let arr = array(5)
    for i in 0..5:
        arr[i] = i * i
    let sum = 0
    for i in 0..5:
        sum += arr[i]
    output sum
    output "\n"
```

```legna
# import standard library
import "math"
import "string"

legna:
    output abs(-42)
    output "\n"
    output pow(2, 10)
    output "\n"
    output is_alpha(65)
```

## Performance

fib(35) recursive benchmark, 20 iterations, Apple Silicon:

| Compiler | CPU Cycles | vs Legna |
|----------|-----------|----------|
| **Legna v0.6** | **2,313M** | baseline |
| C (clang -O0) | 3,165M | 1.37x slower |
| C (clang -O2) | ~90M | ~25x faster |

Legna generates code that beats `gcc -O0` through peephole optimizations — `_out_pos` rewind eliminates redundant push/pop pairs in a single-pass compiler with no IR.

## Language Features

| Feature | Syntax |
|---------|--------|
| Entry block | `legna:` |
| Output | `output expr` |
| Variables | `let x = expr` |
| Arrays | `let arr = array(N)`, `arr[i]` |
| Arithmetic | `+` `-` `*` `/` `%` |
| Augmented assign | `+=` `-=` `*=` |
| Comparison | `==` `!=` `<` `>` `<=` `>=` |
| Boolean | `and` `or` `not` (short-circuit) |
| Control flow | `if`/`elif`/`else`, `while`, `for x in a..b:` |
| Loop control | `break`, `continue` |
| Functions | `fn name(params):` with recursion |
| Input | `input_num()`, `input_str()` |
| String builtins | `len(s)`, `char_at(s,i)`, `to_num(s)` |
| Structured I/O | `emit "key" value` (JSON Lines) |
| File I/O | `open`/`close`/`read_line`/`write_line` |
| Concurrency | `spawn:`/`wait()`, `pipe()`/`send`/`recv` |
| Import | `import "math"`, `import "string"` |
| Comments | `# single line` |
| Indentation | 4 spaces or tab |

## Project Structure

```
legna/
├── src/macos_arm64/     # compiler source (modular ARM64 assembly)
├── lib/                 # standard library (math, string)
├── docs/                # language manual (multi-file book)
├── tests/               # automated test suite (36 tests)
├── helloworld.legna     # hello world example
└── Makefile             # build system
```

## Platform Support

| Platform | Architecture | Status |
|----------|-------------|--------|
| macOS | ARM64 (Apple Silicon) | **Supported** |
| Linux | ARM64 / x86_64 | Planned |
| Windows | x86_64 | Planned |

## Documentation

Full language manual: [docs/README.md](docs/README.md)

## Tests

```bash
make test    # 36/36 tests
```

## License

MIT
