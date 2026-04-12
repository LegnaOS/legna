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
    mov x1, #0
    bl _err_line
    mov x0, #-1
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

// _sym_insert: x0=name_ptr, x1=name_len, w2=type → x0=entry_ptr
_sym_insert:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov x19, x0                  // name_ptr
    mov x20, x1                  // name_len
    mov w21, w2                  // type

    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    ldr w22, [x0]               // current count

    // compute entry address
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
    cmp w21, #TY_STR
    b.eq 1f
    add w3, w3, #8              // int = 8 bytes
    b 2f
1:  add w3, w3, #16             // str = 16 bytes (ptr+len)
2:  str w3, [x0]                // update frame_size
    str w3, [x1, #16]           // store offset

    // increment count
    add w22, w22, #1
    adrp x0, _sym_count@PAGE
    add x0, x0, _sym_count@PAGEOFF
    str w22, [x0]

    mov x0, x1                  // return entry ptr
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

// _emit_mov_imm: emit mov x0, #N
_emit_mov_imm:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    cmp x19, #0
    b.lt 1f
    adrp x0, _fg_mov@PAGE
    add x0, x0, _fg_mov@PAGEOFF
    bl _emit_str
    mov x0, x19
    bl _emit_num
    b 2f
1:  adrp x0, _fg_movn@PAGE
    add x0, x0, _fg_movn@PAGEOFF
    bl _emit_str
    neg x0, x19
    bl _emit_num
2:  adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
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

// _emit_str_write: emit write syscall for string literal index x0
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

    // emit header (runtime + _main prologue)
    bl _emit_header

    // skip leading newlines
    bl _skip_nl

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
_pp_err:
    mov x0, #-1
_pp_ret:
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
    b.ne 7f
    bl _parse_assign
    b _ps_ret
7:  // unexpected token
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    mov x1, #0
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
    b.ne 2f
1:  mov w21, #TY_STR
2:
    // insert symbol
    mov x0, x19
    mov x1, x20
    mov w2, w21
    bl _sym_insert
    mov x22, x0                 // entry ptr

    // parse expression
    cmp w21, #TY_STR
    b.eq _pl_str_init

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
    adrp x0, _fg_wr_adrp@PAGE
    add x0, x0, _fg_wr_adrp@PAGEOFF
    bl _emit_str
    // reuse "x0" instead of "x1" — emit manually
    mov w0, #'_'
    bl _emit_char
    mov w0, #'s'
    bl _emit_char
    mov x0, x19
    bl _emit_num
    adrp x0, _fg_page@PAGE
    add x0, x0, _fg_page@PAGEOFF
    bl _emit_str
    // add x0, x0, _sN@PAGEOFF — emit with x0 reg
    adrp x0, _fg_wr_add@PAGE
    add x0, x0, _fg_wr_add@PAGEOFF
    bl _emit_str
    mov w0, #'_'
    bl _emit_char
    mov w0, #'s'
    bl _emit_char
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

    // lookup
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pa_undef
    mov x19, x0                 // entry ptr

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
_pa_undef:
    adrp x0, _err_undef@PAGE
    add x0, x0, _err_undef@PAGEOFF
    mov x1, #0
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

    // left expr
    bl _parse_expr
    cmp x0, #0
    b.lt _pc_err

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

    // pop left into x1, emit cmp x1, x0
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
    adrp x0, _fg_cmp1@PAGE
    add x0, x0, _fg_cmp1@PAGEOFF
    bl _emit_str

    mov w0, w19                  // return op type
    b _pc_ret
_pc_err:
    mov x0, #-1
_pc_ret:
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

    // parse condition
    bl _parse_condition
    cmp x0, #0
    b.lt _pi_err
    mov w19, w0                  // comp op

    // allocate labels
    bl _new_label
    mov x20, x0                  // lbl_else
    bl _new_label
    mov x21, x0                  // lbl_end

    // emit inverted branch to else
    mov w0, w19
    mov x1, x20
    bl _emit_inv_branch

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

    // check for else clause
    bl _skip_nl
    bl _tok_peek
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

    // parse condition
    bl _parse_condition
    cmp x0, #0
    b.lt _pw_err
    mov w21, w0                  // comp op

    // emit inverted branch to end
    mov w0, w21
    mov x1, x20
    bl _emit_inv_branch

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

    // parse body
    bl _parse_block
    cmp x0, #0
    b.lt _pw_err

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

    // get start value
    bl _tok_peek
    cmp w0, #TOK_INT
    b.ne _pf_err
    bl _tok_current
    ldr x22, [x0, #16]          // start value
    bl _tok_advance

    // expect ".."
    mov w0, #TOK_DOTDOT
    bl _tok_expect
    cmp x0, #0
    b.lt _pf_err

    // get end value
    bl _tok_peek
    cmp w0, #TOK_INT
    b.ne _pf_err
    bl _tok_current
    ldr x23, [x0, #16]          // end value
    bl _tok_advance

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

    // emit: mov x0, #start; str x0, [x29, #-offset]
    mov x0, x22
    bl _emit_mov_imm
    ldr w0, [x21, #16]
    bl _emit_store_var

    // allocate labels (use x24, x25 to avoid clobbering x22/x23)
    bl _new_label
    mov x24, x0                  // lbl_top
    bl _new_label
    mov x25, x0                  // lbl_end

    // emit top label
    mov x0, x24
    bl _emit_label

    // emit: ldr x0, [x29, #-offset]
    ldr w0, [x21, #16]
    bl _emit_load_var
    // emit: cmp x0, #end_value
    adrp x0, _fg_cmp0@PAGE
    add x0, x0, _fg_cmp0@PAGEOFF
    bl _emit_str
    mov x0, x23                  // end value
    bl _emit_num
    adrp x0, _fg_nl@PAGE
    add x0, x0, _fg_nl@PAGEOFF
    bl _emit_str
    // emit: b.ge lbl_end
    mov w0, #TOK_LT             // for < end, invert = b.ge
    mov x1, x25
    bl _emit_inv_branch

    // parse body
    bl _parse_block
    cmp x0, #0
    b.lt _pf_err

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
    // push left
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    // parse right term
    bl _parse_term
    cmp x0, #0
    b.lt _pe_err
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
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_term: factor { (*|/|%) factor }
_parse_term:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

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
    adrp x0, _fg_push@PAGE
    add x0, x0, _fg_push@PAGEOFF
    bl _emit_str
    bl _parse_factor
    cmp x0, #0
    b.lt _pt_err
    adrp x0, _fg_pop1@PAGE
    add x0, x0, _fg_pop1@PAGEOFF
    bl _emit_str
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
    b _pt_loop

_pt_done:
    mov x0, #0
    b _pt_ret
_pt_err:
    mov x0, #-1
_pt_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _parse_factor: INT | STR | IDENT | input_num() | input_str() | (expr) | -factor
_parse_factor:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    bl _tok_peek

    // integer literal
    cmp w0, #TOK_INT
    b.ne _pfac_str
    bl _tok_current
    ldr x19, [x0, #16]          // value
    bl _tok_advance
    mov x0, x19
    bl _emit_mov_imm
    mov x0, #0
    b _pfac_ret

_pfac_str:
    cmp w0, #TOK_STR
    b.ne _pfac_ident
    // string in factor context — just register it, load address
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _reg_string
    // we don't emit anything for string factor in expr context
    // the caller (output) handles string specially
    mov x0, #0
    b _pfac_ret

_pfac_ident:
    cmp w0, #TOK_IDENT
    b.ne _pfac_innum
    bl _tok_current
    ldr x19, [x0, #8]
    ldr w20, [x0, #4]
    bl _tok_advance
    mov x0, x19
    mov x1, x20
    bl _sym_lookup
    cbz x0, _pfac_undef
    ldr w0, [x0, #16]           // offset
    bl _emit_load_var
    mov x0, #0
    b _pfac_ret

_pfac_innum:
    cmp w0, #TOK_KW_INNUM
    b.ne _pfac_instr
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
    b.ne _pfac_lparen
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

_pfac_lparen:
    cmp w0, #TOK_LPAREN
    b.ne _pfac_neg
    bl _tok_advance
    bl _parse_expr
    cmp x0, #0
    b.lt _pfac_err
    mov w0, #TOK_RPAREN
    bl _tok_expect
    cmp x0, #0
    b.lt _pfac_err
    mov x0, #0
    b _pfac_ret

_pfac_neg:
    // unary minus
    cmp w0, #TOK_MINUS
    b.ne _pfac_err
    bl _tok_advance
    bl _parse_factor
    cmp x0, #0
    b.lt _pfac_err
    // emit: neg x0, x0
    adrp x0, _pfac_neg_str@PAGE
    add x0, x0, _pfac_neg_str@PAGEOFF
    bl _emit_str
    mov x0, #0
    b _pfac_ret

_pfac_undef:
    adrp x0, _err_undef@PAGE
    add x0, x0, _err_undef@PAGEOFF
    mov x1, #0
    bl _err_line
_pfac_err:
    mov x0, #-1
_pfac_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ── Local data for parser ──
.section __DATA,__data

_po_mov_x2:    .asciz "    mov x2, x0\n"
_pfac_neg_str: .asciz "    neg x0, x0\n"
