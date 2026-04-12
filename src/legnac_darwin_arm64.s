// ============================================================
// legnac - The Legna Language Compiler v0.2
// Platform: macOS ARM64 (Apple Silicon)
// Pure assembly, no C runtime
// Features: variables, if/else, while, for, input/output
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

// Symbol types
.equ TY_INT,        0
.equ TY_STR,        1

// ── Data Section ──
.section __DATA,__data

// Error messages
err_usage:    .asciz "usage: legnac <file.legna> [-o output]\n"
err_open:     .asciz "error: cannot open source file\n"
err_syntax:   .asciz "error: unexpected token at line "
err_indent:   .asciz "error: bad indentation at line "
err_undef:    .asciz "error: undefined variable at line "
err_type:     .asciz "error: type mismatch at line "
err_nolegna:  .asciz "error: missing 'legna:' entry\n"
err_asm:      .asciz "error: assembler failed\n"
err_link:     .asciz "error: linker failed\n"
err_nl:       .asciz "\n"
msg_ok:       .asciz "compiled successfully\n"

// Keywords (null-terminated, for matching)
kw_legna:     .asciz "legna"
kw_output:    .asciz "output"
kw_let:       .asciz "let"
kw_if:        .asciz "if"
kw_else:      .asciz "else"
kw_while:     .asciz "while"
kw_for:       .asciz "for"
kw_in:        .asciz "in"
kw_input_num: .asciz "input_num"
kw_input_str: .asciz "input_str"

// Tool paths and linker args
path_as:      .asciz "/usr/bin/as"
path_ld:      .asciz "/usr/bin/ld"
tmp_prefix:   .asciz "/tmp/legna_"
tmp_ext_s:    .asciz ".s"
tmp_ext_o:    .asciz ".o"
lnk_o:        .asciz "-o"
lnk_lsys:    .asciz "-lSystem"
lnk_syslib:  .asciz "-syslibroot"
lnk_sdk:      .asciz "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
lnk_e:        .asciz "-e"
lnk_main:     .asciz "_main"
lnk_arch:     .asciz "-arch"
lnk_arm64:    .asciz "arm64"
lnk_dead:     .asciz "-dead_strip"
lnk_x:        .asciz "-x"

// ── Codegen fragments ──
// Header
fg_hdr:       .ascii ".global _main\n.align 2\n\n"
              .byte 0
fg_text:      .asciz ".text\n"
fg_data:      .asciz "\n.data\n"
fg_bss:       .asciz "\n.bss\n.align 4\n_input_buf: .space 1024\n_itoa_buf: .space 24\n"
fg_nl:        .asciz "\n"
fg_comma:     .asciz ", "

// Frame setup/teardown
fg_main:      .ascii "_main:\n    stp x29, x30, [sp, #-16]!\n    mov x29, sp\n    sub sp, sp, #"
              .byte 0
fg_main2:     .asciz "\n"
fg_exit:      .ascii "    mov sp, x29\n    ldp x29, x30, [sp], #16\n    mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
              .byte 0

// Variable access
fg_ldr:       .asciz "    ldr x0, [x29, #-"
fg_ldr1:      .asciz "    ldr x1, [x29, #-"
fg_str_x0:    .asciz "    str x0, [x29, #-"
fg_cb:        .asciz "]\n"
fg_mov:       .asciz "    mov x0, #"
fg_movn:      .asciz "    mov x0, #-"

// Arithmetic
fg_push:      .asciz "    str x0, [sp, #-16]!\n"
fg_pop1:      .asciz "    ldr x1, [sp], #16\n"
fg_add:       .asciz "    add x0, x1, x0\n"
fg_sub:       .asciz "    sub x0, x1, x0\n"
fg_mul:       .asciz "    mul x0, x1, x0\n"
fg_sdiv:      .asciz "    sdiv x0, x1, x0\n"
fg_mod:       .ascii "    sdiv x2, x1, x0\n    msub x0, x2, x0, x1\n"
              .byte 0

// Comparison + branch
fg_cmp0:      .asciz "    cmp x0, #"
fg_cmp1:      .asciz "    cmp x0, x1\n"
fg_ble:       .asciz "    b.le "
fg_bge:       .asciz "    b.ge "
fg_blt:       .asciz "    b.lt "
fg_bgt:       .asciz "    b.gt "
fg_bne:       .asciz "    b.ne "
fg_beq:       .asciz "    b.eq "
fg_b:         .asciz "    b "
fg_lbl:       .asciz "_L"
fg_colon:     .asciz ":\n"

// Output (write syscall)
fg_wr_fd:     .asciz "    mov x0, #1\n"
fg_wr_adrp:   .asciz "    adrp x1, "
fg_wr_add:    .asciz "    add x1, x1, "
fg_wr_len:    .asciz "    mov x2, #"
fg_wr_sys:    .ascii "    mov x16, #4\n    svc #0x80\n"
              .byte 0
fg_page:      .asciz "@PAGE\n"
fg_poff:      .asciz "@PAGEOFF\n"

// String data label
fg_sd:        .asciz "_s"
fg_sd_byte:   .asciz ": .byte "

// itoa call for integer output
fg_itoa_call: .ascii "    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    bl _rt_itoa\n    mov x2, x0\n    mov x0, #1\n    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    mov x16, #4\n    svc #0x80\n"
              .byte 0

// String var output
fg_str_out:   .ascii "    mov x0, #1\n    mov x16, #4\n    svc #0x80\n"
              .byte 0

