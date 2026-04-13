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
```

括号 `()` 可以改变运算优先级。

## 6.2 比较表达式

比较运算符用于条件判断，返回布尔结果（内部为整数 0/1）：

```legna
if x > 5:
    output "big\n"
if a == b:
    output "equal\n"
```

## 6.3 布尔表达式

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
