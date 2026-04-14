// ============================================================
// helpers.s - Utility functions for legnac v0.2
// String ops, emit helpers, itoa, tmp path builder, error reporting
// ============================================================
.include "src/macos_arm64/defs.inc"

.section __TEXT,__text

// ────────────────────────────────────────
// _strlen: x0 = null-terminated string → x0 = length
// ────────────────────────────────────────
.globl _strlen
_strlen:
    mov     x1, x0
    mov     x0, #0
1:  ldrb    w2, [x1, x0]
    cbz     w2, 2f
    add     x0, x0, #1
    b       1b
2:  ret

// ────────────────────────────────────────
// _strcpy: x0 = dest, x1 = src (copies including null terminator)
// ────────────────────────────────────────
.globl _strcpy
.globl _rename_file
_strcpy:
    mov     x2, #0
1:  ldrb    w3, [x1, x2]
    strb    w3, [x0, x2]
    cbz     w3, 2f
    add     x2, x2, #1
    b       1b
2:  ret

// ────────────────────────────────────────
// _strncmp: x0=s1, x1=s2, x2=n → x0=0 if equal, 1 if not
// ────────────────────────────────────────
.globl _strncmp
_strncmp:
    mov     x3, #0
1:  cmp     x3, x2
    b.ge    2f
    ldrb    w4, [x0, x3]
    ldrb    w5, [x1, x3]
    cmp     w4, w5
    b.ne    3f
    cbz     w4, 2f              // both null before n
    add     x3, x3, #1
    b       1b
2:  mov     x0, #0             // equal
    ret
3:  mov     x0, #1             // not equal
    ret

// ────────────────────────────────────────
// _print_err: x0 = null-terminated string, prints to stderr
// ────────────────────────────────────────
.globl _print_err
_print_err:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x1, x0             // save string ptr for syscall
    bl      _strlen             // x0 = length
    mov     x2, x0             // count
    mov     x0, #STDERR        // fd = 2
    mov     x16, #SYS_WRITE
    svc     #0x80
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _strip_ext: x0=dest, x1=src — copy src to dest, truncate at last '.'
// ────────────────────────────────────────
.globl _strip_ext
_strip_ext:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0            // dest
    mov     x20, x1            // src
    // copy src → dest
    bl      _strcpy
    // find length of dest
    mov     x0, x19
    bl      _strlen
    // scan backwards for '.'
    sub     x2, x0, #1
1:  cmp     x2, #0
    b.lt    2f                  // no dot found, leave as-is
    ldrb    w3, [x19, x2]
    cmp     w3, #'.'
    b.eq    3f
    sub     x2, x2, #1
    b       1b
3:  // null-terminate at the dot
    strb    wzr, [x19, x2]
2:  ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _itoa: x0=number (signed 64-bit), x1=buffer
//        → x0=length of string (null-terminated in buffer)
// Handles negative numbers.
// ────────────────────────────────────────
.globl _itoa
_itoa:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    sub     sp, sp, #32         // scratch space for reversed digits

    mov     x19, x0            // number
    mov     x20, x1            // output buffer start
    mov     x21, x1            // write cursor (advances if negative)
    mov     x22, #0            // digit count

    // handle negative
    cmp     x19, #0
    b.ge    1f
    mov     w3, #'-'
    strb    w3, [x21], #1
    neg     x19, x19
1:
    // special case: zero
    cbnz    x19, 2f
    mov     w3, #'0'
    strb    w3, [sp]
    mov     x22, #1
    b       4f

    // extract digits in reverse onto scratch stack area
2:  cbz     x19, 4f
    mov     x3, #10
    udiv    x4, x19, x3
    msub    x5, x4, x3, x19   // remainder = x19 - x4*10
    add     w5, w5, #'0'
    strb    w5, [sp, x22]
    add     x22, x22, #1
    mov     x19, x4
    b       2b

    // copy digits in correct order to output
4:  sub     x22, x22, #1
    mov     x3, #0
5:  ldrb    w5, [sp, x22]
    strb    w5, [x21, x3]
    add     x3, x3, #1
    cbz     x22, 6f
    sub     x22, x22, #1
    b       5b

6:  // null-terminate
    strb    wzr, [x21, x3]
    // compute total length = (x21 - x20) + x3
    sub     x0, x21, x20
    add     x0, x0, x3

    add     sp, sp, #32
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _build_tmp_paths: construct /tmp/legna_<PID>.s and .o
// Uses _tmp_path_s and _tmp_path_o BSS buffers
// ────────────────────────────────────────
.globl _build_tmp_paths
_build_tmp_paths:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!

    // get PID
    mov     x16, #SYS_GETPID
    svc     #0x80
    mov     x19, x0            // PID

    // ── build _tmp_path_s ──
    adrp    x0, _tmp_path_s@PAGE
    add     x0, x0, _tmp_path_s@PAGEOFF
    adrp    x1, _tmp_prefix@PAGE
    add     x1, x1, _tmp_prefix@PAGEOFF
    bl      _strcpy

    // find end of prefix
    adrp    x0, _tmp_path_s@PAGE
    add     x0, x0, _tmp_path_s@PAGEOFF
    bl      _strlen
    adrp    x20, _tmp_path_s@PAGE
    add     x20, x20, _tmp_path_s@PAGEOFF
    add     x1, x20, x0       // x1 = buffer position after prefix
    mov     x0, x19            // PID
    bl      _itoa              // appends PID digits

    // append ".s"
    adrp    x0, _tmp_path_s@PAGE
    add     x0, x0, _tmp_path_s@PAGEOFF
    bl      _strlen
    add     x0, x20, x0       // end of current string
    adrp    x1, _tmp_ext_s@PAGE
    add     x1, x1, _tmp_ext_s@PAGEOFF
    bl      _strcpy

    // ── build _tmp_path_o ──
    adrp    x0, _tmp_path_o@PAGE
    add     x0, x0, _tmp_path_o@PAGEOFF
    adrp    x1, _tmp_prefix@PAGE
    add     x1, x1, _tmp_prefix@PAGEOFF
    bl      _strcpy

    adrp    x0, _tmp_path_o@PAGE
    add     x0, x0, _tmp_path_o@PAGEOFF
    bl      _strlen
    adrp    x20, _tmp_path_o@PAGE
    add     x20, x20, _tmp_path_o@PAGEOFF
    add     x1, x20, x0
    mov     x0, x19
    bl      _itoa

    adrp    x0, _tmp_path_o@PAGE
    add     x0, x0, _tmp_path_o@PAGEOFF
    bl      _strlen
    add     x0, x20, x0
    adrp    x1, _tmp_ext_o@PAGE
    add     x1, x1, _tmp_ext_o@PAGEOFF
    bl      _strcpy

    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _err_line: x0=error prefix string, x1=line number
