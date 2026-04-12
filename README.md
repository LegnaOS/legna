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

## 项目结构

```
legna/
├── src/
│   └── legnac_darwin_arm64.s   # 编译器源码（纯 ARM64 汇编）
├── docs/
│   ├── README.md               # 文档索引
│   └── legna-spec.md           # 语言规范 v0.1
├── tests/
│   ├── run_tests.sh            # 自动化测试
│   ├── escape.legna            # 转义序列测试
│   ├── multiline.legna         # 多行输出测试
│   ├── comments.legna          # 注释测试
│   └── empty.legna             # 空字符串测试
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

完整语言规范见 [docs/legna-spec.md](docs/legna-spec.md)

## 测试

```bash
make test
```

## 许可证

MIT
