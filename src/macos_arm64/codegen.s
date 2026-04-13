// ============================================================
// codegen.s - Runtime templates emitted into generated code
// legnac v0.2 - macOS ARM64
// ============================================================
.include "src/macos_arm64/defs.inc"

.section __TEXT,__text

// ────────────────────────────────────────
// _emit_runtime - Emit runtime helpers into generated .s
// Called once before _main code
// ────────────────────────────────────────
.globl _emit_runtime
_emit_runtime:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // _rt_itoa: x0=int → x0=length, writes to _itoa_buf
    adrp x0, _rt_itoa_code@PAGE
    add x0, x0, _rt_itoa_code@PAGEOFF
    bl _emit_str

    // _rt_atoi: x0=string ptr → x0=integer
    adrp x0, _rt_atoi_code@PAGE
    add x0, x0, _rt_atoi_code@PAGEOFF
    bl _emit_str

    // _rt_read_line: reads stdin → _input_buf, x0=length
    adrp x0, _rt_readline_code@PAGE
    add x0, x0, _rt_readline_code@PAGEOFF
    bl _emit_str

    // _rt_buf_write: buffered output, x1=ptr, x2=len
    adrp x0, _rt_bufwrite_code@PAGE
    add x0, x0, _rt_bufwrite_code@PAGEOFF
    bl _emit_str

    // _rt_flush: flush output buffer
    adrp x0, _rt_flush_code@PAGE
    add x0, x0, _rt_flush_code@PAGEOFF
    bl _emit_str

    // v0.5: File I/O runtime
    adrp x0, _rt_open_r_code@PAGE
    add x0, x0, _rt_open_r_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_open_w_code@PAGE
    add x0, x0, _rt_open_w_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_close_code@PAGE
    add x0, x0, _rt_close_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_readline_fd_code@PAGE
    add x0, x0, _rt_readline_fd_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_write_line_code@PAGE
    add x0, x0, _rt_write_line_code@PAGEOFF
    bl _emit_str

    // v0.5: AI-native I/O runtime
    adrp x0, _rt_emit_int_code@PAGE
    add x0, x0, _rt_emit_int_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_emit_str_code@PAGE
    add x0, x0, _rt_emit_str_code@PAGEOFF
    bl _emit_str

    // v0.5: Concurrency runtime
    adrp x0, _rt_pipe_code@PAGE
    add x0, x0, _rt_pipe_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_wait_code@PAGE
    add x0, x0, _rt_wait_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_send_code@PAGE
    add x0, x0, _rt_send_code@PAGEOFF
    bl _emit_str

    adrp x0, _rt_recv_code@PAGE
    add x0, x0, _rt_recv_code@PAGEOFF
    bl _emit_str

    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_header - Emit .global, .text, runtime, _main prologue
// ────────────────────────────────────────
.globl _emit_header
_emit_header:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // reset out_pos
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    str xzr, [x0]

    adrp x0, _fg_hdr@PAGE
    add x0, x0, _fg_hdr@PAGEOFF
    bl _emit_str
    adrp x0, _fg_text@PAGE
    add x0, x0, _fg_text@PAGEOFF
    bl _emit_str

    bl _emit_runtime

    ldp x29, x30, [sp], #16
    ret

