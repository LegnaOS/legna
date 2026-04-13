# LEGNA.md

This file provides guidance to LegnaCode (claude.ai/code) when working with code in this repository.

## What is this

Legna 是一门极简编程语言，编译器 `legnac` 用纯 ARM64 汇编编写，零 C 依赖，直接通过 macOS syscall 与操作系统交互。编译器将 `.legna` 源文件编译为原生 Mach-O ARM64 可执行文件。

## Build and test commands

```bash
make            # 构建编译器 (输出 ./legnac)
make test       # 运行全部测试
make clean      # 清理构建产物
```

编译并运行 Legna 程序：
```bash
./legnac hello.legna -o hello
./hello
```

测试脚本 `tests/run_tests.sh` 会编译每个 `.legna` 测试文件到 `/tmp/legna_test_*`，比较输出与预期值。添加新测试时在脚本中调用 `run_test "name" "file.legna" "expected_output"` 或 `run_error_test "name" "file.legna"`。

## Compiler architecture

编译器是模块化的纯 ARM64 汇编，源码在 `src/macos_arm64/`：

| 文件 | 职责 |
|------|------|
| `defs.inc` | 共享常量：syscall 号、token 类型、符号类型、缓冲区大小 |
| `main.s` | 入口点，CLI 参数解析 |
| `lexer.s` | 词法分析：将源码转为 token 流（支持缩进/dedent） |
| `parser.s` | 语法分析：验证 `legna:` 块结构，解析语句 |
| `codegen.s` | 代码生成：将 AST 转为 ARM64 汇编输出 |
| `driver.s` | 编译驱动：调用 `as` 和 `ld`（fork+execve），清理临时文件 |
| `helpers.s` | 工具函数：字符串操作、数字转换、错误输出 |
| `data.s` | 全局数据段：缓冲区、token 数组、符号表、字符串常量 |

编译流程：源码 → 词法分析 → 语法分析 → ARM64 汇编生成(`/tmp/_legna.s`) → `as` 汇编 → `ld` 链接 → 原生二进制。

所有模块通过 `.include "src/macos_arm64/defs.inc"` 共享常量定义。Makefile 会自动发现 `src/macos_arm64/*.s` 并编译链接。

## Language features (v0.5)

- `legna:` 入口块（每个文件必须有且仅有一个）
- `output "string"` / `output var` 标准输出（缓冲 I/O，退出时 flush）
- `let x = expr` 变量声明与赋值（整数和字符串类型）
- `if`/`elif`/`else` 条件分支
- `while` 循环（支持 `break`/`continue`）
- `for x in start..end:` 循环（支持表达式边界，支持 `break`/`continue`）
- `fn name(params):` 用户自定义函数（支持递归）
- `return expr` 函数返回值
- 算术运算：`+` `-` `*` `/` `%`（立即数优化）
- 比较运算：`==` `!=` `<` `>` `<=` `>=`
- 布尔运算：`and` `or` `not`（短路求值）
- 转义序列：`\n` `\t` `\\` `\"`
- `input_num()` / `input_str()` 标准输入
- `emit "key" value` 结构化输出（JSON Lines 格式，AI 原生亲和）
- `open` / `close` / `read_line` / `write_line` 文件 I/O
- `spawn:` / `wait()` 多进程并发（fork 进程模型）
- `pipe()` / `send` / `recv` 管道 IPC（JSON Lines 格式）
- `#` 单行注释（支持行尾注释）
- 缩进敏感（4 空格或 Tab，Tab 按 4 列对齐）
- 精确栈帧分配（按实际变量数，16 字节对齐）
- 源文件最大 64KB

## Key constraints

- 仅支持 macOS ARM64 (Apple Silicon)，需要 Xcode Command Line Tools（`as` 和 `ld`）
- 编译器本身不链接 libc，直接使用 macOS syscall（SYS_WRITE=4, SYS_EXIT=1 等）
- 汇编使用 GAS 语法（GNU Assembler）
- 临时文件写入 `/tmp/_legna.s` 和 `/tmp/_legna.o`，编译后自动清理
- 完整语言规范见 `docs/README.md`（多文件书籍结构）
