# 第 4 章：类型系统

> [← 词法结构](03-lexical.md) | [返回目录](README.md) | [变量与赋值 →](05-variables.md)

---

Legna 有四种数据类型，在声明时自动推断：

## 4.1 整数（int）

64 位有符号整数。所有算术运算、比较运算的操作数和结果都是整数。

```legna
let x = 42
let y = -7
let z = x + y * 2    # z = 28
```

## 4.2 字符串（str）

字符串由指针和长度组成，存储在栈上。字符串变量通过字面量赋值或 `input_str()` 获取。

```legna
let name = "Legna"
let greeting = input_str()
output name
```

字符串变量不支持拼接或修改，只能整体输出。

## 4.3 管道（pipe）

管道句柄由 `pipe()` 创建，包含读端和写端两个文件描述符。管道用于 `spawn` 子进程与父进程之间的通信。

```legna
let p = pipe()
# p 包含读端和写端，用于 send/recv
```

管道句柄只能用于 `send` 和 `recv` 操作，不能参与算术运算。

## 4.4 文件描述符（fd）

文件描述符是整数类型，由 `open()` 返回。用于 `read_line`、`write_line` 和 `close` 操作。

```legna
let fd = open("data.txt", "r")
let line = read_line(fd)
close(fd)
```

文件描述符本质上是整数，但语义上代表一个打开的文件句柄。

---

> [← 词法结构](03-lexical.md) | [返回目录](README.md) | [变量与赋值 →](05-variables.md)
