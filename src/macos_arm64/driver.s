// ============================================================
// driver.s - File I/O, fork+exec assembler/linker, cleanup
// legnac v0.2 - macOS ARM64
// ============================================================
.include "src/macos_arm64/defs.inc"

.globl _read_file, _write_asm, _run_as, _run_ld, _cleanup
.globl _build_lib_path, _run_ld_multi

.section __TEXT,__text
.align 2

// ────────────────────────────────────────
// _read_file: x0 = filename → x0 = bytes read (-1 on error)
// ────────────────────────────────────────
_read_file:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // open(filename, O_RDONLY, 0)
    mov x1, #O_RDONLY
    mov x2, #0
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs _rf_err

    mov x19, x0                     // fd

    // read(fd, _src_buf, BUF_SIZE)
    mov x0, x19
    adrp x1, _src_buf@PAGE
    add x1, x1, _src_buf@PAGEOFF
    mov x2, #BUF_SIZE
    mov x16, #SYS_READ
    svc #0x80
    b.cs _rf_err

    mov x20, x0                     // bytes read

    // store src_len
    adrp x1, _src_len@PAGE
    add x1, x1, _src_len@PAGEOFF
    str x20, [x1]

    // null-terminate
    adrp x1, _src_buf@PAGE
    add x1, x1, _src_buf@PAGEOFF
    strb wzr, [x1, x20]

    // close(fd)
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80

    mov x0, x20
    b _rf_done

_rf_err:
    mov x0, #-1
_rf_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _write_asm: write _out_buf to _tmp_path_s
// Returns x0 = 0 ok, -1 error
// ────────────────────────────────────────
_write_asm:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // open(tmp_path_s, O_WRCREAT, 0644)
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    mov x1, #O_WRCREAT
    mov x2, #0x1A4                   // 0644
    mov x16, #SYS_OPEN
    svc #0x80
    b.cs _wa_err

    mov x19, x0                      // fd

    // write(fd, _out_buf, out_pos)
    mov x0, x19
    adrp x1, _out_buf@PAGE
    add x1, x1, _out_buf@PAGEOFF
    adrp x2, _out_pos@PAGE
    add x2, x2, _out_pos@PAGEOFF
    ldr x2, [x2]
    mov x16, #SYS_WRITE
    svc #0x80

    // close
    mov x0, x19
    mov x16, #SYS_CLOSE
    svc #0x80

    mov x0, #0
    b _wa_done

_wa_err:
    mov x0, #-1