// Input
fg_input_call: .ascii "    bl _rt_read_line\n"
               .byte 0
fg_atoi_call:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n    bl _rt_atoi\n"
               .byte 0
fg_inbuf_ptr:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n"
               .byte 0

// For loop increment
fg_add1:      .asciz "    add x0, x0, #1\n"

// ── BSS Section ──
.section __DATA,__bss

.lcomm src_buf,     BUF_SIZE
.lcomm out_buf,     BUF_SIZE
.lcomm out_name,    256
.lcomm src_len,     8
.lcomm out_pos,     8

// Token buffer: MAX_TOKENS * TOK_SIZE (24 bytes each)
// Layout per token: type(4) + len(4) + ptr(8) + value(8)
.lcomm tok_buf,     98304        // 4096 * 24
.lcomm tok_count,   4
.lcomm tok_pos,     4            // parser cursor

// Symbol table: MAX_SYMS * SYM_SIZE (32 bytes each)
// Layout: name_ptr(8) + name_len(4) + type(4) + offset(4) + pad(12)
.lcomm sym_tab,     4096         // 128 * 32
.lcomm sym_count,   4
.lcomm frame_size,  4            // current stack frame size

// Indent stack for lexer
.lcomm ind_stack,   256          // 64 levels * 4 bytes
.lcomm ind_sp,      4            // indent stack pointer

// Label counter for codegen
.lcomm lbl_count,   4

// String literal table for data section
.lcomm str_ptrs,    2048         // 256 * 8 byte pointers
.lcomm str_lens,    1024         // 256 * 4 byte lengths
.lcomm str_bytes,   1024         // 256 * 4 actual byte lengths
.lcomm str_count,   4

// Misc
.lcomm wait_stat,   4
.lcomm num_buf,     24
.lcomm tmp_path_s,  64
.lcomm tmp_path_o,  64
.lcomm line_num,    4            // current line for errors

// ── Text Section ──
.section __TEXT,__text
.global _main
.align 2

