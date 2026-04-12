// ============================================================
// data.s - Data section + BSS definitions
// All symbols .globl for cross-module access
// ============================================================
.include "src/macos_arm64/defs.inc"

// ── Data Section ──
.section __DATA,__data

.globl _err_usage, _err_open, _err_syntax, _err_indent
.globl _err_undef, _err_type, _err_nolegna, _err_asm, _err_link
.globl _err_nl, _msg_ok
_err_usage:    .asciz "usage: legnac <file.legna|.lga> [-o output]\n"
_err_open:     .asciz "error: cannot open source file\n"
_err_syntax:   .asciz "error: unexpected token at line "
_err_indent:   .asciz "error: bad indentation at line "
_err_undef:    .asciz "error: undefined variable at line "
_err_type:     .asciz "error: type mismatch at line "
_err_nolegna:  .asciz "error: missing 'legna:' entry\n"
_err_asm:      .asciz "error: assembler failed\n"
_err_link:     .asciz "error: linker failed\n"
_err_nl:       .asciz "\n"
_msg_ok:       .asciz "compiled successfully\n"

.globl _kw_legna, _kw_output, _kw_let, _kw_if, _kw_else
.globl _kw_while, _kw_for, _kw_in, _kw_input_num, _kw_input_str
_kw_legna:     .asciz "legna"
_kw_output:    .asciz "output"
_kw_let:       .asciz "let"
_kw_if:        .asciz "if"
_kw_else:      .asciz "else"
_kw_while:     .asciz "while"
_kw_for:       .asciz "for"
_kw_in:        .asciz "in"
_kw_input_num: .asciz "input_num"
_kw_input_str: .asciz "input_str"

.globl _path_as, _path_ld, _tmp_prefix, _tmp_ext_s, _tmp_ext_o
.globl _lnk_o, _lnk_lsys, _lnk_syslib, _lnk_sdk
.globl _lnk_e, _lnk_main, _lnk_arch, _lnk_arm64, _lnk_dead, _lnk_x
_path_as:      .asciz "/usr/bin/as"
_path_ld:      .asciz "/usr/bin/ld"
_tmp_prefix:   .asciz "/tmp/legna_"
_tmp_ext_s:    .asciz ".s"
_tmp_ext_o:    .asciz ".o"
_lnk_o:        .asciz "-o"
_lnk_lsys:    .asciz "-lSystem"
_lnk_syslib:  .asciz "-syslibroot"
_lnk_sdk:      .asciz "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
_lnk_e:        .asciz "-e"
_lnk_main:     .asciz "_main"
_lnk_arch:     .asciz "-arch"
_lnk_arm64:    .asciz "arm64"
_lnk_dead:     .asciz "-dead_strip"
_lnk_x:        .asciz "-x"

// ── Codegen fragments ──
.globl _fg_hdr, _fg_text, _fg_data, _fg_bss, _fg_nl, _fg_comma
.globl _fg_main, _fg_main2, _fg_exit
.globl _fg_ldr, _fg_ldr1, _fg_str_x0, _fg_cb, _fg_mov, _fg_movn
.globl _fg_push, _fg_pop1, _fg_add, _fg_sub, _fg_mul, _fg_sdiv, _fg_mod
.globl _fg_cmp0, _fg_cmp1
.globl _fg_ble, _fg_bge, _fg_blt, _fg_bgt, _fg_bne, _fg_beq
.globl _fg_b, _fg_lbl, _fg_colon
.globl _fg_wr_fd, _fg_wr_adrp, _fg_wr_add, _fg_wr_len, _fg_wr_sys
.globl _fg_page, _fg_poff, _fg_sd, _fg_sd_byte
.globl _fg_itoa_call, _fg_str_out
.globl _fg_input_call, _fg_atoi_call, _fg_inbuf_ptr, _fg_add1

_fg_hdr:       .ascii ".global _main\n.align 2\n\n"
               .byte 0
_fg_text:      .asciz ".text\n"
_fg_data:      .asciz "\n.data\n"
_fg_bss:       .asciz "\n.bss\n.align 4\n_input_buf: .space 1024\n_itoa_buf: .space 24\n"
_fg_nl:        .asciz "\n"
_fg_comma:     .asciz ", "
_fg_main:      .ascii "_main:\n    stp x29, x30, [sp, #-16]!\n    mov x29, sp\n    sub sp, sp, #"
               .byte 0
