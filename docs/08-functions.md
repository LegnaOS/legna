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

---

> [← 控制流](07-control-flow.md) | [返回目录](README.md) | [输入输出 →](09-io.md)
