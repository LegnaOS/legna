// ============================================================
// lexer.s - Tokenizer for legnac v0.2
// Scans src_buf → tok_buf
// ============================================================
.include "src/macos_arm64/defs.inc"

.globl _lex
.globl _lex_add_tok, _lex_emit_nl, _lex_skip_comment
.globl _is_alpha, _is_alnum
.globl _lex_ident, _match_keyword, _lex_integer, _lex_string

.section __TEXT,__text
.align 2

// ────────────────────────────────────────
// _lex - Main tokenizer
// Returns x0 = token count, or -1 on error
// ────────────────────────────────────────
_lex:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    adrp x19, _src_buf@PAGE
    add x19, x19, _src_buf@PAGEOFF
    mov x20, #0                      // pos
    adrp x0, _src_len@PAGE
    add x0, x0, _src_len@PAGEOFF
    ldr x21, [x0]                    // src_len
    adrp x22, _tok_buf@PAGE
    add x22, x22, _tok_buf@PAGEOFF
    mov x23, #0                      // tok count
    mov x24, #1                      // line number
    mov x25, #1                      // at line start

    // init indent stack: push 0
    adrp x0, _ind_stack@PAGE
    add x0, x0, _ind_stack@PAGEOFF
    str wzr, [x0]
    adrp x0, _ind_sp@PAGE
    add x0, x0, _ind_sp@PAGEOFF
    mov w1, #1
    str w1, [x0]

_lex_loop:
    cmp x20, x21
    b.ge _lex_eof

    // at line start? handle indentation
    cbz x25, _lex_mid_line

    mov x25, #0
    // count leading spaces and tabs
    mov x26, #0
_lex_count_sp:
    cmp x20, x21
    b.ge _lex_indent_done
    ldrb w0, [x19, x20]
    cmp w0, #' '
    b.ne _lex_check_tab
    add x26, x26, #1
    add x20, x20, #1
    b _lex_count_sp
_lex_check_tab:
    cmp w0, #0x09              // tab
    b.ne _lex_indent_done
    add x26, x26, #4
    and x26, x26, #~3         // align to next tab stop (multiple of 4)
    add x20, x20, #1
    b _lex_count_sp

_lex_indent_done:
    // skip blank lines
    cmp x20, x21
    b.ge _lex_do_indent
    ldrb w0, [x19, x20]
    cmp w0, #'\n'
    b.ne 1f
    bl _lex_emit_nl
    add x20, x20, #1
    add x24, x24, #1
    mov x25, #1
    b _lex_loop
1:  cmp w0, #'#'
    b.ne _lex_do_indent
    // comment at line start: skip to eol, consume \n, stay at line start
    bl _lex_skip_comment
    cmp x20, x21
    b.ge _lex_loop
    add x20, x20, #1            // consume \n
    add x24, x24, #1
    mov x25, #1                  // next line is line start
    b _lex_loop