_fg_main2:     .asciz "\n"
_fg_exit:      .ascii "    mov sp, x29\n    ldp x29, x30, [sp], #16\n    mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
               .byte 0
_fg_ldr:       .asciz "    ldr x0, [x29, #-"
_fg_ldr1:      .asciz "    ldr x1, [x29, #-"
_fg_str_x0:    .asciz "    str x0, [x29, #-"
_fg_cb:        .asciz "]\n"
_fg_mov:       .asciz "    mov x0, #"
_fg_movn:      .asciz "    mov x0, #-"
_fg_push:      .asciz "    str x0, [sp, #-16]!\n"
_fg_pop1:      .asciz "    ldr x1, [sp], #16\n"
_fg_add:       .asciz "    add x0, x1, x0\n"
_fg_sub:       .asciz "    sub x0, x1, x0\n"
_fg_mul:       .asciz "    mul x0, x1, x0\n"
_fg_sdiv:      .asciz "    sdiv x0, x1, x0\n"
_fg_mod:       .ascii "    sdiv x2, x1, x0\n    msub x0, x2, x0, x1\n"
               .byte 0
_fg_cmp0:      .asciz "    cmp x0, #"
_fg_cmp1:      .asciz "    cmp x1, x0\n"
_fg_ble:       .asciz "    b.le "
_fg_bge:       .asciz "    b.ge "
_fg_blt:       .asciz "    b.lt "
_fg_bgt:       .asciz "    b.gt "
_fg_bne:       .asciz "    b.ne "
_fg_beq:       .asciz "    b.eq "
_fg_b:         .asciz "    b "
_fg_lbl:       .asciz "_L"
_fg_colon:     .asciz ":\n"
_fg_wr_fd:     .asciz "    mov x0, #1\n"
_fg_wr_adrp:   .asciz "    adrp x1, "
_fg_wr_add:    .asciz "    add x1, x1, "
_fg_wr_len:    .asciz "    mov x2, #"
_fg_wr_sys:    .ascii "    mov x16, #4\n    svc #0x80\n"
               .byte 0
_fg_page:      .asciz "@PAGE\n"
_fg_poff:      .asciz "@PAGEOFF\n"
_fg_sd:        .asciz "_s"
_fg_sd_byte:   .asciz ": .byte "
_fg_itoa_call: .ascii "    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    bl _rt_itoa\n    mov x2, x0\n    mov x0, #1\n    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    mov x16, #4\n    svc #0x80\n"
               .byte 0
_fg_str_out:   .ascii "    mov x0, #1\n    mov x16, #4\n    svc #0x80\n"
               .byte 0
_fg_input_call: .ascii "    bl _rt_read_line\n"
                .byte 0
_fg_atoi_call:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n    bl _rt_atoi\n"
                .byte 0
_fg_inbuf_ptr:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n"
                .byte 0
_fg_add1:      .asciz "    add x0, x0, #1\n"

// ── BSS Section ──
.section __DATA,__bss

.globl _src_buf, _out_buf, _out_name, _src_len, _out_pos
.globl _tok_buf, _tok_count, _tok_pos
.globl _sym_tab, _sym_count, _frame_size
.globl _ind_stack, _ind_sp
.globl _lbl_count
.globl _str_ptrs, _str_lens, _str_bytes, _str_count
.globl _wait_stat, _num_buf, _tmp_path_s, _tmp_path_o, _line_num

.align 4
_src_buf:     .space BUF_SIZE
_out_buf:     .space BUF_SIZE
_out_name:    .space 256
_src_len:     .space 8
_out_pos:     .space 8
_tok_buf:     .space 98304       // 4096 * 24
_tok_count:   .space 4
_tok_pos:     .space 4
_sym_tab:     .space 4096        // 128 * 32
_sym_count:   .space 4
_frame_size:  .space 4
_ind_stack:   .space 256         // 64 * 4
_ind_sp:      .space 4
_lbl_count:   .space 4
_str_ptrs:    .space 2048        // 256 * 8
_str_lens:    .space 1024        // 256 * 4
_str_bytes:   .space 1024        // 256 * 4
_str_count:   .space 4
_wait_stat:   .space 4
_num_buf:     .space 24
_tmp_path_s:  .space 64
_tmp_path_o:  .space 64
_line_num:    .space 4
