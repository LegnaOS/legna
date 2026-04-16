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
.globl _err_overflow, _err_frame
_err_usage:    .asciz "usage: legnac <file.legna|.lga> [-o output]\n"
_err_open:     .asciz "error: cannot open source file\n"
_err_syntax:   .asciz "error: unexpected token at line "
_err_indent:   .asciz "error: bad indentation at line "
_err_undef:    .asciz "error: undefined variable at line "
_err_type:     .asciz "error: type mismatch at line "
_err_nolegna:  .asciz "error: missing 'legna:' entry\n"
_err_asm:      .asciz "error: assembler failed\n"
_err_link:     .asciz "error: linker failed\n"
_err_overflow: .asciz "error: compiler buffer overflow\n"
_err_frame:    .asciz "error: stack frame too large\n"
_err_nl:       .asciz "\n"
_msg_ok:       .asciz "compiled successfully\n"

.globl _kw_legna, _kw_output, _kw_let, _kw_if, _kw_else, _kw_elif
.globl _kw_while, _kw_for, _kw_in, _kw_input_num, _kw_input_str
.globl _kw_break, _kw_continue, _kw_and, _kw_or, _kw_not
.globl _kw_fn, _kw_return
.globl _kw_spawn, _kw_wait, _kw_pipe, _kw_send, _kw_recv
.globl _kw_emit, _kw_open, _kw_close, _kw_read_line, _kw_write_line
.globl _kw_array
.globl _kw_len, _kw_char_at, _kw_to_str, _kw_to_num
.globl _kw_import
.globl _kw_extern, _kw_link
.globl _kw_struct
.globl _kw_switch, _kw_case, _kw_default
.globl _kw_peek, _kw_poke
.globl _kw_peek4, _kw_poke4, _kw_peek1, _kw_poke1
_kw_legna:     .asciz "legna"
_kw_output:    .asciz "output"
_kw_let:       .asciz "let"
_kw_if:        .asciz "if"
_kw_else:      .asciz "else"
_kw_elif:      .asciz "elif"
_kw_while:     .asciz "while"
_kw_for:       .asciz "for"
_kw_in:        .asciz "in"
_kw_input_num: .asciz "input_num"
_kw_input_str: .asciz "input_str"
_kw_break:     .asciz "break"
_kw_continue:  .asciz "continue"
_kw_and:       .asciz "and"
_kw_or:        .asciz "or"
_kw_not:       .asciz "not"
_kw_fn:        .asciz "fn"
_kw_return:    .asciz "return"
_kw_spawn:     .asciz "spawn"
_kw_wait:      .asciz "wait"
_kw_pipe:      .asciz "pipe"
_kw_send:      .asciz "send"
_kw_recv:      .asciz "recv"
_kw_emit:      .asciz "emit"
_kw_open:      .asciz "open"
_kw_close:     .asciz "close"
_kw_read_line: .asciz "read_line"
_kw_write_line:.asciz "write_line"
_kw_array:     .asciz "array"
_kw_len:       .asciz "len"
_kw_char_at:   .asciz "char_at"
_kw_to_str:    .asciz "to_str"
_kw_to_num:    .asciz "to_num"
_kw_import:    .asciz "import"
_kw_extern:    .asciz "extern"
_kw_link:      .asciz "link"
_kw_struct:    .asciz "struct"
_kw_switch:    .asciz "switch"
_kw_case:      .asciz "case"
_kw_default:   .asciz "default"
_kw_peek:      .asciz "peek"
_kw_poke:      .asciz "poke"
_kw_peek4:     .asciz "peek4"
_kw_poke4:     .asciz "poke4"
_kw_peek1:     .asciz "peek1"
_kw_poke1:     .asciz "poke1"

.globl _path_as, _path_ld, _tmp_prefix, _tmp_ext_s, _tmp_ext_o
.globl _lnk_o, _lnk_lsys, _lnk_syslib, _lnk_sdk
.globl _lnk_e, _lnk_main, _lnk_arch, _lnk_arm64, _lnk_dead, _lnk_x
.globl _lnk_framework
.globl _lnk_lbrew
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
_lnk_framework: .asciz "-framework"
_lnk_lbrew:    .asciz "-L/opt/homebrew/lib"

