# 第 12 章：错误信息参考

> [← 完整示例](11-examples.md) | [返回目录](README.md) | [版本历史 →](13-changelog.md)

---

| 错误信息 | 原因 | 解决方法 |
|----------|------|----------|
| `usage: legnac <file.legna> [-o output]` | 未提供源文件参数 | 指定 `.legna` 源文件路径 |
| `error: cannot open source file` | 源文件不存在或无读取权限 | 检查文件路径和权限 |
| `error: unexpected token at line N` | 语法错误 | 检查第 N 行的拼写和缩进 |
| `error: undefined variable at line N` | 使用了未声明的变量或函数 | 先用 `let` 声明或定义 `fn` |
| `error: assembler failed` | 生成的汇编代码有误 | 这是编译器 bug，请报告 |
| `error: linker failed` | 链接阶段失败 | 检查系统工具链（`as`、`ld`） |
| `error: cannot open file at line N` | 运行时文件打开失败 | 检查文件路径和权限 |
| `error: pipe failed at line N` | 管道创建失败 | 系统资源不足 |
| `error: fork failed at line N` | 进程创建失败 | 系统资源不足或进程数达上限 |

错误信息包含行号，指向源文件中出错的位置。

---

> [← 完整示例](11-examples.md) | [返回目录](README.md) | [版本历史 →](13-changelog.md)
