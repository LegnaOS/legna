// ============================================================
// defs.inc - Shared constants for legnac v0.5
// Include this in every .s file: .include "defs.inc"
// ============================================================

// Syscall numbers (macOS ARM64)
.equ SYS_EXIT,    1
.equ SYS_FORK,    2
.equ SYS_READ,    3
.equ SYS_WRITE,   4
.equ SYS_OPEN,    5
.equ SYS_CLOSE,   6
.equ SYS_WAIT4,   7
.equ SYS_UNLINK,  10
.equ SYS_GETPID,  20
.equ SYS_EXECVE,  59
.equ SYS_PIPE,    42

.equ O_RDONLY,     0
.equ O_WRCREAT,   0x601
.equ STDOUT,      1
.equ STDERR,      2
.equ BUF_SIZE,    65536
.equ MAX_TOKENS,  4096
.equ TOK_SIZE,    24
.equ MAX_SYMS,    128
.equ SYM_SIZE,    32
.equ MAX_STRS,    256
.equ FRAME_MAX,   4096

// Token types
.equ TOK_EOF,       0
.equ TOK_NL,        1
.equ TOK_INDENT,    2
.equ TOK_DEDENT,    3
.equ TOK_IDENT,     4
.equ TOK_INT,       5
.equ TOK_STR,       6
.equ TOK_KW_LEGNA,  7
.equ TOK_KW_OUTPUT, 8
.equ TOK_KW_LET,    9
.equ TOK_KW_IF,     10
.equ TOK_KW_ELSE,   11
.equ TOK_KW_WHILE,  12
.equ TOK_KW_FOR,    13
.equ TOK_KW_IN,     14
.equ TOK_KW_INNUM,  15
.equ TOK_KW_INSTR,  16
.equ TOK_COLON,     17
.equ TOK_LPAREN,    18
.equ TOK_RPAREN,    19
.equ TOK_PLUS,      20
.equ TOK_MINUS,     21
.equ TOK_STAR,      22
.equ TOK_SLASH,     23
.equ TOK_EQ,        24
.equ TOK_NEQ,       25
.equ TOK_LT,        26
.equ TOK_GT,        27
.equ TOK_LTE,       28
.equ TOK_GTE,       29
.equ TOK_ASSIGN,    30
.equ TOK_DOTDOT,    31
.equ TOK_MOD,       32
.equ TOK_KW_ELIF,   33
.equ TOK_KW_BREAK,  34
.equ TOK_KW_CONT,   35
.equ TOK_KW_AND,    36
.equ TOK_KW_OR,     37
.equ TOK_KW_NOT,    38
.equ TOK_KW_FN,     39
.equ TOK_KW_RETURN, 40
.equ TOK_COMMA,     41

// v0.5: Concurrency + AI-native I/O
.equ TOK_KW_SPAWN,  42
.equ TOK_KW_WAIT,   43
.equ TOK_KW_PIPE,   44
.equ TOK_KW_SEND,   45
.equ TOK_KW_RECV,   46
.equ TOK_KW_EMIT,   47
.equ TOK_KW_OPEN,   48
.equ TOK_KW_CLOSE,  49
.equ TOK_KW_RDLINE, 50
.equ TOK_KW_WRLINE, 51

// v0.7: Augmented assignment
.equ TOK_PLUS_EQ,   52
.equ TOK_MINUS_EQ,  53
.equ TOK_STAR_EQ,   54

// v0.7: Arrays
.equ TOK_KW_ARRAY,  55
.equ TOK_LBRACKET,  56
.equ TOK_RBRACKET,  57

// v0.7: String builtins
.equ TOK_KW_LEN,    58
.equ TOK_KW_CHARAT, 59
.equ TOK_KW_TOSTR,  60
.equ TOK_KW_TONUM,  61

// Symbol types
.equ TY_INT,        0
.equ TY_STR,        1
.equ TY_PIPE,       2
.equ TY_ARR,        3