// ── Codegen fragments ──
.globl _fg_hdr, _fg_text, _fg_data, _fg_bss, _fg_nl, _fg_comma
.globl _fg_main, _fg_main2, _fg_frame_ph, _fg_exit
.globl _fg_ldr, _fg_ldr1, _fg_str_x0, _fg_cb, _fg_mov, _fg_movn
.globl _fg_push, _fg_pop0, _fg_pop1, _fg_add, _fg_sub, _fg_mul, _fg_sdiv, _fg_mod
.globl _fg_add_r, _fg_sub_r, _fg_mul_r, _fg_sdiv_r, _fg_mod_r
.globl _fg_and, _fg_orr, _fg_eor, _fg_mvn, _fg_lsl_op, _fg_lsr_op
.globl _fg_and_r, _fg_orr_r, _fg_eor_r, _fg_lsl_op_r, _fg_lsr_op_r
.globl _fg_mov_x1_x0, _fg_str_x1, _fg_sub_x0_x29
.globl _fg_peek, _fg_poke, _fg_poke_seq
.globl _fg_peek4, _fg_peek1, _fg_poke4_seq, _fg_poke1_seq
.globl _fg_cmp0, _fg_cmp1, _fg_cmp01
.globl _fg_ble, _fg_bge, _fg_blt, _fg_bgt, _fg_bne, _fg_beq
.globl _fg_b, _fg_lbl, _fg_colon
.globl _fg_wr_fd, _fg_wr_adrp, _fg_wr_add, _fg_wr_len, _fg_wr_sys
.globl _fg_page, _fg_poff, _fg_sd, _fg_sd_byte
.globl _fg_itoa_call, _fg_str_out
.globl _fg_input_call, _fg_atoi_call, _fg_inbuf_ptr, _fg_add1
.globl _fg_adrp_x0, _fg_add_x0
.globl _fg_fn_uf, _fg_blr_x0, _fg_ldr_x9, _fg_blr_x9
.globl _fg_add_imm, _fg_sub_imm, _fg_cmp_imm
.globl _fg_fn_pro, _fg_fn_epi, _fg_bl_uf, _fg_bl_c, _fg_fn_ret
.globl _fg_flush_call, _fg_fork, _fg_cbnz_x1, _fg_child_exit
.globl _fg_pipe_call, _fg_wait_call, _fg_send_call, _fg_recv_call
.globl _fg_emit_int_call, _fg_emit_str_call
.globl _fg_open_r_call, _fg_open_w_call, _fg_close_call
.globl _fg_readline_fd, _fg_writeline_call
.globl _fg_mov_x0_fd, _fg_str_x1, _fg_ldr_x1
.globl _fg_movz, _fg_movk, _fg_lsl16, _fg_lsl32, _fg_lsl48, _fg_neg_x0
.globl _fg_lsl3, _fg_add_x1_x0, _fg_neg_x1, _fg_ldr_x29_x1, _fg_str_x29_x1
.globl _fg_mov_x2_x0, _fg_mov_x1_imm, _fg_pop_x1
.globl _pa_lsl_x1_3, _pa_add_x1_x0
.globl _fg_ldrb
.globl _fg_globl_uf, _fg_lib_hdr
.globl _err_import, _fg_nl_err

_fg_hdr:       .ascii ".global _main\n.align 2\n\n"
               .byte 0
_fg_text:      .asciz ".text\n"
_fg_data:      .asciz "\n.data\n"
_fg_bss:       .asciz "\n.bss\n.align 4\n_input_buf: .space 1024\n_itoa_buf: .space 24\n_ob_buf: .space 4096\n_ob_pos: .space 8\n_recv_buf: .space 1024\n_path_buf: .space 256\n"
_fg_nl:        .asciz "\n"
_fg_comma:     .asciz ", "
_fg_main:      .ascii "_main:\n    stp x29, x30, [sp, #-16]!\n    mov x29, sp\n    sub sp, sp, #"
               .byte 0