// _emit_main_prologue - Emit _main: with frame size placeholder
.globl _emit_main_prologue
_emit_main_prologue:
    stp x29, x30, [sp, #-16]!

    adrp x0, _fg_main@PAGE
    add x0, x0, _fg_main@PAGEOFF
    bl _emit_str
    // save current out_pos for frame size patching
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    ldr x0, [x1]
    adrp x1, _frame_patch_pos@PAGE
    add x1, x1, _frame_patch_pos@PAGEOFF
    str x0, [x1]
    // emit 4-char placeholder "0000"
    adrp x0, _fg_frame_ph@PAGE
    add x0, x0, _fg_frame_ph@PAGEOFF
    bl _emit_str
    adrp x0, _fg_main2@PAGE
    add x0, x0, _fg_main2@PAGEOFF
    bl _emit_str

    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_footer - Emit _main epilogue + .data + .bss
// ────────────────────────────────────────
.globl _emit_footer
_emit_footer:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    // exit code
    adrp x0, _fg_exit@PAGE
    add x0, x0, _fg_exit@PAGEOFF
    bl _emit_str

    // patch frame size placeholder
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    ldr w0, [x0]
    // minimum 16, round up to 16-byte alignment
    cmp w0, #16
    b.ge 1f
    mov w0, #16
1:  add w0, w0, #15
    and w0, w0, #~15
    // convert to 4-digit decimal and write into _out_buf at _frame_patch_pos
    // Use leading spaces (not zeros) to avoid GAS octal interpretation
    mov w5, w0                   // save original value
    adrp x1, _frame_patch_pos@PAGE
    add x1, x1, _frame_patch_pos@PAGEOFF
    ldr x1, [x1]
    adrp x2, _out_buf@PAGE
    add x2, x2, _out_buf@PAGEOFF
    add x2, x2, x1              // dest ptr in out_buf
    // fill with spaces first
    mov w4, #' '
    strb w4, [x2, #0]
    strb w4, [x2, #1]
    strb w4, [x2, #2]
    strb w4, [x2, #3]
    // write digits right-to-left
    mov w0, w5
    add x6, x2, #3              // rightmost position
2:  mov w3, #10
    udiv w4, w0, w3
    msub w7, w4, w3, w0
    add w7, w7, #'0'
    strb w7, [x6]
    mov w0, w4
    cbz w0, 3f
    sub x6, x6, #1
    b 2b
3:

    // .data section with string literals
    adrp x0, _fg_data@PAGE
    add x0, x0, _fg_data@PAGEOFF
    bl _emit_str

    // emit each string as _sN: .byte ...
    adrp x19, _str_count@PAGE
    add x19, x19, _str_count@PAGEOFF
    ldr w19, [x19]
    mov x20, #0                  // index

_ef_str_loop:
    cmp w20, w19
    b.ge _ef_str_done

    // "_sN: .byte "
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_sd_byte@PAGE
    add x0, x0, _fg_sd_byte@PAGEOFF
    bl _emit_str

    // load string ptr and raw len
    adrp x21, _str_ptrs@PAGE
    add x21, x21, _str_ptrs@PAGEOFF
    ldr x21, [x21, x20, lsl #3]
    adrp x22, _str_lens@PAGE
    add x22, x22, _str_lens@PAGEOFF
    ldr w22, [x22, x20, lsl #2]

    // emit bytes with escape processing
    mov x23, #0                  // src index
    mov x25, #0                  // first flag
_ef_byte_loop:
    cmp w23, w22
    b.ge _ef_byte_done
    cbnz x25, _ef_comma
    mov x25, #1
    b _ef_no_comma
_ef_comma:
    adrp x0, _fg_comma@PAGE
    add x0, x0, _fg_comma@PAGEOFF
    bl _emit_str
_ef_no_comma:
    ldrb w0, [x21, x23]
    cmp w0, #'\\'
    b.ne _ef_normal
    add x23, x23, #1
    ldrb w0, [x21, x23]
    cmp w0, #'n'
    b.ne 1f
    mov x0, #10
    b _ef_val
1:  cmp w0, #'t'
    b.ne 2f
    mov x0, #9
    b _ef_val
2:  cmp w0, #'\\'
    b.ne 3f
    mov x0, #92
    b _ef_val
3:  cmp w0, #'"'
    b.ne 4f
    mov x0, #34
    b _ef_val
4:  and x0, x0, #0xFF
    b _ef_val
_ef_normal:
    and x0, x0, #0xFF
_ef_val:
    bl _emit_num
    add x23, x23, #1
    b _ef_byte_loop
_ef_byte_done:
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    add x20, x20, #1
    b _ef_str_loop

_ef_str_done:
    // .bss section
    adrp x0, _fg_bss@PAGE
    add x0, x0, _fg_bss@PAGEOFF
    bl _emit_str

    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_label - Emit "_LN:\n" where N = x0
// ────────────────────────────────────────
.globl _emit_label
_emit_label:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    adrp x0, _fg_lbl@PAGE
    add x0, x0, _fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_colon@PAGE
    add x0, x0, _fg_colon@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_branch - Emit "    b _LN\n"
// ────────────────────────────────────────
.globl _emit_branch
_emit_branch:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    adrp x0, _fg_b@PAGE
    add x0, x0, _fg_b@PAGEOFF
    bl _emit_str
    adrp x0, _fg_lbl@PAGE
    add x0, x0, _fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _new_label - Return next label number
// ────────────────────────────────────────
.globl _new_label
_new_label:
    adrp x1, _lbl_count@PAGE
    add x1, x1, _lbl_count@PAGEOFF
    ldr w0, [x1]
    add w2, w0, #1
    str w2, [x1]
    ret

// ────────────────────────────────────────
// Runtime code templates (emitted as text)
// ────────────────────────────────────────
.section __DATA,__data

_rt_itoa_code:
    .ascii "_rt_itoa:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    mov x29, sp\n"
    .ascii "    adrp x1, _itoa_buf@PAGE\n"
    .ascii "    add x1, x1, _itoa_buf@PAGEOFF\n"
    .ascii "    mov x2, x1\n"
    .ascii "    add x8, x1, #12\n"
    .ascii "    mov x3, #0\n"
    .ascii "    cmp x0, #0\n"
    .ascii "    b.ge 1f\n"
    .ascii "    mov w4, #45\n"
    .ascii "    strb w4, [x2], #1\n"
    .ascii "    neg x0, x0\n"
    .ascii "    mov x3, #1\n"
    .ascii "1:  mov x4, #0\n"
    .ascii "    cbz x0, 3f\n"
    .ascii "2:  cbz x0, 4f\n"
    .ascii "    mov x5, #10\n"
    .ascii "    udiv x6, x0, x5\n"
    .ascii "    msub x7, x6, x5, x0\n"
    .ascii "    add w7, w7, #48\n"
    .ascii "    strb w7, [x8, x4]\n"
    .ascii "    add x4, x4, #1\n"
    .ascii "    mov x0, x6\n"
    .ascii "    b 2b\n"
    .ascii "3:  mov w7, #48\n"
    .ascii "    strb w7, [x8]\n"
    .ascii "    mov x4, #1\n"
    .ascii "4:  add x3, x3, x4\n"
    .ascii "    sub x4, x4, #1\n"
    .ascii "5:  ldrb w7, [x8, x4]\n"
    .ascii "    strb w7, [x2], #1\n"
    .ascii "    cbz x4, 6f\n"
    .ascii "    sub x4, x4, #1\n"
    .ascii "    b 5b\n"
    .ascii "6:  strb wzr, [x2]\n"
    .ascii "    mov x0, x3\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

_rt_atoi_code:
    .ascii "_rt_atoi:\n"
    .ascii "    mov x1, #0\n"
    .ascii "    mov x2, #0\n"
    .ascii "    ldrb w3, [x0]\n"
    .ascii "    cmp w3, #45\n"
    .ascii "    b.ne 1f\n"
    .ascii "    mov x2, #1\n"
    .ascii "    add x0, x0, #1\n"
    .ascii "1:  ldrb w3, [x0]\n"
    .ascii "    sub w4, w3, #48\n"
    .ascii "    cmp w4, #9\n"
    .ascii "    b.hi 2f\n"
    .ascii "    mov x5, #10\n"
    .ascii "    mul x1, x1, x5\n"
    .ascii "    add x1, x1, x4\n"
    .ascii "    add x0, x0, #1\n"
    .ascii "    b 1b\n"
    .ascii "2:  cbz x2, 3f\n"
    .ascii "    neg x1, x1\n"
    .ascii "3:  mov x0, x1\n"
    .ascii "    ret\n\n"
    .byte 0

_rt_readline_code:
    .ascii "_rt_read_line:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    adrp x1, _input_buf@PAGE\n"
    .ascii "    add x1, x1, _input_buf@PAGEOFF\n"
    .ascii "    mov x19, x1\n"
    .ascii "    mov x0, #0\n"
    .ascii "    mov x2, #1023\n"
    .ascii "    mov x16, #3\n"
    .ascii "    svc #0x80\n"
    .ascii "    cbz x0, 1f\n"
    .ascii "    sub x1, x0, #1\n"
    .ascii "    ldrb w2, [x19, x1]\n"
    .ascii "    cmp w2, #10\n"
    .ascii "    b.ne 1f\n"
    .ascii "    mov x0, x1\n"
    .ascii "    strb wzr, [x19, x1]\n"
    .ascii "1:  ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

_rt_bufwrite_code:
    .ascii "_rt_buf_write:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    stp x21, x22, [sp, #-16]!\n"
    .ascii "    mov x19, x1\n"
    .ascii "    mov x20, x2\n"
    .ascii "    adrp x21, _ob_pos@PAGE\n"
    .ascii "    add x21, x21, _ob_pos@PAGEOFF\n"
    .ascii "    ldr x22, [x21]\n"
    .ascii "    add x3, x22, x20\n"
    .ascii "    cmp x3, #4096\n"
    .ascii "    b.lt 1f\n"
    .ascii "    bl _rt_flush\n"
    .ascii "    mov x22, #0\n"
    .ascii "1:  adrp x3, _ob_buf@PAGE\n"
    .ascii "    add x3, x3, _ob_buf@PAGEOFF\n"
    .ascii "    add x3, x3, x22\n"
    .ascii "    mov x4, #0\n"
    .ascii "2:  cmp x4, x20\n"
    .ascii "    b.ge 3f\n"
    .ascii "    ldrb w5, [x19, x4]\n"
    .ascii "    strb w5, [x3, x4]\n"
    .ascii "    add x4, x4, #1\n"
    .ascii "    b 2b\n"
    .ascii "3:  add x22, x22, x20\n"
    .ascii "    str x22, [x21]\n"
    .ascii "    ldp x21, x22, [sp], #16\n"
    .ascii "    ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

_rt_flush_code:
    .ascii "_rt_flush:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    adrp x1, _ob_pos@PAGE\n"
    .ascii "    add x1, x1, _ob_pos@PAGEOFF\n"
    .ascii "    ldr x2, [x1]\n"
    .ascii "    cbz x2, 1f\n"
    .ascii "    mov x0, #1\n"
    .ascii "    adrp x1, _ob_buf@PAGE\n"
    .ascii "    add x1, x1, _ob_buf@PAGEOFF\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    adrp x1, _ob_pos@PAGE\n"
    .ascii "    add x1, x1, _ob_pos@PAGEOFF\n"
    .ascii "    str xzr, [x1]\n"
    .ascii "1:  ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// ── v0.5: File I/O runtime ──

// _rt_open_r: x0=path_ptr, x1=path_len → x0=fd (or -1 on error)
_rt_open_r_code:
    .ascii "_rt_open_r:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    mov x20, x1\n"
    .ascii "    cmp x20, #255\n"
    .ascii "    b.lt 0f\n"
    .ascii "    mov x20, #255\n"
    .ascii "0:  adrp x2, _path_buf@PAGE\n"
    .ascii "    add x2, x2, _path_buf@PAGEOFF\n"
    .ascii "    mov x3, #0\n"
    .ascii "1:  cmp x3, x20\n"
    .ascii "    b.ge 2f\n"
    .ascii "    ldrb w4, [x19, x3]\n"
    .ascii "    strb w4, [x2, x3]\n"
    .ascii "    add x3, x3, #1\n"
    .ascii "    b 1b\n"
    .ascii "2:  strb wzr, [x2, x3]\n"
    .ascii "    mov x0, x2\n"
    .ascii "    mov x1, #0\n"
    .ascii "    mov x2, #0\n"
    .ascii "    mov x16, #5\n"
    .ascii "    svc #0x80\n"
    .ascii "    b.cc 3f\n"
    .ascii "    mov x0, #-1\n"
    .ascii "3:  ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_open_w: x0=path_ptr, x1=path_len → x0=fd (or -1 on error)
_rt_open_w_code:
    .ascii "_rt_open_w:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    mov x20, x1\n"
    .ascii "    cmp x20, #255\n"
    .ascii "    b.lt 0f\n"
    .ascii "    mov x20, #255\n"
    .ascii "0:  adrp x2, _path_buf@PAGE\n"
    .ascii "    add x2, x2, _path_buf@PAGEOFF\n"
    .ascii "    mov x3, #0\n"
    .ascii "1:  cmp x3, x20\n"
    .ascii "    b.ge 2f\n"
    .ascii "    ldrb w4, [x19, x3]\n"
    .ascii "    strb w4, [x2, x3]\n"
    .ascii "    add x3, x3, #1\n"
    .ascii "    b 1b\n"
    .ascii "2:  strb wzr, [x2, x3]\n"
    .ascii "    mov x0, x2\n"
    .ascii "    mov x1, #0x601\n"
    .ascii "    mov x2, #420\n"
    .ascii "    mov x16, #5\n"
    .ascii "    svc #0x80\n"
    .ascii "    b.cc 3f\n"
    .ascii "    mov x0, #-1\n"
    .ascii "3:  ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_close: x0=fd
_rt_close_code:
    .ascii "_rt_close:\n"
    .ascii "    mov x16, #6\n"
    .ascii "    svc #0x80\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_read_line_fd: x0=fd → x0=len, data in _input_buf
_rt_readline_fd_code:
    .ascii "_rt_read_line_fd:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    adrp x20, _input_buf@PAGE\n"
    .ascii "    add x20, x20, _input_buf@PAGEOFF\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, x20\n"
    .ascii "    mov x2, #1023\n"
    .ascii "    mov x16, #3\n"
    .ascii "    svc #0x80\n"
    .ascii "    cmp x0, #0\n"
    .ascii "    b.le 1f\n"
    .ascii "    sub x1, x0, #1\n"
    .ascii "    ldrb w2, [x20, x1]\n"
    .ascii "    cmp w2, #10\n"
    .ascii "    b.ne 1f\n"
    .ascii "    mov x0, x1\n"
    .ascii "    strb wzr, [x20, x1]\n"
    .ascii "1:  strb wzr, [x20, x0]\n"
    .ascii "    ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_write_line: x0=fd, x1=ptr, x2=len
_rt_write_line_code:
    .ascii "_rt_write_line:\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    ret\n\n"
    .byte 0

// ── v0.5: AI-native I/O runtime ──

// _rt_emit_int: x0=key_ptr, x1=key_len, x2=int_value → stdout {"key":42}\n
_rt_emit_int_code:
    .ascii "_rt_emit_int:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    stp x21, x22, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    mov x20, x1\n"
    .ascii "    mov x21, x2\n"
    .ascii "    bl _rt_flush\n"
    .ascii "    mov x0, #1\n"
    .ascii "    sub sp, sp, #16\n"
    .ascii "    mov w3, #123\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #2\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, x19\n"
    .ascii "    mov x2, x20\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #58\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #2\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, x21\n"
    .ascii "    bl _rt_itoa\n"
    .ascii "    mov x2, x0\n"
    .ascii "    mov x0, #1\n"
    .ascii "    adrp x1, _itoa_buf@PAGE\n"
    .ascii "    add x1, x1, _itoa_buf@PAGEOFF\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #125\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #10\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #2\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    add sp, sp, #16\n"
    .ascii "    ldp x21, x22, [sp], #16\n"
    .ascii "    ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_emit_str: x0=key_ptr, x1=key_len, x2=val_ptr, x3=val_len → stdout {"key":"val"}\n
_rt_emit_str_code:
    .ascii "_rt_emit_str:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    stp x21, x22, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    mov x20, x1\n"
    .ascii "    mov x21, x2\n"
    .ascii "    mov x22, x3\n"
    .ascii "    bl _rt_flush\n"
    .ascii "    sub sp, sp, #16\n"
    .ascii "    mov w3, #123\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #2\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, x19\n"
    .ascii "    mov x2, x20\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #58\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp, #2]\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #3\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, x21\n"
    .ascii "    mov x2, x22\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #125\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov w3, #10\n"
    .ascii "    strb w3, [sp, #2]\n"
    .ascii "    mov x0, #1\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #3\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    add sp, sp, #16\n"
    .ascii "    ldp x21, x22, [sp], #16\n"
    .ascii "    ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// ── v0.5: Concurrency runtime ──

// _rt_pipe: → x0=read_fd, x1=write_fd
_rt_pipe_code:
    .ascii "_rt_pipe:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    sub sp, sp, #16\n"
    .ascii "    mov x0, sp\n"
    .ascii "    mov x16, #42\n"
    .ascii "    svc #0x80\n"
    .ascii "    ldr w0, [sp]\n"
    .ascii "    ldr w1, [sp, #4]\n"
    .ascii "    add sp, sp, #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_wait: x0=pid → x0=exit_status
_rt_wait_code:
    .ascii "_rt_wait:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    sub sp, sp, #16\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #0\n"
    .ascii "    mov x3, #0\n"
    .ascii "    mov x16, #7\n"
    .ascii "    svc #0x80\n"
    .ascii "    ldr w0, [sp]\n"
    .ascii "    lsr w0, w0, #8\n"
    .ascii "    and w0, w0, #0xFF\n"
    .ascii "    add sp, sp, #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_send: x0=write_fd, x1=key_ptr, x2=key_len, x3=val_ptr, x4=val_len
// Writes {"key":value}\n or {"key":"value"}\n to fd
// For simplicity, sends as {"key":"value"}\n (string format)
_rt_send_code:
    .ascii "_rt_send:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    stp x21, x22, [sp, #-16]!\n"
    .ascii "    stp x23, x24, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    mov x20, x1\n"
    .ascii "    mov x21, x2\n"
    .ascii "    mov x22, x3\n"
    .ascii "    mov x23, x4\n"
    .ascii "    sub sp, sp, #16\n"
    .ascii "    mov w3, #123\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #2\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, x20\n"
    .ascii "    mov x2, x21\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #58\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp, #2]\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #3\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, x22\n"
    .ascii "    mov x2, x23\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    mov w3, #34\n"
    .ascii "    strb w3, [sp]\n"
    .ascii "    mov w3, #125\n"
    .ascii "    strb w3, [sp, #1]\n"
    .ascii "    mov w3, #10\n"
    .ascii "    strb w3, [sp, #2]\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, sp\n"
    .ascii "    mov x2, #3\n"
    .ascii "    mov x16, #4\n"
    .ascii "    svc #0x80\n"
    .ascii "    add sp, sp, #16\n"
    .ascii "    ldp x23, x24, [sp], #16\n"
    .ascii "    ldp x21, x22, [sp], #16\n"
    .ascii "    ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0

// _rt_recv: x0=read_fd → x0=val_ptr (in _recv_buf), x1=val_len
// Reads one line from fd, parses minimal JSON {"key":"value"}\n
// Returns pointer to value and its length
_rt_recv_code:
    .ascii "_rt_recv:\n"
    .ascii "    stp x29, x30, [sp, #-16]!\n"
    .ascii "    stp x19, x20, [sp, #-16]!\n"
    .ascii "    mov x19, x0\n"
    .ascii "    adrp x20, _recv_buf@PAGE\n"
    .ascii "    add x20, x20, _recv_buf@PAGEOFF\n"
    .ascii "    mov x0, x19\n"
    .ascii "    mov x1, x20\n"
    .ascii "    mov x2, #1023\n"
    .ascii "    mov x16, #3\n"
    .ascii "    svc #0x80\n"
    .ascii "    cmp x0, #0\n"
    .ascii "    b.le 9f\n"
    .ascii "    mov x3, x0\n"
    .ascii "    mov x4, #0\n"
    .ascii "5:  cmp x4, x3\n"
    .ascii "    b.ge 9f\n"
    .ascii "    ldrb w5, [x20, x4]\n"
    .ascii "    cmp w5, #58\n"
    .ascii "    b.eq 6f\n"
    .ascii "    add x4, x4, #1\n"
    .ascii "    b 5b\n"
    .ascii "6:  add x4, x4, #1\n"
    .ascii "    ldrb w5, [x20, x4]\n"
    .ascii "    cmp w5, #34\n"
    .ascii "    b.ne 7f\n"
    .ascii "    add x4, x4, #1\n"
    .ascii "7:  add x0, x20, x4\n"
    .ascii "    sub x1, x3, x4\n"
    .ascii "    cmp x1, #0\n"
    .ascii "    b.le 9f\n"
    .ascii "    sub x1, x1, #1\n"
    .ascii "    ldrb w5, [x0, x1]\n"
    .ascii "    cmp w5, #10\n"
    .ascii "    b.ne 8f\n"
    .ascii "    sub x1, x1, #1\n"
    .ascii "8:  ldrb w5, [x0, x1]\n"
    .ascii "    cmp w5, #34\n"
    .ascii "    b.ne 10f\n"
    .ascii "    sub x1, x1, #1\n"
    .ascii "10: ldrb w5, [x0, x1]\n"
    .ascii "    cmp w5, #125\n"
    .ascii "    b.ne 11f\n"
    .ascii "    sub x1, x1, #1\n"
    .ascii "11: add x1, x1, #1\n"
    .ascii "    b 12f\n"
    .ascii "9:  mov x0, x20\n"
    .ascii "    mov x1, #0\n"
    .ascii "12: ldp x19, x20, [sp], #16\n"
    .ascii "    ldp x29, x30, [sp], #16\n"
    .ascii "    ret\n\n"
    .byte 0
