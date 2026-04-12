// ============================================================
// main.s - Entry point, CLI argument parsing
// legnac v0.2 - macOS ARM64
// ============================================================
.include "src/macos_arm64/defs.inc"

.globl _main

.section __TEXT,__text
.align 2

// ────────────────────────────────────────
// _main - Entry point
// ────────────────────────────────────────
_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0                     // argc
    mov x20, x1                     // argv

    // need at least 2 args
    cmp x19, #2
    b.lt _m_usage

    // x21 = input filename (argv[1])
    ldr x21, [x20, #8]

    // default output name = strip extension
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    mov x1, x21
    bl _strip_ext

    // check for -o flag (argv[2] == "-o", argv[3] = name)
    cmp x19, #4
    b.lt 1f
    ldr x0, [x20, #16]             // argv[2]
    ldrb w1, [x0]
    cmp w1, #'-'
    b.ne 1f
    ldrb w1, [x0, #1]
    cmp w1, #'o'
    b.ne 1f
    ldrb w1, [x0, #2]
    cbnz w1, 1f                     // must be exactly "-o"
    // copy argv[3] to _out_name
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    ldr x1, [x20, #24]
    bl _strcpy
1:
    // build PID-based temp paths
    bl _build_tmp_paths

    // read source file
    mov x0, x21
    bl _read_file
    cmp x0, #0
    b.lt _m_err_open

    // lex
    bl _lex
    cmp x0, #0
    b.lt _m_err_exit

    // parse + codegen
    bl _parse_program
    cmp x0, #0
    b.lt _m_err_exit

    // write temp .s file
    bl _write_asm
    cmp x0, #0
    b.lt _m_err_open

    // assemble
    bl _run_as
    cmp x0, #0
    b.ne _m_err_asm

    // link
    bl _run_ld
    cmp x0, #0
    b.ne _m_err_link

    // cleanup temp files
    bl _cleanup

    // success
    adrp x0, _msg_ok@PAGE
    add x0, x0, _msg_ok@PAGEOFF
    bl _print_err

    mov x0, #0
    b _m_exit

_m_usage:
    adrp x0, _err_usage@PAGE
    add x0, x0, _err_usage@PAGEOFF
    bl _print_err
    mov x0, #1
    b _m_exit

_m_err_open:
    adrp x0, _err_open@PAGE
    add x0, x0, _err_open@PAGEOFF
    bl _print_err
    mov x0, #1
    b _m_exit

_m_err_asm:
    adrp x0, _err_asm@PAGE
    add x0, x0, _err_asm@PAGEOFF
    bl _print_err
    mov x0, #1
    b _m_exit

_m_err_link:
    adrp x0, _err_link@PAGE
    add x0, x0, _err_link@PAGEOFF
    bl _print_err
    mov x0, #1
    b _m_exit

_m_err_exit:
    // error already printed by lex/parse
    mov x0, #1
    b _m_exit

_m_exit:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    mov x16, #SYS_EXIT
    svc #0x80