_fg_main2:     .asciz "\n"
_fg_frame_ph:  .asciz "0000"
_fg_exit:      .ascii "    mov x0, #0\n    bl _fflush\n    bl _rt_flush\n    mov sp, x29\n    ldp x29, x30, [sp], #16\n    mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
               .byte 0
_fg_ldr:       .asciz "    ldr x0, [x29, #-"
_fg_ldr1:      .asciz "    ldr x1, [x29, #-"
_fg_str_x0:    .asciz "    str x0, [x29, #-"
_fg_cb:        .asciz "]\n"
_fg_mov:       .asciz "    mov x0, #"
_fg_movn:      .asciz "    mov x0, #-"
_fg_push:      .asciz "    str x0, [sp, #-16]!\n"
_fg_pop0:      .asciz "    ldr x0, [sp], #16\n"
_fg_pop1:      .asciz "    ldr x1, [sp], #16\n"
_fg_add:       .asciz "    add x0, x1, x0\n"
_fg_sub:       .asciz "    sub x0, x1, x0\n"
_fg_add_r:     .asciz "    add x0, x0, x1\n"
_fg_sub_r:     .asciz "    sub x0, x0, x1\n"
_fg_mul:       .asciz "    mul x0, x1, x0\n"
_fg_sdiv:      .asciz "    sdiv x0, x1, x0\n"
_fg_mod:       .ascii "    sdiv x2, x1, x0\n    msub x0, x2, x0, x1\n"
               .byte 0
_fg_mul_r:     .asciz "    mul x0, x0, x1\n"
_fg_sdiv_r:    .asciz "    sdiv x0, x0, x1\n"
_fg_mod_r:     .ascii "    sdiv x2, x0, x1\n    msub x0, x2, x1, x0\n"
               .byte 0
// v1.1: Bitwise codegen fragments
_fg_and:       .asciz "    and x0, x1, x0\n"
_fg_orr:       .asciz "    orr x0, x1, x0\n"
_fg_eor:       .asciz "    eor x0, x1, x0\n"
_fg_mvn:       .asciz "    mvn x0, x0\n"
_fg_lsl_op:    .asciz "    lsl x0, x1, x0\n"
_fg_lsr_op:    .asciz "    lsr x0, x1, x0\n"
_fg_and_r:     .asciz "    and x0, x0, x1\n"
_fg_orr_r:     .asciz "    orr x0, x0, x1\n"
_fg_eor_r:     .asciz "    eor x0, x0, x1\n"
_fg_lsl_op_r:  .asciz "    lsl x0, x0, x1\n"
_fg_lsr_op_r:  .asciz "    lsr x0, x0, x1\n"
// v1.1: Multi-return value support
_fg_mov_x1_x0: .asciz "    mov x1, x0\n"
_fg_sub_x0_x29: .asciz "    sub x0, x29, #"
// peek(ptr, idx) → neg x1; ldr x0, [x0, x1, lsl #3]
_fg_peek:      .ascii "    neg x1, x1\n    ldr x0, [x0, x1, lsl #3]\n"
               .byte 0
// poke(ptr, idx, val) → neg x1; str x2, [x0, x1, lsl #3]
_fg_poke:      .ascii "    neg x1, x1\n    str x2, [x0, x1, lsl #3]\n"
               .byte 0
_fg_poke_seq:  .ascii "    mov x2, x0\n    ldr x1, [sp], #16\n    ldr x0, [sp], #16\n    neg x1, x1\n    str x2, [x0, x1, lsl #3]\n"
               .byte 0
// peek4/poke4 — 32-bit memory access at byte offset
_fg_peek4:     .asciz "    ldr w0, [x0, x1]\n"
_fg_poke4_seq: .ascii "    mov w2, w0\n    ldr x1, [sp], #16\n    ldr x0, [sp], #16\n    str w2, [x0, x1]\n"
               .byte 0
// peek1/poke1 — 8-bit memory access at byte offset
_fg_peek1:     .asciz "    ldrb w0, [x0, x1]\n"
_fg_poke1_seq: .ascii "    mov w2, w0\n    ldr x1, [sp], #16\n    ldr x0, [sp], #16\n    strb w2, [x0, x1]\n"
               .byte 0
