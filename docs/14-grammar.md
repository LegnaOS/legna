# 第 14 章：EBNF 文法

> [← 版本历史](13-changelog.md) | [返回目录](README.md)

---

```ebnf
program      = { import_stmt } { fn_def } entry_block ;

import_stmt  = "import" STRING NEWLINE ;

fn_def       = "fn" IDENT "(" [ param_list ] ")" ":" NEWLINE
               INDENT { statement } DEDENT ;

param_list   = IDENT { "," IDENT } ;

entry_block  = "legna" ":" NEWLINE
               INDENT { statement } DEDENT ;

statement    = let_stmt
             | assign_stmt
             | output_stmt
             | emit_stmt
             | send_stmt
             | recv_stmt
             | close_stmt
             | write_line_stmt
             | if_stmt
             | while_stmt
             | for_stmt
             | return_stmt
             | break_stmt
             | continue_stmt
             | fn_call_stmt
             | comment
             | NEWLINE ;

let_stmt     = "let" IDENT "=" expression NEWLINE
             | "let" IDENT "=" "array" "(" INTEGER ")" NEWLINE
             | "let" IDENT "=" spawn_expr ;
assign_stmt  = IDENT "=" expression NEWLINE
             | IDENT ( "+=" | "-=" | "*=" ) expression NEWLINE
             | IDENT "[" expression "]" "=" expression NEWLINE ;
output_stmt  = "output" ( expression | STRING ) NEWLINE ;
emit_stmt    = "emit" STRING expression NEWLINE ;
send_stmt    = "send" IDENT STRING expression NEWLINE ;
recv_stmt    = "recv" IDENT IDENT IDENT NEWLINE ;
close_stmt   = "close" "(" expression ")" NEWLINE ;
write_line_stmt = "write_line" expression ( expression | STRING ) NEWLINE ;
return_stmt  = "return" expression NEWLINE ;
break_stmt   = "break" NEWLINE ;
continue_stmt = "continue" NEWLINE ;
fn_call_stmt = IDENT "(" [ arg_list ] ")" NEWLINE ;

spawn_expr   = "spawn" ":" NEWLINE
               INDENT { statement } DEDENT ;

if_stmt      = "if" condition ":" NEWLINE
               INDENT { statement } DEDENT
               { "elif" condition ":" NEWLINE
                 INDENT { statement } DEDENT }
               [ "else" ":" NEWLINE
                 INDENT { statement } DEDENT ] ;

while_stmt   = "while" condition ":" NEWLINE
               INDENT { statement } DEDENT ;

for_stmt     = "for" IDENT "in" expression ".." expression ":" NEWLINE
               INDENT { statement } DEDENT ;

condition    = cond_term { "or" cond_term } ;
cond_term    = cond_atom { "and" cond_atom } ;
cond_atom    = [ "not" ] expression comp_op expression ;
comp_op      = "==" | "!=" | "<" | ">" | "<=" | ">=" ;

expression   = term { ( "+" | "-" ) term } ;
term         = factor { ( "*" | "/" | "%" ) factor } ;
factor       = INTEGER
             | STRING
             | IDENT
             | IDENT "(" [ arg_list ] ")"
             | IDENT "[" expression "]"
             | "input_num" "(" ")"
             | "input_str" "(" ")"
             | "len" "(" IDENT ")"
             | "char_at" "(" IDENT "," expression ")"
             | "to_num" "(" IDENT ")"
             | "pipe" "(" ")"
             | "open" "(" STRING "," STRING ")"
             | "read_line" "(" expression ")"
             | "wait" "(" expression ")"
             | "(" expression ")"
             | "-" factor ;

arg_list     = expression { "," expression } ;

comment      = "#" { ANY_CHAR } NEWLINE ;
```

---

> **Legna** — 让代码回归本质。

> [← 版本历史](13-changelog.md) | [返回目录](README.md)