_wa_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _run_as - Fork+exec assembler
// Returns x0 = child exit status
// ────────────────────────────────────────
_run_as:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #48                  // argv[6]

    // argv: as -o tmp_path_o tmp_path_s NULL
    adrp x0, _path_as@PAGE
    add x0, x0, _path_as@PAGEOFF
    str x0, [sp]                     // [0] = as
    adrp x0, _lnk_o@PAGE
    add x0, x0, _lnk_o@PAGEOFF
    str x0, [sp, #8]                // [1] = -o
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    str x0, [sp, #16]               // [2] = tmp.o
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    str x0, [sp, #24]               // [3] = tmp.s
    str xzr, [sp, #32]              // [4] = NULL

    // fork
    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _ra_child              // x1=1 → child

    // parent: wait for child
    mov x19, x0                      // child pid
    adrp x1, _wait_stat@PAGE
    add x1, x1, _wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    // extract exit status
    adrp x0, _wait_stat@PAGE
    add x0, x0, _wait_stat@PAGEOFF
    ldr w0, [x0]
    lsr w0, w0, #8
    and w0, w0, #0xFF

    add sp, sp, #48
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_ra_child:
    // execve(path_as, argv, NULL)
    adrp x0, _path_as@PAGE
    add x0, x0, _path_as@PAGEOFF
    mov x1, sp                       // argv
    mov x2, #0                       // envp
    mov x16, #SYS_EXECVE
    svc #0x80
    // if execve returns, exit 127
    mov x0, #127
    mov x16, #SYS_EXIT
    svc #0x80

// ────────────────────────────────────────
// _run_ld - Fork+exec linker
// Returns x0 = child exit status
// ────────────────────────────────────────
_run_ld:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    sub sp, sp, #128                 // argv[14] + padding

    // argv: ld -o out_name tmp.o -lSystem -syslibroot SDK -e _main -arch arm64 -dead_strip -x NULL
    adrp x0, _path_ld@PAGE
    add x0, x0, _path_ld@PAGEOFF
    str x0, [sp]                     // [0]
    adrp x0, _lnk_o@PAGE
    add x0, x0, _lnk_o@PAGEOFF
    str x0, [sp, #8]                // [1]
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    str x0, [sp, #16]               // [2]
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    str x0, [sp, #24]               // [3]
    adrp x0, _lnk_lsys@PAGE
    add x0, x0, _lnk_lsys@PAGEOFF
    str x0, [sp, #32]               // [4]
    adrp x0, _lnk_syslib@PAGE
    add x0, x0, _lnk_syslib@PAGEOFF
    str x0, [sp, #40]               // [5]
    adrp x0, _lnk_sdk@PAGE
    add x0, x0, _lnk_sdk@PAGEOFF
    str x0, [sp, #48]               // [6]
    adrp x0, _lnk_e@PAGE
    add x0, x0, _lnk_e@PAGEOFF
    str x0, [sp, #56]               // [7]
    adrp x0, _lnk_main@PAGE
    add x0, x0, _lnk_main@PAGEOFF
    str x0, [sp, #64]               // [8]
    adrp x0, _lnk_arch@PAGE
    add x0, x0, _lnk_arch@PAGEOFF
    str x0, [sp, #72]               // [9]
    adrp x0, _lnk_arm64@PAGE
    add x0, x0, _lnk_arm64@PAGEOFF
    str x0, [sp, #80]               // [10]
    adrp x0, _lnk_dead@PAGE
    add x0, x0, _lnk_dead@PAGEOFF
    str x0, [sp, #88]               // [11]
    adrp x0, _lnk_x@PAGE
    add x0, x0, _lnk_x@PAGEOFF
    str x0, [sp, #96]               // [12]
    str xzr, [sp, #104]             // [13] = NULL

    // fork
    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _rl_child

    // parent: wait
    mov x19, x0
    adrp x1, _wait_stat@PAGE
    add x1, x1, _wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    adrp x0, _wait_stat@PAGE
    add x0, x0, _wait_stat@PAGEOFF
    ldr w0, [x0]
    lsr w0, w0, #8
    and w0, w0, #0xFF

    add sp, sp, #128
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_rl_child:
    adrp x0, _path_ld@PAGE
    add x0, x0, _path_ld@PAGEOFF
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
    adrp x0, _tmp_path_s@PAGE
    add x0, x0, _tmp_path_s@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80
    adrp x0, _tmp_path_o@PAGE
    add x0, x0, _tmp_path_o@PAGEOFF
    mov x16, #SYS_UNLINK
    svc #0x80
    ret

// ────────────────────────────────────────
// _build_lib_path: w0=import_index → x0=0 ok, -1 err
// Builds "lib/<name>.legna" into _lib_path_buf
// ────────────────────────────────────────
_build_lib_path:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    mov w19, w0

    // get import entry
    adrp x0, _import_tab@PAGE
    add x0, x0, _import_tab@PAGEOFF
    mov x1, #32
    mul x1, x19, x1
    add x0, x0, x1
    ldr x20, [x0]               // name ptr (points into _src_buf)
    ldr w21, [x0, #8]           // name len

    // build path: "lib/" + name + ".legna\0"
    adrp x0, _lib_path_buf@PAGE
    add x0, x0, _lib_path_buf@PAGEOFF
    // "lib/"
    mov w1, #'l'
    strb w1, [x0, #0]
    mov w1, #'i'
    strb w1, [x0, #1]
    mov w1, #'b'
    strb w1, [x0, #2]
    mov w1, #'/'
    strb w1, [x0, #3]
    // copy name
    mov x2, #0
1:  cmp w2, w21
    b.ge 2f
    ldrb w3, [x20, x2]
    add x4, x0, #4
    strb w3, [x4, x2]
    add x2, x2, #1
    b 1b
2:  // ".legna\0"
    add x4, x0, #4
    add x4, x4, x2
    mov w1, #'.'
    strb w1, [x4, #0]
    mov w1, #'l'
    strb w1, [x4, #1]
    mov w1, #'e'
    strb w1, [x4, #2]
    mov w1, #'g'
    strb w1, [x4, #3]
    mov w1, #'n'
    strb w1, [x4, #4]
    mov w1, #'a'
    strb w1, [x4, #5]
    strb wzr, [x4, #6]

    // verify file exists (try open)
    adrp x0, _lib_path_buf@PAGE
    add x0, x0, _lib_path_buf@PAGEOFF
    mov x1, #O_RDONLY
    mov x2, #0
    mov x16, #SYS_OPEN
    svc #0x80
    cmp x0, #0
    b.lt _blp_err
    // close it
    mov x16, #SYS_CLOSE
    svc #0x80
    mov x0, #0
    b _blp_ret
_blp_err:
    mov x0, #-1
_blp_ret:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ────────────────────────────────────────
// _run_ld_multi: link main .o + all lib .o files
// Returns x0=0 ok, nonzero err
// ────────────────────────────────────────
_run_ld_multi:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    // allocate argv on stack: max 48 entries * 8 = 384 bytes
    sub sp, sp, #384

    mov x19, #0                      // argv index

    // [0] = ld path
    adrp x0, _path_ld@PAGE
    add x0, x0, _path_ld@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // [1] = "-o"
    adrp x0, _lnk_o@PAGE
    add x0, x0, _lnk_o@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // [2] = output name
    adrp x0, _out_name@PAGE
    add x0, x0, _out_name@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // [3] = main .o
    adrp x0, _main_o_path@PAGE
    add x0, x0, _main_o_path@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // [4..N] = lib .o files
    adrp x1, _lib_o_count@PAGE
    add x1, x1, _lib_o_count@PAGEOFF
    ldr w1, [x1]
    mov w2, #0
_rlm_lib_loop:
    cmp w2, w1
    b.ge _rlm_lib_done
    adrp x3, _lib_o_paths@PAGE
    add x3, x3, _lib_o_paths@PAGEOFF
    mov x4, #256
    mul x4, x2, x4
    add x3, x3, x4
    str x3, [sp, x19, lsl #3]
    add x19, x19, #1
    add w2, w2, #1
    b _rlm_lib_loop
_rlm_lib_done:

    // add -L/opt/homebrew/lib for homebrew libraries
    adrp x0, _lnk_lbrew@PAGE
    add x0, x0, _lnk_lbrew@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // add link library args (-l<name> or .o paths)
    adrp x1, _link_count@PAGE
    add x1, x1, _link_count@PAGEOFF
    ldr w1, [x1]
    mov w2, #0
_rlm_link_loop:
    cmp w2, w1
    b.ge _rlm_link_done
    adrp x3, _link_tab@PAGE
    add x3, x3, _link_tab@PAGEOFF
    mov x4, #64
    mul x4, x2, x4
    add x3, x3, x4
    // check if framework link: starts with '@'
    ldrb w5, [x3]
    cmp w5, #'@'
    b.ne _rlm_link_normal
    // emit: -framework <name> (skip '@')
    adrp x0, _lnk_framework@PAGE
    add x0, x0, _lnk_framework@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1
    add x3, x3, #1               // skip '@'
_rlm_link_normal:
    str x3, [sp, x19, lsl #3]
    add x19, x19, #1
    add w2, w2, #1
    b _rlm_link_loop
_rlm_link_done:

    // remaining fixed args
    adrp x0, _lnk_lsys@PAGE
    add x0, x0, _lnk_lsys@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_syslib@PAGE
    add x0, x0, _lnk_syslib@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_sdk@PAGE
    add x0, x0, _lnk_sdk@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_e@PAGE
    add x0, x0, _lnk_e@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_main@PAGE
    add x0, x0, _lnk_main@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_arch@PAGE
    add x0, x0, _lnk_arch@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_arm64@PAGE
    add x0, x0, _lnk_arm64@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_dead@PAGE
    add x0, x0, _lnk_dead@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    adrp x0, _lnk_x@PAGE
    add x0, x0, _lnk_x@PAGEOFF
    str x0, [sp, x19, lsl #3]
    add x19, x19, #1

    // NULL terminator
    str xzr, [sp, x19, lsl #3]

    // fork
    mov x16, #SYS_FORK
    svc #0x80
    cbnz x1, _rlm_child

    // parent: wait
    mov x19, x0
    adrp x1, _wait_stat@PAGE
    add x1, x1, _wait_stat@PAGEOFF
    mov x2, #0
    mov x3, #0
    mov x16, #SYS_WAIT4
    svc #0x80

    adrp x0, _wait_stat@PAGE
    add x0, x0, _wait_stat@PAGEOFF
    ldr w0, [x0]
    lsr w0, w0, #8
    and w0, w0, #0xFF

    add sp, sp, #384
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

_rlm_child:
    adrp x0, _path_ld@PAGE
    add x0, x0, _path_ld@PAGEOFF
    mov x1, sp
    mov x2, #0
    mov x16, #SYS_EXECVE
    svc #0x80
    mov x0, #127
    mov x16, #SYS_EXIT
    svc #0x80
