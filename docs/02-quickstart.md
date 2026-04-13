# 第 2 章：快速入门

> [← 前言与设计哲学](01-introduction.md) | [返回目录](README.md) | [词法结构 →](03-lexical.md)

---

## 2.1 Hello World

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

## 2.2 变量与运算

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

## 2.3 函数与递归

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

## 2.4 编译命令

```bash
# 基本用法
./legnac source.legna -o output_name

# 省略 -o 时，输出文件名 = 源文件名去掉 .legna
./legnac hello.legna
```

## 2.5 结构化输出

`emit` 输出 JSON Lines 格式，天然适配 AI agent：

```legna
legna:
    emit "status" "ok"
    emit "count" 42
```

输出：

```json
{"status":"ok"}
{"count":42}
```

## 2.6 文件操作

```legna
legna:
    let fd = open("data.txt", "r")
    let line = read_line(fd)
    output line
    close(fd)
```

## 2.7 并发

```legna
legna:
    let pid = spawn:
        output "child process\n"
    let status = wait(pid)
```

---

> [← 前言与设计哲学](01-introduction.md) | [返回目录](README.md) | [词法结构 →](03-lexical.md)
