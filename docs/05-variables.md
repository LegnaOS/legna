# 第 5 章：变量与赋值

> [← 类型系统](04-types.md) | [返回目录](README.md) | [表达式 →](06-expressions.md)

---

## 5.1 变量声明

使用 `let` 声明变量，类型自动推断：

```legna
let x = 10           # 整数
let name = "Legna"   # 字符串
let y = x + 5        # 表达式
let z = input_num()  # 从标准输入读取
```

## 5.2 变量赋值

已声明的变量可以重新赋值：

```legna
let x = 1
x = x + 1
output x    # 输出 2
```

## 5.3 作用域

- `legna:` 块内的变量为全局作用域
- 函数参数和函数体内的变量为局部作用域，函数返回后销毁
- 不支持嵌套作用域或闭包

---

> [← 类型系统](04-types.md) | [返回目录](README.md) | [表达式 →](06-expressions.md)
