# 第 7 章：控制流

> [← 表达式](06-expressions.md) | [返回目录](README.md) | [函数 →](08-functions.md)

---

## 7.1 条件语句

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

## 7.2 while 循环

```legna
let x = 5
while x > 0:
    output x
    output " "
    x = x - 1
```

输出：`5 4 3 2 1 `

## 7.3 for 循环

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

## 7.4 break 与 continue

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

> [← 表达式](06-expressions.md) | [返回目录](README.md) | [函数 →](08-functions.md)
