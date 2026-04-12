// ============================================================
// legnac - The Legna Language Compiler
// Platform: macOS ARM64 (Apple Silicon)
// Pure assembly, no C runtime
// ============================================================

// Syscall numbers
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
.equ O_WRCREAT,   0x601          // O_WRONLY|O_CREAT|O_TRUNC

.equ STDOUT,      1
.equ STDERR,      2
.equ BUF_SIZE,    65536

// ── Data Section ──
.section __DATA,__data

err_usage:    .asciz "usage: legnac <file.legna> [-o output]\n"
err_open:     .asciz "error: cannot open source file\n"
err_nolegna:  .asciz "error: missing 'legna:' entry point\n"
err_string:   .asciz "error: unterminated string\n"
err_syntax:   .asciz "error: unexpected syntax in legna block\n"
err_asm:      .asciz "error: assembler failed\n"
err_link:     .asciz "error: linker failed\n"
msg_ok:       .asciz "compiled successfully\n"

kw_legna:     .asciz "legna:"
kw_output:    .asciz "output"

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
path_strip:   .asciz "/usr/bin/strip"

// Assembly fragments for codegen (batched single-syscall output)
frag_header:
    .ascii ".global _main\n.align 2\n\n.text\n_main:\n"
    .byte 0
frag_wr_pre:
    .ascii "    mov x0, #1\n    adrp x1, _d@PAGE\n    add x1, x1, _d@PAGEOFF\n    mov x2, #"
    .byte 0
frag_wr_post:
    .ascii "\n    mov x16, #4\n    svc #0x80\n"
    .byte 0
frag_exit:
    .ascii "    mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
    .byte 0
frag_data:
    .ascii "\n.data\n_d: .byte "
    .byte 0
frag_comma:   .asciz ", "
frag_nl:      .asciz "\n"

// ── BSS Section ──
.section __DATA,__bss