// ────────────────────────────────────────
// _main - Entry point
// ────────────────────────────────────────
_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0                 // argc
    mov x20, x1                 // argv

    cmp x19, #2
    b.lt _usage_exit

    ldr x21, [x20, #8]          // input filename

    // default output name
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    mov x1, x21
    bl _strip_ext

    // check -o flag
    cmp x19, #4
    b.lt 1f
    ldr x0, [x20, #16]
    ldrb w1, [x0]
    cmp w1, #'-'
    b.ne 1f
    ldrb w1, [x0, #1]
    cmp w1, #'o'
    b.ne 1f
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    ldr x1, [x20, #24]
    bl _strcpy
1:
    bl _build_tmp_paths

    // read source
    mov x0, x21
    bl _read_file
    cmp x0, #0
    b.lt _err_open

    // lex
    bl _lex
    cmp x0, #0
    b.lt _err_syntax_exit

    // parse + codegen
    bl _parse_program
    cmp x0, #0
    b.lt _err_syntax_exit

    // write temp .s
    bl _write_asm
    cmp x0, #0
    b.lt _err_open

    // assemble
    bl _run_as
    cmp x0, #0
    b.ne _err_asm_exit

    // link
    bl _run_ld
    cmp x0, #0
    b.ne _err_link_exit

    bl _cleanup

    adrp x0, msg_ok@PAGE
    add x0, x0, msg_ok@PAGEOFF
    bl _print_err

    mov x0, #0
    b _exit

_usage_exit:
    adrp x0, err_usage@PAGE
    add x0, x0, err_usage@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit
_err_open:
    adrp x0, err_open@PAGE
    add x0, x0, err_open@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit
_err_syntax_exit:
    mov x0, #1
    b _exit
_err_asm_exit:
    adrp x0, err_asm@PAGE
    add x0, x0, err_asm@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit
_err_link_exit:
    adrp x0, err_link@PAGE
    add x0, x0, err_link@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit

_exit:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    mov x16, #SYS_EXIT
    svc #0x80

// ── Error helper: print error with line number ──
// x0 = error message prefix, x1 = line number
_err_line:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    bl _print_err
    mov x0, x20
    adrp x1, num_buf@PAGE
    add x1, x1, num_buf@PAGEOFF
    bl _itoa
    adrp x0, num_buf@PAGE
    add x0, x0, num_buf@PAGEOFF
    bl _print_err
    adrp x0, err_nl@PAGE
    add x0, x0, err_nl@PAGEOFF
    bl _print_err
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// String helpers (reused from v0.1)
// ────────────────────────────────────────

_strlen:
    mov x1, x0
    mov x0, #0
1:  ldrb w2, [x1, x0]
    cbz w2, 2f
    add x0, x0, #1
    b 1b
2:  ret

_strcpy:
    mov x2, #0
1:  ldrb w3, [x1, x2]
    strb w3, [x0, x2]
    cbz w3, 2f
    add x2, x2, #1
    b 1b
2:  ret

// _strncmp: x0=s1, x1=s2, x2=n → x0=0 if equal
_strncmp:
    mov x3, #0
1:  cmp x3, x2
    b.ge 2f
    ldrb w4, [x0, x3]
    ldrb w5, [x1, x3]
    cmp w4, w5
    b.ne 3f
    cbz w4, 2f
    add x3, x3, #1
    b 1b
2:  mov x0, #0
    ret
3:  mov x0, #1
    ret

_print_err:
    stp x29, x30, [sp, #-16]!
    mov x1, x0
    bl _strlen
    mov x2, x0
    mov x0, #STDERR
    mov x16, #SYS_WRITE
    svc #0x80
    ldp x29, x30, [sp], #16
    ret

_strip_ext:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    bl _strcpy
    mov x0, x19
    bl _strlen
    mov x2, x0
    sub x2, x2, #1
1:  cmp x2, #0
    b.lt 2f
    ldrb w3, [x19, x2]
    cmp w3, #'.'
    b.eq 3f
    sub x2, x2, #1
    b 1b
3:  strb wzr, [x19, x2]
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _itoa: x0=number, x1=buffer → x0=length
_itoa:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    sub sp, sp, #32
    mov x21, sp                  // temp reverse buf
    mov x22, #0                  // digit count
    // handle negative
    cmp x19, #0
    b.ge 1f
    mov w3, #'-'
    strb w3, [x20], #1
    neg x19, x19
1:  cbz x19, 4f
2:  cbz x19, 3f
    mov x3, #10
    udiv x4, x19, x3
    msub x5, x4, x3, x19
    add w5, w5, #'0'
    strb w5, [x21, x22]
    add x22, x22, #1
    mov x19, x4
    b 2b
4:  mov w5, #'0'
    strb w5, [x21]
    mov x22, #1
3:  // copy reversed
    sub x22, x22, #1
    mov x3, #0
5:  ldrb w5, [x21, x22]
    strb w5, [x20, x3]
    add x3, x3, #1
    cbz x22, 6f
    sub x22, x22, #1
    b 5b
6:  strb wzr, [x20, x3]
    // compute total length
    adrp x1, num_buf@PAGE
    add x1, x1, num_buf@PAGEOFF
    mov x0, x20
    sub x0, x0, x1
    add x0, x0, x3
    add sp, sp, #32
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_build_tmp_paths:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x16, #SYS_GETPID
    svc #0x80
    mov x19, x0
    // build tmp_path_s
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    adrp x1, tmp_prefix@PAGE
    add x1, x1, tmp_prefix@PAGEOFF
    bl _strcpy
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    bl _strlen
    adrp x20, tmp_path_s@PAGE
    add x20, x20, tmp_path_s@PAGEOFF
    add x1, x20, x0
    mov x0, x19
    bl _itoa
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    bl _strlen
    add x0, x20, x0
    adrp x1, tmp_ext_s@PAGE
    add x1, x1, tmp_ext_s@PAGEOFF
    bl _strcpy
    // build tmp_path_o
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    adrp x1, tmp_prefix@PAGE
    add x1, x1, tmp_prefix@PAGEOFF
    bl _strcpy
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    bl _strlen
    adrp x20, tmp_path_o@PAGE
    add x20, x20, tmp_path_o@PAGEOFF
    add x1, x20, x0
    mov x0, x19
    bl _itoa
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    bl _strlen
    add x0, x20, x0
    adrp x1, tmp_ext_o@PAGE
    add x1, x1, tmp_ext_o@PAGEOFF
    bl _strcpy
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// Emit helpers
// ────────────────────────────────────────

_emit_str:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    adrp x20, out_pos@PAGE
    add x20, x20, out_pos@PAGEOFF
    ldr x1, [x20]
    adrp x2, out_buf@PAGE
    add x2, x2, out_buf@PAGEOFF
    add x2, x2, x1
    mov x3, #0
1:  ldrb w4, [x19, x3]
    cbz w4, 2f
    strb w4, [x2, x3]
    add x3, x3, #1
    b 1b
2:  add x1, x1, x3
    str x1, [x20]
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_emit_char:
    adrp x1, out_pos@PAGE
    add x1, x1, out_pos@PAGEOFF
    ldr x2, [x1]
    adrp x3, out_buf@PAGE
    add x3, x3, out_buf@PAGEOFF
    strb w0, [x3, x2]
    add x2, x2, #1
    str x2, [x1]
    ret

_emit_num:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    adrp x20, num_buf@PAGE
    add x20, x20, num_buf@PAGEOFF
    mov x21, #0
    // handle negative
    cmp x19, #0
    b.ge 8f
    mov w0, #'-'
    bl _emit_char
    neg x19, x19
8:  cbz x19, 3f
1:  cbz x19, 2f
    mov x3, #10
    udiv x4, x19, x3
    msub x5, x4, x3, x19
    add w5, w5, #'0'
    strb w5, [x20, x21]
    add x21, x21, #1
    mov x19, x4
    b 1b
3:  mov w5, #'0'
    strb w5, [x20]
    mov x21, #1
2:  sub x21, x21, #1
4:  ldrb w0, [x20, x21]
    bl _emit_char
    cbz x21, 5f
    sub x21, x21, #1
    b 4b
5:  ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_emit_raw:
    adrp x2, out_pos@PAGE
    add x2, x2, out_pos@PAGEOFF
    ldr x3, [x2]
    adrp x4, out_buf@PAGE
    add x4, x4, out_buf@PAGEOFF
    add x4, x4, x3
    mov x5, #0
1:  cmp x5, x1
    b.ge 2f
    ldrb w6, [x0, x5]
    strb w6, [x4, x5]
    add x5, x5, #1
    b 1b
2:  add x3, x3, x1
    str x3, [x2]
    ret

// ────────────────────────────────────────
// File I/O (reused from v0.1)
// ────────────────────────────────────────

_read_file:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    mov x0, x19
    mov x1, #O_RDONLY
    mov x2, #0
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs 1f
    mov x19, x0
    mov x0, x19
    adrp x1, src_buf@PAGE
    add x1, x1, src_buf@PAGEOFF
    mov x2, #BUF_SIZE
    mov x16, #SYS_READ
    svc #0x80
    b.cs 1f
    mov x20, x0
    adrp x1, src_len@PAGE
    add x1, x1, src_len@PAGEOFF
    str x20, [x1]
    adrp x1, src_buf@PAGE
    add x1, x1, src_buf@PAGEOFF
    strb wzr, [x1, x20]
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80
    mov x0, x20
    b 2f
1:  mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_write_asm:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    mov x1, #O_WRCREAT
    mov x2, #0x1A4
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs 1f
    mov x19, x0
    mov x0, x19
    adrp x1, out_buf@PAGE
    add x1, x1, out_buf@PAGEOFF
    adrp x2, out_pos@PAGE
    add x2, x2, out_pos@PAGEOFF
    ldr x2, [x2]
    mov x16, #SYS_WRITE
    svc #0x80
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80
    mov x0, #0
    b 2f
1:  mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ════════════════════════════════════════
// LEXER - Tokenize source into tok_buf
// ════════════════════════════════════════
// Returns x0 = token count, or -1 on error
// Registers: x19=src_ptr, x20=src_pos, x21=src_len
//   x22=tok_write_ptr, x23=tok_count, x24=line_num
//   x25=at_line_start flag

_lex:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    adrp x19, src_buf@PAGE
    add x19, x19, src_buf@PAGEOFF
    mov x20, #0                  // pos
    adrp x0, src_len@PAGE
    add x0, x0, src_len@PAGEOFF
    ldr x21, [x0]               // src_len
    adrp x22, tok_buf@PAGE
    add x22, x22, tok_buf@PAGEOFF
    mov x23, #0                  // tok count
    mov x24, #1                  // line number
    mov x25, #1                  // at line start

    // init indent stack: push 0
    adrp x0, ind_stack@PAGE
    add x0, x0, ind_stack@PAGEOFF
    str wzr, [x0]
    adrp x0, ind_sp@PAGE
    add x0, x0, ind_sp@PAGEOFF
    mov w1, #1
    str w1, [x0]                 // stack has 1 entry (value 0)

_lex_loop:
    cmp x20, x21
    b.ge _lex_eof

    // at line start? handle indentation
    cbz x25, _lex_mid_line

    mov x25, #0                  // clear flag
    // count leading spaces
    mov x26, #0                  // space count
_lex_count_sp:
    cmp x20, x21
    b.ge _lex_indent_done
    ldrb w0, [x19, x20]
    cmp w0, #' '
    b.ne _lex_indent_done
    add x26, x26, #1
    add x20, x20, #1
    b _lex_count_sp

_lex_indent_done:
    // skip blank lines
    cmp x20, x21
    b.ge _lex_do_indent
    ldrb w0, [x19, x20]
    cmp w0, #'\n'
    b.ne 1f
    // blank line - emit NL, advance
    bl _lex_emit_nl
    add x20, x20, #1
    add x24, x24, #1
    mov x25, #1
    b _lex_loop
1:  cmp w0, #'#'
    b.ne _lex_do_indent
    // comment line - skip to eol
    bl _lex_skip_comment
    b _lex_loop

_lex_do_indent:
    // compare x26 (cur indent) with stack top
    adrp x0, ind_stack@PAGE
    add x0, x0, ind_stack@PAGEOFF
    adrp x1, ind_sp@PAGE
    add x1, x1, ind_sp@PAGEOFF
    ldr w2, [x1]                 // stack size
    sub w3, w2, #1
    ldr w4, [x0, x3, lsl #2]   // stack top value

    cmp w26, w4
    b.eq _lex_mid_line           // same level
    b.gt _lex_push_indent

    // dedent: pop until match
_lex_pop_loop:
    adrp x0, ind_stack@PAGE
    add x0, x0, ind_stack@PAGEOFF
    adrp x1, ind_sp@PAGE
    add x1, x1, ind_sp@PAGEOFF
    ldr w2, [x1]
    cmp w2, #1
    b.le _lex_indent_err         // can't pop below 0
    sub w2, w2, #1
    str w2, [x1]
    // emit DEDENT
    mov w0, #TOK_DEDENT
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    // check if we match now
    adrp x0, ind_stack@PAGE
    add x0, x0, ind_stack@PAGEOFF
    adrp x1, ind_sp@PAGE
    add x1, x1, ind_sp@PAGEOFF
    ldr w2, [x1]
    sub w3, w2, #1
    ldr w4, [x0, x3, lsl #2]
    cmp w26, w4
    b.gt _lex_indent_err
    b.lt _lex_pop_loop
    b _lex_mid_line

_lex_push_indent:
    // push new indent level
    adrp x0, ind_stack@PAGE
    add x0, x0, ind_stack@PAGEOFF
    adrp x1, ind_sp@PAGE
    add x1, x1, ind_sp@PAGEOFF
    ldr w2, [x1]
    str w26, [x0, x2, lsl #2]
    add w2, w2, #1
    str w2, [x1]
    // emit INDENT
    mov w0, #TOK_INDENT
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    b _lex_mid_line

_lex_mid_line:
    cmp x20, x21
    b.ge _lex_eof

    ldrb w0, [x19, x20]

    // skip spaces mid-line
    cmp w0, #' '
    b.ne 1f
    add x20, x20, #1
    b _lex_mid_line
1:
    // newline
    cmp w0, #'\n'
    b.ne 2f
    bl _lex_emit_nl
    add x20, x20, #1
    add x24, x24, #1
    mov x25, #1
    b _lex_loop
2:
    // comment
    cmp w0, #'#'
    b.ne 3f
    bl _lex_skip_comment
    b _lex_loop
3:
    // string literal
    cmp w0, #'"'
    b.ne 4f
    bl _lex_string
    b _lex_loop
4:
    // digit → integer literal
    sub w1, w0, #'0'
    cmp w1, #9
    b.hi 5f
    bl _lex_integer
    b _lex_loop
5:
    // alpha or underscore → identifier/keyword
    bl _is_alpha
    cbz x0, 6f
    bl _lex_ident
    b _lex_loop
6:
    // operators and punctuation
    ldrb w0, [x19, x20]
    cmp w0, #':'
    b.ne 7f
    mov w0, #TOK_COLON
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
7:  cmp w0, #'('
    b.ne 8f
    mov w0, #TOK_LPAREN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
8:  cmp w0, #')'
    b.ne 9f
    mov w0, #TOK_RPAREN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
9:  cmp w0, #'+'
    b.ne 10f
    mov w0, #TOK_PLUS
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
10: cmp w0, #'-'
    b.ne 11f
    mov w0, #TOK_MINUS
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
11: cmp w0, #'*'
    b.ne 12f
    mov w0, #TOK_STAR
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
12: cmp w0, #'/'
    b.ne 13f
    mov w0, #TOK_SLASH
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
13: cmp w0, #'%'
    b.ne 14f
    mov w0, #TOK_MOD
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
14: // two-char operators: ==, !=, <=, >=, ..
    cmp w0, #'='
    b.ne 15f
    add x1, x20, #1
    cmp x1, x21
    b.ge _lex_assign
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _lex_assign
    mov w0, #TOK_EQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_lex_assign:
    mov w0, #TOK_ASSIGN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
15: cmp w0, #'!'
    b.ne 16f
    add x1, x20, #1
    cmp x1, x21
    b.ge _lex_err
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _lex_err
    mov w0, #TOK_NEQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
16: cmp w0, #'<'
    b.ne 17f
    add x1, x20, #1
    cmp x1, x21
    b.ge _lex_lt_only
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _lex_lt_only
    mov w0, #TOK_LTE
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_lex_lt_only:
    mov w0, #TOK_LT
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
17: cmp w0, #'>'
    b.ne 18f
    add x1, x20, #1
    cmp x1, x21
    b.ge _lex_gt_only
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _lex_gt_only
    mov w0, #TOK_GTE
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_lex_gt_only:
    mov w0, #TOK_GT
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop
18: cmp w0, #'.'
    b.ne _lex_err
    add x1, x20, #1
    cmp x1, x21
    b.ge _lex_err
    ldrb w1, [x19, x1]
    cmp w1, #'.'
    b.ne _lex_err
    mov w0, #TOK_DOTDOT
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop

_lex_eof:
    // emit remaining DEDENTs
    adrp x0, ind_sp@PAGE
    add x0, x0, ind_sp@PAGEOFF
    ldr w1, [x0]
_lex_eof_dedent:
    cmp w1, #1
    b.le _lex_eof_done
    sub w1, w1, #1
    str w1, [x0]
    stp x0, x1, [sp, #-16]!
    mov w0, #TOK_DEDENT
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    ldp x0, x1, [sp], #16
    b _lex_eof_dedent
_lex_eof_done:
    // emit EOF
    mov w0, #TOK_EOF
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    // store count
    adrp x0, tok_count@PAGE
    add x0, x0, tok_count@PAGEOFF
    str w23, [x0]
    mov x0, x23
    b _lex_ret

_lex_err:
    adrp x0, err_syntax@PAGE
    add x0, x0, err_syntax@PAGEOFF
    mov x1, x24
    bl _err_line
    mov x0, #-1
    b _lex_ret
_lex_indent_err:
    adrp x0, err_indent@PAGE
    add x0, x0, err_indent@PAGEOFF
    mov x1, x24
    bl _err_line
    mov x0, #-1
    b _lex_ret

_lex_ret:
    ldp x27, x28, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ── Lexer sub-functions ──

// Add token: w0=type, x1=len, x2=ptr, x3=value
_lex_add_tok:
    str w0, [x22]                // type
    str w1, [x22, #4]           // len
    str x2, [x22, #8]           // ptr
    str x3, [x22, #16]          // value
    add x22, x22, #TOK_SIZE
    add x23, x23, #1
    ret

_lex_emit_nl:
    mov w0, #TOK_NL
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    b _lex_add_tok

_lex_skip_comment:
1:  cmp x20, x21
    b.ge 2f
    ldrb w0, [x19, x20]
    cmp w0, #'\n'
    b.eq 2f
    add x20, x20, #1
    b 1b
2:  // don't consume the \n, let main loop handle it
    ret

// _is_alpha: check if byte at [x19,x20] is alpha or '_'
// returns x0=1 if yes, 0 if no
_is_alpha:
    ldrb w0, [x19, x20]
    cmp w0, #'_'
    b.eq 1f
    cmp w0, #'a'
    b.lt 2f
    cmp w0, #'z'
    b.le 1f
    cmp w0, #'A'
    b.lt 2f
    cmp w0, #'Z'
    b.le 1f
2:  mov x0, #0
    ret
1:  mov x0, #1
    ret

// _is_alnum: check if byte is alpha, digit, or '_'
_is_alnum:
    ldrb w0, [x19, x20]
    cmp w0, #'_'
    b.eq 1f
    cmp w0, #'a'
    b.lt 3f
    cmp w0, #'z'
    b.le 1f
3:  cmp w0, #'A'
    b.lt 4f
    cmp w0, #'Z'
    b.le 1f
4:  cmp w0, #'0'
    b.lt 2f
    cmp w0, #'9'
    b.le 1f
2:  mov x0, #0
    ret
1:  mov x0, #1
    ret

// Lex identifier or keyword
_lex_ident:
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    mov x27, x20                 // start pos
1:  cmp x20, x21
    b.ge 2f
    bl _is_alnum
    cbz x0, 2f
    add x20, x20, #1
    b 1b
2:  // x27=start, x20=end
    sub x28, x20, x27           // length
    add x0, x19, x27            // ptr to ident

    // check keywords
    mov x1, x28                  // len
    bl _match_keyword            // returns token type in w0
    add x2, x19, x27
    mov x3, #0
    mov x1, x28
    bl _lex_add_tok
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Match keyword: x0=ptr, x1=len → w0=token type
_match_keyword:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0                 // save ptr
    mov x20, x1                 // save len

    // try each keyword
    adrp x1, kw_legna@PAGE
    add x1, x1, kw_legna@PAGEOFF
    mov x2, #5
    cmp x20, x2
    b.ne 1f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_legna
1:  adrp x1, kw_output@PAGE
    add x1, x1, kw_output@PAGEOFF
    mov x2, #6
    cmp x20, x2
    b.ne 2f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_output
2:  adrp x1, kw_let@PAGE
    add x1, x1, kw_let@PAGEOFF
    mov x2, #3
    cmp x20, x2
    b.ne 3f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_let
3:  adrp x1, kw_if@PAGE
    add x1, x1, kw_if@PAGEOFF
    mov x2, #2
    cmp x20, x2
    b.ne 4f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_if
4:  adrp x1, kw_else@PAGE
    add x1, x1, kw_else@PAGEOFF
    mov x2, #4
    cmp x20, x2
    b.ne 5f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_else
5:  adrp x1, kw_while@PAGE
    add x1, x1, kw_while@PAGEOFF
    mov x2, #5
    cmp x20, x2
    b.ne 6f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_while
6:  adrp x1, kw_for@PAGE
    add x1, x1, kw_for@PAGEOFF
    mov x2, #3
    cmp x20, x2
    b.ne 7f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_for
7:  adrp x1, kw_in@PAGE
    add x1, x1, kw_in@PAGEOFF
    mov x2, #2
    cmp x20, x2
    b.ne 8f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_in
8:  adrp x1, kw_input_num@PAGE
    add x1, x1, kw_input_num@PAGEOFF
    mov x2, #9
    cmp x20, x2
    b.ne 9f
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_innum
9:  adrp x1, kw_input_str@PAGE
    add x1, x1, kw_input_str@PAGEOFF
    mov x2, #9
    cmp x20, x2
    b.ne _mk_ident
    mov x0, x19
    bl _strncmp
    cbz x0, _mk_instr
_mk_ident:
    mov w0, #TOK_IDENT
    b _mk_ret
_mk_legna:  mov w0, #TOK_KW_LEGNA
    b _mk_ret
_mk_output: mov w0, #TOK_KW_OUTPUT
    b _mk_ret
_mk_let:    mov w0, #TOK_KW_LET
    b _mk_ret
_mk_if:     mov w0, #TOK_KW_IF
    b _mk_ret
_mk_else:   mov w0, #TOK_KW_ELSE
    b _mk_ret
_mk_while:  mov w0, #TOK_KW_WHILE
    b _mk_ret
_mk_for:    mov w0, #TOK_KW_FOR
    b _mk_ret
_mk_in:     mov w0, #TOK_KW_IN
    b _mk_ret
_mk_innum:  mov w0, #TOK_KW_INNUM
    b _mk_ret
_mk_instr:  mov w0, #TOK_KW_INSTR
    b _mk_ret
_mk_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Lex integer literal
_lex_integer:
    stp x29, x30, [sp, #-16]!
    mov x27, x20                 // start
    mov x28, #0                  // value
1:  cmp x20, x21
    b.ge 2f
    ldrb w0, [x19, x20]
    sub w1, w0, #'0'
    cmp w1, #9
    b.hi 2f
    mov x2, #10
    mul x28, x28, x2
    add x28, x28, x1
    add x20, x20, #1
    b 1b
2:  mov w0, #TOK_INT
    sub x1, x20, x27
    add x2, x19, x27
    mov x3, x28
    bl _lex_add_tok
    ldp x29, x30, [sp], #16
    ret

// Lex string literal (opening " already at x20)
_lex_string:
    stp x29, x30, [sp, #-16]!
    add x20, x20, #1            // skip opening "
    mov x27, x20                 // content start
1:  cmp x20, x21
    b.ge _lex_str_err
    ldrb w0, [x19, x20]
    cmp w0, #'"'
    b.eq 2f
    cmp w0, #'\\'
    b.ne 3f
    add x20, x20, #1            // skip escape
3:  add x20, x20, #1
    b 1b
2:  // x27=start, x20=closing quote
    mov w0, #TOK_STR
    sub x1, x20, x27            // raw length
    add x2, x19, x27            // ptr to content
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1            // skip closing "
    ldp x29, x30, [sp], #16
    ret
_lex_str_err:
    ldp x29, x30, [sp], #16
    b _lex_err

// ════════════════════════════════════════
// PARSER + CODEGEN - Recursive descent
// ════════════════════════════════════════

// Token access helpers
// _tok_peek: returns token type in w0 (does not advance)
_tok_peek:
    adrp x0, tok_pos@PAGE
    add x0, x0, tok_pos@PAGEOFF
    ldr w1, [x0]
    mov x2, #TOK_SIZE
    mul x1, x1, x2
    adrp x0, tok_buf@PAGE
    add x0, x0, tok_buf@PAGEOFF
    add x0, x0, x1
    ldr w0, [x0]             // type field
    ret

// _tok_advance: advance tok_pos by 1
_tok_advance:
    adrp x0, tok_pos@PAGE
    add x0, x0, tok_pos@PAGEOFF
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]
    ret

// _tok_cur_ptr: returns pointer to current token struct in x0
_tok_cur_ptr:
    adrp x0, tok_pos@PAGE
    add x0, x0, tok_pos@PAGEOFF
    ldr w1, [x0]
    mov x2, #TOK_SIZE
    mul x1, x1, x2
    adrp x0, tok_buf@PAGE
    add x0, x0, tok_buf@PAGEOFF
    add x0, x0, x1
    ret

// _tok_expect: w0=expected type. Advances if match, else error. Returns 0 ok, -1 err
_tok_expect:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0              // expected
    bl _tok_peek
    cmp w0, w19
    b.ne 1f
    bl _tok_advance
    mov x0, #0
    b 2f
1:  adrp x0, err_syntax@PAGE
    add x0, x0, err_syntax@PAGEOFF
    mov x1, #0
    bl _err_line
    mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _skip_nl: skip all TOK_NL tokens
_skip_nl:
    stp x29, x30, [sp, #-16]!
1:  bl _tok_peek
    cmp w0, #TOK_NL
    b.ne 2f
    bl _tok_advance
    b 1b
2:  ldp x29, x30, [sp], #16
    ret

// _new_label: returns next label number in w0, increments lbl_count
_new_label:
    adrp x0, lbl_count@PAGE
    add x0, x0, lbl_count@PAGEOFF
    ldr w1, [x0]
    mov w2, w1
    add w1, w1, #1
    str w1, [x0]
    mov w0, w2
    ret

// _emit_label: emit "_L<num>:\n" where w0=num
_emit_label:
    stp x29, x30, [sp, #-16]!
    mov w19, w0
    adrp x0, fg_lbl@PAGE
    add x0, x0, fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, fg_colon@PAGE
    add x0, x0, fg_colon@PAGEOFF
    bl _emit_str
    ldp x29, x30, [sp], #16
    ret

// _emit_branch_to: emit "    b _L<num>\n"
_emit_branch_to:
    stp x29, x30, [sp, #-16]!
    mov w19, w0
    adrp x0, fg_b@PAGE
    add x0, x0, fg_b@PAGEOFF
    bl _emit_str
    adrp x0, fg_lbl@PAGE
    add x0, x0, fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, fg_nl@PAGE
    add x0, x0, fg_nl@PAGEOFF
    bl _emit_str
    ldp x29, x30, [sp], #16
    ret

// ── Symbol table ──

// _sym_lookup: x0=name_ptr, x1=name_len → x0=entry_ptr or 0
_sym_lookup:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0             // name ptr
    mov x20, x1             // name len
    adrp x21, sym_tab@PAGE
    add x21, x21, sym_tab@PAGEOFF
    adrp x0, sym_count@PAGE
    add x0, x0, sym_count@PAGEOFF
    ldr w22, [x0]           // count
    mov x0, #0              // index
1:  cmp w0, w22
    b.ge 2f
    // entry at x21 + index*32
    mov x1, #SYM_SIZE
    mul x2, x0, x1
    add x3, x21, x2         // entry ptr
    ldr x4, [x3]            // name_ptr
    ldr w5, [x3, #8]        // name_len
    cmp w5, w20
    b.ne 3f
    // compare names
    stp x0, x3, [sp, #-16]!
    mov x0, x19
    mov x1, x4
    mov x2, x20
    bl _strncmp
    mov x4, x0
    ldp x0, x3, [sp], #16
    cbz x4, 4f              // match
3:  add x0, x0, #1
    b 1b
2:  mov x0, #0              // not found
    b 5f
4:  mov x0, x3              // found
5:  ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _sym_insert: x0=name_ptr, x1=name_len, w2=type → x0=entry_ptr
_sym_insert:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    mov w21, w2              // type
    adrp x0, sym_count@PAGE
    add x0, x0, sym_count@PAGEOFF
    ldr w22, [x0]
    // compute entry address
    adrp x1, sym_tab@PAGE
    add x1, x1, sym_tab@PAGEOFF
    mov x2, #SYM_SIZE
    mul x3, x22, x2
    add x4, x1, x3          // new entry ptr
    // fill entry
    str x19, [x4]           // name_ptr
    str w20, [x4, #8]       // name_len
    str w21, [x4, #12]      // type
    // compute offset: frame grows by 8 for int, 16 for str
    adrp x0, frame_size@PAGE
    add x0, x0, frame_size@PAGEOFF
    ldr w5, [x0]
    cmp w21, #TY_STR
    b.eq 1f
    add w5, w5, #8
    b 2f
1:  add w5, w5, #16
2:  str w5, [x0]            // update frame_size
    str w5, [x4, #16]       // store offset in entry
    // increment count
    add w22, w22, #1
    adrp x0, sym_count@PAGE
    add x0, x0, sym_count@PAGEOFF
    str w22, [x0]
    mov x0, x4
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ── Runtime template emission ──

// Emit the runtime helpers as text into out_buf
_emit_runtime:
    stp x29, x30, [sp, #-16]!

    // _rt_itoa
    adrp x0, _rt_itoa_text@PAGE
    add x0, x0, _rt_itoa_text@PAGEOFF
    bl _emit_str

    // _rt_atoi
    adrp x0, _rt_atoi_text@PAGE
    add x0, x0, _rt_atoi_text@PAGEOFF
    bl _emit_str

    // _rt_read_line
    adrp x0, _rt_read_line_text@PAGE
    add x0, x0, _rt_read_line_text@PAGEOFF
    bl _emit_str

    ldp x29, x30, [sp], #16
    ret

// ── Main parse entry ──

// _parse_program: parse entire program, emit code
// Returns x0=0 success, -1 error
_parse_program:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    // reset state
    adrp x0, out_pos@PAGE
    add x0, x0, out_pos@PAGEOFF
    str xzr, [x0]
    adrp x0, sym_count@PAGE
    add x0, x0, sym_count@PAGEOFF
    str wzr, [x0]
    adrp x0, frame_size@PAGE
    add x0, x0, frame_size@PAGEOFF
    str wzr, [x0]
    adrp x0, lbl_count@PAGE
    add x0, x0, lbl_count@PAGEOFF
    str wzr, [x0]
    adrp x0, str_count@PAGE
    add x0, x0, str_count@PAGEOFF
    str wzr, [x0]
    adrp x0, tok_pos@PAGE
    add x0, x0, tok_pos@PAGEOFF
    str wzr, [x0]

    // emit header + text section
    adrp x0, fg_hdr@PAGE
    add x0, x0, fg_hdr@PAGEOFF
    bl _emit_str
    adrp x0, fg_text@PAGE
    add x0, x0, fg_text@PAGEOFF
    bl _emit_str

    // emit runtime helpers
    bl _emit_runtime

    // emit _main prologue with fixed frame size 4096
    adrp x0, fg_main@PAGE
    add x0, x0, fg_main@PAGEOFF
    bl _emit_str
    mov x0, #4096
    bl _emit_num
    adrp x0, fg_main2@PAGE
    add x0, x0, fg_main2@PAGEOFF
    bl _emit_str

    // skip leading newlines
    bl _skip_nl

    // expect legna keyword
    bl _tok_peek
    cmp w0, #TOK_KW_LEGNA
    b.ne _pp_err
    bl _tok_advance

    // expect colon
    bl _tok_peek
    cmp w0, #TOK_COLON
    b.ne _pp_err
    bl _tok_advance

    // expect NL
    bl _skip_nl

    // expect INDENT
    bl _tok_peek
    cmp w0, #TOK_INDENT
    b.ne _pp_err
    bl _tok_advance

    // parse block
    bl _parse_block
    cmp x0, #0
    b.lt _pp_fail

    // emit exit
    adrp x0, fg_exit@PAGE
    add x0, x0, fg_exit@PAGEOFF
    bl _emit_str

    // emit data section with string literals
    bl _emit_data_section

    // emit bss section
    adrp x0, fg_bss@PAGE
    add x0, x0, fg_bss@PAGEOFF
    bl _emit_str

    mov x0, #0
    b _pp_ret

_pp_err:
    adrp x0, err_nolegna@PAGE
    add x0, x0, err_nolegna@PAGEOFF
    bl _print_err
_pp_fail:
    mov x0, #-1
_pp_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_block: parse statements until DEDENT
_parse_block:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

_pb_loop:
    bl _tok_peek
    cmp w0, #TOK_DEDENT
    b.eq _pb_done
    cmp w0, #TOK_EOF
    b.eq _pb_done

    // skip newlines
    cmp w0, #TOK_NL
    b.ne 1f
    bl _tok_advance
    b _pb_loop
1:
    bl _parse_statement
    cmp x0, #0
    b.lt _pb_fail
    b _pb_loop

_pb_done:
    // consume DEDENT if present
    bl _tok_peek
    cmp w0, #TOK_DEDENT
    b.ne 1f
    bl _tok_advance
1:  mov x0, #0
    b _pb_ret
_pb_fail:
    mov x0, #-1
_pb_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_statement: dispatch based on current token
_parse_statement:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    bl _tok_peek

    cmp w0, #TOK_KW_LET
    b.eq _ps_let
    cmp w0, #TOK_KW_OUTPUT
    b.eq _ps_output
    cmp w0, #TOK_KW_IF
    b.eq _ps_if
    cmp w0, #TOK_KW_WHILE
    b.eq _ps_while
    cmp w0, #TOK_KW_FOR
    b.eq _ps_for
    cmp w0, #TOK_IDENT
    b.eq _ps_assign
    // skip NL
    cmp w0, #TOK_NL
    b.ne _ps_err
    bl _tok_advance
    mov x0, #0
    b _ps_ret

_ps_let:
    bl _parse_let
    b _ps_ret
_ps_output:
    bl _parse_output
    b _ps_ret
_ps_if:
    bl _parse_if
    b _ps_ret
_ps_while:
    bl _parse_while
    b _ps_ret
_ps_for:
    bl _parse_for
    b _ps_ret
_ps_assign:
    bl _parse_assign
    b _ps_ret
_ps_err:
    adrp x0, err_syntax@PAGE
    add x0, x0, err_syntax@PAGEOFF
    mov x1, #0
    bl _err_line
    mov x0, #-1
_ps_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ── PLACEHOLDER_PARSE_LET ──
