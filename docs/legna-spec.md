# Legna 语言规范

> Version 0.4 | 2025

---

## 目录

1. [前言](#1-前言)
2. [快速入门](#2-快速入门)
3. [词法结构](#3-词法结构)
4. [类型系统](#4-类型系统)
5. [变量与赋值](#5-变量与赋值)
6. [表达式](#6-表达式)
7. [控制流](#7-控制流)
8. [函数](#8-函数)
9. [输入输出](#9-输入输出)
10. [编译器](#10-编译器)
11. [完整示例](#11-完整示例)
12. [错误信息参考](#12-错误信息参考)
13. [版本历史](#13-版本历史)
14. [附录：EBNF 文法](#14-附录ebnf-文法)

---

## 1. 前言

Legna 是一门极简编程语言，设计目标是自然、优雅、零冗余。

编译器 `legnac` 用纯 ARM64 汇编编写，不依赖任何 C 运行时库，直接通过系统调用与操作系统交互。编译器将 `.legna` 源文件编译为原生二进制可执行文件。

### 1.1 核心特征

| 特性 | 描述 |
|------|------|
| 文件扩展名 | `.legna` |
| 编译目标 | 原生 Mach-O ARM64 二进制 |
| 编译器实现 | 纯 ARM64 汇编，零 C 依赖 |
| 语法风格 | 缩进敏感，极简主义 |
| 当前版本 | v0.4 |

### 1.2 设计哲学

- **极简** — 去掉一切不必要的语法符号：无分号、无花括号、无多余括号
- **自然** — 代码读起来接近自然语言，降低认知负担
- **优雅** — 缩进即结构，代码即文档
- **原生** — 直接编译为机器码，不依赖虚拟机或解释器
- **零开销** — 缓冲 I/O、精确栈帧、立即数优化，生成代码无冗余

---

## 2. 快速入门

### 2.1 Hello World

创建文件 `hello.legna`：

```legna
legna:
    output "hello, world\n"
```

编译并运行：

```bash
$ ./legnac hello.legna -o hello
compiled successfully
$ ./hello
hello, world
```

### 2.2 变量与运算

```legna
legna:
    let a = 10
    let b = 20
    let sum = a + b
    output "sum = "
    output sum
    output "\n"
```

输出：`sum = 30`

### 2.3 函数与递归

```legna
fn factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

legna:
    output factorial(10)
    output "\n"
```

输出：`3628800`

### 2.4 编译命令

```bash
# 基本用法
./legnac source.legna -o output_name

# 省略 -o 时，输出文件名 = 源文件名去掉 .legna
./legnac hello.legna
```

---

## 3. 词法结构

### 3.1 注释

以 `#` 开头，延续到行尾。支持独占一行或行尾注释：

```legna
# 这是独占一行的注释
legna:
    let x = 5  # 这是行尾注释
```

### 3.2 关键字

所有关键字区分大小写，必须全部小写。

| 关键字 | 用途 |
|--------|------|
| `legna` | 程序入口块 |
| `output` | 标准输出 |
| `let` | 变量声明 |
| `if` | 条件判断 |
| `elif` | 否则如果 |
| `else` | 否则 |
| `while` | 循环 |
| `for` | 范围循环 |
| `in` | for 循环范围标记 |
| `break` | 跳出循环 |
| `continue` | 跳过本次迭代 |
| `fn` | 函数定义 |
| `return` | 函数返回 |
| `and` | 逻辑与 |
| `or` | 逻辑或 |
| `not` | 逻辑非 |
| `input_num` | 读取整数输入 |
| `input_str` | 读取字符串输入 |

### 3.3 字面量

**整数字面量：** 十进制整数，支持负数前缀 `-`。

```legna
42
-7
0
```

**字符串字面量：** 双引号包裹，支持转义序列。

```legna
"hello, world"
"包含转义：\n换行\t制表符"
```

字符串不支持单引号、多行字符串或字符串拼接。

### 3.4 转义序列

| 转义序列 | 含义 | ASCII 码 |
|----------|------|----------|
| `\n` | 换行 | `0x0A` |
| `\t` | 水平制表符 | `0x09` |
| `\\` | 反斜杠 | `0x5C` |
| `\"` | 双引号 | `0x22` |

未识别的转义序列原样输出。

### 3.5 缩进

Legna 使用缩进定义代码块，类似 Python：

- 支持 **4 个空格** 或 **Tab** 字符
- Tab 按 4 列对齐（tab-stop 语义）
- 缩进增加产生 `INDENT` token，减少产生 `DEDENT` token
- 空行和纯注释行不影响缩进层级

```legna
legna:
    output "一级缩进\n"
    if 1 == 1:
        output "二级缩进\n"
```

### 3.6 运算符与分隔符

**算术运算符：**

| 运算符 | 含义 |
|--------|------|
| `+` | 加法 |
| `-` | 减法 / 一元取负 |
| `*` | 乘法 |
| `/` | 整数除法 |
| `%` | 取模 |

**比较运算符：**

| 运算符 | 含义 |
|--------|------|
| `==` | 等于 |
| `!=` | 不等于 |
| `<` | 小于 |
| `>` | 大于 |
| `<=` | 小于等于 |
| `>=` | 大于等于 |

**逻辑运算符：** `and`、`or`、`not`

**其他符号：**

| 符号 | 用途 |
|------|------|
| `:` | 块开始标记 |
| `=` | 赋值 |
| `..` | 范围运算符（for 循环） |
| `(` `)` | 分组 / 函数调用 |
| `,` | 参数分隔符 |
| `"` | 字符串定界符 |
| `#` | 注释起始符 |

---

## 4. 类型系统

Legna 有两种数据类型，在声明时自动推断：

### 4.1 整数（int）

64 位有符号整数。所有算术运算、比较运算的操作数和结果都是整数。

```legna
let x = 42
let y = -7
let z = x + y * 2    # z = 28
```

### 4.2 字符串（str）

字符串由指针和长度组成，存储在栈上。字符串变量通过字面量赋值或 `input_str()` 获取。

```legna
let name = "Legna"
let greeting = input_str()
output name
```

字符串变量不支持拼接或修改，只能整体输出。

---

## 5. 变量与赋值

### 5.1 变量声明

使用 `let` 声明变量，类型自动推断：

```legna
let x = 10           # 整数
let name = "Legna"   # 字符串
let y = x + 5        # 表达式
let z = input_num()  # 从标准输入读取
```

### 5.2 变量赋值

已声明的变量可以重新赋值：

```legna
let x = 1
x = x + 1
output x    # 输出 2
```

### 5.3 作用域

- `legna:` 块内的变量为全局作用域
- 函数参数和函数体内的变量为局部作用域，函数返回后销毁
- 不支持嵌套作用域或闭包

---

## 6. 表达式

### 6.1 算术表达式

支持标准四则运算和取模，遵循数学优先级：

| 优先级 | 运算符 | 结合性 |
|--------|--------|--------|
| 1（最高） | `-`（一元取负） | 右结合 |
| 2 | `*` `/` `%` | 左结合 |
| 3 | `+` `-` | 左结合 |

```legna
let x = 2 + 3 * 4      # x = 14
let y = (2 + 3) * 4    # y = 20
let z = -x + 1          # z = -13
let m = 17 % 5          # m = 2
```

括号 `()` 可以改变运算优先级。

### 6.2 比较表达式

比较运算符用于条件判断，返回布尔结果（内部为整数 0/1）：

```legna
if x > 5:
    output "big\n"
if a == b:
    output "equal\n"
```

### 6.3 布尔表达式

`and`、`or`、`not` 用于组合条件，支持短路求值：

- `and`：左侧为假时不求值右侧
- `or`：左侧为真时不求值右侧
- `not`：反转比较结果

```legna
if x > 0 and x < 100:
    output "in range\n"

if x == 0 or y == 0:
    output "has zero\n"

if not x == 5:
    output "not five\n"
```

---

## 7. 控制流

### 7.1 条件语句

**if / elif / else：**

```legna
let x = 5
if x > 10:
    output "big\n"
elif x > 3:
    output "mid\n"
else:
    output "small\n"
```

- `elif` 和 `else` 可选，`elif` 可以有多个
- 每个分支后接 `:` 和缩进块
- 条件支持 `and`/`or`/`not` 组合

### 7.2 while 循环

```legna
let x = 5
while x > 0:
    output x
    output " "
    x = x - 1
```

输出：`5 4 3 2 1 `

### 7.3 for 循环

`for` 循环遍历整数范围，上界不包含（左闭右开）：

```legna
for i in 0..5:
    output i
    output " "
```

输出：`0 1 2 3 4 `

范围边界支持任意表达式：

```legna
let n = 10
for i in 1..n+1:
    output i
    output " "
```

### 7.4 break 与 continue

`break` 立即跳出当前循环，`continue` 跳过本次迭代：

```legna
let x = 0
while x < 10:
    x = x + 1
    if x == 5:
        break
    if x % 2 == 0:
        continue
    output x
    output " "
```

输出：`1 3 `

`break` 和 `continue` 可用于 `while` 和 `for` 循环，支持嵌套循环（作用于最内层）。

---

## 8. 函数

### 8.1 函数定义

使用 `fn` 关键字定义函数，函数必须在 `legna:` 块之前声明：

```legna
fn add(a, b):
    return a + b

legna:
    let x = add(3, 4)
    output x    # 输出 7
```

### 8.2 参数传递

参数通过 ARM64 寄存器 x0-x7 传递（最多 8 个参数），均为整数类型：

```legna
fn max(a, b):
    if a > b:
        return a
    return b
```

### 8.3 返回值

`return expr` 将表达式结果放入 x0 寄存器并返回调用者。函数末尾没有显式 `return` 时，返回值未定义。

### 8.4 递归

函数支持递归调用，每次调用有独立的栈帧：

```legna
fn factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

fn fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)
```

### 8.5 函数调用

函数可以在表达式中调用（有返回值）或作为独立语句调用（忽略返回值）：

```legna
fn greet():
    output "hello\n"

legna:
    greet()              # 语句调用
    let x = factorial(5) # 表达式调用
```

---

## 9. 输入输出

### 9.1 output

将内容写入标准输出。支持字符串字面量、整数变量、字符串变量和表达式：

```legna
output "hello\n"       # 字符串字面量
output x               # 整数变量（自动转为十进制文本）
output name            # 字符串变量
output x + 1           # 表达式
```

**缓冲机制：** 所有输出写入 4KB 运行时缓冲区，程序退出时统一 flush。这大幅减少系统调用次数，提升 I/O 密集型程序的性能。

### 9.2 input_num()

从标准输入读取一行，解析为整数：

```legna
let x = input_num()
output x * 2
```

### 9.3 input_str()

从标准输入读取一行，存为字符串：

```legna
let name = input_str()
output "hello, "
output name
output "\n"
```

---

## 10. 编译器

### 10.1 用法

```bash
./legnac <file.legna> [-o output]
```

| 参数 | 必需 | 说明 |
|------|------|------|
| `<file.legna>` | 是 | 输入源文件路径 |
| `-o <name>` | 否 | 指定输出可执行文件名 |

### 10.2 架构

编译器 `legnac` 本身用纯 ARM64 汇编编写，模块化设计：

| 模块 | 文件 | 职责 |
|------|------|------|
| 入口 | `main.s` | CLI 参数解析，调度编译流程 |
| 词法分析 | `lexer.s` | 源码 → token 流，缩进追踪 |
| 语法分析 + 代码生成 | `parser.s` | 递归下降解析，单 pass 直接 emit ARM64 汇编 |
| 运行时模板 | `codegen.s` | itoa/atoi/readline/缓冲输出 等运行时函数模板 |
| 数据定义 | `data.s` | 所有字符串常量、代码片段、BSS 缓冲区 |
| 辅助函数 | `helpers.s` | 字符串操作、emit 辅助、错误报告 |
| 驱动 | `driver.s` | 文件 I/O、fork+exec 调用 as/ld |
| 常量 | `defs.inc` | token 类型、syscall 号、缓冲区大小 |

### 10.3 编译流程

```
┌──────────────┐
│  .legna 源码  │
└──────┬───────┘
       │ 读取文件 (syscall: open + read)
       ▼
┌──────────────┐
│   词法分析    │  识别关键字、字符串、缩进、运算符
└──────┬───────┘
       ▼
┌──────────────┐
│ 语法分析 +    │  单 pass：解析 token 流，同时 emit
│ 代码生成      │  ARM64 汇编文本到输出缓冲区
└──────┬───────┘
       │ 写入临时文件 /tmp/legna_<PID>.s
       ▼
┌──────────────┐
│   汇编 (as)   │  fork + execve 调用系统汇编器
└──────┬───────┘
       ▼
┌──────────────┐
│   链接 (ld)   │  fork + execve 调用系统链接器
└──────┬───────┘
       │ 清理临时文件
       ▼
┌──────────────┐
│  原生可执行文件 │  Mach-O ARM64 二进制
└──────────────┘
```

### 10.4 性能优化

| 优化 | 说明 |
|------|------|
| 输出缓冲 | 4KB 运行时缓冲区，退出时一次性 flush，减少 syscall |
| 精确栈帧 | 按实际变量数分配，16 字节对齐，替代固定 4096 |
| 立即数优化 | `add x0, x0, #N` / `cmp x0, #N` 替代 push/pop 路径 |
| 零运行时依赖 | 不链接 libc，直接 syscall |

### 10.5 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| macOS | ARM64 (Apple Silicon) | **已实现** |
| Linux | ARM64 / x86_64 | 计划中 |
| Windows | x86_64 | 计划中 |

---

## 11. 完整示例

### 11.1 FizzBuzz

```legna
legna:
    for i in 1..16:
        let m3 = i % 3
        let m5 = i % 5
        if m3 == 0:
            if m5 == 0:
                output "FizzBuzz\n"
            else:
                output "Fizz\n"
        else:
            if m5 == 0:
                output "Buzz\n"
            else:
                output i
                output "\n"
```

### 11.2 阶乘（递归）

```legna
fn factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

legna:
    output "10! = "
    output factorial(10)
    output "\n"
```

输出：`10! = 3628800`

### 11.3 斐波那契数列

```legna
fn fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

legna:
    for i in 0..10:
        output fib(i)
        output " "
    output "\n"
```

输出：`0 1 1 2 3 5 8 13 21 34`

### 11.4 猜数字游戏

```legna
legna:
    let secret = 42
    let guess = 0
    while guess != secret:
        output "guess a number: "
        guess = input_num()
        if guess < secret:
            output "too low\n"
        elif guess > secret:
            output "too high\n"
        else:
            output "correct!\n"
```

---

## 12. 错误信息参考

| 错误信息 | 原因 | 解决方法 |
|----------|------|----------|
| `usage: legnac <file.legna> [-o output]` | 未提供源文件参数 | 指定 `.legna` 源文件路径 |
| `error: cannot open source file` | 源文件不存在或无读取权限 | 检查文件路径和权限 |
| `error: unexpected token at line N` | 语法错误 | 检查第 N 行的拼写和缩进 |
| `error: undefined variable at line N` | 使用了未声明的变量或函数 | 先用 `let` 声明或定义 `fn` |
| `error: assembler failed` | 生成的汇编代码有误 | 这是编译器 bug，请报告 |
| `error: linker failed` | 链接阶段失败 | 检查系统工具链（`as`、`ld`） |

错误信息包含行号，指向源文件中出错的位置。

---

## 13. 版本历史

### v0.4（当前版本）

- `fn`/`return` 用户自定义函数，支持递归
- 输出缓冲（4KB 运行时缓冲区，退出时 flush）
- 精确栈帧分配（占位符回填，替代固定 4096）
- 立即数优化（add/sub/cmp 直接用 `#imm` 形式）
- Tab 缩进支持（tab-stop 按 4 列对齐）
- 行内注释支持
- 测试增至 21 个

### v0.3

- `elif` 条件链
- `and`/`or`/`not` 布尔运算（短路求值）
- `break`/`continue` 循环控制
- `for` 循环表达式边界
- 修复 `output` 字符串变量输出为空
- 修复错误信息显示 line 0

### v0.2

- `let` 变量声明与赋值（整数、字符串）
- `if`/`else` 条件分支
- `while` 循环
- `for x in start..end` 范围循环
- 算术运算：`+` `-` `*` `/` `%`
- 比较运算：`==` `!=` `<` `>` `<=` `>=`
- `input_num()` / `input_str()` 标准输入
- 模块化编译器架构

### v0.1

- `legna:` 程序入口块
- `output "string"` 标准输出
- `#` 单行注释
- 字符串转义序列
- macOS ARM64 平台支持

---

## 14. 附录：EBNF 文法

```ebnf
program      = { fn_def } entry_block ;

fn_def       = "fn" IDENT "(" [ param_list ] ")" ":" NEWLINE
               INDENT { statement } DEDENT ;

param_list   = IDENT { "," IDENT } ;

entry_block  = "legna" ":" NEWLINE
               INDENT { statement } DEDENT ;

statement    = let_stmt
             | assign_stmt
             | output_stmt
             | if_stmt
             | while_stmt
             | for_stmt
             | return_stmt
             | break_stmt
             | continue_stmt
             | fn_call_stmt
             | comment
             | NEWLINE ;

let_stmt     = "let" IDENT "=" expression NEWLINE ;
assign_stmt  = IDENT "=" expression NEWLINE ;
output_stmt  = "output" ( expression | STRING ) NEWLINE ;
return_stmt  = "return" expression NEWLINE ;
break_stmt   = "break" NEWLINE ;
continue_stmt = "continue" NEWLINE ;
fn_call_stmt = IDENT "(" [ arg_list ] ")" NEWLINE ;

if_stmt      = "if" condition ":" NEWLINE
               INDENT { statement } DEDENT
               { "elif" condition ":" NEWLINE
                 INDENT { statement } DEDENT }
               [ "else" ":" NEWLINE
                 INDENT { statement } DEDENT ] ;

while_stmt   = "while" condition ":" NEWLINE
               INDENT { statement } DEDENT ;

for_stmt     = "for" IDENT "in" expression ".." expression ":" NEWLINE
               INDENT { statement } DEDENT ;

condition    = cond_term { "or" cond_term } ;
cond_term    = cond_atom { "and" cond_atom } ;
cond_atom    = [ "not" ] expression comp_op expression ;
comp_op      = "==" | "!=" | "<" | ">" | "<=" | ">=" ;

expression   = term { ( "+" | "-" ) term } ;
term         = factor { ( "*" | "/" | "%" ) factor } ;
factor       = INTEGER
             | STRING
             | IDENT
             | IDENT "(" [ arg_list ] ")"
             | "input_num" "(" ")"
             | "input_str" "(" ")"
             | "(" expression ")"
             | "-" factor ;

arg_list     = expression { "," expression } ;

comment      = "#" { ANY_CHAR } NEWLINE ;
```

---

> **Legna** — 让代码回归本质。
