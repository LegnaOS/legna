# Legna

一门极简编程语言。编译器用纯 ARM64 汇编编写——零 C 依赖，直接编译为原生机器码。

> [English](README.md)

## 亮点

- 纯 ARM64 汇编编译器——不依赖 libc，不依赖运行时，直接 syscall
- 单 pass 编译：源码 → 词法分析 → 语法分析+代码生成 → 原生二进制
- 递归场景比 C -O0 快 27%（fib(35): 2,313M vs 3,165M cycles）
- AI 原生结构化输出（JSON Lines，`emit` 指令）
- 多进程并发：`spawn`/`wait` + 管道 IPC

## 快速开始

```bash
make                              # 构建编译器
./legnac hello.legna -o hello     # 编译
./hello                           # 运行
```

```legna
legna:
    output "hello, world\n"
```

## 语法一览

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
# AI 原生结构化输出（JSON Lines）
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

输出：

```json
{"lines":42}
{"status":"ok"}
```

```legna
# 多进程并发
legna:
    let pid = spawn:
        output "child\n"
    wait(pid)
    output "done\n"
```

## 性能

fib(35) 递归基准测试，20 次迭代，Apple Silicon：

| 编译器 | CPU 周期 | 对比 |
|--------|----------|------|
| **Legna v0.6** | **2,313M** | 基准 |
| C (clang -O0) | 3,165M | 慢 1.37x |
| C (clang -O2) | ~90M | 快 ~25x |

Legna 通过窥孔优化生成比 `gcc -O0` 更快的代码——在无 IR 的单 pass 编译器中，通过 `_out_pos` 回退消除冗余 push/pop 指令对。

## 语言特性

| 特性 | 语法 |
|------|------|
| 入口块 | `legna:` |
| 输出 | `output expr` |
| 变量 | `let x = expr` |
| 算术运算 | `+` `-` `*` `/` `%` |
| 比较运算 | `==` `!=` `<` `>` `<=` `>=` |
| 布尔运算 | `and` `or` `not`（短路求值） |
| 控制流 | `if`/`elif`/`else`、`while`、`for x in a..b:` |
| 循环控制 | `break`、`continue` |
| 函数 | `fn name(params):`，支持递归 |
| 输入 | `input_num()`、`input_str()` |
| 结构化 I/O | `emit "key" value`（JSON Lines） |
| 文件 I/O | `open`/`close`/`read_line`/`write_line` |
| 并发 | `spawn:`/`wait()`、`pipe()`/`send`/`recv` |
| 注释 | `# 单行注释` |
| 缩进 | 4 空格或 Tab |

## 项目结构

```
legna/
├── src/macos_arm64/     # 编译器源码（模块化纯 ARM64 汇编）
├── docs/                # 语言手册（多文件书籍结构）
├── tests/               # 自动化测试（25 个）
├── helloworld.legna     # Hello World 示例
└── Makefile             # 构建系统
```

## 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| macOS | ARM64 (Apple Silicon) | **已支持** |
| Linux | ARM64 / x86_64 | 计划中 |
| Windows | x86_64 | 计划中 |

## 文档

完整语言手册：[docs/README.md](docs/README.md)

## 测试

```bash
make test    # 25/25 通过
```

## 许可证

MIT
