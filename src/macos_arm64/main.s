// ============================================================
// main.s - Entry point, CLI argument parsing
// legnac v0.8 - macOS ARM64
// ============================================================
.include "src/macos_arm64/defs.inc"

.globl _main

.section __TEXT,__text
.align 2

// ────────────────────────────────────────
// _main - Entry point
// Callee-saved: x19=argc, x20=argv, x21=input_file, x22=import_idx, x23=spare
// ────────────────────────────────────────
_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0                     // argc
    mov x20, x1                     // argv

    cmp x19, #2
    b.lt _m_usage

    ldr x21, [x20, #8]             // input filename

    // default output name = strip extension
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    mov x1, x21
    bl _strip_ext

    // check for -o flag
    cmp x19, #4
    b.lt 1f
    ldr x0, [x20, #16]
    ldrb w1, [x0]
    cmp w1, #'-'
    b.ne 1f
    ldrb w1, [x0, #1]
    cmp w1, #'o'
    b.ne 1f
    ldrb w1, [x0, #2]
    cbnz w1, 1f
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    ldr x1, [x20, #24]
    bl _strcpy
1:
    bl _build_tmp_paths

    // read source file
    mov x0, x21
    bl _read_file
    cmp x0, #0
    b.lt _m_err_open

    bl _lex
    cmp x0, #0
    b.lt _m_err_exit

    bl _parse_program
    cmp x0, #0
    b.lt _m_err_exit

    bl _write_asm
    cmp x0, #0
    b.lt _m_err_open

    bl _run_as
    cmp x0, #0
    b.ne _m_err_asm

    // ── Dispatch based on mode ──

    // lib mode? → output .o directly
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    ldr w0, [x0]
    cbnz w0, _m_lib_done

    // has imports? → multi-file compile
    adrp x0, _import_count@PAGE
    add x0, x0, _import_count@PAGEOFF
    ldr w0, [x0]
    cbz w0, _m_no_imports

    // ── Multi-file path ──
    // Step 1: rename main .o so it won't be overwritten
    bl _save_main_o

    // Step 2: compile each import
    adrp x0, _lib_o_count@PAGE
    add x0, x0, _lib_o_count@PAGEOFF
    str wzr, [x0]
    mov w22, #0                      // import index (callee-saved)
    adrp x0, _import_count@PAGE
    add x0, x0, _import_count@PAGEOFF
    ldr w23, [x0]                    // save import count (callee-saved)

_m_import_loop:
    cmp w22, w23
    b.ge _m_import_done

    mov w0, w22
    bl _build_lib_path
    cmp x0, #0
    b.lt _m_err_import

    // set lib mode
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    mov w1, #1
    str w1, [x0]

    // compile library
    adrp x0, _lib_path_buf@PAGE
    add x0, x0, _lib_path_buf@PAGEOFF
    bl _read_file
    cmp x0, #0
    b.lt _m_err_import

    bl _lex
    cmp x0, #0
    b.lt _m_err_exit

    bl _parse_program
    cmp x0, #0
    b.lt _m_err_exit

    bl _write_asm
    cmp x0, #0
    b.lt _m_err_open

    bl _run_as
    cmp x0, #0
    b.ne _m_err_asm

    // save lib .o with unique name
    mov w0, w22
    bl _save_lib_o

    add w22, w22, #1
    b _m_import_loop

_m_import_done:
    // clear lib mode
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    str wzr, [x0]

    // link all
    bl _run_ld_multi
    cmp x0, #0
    b.ne _m_err_link

    // cleanup all temp .o files
    bl _cleanup_multi
    b _m_ok

_m_no_imports:
    bl _run_ld
    cmp x0, #0
    b.ne _m_err_link
    bl _cleanup
    b _m_ok

_m_lib_done:
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    adrp x1, _out_name@PAGE
    add x1, x1, _out_name@PAGEOFF
    bl _rename_file
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80
    b _m_ok

_m_ok:
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
_m_err_import:
    adrp x0, _err_import@PAGE
    add x0, x0, _err_import@PAGEOFF
    bl _print_err
    adrp x0, _lib_path_buf@PAGE
    add x0, x0, _lib_path_buf@PAGEOFF
    bl _print_err
    adrp x0, _fg_nl_err@PAGE
    add x0, x0, _fg_nl_err@PAGEOFF
    bl _print_err
    mov x0, #1
    b _m_exit
_m_err_exit:
    mov x0, #1
    b _m_exit

_m_exit:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// _save_main_o - Rename main .o to _main_o_path (unique name)
// ────────────────────────────────────────
_save_main_o:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    // copy tmp_path_o to main_o_path
    adrp x0, _main_o_path@PAGE
    add x0, x0, _main_o_path@PAGEOFF
    adrp x1, _tmp_path_o@PAGE
    add x1, x1, _tmp_path_o@PAGEOFF
    bl _strcpy

    // append "m" to make unique
    adrp x19, _main_o_path@PAGE
    add x19, x19, _main_o_path@PAGEOFF
    mov x0, x19
    bl _strlen
    mov w1, #'m'
    strb w1, [x19, x0]
    add x0, x0, #1
    strb wzr, [x19, x0]

    // rename file
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    mov x1, x19
    bl _rename_file

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _save_lib_o - Rename lib .o to unique path in _lib_o_paths
// w0 = lib index
// ────────────────────────────────────────
_save_lib_o:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov w19, w0                      // lib index

    // compute dest slot: _lib_o_paths + index * 256
    adrp x20, _lib_o_paths@PAGE
    add x20, x20, _lib_o_paths@PAGEOFF
    mov x1, #256
    mul x1, x19, x1
    add x20, x20, x1                // x20 = dest buffer

    // copy tmp_path_o to dest
    mov x0, x20
    adrp x1, _tmp_path_o@PAGE
    add x1, x1, _tmp_path_o@PAGEOFF
    bl _strcpy

    // append 2-digit index to make unique (00-99)
    mov x0, x20
    bl _strlen
    mov w1, w19
    mov w3, #10
    udiv w4, w1, w3              // tens digit
    msub w5, w4, w3, w1          // ones digit
    add w4, w4, #'0'
    add w5, w5, #'0'
    strb w4, [x20, x0]
    add x0, x0, #1
    strb w5, [x20, x0]
    add x0, x0, #1
    strb wzr, [x20, x0]

    // rename file
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    mov x1, x20
    bl _rename_file

    // increment lib_o_count
    adrp x0, _lib_o_count@PAGE
    add x0, x0, _lib_o_count@PAGEOFF
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // cleanup .s
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _cleanup_multi - Remove all temp .o files and main .s
// ────────────────────────────────────────
_cleanup_multi:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    // remove main .o
    adrp x0, _main_o_path@PAGE
    add x0, x0, _main_o_path@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80

    // remove lib .o files
    mov w19, #0
    adrp x20, _lib_o_count@PAGE
    add x20, x20, _lib_o_count@PAGEOFF
1:  ldr w0, [x20]
    cmp w19, w0
    b.ge 2f
    adrp x0, _lib_o_paths@PAGE
    add x0, x0, _lib_o_paths@PAGEOFF
    mov x1, #256
    mul x1, x19, x1
    add x0, x0, x1
    mov x16, #SYS_UNLINK
    svc #0x80
    add w19, w19, #1
    b 1b

2:  // remove main .s
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
