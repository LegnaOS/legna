# 第 11 章：完整示例

> [← 编译器架构](10-compiler.md) | [返回目录](README.md) | [错误信息参考 →](12-errors.md)

---

## 11.1 FizzBuzz

```legna
legna:
    for i in 1..16:
        let m3 = i % 3
        let m5 = i % 5
        if m3 == 0:
            if m5 == 0:
                output "FizzBuzz\n"
            else:
                output "Fizz\n"
        else:
            if m5 == 0:
                output "Buzz\n"
            else:
                output i
                output "\n"
```

## 11.2 阶乘（递归）

```legna
fn factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

legna:
    output "10! = "
    output factorial(10)
    output "\n"
```

输出：`10! = 3628800`

## 11.3 斐波那契数列

```legna
fn fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)

legna:
    for i in 0..10:
        output fib(i)
        output " "
    output "\n"
```

输出：`0 1 1 2 3 5 8 13 21 34`

## 11.4 猜数字游戏

```legna
legna:
    let secret = 42
    let guess = 0
    while guess != secret:
        output "guess a number: "
        guess = input_num()
        if guess < secret:
            output "too low\n"
        elif guess > secret:
            output "too high\n"
        else:
            output "correct!\n"
```

## 11.5 AI Agent 文件处理器

读取文件、统计行数，以 JSON Lines 格式输出结果：

```legna
fn count_lines(fd):
    let count = 0
    let line = read_line(fd)
    while line != "":
        count = count + 1
        line = read_line(fd)
    return count

legna:
    let fd = open("data.txt", "r")
    let n = count_lines(fd)
    close(fd)
    emit "file" "data.txt"
    emit "lines" n
    emit "status" "ok"
```

输出：

```json
{"file":"data.txt"}
{"lines":42}
{"status":"ok"}
```

## 11.6 冒泡排序（数组）

```legna
legna:
    let arr = array(5)
    arr[0] = 5
    arr[1] = 3
    arr[2] = 8
    arr[3] = 1
    arr[4] = 4
    for i in 0..4:
        for j in 0..4:
            if arr[j] > arr[j + 1]:
                let tmp = arr[j]
                arr[j] = arr[j + 1]
                arr[j + 1] = tmp
    for i in 0..5:
        output arr[i]
        if i < 4:
            output " "
```

输出：`1 3 4 5 8`

## 11.7 并发 Worker

多个子进程并行工作，通过管道汇报结果：

```legna
fn process(p, id):
    let result = id * id
    send p "worker" id
    send p "result" result

legna:
    let p = pipe()

    let w1 = spawn:
        process(p, 1)
    let w2 = spawn:
        process(p, 2)
    let w3 = spawn:
        process(p, 3)

    # 收集结果
    let key = ""
    let val = 0
    for i in 0..6:
        recv p key val
        emit key val

    wait(w1)
    wait(w2)
    wait(w3)
```

---

> [← 编译器架构](10-compiler.md) | [返回目录](README.md) | [错误信息参考 →](12-errors.md)
