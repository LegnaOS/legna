# 第 15 章：多进程并发

> [← EBNF 文法](14-grammar.md) | [返回目录](README.md) | [AI 原生设计 →](16-ai-native.md)

---

Legna 使用基于 fork 的进程模型实现并发。每个 `spawn` 块创建一个独立的子进程，父子进程通过管道（pipe）进行结构化通信。

## 15.1 进程模型概述

Legna 的并发模型是**共享无状态**的多进程架构：

- `spawn` 创建子进程（通过 `fork` 系统调用）
- 子进程拥有父进程内存的完整副本，但修改互不影响
- 进程间通过 `pipe` 管道通信，数据格式为 JSON Lines
- `wait` 等待子进程结束并获取退出码

这种模型的优势：
- 无需锁、互斥量、原子操作等同步原语
- 子进程崩溃不影响父进程
- 天然避免数据竞争

## 15.2 spawn 块

`spawn` 创建子进程执行一个代码块，返回子进程的 PID：

```legna
let pid = spawn:
    output "I am the child\n"
    # 子进程在块结束时自动退出
```

**语义：**
- `spawn:` 后接缩进块，块内代码在子进程中执行
- 父进程获得子进程 PID，存入变量
- 子进程执行完块内代码后自动退出（exit code 0）
- 父进程在 `spawn:` 之后立即继续执行

**输出缓冲：** `spawn` 前会自动 flush 父进程的输出缓冲区，确保子进程不会重复输出父进程的缓冲内容。

## 15.3 wait

`wait` 等待指定子进程结束，返回退出码：

```legna
let pid = spawn:
    output "working...\n"

# 阻塞等待子进程结束
let status = wait(pid)
# status == 0 表示正常退出
```

**注意：** 每个 `spawn` 都应该有对应的 `wait`，否则子进程会变成僵尸进程。

## 15.4 pipe

`pipe` 创建一个管道，用于父子进程间的双向通信：

```legna
let p = pipe()
```

管道包含读端和写端两个文件描述符。`pipe()` 必须在 `spawn` 之前调用，这样父子进程都能访问同一个管道。

## 15.5 send / recv

`send` 向管道写入一条 JSON Line，`recv` 从管道读取并解析：

```legna
# 子进程发送数据
send p "key" value

# 父进程接收数据
recv p key_var val_var
```

**send 语法：** `send <pipe> <key_string> <value_expr>`
- key 必须是字符串字面量
- value 可以是整数表达式或字符串
- 写入格式：`{"key":value}\n`

**recv 语法：** `recv <pipe> <key_var> <val_var>`
- 从管道读取一行 JSON
- 解析 key 存入第一个变量（字符串）
- 解析 value 存入第二个变量（整数或字符串）

## 15.6 完整示例：并发 Worker Pool

```legna
fn worker(p, id, n):
    let result = 0
    for i in 0..n:
        result = result + i
    send p "worker_id" id
    send p "sum" result

legna:
    let p = pipe()

    # 启动 3 个 worker
    let w1 = spawn:
        worker(p, 1, 100)
    let w2 = spawn:
        worker(p, 2, 200)
    let w3 = spawn:
        worker(p, 3, 300)

    # 收集所有结果
    let key = ""
    let val = 0
    for i in 0..6:
        recv p key val
        emit key val

    # 等待所有 worker 结束
    wait(w1)
    wait(w2)
    wait(w3)
```

---

> [← EBNF 文法](14-grammar.md) | [返回目录](README.md) | [AI 原生设计 →](16-ai-native.md)