_lex_do_indent:
    // compare x26 (cur indent) with stack top
    adrp x0, _ind_stack@PAGE
    add x0, x0, _ind_stack@PAGEOFF
    adrp x1, _ind_sp@PAGE
    add x1, x1, _ind_sp@PAGEOFF
    ldr w2, [x1]                     // stack size
    sub w3, w2, #1
    // w3 is index, need to load word at [x0 + w3*4]
    // use x-reg arithmetic to avoid uxtw issues
    mov x4, x3
    ldr w4, [x0, x4, lsl #2]        // stack top value

    cmp w26, w4
    b.eq _lex_mid_line
    b.gt _lex_push_indent

    // dedent: pop until match
_lex_pop_loop:
    adrp x0, _ind_stack@PAGE
    add x0, x0, _ind_stack@PAGEOFF
    adrp x1, _ind_sp@PAGE
    add x1, x1, _ind_sp@PAGEOFF
    ldr w2, [x1]
    cmp w2, #1
    b.le _lex_indent_err
    sub w2, w2, #1
    str w2, [x1]
    // emit DEDENT
    mov w0, #TOK_DEDENT
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    // check if we match now
    adrp x0, _ind_stack@PAGE
    add x0, x0, _ind_stack@PAGEOFF
    adrp x1, _ind_sp@PAGE
    add x1, x1, _ind_sp@PAGEOFF
    ldr w2, [x1]
    sub w3, w2, #1
    mov x4, x3
    ldr w4, [x0, x4, lsl #2]
    cmp w26, w4
    b.gt _lex_indent_err
    b.lt _lex_pop_loop
    b _lex_mid_line

_lex_push_indent:
    adrp x0, _ind_stack@PAGE
    add x0, x0, _ind_stack@PAGEOFF
    adrp x1, _ind_sp@PAGE
    add x1, x1, _ind_sp@PAGEOFF
    ldr w2, [x1]
    mov x4, x2
    str w26, [x0, x4, lsl #2]
    add w2, w2, #1
    str w2, [x1]
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

    // skip mid-line spaces and tabs
    cmp w0, #' '
    b.eq _lex_skip_ws
    cmp w0, #0x09
    b.ne 1f
_lex_skip_ws:
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
    // digit
    sub w1, w0, #'0'
    cmp w1, #9
    b.hi 5f
    bl _lex_integer
    b _lex_loop
5:
    // alpha or underscore
    bl _is_alpha
    cbz x0, 6f
    bl _lex_ident
    b _lex_loop
6:
    // single/double char operators
    ldrb w0, [x19, x20]

    cmp w0, #':'
    b.ne _op_lparen
    mov w0, #TOK_COLON
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_lparen:
    cmp w0, #'('
    b.ne _op_rparen
    mov w0, #TOK_LPAREN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_rparen:
    cmp w0, #')'
    b.ne _op_comma
    mov w0, #TOK_RPAREN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_comma:
    cmp w0, #','
    b.ne _op_lbracket
    mov w0, #TOK_COMMA
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_lbracket:
    cmp w0, #'['
    b.ne _op_rbracket
    mov w0, #TOK_LBRACKET
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_rbracket:
    cmp w0, #']'
    b.ne _op_plus
    mov w0, #TOK_RBRACKET
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_plus:
    cmp w0, #'+'
    b.ne _op_minus
    // peek next char for +=
    add x1, x20, #1
    cmp x1, x21
    b.ge _op_plus_single
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _op_plus_single
    mov w0, #TOK_PLUS_EQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_plus_single:
    mov w0, #TOK_PLUS
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_minus:
    cmp w0, #'-'
    b.ne _op_star
    // peek next char for -=
    add x1, x20, #1
    cmp x1, x21
    b.ge _op_minus_single
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _op_minus_single
    mov w0, #TOK_MINUS_EQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_minus_single:
    mov w0, #TOK_MINUS
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_star:
    cmp w0, #'*'
    b.ne _op_slash
    // peek next char for *=
    add x1, x20, #1
    cmp x1, x21
    b.ge _op_star_single
    ldrb w1, [x19, x1]
    cmp w1, #'='
    b.ne _op_star_single
    mov w0, #TOK_STAR_EQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_star_single:
    mov w0, #TOK_STAR
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_slash:
    cmp w0, #'/'
    b.ne _op_mod
    mov w0, #TOK_SLASH
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_mod:
    cmp w0, #'%'
    b.ne _op_eq
    mov w0, #TOK_MOD
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_eq:
    cmp w0, #'='
    b.ne _op_bang
    // peek next char for ==
    add x4, x20, #1
    cmp x4, x21
    b.ge _op_eq_single
    ldrb w5, [x19, x4]
    cmp w5, #'='
    b.ne _op_eq_single
    // ==
    mov w0, #TOK_EQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_eq_single:
    mov w0, #TOK_ASSIGN
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_bang:
    cmp w0, #'!'
    b.ne _op_lt
    add x4, x20, #1
    cmp x4, x21
    b.ge _lex_err
    ldrb w5, [x19, x4]
    cmp w5, #'='
    b.ne _lex_err
    mov w0, #TOK_NEQ
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop

_op_lt:
    cmp w0, #'<'
    b.ne _op_gt
    add x4, x20, #1
    cmp x4, x21
    b.ge _op_lt_single
    ldrb w5, [x19, x4]
    cmp w5, #'='
    b.ne _op_lt_single
    mov w0, #TOK_LTE
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_lt_single:
    mov w0, #TOK_LT
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_gt:
    cmp w0, #'>'
    b.ne _op_dot
    add x4, x20, #1
    cmp x4, x21
    b.ge _op_gt_single
    ldrb w5, [x19, x4]
    cmp w5, #'='
    b.ne _op_gt_single
    mov w0, #TOK_GTE
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop
_op_gt_single:
    mov w0, #TOK_GT
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1
    b _lex_loop

_op_dot:
    cmp w0, #'.'
    b.ne _lex_err
    add x4, x20, #1
    cmp x4, x21
    b.ge _lex_err
    ldrb w5, [x19, x4]
    cmp w5, #'.'
    b.ne _lex_err
    mov w0, #TOK_DOTDOT
    mov x1, #2
    add x2, x19, x20
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #2
    b _lex_loop

// ── EOF handling ──
_lex_eof:
    // emit remaining DEDENTs
    adrp x0, _ind_sp@PAGE
    add x0, x0, _ind_sp@PAGEOFF
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
    mov w0, #TOK_EOF
    mov x1, #0
    mov x2, #0
    mov x3, #0
    bl _lex_add_tok
    // store count
    adrp x0, _tok_count@PAGE
    add x0, x0, _tok_count@PAGEOFF
    str w23, [x0]
    mov x0, x23
    b _lex_ret

// ── Error paths ──
_lex_err:
    adrp x0, _err_syntax@PAGE
    add x0, x0, _err_syntax@PAGEOFF
    mov x1, x24
    bl _err_line
    mov x0, #-1
    b _lex_ret

_lex_indent_err:
    adrp x0, _err_indent@PAGE
    add x0, x0, _err_indent@PAGEOFF
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

// ════════════════════════════════════════
// Lexer sub-functions
// ════════════════════════════════════════

// _lex_add_tok: w0=type, x1=len, x2=ptr, x3=value
// Stores token and advances x22/x23
_lex_add_tok:
    cmp x23, #MAX_TOKENS
    b.ge _lex_overflow
    str w0, [x22]                    // type
    str w1, [x22, #4]               // len
    str x2, [x22, #8]               // ptr
    str x3, [x22, #16]              // value
    add x22, x22, #TOK_SIZE
    add x23, x23, #1
    ret

_lex_overflow:
    stp x29, x30, [sp, #-16]!
    adrp x0, _err_overflow@PAGE
    add x0, x0, _err_overflow@PAGEOFF
    bl _print_err
    mov x0, #1
    mov x16, #1
    svc #0x80

// _lex_emit_nl: emit a TOK_NL token
_lex_emit_nl:
    mov w0, #TOK_NL
    mov x1, #1
    add x2, x19, x20
    mov x3, #0
    b _lex_add_tok

// _lex_skip_comment: skip from # to end of line (don't consume \n)
_lex_skip_comment:
1:  cmp x20, x21
    b.ge 2f
    ldrb w0, [x19, x20]
    cmp w0, #'\n'
    b.eq 2f
    add x20, x20, #1
    b 1b
2:  ret

// _is_alpha: check if byte at [x19, x20] is alpha or '_'
// Returns x0 = 1 if yes, 0 if no
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

// _is_alnum: check if byte at [x19, x20] is alpha, digit, or '_'
// Returns x0 = 1 if yes, 0 if no
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

// _lex_ident: scan identifier/keyword starting at x20
_lex_ident:
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    mov x27, x20                     // start pos
1:  cmp x20, x21
    b.ge 2f
    bl _is_alnum
    cbz x0, 2f
    add x20, x20, #1
    b 1b
2:  sub x28, x20, x27               // length
    add x0, x19, x27                // ptr
    mov x1, x28                      // len
    bl _match_keyword                // w0 = token type
    mov x1, x28
    add x2, x19, x27
    mov x3, #0
    bl _lex_add_tok
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _match_keyword: x0=ptr, x1=len → w0=token type
_match_keyword:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    // save ptr and len in callee-saved regs (shadow the lexer's x19/x20)
    // We need our own saved copies since we call _strncmp which may clobber x0-x18
    mov x19, x0                     // ptr
    mov x20, x1                     // len

    // "legna" (5)
    cmp x20, #5
    b.ne _mk_try_output
    mov x0, x19
    adrp x1, _kw_legna@PAGE
    add x1, x1, _kw_legna@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_legna

_mk_try_output:
    // "output" (6)
    cmp x20, #6
    b.ne _mk_try_let
    mov x0, x19
    adrp x1, _kw_output@PAGE
    add x1, x1, _kw_output@PAGEOFF
    mov x2, #6
    bl _strncmp
    cbz x0, _mk_output

_mk_try_let:
    // "let" (3)
    cmp x20, #3
    b.ne _mk_try_if
    mov x0, x19
    adrp x1, _kw_let@PAGE
    add x1, x1, _kw_let@PAGEOFF
    mov x2, #3
    bl _strncmp
    cbz x0, _mk_let

_mk_try_if:
    // "if" (2)
    cmp x20, #2
    b.ne _mk_try_else
    mov x0, x19
    adrp x1, _kw_if@PAGE
    add x1, x1, _kw_if@PAGEOFF
    mov x2, #2
    bl _strncmp
    cbz x0, _mk_if

_mk_try_else:
    // "else" (4)
    cmp x20, #4
    b.ne _mk_try_while
    mov x0, x19
    adrp x1, _kw_else@PAGE
    add x1, x1, _kw_else@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_else

_mk_try_while:
    // "while" (5)
    cmp x20, #5
    b.ne _mk_try_for
    mov x0, x19
    adrp x1, _kw_while@PAGE
    add x1, x1, _kw_while@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_while

_mk_try_for:
    // "for" (3)
    cmp x20, #3
    b.ne _mk_try_in
    mov x0, x19
    adrp x1, _kw_for@PAGE
    add x1, x1, _kw_for@PAGEOFF
    mov x2, #3
    bl _strncmp
    cbz x0, _mk_for

_mk_try_in:
    // "in" (2)
    cmp x20, #2
    b.ne _mk_try_innum
    mov x0, x19
    adrp x1, _kw_in@PAGE
    add x1, x1, _kw_in@PAGEOFF
    mov x2, #2
    bl _strncmp
    cbz x0, _mk_in

_mk_try_innum:
    // "input_num" (9)
    cmp x20, #9
    b.ne _mk_try_instr
    mov x0, x19
    adrp x1, _kw_input_num@PAGE
    add x1, x1, _kw_input_num@PAGEOFF
    mov x2, #9
    bl _strncmp
    cbz x0, _mk_innum

_mk_try_instr:
    // "input_str" (9)
    cmp x20, #9
    b.ne _mk_try_continue
    mov x0, x19
    adrp x1, _kw_input_str@PAGE
    add x1, x1, _kw_input_str@PAGEOFF
    mov x2, #9
    bl _strncmp
    cbz x0, _mk_instr

_mk_try_continue:
    // "continue" (8)
    cmp x20, #8
    b.ne _mk_try_break
    mov x0, x19
    adrp x1, _kw_continue@PAGE
    add x1, x1, _kw_continue@PAGEOFF
    mov x2, #8
    bl _strncmp
    cbz x0, _mk_continue

_mk_try_break:
    // "break" (5)
    cmp x20, #5
    b.ne _mk_try_elif
    mov x0, x19
    adrp x1, _kw_break@PAGE
    add x1, x1, _kw_break@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_break

_mk_try_elif:
    // "elif" (4)
    cmp x20, #4
    b.ne _mk_try_and
    mov x0, x19
    adrp x1, _kw_elif@PAGE
    add x1, x1, _kw_elif@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_elif

_mk_try_and:
    // "and" (3)
    cmp x20, #3
    b.ne _mk_try_or
    mov x0, x19
    adrp x1, _kw_and@PAGE
    add x1, x1, _kw_and@PAGEOFF
    mov x2, #3
    bl _strncmp
    cbz x0, _mk_and

_mk_try_or:
    // "or" (2)
    cmp x20, #2
    b.ne _mk_try_not
    mov x0, x19
    adrp x1, _kw_or@PAGE
    add x1, x1, _kw_or@PAGEOFF
    mov x2, #2
    bl _strncmp
    cbz x0, _mk_or

_mk_try_not:
    // "not" (3)
    cmp x20, #3
    b.ne _mk_try_fn
    mov x0, x19
    adrp x1, _kw_not@PAGE
    add x1, x1, _kw_not@PAGEOFF
    mov x2, #3
    bl _strncmp
    cbz x0, _mk_not

_mk_try_fn:
    // "fn" (2)
    cmp x20, #2
    b.ne _mk_try_return
    mov x0, x19
    adrp x1, _kw_fn@PAGE
    add x1, x1, _kw_fn@PAGEOFF
    mov x2, #2
    bl _strncmp
    cbz x0, _mk_fn

_mk_try_return:
    // "return" (6)
    cmp x20, #6
    b.ne _mk_try_spawn
    mov x0, x19
    adrp x1, _kw_return@PAGE
    add x1, x1, _kw_return@PAGEOFF
    mov x2, #6
    bl _strncmp
    cbz x0, _mk_return

// v0.5: Concurrency keywords
_mk_try_spawn:
    // "spawn" (5)
    cmp x20, #5
    b.ne _mk_try_wait
    mov x0, x19
    adrp x1, _kw_spawn@PAGE
    add x1, x1, _kw_spawn@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_spawn

_mk_try_wait:
    // "wait" (4)
    cmp x20, #4
    b.ne _mk_try_pipe
    mov x0, x19
    adrp x1, _kw_wait@PAGE
    add x1, x1, _kw_wait@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_wait

_mk_try_pipe:
    // "pipe" (4)
    cmp x20, #4
    b.ne _mk_try_send
    mov x0, x19
    adrp x1, _kw_pipe@PAGE
    add x1, x1, _kw_pipe@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_pipe

_mk_try_send:
    // "send" (4)
    cmp x20, #4
    b.ne _mk_try_recv
    mov x0, x19
    adrp x1, _kw_send@PAGE
    add x1, x1, _kw_send@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_send

_mk_try_recv:
    // "recv" (4)
    cmp x20, #4
    b.ne _mk_try_emit
    mov x0, x19
    adrp x1, _kw_recv@PAGE
    add x1, x1, _kw_recv@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_recv

// v0.5: AI-native I/O keywords
_mk_try_emit:
    // "emit" (4)
    cmp x20, #4
    b.ne _mk_try_open
    mov x0, x19
    adrp x1, _kw_emit@PAGE
    add x1, x1, _kw_emit@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_emit

_mk_try_open:
    // "open" (4)
    cmp x20, #4
    b.ne _mk_try_close
    mov x0, x19
    adrp x1, _kw_open@PAGE
    add x1, x1, _kw_open@PAGEOFF
    mov x2, #4
    bl _strncmp
    cbz x0, _mk_open

_mk_try_close:
    // "close" (5)
    cmp x20, #5
    b.ne _mk_try_rdline
    mov x0, x19
    adrp x1, _kw_close@PAGE
    add x1, x1, _kw_close@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_close

_mk_try_rdline:
    // "read_line" (9)
    cmp x20, #9
    b.ne _mk_try_wrline
    mov x0, x19
    adrp x1, _kw_read_line@PAGE
    add x1, x1, _kw_read_line@PAGEOFF
    mov x2, #9
    bl _strncmp
    cbz x0, _mk_rdline

_mk_try_wrline:
    // "write_line" (10)
    cmp x20, #10
    b.ne _mk_try_array
    mov x0, x19
    adrp x1, _kw_write_line@PAGE
    add x1, x1, _kw_write_line@PAGEOFF
    mov x2, #10
    bl _strncmp
    cbz x0, _mk_wrline

_mk_try_array:
    // "array" (5)
    cmp x20, #5
    b.ne _mk_try_len
    mov x0, x19
    adrp x1, _kw_array@PAGE
    add x1, x1, _kw_array@PAGEOFF
    mov x2, #5
    bl _strncmp
    cbz x0, _mk_array

_mk_try_len:
    // "len" (3)
    cmp x20, #3
    b.ne _mk_try_char_at
    mov x0, x19
    adrp x1, _kw_len@PAGE
    add x1, x1, _kw_len@PAGEOFF
    mov x2, #3
    bl _strncmp
    cbz x0, _mk_len

_mk_try_char_at:
    // "char_at" (7)
    cmp x20, #7
    b.ne _mk_try_to_str
    mov x0, x19
    adrp x1, _kw_char_at@PAGE
    add x1, x1, _kw_char_at@PAGEOFF
    mov x2, #7
    bl _strncmp
    cbz x0, _mk_char_at

_mk_try_to_str:
    // "to_str" (6)
    cmp x20, #6
    b.ne _mk_try_to_num
    mov x0, x19
    adrp x1, _kw_to_str@PAGE
    add x1, x1, _kw_to_str@PAGEOFF
    mov x2, #6
    bl _strncmp
    cbz x0, _mk_to_str

_mk_try_to_num:
    // "to_num" (6)
    cmp x20, #6
    b.ne _mk_try_import
    mov x0, x19
    adrp x1, _kw_to_num@PAGE
    add x1, x1, _kw_to_num@PAGEOFF
    mov x2, #6
    bl _strncmp
    cbz x0, _mk_to_num

_mk_try_import:
    // "import" (6)
    cmp x20, #6
    b.ne _mk_ident
    mov x0, x19
    adrp x1, _kw_import@PAGE
    add x1, x1, _kw_import@PAGEOFF
    mov x2, #6
    bl _strncmp
    cbz x0, _mk_import

_mk_ident:
    mov w0, #TOK_IDENT
    b _mk_ret
_mk_legna:
    mov w0, #TOK_KW_LEGNA
    b _mk_ret
_mk_output:
    mov w0, #TOK_KW_OUTPUT
    b _mk_ret
_mk_let:
    mov w0, #TOK_KW_LET
    b _mk_ret
_mk_if:
    mov w0, #TOK_KW_IF
    b _mk_ret
_mk_else:
    mov w0, #TOK_KW_ELSE
    b _mk_ret
_mk_while:
    mov w0, #TOK_KW_WHILE
    b _mk_ret
_mk_for:
    mov w0, #TOK_KW_FOR
    b _mk_ret
_mk_in:
    mov w0, #TOK_KW_IN
    b _mk_ret
_mk_innum:
    mov w0, #TOK_KW_INNUM
    b _mk_ret
_mk_instr:
    mov w0, #TOK_KW_INSTR
    b _mk_ret
_mk_elif:
    mov w0, #TOK_KW_ELIF
    b _mk_ret
_mk_break:
    mov w0, #TOK_KW_BREAK
    b _mk_ret
_mk_continue:
    mov w0, #TOK_KW_CONT
    b _mk_ret
_mk_and:
    mov w0, #TOK_KW_AND
    b _mk_ret
_mk_or:
    mov w0, #TOK_KW_OR
    b _mk_ret
_mk_not:
    mov w0, #TOK_KW_NOT
    b _mk_ret
_mk_fn:
    mov w0, #TOK_KW_FN
    b _mk_ret
_mk_return:
    mov w0, #TOK_KW_RETURN
    b _mk_ret
_mk_spawn:
    mov w0, #TOK_KW_SPAWN
    b _mk_ret
_mk_wait:
    mov w0, #TOK_KW_WAIT
    b _mk_ret
_mk_pipe:
    mov w0, #TOK_KW_PIPE
    b _mk_ret
_mk_send:
    mov w0, #TOK_KW_SEND
    b _mk_ret
_mk_recv:
    mov w0, #TOK_KW_RECV
    b _mk_ret
_mk_emit:
    mov w0, #TOK_KW_EMIT
    b _mk_ret
_mk_open:
    mov w0, #TOK_KW_OPEN
    b _mk_ret
_mk_close:
    mov w0, #TOK_KW_CLOSE
    b _mk_ret
_mk_rdline:
    mov w0, #TOK_KW_RDLINE
    b _mk_ret
_mk_wrline:
    mov w0, #TOK_KW_WRLINE
    b _mk_ret
_mk_array:
    mov w0, #TOK_KW_ARRAY
    b _mk_ret
_mk_len:
    mov w0, #TOK_KW_LEN
    b _mk_ret
_mk_char_at:
    mov w0, #TOK_KW_CHARAT
    b _mk_ret
_mk_to_str:
    mov w0, #TOK_KW_TOSTR
    b _mk_ret
_mk_to_num:
    mov w0, #TOK_KW_TONUM
    b _mk_ret
_mk_import:
    mov w0, #TOK_KW_IMPORT
    b _mk_ret
_mk_ret:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _lex_integer: scan decimal integer, compute value
_lex_integer:
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    mov x27, x20                     // start pos
    mov x28, #0                      // value
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
    sub x1, x20, x27                // length
    add x2, x19, x27                // ptr
    mov x3, x28                      // value
    bl _lex_add_tok
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// _lex_string: scan string literal (opening " at x20)
_lex_string:
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    add x20, x20, #1                // skip opening "
    mov x27, x20                     // content start
1:  cmp x20, x21
    b.ge _lex_str_err
    ldrb w0, [x19, x20]
    cmp w0, #'"'
    b.eq 2f
    cmp w0, #'\\'
    b.ne 3f
    add x20, x20, #1                // skip escape char
3:  add x20, x20, #1
    b 1b
2:  // x27 = start, x20 = closing quote pos
    mov w0, #TOK_STR
    sub x1, x20, x27                // raw length (between quotes)
    add x2, x19, x27                // ptr to content
    mov x3, #0
    bl _lex_add_tok
    add x20, x20, #1                // skip closing "
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_lex_str_err:
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    b _lex_err
