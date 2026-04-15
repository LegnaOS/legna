# 第 8 章：函数

> [← 控制流](07-control-flow.md) | [返回目录](README.md) | [输入输出 →](09-io.md)

---

## 8.1 函数定义

使用 `fn` 关键字定义函数，函数必须在 `legna:` 块之前声明：

```legna
fn add(a, b):
    return a + b

legna:
    let x = add(3, 4)
    output x    # 输出 7
```

## 8.2 参数传递

参数通过 ARM64 寄存器 x0-x7 传递（最多 8 个参数），均为整数类型：

```legna
fn max(a, b):
    if a > b:
        return a
    return b
```

## 8.3 返回值

`return expr` 将表达式结果放入 x0 寄存器并返回调用者。函数末尾没有显式 `return` 时，返回值未定义。

## 8.4 递归

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

## 8.5 函数调用

函数可以在表达式中调用（有返回值）或作为独立语句调用（忽略返回值）：

```legna
fn greet():
    output "hello\n"

legna:
    greet()              # 语句调用
    let x = factorial(5) # 表达式调用
```

## 8.6 外部函数（FFI）

使用 `extern fn` 声明 C/C++ 函数，通过 `link` 指定链接库或 `.o` 文件：

```legna
extern fn puts(s)
extern fn abs(x)
extern fn malloc(size)
link "lua"
link "/tmp/mylib.o"

legna:
    puts("hello from C")
    output abs(0 - 42)
```

- `extern fn` 声明的函数直接调用 libc 或外部库符号
- `link "name"` 添加 `-lname` 链接参数
- `link "path.o"` 直接链接 `.o` 文件
- 字符串字面量自动 null-terminated，兼容 C 字符串
- import/extern/link 可任意顺序混合声明

## 8.7 函数指针与高阶函数

函数名可以作为值传递，存储在变量中，或作为参数传递给其他函数：

```legna
fn double(x):
    return x * 2

fn apply(f, x):
    return f(x)

legna:
    output apply(double, 5)   # 10
    let f = double
    output f(10)               # 20
```

函数指针通过 `adrp`/`add` 加载函数地址，间接调用通过 `blr` 指令实现。

## 8.8 方法调用

结构体变量可以用 `.method()` 语法调用函数，所有字段自动展开为参数：

```legna
struct point:
    x
    y

fn magnitude(px, py):
    return px * px + py * py

legna:
    let p = point(3, 4)
    output p.magnitude()    # → magnitude(3, 4) = 25
```

`p.method(extra)` 展开为 `method(p.x, p.y, extra)`。

---

> [← 控制流](07-control-flow.md) | [返回目录](README.md) | [输入输出 →](09-io.md)