_fg_cmp0:      .asciz "    cmp x0, #"
_fg_cmp1:      .asciz "    cmp x1, x0\n"
_fg_cmp01:     .asciz "    cmp x0, x1\n"
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
_fg_wr_sys:    .asciz "    bl _rt_buf_write\n"
_fg_page:      .asciz "@PAGE\n"
_fg_poff:      .asciz "@PAGEOFF\n"
_fg_sd:        .asciz "_s"
_fg_sd_byte:   .asciz ": .byte "
_fg_itoa_call: .ascii "    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    bl _rt_itoa\n    mov x2, x0\n    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    bl _rt_buf_write\n"
               .byte 0
_fg_str_out:   .asciz "    bl _rt_buf_write\n"
_fg_input_call: .ascii "    bl _rt_read_line\n"
                .byte 0
_fg_atoi_call:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n    bl _rt_atoi\n"
                .byte 0
_fg_inbuf_ptr:  .ascii "    adrp x0, _input_buf@PAGE\n    add x0, x0, _input_buf@PAGEOFF\n"
                .byte 0
_fg_add1:      .asciz "    add x0, x0, #1\n"
_fg_adrp_x0:   .asciz "    adrp x0, "
_fg_add_x0:    .asciz "    add x0, x0, "
_fg_fn_uf:     .asciz "_uf_"
_fg_blr_x0:    .asciz "    blr x0\n"
_fg_ldr_x9:    .asciz "    ldr x9, [x29, #-"
_fg_blr_x9:    .asciz "    blr x9\n"
_fg_add_imm:   .asciz "    add x0, x0, #"
_fg_sub_imm:   .asciz "    sub x0, x0, #"
_fg_cmp_imm:   .asciz "    cmp x0, #"
_fg_fn_pro:    .ascii "    stp x29, x30, [sp, #-16]!\n    mov x29, sp\n    sub sp, sp, #"
               .byte 0
_fg_fn_epi:    .ascii "    mov sp, x29\n    ldp x29, x30, [sp], #16\n    ret\n"
               .byte 0
_fg_bl_uf:     .asciz "    bl _uf_"
_fg_bl_c:      .asciz "    bl _"
_fg_fn_ret:    .ascii "    mov sp, x29\n    ldp x29, x30, [sp], #16\n    ret\n"
               .byte 0

// v0.5: Concurrency fragments
_fg_flush_call: .asciz "    bl _rt_flush\n"
_fg_fork:       .ascii "    mov x16, #2\n    svc #0x80\n    cbnz x1, "
                .byte 0
_fg_cbnz_x1:   .asciz "    cbnz x1, "
_fg_child_exit: .ascii "    bl _rt_flush\n    mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
                .byte 0
_fg_pipe_call:  .asciz "    bl _rt_pipe\n"
_fg_wait_call:  .asciz "    bl _rt_wait\n"
_fg_send_call:  .asciz "    bl _rt_send\n"
_fg_recv_call:  .asciz "    bl _rt_recv\n"

// v0.5: AI-native I/O fragments
_fg_emit_int_call: .asciz "    bl _rt_emit_int\n"
_fg_emit_str_call: .asciz "    bl _rt_emit_str\n"

// v0.5: File I/O fragments
_fg_open_r_call: .asciz "    bl _rt_open_r\n"
_fg_open_w_call: .asciz "    bl _rt_open_w\n"
_fg_close_call:  .asciz "    bl _rt_close\n"
_fg_readline_fd: .asciz "    bl _rt_read_line_fd\n"
_fg_writeline_call: .asciz "    bl _rt_write_line\n"
_fg_mov_x0_fd:  .asciz "    mov x0, x"
_fg_str_x1:     .asciz "    str x1, [x29, #-"
_fg_ldr_x1:     .asciz "    ldr x1, [x29, #-"

// v0.7: Large immediate support (movz/movk)
_fg_movz:       .asciz "    movz x0, #"
_fg_movk:       .asciz "    movk x0, #"
_fg_lsl16:      .asciz ", lsl #16\n"
_fg_lsl32:      .asciz ", lsl #32\n"
_fg_lsl48:      .asciz ", lsl #48\n"
_fg_neg_x0:     .asciz "    neg x0, x0\n"

