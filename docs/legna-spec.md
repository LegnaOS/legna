# Legna 语言规范

> Version 0.1 | 2026-04-12

---

## 目录

1. [概述](#1-概述)
2. [设计哲学](#2-设计哲学)
3. [源文件格式](#3-源文件格式)
4. [词法结构](#4-词法结构)
   - 4.1 注释
   - 4.2 关键字
   - 4.3 字符串字面量
   - 4.4 转义序列
   - 4.5 缩进
   - 4.6 分隔符
5. [语法规范](#5-语法规范)
   - 5.1 EBNF 文法
   - 5.2 程序结构
   - 5.3 入口块
   - 5.4 语句
6. [语义规则](#6-语义规则)
7. [内置函数](#7-内置函数)
8. [编译器](#8-编译器)
   - 8.1 用法
   - 8.2 架构
   - 8.3 编译流程
   - 8.4 平台支持
9. [示例](#9-示例)
10. [错误信息参考](#10-错误信息参考)
11. [版本历史](#11-版本历史)

---

## 1. 概述

Legna 是一门极简编程语言，设计目标是自然、优雅、零冗余。

Legna 的编译器 `legnac` 用纯 ARM64 汇编编写，不依赖任何 C 运行时库，直接通过系统调用（syscall）与操作系统交互。编译器将 `.legna` 源文件编译为原生二进制可执行文件。

**核心特征：**

| 特性 | 描述 |
|------|------|
| 文件扩展名 | `.legna` |
| 编译目标 | 原生二进制可执行文件（Mach-O / ELF / PE） |
| 编译器实现 | 纯汇编，零 C 依赖 |
| 语法风格 | 缩进敏感，极简主义 |
| 当前版本 | v0.1 |

---

## 2. 设计哲学

Legna 的设计遵循以下原则：

- **极简** — 去掉一切不必要的语法符号：无分号、无花括号、无多余括号
- **自然** — 代码读起来接近自然语言，降低认知负担
- **优雅** — 缩进即结构，代码即文档
- **原生** — 直接编译为机器码，不依赖虚拟机或解释器

---

## 3. 源文件格式

| 属性 | 规定 |
|------|------|
| 文件扩展名 | `.legna` |
| 字符编码 | UTF-8 |
| 缩进方式 | 4 个空格（**不支持** Tab） |
| 换行符 | `\n`（LF），兼容 `\r\n`（CRLF，`\r` 被忽略） |
| 最大源文件大小 | 64 KB |

---

## 4. 词法结构

### 4.1 注释

Legna 支持单行注释，以 `#` 开头，延续到行尾：

```legna
# 这是一条注释
legna:
    output "hello"  # 行尾注释暂不支持，请独占一行
```

> **注意：** v0.1 中注释必须独占一行，不支持行尾注释。

### 4.2 关键字

v0.1 保留以下关键字：

| 关键字 | 用途 | 说明 |
|--------|------|------|
| `legna` | 程序入口 | 后接 `:` 定义入口块 |
| `output` | 标准输出 | 后接字符串字面量 |

关键字区分大小写，必须全部小写。

### 4.3 字符串字面量

字符串用双引号 `"` 包裹：

```
"hello, world"
"包含转义：\n换行\t制表符"
```

字符串不支持：
- 单引号 `'`
- 多行字符串（字符串必须在同一行内闭合）
- 字符串拼接

### 4.4 转义序列

在字符串字面量中，反斜杠 `\` 开启转义序列：

| 转义序列 | 含义 | ASCII 码 |
|----------|------|----------|
| `\n` | 换行（Line Feed） | `0x0A` |
| `\t` | 水平制表符（Tab） | `0x09` |
| `\\` | 反斜杠 | `0x5C` |
| `\"` | 双引号 | `0x22` |

未识别的转义序列（如 `\a`）将原样输出转义字符。

### 4.5 缩进

Legna 使用缩进来定义代码块，类似 Python：

- 缩进单位：**4 个空格**
- 不支持 Tab 字符
- `legna:` 之后的语句必须缩进至少 1 级（4 个空格）
- 缩进回到 0 级表示块结束

```legna
legna:
    output "缩进 4 空格"    # 正确
```

### 4.6 分隔符

| 符号 | 用途 |
|------|------|
| `:` | 跟在 `legna` 后，标记块开始 |
| `"` | 字符串字面量定界符 |
| `#` | 注释起始符 |

---

## 5. 语法规范

### 5.1 EBNF 文法

```ebnf
program      = { comment | blank_line }
               entry_block
               { comment | blank_line } ;

entry_block  = "legna" ":" NEWLINE
               INDENT { statement } DEDENT ;

statement    = output_stmt NEWLINE
             | comment
             | blank_line ;

output_stmt  = "output" SPACE STRING_LITERAL ;

comment      = "#" { ANY_CHAR } NEWLINE ;

blank_line   = [ SPACES ] NEWLINE ;

STRING_LITERAL = '"' { CHAR | escape_seq } '"' ;

escape_seq   = "\n" | "\t" | "\\" | "\"" ;

INDENT       = <缩进增加 4 空格> ;
DEDENT       = <缩进减少到 0> ;
NEWLINE      = LF | CR LF ;
SPACE        = " " { " " } ;
CHAR         = <除 '"' 和 '\' 外的任意可打印字符> ;
ANY_CHAR     = <除换行外的任意字符> ;
```

### 5.2 程序结构

一个合法的 Legna 程序由以下部分组成：

```
[可选：注释和空行]
legna:
    [语句块]
[可选：注释和空行]
```

### 5.3 入口块

`legna:` 是程序的入口点，等价于其他语言中的 `main` 函数：

```legna
legna:
    # 程序从这里开始执行
    output "hello"
```

**规则：**
- 每个 `.legna` 文件必须有且仅有一个 `legna:` 块
- `legna:` 必须位于行首（无缩进）
- 冒号 `:` 紧跟 `legna`，之间无空格
- 块体必须缩进 4 个空格

### 5.4 语句

v0.1 支持的语句类型：

| 语句 | 语法 | 说明 |
|------|------|------|
| 输出语句 | `output "string"` | 将字符串写入标准输出 |

---

## 6. 语义规则

1. **唯一入口** — 每个源文件必须包含恰好一个 `legna:` 块
2. **顺序执行** — 块内语句按从上到下的顺序执行
3. **无自动换行** — `output` 不会自动追加换行符，需要换行请使用 `\n`
4. **空块合法** — `legna:` 后没有语句是合法的，生成的程序仅执行 `exit(0)`
5. **退出码** — 程序正常结束时返回退出码 `0`

---

## 7. 内置函数

### output

```
output STRING_LITERAL
```

将字符串内容写入标准输出（file descriptor 1）。

**行为：**
- 处理转义序列后，将实际字节写入 stdout
- 不追加换行符
- 底层实现为 `write(1, str, len)` 系统调用

**示例：**

```legna
legna:
    output "hello"       # 输出: hello（无换行）
    output "hello\n"     # 输出: hello（带换行）
    output "a\tb\n"      # 输出: a	b（带制表符和换行）
```

---

## 8. 编译器

### 8.1 用法

```bash
# 基本用法（输出文件名 = 源文件名去掉 .legna 扩展名）
./legnac hello.legna

# 指定输出文件名
./legnac hello.legna -o myapp

# 运行编译后的程序
./myapp
```

**参数说明：**

| 参数 | 必需 | 说明 |
|------|------|------|
| `<file.legna>` | 是 | 输入源文件路径 |
| `-o <name>` | 否 | 指定输出可执行文件名 |

### 8.2 架构

编译器 `legnac` 的核心特征：

- **实现语言：** 纯 ARM64 汇编（GAS 语法）
- **运行时依赖：** 无（直接系统调用，不链接 libc）
- **外部工具：** 调用系统汇编器 `as` 和链接器 `ld`
- **临时文件：** `/tmp/_legna.s` 和 `/tmp/_legna.o`（编译后自动清理）

### 8.3 编译流程

```
┌──────────────┐
│  .legna 源码  │
└──────┬───────┘
       │ 读取文件 (syscall: open + read)
       ▼
┌──────────────┐
│   词法分析    │  识别关键字、字符串、缩进、注释
└──────┬───────┘
       ▼
┌──────────────┐
│   语法分析    │  验证 legna: 块结构，提取 output 字符串
└──────┬───────┘
       ▼
┌──────────────┐
│   代码生成    │  生成 ARM64 汇编代码（.s 文件）
└──────┬───────┘
       │ 写入临时文件 (syscall: open + write)
       ▼
┌──────────────┐
│   汇编 (as)   │  fork + execve 调用 /usr/bin/as
└──────┬───────┘
       ▼
┌──────────────┐
│   链接 (ld)   │  fork + execve 调用 /usr/bin/ld
└──────┬───────┘
       ▼
┌──────────────┐
│  原生可执行文件 │  Mach-O ARM64 二进制
└──────────────┘
```

**生成的代码结构：**

每个 `output "..."` 语句编译为一个 `write` 系统调用：

```asm
mov x0, #1              ; fd = stdout
adrp x1, _s0@PAGE       ; 字符串地址
add x1, x1, _s0@PAGEOFF
mov x2, #<length>        ; 字节长度
mov x16, #4              ; SYS_write
svc #0x80
```

程序末尾生成 `exit(0)`：

```asm
mov x0, #0
mov x16, #1              ; SYS_exit
svc #0x80
```

### 8.4 平台支持

| 平台 | 架构 | 状态 | 汇编语法 | 二进制格式 |
|------|------|------|----------|-----------|
| macOS | ARM64 (Apple Silicon) | **已实现** | GAS | Mach-O |
| Linux | x86_64 | 计划中 | GAS | ELF |
| Windows | x86_64 | 计划中 | NASM | PE |

---

## 9. 示例

### Hello World

```legna
# hello world

legna:
    output "hello, world"
```

编译并运行：

```bash
$ ./legnac helloworld.legna -o helloworld
compiled successfully
$ ./helloworld
hello, world
```

### 多行输出

```legna
# 多行输出示例

legna:
    output "first line\n"
    output "second line\n"
    output "third line\n"
```

预期输出：

```
first line
second line
third line
```

### 转义序列

```legna
# 转义序列演示

legna:
    output "name:\tLegna\n"
    output "path:\tC:\\legna\\bin\n"
    output "motto:\t\"code is poetry\"\n"
```

预期输出：

```
name:	Legna
path:	C:\legna\bin
motto:	"code is poetry"
```

### 空程序

```legna
# 合法的空程序，仅执行 exit(0)

legna:
```

---

## 10. 错误信息参考

| 错误信息 | 原因 | 解决方法 |
|----------|------|----------|
| `usage: legnac <file.legna> [-o output]` | 未提供源文件参数 | 指定 `.legna` 源文件路径 |
| `error: cannot open source file` | 源文件不存在或无读取权限 | 检查文件路径和权限 |
| `error: missing 'legna:' entry point` | 源文件中没有 `legna:` 块 | 添加 `legna:` 入口块 |
| `error: unterminated string` | 字符串缺少闭合双引号 | 补全 `"` |
| `error: unexpected syntax in legna block` | 块内包含无法识别的语句 | 检查拼写和缩进 |
| `error: assembler failed` | 生成的汇编代码有误 | 这是编译器 bug，请报告 |
| `error: linker failed` | 链接阶段失败 | 检查系统工具链（`as`、`ld`） |

---

## 11. 版本历史

### v0.1 — 2026-04-12（初始版本）

**语言特性：**
- `legna:` 程序入口块
- `output "string"` 标准输出语句
- `#` 单行注释
- 字符串转义序列：`\n`、`\t`、`\\`、`\"`
- 缩进敏感的块结构

**编译器：**
- macOS ARM64 平台支持
- 纯 ARM64 汇编实现，零 C 依赖
- 编译为原生 Mach-O 可执行文件
- 支持 `-o` 指定输出文件名

**已知限制：**
- 仅支持 `output` 一种语句
- 不支持变量、函数、控制流
- 不支持行尾注释
- 源文件最大 64 KB
- 仅支持 macOS ARM64 平台

---

> **Legna** — 让代码回归本质。
