// ============================================================
// parser.s - Recursive descent parser + codegen
// legnac v0.2 - macOS ARM64
// Single-pass: parses tokens and emits ARM64 assembly directly
// ============================================================
.include "src/macos_arm64/defs.inc"

.section __TEXT,__text

// ────────────────────────────────────────
// Token access helpers
// ────────────────────────────────────────

// _tok_peek: returns w0 = type of current token
_tok_peek:
    adrp x1, _tok_pos@PAGE
    add x1, x1, _tok_pos@PAGEOFF
    ldr w2, [x1]
    mov x3, #TOK_SIZE
    mul x2, x2, x3
    adrp x1, _tok_buf@PAGE
    add x1, x1, _tok_buf@PAGEOFF
    add x1, x1, x2
    ldr w0, [x1]
    ret

// _tok_advance: increment tok_pos
_tok_advance:
    adrp x0, _tok_pos@PAGE
    add x0, x0, _tok_pos@PAGEOFF
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]
    ret

// _tok_current: returns x0 = pointer to current token struct
_tok_current:
    adrp x1, _tok_pos@PAGE
    add x1, x1, _tok_pos@PAGEOFF
    ldr w2, [x1]
    mov x3, #TOK_SIZE
    mul x2, x2, x3
    adrp x0, _tok_buf@PAGE
    add x0, x0, _tok_buf@PAGEOFF
    add x0, x0, x2
    ret

// _tok_expect: w0 = expected type → x0=0 ok, -1 err
_tok_expect:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0
    bl _tok_peek
    cmp w0, w19
    b.ne 1f
    bl _tok_advance
    mov x0, #0
    b 2f