// v0.7: Array support fragments
_fg_lsl3:       .asciz "    lsl x0, x0, #3\n"
_fg_add_x1_x0:  .asciz "    add x1, x1, x0\n"
_fg_neg_x1:     .asciz "    neg x1, x1\n"
_fg_ldr_x29_x1: .asciz "    ldr x0, [x29, x1]\n"
_fg_str_x29_x1: .asciz "    str x2, [x29, x1]\n"
_fg_mov_x2_x0:  .asciz "    mov x2, x0\n"
_fg_mov_x1_imm: .asciz "    mov x1, #"
_fg_pop_x1:     .asciz "    ldr x1, [sp], #16\n"
_pa_lsl_x1_3:   .asciz "    lsl x1, x1, #3\n"
_pa_add_x1_x0:  .asciz "    add x1, x1, x0\n"
_fg_ldrb:       .asciz "    ldrb w0, [x0, x1]\n"

// v0.8: Multi-file compilation
_fg_globl_uf:   .asciz ".globl _uf_"
_fg_lib_hdr:    .asciz ".text\n.align 2\n"
_err_import:    .asciz "error: cannot find import file: "
_fg_nl_err:     .asciz "\n"

// ── BSS Section ──
.section __DATA,__bss

.globl _src_buf, _out_buf, _out_name, _src_len, _out_pos
.globl _tok_buf, _tok_count, _tok_pos
.globl _sym_tab, _sym_count, _frame_size
.globl _ind_stack, _ind_sp
.globl _lbl_count
.globl _str_ptrs, _str_lens, _str_bytes, _str_count
.globl _wait_stat, _num_buf, _tmp_path_s, _tmp_path_o, _line_num
.globl _loop_stack, _loop_sp
.globl _frame_patch_pos
.globl _fn_tab, _fn_count
.globl _fn_frame_patches, _fn_patch_count
.globl _is_lib_mode
.globl _import_tab, _import_count
.globl _lib_o_paths, _lib_o_count, _lib_path_buf, _main_o_path
.globl _ext_tab, _ext_count
.globl _link_tab, _link_count
.globl _struct_tab, _struct_count
.globl _last_is_imm, _last_imm_val, _last_imm_out_pos
.globl _last_is_var, _last_var_offset, _last_var_out_pos

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
_loop_stack:  .space 256         // 16 entries * 16 bytes (top_label + end_label)
_loop_sp:     .space 4
_frame_patch_pos: .space 8
_last_is_imm: .space 4
_last_imm_val: .space 8
_last_imm_out_pos: .space 8
_last_is_var:  .space 4
_last_var_offset: .space 4
_last_var_out_pos: .space 8
_fn_tab:      .space 2048        // 32 entries * 64 bytes (name_ptr(8), name_len(4), param_count(4), label_num(4), padding)
_fn_count:    .space 4
_fn_frame_patches: .space 256    // 32 entries * 8 bytes (out_pos for frame size patch)
_fn_patch_count:   .space 4
_is_lib_mode:      .space 4
_import_tab:       .space 512       // 16 entries * 32 bytes (ptr(8) + len(4) + padding)
_import_count:     .space 4
_lib_o_paths:      .space 4096     // 16 entries * 256 bytes (paths to compiled .o files)
_lib_o_count:      .space 4
_lib_path_buf:     .space 256      // temp buffer for building lib file paths
_main_o_path:      .space 256      // path to main .o file
_ext_tab:          .space 768      // 32 entries * 24 bytes (name_ptr(8) + name_len(4) + param_count(4) + padding(8))
_ext_count:        .space 4
_link_tab:         .space 1024     // 16 entries * 64 bytes (pre-built "-l<name>" strings)
_link_count:       .space 4
// struct descriptor table: 16 structs × 192 bytes
// layout per entry: name_ptr(8) + name_len(4) + field_count(4) + fields[11](name_ptr(8)+name_len(4)+pad(4))
_struct_tab:       .space 3072
_struct_count:     .space 4
