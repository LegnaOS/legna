# 第 4 章：类型系统

> [← 词法结构](03-lexical.md) | [返回目录](README.md) | [变量与赋值 →](05-variables.md)

---

Legna 有六种数据类型，在声明时自动推断：

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

### 字符串内建函数

```legna
let s = "hello"
let n = len(s)           # n = 5
let c = char_at(s, 0)    # c = 104 (ASCII 'h')
let x = to_num("123")    # x = 123
```

- `len(s)` — 返回字符串长度（字节数）
- `char_at(s, i)` — 返回第 i 个字节的 ASCII 值（0 索引）
- `to_num(s)` — 将数字字符串解析为整数

## 4.3 数组（array）

固定大小数组，元素为 64 位整数，栈上分配。

```legna
let arr = array(5)       # 声明大小为 5 的数组
arr[0] = 42              # 写入
let x = arr[0]           # 读取
arr[i] = arr[j] + 1      # 索引可以是任意表达式
```

数组大小必须是编译期整数常量。索引从 0 开始，不做边界检查。

## 4.4 管道（pipe）

管道句柄由 `pipe()` 创建，包含读端和写端两个文件描述符。管道用于 `spawn` 子进程与父进程之间的通信。

```legna
let p = pipe()
# p 包含读端和写端，用于 send/recv
```

管道句柄只能用于 `send` 和 `recv` 操作，不能参与算术运算。

## 4.5 文件描述符（fd）

文件描述符是整数类型，由 `open()` 返回。用于 `read_line`、`write_line` 和 `close` 操作。

```legna
let fd = open("data.txt", "r")
let line = read_line(fd)
close(fd)
```

文件描述符本质上是整数，但语义上代表一个打开的文件句柄。

## 4.6 结构体（struct）

用户自定义复合类型，栈上分配，字段为 64 位整数。

```legna
struct point:
    x
    y

legna:
    let p = point(10, 20)
    output p.x              # 10
    output p.y              # 20
    p.x = 30                # 字段写入
    output p.x              # 30
```

结构体字段偏移在编译期计算，访问效率与普通变量相同。字段数量最多 11 个。

### 方法调用

结构体变量可以用 `.method()` 语法调用函数，所有字段自动作为参数传递：

```legna
fn magnitude(px, py):
    return px * px + py * py

legna:
    let p = point(3, 4)
    output p.magnitude()    # → magnitude(3, 4) = 25
```

---

> [← 词法结构](03-lexical.md) | [返回目录](README.md) | [变量与赋值 →](05-variables.md)