1:  adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    bl _tok_line
    mov x1, x0
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    bl _err_line
    mov x0, #-1
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _tok_line: compute line number of current token
// Returns x0 = line number (1-based)
_tok_line:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    bl _tok_current
    ldr x19, [x0, #8]               // token src ptr
    adrp x20, _src_buf@PAGE
    add x20, x20, _src_buf@PAGEOFF
    mov x0, #1                       // line = 1
    // if token has no ptr (synthetic token), return 0
    cbz x19, 2f
1:  cmp x20, x19
    b.ge 2f
    ldrb w1, [x20]
    cmp w1, #'\n'
    b.ne 3f
    add x0, x0, #1
3:  add x20, x20, #1
    b 1b
2:  ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// Symbol table
// ────────────────────────────────────────

// _sym_lookup: x0=name_ptr, x1=name_len → x0=entry_ptr or 0
_sym_lookup:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0                  // name_ptr
    mov x20, x1                  // name_len
    adrp x21, _sym_tab@PAGE
    add x21, x21, _sym_tab@PAGEOFF
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    ldr w22, [x0]
    mov x0, #0                   // index
1:  cmp w0, w22
    b.ge 2f
    // entry at x21 + index * SYM_SIZE
    mov x1, #SYM_SIZE
    mul x1, x0, x1
    add x2, x21, x1             // entry ptr
    ldr x3, [x2]                // entry name_ptr
    ldr w4, [x2, #8]            // entry name_len
    cmp w4, w20
    b.ne 3f
    // compare names
    stp x0, x2, [sp, #-16]!
    mov x0, x19
    mov x1, x3
    mov x2, x20
    bl _strncmp
    mov x3, x0
    ldp x0, x2, [sp], #16
    cbz x3, 4f                  // match
3:  add x0, x0, #1
    b 1b
2:  mov x0, #0                  // not found
    b 5f
4:  mov x0, x2                  // return entry ptr
5:  ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _sym_insert: x0=name_ptr, x1=name_len, w2=type, w3=arr_count (if TY_ARR) → x0=entry_ptr
_sym_insert:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    mov x19, x0                  // name_ptr
    mov x20, x1                  // name_len
    mov w21, w2                  // type
    mov w23, w3                  // arr_count (only used if TY_ARR)

    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    ldr w22, [x0]               // current count
    cmp w22, #MAX_SYMS
    b.ge _parser_overflow
    adrp x1, _sym_tab@PAGE
    add x1, x1, _sym_tab@PAGEOFF
    mov x2, #SYM_SIZE
    mul x3, x22, x2
    add x1, x1, x3              // entry ptr

    // store fields
    str x19, [x1]               // name_ptr
    str w20, [x1, #8]           // name_len
    str w21, [x1, #12]          // type

    // allocate stack space
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    ldr w3, [x0]
    cmp w21, #TY_ARR
    b.eq 3f
    cmp w21, #TY_STR
    b.eq 1f
    add w3, w3, #8              // int = 8 bytes
    b 2f
1:  add w3, w3, #16             // str = 16 bytes (ptr+len)
    b 2f
3:  // array: allocate arr_count * 8 bytes
    mov w4, w23
    lsl w4, w4, #3              // arr_count * 8
    add w3, w3, w4
    str w23, [x1, #20]          // store element_count at offset+20
2:  str w3, [x0]                // update frame_size
    str w3, [x1, #16]           // store offset (points to end of array region)

    // increment count
    add w22, w22, #1
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    str w22, [x0]

    mov x0, x1                  // return entry ptr
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _reg_string: register a string literal
// x0=ptr, x1=raw_len → x0=string index
// ────────────────────────────────────────
_reg_string:
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    adrp x2, _str_count@PAGE
    add x2, x2, _str_count@PAGEOFF
    ldr w3, [x2]
    cmp w3, #MAX_STRS
    b.ge _parser_overflow
    adrp x4, _str_ptrs@PAGE
    add x4, x4, _str_ptrs@PAGEOFF
    str x19, [x4, x3, lsl #3]
    adrp x4, _str_lens@PAGE
    add x4, x4, _str_lens@PAGEOFF
    str w20, [x4, x3, lsl #2]
    mov x0, x3
    add w3, w3, #1
    str w3, [x2]
    ldp x19, x20, [sp], #16
    ret

// ────────────────────────────────────────
// Emit helpers for codegen
// ────────────────────────────────────────

// _emit_load_var: emit ldr x0, [x29, #-offset]
// w0 = offset
_emit_load_var:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0
    adrp x0, _fg_ldr@PAGE
    add x0, x0, _fg_ldr@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _emit_store_var: emit str x0, [x29, #-offset]
_emit_store_var:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0
    adrp x0, _fg_str_x0@PAGE
    add x0, x0, _fg_str_x0@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _emit_mov_imm: emit mov x0, #N (supports full 64-bit range via movz/movk)
_emit_mov_imm:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0                     // value
    mov w20, #0                     // neg flag

    // handle negative: negate, set flag
    cmp x19, #0
    b.ge _emi_pos
    neg x19, x19
    mov w20, #1

_emi_pos:
    // check if fits in 16 bits (0-65535)
    mov x0, #65535
    cmp x19, x0
    b.hi _emi_large

    // small: emit "    mov x0, #N\n" (original path, GAS accepts movz alias)
    cmp w20, #0
    b.ne _emi_small_neg
    adrp x0, _fg_mov@PAGE
    add x0, x0, _fg_mov@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    b _emi_done

_emi_small_neg:
    adrp x0, _fg_movn@PAGE
    add x0, x0, _fg_movn@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    b _emi_done

_emi_large:
    // emit movz x0, #(bits 0-15)
    adrp x0, _fg_movz@PAGE
    add x0, x0, _fg_movz@PAGEOFF
    bl _emit_str
    and x0, x19, #0xFFFF
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str

    // emit movk x0, #(bits 16-31), lsl #16 if non-zero
    lsr x0, x19, #16
    and x0, x0, #0xFFFF
    cbz x0, _emi_hw2
    adrp x0, _fg_movk@PAGE
    add x0, x0, _fg_movk@PAGEOFF
    bl _emit_str
    lsr x0, x19, #16
    and x0, x0, #0xFFFF
    bl _emit_num
    adrp x0, _fg_lsl16@PAGE
    add x0, x0, _fg_lsl16@PAGEOFF
    bl _emit_str

_emi_hw2:
    // emit movk x0, #(bits 32-47), lsl #32 if non-zero
    lsr x0, x19, #32
    and x0, x0, #0xFFFF
    cbz x0, _emi_hw3
    adrp x0, _fg_movk@PAGE
    add x0, x0, _fg_movk@PAGEOFF
    bl _emit_str
    lsr x0, x19, #32
    and x0, x0, #0xFFFF
    bl _emit_num
    adrp x0, _fg_lsl32@PAGE
    add x0, x0, _fg_lsl32@PAGEOFF
    bl _emit_str

_emi_hw3:
    // emit movk x0, #(bits 48-63), lsl #48 if non-zero
    lsr x0, x19, #48
    and x0, x0, #0xFFFF
    cbz x0, _emi_neg_check
    adrp x0, _fg_movk@PAGE
    add x0, x0, _fg_movk@PAGEOFF
    bl _emit_str
    lsr x0, x19, #48
    and x0, x0, #0xFFFF
    bl _emit_num
    adrp x0, _fg_lsl48@PAGE
    add x0, x0, _fg_lsl48@PAGEOFF
    bl _emit_str

_emi_neg_check:
    // if negative, emit neg x0, x0
    cmp w20, #0
    b.eq _emi_done
    adrp x0, _fg_neg_x0@PAGE
    add x0, x0, _fg_neg_x0@PAGEOFF
    bl _emit_str

_emi_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _emit_inv_branch: emit inverted conditional branch to label
// w0 = comp op token type, x1 = label number
_emit_inv_branch:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0
    mov x20, x1
    // select inverted branch fragment
    cmp w19, #TOK_GT
    b.ne 1f
    adrp x0, _fg_ble@PAGE
    add x0, x0, _fg_ble@PAGEOFF
    b 10f
1:  cmp w19, #TOK_LT
    b.ne 2f
    adrp x0, _fg_bge@PAGE
    add x0, x0, _fg_bge@PAGEOFF
    b 10f
2:  cmp w19, #TOK_GTE
    b.ne 3f
    adrp x0, _fg_blt@PAGE
    add x0, x0, _fg_blt@PAGEOFF
    b 10f
3:  cmp w19, #TOK_LTE
    b.ne 4f
    adrp x0, _fg_bgt@PAGE
    add x0, x0, _fg_bgt@PAGEOFF
    b 10f
4:  cmp w19, #TOK_EQ
    b.ne 5f
    adrp x0, _fg_bne@PAGE
    add x0, x0, _fg_bne@PAGEOFF
    b 10f
5:  // TOK_NEQ or default
    adrp x0, _fg_beq@PAGE
    add x0, x0, _fg_beq@PAGEOFF
10: bl _emit_str
    // emit label ref: _LN\n
    adrp x0, _fg_lbl@PAGE
    add x0, x0, _fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _emit_norm_branch: emit normal (non-inverted) conditional branch to label
// w0 = comp op token type, x1 = label number
_emit_norm_branch:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov w19, w0
    mov x20, x1
    cmp w19, #TOK_GT
    b.ne 1f
    adrp x0, _fg_bgt@PAGE
    add x0, x0, _fg_bgt@PAGEOFF
    b 10f
1:  cmp w19, #TOK_LT
    b.ne 2f
    adrp x0, _fg_blt@PAGE
    add x0, x0, _fg_blt@PAGEOFF
    b 10f
2:  cmp w19, #TOK_GTE
    b.ne 3f
    adrp x0, _fg_bge@PAGE
    add x0, x0, _fg_bge@PAGEOFF
    b 10f
3:  cmp w19, #TOK_LTE
    b.ne 4f
    adrp x0, _fg_ble@PAGE
    add x0, x0, _fg_ble@PAGEOFF
    b 10f
4:  cmp w19, #TOK_EQ
    b.ne 5f
    adrp x0, _fg_beq@PAGE
    add x0, x0, _fg_beq@PAGEOFF
    b 10f
5:  adrp x0, _fg_bne@PAGE
    add x0, x0, _fg_bne@PAGEOFF
10: bl _emit_str
    adrp x0, _fg_lbl@PAGE
    add x0, x0, _fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_cond_branch: parse condition with and/or/not, emit branches
// x0 = false_label (where to jump if condition is false)
// Returns x0=0 success, -1 error
// ────────────────────────────────────────
_parse_cond_branch:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0                  // false_label
    mov x21, #0                  // has_or flag
    mov x22, #0                  // true_label (allocated if needed)

_pcb_next:
    // check for 'not' prefix
    bl _tok_peek
    cmp w0, #TOK_KW_NOT
    b.ne _pcb_no_not
    bl _tok_advance
    bl _parse_condition
    cmp x0, #0
    b.lt _pcb_err
    // invert the comparison op
    bl _invert_comp_op
    b _pcb_got_op

_pcb_no_not:
    bl _parse_condition
    cmp x0, #0
    b.lt _pcb_err

_pcb_got_op:
    mov w20, w0                  // comp op

    // check for and/or
    bl _tok_peek
    cmp w0, #TOK_KW_AND
    b.eq _pcb_and
    cmp w0, #TOK_KW_OR
    b.eq _pcb_or

    // last condition: emit inverted branch to false_label
    mov w0, w20
    mov x1, x19
    bl _emit_inv_branch

    // if we had any 'or', emit the true label
    cbz x22, _pcb_ok
    mov x0, x22
    bl _emit_label
    b _pcb_ok

_pcb_and:
    bl _tok_advance              // skip "and"
    // if false, short-circuit to false_label
    mov w0, w20
    mov x1, x19
    bl _emit_inv_branch
    b _pcb_next

_pcb_or:
    bl _tok_advance              // skip "or"
    // allocate true_label if not yet
    cbnz x22, 1f
    bl _new_label
    mov x22, x0
1:  // if true, short-circuit to true_label (skip remaining conditions)
    mov w0, w20
    mov x1, x22
    bl _emit_norm_branch
    b _pcb_next

_pcb_ok:
    mov x0, #0
    b _pcb_ret
_pcb_err:
    mov x0, #-1
_pcb_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _invert_comp_op: w0 = comp op → w0 = inverted comp op
_invert_comp_op:
    cmp w0, #TOK_GT
    b.ne 1f
    mov w0, #TOK_LTE
    ret
1:  cmp w0, #TOK_LT
    b.ne 2f
    mov w0, #TOK_GTE
    ret
2:  cmp w0, #TOK_GTE
    b.ne 3f
    mov w0, #TOK_LT
    ret
3:  cmp w0, #TOK_LTE
    b.ne 4f
    mov w0, #TOK_GT
    ret
4:  cmp w0, #TOK_EQ
    b.ne 5f
    mov w0, #TOK_NEQ
    ret
5:  mov w0, #TOK_EQ
    ret
_emit_str_write:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0                  // string index

    // compute byte length
    adrp x1, _str_ptrs@PAGE
    add x1, x1, _str_ptrs@PAGEOFF
    ldr x20, [x1, x19, lsl #3]  // ptr
    adrp x1, _str_lens@PAGE
    add x1, x1, _str_lens@PAGEOFF
    ldr w21, [x1, x19, lsl #2]  // raw len
    // count actual bytes
    mov x22, #0
    mov x0, #0
1:  cmp w0, w21
    b.ge 2f
    ldrb w1, [x20, x0]
    cmp w1, #'\\'
    b.ne 3f
    add x0, x0, #1
3:  add x0, x0, #1
    add x22, x22, #1
    b 1b
2:
    // emit: mov x0, #1
    adrp x0, _fg_wr_fd@PAGE
    add x0, x0, _fg_wr_fd@PAGEOFF
    bl _emit_str
    // adrp x1, _sN@PAGE
    adrp x0, _fg_wr_adrp@PAGE
    add x0, x0, _fg_wr_adrp@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    // add x1, x1, _sN@PAGEOFF
    adrp x0, _fg_wr_add@PAGE
    add x0, x0, _fg_wr_add@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // mov x2, #len
    adrp x0, _fg_wr_len@PAGE
    add x0, x0, _fg_wr_len@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // syscall
    adrp x0, _fg_wr_sys@PAGE
    add x0, x0, _fg_wr_sys@PAGEOFF
    bl _emit_str

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ════════════════════════════════════════
// Parse functions
// ════════════════════════════════════════

// _skip_nl: skip consecutive TOK_NL tokens
_skip_nl:
    stp x29, x30, [sp, #-16]!
1:  bl _tok_peek
    cmp w0, #TOK_NL
    b.ne 2f
    bl _tok_advance
    b 1b
2:  ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_program - Main entry point
// Returns x0=0 success, -1 error
// ────────────────────────────────────────
.globl _parse_program
_parse_program:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    // reset state
    adrp x0, _tok_pos@PAGE
    add x0, x0, _tok_pos@PAGEOFF
    str wzr, [x0]
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    str wzr, [x0]
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    str wzr, [x0]
    adrp x0, _lbl_count@PAGE
    add x0, x0, _lbl_count@PAGEOFF
    str wzr, [x0]
    adrp x0, _str_count@PAGE
    add x0, x0, _str_count@PAGEOFF
    str wzr, [x0]
    adrp x0, _loop_sp@PAGE
    add x0, x0, _loop_sp@PAGEOFF
    str wzr, [x0]
    adrp x0, _fn_count@PAGE
    add x0, x0, _fn_count@PAGEOFF
    str wzr, [x0]
    adrp x0, _fn_patch_count@PAGE
    add x0, x0, _fn_patch_count@PAGEOFF
    str wzr, [x0]

    // pre-scan: detect library mode (no legna: block)
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    mov w1, #1
    str w1, [x0]                     // assume lib mode
    adrp x1, _tok_count@PAGE
    add x1, x1, _tok_count@PAGEOFF
    ldr w1, [x1]
    adrp x2, _tok_buf@PAGE
    add x2, x2, _tok_buf@PAGEOFF
    mov x3, #0                       // use x3 (64-bit) for index
_pp_scan:
    cmp x3, x1
    b.ge _pp_scan_done
    mov x4, #TOK_SIZE
    madd x4, x3, x4, x2             // x4 = tok_buf + index * TOK_SIZE
    ldr w5, [x4]                     // token type
    cmp w5, #TOK_KW_LEGNA
    b.ne _pp_scan_next
    // found legna: → not lib mode
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    str wzr, [x0]
    b _pp_scan_done
_pp_scan_next:
    add x3, x3, #1
    b _pp_scan
_pp_scan_done:

    // emit header (runtime only, no _main yet)
    bl _emit_header

    // skip leading newlines
    bl _skip_nl

    // reset import count
    adrp x0, _import_count@PAGE
    add x0, x0, _import_count@PAGEOFF
    str wzr, [x0]

    // parse import, extern fn, and link directives (any order)
    // only reset ext/link counts if not in lib mode (lib files are compiled
    // after the main file, and we must preserve the main file's extern/link state)
    adrp x0, _is_lib_mode@PAGE
    add x0, x0, _is_lib_mode@PAGEOFF
    ldr w0, [x0]
    cbnz w0, _pp_decl_loop
    adrp x0, _ext_count@PAGE
    add x0, x0, _ext_count@PAGEOFF
    str wzr, [x0]
    adrp x0, _link_count@PAGE
    add x0, x0, _link_count@PAGEOFF
    str wzr, [x0]

_pp_decl_loop:
    bl _tok_peek
    cmp w0, #TOK_KW_IMPORT
    b.eq _pp_parse_import
    cmp w0, #TOK_KW_EXTERN
    b.eq _pp_parse_extern
    cmp w0, #TOK_KW_LINK
    b.eq _pp_parse_link
    b _pp_decl_done

_pp_parse_import:
    bl _tok_advance              // skip "import"
    // expect string literal
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pp_err
    bl _tok_current
    ldr x1, [x0, #8]            // string content ptr
    ldr w2, [x0, #4]            // string len
    // store in import table — copy name bytes into entry (offset 12..31)
    adrp x3, _import_count@PAGE
    add x3, x3, _import_count@PAGEOFF
    ldr w4, [x3]
    adrp x5, _import_tab@PAGE
    add x5, x5, _import_tab@PAGEOFF
    mov x6, #32
    mul x6, x4, x6
    add x5, x5, x6
    str w2, [x5, #8]            // len
    // copy name bytes into entry at offset 12
    add x7, x5, #12
    mov x8, #0
_pp_imp_copy:
    cmp x8, x2
    b.ge _pp_imp_copy_done
    ldrb w9, [x1, x8]
    strb w9, [x7, x8]
    add x8, x8, #1
    b _pp_imp_copy
_pp_imp_copy_done:
    // store ptr to the copied name (within import_tab entry)
    str x7, [x5]                // ptr now points into import_tab, not _src_buf
    add w4, w4, #1
    str w4, [x3]
    bl _tok_advance              // skip string
    bl _skip_nl
    b _pp_decl_loop

_pp_parse_extern:
    bl _tok_advance              // skip "extern"
    // expect "fn"
    bl _tok_peek
    cmp w0, #TOK_KW_FN
    b.ne _pp_ext_no_fn
    bl _tok_advance              // skip "fn"
_pp_ext_no_fn:
    // get function name
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pp_err
    bl _tok_current
    ldr x1, [x0, #8]            // name_ptr
    ldr w2, [x0, #4]            // name_len
    stp x1, x2, [sp, #-16]!
    bl _tok_advance
    // expect "("
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err
    // count parameters (skip names)
    mov w21, #0
_pp_ext_param_loop:
    bl _tok_peek
    cmp w0, #TOK_RPAREN
    b.eq _pp_ext_param_done
    cbz w21, _pp_ext_param_skip
    mov w0, #TOK_COMMA
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err
_pp_ext_param_skip:
    bl _tok_advance              // skip param name
    add w21, w21, #1
    b _pp_ext_param_loop
_pp_ext_param_done:
    bl _tok_advance              // skip ")"
    // store in extern table
    ldp x1, x2, [sp], #16       // name_ptr, name_len
    mov x0, x1
    mov x1, x2
    mov w2, w21                  // param_count
    bl _ext_insert
    bl _skip_nl
    b _pp_decl_loop

_pp_parse_link:
    bl _tok_advance              // skip "link"
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pp_err
    bl _tok_current
    ldr x1, [x0, #8]            // lib name ptr
    ldr w2, [x0, #4]            // lib name len
    bl _link_add
    bl _tok_advance              // skip string
    bl _skip_nl
    b _pp_decl_loop

_pp_decl_done:

    // parse fn definitions before legna:
_pp_fn_loop:
    bl _tok_peek
    cmp w0, #TOK_KW_FN
    b.ne _pp_fn_done
    bl _parse_fn
    cmp x0, #0
    b.lt _pp_err
    bl _skip_nl
    b _pp_fn_loop
_pp_fn_done:

    // check if this is a library file (no legna: block)
    bl _tok_peek
    cmp w0, #TOK_EOF
    b.eq _pp_lib_mode

    // now emit _main prologue (after all fn definitions)
    bl _emit_main_prologue

    // expect "legna"
    mov w0, #TOK_KW_LEGNA
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err
    // expect ":"
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err
    // expect NL
    mov w0, #TOK_NL
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err
    // expect INDENT
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pp_err

    // parse block
    bl _parse_block
    cmp x0, #0
    b.lt _pp_err

    // emit footer
    bl _emit_footer

    mov x0, #0
    b _pp_ret

_pp_lib_mode:
    // library file: no legna: block, just fn definitions
    // emit footer (lib mode skips _main epilogue and bss)
    bl _emit_footer
    mov x0, #0
    b _pp_ret

_pp_err:
    mov x0, #-1
_pp_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_block - Parse indented block until DEDENT
// ────────────────────────────────────────
_parse_block:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
_pb_loop:
    bl _tok_peek
    cmp w0, #TOK_DEDENT
    b.eq _pb_done
    cmp w0, #TOK_EOF
    b.eq _pb_done
    bl _parse_statement
    cmp x0, #0
    b.lt _pb_err
    b _pb_loop
_pb_done:
    // consume DEDENT if present
    bl _tok_peek
    cmp w0, #TOK_DEDENT
    b.ne 1f
    bl _tok_advance
1:  mov x0, #0
    b _pb_ret
_pb_err:
    mov x0, #-1
_pb_ret:
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parser_overflow - Fatal: compiler buffer overflow
// ────────────────────────────────────────
_parser_overflow:
    stp x29, x30, [sp, #-16]!
    adrp x0, _err_overflow@PAGE
    add x0, x0, _err_overflow@PAGEOFF
    bl _print_err
    mov x0, #1
    mov x16, #1
    svc #0x80

// ────────────────────────────────────────
// _parse_statement - Dispatch on token type
// ────────────────────────────────────────
_parse_statement:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl _tok_peek
    cmp w0, #TOK_NL
    b.ne 1f
    bl _tok_advance
    mov x0, #0
    b _ps_ret
1:  cmp w0, #TOK_KW_LET
    b.ne 2f
    bl _parse_let
    b _ps_ret
2:  cmp w0, #TOK_KW_OUTPUT
    b.ne 3f
    bl _parse_output
    b _ps_ret
3:  cmp w0, #TOK_KW_IF
    b.ne 4f
    bl _parse_if
    b _ps_ret
4:  cmp w0, #TOK_KW_WHILE
    b.ne 5f
    bl _parse_while
    b _ps_ret
5:  cmp w0, #TOK_KW_FOR
    b.ne 6f
    bl _parse_for
    b _ps_ret
6:  cmp w0, #TOK_IDENT
    b.ne 8f
    bl _parse_assign
    b _ps_ret
8:  cmp w0, #TOK_KW_BREAK
    b.ne 9f
    bl _parse_break
    b _ps_ret
9:  cmp w0, #TOK_KW_CONT
    b.ne 10f
    bl _parse_continue
    b _ps_ret
10: cmp w0, #TOK_KW_RETURN
    b.ne 11f
    bl _parse_return
    b _ps_ret
// v0.5: AI-native I/O + File I/O + Concurrency
11: cmp w0, #TOK_KW_EMIT
    b.ne 12f
    bl _parse_emit
    b _ps_ret
12: cmp w0, #TOK_KW_CLOSE
    b.ne 13f
    bl _parse_close
    b _ps_ret
13: cmp w0, #TOK_KW_WRLINE
    b.ne 14f
    bl _parse_write_line
    b _ps_ret
14: cmp w0, #TOK_KW_SEND
    b.ne 15f
    bl _parse_send
    b _ps_ret
15: cmp w0, #TOK_KW_RECV
    b.ne 7f
    bl _parse_recv
    b _ps_ret
7:  // unexpected token
    bl _tok_line
    mov x1, x0
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    bl _err_line
    mov x0, #-1
_ps_ret:
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_let
// ────────────────────────────────────────
_parse_let:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _tok_advance              // skip "let"

    // get ident
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pl_err
    bl _tok_current
    ldr x19, [x0, #8]           // name_ptr
    ldr w20, [x0, #4]           // name_len
    bl _tok_advance

    // expect "="
    mov w0, #TOK_ASSIGN
    bl _tok_expect
    cmp x0, #0
    b.lt _pl_err

    // determine type from next token
    bl _tok_peek
    mov w21, #TY_INT
    cmp w0, #TOK_STR
    b.eq 1f
    cmp w0, #TOK_KW_INSTR
    b.eq 1f
    cmp w0, #TOK_KW_RDLINE
    b.eq 1f
    b 2f
1:  mov w21, #TY_STR
2:
    // v0.5: check for pipe() → TY_PIPE
    cmp w0, #TOK_KW_PIPE
    b.ne 3f
    mov w21, #TY_PIPE
3:
    // v0.7: check for array() → TY_ARR
    cmp w0, #TOK_KW_ARRAY
    b.eq _pl_arr_init
    // v0.5: check for spawn: → fork block
    cmp w0, #TOK_KW_SPAWN
    b.eq _pl_spawn
    // insert symbol
    mov x0, x19
    mov x1, x20
    mov w2, w21
    mov w3, #0
    bl _sym_insert
    mov x22, x0                 // entry ptr

    // parse expression
    cmp w21, #TY_STR
    b.eq _pl_str_init
    cmp w21, #TY_PIPE
    b.eq _pl_pipe_init

    // integer: parse expr, emit store
    bl _parse_expr
    cmp x0, #0
    b.lt _pl_err
    ldr w0, [x22, #16]          // offset
    bl _emit_store_var
    b _pl_nl

_pl_str_init:
    // string init: check if literal or input_str
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pl_str_input

    // string literal: register and store ptr+len
    bl _tok_current
    ldr x19, [x0, #8]           // str content ptr
    ldr w20, [x0, #4]           // str raw len
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string               // x0 = string index
    mov x19, x0

    // emit: adrp x0, _sN@PAGE / add x0, x0, _sN@PAGEOFF
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str

    // store ptr at offset
    ldr w0, [x22, #16]
    bl _emit_store_var

    // compute and store length
    // emit: mov x0, #byte_len
    // need to compute byte_len from raw string
    adrp x1, _str_ptrs@PAGE
    add x1, x1, _str_ptrs@PAGEOFF
    ldr x1, [x1, x19, lsl #3]
    adrp x2, _str_lens@PAGE
    add x2, x2, _str_lens@PAGEOFF
    ldr w2, [x2, x19, lsl #2]
    mov x3, #0
    mov x4, #0
11: cmp w3, w2
    b.ge 12f
    ldrb w5, [x1, x3]
    cmp w5, #'\\'
    b.ne 13f
    add x3, x3, #1
13: add x3, x3, #1
    add x4, x4, #1
    b 11b
12: mov x0, x4
    bl _emit_mov_imm
    // store len at offset+8
    ldr w0, [x22, #16]
    add w0, w0, #8
    bl _emit_store_var
    b _pl_nl

_pl_str_input:
    // input_str()
    bl _parse_expr
    cmp x0, #0
    b.lt _pl_err
    // after input_str, x0=len in generated code
    // store len at offset+8
    ldr w0, [x22, #16]
    add w0, w0, #8
    bl _emit_store_var
    // store ptr (input_buf) at offset
    adrp x0, _fg_inbuf_ptr@PAGE
    add x0, x0, _fg_inbuf_ptr@PAGEOFF
    bl _emit_str
    ldr w0, [x22, #16]
    bl _emit_store_var
    b _pl_nl

// v0.5: let p = pipe()
_pl_pipe_init:
    // pipe() returns read_fd in x0, write_fd in x1
    bl _parse_expr               // emits bl _rt_pipe
    cmp x0, #0
    b.lt _pl_err
    // store read_fd (x0) at offset
    ldr w0, [x22, #16]
    bl _emit_store_var
    // store write_fd (x1) at offset+8
    // emit: str x1, [x29, #-(offset+8)]
    adrp x0, _fg_str_x1@PAGE
    add x0, x0, _fg_str_x1@PAGEOFF
    bl _emit_str
    ldr w0, [x22, #16]
    add w0, w0, #8
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    b _pl_nl

// v0.5: let pid = spawn:
_pl_spawn:
    // insert symbol as TY_INT (PID is an integer)
    mov x0, x19
    mov x1, x20
    mov w2, #TY_INT
    bl _sym_insert
    mov x22, x0                 // entry ptr

    bl _tok_advance              // skip "spawn"
    // expect ":"
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pl_err
    bl _skip_nl
    // expect INDENT
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pl_err

    // allocate labels
    bl _new_label
    mov x19, x0                 // child_label
    bl _new_label
    mov x20, x0                 // end_label

    // emit: flush + fork
    adrp x0, _fg_flush_call@PAGE
    add x0, x0, _fg_flush_call@PAGEOFF
    bl _emit_str
    // emit: fork syscall
    adrp x0, _pspawn_fork@PAGE
    add x0, x0, _pspawn_fork@PAGEOFF
    bl _emit_str
    // emit child label ref
    adrp x0, _fg_lbl@PAGE
    add x0, x0, _fg_lbl@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // parent path: store PID (x0) to variable
    ldr w0, [x22, #16]
    bl _emit_store_var
    // branch to end
    mov x0, x20
    bl _emit_branch
    // child label
    mov x0, x19
    bl _emit_label
    // parse child block
    bl _parse_block
    // emit child exit
    adrp x0, _pspawn_exit@PAGE
    add x0, x0, _pspawn_exit@PAGEOFF
    bl _emit_str
    // end label
    mov x0, x20
    bl _emit_label
    mov x0, #0
    b _pl_ret

// v0.7: let arr = array(N)
_pl_arr_init:
    bl _tok_advance              // skip "array"
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pl_err
    // read N (must be integer literal)
    bl _tok_peek
    cmp w0, #TOK_INT
    b.ne _pl_err
    bl _tok_current
    ldr x21, [x0, #16]          // N (element count)
    bl _tok_advance
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pl_err
    // insert symbol with TY_ARR
    mov x0, x19
    mov x1, x20
    mov w2, #TY_ARR
    mov w3, w21
    bl _sym_insert
    // no runtime code needed — space is in stack frame
    b _pl_nl

_pl_nl:
    bl _skip_nl
    mov x0, #0
    b _pl_ret
_pl_err:
    mov x0, #-1
_pl_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_assign
// ────────────────────────────────────────
_parse_assign:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // get ident
    bl _tok_current
    ldr x19, [x0, #8]           // name_ptr
    ldr w20, [x0, #4]           // name_len
    bl _tok_advance

    // check if this is a function call: IDENT followed by "("
    bl _tok_peek
    cmp w0, #TOK_LPAREN
    b.eq _pa_fn_call

    // lookup variable
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pa_undef
    mov x19, x0                 // entry ptr

    // v0.7: check if array index write: arr[i] = expr
    bl _tok_peek
    cmp w0, #TOK_LBRACKET
    b.eq _pa_arr_write

    // check token: = or += -= *=
    bl _tok_peek
    cmp w0, #TOK_PLUS_EQ
    b.eq _pa_aug_add
    cmp w0, #TOK_MINUS_EQ
    b.eq _pa_aug_sub
    cmp w0, #TOK_STAR_EQ
    b.eq _pa_aug_mul

    // expect "="
    mov w0, #TOK_ASSIGN
    bl _tok_expect
    cmp x0, #0
    b.lt _pa_err

    // parse expr
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err

    // store
    ldr w0, [x19, #16]
    bl _emit_store_var

    bl _skip_nl
    mov x0, #0
    b _pa_ret

_pa_aug_add:
    bl _tok_advance
    // load current value, push
    ldr w0, [x19, #16]
    bl _emit_load_var
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // parse rhs
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err
    // pop old value into x1, add
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add@PAGE
    add x0, x0, _fg_add@PAGEOFF
    bl _emit_str
    // store result
    ldr w0, [x19, #16]
    bl _emit_store_var
    bl _skip_nl
    mov x0, #0
    b _pa_ret

_pa_aug_sub:
    bl _tok_advance
    ldr w0, [x19, #16]
    bl _emit_load_var
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sub@PAGE
    add x0, x0, _fg_sub@PAGEOFF
    bl _emit_str
    ldr w0, [x19, #16]
    bl _emit_store_var
    bl _skip_nl
    mov x0, #0
    b _pa_ret

_pa_aug_mul:
    bl _tok_advance
    ldr w0, [x19, #16]
    bl _emit_load_var
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _fg_mul@PAGE
    add x0, x0, _fg_mul@PAGEOFF
    bl _emit_str
    ldr w0, [x19, #16]
    bl _emit_store_var
    bl _skip_nl
    mov x0, #0
    b _pa_ret

_pa_arr_write:
    // arr[i] = expr
    // x19 = entry ptr
    ldr w20, [x19, #16]         // offset
    ldr w0, [x19, #20]          // element_count
    lsl w0, w0, #3              // N*8
    sub w20, w20, w0            // offset - N*8
    add w20, w20, #8            // arr_base (saved in w20, callee-saved)
    // advance past [
    bl _tok_advance
    // parse index expression → x0
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err
    // push index onto stack
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // expect ]
    mov w0, #TOK_RBRACKET
    bl _tok_expect
    cmp x0, #0
    b.lt _pa_err
    // expect =
    mov w0, #TOK_ASSIGN
    bl _tok_expect
    cmp x0, #0
    b.lt _pa_err
    // parse value expression → x0
    bl _parse_expr
    cmp x0, #0
    b.lt _pa_err
    // emit: mov x2, x0 (save value)
    adrp x0, _fg_mov_x2_x0@PAGE
    add x0, x0, _fg_mov_x2_x0@PAGEOFF
    bl _emit_str
    // emit: pop index → x1
    adrp x0, _fg_pop_x1@PAGE
    add x0, x0, _fg_pop_x1@PAGEOFF
    bl _emit_str
    // emit: lsl x1, x1, #3 (reuse lsl3 but for x1 — need custom)
    // actually emit inline: "    lsl x1, x1, #3\n"
    adrp x0, _pa_lsl_x1_3@PAGE
    add x0, x0, _pa_lsl_x1_3@PAGEOFF
    bl _emit_str
    // emit: mov x0, #arr_base (use x0 as temp)
    adrp x0, _fg_mov@PAGE
    add x0, x0, _fg_mov@PAGEOFF
    bl _emit_str
    mov x0, x20                  // arr_base
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // emit: add x1, x1, x0
    adrp x0, _pa_add_x1_x0@PAGE
    add x0, x0, _pa_add_x1_x0@PAGEOFF
    bl _emit_str
    // emit: neg x1, x1
    adrp x0, _fg_neg_x1@PAGE
    add x0, x0, _fg_neg_x1@PAGEOFF
    bl _emit_str
    // emit: str x2, [x29, x1]
    adrp x0, _fg_str_x29_x1@PAGE
    add x0, x0, _fg_str_x29_x1@PAGEOFF
    bl _emit_str
    bl _skip_nl
    mov x0, #0
    b _pa_ret

_pa_fn_call:
    // function call as statement: name(args...)
    mov x0, x19
    mov x1, x20
    bl _emit_fn_call
    bl _skip_nl
    b _pa_ret

_pa_undef:
    bl _tok_line
    mov x1, x0
    adrp x0, _err_undef@PAGE
    add x0, x0, _err_undef@PAGEOFF
    bl _err_line
_pa_err:
    mov x0, #-1
_pa_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_output
// ────────────────────────────────────────
_parse_output:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl _tok_advance              // skip "output"

    bl _tok_peek

    // string literal?
    cmp w0, #TOK_STR
    b.ne _po_check_ident

    bl _tok_current
    ldr x19, [x0, #8]           // str ptr
    ldr w20, [x0, #4]           // str len
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string
    bl _emit_str_write
    b _po_nl

_po_check_ident:
    cmp w0, #TOK_IDENT
    b.ne _po_int_expr

    // check variable type
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _po_int_expr        // not found, try as expr
    mov x19, x0                 // entry ptr
    ldr w0, [x19, #12]          // type
    cmp w0, #TY_STR
    b.eq _po_str_var

    // integer variable: parse as expression (handles x+1 etc)
    bl _parse_expr
    cmp x0, #0
    b.lt _po_err
    adrp x0, _fg_itoa_call@PAGE
    add x0, x0, _fg_itoa_call@PAGEOFF
    bl _emit_str
    b _po_nl

_po_str_var:
    bl _tok_advance              // consume ident
    // load ptr into x1
    ldr w0, [x19, #16]          // offset
    // emit: ldr x1, [x29, #-offset]
    adrp x0, _fg_ldr1@PAGE
    add x0, x0, _fg_ldr1@PAGEOFF
    bl _emit_str
    ldr w0, [x19, #16]
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    // load len into x2: ldr x0, [x29, #-(offset+8)]
    ldr w0, [x19, #16]
    add w0, w0, #8
    bl _emit_load_var
    // emit: mov x2, x0
    adrp x0, _po_mov_x2@PAGE
    add x0, x0, _po_mov_x2@PAGEOFF
    bl _emit_str
    // emit write syscall
    adrp x0, _fg_str_out@PAGE
    add x0, x0, _fg_str_out@PAGEOFF
    bl _emit_str
    b _po_nl

_po_int_expr:
    // general expression → itoa → write
    bl _parse_expr
    cmp x0, #0
    b.lt _po_err
    adrp x0, _fg_itoa_call@PAGE
    add x0, x0, _fg_itoa_call@PAGEOFF
    bl _emit_str
    b _po_nl

_po_nl:
    bl _skip_nl
    mov x0, #0
    b _po_ret
_po_err:
    mov x0, #-1
_po_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_condition - Parse "expr OP expr"
// Returns w0 = comparison op token type
// ────────────────────────────────────────
_parse_condition:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    // left expr
    bl _parse_expr
    cmp x0, #0
    b.lt _pc_err

    // save out_pos before push (for potential rewind)
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x21, [x0]               // x21 = push_pos

    // check if left is a simple var (for optimization)
    adrp x0, _last_is_var@PAGE
    add x0, x0, _last_is_var@PAGEOFF
    ldr w22, [x0]               // w22 = left_is_var flag
    str wzr, [x0]               // clear

    // push left
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str

    // get comp op
    bl _tok_peek
    mov w19, w0                  // save op type
    cmp w0, #TOK_EQ
    b.eq 1f
    cmp w0, #TOK_NEQ
    b.eq 1f
    cmp w0, #TOK_LT
    b.eq 1f
    cmp w0, #TOK_GT
    b.eq 1f
    cmp w0, #TOK_LTE
    b.eq 1f
    cmp w0, #TOK_GTE
    b.eq 1f
    b _pc_err
1:  bl _tok_advance

    // right expr
    bl _parse_expr
    cmp x0, #0
    b.lt _pc_err

    // check _last_is_var for right operand
    adrp x0, _last_is_var@PAGE
    add x0, x0, _last_is_var@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]               // clear flag
    cbnz w20, _pc_var_opt

    // check _last_is_imm for right operand
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]               // clear flag
    cbz w20, _pc_no_imm

    // immediate right: rewind to before push (erases push + dead mov)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // emit: cmp x0, #imm
    adrp x0, _fg_cmp_imm@PAGE
    add x0, x0, _fg_cmp_imm@PAGEOFF
    bl _emit_str
    adrp x0, _last_imm_val@PAGE
    add x0, x0, _last_imm_val@PAGEOFF
    ldr x0, [x0]
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    b _pc_done

_pc_var_opt:
    // clear _last_is_imm in case it was also set
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    str wzr, [x0]
    // rewind to before push (erases push + right's ldr x0)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // load right var offset
    adrp x0, _last_var_offset@PAGE
    add x0, x0, _last_var_offset@PAGEOFF
    ldr w20, [x0]              // w20 = right var offset
    // emit: ldr x1, [x29, #-offset]\n
    adrp x0, _fg_ldr1@PAGE
    add x0, x0, _fg_ldr1@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    // emit: cmp x0, x1
    adrp x0, _fg_cmp01@PAGE
    add x0, x0, _fg_cmp01@PAGEOFF
    bl _emit_str
    b _pc_done

_pc_no_imm:
    // pop left into x1, emit cmp x1, x0
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _fg_cmp1@PAGE
    add x0, x0, _fg_cmp1@PAGEOFF
    bl _emit_str

_pc_done:

    mov w0, w19                  // return op type
    b _pc_ret
_pc_err:
    mov x0, #-1
_pc_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_if
// ────────────────────────────────────────
_parse_if:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _tok_advance              // skip "if"

    // allocate labels
    bl _new_label
    mov x20, x0                  // lbl_else
    bl _new_label
    mov x21, x0                  // lbl_end

    // parse condition with and/or/not support
    mov x0, x20                  // false_label = lbl_else
    bl _parse_cond_branch
    cmp x0, #0
    b.lt _pi_err

    // expect : NL INDENT
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err

    // parse then block
    bl _parse_block
    cmp x0, #0
    b.lt _pi_err

    // emit branch to end
    mov x0, x21
    bl _emit_branch

    // emit else label
    mov x0, x20
    bl _emit_label

    // check for else/elif clause
_pi_check_elif_else:
    bl _skip_nl
    bl _tok_peek
    cmp w0, #TOK_KW_ELIF
    b.ne _pi_check_else

    // elif: parse as nested if within else
    bl _tok_advance              // skip "elif"

    // allocate new else label
    bl _new_label
    mov x20, x0                  // new lbl_else

    // parse condition with and/or/not support
    mov x0, x20
    bl _parse_cond_branch
    cmp x0, #0
    b.lt _pi_err

    // expect : NL INDENT
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err

    // parse elif body
    bl _parse_block
    cmp x0, #0
    b.lt _pi_err

    // emit branch to end
    mov x0, x21
    bl _emit_branch

    // emit else label for this elif
    mov x0, x20
    bl _emit_label

    // loop back to check for more elif/else
    b _pi_check_elif_else

_pi_check_else:
    cmp w0, #TOK_KW_ELSE
    b.ne _pi_no_else

    bl _tok_advance              // skip "else"
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pi_err
    bl _parse_block
    cmp x0, #0
    b.lt _pi_err

_pi_no_else:
    // emit end label
    mov x0, x21
    bl _emit_label

    mov x0, #0
    b _pi_ret
_pi_err:
    mov x0, #-1
_pi_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_while
// ────────────────────────────────────────
_parse_while:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _tok_advance              // skip "while"

    bl _new_label
    mov x19, x0                  // lbl_top
    bl _new_label
    mov x20, x0                  // lbl_end

    // emit top label
    mov x0, x19
    bl _emit_label

    // parse condition with and/or/not support
    mov x0, x20                  // false_label = lbl_end
    bl _parse_cond_branch
    cmp x0, #0
    b.lt _pw_err

    // expect : NL INDENT
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pw_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pw_err

    // push loop stack
    mov x0, x19                  // top_label
    mov x1, x20                  // end_label
    bl _loop_push

    // parse body
    bl _parse_block
    cmp x0, #0
    b.lt _pw_err

    // pop loop stack
    bl _loop_pop

    // branch back to top
    mov x0, x19
    bl _emit_branch

    // emit end label
    mov x0, x20
    bl _emit_label

    mov x0, #0
    b _pw_ret
_pw_err:
    mov x0, #-1
_pw_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_for - "for i in 0..10:"
// ────────────────────────────────────────
_parse_for:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    bl _tok_advance              // skip "for"

    // get loop var ident
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pf_err
    bl _tok_current
    ldr x19, [x0, #8]           // name_ptr
    ldr w20, [x0, #4]           // name_len
    bl _tok_advance

    // lookup or insert
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbnz x0, 1f
    mov x0, x19
    mov x1, x20
    mov w2, #TY_INT
    bl _sym_insert
1:  mov x21, x0                 // entry ptr

    // expect "in"
    mov w0, #TOK_KW_IN
    bl _tok_expect
    cmp x0, #0
    b.lt _pf_err

    // parse start expression
    bl _parse_expr
    cmp x0, #0
    b.lt _pf_err
    // store start value to loop var
    ldr w0, [x21, #16]
    bl _emit_store_var

    // expect ".."
    mov w0, #TOK_DOTDOT
    bl _tok_expect
    cmp x0, #0
    b.lt _pf_err

    // parse end expression
    bl _parse_expr
    cmp x0, #0
    b.lt _pf_err
    // allocate hidden end-bound slot
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    ldr w22, [x0]
    add w22, w22, #8
    str w22, [x0]                // x22 = end_bound offset
    // store end value
    mov w0, w22
    bl _emit_store_var

    // expect : NL INDENT
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pf_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pf_err

    // allocate labels
    bl _new_label
    mov x24, x0                  // lbl_top
    bl _new_label
    mov x25, x0                  // lbl_end

    // emit top label
    mov x0, x24
    bl _emit_label

    // emit: load loop var, load end bound into x1, cmp x0, x1
    ldr w0, [x21, #16]
    bl _emit_load_var
    // emit: ldr x1, [x29, #-end_offset]\n
    adrp x0, _fg_ldr1@PAGE
    add x0, x0, _fg_ldr1@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    // emit: cmp x0, x1
    adrp x0, _fg_cmp01@PAGE
    add x0, x0, _fg_cmp01@PAGEOFF
    bl _emit_str
    // emit: b.ge lbl_end (if loop_var >= end, exit)
    mov w0, #TOK_LT             // for < end, invert = b.ge
    mov x1, x25
    bl _emit_inv_branch

    // push loop stack
    mov x0, x24                  // top_label
    mov x1, x25                  // end_label
    bl _loop_push

    // parse body
    bl _parse_block
    cmp x0, #0
    b.lt _pf_err

    // pop loop stack
    bl _loop_pop

    // emit increment: ldr, add #1, str
    ldr w0, [x21, #16]
    bl _emit_load_var
    adrp x0, _fg_add1@PAGE
    add x0, x0, _fg_add1@PAGEOFF
    bl _emit_str
    ldr w0, [x21, #16]
    bl _emit_store_var

    // branch back to top
    mov x0, x24
    bl _emit_branch

    // emit end label
    mov x0, x25
    bl _emit_label

    mov x0, #0
    b _pf_ret

_pf_err:
    mov x0, #-1
_pf_ret:
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// Expression parsing: expr → term → factor
// Result always in x0 of generated code
// ────────────────────────────────────────

// _parse_expr: term { (+|-) term }
_parse_expr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _parse_term
    cmp x0, #0
    b.lt _pe_err

_pe_loop:
    bl _tok_peek
    cmp w0, #TOK_PLUS
    b.eq 1f
    cmp w0, #TOK_MINUS
    b.eq 1f
    b _pe_done
1:  mov w19, w0                  // save op
    bl _tok_advance
    // save out_pos before push (for potential rewind)
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x21, [x0]               // x21 = push_pos
    // emit push
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // parse right term
    bl _parse_term
    cmp x0, #0
    b.lt _pe_err

    // check _last_is_var flag first
    adrp x0, _last_is_var@PAGE
    add x0, x0, _last_is_var@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]               // clear flag
    cbnz w20, _pe_var_opt

    // check _last_is_imm flag
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]               // clear flag
    cbz w20, _pe_no_imm

    // immediate: rewind to before push (erases push + dead mov)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // emit add/sub with immediate directly
    cmp w19, #TOK_PLUS
    b.ne _pe_imm_sub
    adrp x0, _fg_add_imm@PAGE
    add x0, x0, _fg_add_imm@PAGEOFF
    b _pe_imm_emit
_pe_imm_sub:
    adrp x0, _fg_sub_imm@PAGE
    add x0, x0, _fg_sub_imm@PAGEOFF
_pe_imm_emit:
    bl _emit_str
    adrp x0, _last_imm_val@PAGE
    add x0, x0, _last_imm_val@PAGEOFF
    ldr x0, [x0]
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    b _pe_loop

_pe_var_opt:
    // clear _last_is_imm in case it was also set
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    str wzr, [x0]
    // rewind to before push (erases push + right's ldr x0)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // load right var offset
    adrp x0, _last_var_offset@PAGE
    add x0, x0, _last_var_offset@PAGEOFF
    ldr w20, [x0]              // w20 = right var offset
    // emit: ldr x1, [x29, #-offset]\n
    adrp x0, _fg_ldr1@PAGE
    add x0, x0, _fg_ldr1@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    // emit add/sub: x0 op x1 → x0
    cmp w19, #TOK_PLUS
    b.ne _pe_var_sub
    adrp x0, _fg_add_r@PAGE
    add x0, x0, _fg_add_r@PAGEOFF
    b _pe_var_emit
_pe_var_sub:
    adrp x0, _fg_sub_r@PAGE
    add x0, x0, _fg_sub_r@PAGEOFF
_pe_var_emit:
    bl _emit_str
    b _pe_loop

_pe_no_imm:
    // pop left into x1
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    // emit op
    cmp w19, #TOK_PLUS
    b.ne 2f
    adrp x0, _fg_add@PAGE
    add x0, x0, _fg_add@PAGEOFF
    b 3f
2:  adrp x0, _fg_sub@PAGE
    add x0, x0, _fg_sub@PAGEOFF
3:  bl _emit_str
    b _pe_loop

_pe_done:
    mov x0, #0
    b _pe_ret
_pe_err:
    mov x0, #-1
_pe_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_term: factor { (*|/|%) factor }
_parse_term:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _parse_factor
    cmp x0, #0
    b.lt _pt_err

_pt_loop:
    bl _tok_peek
    cmp w0, #TOK_STAR
    b.eq 1f
    cmp w0, #TOK_SLASH
    b.eq 1f
    cmp w0, #TOK_MOD
    b.eq 1f
    b _pt_done
1:  mov w19, w0
    bl _tok_advance
    // save out_pos before push (for potential rewind)
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x21, [x0]               // x21 = push_pos
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    bl _parse_factor
    cmp x0, #0
    b.lt _pt_err

    // check _last_is_var for right operand
    adrp x0, _last_is_var@PAGE
    add x0, x0, _last_is_var@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]               // clear flag
    cbnz w20, _pt_var_opt

    // check _last_is_imm — can still eliminate push/pop
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    ldr w20, [x0]
    str wzr, [x0]
    cbz w20, _pt_no_opt

    // imm right: rewind to before push (erases push + dead mov)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // emit: mov x1, #imm
    adrp x0, _pt_mov_x1_imm@PAGE
    add x0, x0, _pt_mov_x1_imm@PAGEOFF
    bl _emit_str
    adrp x0, _last_imm_val@PAGE
    add x0, x0, _last_imm_val@PAGEOFF
    ldr x0, [x0]
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    b _pt_emit_op_r

_pt_var_opt:
    // clear _last_is_imm in case it was also set
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    str wzr, [x0]
    // rewind to before push (erases push + right's ldr x0)
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    str x21, [x1]
    // load right var offset
    adrp x0, _last_var_offset@PAGE
    add x0, x0, _last_var_offset@PAGEOFF
    ldr w20, [x0]
    // emit: ldr x1, [x29, #-offset]\n
    adrp x0, _fg_ldr1@PAGE
    add x0, x0, _fg_ldr1@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_cb@PAGE
    add x0, x0, _fg_cb@PAGEOFF
    bl _emit_str
    b _pt_emit_op_r

_pt_no_opt:
    // fallback: pop left into x1
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str

    // emit mul/sdiv/mod with original operand order (x1=left, x0=right)
    cmp w19, #TOK_STAR
    b.ne 2f
    adrp x0, _fg_mul@PAGE
    add x0, x0, _fg_mul@PAGEOFF
    b 4f
2:  cmp w19, #TOK_SLASH
    b.ne 3f
    adrp x0, _fg_sdiv@PAGE
    add x0, x0, _fg_sdiv@PAGEOFF
    b 4f
3:  adrp x0, _fg_mod@PAGE
    add x0, x0, _fg_mod@PAGEOFF
4:  bl _emit_str
    // clear _last_is_var (term result is not a simple var)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    b _pt_loop

_pt_emit_op_r:
    // emit mul/sdiv/mod with reversed operand order (x0=left, x1=right)
    cmp w19, #TOK_STAR
    b.ne 5f
    adrp x0, _fg_mul_r@PAGE
    add x0, x0, _fg_mul_r@PAGEOFF
    b 7f
5:  cmp w19, #TOK_SLASH
    b.ne 6f
    adrp x0, _fg_sdiv_r@PAGE
    add x0, x0, _fg_sdiv_r@PAGEOFF
    b 7f
6:  adrp x0, _fg_mod_r@PAGE
    add x0, x0, _fg_mod_r@PAGEOFF
7:  bl _emit_str
    // clear _last_is_var (term result is not a simple var)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    b _pt_loop

_pt_done:
    mov x0, #0
    b _pt_ret
_pt_err:
    mov x0, #-1
_pt_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_factor: INT | STR | IDENT | input_num() | input_str() | (expr) | -factor
_parse_factor:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // clear _last_is_var flag (set only in variable load path)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]

    bl _tok_peek

    // integer literal
    cmp w0, #TOK_INT
    b.ne _pfac_str
    bl _tok_current
    ldr x19, [x0, #16]          // value
    bl _tok_advance
    // check if value fits in 12-bit immediate (0-4095) and is non-negative
    cmp x19, #0
    b.lt _pfac_int_full
    cmp x19, #4095
    b.gt _pfac_int_full
    // defer: set _last_is_imm flag
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    mov w1, #1
    str w1, [x0]
    adrp x0, _last_imm_val@PAGE
    add x0, x0, _last_imm_val@PAGEOFF
    str x19, [x0]
    // save out_pos for potential rewind of dead mov
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    ldr x1, [x1]
    adrp x0, _last_imm_out_pos@PAGE
    add x0, x0, _last_imm_out_pos@PAGEOFF
    str x1, [x0]
    mov x0, x19
    bl _emit_mov_imm
    mov x0, #0
    b _pfac_ret
_pfac_int_full:
    adrp x0, _last_is_imm@PAGE
    add x0, x0, _last_is_imm@PAGEOFF
    str wzr, [x0]
    mov x0, x19
    bl _emit_mov_imm
    mov x0, #0
    b _pfac_ret

_pfac_str:
    cmp w0, #TOK_STR
    b.ne _pfac_ident
    // string in factor context — register it and load address to x0
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string
    mov x19, x0                  // string index

    // emit: adrp x0, _sN@PAGE / add x0, x0, _sN@PAGEOFF
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str

    mov x0, #0
    b _pfac_ret

_pfac_ident:
    cmp w0, #TOK_IDENT
    b.ne _pfac_innum
    // clear imm flag for non-literal values
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance

    // check if function call: IDENT followed by "("
    bl _tok_peek
    cmp w0, #TOK_LPAREN
    b.eq _pfac_fn_call

    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pfac_undef

    // v0.7: check if array type
    ldr w1, [x0, #12]
    cmp w1, #TY_ARR
    b.eq _pfac_arr_read

    ldr w19, [x0, #16]          // offset (reuse x19, done with name)
    // set _last_is_var flag
    adrp x0, _last_is_var@PAGE
    add x0, x0, _last_is_var@PAGEOFF
    mov w1, #1
    str w1, [x0]
    adrp x0, _last_var_offset@PAGE
    add x0, x0, _last_var_offset@PAGEOFF
    str w19, [x0]
    // save out_pos before emitting ldr
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x0, [x0]
    adrp x1, _last_var_out_pos@PAGE
    add x1, x1, _last_var_out_pos@PAGEOFF
    str x0, [x1]
    mov w0, w19
    bl _emit_load_var
    mov x0, #0
    b _pfac_ret

_pfac_fn_call:
    // function call in expression context
    mov x0, x19
    mov x1, x20
    bl _emit_fn_call
    // clear _last_is_var (fn call result is not a simple var)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    // result is in x0 of generated code
    b _pfac_ret

_pfac_innum:
    cmp w0, #TOK_KW_INNUM
    b.ne _pfac_instr
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    // expect ()
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // emit: bl _rt_read_line / atoi
    adrp x0, _fg_input_call@PAGE
    add x0, x0, _fg_input_call@PAGEOFF
    bl _emit_str
    adrp x0, _fg_atoi_call@PAGE
    add x0, x0, _fg_atoi_call@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

_pfac_instr:
    cmp w0, #TOK_KW_INSTR
    b.ne _pfac_pipe
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // emit: bl _rt_read_line (x0 = length)
    adrp x0, _fg_input_call@PAGE
    add x0, x0, _fg_input_call@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

// v0.5: pipe() expression
_pfac_pipe:
    cmp w0, #TOK_KW_PIPE
    b.ne _pfac_open
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // emit: bl _rt_pipe (x0=read_fd, x1=write_fd)
    adrp x0, _fg_pipe_call@PAGE
    add x0, x0, _fg_pipe_call@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

// v0.5: open("path", "r"/"w") expression
_pfac_open:
    cmp w0, #TOK_KW_OPEN
    b.ne _pfac_rdline
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // get path string
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pfac_err
    bl _tok_current
    ldr x19, [x0, #8]           // path ptr
    ldr w20, [x0, #4]           // path len
    bl _tok_advance
    // expect comma
    mov w0, #TOK_COMMA
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // get mode string
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pfac_err
    bl _tok_current
    ldr x0, [x0, #8]            // mode ptr
    ldrb w0, [x0]               // first char: 'r' or 'w'
    str x0, [sp, #-16]!         // save mode char
    bl _tok_advance
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // register path string and load address
    mov x0, x19
    mov x1, x20
    bl _reg_string
    mov x19, x0                 // string index
    // emit: adrp x0, _sN@PAGE / add x0, x0, _sN@PAGEOFF
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // emit: mov x1, #path_len (for _rt_open_r/w: x0=path_ptr, x1=path_len)
    adrp x0, _pemit_mov_x1_imm@PAGE
    add x0, x0, _pemit_mov_x1_imm@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // check mode
    ldr x0, [sp], #16           // restore mode char
    cmp w0, #'w'
    b.eq _pfac_open_w
    // read mode
    adrp x0, _fg_open_r_call@PAGE
    add x0, x0, _fg_open_r_call@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret
_pfac_open_w:
    adrp x0, _fg_open_w_call@PAGE
    add x0, x0, _fg_open_w_call@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

// v0.5: read_line(fd) expression
_pfac_rdline:
    cmp w0, #TOK_KW_RDLINE
    b.ne _pfac_wait
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    bl _parse_expr               // fd in x0
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    adrp x0, _fg_readline_fd@PAGE
    add x0, x0, _fg_readline_fd@PAGEOFF
    bl _emit_str
    // clear flags (rdline result is not simple var/imm)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

// v0.5: wait(pid) expression
_pfac_wait:
    cmp w0, #TOK_KW_WAIT
    b.ne _pfac_lparen
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    bl _parse_expr               // pid in x0
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // emit: bl _rt_wait (x0=pid → x0=exit_status)
    adrp x0, _fg_wait_call@PAGE
    add x0, x0, _fg_wait_call@PAGEOFF
    bl _emit_str
    // clear flags (wait result is not simple var/imm)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

_pfac_lparen:
    cmp w0, #TOK_LPAREN
    b.ne _pfac_len
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    bl _parse_expr
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // clear flags (paren result is not simple var/imm)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

// v0.7: len(s) — string length
_pfac_len:
    cmp w0, #TOK_KW_LEN
    b.ne _pfac_char_at
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // expect identifier (string variable)
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pfac_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pfac_undef
    // load length from offset+8 (TY_STR stores ptr at offset, len at offset+8)
    ldr w19, [x0, #16]
    add w19, w19, #8
    mov w0, w19
    bl _emit_load_var
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

// v0.7: char_at(s, i) — character at index
_pfac_char_at:
    cmp w0, #TOK_KW_CHARAT
    b.ne _pfac_to_str
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // expect string variable
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pfac_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pfac_undef
    // load string ptr → x0
    ldr w19, [x0, #16]
    mov w0, w19
    bl _emit_load_var
    // push string ptr
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // expect comma
    mov w0, #TOK_COMMA
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // parse index expression → x0
    bl _parse_expr
    cmp x0, #0
    b.lt _pfac_err
    // emit: mov x1, x0 (index → x1)
    adrp x0, _pfac_mov_x1_x0@PAGE
    add x0, x0, _pfac_mov_x1_x0@PAGEOFF
    bl _emit_str
    // pop string ptr → x0
    adrp x0, _fg_pop0@PAGE
    add x0, x0, _fg_pop0@PAGEOFF
    bl _emit_str
    // emit: ldrb w0, [x0, x1]
    adrp x0, _fg_ldrb@PAGE
    add x0, x0, _fg_ldrb@PAGEOFF
    bl _emit_str
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

// v0.7: to_str(n) — integer to string
_pfac_to_str:
    cmp w0, #TOK_KW_TOSTR
    b.ne _pfac_to_num
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // parse integer expression → x0
    bl _parse_expr
    cmp x0, #0
    b.lt _pfac_err
    // emit: itoa call (x0=value → _itoa_buf, x0=length)
    adrp x0, _pfac_tostr_code@PAGE
    add x0, x0, _pfac_tostr_code@PAGEOFF
    bl _emit_str
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

// v0.7: to_num(s) — string to integer
_pfac_to_num:
    cmp w0, #TOK_KW_TONUM
    b.ne _pfac_neg
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // expect string variable
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pfac_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pfac_undef
    // load string ptr → x0
    ldr w19, [x0, #16]
    mov w0, w19
    bl _emit_load_var
    // emit: bl _rt_atoi
    adrp x0, _pfac_atoi_call@PAGE
    add x0, x0, _pfac_atoi_call@PAGEOFF
    bl _emit_str
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

_pfac_neg:
    // unary minus
    cmp w0, #TOK_MINUS
    b.ne _pfac_err
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    bl _tok_advance
    bl _parse_factor
    cmp x0, #0
    b.lt _pfac_err
    // clear flags (neg result is not simple var/imm)
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    // emit: neg x0, x0
    adrp x0, _pfac_neg_str@PAGE
    add x0, x0, _pfac_neg_str@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

// v0.7: array index read — arr[i]
_pfac_arr_read:
    // x0 = entry ptr
    ldr w19, [x0, #16]          // offset
    ldr w20, [x0, #20]          // element_count
    // compute arr_base = offset - N*8 + 8
    lsl w20, w20, #3
    sub w19, w19, w20
    add w19, w19, #8
    // expect [
    mov w0, #TOK_LBRACKET
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // parse index expression → x0
    bl _parse_expr
    cmp x0, #0
    b.lt _pfac_err
    // expect ]
    mov w0, #TOK_RBRACKET
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    // emit: lsl x0, x0, #3
    adrp x0, _fg_lsl3@PAGE
    add x0, x0, _fg_lsl3@PAGEOFF
    bl _emit_str
    // emit: mov x1, #arr_base
    adrp x0, _fg_mov_x1_imm@PAGE
    add x0, x0, _fg_mov_x1_imm@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // emit: add x1, x1, x0
    adrp x0, _fg_add_x1_x0@PAGE
    add x0, x0, _fg_add_x1_x0@PAGEOFF
    bl _emit_str
    // emit: neg x1, x1
    adrp x0, _fg_neg_x1@PAGE
    add x0, x0, _fg_neg_x1@PAGEOFF
    bl _emit_str
    // emit: ldr x0, [x29, x1]
    adrp x0, _fg_ldr_x29_x1@PAGE
    add x0, x0, _fg_ldr_x29_x1@PAGEOFF
    bl _emit_str
    // clear optimization flags
    adrp x1, _last_is_var@PAGE
    add x1, x1, _last_is_var@PAGEOFF
    str wzr, [x1]
    adrp x1, _last_is_imm@PAGE
    add x1, x1, _last_is_imm@PAGEOFF
    str wzr, [x1]
    mov x0, #0
    b _pfac_ret

_pfac_undef:
    bl _tok_line
    mov x1, x0
    adrp x0, _err_undef@PAGE
    add x0, x0, _err_undef@PAGEOFF
    bl _err_line
_pfac_err:
    mov x0, #-1
_pfac_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// Loop stack operations for break/continue
// ────────────────────────────────────────

// _loop_push: x0=top_label, x1=end_label
_loop_push:
    adrp x2, _loop_sp@PAGE
    add x2, x2, _loop_sp@PAGEOFF
    ldr w3, [x2]
    cmp w3, #16
    b.ge _parser_overflow
    adrp x4, _loop_stack@PAGE
    add x4, x4, _loop_stack@PAGEOFF
    mov x5, x3
    lsl x5, x5, #4              // * 16
    str x0, [x4, x5]            // top_label
    add x5, x5, #8
    str x1, [x4, x5]            // end_label
    add w3, w3, #1
    str w3, [x2]
    ret

// _loop_pop: decrement loop stack
_loop_pop:
    adrp x0, _loop_sp@PAGE
    add x0, x0, _loop_sp@PAGEOFF
    ldr w1, [x0]
    sub w1, w1, #1
    str w1, [x0]
    ret

// _parse_break: emit branch to current loop's end label
_parse_break:
    stp x29, x30, [sp, #-16]!
    bl _tok_advance              // skip "break"
    adrp x0, _loop_sp@PAGE
    add x0, x0, _loop_sp@PAGEOFF
    ldr w1, [x0]
    cbz w1, _pbrk_err           // not in a loop
    sub w1, w1, #1
    adrp x2, _loop_stack@PAGE
    add x2, x2, _loop_stack@PAGEOFF
    mov x3, x1
    lsl x3, x3, #4
    add x3, x3, #8              // end_label offset
    ldr x0, [x2, x3]
    bl _emit_branch
    bl _skip_nl
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret
_pbrk_err:
    bl _tok_line
    mov x1, x0
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    bl _err_line
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

// _parse_continue: emit branch to current loop's top label
_parse_continue:
    stp x29, x30, [sp, #-16]!
    bl _tok_advance              // skip "continue"
    adrp x0, _loop_sp@PAGE
    add x0, x0, _loop_sp@PAGEOFF
    ldr w1, [x0]
    cbz w1, _pcont_err           // not in a loop
    sub w1, w1, #1
    adrp x2, _loop_stack@PAGE
    add x2, x2, _loop_stack@PAGEOFF
    mov x3, x1
    lsl x3, x3, #4
    ldr x0, [x2, x3]            // top_label
    bl _emit_branch
    bl _skip_nl
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret
_pcont_err:
    bl _tok_line
    mov x1, x0
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    bl _err_line
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// Function table operations
// ────────────────────────────────────────

// _fn_insert: x0=name_ptr, x1=name_len, w2=param_count
// Returns x0 = entry ptr
_fn_insert:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    mov w21, w2
    adrp x0, _fn_count@PAGE
    add x0, x0, _fn_count@PAGEOFF
    ldr w1, [x0]
    mov x2, #24                  // entry size: name_ptr(8)+name_len(4)+param_count(4)+reserved(8)
    mul x3, x1, x2
    adrp x4, _fn_tab@PAGE
    add x4, x4, _fn_tab@PAGEOFF
    add x4, x4, x3              // entry ptr
    str x19, [x4, #0]           // name_ptr
    str w20, [x4, #8]           // name_len
    str w21, [x4, #12]          // param_count
    add w1, w1, #1
    str w1, [x0]
    mov x0, x4
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _fn_lookup: x0=name_ptr, x1=name_len → x0=entry ptr or 0
_fn_lookup:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    adrp x0, _fn_count@PAGE
    add x0, x0, _fn_count@PAGEOFF
    ldr w21, [x0]
    adrp x22, _fn_tab@PAGE
    add x22, x22, _fn_tab@PAGEOFF
    mov w0, #0
_fnl_loop:
    cmp w0, w21
    b.ge _fnl_notfound
    mov x1, #24
    mul x2, x0, x1
    add x3, x22, x2
    ldr x4, [x3, #0]            // stored name_ptr
    ldr w5, [x3, #8]            // stored name_len
    cmp w5, w20
    b.ne _fnl_next
    // compare names
    stp x0, x3, [sp, #-16]!
    mov x0, x19
    mov x1, x4
    mov x2, x20
    bl _strncmp
    mov x4, x0
    ldp x0, x3, [sp], #16
    cbz x4, _fnl_found
_fnl_next:
    add w0, w0, #1
    b _fnl_loop
_fnl_found:
    mov x0, x3
    b _fnl_ret
_fnl_notfound:
    mov x0, #0
_fnl_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _emit_fn_call: x0=name_ptr, x1=name_len
// Parses args, emits arg setup + bl _uf_<name>
// Returns x0=0 ok, -1 err
// ────────────────────────────────────────
_emit_fn_call:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0                  // name_ptr
    mov x20, x1                  // name_len

    // lookup function
    bl _fn_lookup
    cbz x0, _efc_undef
    ldr w21, [x0, #12]          // expected param_count

    // expect "("
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err

    // parse arguments — evaluate each into x0, push to stack
    mov w22, #0                  // arg_count
_efc_arg_loop:
    bl _tok_peek
    cmp w0, #TOK_RPAREN
    b.eq _efc_args_done
    // if not first arg, expect comma
    cbz w22, _efc_parse_arg
    mov w0, #TOK_COMMA
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err
_efc_parse_arg:
    bl _parse_expr
    cmp x0, #0
    b.lt _efc_err
    // push arg value onto stack (will pop into registers later)
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    add w22, w22, #1
    b _efc_arg_loop

_efc_args_done:
    // expect ")"
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err

    // single-arg optimization: skip push/pop round-trip
    cmp w22, #1
    b.ne _efc_multi_args
    // rewind the push (x0 already has the arg value)
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x1, [x0]
    // push emitted 24 bytes: "    str x0, [sp, #-16]!\n"
    sub x1, x1, #24
    str x1, [x0]
    b _efc_emit_call

_efc_multi_args:
    // pop args into registers in reverse order
    mov w0, w22
    sub w0, w0, #1              // start from last arg
_efc_pop_args:
    cmp w0, #0
    b.lt _efc_emit_call
    // emit: ldr xN, [sp], #16
    stp x0, x1, [sp, #-16]!
    adrp x1, _efc_ldr_x@PAGE
    add x1, x1, _efc_ldr_x@PAGEOFF
    mov x0, x1
    bl _emit_str
    ldp x0, x1, [sp], #16
    stp x0, x1, [sp, #-16]!
    bl _emit_num
    adrp x0, _efc_pop_suf@PAGE
    add x0, x0, _efc_pop_suf@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    sub w0, w0, #1
    b _efc_pop_args

_efc_emit_call:
    // check if this is an extern C call
    adrp x1, _efc_is_extern@PAGE
    add x1, x1, _efc_is_extern@PAGEOFF
    ldr w2, [x1]
    str wzr, [x1]                // clear flag
    cbnz w2, _efc_emit_c_call
    // emit: bl _uf_<name>
    adrp x0, _fg_bl_uf@PAGE
    add x0, x0, _fg_bl_uf@PAGEOFF
    bl _emit_str
    b _efc_emit_name
_efc_emit_c_call:
    // emit: bl _<name>
    adrp x0, _fg_bl_c@PAGE
    add x0, x0, _fg_bl_c@PAGEOFF
    bl _emit_str
_efc_emit_name:
    mov x0, x19
    mov x1, x20
    bl _emit_raw
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str

    mov x0, #0
    b _efc_ret

_efc_undef:
    // check extern table first
    mov x0, x19
    mov x1, x20
    bl _ext_lookup
    cbnz x0, _efc_extern_call

    // check if imports exist — if so, trust the linker
    adrp x0, _import_count@PAGE
    add x0, x0, _import_count@PAGEOFF
    ldr w0, [x0]
    cbz w0, _efc_check_ext_only

    // blind call: parse args without param_count check
_efc_blind_call_args:
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err
    mov w22, #0
_efc_blind_arg_loop:
    bl _tok_peek
    cmp w0, #TOK_RPAREN
    b.eq _efc_blind_args_done
    cbz w22, _efc_blind_parse_arg
    mov w0, #TOK_COMMA
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err
_efc_blind_parse_arg:
    bl _parse_expr
    cmp x0, #0
    b.lt _efc_err
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    add w22, w22, #1
    b _efc_blind_arg_loop
_efc_blind_args_done:
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _efc_err
    // single-arg optimization
    cmp w22, #1
    b.ne _efc_blind_multi
    adrp x0, _out_pos@PAGE
    add x0, x0, _out_pos@PAGEOFF
    ldr x1, [x0]
    sub x1, x1, #24
    str x1, [x0]
    b _efc_emit_call
_efc_blind_multi:
    mov w0, w22
    sub w0, w0, #1
_efc_blind_pop:
    cmp w0, #0
    b.lt _efc_emit_call
    stp x0, x1, [sp, #-16]!
    adrp x0, _efc_ldr_x@PAGE
    add x0, x0, _efc_ldr_x@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    stp x0, x1, [sp, #-16]!
    mov x1, x0
    mov x0, x1
    bl _emit_num
    adrp x0, _efc_pop_suf@PAGE
    add x0, x0, _efc_pop_suf@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    sub w0, w0, #1
    b _efc_blind_pop

_efc_extern_call:
    // set extern flag, then reuse blind call arg parsing
    adrp x1, _efc_is_extern@PAGE
    add x1, x1, _efc_is_extern@PAGEOFF
    mov w2, #1
    str w2, [x1]
    b _efc_blind_call_args

_efc_check_ext_only:
    // no imports — check if extern functions exist
    adrp x0, _ext_count@PAGE
    add x0, x0, _ext_count@PAGEOFF
    ldr w0, [x0]
    cbz w0, _efc_undef_err
    // has externs but function not in extern table — error
    b _efc_undef_err

_efc_undef_err:
    bl _tok_line
    mov x1, x0
    adrp x0, _err_undef@PAGE
    add x0, x0, _err_undef@PAGEOFF
    bl _err_line
_efc_err:
    mov x0, #-1
_efc_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_fn - Parse function definition
// fn name(params...):
//     body
// ────────────────────────────────────────
_parse_fn:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    bl _tok_advance              // skip "fn"

    // get function name
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _pfn_err
    bl _tok_current
    ldr x19, [x0, #8]           // name_ptr
    ldr w20, [x0, #4]           // name_len
    bl _tok_advance

    // expect "("
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfn_err

    // save sym_count and frame_size for scope
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    ldr w21, [x0]               // saved sym_count
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    ldr w22, [x0]               // saved frame_size
    str wzr, [x0]               // reset frame_size for function

    // parse parameter list
    mov w23, #0                  // param_count
_pfn_param_loop:
    bl _tok_peek
    cmp w0, #TOK_RPAREN
    b.eq _pfn_param_done
    cmp w0, #TOK_IDENT
    b.ne _pfn_err
    // get param name before advancing
    bl _tok_current
    ldr x0, [x0, #8]            // param name_ptr
    stp x0, x30, [sp, #-16]!    // save name_ptr
    bl _tok_current
    ldr w1, [x0, #4]            // param name_len
    ldp x0, x30, [sp], #16      // restore name_ptr
    stp x0, x1, [sp, #-16]!     // save name_ptr + name_len
    bl _tok_advance
    ldp x0, x1, [sp], #16       // restore name_ptr + name_len
    // insert param as integer symbol
    mov w2, #TY_INT
    bl _sym_insert
    // bump param count
    add w23, w23, #1
    // check for comma
    bl _tok_peek
    cmp w0, #TOK_COMMA
    b.ne _pfn_param_loop
    bl _tok_advance              // skip ","
    b _pfn_param_loop

_pfn_param_done:
    bl _tok_advance              // skip ")"

    // register function
    mov x0, x19
    mov x1, x20
    mov w2, w23
    bl _fn_insert
    mov x24, x0                 // fn entry ptr

    // expect : NL INDENT
    mov w0, #TOK_COLON
    bl _tok_expect
    cmp x0, #0
    b.lt _pfn_err
    bl _skip_nl
    mov w0, #TOK_INDENT
    bl _tok_expect
    cmp x0, #0
    b.lt _pfn_err

    // emit function label: _uf_<name>\n
    // emit .globl _uf_<name> for cross-file linking
    adrp x0, _fg_globl_uf@PAGE
    add x0, x0, _fg_globl_uf@PAGEOFF
    bl _emit_str
    mov x0, x19
    mov x1, x20
    bl _emit_raw
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    adrp x0, _pfn_uf@PAGE
    add x0, x0, _pfn_uf@PAGEOFF
    bl _emit_str
    mov x0, x19
    mov x1, x20
    bl _emit_raw
    adrp x0, _pfn_colon_nl@PAGE
    add x0, x0, _pfn_colon_nl@PAGEOFF
    bl _emit_str

    // emit function prologue with frame placeholder
    adrp x0, _fg_fn_pro@PAGE
    add x0, x0, _fg_fn_pro@PAGEOFF
    bl _emit_str
    // save patch position for this function's frame size
    adrp x1, _out_pos@PAGE
    add x1, x1, _out_pos@PAGEOFF
    ldr x0, [x1]
    adrp x1, _fn_frame_patches@PAGE
    add x1, x1, _fn_frame_patches@PAGEOFF
    adrp x2, _fn_patch_count@PAGE
    add x2, x2, _fn_patch_count@PAGEOFF
    ldr w3, [x2]
    str x0, [x1, x3, lsl #3]
    add w3, w3, #1
    str w3, [x2]
    // emit placeholder
    adrp x0, _fg_frame_ph@PAGE
    add x0, x0, _fg_frame_ph@PAGEOFF
    bl _emit_str
    adrp x0, _fg_main2@PAGE
    add x0, x0, _fg_main2@PAGEOFF
    bl _emit_str

    // emit stores for parameters from registers
    mov w0, #0
_pfn_store_params:
    cmp w0, w23
    b.ge _pfn_store_done
    // emit: str xN, [x29, #-offset]
    // param N is in register xN, offset = (N+1)*8
    stp x0, x1, [sp, #-16]!
    add w1, w0, #1
    lsl w1, w1, #3              // offset = (N+1)*8
    // emit "    str x"
    adrp x0, _pfn_str_x@PAGE
    add x0, x0, _pfn_str_x@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    stp x0, x1, [sp, #-16]!
    mov x1, x0
    mov x0, x1
    bl _emit_num
    adrp x0, _pfn_comma_x29@PAGE
    add x0, x0, _pfn_comma_x29@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    stp x0, x1, [sp, #-16]!
    add w1, w0, #1
    lsl w1, w1, #3
    mov x0, x1
    bl _emit_num
    adrp x0, _pfn_bracket_nl@PAGE
    add x0, x0, _pfn_bracket_nl@PAGEOFF
    bl _emit_str
    ldp x0, x1, [sp], #16
    add w0, w0, #1
    b _pfn_store_params
_pfn_store_done:

    // parse function body
    bl _parse_block
    cmp x0, #0
    b.lt _pfn_err

    // emit default return (in case no explicit return)
    adrp x0, _fg_fn_epi@PAGE
    add x0, x0, _fg_fn_epi@PAGEOFF
    bl _emit_str

    // patch this function's frame size
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    ldr w0, [x0]
    cmp w0, #16
    b.ge 1f
    mov w0, #16
1:  add w0, w0, #15
    and w0, w0, #~15
    mov w23, w0                  // aligned frame size
    // get patch position
    adrp x1, _fn_patch_count@PAGE
    add x1, x1, _fn_patch_count@PAGEOFF
    ldr w2, [x1]
    sub w2, w2, #1
    adrp x3, _fn_frame_patches@PAGE
    add x3, x3, _fn_frame_patches@PAGEOFF
    ldr x1, [x3, x2, lsl #3]
    adrp x2, _out_buf@PAGE
    add x2, x2, _out_buf@PAGEOFF
    add x2, x2, x1
    // write digits right-to-left with leading spaces
    mov w4, #' '
    strb w4, [x2, #0]
    strb w4, [x2, #1]
    strb w4, [x2, #2]
    strb w4, [x2, #3]
    mov w0, w23
    add x6, x2, #3
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

    // restore sym_count and frame_size
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    str w21, [x0]
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    str w22, [x0]

    mov x0, #0
    b _pfn_ret
_pfn_err:
    // restore sym_count and frame_size on error too
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    str w21, [x0]
    adrp x0, _frame_size@PAGE
    add x0, x0, _frame_size@PAGEOFF
    str w22, [x0]
    mov x0, #-1
_pfn_ret:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _parse_return - Parse return statement
// ────────────────────────────────────────
_parse_return:
    stp x29, x30, [sp, #-16]!
    bl _tok_advance              // skip "return"
    bl _parse_expr
    cmp x0, #0
    b.lt _pret_err
    // emit function epilogue + ret (result already in x0)
    adrp x0, _fg_fn_epi@PAGE
    add x0, x0, _fg_fn_epi@PAGEOFF
    bl _emit_str
    bl _skip_nl
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret
_pret_err:
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// v0.5: _parse_emit - emit "key" value
// ────────────────────────────────────────
_parse_emit:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _tok_advance              // skip "emit"

    // get key string literal
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _pemit_err
    bl _tok_current
    ldr x19, [x0, #8]           // key ptr
    ldr w20, [x0, #4]           // key len
    bl _tok_advance

    // register key string
    mov x0, x19
    mov x1, x20
    bl _reg_string
    mov x21, x0                 // key string index

    // check value type: string literal or expression
    bl _tok_peek
    cmp w0, #TOK_STR
    b.eq _pemit_str_val

    // integer/expression value: use push/pop to preserve registers
    // Strategy:
    //   adrp x0, _sK@PAGE; add x0, x0, _sK@PAGEOFF  (key addr)
    //   mov x1, #key_len
    //   str x0, [sp, #-16]!   (push key_addr)
    //   str x1, [sp, #-16]!   (push key_len)
    //   <parse expr → x0 = int value>
    //   mov x2, x0            (int value to x2)
    //   ldr x1, [sp], #16     (pop key_len)
    //   ldr x0, [sp], #16     (pop key_addr)
    //   bl _rt_emit_int

    // load key addr into x0
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x21
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x21
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // push key addr
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // emit: mov x0, #key_len then push
    adrp x0, _fg_mov@PAGE
    add x0, x0, _fg_mov@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // parse value expression → x0 = int value
    bl _parse_expr
    cmp x0, #0
    b.lt _pemit_err
    // mov x2, x0 (int value)
    adrp x0, _pemit_mov_x2@PAGE
    add x0, x0, _pemit_mov_x2@PAGEOFF
    bl _emit_str
    // pop key_len → x1
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    // pop key_addr → x0
    adrp x0, _pemit_pop_x0@PAGE
    add x0, x0, _pemit_pop_x0@PAGEOFF
    bl _emit_str
    // now x0=key_ptr, x1=key_len, x2=int_value
    adrp x0, _fg_emit_int_call@PAGE
    add x0, x0, _fg_emit_int_call@PAGEOFF
    bl _emit_str
    b _pemit_nl

_pemit_str_val:
    // string value
    bl _tok_current
    ldr x19, [x0, #8]           // val ptr
    ldr w22, [x0, #4]           // val len
    bl _tok_advance
    // register value string
    mov x0, x19
    mov x1, x22
    bl _reg_string
    mov x22, x0                 // val string index

    // Strategy: compute val byte_len at compile time, then emit:
    //   adrp x0, _sK@PAGE; add x0, x0, _sK@PAGEOFF  (key addr)
    //   mov x1, #key_len
    //   str x0, [sp, #-16]!   (push key_addr)
    //   str x1, [sp, #-16]!   (push key_len)
    //   adrp x0, _sV@PAGE; add x0, x0, _sV@PAGEOFF  (val addr)
    //   mov x3, #val_byte_len
    //   mov x2, x0            (val addr to x2)
    //   ldr x1, [sp], #16     (pop key_len)
    //   ldr x0, [sp], #16     (pop key_addr)
    //   bl _rt_emit_str

    // compute val byte_len at compile time
    adrp x1, _str_ptrs@PAGE
    add x1, x1, _str_ptrs@PAGEOFF
    ldr x1, [x1, x22, lsl #3]
    adrp x2, _str_lens@PAGE
    add x2, x2, _str_lens@PAGEOFF
    ldr w2, [x2, x22, lsl #2]
    mov x3, #0
    mov x4, #0
31: cmp w3, w2
    b.ge 32f
    ldrb w5, [x1, x3]
    cmp w5, #'\\'
    b.ne 33f
    add x3, x3, #1
33: add x3, x3, #1
    add x4, x4, #1
    b 31b
32: // x4 = val byte_len
    str x4, [sp, #-16]!         // save val_byte_len for later

    // emit: load key addr to x0
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x21
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x21
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // emit: mov x1, #key_len
    adrp x0, _pemit_mov_x1_imm@PAGE
    add x0, x0, _pemit_mov_x1_imm@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // emit: push x0 (key addr)
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // emit: push x1 (key len) — use str x1
    adrp x0, _pemit_push_x1@PAGE
    add x0, x0, _pemit_push_x1@PAGEOFF
    bl _emit_str
    // emit: load val addr to x0
    adrp x0, _fg_adrp_x0@PAGE
    add x0, x0, _fg_adrp_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_add_x0@PAGE
    add x0, x0, _fg_add_x0@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // emit: mov x3, #val_byte_len
    adrp x0, _pfac_mov_x3@PAGE
    add x0, x0, _pfac_mov_x3@PAGEOFF
    bl _emit_str
    ldr x0, [sp], #16           // restore val_byte_len
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // emit: mov x2, x0 (val addr)
    adrp x0, _pemit_mov_x2@PAGE
    add x0, x0, _pemit_mov_x2@PAGEOFF
    bl _emit_str
    // emit: pop x1 (key_len)
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    // emit: ldr x0, [sp], #16 (pop key_addr)
    adrp x0, _pemit_pop_x0@PAGE
    add x0, x0, _pemit_pop_x0@PAGEOFF
    bl _emit_str
    // call _rt_emit_str: x0=key_ptr, x1=key_len, x2=val_ptr, x3=val_len
    adrp x0, _fg_emit_str_call@PAGE
    add x0, x0, _fg_emit_str_call@PAGEOFF
    bl _emit_str
    b _pemit_nl

_pemit_nl:
    bl _skip_nl
    mov x0, #0
    b _pemit_ret
_pemit_err:
    mov x0, #-1
_pemit_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// v0.5: _parse_close - close(fd)
// ────────────────────────────────────────
_parse_close:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl _tok_advance              // skip "close"
    mov w0, #TOK_LPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pcl_err
    bl _parse_expr               // fd in x0
    cmp x0, #0
    b.lt _pcl_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pcl_err
    adrp x0, _pclose_call@PAGE
    add x0, x0, _pclose_call@PAGEOFF
    bl _emit_str
    bl _skip_nl
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret
_pcl_err:
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// v0.5: _parse_write_line - write_line fd value
// ────────────────────────────────────────
_parse_write_line:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl _tok_advance              // skip "write_line"

    // parse fd expression
    bl _parse_expr
    cmp x0, #0
    b.lt _pwl_err
    // push fd
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str

    // check if string literal or expression
    bl _tok_peek
    cmp w0, #TOK_STR
    b.eq _pwl_str

    // integer expression
    bl _parse_expr
    cmp x0, #0
    b.lt _pwl_err
    // itoa
    adrp x0, _fg_itoa_call@PAGE
    add x0, x0, _fg_itoa_call@PAGEOFF
    bl _emit_str
    // now x1=itoa_buf, x2=len from itoa_call
    // pop fd into x0
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _pe_mov_x0_x1@PAGE
    add x0, x0, _pe_mov_x0_x1@PAGEOFF
    bl _emit_str
    // x0=fd, x1=itoa_buf, x2=len — call write_line
    adrp x0, _fg_writeline_call@PAGE
    add x0, x0, _fg_writeline_call@PAGEOFF
    bl _emit_str
    b _pwl_nl

_pwl_str:
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string
    mov x19, x0                 // string index
    // emit str write to fd
    bl _emit_str_write           // writes to stdout buffer — but we need fd
    // Actually for write_line we need to write to the fd, not stdout
    // Pop fd, load string addr+len, call _rt_write_line
    // Let me redo: pop fd into x0
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _pe_mov_x0_x1@PAGE
    add x0, x0, _pe_mov_x0_x1@PAGEOFF
    bl _emit_str
    // load string addr into x1
    adrp x0, _fg_wr_adrp@PAGE
    add x0, x0, _fg_wr_adrp@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_wr_add@PAGE
    add x0, x0, _fg_wr_add@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // compute byte len
    adrp x1, _str_ptrs@PAGE
    add x1, x1, _str_ptrs@PAGEOFF
    ldr x1, [x1, x19, lsl #3]
    adrp x2, _str_lens@PAGE
    add x2, x2, _str_lens@PAGEOFF
    ldr w2, [x2, x19, lsl #2]
    mov x3, #0
    mov x4, #0
41: cmp w3, w2
    b.ge 42f
    ldrb w5, [x1, x3]
    cmp w5, #'\\'
    b.ne 43f
    add x3, x3, #1
43: add x3, x3, #1
    add x4, x4, #1
    b 41b
42: adrp x0, _fg_wr_len@PAGE
    add x0, x0, _fg_wr_len@PAGEOFF
    bl _emit_str
    mov x0, x4
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // call _rt_write_line
    adrp x0, _fg_writeline_call@PAGE
    add x0, x0, _fg_writeline_call@PAGEOFF
    bl _emit_str
    b _pwl_nl

_pwl_nl:
    bl _skip_nl
    mov x0, #0
    b _pwl_ret
_pwl_err:
    mov x0, #-1
_pwl_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// v0.5: _parse_send - send pipe "key" value
// ────────────────────────────────────────
_parse_send:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    bl _tok_advance              // skip "send"

    // get pipe variable
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _psnd_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    // lookup pipe var — write_fd is at offset+8
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _psnd_err
    mov x21, x0                 // entry ptr
    // load write_fd (offset+8) into x0 and push
    ldr w0, [x21, #16]
    add w0, w0, #8
    bl _emit_load_var
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str

    // get key string
    bl _tok_peek
    cmp w0, #TOK_STR
    b.ne _psnd_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string
    mov x22, x0                 // key string index

    // parse value expression
    bl _parse_expr
    cmp x0, #0
    b.lt _psnd_err
    // x0 = value — for now treat as integer, convert to string via itoa
    adrp x0, _fg_itoa_call@PAGE
    add x0, x0, _fg_itoa_call@PAGEOFF
    bl _emit_str
    // now itoa_buf has the value string, x0=len
    // We need: x0=write_fd, x1=key_ptr, x2=key_len, x3=val_ptr, x4=val_len
    // push val_len (x0)
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // load val_ptr (itoa_buf)
    adrp x0, _fg_inbuf_ptr@PAGE
    add x0, x0, _fg_inbuf_ptr@PAGEOFF
    bl _emit_str
    // Actually itoa_buf, not input_buf
    // emit: adrp x3, _itoa_buf@PAGE / add x3, x3, _itoa_buf@PAGEOFF
    adrp x0, _psnd_itoa_ptr@PAGE
    add x0, x0, _psnd_itoa_ptr@PAGEOFF
    bl _emit_str
    // pop val_len into x4
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _psnd_mov_x4@PAGE
    add x0, x0, _psnd_mov_x4@PAGEOFF
    bl _emit_str
    // load key_ptr into x1
    adrp x0, _fg_wr_adrp@PAGE
    add x0, x0, _fg_wr_adrp@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    adrp x0, _fg_wr_add@PAGE
    add x0, x0, _fg_wr_add@PAGEOFF
    bl _emit_str
    adrp x0, _fg_sd@PAGE
    add x0, x0, _fg_sd@PAGEOFF
    bl _emit_str
    mov x0, x22
    bl _emit_num
    adrp x0, _fg_poff@PAGE
    add x0, x0, _fg_poff@PAGEOFF
    bl _emit_str
    // key_len into x2
    adrp x0, _fg_wr_len@PAGE
    add x0, x0, _fg_wr_len@PAGEOFF
    bl _emit_str
    mov x0, x20
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    adrp x0, _pemit_mov_x2@PAGE
    add x0, x0, _pemit_mov_x2@PAGEOFF
    bl _emit_str
    // pop write_fd into x0
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _pe_mov_x0_x1@PAGE
    add x0, x0, _pe_mov_x0_x1@PAGEOFF
    bl _emit_str
    // call _rt_send
    adrp x0, _fg_send_call@PAGE
    add x0, x0, _fg_send_call@PAGEOFF
    bl _emit_str
    bl _skip_nl
    mov x0, #0
    b _psnd_ret
_psnd_err:
    mov x0, #-1
_psnd_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// v0.5: _parse_recv - recv pipe key_var val_var
// (simplified: reads line from pipe, stores as string)
// ────────────────────────────────────────
_parse_recv:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl _tok_advance              // skip "recv"

    // get pipe variable
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _precv_err
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _precv_err
    mov x19, x0                 // pipe entry
    // load read_fd (at offset) into x0
    ldr w0, [x19, #16]
    bl _emit_load_var
    // call _rt_recv: x0=read_fd → x0=val_ptr, x1=val_len
    adrp x0, _fg_recv_call@PAGE
    add x0, x0, _fg_recv_call@PAGEOFF
    bl _emit_str

    // skip key_var and val_var idents (simplified: we don't store them separately)
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _precv_err
    bl _tok_advance              // skip key_var
    bl _tok_peek
    cmp w0, #TOK_IDENT
    b.ne _precv_err
    bl _tok_advance              // skip val_var

    bl _skip_nl
    mov x0, #0
    b _precv_ret
_precv_err:
    mov x0, #-1
_precv_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ── Local data for parser ──
.section __DATA,__data

_po_mov_x2:    .asciz "    mov x2, x0\n"
_pfac_neg_str: .asciz "    neg x0, x0\n"
_pe_mov_x0_x1: .asciz "    mov x0, x1\n"
_pt_mov_x1_imm: .asciz "    mov x1, #"
_pfn_uf:       .asciz "_uf_"
_pfn_colon_nl: .asciz ":\n"
_pfn_str_x:    .asciz "    str x"
_pfn_comma_x29: .asciz ", [x29, #-"
_pfn_bracket_nl: .asciz "]\n"
_efc_ldr_x:    .asciz "    ldr x"
_efc_pop_suf:  .asciz ", [sp], #16\n"
_pfac_mov_x1_x0: .asciz "    mov x1, x0\n"
_pspawn_fork:  .ascii "    bl _rt_flush\n    mov x16, #2\n    svc #0x80\n    cbnz x1, "
               .byte 0
_pspawn_exit:  .ascii "    bl _rt_flush\n    mov x19, #3\n4:  cmp x19, #256\n    b.ge 5f\n    mov x0, x19\n    mov x16, #6\n    svc #0x80\n    add x19, x19, #1\n    b 4b\n5:  mov x0, #0\n    mov x16, #1\n    svc #0x80\n"
               .byte 0
_pemit_mov_x2: .asciz "    mov x2, x0\n"
_psend_mov_x3: .asciz "    mov x3, x0\n"
_psend_mov_x4: .asciz "    mov x4, x0\n"
_pclose_call:  .asciz "    bl _rt_close\n"
_pfac_zero_pop: .asciz "0, [sp], #16\n"
_pfac_adrp_x2: .asciz "    adrp x2, "
_pfac_add_x2:  .asciz "    add x2, x2, "
_pfac_mov_x3:  .asciz "    mov x3, #"
_psnd_itoa_ptr: .ascii "    adrp x3, _itoa_buf@PAGE\n    add x3, x3, _itoa_buf@PAGEOFF\n"
                .byte 0
_psnd_mov_x4:  .asciz "    mov x4, x1\n"
_pemit_mov_x1_imm: .asciz "    mov x1, #"
_pemit_push_x1: .asciz "    str x1, [sp, #-16]!\n"
_pemit_pop_x0:  .asciz "    ldr x0, [sp], #16\n"

// v0.7: String builtin code fragments
_pfac_tostr_code: .ascii "    adrp x1, _itoa_buf@PAGE\n    add x1, x1, _itoa_buf@PAGEOFF\n    bl _rt_itoa\n"
                  .byte 0
_pfac_atoi_call:  .asciz "    bl _rt_atoi\n"

// ────────────────────────────────────────
// FFI: extern function table + link table
// ────────────────────────────────────────
.section __TEXT,__text
.align 2

// _ext_insert: x0=name_ptr, x1=name_len, w2=param_count
.globl _ext_insert
_ext_insert:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    mov w21, w2
    adrp x0, _ext_count@PAGE
    add x0, x0, _ext_count@PAGEOFF
    ldr w22, [x0]
    adrp x1, _ext_tab@PAGE
    add x1, x1, _ext_tab@PAGEOFF
    mov x2, #24
    mul x3, x22, x2
    add x1, x1, x3
    str x19, [x1]               // name_ptr
    str w20, [x1, #8]           // name_len
    str w21, [x1, #12]          // param_count
    add w22, w22, #1
    str w22, [x0]
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _ext_lookup: x0=name_ptr, x1=name_len → x0=entry ptr or 0
.globl _ext_lookup
_ext_lookup:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0
    mov x20, x1
    adrp x21, _ext_tab@PAGE
    add x21, x21, _ext_tab@PAGEOFF
    adrp x0, _ext_count@PAGE
    add x0, x0, _ext_count@PAGEOFF
    ldr w22, [x0]
    mov x0, #0
1:  cmp w0, w22
    b.ge 2f
    mov x1, #24
    mul x1, x0, x1
    add x2, x21, x1
    ldr x3, [x2]                // entry name_ptr
    ldr w4, [x2, #8]            // entry name_len
    cmp w4, w20
    b.ne 3f
    stp x0, x2, [sp, #-16]!
    mov x0, x19
    mov x1, x3
    mov x2, x20
    bl _strncmp
    mov x3, x0
    ldp x0, x2, [sp], #16
    cbz x3, 4f
3:  add x0, x0, #1
    b 1b
2:  mov x0, #0
    b 5f
4:  mov x0, x2
5:  ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _link_add: x1=name_ptr, w2=name_len — store lib name or .o path for linker
.globl _link_add
_link_add:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x1
    mov w20, w2
    adrp x0, _link_count@PAGE
    add x0, x0, _link_count@PAGEOFF
    ldr w1, [x0]
    adrp x2, _link_tab@PAGE
    add x2, x2, _link_tab@PAGEOFF
    mov x3, #64
    mul x3, x1, x3
    add x2, x2, x3              // dest slot
    // check if ends with ".o" — if so, copy path directly
    cmp w20, #2
    b.lt _la_lib                 // too short for ".o"
    sub w3, w20, #2
    ldrb w4, [x19, x3]
    cmp w4, #'.'
    b.ne _la_lib
    sub w3, w20, #1
    ldrb w4, [x19, x3]
    cmp w4, #'o'
    b.ne _la_lib
    // .o file: copy path directly
    mov x5, #0
1:  cmp w5, w20
    b.ge 2f
    ldrb w6, [x19, x5]
    strb w6, [x2, x5]
    add x5, x5, #1
    b 1b
2:  strb wzr, [x2, x5]
    b _la_done
_la_lib:
    // build "-l<name>"
    mov w3, #'-'
    strb w3, [x2]
    mov w3, #'l'
    strb w3, [x2, #1]
    add x4, x2, #2
    mov x5, #0
3:  cmp w5, w20
    b.ge 4f
    ldrb w6, [x19, x5]
    strb w6, [x4, x5]
    add x5, x5, #1
    b 3b
4:  strb wzr, [x4, x5]
_la_done:
    add w1, w1, #1
    str w1, [x0]
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _efc_is_extern: flag for C call emit path
.section __DATA,__bss
.globl _efc_is_extern
_efc_is_extern: .space 4
