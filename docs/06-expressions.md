# 第 6 章：表达式

> [← 变量与赋值](05-variables.md) | [返回目录](README.md) | [控制流 →](07-control-flow.md)

---

## 6.1 算术表达式

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
let big = 100000 + 1    # 大立即数（超过 65535 自动使用 movz/movk）
```

括号 `()` 可以改变运算优先级。

### 增强赋值

`+=`、`-=`、`*=` 是赋值的语法糖：

```legna
x += 5     # 等价于 x = x + 5
x -= 3     # 等价于 x = x - 3
x *= 2     # 等价于 x = x * 2
```

## 6.2 数组索引

数组元素通过 `[]` 访问，索引可以是任意表达式：

```legna
let arr = array(5)
arr[0] = 42
let x = arr[0]           # 读取
arr[i + 1] = arr[i] * 2  # 索引为表达式
```

## 6.3 字符串内建函数

| 函数 | 说明 | 返回类型 |
|------|------|----------|
| `len(s)` | 字符串长度（字节数） | 整数 |
| `char_at(s, i)` | 第 i 个字节的 ASCII 值 | 整数 |
| `to_num(s)` | 数字字符串转整数 | 整数 |

```legna
let s = "hello"
let n = len(s)           # 5
let c = char_at(s, 0)    # 104 ('h')
let x = to_num("123")    # 123
```

## 6.4 比较表达式

比较运算符用于条件判断，返回布尔结果（内部为整数 0/1）：

```legna
if x > 5:
    output "big\n"
if a == b:
    output "equal\n"
```

## 6.5 布尔表达式

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

> [← 变量与赋值](05-variables.md) | [返回目录](README.md) | [控制流 →](07-control-flow.md)
