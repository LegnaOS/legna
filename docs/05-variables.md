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

### 增强赋值

支持 `+=`、`-=`、`*=` 语法糖：

```legna
let x = 10
x += 5     # x = 15
x -= 3     # x = 12
x *= 2     # x = 24
```

## 5.3 数组

使用 `array(N)` 声明固定大小数组，通过 `[]` 索引读写：

```legna
let arr = array(5)
arr[0] = 42
arr[1] = arr[0] + 1
output arr[1]           # 输出 43
```

索引可以是任意表达式：

```legna
for i in 0..5:
    arr[i] = i * i
```

## 5.4 作用域

- `legna:` 块内的变量为全局作用域
- 函数参数和函数体内的变量为局部作用域，函数返回后销毁
- 不支持嵌套作用域或闭包

---

> [← 类型系统](04-types.md) | [返回目录](README.md) | [表达式 →](06-expressions.md)