.lcomm src_buf,     BUF_SIZE
.lcomm out_buf,     BUF_SIZE
.lcomm out_name,    256
.lcomm src_len,     8
.lcomm out_pos,     8
.lcomm str_ptrs,    512          // up to 64 string pointers
.lcomm str_lens,    256          // up to 64 string lengths
.lcomm str_count,   4
.lcomm byte_lens,   256          // actual byte lengths after escape processing
.lcomm wait_stat,   4
.lcomm num_buf,     24
.lcomm tmp_path_s,  64           // PID-based temp .s path
.lcomm tmp_path_o,  64           // PID-based temp .o path

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
    stp x23, x24, [sp, #-16]!

    mov x19, x0                 // argc
    mov x20, x1                 // argv

    // need at least 2 args
    cmp x19, #2
    b.lt _usage_exit

    // x21 = input filename (argv[1])
    ldr x21, [x20, #8]

    // default output name = strip .legna extension
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    mov x1, x21
    bl _strip_ext

    // check for -o flag
    cmp x19, #4
    b.lt 1f
    ldr x0, [x20, #16]          // argv[2]
    ldrb w1, [x0]
    cmp w1, #'-'
    b.ne 1f
    ldrb w1, [x0, #1]
    cmp w1, #'o'
    b.ne 1f
    // copy argv[3] to out_name
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    ldr x1, [x20, #24]
    bl _strcpy
1:
    // build PID-based temp file paths
    bl _build_tmp_paths

    // read source file
    mov x0, x21
    bl _read_file
    cmp x0, #0
    b.lt _err_open

    // parse source
    bl _parse_source
    cmp x0, #0
    b.lt _err_syntax

    // generate assembly
    bl _gen_asm

    // write temp .s file
    bl _write_asm
    cmp x0, #0
    b.lt _err_open

    // assemble
    bl _run_as
    cmp x0, #0
    b.ne _err_asm

    // link with -dead_strip -x (already strips symbols)
    bl _run_ld
    cmp x0, #0
    b.ne _err_link

    // cleanup temp files
    bl _cleanup

    // print success
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
_err_syntax:
    adrp x0, err_syntax@PAGE
    add x0, x0, err_syntax@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit
_err_asm:
    adrp x0, err_asm@PAGE
    add x0, x0, err_asm@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit
_err_link:
    adrp x0, err_link@PAGE
    add x0, x0, err_link@PAGEOFF
    bl _print_err
    mov x0, #1
    b _exit

_exit:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// String helpers
// ────────────────────────────────────────

// _strlen: x0 = str → x0 = length
_strlen:
    mov x1, x0
    mov x0, #0
1:  ldrb w2, [x1, x0]
    cbz w2, 2f
    add x0, x0, #1
    b 1b
2:  ret

// _strcpy: x0 = dest, x1 = src
_strcpy:
    mov x2, #0
1:  ldrb w3, [x1, x2]
    strb w3, [x0, x2]
    cbz w3, 2f
    add x2, x2, #1
    b 1b
2:  ret

// _strncmp: x0 = s1, x1 = s2, x2 = n → x0 = 0 if equal
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

// _print_err: x0 = string, print to stderr
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

// _strip_ext: x0 = dest, x1 = src (copy src, strip .legna)
_strip_ext:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0                 // dest
    mov x20, x1                 // src
    bl _strcpy
    // find last '.' in dest
    mov x0, x19
    bl _strlen
    mov x2, x0                  // len
    sub x2, x2, #1
1:  cmp x2, #0
    b.lt 2f
    ldrb w3, [x19, x2]
    cmp w3, #'.'
    b.eq 3f
    sub x2, x2, #1
    b 1b
3:  // found dot, null-terminate there
    strb wzr, [x19, x2]
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _itoa: x0 = number, x1 = buffer → x0 = length (null-terminates)
_itoa:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0                 // number
    mov x20, x1                 // output buffer
    adrp x21, num_buf@PAGE
    add x21, x21, num_buf@PAGEOFF
    mov x22, #0                 // digit count
    cbz x19, 3f
1:  cbz x19, 2f
    mov x3, #10
    udiv x4, x19, x3
    msub x5, x4, x3, x19
    add w5, w5, #'0'
    strb w5, [x21, x22]
    add x22, x22, #1
    mov x19, x4
    b 1b
3:  mov w5, #'0'
    strb w5, [x21]
    mov x22, #1
2:  // copy reversed digits to output
    mov x0, x22
    sub x22, x22, #1
    mov x3, #0
4:  ldrb w5, [x21, x22]
    strb w5, [x20, x3]
    add x3, x3, #1
    cbz x22, 5f
    sub x22, x22, #1
    b 4b
5:  strb wzr, [x20, x3]
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _build_tmp_paths: construct /tmp/legna_PID.s and .o
_build_tmp_paths:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    // getpid
    mov x16, #SYS_GETPID
    svc #0x80
    mov x19, x0                 // pid

    // build tmp_path_s = "/tmp/legna_<PID>.s"
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
    add x1, x20, x0             // end of prefix
    mov x0, x19
    bl _itoa                     // append PID digits
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    bl _strlen
    add x0, x20, x0
    adrp x1, tmp_ext_s@PAGE
    add x1, x1, tmp_ext_s@PAGEOFF
    bl _strcpy                   // append ".s"

    // build tmp_path_o = "/tmp/legna_<PID>.o"
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
// Emit helpers - append to out_buf
// ────────────────────────────────────────

// _emit_str: x0 = null-terminated string, append to out_buf
_emit_str:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    adrp x20, out_pos@PAGE
    add x20, x20, out_pos@PAGEOFF
    ldr x1, [x20]               // current pos
    adrp x2, out_buf@PAGE
    add x2, x2, out_buf@PAGEOFF
    add x2, x2, x1              // dest = out_buf + pos
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

// _emit_char: w0 = char, append to out_buf
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

// _emit_num: x0 = number, append decimal to out_buf
_emit_num:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0                 // number
    adrp x20, num_buf@PAGE
    add x20, x20, num_buf@PAGEOFF
    mov x21, #0                 // digit count
    cbz x19, 3f
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
2:  // emit digits in reverse order
    sub x21, x21, #1
4:  ldrb w0, [x20, x21]
    bl _emit_char
    cbz x21, 5f
    sub x21, x21, #1
    b 4b
5:  ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _emit_raw: x0 = ptr, x1 = len, append raw bytes to out_buf
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
// File I/O
// ────────────────────────────────────────

// _read_file: x0 = filename → x0 = bytes read (-1 on error)
_read_file:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    // open(filename, O_RDONLY)
    mov x0, x19
    mov x1, #O_RDONLY
    mov x2, #0
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs 1f                      // carry set = error
    mov x19, x0                  // fd
    // read(fd, src_buf, BUF_SIZE)
    mov x0, x19
    adrp x1, src_buf@PAGE
    add x1, x1, src_buf@PAGEOFF
    mov x2, #BUF_SIZE
    mov x16, #SYS_READ
    svc #0x80
    b.cs 1f
    mov x20, x0                  // bytes read
    // store src_len
    adrp x1, src_len@PAGE
    add x1, x1, src_len@PAGEOFF
    str x20, [x1]
    // null-terminate
    adrp x1, src_buf@PAGE
    add x1, x1, src_buf@PAGEOFF
    strb wzr, [x1, x20]
    // close(fd)
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80
    mov x0, x20
    b 2f
1:  mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _write_asm: write out_buf to tmp_path_s → x0 = 0 ok, -1 err
_write_asm:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    mov x1, #O_WRCREAT
    mov x2, #0x1A4               // 0644
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs 1f
    mov x19, x0                  // fd
    // write(fd, out_buf, out_pos)
    mov x0, x19
    adrp x1, out_buf@PAGE
    add x1, x1, out_buf@PAGEOFF
    adrp x2, out_pos@PAGE
    add x2, x2, out_pos@PAGEOFF
    ldr x2, [x2]
    mov x16, #SYS_WRITE
    svc #0x80
    // close
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80
    mov x0, #0
    b 2f
1:  mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_source - Parse .legna source
// Finds "legna:" then extracts output strings
// Returns x0 = 0 ok, -1 error
// ────────────────────────────────────────
_parse_source:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    adrp x19, src_buf@PAGE
    add x19, x19, src_buf@PAGEOFF   // x19 = source ptr
    adrp x20, src_len@PAGE
    add x20, x20, src_len@PAGEOFF
    ldr x20, [x20]                   // x20 = source length
    mov x21, #0                      // x21 = current pos
    mov x22, #0                      // x22 = found legna flag

    // Phase 1: find "legna:" line
_ps_next_line:
    cmp x21, x20
    b.ge _ps_check_found

    // check if line starts with space (indentation)
    ldrb w0, [x19, x21]
    mov x23, #0                      // x23 = indent level
_ps_count_indent:
    ldrb w0, [x19, x21]
    cmp w0, #' '
    b.ne _ps_indent_done
    add x23, x23, #1
    add x21, x21, #1
    b _ps_count_indent
_ps_indent_done:

    // skip blank lines
    ldrb w0, [x19, x21]
    cmp w0, #'\n'
    b.ne 1f
    add x21, x21, #1
    b _ps_next_line
1:
    // skip comment lines
    cmp w0, #'#'
    b.ne 2f
    bl _ps_skip_to_eol
    b _ps_next_line
2:
    // check for "legna:"
    cbz w22, _ps_try_legna

    // Phase 2: inside legna block - must be indented
    cbz x23, _ps_done               // no indent = end of block

    // skip blank/comment inside block
    ldrb w0, [x19, x21]
    cmp w0, #'\n'
    b.ne 3f
    add x21, x21, #1
    b _ps_next_line
3:  cmp w0, #'#'
    b.ne 4f
    bl _ps_skip_to_eol
    b _ps_next_line
4:
    // expect "output"
    adrp x0, kw_output@PAGE
    add x0, x0, kw_output@PAGEOFF
    add x1, x19, x21
    mov x2, #6
    bl _strncmp
    cbnz x0, _ps_fail

    add x21, x21, #6                // skip "output"

    // skip spaces after output
    bl _ps_skip_spaces

    // expect opening quote
    ldrb w0, [x19, x21]
    cmp w0, #'"'
    b.ne _ps_fail
    add x21, x21, #1                // skip quote

    // record string start
    add x23, x19, x21               // x23 = string start ptr
    mov x24, #0                     // x24 = string length

    // scan to closing quote (handle escapes)
5:  ldrb w0, [x19, x21]
    cbz w0, _ps_fail                // EOF without closing quote
    cmp w0, #'"'
    b.eq 6f
    cmp w0, #'\\'
    b.ne 7f
    add x21, x21, #1               // skip escape char
    add x24, x24, #1
7:  add x21, x21, #1
    add x24, x24, #1
    b 5b
6:  add x21, x21, #1               // skip closing quote

    // store string ptr and length
    adrp x0, str_ptrs@PAGE
    add x0, x0, str_ptrs@PAGEOFF
    adrp x1, str_lens@PAGE
    add x1, x1, str_lens@PAGEOFF
    adrp x2, str_count@PAGE
    add x2, x2, str_count@PAGEOFF
    ldr w3, [x2]
    str x23, [x0, x3, lsl #3]       // str_ptrs[count] = ptr
    str w24, [x1, x3, lsl #2]       // str_lens[count] = len
    add w3, w3, #1
    str w3, [x2]

    bl _ps_skip_to_eol
    b _ps_next_line

_ps_try_legna:
    adrp x0, kw_legna@PAGE
    add x0, x0, kw_legna@PAGEOFF
    add x1, x19, x21
    mov x2, #6                      // "legna:" = 6 chars
    bl _strncmp
    cbnz x0, _ps_fail
    add x21, x21, #6
    mov x22, #1                     // found legna
    bl _ps_skip_to_eol
    b _ps_next_line

_ps_check_found:
    cbz x22, _ps_fail
_ps_done:
    mov x0, #0
    b _ps_ret
_ps_fail:
    mov x0, #-1
_ps_ret:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// helper: skip spaces at current pos
_ps_skip_spaces:
1:  ldrb w0, [x19, x21]
    cmp w0, #' '
    b.ne 2f
    add x21, x21, #1
    b 1b
2:  ret

// helper: skip to end of line
_ps_skip_to_eol:
1:  cmp x21, x20
    b.ge 2f
    ldrb w0, [x19, x21]
    add x21, x21, #1
    cmp w0, #'\n'
    b.ne 1b
2:  ret

// ────────────────────────────────────────
// _gen_asm - Generate ARM64 assembly
// Batched single-syscall output, .byte data
// ────────────────────────────────────────
_gen_asm:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    // reset output position
    adrp x0, out_pos@PAGE
    add x0, x0, out_pos@PAGEOFF
    str xzr, [x0]

    // load string count
    adrp x19, str_count@PAGE
    add x19, x19, str_count@PAGEOFF
    ldr w19, [x19]               // x19 = count

    // compute actual byte lengths + total
    mov x20, #0                  // index
    mov x26, #0                  // x26 = total byte length
_ga_compute_lens:
    cmp w20, w19
    b.ge _ga_emit_code
    adrp x1, str_ptrs@PAGE
    add x1, x1, str_ptrs@PAGEOFF
    ldr x21, [x1, x20, lsl #3]
    adrp x1, str_lens@PAGE
    add x1, x1, str_lens@PAGEOFF
    ldr w22, [x1, x20, lsl #2]
    mov x23, #0
    mov x24, #0
_ga_cl_loop:
    cmp w23, w22
    b.ge _ga_cl_done
    ldrb w0, [x21, x23]
    cmp w0, #'\\'
    b.ne 1f
    add x23, x23, #1
1:  add x23, x23, #1
    add x24, x24, #1
    b _ga_cl_loop
_ga_cl_done:
    adrp x1, byte_lens@PAGE
    add x1, x1, byte_lens@PAGEOFF
    str w24, [x1, x20, lsl #2]
    add x26, x26, x24           // accumulate total
    add x20, x20, #1
    b _ga_compute_lens

_ga_emit_code:
    // emit header
    adrp x0, frag_header@PAGE
    add x0, x0, frag_header@PAGEOFF
    bl _emit_str

    // emit single batched write (only if total > 0)
    cbz x26, _ga_emit_exit
    adrp x0, frag_wr_pre@PAGE
    add x0, x0, frag_wr_pre@PAGEOFF
    bl _emit_str
    mov x0, x26
    bl _emit_num
    adrp x0, frag_wr_post@PAGE
    add x0, x0, frag_wr_post@PAGEOFF
    bl _emit_str

_ga_emit_exit:
    adrp x0, frag_exit@PAGE
    add x0, x0, frag_exit@PAGEOFF
    bl _emit_str

    // emit data section (only if total > 0)
    cbz x26, _ga_done
    adrp x0, frag_data@PAGE
    add x0, x0, frag_data@PAGEOFF
    bl _emit_str

    // emit ALL bytes from ALL strings as one .byte line
    mov x20, #0                  // string index
    mov x25, #0                  // first-byte flag
_ga_str_loop:
    cmp w20, w19
    b.ge _ga_data_end
    adrp x1, str_ptrs@PAGE
    add x1, x1, str_ptrs@PAGEOFF
    ldr x21, [x1, x20, lsl #3]
    adrp x1, str_lens@PAGE
    add x1, x1, str_lens@PAGEOFF
    ldr w22, [x1, x20, lsl #2]
    mov x23, #0
_ga_byte_loop:
    cmp w23, w22
    b.ge _ga_next_str
    cbnz x25, _ga_comma
    mov x25, #1
    b _ga_no_comma
_ga_comma:
    adrp x0, frag_comma@PAGE
    add x0, x0, frag_comma@PAGEOFF
    bl _emit_str
_ga_no_comma:
    ldrb w0, [x21, x23]
    cmp w0, #'\\'
    b.ne _ga_byte_normal
    add x23, x23, #1
    ldrb w0, [x21, x23]
    cmp w0, #'n'
    b.ne 1f
    mov x0, #10
    b _ga_byte_val
1:  cmp w0, #'t'
    b.ne 2f
    mov x0, #9
    b _ga_byte_val
2:  cmp w0, #'\\'
    b.ne 3f
    mov x0, #92
    b _ga_byte_val
3:  cmp w0, #'"'
    b.ne 4f
    mov x0, #34
    b _ga_byte_val
4:  and x0, x0, #0xFF
    b _ga_byte_val
_ga_byte_normal:
    and x0, x0, #0xFF
_ga_byte_val:
    bl _emit_num
    add x23, x23, #1
    b _ga_byte_loop
_ga_next_str:
    add x20, x20, #1
    b _ga_str_loop
_ga_data_end:
    adrp x0, frag_nl@PAGE
    add x0, x0, frag_nl@PAGEOFF
    bl _emit_str

_ga_done:
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _run_as - Fork+exec assembler
// Returns x0 = 0 on success
// ────────────────────────────────────────
_run_as:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #48              // argv[6] on stack

    // build argv: as -o tmp_path_o tmp_path_s NULL
    adrp x0, path_as@PAGE
    add x0, x0, path_as@PAGEOFF
    str x0, [sp]                 // argv[0]
    adrp x0, lnk_o@PAGE
    add x0, x0, lnk_o@PAGEOFF
    str x0, [sp, #8]            // argv[1] = "-o"
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    str x0, [sp, #16]           // argv[2] = tmp.o
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    str x0, [sp, #24]           // argv[3] = tmp.s
    str xzr, [sp, #32]          // argv[4] = NULL

    // fork (macOS: x1=0 parent, x1=1 child)
    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _ra_child

    // parent: x0 = child pid
    mov x19, x0
    mov x0, x19
    adrp x1, wait_stat@PAGE
    add x1, x1, wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    // check exit status
    adrp x0, wait_stat@PAGE
    add x0, x0, wait_stat@PAGEOFF
    ldr w0, [x0]
    // macOS: status is in bits 8-15 if exited normally
    lsr w0, w0, #8
    and w0, w0, #0xFF

    add sp, sp, #48
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_ra_child:
    // execve(path_as, argv, NULL)
    adrp x0, path_as@PAGE
    add x0, x0, path_as@PAGEOFF
    mov x1, sp                   // argv
    mov x2, #0                   // envp
    mov x16, #SYS_EXECVE
    svc #0x80
    // if execve returns, exit with error
    mov x0, #127
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// _run_ld - Fork+exec linker
// Returns x0 = 0 on success
// ────────────────────────────────────────
_run_ld:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #112             // argv[13] on stack

    // build argv: ld -o <out> tmp_path_o -lSystem -syslibroot <sdk> -e _main -arch arm64 -dead_strip -x NULL
    adrp x0, path_ld@PAGE
    add x0, x0, path_ld@PAGEOFF
    str x0, [sp]                 // [0] ld
    adrp x0, lnk_o@PAGE
    add x0, x0, lnk_o@PAGEOFF
    str x0, [sp, #8]            // [1] -o
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    str x0, [sp, #16]           // [2] output name
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    str x0, [sp, #24]           // [3] tmp.o
    adrp x0, lnk_lsys@PAGE
    add x0, x0, lnk_lsys@PAGEOFF
    str x0, [sp, #32]           // [4] -lSystem
    adrp x0, lnk_syslib@PAGE
    add x0, x0, lnk_syslib@PAGEOFF
    str x0, [sp, #40]           // [5] -syslibroot
    adrp x0, lnk_sdk@PAGE
    add x0, x0, lnk_sdk@PAGEOFF
    str x0, [sp, #48]           // [6] sdk path
    adrp x0, lnk_e@PAGE
    add x0, x0, lnk_e@PAGEOFF
    str x0, [sp, #56]           // [7] -e
    adrp x0, lnk_main@PAGE
    add x0, x0, lnk_main@PAGEOFF
    str x0, [sp, #64]           // [8] _main
    adrp x0, lnk_arch@PAGE
    add x0, x0, lnk_arch@PAGEOFF
    str x0, [sp, #72]           // [9] -arch
    adrp x0, lnk_arm64@PAGE
    add x0, x0, lnk_arm64@PAGEOFF
    str x0, [sp, #80]           // [10] arm64
    adrp x0, lnk_dead@PAGE
    add x0, x0, lnk_dead@PAGEOFF
    str x0, [sp, #88]           // [11] -dead_strip
    adrp x0, lnk_x@PAGE
    add x0, x0, lnk_x@PAGEOFF
    str x0, [sp, #96]           // [12] -x
    str xzr, [sp, #104]         // [13] NULL

    // fork (macOS: x1=0 parent, x1=1 child)
    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _rl_child

    // parent: x0 = child pid
    mov x19, x0
    mov x0, x19
    adrp x1, wait_stat@PAGE
    add x1, x1, wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    adrp x0, wait_stat@PAGE
    add x0, x0, wait_stat@PAGEOFF
    ldr w0, [x0]
    lsr w0, w0, #8
    and w0, w0, #0xFF

    add sp, sp, #112
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_rl_child:
    adrp x0, path_ld@PAGE
    add x0, x0, path_ld@PAGEOFF
    mov x1, sp
    mov x2, #0
    mov x16, #SYS_EXECVE
    svc #0x80
    mov x0, #127
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// _run_strip - Strip symbols from output binary
// ────────────────────────────────────────
_run_strip:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #32

    adrp x0, path_strip@PAGE
    add x0, x0, path_strip@PAGEOFF
    str x0, [sp]                 // argv[0] = strip
    adrp x0, out_name@PAGE
    add x0, x0, out_name@PAGEOFF
    str x0, [sp, #8]            // argv[1] = output binary
    str xzr, [sp, #16]          // argv[2] = NULL

    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _rs_child

    mov x19, x0
    mov x0, x19
    adrp x1, wait_stat@PAGE
    add x1, x1, wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    add sp, sp, #32
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_rs_child:
    adrp x0, path_strip@PAGE
    add x0, x0, path_strip@PAGEOFF
    mov x1, sp
    mov x2, #0
    mov x16, #SYS_EXECVE
    svc #0x80
    mov x0, #127
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// _cleanup - Remove temp files
// ────────────────────────────────────────
_cleanup:
    adrp x0, tmp_path_s@PAGE
    add x0, x0, tmp_path_s@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80
    adrp x0, tmp_path_o@PAGE
    add x0, x0, tmp_path_o@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80
    ret
