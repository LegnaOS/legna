# 第 13 章：版本历史

> [← 错误信息参考](12-errors.md) | [返回目录](README.md) | [EBNF 文法 →](14-grammar.md)

---

## v0.8（当前版本）

- 多文件编译：`import "math"` 语法，编译器自动编译库文件并链接
- 库模式：纯 `fn` 定义文件（无 `legna:` 块）编译为 `.o` 对象文件
- 标准库 4 个模块：
  - `math`：abs, min, max, clamp, pow, sign, gcd, lcm, factorial, fib, sqrt_int, is_prime, mod, div_ceil
  - `string`：str_eq, str_contains, is_digit, is_alpha, to_upper, to_lower, is_alnum, is_space, is_upper, is_lower, is_print, is_hex, hex_val, digit_val
  - `bits`：shl, shr, bit_get, bit_set, bit_clear, bit_and, bit_or, bit_xor, bit_not, popcount
  - `conv`：to_hex_digit, from_hex_digit, to_bin_digit
- 多文件链接：`_run_ld_multi` 支持链接主文件 + 多个库 `.o`
- 函数符号导出：所有 `fn` 定义自动 emit `.globl _uf_<name>`
- 盲调用：有 import 时，未知函数信任链接器解析
- 新增测试 7 个，40/40 全部通过

## v0.7

- 大立即数支持：`movz`/`movk` 指令序列，突破 65535 限制，支持完整 64 位整数
- 增强赋值运算符：`+=` `-=` `*=` 语法糖
- 固定大小数组：`let arr = array(N)`，支持 `arr[i]` 读写和动态索引
- 字符串内建函数：`len(s)`、`char_at(s, i)`、`to_num(s)`
- 新增测试 8 个（bignum、augassign、array、array_loop、strlen、charat、tonum、bubblesort）
- 综合验证：用数组实现冒泡排序，33/33 测试全部通过

## v0.6

- 窥孔优化：`_out_pos` 回退技术消除冗余 push/pop 指令
- 立即数路径死代码消除（擦除无用 `mov`，`pop` 直接到 x0）
- 简单变量右操作数优化（`ldr x1` 直接加载，跳过 push/pop）
- 条件比较优化（`cmp x0, #imm` / `cmp x0, x1` 直接比较）
- for 循环边界直接比较（每次迭代省 2 条指令）
- 单参数函数调用优化（跳过无意义的 push+pop 往返）
- 乘除模运算优化（新增反向操作数片段 `_fg_mul_r` 等）
- fib(35) 递归性能：从比 C -O0 慢 60% → 比 C -O0 快 27%

## v0.5

- `spawn`/`wait` 多进程并发（fork 进程模型）
- `pipe`/`send`/`recv` 管道 IPC（JSON Lines 格式）
- `emit` 结构化输出（JSON Lines，AI 原生亲和）
- `open`/`close`/`read_line`/`write_line` 文件 I/O
- AI 原生亲和设计：输出默认结构化，天然适配 agent 工作流
- 新增测试 ~12 个

## v0.4

- `fn`/`return` 用户自定义函数，支持递归
- 输出缓冲（4KB 运行时缓冲区，退出时 flush）
- 精确栈帧分配（占位符回填，替代固定 4096）
- 立即数优化（add/sub/cmp 直接用 `#imm` 形式）
- Tab 缩进支持（tab-stop 按 4 列对齐）
- 行内注释支持
- 测试增至 21 个

## v0.3

- `elif` 条件链
- `and`/`or`/`not` 布尔运算（短路求值）
- `break`/`continue` 循环控制
- `for` 循环表达式边界
- 修复 `output` 字符串变量输出为空
- 修复错误信息显示 line 0

## v0.2

- `let` 变量声明与赋值（整数、字符串）
- `if`/`else` 条件分支
- `while` 循环
- `for x in start..end` 范围循环
- 算术运算：`+` `-` `*` `/` `%`
- 比较运算：`==` `!=` `<` `>` `<=` `>=`
- `input_num()` / `input_str()` 标准输入
- 模块化编译器架构

## v0.1

- `legna:` 程序入口块
- `output "string"` 标准输出
- `#` 单行注释
- 字符串转义序列
- macOS ARM64 平台支持

---

> [← 错误信息参考](12-errors.md) | [返回目录](README.md) | [EBNF 文法 →](14-grammar.md)
