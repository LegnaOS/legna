# 第 16 章：AI 原生设计

> [← 多进程并发](15-concurrency.md) | [返回目录](README.md)

---

Legna 从 v0.5 起将 AI 亲和性作为核心设计原则。语言的输入输出默认结构化，天然适配 AI agent 的工作流。

## 16.1 设计理念

传统编程语言的 I/O 面向人类：自由格式文本、彩色终端输出、交互式提示。这些对 AI agent 来说是噪音——需要正则表达式、模糊匹配、甚至视觉识别才能解析。

Legna 的 AI 原生设计原则：

- **输出即数据** — `emit` 产生的每一行都是合法 JSON，零解析成本
- **输入可预测** — 结构化输入格式，无需猜测分隔符
- **错误可机读** — 错误信息包含行号，格式固定
- **管道即协议** — 进程间通信使用 JSON Lines，天然支持流式处理

## 16.2 JSON Lines 格式规范

Legna 的结构化 I/O 遵循 [JSON Lines](https://jsonlines.org/) 规范：

```
{"key":value}\n
```

规则：

- 每行恰好一个 JSON 对象
- 对象只有一个键值对
- key 始终是双引号字符串
- value 是整数（无引号）或字符串（双引号）
- 字符串中的 `"` 转义为 `\"`，`\` 转义为 `\\`
- 行以 `\n` 结尾

示例输出：

```json
{"status":"ok"}
{"count":42}
{"message":"hello \"world\""}
```

## 16.3 emit 使用模式

### 状态报告

```legna
legna:
    emit "phase" "init"
    # ... 初始化工作 ...
    emit "phase" "processing"
    # ... 处理工作 ...
    emit "phase" "done"
    emit "exit_code" 0
```

### 数据输出

```legna
legna:
    for i in 1..11:
        emit "value" i * i
```

输出：

```json
{"value":1}
{"value":4}
{"value":9}
...
{"value":100}
```

### 错误报告

```legna
legna:
    let fd = open("missing.txt", "r")
    if fd < 0:
        emit "error" "file not found"
        emit "file" "missing.txt"
```

## 16.4 Agent 集成模式

### Python 包装

```python
import json
import subprocess

def run_legna(program, input_data=None):
    result = subprocess.run(
        ["./legnac_output"],
        input=input_data,
        capture_output=True,
        text=True
    )
    records = []
    for line in result.stdout.strip().split("\n"):
        if line:
            records.append(json.loads(line))
    return records

# 使用
data = run_legna("analyze.legna")
for record in data:
    print(record)
```

### Shell 包装

```bash
# 提取特定字段
./my_program | jq -r 'select(.status) | .status'

# 过滤错误
./my_program | jq -r 'select(.error) | .error'

# 统计数值
./my_program | jq -s '[.[].value] | add'
```

### AI Agent 循环

```python
# AI agent 调用 Legna 程序并解析结果
output = run_legna("task.legna")
for record in output:
    key = list(record.keys())[0]
    value = record[key]
    if key == "status" and value == "error":
        # 自动重试或调整参数
        pass
    elif key == "result":
        # 处理结果
        pass
```

## 16.5 管道链模式

多个 Legna 进程可以通过 Unix 管道串联，形成数据处理流水线：

```bash
# 生成数据 → 处理 → 汇总
./generate | ./process | ./summarize
```

每个程序用 `emit` 输出、用 `input_str()` 或 `recv` 读取，JSON Lines 格式在管道间无缝传递。

```legna
# generate.legna — 数据生成器
legna:
    for i in 1..101:
        emit "value" i

# process.legna — 数据处理器（读 stdin，写 stdout）
legna:
    let line = input_str()
    while line != "":
        # 解析并处理每行 JSON
        emit "processed" 1
        line = input_str()
```

这种模式让 AI agent 可以灵活组合小型 Legna 程序，构建复杂的数据处理流水线。

---

> **Legna** — 让代码回归本质，让 AI 理解一切。

> [← 多进程并发](15-concurrency.md) | [返回目录](README.md)