// Prints: "<prefix><line_number>\n" to stderr
// ────────────────────────────────────────
.globl _err_line
_err_line:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0            // prefix
    mov     x20, x1            // line number

    // print prefix
    mov     x0, x19
    bl      _print_err

    // convert line number to string and print
    mov     x0, x20
    adrp    x1, _num_buf@PAGE
    add     x1, x1, _num_buf@PAGEOFF
    bl      _itoa
    adrp    x0, _num_buf@PAGE
    add     x0, x0, _num_buf@PAGEOFF
    bl      _print_err

    // print newline
    adrp    x0, _err_nl@PAGE
    add     x0, x0, _err_nl@PAGEOFF
    bl      _print_err

    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_str: x0 = null-terminated string, append to _out_buf
// ────────────────────────────────────────
.globl _emit_str
_emit_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0            // source string

    adrp    x20, _out_pos@PAGE
    add     x20, x20, _out_pos@PAGEOFF
    ldr     x1, [x20]          // current pos

    adrp    x2, _out_buf@PAGE
    add     x2, x2, _out_buf@PAGEOFF
    add     x2, x2, x1         // dest = out_buf + pos

    mov     x3, #0
1:  ldrb    w4, [x19, x3]
    cbz     w4, 2f
    strb    w4, [x2, x3]
    add     x3, x3, #1
    b       1b
2:  add     x1, x1, x3
    str     x1, [x20]

    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_char: w0 = byte to append to _out_buf
// ────────────────────────────────────────
.globl _emit_char
_emit_char:
    adrp    x1, _out_pos@PAGE
    add     x1, x1, _out_pos@PAGEOFF
    ldr     x2, [x1]           // current pos
    adrp    x3, _out_buf@PAGE
    add     x3, x3, _out_buf@PAGEOFF
    strb    w0, [x3, x2]
    add     x2, x2, #1
    str     x2, [x1]
    ret

// ────────────────────────────────────────
// _emit_num: x0 = signed number, append decimal ASCII to _out_buf
// Handles negative numbers.
// ────────────────────────────────────────
.globl _emit_num
_emit_num:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    sub     sp, sp, #32         // scratch for reversed digits

    mov     x19, x0            // number

    // handle negative
    cmp     x19, #0
    b.ge    1f
    mov     w0, #'-'
    bl      _emit_char
    neg     x19, x19
1:
    adrp    x20, _num_buf@PAGE
    add     x20, x20, _num_buf@PAGEOFF
    mov     x21, #0            // digit count

    // special case zero
    cbnz    x19, 2f
    mov     w5, #'0'
    strb    w5, [x20]
    mov     x21, #1
    b       4f

2:  cbz     x19, 4f
    mov     x3, #10
    udiv    x4, x19, x3
    msub    x5, x4, x3, x19   // remainder
    add     w5, w5, #'0'
    strb    w5, [x20, x21]
    add     x21, x21, #1
    mov     x19, x4
    b       2b

    // emit digits in reverse order
4:  sub     x21, x21, #1
5:  ldrb    w0, [x20, x21]
    bl      _emit_char
    cbz     x21, 6f
    sub     x21, x21, #1
    b       5b

6:  add     sp, sp, #32
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_raw: x0=ptr, x1=len — append raw bytes to _out_buf
// ────────────────────────────────────────
.globl _emit_raw
_emit_raw:
    adrp    x2, _out_pos@PAGE
    add     x2, x2, _out_pos@PAGEOFF
    ldr     x3, [x2]           // current pos
    adrp    x4, _out_buf@PAGE
    add     x4, x4, _out_buf@PAGEOFF
    add     x4, x4, x3         // dest

    mov     x5, #0
1:  cmp     x5, x1
    b.ge    2f
    ldrb    w6, [x0, x5]
    strb    w6, [x4, x5]
    add     x5, x5, #1
    b       1b
2:  add     x3, x3, x1
    str     x3, [x2]
    ret

// ────────────────────────────────────────
// _rename_file: x0=old_path, x1=new_path → x0=0 ok, -1 err
// ────────────────────────────────────────
_rename_file:
    mov     x16, #128              // SYS_rename
    svc     #0x80
    ret
