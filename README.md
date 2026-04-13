# Legna

一门极简编程语言，编译器用纯 ARM64 汇编编写，零 C 依赖。

## 快速开始

```bash
# 构建编译器
make

# 编写你的第一个程序
cat > hello.legna << 'EOF'
# hello world

legna:
    output "hello, world\n"
EOF

# 编译并运行
./legnac hello.legna -o hello
./hello
```

## 语法示例

```legna
# Legna 使用极简语法：缩进敏感，无分号，无花括号

legna:
    output "name:\tLegna\n"
    output "path: C:\\legna\n"
    output "say \"hello\"\n"
```

```legna
# AI 原生结构化输出（JSON Lines）

legna:
    emit "status" "ok"
    emit "count" 42
```

## 项目结构

```
legna/
├── src/macos_arm64/            # 编译器源码（模块化纯 ARM64 汇编）
├── docs/                       # 语言手册（多文件书籍结构）
│   ├── README.md               # 目录
│   ├── 01-introduction.md      # 前言与设计哲学
│   ├── 02-quickstart.md        # 快速入门
│   ├── 03-lexical.md           # 词法结构
│   ├── 04-types.md             # 类型系统
│   ├── 05-variables.md         # 变量与赋值
│   ├── 06-expressions.md       # 表达式
│   ├── 07-control-flow.md      # 控制流
│   ├── 08-functions.md         # 函数
│   ├── 09-io.md                # 输入输出
│   ├── 10-compiler.md          # 编译器架构
│   ├── 11-examples.md          # 完整示例
│   ├── 12-errors.md            # 错误信息参考
│   ├── 13-changelog.md         # 版本历史
│   ├── 14-grammar.md           # EBNF 文法
│   ├── 15-concurrency.md       # 多进程并发
│   └── 16-ai-native.md         # AI 原生设计
├── tests/                      # 自动化测试
├── helloworld.legna            # Hello World 示例
├── Makefile                    # 构建系统
└── .gitignore
```

## 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| macOS | ARM64 (Apple Silicon) | 已实现 |
| Linux | x86_64 | 计划中 |
| Windows | x86_64 | 计划中 |

## 文档

完整语言手册见 [docs/README.md](docs/README.md)

## 测试

```bash
make test
```

## 许可证

MIT
